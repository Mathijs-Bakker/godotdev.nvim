local h = require("tests.helpers")

local function delete_command(name)
  if vim.fn.exists(":" .. name) == 2 then
    vim.api.nvim_del_user_command(name)
  end
end

return {
  {
    name = "inline hints setup registers toggle command once",
    run = function()
      delete_command("GodotToggleInlineHints")

      h.clear_module("godotdev.inline_hints")
      local mod = require("godotdev.inline_hints")
      mod.setup()
      mod.setup()

      h.assert_equal(vim.fn.exists(":GodotToggleInlineHints"), 2)
    end,
  },
  {
    name = "inline hints enable_for_buffer enables hints when configured and supported",
    run = function()
      h.clear_module("godotdev.inline_hints")
      local mod = require("godotdev.inline_hints")
      mod.setup({ enabled = true })

      local calls = {}
      local original_enable = vim.lsp.inlay_hint.enable
      vim.lsp.inlay_hint.enable = function(enabled, filter)
        table.insert(calls, { enabled = enabled, filter = filter })
      end

      local ok, err = pcall(function()
        local client = {
          supports_method = function(_, method)
            return method == "textDocument/inlayHint"
          end,
        }

        h.assert_truthy(mod.enable_for_buffer(client, 12))
        h.assert_equal(#calls, 1)
        h.assert_equal(calls[1].enabled, true)
        h.assert_equal(calls[1].filter.bufnr, 12)
      end)

      vim.lsp.inlay_hint.enable = original_enable
      if not ok then
        error(err)
      end
    end,
  },
  {
    name = "inline hints toggle flips current buffer state",
    run = function()
      h.clear_module("godotdev.inline_hints")
      local mod = require("godotdev.inline_hints")

      local enabled = false
      local notifications = {}
      local original_is_enabled = vim.lsp.inlay_hint.is_enabled
      local original_enable = vim.lsp.inlay_hint.enable

      vim.lsp.inlay_hint.is_enabled = function(filter)
        h.assert_equal(filter.bufnr, 9)
        return enabled
      end
      vim.lsp.inlay_hint.enable = function(value, filter)
        enabled = value
        h.assert_equal(filter.bufnr, 9)
      end

      local ok, err = pcall(function()
        h.with_temp("notify", function(message, level)
          table.insert(notifications, { message = message, level = level })
        end, function()
          h.assert_truthy(mod.toggle(9))
        end)

        h.assert_truthy(enabled)
        h.assert_equal(#notifications, 1)
        h.assert_truthy(notifications[1].message:match("enabled") ~= nil)
      end)

      vim.lsp.inlay_hint.is_enabled = original_is_enabled
      vim.lsp.inlay_hint.enable = original_enable
      if not ok then
        error(err)
      end
    end,
  },
  {
    name = "lsp on_attach enables inline hints when available",
    run = function()
      h.clear_module("godotdev.inline_hints")
      h.clear_module("godotdev.lsp")

      local inline_hints = require("godotdev.inline_hints")
      local called = {}

      h.with_field(vim.lsp, "enable", function(name)
        h.assert_equal(name, "gdscript")
      end, function()
        h.with_field(inline_hints, "enable_for_buffer", function(client, bufnr)
          called.client = client
          called.bufnr = bufnr
          return true
        end, function()
          require("godotdev.lsp").setup({ editor_host = "127.0.0.1", editor_port = 6005 })

          local config = vim.lsp.config.gdscript
          h.assert_truthy(type(config.on_attach) == "function")

          local client = { handlers = {} }
          config.on_attach(client, 7)

          h.assert_equal(called.client, client)
          h.assert_equal(called.bufnr, 7)
        end)
      end)
    end,
  },
}
