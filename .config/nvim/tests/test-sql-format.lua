local config = vim.fn.stdpath("config")
local plugin_path = config .. "/lua/plugins/sql-format.lua"

assert(vim.fn.filereadable(plugin_path) == 1, "SQL formatter plugin spec is missing")

local conform_spec
local has_mason = false
for _, spec in ipairs(dofile(plugin_path)) do
  if spec[1] == "stevearc/conform.nvim" then
    conform_spec = spec
  elseif spec[1] == "mason-org/mason.nvim" then
    has_mason = true
    assert(vim.tbl_contains(spec.opts.ensure_installed, "sql-formatter"), "sql-formatter is not ensured by Mason")
  end
end

assert(conform_spec, "Conform plugin spec is missing")
assert(has_mason, "Mason plugin spec is missing")
assert(type(conform_spec.init) == "function", "SQL autoformat guard is missing")
assert(type(conform_spec.opts) == "function", "Conform opts extension must be a function")

conform_spec.init()
local autocmds = vim.api.nvim_get_autocmds({ group = "sql_manual_format", event = "FileType" })
assert(#autocmds == 1 and autocmds[1].pattern == "sql", "SQL FileType autocmd is missing")

local sql_buf = vim.api.nvim_create_buf(false, true)
autocmds[1].callback({ buf = sql_buf, match = "sql" })
assert(vim.b[sql_buf].autoformat == false, "automatic SQL formatting was not disabled")
vim.api.nvim_set_current_buf(sql_buf)
for _, mode in ipairs({ "n", "x" }) do
  local map = vim.fn.maparg("<C-M-l>", mode, false, true)
  assert(type(map.callback) == "function", "Ctrl+Alt+L is missing in SQL mode " .. mode)
  assert(map.buffer == 1, "Ctrl+Alt+L must be buffer-local in SQL mode " .. mode)
  assert(map.desc == "Format (SQL)", "unexpected Ctrl+Alt+L description")
end

local lua_buf = vim.api.nvim_create_buf(false, true)
assert(vim.b[lua_buf].autoformat == nil, "non-SQL autoformat was changed")
vim.api.nvim_set_current_buf(lua_buf)
for _, mode in ipairs({ "n", "x" }) do
  assert(vim.tbl_isempty(vim.fn.maparg("<C-M-l>", mode, false, true)), "Ctrl+Alt+L leaked into non-SQL mode " .. mode)
end

local opts = { formatters_by_ft = {}, formatters = {} }
conform_spec.opts(nil, opts)

assert(vim.deep_equal(opts.formatters_by_ft.sql, { "sql_formatter" }), "SQL formatter was not registered")
local formatter = opts.formatters.sql_formatter
assert(type(formatter) == "table", "sql_formatter definition is missing")
assert(formatter.command == "sql-formatter", "wrong formatter command")
assert(formatter.stdin == true, "sql_formatter must read from stdin")
assert(type(formatter.args) == "function", "formatter args must discover the config")

local project = vim.fn.tempname()
vim.fn.mkdir(project, "p")
local sql = project .. "/query.sql"
local project_config = project .. "/.sql-formatter.json"
vim.fn.writefile({ "select 1;" }, sql)
vim.fn.writefile({ '{"keywordCase":"lower"}' }, project_config)

local args = formatter.args(formatter, { filename = sql })
assert(vim.deep_equal(args, { "-c", project_config }), "project config was not discovered: " .. vim.inspect(args))

vim.env.SQL_FORMATTER_CONFIG = "/tmp/custom-sql-formatter.json"
args = formatter.args(formatter, { filename = sql })
assert(args[2] == "/tmp/custom-sql-formatter.json", "environment config override was ignored")
vim.env.SQL_FORMATTER_CONFIG = nil

local bare = vim.fn.tempname()
vim.fn.mkdir(bare, "p")
args = formatter.args(formatter, { filename = bare .. "/query.sql" })
assert(args[2] == config .. "/sql-formatter.json", "bundled config fallback is wrong: " .. vim.inspect(args))
vim.fn.delete(bare, "rf")
vim.fn.delete(project, "rf")

local bundled = config .. "/sql-formatter.json"
local decoded_ok, bundled_config = pcall(vim.json.decode, table.concat(vim.fn.readfile(bundled), "\n"))
assert(decoded_ok, "bundled sql-formatter.json is not valid JSON")
assert(bundled_config.language == "postgresql", "bundled config must target PostgreSQL")
assert(bundled_config.keywordCase == "upper", "bundled config must uppercase keywords")
assert(bundled_config.tabWidth == 2, "bundled config must indent with 2 spaces")

local binary = vim.fn.exepath("sql-formatter")
if binary == "" then
  local mason_bin = vim.fn.stdpath("data") .. "/mason/bin/sql-formatter"
  if vim.fn.executable(mason_bin) == 1 then
    binary = mason_bin
  end
end

if binary ~= "" then
  local output = vim.fn.system({ binary, "-c", bundled }, "select 1 as x from t where a = 1 and b = 2;\n")
  assert(vim.v.shell_error == 0, "sql-formatter failed: " .. output)
  assert(output:match("SELECT 1 AS x"), "keywords were not uppercased: " .. output)
  assert(output:match("FROM t"), "FROM clause is missing: " .. output)
  assert(output:match("AND b = 2"), "logical operator formatting is wrong: " .. output)
else
  print("SKIP: sql-formatter binary not found; install it with :MasonInstall sql-formatter")
end

print("PASS: SQL formatter registered, config discovery works, Ctrl+Alt+L is buffer-local")
