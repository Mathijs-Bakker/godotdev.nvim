vim.api.nvim_create_autocmd("FileType", {
  pattern = "gdscript",
  callback = function()
    vim.bo.expandtab = true -- convert <Tab> to spaces
    vim.bo.shiftwidth = 4 -- number of spaces for indent
    vim.bo.softtabstop = 4 -- spaces when pressing <Tab>
    vim.bo.softtabstop = 4
    vim.bo.tabstop = 4 -- Show tabs as 4 spaces
    vim.bo.autoindent = true -- Enable autoindent
    vim.bo.smartindent = true
  end,
})

-- Autoformat .gd files on save using gdformat
vim.api.nvim_create_autocmd("BufWritePost", {
  pattern = "*.gd",
  callback = function()
    -- Run gdformat on the file
    vim.cmd("silent !gdformat %")
    -- Reload the buffer to reflect changes
    vim.cmd("edit")
  end,
})
