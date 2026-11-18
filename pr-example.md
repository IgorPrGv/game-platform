# feat(api): add media upload ticket

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
COMO USAR ESTE ARQUIVO (apague este bloco no seu pr.md)

1. Copie para pr.md: `cp pr-example.md pr.md` (PowerShell: `Copy-Item pr-example.md pr.md`).
   O pr.md está no .gitignore. NUNCA faça git add dele. Ele só existe para ser lido pelo gh.
2. Linha 1 = título do PR e do commit de squash. Formato obrigatório (Conventional Commits):
   `tipo(escopo): resumo no imperativo`
   - tipos: feat, fix, docs, chore, refactor, test, ci, build, perf
   - escopos: api, web, functions, infra, ops, docs, ci, deps
   - sem número de tarefa no título; o nome da tarefa vai na seção "Tarefa" do corpo
3. A linha 2 fica em branco. Do resto em diante é o corpo do PR.
4. Regras:
   - Um PR = uma tarefa (ou um lote de 1 a 2 dias). Nada de acumular semanas.
   - O PR sempre vai para `develop` (nunca para `main`).
   - Só mexa na pasta da sua branch (ver plano, seção 3.1).
   - Sincronize `develop` na sua branch antes de abrir o PR.
   - Em "O que muda", diga o que e por que, não liste arquivos.
   - Marque só as caixas que de fato foram cumpridas. Se algo não se aplica, escreva "n/a".
5. Abrir o PR (a partir da raiz do repositório, com a branch já enviada com `git push`):
   PowerShell:
     $t = (Get-Content pr.md -TotalCount 1) -replace '^#\s*',''
     $b = (Get-Content pr.md | Select-Object -Skip 2) -join "`n"
     gh pr create --base develop --title $t --body $b
   Bash:
     gh pr create --base develop --title "$(head -1 pr.md | sed 's/^# *//')" --body "$(tail -n +3 pr.md)"
6. Depois do merge (squash): `git switch develop`, `git pull`, e recrie a branch da pasta:
   `git switch -C feature/<pasta>`.
-->
