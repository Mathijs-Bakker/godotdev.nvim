local M = {}

M.reconnect_all = function()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local ft = vim.bo[bufnr].filetype
      if ft == "gdscript" or ft == "gdresource" or ft == "gdshader" then
        vim.api.nvim_buf_call(bufnr, function()
          vim.cmd("edit") -- retriggers LSP attach
        end)
      end
    end
  end

  vim.notify("Godot LSP reconnected for all Godot buffers", vim.log.levels.INFO)
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "gdscript", "gdresource", "gdshader" },
  callback = function()
    -- Define command once per session
    if not vim.g._godot_reconnect_all_defined then
      vim.api.nvim_create_user_command("GodotReconnectLSP", function()
        M.reconnect_all()
      end, { desc = "Reconnect Godot LSP for all buffers" })
      vim.g._godot_reconnect_all_defined = true
    end
  end,
})
