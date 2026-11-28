# Celeta — Backend

API REST da **Celeta**, plataforma de recrutamento com recomendações, busca de vagas e triagem assistida por IA em duas fases (fase 1 cega, fase 2 identificada).

> A IA sugere; o contratante decide. O backend é a autoridade sobre autenticação, autorização, regras de negócio e persistência.

Frontend: [celeta-org/celeta-frontend](https://github.com/celeta-org/celeta-frontend)

---

## Stack

| Área | Escolha |
| --- | --- |
| Runtime | Node.js LTS, JavaScript (ES Modules) |
| HTTP | Express |
| Validação | Zod (requisições e respostas da IA) |
| Banco | MySQL 8.0.16+ (InnoDB, utf8mb4, UTC) |
| Acesso ao banco | `mysql2/promise`, SQL parametrizado, sem ORM |
| IDs | UUID v4 via `crypto.randomUUID()` (`CHAR(36)`) |
| Autenticação | Própria: Argon2id + sessões no MySQL + cookie `HttpOnly` |
| Arquivos | Diretório privado persistente (PDFs fora do banco) |
| IA | Adaptador HTTP para provedor configurável |
| Busca | `FULLTEXT` do MySQL + filtros + interpretação opcional por IA |
| Deploy | VPS única com Docker Compose e proxy HTTPS (Caddy ou Nginx) |

**Fora do MVP:** Supabase, n8n, Redis, filas, banco vetorial, microsserviços, storage externo, ORM.

## Arquitetura

Monólito modular em camadas:

```
HTTP → Middleware → Zod → Controller → Use Case → Repository / Integration → Response
```

| Camada | Responsabilidade |
| --- | --- |
| Routes | Endpoints, middlewares e controllers. |
| Middlewares | Autenticação, autorização, erros. |
| Schemas | Validação Zod. |
| Controllers | HTTP → caso de uso. Sem regra de negócio. |
| Use Cases | Regras de negócio e transações. Sem Express. |
| Repositories | SQL e mapeamento `snake_case` ↔ `camelCase`. |
| Integrations | Provedor de IA e sistema de arquivos. |

```
src/
├─ app.js · server.js
├─ config/
├─ database/        # pool.js, migrations/
├─ modules/         # auth, users, candidate-profiles, employer-profiles,
│                   # jobs, discovery, resumes, applications, screening
├─ integrations/    # ai/, files/
└─ shared/          # errors/, middlewares/, utils/
tests/
```

## Modelo de dados

| Entidade | Tabela | Papel |
| --- | --- | --- |
| `User` | `users` | Conta, credenciais e papel (`CANDIDATE` / `EMPLOYER`). |
| `AuthSession` | `auth_sessions` | Sessão (somente SHA-256 do token). |
| `CandidateProfile` | `candidate_profiles` | Dados profissionais do candidato. |
| `EmployerProfile` | `employer_profiles` | Empresa/contratante. |
| `Job` | `jobs` | Vaga, requisitos (`requirements_json`), publicação e confirmação de critérios. |
| `JobCriterion` | `job_criteria` | Critério avaliado na triagem (`REQUIRED`/`DESIRABLE` + peso). |
| `Resume` | `resumes` | Metadados, `storage_key` privada e texto extraído. |
| `Application` | `applications` | Candidatura, status, fase, estado e resultado da triagem. |
| `ApplicationCriterionEvaluation` | `application_criterion_evaluations` | Resultado e evidência por critério. |

DDL: [`database/migrations/001_initial_schema.sql`](database/migrations/001_initial_schema.sql) (esquema v2.2).

### Estados

| Campo | Valores |
| --- | --- |
| `jobs.status` | `DRAFT` → `PUBLISHED` → `CLOSED` |
| `applications.status` (decisão humana) | `IN_REVIEW`, `ADVANCED`, `NOT_SELECTED` |
| `applications.selection_phase` (acesso) | `BLIND`, `IDENTIFIED` |
| `applications.screening_status` (técnico) | `PENDING`, `PROCESSING`, `COMPLETED`, `FAILED` |
| `applications.ai_classification` / `classification_override` | `ELIGIBLE`, `NOT_ELIGIBLE`, `REVIEW_REQUIRED` |
| `jobs.seniority` | `INTERN`, `JUNIOR`, `MID`, `SENIOR`, `LEAD` |
| `jobs.work_mode` | `ONSITE`, `HYBRID`, `REMOTE` |
| `job_criteria.origin` | `AI_SUGGESTED`, `AI_EDITED`, `EMPLOYER` |
| `candidate_profiles.career_stage` | `STUDENT`, `ENTRY_LEVEL`, `EXPERIENCED`, `CAREER_CHANGE` |
| `application_criterion_evaluations.result` | `MET`, `NOT_MET`, `INSUFFICIENT_EVIDENCE` |
| `resumes.extraction_status` | `PENDING`, `COMPLETED`, `FAILED` |

## Regras de negócio principais

- Cadastro cria usuário + perfil do papel em **uma transação**.
- Identidade vem sempre da sessão; nunca de `userId` enviado pelo cliente.
- Vaga nasce `DRAFT`. Publicar exige ≥ 1 critério e confirmação (`criteria_confirmed_at` + `criteria_confirmed_by_user_id`). Alterar critérios limpa a confirmação.
- Uma candidatura por candidato e vaga; o currículo precisa ser do candidato (FK composta).
- Avançar candidatura: `status = ADVANCED` e `selection_phase = IDENTIFIED` na mesma transação.
- Fase `BLIND`: a API não devolve nome, contato, perfil nem PDF ao contratante.
- A IA nunca altera `applications.status` nem reprova sozinha.
- Contratante pode contestar a classificação (`classification_override`) com justificativa obrigatória; a classificação da IA é preservada.
- Remover critério apaga suas avaliações, limpa a confirmação e exige nova triagem.
- Currículo é arquivado (`archived_at`), não apagado.
- Logout preenche `auth_sessions.revoked_at`.

### Triagem

1. Extrai texto do PDF no backend e remove identificadores diretos detectáveis.
2. Envia texto + critérios confirmados ao provedor; resposta JSON validada com Zod.
3. Critério ausente ou sem evidência → `INSUFFICIENT_EVIDENCE`.
4. Classificação calculada pelo backend:
   - `REVIEW_REQUIRED`: obrigatório sem evidência, resposta inválida ou falha;
   - `NOT_ELIGIBLE`: obrigatório `NOT_MET` sem pendência obrigatória;
   - `ELIGIBLE`: todos os obrigatórios `MET`.
5. Score:

```
score = Σ peso(MET) / Σ peso(MET + NOT_MET) × 100
```

`INSUFFICIENT_EVIDENCE` fica fora do denominador; sem avaliação conclusiva, score `NULL`. Falha, timeout ou resposta malformada → `REVIEW_REQUIRED`, nunca reprovação.

## API

Prefixo `/api/v1`, JSON em `camelCase`.

| Método e rota | Acesso | Finalidade |
| --- | --- | --- |
| `POST /auth/register` | Público | Criar usuário e perfil |
| `POST /auth/login` | Público | Iniciar sessão |
| `POST /auth/logout` | Autenticado | Encerrar sessão |
| `GET /auth/me` | Autenticado | Usuário e perfil atual |
| `GET/PATCH /candidate-profile/me` | Candidato | Próprio perfil |
| `GET/PATCH /employer-profile/me` | Contratante | Próprio perfil |
| `GET /jobs` | Público | Listar/pesquisar vagas publicadas |
| `POST /jobs` | Contratante | Criar rascunho |
| `GET /jobs/:jobId` | Público/dono | Detalhe |
| `GET /jobs/by-slug/:slug` | Público | Detalhe pelo slug |
| `PATCH /jobs/:jobId` | Dono | Editar |
| `POST /jobs/:jobId/criteria/suggestions` | Dono | Sugestões da IA |
| `POST /jobs/:jobId/criteria/confirm` | Dono | Confirmar critérios |
| `POST /jobs/:jobId/publish` | Dono | Publicar |
| `POST /jobs/:jobId/close` | Dono | Encerrar |
| `GET/POST /resumes` | Candidato | Listar/enviar currículos |
| `GET /resumes/:resumeId/file` | Autorizado | Baixar PDF |
| `DELETE /resumes/:resumeId` | Candidato | Arquivar currículo |
| `POST /jobs/:jobId/applications` | Candidato | Candidatar-se |
| `GET /applications/me` | Candidato | Minhas candidaturas |
| `GET /jobs/:jobId/applications` | Dono | Candidaturas (anonimizadas na fase `BLIND`) |
| `POST /applications/:applicationId/screening` | Dono | Executar/reexecutar triagem |
| `PATCH /applications/:applicationId/status` | Dono | Avançar ou não selecionar |
| `PATCH /applications/:applicationId/classification` | Dono | Contestar classificação |

## Como rodar

Requisitos: Node.js LTS, Docker e Docker Compose.

```bash
npm install
cp .env.example .env
docker compose up -d mysql
npm run migrate
npm run dev
```

### Variáveis de ambiente

| Variável | Descrição |
| --- | --- |
| `PORT` | Porta da API |
| `DATABASE_URL` | Conexão MySQL (UTC) |
| `SESSION_TTL_HOURS` | Validade da sessão |
| `COOKIE_SECURE` | `true` em produção |
| `UPLOAD_DIR` | Diretório privado dos PDFs |
| `UPLOAD_MAX_BYTES` | Tamanho máximo do PDF |
| `AI_PROVIDER_URL` / `AI_API_KEY` / `AI_MODEL` | Provedor de IA (opcional: sem chave, modo reduzido) |
| `AI_TIMEOUT_MS` | Timeout das chamadas de IA |

Sem chave de IA a API continua funcionando: critérios manuais, busca textual e revisão humana.

## Testes

TDD (Red → Green → Refactor), MySQL de teste e IA sempre simulada.

```bash
npm test
```

Prioridades: permissões e propriedade · cadastro atômico · confirmação e publicação · candidatura duplicada · integridade entre tabelas · transições de status/fase · anonimização · score e classificação · falhas da IA · download protegido.

## Segurança e privacidade

- Argon2id; token de sessão aleatório, somente hash no banco.
- HTTPS e cookie `Secure` em produção, `SameSite=Lax`.
- Autorização por papel **e** propriedade em todo caso de uso.
- PDFs fora da pasta pública; validação de extensão, MIME, assinatura e tamanho.
- Logs sem senha, token, cookie ou texto de currículo.
- Rate limit em autenticação, upload e IA.
- Secrets só em variáveis de ambiente; MySQL nunca exposto à internet.
- Retenção e exclusão compatíveis com a LGPD antes de dados reais.

## Deploy

```
Internet → Proxy HTTPS (Caddy/Nginx) → API Node.js → MySQL 8
                                           ├─ volume privado de PDFs
                                           └─ provedor de IA (sob demanda)
```

Backup periódico do MySQL e dos PDFs em um segundo destino, com teste de restauração.

## Cronograma (3 semanas)

1. **Fundação:** Express, Zod, erros, pool, migrations, autenticação, perfis, vagas e publicação.
2. **Currículos, candidaturas e IA:** upload e extração, candidatura, busca, sugestão de critérios, triagem.
3. **Seleção e estabilização:** fase cega/identificada, status, testes de falha e permissão, deploy e backup.

## Fluxo de trabalho

- Branch `main`; trabalho em `feat/*`, `fix/*`, `chore/*`.
- [Conventional Commits](https://www.conventionalcommits.org/pt-br/).
- Mudança de esquema só via migration versionada.

## Contribuidores

| Nome | GitHub |
| --- | --- |
| Marcos Danilo | [@MDanilo0610](https://github.com/MDanilo0610) |
| Rafael Araujo | [@R0f0el](https://github.com/R0f0el) |
| Renan Almeida de Araujo | [@renn1805](https://github.com/renn1805) |

---

Projeto acadêmico.
# Celeta — Backend

API REST da **Celeta**, plataforma de recrutamento com recomendações, busca de vagas e triagem assistida por IA em duas fases (fase 1 cega, fase 2 identificada).

> A IA sugere; o contratante decide. O backend é a autoridade sobre autenticação, autorização, regras de negócio e persistência.

Frontend: [celeta-org/celeta-frontend](https://github.com/celeta-org/celeta-frontend)

---

## Stack

| Área | Escolha |
| --- | --- |
| Runtime | Node.js LTS, JavaScript (ES Modules) |
| HTTP | Express |
| Validação | Zod (requisições e respostas da IA) |
| Banco | MySQL 8.0.16+ (InnoDB, utf8mb4, UTC) |
| Acesso ao banco | `mysql2/promise`, SQL parametrizado, sem ORM |
| IDs | UUID v4 via `crypto.randomUUID()` (`CHAR(36)`) |
| Autenticação | Própria: Argon2id + sessões no MySQL + cookie `HttpOnly` |
| Arquivos | Diretório privado persistente (PDFs fora do banco) |
| IA | Adaptador HTTP para provedor configurável |
| Busca | `FULLTEXT` do MySQL + filtros + interpretação opcional por IA |
| Deploy | VPS única com Docker Compose e proxy HTTPS (Caddy ou Nginx) |

**Fora do MVP:** Supabase, n8n, Redis, filas, banco vetorial, microsserviços, storage externo, ORM.

## Arquitetura

Monólito modular em camadas:

```
HTTP → Middleware → Zod → Controller → Use Case → Repository / Integration → Response
```

| Camada | Responsabilidade |
| --- | --- |
| Routes | Endpoints, middlewares e controllers. |
| Middlewares | Autenticação, autorização, erros. |
| Schemas | Validação Zod. |
| Controllers | HTTP → caso de uso. Sem regra de negócio. |
| Use Cases | Regras de negócio e transações. Sem Express. |
| Repositories | SQL e mapeamento `snake_case` ↔ `camelCase`. |
| Integrations | Provedor de IA e sistema de arquivos. |

```
src/
├─ app.js · server.js
├─ config/
├─ database/        # pool.js, migrations/
├─ modules/         # auth, users, candidate-profiles, employer-profiles,
│                   # jobs, discovery, resumes, applications, screening
├─ integrations/    # ai/, files/
└─ shared/          # errors/, middlewares/, utils/
tests/
```

## Modelo de dados

| Entidade | Tabela | Papel |
| --- | --- | --- |
| `User` | `users` | Conta, credenciais e papel (`CANDIDATE` / `EMPLOYER`). |
| `AuthSession` | `auth_sessions` | Sessão (somente SHA-256 do token). |
| `CandidateProfile` | `candidate_profiles` | Dados profissionais do candidato. |
| `EmployerProfile` | `employer_profiles` | Empresa/contratante. |
| `Job` | `jobs` | Vaga, requisitos (`requirements_json`), publicação e confirmação de critérios. |
| `JobCriterion` | `job_criteria` | Critério avaliado na triagem (`REQUIRED`/`DESIRABLE` + peso). |
| `Resume` | `resumes` | Metadados, `storage_key` privada e texto extraído. |
| `Application` | `applications` | Candidatura, status, fase, estado e resultado da triagem. |
| `ApplicationCriterionEvaluation` | `application_criterion_evaluations` | Resultado e evidência por critério. |

DDL: `database/migrations` (baseado em `celeta_database_v2.sql`).

### Estados

| Campo | Valores |
| --- | --- |
| `jobs.status` | `DRAFT` → `PUBLISHED` → `CLOSED` |
| `applications.status` (decisão humana) | `IN_REVIEW`, `ADVANCED`, `NOT_SELECTED` |
| `applications.selection_phase` (acesso) | `BLIND`, `IDENTIFIED` |
| `applications.screening_status` (técnico) | `PENDING`, `PROCESSING`, `COMPLETED`, `FAILED` |
| `applications.ai_classification` | `ELIGIBLE`, `NOT_ELIGIBLE`, `REVIEW_REQUIRED` |
| `application_criterion_evaluations.result` | `MET`, `NOT_MET`, `INSUFFICIENT_EVIDENCE` |
| `resumes.extraction_status` | `PENDING`, `COMPLETED`, `FAILED` |

## Regras de negócio principais

- Cadastro cria usuário + perfil do papel em **uma transação**.
- Identidade vem sempre da sessão; nunca de `userId` enviado pelo cliente.
- Vaga nasce `DRAFT`. Publicar exige ≥ 1 critério e confirmação (`criteria_confirmed_at` + `criteria_confirmed_by_user_id`). Alterar critérios limpa a confirmação.
- Uma candidatura por candidato e vaga; o currículo precisa ser do candidato (FK composta).
- Avançar candidatura: `status = ADVANCED` e `selection_phase = IDENTIFIED` na mesma transação.
- Fase `BLIND`: a API não devolve nome, contato, perfil nem PDF ao contratante.
- A IA nunca altera `applications.status` nem reprova sozinha.

### Triagem

1. Extrai texto do PDF no backend e remove identificadores diretos detectáveis.
2. Envia texto + critérios confirmados ao provedor; resposta JSON validada com Zod.
3. Critério ausente ou sem evidência → `INSUFFICIENT_EVIDENCE`.
4. Classificação calculada pelo backend:
   - `REVIEW_REQUIRED`: obrigatório sem evidência, resposta inválida ou falha;
   - `NOT_ELIGIBLE`: obrigatório `NOT_MET` sem pendência obrigatória;
   - `ELIGIBLE`: todos os obrigatórios `MET`.
5. Score:

```
score = Σ peso(MET) / Σ peso(MET + NOT_MET) × 100
```

`INSUFFICIENT_EVIDENCE` fica fora do denominador; sem avaliação conclusiva, score `NULL`. Falha, timeout ou resposta malformada → `REVIEW_REQUIRED`, nunca reprovação.

## API

Prefixo `/api/v1`, JSON em `camelCase`.

| Método e rota | Acesso | Finalidade |
| --- | --- | --- |
| `POST /auth/register` | Público | Criar usuário e perfil |
| `POST /auth/login` | Público | Iniciar sessão |
| `POST /auth/logout` | Autenticado | Encerrar sessão |
| `GET /auth/me` | Autenticado | Usuário e perfil atual |
| `GET/PATCH /candidate-profile/me` | Candidato | Próprio perfil |
| `GET/PATCH /employer-profile/me` | Contratante | Próprio perfil |
| `GET /jobs` | Público | Listar/pesquisar vagas publicadas |
| `POST /jobs` | Contratante | Criar rascunho |
| `GET /jobs/:jobId` | Público/dono | Detalhe |
| `PATCH /jobs/:jobId` | Dono | Editar |
| `POST /jobs/:jobId/criteria/suggestions` | Dono | Sugestões da IA |
| `POST /jobs/:jobId/criteria/confirm` | Dono | Confirmar critérios |
| `POST /jobs/:jobId/publish` | Dono | Publicar |
| `POST /jobs/:jobId/close` | Dono | Encerrar |
| `GET/POST /resumes` | Candidato | Listar/enviar currículos |
| `GET /resumes/:resumeId/file` | Autorizado | Baixar PDF |
| `POST /jobs/:jobId/applications` | Candidato | Candidatar-se |
| `GET /applications/me` | Candidato | Minhas candidaturas |
| `GET /jobs/:jobId/applications` | Dono | Candidaturas (anonimizadas na fase `BLIND`) |
| `POST /applications/:applicationId/screening` | Dono | Executar/reexecutar triagem |
| `PATCH /applications/:applicationId/status` | Dono | Avançar ou não selecionar |

## Como rodar

Requisitos: Node.js LTS, Docker e Docker Compose.

```bash
npm install
cp .env.example .env
docker compose up -d mysql
npm run migrate
npm run dev
```

### Variáveis de ambiente

| Variável | Descrição |
| --- | --- |
| `PORT` | Porta da API |
| `DATABASE_URL` | Conexão MySQL (UTC) |
| `SESSION_TTL_HOURS` | Validade da sessão |
| `COOKIE_SECURE` | `true` em produção |
| `UPLOAD_DIR` | Diretório privado dos PDFs |
| `UPLOAD_MAX_BYTES` | Tamanho máximo do PDF |
| `AI_PROVIDER_URL` / `AI_API_KEY` / `AI_MODEL` | Provedor de IA (opcional: sem chave, modo reduzido) |
| `AI_TIMEOUT_MS` | Timeout das chamadas de IA |

Sem chave de IA a API continua funcionando: critérios manuais, busca textual e revisão humana.

## Testes

TDD (Red → Green → Refactor), MySQL de teste e IA sempre simulada.

```bash
npm test
```

Prioridades: permissões e propriedade · cadastro atômico · confirmação e publicação · candidatura duplicada · integridade entre tabelas · transições de status/fase · anonimização · score e classificação · falhas da IA · download protegido.

## Segurança e privacidade

- Argon2id; token de sessão aleatório, somente hash no banco.
- HTTPS e cookie `Secure` em produção, `SameSite=Lax`.
- Autorização por papel **e** propriedade em todo caso de uso.
- PDFs fora da pasta pública; validação de extensão, MIME, assinatura e tamanho.
- Logs sem senha, token, cookie ou texto de currículo.
- Rate limit em autenticação, upload e IA.
- Secrets só em variáveis de ambiente; MySQL nunca exposto à internet.
- Retenção e exclusão compatíveis com a LGPD antes de dados reais.

## Deploy

```
Internet → Proxy HTTPS (Caddy/Nginx) → API Node.js → MySQL 8
                                           ├─ volume privado de PDFs
                                           └─ provedor de IA (sob demanda)
```

Backup periódico do MySQL e dos PDFs em um segundo destino, com teste de restauração.

## Cronograma (3 semanas)

1. **Fundação:** Express, Zod, erros, pool, migrations, autenticação, perfis, vagas e publicação.
2. **Currículos, candidaturas e IA:** upload e extração, candidatura, busca, sugestão de critérios, triagem.
3. **Seleção e estabilização:** fase cega/identificada, status, testes de falha e permissão, deploy e backup.

## Fluxo de trabalho

- Branch `main`; trabalho em `feat/*`, `fix/*`, `chore/*`.
- [Conventional Commits](https://www.conventionalcommits.org/pt-br/).
- Mudança de esquema só via migration versionada.

## Contribuidores

| Nome | GitHub |
| --- | --- |
| Marcos Danilo | [@MDanilo0610](https://github.com/MDanilo0610) |
| Rafael Araujo | [@R0f0el](https://github.com/R0f0el) |
| Renan Almeida de Araujo | [@renn1805](https://github.com/renn1805) |

---

Projeto acadêmico.
