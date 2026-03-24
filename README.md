# ShopFlow API — Projet DevOps Complet

> Pipeline CI/CD complet : GitHub Actions → Docker → Kubernetes (EKS) via GitOps (ArgoCD)

## Architecture

```
Git push → GitHub Actions (CI) → Docker Hub → ArgoCD (CD) → EKS (Prod)
                ↓                                               ↓
          Tests + Trivy                              Prometheus + Grafana
```

## Stack technique

| Couche | Outil | Version |
|---|---|---|
| Application | Node.js + Express | 20 LTS |
| CI | GitHub Actions | — |
| Conteneurisation | Docker multi-stage | 24+ |
| IaC | Terraform | >= 1.6 |
| Orchestration | Kubernetes (AWS EKS) | 1.29 |
| CD / GitOps | ArgoCD | 2.9+ |
| Charts | Helm | 3.14+ |
| Métriques | Prometheus + Grafana | kube-prometheus-stack |
| Logs | Loki | 2.9+ |
| Alertes | Alertmanager → Slack | — |
| Secrets | HashiCorp Vault | 1.15+ |
| Sécurité | Trivy + Semgrep | — |

## Démarrage rapide

### Prérequis

```bash
# Outils nécessaires
terraform >= 1.6
kubectl >= 1.29
helm >= 3.14
argocd >= 2.9
aws-cli >= 2.0
node >= 20
```

### 1. Setup infrastructure

```bash
# Cloner le projet
git clone https://github.com/shopflow-org/shopflow-api.git
cd shopflow-api

# Déployer l'infra staging
chmod +x scripts/setup.sh
./scripts/setup.sh staging
```

### 2. Développement local

```bash
npm install
npm run dev          # Démarrer en mode développement
npm test             # Lancer les tests
npm run lint         # Vérifier le code

# Docker local
docker build -t shopflow-api:local .
docker run -p 3000:3000 shopflow-api:local
curl http://localhost:3000/health
```

### 3. Déploiement

Le déploiement est **entièrement automatisé** via la CI/CD.

```
git push origin main
  └─→ CI : Tests + Scan Trivy + Build image
      └─→ CD : Mise à jour GitOps repo
          └─→ ArgoCD détecte et déploie automatiquement
```

## Structure du projet

```
shopflow-api/
├── src/
│   ├── index.js              # Application principale
│   └── index.test.js         # Tests unitaires
├── .github/
│   └── workflows/
│       ├── ci.yml            # Pipeline CI (tests, scan, build)
│       └── cd.yml            # Pipeline CD (deploy staging → prod)
├── helm/
│   └── shopflow/             # Chart Helm
│       ├── Chart.yaml
│       ├── values.yaml       # Valeurs par défaut
│       ├── values-staging.yaml
│       ├── values-prod.yaml
│       └── templates/
│           └── deployment.yaml
├── terraform/
│   └── environments/
│       └── prod/
│           ├── main.tf       # VPC + EKS + RDS
│           └── variables.tf
├── k8s-gitops/
│   └── apps/
│       └── shopflow-app.yaml # Application ArgoCD
├── monitoring/
│   ├── prometheus/
│   │   └── rules.yaml        # Règles d'alerte SLO
│   ├── alertmanager/
│   │   └── alertmanager.yaml # Config alertes Slack + PagerDuty
│   └── grafana/
│       └── dashboards/
│           └── shopflow-api.json
├── scripts/
│   ├── setup.sh              # Setup initial complet
│   ├── rollback.sh           # Rollback rapide
│   └── smoke-tests.sh        # Tests post-déploiement
├── Dockerfile                # Build multi-stage
├── package.json
└── README.md
```

## SLO (Service Level Objectives)

| Objectif | Cible | Seuil warning | Seuil critical |
|---|---|---|---|
| Disponibilité | 99.9% | < 99.5% | < 99.0% |
| Latence P95 | < 200ms | > 150ms | > 500ms |
| Taux d'erreur | < 0.1% | > 0.05% | > 1.0% |
| MTTR | < 30 min | — | — |

## DORA Metrics cibles

| Métrique | Cible | Niveau |
|---|---|---|
| Deployment Frequency | 4×/jour | Elite |
| Lead Time for Changes | < 1 heure | Elite |
| Change Failure Rate | < 5% | Elite |
| MTTR | < 1 heure | Elite |

## Secrets

Les secrets ne sont **jamais** stockés dans Git. Ils sont gérés par HashiCorp Vault et injectés dans les pods via l'agent Vault Kubernetes.

```bash
# Variables GitHub Actions à configurer
DOCKER_USERNAME        # Docker Hub username
DOCKER_PASSWORD        # Docker Hub token
GITOPS_TOKEN           # GitHub PAT pour le repo GitOps
SLACK_WEBHOOK_URL      # Webhook Slack alertes
```

## Rollback

```bash
# Rollback rapide vers une révision précédente
./scripts/rollback.sh prod 42

# Via ArgoCD CLI
argocd app rollback shopflow-api-prod 42

# Via kubectl (Kubernetes)
kubectl rollout undo deployment/shopflow-api -n shopflow-prod
```

## Monitoring

| Dashboard | URL |
|---|---|
| ArgoCD | https://argocd.shopflow.io |
| Grafana | https://grafana.shopflow.io |
| Alertmanager | https://alertmanager.shopflow.io |

## Licences

Projet réalisé dans le cadre d'une évaluation professionnelle DevOps.
