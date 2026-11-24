import { Router } from 'express';
import { pingDatabase } from '../../database/pool.js';

export const healthRouter = Router();

healthRouter.get('/health', async (_req, res) => {
  try {
    const ok = await pingDatabase();
    if (!ok) {
      return res.status(503).json({ status: 'error', database: 'down' });
    }
    return res.status(200).json({ status: 'ok', database: 'up' });
  } catch (error) {
    // Registra só a classe do erro, nunca credenciais ou dados pessoais.
    console.error('[health] falha ao consultar o banco:', error.code ?? error.name);
    return res.status(503).json({ status: 'error', database: 'down' });
  }
});
