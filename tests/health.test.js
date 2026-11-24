import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { createApp } from '../src/app.js';
import { pool } from '../src/database/pool.js';

const server = createApp().listen(0);
await new Promise((resolve) => server.once('listening', resolve));
const baseUrl = `http://127.0.0.1:${server.address().port}`;

after(async () => {
  await new Promise((resolve) => server.close(resolve));
  await pool.end();
});

test('GET /api/v1/health responde 200 e confirma conexão com o banco', async () => {
  const response = await fetch(`${baseUrl}/api/v1/health`);
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.deepEqual(body, { status: 'ok', database: 'up' });
});

test('resposta não expõe cabeçalho x-powered-by', async () => {
  const response = await fetch(`${baseUrl}/api/v1/health`);

  assert.equal(response.headers.get('x-powered-by'), null);
});
