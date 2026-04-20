local M = {}

M.opts = {
  enabled = false,
  renderer = "buffer", -- "buffer" | "float"
  buffer = {
    position = "bottom", -- "right" | "bottom" | "current"
    size = 0.3,
  },
  float = {
    width = 0.8,
    height = 0.25,
    border = "rounded",
  },
}

local state = {
  buffer = nil,
  window = nil,
  process = nil,
  partial = {
    stdout = "",
    stderr = "",
  },
}

local function sanitize_size(size, fallback, max)
  if type(size) ~= "number" or size <= 0 then
    return fallback
  end

  return math.min(size, max)
end

local function set_window_options(win)
  if not win or not vim.api.nvim_win_is_valid(win) then
    return
  end

  vim.wo[win].wrap = false
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].cursorline = false
  vim.wo[win].winfixwidth = false
  vim.wo[win].winfixheight = false
end

local function ensure_buffer()
  local buf = state.buffer
  if buf and vim.api.nvim_buf_is_valid(buf) then
    return buf
  end

  for _, existing in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(existing) and vim.api.nvim_buf_get_name(existing) == "godotdev://console" then
      state.buffer = existing
      return existing
    end
  end

  buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false
  vim.bo[buf].buflisted = false
  vim.bo[buf].filetype = "log"
  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = false
  vim.api.nvim_buf_set_name(buf, "godotdev://console")
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, silent = true })

  state.buffer = buf
  return buf
end

local function open_buffer_window(buf)
  local buffer_config = M.opts.buffer or {}
  local position = buffer_config.position or "bottom"
  local size = sanitize_size(buffer_config.size, 0.3, 0.9)

  if position == "current" then
    vim.api.nvim_set_current_buf(buf)
    state.window = vim.api.nvim_get_current_win()
    set_window_options(state.window)
    return state.window
  end

  local width = math.max(math.floor(vim.o.columns * size), 40)
  local height = math.max(math.floor(vim.o.lines * size), 10)

  if position == "right" then
    vim.cmd(("botright %dvsplit"):format(width))
  else
    vim.cmd(("botright %dsplit"):format(height))
  end

  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)
  state.window = win
  set_window_options(win)
  return win
end

local function open_float_window(buf)
  local float = M.opts.float or {}
  local width_ratio = sanitize_size(float.width, 0.8, 1)
  local height_ratio = sanitize_size(float.height, 0.25, 1)
  local width = math.min(math.max(math.floor(vim.o.columns * width_ratio), 60), vim.o.columns)
  local height = math.min(math.max(math.floor(vim.o.lines * height_ratio), 10), vim.o.lines - 2)
  local row = math.max(math.floor((vim.o.lines - height) / 2 - 1), 0)
  local col = math.max(math.floor((vim.o.columns - width) / 2), 0)

  local win = state.window
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_set_buf(win, buf)
    vim.api.nvim_win_set_config(win, {
      relative = "editor",
      width = width,
      height = height,
      row = row,
      col = col,
      style = "minimal",
      border = float.border or "rounded",
      title = " Godot Console ",
      title_pos = "center",
    })
    state.window = win
    set_window_options(win)
    return win
  end

  win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = float.border or "rounded",
    title = " Godot Console ",
    title_pos = "center",
  })
  state.window = win
  set_window_options(win)
  return win
end

local function focus_or_open()
  local buf = ensure_buffer()
  local win = state.window

  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_set_current_win(win)
    if vim.api.nvim_win_get_buf(win) ~= buf then
      vim.api.nvim_win_set_buf(win, buf)
    end
    set_window_options(win)
    return buf, win
  end

  if M.opts.renderer == "float" then
    return buf, open_float_window(buf)
  end

  return buf, open_buffer_window(buf)
end

local function replace_buffer_lines(lines)
  local buf = ensure_buffer()
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false
end

local function append_lines(lines)
  if not lines or #lines == 0 then
    return
  end

  local buf = ensure_buffer()
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, -1, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false
end

local function flush_partial(stream)
  local pending = state.partial[stream]
  if pending == "" then
    return
  end

  state.partial[stream] = ""
  if stream == "stderr" then
    append_lines({ "[stderr] " .. pending })
    return
  end

  append_lines({ pending })
end

local function append_stream_chunk(stream, data)
  if not data or data == "" then
    return
  end

  local pending = state.partial[stream] .. data
  local complete = pending:sub(-1) == "\n"
  local lines = vim.split(pending, "\n", { plain = true })

  if complete then
    state.partial[stream] = ""
    if lines[#lines] == "" then
      table.remove(lines)
    end
  else
    state.partial[stream] = table.remove(lines) or ""
  end

  if stream == "stderr" then
    for i, line in ipairs(lines) do
      lines[i] = "[stderr] " .. line
    end
  end

  append_lines(lines)
end

function M.is_enabled()
  return M.opts.enabled == true
end

function M.show()
  local buf = state.buffer
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    vim.notify("godotdev.nvim: no Godot console output has been captured yet", vim.log.levels.INFO)
    return false
  end

  local _, win = focus_or_open()
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_set_cursor(win, { vim.api.nvim_buf_line_count(buf), 0 })
  end
  return true
end

function M.start(cmd, root)
  if state.process then
    vim.notify("godotdev.nvim: Godot console capture already has an active process", vim.log.levels.WARN)
    return false
  end

  local buf, win = focus_or_open()
  local header = {
    "# Godot Console",
    "",
    "Command: " .. table.concat(cmd, " "),
    "Project: " .. root,
    "",
  }
  replace_buffer_lines(header)
  state.partial.stdout = ""
  state.partial.stderr = ""

  local exited = false
  local ok, process_or_err = pcall(vim.system, cmd, {
    cwd = root,
    text = true,
    stdout = function(err, data)
      if err then
        vim.schedule(function()
          append_lines({ "[stdout error] " .. tostring(err) })
        end)
        return
      end

      vim.schedule(function()
        append_stream_chunk("stdout", data)
      end)
    end,
    stderr = function(err, data)
      if err then
        vim.schedule(function()
          append_lines({ "[stderr error] " .. tostring(err) })
        end)
        return
      end

      vim.schedule(function()
        append_stream_chunk("stderr", data)
      end)
    end,
  }, function(result)
    vim.schedule(function()
      flush_partial("stdout")
      flush_partial("stderr")
      append_lines({
        "",
        ("[Process exited] code=%d signal=%d"):format(result.code or 0, result.signal or 0),
      })
      exited = true
      state.process = nil
    end)
  end)

  if not ok then
    append_lines({ "[spawn error] " .. tostring(process_or_err) })
    return false
  end

  state.process = exited and nil or process_or_err
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_set_cursor(win, { vim.api.nvim_buf_line_count(buf), 0 })
  end
  return true
end

function M.setup(opts)
  M.opts = vim.tbl_deep_extend("force", M.opts, opts or {})

  if vim.fn.exists(":GodotShowConsole") ~= 2 then
    vim.api.nvim_create_user_command("GodotShowConsole", function()
      M.show()
    end, { desc = "Show the Godot run console buffer" })
  end
end

return M
