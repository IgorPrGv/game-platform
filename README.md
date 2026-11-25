# game-platform

Plataforma Distribuída de Jogos, projeto de Desenvolvimento de Aplicações Distribuídas.

Desenvolvedores publicam jogos; jogadores montam a biblioteca, reagem e comentam; ofertas de jogos vêm de uma API externa. Roda na AWS (CloudFront, S3, EC2, Lambda, DynamoDB, SQS), provisionada com Terraform.

## Estrutura

| Pasta        | Conteúdo                                     |
| ------------ | -------------------------------------------- |
| `api/`       | NestJS (TypeScript)                          |
| `web/`       | React + Vite                                 |
| `functions/` | Lambdas `offers-ingest` e `media-processing` |
| `infra/`     | Terraform                                    |
| `docs/`      | Arquitetura, requisitos e contratos          |
| `scripts/`   | Scripts operacionais                         |

## Começando

```
npm ci
```

## Ambiente local

Precisa de Docker com Compose. Sobe o MongoDB e os emuladores da AWS:

```
cp .env.example .env
npm run local:up
```

| Serviço    | Emula                | Endereço                |
| ---------- | -------------------- | ----------------------- |
| `mongo`    | MongoDB 8.0          | `localhost:27017`       |
| `s3`       | S3 (SeaweedFS)       | `http://localhost:8333` |
| `dynamodb` | DynamoDB Local       | `http://localhost:8000` |
| `sqs`      | SQS (ElasticMQ)      | `http://localhost:9324` |
| `init`     | Cria bucket e tabela | roda uma vez e sai      |

O serviço `init` cria o bucket `app-data` com CORS para `http://localhost:5173` e a tabela `offers` com o índice `feed-rating` e TTL em `expiresAt`. As filas `moderation-results`, `moderation-results-dlq` (após 3 recebimentos) e `media-processing-dlq` vêm de `infra/local/elasticmq.conf`. Os endereços e credenciais estão no `.env.example`.

| Comando               | Efeito                                |
| --------------------- | ------------------------------------- |
| `npm run local:up`    | Sobe e espera todos ficarem saudáveis |
| `npm run local:down`  | Para, mantendo os dados               |
| `npm run local:reset` | Para e apaga os dados (volumes)       |
| `npm run local:logs`  | Acompanha os logs                     |

Os dados ficam em volumes nomeados e as portas abrem só em `127.0.0.1`.
