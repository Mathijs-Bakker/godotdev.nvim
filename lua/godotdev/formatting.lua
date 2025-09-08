vim.api.nvim_create_autocmd("FileType", {
  pattern = "gdscript",
  callback = function()
    vim.bo.expandtab = true
    vim.bo.shiftwidth = 4
    vim.bo.softtabstop = 4
    vim.bo.tabstop = 4
    vim.bo.autoindent = true
    vim.bo.smartindent = true
  end,
})

vim.api.nvim_create_autocmd("BufWritePost", {
  pattern = "*.gd",
  callback = function()
    if vim.fn.executable("gdformat") == 1 then
      -- format with gdformat
      vim.cmd("silent !gdformat %")
      -- reload buffer if changed externally
      vim.cmd("checktime")
    else
      vim.notify("gdformat not found in PATH. Run `:checkhealth godotdev` for more info.", vim.log.levels.WARN)
    end
  end,
})
