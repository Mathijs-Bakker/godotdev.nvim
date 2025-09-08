local M = {}

M.opts = {
  editor_host = "127.0.0.1",
  editor_port = 6005,
  debug_port = 6006,
}

function M.setup(opts)
  M.opts = vim.tbl_extend("force", M.opts, opts or {})

  require("godotdev.lsp").setup({
    editor_host = M.opts.editor_host,
    editor_port = M.opts.editor_port,
  })

  require("godotdev.start_editor_server")
  require("godotdev.reconnect_lsp")
  require("godotdev.formatting")

  require("godotdev.dap").setup({
    type = "server",
    host = M.opts.editor_host,
    port = M.opts.debug_port,
  })

  require("godotdev.tree-sitter")

  require("godotdev.health").setup({
    port = M.opts.editor_port,
  })

  if opts.csharp then
    local dap = require("dap")
    dap.adapters.coreclr = {
      type = "executable",
      command = opts.netcoredbg_path or "netcoredbg",
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
