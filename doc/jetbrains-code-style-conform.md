# Code Style JetBrains no LazyVim com conform.nvim

Este documento descreve a integração que permite formatar SQL no LazyVim com o mesmo XML de Code Style usado pelo DataGrip. Também explica como estender a solução para Java, Kotlin e outras linguagens suportadas por produtos JetBrains.

## Visão geral

O `conform.nvim` não formata código por conta própria e não interpreta XMLs da JetBrains. Ele funciona como um orquestrador:

```text
Ctrl+Alt+L
    ↓
conform.nvim
    ↓
wrapper shell
    ↓
format.sh do produto JetBrains
    ↓
XML de Code Style
    ↓
pós-processador de whitespace para CREATE TABLE
    ↓
validador baseado no SQL Style Guide
    ↓
buffer formatado no Neovim
```

A integração SQL usa componentes que já estavam instalados:

- LazyVim;
- `conform.nvim`;
- DataGrip e seu `bin/format.sh`;
- um XML de Code Style exportado pela JetBrains.

Não é necessário instalar SQLFluff ou pgFormatter.

## Regra obrigatória de validação

Toda execução do formatter termina com uma validação baseada em
<https://www.sqlstyle.guide/>. O validador cobre apenas regras que podem ser
verificadas deterministicamente sem interpretar a semântica da consulta:

- palavras-chave estruturais em maiúsculas;
- ausência de tabs e espaços no fim das linhas;
- uma definição por linha em `CREATE TABLE`;
- `PRIMARY KEY` inline;
- separação e recuo consistente de constraints;
- constraints `UNIQUE` nomeadas em duas linhas (`CONSTRAINT` e `UNIQUE`);
- fechamento consistente de `CREATE TABLE`.

O guia recomenda quatro espaços para colunas de `CREATE TABLE`, mas também
enfatiza que o principal é escolher um estilo e aplicá-lo consistentemente.
Esta configuração adota explicitamente a variação do projeto: 6 espaços para
colunas/`CONSTRAINT`, 10 para componentes de FK e 2 para `);`. Regras de nomes,
modelagem, escolha de tipos e portabilidade continuam exigindo revisão humana.

Antes de qualquer nova alteração no formatter, o resultado deve ser comparado
com <https://www.sqlstyle.guide/>. Se a formatação solicitada conflitar com o
guia, a alteração não deve ser aplicada até o usuário autorizar explicitamente
a exceção. Preferências já autorizadas do projeto, como o recuo 6/10/2, não
precisam ser perguntadas novamente.

## Arquivos da implementação

A configuração está versionada nestes caminhos do repositório:

| Arquivo | Responsabilidade |
| --- | --- |
| `.config/nvim/lua/plugins/jetbrains-sql-format.lua` | Registra `jetbrains_sql` no Conform e associa o formatter ao filetype `sql`. |
| `.config/nvim/scripts/jetbrains-sql-format.sh` | Valida os caminhos, cria um ambiente DataGrip isolado, executa `format.sh -s` e chama o pós-processador. |
| `.config/nvim/scripts/sql_style_lexer.py` | Mascara comentários, strings, identificadores citados e dollar quotes para impedir alterações dentro de conteúdo não executável. |
| `.config/nvim/scripts/jetbrains-sql-postprocess.py` | Normaliza apenas whitespace de `CREATE TABLE`: `PRIMARY KEY` inline, FK com recuo de 4 espaços e fechamento com recuo de 2. |
| `.config/nvim/scripts/validate-sqlstyle-guide.py` | Valida automaticamente as regras mecanicamente verificáveis adotadas de <https://www.sqlstyle.guide/>. |
| `.config/nvim/lua/plugins/jetbrains-sql-format.lua` | Define `Ctrl+Alt+L` localmente nos buffers SQL, nos modos normal e visual. |
| `.config/nvim/tests/test-jetbrains-sql-format.sh` | Testa o contrato do wrapper sem executar o DataGrip real. |
| `.config/nvim/tests/test-jetbrains-sql-conform.lua` | Testa o spec do Conform, descoberta do XML e atalhos. |

