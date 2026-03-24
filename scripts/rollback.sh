#!/bin/bash
# ─── Script de rollback ShopFlow ─────────────────────────────────────────────
# Usage : ./scripts/rollback.sh [staging|prod] [revision_number]
set -euo pipefail

ENVIRONMENT="${1:-prod}"
REVISION="${2:-}"
APP_NAME="shopflow-api-${ENVIRONMENT}"

echo "╔══════════════════════════════════════════════╗"
echo "║   ShopFlow — Rollback ${ENVIRONMENT}               ║"
echo "╚══════════════════════════════════════════════╝"

# ─── Historique des déploiements ─────────────────────────────────────────────
echo ""
echo "▶ Historique des déploiements ArgoCD :"
argocd app history "${APP_NAME}" --output wide

if [ -z "$REVISION" ]; then
  echo ""
  read -p "Numéro de révision cible : " REVISION
fi

echo ""
echo "⚠ Rollback vers la révision ${REVISION} sur ${ENVIRONMENT} ?"
read -p "Confirmer [y/N] : " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Rollback annulé."
  exit 0
fi

# ─── Rollback ArgoCD ─────────────────────────────────────────────────────────
echo "▶ Rollback en cours..."
argocd app rollback "${APP_NAME}" "${REVISION}"

echo ""
echo "▶ Attente de la synchronisation..."
argocd app wait "${APP_NAME}" --health --timeout 120

echo ""
echo "▶ Vérification post-rollback..."
kubectl rollout status deployment/shopflow-api \
  -n "shopflow-${ENVIRONMENT}" \
  --timeout=120s

# Smoke test
sleep 5
if [ "${ENVIRONMENT}" = "prod" ]; then
  URL="https://api.shopflow.io/health"
else
  URL="https://staging.shopflow.io/health"
fi

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$URL" || echo "000")
if [ "$HTTP_STATUS" = "200" ]; then
  echo "  ✓ Smoke test OK (HTTP 200)"
else
  echo "  ✗ Smoke test ÉCHOUÉ (HTTP $HTTP_STATUS)"
  exit 1
fi

echo ""
echo "✅ Rollback réussi vers la révision ${REVISION}"

# ─── Notification Slack ───────────────────────────────────────────────────────
if [ -n "${SLACK_WEBHOOK_URL:-}" ]; then
  curl -s -X POST "$SLACK_WEBHOOK_URL" \
    -H 'Content-Type: application/json' \
    -d "{
      \"text\": \"🔄 *Rollback ShopFlow effectué*\",
      \"attachments\": [{
        \"color\": \"warning\",
        \"fields\": [
          {\"title\": \"Environnement\", \"value\": \"${ENVIRONMENT}\", \"short\": true},
          {\"title\": \"Révision\", \"value\": \"${REVISION}\", \"short\": true},
          {\"title\": \"Opérateur\", \"value\": \"$(whoami)\", \"short\": true}
        ]
      }]
    }"
fi
