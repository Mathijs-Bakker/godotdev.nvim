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
