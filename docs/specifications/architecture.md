# Spec: architecture

Fundação do backend: stack, camadas, configuração, banco, erros, testes e deploy. Base para todas as outras specs.

Referência completa: [backend.md](backend.md), seções 1 a 4, 6, 9 a 11.

## Objetivo

API REST da Celeta com monólito modular em camadas. Um único processo Node.js, um banco MySQL, um diretório privado de PDFs.

## Stack

| Área | Decisão |
|---|---|
| Runtime | Node.js LTS (`engines.node >= 20.6.0`, por causa de `--env-file`) |
| Módulos | JavaScript ES Modules (`"type": "module"`) |
| HTTP | Express 4 |
| Validação | Zod 3 |
| Banco | MySQL 8.0.16+ (InnoDB, utf8mb4, UTC) |
| Acesso | `mysql2/promise`, SQL parametrizado, sem ORM |
| IDs | UUID v4 via `crypto.randomUUID()`, `CHAR(36)` |
| Senhas | Argon2id (dependência a instalar na spec `auth`) |
| Testes | `node:test` (`npm test`) |

Fora do MVP: Supabase, n8n, Redis, filas, banco vetorial, microsserviços, storage externo, ORM.

## Camadas

Fluxo padrão:

```text
HTTP → Middleware → Zod → Controller → Use Case → Repository / Integration → Response
```

| Camada | Responsabilidade | Não faz |
|---|---|---|
| Routes | Endpoints, middlewares, controllers | Regra de negócio |
| Middlewares | Autenticação, autorização, erros | Regra de negócio |
| Schemas | Validação Zod de entrada e resposta da IA | Acesso ao banco |
| Controllers | HTTP ↔ caso de uso | Decidir classificação ou transição |
| Use Cases | Regras e transações | Depender de Express ou do provedor de IA |
| Repositories | SQL e mapeamento `snake_case` ↔ `camelCase` | Decidir regra |
| Integrations | Provedor de IA e sistema de arquivos | Regra de negócio |

Estrutura de referência em `src/`:

```text
src/
  app.js
  server.js
  config/
  database/
    pool.js
    migrations/
  modules/
    auth/ users/ candidate-profiles/ employer-profiles/
    jobs/ discovery/ resumes/ applications/ screening/
  integrations/
    ai/
    files/
  shared/
    errors/ middlewares/ utils/
tests/
```

Cada módulo contém só as camadas que usa.

## Configuração

Variáveis lidas e validadas por `src/config/env.js` (Zod). Falha de validação impede a subida do processo.

| Variável | Obrigatória | Padrão | Observação |
|---|---|---|---|
| `NODE_ENV` | não | `development` | `development`, `test` ou `production` |
| `PORT` | não | `3000` | `0` nos testes |
| `DB_HOST` | não | `127.0.0.1` | |
| `DB_PORT` | não | `3306` | |
| `DB_USER` | sim | | |
| `DB_PASSWORD` | sim | | Nunca no repositório |
| `DB_NAME` | sim | | `celeta_db` em desenvolvimento, `celeta_db_test` nos testes |
| `DB_CONNECTION_LIMIT` | não | `10` | `5` nos testes |

Arquivos de exemplo: `.env.example` e `.env.test.example`. Os reais (`.env`, `.env.test`) ficam fora do Git.

Variáveis previstas para as próximas specs (ainda não existem no código): chave e URL do provedor de IA, nome do modelo, timeout, limite de tamanho de PDF, diretório privado de arquivos, tempo de expiração da sessão, ambiente de cookie seguro.

## Banco de dados

- Engine InnoDB, charset `utf8mb4`, collation `utf8mb4_0900_ai_ci`.
- Datas em `DATETIME(3)` em UTC. Pool configurado com `timezone: 'Z'`.
- Esquema detalhado em [database.md](database.md).
- Migrations SQL versionadas em `src/database/migrations/`.
- Regra: consultas sempre parametrizadas.

## Erros e respostas

