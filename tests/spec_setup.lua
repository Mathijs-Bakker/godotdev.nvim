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
  {
    name = "run setup registers commands",
    run = function()
      for _, name in ipairs({ "GodotRunProject", "GodotRunCurrentScene", "GodotRunScene", "GodotRunScenePicker" }) do
        delete_command(name)
      end

      h.clear_module("godotdev.run")
      local mod = require("godotdev.run")
      mod.setup()
      mod.setup()

      h.assert_equal(vim.fn.exists(":GodotRunProject"), 2)
      h.assert_equal(vim.fn.exists(":GodotRunCurrentScene"), 2)
      h.assert_equal(vim.fn.exists(":GodotRunScene"), 2)
      h.assert_equal(vim.fn.exists(":GodotRunScenePicker"), 2)
    end,
  },
  {
    name = "docs setup registers commands once",
    run = function()
      for _, name in ipairs({ "GodotDocs", "GodotDocsFloat", "GodotDocsBrowser", "GodotDocsBuffer", "GodotDocsCursor" }) do
        delete_command(name)
      end
      vim.g._godot_docs_commands_defined = nil

      h.clear_module("godotdev.docs")
      local mod = require("godotdev.docs")
      mod.setup()
      mod.setup()

      h.assert_equal(vim.fn.exists(":GodotDocs"), 2)
      h.assert_equal(vim.fn.exists(":GodotDocsFloat"), 2)
      h.assert_equal(vim.fn.exists(":GodotDocsBrowser"), 2)
      h.assert_equal(vim.fn.exists(":GodotDocsBuffer"), 2)
      h.assert_equal(vim.fn.exists(":GodotDocsCursor"), 2)
    end,
  },
  {
    name = "main setup does not abort when dap is unavailable",
    run = function()
      local notifications = {}

      h.clear_module("godotdev")
      h.clear_module("godotdev.setup")

      h.with_temp("notify", function(message, level)
        table.insert(notifications, { message = message, level = level })
      end, function()
        h.with_package("godotdev.dap", {
          setup = function()
            error("dap unavailable")
          end,
        }, function()
          local godotdev = require("godotdev")
          godotdev.setup({ autostart_editor_server = false })
        end)
      end)

      h.assert_truthy(#notifications > 0)
      h.assert_truthy(
        notifications[1].message:match("nvim%-dap is not available") ~= nil
          or notifications[1].message:match("failed to configure DAP integration") ~= nil
      )
      h.assert_equal(vim.fn.exists(":GodotDocs"), 2)
      h.assert_equal(vim.fn.exists(":GodotStartEditorServer"), 2)
      h.assert_equal(vim.fn.exists(":GodotRunProject"), 2)
    end,
  },
}
