-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
-- Função para encontrar a raiz do projeto (onde tem .git, pom.xml ou build.gradle)
local function find_project_root()
  local root_markers = { ".git", "pom.xml", "build.gradle", "gradlew", "mvnw" }
  for _, marker in ipairs(root_markers) do
    local root = vim.fn.finddir(marker, vim.fn.getcwd() .. ";")
    if root ~= "" then
      return vim.fn.fnamemodify(root, ":h")
    end
  end
  return vim.fn.getcwd() -- fallback para diretório atual
end

-- Função para procurar Main.java em ordem prioritária
local function find_main_java_priority()
  local current_dir = vim.fn.expand("%:p:h") -- diretório do arquivo atual
  local project_root = find_project_root()
  local src_dir = project_root .. "/src" -- assume src na raiz

  -- 1. Mesma pasta do arquivo atual
  local same_dir_file = current_dir .. "/Main.java"
  if vim.fn.filereadable(same_dir_file) == 1 then
    return same_dir_file
  end
  same_dir_file = current_dir .. "/main.java"
  if vim.fn.filereadable(same_dir_file) == 1 then
    return same_dir_file
  end

  -- 2. Pasta src (qualquer nível? Vamos buscar src/**/Main.java)
  if vim.fn.isdirectory(src_dir) == 1 then
    local src_mains = vim.fn.globpath(src_dir, "**/Main.java", false, true)
    if #src_mains > 0 then
      return src_mains[1]
    end
    src_mains = vim.fn.globpath(src_dir, "**/main.java", false, true)
    if #src_mains > 0 then
      return src_mains[1]
    end
  end

  -- 3. Fallback: busca recursiva geral (qualquer lugar)
  local general_mains = vim.fn.globpath(".", "**/Main.java", false, true)
  if #general_mains == 0 then
    general_mains = vim.fn.globpath(".", "**/main.java", false, true)
  end
  if #general_mains > 0 then
    return general_mains[1]
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

  -- Abre terminal dividido e executa
  vim.cmd("split | terminal")
  vim.cmd("wincmd j")
  local cmd = string.format("cd %s && javac %s && java %s\n", dir, file, class_name)
  vim.api.nvim_feedkeys(cmd, "n", false)
end, { desc = "Run Java (Main.java priority: same folder → src → recursive → current file)" })