- Formato único de erro para toda a API (a definir na implementação, base em `src/shared/errors/AppError.js`).
- `AppError(statusCode, code, message)` é a classe base para erros de negócio.
- Códigos HTTP consistentes: 200/201 sucesso, 400 validação, 401 sem sessão, 403 sem permissão, 404 recurso inexistente ou fora do escopo do usuário, 409 conflito (ex.: candidatura duplicada), 503 indisponibilidade.
- Erros internos não vazam stack, SQL nem credenciais.

## Logs e observabilidade

- Logs com rotação e sem dados pessoais.
- Nunca registrar senha, cookie, token, currículo ou texto integral de currículo.
- Health check em `GET /api/v1/health`: responde `200` com `{ status: 'ok', database: 'up' }` ou `503` com `database: 'down'`. Não expõe credenciais.

## Segurança transversal

- HTTPS obrigatório no proxy reverso.
- Rate limit em autenticação, upload e IA.
- `x-powered-by` desligado.
- Limite de tamanho do corpo JSON: `100kb`.
- Secrets fora das imagens e do Git.
- Detalhes de autenticação e autorização em [auth.md](auth.md).

## Testes

- Ciclo Red → Green → Refactor.
- Banco MySQL de teste separado (`celeta_db_test`).
- Integração com a IA sempre simulada. Testes não chamam modelos reais.
- Prioridades: papel e propriedade, cadastro atômico, publicação, currículo e duplicidade, integridade entre candidatura, transições, anonimização, score, falha da IA, download protegido.
- Teste atual: `tests/health.test.js` cobre o health check e a ausência do cabeçalho `x-powered-by`.

## Deploy

Arquitetura alvo:

```text
Internet → Proxy reverso HTTPS (Caddy ou Nginx) → API Celeta (Node.js / Express)
                                                    ├─ MySQL 8 (rede interna)
                                                    ├─ Volume privado de PDFs
                                                    └─ Provedor de IA (HTTP, quando necessário)
MySQL → backup externo / segundo destino
```

- Uma VPS com Docker Compose: proxy, API e MySQL.
- MySQL sem porta exposta à internet. Só API e rede interna acessam.
- Volume de PDFs montado apenas na API. Nunca servido como estático.
- Backup periódico do MySQL e do volume de PDFs, com teste de restauração.
- Monitorar disco, memória e disponibilidade.
- Infraestrutura gratuita ou já disponível quando possível. Custo variável principal: provedor de IA.

## Plano de implementação

| Semana | Entrega |
|---|---|
| 1 — Fundação | API Express, Zod, erros, pool MySQL, migrations, autenticação, perfis, vagas, deploy inicial |
| 2 — Currículos, candidaturas e IA | Upload e extração de PDF, candidatura, busca, interpretação de pesquisa, contrato de triagem |
| 3 — Seleção e estabilização | Lista anonimizada, segunda fase, status, consulta do candidato, testes de falha, backup e deploy validados |

## Critérios de aceite do backend

1. Candidato e contratante cadastram-se, autenticam-se e acessam só seus recursos.
2. Contratante cria vaga como rascunho, revisa critérios e confirma antes de publicar.
3. Candidato pesquisa vagas, envia currículos e se candidata com uma versão específica.
4. Candidatura duplicada para a mesma vaga é bloqueada.
5. Triagem gera avaliação por critério, evidências, score e classificação validados.
6. Falha da IA não reprova automaticamente.
7. Contratante vê candidaturas anonimizadas na primeira fase.
8. Avanço para a segunda fase libera identidade e currículo por autorização do backend.
9. Contratante atualiza status e candidato consulta suas candidaturas.
10. Fluxos essenciais funcionam no deploy, com custo controlado e sem serviços pagos obrigatórios, exceto eventual provedor de IA.

## Fora do MVP

Chat, e-mails de notificação, pagamentos, integrações com portais externos, app nativo, entrevistas por vídeo, testes técnicos, analytics avançado, busca vetorial, treinamento de modelos, microsserviços, n8n, Redis e automação integral da decisão de contratação.

## Tarefas

Ver [backlog](../tasks/backlog.md): T01 a T03.