O cache isolado do formatter fica fora do Git:

```text
~/.cache/nvim/jetbrains-datagrip-formatter/
```

Ele contém `config`, `system`, `plugins`, `log` e `idea.properties`. Esse isolamento evita usar ou modificar o perfil normal do DataGrip e contorna o bloqueio de instância única.

## Como usar para SQL

### Pré-requisitos

1. DataGrip instalado pelo JetBrains Toolbox no caminho esperado:

   ```text
   ~/.local/share/JetBrains/Toolbox/apps/datagrip/bin/format.sh
   ```

2. Um XML válido de Code Style da JetBrains.
3. O arquivo aberto no Neovim precisa ter filetype `sql`.

Confira o filetype no Neovim com:

```vim
:set filetype?
```

O resultado esperado é:

```text
filetype=sql
```

### Formatar

No modo normal ou visual, pressione:

```text
Ctrl+Alt+L
```

O formatter atual sempre formata o buffer inteiro. Uma seleção visual não limita a operação somente ao trecho selecionado, porque o CLI JetBrains trabalha sobre um arquivo.

O atalho padrão do LazyVim também permanece disponível:

```text
Space c f
```

Para inspecionar os formatters associados ao buffer:

```vim
:ConformInfo
```

Para SQL, `jetbrains_sql` deve aparecer como disponível.

### Como o XML SQL é encontrado

A função `find_scheme()` em `jetbrains-sql-format.lua` usa a seguinte precedência:

1. variável de ambiente `JETBRAINS_SQL_CODE_STYLE`;
2. arquivo chamado `datagrip-sqlstyle-guide-postgresql.xml` no diretório do SQL ou em algum diretório pai;
3. fallback local:

   ```text
   /home/red/workspace/redfood/datagrip-sqlstyle-guide-postgresql.xml
   ```

Isso permite colocar o XML na raiz de cada projeto sem editar a configuração do Neovim.

Exemplo por sessão:

```sh
export JETBRAINS_SQL_CODE_STYLE="$HOME/code-styles/postgresql.xml"
nvim consultas.sql
```

A variável precisa estar presente no ambiente que inicia o Neovim. Se o Neovim já estiver aberto, também pode ser definida temporariamente nele:

```vim
:let $JETBRAINS_SQL_CODE_STYLE = expand('~/code-styles/postgresql.xml')
```

## Exportar um XML na JetBrains

No IntelliJ IDEA ou DataGrip:

1. Abra `Settings`.
2. Acesse `Editor | Code Style`.
3. Selecione ou crie o esquema desejado.
4. Abra o menu de ações ao lado do nome do esquema.
5. Use `Export | IntelliJ IDEA code style XML`.
6. Salve o XML em uma localização versionada ou compartilhada.

Há duas estratégias possíveis:

### Um esquema para várias linguagens

Um único XML exportado pelo IntelliJ IDEA pode conter seções para Java, Kotlin, XML e outras linguagens. O mesmo arquivo pode ser passado ao `format.sh` do IntelliJ para arquivos diferentes.

Vantagens:

- uma única fonte de verdade;
- regras comuns, como margem e indentação, ficam centralizadas;
- menos variáveis de ambiente.

### Um XML por linguagem

Também é possível manter arquivos independentes, por exemplo:

```text
code-styles/
├── java.xml
├── kotlin.xml
├── postgresql.xml
└── xml.xml
```

Vantagens:

- cada time ou projeto pode atualizar uma linguagem sem alterar as demais;
- seleção explícita por filetype;
- facilita testar cada esquema isoladamente.

A estrutura interna do XML é definida pela JetBrains. Não copie opções SQL para uma seção Java ou Kotlin: exporte o esquema pelo produto que realmente oferece suporte à linguagem.

## Adicionar Java ou Kotlin

> A configuração atual não formata Java ou Kotlin. Os passos desta seção são uma receita de extensão, não uma funcionalidade já habilitada.

### Escolher o produto correto

