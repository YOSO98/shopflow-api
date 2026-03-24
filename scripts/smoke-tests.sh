#!/bin/bash
# ─── Smoke Tests ShopFlow API ─────────────────────────────────────────────────
# Usage : ./scripts/smoke-tests.sh [staging|prod]
set -euo pipefail

ENVIRONMENT="${1:-staging}"
PASS=0
FAIL=0

if [ "$ENVIRONMENT" = "prod" ]; then
  BASE_URL="https://api.shopflow.io"
else
  BASE_URL="https://staging.shopflow.io"
fi

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

pass() { echo -e "  ${GREEN}✓${NC} $1"; PASS=$((PASS+1)); }
fail() { echo -e "  ${RED}✗${NC} $1"; FAIL=$((FAIL+1)); }

echo ""
echo "▶ Smoke tests ShopFlow API (${ENVIRONMENT})"
echo "  Base URL : ${BASE_URL}"
echo ""

# Test 1 — Health check
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/health")
[ "$STATUS" = "200" ] && pass "GET /health → 200" || fail "GET /health → $STATUS"

# Test 2 — Ready check
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/ready")
[ "$STATUS" = "200" ] && pass "GET /ready → 200" || fail "GET /ready → $STATUS"

# Test 3 — Endpoint produits
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/api/v1/products")
[ "$STATUS" = "200" ] && pass "GET /api/v1/products → 200" || fail "GET /api/v1/products → $STATUS"

# Test 4 — Latence < 500ms
LATENCY=$(curl -s -o /dev/null -w "%{time_total}" "${BASE_URL}/api/v1/products")
LATENCY_MS=$(echo "$LATENCY * 1000" | bc | cut -d'.' -f1)
[ "$LATENCY_MS" -lt 500 ] && pass "Latence ${LATENCY_MS}ms < 500ms" || fail "Latence ${LATENCY_MS}ms ≥ 500ms"

# Test 5 — Métriques Prometheus exposées
METRICS=$(curl -s "${BASE_URL}/metrics" | grep -c "http_requests_total" || true)
[ "$METRICS" -gt 0 ] && pass "Métriques Prometheus exposées" || fail "Métriques Prometheus manquantes"

# Test 6 — Headers de sécurité
HEADERS=$(curl -s -I "${BASE_URL}/api/v1/products")
echo "$HEADERS" | grep -qi "x-content-type-options" && pass "Header X-Content-Type-Options présent" || fail "Header X-Content-Type-Options absent"

# ─── Résultat ─────────────────────────────────────────────────────────────────
echo ""
echo "Résultat : ${PASS} succès / $((PASS+FAIL)) tests"

if [ "$FAIL" -gt 0 ]; then
  echo -e "${RED}✗ ${FAIL} test(s) échoué(s)${NC}"
  exit 1
fi

echo -e "${GREEN}✅ Tous les smoke tests passent${NC}"
