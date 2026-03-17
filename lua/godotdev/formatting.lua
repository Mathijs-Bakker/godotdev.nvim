local config = require("godotdev").opts

vim.api.nvim_create_autocmd("BufWritePost", {
  pattern = "*.gd",
  callback = function()
    local cmd = config.formatter_cmd or config.formatter
    local bin = cmd
    if cmd:find("%s") then
      bin = vim.split(cmd, "%s+")[1]
    end
    if vim.fn.executable(bin) ~= 1 then
      vim.notify(bin .. " not found in PATH. Run `:checkhealth godotdev` for more info.", vim.log.levels.WARN)
      return
    end

    if config.formatter == "gdformat" then
      vim.cmd("silent !" .. cmd .. " %")
    elseif config.formatter == "gdscript-format" then
      vim.cmd("silent !" .. cmd .. " %")
    end

    vim.cmd("checktime")
  end,
})
