if vim.fn.has("nvim-0.9") == 1 then
  vim.api.nvim_create_user_command("CheckGodotdev", function()
    require("godotdev.health").check()
  end, {})
end
