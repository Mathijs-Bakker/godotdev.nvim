local h = require("tests.helpers")

local function delete_command(name)
  if vim.fn.exists(":" .. name) == 2 then
    vim.api.nvim_del_user_command(name)
  end
end

return {
  {
    name = "docs commands dispatch the expected renderer",
    run = function()
      for _, name in ipairs({ "GodotDocs", "GodotDocsFloat", "GodotDocsBrowser", "GodotDocsBuffer", "GodotDocsCursor" }) do
        delete_command(name)
      end
      vim.g._godot_docs_commands_defined = nil

      h.clear_module("godotdev.docs")
      local docs = require("godotdev.docs")
      docs.setup()

      local calls = {}
      local original_open = docs.open
      docs.open = function(symbol, renderer)
        table.insert(calls, { symbol = symbol, renderer = renderer })
      end

      local ok, err = pcall(function()
        h.with_field(vim.fn, "expand", function()
          return "CursorSymbol"
        end, function()
          vim.cmd("GodotDocs Node")
          vim.cmd("GodotDocsFloat Node")
          vim.cmd("GodotDocsBrowser Node")
          vim.cmd("GodotDocsBuffer Node")
          vim.cmd("GodotDocsCursor")
        end)
      end)

      docs.open = original_open
      if not ok then
        error(err)
      end

      h.assert_equal(#calls, 5)
      h.assert_equal(calls[1].symbol, "Node")
      h.assert_equal(calls[1].renderer, nil)
      h.assert_equal(calls[2].renderer, "float")
      h.assert_equal(calls[3].renderer, "browser")
      h.assert_equal(calls[4].renderer, "buffer")
      h.assert_equal(calls[5].symbol, "CursorSymbol")
      h.assert_equal(calls[5].renderer, nil)
    end,
  },
}
