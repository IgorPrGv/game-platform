# Plano de construção

Como o trabalho se divide em tarefas, branches e fatias, e em que ordem é entregue. Parte da [Arquitetura de nuvem](02-arquitetura-nuvem.md), da [Arquitetura de software](03-arquitetura-software.md), dos [Contratos e dados](04-contratos-e-dados.md) e dos [Requisitos](01-requisitos.md). O fluxo de Git (commits, PRs, revisão, integração) está em [Como contribuir](06-como-contribuir.md) e não se repete aqui.

## Siglas

| Sigla             | Significado                                                                     |
| ----------------- | ------------------------------------------------------------------------------- |
| T-nn              | Tarefa numerada                                                                 |
| PR-xx             | Pull request previsto: PR-O (ops), PR-A (api), PR-F (functions), PR-W (web)     |
| E0                | Esqueleto andante: fatia mínima que atravessa todas as camadas e já roda na AWS |
| MVP               | Todos os requisitos de prioridade P1                                            |
| Faixa A, B, C, D  | Prioridade das tarefas: A núcleo, B resto do MVP, C prioridade P2, D extras     |
| `develop`, `main` | Branch principal de trabalho e branch estável                                   |

## 1. Visão geral

Ordem de entrega: fundação, esqueleto andante (E0), jogos do desenvolvedor e download, biblioteca, reações e comentários, completar, entrega.

Marcos, em ordem: **Esqueleto andante (E0)**, **MVP**, **Completo**, **Entrega**. Nenhum marco tem data neste documento.

As estimativas são em dias de trabalho de uma pessoa e **não são calibradas**. Totais por faixa: A 31,5, B 14,4, C 7,6, D 3. Se faltar tempo, corta-se pela ponta (seção 6), sem refazer nada.

## 2. Responsáveis e carga

Cada pasta do monorepo tem um só dono. O dono do repositório revisa e integra todos os PRs.

| Pessoa   | Responsabilidade                                                                                                                                                         |
| -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Igor** | Figma; repositório e infraestrutura de base (estrutura, Compose, CI, Terraform de rede, dados, computação e entrada, roteiro de demonstração); `web/`                    |
| **Luis** | `api/` inteira; `functions/`; Terraform das funções (`infra/modules/serverless`) e da observabilidade (`infra/modules/observability`); `scripts/`; dados de demonstração |

Branches e donos (detalhes em [Como contribuir](06-como-contribuir.md)):

| Branch              | Pasta                                                                                | Dono |
| ------------------- | ------------------------------------------------------------------------------------ | ---- |
| `feature/ops`       | repositório, Compose, CI, Terraform (rede, dados, computação e entrada), `docs/`     | Igor |
| `feature/web`       | `web/`                                                                               | Igor |
| `feature/api`       | `api/` e `docs/contracts/`                                                           | Luis |
| `feature/functions` | `functions/`, `infra/modules/serverless`, `infra/modules/observability` e `scripts/` | Luis |

Carga estimada (dias de uma pessoa, faixas A a C, somando a coluna Dias da seção 4):

| Item                                  | Igor | Luis |
| ------------------------------------- | ---- | ---- |
| `web/`                                | 13,5 | -    |
| `api/`                                | -    | 18   |
| `functions/`                          | -    | 3,5  |
| Infraestrutura e operação             | 8    | 3,5  |
| Figma                                 | 6    | -    |
| Endurecimento (T36, metade para cada) | 0,5  | 0,5  |
| **Total**                             | 28   | 25,5 |

Composição da infraestrutura: Igor T01 a T04, T08, T10, T35 (8 dias); Luis T09, T11, T12, T34 (3,5 dias). Os extras da faixa D (T37, 3 dias) ficam fora do total e são divididos conforme a pasta.

Totais por faixa e por dono (dias):

| Faixa | Igor | Luis | Total |
| ----- | ---- | ---- | ----- |
| A     | 17,5 | 14   | 31,5  |
| B     | 8,2  | 6,2  | 14,4  |
| C     | 2,3  | 5,3  | 7,6   |
| D     | -    | -    | 3     |

