# Runbook — ShopFlow API : Incidents de disponibilité

> Ce runbook décrit les étapes à suivre lors d'une alerte de disponibilité
> sur l'API ShopFlow en production.

---

## Alerte : `ShopFlowAvailabilityCritical`

**Sévérité** : 🔴 Critique  
**SLO impacté** : Disponibilité < 99%  
**Temps de résolution cible (MTTR)** : < 30 minutes

---

## Étape 1 — Évaluation initiale (2 min)

```bash
# 1. État des pods
kubectl get pods -n shopflow-prod -l app.kubernetes.io/name=shopflow-api

# 2. Logs récents
kubectl logs -n shopflow-prod -l app.kubernetes.io/name=shopflow-api \
  --since=5m --tail=100

# 3. Events Kubernetes
kubectl get events -n shopflow-prod --sort-by='.lastTimestamp' | tail -20

# 4. Statut ArgoCD
argocd app get shopflow-api-prod
```

---

## Étape 2 — Diagnostic

### Cas A : Pod(s) en CrashLoopBackOff

```bash
# Voir les logs du pod en crash
kubectl logs <pod-name> -n shopflow-prod --previous

# Décrire le pod pour voir les events
kubectl describe pod <pod-name> -n shopflow-prod
```

→ Si l'erreur est liée au code : **rollback immédiat** (voir Étape 3A)  
→ Si l'erreur est liée à la config : corriger le ConfigMap/Secret

### Cas B : Pods OK mais API inaccessible

```bash
# Vérifier le service
kubectl get svc -n shopflow-prod shopflow-api
kubectl describe svc -n shopflow-prod shopflow-api

# Vérifier l'ingress
kubectl get ingress -n shopflow-prod
kubectl describe ingress -n shopflow-prod shopflow-api

# Test direct depuis un pod debug
kubectl run debug --rm -it --image=curlimages/curl -- \
  curl http://shopflow-api.shopflow-prod.svc.cluster.local/health
```

### Cas C : Surcharge (CPU/Mémoire)

```bash
# Voir les ressources consommées
kubectl top pods -n shopflow-prod

# Scale manuel temporaire
kubectl scale deployment shopflow-api -n shopflow-prod --replicas=6
```

---

## Étape 3A — Rollback (si nécessaire)

```bash
# Option 1 : Rollback via script
./scripts/rollback.sh prod

# Option 2 : Rollback via ArgoCD
argocd app rollback shopflow-api-prod

# Option 3 : Rollback Kubernetes direct
kubectl rollout undo deployment/shopflow-api -n shopflow-prod

# Vérification post-rollback
kubectl rollout status deployment/shopflow-api -n shopflow-prod
curl https://api.shopflow.io/health
```

---

## Étape 4 — Validation post-incident

```bash
# Lancer les smoke tests complets
./scripts/smoke-tests.sh prod

# Vérifier les métriques Prometheus (5 min de fenêtre)
# → Grafana : https://grafana.shopflow.io/d/shopflow-api
```

---

## Étape 5 — Post-mortem (à compléter dans les 24h)

Template : https://wiki.shopflow.io/post-mortem-template

Sections obligatoires :
- Chronologie détaillée de l'incident
- Cause racine identifiée
- Impact utilisateur (nombre de requêtes en erreur, durée)
- Actions correctives (avec responsable et date)
- Amélioration du monitoring si détection tardive

---

## Contacts d'escalade

| Rôle | Contact |
|---|---|
| Astreinte DevOps | PagerDuty — équipe devops |
| Lead technique | Slack @tech-lead |
| Responsable produit | Slack @product |
