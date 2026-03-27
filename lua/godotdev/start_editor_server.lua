local M = {}

local uv = vim.uv or vim.loop
local is_windows = uv.os_uname().sysname == "Windows_NT"
local default_pipe = is_windows and [[\\.\pipe\godot.nvim]] or "/tmp/godot.nvim"

local function get_config()
  local ok, godotdev = pcall(require, "godotdev")
  if not ok then
    return {}
  end

  return godotdev.opts.editor_server or {}
end

local function configured_address()
  local address = get_config().address
  if type(address) == "string" and address ~= "" then
    return address
  end

  return nil
end

local function remove_stale_socket_enabled()
  return get_config().remove_stale_socket ~= false
end

local function is_pipe_address(address)
  return type(address) == "string" and address ~= "" and not address:find(":", 1, true)
end

local function file_exists(path)
  return path and uv.fs_stat(path) ~= nil
end

local function can_connect(address)
  local ok, channel = pcall(vim.fn.sockconnect, "pipe", address, { rpc = true })
  if not ok or type(channel) ~= "number" or channel <= 0 then
    return false
  end

  vim.fn.chanclose(channel)
  return true
end

local function cleanup_stale_socket(address)
  if is_windows or not is_pipe_address(address) or not remove_stale_socket_enabled() then
    return false, nil
  end

  if not file_exists(address) then
    return false, nil
  end

  if can_connect(address) then
    return false, nil
  end

  local ok, err = pcall(uv.fs_unlink, address)
  if not ok then
    return false, err
  end

  return true, nil
end

local function resolve_address(address)
  if type(address) == "string" and address ~= "" then
    return address
  end

  if vim.v.servername ~= "" then
    return vim.v.servername
  end

  return configured_address() or default_pipe
end

local function start_editor_server(address)
  local target = resolve_address(address)

  if vim.v.servername ~= "" then
    if vim.v.servername == target then
      vim.notify("Godot editor server already running on " .. target, vim.log.levels.INFO)
      return true
    end

    vim.notify(
      "Neovim server already running on " .. vim.v.servername .. "; skipping start on " .. target,
      vim.log.levels.WARN
    )
    return false
  end

  local removed_stale_socket, stale_err = cleanup_stale_socket(target)
  if stale_err then
    vim.notify(
      "Failed to remove stale Godot editor socket at " .. target .. ": " .. tostring(stale_err),
      vim.log.levels.ERROR
    )
    return false
  end

  if removed_stale_socket then
    vim.notify("Removed stale Godot editor socket at " .. target, vim.log.levels.WARN)
  end

  local ok, result = pcall(vim.fn.serverstart, target)
  if not ok then
    vim.notify("Failed to start Godot editor server on " .. target .. ": " .. tostring(result), vim.log.levels.ERROR)
    return false
  end

  vim.notify("Godot editor server started on " .. result, vim.log.levels.INFO)
  return true
end

M.start_editor_server = start_editor_server
M.default_pipe = default_pipe

vim.api.nvim_create_user_command("GodotStartEditorServer", function(opts)
  start_editor_server(opts.args ~= "" and opts.args or nil)
end, {
  nargs = "?",
  complete = "file",
})

vim.api.nvim_create_autocmd("BufReadPost", {
  pattern = { "*.gd", "*.cs" },
  callback = function()
    local config = require("godotdev")
    if config.opts and config.opts.autostart_editor_server then
      start_editor_server(config.opts.editor_server and config.opts.editor_server.address or nil)
    end
  end,
})

return M
