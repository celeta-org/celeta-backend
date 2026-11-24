import express from 'express';
import { healthRouter } from './modules/health/health.routes.js';

export function createApp() {
  const app = express();

  app.disable('x-powered-by');
  app.use(express.json({ limit: '100kb' }));

  app.use('/api/v1', healthRouter);

  return app;
}
