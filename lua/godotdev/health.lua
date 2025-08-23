local health = vim.health
local godotdev = require("godotdev")

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

local function has_exe(name)
  return vim.fn.executable(name) == 1
end

local function check_indent()
  health.start("Indentation")

  local handle = io.popen("grep -P '\t' -R --include='*.gd' --include='*.cs' . 2>/dev/null | head -n 1")
  if handle then
    local result = handle:read("*a")
    handle:close()
    if result ~= "" then
      health.warn(
        "Mixed indentation detected (tabs found in .gd or .cs files). Godot expects spaces, 4 per indent. See :help godotdev-indent"
      )
    else
      health.ok("Indentation style looks consistent (no tabs in .gd or .cs files).")
    end
  end
end

function M.check()
  health.start("Godotdev.nvim")

  -- Godot version
  health.start("Godot version")
  local ok, godot_version = pcall(vim.fn.system, "godot --version")
  if ok and godot_version and godot_version ~= "" then
    local ver = vim.trim(godot_version)
    health.ok("Godot detected: " .. ver)
    local major, minor = ver:match("(%d+)%.(%d+)")
    if major and minor and (tonumber(major) < 4 or (tonumber(major) == 4 and tonumber(minor) < 3)) then
      health.warn("Godot version is below 4.3. Some features may not work correctly.")
    end
  else
    health.info("Godot executable not found. Make sure 'godot' is in your PATH.")
  end

  -- Dependencies
  health.start("Dependencies")
  for _, plugin in ipairs({ "nvim-lspconfig", "nvim-treesitter", "nvim-dap" }) do
    if plugin_installed(plugin) then
      health.ok("✅ OK Dependency '" .. plugin .. "' is installed")
    else
      health.warn("⚠️ WARNING Dependency '" .. plugin .. "' not found. Some features may not work.")
    end
  end

  -- Godot detection
  health.start("Godot detection")
  local editor_port = M.opts.editor_port
  if port_open("127.0.0.1", editor_port) then
    health.ok("✅ OK Godot editor LSP detected on port " .. editor_port)
  else
    health.warn(string.format(
      [[⚠️ WARNING Godot editor LSP not detected on port %d.
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
      health.ok("✅ OK Godot editor debug server detected on port " .. debug_port)
    else
      health.warn("⚠️ WARNING Godot editor debug server not detected on port " .. debug_port)
    end
  end

  if is_windows then
    if has_exe("ncat") then
      health.ok("✅ OK 'ncat' is installed")
    else
      health.error([[
❌ ERROR Windows: 'ncat' not found. Install via Scoop or Chocolatey:
  scoop install nmap
  choco install nmap]])
    end
  end

  -- Optional C# support
  if godotdev.opts.csharp then
    health.start("C# support")
    if has_exe("dotnet") then
      health.ok("✅ OK 'dotnet' found")
    else
      health.error("❌ ERROR 'dotnet' not found. Install the .NET SDK: https://dotnet.microsoft.com/download")
    end

    if has_exe("csharp-ls") or has_exe("omnisharp") then
      health.ok("✅ OK C# LSP server found (csharp-ls or omnisharp)")
    else
      health.error("❌ ERROR No C# LSP server found. Install 'csharp-ls' (recommended) or 'omnisharp'.")
    end

    if has_exe("netcoredbg") then
      health.ok("✅ OK 'netcoredbg' found")
    else
      health.error("❌ ERROR 'netcoredbg' not found. Install from: https://github.com/Samsung/netcoredbg")
    end
  else
    health.info("ℹ️ C# checks skipped (csharp=false)")
  end

  check_indent()
end
return M
