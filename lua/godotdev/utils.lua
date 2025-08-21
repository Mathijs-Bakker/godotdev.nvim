local M = {}

--- Suppress specific LSP messages
-- @param client vim.lsp.Client
-- @param patterns table List of string patterns to ignore in client messages
function M.suppress_unsupported_lsp_messages(client, patterns)
  local orig_handler = vim.lsp.handlers["window/showMessage"]
  vim.lsp.handlers["window/showMessage"] = function(err, method, params, client_id)
    local lsp_client = vim.lsp.get_client_by_id(client_id)
    if lsp_client and lsp_client.name == client.name then
      if params and params.message then
        for _, pat in ipairs(patterns) do
          if params.message:match(pat) then
            return -- silently ignore this message
          end
        end
      end
    end
    -- fallback to original handler for all other messages
    orig_handler(err, method, params, client_id)
  end
end

return M
