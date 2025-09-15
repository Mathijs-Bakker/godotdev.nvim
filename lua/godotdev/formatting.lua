local config = require("godotdev").opts

vim.api.nvim_create_autocmd("BufWritePost", {
  pattern = "*.gd",
  callback = function()
    local exe = config.formatter_cmd or config.formatter
    if vim.fn.executable(exe) ~= 1 then
      vim.notify(exe .. " not found in PATH. Run `:checkhealth godotdev` for more info.", vim.log.levels.WARN)
      return
    end

    if config.formatter == "gdformat" then
      vim.cmd("silent !" .. exe .. " %")
    elseif config.formatter == "gdscript-format" then
      vim.cmd("silent !" .. exe .. " %")
    end

    vim.cmd("checktime")
  end,
})
