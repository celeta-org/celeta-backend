# Spec: screening

Triagem assistida por IA: contrato com o provedor, validação, cálculo de score e classificação, gravação e reprocessamento.

Referência: [backend.md](backend.md), seções 5.6 e 8. Tabelas: [database.md](database.md), `applications` e `application_criterion_evaluations`.

## Princípios

- IA é apoio. Não decide contratação, não altera `applications.status`, não avança fase.
- Falha, timeout, resposta malformada ou falta de evidência **nunca** resultam em `NOT_ELIGIBLE`. O resultado é `REVIEW_REQUIRED`.
- Backend calcula score e classificação. O modelo só retorna avaliação por critério.
- Toda resposta da IA é validada com Zod antes de persistir.

## Gatilho

- `POST /api/v1/applications/:applicationId/screening`. Acesso: dono da vaga ou rotina interna autorizada.
- Executa ou reexecuta explicitamente. **Não** roda ao abrir página.
- Uma chamada à IA por triagem. Sem agentes autônomos.

Estados: `screening_status` vai de `PENDING` para `PROCESSING`, depois `COMPLETED` ou `FAILED`. `screening_started_at` e `screening_completed_at` registram o período.

## Entrada enviada à IA

- Texto extraído do currículo, com **remoção de identificadores diretos** detectáveis (e-mail, telefone, endereço, documentos).
- Lista de critérios **confirmados** da vaga (`name`, `details`, `criterionType`).
- Limite de tamanho do texto. Texto acima do limite é truncado e a truncagem é registrada.
- Nunca enviar nome, e-mail ou telefone do candidato.

## Saída esperada da IA (Zod)

```text
{ criteria: [ { criterionId, result, evidenceText } ] }
```

- `result`: `MET`, `NOT_MET` ou `INSUFFICIENT_EVIDENCE`.
- `evidenceText`: trecho do currículo que sustenta o resultado. Pode ser vazio para `INSUFFICIENT_EVIDENCE`.
- `criterionId` deve pertencer à vaga. ID desconhecido é descartado e registrado como erro.
- Critério ausente na resposta vira `INSUFFICIENT_EVIDENCE`.

## Cálculo do backend

### Classificação

| Condição | Classificação |
|---|---|
| Resposta inválida, falha ou timeout | `REVIEW_REQUIRED` |
| Critério obrigatório com `INSUFFICIENT_EVIDENCE` | `REVIEW_REQUIRED` |
| Critério obrigatório `NOT_MET` sem pendência de evidência obrigatória | `NOT_ELIGIBLE` |
| Todos os critérios obrigatórios `MET` | `ELIGIBLE` |

Ordem de avaliação: primeiro falha e pendência (`REVIEW_REQUIRED`), depois reprovação explícita, por último elegibilidade.

### Score

```text
score = (soma dos pesos dos MET / soma dos pesos dos MET e NOT_MET) × 100
```

- `INSUFFICIENT_EVIDENCE` não entra no denominador.
- Se nenhum critério for conclusivo, `compatibility_score = NULL`.
- Score ordena resultados. Não substitui revisão humana.
- Faixa: `0.00` a `100.00`.

## Gravação

- Em uma transação: atualizar `applications` (`ai_classification`, `compatibility_score`, `ai_summary`, `screening_status`, datas) e gravar `application_criterion_evaluations` em lote.
- `UNIQUE(application_id, criterion_id)` impede avaliação duplicada. Reprocessamento substitui as avaliações anteriores na mesma transação.
- Composite FKs garantem que cada avaliação pertence à candidatura e a um critério da mesma vaga.

## Falhas e limites

| Falha | Tratamento |
|---|---|
| Sem chave ou sem cota | `screening_status = FAILED`, `ai_classification = REVIEW_REQUIRED` |
| Timeout | Mesmo tratamento, com timeout configurado |
| Resposta malformada | Mesmo tratamento. Resposta bruta não é persistida |
| Quantidade acima do lote | Processa até o limite configurado e informa o restante |
| Erro de provedor | Registrar só classe do erro, nunca dados pessoais |

Sistema segue funcionando sem IA: contratante revisa manualmente.

## Custo e controle

- Limite de tamanho de texto por chamada.
- Limite de candidaturas por lote.
- Timeout, limite de requisições e tratamento de cota excedida.
- Registrar consumo técnico (tokens, latência, classe de erro) sem gravar prompt com dados pessoais.

## Adaptador

- Isolado em `src/integrations/ai/`.
- URL, chave e modelo por variável de ambiente.
- Provedor trocável sem mudar casos de uso.
- Testes usam resposta simulada. Nenhum teste chama modelo real.

## Testes (prioridades 8 e 9 da spec de backend)

- Critério obrigatório `NOT_MET` gera `NOT_ELIGIBLE`.
- Critério obrigatório `INSUFFICIENT_EVIDENCE` gera `REVIEW_REQUIRED`.
- Todos obrigatórios `MET` geram `ELIGIBLE`.
- Falha, timeout e JSON malformado geram `REVIEW_REQUIRED`, nunca `NOT_ELIGIBLE`.
- Score ignora `INSUFFICIENT_EVIDENCE`.
- Score `NULL` quando nada é conclusivo.
- `criterionId` de outra vaga é descartado.
- Reprocessamento não duplica avaliações.
- IA não altera `applications.status` em nenhum caso.

## Tarefas

Ver [backlog](../tasks/backlog.md): T21 a T24.
