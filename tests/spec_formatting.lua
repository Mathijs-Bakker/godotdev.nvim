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
    name = "formatting warns when formatter executable is missing",
    run = function()
      local notifications = {}

      clear_augroup("godotdev_formatting")
      h.with_package("godotdev", {
        opts = {
          formatter = "gdformat",
          formatter_cmd = nil,
        },
      }, function()
        h.clear_module("godotdev.formatting")
        local formatting = require("godotdev.formatting")
        formatting.setup()

        h.with_field(vim.fn, "executable", function(name)
          if name == "gdformat" then
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
      h.assert_truthy(notifications[1].message:match("gdformat not found in PATH") ~= nil)
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
          formatter = "gdscript-format",
          formatter_cmd = { "gdscript-format", "--check" },
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
              return { wait = function() return result end }
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

      h.assert_equal(called_argv[1], "gdscript-format")
      h.assert_equal(called_argv[2], "--check")
      h.assert_truthy(notifications[1].message:match("formatter failed") ~= nil)
    end,
  },
}
