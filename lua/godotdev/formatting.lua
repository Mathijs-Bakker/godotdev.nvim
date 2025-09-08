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
      vim.cmd("silent !gdformat %")
      vim.cmd("checktime")
    else
      vim.notify("gdformat not found in PATH", vim.log.levels.WARN)
    end
  end,
})
