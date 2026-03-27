local h = require("tests.helpers")

return {
  {
    name = "suppress_client_messages filters only matching client messages",
    run = function()
      h.clear_module("godotdev.utils")
      local utils = require("godotdev.utils")

      local calls = 0
      local client = { handlers = {} }

      local original = vim.lsp.handlers["window/showMessage"]
      vim.lsp.handlers["window/showMessage"] = function(...)
        calls = calls + 1
        return ...
      end

      local ok, err = pcall(function()
        utils.suppress_client_messages(client, { "godot/reloadScript" })

        h.assert_truthy(type(client.handlers["window/showMessage"]) == "function")
        client.handlers["window/showMessage"](nil, { message = "Method not found: godot/reloadScript" }, {}, {})
        h.assert_equal(calls, 0, "matching message should be suppressed")

        client.handlers["window/showMessage"](nil, { message = "Something else" }, {}, {})
        h.assert_equal(calls, 1, "non-matching message should call the original handler")
      end)

      vim.lsp.handlers["window/showMessage"] = original
      if not ok then
        error(err)
      end
    end,
  },
}
