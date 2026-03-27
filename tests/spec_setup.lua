local h = require("tests.helpers")

local function delete_command(name)
  if vim.fn.exists(":" .. name) == 2 then
    vim.api.nvim_del_user_command(name)
  end
end

local function clear_augroup(name)
  pcall(vim.api.nvim_del_augroup_by_name, name)
end

return {
  {
    name = "start editor server setup registers command and single autocmd group",
    run = function()
      delete_command("GodotStartEditorServer")
      clear_augroup("godotdev_start_editor_server")

      h.clear_module("godotdev.start_editor_server")
      local mod = require("godotdev.start_editor_server")
      mod.setup()
      mod.setup()

      h.assert_equal(vim.fn.exists(":GodotStartEditorServer"), 2)

      local autocmds = vim.api.nvim_get_autocmds({ group = "godotdev_start_editor_server" })
      h.assert_equal(#autocmds, 2)
      h.assert_equal(autocmds[1].event, "BufReadPost")
      h.assert_equal(autocmds[2].event, "BufReadPost")
      h.assert_equal(autocmds[1].pattern, "*.gd")
      h.assert_equal(autocmds[2].pattern, "*.cs")
    end,
  },
  {
    name = "reconnect setup registers command",
    run = function()
      delete_command("GodotReconnectLSP")

      h.clear_module("godotdev.reconnect_lsp")
      local mod = require("godotdev.reconnect_lsp")
      mod.setup()
      mod.setup()

      h.assert_equal(vim.fn.exists(":GodotReconnectLSP"), 2)
    end,
  },
  {
    name = "formatting setup registers a single BufWritePost autocmd",
    run = function()
      clear_augroup("godotdev_formatting")

      h.clear_module("godotdev.formatting")
      local mod = require("godotdev.formatting")
      mod.setup()
      mod.setup()

      local autocmds = vim.api.nvim_get_autocmds({ group = "godotdev_formatting" })
      h.assert_equal(#autocmds, 1)
      h.assert_equal(autocmds[1].event, "BufWritePost")
      h.assert_equal(autocmds[1].pattern, "*.gd")
    end,
  },
}
