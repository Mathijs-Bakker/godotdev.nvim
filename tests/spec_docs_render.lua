local h = require("tests.helpers")

local function with_mock_system(responses, fn)
  return h.with_field(vim, "system", function(argv, _opts, on_exit)
    local url = argv[#argv]
    local response = responses[url] or { code = 1, stdout = "", stderr = "missing mock for " .. url }
    if on_exit then
      on_exit(response)
      return { wait = function() return response end }
    end
    return { wait = function() return response end }
  end, fn)
end

return {
  {
    name = "docs open uses configured browser renderer",
    run = function()
      h.clear_module("godotdev.docs")
      local docs = require("godotdev.docs")

      local opened_url
      local html_url = "https://docs.godotengine.org/en/stable/classes/class_node.html"

      h.with_package("godotdev", {
        opts = {
          docs = {
            renderer = "browser",
            version = "stable",
            language = "en",
          },
        },
      }, function()
        h.with_field(vim.fn, "executable", function(name)
          if name == "curl" then
            return 1
          end
          return vim.fn.executable(name)
        end, function()
          with_mock_system({
            [html_url] = { code = 0, stdout = "<html>ok</html>", stderr = "" },
          }, function()
            h.with_field(vim.ui, "open", function(url)
              opened_url = url
              return true
            end, function()
              docs.open("Node", nil)
              vim.wait(50, function()
                return opened_url ~= nil
              end)
            end)
          end)
        end)
      end)

      h.assert_equal(opened_url, html_url)
    end,
  },
  {
    name = "docs buffer renderer reuses the same scratch buffer",
    run = function()
      h.clear_module("godotdev.docs")
      local docs = require("godotdev.docs")

      local html_node = "https://docs.godotengine.org/en/stable/classes/class_node.html"
      local rst_node = "https://raw.githubusercontent.com/godotengine/godot-docs/master/classes/class_node.rst"
      local html_sprite = "https://docs.godotengine.org/en/stable/classes/class_sprite2d.html"
      local rst_sprite = "https://raw.githubusercontent.com/godotengine/godot-docs/master/classes/class_sprite2d.rst"

      h.with_package("godotdev", {
        opts = {
          docs = {
            renderer = "buffer",
            version = "stable",
            language = "en",
            source_ref = "master",
            buffer = {
              position = "current",
            },
          },
        },
      }, function()
        h.with_field(vim.fn, "executable", function(name)
          if name == "curl" then
            return 1
          end
          return vim.fn.executable(name)
        end, function()
          with_mock_system({
            [html_node] = { code = 0, stdout = "<html>node</html>", stderr = "" },
            [rst_node] = {
              code = 0,
              stdout = "Node\n====\n\nNode docs paragraph.\n",
              stderr = "",
            },
            [html_sprite] = { code = 0, stdout = "<html>sprite</html>", stderr = "" },
            [rst_sprite] = {
              code = 0,
              stdout = "Sprite2D\n========\n\nSprite docs paragraph.\n",
              stderr = "",
            },
          }, function()
            docs.open("Node", "buffer")
            vim.wait(50)
            local first_buf = vim.api.nvim_get_current_buf()
            local first_name = vim.api.nvim_buf_get_name(first_buf)
            local first_lines = vim.api.nvim_buf_get_lines(first_buf, 0, 4, false)

            docs.open("Sprite2D", "buffer")
            vim.wait(50)
            local second_buf = vim.api.nvim_get_current_buf()
            local second_name = vim.api.nvim_buf_get_name(second_buf)
            local second_lines = vim.api.nvim_buf_get_lines(second_buf, 0, 4, false)

            h.assert_equal(first_buf, second_buf)
            h.assert_truthy(first_name:match("godotdev://docs/node") ~= nil)
            h.assert_truthy(second_name:match("godotdev://docs/sprite2d") ~= nil)
            h.assert_equal(first_lines[1], "# Node")
            h.assert_equal(second_lines[1], "# Sprite2D")
          end)
        end)
      end)
    end,
  },
  {
    name = "docs fall back to browser when rendered docs fetch fails",
    run = function()
      h.clear_module("godotdev.docs")
      local docs = require("godotdev.docs")

      local opened_url
      local html_url = "https://docs.godotengine.org/en/stable/classes/class_node.html"
      local rst_url = "https://raw.githubusercontent.com/godotengine/godot-docs/master/classes/class_node.rst"

      h.with_package("godotdev", {
        opts = {
          docs = {
            renderer = "float",
            fallback_renderer = "browser",
            version = "stable",
            language = "en",
            source_ref = "master",
          },
        },
      }, function()
        h.with_field(vim.fn, "executable", function(name)
          if name == "curl" then
            return 1
          end
          return vim.fn.executable(name)
        end, function()
          with_mock_system({
            [html_url] = { code = 0, stdout = "<html>node</html>", stderr = "" },
            [rst_url] = { code = 1, stdout = "", stderr = "fetch failed" },
          }, function()
            h.with_field(vim.ui, "open", function(url)
              opened_url = url
              return true
            end, function()
              docs.open("Node", "float")
              vim.wait(50, function()
                return opened_url ~= nil
              end)
            end)
          end)
        end)
      end)

      h.assert_equal(opened_url, html_url)
    end,
  },
  {
    name = "docs fall back to browser when rendered markdown is empty",
    run = function()
      h.clear_module("godotdev.docs")
      local docs = require("godotdev.docs")

      local opened_url
      local html_url = "https://docs.godotengine.org/en/stable/classes/class_node.html"
      local rst_url = "https://raw.githubusercontent.com/godotengine/godot-docs/master/classes/class_node.rst"

      h.with_package("godotdev", {
        opts = {
          docs = {
            renderer = "float",
            fallback_renderer = "browser",
            version = "stable",
            language = "en",
            source_ref = "master",
          },
        },
      }, function()
        h.with_field(vim.fn, "executable", function(name)
          if name == "curl" then
            return 1
          end
          return vim.fn.executable(name)
        end, function()
          with_mock_system({
            [html_url] = { code = 0, stdout = "<html>node</html>", stderr = "" },
            [rst_url] = { code = 0, stdout = "", stderr = "" },
          }, function()
            h.with_field(vim.ui, "open", function(url)
              opened_url = url
              return true
            end, function()
              docs.open("Node", "float")
              vim.wait(50, function()
                return opened_url ~= nil
              end)
            end)
          end)
        end)
      end)

      h.assert_equal(opened_url, html_url)
    end,
  },
  {
    name = "docs resolve symbols through the index when direct page lookup fails",
    run = function()
      h.clear_module("godotdev.docs")
      local docs = require("godotdev.docs")

      local opened_url
      local direct_url = "https://docs.godotengine.org/en/stable/classes/class_animatedsprite2d.html"
      local index_url = "https://docs.godotengine.org/en/stable/classes/index.html"
      local resolved_url = "https://docs.godotengine.org/en/stable/classes/class_animated_sprite_2d.html"

      h.with_package("godotdev", {
        opts = {
          docs = {
            renderer = "browser",
            version = "stable",
            language = "en",
          },
        },
      }, function()
        h.with_field(vim.fn, "executable", function(name)
          if name == "curl" then
            return 1
          end
          return vim.fn.executable(name)
        end, function()
          with_mock_system({
            [direct_url] = { code = 1, stdout = "", stderr = "not found" },
            [index_url] = {
              code = 0,
              stdout = [[<a href="classes/class_animated_sprite_2d.html">AnimatedSprite2D</a>]],
              stderr = "",
            },
            [resolved_url] = { code = 0, stdout = "<html>resolved</html>", stderr = "" },
          }, function()
            h.with_field(vim.ui, "open", function(url)
              opened_url = url
              return true
            end, function()
              docs.open("AnimatedSprite2D", "browser")
              vim.wait(50, function()
                return opened_url ~= nil
              end)
            end)
          end)
        end)
      end)

      h.assert_equal(opened_url, resolved_url)
    end,
  },
  {
    name = "docs show feedback when a symbol cannot be resolved",
    run = function()
      h.clear_module("godotdev.docs")
      local docs = require("godotdev.docs")

      local messages = {}
      local direct_url = "https://docs.godotengine.org/en/stable/classes/class_notarealsymbol.html"
      local index_url = "https://docs.godotengine.org/en/stable/classes/index.html"

      h.with_package("godotdev", {
        opts = {
          docs = {
            renderer = "float",
            version = "stable",
            language = "en",
            missing_symbol_feedback = "message",
          },
        },
      }, function()
        h.with_field(vim.fn, "executable", function(name)
          if name == "curl" then
            return 1
          end
          return vim.fn.executable(name)
        end, function()
          with_mock_system({
            [direct_url] = { code = 1, stdout = "", stderr = "not found" },
            [index_url] = { code = 0, stdout = "<html></html>", stderr = "" },
          }, function()
            h.with_field(vim.api, "nvim_echo", function(chunks)
              table.insert(messages, chunks[1][1])
            end, function()
              docs.open("NotARealSymbol", nil)
              vim.wait(50, function()
                return #messages > 0
              end)
            end)
          end)
        end)
      end)

      h.assert_truthy(messages[1]:match("Could not find Godot docs for `NotARealSymbol`") ~= nil)
    end,
  },
}
