local M = {}

M.reconnect_lsp = function()
  local clients = vim.lsp.get_clients()
  for _, client in ipairs(clients) do
    if client.name == "godot" then
      vim.lsp.stop_client(client.id, true)
    end
  end
  vim.cmd("edit") -- triggers LSP reattach for current buffer
  vim.notify("Godot LSP reconnected", vim.log.levels.INFO)
end

vim.api.nvim_create_user_command("GodotReconnectLSP", function()
  M.reconnect_lsp()
end, {})

return M
