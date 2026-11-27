-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Raiz do projeto: .git, pom.xml, build.gradle, gradlew ou mvnw
local function find_project_root()
  return vim.fs.root(0, { ".git", "pom.xml", "build.gradle", "gradlew", "mvnw" }) or vim.fn.getcwd()
end

-- Procura Main.java em ordem prioritária: pasta atual, src, projeto
local function find_main_java_priority()
  local current_dir = vim.fn.expand("%:p:h")
  local project_root = find_project_root()

  -- 1. Mesma pasta do arquivo atual
  for _, name in ipairs({ "Main.java", "main.java" }) do
    local candidate = current_dir .. "/" .. name
    if vim.fn.filereadable(candidate) == 1 then
      return candidate
    end
  end

  -- 2. Qualquer Main.java dentro de src
  local src_dir = project_root .. "/src"
  if vim.fn.isdirectory(src_dir) == 1 then
    for _, pattern in ipairs({ "**/Main.java", "**/main.java" }) do
      local found = vim.fn.globpath(src_dir, pattern, false, true)
      if #found > 0 then
        return found[1]
      end
    end
  end

  -- 3. Fallback: busca recursiva na raiz do projeto
  for _, pattern in ipairs({ "**/Main.java", "**/main.java" }) do
    local found = vim.fn.globpath(project_root, pattern, false, true)
    if #found > 0 then
      return found[1]
    end
  end

  return nil
end

-- Atalho para executar Java (prioridade para Main.java na mesma pasta ou src)
vim.keymap.set("n", "<leader>rj", function()
  local main_file = find_main_java_priority()
  local file, class_name, dir

  if main_file then
    file = vim.fn.fnamemodify(main_file, ":t") -- Main.java
    class_name = vim.fn.fnamemodify(main_file, ":t:r") -- Main
    dir = vim.fn.fnamemodify(main_file, ":p:h") -- diretório do Main.java
  else
    -- Usa o arquivo atual
    file = vim.fn.expand("%:t")
    class_name = vim.fn.expand("%:t:r")
    dir = vim.fn.expand("%:p:h")
  end

  -- Abre o terminal abaixo e mantém o foco nele
  vim.cmd("botright split | terminal")
  local cmd = string.format(
    "cd %s && javac %s && java %s\n",
    vim.fn.shellescape(dir),
    vim.fn.shellescape(file),
    vim.fn.shellescape(class_name)
  )
  vim.api.nvim_feedkeys(cmd, "n", false)
end, { desc = "Run Java (Main.java priority: same folder → src → recursive → current file)" })
