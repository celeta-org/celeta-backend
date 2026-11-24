# Celeta — Definição de Escopo do Produto

**Versão:** 1.0 (escopo inicial do MVP)
**Prazo de desenvolvimento:** 3 semanas
**Contexto:** projeto acadêmico
**Orçamento:** preferencialmente zero, com serviços gratuitos
**Status:** planejamento

Fonte original: `celeta_escopo_produto.docx`. Este arquivo é a versão em Markdown para consulta no repositório.

## 1. Visão geral

### 1.1. Descrição

A Celeta é uma plataforma de recrutamento que conecta candidatos a oportunidades profissionais por meio de recomendações personalizadas, pesquisa semântica e análise assistida por inteligência artificial.

A plataforma tem dois perfis principais: candidatos e contratantes. Candidatos informam contexto profissional, objetivos e competências. Contratantes publicam vagas com requisitos e critérios de seleção.

Agentes de IA auxiliam na interpretação das vagas, na descoberta de oportunidades e na avaliação de compatibilidade entre candidatos e requisitos. O processo de seleção tem duas etapas: triagem inicial com identidade oculta e avaliação posterior conduzida pelo contratante.

### 1.2. Problema

**Candidatos**
- Dificuldade em encontrar vagas compatíveis com seu momento profissional.
- Buscas dependentes de palavras-chave exatas.
- Dificuldade em identificar quais competências atendem a uma vaga.

**Contratantes**
- Grande volume de currículos para análise manual.
- Dificuldade em comparar candidatos com critérios consistentes.
- Tempo gasto na triagem inicial e na organização das candidaturas.

### 1.3. Proposta de valor

Reduzir o esforço de busca e triagem, usando IA para interpretar informações profissionais e apontar compatibilidades relevantes.

### 1.4. Limites do escopo

**Dentro do escopo (In)**
- Cadastro e autenticação de candidatos e contratantes.
- Perfil profissional contextualizado do candidato.
- Publicação e gerenciamento básico de vagas.
- Interpretação de vagas por IA.
- Mural de oportunidades personalizadas.
- Pesquisa flexível por linguagem natural.
- Envio de currículo por candidatura.
- Análise de compatibilidade entre currículo e vaga.
- Ranking de candidatos elegíveis para revisão humana.
- Primeira fase com identidade oculta e segunda fase com avaliação do contratante.
- Atualização básica do status das candidaturas.

**Fora do escopo inicial (Out)**
- Aplicativo mobile nativo.
- Integração com LinkedIn, portais externos ou sistemas de RH.
- Entrevistas por vídeo, testes técnicos e agendamento de entrevistas.
- Chat em tempo real entre candidatos e contratantes.
- E-mails transacionais avançados.
- Pagamentos, planos comerciais e monetização.
- Modelos de IA próprios ou treinamento de modelos.
- Algoritmos de previsão de desempenho profissional.
- Automação integral da decisão de contratação.
- Painéis analíticos avançados e relatórios corporativos.

## 2. Objetivos e indicadores de sucesso

Projeto acadêmico sem metas comerciais. Sucesso medido por fluxos concluídos, qualidade das recomendações e demonstração técnica.

| Indicador | Critério inicial de sucesso |
|---|---|
| Fluxo completo | Demonstrar o percurso da publicação da vaga até a revisão dos candidatos |
| Publicação de vagas | Uma vaga pode ser criada, salva e consultada |
| Personalização | O mural apresenta vagas compatíveis com o perfil cadastrado |
| Pesquisa semântica | Consultas com termos diferentes dos da vaga recuperam resultados pertinentes |
| Triagem por IA | Currículos são comparados aos critérios definidos para a vaga |
| Revisão humana | O contratante revisa candidatos e altera seus status |
| Estabilidade | Fluxos principais sem erros bloqueantes durante a demonstração |
| Custo operacional | Serviços gratuitos ou recursos já disponíveis, sem pagamentos |

**Metas de validação sugeridas**
- Executar pelo menos cinco cenários de teste completos.
- Testar pesquisa com consultas literais e consultas por significado.
- Testar currículos compatíveis, parcialmente compatíveis e incompatíveis.
- Verificar se a IA apresenta justificativas vinculadas aos critérios da vaga.
- Garantir que candidatos não acessem informações privadas de outras candidaturas.

