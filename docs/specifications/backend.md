# Celeta — Especificação do Backend

**Versão:** 2.0  
**Escopo:** MVP acadêmico  
**Referência de produto:** Celeta — Definição de Escopo do Produto v1.0  
**Prazo de referência:** 3 semanas  
**Stack:** Node.js (LTS), JavaScript ES Modules, Express, Zod e MySQL 8.0.16+  
**Estilo arquitetural:** monólito modular em camadas

## 1. Objetivo

O backend da Celeta fornece uma API REST para cadastro e autenticação, perfis, vagas, currículos, candidaturas, busca e triagem assistida por IA. Ele é a autoridade sobre autenticação, autorização, regras de negócio e persistência.

O MVP deve priorizar o fluxo completo de publicação de vaga até a revisão humana das candidaturas. Não deve introduzir microsserviços, agentes autônomos, filas externas ou serviços pagos que não sejam necessários para demonstrar esse fluxo.

## 2. Decisões técnicas consolidadas

| Área | Decisão | Justificativa |
|---|---|---|
| Runtime | Node.js LTS | Mantém a stack JavaScript já prevista. |
| HTTP | Express | Atende à API REST sem trocar o framework existente. |
| Validação | Zod | Valida requisições e respostas externas com o mesmo padrão. |
| Banco | MySQL 8.0.16+ | Mantém a tecnologia do esquema existente e permite usar `CHECK` constraints. |
| Acesso ao banco | `mysql2/promise` com SQL parametrizado | Evita adicionar ORM e mantém as consultas explícitas. |
| Identificadores | UUID v4 gerado pelo backend | Simples de gerar com `crypto.randomUUID()` e compatível com `CHAR(36)`. |
| Autenticação | Própria, com Argon2id e sessões no MySQL | Evita dependência de Supabase Auth ou outro serviço externo. |
| Arquivos | Diretório privado persistente no servidor | Evita custo de storage externo no MVP. |
| IA | Adaptador HTTP direto para um provedor de modelo | Elimina a necessidade de hospedar e manter n8n para poucos workflows. |
| Busca | Full-text do MySQL, filtros e interpretação opcional por IA | Evita banco vetorial, embeddings e infraestrutura adicional. |
| Deploy | Uma VPS, Docker Compose e proxy HTTPS | Centraliza API, banco e arquivos em uma única infraestrutura. |

**Não fazem parte da infraestrutura do MVP:** Supabase, n8n, Redis, RabbitMQ, banco vetorial, microsserviços, storage externo, serviço de autenticação externo e ORM.

A escolha de um provedor de IA não implica que seu uso será gratuito. O backend deve aceitar provedores diferentes por configuração, aplicar limites de uso e permitir que a funcionalidade opere em modo reduzido quando não houver chave ou cota disponível.

## 3. Arquitetura

Adotar um monólito modular em camadas. Os módulos ficam dentro da mesma aplicação e compartilham o mesmo banco de dados.

### 3.1. Responsabilidades

| Componente | Responsabilidade |
|---|---|
| Routes | Definir endpoints e associar middlewares e controllers. |
| Middlewares | Autenticação, autorização, validação transversal e tratamento de erros. |
| Schemas | Validar parâmetros, query strings, corpos e respostas externas com Zod. |
| Controllers | Traduzir HTTP para chamadas de casos de uso e montar respostas. |
| Use Cases | Executar regras de negócio e coordenar transações. |
| Repositories | Executar SQL e mapear linhas do MySQL para objetos de domínio. |
| Integrations | Isolar o provedor de IA e o acesso ao sistema de arquivos. |
| Tests | Validar regras, permissões, persistência e contratos HTTP. |

Fluxo padrão:

`HTTP → Middleware → Zod → Controller → Use Case → Repository / Integration → Response`

Controllers não contêm regras de negócio. Repositories não decidem classificação de candidatos ou transições de seleção. Casos de uso não dependem de objetos do Express nem de detalhes do provedor de IA.

