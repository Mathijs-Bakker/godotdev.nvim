local M = {}

M.setup = function(config)
  config = config or {}
  local utils = require("godotdev.utils")

  local host = config.editor_host or "127.0.0.1"
  local port = config.editor_port or 6005

  local capabilities = vim.lsp.protocol.make_client_capabilities()
  capabilities.textDocument.typeDefinition = nil -- suppress unsupported typeDefinition

  local is_windows = vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1

  local cmd
  if is_windows then
    cmd = { "ncat", host, tostring(port) }
  else
    cmd = vim.lsp.rpc.connect(host, port)
  end

  vim.lsp.config["gdscript"] = {
    name = "godot_editor",
    cmd = cmd,
    filetypes = { "gd", "gdscript", "gdshader", "gdscript3" },
    root_markers = { "project.godot", ".git" },
    capabilities = capabilities,
    on_attach = function(client, bufnr)
      utils.suppress_unsupported_lsp_messages(client, { "Method not found: godot/reloadScript" })
    end,
  }

  vim.lsp.enable("gdscript")
end

return M
