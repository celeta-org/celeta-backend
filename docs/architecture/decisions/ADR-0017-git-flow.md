# ADR-0017 — Fluxo Git com branches por spec e PRs encadeados

**Status:** Aceita

**Contexto:** O desenvolvimento segue SDD, com specs independentes e tarefas pequenas. É preciso isolar o trabalho de cada spec e manter `main` estável até o fim do MVP.

**Decisão:** Usar `main` (release do MVP), `develop` (integração), `spec/<nome>` (uma por spec) e `feature/<tarefa>-<slug>` (uma por tarefa do backlog). PRs encadeados: feature → spec → develop → main. Automação por script PowerShell com GitHub CLI.

**Alternativas consideradas:**
- Git Flow tradicional com `release/` e `hotfix/`: mais cerimônia do que o MVP precisa.
- Trunk-based (commits direto em `develop`): não isola as specs entre si.

**Consequências:** Cada PR fica pequeno e revisável. A ordem de merge importa: uma spec só começa após a anterior estar mesclada em `develop`.
