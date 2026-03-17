local M = {}

local default_pipe = (vim.loop.os_uname().version:match("Windows")) and [[\\.\pipe\godot.nvim]] or "/tmp/godot.nvim"

local function start_editor_server(pipe)
  pipe = pipe or default_pipe
  if vim.v.servername ~= "" and vim.v.servername ~= pipe then
    vim.notify(
      "Neovim server already running on " .. vim.v.servername .. "; skipping start on " .. pipe,
      vim.log.levels.WARN
    )
    return
  end
  if vim.v.servername == pipe then
    vim.notify("Godot editor server already running on " .. pipe, vim.log.levels.INFO)
    return
  end
  local ok, err = pcall(vim.fn.serverstart, pipe)
  if not ok then
    vim.notify("Failed to start Godot editor server on " .. pipe .. ": " .. tostring(err), vim.log.levels.ERROR)
    return
  end
  vim.notify("Godot editor server started on " .. pipe, vim.log.levels.INFO)
end

M.start_editor_server = start_editor_server

-- User command
vim.api.nvim_create_user_command("GodotStartEditorServer", function(opts)
  start_editor_server(opts.args ~= "" and opts.args or nil)
end, {
  nargs = "?",
  complete = "file",
})

-- Autostart when opening a Godot script (.gd or .cs if enabled)
vim.api.nvim_create_autocmd("BufReadPost", {
  pattern = { "*.gd", "*.cs" },
  callback = function()
    local config = require("godotdev")
    if config.opts and config.opts.autostart_editor_server then
      start_editor_server()
    end
  end,
})

return M
