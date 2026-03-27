local M = {}

local function matches_any_pattern(message, patterns)
  if type(message) ~= "string" or type(patterns) ~= "table" then
    return false
  end

  for _, pattern in ipairs(patterns) do
    if message:match(pattern) then
      return true
    end
  end

  return false
end

function M.wrap_client_handler(client, method, predicate)
  local base_handler = client.handlers[method] or vim.lsp.handlers[method]
  if type(base_handler) ~= "function" then
    return
  end

  client.handlers[method] = function(err, result, ctx, config)
    if predicate(err, result, ctx, config) then
      return
    end

    return base_handler(err, result, ctx, config)
  end
end

--- Suppress specific LSP messages for a single client.
-- @param client vim.lsp.Client
-- @param patterns table List of string patterns to ignore in client messages
function M.suppress_client_messages(client, patterns)
  M.wrap_client_handler(client, "window/showMessage", function(_, params)
    return params and matches_any_pattern(params.message, patterns)
  end)
end

return M