O wrapper SQL usa DataGrip, que é apropriado para SQL. Para Java e Kotlin, use o formatter do IntelliJ IDEA:

```text
~/.local/share/JetBrains/Toolbox/apps/intellij-idea/bin/format.sh
```

Nesta máquina esse launcher existe. Em outra instalação, confirme o caminho antes de configurar.

Cada produto possui uma variável própria para apontar o arquivo `idea.properties` isolado:

- DataGrip: `DATAGRIP_PROPERTIES`;
- IntelliJ IDEA: normalmente `IDEA_PROPERTIES`.

Confirme o nome na versão instalada procurando `idea.properties.file` em `bin/idea.sh` antes de criar o wrapper. Não reutilize cegamente `DATAGRIP_PROPERTIES` com IntelliJ.

### 1. Exportar o esquema apropriado

No IntelliJ IDEA:

1. Configure `Editor | Code Style | Java` e/ou `Kotlin`.
2. Exporte como `IntelliJ IDEA code style XML`.
3. Salve como um esquema conjunto ou como arquivos separados.
4. Valide que o XML foi exportado pelo IntelliJ que contém os plugins das linguagens desejadas.

Exemplos de nomes:

```text
jetbrains-code-style.xml
jetbrains-java-code-style.xml
jetbrains-kotlin-code-style.xml
```

### 2. Criar um wrapper para IntelliJ

Não altere o wrapper SQL para apontar para o IntelliJ: mantenha os produtos isolados e os testes independentes.

Crie, por exemplo:

```text
.config/nvim/scripts/jetbrains-idea-format.sh
```

O novo wrapper deve reproduzir as proteções de `jetbrains-sql-format.sh`:

1. aceitar `<code-style.xml>` e `<arquivo>`;
2. verificar se ambos são legíveis e se o arquivo é gravável;
3. localizar `intellij-idea/bin/format.sh`;
4. criar diretórios isolados em:

   ```text
   ~/.cache/nvim/jetbrains-idea-formatter/
   ```

5. criar `idea.properties` com:

   ```properties
   idea.config.path=<cache>/config
   idea.system.path=<cache>/system
   idea.plugins.path=<cache>/plugins
   idea.log.path=<cache>/log
   idea.auto.reload.plugins=false
   ```

6. exportar a variável de properties esperada pela versão instalada do IntelliJ;
7. executar:

   ```sh
   "$FORMATTER" -s "$SCHEME" "$SOURCE_FILE"
   ```

Use caminhos entre aspas, `umask 077` e nunca execute conteúdo vindo do XML.

### 3. Registrar formatters no Conform

Crie um plugin spec separado, por exemplo:

```text
.config/nvim/lua/plugins/jetbrains-idea-format.lua
```

Para XMLs separados, a configuração conceitual é:

```lua
return {
  "stevearc/conform.nvim",
  opts = function(_, opts)
    opts.formatters_by_ft = opts.formatters_by_ft or {}
    opts.formatters = opts.formatters or {}

    opts.formatters_by_ft.java = { "jetbrains_java" }
    opts.formatters_by_ft.kotlin = { "jetbrains_kotlin" }

    opts.formatters.jetbrains_java = {
      command = vim.fn.stdpath("config") .. "/scripts/jetbrains-idea-format.sh",
      args = { vim.env.JETBRAINS_JAVA_CODE_STYLE, "$FILENAME" },
      stdin = false,
      exit_codes = { 0 },
    }

    opts.formatters.jetbrains_kotlin = {
      command = vim.fn.stdpath("config") .. "/scripts/jetbrains-idea-format.sh",
      args = { vim.env.JETBRAINS_KOTLIN_CODE_STYLE, "$FILENAME" },
      stdin = false,
      exit_codes = { 0 },
    }
  end,
}
```

Esse trecho é um modelo. Antes de usá-lo em produção, adicione funções de descoberta e validação para não passar valores vazios ao wrapper.

Variáveis sugeridas:

```sh
export JETBRAINS_JAVA_CODE_STYLE="$HOME/code-styles/java.xml"
export JETBRAINS_KOTLIN_CODE_STYLE="$HOME/code-styles/kotlin.xml"
```

