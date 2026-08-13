return {
  {
    "kristijanhusak/vim-dadbod-ui",
    init = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "sql",
        callback = function(event)
          vim.keymap.set({ "n", "x" }, "<leader>S", "<Plug>(DBUI_ExecuteQuery)", {
            buffer = event.buf,
            remap = true,
            desc = "Execute DB query",
          })
        end,
      })
    end,
  },
}