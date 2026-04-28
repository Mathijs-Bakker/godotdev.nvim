local M = {}

local state = {
  buffer = nil,
  window = nil,
  source_window = nil,
  source_path = nil,
  project_root = nil,
  scene = nil,
  lines = {},
  nodes_by_line = {},
}

local function sanitize_size(size)
  if type(size) ~= "number" or size <= 0 then
    return 0.35
  end

  return math.min(size, 0.9)
end

local function find_project_root()
  local file = vim.api.nvim_buf_get_name(0)
  local start_path = file ~= "" and vim.fs.dirname(file) or vim.uv.cwd()
  local project_file = vim.fs.find("project.godot", {
    upward = true,
    path = start_path,
  })[1]

  if not project_file then
    return nil
  end

  return vim.fs.dirname(project_file)
end

local function normalize_res_path(path)
  local root = find_project_root()
  if not root or type(path) ~= "string" or path == "" then
    return nil
  end

  if path:match("^res://") then
    return path
  end

  local absolute = path
  if not path:match("^/") then
    absolute = root .. "/" .. path
  end

  absolute = vim.fs.normalize(absolute)
  root = vim.fs.normalize(root)

  if absolute ~= root and absolute:sub(1, #root + 1) ~= root .. "/" then
    return nil
  end

  return "res://" .. absolute:sub(#root + 2)
end

local function res_to_absolute(path)
  local root = state.project_root or find_project_root()
  if not root or type(path) ~= "string" or not path:match("^res://") then
    return nil
  end

  return vim.fs.normalize(root .. "/" .. path:sub(7))
end

local function current_scene_from_buffer()
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" or not file:match("%.tscn$") then
    return nil
  end

  return normalize_res_path(file)
end

local function scenes_for_script()
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" or not (file:match("%.gd$") or file:match("%.cs$")) then
    return nil
  end

  local script = normalize_res_path(file)
  local root = find_project_root()
  if not script or not root then
    return nil
  end

  local matches = vim.fn.globpath(root, "**/*.tscn", false, true)
  local scenes = {}

  for _, path in ipairs(matches) do
    local lines = vim.fn.readfile(path)
    if table.concat(lines, "\n"):find(script, 1, true) then
      local normalized = normalize_res_path(path)
      if normalized then
        table.insert(scenes, normalized)
      end
    end
  end

  table.sort(scenes)
  return scenes
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

local function pick_scene_list(scenes, title, on_select)
  local telescope = telescope_modules()
  if not telescope then
    vim.notify("Telescope is required for scene selection", vim.log.levels.ERROR)
    return false
  end

  telescope.pickers.new({}, {
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
          on_select(selection[1])
        end
      end)
      return true
    end,
  }):find()

  return true
end

local function resolve_scene(scene)
  if scene and scene ~= "" then
    return normalize_res_path(scene)
  end

  local current_scene = current_scene_from_buffer()
  if current_scene then
    return current_scene
  end

  local scenes = scenes_for_script()
  if scenes and #scenes == 1 then
    return scenes[1]
  end

  if scenes and #scenes > 1 then
    return scenes
  end

  return nil
end

local function parse_attributes(header)
  local attrs = {}

  for key, value in header:gmatch('([%w_]+)%s*=%s*"([^"]*)"') do
    attrs[key] = value
  end

  for key, value in header:gmatch('([%w_]+)%s*=%s*([^%s"%]]+)') do
    if attrs[key] == nil then
      attrs[key] = value
    end
  end

  return attrs
end

local function parse_scene(lines)
  local ext_resources = {}
  local nodes = {}
  local current_node = nil
  local root_name = nil

  local function finish_node()
    if not current_node then
      return
    end

    table.insert(nodes, current_node)
    current_node = nil
  end

  for index, line in ipairs(lines) do
    local ext_header = line:match("^%[ext_resource%s+(.+)%]$")
    if ext_header then
      local attrs = parse_attributes(ext_header)
      if attrs.id and attrs.path then
        ext_resources[attrs.id] = attrs.path
      end
    end

    local node_header = line:match("^%[node%s+(.+)%]$")
    if node_header then
      finish_node()

      local attrs = parse_attributes(node_header)
      if not root_name then
        root_name = attrs.name
      end

      local parent_rel = attrs.parent
      local node_path = "."
      local depth = 0

      if parent_rel and parent_rel ~= "" then
        if parent_rel == "." then
          depth = 1
          node_path = attrs.name or "."
        else
          depth = select(2, parent_rel:gsub("/", "/")) + 2
          node_path = parent_rel .. "/" .. (attrs.name or "")
        end
      elseif attrs.name and attrs.name ~= "" then
        node_path = "."
      end

      current_node = {
        name = attrs.name or "",
        type = attrs.type or attrs.instance or "Node",
        parent = parent_rel,
        path = node_path,
        depth = depth,
        line = index,
        script = nil,
      }
    elseif current_node then
      local ext_id = line:match('^script%s*=%s*ExtResource%("([^"]+)"%)')
      if ext_id and ext_resources[ext_id] then
        current_node.script = ext_resources[ext_id]
      end
    end
  end

  finish_node()

  return {
    root_name = root_name,
    nodes = nodes,
  }
end

local function format_tree(parsed)
  local lines = {}
  local nodes_by_line = {}

  for _, node in ipairs(parsed.nodes) do
    local indent = string.rep("  ", node.depth)
    local label = ("%s%s [%s]"):format(indent, node.name ~= "" and node.name or "<unnamed>", node.type)
    if node.script then
      label = label .. " *"
    end
    table.insert(lines, label)
    nodes_by_line[#lines] = node
  end

  if #lines == 0 then
    lines = { "No [node ...] sections found in this scene." }
  end

  return lines, nodes_by_line
end

local function ensure_buffer()
  local buf = state.buffer
  if buf and vim.api.nvim_buf_is_valid(buf) then
    return buf
  end

  buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false
  vim.bo[buf].buflisted = false
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = "godotscene"

  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, silent = true })
  vim.keymap.set("n", "<CR>", function()
    M.jump_to_node()
  end, { buffer = buf, silent = true, desc = "Jump to scene node" })
  vim.keymap.set("n", "p", function()
    M.copy_node_path()
  end, { buffer = buf, silent = true, desc = "Copy node path" })
  vim.keymap.set("n", "g", function()
    M.jump_to_script()
  end, { buffer = buf, silent = true, desc = "Jump to attached script" })
  vim.keymap.set("n", "r", function()
    M.refresh()
  end, { buffer = buf, silent = true, desc = "Refresh scene tree" })

  state.buffer = buf
  return buf
