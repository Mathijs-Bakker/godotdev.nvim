local health = vim.health
local godotdev = require("godotdev")
local uv = vim.uv or vim.loop

local M = {}

M.opts = {
  editor_port = 6005,
  debug_port = 6006,
  editor_server_address = nil,
  autostart_editor_server = false,
}

function M.setup(opts)
  M.opts = vim.tbl_extend("force", M.opts, opts or {})
end

local is_windows = uv.os_uname().sysname == "Windows_NT"

local function run_command(argv, opts)
  local ok, job = pcall(vim.system, argv, vim.tbl_extend("keep", opts or {}, { text = true }))
  if not ok then
    return nil, job
  end

  local result = job:wait()
  return result, nil
end

local function port_open(host, port)
  if is_windows then
    if vim.fn.executable("ncat") ~= 1 then
      return false
    end

    local result = run_command({ "ncat", "-z", "-w", "1", host, tostring(port) })
    return result ~= nil and result.code == 0
  end

  if vim.fn.executable("nc") ~= 1 then
    return true -- assume port ok if nc is missing
  end

  local result = run_command({ "nc", "-z", "-w", "1", host, tostring(port) })
  return result ~= nil and result.code == 0
end

local function plugin_installed(name)
  if name == "nvim-treesitter" then
    return pcall(require, "nvim-treesitter.configs")
      or pcall(require, "nvim-treesitter.config")
      or pcall(require, "nvim-treesitter")
  elseif name == "nvim-dap" then
    return vim.fn.exists(":DapContinue") == 2
  elseif name == "nvim-dap-ui" then
    return pcall(require, "dapui")
  end
  return false
end

local function has_exe(name)
  return vim.fn.executable(name) == 1
end

local function formatter_disabled(opts)
  return opts.formatter_cmd == nil and opts.formatter == false
end

local function formatter_command_argv(opts)
  if formatter_disabled(opts) then
    return nil
  end

  local cmd = opts.formatter_cmd or opts.formatter or "gdformat"

  if type(cmd) == "table" then
    return vim.deepcopy(cmd)
  end

  if type(cmd) ~= "string" or cmd == "" then
    return { "gdformat" }
  end

  return vim.split(cmd, "%s+", { trimempty = true })
end

local function editor_server_target()
  if type(M.opts.editor_server_address) == "string" and M.opts.editor_server_address ~= "" then
    return M.opts.editor_server_address
  end

  local start_editor_server = require("godotdev.start_editor_server")
  return vim.v.servername ~= "" and vim.v.servername or start_editor_server.default_pipe
end

local function report_godot_version()
  health.start("Godot version")

  local godot_result = run_command({ "godot", "--version" })
  if godot_result and godot_result.code == 0 and godot_result.stdout and godot_result.stdout ~= "" then
    local ver = vim.trim(godot_result.stdout)
    health.ok("Godot detected: " .. ver)
    local major, minor = ver:match("(%d+)%.(%d+)")
    if major and minor and (tonumber(major) < 4 or (tonumber(major) == 4 and tonumber(minor) < 3)) then
      health.warn("Godot version is below 4.3. Some features may not work correctly.")
    end
    return
  end

  health.info("Godot executable not found. Make sure 'godot' is in your PATH.")
end

local function report_dependencies()
  health.start("Dependencies")

  health.ok("Built-in Neovim LSP APIs available")

  for _, plugin in ipairs({ "nvim-treesitter", "nvim-dap", "nvim-dap-ui" }) do
    if plugin_installed(plugin) then
      health.ok("Dependency '" .. plugin .. "' is installed")
    else
      health.warn("Dependency '" .. plugin .. "' not found. Some features may not work.")
    end
  end
end

