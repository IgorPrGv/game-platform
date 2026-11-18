# Contratos e dados

Este documento especifica o que cada parte do sistema promete às outras: a API HTTP, o formato dos dados no MongoDB, no DynamoDB e no S3, e as mensagens trocadas entre as funções Lambda e a API. É a referência para DTOs e controllers. O `openapi.json` é gerado a partir do código.

Documentos relacionados: [Requisitos](01-requisitos.md), [Arquitetura de nuvem](02-arquitetura-nuvem.md), [Arquitetura de software](03-arquitetura-software.md), [Plano de construção](05-plano-de-construcao.md).

## Sumário

1. [Visão geral dos contratos](#1-visão-geral-dos-contratos)
2. [Convenções](#2-convenções)
3. [Modelo de dados](#3-modelo-de-dados)
4. [API HTTP `/api/v1`](#4-api-http-apiv1)
5. [Envio de arquivos](#5-envio-de-arquivos)
6. [Eventos e mensagens](#6-eventos-e-mensagens)
7. [Estados e regras de negócio](#7-estados-e-regras-de-negócio)
8. [Matriz de requisitos para rotas](#8-matriz-de-requisitos-para-rotas)
9. [Valores padrão e limites](#9-valores-padrão-e-limites)

## Siglas e termos

| Termo                          | Significado                                                                |
| ------------------------------ | -------------------------------------------------------------------------- |
| RF, RNF, REST                  | Requisitos funcionais, não funcionais e restrições                         |
| DTO                            | Formato de dados de uma rota                                               |
| `itemKey`                      | Identificador de item de catálogo: `offer:{steamAppID}` ou `game:{gameId}` |
| `pending`, `ready`, `rejected` | Estados de processamento de uma mídia                                      |

## 1. Visão geral dos contratos

| #   | Contrato                                                | Entre quem                       | Seção |
| --- | ------------------------------------------------------- | -------------------------------- | ----- |
| C1  | API HTTP `/api/v1`                                      | Navegador ↔ API                  | 4     |
| C2  | Envio de arquivos (POST pré-assinado e URLs de leitura) | Navegador ↔ S3, emitido pela API | 5     |
| C3  | Dados do MongoDB                                        | API ↔ MongoDB                    | 3     |
| C4  | Itens do DynamoDB `offers`                              | Lambda de ofertas → API          | 3.8   |
| C5  | Evento do S3 e mensagem de resultado                    | S3 → Lambda → SQS → API          | 6     |
| C6  | Resposta da CheapShark e sua normalização               | CheapShark → Lambda              | 6.4   |
| C7  | Chaves do S3                                            | Todos                            | 3.9   |

## 2. Convenções

| Tema            | Regra                                                                                                           |
| --------------- | --------------------------------------------------------------------------------------------------------------- |
| Prefixo         | `/api/v1`; `GET /api/health` sem versão                                                                         |
| Formato         | JSON em UTF-8; datas em ISO 8601 UTC (`AAAA-MM-DDThh:mm:ssZ`)                                                   |
| Identificadores | Texto opaco; no Mongo, o `_id` em hexadecimal                                                                   |
| Autenticação    | Cookie `session` (JWT de 1 h): `HttpOnly; Secure; SameSite=Strict; Path=/api; Max-Age=3600`                     |
| Rotas públicas  | Marcadas como **pública** nas tabelas; as demais exigem sessão (`401 unauthenticated`)                          |
| Paginação       | `?page=1&pageSize=20` (página a partir de 1; `pageSize` de 1 a 50). Resposta `{ items, page, pageSize, total }` |
| Erros           | `application/problem+json` (seção 2.1)                                                                          |
| Idempotência    | `PUT` e `DELETE` são idempotentes; `POST` cria com identificador gerado pelo servidor                           |
| Limites de taxa | Cadastro e login: 10 por minuto por IP; demais rotas: 120 por minuto por IP. Excesso: `429 rate_limited`        |
| Correlação      | Toda resposta traz `X-Request-Id`, com o mesmo valor de `requestId` nos erros e nos logs                        |
| Textos          | Mensagens ao usuário em português do Brasil; `code` é estável e em inglês                                       |
| Moeda           | As ofertas são em dólares (USD)                                                                                 |

### 2.1 Formato de erro

```json
{
  "type": "about:blank",
  "title": "Validation failed",
  "status": 400,
  "code": "validation_failed",
  "detail": "Um ou mais campos são inválidos.",
  "requestId": "Root=1-67f...",
  "errors": [{ "path": "password", "message": "Mínimo de 8 caracteres." }]
}
```

`errors` só aparece em `validation_failed`. As respostas nunca expõem detalhes internos (pilha, consultas, nomes de coleção).

### 2.2 Catálogo de códigos de erro

| `code`                 | Status | Quando                                                                  |
| ---------------------- | ------ | ----------------------------------------------------------------------- |
| `validation_failed`    | 400    | Corpo, consulta ou parâmetro inválido                                   |
| `unauthenticated`      | 401    | Sem sessão ou sessão vencida                                            |
| `invalid_credentials`  | 401    | Login com dados incorretos (mensagem genérica)                          |
| `forbidden`            | 403    | Sem o papel ou sem posse do recurso                                     |
| `not_found`            | 404    | Recurso inexistente (ou que o usuário não pode ver)                     |
| `username_taken`       | 409    | Nome de usuário já cadastrado                                           |
| `email_taken`          | 409    | E-mail já cadastrado                                                    |
| `invalid_state`        | 409    | Operação incompatível com o estado atual (por exemplo, mídia `pending`) |
| `not_in_library`       | 403    | Download de jogo que não está na biblioteca                             |
| `game_not_available`   | 404    | Jogo não publicado ou removido                                          |
| `reply_depth_exceeded` | 409    | Resposta a uma resposta                                                 |
| `offers_unavailable`   | 503    | Ainda não há nenhuma execução da Lambda de ofertas                      |
| `rate_limited`         | 429    | Limite de taxa excedido                                                 |
| `internal_error`       | 500    | Falha inesperada                                                        |

## 3. Modelo de dados

### 3.1 Princípios

- Cada operação altera **um documento**. Contadores de reações e de comentários são **calculados** por contagem indexada, exceto `downloadCount`, que usa `$inc` atômico.
- **Cópias de exibição** (`title`, `thumbUrl`) na biblioteca mantêm o item listado depois que a oferta expira ou o jogo é excluído.
- Documentos usam `createdAt` e `updatedAt` em UTC. Os índices são criados pelo código na partida.

### 3.2 `users`

| Campo                    | Tipo                  | Regras                                                               |
| ------------------------ | --------------------- | -------------------------------------------------------------------- |
| `_id`                    | ObjectId              |                                                                      |
| `username`               | string                | Único; 3 a 20 caracteres, `a-z`, `0-9` e `_`; guardado em minúsculas |
| `email`                  | string                | Único; formato válido; minúsculas                                    |
| `passwordHash`           | string                | argon2id em formato PHC; nunca sai da API                            |
| `roles`                  | `("player"\|"dev")[]` | Sempre contém `player`                                               |
| `displayName`            | string                | 1 a 40 caracteres; padrão = `username`                               |
| `bio`                    | string                | Até 280 caracteres                                                   |
| `avatarMediaId`          | ObjectId?             | Mídia `ready` do dono, finalidade `avatar`                           |
| `createdAt`, `updatedAt` | Date                  |                                                                      |

Índices: `{username}` único; `{email}` único.

### 3.3 `media`

| Campo                      | Tipo      | Regras                                                    |
| -------------------------- | --------- | --------------------------------------------------------- |
| `_id`                      | ObjectId  | É o `mediaId` na chave do S3                              |
| `ownerId`                  | ObjectId  |                                                           |
| `purpose`                  | enum      | `avatar`, `game-cover`, `game-image`, `comment-image`     |
| `refId`                    | ObjectId? | `gameId` para `game-cover` e `game-image`                 |
| `status`                   | enum      | `pending`, `ready`, `rejected`                            |
| `contentType`              | string    | `image/jpeg` ou `image/png`                               |
| `declaredSize`             | int       | Bytes declarados no pedido (até 5 242 880)                |
| `key`, `thumbKey`          | string?   | Chaves em `media/...` (só `ready`)                        |
| `width`, `height`          | int?      | Do resultado do processamento                             |
| `reason`                   | enum?     | `invalid_image`, `flagged`, `unavailable` (só `rejected`) |
| `createdAt`, `processedAt` | Date      |                                                           |

Índices: `{ownerId, purpose}`; `{status, createdAt}`; `{refId}`.

### 3.4 `games`

| Campo                                    | Tipo                 | Regras                                        |
| ---------------------------------------- | -------------------- | --------------------------------------------- |
| `_id`                                    | ObjectId             |                                               |
| `devId`                                  | ObjectId             | Usuário com papel `dev`                       |
| `title`, `titleLower`                    | string               | 3 a 80 caracteres; `titleLower` serve à busca |
| `description`                            | string               | Até 2000 caracteres                           |
| `genre`                                  | enum                 | Lista da seção 3.10                           |
| `coverMediaId`                           | ObjectId?            | Mídia `ready` `game-cover`                    |
| `imageMediaIds`                          | ObjectId[]           | Até 3, `ready`, `game-image`                  |
| `status`                                 | enum                 | `pending`, `published`, `rejected`            |
| `rejectReason`                           | enum?                | Igual a `media.reason`                        |
| `versions`                               | embutido (seção 3.5) |                                               |
| `currentVersionId`                       | ObjectId?            | Versão `ready` mais recente                   |
| `downloadCount`                          | int                  | `$inc` atômico                                |
| `createdAt`, `updatedAt`, `publishedAt?` | Date                 |                                               |

Índices: `{status, publishedAt}`; `{devId, createdAt}`; `{status, genre, publishedAt}`; `{titleLower}`.

### 3.5 `games.versions[]`

| Campo          | Tipo     | Regras                                     |
| -------------- | -------- | ------------------------------------------ |
| `versionId`    | ObjectId |                                            |
| `label`        | string   | 1 a 20 caracteres (por exemplo, `0.1.0`)   |
| `notes`        | string   | Até 1000 caracteres                        |
| `filename`     | string   | `.apk` ou `.zip`; nome limpo (sem caminho) |
| `declaredSize` | int      | Até 104 857 600 (100 MB)                   |
| `sizeBytes`    | int?     | Medido por `HeadObject` ao concluir        |
| `fileKey`      | string   | `games/{gameId}/{versionId}/{filename}`    |
| `status`       | enum     | `pending`, `ready`                         |
| `createdAt`    | Date     |                                            |

Limite de 20 versões por jogo.

### 3.6 `library`

| Campo                    | Tipo            | Regras                                                           |
| ------------------------ | --------------- | ---------------------------------------------------------------- |
| `_id`                    | ObjectId        |                                                                  |
| `userId`                 | ObjectId        |                                                                  |
| `itemKey`                | string          | `offer:{steamAppID}` ou `game:{gameId}`                          |
| `kind`, `refId`          | enum, string    | Derivados de `itemKey`                                           |
| `title`, `thumbUrl`      | string, string? | Cópias de exibição                                               |
| `status`                 | enum            | `wishlist`, `owned`, `playing`, `done`                           |
| `unavailable`            | bool            | `true` se o jogo foi excluído (ofertas expiradas **não** marcam) |
| `createdAt`, `updatedAt` | Date            |                                                                  |

Índices: `{userId, itemKey}` **único**; `{userId, status, updatedAt}`; `{itemKey}` (para marcar indisponíveis).

### 3.7 `reactions`, `comments`, `comment_likes`

**`reactions`**

| Campo                    | Tipo     | Regras              |
| ------------------------ | -------- | ------------------- |
| `userId`                 | ObjectId |                     |
| `itemKey`                | string   |                     |
| `value`                  | enum     | `like` ou `dislike` |
| `createdAt`, `updatedAt` | Date     |                     |

Índices: `{userId, itemKey}` **único**; `{itemKey, value}`.

**`comments`**

| Campo                    | Tipo       | Regras                                                   |
| ------------------------ | ---------- | -------------------------------------------------------- |
| `_id`                    | ObjectId   |                                                          |
| `authorId`               | ObjectId   |                                                          |
| `itemKey`                | string     |                                                          |
| `parentId`               | ObjectId?  | Nulo no comentário principal; um nível apenas            |
| `text`                   | string     | 1 a 1000 caracteres; vazio se `deleted`                  |
| `imageMediaIds`          | ObjectId[] | Até 3, `comment-image` `ready` (opcional, prioridade P3) |
| `deleted`                | bool       | `true` quando excluído mas com respostas                 |
| `createdAt`, `updatedAt` | Date       |                                                          |

Índices: `{itemKey, parentId, createdAt}`; `{parentId, createdAt}`; `{authorId}`.

**`comment_likes`**

| Campo       | Tipo     |
| ----------- | -------- |
| `userId`    | ObjectId |
| `commentId` | ObjectId |
| `createdAt` | Date     |

Índices: `{userId, commentId}` **único**; `{commentId}`.

### 3.8 DynamoDB `offers`

| Atributo                                                    | Tipo    | Origem na CheapShark                                    |
| ----------------------------------------------------------- | ------- | ------------------------------------------------------- |
| `steamAppID` (chave)                                        | S       | `steamAppID`                                            |
| `feed`                                                      | S       | Constante `steam`                                       |
| `title`                                                     | S       | `title`                                                 |
| `salePrice`, `normalPrice`                                  | N       | `salePrice`, `normalPrice` (texto convertido em número) |
| `savings`                                                   | N       | `savings` (percentual)                                  |
| `metacriticScore`                                           | N?      | `metacriticScore` (0 vira ausente)                      |
| `steamRatingText`, `steamRatingPercent`, `steamRatingCount` | S, N, N | Campos de mesmo nome                                    |
| `dealRating`                                                | N       | `dealRating`                                            |
| `thumb`                                                     | S       | `thumb`                                                 |
| `dealID`                                                    | S       | `dealID` (como veio, já codificado)                     |
| `lastChange`                                                | N       | `lastChange` (epoch)                                    |
| `runId`                                                     | S       | Identificador da execução (instante em epoch)           |
| `expiresAt`                                                 | N       | `runId` + 24 h (TTL)                                    |

- Índice `feed-rating`: partição `feed`, ordenação `dealRating`.
- Item-ponteiro: chave `META#steam`, atributos `runId`, `updatedAt`, `itemCount`.

### 3.9 Chaves do S3 (`app-data`)

| Chave                                                                          | Gravada por               |
| ------------------------------------------------------------------------------ | ------------------------- |
| `quarantine/{purpose}/{mediaId}`                                               | Navegador (POST assinado) |
| `media/{purpose}/{mediaId}.{jpg\|png}` e `media/{purpose}/{mediaId}_thumb.jpg` | Lambda de processamento   |
| `games/{gameId}/{versionId}/{filename}`                                        | Navegador (POST assinado) |
| `raw/offers/{AAAA-MM-DD}/{HHmm}.json`                                          | Lambda de ofertas         |
| `backups/mongo/{AAAA-MM-DD}.archive.gz`                                        | Instância do Mongo        |

URL pública da mídia: `/media/{purpose}/{mediaId}.{ext}` (servida pelo CloudFront).

### 3.10 Gêneros

`action`, `adventure`, `rpg`, `strategy`, `simulation`, `sports`, `racing`, `puzzle`, `platformer`, `horror`, `other`. O front traduz os rótulos.

## 4. API HTTP `/api/v1`

Total: 38 rotas (37 sob `/api/v1` e `GET /api/health`).

### 4.1 Schemas comuns

| Schema          | Campos                                                                                                                                                                                                                                                                                                  |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `SessionUser`   | `id`, `username`, `displayName`, `roles[]`, `avatarUrl?`                                                                                                                                                                                                                                                |
| `PublicProfile` | `username`, `displayName`, `bio`, `avatarUrl?`, `games` (lista de `GameCard`, só se tiver papel `dev`)                                                                                                                                                                                                  |
| `Media`         | `id`, `purpose`, `status`, `url?`, `thumbUrl?`, `reason?`                                                                                                                                                                                                                                               |
| `UploadTicket`  | `mediaId` ou `versionId`, `upload: { url, fields }`, `expiresAt` (seção 5)                                                                                                                                                                                                                              |
| `Offer`         | `steamAppID`, `title`, `currency` (`USD`), `salePrice`, `normalPrice`, `savingsPercent`, `metacriticScore?`, `steamRating { text, percent, count }`, `dealRating`, `thumbUrl`, `storeUrl`, `lastChange`                                                                                                 |
| `OffersPage`    | `Page<Offer>` mais `updatedAt` (da última execução) e `attribution` (`"Dados: CheapShark"`)                                                                                                                                                                                                             |
| `GameCard`      | `id`, `title`, `genre`, `coverUrl?`, `thumbUrl?`, `devUsername`, `downloadCount`, `likes`                                                                                                                                                                                                               |
| `Game`          | `id`, `title`, `description`, `genre`, `coverUrl?`, `imageUrls[]`, `dev { username, displayName, avatarUrl? }`, `currentVersion? { id, label, notes, sizeBytes, createdAt }`, `downloadCount`, `likes`, `dislikes`, `commentCount`, `createdAt`, `publishedAt?`; para o dono: `status`, `rejectReason?` |
| `GameVersion`   | `id`, `label`, `notes`, `filename`, `sizeBytes?`, `status`, `createdAt`                                                                                                                                                                                                                                 |
| `LibraryItem`   | `itemKey`, `kind`, `refId`, `title`, `thumbUrl?`, `status`, `unavailable`, `addedAt`                                                                                                                                                                                                                    |
| `ItemSummary`   | `itemKey`, `likes`, `dislikes`, `commentCount`, `myReaction?`, `inLibrary?` (os dois últimos só com sessão)                                                                                                                                                                                             |
| `Comment`       | `id`, `itemKey`, `parentId?`, `text` (nulo se `deleted`), `deleted`, `author { username, displayName, avatarUrl? }`, `imageUrls[]`, `likeCount`, `replyCount`, `likedByMe?`, `createdAt`, `updatedAt`                                                                                                   |

### 4.2 Autenticação e sessão (`auth`)

| Método e rota         | Acesso  | Corpo ou consulta                                         | Resposta                                  | Erros                                        | RF        |
| --------------------- | ------- | --------------------------------------------------------- | ----------------------------------------- | -------------------------------------------- | --------- |
| `POST /auth/register` | pública | `username`, `email`, `password` (8 a 72), `asDev?` (bool) | 201 `SessionUser` e `Set-Cookie`          | 400, 409 `username_taken`/`email_taken`, 429 | RF-AUT-01 |
| `POST /auth/login`    | pública | `login` (usuário ou e-mail), `password`                   | 200 `SessionUser` e `Set-Cookie`          | 401 `invalid_credentials`, 429               | RF-AUT-02 |
| `POST /auth/logout`   | sessão  | (vazio)                                                   | 204 e cookie expirado                     | 401                                          | RF-AUT-03 |
| `GET /auth/me`        | sessão  |                                                           | 200 `SessionUser`                         | 401                                          | RF-AUT-03 |
| `POST /auth/dev`      | sessão  | (vazio)                                                   | 200 `SessionUser` com `dev` e novo cookie | 401                                          | RF-AUT-04 |

### 4.3 Perfil (`users`)

| Método e rota           | Acesso  | Corpo ou consulta                                        | Resposta              | Erros                                                               | RF            |
| ----------------------- | ------- | -------------------------------------------------------- | --------------------- | ------------------------------------------------------------------- | ------------- |
| `GET /users/{username}` | pública |                                                          | 200 `PublicProfile`   | 404                                                                 | RF-PRF-03     |
| `PATCH /me`             | sessão  | `displayName?`, `bio?`, `avatarMediaId?` (`null` remove) | 200 `SessionUser`     | 400, 404 (mídia não é sua), 409 `invalid_state` (mídia não `ready`) | RF-PRF-01, 02 |
| `DELETE /me`            | sessão  | (vazio)                                                  | 204 e cookie expirado | 401                                                                 | RF-AUT-05     |

### 4.4 Mídia (`media`)

| Método e rota         | Acesso        | Corpo ou consulta                                                                                                                    | Resposta           | Erros         | RF                   |
| --------------------- | ------------- | ------------------------------------------------------------------------------------------------------------------------------------ | ------------------ | ------------- | -------------------- |
| `POST /media/uploads` | sessão        | `purpose`, `contentType`, `sizeBytes`, `gameId?` (obrigatório em `game-cover` e `game-image`; o usuário deve ser o dev dono do jogo) | 201 `UploadTicket` | 400, 403, 404 | RF-PRF-02, RF-JOG-02 |
| `GET /media/{id}`     | sessão (dono) |                                                                                                                                      | 200 `Media`        | 404           | RF-MID-02            |

Limites e regras de aceitação da imagem: seção 5.1.

### 4.5 Ofertas (`offers`)

| Método e rota              | Acesso  | Corpo ou consulta                                            | Resposta         | Erros                    | RF            |
| -------------------------- | ------- | ------------------------------------------------------------ | ---------------- | ------------------------ | ------------- |
| `GET /offers`              | pública | `sort` (`rating`, padrão, ou `discount`), `page`, `pageSize` | 200 `OffersPage` | 503 `offers_unavailable` | RF-OFE-03, 05 |
| `GET /offers/{steamAppID}` | pública |                                                              | 200 `Offer`      | 404                      | RF-OFE-04     |

`storeUrl` = `https://www.cheapshark.com/redirect?dealID={dealID}`. A lista usa o ponteiro da última execução completa.

### 4.6 Jogos da comunidade (`games`)

| Método e rota                                    | Acesso      | Corpo ou consulta                          | Resposta                                           | Erros                                                           | RF                |
| ------------------------------------------------ | ----------- | ------------------------------------------ | -------------------------------------------------- | --------------------------------------------------------------- | ----------------- |
| `GET /games`                                     | pública     | `q?`, `genre?`, `page`, `pageSize`         | 200 `Page<GameCard>` (só `published`)              | 400                                                             | RF-JOG-08         |
| `GET /games/{id}`                                | pública     |                                            | 200 `Game` (`pending` e `rejected` só para o dono) | 404                                                             | RF-JOG-09         |
| `POST /games`                                    | papel `dev` | `title`, `description`, `genre`            | 201 `Game` com `status: pending`                   | 400, 403                                                        | RF-JOG-01         |
| `PATCH /games/{id}`                              | dev dono    | `title?`, `description?`, `genre?`         | 200 `Game`                                         | 400, 403, 404                                                   | RF-JOG-04         |
| `DELETE /games/{id}/images/{mediaId}`            | dev dono    |                                            | 204                                                | 403, 404                                                        | RF-JOG-04         |
| `DELETE /games/{id}`                             | dev dono    |                                            | 204                                                | 403, 404                                                        | RF-JOG-06         |
| `GET /me/games`                                  | papel `dev` | `page`, `pageSize`                         | 200 `Page<Game>` (com `status`)                    | 403                                                             | RF-JOG-07         |
| `POST /games/{id}/versions`                      | dev dono    | `label`, `notes?`, `filename`, `sizeBytes` | 201 `UploadTicket` (com `versionId`)               | 400, 403, 404, 409 (limite de versões)                          | RF-JOG-01, 02, 05 |
| `POST /games/{id}/versions/{versionId}/complete` | dev dono    | (vazio)                                    | 200 `GameVersion` com `status: ready`              | 404, 409 `invalid_state` (arquivo ausente ou tamanho diferente) | RF-JOG-05         |
| `GET /games/{id}/versions`                       | dev dono    |                                            | 200 `GameVersion[]` (mais novas primeiro)          | 403, 404                                                        | RF-JOG-05         |
| `POST /games/{id}/download`                      | sessão      | (vazio)                                    | 200 `{ url, expiresAt, filename, sizeBytes }`      | 403 `not_in_library`, 404 `game_not_available`                  | RF-JOG-10         |

Regras: o dono só altera os **seus** jogos; o gênero pertence à lista da seção 3.10; o download soma 1 em `downloadCount` a cada pedido bem-sucedido.

### 4.7 Biblioteca (`library`)

| Método e rota                     | Acesso | Corpo ou consulta                                          | Resposta                             | Erros                                           | RF                |
| --------------------------------- | ------ | ---------------------------------------------------------- | ------------------------------------ | ----------------------------------------------- | ----------------- |
| `GET /library`                    | sessão | `status?`, `kind?` (`offer` ou `game`), `page`, `pageSize` | 200 `Page<LibraryItem>`              | 400                                             | RF-BIB-03         |
| `PUT /library/items/{itemKey}`    | sessão | `status`                                                   | 200 `LibraryItem` (cria ou atualiza) | 400, 404 (oferta ausente ou jogo não publicado) | RF-BIB-01, 02, 04 |
| `DELETE /library/items/{itemKey}` | sessão |                                                            | 204 (mesmo se já ausente)            |                                                 | RF-BIB-02         |

### 4.8 Reações e comentários (`reactions`, `comments`)

| Método e rota                      | Acesso  | Corpo ou consulta                                            | Resposta                                                 | Erros                                | RF            |
| ---------------------------------- | ------- | ------------------------------------------------------------ | -------------------------------------------------------- | ------------------------------------ | ------------- |
| `GET /items/{itemKey}/summary`     | pública |                                                              | 200 `ItemSummary`                                        | 404                                  | RF-OPI-04     |
| `PUT /items/{itemKey}/reaction`    | sessão  | `value` (`like` ou `dislike`)                                | 200 `ItemSummary`                                        | 400, 404                             | RF-OPI-01     |
| `DELETE /items/{itemKey}/reaction` | sessão  |                                                              | 200 `ItemSummary`                                        | 404                                  | RF-OPI-01     |
| `GET /items/{itemKey}/comments`    | pública | `page`, `pageSize` (principais, do mais novo ao mais antigo) | 200 `Page<Comment>`                                      | 404                                  | RF-OPI-03     |
| `POST /items/{itemKey}/comments`   | sessão  | `text`, `imageMediaIds?`                                     | 201 `Comment`                                            | 400, 404                             | RF-OPI-02, 05 |
| `GET /comments/{id}/replies`       | pública | `page`, `pageSize` (do mais antigo ao mais novo)             | 200 `Page<Comment>`                                      | 404                                  | RF-OPI-07     |
| `POST /comments/{id}/replies`      | sessão  | `text`                                                       | 201 `Comment`                                            | 400, 404, 409 `reply_depth_exceeded` | RF-OPI-07     |
| `PATCH /comments/{id}`             | autor   | `text`                                                       | 200 `Comment`                                            | 400, 403, 404                        | RF-OPI-02     |
| `DELETE /comments/{id}`            | autor   |                                                              | 204 (com respostas: vira `deleted`; sem respostas: some) | 403, 404                             | RF-OPI-02, 07 |
| `PUT /comments/{id}/like`          | sessão  |                                                              | 200 `Comment`                                            | 404                                  | RF-OPI-06     |
| `DELETE /comments/{id}/like`       | sessão  |                                                              | 200 `Comment`                                            | 404                                  | RF-OPI-06     |

`itemKey` inexistente (oferta expirada que ainda não está na biblioteca, ou jogo não publicado) devolve `404`.

### 4.9 Operação (`health`)

| Método e rota     | Acesso  | Resposta                                                              | RF        |
| ----------------- | ------- | --------------------------------------------------------------------- | --------- |
| `GET /api/health` | pública | 200 `{ status: "ok" }` ou 503 `{ status: "degraded", mongo: "down" }` | RF-OPS-01 |

## 5. Envio de arquivos

### 5.1 Imagens (`POST /media/uploads`)

| Finalidade      | Dono             | Regras                                                                                |
| --------------- | ---------------- | ------------------------------------------------------------------------------------- |
| `avatar`        | Qualquer usuário | Um avatar `ready` por vez; o novo substitui o anterior ao ser aplicado em `PATCH /me` |
| `game-cover`    | Dev dono do jogo | Uma capa; a nova `ready` substitui a anterior                                         |
| `game-image`    | Dev dono do jogo | Até 3; excedente: `409 invalid_state`                                                 |
| `comment-image` | Autor            | Até 3 por comentário (prioridade P3)                                                  |

Aceite: `contentType` `image/jpeg` ou `image/png`; `sizeBytes` de 1 a 5 242 880.

Exemplo de resposta (`UploadTicket`):

```json
{
  "mediaId": "6730c0a1f0d898f00ceae98d",
  "upload": {
    "url": "https://<bucket>.s3.amazonaws.com/",
    "fields": {
      "key": "quarantine/avatar/6730c0a1f0d898f00ceae98d",
      "Content-Type": "image/png",
      "policy": "...",
      "x-amz-signature": "...",
      "x-amz-credential": "...",
      "x-amz-algorithm": "...",
      "x-amz-date": "..."
    }
  },
  "expiresAt": "<ISO 8601 UTC, 10 minutos após a emissão>"
}
```

O navegador envia um `POST` multipart com esses campos e o arquivo. A política impõe `key`, `Content-Type` e `content-length-range` (1 a 5 242 880). O endereço real do bucket depende do ambiente. A URL vale 10 minutos.

### 5.2 Builds (`POST /games/{id}/versions`)

Mesmo mecanismo, com `key` = `games/{gameId}/{versionId}/{filename}`, `Content-Type` `application/octet-stream` ou o tipo declarado, e `content-length-range` de 1 a 104 857 600. O envio não passa pela Lambda: o dono chama `complete`, e a API confere com `HeadObject` que o objeto existe e mede o tamanho.

### 5.3 Download (`POST /games/{id}/download`)

A URL de leitura vale **5 minutos** e força o nome do arquivo (`Content-Disposition`).

## 6. Eventos e mensagens

### 6.1 Evento do S3 para a Lambda `media-processing`

Evento `ObjectCreated:Post` com filtro de prefixo `quarantine/`. A função usa `Records[0].s3.bucket.name` e `Records[0].s3.object.key` (decodificada de URL), extrai `purpose` e `mediaId` da chave e ignora chaves fora do padrão.

### 6.2 Mensagem de resultado (SQS `moderation-results`)

```json
{
  "schemaVersion": 1,
  "mediaId": "6730c0a1f0d898f00ceae98d",
  "purpose": "avatar",
  "outcome": "ready",
  "reason": null,
  "key": "media/avatar/6730c0a1f0d898f00ceae98d.png",
  "thumbKey": "media/avatar/6730c0a1f0d898f00ceae98d_thumb.jpg",
  "width": 512,
  "height": 512,
  "processedAt": "<ISO 8601 UTC>"
}
```

| Campo                | Tipo                  | Regras                                        |
| -------------------- | --------------------- | --------------------------------------------- |
| `schemaVersion`      | int                   | 1                                             |
| `mediaId`, `purpose` | string                | Os da chave da quarentena                     |
| `outcome`            | `ready` ou `rejected` |                                               |
| `reason`             | string ou nulo        | `invalid_image` ou `flagged`; nulo se `ready` |
| `key`, `thumbKey`    | string                | Só em `ready`                                 |
| `width`, `height`    | int                   | Só em `ready`                                 |
| `processedAt`        | string                | ISO 8601 UTC                                  |

O JSON Schema formal fica em `docs/contracts/media-result.schema.json`, validado pela função (produtora) e pela API (consumidora), com teste de contrato.

**Efeitos na API:** a mensagem só é aplicada se `media.status` for `pending` (idempotente); a API atualiza a mídia e, se a finalidade for `game-cover` ou `game-image`, recalcula o estado do jogo (seção 7.2).

### 6.3 Mídia sem resposta

Uma tarefa periódica da API marca como `rejected`, com `reason: unavailable`, toda mídia `pending` há mais de **15 minutos**. Mensagens que a API não consegue processar vão à DLQ após 3 recebimentos (RF-MID-03).

### 6.4 Lambda `offers-ingest`

- **Entrada:** evento agendado do EventBridge ou invocação manual (`{ "trigger": "manual" }`).
- **Consulta à CheapShark:** `GET /api/1.0/deals?storeID=1&pageSize=30&sortBy=Deal Rating&onSale=1`, com `User-Agent` do projeto.
- **Descartes:** itens sem `steamAppID`.
- **Saída:** `raw/offers/...json` (corpo cru), itens do DynamoDB (seção 3.8) e o ponteiro atualizado **por último**.
- **Registro:** um log JSON com `runId`, itens lidos, itens gravados e duração.

## 7. Estados e regras de negócio

### 7.1 Mídia

`pending` → `ready` ou `rejected`. Não há retorno de estado: uma nova imagem é uma **nova** mídia.

### 7.2 Jogo

| De          | Para        | Condição                                                                                                      |
| ----------- | ----------- | ------------------------------------------------------------------------------------------------------------- |
| (criação)   | `pending`   | `POST /games`                                                                                                 |
| `pending`   | `published` | Capa `ready`, nenhuma imagem `pending` ou `rejected`, e ao menos uma versão `ready`                           |
| `pending`   | `rejected`  | Alguma imagem `rejected` (com `rejectReason`)                                                                 |
| `published` | `pending`   | O dono envia uma imagem nova (ela precisa passar pelo processamento); o jogo some do catálogo até a conclusão |
| `rejected`  | `pending`   | O dono remove a imagem rejeitada ou envia outra                                                               |

A reavaliação ocorre a cada resultado de mídia, a cada `complete` de versão e a cada remoção de imagem.

### 7.3 Versão

`pending` → `ready` ao `complete`. `currentVersionId` aponta para a versão `ready` mais recente.

### 7.4 Regras de negócio

| Regra                                                                                                                                             | Onde vale                         |
| ------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------- |
| Um item aparece uma só vez por usuário na biblioteca                                                                                              | Índice único; `PUT` é idempotente |
| Um voto por usuário e item                                                                                                                        | Índice único em `reactions`       |
| Resposta só a comentário principal                                                                                                                | `reply_depth_exceeded`            |
| Excluir jogo: apaga objetos do S3 e marca `unavailable` nas bibliotecas                                                                           | RF-JOG-06                         |
| Excluir conta: apaga `users`, `library`, `reactions`, `comment_likes`, `comments` do usuário, `media` e objetos; jogos do dev são excluídos antes | RF-AUT-05; tarefa reexecutável    |
| Download exige jogo publicado e presente na biblioteca (qualquer estado)                                                                          | RF-JOG-10                         |
| Só o dono vê jogos `pending` ou `rejected`                                                                                                        | `GET /games/{id}`                 |

## 8. Matriz de requisitos para rotas

Requisitos de prioridade P1 e P2.

| Requisito      | Rotas                                                                                                |
| -------------- | ---------------------------------------------------------------------------------------------------- |
| RF-AUT-01 a 05 | `POST /auth/register`, `/auth/login`, `/auth/logout`, `GET /auth/me`, `POST /auth/dev`, `DELETE /me` |
| RF-PRF-01 a 03 | `PATCH /me`, `GET /users/{username}`, `POST /media/uploads`, `GET /media/{id}`                       |
| RF-MID-01 a 03 | `POST /media/uploads`, `GET /media/{id}`, mensagem de resultado, tarefa de mídia vencida             |
| RF-OFE-01 a 06 | Lambda `offers-ingest`; `GET /offers`, `GET /offers/{steamAppID}`                                    |
| RF-JOG-01 a 10 | `POST/GET/PATCH/DELETE /games…`, `GET /me/games`, `…/versions…`, `POST /games/{id}/download`         |
| RF-BIB-01 a 04 | `GET /library`, `PUT` e `DELETE /library/items/{itemKey}`                                            |
| RF-OPI-01 a 07 | `…/items/{itemKey}/summary`, `…/reaction`, `…/comments`, `/comments/{id}…`                           |
| RF-OPS-01      | `GET /api/health`                                                                                    |

## 9. Valores padrão e limites

| Item                 | Valor                                                                    |
| -------------------- | ------------------------------------------------------------------------ |
| Download             | Permitido em qualquer estado da biblioteca (inclusive `wishlist`)        |
| Login                | Por usuário ou por e-mail                                                |
| Exclusão de conta    | Exige apenas a sessão (sem confirmação de senha)                         |
| Mídia sem resposta   | Após 15 minutos em `pending`, vira `rejected` com `reason: unavailable`  |
| Gêneros              | Lista da seção 3.10                                                      |
| Criação de jogo      | Sem mídia; capa e imagens são enviadas depois, com `gameId`              |
| Publicação de jogo   | Exige ao menos uma versão `ready` (arquivo de build enviado e concluído) |
| Versões por jogo     | Até 20                                                                   |
| Imagens por jogo     | Até 3, além da capa                                                      |
| Perfil               | Sem banner                                                               |
| Taxa de requisições  | Cadastro e login: 10 por minuto por IP; demais: 120 por minuto por IP    |
| Sessão               | JWT de 1 h                                                               |
| Tamanho de imagem    | 1 a 5 242 880 bytes (JPEG ou PNG)                                        |
| Tamanho de build     | 1 a 104 857 600 bytes (`.apk` ou `.zip`)                                 |
| URL de envio         | Vale 10 minutos                                                          |
| URL de download      | Vale 5 minutos                                                           |
| Paginação            | `pageSize` de 1 a 50; padrão 20                                          |
| Expiração de ofertas | 24 h a partir de `runId` (TTL do DynamoDB)                               |