A faixa B inclui as duas metades de T36 (0,5 para cada).

Ordem natural: o dono do repositório começa pelo repositório (PR-O1) e pelo Figma; o dono da API começa pelo esqueleto e pelo contrato (T05, T06) e pelas Lambdas (T13 só depende do Compose). O `web/` entra quando o contrato (T06) e os tokens do Figma existirem, e já funciona com o contrato simulado.

## 3. Fatias

| Fatia                         | Entrega                                                                                                                                                                            | Pronto quando                                                              |
| ----------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------- |
| **S0 Fundação**               | Repositório, Compose, CI, relatório da AWS                                                                                                                                         | `docker compose up` sobe tudo; CI verde; relatório com cada item e plano B |
| **S1 Esqueleto andante (E0)** | Na AWS, pelo CloudFront: cadastro e login por cookie; avatar (S3, Lambda, fila, API, imagem pronta); lista de ofertas (EventBridge, Lambda, DynamoDB, API, tela); Terraform mínimo | O roteiro funciona sem intervenção                                         |
| **S2 Jogos**                  | Criar jogo, enviar capa, imagens e build, publicação automática, catálogo, detalhe, "meus jogos", download                                                                         | RF-JOG-01 a 03 e 07 a 10                                                   |
| **S3 Biblioteca e social**    | Biblioteca, reações, comentários                                                                                                                                                   | MVP                                                                        |
| **S4 Completar**              | Faixa C que couber, painel e alarmes, script de ligar, restauração testada                                                                                                         | Completo                                                                   |
| **S5 Entrega**                | Segurança revisada, dados de demonstração, roteiro e ensaio                                                                                                                        | Entrega                                                                    |

## 4. Tarefas

Estimativas em dias de uma pessoa, não calibradas. Cada tarefa corresponde a uma issue do repositório.

