return {
  {
    "okuuva/auto-save.nvim",
    version = "^1.0.0", -- Use versões estáveis
    cmd = "ASToggle", -- Comando para toggle (ligar/desligar)
    event = { "InsertLeave", "TextChanged" }, -- Eventos que disparam o auto-save
    keys = {
      { "<leader>as", "<cmd>ASToggle<CR>", desc = "Toggle AutoSave" }, -- Tecla para ativar/desativar
    },
    opts = {
      enabled = true, -- Ativa automaticamente ao carregar
      trigger_events = {
        immediate_save = { "BufLeave", "FocusLost" }, -- Salva imediatamente ao sair do buffer ou perder foco
        defer_save = { "InsertLeave", "TextChanged" }, -- Salva com debounce após esses eventos
        cancel_deferred_save = { "InsertEnter" }, -- Cancela salvamento pendente ao entrar em insert mode
      },
      debounce_delay = 1000, -- Aguarda 1000ms (1 segundo) antes de salvar
      condition = function(buf)
        -- Exclui buffers especiais que não devem ser salvos automaticamente
        local excluded_filetypes = {
          "NvimTree",
          "TelescopePrompt",
          "neo-tree",
          "lazygit",
          "toggleterm",
        }
        local filetype = vim.fn.getbufvar(buf, "&filetype")
        if vim.tbl_contains(excluded_filetypes, filetype) then
          return false
        end
        return true
      end,
    },
  },
}
