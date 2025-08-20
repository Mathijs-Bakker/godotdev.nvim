local M = {}

M.setup = function(config)
  config = config or {}
  local lspconfig = require("lspconfig")
  local utils = require("godotdev.utils")
  local keymaps = require("godotdev.keymaps")

  local host = config.editor_host or "127.0.0.1"
  local port = config.editor_port or 6005

  local capabilities = vim.lsp.protocol.make_client_capabilities()
  capabilities.textDocument.typeDefinition = nil -- suppress unsupported typeDefinition

  lspconfig.gdscript.setup({
    name = "godot_editor",
    cmd = vim.lsp.rpc.connect(host, port),
    filetypes = { "gd", "gdscript" },
    root_dir = lspconfig.util.root_pattern("project.godot"),
    capabilities = capabilities,
    on_attach = function(client, bufnr)
      -- suppress known Godot unsupported messages
      utils.suppress_lsp_messages(client, { "Method not found: godot/reloadScript" })
      keymaps.attach(bufnr)
    end,
  })
end

return M
