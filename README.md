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
2. Gera o texto sanitizado (`resumes.sanitized_text`), que é o único enviado ao provedor e o único exibido ao contratante na fase `BLIND`; resposta JSON validada com Zod.
   Cada critério volta com resultado, justificativa (`rationale`) e evidência; não existe resultado "parcial".
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

**Padrões do contrato** (válidos para backend e frontend):

- Prefixo `/api/v1`. Rotas e recursos em português; `{vagaId}`, `{candidaturaId}`, `{curriculoId}` são UUID; `{slug}` é texto.
- Corpo JSON em `camelCase` com nomes em português (ex.: `vagaId`, `curriculoId`, `justificativa`). Valores de estado continuam os do banco, em inglês e `UPPER_SNAKE_CASE` (`DRAFT`, `BLIND`, `ELIGIBLE`…); a interface traduz.
- Rotas `/candidato/*` e `/contratante/*` agem sempre sobre o usuário da sessão; nunca recebem `userId`.
- Paginação: `{ items, nextCursor }` com `?cursor=&limite=`.
- Erro: `{ code, message, details? }`. HTTP: 400/422 validação, 401 sessão, 403 permissão, 404, 409 duplicidade ou estado inválido, 429 limite de IA, 503 IA indisponível.
- IA síncrona no MVP, com timeout. Não existe recurso de operação assíncrona (`/jobs/{id}`); o andamento da triagem é lido em `screeningStatus` da candidatura (polling na lista).
- Arquivos: o PDF nunca é servido direto; as rotas `.../url` devolvem URL assinada de curta duração.
- `PATCH .../status` e o detalhe da candidatura devolvem `transicoesPermitidas`.

| Método e rota | Acesso | Finalidade |
| --- | --- | --- |
| `POST /auth/cadastro` | Público | Criar usuário e perfil do papel |
| `POST /auth/login` | Público | Iniciar sessão (cookie HttpOnly) |
| `POST /auth/logout` | Autenticado | Revogar sessão |
| `GET /auth/sessao` | Autenticado | Usuário, papel e perfil atual |
| `GET/PATCH /candidato/perfil` | Candidato | Consultar/editar próprio perfil |
| `GET/POST /candidato/curriculos` | Candidato | Listar/enviar currículos (multipart) |
| `DELETE /candidato/curriculos/{curriculoId}` | Candidato | Arquivar currículo (exclusão lógica) |
| `GET /candidato/curriculos/{curriculoId}/url` | Candidato | URL assinada de curta duração |
| `GET /candidato/mural` | Candidato | Vagas recomendadas (paginado, motivos opcionais) |
| `GET /candidato/candidaturas` | Candidato | Minhas candidaturas |
| `GET /candidato/candidaturas/{candidaturaId}` | Candidato | Detalhe e linha do tempo do status |
| `POST /candidato/candidaturas` | Candidato | Candidatar-se: vagaId + curriculoId ou arquivo |
| `GET /vagas` | Público | Listar vagas publicadas (filtros, q textual) |
| `GET /vagas/busca?q=` | Público | Busca em linguagem natural; retorna interpretação |
| `GET /vagas/{slug}` | Público | Detalhe público da vaga |
| `GET/PATCH /contratante/perfil` | Contratante | Consultar/editar próprio perfil |
| `GET/POST /contratante/vagas` | Contratante | Listar próprias vagas / criar rascunho |
| `GET/PATCH /contratante/vagas/{vagaId}` | Dono | Obter/editar vaga |
| `POST /contratante/vagas/{vagaId}/criterios/sugestoes` | Dono | Sugestões da IA (síncrono, com timeout) |
| `PUT /contratante/vagas/{vagaId}/criterios` | Dono | Salvar lista revisada (limpa confirmação) |
| `POST /contratante/vagas/{vagaId}/criterios/confirmar` | Dono | Confirmar critérios |
| `POST /contratante/vagas/{vagaId}/publicar` | Dono | Publicar |
| `POST /contratante/vagas/{vagaId}/encerrar` | Dono | Encerrar |
| `GET /contratante/vagas/{vagaId}/candidaturas` | Dono | Lista com ranking; anônima na fase BLIND |
| `GET /contratante/vagas/{vagaId}/candidaturas/{candidaturaId}` | Dono | Detalhe (anônimo ou identificado) |
| `GET /contratante/vagas/{vagaId}/candidaturas/{candidaturaId}/curriculo/url` | Dono (fase IDENTIFIED) | URL assinada do PDF |
| `POST /contratante/vagas/{vagaId}/candidaturas/{candidaturaId}/triagem` | Dono | Executar/reexecutar triagem |
| `PATCH /contratante/vagas/{vagaId}/candidaturas/{candidaturaId}/classificacao` | Dono | Contestar classificação (justificativa obrigatória) |
| `POST /contratante/vagas/{vagaId}/candidaturas/{candidaturaId}/avancar` | Dono | Avançar para a fase 2 (ADVANCED + IDENTIFIED) |
| `PATCH /contratante/vagas/{vagaId}/candidaturas/{candidaturaId}/status` | Dono | Não selecionar; devolve transicoesPermitidas |

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
| `UPLOAD_MAX_BYTES` | Tamanho máximo do PDF (MVP: `5242880`, 5 MB) |
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
