# Spec: applications

Candidatura do candidato a uma vaga, status de negócio, fase de acesso e anonimização.

Referência: [backend.md](backend.md), seções 5.5, 5.7, 5.8, 7 e 13. Tabelas: [database.md](database.md), `applications` e `application_criterion_evaluations`.

## Regras

- Candidatura só para vaga `PUBLISHED`.
- Candidatura só com currículo do próprio candidato autenticado.
- Uma candidatura por candidato e vaga (`UNIQUE(job_id, candidate_profile_id)`).
- FK composta `(resume_id, candidate_profile_id)` garante que o currículo é do candidato da candidatura.
- Criação verifica: propriedade do currículo, vaga publicada, duplicidade. Tudo antes de inserir.
- Nasce com `status = IN_REVIEW`, `selection_phase = BLIND`, `screening_status = PENDING`.

### Campos independentes

| Campo | Dono | Significado |
|---|---|---|
| `screening_status` | Sistema | Estado técnico da análise de IA |
| `ai_classification` | IA + backend | Recomendação inicial (`ELIGIBLE`, `NOT_ELIGIBLE`, `REVIEW_REQUIRED`) |
| `status` | Contratante | Decisão humana: `IN_REVIEW`, `ADVANCED`, `NOT_SELECTED` |
| `selection_phase` | Sistema, por ação do contratante | Controla o que o contratante pode ver: `BLIND` ou `IDENTIFIED` |

A classificação da IA nunca é o status da candidatura. A IA não altera `status` nem decide contratação.

## Transições

| Ação | `status` | `selection_phase` |
|---|---|---|
| Criar candidatura | `IN_REVIEW` | `BLIND` |
| Avançar | `ADVANCED` | `IDENTIFIED` (mesma transação) |
| Não selecionar na primeira fase | `NOT_SELECTED` | `BLIND` |
| Não selecionar depois da identificação | `NOT_SELECTED` | `IDENTIFIED` |

Avançar sempre atualiza os dois campos na mesma transação.

## Anonimização (regra crítica)

A primeira fase é cega **na API**, não só na interface.

- Listagem da vaga com `selection_phase = BLIND` não retorna nome, contato, perfil, currículo nem acesso ao PDF.
- Identidade só para o contratante depois da transição para `IDENTIFIED`.
- Candidato sempre consulta os próprios dados e o status da própria candidatura.
- Anonimização não é absoluta: o texto do currículo pode dar pistas indiretas. Documentar isso ao contratante.

## Endpoints

| Método e rota | Acesso | Finalidade |
|---|---|---|
| `POST /api/v1/jobs/:jobId/applications` | Candidato | Criar candidatura com currículo escolhido |
| `GET /api/v1/applications/me` | Candidato | Listar próprias candidaturas e status |
| `GET /api/v1/jobs/:jobId/applications` | Dono da vaga | Listar com anonimização conforme a fase |
| `PATCH /api/v1/applications/:applicationId/status` | Dono da vaga | Avançar ou não selecionar |

Triagem por IA (`POST /api/v1/applications/:applicationId/screening`) está na spec [screening](screening.md).

## Listagem do contratante

- `BLIND`: id interno, `ai_classification`, `compatibility_score`, `ai_summary`, status de triagem. Sem identidade.
- `IDENTIFIED`: inclui nome, contato, perfil e acesso ao currículo.
- Ordenação padrão: `compatibility_score` decrescente (apoio à revisão, não decisão).
- Paginação obrigatória.

## Erros esperados

| Situação | Código |
|---|---|
| Vaga não publicada | 409 |
| Currículo de outro candidato | 404 (não revelar que existe) |
| Candidatura duplicada | 409 |
| Avançar candidatura de vaga alheia | 404 |

## Testes (prioridades 4, 5, 6 e 7 da spec de backend)

- Candidatura duplicada é bloqueada.
- Currículo de outro candidato é recusado.
- Vaga não publicada é recusada.
- Composite FK impede currículo de outro candidato mesmo com acesso direto ao banco.
- Avanço muda `status` e `selection_phase` juntos. Falha no meio não deixa estado parcial.
- Lista `BLIND` não contém nenhum campo identificável.
- Contratante de outra vaga não lista candidaturas.
- Candidato não vê candidatura de outro candidato.

## Tarefas

Ver [backlog](../tasks/backlog.md): T17 a T20.