### 3.2. Organização sugerida

```text
src/
  app.js
  server.js
  config/
  database/
    pool.js
    migrations/
  modules/
    auth/
      auth.routes.js
      auth.controller.js
      auth.schemas.js
      auth.service.js
      auth.repository.js
    users/
    candidate-profiles/
    employer-profiles/
    jobs/
    discovery/
    resumes/
    applications/
    screening/
  integrations/
    ai/
      ai-provider.js
      ai.schemas.js
    files/
  shared/
    errors/
    middlewares/
    utils/
tests/
```

A estrutura é uma referência, não uma obrigação de criar arquivos vazios. Cada módulo deve conter apenas as camadas necessárias à funcionalidade.

## 4. Nomenclatura única

O idioma técnico oficial do projeto passa a ser inglês em backend, API e banco de dados.

| Conceito | Entidade no backend | Tabela MySQL |
|---|---|---|
| Conta | `User` | `users` |
| Sessão de autenticação | `AuthSession` | `auth_sessions` |
| Perfil de candidato | `CandidateProfile` | `candidate_profiles` |
| Perfil de contratante | `EmployerProfile` | `employer_profiles` |
| Vaga | `Job` | `jobs` |
| Critério de seleção | `JobCriterion` | `job_criteria` |
| Currículo | `Resume` | `resumes` |
| Candidatura | `Application` | `applications` |
| Resultado de um critério para uma candidatura | `ApplicationCriterionEvaluation` | `application_criterion_evaluations` |

Regras de nomenclatura:

- Entidades e classes: `PascalCase`, no singular (`CandidateProfile`).
- Variáveis e propriedades JavaScript: `camelCase` (`candidateProfileId`).
- Tabelas e colunas SQL: `snake_case`, tabelas no plural (`candidate_profiles`, `candidate_profile_id`).
- Endpoints: recursos no plural (`/jobs`, `/applications`).
- JSON da API: `camelCase`.
- Valores de estados e classificações: constantes em inglês e `UPPER_SNAKE_CASE`.

`JobRequirement` não será uma tabela própria no MVP. Os requisitos de exibição ficam em `jobs.requirements_json`. `JobCriterion` é uma entidade própria porque seus itens são avaliados individualmente pela triagem.

`Screening` é um módulo/caso de uso, não uma entidade persistida isoladamente. O estado e o resumo da triagem ficam em `applications`; os resultados por critério ficam em `application_criterion_evaluations`.

## 5. Regras de domínio

### 5.1. Usuários e perfis

Existem dois papéis:

- `CANDIDATE`: possui um `CandidateProfile`.
- `EMPLOYER`: possui um `EmployerProfile`.

O cadastro cria o usuário e o perfil correspondente dentro de uma única transação. O backend não permite criar ou acessar um perfil incompatível com o papel da conta.

A identidade autenticada é obtida da sessão validada pelo servidor. Nunca confiar em `userId` enviado pelo frontend para definir quem está realizando uma operação.

### 5.2. Autenticação

A autenticação será própria, sem Supabase Auth.

- Senhas armazenadas somente como hash Argon2id em `users.password_hash`.
- O login gera um token de sessão aleatório e não previsível.
- O banco armazena somente o SHA-256 do token em `auth_sessions.token_hash`; o token original vai para cookie `HttpOnly`.
- Cookie configurado com `Secure` em produção, `SameSite=Lax` e escopo restrito ao domínio da aplicação.
- Logout revoga a sessão no banco e remove o cookie.
- Sessões possuem expiração e podem ser revogadas.
- O backend valida sessão e papel em toda rota protegida.

Para simplificar CORS e proteção de cookies, frontend e API devem ser publicados sob o mesmo domínio, usando o proxy reverso. Se isso não for possível, CORS com credenciais e proteção CSRF precisam ser configurados explicitamente.

Endpoints mínimos:

- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/logout`
- `GET /api/v1/auth/me`

### 5.3. Vagas e critérios

- O contratante cria a vaga inicialmente com status `DRAFT`.
- A IA pode sugerir requisitos e critérios, mas não publica a vaga nem confirma os critérios.
- O contratante pode editar, adicionar ou remover critérios.
- A confirmação é registrada em `jobs.criteria_confirmed_at` e `jobs.criteria_confirmed_by_user_id`.
- Qualquer alteração nos critérios após a confirmação deve limpar os dois campos de confirmação.
- A publicação exige vaga válida e critérios revisados e confirmados.
- Somente o contratante proprietário pode editar, confirmar, publicar ou encerrar a vaga.

Estados de vaga:

- `DRAFT`
- `PUBLISHED`
- `CLOSED`

### 5.4. Requisitos e critérios

São conceitos diferentes:

- **Requirements:** informações estruturadas para exibição e filtros simples; ficam em `jobs.requirements_json`.
- **Criteria:** itens que serão avaliados individualmente na triagem; ficam em `job_criteria`.

Cada critério possui:

- `criterion_type`: `REQUIRED` ou `DESIRABLE`.
- `weight`: peso numérico positivo usado pelo cálculo de compatibilidade.
- `name` e `details`: identificação e instrução contextual do critério.

O tipo do critério e seu peso são informações distintas. O tipo diz se é obrigatório ou desejável; o peso indica sua influência no score.

### 5.5. Currículos e candidaturas

- O candidato pode manter vários currículos.
- Cada candidatura referencia um currículo específico.
- O backend verifica que o currículo selecionado pertence ao candidato autenticado.
- Um candidato pode possuir somente uma candidatura por vaga: regra garantida por `UNIQUE(job_id, candidate_profile_id)`.
- O PDF fica em diretório privado e persistente. O banco armazena somente `storage_key`, nunca URL pública.
- O arquivo só pode ser baixado por endpoint autenticado e autorizado.
- O MVP aceita PDF; validar extensão, MIME, assinatura do arquivo e tamanho máximo configurado.

Estados de extração do currículo:

- `PENDING`
- `COMPLETED`
- `FAILED`

A extração de texto do PDF acontece no backend, antes da chamada à IA. Falha de extração não deve resultar em reprovação: a candidatura deve ser encaminhada para revisão ou permitir novo envio de currículo.

### 5.6. Triagem assistida por IA

O backend chama diretamente o provedor de IA por meio de `integrations/ai`. O provedor pode ser trocado sem alterar os casos de uso.

Fluxos de IA do MVP:

1. **Estruturação da vaga:** descrição livre → requisitos e critérios sugeridos.
2. **Interpretação da busca:** consulta em linguagem natural → palavras-chave e filtros estruturados.
3. **Triagem:** texto do currículo e critérios confirmados → resultado por critério, evidência e incerteza.

Contrato de triagem:

- O backend envia somente os dados necessários: texto extraído do currículo com remoção de identificadores diretos detectáveis e critérios confirmados.
- A resposta deve ser JSON estruturado e validado com Zod.
- Cada critério deve retornar `MET`, `NOT_MET` ou `INSUFFICIENT_EVIDENCE`, acompanhado de evidência textual quando houver.
- Critérios ausentes na resposta ou sem evidência suficiente devem ser tratados como `INSUFFICIENT_EVIDENCE`.
- O backend confere se os IDs retornados pertencem à vaga e calcula score e classificação.
- O modelo não define status da candidatura, não avança candidato de fase e não toma decisão final.

Classificação calculada pelo backend:

- `REVIEW_REQUIRED`: existe critério obrigatório sem evidência suficiente, a resposta é inválida ou a análise falhou.
- `NOT_ELIGIBLE`: existe critério obrigatório explicitamente `NOT_MET`, sem pendência de evidência obrigatória.
- `ELIGIBLE`: todos os critérios obrigatórios foram avaliados como `MET`.

O score é calculado pelo backend com os critérios conclusivamente avaliados:

`score = (soma dos pesos dos critérios MET / soma dos pesos dos critérios MET e NOT_MET) × 100`

Critérios `INSUFFICIENT_EVIDENCE` não entram no denominador. Se nenhum critério tiver avaliação conclusiva, o score será `NULL`. O score serve para ordenar resultados; não substitui a decisão humana.

Falha, timeout, resposta malformada ou ausência de evidência não pode gerar `NOT_ELIGIBLE` por padrão. O resultado deve ser `REVIEW_REQUIRED`, sem reprovação automática.

### 5.7. Fases e status de candidatura

O banco mantém dois campos separados porque representam dimensões diferentes.

**Status de negócio (`applications.status`):**

- `IN_REVIEW`: candidatura em avaliação.
- `ADVANCED`: contratante decidiu avançar o candidato.
- `NOT_SELECTED`: contratante decidiu não selecionar o candidato.

**Fase de acesso (`applications.selection_phase`):**

- `BLIND`: dados identificáveis ocultos para o contratante.
- `IDENTIFIED`: dados identificáveis liberados para a segunda fase.

Quando o contratante avança uma candidatura, o backend atualiza `status = ADVANCED` e `selection_phase = IDENTIFIED` na mesma transação. Quando rejeita na primeira fase, define `NOT_SELECTED` e mantém `BLIND`. Uma rejeição posterior mantém `IDENTIFIED`.

A classificação da IA (`ai_classification`) nunca é o status da candidatura. O frontend pode traduzir os valores técnicos para rótulos em português.

### 5.8. Anonimização

A primeira fase é cega na API, não apenas na interface:

- A listagem de candidaturas de uma vaga retorna resultados anonimizados quando `selection_phase = BLIND`.
- Nome, contato, perfil e acesso ao PDF não são incluídos na resposta.
- A identidade só é disponibilizada ao contratante após a transição para `IDENTIFIED`.
- O candidato autenticado sempre pode consultar os próprios dados e o status da própria candidatura.
- O texto do currículo enviado à IA deve passar por remoção de identificadores diretos detectáveis; anonimização perfeita não é garantida, pois o conteúdo pode conter pistas indiretas.

### 5.9. Busca de oportunidades

A primeira versão utiliza:

- Índice `FULLTEXT` em título e descrição da vaga.
- Filtros relacionais estruturados.
- Interpretação opcional da consulta por IA para extrair intenção e filtros.

Sem chave ou com indisponibilidade da IA, o backend executa a busca textual convencional. Não haverá embeddings, banco vetorial ou treinamento de modelo no MVP.

## 6. Persistência e transações

- Acesso ao banco centralizado em repositories usando `mysql2/promise`.
- Todas as consultas com parâmetros; nunca concatenar entrada do usuário em SQL.
- IDs UUID gerados no backend com `crypto.randomUUID()`.
- Operações de cadastro com criação de usuário e perfil dentro de uma transação.
- Publicação de vaga verifica confirmação de critérios antes de atualizar o status.
- Candidatura verifica propriedade do currículo, vaga publicada e duplicidade antes de inserir.
- Avanço de fase atualiza status e fase em uma transação.
- Avaliações por critério são gravadas em lote dentro de uma transação.
- Alterações no esquema são versionadas em arquivos SQL de migration.

## 7. Contratos REST mínimos

Prefixo: `/api/v1`. JSON da API usa `camelCase`; o repository faz o mapeamento para `snake_case` do MySQL.

| Método e rota | Acesso | Finalidade |
|---|---|---|
| `POST /auth/register` | Público | Criar usuário e perfil correspondente. |
| `POST /auth/login` | Público | Iniciar sessão. |
| `POST /auth/logout` | Autenticado | Encerrar sessão. |
| `GET /auth/me` | Autenticado | Retornar usuário e perfil atual. |
| `GET/PATCH /candidate-profile/me` | Candidato | Consultar/editar próprio perfil. |
| `GET/PATCH /employer-profile/me` | Contratante | Consultar/editar próprio perfil. |
| `GET /jobs` | Público/autenticado | Listar e pesquisar vagas publicadas. |
| `POST /jobs` | Contratante | Criar vaga em rascunho. |
| `GET /jobs/:jobId` | Público/autenticado | Consultar vaga publicada ou vaga própria. |
| `PATCH /jobs/:jobId` | Contratante proprietário | Editar vaga. |
| `POST /jobs/:jobId/criteria/suggestions` | Contratante proprietário | Gerar sugestões com IA. |
| `POST /jobs/:jobId/criteria/confirm` | Contratante proprietário | Confirmar critérios revisados. |
| `POST /jobs/:jobId/publish` | Contratante proprietário | Publicar vaga. |
| `POST /jobs/:jobId/close` | Contratante proprietário | Encerrar vaga. |
| `GET/POST /resumes` | Candidato | Listar e enviar currículos. |
| `GET /resumes/:resumeId/file` | Proprietário autorizado | Baixar PDF protegido. |
| `POST /jobs/:jobId/applications` | Candidato | Criar candidatura com currículo escolhido. |
| `GET /applications/me` | Candidato | Consultar próprias candidaturas. |
| `GET /jobs/:jobId/applications` | Contratante proprietário | Listar candidaturas com anonimização conforme a fase. |
| `POST /applications/:applicationId/screening` | Contratante proprietário ou rotina interna autorizada | Executar/reexecutar triagem. |
| `PATCH /applications/:applicationId/status` | Contratante proprietário | Avançar ou não selecionar candidatura. |

As rotas podem ser entregues gradualmente, mas não devem duplicar regras de negócio. O backend deve responder com códigos HTTP consistentes e um formato de erro comum.

## 8. Integração com IA e controle de custo

A integração usa um adaptador HTTP, com URL, chave e nome do modelo definidos por variáveis de ambiente.

Controles obrigatórios:

- Uma chamada por operação necessária, sem agentes autônomos.
- Não executar triagem repetidamente ao abrir uma página.
- Persistir o resultado e permitir reprocessamento explícito.
- Limitar tamanho do texto enviado e quantidade de candidaturas processadas por lote.
- Aplicar timeout, limite de requisições e tratamento de cota excedida.
- Validar toda resposta com Zod antes de persistir.
- Usar respostas simuladas nos testes; testes automatizados não chamam modelos reais.
- Permitir operação sem IA: critérios manuais, busca textual e revisão humana.

A cobrança do modelo, quando houver, é variável e externa à hospedagem. O backend deve registrar consumo técnico sem gravar prompts com dados pessoais desnecessários.

## 9. Segurança e privacidade

- Argon2id para senhas; nunca armazenar senha em texto puro.
- Tokens de sessão aleatórios; armazenar somente hash do token.
- Cookies seguros em produção e HTTPS obrigatório.
- Autorização por papel e propriedade do recurso em todos os casos de uso.
- Currículos fora da pasta pública do servidor; download sempre autenticado.
- Validar PDF, tamanho, assinatura e nome interno gerado pelo sistema.
- Não registrar senha, cookie, token, currículo ou texto integral de currículo em logs.
- Não expor dados identificáveis na primeira fase.
- Manter chaves de IA e credenciais em variáveis de ambiente, nunca no repositório.
- Configurar rate limit nos endpoints de autenticação, upload e IA.
- Aplicar coleta mínima, prazo de retenção e processo de exclusão compatíveis com a LGPD antes de utilizar dados reais.

## 10. Testes e TDD

Seguir o ciclo Red → Green → Refactor.

Prioridade de testes:

1. Regras de papel e propriedade de recursos.
2. Cadastro atômico de usuário e perfil.
3. Confirmação de critérios e publicação de vaga.
4. Propriedade do currículo e bloqueio de candidatura duplicada.
5. Integridade entre candidatura, candidato, currículo, vaga e critérios.
6. Transições válidas de status e fase.
7. Anonimização da resposta da primeira fase.
8. Cálculo de score e classificação.
9. Falha, timeout e resposta malformada do provedor de IA.
10. Download protegido de currículos.

Usar um banco MySQL de teste e simular a integração de IA. Não depender de chamadas reais a modelos nos testes.

## 11. Infraestrutura e deploy de menor custo

Arquitetura de implantação:

```text
Internet
   |
