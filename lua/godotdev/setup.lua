local M = {}

M.opts = {
  editor_host = "127.0.0.1",
  editor_port = 6005,
  debug_port = 6006,
  autostart_editor_server = false, -- opt-in: avoid starting a server unless the user wants it
  editor_server = {
    address = nil, -- nil uses the current server or the platform default
    remove_stale_socket = true,
  },
  treesitter = {
    auto_setup = true, -- convenience default; disable if you manage nvim-treesitter yourself
    ensure_installed = { "gdscript" },
  },
  formatter = "gdscript-formatter", -- "gdscript-formatter" | "gdformat" | false
  formatter_cmd = nil, -- string or argv list, e.g. { "gdscript-formatter", "--check" }
  docs = {
    renderer = "float", -- "float" | "browser" | "buffer"
    fallback_renderer = "browser", -- nil | "browser" | "buffer"; browser is the only fetch-recovery fallback
    missing_symbol_feedback = "message", -- "message" | "notify"
    version = "stable",
    language = "en",
    source_ref = "master",
    source_base_url = nil, -- optional override for raw godot-docs source
    timeout_ms = 10000,
    cache = {
      enabled = true,
      max_entries = 64,
    },
    float = {
      width = 0.8,
      height = 0.8,
      border = "rounded",
    },
    buffer = {
      position = "right", -- "right" | "bottom" | "current"
      size = 0.4,
    },
  },
}

local function warn_missing_dependency(message)
  vim.notify("godotdev.nvim: " .. message, vim.log.levels.WARN)
end

local function setup_dap()
  local ok, dap_module = pcall(require, "godotdev.dap")
  if not ok then
    warn_missing_dependency("nvim-dap is not available; debugging integration is disabled")
    return false
  end

  local ok_setup, err = pcall(dap_module.setup, {
    type = "server",
    host = M.opts.editor_host,
    port = M.opts.debug_port,
  })
  if not ok_setup then
    if tostring(err):match("module 'dap' not found") then
      warn_missing_dependency("nvim-dap is not available; debugging integration is disabled")
    else
      vim.notify("godotdev.nvim: failed to configure DAP integration: " .. tostring(err), vim.log.levels.WARN)
    end
    return false
  end

  return true
end

local function setup_csharp_dap()
  if not M.opts.csharp then
    return
  end

  local ok, dap = pcall(require, "dap")
  if not ok then
    warn_missing_dependency("C# debugging requires nvim-dap to be installed")
    return
  end

  dap.adapters.coreclr = {
    type = "executable",
    command = M.opts.netcoredbg_path or "netcoredbg",
    args = { "--interpreter=vscode" },
  }
  dap.configurations.cs = {
    {
      type = "coreclr",
      name = "launch - netcoredbg",
      request = "launch",
      program = function()
        return vim.fn.input("Path to dll: ", vim.fn.getcwd() .. "/bin/Debug/net6.0/", "file")
      end,
    },
  }
end

function M.setup(opts)
  M.opts = vim.tbl_deep_extend("force", M.opts, opts or {})

  require("godotdev.lsp").setup({
    editor_host = M.opts.editor_host,
    editor_port = M.opts.editor_port,
  })

  local editor_server = require("godotdev.start_editor_server")
  editor_server.setup()
  -- autostart editor server if enabled
  if M.opts.autostart_editor_server then
    editor_server.start_editor_server(M.opts.editor_server and M.opts.editor_server.address or nil)
  end

  require("godotdev.reconnect_lsp").setup()
  require("godotdev.run").setup()
  require("godotdev.formatting").setup()
  require("godotdev.docs").setup()
  setup_dap()

  require("godotdev.tree-sitter").setup()

  require("godotdev.health").setup({
    editor_port = M.opts.editor_port,
    debug_port = M.opts.debug_port,
    editor_server_address = M.opts.editor_server and M.opts.editor_server.address or nil,
    autostart_editor_server = M.opts.autostart_editor_server,
  })

  setup_csharp_dap()
end

return M
