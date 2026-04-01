local h = require("tests.helpers")

local function with_temp_project(fn)
  local root = vim.fn.tempname()
  vim.fn.mkdir(root, "p")
  vim.fn.writefile({ "; Engine configuration file." }, root .. "/project.godot")

  local ok, err = pcall(fn, root)

  pcall(vim.fn.delete, root, "rf")

  if not ok then
    error(err)
  end
end

return {
  {
    name = "pick_scene warns when telescope is unavailable",
    run = function()
      local notifications = {}

      h.clear_module("godotdev.run")
      local run = require("godotdev.run")

      with_temp_project(function(root)
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_name(buf, root .. "/scripts/player.gd")
        vim.api.nvim_set_current_buf(buf)

        h.with_temp("notify", function(message, level)
          table.insert(notifications, { message = message, level = level })
        end, function()
          local ok = run.pick_scene()
          h.assert_falsy(ok)
        end)

        pcall(vim.api.nvim_buf_delete, buf, { force = true })
      end)

      h.assert_truthy(notifications[1].message:match("Telescope is required") ~= nil)
    end,
  },
  {
    name = "pick_scene runs the selected telescope scene",
    run = function()
      local called_scene
      local replaced = false
      local picker_found = false

      h.clear_module("godotdev.run")
      local run = require("godotdev.run")

      with_temp_project(function(root)
        local scene = root .. "/scenes/Main.tscn"
        vim.fn.mkdir(vim.fs.dirname(scene), "p")
        vim.fn.writefile({ "[gd_scene format=3]" }, scene)

        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_name(buf, root .. "/scripts/player.gd")
        vim.api.nvim_set_current_buf(buf)

        h.with_package("telescope.finders", {
          new_table = function(opts)
            return opts
          end,
        }, function()
          h.with_package("telescope.config", {
            values = {
              generic_sorter = function()
                return function()
                  return true
                end
              end,
            },
          }, function()
            h.with_package("telescope.actions", {
              select_default = {
                replace = function(_self, fn)
                  replaced = true
                  fn()
                end,
              },
              close = function()
              end,
            }, function()
              h.with_package("telescope.actions.state", {
                get_selected_entry = function()
                  return { "res://scenes/Main.tscn" }
                end,
              }, function()
                h.with_package("telescope.pickers", {
                  new = function(_opts, spec)
                    return {
                      find = function()
                        picker_found = true
                        spec.attach_mappings(1)
                      end,
                    }
                  end,
                }, function()
                  h.with_field(run, "run_scene", function(scene_arg)
                    called_scene = scene_arg
                    return true
                  end, function()
                    local ok = run.pick_scene()
                    h.assert_truthy(ok)
                  end)
                end)
              end)
            end)
          end)
        end)

        pcall(vim.api.nvim_buf_delete, buf, { force = true })
      end)

      h.assert_truthy(picker_found)
      h.assert_truthy(replaced)
      h.assert_equal(called_scene, "res://scenes/Main.tscn")
    end,
  },
  {
    name = "run_project launches godot with the project root",
    run = function()
      local called_cmd

      h.clear_module("godotdev.run")
      local run = require("godotdev.run")

      with_temp_project(function(root)
        local scene = root .. "/scenes/Main.tscn"
        vim.fn.mkdir(vim.fs.dirname(scene), "p")
        vim.fn.writefile({ "[gd_scene format=3]" }, scene)

        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_name(buf, scene)
        vim.api.nvim_set_current_buf(buf)

        h.with_field(vim.fn, "executable", function(name)
          return name == "godot" and 1 or 0
        end, function()
          h.with_field(vim, "system", function(cmd, _opts, _on_exit)
            called_cmd = cmd
            return {}
          end, function()
            run.run_project()
          end)
        end)

        pcall(vim.api.nvim_buf_delete, buf, { force = true })
      end)

      h.assert_equal(called_cmd[1], "godot")
      h.assert_equal(called_cmd[2], "--path")
      h.assert_truthy(called_cmd[3]:match("project%.godot") == nil)
    end,
  },
  {
    name = "run_current_scene launches the current scene as res path",
    run = function()
      local called_cmd

      h.clear_module("godotdev.run")
      local run = require("godotdev.run")

      with_temp_project(function(root)
        local scene = root .. "/scenes/Main.tscn"
        vim.fn.mkdir(vim.fs.dirname(scene), "p")
        vim.fn.writefile({ "[gd_scene format=3]" }, scene)

        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_name(buf, scene)
        vim.api.nvim_set_current_buf(buf)

        h.with_field(vim.fn, "executable", function(name)
          return name == "godot" and 1 or 0
        end, function()
          h.with_field(vim, "system", function(cmd, _opts, _on_exit)
            called_cmd = cmd
            return {}
          end, function()
            run.run_current_scene()
          end)
        end)

        pcall(vim.api.nvim_buf_delete, buf, { force = true })
      end)

      h.assert_equal(called_cmd[4], "res://scenes/Main.tscn")
    end,
  },
  {
    name = "run_scene rejects paths outside the project",
    run = function()
      local notifications = {}

      h.clear_module("godotdev.run")
      local run = require("godotdev.run")

      with_temp_project(function(root)
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_name(buf, root .. "/scripts/player.gd")
        vim.api.nvim_set_current_buf(buf)

        h.with_temp("notify", function(message, level)
          table.insert(notifications, { message = message, level = level })
        end, function()
          local ok = run.run_scene("/tmp/outside.tscn")
          h.assert_falsy(ok)
        end)

        pcall(vim.api.nvim_buf_delete, buf, { force = true })
      end)

      h.assert_truthy(notifications[1].message:match("inside the current Godot project") ~= nil)
    end,
  },
}
