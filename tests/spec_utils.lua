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
  {
    name = "is_absolute_path recognizes unix windows drive and unc paths",
    run = function()
      h.clear_module("godotdev.utils")
      local utils = require("godotdev.utils")

      h.assert_truthy(utils.is_absolute_path("/tmp/project"))
      h.assert_truthy(utils.is_absolute_path("D:/project/scenes/Main.tscn"))
      h.assert_truthy(utils.is_absolute_path([[D:\project\scenes\Main.tscn]]))
      h.assert_truthy(utils.is_absolute_path([[\\server\share\project\scenes\Main.tscn]]))
      h.assert_falsy(utils.is_absolute_path("scenes/Main.tscn"))
    end,
  },
  {
    name = "to_res_path handles windows absolute scene paths inside project",
    run = function()
      h.clear_module("godotdev.utils")
      local utils = require("godotdev.utils")

      h.assert_equal(
        utils.to_res_path(
          "D:/2zhuomian/Projects/GameDev/Assets/Action/common_techniques_starter_project",
          "D:/2zhuomian/Projects/GameDev/Assets/Action/common_techniques_starter_project/scenes/player.tscn"
        ),
        "res://scenes/player.tscn"
      )
      h.assert_equal(utils.to_res_path([[D:\project]], [[D:\project\scenes\Main.tscn]]), "res://scenes/Main.tscn")
      h.assert_equal(
        utils.to_res_path([[\\server\share\project]], [[\\server\share\project\scenes\Main.tscn]]),
        "res://scenes/Main.tscn"
      )
      h.assert_equal(utils.to_res_path("D:/project", "D:/project-other/scenes/Main.tscn"), nil)
    end,
  },
}
