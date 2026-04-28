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
    name = "scene tree parser extracts hierarchy and attached scripts",
    run = function()
      h.clear_module("godotdev.scene_tree")
      local scene_tree = require("godotdev.scene_tree")

      local parsed = scene_tree._parse_scene({
        '[gd_scene format=3]',
        '[ext_resource type="Script" path="res://scripts/player.gd" id="1"]',
        '[node name="Main" type="Node2D"]',
        '[node name="Player" type="CharacterBody2D" parent="."]',
        'script = ExtResource("1")',
        '[node name="Weapon" type="Node" parent="Player"]',
      })

      h.assert_equal(#parsed.nodes, 3)
      h.assert_equal(parsed.nodes[1].path, ".")
      h.assert_equal(parsed.nodes[2].path, "Player")
      h.assert_equal(parsed.nodes[2].script, "res://scripts/player.gd")
      h.assert_equal(parsed.nodes[3].path, "Player/Weapon")
      h.assert_equal(parsed.nodes[3].depth, 2)
    end,
  },
  {
    name = "scene tree opens for current scene and copies node path",
    run = function()
      h.clear_module("godotdev.scene_tree")
      local scene_tree = require("godotdev.scene_tree")

      with_temp_project(function(root)
        local scene = root .. "/scenes/Main.tscn"
        vim.fn.mkdir(vim.fs.dirname(scene), "p")
        vim.fn.writefile({
          '[gd_scene format=3]',
          '[node name="Main" type="Node2D"]',
          '[node name="Player" type="CharacterBody2D" parent="."]',
        }, scene)

        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_name(buf, scene)
        vim.api.nvim_set_current_buf(buf)

        local ok = scene_tree.open()
        h.assert_truthy(ok)
        h.assert_equal(scene_tree._state.lines[1], "Main [Node2D]")
        h.assert_equal(scene_tree._state.lines[2], "  Player [CharacterBody2D]")

        local tree_buf = scene_tree._state.buffer
        local tree_win = scene_tree._state.window
        vim.api.nvim_set_current_win(tree_win)
        vim.api.nvim_win_set_cursor(tree_win, { 2, 0 })

        local copied
        h.with_field(vim.fn, "setreg", function(_register, value)
          copied = value
        end, function()
          local copied_ok = scene_tree.copy_node_path()
          h.assert_truthy(copied_ok)
        end)

        h.assert_equal(copied, "Player")

        pcall(vim.api.nvim_buf_delete, tree_buf, { force = true })
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
      end)
    end,
  },
  {
    name = "scene tree resolves the only attached scene for a script",
    run = function()
      h.clear_module("godotdev.scene_tree")
      local scene_tree = require("godotdev.scene_tree")

      with_temp_project(function(root)
        local script = root .. "/scripts/player.gd"
        local scene = root .. "/scenes/Main.tscn"
        vim.fn.mkdir(vim.fs.dirname(script), "p")
        vim.fn.mkdir(vim.fs.dirname(scene), "p")
        vim.fn.writefile({ "extends Node" }, script)
        vim.fn.writefile({
          '[gd_scene format=3]',
          '[ext_resource type="Script" path="res://scripts/player.gd" id="1"]',
          '[node name="Main" type="Node2D"]',
          '[node name="Player" type="CharacterBody2D" parent="."]',
          'script = ExtResource("1")',
        }, scene)

        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_name(buf, script)
        vim.api.nvim_set_current_buf(buf)

        h.assert_equal(scene_tree._resolve_scene(), "res://scenes/Main.tscn")

        pcall(vim.api.nvim_buf_delete, buf, { force = true })
      end)
    end,
  },
  {
    name = "scene tree jumps to attached script for the selected node",
    run = function()
      h.clear_module("godotdev.scene_tree")
      local scene_tree = require("godotdev.scene_tree")

      with_temp_project(function(root)
        local script = root .. "/scripts/player.gd"
        local scene = root .. "/scenes/Main.tscn"
        vim.fn.mkdir(vim.fs.dirname(script), "p")
        vim.fn.mkdir(vim.fs.dirname(scene), "p")
        vim.fn.writefile({ "extends Node" }, script)
        vim.fn.writefile({
          '[gd_scene format=3]',
          '[ext_resource type="Script" path="res://scripts/player.gd" id="1"]',
          '[node name="Main" type="Node2D"]',
          '[node name="Player" type="CharacterBody2D" parent="."]',
          'script = ExtResource("1")',
        }, scene)

        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_name(buf, scene)
        vim.api.nvim_set_current_buf(buf)
        scene_tree.open()

        local tree_win = scene_tree._state.window
        vim.api.nvim_set_current_win(tree_win)
        vim.api.nvim_win_set_cursor(tree_win, { 2, 0 })

        local opened
        h.with_temp("cmd", function(command)
          opened = command
        end, function()
          local ok = scene_tree.jump_to_script()
          h.assert_truthy(ok)
        end)

        h.assert_truthy(opened:match("player%.gd") ~= nil)

        pcall(vim.api.nvim_buf_delete, scene_tree._state.buffer, { force = true })
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
      end)
    end,
  },
}
