local M = {}
local utils = require("godotdev.utils")

M.opts = {
  godot_path = "godot",
}

local function godot_executable()
  if type(M.opts.godot_path) == "string" and M.opts.godot_path ~= "" then
    return M.opts.godot_path
  end

  return "godot"
end

local function missing_godot_message(executable)
  return table.concat({
    "Godot executable not found: " .. executable,
    "You can:",
    "- add Godot to your PATH as `godot`",
    "- configure `godot_path` in require('godotdev').setup()",
    "- use a version manager such as gdvm or a project-aware wrapper script",
  }, "\n")
end

local function normalize_scene_arg(scene)
  local root = utils.find_project_root()
  if not root or type(scene) ~= "string" or scene == "" then
    return nil
  end

  return utils.to_res_path(root, scene)
end

local function current_scene_arg()
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" or not file:match("%.tscn$") then
    return nil
  end

  return normalize_scene_arg(file)
end

local function telescope_modules()
  local ok, pickers = pcall(require, "telescope.pickers")
  local ok_finders, finders = pcall(require, "telescope.finders")
  local ok_config, telescope_config = pcall(require, "telescope.config")
  local ok_actions, actions = pcall(require, "telescope.actions")
  local ok_state, action_state = pcall(require, "telescope.actions.state")
  if not (ok and ok_finders and ok_config and ok_actions and ok_state) then
    return nil
  end

  return {
    pickers = pickers,
    finders = finders,
    config = telescope_config,
    actions = actions,
    action_state = action_state,
  }
end

local function project_scene_args()
  local root = utils.find_project_root()
  if not root then
    return nil
  end

  local matches = vim.fn.globpath(root, "**/*.tscn", false, true)
  local scenes = {}

  for _, path in ipairs(matches) do
    local normalized = normalize_scene_arg(path)
    if normalized then
      table.insert(scenes, normalized)
    end
  end

  table.sort(scenes)
  return scenes
end

local function scenes_for_script()
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" or not (file:match("%.gd$") or file:match("%.cs$")) then
    return nil
  end

  local script = normalize_scene_arg(file)
  local root = utils.find_project_root()
  if not script or not root then
    return nil
  end

  local matches = vim.fn.globpath(root, "**/*.tscn", false, true)
  local scenes = {}

  for _, path in ipairs(matches) do
    local lines = vim.fn.readfile(path)
    if table.concat(lines, "\n"):find(script, 1, true) then
      local normalized = normalize_scene_arg(path)
      if normalized then
        table.insert(scenes, normalized)
      end
    end
  end

  table.sort(scenes)
  return scenes
end

local function pick_scene_list(scenes, title)
  local telescope = telescope_modules()
  if not telescope then
    vim.notify("Telescope is required for scene selection", vim.log.levels.ERROR)
    return false
  end

  telescope.pickers
    .new({}, {
      prompt_title = title,
      finder = telescope.finders.new_table({
        results = scenes,
      }),
      sorter = telescope.config.values.generic_sorter({}),
      attach_mappings = function(prompt_bufnr)
        telescope.actions.select_default:replace(function()
          local selection = telescope.action_state.get_selected_entry()
          telescope.actions.close(prompt_bufnr)
          if selection and selection[1] then
            M.run_scene(selection[1])
          end
        end)
        return true
      end,
    })
    :find()

  return true
end

local function run_godot(args)
  local root = utils.find_project_root()
  if not root then
    vim.notify("project.godot not found", vim.log.levels.ERROR)
    return false
  end

  local executable = godot_executable()
  if vim.fn.executable(executable) ~= 1 then
    vim.notify(missing_godot_message(executable), vim.log.levels.ERROR)
    return false
  end

  local cmd = { executable, "--path", root }
  vim.list_extend(cmd, args or {})

  local run_console = require("godotdev.run_console")
  if run_console.is_enabled() then
    return run_console.start(cmd, root)
  end

  vim.system(cmd, { detach = true, text = true }, function(result)
    if result.code == 0 then
      return
    end

    vim.schedule(function()
      local stderr = vim.trim(result.stderr or "")
      vim.notify(stderr ~= "" and stderr or "Failed to start Godot", vim.log.levels.ERROR)
    end)
  end)

  return true
end

function M.run_project()
  return run_godot()
end

function M.run_current_scene()
  local scene = current_scene_arg()
  if scene then
    return run_godot({ scene })
  end

  local scenes = scenes_for_script()
  if scenes and #scenes == 1 then
    return run_godot({ scenes[1] })
  end

  if scenes and #scenes > 1 then
    return pick_scene_list(scenes, "Scenes using current script")
  end

  vim.notify(
    "Current buffer is not a .tscn scene or a .gd/.cs script attached to a scene in this Godot project",
    vim.log.levels.ERROR
  )
  return false
end

function M.run_scene(scene)
  local normalized = normalize_scene_arg(scene)
  if not normalized then
    vim.notify("Scene must be inside the current Godot project", vim.log.levels.ERROR)
    return false
  end

  return run_godot({ normalized })
end

function M.pick_scene()
  local root = utils.find_project_root()
  if not root then
    vim.notify("project.godot not found", vim.log.levels.ERROR)
    return false
  end

  local scenes = project_scene_args()
  if not scenes or #scenes == 0 then
    vim.notify("No .tscn scenes found in the current Godot project", vim.log.levels.WARN)
    return false
  end

  return pick_scene_list(scenes, "Godot Scenes")
end

function M.setup(opts)
  M.opts = vim.tbl_extend("force", M.opts, opts or {})

  if vim.fn.exists(":GodotRunProject") ~= 2 then
    vim.api.nvim_create_user_command("GodotRunProject", function()
      M.run_project()
    end, { desc = "Run the current Godot project" })
  end

  if vim.fn.exists(":GodotRunCurrentScene") ~= 2 then
    vim.api.nvim_create_user_command("GodotRunCurrentScene", function()
      M.run_current_scene()
    end, { desc = "Run the current Godot scene" })
  end

  if vim.fn.exists(":GodotRunScene") ~= 2 then
    vim.api.nvim_create_user_command("GodotRunScene", function(opts)
      M.run_scene(opts.args)
    end, {
      nargs = 1,
      complete = "file",
      desc = "Run a specific Godot scene",
    })
  end

  if vim.fn.exists(":GodotRunScenePicker") ~= 2 then
    vim.api.nvim_create_user_command("GodotRunScenePicker", function()
      M.pick_scene()
    end, {
      desc = "Pick and run a Godot scene using Telescope",
    })
  end
end

return M
