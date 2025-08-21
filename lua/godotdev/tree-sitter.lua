local ok, ts_configs = pcall(require, "nvim-treesitter.configs")
if not ok then
  return
end

ts_configs.setup({
  ensure_installed = { "gdscript" },
  highlight = {
    enable = true,
    additional_vim_regex_highlighting = false,
  },
})

vim.filetype.add({
  extension = {
    gdshader = "gdshader",
  },
})

local parsers_ok, ts_parsers = pcall(require, "nvim-treesitter.parsers")
if parsers_ok then
  local parser_configs = ts_parsers.get_parser_configs()
  parser_configs.gdshader = {
    used_by = { "gdshader" }, -- filetype
    install_info = {
      url = "", -- no external parser
      files = {}, -- no parser files
      generate_requires_npm = false,
      requires_generate_from_grammar = false,
    },
  }
end
