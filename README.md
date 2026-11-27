# Dotfiles do Neovim (LazyVim)

Configuração pessoal de Neovim baseada no [LazyVim](https://github.com/LazyVim/LazyVim),
versionada como um pacote [GNU Stow](https://www.gnu.org/software/stow/). O objetivo é
clonar o repositório em qualquer máquina e deixar o editor pronto com poucos comandos.

## Requisitos

Obrigatórios:

- Neovim **0.11+** (testado com 0.12.x)
- `git`
- GNU Stow (`stow`)
- `ripgrep` (`rg`)

Recomendados (o `install.sh` avisa se faltarem):

- `fd` (ou `fdfind`)
- `gcc` (compilação de parsers do Treesitter)
- `node` e `npm` (markdown-preview e instalação do `sql-formatter` via Mason)
- `curl`

Por linguagem:

| Linguagem | Dependências |
| --- | --- |
| Java | JDK 21+ (`javac`/`java` no `PATH`); LSP e debug instalados pelo Mason |
| Kotlin | JDK 21+; `kotlin-lsp`/`ktlint` instalados pelo Mason |
| Rust | `rustup` com `rust-analyzer` e `rustc` |
| SQL | `sql-formatter` (instalado pelo Mason); cliente do banco para o dadbod (`psql`, etc.) |
| Markdown | `node`/`npm` (ou o preview baixa um binário próprio) |

## Instalação

```sh
git clone <url-do-repositorio> ~/dotfiles
cd ~/dotfiles
./install.sh
```

O script:

1. valida as dependências básicas;
2. detecta uma configuração existente em `~/.config/nvim` e move para
   `~/.config/nvim.bak.<data>`;
3. verifica conflitos com `stow -n` antes de alterar qualquer coisa;
4. cria os links com `stow --no-folding --restow`.

Para já baixar os plugins durante a instalação:

```sh
./install.sh --sync
```

Para apenas simular:

```sh
./install.sh --dry-run
```

### Instalação manual

```sh
cd ~/dotfiles
stow --no-folding -n -v -t "$HOME" .   # confira o que será linkado
stow --no-folding --restow -t "$HOME" .
```

`--no-folding` evita que o stow transforme `~/.config` inteiro em um symlink
para o repositório. Assim só `~/.config/nvim` é gerenciado.

### Primeiro uso

1. Abra `nvim` e aguarde o lazy.nvim instalar os plugins (a primeira execução
   precisa de rede).
2. Rode `:checkhealth` para verificar o ambiente.
3. Abra `:Mason` e confirme as ferramentas instaladas. O primeiro uso de uma
   linguagem pode baixar o LSP correspondente.
4. Rode `:TSUpdate` se os parsers do Treesitter não estiverem presentes.

## Atualização

```sh
cd ~/dotfiles
git pull
./install.sh --sync
```

Depois de atualizar plugins no Neovim (`:Lazy update`), teste o editor e
versione o `lazy-lock.json`:

```sh
git add .config/nvim/lazy-lock.json
git commit -m "chore(deps): atualiza plugins"
```

## Estrutura

```text
.
├── .config/nvim/            # pacote stow (vai para ~/.config/nvim)
│   ├── init.lua             # bootstrap do lazy.nvim
│   ├── lazy-lock.json       # versões fixadas dos plugins
│   ├── lazyvim.json         # extras habilitados do LazyVim
│   ├── sql-formatter.json   # estilo SQL padrão
│   ├── lua/config/          # options, keymaps, autocmds, lazy
│   ├── lua/plugins/         # plugins e overrides
│   ├── tests/               # testes dos specs e formatters
│   └── stylua.toml
├── doc/                     # documentação (não é stowada)
├── install.sh
├── uninstall.sh
└── .stow-local-ignore       # evita linkar README, doc, .hermes etc.
```

Plugins, LSPs, parsers e cache ficam fora do repositório, em
`~/.local/share/nvim` e `~/.cache/nvim`. Isso é intencional: o repositório guarda
apenas configuração e o lock das versões.

## Atalhos principais

| Atalho | Ação |
| --- | --- |
| `<leader>gvd` | CodeDiff: working tree |
| `<leader>gvs` | CodeDiff: staged |
| `<leader>gvh` | CodeDiff: histórico |
| `<leader>gvc` | CodeDiff: arquivo atual vs `HEAD` |
| `<leader>gvr` | CodeDiff: revisão (pede a revisão) |
| `<leader>gvp` | CodeDiff: pull request (pede o número) |
| `<leader>gd` / `<leader>gs` | diff/status do git pelo picker |
| `<leader>ghs` / `<leader>ghr` | stage/reset de hunk (gitsigns) |
| `<leader>cf` | formatar buffer |
| `Ctrl+Alt+L` | formatar SQL com o estilo padrão |
| `<leader>rj` | compilar e executar o `Main.java` do projeto |
| `<leader>S` | executar consulta no dadbod |
| `<leader>as` | ligar/desligar auto-save |

## Formatação de SQL

O SQL usa o [`sql-formatter`](https://github.com/sql-formatter-org/sql-formatter)
com um perfil inspirado no DataGrip/sqlstyle.guide, **sem precisar do DataGrip
instalado**. Veja [doc/sql-formatter.md](doc/sql-formatter.md) para o perfil,
as opções suportadas e como sobrescrever o estilo por projeto.

## Desinstalação

```sh
cd ~/dotfiles
./uninstall.sh
```

O script remove apenas os links. Se houver backup, restaure manualmente:

```sh
mv ~/.config/nvim.bak.<data> ~/.config/nvim
```

## Solução de problemas

- **`stow` acusou conflito**: existe um arquivo real no destino. Faça backup ou
  remova o arquivo e rode de novo. Evite `--adopt`: ele move o conteúdo do
  destino para dentro do repositório e pode sobrescrever sua configuração.
- **Plugins não instalaram**: abra `nvim` e rode `:Lazy sync`; confira a rede.
- **LSP ausente**: `:Mason` → instale o servidor da linguagem; confira
  `:checkhealth`.
- **Parsers ausentes**: `:TSUpdate` ou `:TSInstall <linguagem>`.
- **SQL não formata**: confira `:ConformInfo` e se o `sql-formatter` aparece no
  `PATH` (Mason instala em `~/.local/share/nvim/mason/bin`).
