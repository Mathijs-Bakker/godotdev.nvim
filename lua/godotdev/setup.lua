local M = {}

M.opts = {
  editor_host = "127.0.0.1",
  editor_port = 6005,
}

function M.setup(opts)
  M.opts = vim.tbl_extend("force", M.opts, opts or {})
  require("godotdev.lsp").setup({ editor_host = M.opts.editor_host, editor_port = M.opts.editor_port })
  require("godotdev.health").setup({ port = M.opts.editor_port })
end

return M
