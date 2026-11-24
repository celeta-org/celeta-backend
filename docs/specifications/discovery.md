# Spec: discovery

Mural de vagas, busca textual com filtros e interpretação opcional da consulta por IA.

Referência: [backend.md](backend.md), seções 5.9 e 7. Índice: `FULLTEXT` em `jobs.title` e `jobs.description` ([database.md](database.md)).

## Regras

- Busca só retorna vagas `PUBLISHED`.
- Pesquisa usa `FULLTEXT` do MySQL + filtros relacionais estruturados.
- Interpretação por IA é **opcional**: extrai intenção e filtros de linguagem natural.
- Sem chave ou com IA indisponível: busca textual convencional. Nunca erro para o usuário por causa da IA.
- Sem embeddings, banco vetorial ou modelo próprio no MVP.
- Mural personalizado usa o perfil do candidato e requisitos estruturados (`requirements_json`). Recomendação simples, sem modelo de ranking.
- Resultado da busca não expõe dados de candidatos.

## Endpoints

| Método e rota | Acesso | Finalidade |
|---|---|---|
| `GET /api/v1/jobs` | Público / autenticado | Listar e pesquisar vagas publicadas |
| `GET /api/v1/jobs?q=...&filters...` | Público / autenticado | Busca com filtros |
| Mural personalizado | Candidato | Vagas recomendadas pelo perfil (rota a fixar na implementação, ex.: `GET /api/v1/jobs?recommended=true`) |

## Fluxo da busca

1. Recebe `q` e filtros opcionais.
2. Se `q` existir e a IA estiver habilitada, pede interpretação com timeout curto.
3. Interpretação válida (Zod) vira palavras-chave e filtros. Inválida ou falha: usa `q` como está.
4. Executa `MATCH ... AGAINST` (modo natural) e filtros em SQL parametrizado.
5. Ordena por relevância e pagina.

## Filtros previstos

- Área profissional.
- Tipo de critério obrigatório (ex.: vagas com determinada competência).
- Paginação com limite máximo.

Filtros definitivos fecham na implementação. Nenhum filtro aceita SQL bruto.

## Limites

- Tamanho máximo de `q`.
- Limite de chamadas à IA por usuário (rate limit).
- Timeout da chamada de interpretação.

## Testes

- Vaga `DRAFT` ou `CLOSED` não aparece.
- Consulta literal encontra vaga pelo título ou descrição.
- Com IA desligada, busca funciona.
- Resposta da IA malformada cai na busca textual, sem erro.
- Filtro inválido é recusado pelo Zod.

## Tarefas

Ver [backlog](../tasks/backlog.md): T15 e T16.
