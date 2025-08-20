local health = vim.health
local M = {}

-- default port
M.opts = { editor_port = 6005 }

function M.setup(opts)
  M.opts = vim.tbl_extend("force", M.opts, opts or {})
end

local function port_open(host, port)
  local cmd
  if vim.fn.executable("ncat") == 1 then
    cmd = string.format("ncat -z -w 1 %s %d 2>/dev/null", host, port)
  else
    return false
  end
  vim.fn.system(cmd)
  return vim.v.shell_error == 0
end

local is_windows = vim.loop.os_uname().sysname == "Windows_NT"

function M.check()
  health.start("Godotdev.nvim")

  if is_windows then
    if vim.fn.executable("ncat") == 1 then
      health.ok("'ncat' is installed")
    else
      health.error([[Windows: 'ncat' not found. Install via Scoop or Chocolatey:
  scoop install nmap
  choco install nmap]])
    end
  end

  local port = M.opts.editor_port
  if port_open("127.0.0.1", port) or not is_windows then
    health.ok("Godot editor LSP detected on port " .. port)
  else
    local msg = string.format(
      [[
Godot editor LSP not detected on port %d.
Make sure the Godot editor is running with the LSP server enabled on this port.

- Open your project in Godot.
- Enable the LSP server (Editor Settings → Network → Enable TCP LSP server).
- Confirm the port matches %d (change `editor_port` in your config if needed).
]],
      port,
      port
    )
    health.warn(msg)
  end
end

return M
