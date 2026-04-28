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
  icon_spans = {},
}

local namespace = vim.api.nvim_create_namespace("godotdev.scene_tree")

local default_icons = {
  generic = "󰀘",
  script_suffix = " *",
  types = {
    Node = "󰀘",
    Node2D = "󰔷",
    Node3D = "󰆧",
    CanvasLayer = "󰧨",
    Area2D = "󰯈",
    Area3D = "󰯈",
    Camera2D = "󰹑",
    Camera3D = "󰹑",
    CharacterBody2D = "󰆿",
    CharacterBody3D = "󰆿",
    StaticBody2D = "󰜌",
    StaticBody3D = "󰜌",
    RigidBody2D = "󰔡",
    RigidBody3D = "󰔡",
    CollisionShape2D = "󰛢",
    CollisionShape3D = "󰛢",
    Sprite2D = "󰈟",
    AnimatedSprite2D = "󰵉",
    TileMap = "󰝰",
    TileMapLayer = "󰝰",
    Label = "󰉿",
    RichTextLabel = "󰉿",
    Button = "󰌌",
    TextureButton = "󰌌",
    Control = "󰖯",
    Panel = "󰕫",
    MarginContainer = "󰅩",
    VBoxContainer = "󰉸",
    HBoxContainer = "󰉹",
    AudioStreamPlayer = "󰎈",
    AudioStreamPlayer2D = "󰎈",
    AudioStreamPlayer3D = "󰎈",
    GPUParticles2D = "󰖐",
    GPUParticles3D = "󰖐",
    CPUParticles2D = "󰖐",
    CPUParticles3D = "󰖐",
    Light2D = "󰌵",
    DirectionalLight2D = "󰌵",
    DirectionalLight3D = "󰌵",
    OmniLight3D = "󰌵",
    SpotLight3D = "󰌵",
    Marker2D = "󰍎",
    Marker3D = "󰍎",
  },
}

local ascii_icons = {
  generic = ">",
  script_suffix = " *",
  types = {},
}

local default_highlights = {
  generic = "Directory",
  groups = {
    Node = "Directory",
    Node2D = "Function",
    Node3D = "Type",
    Control = "Special",
    Camera = "Identifier",
    Physics = "Conditional",
    Collision = "DiagnosticWarn",
    Visual = "String",
    Tile = "Number",
    Audio = "Constant",
    Light = "DiagnosticInfo",
    Marker = "Label",
  },
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

local function get_config()
  return require("godotdev").opts.scene_tree or {}
end

local function merged_icons()
  local config = get_config()
  local icons = config.icons

  if icons == false then
    return nil
  end

  local base = default_icons
  if icons == "ascii" then
    base = ascii_icons
  elseif type(icons) == "table" and icons.style == "ascii" then
    base = ascii_icons
  end

  if type(icons) == "table" then
    local merged = vim.tbl_deep_extend("force", vim.deepcopy(base), icons)
    if icons.generic ~= nil then
      merged.generic = icons.generic
    end
    if icons.script_suffix ~= nil then
      merged.script_suffix = icons.script_suffix
    end
    return merged
  end

  return vim.deepcopy(base)
end

local function merged_highlights()
  local config = get_config()
  local colors = config.icon_colors

  if colors == false then
    return nil
  end

  local merged = vim.deepcopy(default_highlights)

  if type(colors) == "table" then
    merged = vim.tbl_deep_extend("force", merged, colors)
    if colors.generic ~= nil then
      merged.generic = colors.generic
    end
  end

  return merged
end

local function icon_for_node(node, icons)
  if not icons then
    return nil
  end

  local icon = icons.types and icons.types[node.type] or nil
  if icon then
    return icon
  end

  if node.type:match("2D$") and icons.types and icons.types.Node2D then
    return icons.types.Node2D
  end

  if node.type:match("3D$") and icons.types and icons.types.Node3D then
    return icons.types.Node3D
  end

  if node.type:match("Container$") and icons.types and icons.types.Control then
    return icons.types.Control
  end

  if node.type:match("Label$") and icons.types and icons.types.Label then
    return icons.types.Label
  end

  if node.type:match("Button$") and icons.types and icons.types.Button then
    return icons.types.Button
  end

  return icons.generic
end

local function highlight_for_node(node, highlights)
  if not highlights then
    return nil
  end

  local groups = highlights.groups or {}

  if groups[node.type] then
    return groups[node.type]
  end

  if node.type:match("Camera") then
    return groups.Camera or highlights.generic
  end

  if node.type:match("Body") or node.type:match("^Area") then
    return groups.Physics or highlights.generic
  end

  if node.type:match("^Collision") then
    return groups.Collision or highlights.generic
  end

  if node.type:match("Sprite") or node.type:match("Animated") then
    return groups.Visual or highlights.generic
  end

  if node.type:match("^Tile") then
    return groups.Tile or highlights.generic
  end

  if node.type:match("^Audio") then
    return groups.Audio or highlights.generic
  end

  if node.type:match("Light") then
    return groups.Light or highlights.generic
  end

  if node.type:match("^Marker") then
    return groups.Marker or highlights.generic
  end

  if node.type:match("Container$") or node.type:match("^Panel") or node.type:match("^Label") or node.type:match("Button$") then
    return groups.Control or highlights.generic
  end

  if node.type:match("2D$") then
    return groups.Node2D or highlights.generic
  end

  if node.type:match("3D$") then
    return groups.Node3D or highlights.generic
  end

  return groups.Node or highlights.generic
end

local function format_tree(parsed)
  local lines = {}
  local nodes_by_line = {}
  local icon_spans = {}
  local icons = merged_icons()
  local highlights = merged_highlights()

  for _, node in ipairs(parsed.nodes) do
    local indent = string.rep("  ", node.depth)
    local icon = icon_for_node(node, icons)
    local prefix = icon and (icon .. " ") or ""
    local label = ("%s%s%s [%s]"):format(indent, prefix, node.name ~= "" and node.name or "<unnamed>", node.type)
    if node.script then
      label = label .. ((icons and icons.script_suffix) or " *")
    end
    table.insert(lines, label)
    nodes_by_line[#lines] = node

    if icon then
      table.insert(icon_spans, {
        line = #lines - 1,
        col_start = #indent,
        col_end = #indent + #icon,
        group = highlight_for_node(node, highlights),
      })
    end
  end

  if #lines == 0 then
    lines = { "No [node ...] sections found in this scene." }
  end

  return lines, nodes_by_line, icon_spans
end

local function apply_icon_highlights(buf, icon_spans)
  vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)

  for _, span in ipairs(icon_spans or {}) do
    if span.group then
      vim.api.nvim_buf_add_highlight(buf, namespace, span.group, span.line, span.col_start, span.col_end)
    end
  end
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
  local lines, nodes_by_line, icon_spans = format_tree(parsed)

  state.scene = scene
  state.source_path = absolute_path
  state.project_root = vim.fs.dirname(vim.fs.find("project.godot", {
    upward = true,
    path = vim.fs.dirname(absolute_path),
  })[1] or "")
  state.lines = lines
  state.nodes_by_line = nodes_by_line
  state.icon_spans = icon_spans

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false
  vim.api.nvim_buf_set_name(buf, ("godotdev://scene-tree/%s"):format(scene:gsub("^res://", "")))
  apply_icon_highlights(buf, icon_spans)

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
M._format_tree = function(parsed)
  local lines, _, icon_spans = format_tree(parsed)
  return lines, icon_spans
end
M._resolve_scene = resolve_scene
M._state = state

return M