Estas metas são critérios de validação do protótipo, não compromissos de desempenho de produção.

## 3. Histórias de usuário

### 3.1. Candidato

- **US-01 — Cadastro contextualizado:** informar área profissional, competências, objetivos e momento de carreira para receber oportunidades compatíveis.
- **US-02 — Cadastro de currículo:** cadastrar currículo no perfil para reutilizar nas candidaturas.
- **US-03 — Currículo específico:** enviar currículo diferente ao se candidatar a uma vaga.
- **US-04 — Mural personalizado:** ver vagas recomendadas pelo perfil.
- **US-05 — Pesquisa flexível:** pesquisar em linguagem natural, mesmo sem os termos da vaga.
- **US-06 — Candidatura:** candidatar-se e acompanhar o status.

### 3.2. Contratante

- **US-07 — Publicação de vaga:** preencher formulário e descrição livre para publicar com requisitos estruturados.
- **US-08 — Estruturação por IA:** IA extrai competências, requisitos e critérios da descrição.
- **US-09 — Definição de critérios:** revisar e confirmar critérios antes da triagem.
- **US-10 — Triagem inicial:** ver resultados da primeira fase sem identificação dos candidatos.
- **US-11 — Ranking explicável:** comparar candidatos pelos critérios e ver justificativas da IA.
- **US-12 — Avaliação humana:** acessar dados dos candidatos aprovados na primeira fase.
- **US-13 — Gestão de candidaturas:** atualizar o status dos candidatos.

## 4. MVP

**Módulo A — Autenticação e perfis**
- Cadastro e login.
- Tipo de usuário: candidato ou contratante.
- Perfil básico do candidato (área de interesse, competências, objetivos).
- Perfil básico do contratante.

**Módulo B — Criação e publicação de vagas**
- Formulário de vaga com descrição livre.
- Campos estruturados para requisitos, competências e critérios.
- Agente de IA que propõe estrutura a partir da descrição.
- Confirmação e edição dos critérios pelo contratante.
- Listagem de vagas publicadas.
- A IA não define critérios finais em silêncio; o contratante revisa antes da triagem.

**Módulo C — Descoberta de oportunidades**
- Mural de vagas para o candidato, com recomendação inicial pelo perfil e requisitos.
- Campo de pesquisa em linguagem natural.
- Interpretação da consulta por IA ou mecanismo semântico.
- Recuperação das vagas mais relevantes, sem exigir correspondência textual exata.
- Pode combinar busca textual, filtros estruturados e interpretação semântica. Sem sistema complexo de recomendação e sem modelo próprio.

**Módulo D — Candidatura e currículo**
- Envio de currículo em PDF.
- Uso do currículo cadastrado ou de versão específica.
- Registro da candidatura vinculada à vaga e ao currículo usado.
- Armazenamento seguro dos arquivos.

**Módulo E — Triagem assistida por IA**
- Extração das informações relevantes do currículo.
- Comparação com os critérios da vaga.
- Resultado estruturado por candidato: compatibilidade, evidências e critérios não atendidos.
- Classificação: elegível, não elegível ou revisão necessária.
- Ranking dos candidatos elegíveis.
- Ocultação de nome, foto, contato e outros identificadores na primeira fase, inclusive para o contratante.
- Identificação liberada na segunda fase, após decisão de avançar.
- Resultado da IA é apoio, não decisão de contratação. Contratante revisa casos duvidosos e pode contestar classificações.

**Módulo F — Gestão básica do processo seletivo**
- Lista de candidatos por vaga.
- Visualização dos resultados da primeira fase.
- Acesso a currículos e perfis na segunda fase.
- Atualização manual de status: em análise, aprovado para próxima fase, não selecionado.
- Candidato vê o status na plataforma.
- Notificações por e-mail ficam fora do MVP.

## 5. Roadmap — Fase 2

- Mensagens entre candidato e contratante.
- Notificações por e-mail.
- Busca vetorial avançada.
- Recomendações ajustadas por feedback de uso real.
- Painéis analíticos do funil de recrutamento.
- Comparação avançada de candidatos.
- Histórico e auditoria detalhada.
- Exportação de relatórios.
- Integrações externas.
- Testes técnicos e avaliações.