Proxy reverso HTTPS (Caddy ou Nginx)
   |
API Celeta (Node.js / Express)
   |--------------------|
MySQL 8              Volume privado de PDFs
   |
Backup externo/segundo destino

API ----------------> Provedor de IA (HTTP, somente quando necessário)
```

Para o MVP, executar proxy, API e MySQL em uma única VPS via Docker Compose, com volumes persistentes para banco e PDFs. Não expor a porta do MySQL à internet. O diretório de PDFs deve ser montado apenas na API e não servido como conteúdo estático.

Medidas mínimas:

- HTTPS no proxy reverso.
- Variáveis e secrets fora das imagens e do Git.
- Backup periódico do MySQL e do volume de PDFs para um segundo destino.
- Testar restauração dos backups.
- Logs com rotação e sem dados pessoais.
- Monitorar uso de disco, memória e disponibilidade.

Uma oferta gratuita de VPS pode ser usada quando estiver disponível e atender aos requisitos, mas não deve ser tratada como garantia permanente. O desenho permanece compatível com uma VPS pequena paga ou infraestrutura já disponível. O principal custo variável esperado é o uso do provedor de IA e, dependendo do cenário, a hospedagem e o domínio.

## 12. Plano de implementação

### Semana 1 — Fundação

- Criar API Express, validação Zod, tratamento de erros e pool MySQL.
- Aplicar migrations e testar relações.
- Implementar autenticação, sessões e perfis.
- Implementar criação, edição, confirmação de critérios e publicação de vagas.
- Preparar deploy inicial.

### Semana 2 — Currículos, candidaturas e IA

- Implementar upload privado e extração de texto dos PDFs.
- Implementar candidatura e bloqueio de duplicidade.
- Implementar busca textual e filtros.
- Integrar geração de critérios e interpretação de pesquisa.
- Implementar contrato de triagem e gravação dos resultados.

### Semana 3 — Seleção e estabilização

- Implementar lista anonimizada e segunda fase identificada.
- Implementar atualização de status e consulta do candidato.
- Cobrir transições, permissões e falhas de IA.
- Validar backup, deploy, logs e fluxo completo.

## 13. Critérios de aceite do backend

1. Candidato e contratante conseguem cadastrar-se, autenticar-se e acessar somente seus recursos.
2. Contratante cria vaga como rascunho, revisa critérios e confirma antes de publicar.
3. Candidato pesquisa vagas, envia currículos e se candidata com uma versão específica.
4. O sistema bloqueia candidatura duplicada para a mesma vaga.
5. A triagem gera avaliação por critério, evidências, score e classificação validados.
6. Falha da IA não reprova automaticamente o candidato.
7. Contratante visualiza candidaturas anonimizadas na primeira fase.
8. Avanço para a segunda fase libera identidade e currículo por autorização do backend.
9. Contratante atualiza status e candidato consulta suas candidaturas.
10. Os fluxos essenciais funcionam no deploy com custos controlados e sem dependência de serviços pagos obrigatórios, exceto eventual provedor de IA.

## 14. Fora do MVP

Chat, notificações por e-mail, pagamentos, integração com portais externos, aplicativo nativo, entrevistas por vídeo, testes técnicos, analytics avançado, busca vetorial, treinamento de modelos, microsserviços, n8n, Redis e automação integral da decisão de contratação.
