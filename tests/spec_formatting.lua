local h = require("tests.helpers")

local function clear_augroup(name)
  pcall(vim.api.nvim_del_augroup_by_name, name)
end

local function with_temp_gd_buffer(fn)
  local path = vim.fn.tempname() .. ".gd"
  local buf = vim.api.nvim_create_buf(false, true)

  vim.bo[buf].swapfile = false
  vim.bo[buf].buftype = ""
  vim.bo[buf].bufhidden = "wipe"
  vim.api.nvim_buf_set_name(buf, path)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "extends Node" })

  local ok, err = pcall(fn, buf, path)

  pcall(vim.api.nvim_buf_delete, buf, { force = true })
  pcall(vim.fn.delete, path)

  if not ok then
    error(err)
  end
end

local function simulate_save(buf, path)
  vim.fn.writefile(vim.api.nvim_buf_get_lines(buf, 0, -1, false), path)
  vim.api.nvim_exec_autocmds("BufWritePost", { buffer = buf, modeline = false })
end

return {
  {
    name = "formatting does nothing when formatter is disabled",
    run = function()
      local notifications = {}
      local system_called = false

      clear_augroup("godotdev_formatting")
      h.with_package("godotdev", {
        opts = {
          formatter = false,
          formatter_cmd = nil,
        },
      }, function()
        h.clear_module("godotdev.formatting")
        local formatting = require("godotdev.formatting")
        formatting.setup()

        h.with_temp("notify", function(message, level)
          table.insert(notifications, { message = message, level = level })
        end, function()
          h.with_field(vim, "system", function()
            system_called = true
            error("vim.system should not be called when formatter is disabled")
          end, function()
            with_temp_gd_buffer(function(buf, path)
              simulate_save(buf, path)
            end)
          end)
        end)
      end)

      h.assert_falsy(system_called)
      h.assert_equal(#notifications, 0)
    end,
  },
  {
    name = "formatting warns when formatter executable is missing",
    run = function()
      local notifications = {}

      clear_augroup("godotdev_formatting")
      h.with_package("godotdev", {
        opts = {
          formatter = "gdscript-formatter",
          formatter_cmd = nil,
        },
      }, function()
        h.clear_module("godotdev.formatting")
        local formatting = require("godotdev.formatting")
        formatting.setup()

        h.with_field(vim.fn, "executable", function(name)
          if name == "gdscript-formatter" then
            return 0
          end
          return vim.fn.executable(name)
        end, function()
          h.with_temp("notify", function(message, level)
            table.insert(notifications, { message = message, level = level })
          end, function()
            with_temp_gd_buffer(function(buf, path)
              simulate_save(buf, path)
            end)
          end)
        end)
      end)

      h.assert_equal(#notifications, 1)
      h.assert_truthy(notifications[1].message:match("gdscript%-formatter not found in PATH") ~= nil)
    end,
  },
  {
    name = "formatting reports formatter failures from vim.system",
    run = function()
      local notifications = {}
      local called_argv

      clear_augroup("godotdev_formatting")
      h.with_package("godotdev", {
        opts = {
          formatter = "gdscript-formatter",
          formatter_cmd = { "gdscript-formatter", "--check" },
        },
      }, function()
        h.clear_module("godotdev.formatting")
        local formatting = require("godotdev.formatting")
        formatting.setup()

        h.with_field(vim.fn, "executable", function()
          return 1
        end, function()
          h.with_temp("notify", function(message, level)
            table.insert(notifications, { message = message, level = level })
          end, function()
            h.with_field(vim, "system", function(argv, _opts, on_exit)
              called_argv = argv
              local result = { code = 1, stdout = "", stderr = "formatter failed" }
              on_exit(result)
              return {
                wait = function()
                  return result
                end,
              }
            end, function()
              with_temp_gd_buffer(function(buf, path)
                simulate_save(buf, path)
                vim.wait(50, function()
                  return #notifications > 0
                end)
              end)
            end)
          end)
        end)
      end)

      h.assert_equal(called_argv[1], "gdscript-formatter")
      h.assert_equal(called_argv[2], "--check")
      h.assert_truthy(notifications[1].message:match("formatter failed") ~= nil)
    end,
  },
  {
    name = "formatting runs checktime after successful formatter completion",
    run = function()
      local called_argv
      local checktime_calls = 0

      clear_augroup("godotdev_formatting")
      h.with_package("godotdev", {
        opts = {
          formatter = "gdscript-formatter",
          formatter_cmd = { "gdscript-formatter" },
        },
      }, function()
        h.clear_module("godotdev.formatting")
        local formatting = require("godotdev.formatting")
        formatting.setup()

        h.with_field(vim.fn, "executable", function()
          return 1
        end, function()
          h.with_field(vim, "system", function(argv, _opts, on_exit)
            called_argv = argv
            local result = { code = 0, stdout = "", stderr = "" }
            on_exit(result)
            return {
              wait = function()
                return result
              end,
            }
          end, function()
            h.with_field(vim.api, "nvim_buf_call", function(_buf, cb)
              return cb()
            end, function()
              h.with_temp("cmd", function(command)
                if command == "checktime" then
                  checktime_calls = checktime_calls + 1
                end
              end, function()
                with_temp_gd_buffer(function(buf, path)
                  simulate_save(buf, path)
                  vim.wait(50, function()
                    return checktime_calls > 0
                  end)
                end)
              end)
            end)
          end)
        end)
      end)

      h.assert_equal(called_argv[1], "gdscript-formatter")
      h.assert_equal(checktime_calls, 1)
    end,
  },
}
