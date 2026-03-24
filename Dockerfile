# ─── Stage 1 : Installation des dépendances ───────────────────────────────────
FROM node:20-alpine AS deps

WORKDIR /app

# Copier uniquement les fichiers de dépendances pour profiter du cache Docker
COPY package*.json ./

# Installer uniquement les dépendances de production
RUN npm ci --only=production && \
    npm cache clean --force

# ─── Stage 2 : Image de production finale ─────────────────────────────────────
FROM node:20-alpine AS production

# Metadonnées OCI
LABEL org.opencontainers.image.title="ShopFlow API"
LABEL org.opencontainers.image.description="API e-commerce ShopFlow"
LABEL org.opencontainers.image.vendor="ShopFlow Inc."

# Mises à jour de sécurité de l'OS
RUN apk update && apk upgrade --no-cache && \
    apk add --no-cache wget && \
    rm -rf /var/cache/apk/*

# Créer un utilisateur non-root (sécurité)
RUN addgroup -S appgroup && \
    adduser -S appuser -G appgroup -u 1001

WORKDIR /app

# Copier les dépendances depuis le stage précédent
COPY --from=deps --chown=appuser:appgroup /app/node_modules ./node_modules

# Copier le code source
COPY --chown=appuser:appgroup src/ ./src/
COPY --chown=appuser:appgroup package.json ./

# Basculer vers l'utilisateur non-root
USER appuser

# Exposer le port applicatif
EXPOSE 3000

# Health check intégré
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD wget -qO- http://localhost:3000/health || exit 1

# Commande de démarrage
CMD ["node", "src/index.js"]