Se um único XML contiver Java e Kotlin, ambas as variáveis podem apontar para o mesmo arquivo:

```sh
export JETBRAINS_JAVA_CODE_STYLE="$HOME/code-styles/jetbrains-code-style.xml"
export JETBRAINS_KOTLIN_CODE_STYLE="$HOME/code-styles/jetbrains-code-style.xml"
```

Para Kotlin, o filetype usual do Neovim é `kotlin`. Confirme com `:set filetype?`, pois extensões ou plugins podem usar nomes adicionais em casos especiais.

### 4. Reutilizar Ctrl+Alt+L

O mapa atual chama explicitamente apenas `jetbrains_sql`:

```lua
require("conform").format({
  formatters = { "jetbrains_sql" },
  timeout_ms = 30000,
})
```

Portanto, somente registrar Java/Kotlin no `formatters_by_ft` não é suficiente enquanto esse mapa continuar SQL-only.

Ao adicionar outras linguagens, altere o callback para deixar o Conform escolher o formatter pelo filetype:

```lua
require("conform").format({ timeout_ms = 30000 })
```

Outra opção é selecionar explicitamente por filetype:

```lua
local formatters = {
  sql = { "jetbrains_sql" },
  java = { "jetbrains_java" },
  kotlin = { "jetbrains_kotlin" },
}

require("conform").format({
  formatters = formatters[vim.bo.filetype],
  timeout_ms = 30000,
})
```

A seleção explícita é preferível quando há outros formatters ou LSPs configurados e se deseja evitar fallback inesperado.

### 5. Adicionar testes antes de ativar

Para cada linguagem:

1. crie um fixture deliberadamente mal formatado;
2. execute o `format.sh` real com perfil isolado;
3. confirme que o arquivo foi alterado;
4. compare a saída exata com o resultado esperado;
5. confira `:ConformInfo`;
6. teste `Ctrl+Alt+L` em um buffer real;
7. confirme que a instância normal do IntelliJ não foi modificada;
8. remova todos os fixtures temporários.

Use arquivos temporários com prefixo `hermes-verify-*` para evitar colisões e facilitar a limpeza.

Exemplos de fixtures mínimos:

```java
class Example{public static void main(String[] args){System.out.println("ok");}}
```

```kotlin
class Example{fun message():String="ok"}
```

Não considere somente o exit code: leia o arquivo resultante e compare a formatação esperada.

## Adicionar outras linguagens

O processo é o mesmo para qualquer linguagem, desde que o produto JetBrains instalado tenha:

1. suporte à linguagem;
2. uma seção de Code Style exportável;
3. formatter CLI capaz de processar a extensão.

Exemplos:

| Linguagem | Produto provável | Filetype Neovim | Observação |
| --- | --- | --- | --- |
| SQL/PostgreSQL | DataGrip ou IntelliJ Ultimate | `sql` | Implementado atualmente com DataGrip. |
| Java | IntelliJ IDEA | `java` | Use XML exportado pelo IntelliJ. |
| Kotlin | IntelliJ IDEA com plugin Kotlin | `kotlin` | Confirme o plugin no ambiente isolado. |
| JavaScript/TypeScript | WebStorm ou IntelliJ | `javascript`, `typescript` | Use o launcher do produto que possui suporte JS/TS. |
| Rust | RustRover | `rust` | Avalie custo e resultado contra `rustfmt` antes de integrar. |
| XML | IntelliJ, WebStorm ou outro produto compatível | `xml` | Não confundir XML de código-fonte com XML de esquema de Code Style. |

Crie um cache isolado por produto, por exemplo:

```text
~/.cache/nvim/jetbrains-datagrip-formatter/
~/.cache/nvim/jetbrains-idea-formatter/
~/.cache/nvim/jetbrains-webstorm-formatter/
~/.cache/nvim/jetbrains-rustrover-formatter/
```

Isso evita compartilhar locks, índices e configurações entre produtos.

## Diagnóstico

### `jetbrains_sql` aparece como indisponível

