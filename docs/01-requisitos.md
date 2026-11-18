# Requisitos

Este documento define o que a Plataforma Distribuída de Jogos faz e quais limites a condicionam. Cada requisito tem um ID estável, referenciado pelos demais documentos: [Arquitetura de nuvem](02-arquitetura-nuvem.md), [Arquitetura de software](03-arquitetura-software.md), [Contratos e dados](04-contratos-e-dados.md) e [Plano de construção](05-plano-de-construcao.md).

## Índice

1. [Visão e escopo](#1-visão-e-escopo)
2. [Requisitos funcionais](#2-requisitos-funcionais)
3. [Requisitos não funcionais](#3-requisitos-não-funcionais)
4. [Restrições](#4-restrições)
5. [Cobertura do enunciado](#5-cobertura-do-enunciado)
6. [Fora do escopo](#6-fora-do-escopo)

## 1. Visão e escopo

### 1.1 Produto

A Plataforma Distribuída de Jogos é uma loja-vitrine em que:

- **desenvolvedores publicam jogos autorais** (um arquivo de demonstração, não jogável);
- **jogadores montam uma biblioteca, reagem e comentam**;
- uma seção de **Ofertas** mostra promoções reais de jogos do mercado, obtidas de uma API externa (CheapShark) e atualizadas por uma Lambda agendada.

A plataforma roda na AWS.

### 1.2 Atores

| Ator          | O que faz                                                                                           | Observação                                               |
| ------------- | --------------------------------------------------------------------------------------------------- | -------------------------------------------------------- |
| Visitante     | Vê ofertas, catálogo da comunidade, detalhes e comentários                                          | Leitura pública; qualquer ação de escrita exige login    |
| Jogador       | Tudo do visitante, mais biblioteca, likes, comentários, download e perfil                           | Papel padrão de toda conta (`player`)                    |
| Desenvolvedor | Tudo do jogador, mais publicar e gerir jogos                                                        | Papel aditivo (`dev`): uma conta pode ter os dois papéis |
| Sistema       | Lambda de ofertas (agendada), Lambda de processamento de imagens (evento do S3), fila de resultados | Atores técnicos                                          |
| Operador      | Dispara a Lambda de ofertas e consulta os painéis na demonstração                                   | Não é perfil do produto                                  |

### 1.3 Exemplo de uso

Marina (Dev) cria "Cajueiro Run": título, descrição, gênero "Plataforma", uma capa, dois prints e um `cajueiro-run-0.1.apk` de demonstração. Os arquivos vão direto ao S3. A Lambda processa as imagens; prontas, o jogo passa a Publicado.

Rafael (Jogador) acha o jogo no catálogo da comunidade, adiciona à biblioteca, baixa o arquivo por uma URL de 5 minutos, dá like e comenta. Na aba Ofertas, vê as promoções do dia (atualizadas a cada 6 h) e adiciona uma à lista de desejos.

### 1.4 Dentro do escopo

| Módulo                    | Cobre                                                                            |
| ------------------------- | -------------------------------------------------------------------------------- |
| Autenticação              | Cadastro, login, sessão, habilitar papel Dev, excluir conta                      |
| Perfil e mídia            | Perfil, avatar, envio de imagens com processamento automático                    |
| Ofertas                   | Ingestão agendada, arquivo bruto, listagem, detalhe, degradação controlada       |
| Jogos da comunidade (Dev) | Criar, editar, versionar build, excluir, catálogo, detalhe, download controlado  |
| Biblioteca                | Adicionar, mudar estado, listar, preservar dados do item                         |
| Opiniões                  | Like e dislike, comentários, curtir comentário e responder (um nível), contagens |
| Operação                  | Saúde, logs, alarmes, disparo manual da Lambda                                   |

### 1.5 Prioridades

| Código | Sentido                                                                  |
| ------ | ------------------------------------------------------------------------ |
| P1     | Necessário para cumprir o enunciado ou para a demonstração ponta a ponta |
| P2     | Completa o produto                                                       |
| P3     | Opcional, só se sobrar tempo                                             |

### 1.6 Convenções

- Nos requisitos funcionais que citam "aprovada", "rejeitada" ou "moderação", o fluxo é o de processamento automático de imagem (RF-MID-01). A moderação por Rekognition é opcional e fica desligada por padrão.
- "Depende do ambiente" marca requisito cujo detalhe muda conforme o acesso AWS (Learner Lab com `LabRole` ou conta própria).
- Valores marcados "calibrar" são ponto de partida, ajustáveis após medição.
- "A definir" marca um detalhe de um requisito ainda sem valor fechado.

## 2. Requisitos funcionais

### 2.1 Autenticação (AUT)

| ID        | Requisito                                                                                                  | Critério de aceite                                                                                                                                 | Prio |
| --------- | ---------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- | ---- |
| RF-AUT-01 | Cadastro com nome de usuário, e-mail e senha (mín. 8 caracteres). O cadastro pode já habilitar o papel Dev | Usuário ou e-mail repetido devolve 409; a senha nunca aparece em resposta nem em log; cria conta com papel `player` (e `dev` se pedido)            | P1   |
| RF-AUT-02 | Login devolve token de acesso com identificador e papéis                                                   | Credencial inválida devolve 401 com mensagem genérica (não diz se o usuário existe)                                                                | P1   |
| RF-AUT-03 | O token expira (padrão 1 h); o front trata a expiração levando ao login                                    | Token vencido devolve 401; o front não entra em laço de erro. A renovação por refresh token está a definir                                         | P2   |
| RF-AUT-04 | Conta existente habilita o papel Dev                                                                       | Após habilitar, as rotas de Dev passam a aceitar; antes, devolvem 403                                                                              | P2   |
| RF-AUT-05 | Excluir a própria conta apaga dados pessoais, opiniões, biblioteca e arquivos no S3                        | Após a exclusão, nenhum documento do usuário no Mongo e nenhum objeto com o prefixo dele. O destino dos jogos publicados pela conta está a definir | P2   |

### 2.2 Perfil e mídia (PRF, MID)

| ID        | Requisito                                                                                                                                                                                                                          | Critério de aceite                                                                                                                                          | Prio |
| --------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- | ---- |
| RF-PRF-01 | Ver e editar nome de exibição e bio                                                                                                                                                                                                | Só o dono edita; bio com limite de tamanho                                                                                                                  | P2   |
| RF-PRF-02 | Enviar avatar (JPEG ou PNG, até 5 MB)                                                                                                                                                                                              | O envio vai direto ao S3; o avatar só aparece a terceiros depois de aprovado; antes, o dono vê "em análise"                                                 | P1   |
| RF-PRF-03 | Perfil público: nome, avatar, bio e jogos publicados (se Dev)                                                                                                                                                                      | Acessível sem login; não expõe e-mail                                                                                                                       | P2   |
| RF-MID-01 | Todo envio de imagem passa por processamento automático disparado por evento (valida o arquivo, remove metadados, gera miniatura) antes de ser visível. A moderação com Rekognition é opcional (sinalizador, desligado por padrão) | Arquivo inválido fica `rejected` e é removido; imagem válida fica disponível com miniatura; com a moderação ligada, imagem imprópria também fica `rejected` | P1   |
| RF-MID-02 | Estado do envio visível ao dono: `pending`, `approved`, `rejected`                                                                                                                                                                 | O front consulta o estado e atualiza sem recarregar manualmente                                                                                             | P1   |
| RF-MID-03 | Falha no processamento não derruba o envio: o sistema tenta de novo e, esgotadas as tentativas, marca como indisponível                                                                                                            | Mensagem forçada a falhar chega à DLQ e o item fica `rejected` com motivo "indisponível"                                                                    | P2   |

### 2.3 Ofertas (OFE)

| ID        | Requisito                                                                                                                                                        | Critério de aceite                                                                                                                      | Prio |
| --------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- | ---- |
| RF-OFE-01 | Uma Lambda agendada (a cada 6 h) busca as 30 melhores ofertas da Steam na CheapShark e grava no DynamoDB com expiração de 24 h                                   | Após a execução, a tabela `offers` tem 30 itens com `expiresAt`                                                                         | P1   |
| RF-OFE-02 | Cada execução guarda a resposta crua da API no S3 (arquivo bruto)                                                                                                | Existe `raw/offers/{data}/{hora}.json` com o conteúdo recebido                                                                          | P2   |
| RF-OFE-03 | Listar ofertas ordenadas por nota de oferta ou desconto, paginadas                                                                                               | Retorna página com preço, preço normal, desconto e miniatura; visitante acessa                                                          | P1   |
| RF-OFE-04 | Detalhe da oferta com link de saída para a loja e a atribuição "Dados: CheapShark"                                                                               | O link abre a oferta na loja; a atribuição aparece no rodapé                                                                            | P2   |
| RF-OFE-05 | Se a API externa falhar, o site continua exibindo as últimas ofertas e mostra a hora da última atualização                                                       | Com a Lambda forçada a falhar, a lista segue disponível por até 24 h                                                                    | P2   |
| RF-OFE-06 | A Lambda pode ser disparada manualmente (console ou CLI) para demonstração                                                                                       | Invocação manual repete o fluxo de RF-OFE-01                                                                                            | P1   |
| RF-OFE-07 | O detalhe da oferta mostra o histórico de preço em gráfico temporal (linha em degraus), com os pontos de mudança coletados pela Lambda e o menor preço histórico | `GET /offers/{id}/history?from=&to=` devolve os pontos ordenados por data; com menos de 2 pontos o gráfico mostra um estado explicativo | P3   |

### 2.4 Jogos da comunidade (JOG), papel Dev

| ID        | Requisito                                                                                                                                 | Critério de aceite                                                                                | Prio |
| --------- | ----------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- | ---- |
| RF-JOG-01 | Dev cria jogo: título, descrição, gênero, capa obrigatória, até 3 imagens e arquivo de build (`.apk` ou `.zip`; tamanho máximo a definir) | O jogo nasce em `em análise`; só o Dev dono o vê                                                  | P1   |
| RF-JOG-02 | Os arquivos do jogo vão direto ao S3 por URL ou POST pré-assinado; a API não recebe os bytes                                              | Nenhuma rota da API aceita `multipart` com arquivo; o limite de tipo e tamanho é imposto no envio | P1   |
| RF-JOG-03 | O jogo passa a `publicado` só quando todas as imagens são aprovadas; se alguma for rejeitada, fica `rejeitado` e o Dev vê o motivo        | Estado muda ao consumir o resultado da fila; um jogo `em análise` não aparece no catálogo         | P1   |
| RF-JOG-04 | Dev edita título, descrição e gênero; trocar imagem reinicia o processamento                                                              | Edição por quem não é dono devolve 403                                                            | P2   |
| RF-JOG-05 | Dev publica nova versão do build (rótulo e notas); jogadores recebem sempre a mais recente; o Dev vê o histórico                          | A lista de versões ordena por data; o download usa a atual                                        | P2   |
| RF-JOG-06 | Dev exclui jogo: somem o registro e os objetos no S3; a biblioteca de jogadores mantém o título e indica "removido"                       | Após excluir, o catálogo não o lista e o download devolve 404                                     | P2   |
| RF-JOG-07 | "Meus jogos": lista do Dev com estado, versão atual, número de downloads e de likes                                                       | Mostra só os jogos do próprio Dev                                                                 | P1   |
| RF-JOG-08 | Catálogo público da comunidade: lista paginada, busca por título, filtro por gênero                                                       | Só jogos `publicado`; gêneros de uma lista fixa (conteúdo a definir)                              | P1   |
| RF-JOG-09 | Detalhe do jogo: descrição, imagens, Dev, versão atual, contadores e comentários                                                          | Acessível sem login                                                                               | P1   |
| RF-JOG-10 | Download controlado: usuário autenticado que tem o jogo na biblioteca recebe URL de leitura de 5 minutos; o download é contado            | Sem login: 401. Sem o jogo na biblioteca: 403. A URL vence em 5 min (teste de relógio)            | P1   |

### 2.5 Biblioteca (BIB)

| ID        | Requisito                                                                                                      | Critério de aceite                                                      | Prio |
| --------- | -------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- | ---- |
| RF-BIB-01 | Adicionar à biblioteca uma oferta ou um jogo da comunidade, com estado (desejo, tenho, jogando, zerado)        | Um item aparece uma só vez por usuário; repetir devolve a mesma entrada | P1   |
| RF-BIB-02 | Mudar o estado e remover                                                                                       | Só o dono altera                                                        | P2   |
| RF-BIB-03 | Listar a biblioteca com filtro por estado e por tipo                                                           | Paginação; retorna título e miniatura                                   | P1   |
| RF-BIB-04 | O item guarda título e miniatura próprios: continua listado quando a oferta expira (24 h) ou o jogo é excluído | Com a oferta apagada do DynamoDB, a biblioteca segue exibindo o item    | P1   |

Um item de catálogo é identificado por `itemKey`: `offer:{steamAppID}` para ofertas e `game:{id}` para jogos da comunidade.

### 2.6 Opiniões (OPI)

| ID        | Requisito                                                                                               | Critério de aceite                                                                                                                                           | Prio |
| --------- | ------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---- |
| RF-OPI-01 | Like ou dislike em um item; um por usuário e item; pode mudar ou remover                                | Votar duas vezes não duplica; trocar like por dislike atualiza as contagens                                                                                  | P1   |
| RF-OPI-02 | Comentar em um item; editar e excluir o próprio comentário                                              | Só o autor edita ou exclui; texto com limite de tamanho                                                                                                      | P1   |
| RF-OPI-03 | Listar comentários do item, paginados e com autor; leitura pública                                      | Ordenados do mais novo ao mais antigo                                                                                                                        | P1   |
| RF-OPI-04 | Mostrar contagem de likes, dislikes e comentários em cada item (e likes e respostas em cada comentário) | A contagem bate com os registros (sem contador paralelo)                                                                                                     | P1   |
| RF-OPI-05 | Anexar até 3 imagens a um comentário, com processamento automático                                      | Mesmo fluxo de RF-MID-01                                                                                                                                     | P3   |
| RF-OPI-06 | Curtir um comentário; um por usuário e comentário; pode remover                                         | Curtir duas vezes não duplica; a contagem aparece no comentário                                                                                              | P2   |
| RF-OPI-07 | Responder a um comentário (um nível de resposta); as respostas aparecem sob o comentário                | Responder a uma resposta é recusado; excluir o comentário pai mantém as respostas com a marca "comentário removido". Mais níveis de resposta estão a definir | P2   |

### 2.7 Operação (OPS)

| ID        | Requisito                                                  | Critério de aceite                                                                               | Prio |
| --------- | ---------------------------------------------------------- | ------------------------------------------------------------------------------------------------ | ---- |
| RF-OPS-01 | `GET /health` informa que o processo e o MongoDB respondem | Usado pelo roteiro de verificação e, se houver ALB, por ele; devolve 503 se o Mongo estiver fora | P1   |

### 2.8 Contagem

| Prioridade | Quantidade |
| ---------- | ---------- |
| P1         | 23         |
| P2         | 15         |
| P3         | 2          |
| Total      | 40         |

## 3. Requisitos não funcionais

Os requisitos desta seção não têm prioridade própria, exceto onde indicada. Valores marcados "calibrar" são ponto de partida.

### 3.1 Desempenho e escala (DES)

| ID         | Requisito                                                                                                          | Como verificar                                                               |
| ---------- | ------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------- |
| RNF-DES-01 | A API não recebe nem envia bytes de arquivos; envio e download são direto com o S3                                 | Inspeção das rotas; teste com arquivo de 50 MB sem aumento de memória da API |
| RNF-DES-02 | Leituras de lista (catálogo, ofertas, comentários) com p95 abaixo de 400 ms com 20 usuários simultâneos (calibrar) | Teste de carga curto                                                         |
| RNF-DES-03 | Toda listagem é paginada (máx. 50 por página)                                                                      | Teste de contrato                                                            |
| RNF-DES-04 | A API é sem estado local. Executar de 1 a 3 instâncias atrás de um ALB sem mudar código é extra (P3)               | Subir 2 instâncias e alternar requisições                                    |

### 3.2 Disponibilidade e confiabilidade (CONF)

| ID          | Requisito                                                                                                                                                                      | Como verificar                                                               |
| ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------- |
| RNF-CONF-01 | Resultado de processamento de imagem: até 3 tentativas, depois DLQ; alarme se a DLQ tiver mensagem                                                                             | Forçar falha e ver a DLQ e o alarme                                          |
| RNF-CONF-02 | Falha da CheapShark: 3 tentativas com espera crescente; ofertas antigas permanecem (TTL 24 h)                                                                                  | Lambda com falha simulada; a lista continua                                  |
| RNF-CONF-03 | Processar duas vezes a mesma mensagem de resultado produz o mesmo estado (idempotência)                                                                                        | Teste unitário e de integração                                               |
| RNF-CONF-04 | Extra (P3): ALB em 2 zonas de disponibilidade, com verificação de saúde; instância doente sai de rotação. Depende do ambiente (auto scaling)                                   | Parar a API e ver o alvo `unhealthy`                                         |
| RNF-CONF-05 | Backup do MongoDB: snapshot do disco antes da demonstração e em rotina agendada (periodicidade a definir)                                                                      | Snapshot existente e restaurável                                             |
| RNF-CONF-06 | A API e o MongoDB voltam sozinhos quando a instância reinicia: política de reinício dos contêineres e Docker habilitado na partida; dados do Mongo no disco EBS. Prioridade P2 | Parar e iniciar as duas instâncias e ver `/health` responder sem intervenção |
| RNF-CONF-07 | A restauração do backup do Mongo (`mongodump` no S3) é testada ao menos uma vez antes da demonstração. Prioridade P2                                                           | Restaurar num banco limpo e conferir contagens                               |
| RNF-CONF-08 | Alarme de falha de verificação da instância (aviso por e-mail); a ação de recuperação automática é opcional e depende de verificação no ambiente. Prioridade P2                | Provocar e receber o aviso                                                   |
| RNF-CONF-09 | Evolução: ALB com Auto Scaling substitui sozinho a instância da API que falhe (uma ou mais instâncias). Prioridade P3                                                          | Encerrar a instância e ver o site voltar                                     |

A API roda em uma única instância; RNF-CONF-06 a RNF-CONF-09 reduzem o impacto dessa limitação a baixo custo.

### 3.3 Segurança (SEG)

| ID         | Requisito                                                                                                                | Como verificar                              |
| ---------- | ------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------- |
| RNF-SEG-01 | Senhas com hash forte (argon2id ou bcrypt); nunca em log                                                                 | Revisão e teste                             |
| RNF-SEG-02 | Token de acesso curto (até 1 h); segredo de assinatura fora do código e do repositório                                   | Varredura de segredos no CI                 |
| RNF-SEG-03 | Credenciais AWS por papel da instância; nenhuma chave em variável de ambiente ou código. Depende do ambiente (`LabRole`) | Inspeção da EC2 e das Lambdas               |
| RNF-SEG-04 | Buckets privados; leitura pública apenas da mídia aprovada, via CloudFront                                               | Tentar acessar objeto da quarentena: negado |
| RNF-SEG-05 | Tipo e tamanho dos envios impostos na URL assinada (POST) e revalidados no servidor                                      | Enviar `.exe` ou 20 MB de imagem: recusado  |
| RNF-SEG-06 | MongoDB sem acesso público, com autenticação; cadeia de Security Groups CloudFront, ALB (se existir), API, Mongo         | Teste de conexão externa falha              |
| RNF-SEG-07 | Toda entrada validada por esquema; um formato de erro único, sem vazar detalhes internos                                 | Teste de contrato dos erros                 |
| RNF-SEG-08 | Limite de tentativas em cadastro e login                                                                                 | 20 tentativas em 1 min: bloqueio temporário |
| RNF-SEG-09 | Autorização por posse: só o dono edita ou exclui; Dev só gere os próprios jogos; download só com o jogo na biblioteca    | Testes por perfil                           |
| RNF-SEG-10 | HTTPS ao usuário (CloudFront); site e API na mesma origem, sem CORS aberto                                               | Verificação de cabeçalhos                   |

### 3.4 Observabilidade (OBS)

| ID         | Requisito                                                                                                             | Como verificar         |
| ---------- | --------------------------------------------------------------------------------------------------------------------- | ---------------------- |
| RNF-OBS-01 | Logs JSON estruturados (identificador da requisição, usuário, ação, latência) no CloudWatch Logs; sem dados sensíveis | Consulta no CloudWatch |
| RNF-OBS-02 | Painel com requisições, erros 5xx, latência, erros das Lambdas, profundidade da fila e da DLQ                         | Painel existente       |
| RNF-OBS-03 | Alarmes com aviso por e-mail (SNS): 5xx, falha da Lambda de ofertas, DLQ não vazia                                    | Forçar cada condição   |

### 3.5 Qualidade e manutenção (QUA)

| ID         | Requisito                                                                                                                                                                                                                                                   | Como verificar                        |
| ---------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------- |
| RNF-QUA-01 | Arquitetura em camadas por módulo: domínio sem I/O; portas para persistência, armazenamento, fila, relógio e catálogo de ofertas                                                                                                                            | Domínio testável sem Mongo, S3 ou AWS |
| RNF-QUA-02 | Testes: unitários das regras; integração dos adaptadores (Mongo real em contêiner; S3, SQS e DynamoDB emulados); ao menos um teste ponta a ponta do envio com processamento; cenário de relógio para expirações; os testes afirmam o comportamento desejado | CI verde                              |
| RNF-QUA-03 | Contrato da API em OpenAPI gerado do código; cliente tipado do front gerado dele                                                                                                                                                                            | Cliente regenerado sem edição manual  |
| RNF-QUA-04 | Configuração tipada e validada na partida; sem valor padrão para segredo; falha ao subir se faltar                                                                                                                                                          | Subir sem variável: erro claro        |
| RNF-QUA-05 | TypeScript estrito, lint e formatação; CI (lint, testes, build) a cada PR                                                                                                                                                                                   | Pipeline                              |
| RNF-QUA-06 | Convenções: Conventional Commits, PR com checklist, ADR para decisões de arquitetura; comentários de código em inglês, dizendo o que a coisa faz e sem narrar a mudança                                                                                     | Revisão de PR                         |

### 3.6 Operação e entrega (OPE)

| ID         | Requisito                                                                                                                                                      | Como verificar             |
| ---------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------- |
| RNF-OPE-01 | Infraestrutura reproduzível por IaC (rede, EC2, ALB se houver, S3, CloudFront, Lambdas, filas, tabelas, alarmes). Depende do ambiente (ferramenta e `LabRole`) | Destruir e recriar         |
| RNF-OPE-02 | Ambiente local com um comando (Mongo e emuladores AWS em contêineres)                                                                                          | Clonar e subir             |
| RNF-OPE-03 | Deploy do front: build estático para o S3 com invalidação de cache; deploy da API na EC2 por procedimento documentado (forma de automação a definir)           | Passo a passo reproduzível |
| RNF-OPE-04 | Custo sob controle: instâncias pequenas; EC2 (e ALB, se existir) desligados ou destruídos fora de ensaios e demonstração. Depende do ambiente                  | Checagem do faturamento    |
| RNF-OPE-05 | Existe um script de ligar o ambiente (Mongo primeiro, depois a API, espera e verificação de `/health`) e um roteiro curto de recuperação. Prioridade P2        | Executar o script do zero  |

### 3.7 Usabilidade, acessibilidade e privacidade (USA, PRI)

| ID         | Requisito                                                                                                        | Como verificar                             |
| ---------- | ---------------------------------------------------------------------------------------------------------------- | ------------------------------------------ |
| RNF-USA-01 | Interface fiel ao Figma, responsiva (a partir de 360 px), com estados de carregamento, vazio e erro em toda tela | Revisão contra o Figma                     |
| RNF-USA-02 | Acessibilidade básica: rótulos, foco por teclado, contraste AA como meta                                         | Verificação manual e ferramenta automática |
| RNF-PRI-01 | Excluir a conta remove dados pessoais no Mongo e no S3                                                           | Conferir ausência após a exclusão          |
| RNF-PRI-02 | Exibir a atribuição "Dados: CheapShark"                                                                          | Rodapé                                     |

## 4. Restrições

| ID      | Restrição                                                                                                       |
| ------- | --------------------------------------------------------------------------------------------------------------- |
| REST-01 | Duas VMs: uma com a aplicação (servidor de aplicação) e outra com o SGBD                                        |
| REST-02 | Blob (S3) usando o SDK para dados estáticos                                                                     |
| REST-03 | Ao menos um serviço serverless para um aspecto específico                                                       |
| REST-04 | Infraestrutura AWS                                                                                              |
| REST-05 | Entrega do código, slides e apresentação presencial obrigatória, nos prazos da disciplina                       |
| REST-06 | Projeto em dupla, com divisão entre requisitos, estrutura e Figma de um lado e tarefas de front e back do outro |
| REST-07 | Back-end em NestJS (Node, TypeScript); front-end em React com Vite                                              |
| REST-08 | MongoDB na EC2, em sub-rede privada                                                                             |
| REST-09 | Lambda de ofertas fora da VPC; consumo pela API via DynamoDB                                                    |
| REST-10 | Fonte externa de ofertas: CheapShark                                                                            |
| REST-11 | Sem jogo jogável: o arquivo é de demonstração                                                                   |
| REST-12 | CloudFront entre o usuário e a API; o ALB é extra (P3)                                                          |
| REST-13 | Região us-east-1. Depende do ambiente (o Learner Lab permite us-east-1 e us-west-2)                             |
| REST-14 | Ambiente AWS não confirmado: projetar para o caso mais restrito (`LabRole`, credenciais temporárias)            |
| REST-15 | Código preparado para crescer: papéis aditivos, envio genérico por finalidade, itens `{kind, id}`               |
| REST-16 | Documentação no repositório; legado somente leitura; comentários de código em inglês                            |

## 5. Cobertura do enunciado

| Requisito do enunciado                        | Atendido por                                                                                                  | Prio mínima |
| --------------------------------------------- | ------------------------------------------------------------------------------------------------------------- | ----------- |
| Duas VMs (aplicação e SGBD)                   | REST-01, REST-08, RNF-SEG-06, RF-OPS-01                                                                       | P1          |
| S3 com SDK                                    | RF-PRF-02, RF-JOG-01, RF-JOG-02, RF-JOG-10, RF-OFE-02, RNF-DES-01, RNF-SEG-04, RNF-SEG-05                     | P1          |
| Serverless para um aspecto específico         | RF-OFE-01 e RF-OFE-06 (Lambda agendada), RF-MID-01 e RF-MID-03 (Lambda por evento)                            | P1          |
| Bônus de AWS                                  | CloudFront, ALB, SQS com DLQ, DynamoDB, Rekognition, CloudWatch, IaC (REST-12, RNF-CONF, RNF-OBS, RNF-OPE-01) | P2          |
| Proposta da Parte 01                          | Perfis Jogador e Dev, catálogo, comentários, biblioteca, ofertas (RF-JOG, RF-BIB, RF-OPI, RF-OFE)             | P1          |
| Critério de avaliação "uso da infraestrutura" | Cada serviço AWS tem uso demonstrável (ver [Arquitetura de nuvem](02-arquitetura-nuvem.md))                   |             |

## 6. Fora do escopo

| Item                                               | Motivo                                                                                                     |
| -------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| Jogo jogável, pagamentos, compras                  | O arquivo é de demonstração; não há transação financeira                                                   |
| Relatório CSV da biblioteca                        | Fora do produto                                                                                            |
| Coleções públicas                                  | Redundantes com o papel Dev; extra opcional (P3)                                                           |
| Moderação manual por administrador, perfil curador | Fora do prazo                                                                                              |
| Login social, Cognito, e-mail e notificações       | Fora do prazo; a API faz o cadastro                                                                        |
| SSR, Next.js                                       | O front é uma SPA em React com Vite                                                                        |
| Glue e histórico de preço em gráfico               | Extras (ver RF-OFE-07); o arquivo bruto no S3 (RF-OFE-02) preserva a opção de construir o histórico depois |