local function report_godot_detection()
  health.start("Godot detection")

  local editor_port = M.opts.editor_port
  if port_open("127.0.0.1", editor_port) then
    health.ok("Godot editor LSP detected on port " .. editor_port)
  else
    health.warn(string.format(
      [[Godot editor LSP not detected on port %d.
Make sure the Godot editor is running with LSP server enabled.
- Enable TCP LSP server in Editor Settings → Network
- Confirm port matches %d]],
      editor_port,
      editor_port
    ))
  end

  local debug_port = M.opts.debug_port
  if plugin_installed("nvim-dap") then
    if port_open("127.0.0.1", debug_port) then
      health.ok("Godot editor debug server detected on port " .. debug_port)
    else
      health.warn("Godot editor debug server not detected on port " .. debug_port)
    end
  end
end

local function report_editor_server()
  health.start("Editor server")
  health.info("Autostart editor server: " .. (M.opts.autostart_editor_server and "enabled" or "disabled"))
  health.info("Editor server target: " .. editor_server_target())

  if vim.v.servername ~= "" then
    health.ok("Neovim server listening on " .. vim.v.servername)
  else
    health.info("No active Neovim server address in this session.")
  end
end

local function report_windows_dependencies()
  if not is_windows then
    return
  end

  if has_exe("ncat") then
    health.ok("'ncat' is installed")
  else
    health.error([[
Windows: 'ncat' not found. Install via Scoop or Chocolatey:
  scoop install nmap
  choco install nmap]])
  end
end

local function report_csharp()
  if not godotdev.opts.csharp then
    health.info("C# checks skipped (csharp=false)")
    return
  end

  health.start("C# support")

  if has_exe("dotnet") then
    health.ok("'dotnet' found")
  else
    health.error("'dotnet' not found. Install the .NET SDK: https://dotnet.microsoft.com/download")
  end

  if has_exe("csharp-ls") or has_exe("omnisharp") then
    health.ok("C# LSP server found (csharp-ls or omnisharp)")
  else
    health.error("No C# LSP server found. Install 'csharp-ls' (recommended) or 'omnisharp'.")
  end

  if has_exe("netcoredbg") then
    health.ok("'netcoredbg' found")
  else
    health.error("'netcoredbg' not found. Install from: https://github.com/Samsung/netcoredbg")
  end
end

local function report_docs()
  health.start("Godot docs")

  local docs_opts = godotdev.opts.docs or {}
  local docs_renderer = docs_opts.renderer or "float"
  local docs_source = docs_opts.source_base_url
    or ("https://raw.githubusercontent.com/godotengine/godot-docs/" .. (docs_opts.source_ref or "master"))

  health.info("Docs renderer: " .. docs_renderer)
  health.info("Docs source: " .. docs_source)

  if docs_renderer == "float" or docs_renderer == "buffer" then
    if has_exe("curl") then
      health.ok("'curl' found for rendered Godot docs")
    else
      health.warn("'curl' not found. Float and buffer Godot docs rendering require 'curl'.")
    end
  else
    health.info("Rendered docs dependency checks skipped (docs.renderer is browser-only).")
  end
end

local function report_formatter()
  health.start("GDScript Formatter")

  if formatter_disabled(godotdev.opts) then
    health.info("Formatter disabled (`formatter = false`)")
    return
  end

  local formatter = godotdev.opts.formatter or "gdformat"
  local formatter_argv = formatter_command_argv(godotdev.opts)
  local exe = formatter_argv[1] or formatter

  if type(godotdev.opts.formatter_cmd) == "table" then
    health.info("Formatter command: " .. table.concat(formatter_argv, " "))
  end

  if has_exe(exe) then
    health.ok("'" .. exe .. "' found")
    return
  end

  if formatter == "gdformat" then
    health.warn([[
'gdformat' not found.
Install with Python pip or Homebrew:

Linux / macOS:
  pip install gdtoolkit

macOS (Homebrew):
  brew install gdtoolkit

Windows:
  pip install gdtoolkit]])
  elseif formatter == "gdscript-format" then
    health.warn([[
'gdscript-format' not found.
Install from the repo: https://github.com/Scony/godot-gdscript-formatter-tree-sitter
Follow instructions in README.md]])
  end
end

function M.check()
  health.start("Godotdev.nvim")
  report_godot_version()
  report_dependencies()
  report_godot_detection()
  report_editor_server()
  report_windows_dependencies()
  report_csharp()
  report_docs()
  report_formatter()
end

return M
