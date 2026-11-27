local function run(args)
  vim.api.nvim_cmd({ cmd = "CodeDiff", args = args }, {})
end

local function prompt(label, args)
  vim.ui.input({ prompt = label .. ": " }, function(input)
    if input and input ~= "" then
      run(vim.list_extend(vim.deepcopy(args), { vim.trim(input) }))
    end
  end)
end

return {
  {
    "esmuellert/codediff.nvim",
    cmd = "CodeDiff",
    opts = {},
    keys = {
      {
        "<leader>gvd",
        function()
          run({})
        end,
        desc = "CodeDiff: Working Tree",
      },
      {
        "<leader>gvs",
        function()
          run({ "--staged" })
        end,
        desc = "CodeDiff: Staged",
      },
      {
        "<leader>gvh",
        function()
          run({ "history" })
        end,
        desc = "CodeDiff: History",
      },
      {
        "<leader>gvc",
        function()
          run({ "file", "HEAD" })
        end,
        desc = "CodeDiff: Current File vs HEAD",
      },
      {
        "<leader>gvr",
        function()
          prompt("Revision", {})
        end,
        desc = "CodeDiff: Revision",
      },
      {
        "<leader>gvp",
        function()
          prompt("PR number", { "pr" })
        end,
        desc = "CodeDiff: Pull Request",
      },
    },
  },
  {
    "folke/which-key.nvim",
    opts = { spec = { { "<leader>gv", group = "codediff" } } },
  },
}
