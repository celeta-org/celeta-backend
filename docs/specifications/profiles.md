# Spec: profiles

Perfil profissional do candidato e perfil do contratante.

Referência: [backend.md](backend.md), seções 5.1 e 7. Tabelas: [database.md](database.md), `candidate_profiles` e `employer_profiles`.

## Regras

- Um perfil por usuário (`UNIQUE(user_id)` nas duas tabelas).
- Perfil criado no cadastro (spec [auth](auth.md)). Não há criação avulsa.
- Só o dono edita o próprio perfil. Identidade vem da sessão.
- CNPJ opcional, somente dígitos, único quando informado (`CHAR(14)`).
- `skills_json` guarda competências declaradas em estrutura livre (JSON) para exibição e pesquisa.
- Dados de contato do candidato não aparecem para contratante antes da fase identificada (ver [applications](applications.md)).

## Endpoints

| Método e rota | Acesso | Finalidade |
|---|---|---|
| `GET /api/v1/candidate-profile/me` | Candidato | Consultar próprio perfil |
| `PATCH /api/v1/candidate-profile/me` | Candidato | Editar próprio perfil |
| `GET /api/v1/employer-profile/me` | Contratante | Consultar próprio perfil |
| `PATCH /api/v1/employer-profile/me` | Contratante | Editar próprio perfil |

## Campos

**Candidato** (`candidate_profiles`)

| Campo | Regra |
|---|---|
| `fullName` | Obrigatório, até 150 caracteres |
| `phone` | Opcional, até 30 |
| `professionalArea` | Opcional, até 120. Área de interesse |
| `skills` | Lista de competências declaradas |
| `careerObjectives` | Texto livre. Objetivos e momento de carreira |

**Contratante** (`employer_profiles`)

| Campo | Regra |
|---|---|
| `companyName` | Obrigatório, até 150 |
| `cnpj` | Opcional, 14 dígitos, único |
| `description` | Opcional |

## Testes

- Candidato não lê nem edita perfil de contratante, e vice-versa.
- `PATCH` não aceita campos fora da lista (ex.: `userId`, `role`).
- CNPJ com máscara ou tamanho errado é recusado.
- CNPJ duplicado é recusado.

## Tarefas

Ver [backlog](../tasks/backlog.md): T06 e T07.
