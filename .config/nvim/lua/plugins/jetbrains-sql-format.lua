local scheme_name = "datagrip-sqlstyle-guide-postgresql.xml"
local fallback_scheme = "/home/red/workspace/redfood/" .. scheme_name

local function find_scheme(filename)
  if vim.env.JETBRAINS_SQL_CODE_STYLE and vim.env.JETBRAINS_SQL_CODE_STYLE ~= "" then
    return vim.env.JETBRAINS_SQL_CODE_STYLE
  end

  local start = vim.fs.dirname(filename)
  local found = vim.fs.find(scheme_name, { path = start, upward = true, type = "file" })[1]
  return found or fallback_scheme
end

return {
  "stevearc/conform.nvim",
  init = function()
    -- LazyVim formats buffers on BufWritePre. Auto-save can trigger that hook
    -- while SQL is being edited, so opt SQL buffers out of automatic format.
    -- The explicit Ctrl+Alt+L mapping still calls Conform directly.
    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("jetbrains_sql_manual_format", { clear = true }),
      pattern = "sql",
      callback = function(event)
        vim.b[event.buf].autoformat = false
        vim.keymap.set({ "n", "x" }, "<C-M-l>", function()
          require("conform").format({ formatters = { "jetbrains_sql" }, timeout_ms = 30000 })
        end, {
          buffer = event.buf,
          desc = "Format (JetBrains Code Style)",
        })
      end,
      desc = "Disable automatic SQL formatting",
    })
  end,
  opts = function(_, opts)
    opts.formatters_by_ft = opts.formatters_by_ft or {}
    opts.formatters = opts.formatters or {}

    opts.formatters_by_ft.sql = { "jetbrains_sql" }
    opts.formatters.jetbrains_sql = {
      command = vim.fn.stdpath("config") .. "/scripts/jetbrains-sql-format.sh",
      args = function(_, ctx)
        return { find_scheme(ctx.filename), "$FILENAME" }
      end,
      stdin = false,
      tmpfile_format = ".conform.$RANDOM.$FILENAME",
      exit_codes = { 0 },
    }
  end,
}
