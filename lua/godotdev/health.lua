local health = vim.health
local M = {}

M.opts = {
  editor_port = 6005,
  debug_port = 6006,
}

function M.setup(opts)
  M.opts = vim.tbl_extend("force", M.opts, opts or {})
end

local is_windows = vim.loop.os_uname().sysname == "Windows_NT"

local function port_open(host, port)
  local cmd
  if is_windows then
    if vim.fn.executable("ncat") ~= 1 then
      return false
    end
    cmd = string.format("ncat -z -w 1 %s %d 2>NUL", host, port)
  else
    if vim.fn.executable("nc") ~= 1 then
      return true -- assume port ok if nc is missing
    end
    cmd = string.format("nc -z -w 1 %s %d >/dev/null 2>&1", host, port)
  end
  vim.fn.system(cmd)
  return vim.v.shell_error == 0
end

-- Check if a plugin is installed, works with Lazy.nvim
local function plugin_installed(name)
  if name == "nvim-lspconfig" then
    return vim.fn.exists(":LspInfo") == 2
  elseif name == "nvim-dap" then
    return vim.fn.exists(":DapContinue") == 2
  elseif name == "nvim-treesitter" then
    return pcall(require, "nvim-treesitter.configs")
  end
  return false
end

function M.check()
  health.start("Godotdev.nvim")

  -- plugin dependencies
  for _, plugin in ipairs({ "nvim-lspconfig", "nvim-treesitter", "nvim-dap" }) do
    if plugin_installed(plugin) then
      health.ok("Dependency '" .. plugin .. "' is installed")
    else
      health.warn("Dependency '" .. plugin .. "' not found. Some features may not work.")
    end
  end

  -- Godot editor LSP
  local editor_port = M.opts.editor_port
  if port_open("127.0.0.1", editor_port) then
    health.ok("Godot editor LSP detected on port " .. editor_port)
  else
    health.warn(string.format(
      [[
Godot editor LSP not detected on port %d.
Make sure the Godot editor is running with LSP server enabled.

- Open your project in Godot.
- Enable the LSP server (Editor Settings → Network → Enable TCP LSP server).
- Confirm the port matches %d (change `editor_port` in your config if needed).
]],
      editor_port,
      editor_port
    ))
  end

  -- Godot editor debug server
  local debug_port = M.opts.debug_port
  if plugin_installed("nvim-dap") then
    if port_open("127.0.0.1", debug_port) then
      health.ok("Godot editor debug server detected on port " .. debug_port)
    else
      health.warn("Godot editor debug server not detected on port " .. debug_port)
    end
  end

  -- Windows: ncat check
  if is_windows then
    if vim.fn.executable("ncat") == 1 then
      health.ok("'ncat' is installed")
    else
      health.error([[
Windows: 'ncat' not found. Install via Scoop or Chocolatey:
  scoop install nmap
  choco install nmap
]])
    end
  end
end

return M
