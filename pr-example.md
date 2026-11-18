## Tarefa

Upload de mídia (RF-PRF-02, RF-MID-01 a 03)

## O que muda

- Endpoint que devolve o pedido de envio (POST pré-assinado) com limite de tamanho.
- Consumidor da fila de resultado da moderação.

## Como testar

1. `docker compose up`
2. `npm test` na pasta `api/`

## Pronto quando

- [ ] Testes escritos e passando
- [ ] Tipos e lint limpos
- [ ] Contrato e documentação em dia
- [ ] CI verde

<!--
COMO USAR ESTE ARQUIVO (apague este bloco no seu pr.md). Fluxo completo em docs/06-como-contribuir.md.

1. Copie para pr.md (PowerShell: `Copy-Item pr-example.md pr.md`) e edite.
   O pr.md está no .gitignore: NUNCA faça git add dele. Ele só existe para o gh ler.
2. O arquivo contém só o CORPO do PR. O título vai no comando, em Conventional Commits:
   `tipo(escopo): resumo no imperativo`
   - tipos: feat, fix, docs, chore, refactor, test, ci, build, perf
   - escopos: api, web, functions, infra, ops, docs, ci, deps
   - sem número de tarefa no título; o nome da tarefa vai na seção "Tarefa"
3. Regras:
   - Um PR = uma tarefa (ou um lote de 1 a 2 dias).
   - O PR sempre vai para `develop`, nunca para `main`.
   - Só mexa na pasta da sua branch.
   - Em "O que muda", diga o que e por que, não liste arquivos.
   - Marque só as caixas cumpridas. Se algo não se aplica, escreva "n/a".
4. Abrir o PR (da raiz, com a branch já enviada por `git push`):
   gh pr create --base develop --title "feat(api): add media upload ticket" --body-file pr.md
-->