end

local function open_window(buf)
  local config = require("godotdev").opts.scene_tree or {}
  local buffer_config = config.buffer or {}
  local position = buffer_config.position or "right"
  local size = sanitize_size(buffer_config.size)

  if position == "current" then
    vim.api.nvim_set_current_buf(buf)
    state.window = vim.api.nvim_get_current_win()
    return state.window
  end

  local width = math.max(math.floor(vim.o.columns * size), 30)
  local height = math.max(math.floor(vim.o.lines * size), 10)

  if position == "bottom" then
    vim.cmd(("botright %dsplit"):format(height))
  else
    vim.cmd(("botright %dvsplit"):format(width))
  end

  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)
  state.window = win
  return win
end

local function focus_or_open_buffer()
  local buf = ensure_buffer()
  local win = state.window

  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_set_current_win(win)
    if vim.api.nvim_win_get_buf(win) ~= buf then
      vim.api.nvim_win_set_buf(win, buf)
    end
    return buf, win
  end

  return buf, open_window(buf)
end

local function set_window_options(win)
  if not win or not vim.api.nvim_win_is_valid(win) then
    return
  end

  vim.wo[win].wrap = false
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].cursorline = true
  vim.wo[win].winfixwidth = false
  vim.wo[win].winfixheight = false
end