| ID   | Tarefa                                                                                 | Dono        | Branch           | Dias          | Faixa | Depende de           | Pronto quando                                    |
| ---- | -------------------------------------------------------------------------------------- | ----------- | ---------------- | ------------- | ----- | -------------------- | ------------------------------------------------ |
| T01  | Criar o repositório: pastas, README, `.env.example`, lint, formato, commitlint         | Igor        | ops              | 0,5           | A     | -                    | PR de exemplo passa nos verificadores            |
| T02  | Docker Compose (Mongo 8.0, SeaweedFS, DynamoDB Local, ElasticMQ)                       | Igor        | ops              | 1             | A     | T01                  | Healthchecks verdes                              |
| T03  | CI: lint, tipos, testes, build, deriva do `openapi.json`                               | Igor        | ops              | 0,5           | A     | T01                  | PR bloqueado se falhar                           |
| T04  | Teste do 1º dia na AWS e validações S1 a S7                                            | Igor        | ops              | 1             | A     | acesso à AWS         | Relatório com plano B por item                   |
| T05  | Esqueleto da API (módulos, configuração, erros, logs, guardas, `/api/health`)          | Luis        | api              | 1,5           | A     | T01                  | Responde `/api/health` local                     |
| T06  | Schemas Zod e controllers esboço das 38 rotas; `openapi.json`; JSON Schema da mensagem | Luis        | api              | 1,5           | A     | T05                  | CI confere o `openapi.json`                      |
| T07  | Cliente do front: tipos gerados e simulações (MSW)                                     | Igor        | web              | 0,5           | A     | T06                  | Front chama o contrato simulado                  |
| T08  | Terraform `network` e `data`                                                           | Igor        | ops              | 1,5           | A     | T04                  | `apply` e `destroy` limpos                       |
| T09  | Terraform `serverless`                                                                 | Luis        | functions        | 1             | A     | T08, T13, T14        | Funções disparáveis                              |
| T10  | Terraform `compute` e `edge`                                                           | Igor        | ops              | 2             | A     | T08                  | Site e API pelo CloudFront                       |
| T11  | Terraform `observability`                                                              | Luis        | functions        | 1             | C     | T10                  | Alarme provocado e recebido                      |
| T12  | Scripts: ligar o ambiente, implantar API e web, testar restauração                     | Luis        | functions        | 1             | C     | T10                  | Executados do zero                               |
| T13  | Lambda `offers-ingest`                                                                 | Luis        | functions        | 1,5           | A     | T02                  | Ofertas no DynamoDB e bruto no S3                |
| T14  | Lambda `media-processing`                                                              | Luis        | functions        | 2             | A     | T02, T06             | Evento sintético gera `media/` e mensagem válida |
| T15  | API: cadastro, login, logout, `me`                                                     | Luis        | api              | 1,5           | A     | T06                  | RF-AUT-01 a 03                                   |
| T15b | API: perfil público, habilitar Dev, excluir conta                                      | Luis        | api              | 1             | C     | T15                  | RF-AUT-04, 05; RF-PRF-01, 03                     |
| T16  | API: mídia (pedido, estado, consumidor, tarefa de mídia vencida)                       | Luis        | api              | 2             | A     | T14, T15             | RF-PRF-02; RF-MID-01 a 03                        |
| T17  | API: ofertas                                                                           | Luis        | api              | 1             | A     | T13                  | RF-OFE-03 a 05                                   |
| T18a | API: jogos (criar, catálogo, detalhe, "meus jogos", versões, publicação, download)     | Luis        | api              | 2,5           | B     | T16                  | RF-JOG-01 a 03, 07 a 10                          |
| T18b | API: editar, excluir, remover imagem, listar versões                                   | Luis        | api              | 1             | C     | T18a                 | RF-JOG-04 a 06                                   |
| T19  | API: biblioteca                                                                        | Luis        | api              | 1             | B     | T17, T18a            | RF-BIB-01 a 04                                   |
| T20  | API: reações e resumo do item                                                          | Luis        | api              | 1             | B     | T18a                 | RF-OPI-01, 04                                    |
| T21a | API: comentários (listar, criar, editar, excluir)                                      | Luis        | api              | 1,2           | B     | T20                  | RF-OPI-02, 03                                    |
| T21b | API: respostas e curtidas de comentário                                                | Luis        | api              | 0,8           | C     | T21a                 | RF-OPI-06, 07                                    |
| T22  | API: exclusão de conta (apagadores por módulo)                                         | Luis        | api              | 0,5           | C     | T15b e módulos       | RF-AUT-05                                        |
| T23  | Web: fundação (rotas, sessão, tema com os tokens, cliente, erros, layout)              | Igor        | web              | 1,5           | A     | T07, tokens do Figma | Shell navegável                                  |
| T24  | Web: cadastro e login                                                                  | Igor        | web              | 1             | A     | T23                  | RF-AUT-01, 02                                    |
| T25  | Web: ofertas                                                                           | Igor        | web              | 1             | A     | T23                  | RF-OFE-03, 04                                    |
| T26  | Web: perfil e envio de avatar                                                          | Igor        | web              | 1,5           | A     | T23, T16             | RF-PRF-01, 02                                    |
| T27  | Web: catálogo, detalhe e download                                                      | Igor        | web              | 1,5           | B     | T23, T18a            | RF-JOG-08 a 10                                   |
| T28a | Web: painel do Dev (criar, enviar capa, imagens e build, estado)                       | Igor        | web              | 2             | B     | T26, T18a            | RF-JOG-01 a 03, 07                               |
| T28b | Web: editar jogo e versões                                                             | Igor        | web              | 0,5           | C     | T28a                 | RF-JOG-04, 05                                    |
| T29  | Web: biblioteca                                                                        | Igor        | web              | 1             | B     | T19                  | RF-BIB-01 a 04                                   |
| T30a | Web: reações e comentários                                                             | Igor        | web              | 1,2           | B     | T20, T21a            | RF-OPI-01 a 04                                   |
| T30b | Web: respostas e curtidas                                                              | Igor        | web              | 0,8           | C     | T21b                 | RF-OPI-06, 07                                    |
| T31  | Web: carregamento, vazio e erro; responsivo; acessibilidade                            | Igor        | web              | 1             | C     | telas                | RNF-USA-01, 02                                   |
| T32a | Figma: jornadas, fluxos, componentes, tokens e telas do núcleo                         | Igor        | (Figma)          | 4             | A     | requisitos           | Tokens e telas A                                 |
| T32b | Figma: telas restantes                                                                 | Igor        | (Figma)          | 2             | B     | T32a                 | Telas do catálogo ao painel do Dev               |
| T33  | Testes ponta a ponta da API                                                            | Luis        | api              | 1,5           | A     | funcionalidades      | Verdes no CI                                     |
| T34  | Dados de demonstração e script                                                         | Luis        | functions        | 0,5           | A     | S2                   | Ambiente reproduzível                            |
| T35  | Roteiro de demonstração e slides                                                       | Igor        | ops              | 1,5           | A     | MVP                  | Ensaio completo                                  |
| T36  | Endurecimento: lista de segurança e revisão cruzada                                    | Igor e Luis | cada branch      | 1 (0,5 + 0,5) | B     | MVP                  | Itens resolvidos                                 |
| T37  | Extras: ALB com Auto Scaling, SHA-256 do build, moderação com Rekognition              | Igor e Luis | conforme a pasta | 3             | D     | MVP                  | Escopo definido no MVP                           |

