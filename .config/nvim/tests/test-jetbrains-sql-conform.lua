local config = vim.fn.stdpath("config")
local plugin_path = config .. "/lua/plugins/jetbrains-sql-format.lua"

assert(vim.fn.filereadable(plugin_path) == 1, "JetBrains SQL Conform plugin is missing")

local spec = dofile(plugin_path)
assert(spec[1] == "stevearc/conform.nvim", "unexpected Conform plugin spec")
assert(type(spec.init) == "function", "SQL autoformat guard is missing")
assert(type(spec.opts) == "function", "Conform opts extension must be a function")

spec.init()
local autocmds = vim.api.nvim_get_autocmds({ group = "jetbrains_sql_manual_format", event = "FileType" })
assert(#autocmds == 1 and autocmds[1].pattern == "sql", "SQL FileType autocmd is missing")

local sql_buf = vim.api.nvim_create_buf(false, true)
autocmds[1].callback({ buf = sql_buf, match = "sql" })
assert(vim.b[sql_buf].autoformat == false, "automatic SQL formatting was not disabled")
vim.api.nvim_set_current_buf(sql_buf)
for _, mode in ipairs({ "n", "x" }) do
  local map = vim.fn.maparg("<C-M-l>", mode, false, true)
  assert(type(map.callback) == "function", "Ctrl+Alt+L is missing in SQL mode " .. mode)
  assert(map.buffer == 1, "Ctrl+Alt+L must be buffer-local in SQL mode " .. mode)
  assert(map.desc == "Format (JetBrains Code Style)", "unexpected Ctrl+Alt+L description")
end

local lua_buf = vim.api.nvim_create_buf(false, true)
assert(vim.b[lua_buf].autoformat == nil, "non-SQL autoformat was changed")
vim.api.nvim_set_current_buf(lua_buf)
for _, mode in ipairs({ "n", "x" }) do
  assert(vim.tbl_isempty(vim.fn.maparg("<C-M-l>", mode, false, true)), "Ctrl+Alt+L leaked into non-SQL mode " .. mode)
end

local opts = {
  formatters_by_ft = {},
  formatters = {},
}
spec.opts(nil, opts)

assert(vim.deep_equal(opts.formatters_by_ft.sql, { "jetbrains_sql" }), "SQL formatter was not registered")
local formatter = opts.formatters.jetbrains_sql
assert(type(formatter) == "table", "jetbrains_sql formatter definition is missing")
assert(formatter.stdin == false, "jetbrains_sql must format a temporary file")
assert(type(formatter.command) == "string" and formatter.command:match("jetbrains%-sql%-format%.sh$"), "wrong wrapper")
assert(type(formatter.args) == "function", "formatter args must discover the XML")

local project = vim.fn.tempname()
vim.fn.mkdir(project, "p")
local sql = project .. "/query.sql"
local scheme = project .. "/datagrip-sqlstyle-guide-postgresql.xml"
vim.fn.writefile({ "select 1;" }, sql)
vim.fn.writefile({ '<code_scheme name="test" />' }, scheme)
local args = formatter.args(formatter, { filename = sql })
assert(vim.deep_equal(args, { scheme, "$FILENAME" }), "project XML was not discovered: " .. vim.inspect(args))
vim.fn.delete(project, "rf")

vim.env.JETBRAINS_SQL_CODE_STYLE = "/tmp/custom-jetbrains-style.xml"
args = formatter.args(formatter, { filename = sql })
assert(args[1] == "/tmp/custom-jetbrains-style.xml", "environment scheme override was ignored")
vim.env.JETBRAINS_SQL_CODE_STYLE = nil

-- Load the real keymap file after stubbing the globals it references.
_G.Snacks = _G.Snacks or { terminal = { focus = function() end } }
_G.LazyVim = _G.LazyVim or {
  root = function()
    return vim.fn.getcwd()
  end,
  format = function() end,
}
vim.keymap.set("n", "<leader>cf", function() end, { desc = "Format" })
dofile(config .. "/lua/config/keymaps.lua")
assert(not vim.tbl_isempty(vim.fn.maparg("<leader>cf", "n", false, true)), "LazyVim leader-cf was removed")

print("PASS: SQL autoformat disabled; JetBrains formatter available only through Ctrl+Alt+L")
