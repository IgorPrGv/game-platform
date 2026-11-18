# Documentação

Documentação técnica da Plataforma Distribuída de Jogos.

| Documento                                             | Conteúdo                                                                                    |
| ----------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| [Requisitos](01-requisitos.md)                        | Escopo, perfis, requisitos funcionais e não funcionais, restrições                          |
| [Arquitetura de nuvem](02-arquitetura-nuvem.md)       | Componentes na AWS, fluxos, segurança, implantação, ambiente local, limitações e validações |
| [Arquitetura de software](03-arquitetura-software.md) | Estrutura da API e do web, persistência, autenticação, convenções, pilha de tecnologias     |
| [Contratos e dados](04-contratos-e-dados.md)          | Convenções da API, erros, modelo de dados, rotas, envio de arquivos, mensagens e estados    |
| [Plano de construção](05-plano-de-construcao.md)      | Fatias, tarefas, responsáveis, estimativas, branches e PRs                                  |
| [Como contribuir](06-como-contribuir.md)              | Fluxo de Git, commits, Pull Requests                                                        |

## Por onde começar

1. Leia os requisitos para entender o produto.
2. Leia a arquitetura de nuvem e a de software para entender como ele é construído.
3. Use os contratos e dados como referência ao implementar a API, o web e as Lambdas.
4. Consulte o plano de construção para saber a ordem e as responsabilidades.
5. Antes do primeiro PR, leia [Como contribuir](06-como-contribuir.md).

O contrato OpenAPI gerado pela API fica em `api/openapi.json`; os documentos de contrato complementares ficam em `docs/contracts/`.