## 5. Branches e PRs

Os PRs seguem a ordem de cada branch; a coluna "Depois de" mostra as dependências entre branches.

### `feature/ops` (Igor)

| PR    | Tarefas  | Conteúdo                                                                             | Depois de           |
| ----- | -------- | ------------------------------------------------------------------------------------ | ------------------- |
| PR-O1 | T01, T03 | Estrutura do repositório, lint, formato, commitlint e CI                             | (primeiro de todos) |
| PR-O2 | T02      | Docker Compose local                                                                 | PR-O1               |
| PR-O3 | T04      | Relatório do teste do 1º dia na AWS e das validações S1 a S7 (`docs/validations.md`) | PR-O1               |
| PR-O4 | T08      | Terraform `network` e `data`                                                         | PR-O3               |
| PR-O5 | T10      | Terraform `compute` e `edge`                                                         | PR-O4               |
| PR-O6 | T35      | Roteiro de demonstração e slides                                                     | MVP                 |

### `feature/api` (Luis)

| PR     | Tarefas               | Conteúdo                                                                              | Depois de    |
| ------ | --------------------- | ------------------------------------------------------------------------------------- | ------------ |
| PR-A1  | T05                   | Esqueleto da API                                                                      | PR-O1        |
| PR-A2  | T06                   | Schemas Zod, controllers esboço das 38 rotas, `openapi.json`, JSON Schema da mensagem | PR-A1        |
| PR-A3  | T15                   | Cadastro, login, logout, `me`                                                         | PR-A2        |
| PR-A4  | T16                   | Mídia: pedido de envio, estado, consumidor da fila                                    | PR-A3, PR-F2 |
| PR-A5  | T17                   | Ofertas                                                                               | PR-A2, PR-F1 |
| PR-A6  | T18a                  | Jogos: criar, catálogo, detalhe, versões, publicação, download                        | PR-A4        |
| PR-A7  | T19                   | Biblioteca                                                                            | PR-A5, PR-A6 |
| PR-A8  | T20                   | Reações                                                                               | PR-A6        |
| PR-A9  | T21a                  | Comentários                                                                           | PR-A8        |
| PR-A10 | T33                   | Testes ponta a ponta dos fluxos críticos                                              | PR-A9        |
| PR-A11 | T15b, T18b, T21b, T22 | Faixa C da API                                                                        | PR-A9        |

### `feature/functions` (Luis)

