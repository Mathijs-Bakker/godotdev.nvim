local M = {}

vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("MyLspKeymaps", { clear = true }),
	callback = function(ev)
		local client = vim.lsp.get_client_by_id(ev.data.client_id)
		local opts = { buffer = ev.buf }

		-- Lazy-load Telescope when needed
		local has_telescope, telescope_builtin = pcall(require, "telescope.builtin")

		local function map(mode, lhs, rhs, desc)
			vim.keymap.set(mode, lhs, rhs, vim.tbl_extend("force", opts, { desc = desc }))
		end

		-- Definitions / Declarations
		if client.server_capabilities.definitionProvider then
			map(
				"n",
				"gd",
				has_telescope and telescope_builtin.lsp_definitions or vim.lsp.buf.definition,
				"LSP: Go to definition"
			)
		end
		if client.server_capabilities.declarationProvider then
			map("n", "gD", vim.lsp.buf.declaration, "LSP: Go to declaration")
		end
		if client.server_capabilities.typeDefinitionProvider then
			map(
				"n",
				"gy",
				has_telescope and telescope_builtin.lsp_type_definitions or vim.lsp.buf.type_definition,
				"LSP: Type definition"
			)
		end
		if client.server_capabilities.implementationProvider then
			map(
				"n",
				"gi",
				has_telescope and telescope_builtin.lsp_implementations or vim.lsp.buf.implementation,
				"LSP: Go to implementation"
			)
		end
		if client.server_capabilities.referencesProvider then
			map(
				"n",
				"gr",
				has_telescope and telescope_builtin.lsp_references or vim.lsp.buf.references,
				"LSP: List references"
			)
		end

		-- Info
		if client.server_capabilities.hoverProvider then
			map("n", "K", vim.lsp.buf.hover, "LSP: Hover documentation")
		end
		if client.server_capabilities.signatureHelpProvider then
			map("n", "<C-k>", vim.lsp.buf.signature_help, "LSP: Signature help")
		end

		-- Symbols
		if client.server_capabilities.documentSymbolProvider then
			map(
				"n",
				"<leader>ds",
				has_telescope and telescope_builtin.lsp_document_symbols or vim.lsp.buf.document_symbol,
				"LSP: Document symbols"
			)
		end
		if client.server_capabilities.workspaceSymbolProvider then
			map(
				"n",
				"<leader>ws",
				has_telescope and telescope_builtin.lsp_dynamic_workspace_symbols or vim.lsp.buf.workspace_symbol,
				"LSP: Workspace symbols"
			)
		end

		-- Actions
		if client.server_capabilities.renameProvider then
			map("n", "<leader>rn", vim.lsp.buf.rename, "LSP: Rename symbol")
		end
		if client.server_capabilities.codeActionProvider then
			map({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, "LSP: Code action")
		end
		if client.server_capabilities.documentFormattingProvider then
			map("n", "<leader>f", function()
				vim.lsp.buf.format({ async = true })
			end, "LSP: Format buffer")
		end

		-- Diagnostics (always available)
		map("n", "gl", vim.diagnostic.open_float, "LSP: Show diagnostics")
		map("n", "[d", vim.diagnostic.goto_prev, "LSP: Previous diagnostic")
		map("n", "]d", vim.diagnostic.goto_next, "LSP: Next diagnostic")
	end,
})

M.setup = function()
	-- global setup if needed
end

return M
