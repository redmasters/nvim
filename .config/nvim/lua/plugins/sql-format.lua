local bundled_config = vim.fn.stdpath("config") .. "/sql-formatter.json"

local function find_config(filename)
  if vim.env.SQL_FORMATTER_CONFIG and vim.env.SQL_FORMATTER_CONFIG ~= "" then
    return vim.env.SQL_FORMATTER_CONFIG
  end

  local start = filename and filename ~= "" and vim.fs.dirname(filename) or vim.fn.getcwd()
  local found = vim.fs.find(".sql-formatter.json", { path = start, upward = true, type = "file" })[1]
  return found or bundled_config
end

return {
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "sql-formatter" } },
  },
  {
    "stevearc/conform.nvim",
    init = function()
      -- O auto-save pode disparar o BufWritePre no meio da edição de SQL.
      -- O atalho explícito continua formatando o buffer inteiro.
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("sql_manual_format", { clear = true }),
        pattern = "sql",
        callback = function(event)
          vim.b[event.buf].autoformat = false
          vim.keymap.set({ "n", "x" }, "<C-M-l>", function()
            require("conform").format({ formatters = { "sql_formatter" }, timeout_ms = 30000 })
          end, {
            buffer = event.buf,
            desc = "Format (SQL)",
          })
        end,
        desc = "Disable automatic SQL formatting",
      })
    end,
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters = opts.formatters or {}

      opts.formatters_by_ft.sql = { "sql_formatter" }
      opts.formatters.sql_formatter = {
        command = "sql-formatter",
        args = function(_, ctx)
          return { "-c", find_config(ctx.filename) }
        end,
        stdin = true,
      }
    end,
  },
}
