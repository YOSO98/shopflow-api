'use strict';

const request = require('supertest');
const app = require('../src/index');

describe('ShopFlow API', () => {
  describe('GET /health', () => {
    it('doit retourner status ok', async () => {
      const res = await request(app).get('/health');
      expect(res.statusCode).toBe(200);
      expect(res.body.status).toBe('ok');
      expect(res.body.version).toBeDefined();
      expect(res.body.timestamp).toBeDefined();
    });
  });

  describe('GET /ready', () => {
    it('doit retourner status ready', async () => {
      const res = await request(app).get('/ready');
      expect(res.statusCode).toBe(200);
      expect(res.body.status).toBe('ready');
    });
  });

  describe('GET /api/v1/products', () => {
    it('doit retourner la liste des produits', async () => {
      const res = await request(app).get('/api/v1/products');
      expect(res.statusCode).toBe(200);
      expect(Array.isArray(res.body.products)).toBe(true);
      expect(res.body.total).toBeGreaterThan(0);
    });
  });

  describe('GET /api/v1/products/:id', () => {
    it('doit retourner un produit par ID', async () => {
      const res = await request(app).get('/api/v1/products/1');
      expect(res.statusCode).toBe(200);
      expect(res.body.id).toBe(1);
    });

    it('doit retourner 400 pour un ID invalide', async () => {
      const res = await request(app).get('/api/v1/products/abc');
      expect(res.statusCode).toBe(400);
      expect(res.body.error).toBeDefined();
    });
  });

  describe('GET /metrics', () => {
    it('doit exposer les métriques Prometheus', async () => {
      const res = await request(app).get('/metrics');
      expect(res.statusCode).toBe(200);
      expect(res.text).toContain('http_requests_total');
    });
  });
});
