import { env } from './config/env.js';
import { createApp } from './app.js';
import { pool } from './database/pool.js';

const app = createApp();
const server = app.listen(env.PORT, () => {
  const address = server.address();
  console.log(`[celeta] API ouvindo na porta ${address.port} (${env.NODE_ENV})`);
});

function shutdown(signal) {
  console.log(`[celeta] ${signal} recebido, encerrando`);
  server.close(async () => {
    await pool.end();
    process.exit(0);
  });
}

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));
