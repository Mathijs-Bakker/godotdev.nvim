local M = {}

function M.reconnect_all()
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

function M.setup()
  if vim.fn.exists(":GodotReconnectLSP") ~= 2 then
    vim.api.nvim_create_user_command("GodotReconnectLSP", function()
      M.reconnect_all()
    end, { desc = "Reconnect Godot LSP for all buffers" })
  end
end

return M
