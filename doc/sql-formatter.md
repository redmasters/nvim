# Formatação de SQL estilo DataGrip sem DataGrip

Esta configuração formata SQL com um perfil inspirado no DataGrip e no
[sqlstyle.guide](https://www.sqlstyle.guide/), usando apenas o
[`sql-formatter`](https://github.com/sql-formatter-org/sql-formatter). Não é
necessário ter DataGrip (nem o `format.sh` da JetBrains) instalado.

## Como funciona

```text
Ctrl+Alt+L (ou :ConformInfo)
    ↓
conform.nvim
    ↓
sql-formatter -c <config>
    ↓
buffer formatado
```

O `sql-formatter` é instalado pelo Mason e lido do `PATH`. O perfil padrão fica
versionado em `.config/nvim/sql-formatter.json` e é aplicado a qualquer buffer
com `filetype=sql`.

## Recursos suportados

| Recurso | Configuração |
| --- | --- |
| Palavras-chave em maiúsculas | `keywordCase: "upper"` |
| Tipos de dados em maiúsculas | `dataTypeCase: "upper"` |
| Funções em maiúsculas | `functionCase: "upper"` |
| Identificadores e aliases preservados | `identifierCase: "preserve"` |
| Indentação de 2 espaços | `tabWidth: 2` |
| Alinhamento em "rio" (SELECT/FROM/WHERE à direita) | `indentStyle: "tabularRight"` |
| `AND`/`OR` no início da linha | `logicalOperatorNewline: "before"` |
| Vírgula no fim da linha | comportamento padrão do formatter |
| Quebra de expressões longas | `expressionWidth: 80` |
| Uma linha em branco entre comandos | `linesBetweenQueries: 1` |
| Dialeto PostgreSQL | `language: "postgresql"` |

Exemplo:

```sql
SELECT a.title,
          a.release_date,
          a.recording_date
     FROM albums AS a
    WHERE a.title = 'Charcoal Lane'
       OR a.title = 'The New Danger';
```

## Recursos não suportados

O `sql-formatter` não implementa todos os ajustes do DataGrip. Ficam de fora:

- alinhamento de `AS` e de aliases (`SELECT_ALIGN_AS`);
- alinhamento em matriz de `INSERT ... VALUES`;
- quebra automática do `ON` do `JOIN` em linha própria;
- alinhamento de comentários e de operadores binários;
- inclusão automática da palavra `AS` quando ela não existe.

Esses itens exigiam o formatador da JetBrains. Se algum for indispensável, a
alternativa é manter uma configuração local do DataGrip fora do repositório.

> `indentStyle` está marcado como obsoleto no `sql-formatter` 15.x, mas ainda
> funciona. Se for removido em uma versão futura, troque para `"standard"`.

## Precedência da configuração

1. variável de ambiente `SQL_FORMATTER_CONFIG`;
2. arquivo `.sql-formatter.json` no diretório do SQL ou em um diretório pai;
3. perfil padrão do repositório: `~/.config/nvim/sql-formatter.json`.

Para usar um estilo específico em um projeto, crie `.sql-formatter.json` na
raiz dele:

```json
{
  "language": "postgresql",
  "tabWidth": 4,
  "keywordCase": "lower",
  "indentStyle": "standard"
}
```

Ou aponte um arquivo por sessão:

```sh
export SQL_FORMATTER_CONFIG="$HOME/estilos/sql-formatter.json"
nvim consulta.sql
```

Dentro do Neovim também é possível definir temporariamente:

```vim
:let $SQL_FORMATTER_CONFIG = expand('~/estilos/sql-formatter.json')
```

## Uso

O auto-format ao salvar fica desligado para SQL (o auto-save pode disparar o
hook no meio da edição). Formate explicitamente com:

- `Ctrl+Alt+L` no modo normal ou visual;
- `<leader>cf` (atalho padrão do LazyVim).

O buffer inteiro é formatado; a seleção visual não limita o trecho.

Para diagnosticar:

```vim
:ConformInfo
```

`sql_formatter` deve aparecer como disponível. Se não aparecer, confira:

```sh
command -v sql-formatter
# ou
ls ~/.local/share/nvim/mason/bin/sql-formatter
```

Instale pelo Mason com:

```vim
:MasonInstall sql-formatter
```

## Testes

O teste do spec valida o registro no Conform, a descoberta de configuração, o
atalho buffer-local e, quando o binário está disponível, a saída formatada:

```sh
nvim -l ~/.config/nvim/tests/test-sql-format.lua
```

## Migração

A versão anterior usava o `format.sh` do DataGrip com um XML de Code Style. O
wrapper, o XML e os testes correspondentes foram removidos. O perfil JSON
versionado substitui o XML para os recursos listados acima.