local function update_buffer(scene, absolute_path, parsed)
  local buf, win = focus_or_open_buffer()
  local lines, nodes_by_line = format_tree(parsed)

  state.scene = scene
  state.source_path = absolute_path
  state.project_root = vim.fs.dirname(vim.fs.find("project.godot", {
    upward = true,
    path = vim.fs.dirname(absolute_path),
  })[1] or "")
  state.lines = lines
  state.nodes_by_line = nodes_by_line

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false
  vim.api.nvim_buf_set_name(buf, ("godotdev://scene-tree/%s"):format(scene:gsub("^res://", "")))

  vim.b[buf].godotdev_scene_tree_source = absolute_path
  vim.b[buf].godotdev_scene_tree_scene = scene
  vim.b[buf].godotdev_scene_tree_nodes = nodes_by_line

  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_set_cursor(win, { 1, 0 })
    set_window_options(win)
  end
end

local function current_node()
  local buf = state.buffer
  if not buf or vim.api.nvim_get_current_buf() ~= buf then
    return nil
  end

  local line = vim.api.nvim_win_get_cursor(0)[1]
  return state.nodes_by_line[line]
end

function M.open(scene)
  local resolved = resolve_scene(scene)
  if type(resolved) == "table" then
    return pick_scene_list(resolved, "Scenes using current script", function(choice)
      M.open(choice)
    end)
  end

  if not resolved then
    vim.notify(
      "Current buffer is not a .tscn scene or a .gd/.cs script attached to a scene in this Godot project",
      vim.log.levels.ERROR
    )
    return false
  end

  local absolute = res_to_absolute(resolved)
  if not absolute or vim.fn.filereadable(absolute) ~= 1 then
    vim.notify(("Scene not found: %s"):format(resolved), vim.log.levels.ERROR)
    return false
  end

  local parsed = parse_scene(vim.fn.readfile(absolute))
  update_buffer(resolved, absolute, parsed)
  return true
end

function M.refresh()
  if not state.scene then
    return M.open(nil)
  end

  return M.open(state.scene)
end

function M.jump_to_node()
  local node = current_node()
  if not node or not state.source_path then
    return false
  end

  if state.source_window and vim.api.nvim_win_is_valid(state.source_window) then
    vim.api.nvim_set_current_win(state.source_window)
    vim.cmd(("edit %s"):format(vim.fn.fnameescape(state.source_path)))
  else
    vim.cmd(("edit %s"):format(vim.fn.fnameescape(state.source_path)))
  end

  vim.api.nvim_win_set_cursor(0, { node.line, 0 })
  return true
end

function M.copy_node_path()
  local node = current_node()
  if not node then
    return false
  end

  vim.fn.setreg('"', node.path)
  pcall(vim.fn.setreg, "+", node.path)
  vim.notify(("Copied node path: %s"):format(node.path), vim.log.levels.INFO)
  return true
end

function M.jump_to_script()
  local node = current_node()
  if not node then
    return false
  end

  if not node.script then
    vim.notify("Selected node has no attached script", vim.log.levels.WARN)
    return false
  end

  local absolute = res_to_absolute(node.script)
  if not absolute then
    vim.notify(("Script not found: %s"):format(node.script), vim.log.levels.ERROR)
    return false
  end

  vim.cmd(("edit %s"):format(vim.fn.fnameescape(absolute)))
  return true
end

function M.setup()
  if vim.fn.exists(":GodotSceneTree") ~= 2 then
    vim.api.nvim_create_user_command("GodotSceneTree", function(opts)
      state.source_window = vim.api.nvim_get_current_win()
      M.open(opts.args ~= "" and opts.args or nil)
    end, {
      nargs = "?",
      complete = "file",
      desc = "Open a static scene tree for a Godot .tscn scene",
    })
  end

  if vim.fn.exists(":GodotSceneTreeRefresh") ~= 2 then
    vim.api.nvim_create_user_command("GodotSceneTreeRefresh", function()
      M.refresh()
    end, {
      desc = "Refresh the Godot scene tree pane",
    })
  end
end

M._parse_scene = parse_scene
M._resolve_scene = resolve_scene
M._state = state

return M