A prioridade da Fase 2 depende dos resultados dos testes do MVP.

## 6. Riscos e dependências

**Dependências técnicas**
- **Serviços gratuitos de IA:** limites de requisições, tokens, velocidade e disponibilidade. Mitigação: camada de integração trocável, entradas limitadas, respostas estruturadas, poucas chamadas e alternativa simplificada se a IA cair.
- **Hospedagem e banco:** hospedagem gratuita pode exigir configuração extra e ter limites. Mitigação: escolher infraestrutura na semana 1, validar deploy cedo, arquitetura simples.
- **Armazenamento de currículos:** dados pessoais e possivelmente sensíveis. Mitigação: permissões no backend, validação de arquivos, sem URLs públicas permanentes.
- **Consistência da IA:** classificações inconsistentes, leitura errada ou competências inventadas. Mitigação: saída estruturada, evidências registradas, validação e revisão humana. Falha da análise leva a revisão, não a descarte automático.

**Riscos de produto**
- **Complexidade excessiva para o prazo:** mitigação — entregar fluxo essencial primeiro; agentes como funções delimitadas, sem infraestrutura autônoma.
- **Critérios injustos ou inadequados:** IA pode favorecer por características irrelevantes ou tratar lacuna de informação como falta de competência. Mitigação — avaliar só competências pertinentes, excluir atributos protegidos e dados desnecessários, testar casos variados, manter supervisão humana.
- **Limites da seleção cega:** dados do currículo podem revelar identidade indiretamente. Mitigação — remover identificadores diretos na primeira fase e documentar que o anonimato é parcial.
- **LGPD:** coletar só o necessário, informar finalidade, limitar acesso, definir retenção e exclusão, avaliar obrigações antes de usar dados reais.

## 7. Cronograma

- **Semana 1 — Fundação e fluxo principal:** arquitetura e serviços gratuitos; banco e permissões; autenticação e perfis; criação, publicação e listagem de vagas; primeiro deploy. *Entrega:* acesso à plataforma e vagas publicáveis.
- **Semana 2 — IA e candidaturas:** mural e pesquisa flexível; interpretação de vagas; upload de currículo e candidatura; análise de compatibilidade; triagem cega. *Entrega:* candidato encontra vagas, candidata-se e tem currículo analisado.
- **Semana 3 — Seleção e validação:** ranking e justificativas; revisão do contratante e segunda fase; atualização de status; testes de permissão e segurança; correções e preparo da demonstração. *Entrega:* fluxo completo demonstrável.

## 8. Critérios de aceite do MVP

1. Contratante cria vaga e revisa critérios sugeridos pela IA.
2. Candidato cria perfil e encontra vagas relevantes.
3. Pesquisa recupera vagas pertinentes para consultas não literais.
4. Candidato envia currículo e conclui candidatura.
5. IA produz análise estruturada vinculada aos requisitos.
6. Contratante vê resultados da primeira fase sem identificadores diretos.
7. Contratante revisa candidatos e avança para a segunda fase.
8. Candidato consulta o status da candidatura.
9. Acessos a perfis, candidaturas e currículos respeitam permissões.
10. Fluxos essenciais funcionam no ambiente de demonstração sem erros bloqueantes.

## 9. Diretrizes de escopo

- Aplicação web responsiva, sem app nativo.
- Um backend e um banco, sem microsserviços.
- IA como serviço auxiliar, sem treinar modelos próprios.
- Agentes como módulos delimitados, com entradas e saídas previsíveis.
- Busca híbrida simplificada: filtros e interpretação semântica.
- Triagem configurável e supervisionada, sem decisão final automatizada.
- Status e mensagens simples, sem chat nem notificações avançadas.
- Infraestrutura gratuita ou já disponível, com plano alternativo.

## 10. Definição de sucesso

Demonstrar que a Celeta transforma descrição de vaga em critérios estruturados, encontra candidatos potencialmente compatíveis e ajuda o contratante a fazer triagem mais organizada e explicável. A prioridade é um fluxo funcional, seguro o bastante para a demonstração, dentro do prazo acadêmico, e não a quantidade de funcionalidades, escala ou faturamento.