| PR    | Tarefas | Conteúdo                                                              | Depois de                              |
| ----- | ------- | --------------------------------------------------------------------- | -------------------------------------- |
| PR-F1 | T13     | Lambda `offers-ingest`                                                | PR-O2                                  |
| PR-F2 | T14     | Lambda `media-processing`                                             | PR-O2, PR-A2 (JSON Schema da mensagem) |
| PR-F3 | T09     | Terraform `serverless` (`infra/modules/serverless`)                   | PR-O4, PR-F1, PR-F2                    |
| PR-F4 | T11     | Terraform `observability` (`infra/modules/observability`)             | PR-O5                                  |
| PR-F5 | T12     | Scripts: ligar o ambiente, implantar, testar restauração (`scripts/`) | PR-O5                                  |
| PR-F6 | T34     | Dados de demonstração e script (`scripts/`)                           | MVP                                    |

### `feature/web` (Igor)

| PR    | Tarefas         | Conteúdo                                       | Depois de                |
| ----- | --------------- | ---------------------------------------------- | ------------------------ |
| PR-W1 | T07, T23        | Cliente gerado, simulações e fundação do front | PR-A2, tokens do Figma   |
| PR-W2 | T24             | Telas de cadastro e login                      | PR-W1 (com a API: PR-A3) |
| PR-W3 | T25             | Ofertas                                        | PR-W1 (com a API: PR-A5) |
| PR-W4 | T26             | Perfil e envio de avatar                       | PR-W2 (com a API: PR-A4) |
| PR-W5 | T27             | Catálogo, detalhe e download                   | PR-W1 (com a API: PR-A6) |
| PR-W6 | T28a            | Painel do Dev                                  | PR-W4, PR-W5             |
| PR-W7 | T29             | Biblioteca                                     | PR-W5 (com a API: PR-A7) |
| PR-W8 | T30a            | Reações e comentários                          | PR-W5 (com a API: PR-A9) |
| PR-W9 | T28b, T30b, T31 | Faixa C do web                                 | PR-W8                    |

Com o contrato simulado (MSW), o front pode entrar antes da API correspondente; a integração real é conferida no PR seguinte.

### Ordem de merge até o esqueleto andante (E0)

`PR-O1` → (`PR-O2`, `PR-A1`) → `PR-A2` → (`PR-W1`, `PR-A3`, `PR-F1`, `PR-O3`) → (`PR-A5`, `PR-W2`, `PR-W3`, `PR-O4`) → (`PR-F2`, `PR-A4`, `PR-W4`, `PR-O5`) → `PR-F3` → **E0** (merge de `develop` em `main` com a tag `v0.1-e0`).

Os demais marcos também recebem tag em `main`: MVP (`v0.2-mvp`) e Entrega (`v1.0`).

<!-- ## 6. Linhas de corte

Se faltar tempo, sai nesta ordem:

1. Faixa D.
2. T31, T30b, T21b, T28b, T22.
3. T11, T12.
4. T15b, T18b.
5. Reações.
6. Biblioteca (atenção: o download exige o jogo na biblioteca).

Nunca se corta o que a avaliação cobra: as duas VMs, o S3 com o SDK e uma Lambda (T04, T08 a T10, T13, T14, T16). A linha de corte é decidida com números no E0 e no MVP. -->

## 7. Critério de pronto

- Testes escritos e passando, afirmando o resultado desejado.
- Tipos e lint limpos.
- Contrato em dia; documentação atualizada se algo mudou.
- Em infraestrutura, `apply` e `destroy` limpos.
- Mudança de contrato: primeiro o schema e o `openapi.json`, no mesmo PR da `feature/api`; quem consome sincroniza `develop` depois.
- Revisão cruzada: o dono do repositório revisa e integra todos os PRs, contra os [Contratos e dados](04-contratos-e-dados.md) e a [Arquitetura de software](03-arquitetura-software.md).

## 8. Riscos e pontos em aberto

- **Acesso ao ambiente AWS:** sem ele ficam bloqueados T04 e a implantação (T08 a T12 e as Lambdas na AWS). O trabalho local segue normalmente.