Execute:

```vim
:ConformInfo
```

Depois confira:

```sh
test -x ~/.config/nvim/scripts/jetbrains-sql-format.sh
test -x ~/.config/nvim/scripts/jetbrains-sql-postprocess.py
test -x ~/.local/share/JetBrains/Toolbox/apps/datagrip/bin/format.sh
```

### XML não encontrado

Confira a variável dentro do Neovim:

```vim
:echo $JETBRAINS_SQL_CODE_STYLE
```

Confira também se o nome esperado existe na raiz do projeto:

```text
datagrip-sqlstyle-guide-postgresql.xml
```

### `Only one instance ... can be run at a time`

Isso indica que o formatter tentou usar o perfil normal do IDE. Verifique:

- se o wrapper criou `idea.properties` no cache isolado;
- se a variável correta (`DATAGRIP_PROPERTIES`, `IDEA_PROPERTIES` etc.) foi exportada;
- se todos os quatro caminhos `idea.*.path` apontam para o cache isolado.

Não feche automaticamente o IDE do usuário para resolver esse erro.

### O atalho não chega ao Neovim

No Neovim, confira:

```vim
:verbose nmap <C-M-l>
:verbose xmap <C-M-l>
```

Se não houver mapa, reinicie o LazyVim ou recarregue a configuração. Se houver mapa, investigue conflitos no terminal ou no ambiente gráfico.

### Formatação lenta

O formatter JetBrains inicia uma JVM. Nos testes locais, uma execução SQL levou aproximadamente três segundos. Isso é esperado e é o motivo pelo qual a integração usa formatação manual, sem format-on-save.

## Executar os testes atuais

A partir de `~/workspace/nvim`:

```sh
sh -n \
  .config/nvim/scripts/jetbrains-sql-format.sh \
  .config/nvim/tests/test-jetbrains-sql-format.sh

python3 -m py_compile \
  .config/nvim/scripts/sql_style_lexer.py \
  .config/nvim/scripts/jetbrains-sql-postprocess.py \
  .config/nvim/scripts/validate-sqlstyle-guide.py

sh .config/nvim/tests/test-jetbrains-sql-format.sh

nvim --headless \
  "+luafile .config/nvim/tests/test-jetbrains-sql-conform.lua" \
  +qa
```

O primeiro teste usa um formatter falso e valida o contrato do wrapper e a saída exata do pós-processador. O segundo testa o spec do Conform, a descoberta do XML e os atalhos. A validação end-to-end com o DataGrip real deve usar um fixture temporário e comparar o arquivo resultante byte a byte.

## Limitações conhecidas

- `conform.nvim` não interpreta XML JetBrains; ele depende do executável externo.
- A integração atual é somente SQL.
- O atalho atual seleciona explicitamente `jetbrains_sql`.
- Formatação por range/seleção não foi implementada; o buffer inteiro é formatado.
- O formatter JetBrains é mais lento que formatters nativos.
- O recuo DDL exato de 6/10/2 espaços não é representável somente pelas opções do DataGrip; o wrapper aplica uma normalização de whitespace depois do formatter oficial.
- Um XML bem formado pode conter seções ignoradas pelo produto errado.
- DataGrip não deve ser tratado como formatter Java/Kotlin.
- `.editorconfig` em diretórios pais pode influenciar ou sobrescrever regras coincidentes, dependendo do produto e da configuração.
- Atualizações JetBrains podem alterar caminhos, variáveis ou o formato interno dos esquemas; reexecute os testes após upgrades.

## Referências

- JetBrains — command-line formatter do DataGrip: <https://www.jetbrains.com/help/datagrip/command-line-formatter.html>
- JetBrains — command-line formatter do IntelliJ IDEA: <https://www.jetbrains.com/help/idea/command-line-formatter.html>
- JetBrains — Code Style Schemes: <https://www.jetbrains.com/help/idea/configuring-code-style.html>
- Conform — opções de formatters customizados: <https://github.com/stevearc/conform.nvim/blob/master/doc/formatter_options.md>
