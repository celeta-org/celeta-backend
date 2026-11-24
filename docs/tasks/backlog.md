# Backlog

Tarefas do MVP, agrupadas por spec. Cada tarefa vira uma branch `feature/<tarefa>-<slug>` (ver [git-flow](../process/git-flow.md)).

Status: `TODO`, `DOING`, `DONE`.

## architecture

| Tarefa | Descrição | Status |
|---|---|---|
| T01 | Estrutura base, configuração (Zod), pool MySQL, erros, health check | DOING |
| T02 | Migrations SQL versionadas (esquema de [database.md](../specifications/database.md)) | TODO |
| T03 | Base de testes com banco de teste e `npm test` | TODO |

## auth

| Tarefa | Descrição | Status |
|---|---|---|
| T04 | Register, login, logout, me, sessões em `auth_sessions`, Argon2id | TODO |
| T05 | Middlewares de autenticação e autorização por papel | TODO |

## profiles

| Tarefa | Descrição | Status |
|---|---|---|
| T06 | `candidate-profile/me` (GET e PATCH) | TODO |
| T07 | `employer-profile/me` (GET e PATCH) | TODO |

## jobs

| Tarefa | Descrição | Status |
|---|---|---|
| T08 | Criar e editar vaga em rascunho, com dono | TODO |
| T09 | Critérios: criar, editar, remover, limpar confirmação | TODO |
| T10 | Sugestões de critérios por IA, confirmação, publicação, encerramento | TODO |
| T11 | Listagem e consulta pública de vagas publicadas | TODO |

## resumes

| Tarefa | Descrição | Status |
|---|---|---|
| T12 | Upload de PDF com validação (extensão, MIME, assinatura, tamanho) e armazenamento privado | TODO |
| T13 | Extração de texto e estados `PENDING`, `COMPLETED`, `FAILED` | TODO |
| T14 | Download protegido do PDF | TODO |

## discovery

| Tarefa | Descrição | Status |
|---|---|---|
| T15 | Busca `FULLTEXT` com filtros e mural personalizado | TODO |
| T16 | Interpretação opcional da consulta por IA, com fallback textual | TODO |

## applications

| Tarefa | Descrição | Status |
|---|---|---|
| T17 | Criar candidatura com regras de propriedade, vaga publicada e duplicidade | TODO |
| T18 | Listagem do contratante com anonimização por fase | TODO |
| T19 | Avanço e não seleção em transação (status + fase) | TODO |
| T20 | Consulta das próprias candidaturas pelo candidato | TODO |

## screening

| Tarefa | Descrição | Status |
|---|---|---|
| T21 | Adaptador de IA, contrato de entrada e saída, validação Zod | TODO |
| T22 | Cálculo de classificação e score pelo backend | TODO |
| T23 | Gravação em transação e reprocessamento explícito | TODO |
| T24 | Tratamento de falha, timeout, cota e resposta malformada | TODO |

## Ordem sugerida

1. architecture (T01 a T03)
2. auth e profiles
3. jobs
4. resumes e discovery
5. applications
6. screening

Specs seguem a ordem de merge: uma só começa depois da anterior estar em `develop` (ADR-0017).
