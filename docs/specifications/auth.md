# Spec: auth

Cadastro, login, sessões e autorização por papel. Autenticação própria, sem Supabase Auth.

Referência: [backend.md](backend.md), seções 5.1, 5.2 e 9. Tabelas: [database.md](database.md), `users` e `auth_sessions`.

## Regras

- Dois papéis: `CANDIDATE` e `EMPLOYER`.
- Cadastro cria `users` e o perfil correspondente em **uma transação**.
- Usuário `CANDIDATE` só tem `candidate_profiles`. `EMPLOYER` só tem `employer_profiles`.
- Identidade vem sempre da sessão validada no servidor. Nunca de `userId` enviado pelo frontend.
- Senha: somente hash Argon2id em `users.password_hash`. Nunca texto puro.
- E-mail normalizado para minúsculas na aplicação. Único no banco.
- Token de sessão: aleatório e imprevisível. O banco guarda só `SHA-256(token)` em `auth_sessions.token_hash`.
- Token original vai para cookie `HttpOnly`, `SameSite=Lax`, `Secure` em produção, escopo do domínio da aplicação.
- Logout revoga a sessão no banco e remove o cookie.
- Sessões têm expiração obrigatória e podem ser revogadas.
- `is_active = false` bloqueia login e uso de sessão existente.
- Backend valida sessão e papel em toda rota protegida.

## Endpoints

| Método e rota | Acesso | Finalidade |
|---|---|---|
| `POST /api/v1/auth/register` | Público | Criar usuário e perfil correspondente |
| `POST /api/v1/auth/login` | Público | Iniciar sessão |
| `POST /api/v1/auth/logout` | Autenticado | Encerrar sessão |
| `GET /api/v1/auth/me` | Autenticado | Retornar usuário e perfil atual |

Entrada de `register`: e-mail, senha, papel (`CANDIDATE` ou `EMPLOYER`) e dados mínimos do perfil correspondente (`fullName` para candidato, `companyName` para contratante).

Respostas usam `camelCase` (ex.: `user.role`, `profile.fullName`). Nunca devolver `password_hash` nem `token_hash`.

## Frontend e CORS

Frontend e API no mesmo domínio, via proxy reverso. Se não for possível, configurar CORS com credenciais e proteção CSRF explicitamente.

## Segurança

- Rate limit em `register` e `login`.
- Mensagem de erro de login genérica (não revela se o e-mail existe).
- Não registrar senha, cookie ou token em logs.
- Parâmetros de Argon2id definidos na implementação e revisados antes do deploy.

## Testes (prioridade 1 e 2 da spec de backend)

- Cadastro cria usuário e perfil juntos; falha em um reverte o outro.
- Papel incompatível com o perfil é recusado.
- Login com senha errada não cria sessão.
- Sessão expirada ou revogada não autentica.
- Logout invalida o cookie no banco.
- `auth/me` nunca retorna hash.
- E-mail duplicado é recusado (independente de maiúsculas).

## Dependências a instalar nesta spec

- `argon2` (Argon2id). Instalar quando a implementação começar, não antes.
- Parser de cookies, se o Express não cobrir o caso.

## Tarefas

Ver [backlog](../tasks/backlog.md): T04 e T05.
