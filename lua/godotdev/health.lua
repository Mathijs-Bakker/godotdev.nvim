local M = {}
local uv = vim.loop

M.setup = function(config)
  local lspconfig = require("lspconfig")
  local utils = require("godotdev.utils")
  local keymaps = require("godotdev.keymaps")

  local capabilities = vim.lsp.protocol.make_client_capabilities()
  capabilities.textDocument.typeDefinition = nil

  lspconfig.godot_lsp = {
    default_config = {
      name = "godot_editor",
      root_dir = lspconfig.util.root_pattern("project.godot"),
      filetypes = { "gd", "gdscript" },
      cmd = nil,
      on_attach = function(client, bufnr)
        utils.suppress_lsp_messages(client, { "Method not found: godot/reloadScript" })
        keymaps.attach(bufnr)
      end,
      new_client = function(cfg)
        local host = "127.0.0.1"
        local port = config.editor_port or 6005

        local sock = uv.new_tcp()
        sock:connect(host, port, function(err)
          if err then
            vim.schedule(function()
              vim.notify("Failed to connect to Godot editor LSP: " .. err, vim.log.levels.ERROR)
            end)
            return
          end

          vim.lsp.start_client({
            name = "godot_editor",
            cmd = nil,
            root_dir = cfg.root_dir,
            capabilities = cfg.capabilities,
            handlers = cfg.handlers,
            offset_encoding = "utf-8",
            stdin = sock,
            stdout = sock,
          })
        end)
      end,
    },
  }

  -- DO NOT call lspconfig.godot_lsp.setup()
end

return M
