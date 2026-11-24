# Documentação da API Celeta

Índice da documentação do backend. Cada item aponta para o arquivo de referência.

## Produto

- [Escopo do produto](product/escopo-produto.md): visão, MVP, histórias de usuário, riscos e critérios de aceite.

## Especificações técnicas

Documento de referência completo: [backend.md](specifications/backend.md). Banco: [database.md](specifications/database.md).

Specs por área, na ordem de implementação:

| Spec | Arquivo | Conteúdo |
|---|---|---|
| architecture | [architecture.md](specifications/architecture.md) | Stack, camadas, configuração, erros, testes, deploy |
| auth | [auth.md](specifications/auth.md) | Cadastro, login, sessões, papéis |
| profiles | [profiles.md](specifications/profiles.md) | Perfis de candidato e contratante |
| jobs | [jobs.md](specifications/jobs.md) | Vagas, critérios, confirmação, publicação |
| discovery | [discovery.md](specifications/discovery.md) | Mural, busca e interpretação por IA |
| resumes | [resumes.md](specifications/resumes.md) | Upload privado de PDF, extração, download |
| applications | [applications.md](specifications/applications.md) | Candidatura, status, fase, anonimização |
| screening | [screening.md](specifications/screening.md) | Triagem por IA, score, classificação |
| banco | [database.md](specifications/database.md) | Esquema MySQL, dicionário, estado do dump |

## Tarefas

- [Backlog](tasks/backlog.md): tarefas T01 a T24 por spec, com status e ordem sugerida.

## Processo

- [Fluxo Git](process/git-flow.md): hierarquia de branches (`main` ← `develop` ← `spec/*` ← `feature/*`), comandos do `scripts/git/celeta-git.ps1` e regras de commit.
- [ADR-0017 — Git flow](architecture/decisions/ADR-0017-git-flow.md): decisão registrada sobre o fluxo Git.

## Pendências conhecidas

- DDL de referência: `celeta_database_v2.sql` na raiz. Migrations em T02 devem partir dele.
- Diferenças de esquema revisadas e aceitas em [database.md, seção 12](specifications/database.md).
- Dependências (Argon2id, extração de PDF, upload) só serão instaladas na implementação de cada spec.
