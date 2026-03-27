local M = {}

M.opts = {
  editor_host = "127.0.0.1",
  editor_port = 6005,
  debug_port = 6006,
  autostart_editor_server = false,
  editor_server = {
    address = nil, -- nil uses the current server or the platform default
    remove_stale_socket = true,
  },
  formatter = "gdformat", -- "gdformat" | "gdscript-format"
  formatter_cmd = nil, -- allow override, e.g. "gdscript-format --check"
  docs = {
    renderer = "float", -- "float" | "browser" | "buffer"
    fallback_renderer = "browser", -- nil | "browser" | "buffer"
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
  require("godotdev.formatting").setup()
  require("godotdev.docs").setup()

  require("godotdev.dap").setup({
    type = "server",
    host = M.opts.editor_host,
    port = M.opts.debug_port,
  })

  require("godotdev.tree-sitter")

  require("godotdev.health").setup({
    editor_port = M.opts.editor_port,
    debug_port = M.opts.debug_port,
    editor_server_address = M.opts.editor_server and M.opts.editor_server.address or nil,
    autostart_editor_server = M.opts.autostart_editor_server,
  })

  if M.opts.csharp then
    local dap = require("dap")
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
end

return M
