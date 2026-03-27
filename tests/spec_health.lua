local h = require("tests.helpers")

local function make_health_recorder()
  local calls = { start = {}, ok = {}, warn = {}, info = {}, error = {} }
  return {
    calls = calls,
    api = {
      start = function(message)
        table.insert(calls.start, message)
      end,
      ok = function(message)
        table.insert(calls.ok, message)
      end,
      warn = function(message)
        table.insert(calls.warn, message)
      end,
      info = function(message)
        table.insert(calls.info, message)
      end,
      error = function(message)
        table.insert(calls.error, message)
      end,
    },
  }
end

return {
  {
    name = "health reports curl requirement for buffer docs renderer",
    run = function()
      local recorder = make_health_recorder()

      h.with_temp("health", recorder.api, function()
        h.with_package("godotdev", {
          opts = {
            csharp = false,
            docs = { renderer = "buffer", source_ref = "master" },
            formatter = "gdformat",
          },
        }, function()
          h.with_package("nvim-treesitter.configs", {}, function()
            h.with_package("dapui", {}, function()
              h.clear_module("godotdev.health")
              local health = require("godotdev.health")

              h.with_field(vim.fn, "exists", function(cmd)
                if cmd == ":LspInfo" or cmd == ":DapContinue" then
                  return 2
                end
                return 0
              end, function()
                h.with_field(vim.fn, "executable", function(name)
                  if name == "curl" then
                    return 0
                  end
                  return 1
                end, function()
                  h.with_field(vim.fn, "systemlist", function()
                    return {}
                  end, function()
                    h.with_field(vim, "system", function(argv, _opts)
                      return {
                        wait = function()
                          if argv[1] == "godot" then
                            return { code = 0, stdout = "4.3.stable\n", stderr = "" }
                          end
                          return { code = 0, stdout = "", stderr = "" }
                        end,
                      }
                    end, function()
                      health.check()
                    end)
                  end)
                end)
              end)
            end)
          end)
        end)
      end)

      local joined_warns = table.concat(recorder.calls.warn, "\n")
      h.assert_truthy(joined_warns:match("Float and buffer Godot docs rendering require 'curl'") ~= nil)
    end,
  },
  {
    name = "health reports formatter command when formatter_cmd is an argv list",
    run = function()
      local recorder = make_health_recorder()

      h.with_temp("health", recorder.api, function()
        h.with_package("godotdev", {
          opts = {
            csharp = false,
            docs = { renderer = "browser", source_ref = "master" },
            formatter = "gdscript-format",
            formatter_cmd = { "gdscript-format", "--check" },
          },
        }, function()
          h.with_package("nvim-treesitter.configs", {}, function()
            h.with_package("dapui", {}, function()
              h.clear_module("godotdev.health")
              local health = require("godotdev.health")

              h.with_field(vim.fn, "exists", function(cmd)
                if cmd == ":LspInfo" or cmd == ":DapContinue" then
                  return 2
                end
                return 0
              end, function()
                h.with_field(vim.fn, "executable", function()
                  return 1
                end, function()
                  h.with_field(vim.fn, "systemlist", function()
                    return {}
                  end, function()
                    h.with_field(vim, "system", function(argv, _opts)
                      return {
                        wait = function()
                          if argv[1] == "godot" then
                            return { code = 0, stdout = "4.3.stable\n", stderr = "" }
                          end
                          return { code = 0, stdout = "", stderr = "" }
                        end,
                      }
                    end, function()
                      health.check()
                    end)
                  end)
                end)
              end)
            end)
          end)
        end)
      end)

      local joined_info = table.concat(recorder.calls.info, "\n")
      h.assert_truthy(joined_info:match("Formatter command: gdscript%-format %-%-check") ~= nil)
    end,
  },
  {
    name = "health skips curl warning for browser-only docs mode",
    run = function()
      local recorder = make_health_recorder()

      h.with_temp("health", recorder.api, function()
        h.with_package("godotdev", {
          opts = {
            csharp = false,
            docs = { renderer = "browser", source_ref = "master" },
            formatter = "gdformat",
          },
        }, function()
          h.with_package("nvim-treesitter.configs", {}, function()
            h.with_package("dapui", {}, function()
              h.clear_module("godotdev.health")
              local health = require("godotdev.health")

              h.with_field(vim.fn, "exists", function(cmd)
                if cmd == ":LspInfo" or cmd == ":DapContinue" then
                  return 2
                end
                return 0
              end, function()
                h.with_field(vim.fn, "executable", function(name)
                  if name == "curl" then
                    return 0
                  end
                  return 1
                end, function()
                  h.with_field(vim.fn, "systemlist", function()
                    return {}
                  end, function()
                    h.with_field(vim, "system", function(argv, _opts)
                      return {
                        wait = function()
                          if argv[1] == "godot" then
                            return { code = 0, stdout = "4.3.stable\n", stderr = "" }
                          end
                          return { code = 0, stdout = "", stderr = "" }
                        end,
                      }
                    end, function()
                      health.check()
                    end)
                  end)
                end)
              end)
            end)
          end)
        end)
      end)

      local joined_warns = table.concat(recorder.calls.warn, "\n")
      local joined_info = table.concat(recorder.calls.info, "\n")
      h.assert_falsy(joined_warns:match("rendered Godot docs"))
      h.assert_truthy(joined_info:match("Rendered docs dependency checks skipped") ~= nil)
    end,
  },
}
