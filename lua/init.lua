local M = {}

M.config = {
	lint_mode = false,
}

M.setup = function(user_config)
	if user_config then
		M.config = vim.tbl_deep_extend("force", M.config, user_config)
	end

	-- load submodules
	require("godotdev.lsp").setup(M.config)

	package.loaded["godotdev.keymaps"] = nil
	require("godotdev.keymaps").setup()
end

return M
