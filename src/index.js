'use strict';

const express = require('express');
const promClient = require('prom-client');
const winston = require('winston');

// ─── Logger ───────────────────────────────────────────────────────────────────
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [new winston.transports.Console()],
});

// ─── Prometheus metrics ────────────────────────────────────────────────────────
const register = new promClient.Registry();
promClient.collectDefaultMetrics({ register });

const httpRequestDurationMs = new promClient.Histogram({
  name: 'http_request_duration_ms',
  help: 'Durée des requêtes HTTP en millisecondes',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [5, 10, 25, 50, 100, 200, 500, 1000],
  registers: [register],
});

const httpRequestsTotal = new promClient.Counter({
  name: 'http_requests_total',
  help: 'Nombre total de requêtes HTTP',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register],
});

// ─── App ───────────────────────────────────────────────────────────────────────
const app = express();
app.use(express.json());

// Middleware métriques
app.use((req, res, next) => {
  const end = httpRequestDurationMs.startTimer();
  res.on('finish', () => {
    const labels = { method: req.method, route: req.path, status_code: res.statusCode };
    end(labels);
    httpRequestsTotal.inc(labels);
  });
  next();
});

// ─── Routes ────────────────────────────────────────────────────────────────────
app.get('/health', (req, res) => {
  res.json({ status: 'ok', version: process.env.APP_VERSION || '1.0.0', timestamp: new Date().toISOString() });
});

app.get('/ready', (req, res) => {
  // Vérification de la readiness (DB connection, etc.)
  res.json({ status: 'ready' });
});

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

app.get('/api/v1/products', (req, res) => {
  logger.info('GET /api/v1/products called', { correlationId: req.headers['x-correlation-id'] });
  res.json({
    products: [
      { id: 1, name: 'Produit A', price: 29.99 },
      { id: 2, name: 'Produit B', price: 49.99 },
    ],
    total: 2,
  });
});

app.get('/api/v1/products/:id', (req, res) => {
  const { id } = req.params;
  logger.info(`GET /api/v1/products/${id}`, { correlationId: req.headers['x-correlation-id'] });
  if (isNaN(id)) { return res.status(400).json({ error: 'ID invalide' }); }
  res.json({ id: parseInt(id), name: `Produit ${id}`, price: 29.99 });
});

// ─── Start ─────────────────────────────────────────────────────────────────────
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  logger.info(`ShopFlow API démarrée sur le port ${PORT}`, {
    environment: process.env.NODE_ENV || 'development',
    version: process.env.APP_VERSION || '1.0.0',
  });
});

module.exports = app;
