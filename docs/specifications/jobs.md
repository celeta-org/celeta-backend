# Spec: jobs

Criação, estruturação, confirmação de critérios, publicação e encerramento de vagas.

Referência: [backend.md](backend.md), seções 5.3, 5.4, 7 e 8. Tabelas: [database.md](database.md), `jobs` e `job_criteria`.

## Estados da vaga

| Estado | Significado |
|---|---|
| `DRAFT` | Rascunho. Padrão ao criar. Editável pelo dono |
| `PUBLISHED` | Visível no mural e na busca. Aceita candidaturas |
| `CLOSED` | Encerrada. Não aceita novas candidaturas |

Transições: `DRAFT → PUBLISHED → CLOSED`. Sem volta de `PUBLISHED` para `DRAFT` no MVP.

## Regras

- Só o contratante proprietário (via `employer_profile_id`) edita, confirma, publica ou encerra.
- IA pode sugerir requisitos e critérios. **Não** publica a vaga e **não** confirma critérios.
- Requisitos (`requirements_json`) são para exibição e filtros simples. Critérios (`job_criteria`) são avaliados individualmente na triagem.
- Confirmação: `criteria_confirmed_at` e `criteria_confirmed_by_user_id` são preenchidos juntos ou ficam nulos (regra no banco).
- Qualquer alteração de critérios depois da confirmação limpa os dois campos.
- Publicação exige: vaga válida, pelo menos um critério e confirmação. A regra de "pelo menos um critério" é aplicada no caso de uso.
- Publicação verifica a confirmação antes de mudar o status. No banco, `PUBLISHED` exige `criteria_confirmed_at`.
- Fechar a vaga define `closed_at`.

## Critérios

| Campo | Regra |
|---|---|
| `name` | Obrigatório, até 150 |
| `details` | Texto que orienta a avaliação |
| `criterionType` | `REQUIRED` ou `DESIRABLE` |
| `weight` | Número positivo. Padrão `1.00`. Limite de `10` no banco |
| `sortOrder` | Ordem de exibição, padrão `0` |

`criterionType` e `weight` não são sinônimos. O tipo diz se é obrigatório. O peso entra no cálculo do score (spec [screening](screening.md)).

## Endpoints

| Método e rota | Acesso | Finalidade |
|---|---|---|
| `POST /api/v1/jobs` | Contratante | Criar vaga em rascunho |
| `GET /api/v1/jobs` | Público / autenticado | Listar e pesquisar vagas publicadas |
| `GET /api/v1/jobs/:jobId` | Público (publicada) / dono (qualquer estado) | Consultar vaga |
| `PATCH /api/v1/jobs/:jobId` | Dono | Editar vaga |
| `POST /api/v1/jobs/:jobId/criteria/suggestions` | Dono | Gerar sugestões com IA (não grava como confirmadas) |
| `POST /api/v1/jobs/:jobId/criteria/confirm` | Dono | Confirmar critérios revisados |
| `POST /api/v1/jobs/:jobId/publish` | Dono | Publicar |
| `POST /api/v1/jobs/:jobId/close` | Dono | Encerrar |

Edição de critérios (adicionar, alterar, remover) faz parte de `PATCH` ou de rotas de critérios a definir na implementação. Qualquer delas limpa a confirmação.

## Fluxo de estruturação por IA

1. Contratante envia descrição livre.
2. Backend chama a IA (uma chamada) e recebe requisitos e critérios sugeridos.
3. Backend valida com Zod.
4. Sugestões são exibidas para revisão. Nada vira critério confirmado sem o contratante.
5. Contratante revisa, edita, confirma e publica.

Falha ou cota da IA: contratante cria critérios manualmente. Operação sem IA continua válida.

## Testes (prioridade 3 da spec de backend)

- Vaga nova nasce `DRAFT`.
- Publicar sem critérios é recusado.
- Publicar sem confirmação é recusado.
- Editar critério depois de confirmar limpa a confirmação.
- Vaga de outro contratante não é editada, confirmada, publicada nem encerrada.
- Vaga em `DRAFT` não aparece na listagem pública.
- Sugestão de IA não altera critérios confirmados.

## Tarefas

Ver [backlog](../tasks/backlog.md): T08 a T11.
