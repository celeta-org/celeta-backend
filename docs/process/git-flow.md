# Fluxo Git — Celeta

## Hierarquia de branches

```text
main                          versão do MVP (recebe só o release final)
 └─ develop                   integração contínua
     └─ spec/<nome>           uma branch por spec (ex.: spec/auth)
         └─ feature/<tarefa>-<slug>   uma branch por tarefa do backlog (ex.: feature/T02-erro-comum)
```

Specs válidas: `architecture`, `auth`, `profiles`, `jobs`, `discovery`, `resumes`, `applications`, `screening`.

## Pull requests encadeados

1. `feature/*` → `spec/*` (feito por `feature-finish`).
2. Mesclar no GitHub. Só então começar a próxima feature da mesma spec.
3. `spec/*` → `develop` (feito por `spec-finish`).
4. Ao final do MVP, `develop` → `main` (feito por `mvp-release`).

Nenhum PR é mesclado sem testes verdes (`npm test`).

## Regras

- Commits no padrão `tipo(escopo): descrição`. Tipos: feat, fix, docs, test, chore, refactor.
- Uma tarefa do backlog = uma feature branch.
- Nunca commitar `.env`, `.env.test`, `node_modules` ou `storage/` (já no `.gitignore`).
- Nunca commitar direto em `main`, `develop` ou `spec/*`.
- Não reescrever histórico de branches publicadas (sem `push --force`).

## Comandos

Script: `scripts/git/celeta-git.ps1`. Rodar na raiz do repositório.

| Comando | Faz |
|---|---|
| `bootstrap` | Cria `main` e `develop`, publica os dois. Uso único. |
| `spec-start -Spec auth` | Cria `spec/auth` a partir de `develop`. |
| `feature-start -Spec auth -Task T02 -Slug erro-comum` | Cria a feature a partir da spec. |
| `feature-finish -Message "feat(T02): erro comum"` | Commita, publica e abre PR para a spec. |
| `spec-finish` | Publica a spec e abre PR para `develop`. |
| `mvp-release` | Publica `develop` e abre PR para `main`. |

Pré-requisitos: Git 2.28+, GitHub CLI (`gh auth login`) e remoto `origin` configurado.

Se o PowerShell bloquear o script, rode uma vez:
`Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`
