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
