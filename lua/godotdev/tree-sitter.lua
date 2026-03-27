local M = {}

local function get_config()
  local ok, godotdev = pcall(require, "godotdev")
  if not ok then
    return {}
  end

  return godotdev.opts.treesitter or {}
end

local function setup_filetypes()
  vim.filetype.add({
    extension = {
      gdshader = "gdshader",
    },
  })
end

function M.setup()
  setup_filetypes()

  local config = get_config()
  if config.auto_setup == false then
    return
  end

  local ok, ts_configs = pcall(require, "nvim-treesitter.configs")
  if not ok then
    return
  end

  ts_configs.setup({
    ensure_installed = config.ensure_installed or { "gdscript" },
    highlight = {
      enable = true,
      additional_vim_regex_highlighting = false,
    },
  })
end

return M
