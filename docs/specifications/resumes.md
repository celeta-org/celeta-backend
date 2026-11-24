# Spec: resumes

Currículos do candidato: upload privado de PDF, extração de texto e download protegido.

Referência: [backend.md](backend.md), seções 5.5, 5.6 (extração), 8 e 9. Tabela: [database.md](database.md), `resumes`.

## Regras

- Candidato mantém vários currículos. Cada um pertence a um `candidate_profile`.
- Só PDF no MVP.
- Validação na entrada: extensão, MIME, **assinatura do arquivo** (magic bytes `%PDF-`), tamanho máximo configurado.
- Nome interno do arquivo é gerado pelo sistema (UUID). O nome original não é usado no disco.
- Arquivo fica em diretório **privado e persistente**, fora de qualquer pasta pública e fora do banco.
- Banco guarda só `storage_key` (caminho interno). Nunca URL pública. `storage_key` não sai em respostas abertas.
- Download só por endpoint autenticado e autorizado (dono do currículo).
- Estados de extração: `PENDING`, `COMPLETED`, `FAILED`.
- Extração do texto acontece no backend, antes da IA.
- `extracted_text` fica acessível só ao backend. Não sai em respostas da API.
- Falha de extração **não reprova**. A candidatura vai para revisão, ou o candidato pode enviar outro currículo.
- Currículo vinculado a candidatura não é apagado fisicamente (ver regra de exclusão em [database.md](database.md)).

## Endpoints

| Método e rota | Acesso | Finalidade |
|---|---|---|
| `GET /api/v1/resumes` | Candidato | Listar próprios currículos (sem `storage_key` nem texto) |
| `POST /api/v1/resumes` | Candidato | Enviar PDF |
| `GET /api/v1/resumes/:resumeId/file` | Dono autorizado | Baixar PDF protegido |

## Fluxo de upload

1. Verificar autenticação e papel `CANDIDATE`.
2. Aplicar rate limit de upload.
3. Limitar tamanho antes de ler o corpo inteiro.
4. Validar extensão, MIME e assinatura `%PDF-`.
5. Gerar nome interno e gravar no diretório privado.
6. Inserir `resumes` com `extraction_status = PENDING`.
7. Extrair texto. Atualizar para `COMPLETED` ou `FAILED`.
8. Responder sem `storage_key` nem texto.

Se a gravação em disco falhar, nada fica registrado no banco. Se o banco falhar após gravar, remover o arquivo órfão.

## Segurança

- Diretório de PDFs montado só na API. Não servido como conteúdo estático.
- Não registrar texto do currículo nem nome de arquivo com dados pessoais em logs.
- Download responde com `Content-Disposition` de anexo e `Content-Type: application/pdf`.
- Acesso negado retorna `404` para não revelar a existência do arquivo a terceiros.

## Testes (prioridade 10 da spec de backend)

- Arquivo com extensão `.pdf` mas conteúdo não-PDF é recusado.
- Arquivo acima do limite é recusado.
- Candidato não baixa currículo de outro candidato.
- Contratante não baixa currículo por esta rota (o acesso dele passa pela candidatura, na fase correta).
- `storage_key` não aparece em nenhuma resposta da API.
- Falha de extração grava `FAILED` e não altera status da candidatura.

## Dependências a instalar nesta spec

- Extração de texto de PDF (biblioteca a escolher na implementação).
- Biblioteca de upload multipart, se o Express não bastar.

## Tarefas

Ver [backlog](../tasks/backlog.md): T12 a T14.
