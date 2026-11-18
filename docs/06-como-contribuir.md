# Como contribuir

Guia do fluxo de trabalho do repositório. Vale para as duas pessoas do projeto.

## 1. Ideia geral

- A branch **`develop`** é a principal: é onde o trabalho de todo mundo se junta. Só recebe código por Pull Request (PR).
- A branch **`main`** é a estável: só recebe a `develop` nos marcos do projeto, com tag. Quem faz isso é o dono do repositório.
- Cada pasta do monorepo tem **uma branch de feature** e **um dono**:

| Branch              | Pasta                                                                                | Dono |
| ------------------- | ------------------------------------------------------------------------------------ | ---- |
| `feature/ops`       | repositório, Compose, CI, Terraform (rede, dados, computação e entrada), `docs/`     | Igor |
| `feature/web`       | `web/`                                                                               | Igor |
| `feature/api`       | `api/` e `docs/contracts/`                                                           | Luis |
| `feature/functions` | `functions/`, `infra/modules/serverless`, `infra/modules/observability` e `scripts/` | Luis |

- Só se mexe na pasta da própria branch. Assim os PRs quase nunca disputam o mesmo arquivo.
- Quem **integra** os PRs (faz o merge) é o Igor. Quem não integra abre o PR e espera.

## 2. Preparação (uma vez)

```
git clone git@github.com:IgorPrGv/game-platform.git
cd game-platform
npm ci
```

O `npm ci` instala as ferramentas da raiz e ativa o hook que confere a mensagem de cada commit. É preciso ter Node 24 (`.nvmrc`) e o `gh` (GitHub CLI) instalado e logado (`gh auth login`).

## 3. Ciclo de um PR

### 3.1 Começar

Sempre a partir da `develop` atualizada:

```
git fetch origin
git switch -C feature/<pasta> origin/develop
```

### 3.2 Trabalhar e fazer commits

Commits pequenos, em Conventional Commits:

```
tipo(escopo): resumo no imperativo
```

- **tipos:** `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `ci`, `build`, `perf`
- **escopos:** `api`, `web`, `functions`, `infra`, `ops`, `docs`, `ci`, `deps`
- exemplo: `feat(api): add media upload ticket`
- não se usa número de tarefa; o nome da tarefa vai no corpo do PR

O hook rejeita a mensagem fora desse formato.

### 3.3 Sincronizar com a `develop`

No começo do dia e antes de abrir o PR, traga o que os outros integraram:

```
git fetch origin
git merge origin/develop
```

Se houver conflito, resolva, confira os testes e faça o commit da junção. Alterações em `api/openapi.json` vêm da `feature/api`: quem consome (o `web/`) sincroniza e regenera o cliente.

### 3.4 Abrir o PR

1. Envie a branch: `git push -u origin feature/<pasta>` (nas vezes seguintes, só `git push`).
2. Copie o modelo e edite: `Copy-Item pr-example.md pr.md` (PowerShell) ou `cp pr-example.md pr.md`. Apague o bloco de instruções do fim.
3. Abra o PR:

```
gh pr create --base develop --title "feat(api): add media upload ticket" --body-file pr.md
```

O `pr.md` é só o corpo do PR e fica no `.gitignore`: **nunca** entra em `git add`. O título (que vira o commit na `develop`) segue o formato de commit. Um PR deve ter uma tarefa, ou um lote que caiba em 1 a 2 dias.

### 3.5 CI e revisão

O CI roda sozinho no PR. Para acompanhar:

```
gh pr checks --watch
```

O Igor revisa e integra. Se pedir mudanças, faça novos commits na mesma branch e dê `git push`: **o PR já aberto se atualiza sozinho**. Não é preciso nenhum comando para incluir commits novos.

### 3.6 Integrar (só o Igor)

Com o CI verde:

```
gh pr merge --squash
```

O merge é sempre por **squash**: todos os commits do PR viram um só na `develop`, com o título do PR. A branch no GitHub só é apagada se usar `--delete-branch`.

### 3.7 Depois do merge

Quem abriu o PR recria a branch a partir da `develop`. Não continue na branch antiga: com squash, ela passa a parecer "desatualizada" e gera conflitos falsos.

```
git fetch origin
git switch -C feature/<pasta> origin/develop
```

## 4. Regra de ouro: não empurre depois do PR aberto

Enquanto o PR estiver aberto, tudo o que for enviado à branch entra nele. Mas se o Igor integrar **antes** de você enviar mais commits, esses commits ficam de fora da `develop` (não se perdem; só não entraram). Para evitar:

1. Depois de abrir o PR, **avise no chat** e **não dê push** naquela branch até o merge.
2. Para continuar trabalhando enquanto espera, crie uma branch local a partir da sua: `git switch -c feature/<pasta>-seguinte`.
3. Depois do merge, recrie a branch da pasta (3.7). O trabalho já feito na branch local seguinte pode ser trazido com `git cherry-pick <hash>` (veja os hashes com `git log --oneline`).

## 5. Regras resumidas

- Todo PR vai para `develop`. Ninguém faz `push` direto em `develop` ou `main`.
- Só se mexe na pasta da própria branch.
- PR pequeno, com CI verde antes de integrar.
- Segredos nunca entram no repositório (use `.env`, que é ignorado).
- `api/openapi.json` e `docs/contracts/` só mudam na `feature/api`.
- Mudança de contrato: primeiro o schema e o `openapi.json`, no PR da API; quem consome sincroniza depois.
- Dúvidas de desenho vão para o chat antes do código.
