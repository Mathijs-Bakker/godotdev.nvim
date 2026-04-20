local h = require("tests.helpers")

local function delete_command(name)
  if vim.fn.exists(":" .. name) == 2 then
    vim.api.nvim_del_user_command(name)
  end
end

return {
  {
    name = "run console setup registers show command once",
    run = function()
      delete_command("GodotShowConsole")

      h.clear_module("godotdev.run_console")
      local mod = require("godotdev.run_console")
      mod.setup()
      mod.setup()

      h.assert_equal(vim.fn.exists(":GodotShowConsole"), 2)
    end,
  },
  {
    name = "run console start appends stdout stderr and exit status",
    run = function()
      h.clear_module("godotdev.run_console")
      local mod = require("godotdev.run_console")
      mod.setup({
        enabled = true,
        renderer = "buffer",
        buffer = {
          position = "bottom",
          size = 0.3,
        },
      })

      local ok, err = pcall(function()
        h.with_field(vim, "schedule", function(fn)
          fn()
        end, function()
          h.with_field(vim, "system", function(_cmd, _opts, on_exit)
            _opts.stdout(nil, "hello\n")
            _opts.stderr(nil, "oops\n")
            on_exit({ code = 0, signal = 0 })
            return {}
          end, function()
            h.assert_truthy(mod.start({ "godot", "--path", "/tmp/project" }, "/tmp/project"))
          end)
        end)

        local buf = vim.api.nvim_get_current_buf()
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        h.assert_truthy(lines[1]:match("Godot Console") ~= nil)
        h.assert_equal(lines[6], "hello")
        h.assert_equal(lines[7], "[stderr] oops")
        h.assert_truthy(lines[#lines]:match("%[Process exited%] code=0 signal=0") ~= nil)
      end)

      if not ok then
        error(err)
      end
    end,
  },
  {
    name = "run_project uses run console when enabled",
    run = function()
      local called = {}

      h.clear_module("godotdev.run_console")
      h.clear_module("godotdev.run")
      local run = require("godotdev.run")
      local run_console = require("godotdev.run_console")
      run_console.setup({ enabled = true })

      local root = vim.fn.tempname()
      vim.fn.mkdir(root, "p")
      vim.fn.writefile({ "; Engine configuration file." }, root .. "/project.godot")
      local scene = root .. "/scenes/Main.tscn"
      vim.fn.mkdir(vim.fs.dirname(scene), "p")
      vim.fn.writefile({ "[gd_scene format=3]" }, scene)

      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_name(buf, scene)
      vim.api.nvim_set_current_buf(buf)

      local ok, err = pcall(function()
        h.with_field(vim.fn, "executable", function(name)
          return name == "godot" and 1 or 0
        end, function()
          h.with_field(run_console, "start", function(cmd, root_arg)
            called.cmd = cmd
            called.root = root_arg
            return true
          end, function()
            h.assert_truthy(run.run_project())
          end)
        end)
      end)

      run_console.setup({ enabled = false })

      pcall(vim.api.nvim_buf_delete, buf, { force = true })
      pcall(vim.fn.delete, root, "rf")

      if not ok then
        error(err)
      end

      h.assert_equal(called.cmd[1], "godot")
      h.assert_equal(called.cmd[2], "--path")
      h.assert_equal(vim.uv.fs_realpath(called.root), vim.uv.fs_realpath(root))
    end,
  },
}
