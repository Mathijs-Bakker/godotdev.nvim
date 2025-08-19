local M = {}

M.setup = function(config)
	local lspconfig = require("lspconfig")
	local utils = require("godotdev.utils")
	local capabilities = vim.lsp.protocol.make_client_capabilities()
	capabilities.textDocument.typeDefinition = nil

	-- GDscript standalone LSP
	lspconfig.gdscript.setup({
		cmd = { "godot-lsp", "--stdio" },
		filetypes = { "gd", "gdscript" },
		root_dir = lspconfig.util.root_pattern("project.godot"),
		capabilities = capabilities,
	})

	-- Godot editor LSP
	lspconfig.godot_lsp = {
		default_config = {
			cmd = { "nc", "127.0.0.1", "6005" },
			root_dir = lspconfig.util.root_pattern("project.godot"),
			filetypes = { "gd", "gdscript" },
			name = "godot",
		},
	}

	lspconfig.godot_lsp.setup({
		capabilities = config.capabilities or vim.lsp.protocol.make_client_capabilities(),
		on_attach = function(client, _)
			-- Suppress known unsupported Godot messages
			utils.suppress_lsp_messages(client, { "Method not found: godot/reloadScript" })
		end,
	})
end

return M
