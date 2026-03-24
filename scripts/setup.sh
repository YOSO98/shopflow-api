#!/bin/bash
# ─── Script de setup du projet ShopFlow DevOps ───────────────────────────────
# Usage : ./scripts/setup.sh [staging|prod]
set -euo pipefail

ENVIRONMENT="${1:-staging}"
REGION="eu-west-1"

echo "╔══════════════════════════════════════════════╗"
echo "║   ShopFlow DevOps — Setup ${ENVIRONMENT}           ║"
echo "╚══════════════════════════════════════════════╝"

# ─── Vérification des prérequis ───────────────────────────────────────────────
echo ""
echo "▶ Vérification des outils requis..."
for tool in terraform kubectl helm argocd aws; do
  if ! command -v "$tool" &> /dev/null; then
    echo "  ✗ $tool non trouvé — installer avant de continuer"
    exit 1
  fi
  version=$("$tool" version --short 2>/dev/null || "$tool" --version 2>&1 | head -1)
  echo "  ✓ $tool — $version"
done

# ─── Infrastructure Terraform ─────────────────────────────────────────────────
echo ""
echo "▶ Déploiement infrastructure Terraform (${ENVIRONMENT})..."
cd terraform/environments/${ENVIRONMENT}

terraform init \
  -backend-config="bucket=shopflow-terraform-state" \
  -backend-config="key=environments/${ENVIRONMENT}/terraform.tfstate" \
  -backend-config="region=${REGION}"

terraform plan \
  -var="environment=${ENVIRONMENT}" \
  -out=tfplan \
  -detailed-exitcode || true

echo ""
read -p "Appliquer le plan Terraform ? [y/N] " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
  terraform apply tfplan
  echo "  ✓ Infrastructure créée"
else
  echo "  ⚠ Application annulée"
  exit 0
fi

cd ../../..

# ─── Configuration kubectl ────────────────────────────────────────────────────
echo ""
echo "▶ Configuration kubectl..."
aws eks update-kubeconfig \
  --name "shopflow-${ENVIRONMENT}" \
  --region "${REGION}"
echo "  ✓ kubeconfig mis à jour"

# ─── Déploiement ArgoCD ───────────────────────────────────────────────────────
echo ""
echo "▶ Installation ArgoCD..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "  Attente démarrage ArgoCD..."
kubectl wait --for=condition=available --timeout=300s \
  deployment/argocd-server -n argocd

echo "  ✓ ArgoCD opérationnel"

# ─── Déploiement stack monitoring ─────────────────────────────────────────────
echo ""
echo "▶ Installation stack monitoring (Prometheus + Grafana)..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set grafana.adminPassword="$(openssl rand -base64 16)" \
  --wait

# Appliquer les règles d'alerte
kubectl apply -f monitoring/prometheus/rules.yaml
kubectl apply -f monitoring/alertmanager/alertmanager.yaml

echo "  ✓ Monitoring opérationnel"

# ─── Application ArgoCD ───────────────────────────────────────────────────────
echo ""
echo "▶ Déploiement application via ArgoCD..."
kubectl apply -f k8s-gitops/apps/shopflow-app.yaml

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║   Setup terminé avec succès ! ✅              ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "Accès :"
echo "  ArgoCD  : kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  Grafana : kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80"
echo ""
echo "Commandes utiles :"
echo "  kubectl get pods -n shopflow-${ENVIRONMENT}   # État des pods"
echo "  argocd app get shopflow-api-${ENVIRONMENT}    # État ArgoCD"
