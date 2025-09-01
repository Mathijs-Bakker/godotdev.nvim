local M = {}

M.reconnect_lsp = function()
  local clients = vim.lsp.get_clients()
  for _, client in ipairs(clients) do
    if client.name == "godot" then
      vim.lsp.stop_client(client.id, true)
    end
  end
  vim.cmd("edit") -- triggers LSP reattach
  vim.notify("Godot LSP reconnected", vim.log.levels.INFO)
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "gdscript", "gdresource", "gdshader" }, -- adjust patterns if needed
  callback = function()
    vim.api.nvim_buf_create_user_command(0, "GodotReconnect", function()
      M.reconnect_lsp()
    end, { desc = "Reconnect to the Godot LSP server" })
  end,
})

return M
