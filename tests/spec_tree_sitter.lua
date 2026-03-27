local h = require("tests.helpers")

return {
  {
    name = "tree-sitter setup always registers gdshader filetype",
    run = function()
      h.clear_module("godotdev.tree-sitter")
      local tree_sitter = require("godotdev.tree-sitter")

      local calls = {}
      local original = vim.filetype.add
      vim.filetype.add = function(spec)
        table.insert(calls, spec)
      end

      local ok, err = pcall(function()
        h.with_package("godotdev", { opts = { treesitter = { auto_setup = false } } }, function()
          tree_sitter.setup()
        end)
      end)

      vim.filetype.add = original
      if not ok then
        error(err)
      end

      h.assert_equal(#calls, 1)
      h.assert_equal(calls[1].extension.gdshader, "gdshader")
    end,
  },
  {
    name = "tree-sitter setup honors custom ensure_installed list",
    run = function()
      h.clear_module("godotdev.tree-sitter")
      local tree_sitter = require("godotdev.tree-sitter")

      local original_filetype_add = vim.filetype.add
      vim.filetype.add = function() end

      local captured
      local ok, err = pcall(function()
        h.with_package("godotdev", {
          opts = {
            treesitter = {
              auto_setup = true,
              ensure_installed = { "gdscript", "lua" },
            },
          },
        }, function()
          h.with_package("nvim-treesitter.configs", {
            setup = function(opts)
              captured = opts
            end,
          }, function()
            tree_sitter.setup()
          end)
        end)
      end)

      vim.filetype.add = original_filetype_add
      if not ok then
        error(err)
      end

      h.assert_truthy(captured ~= nil, "nvim-treesitter setup should be called")
      h.assert_equal(captured.ensure_installed[1], "gdscript")
      h.assert_equal(captured.ensure_installed[2], "lua")
      h.assert_equal(captured.highlight.enable, true)
    end,
  },
}
