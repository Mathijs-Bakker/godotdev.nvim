local common = require("godotdev.docs.common")

local M = {}

local state = {
  docs_buffer = nil,
  docs_window = nil,
}

function M.reset()
  state.docs_buffer = nil
  state.docs_window = nil
end

local function render_docs_lines(title, text, source_url, page_url)
  local header = ("# %s\n\nSource: %s\nDocs: %s\n\n%s"):format(title, source_url, page_url, text)
  return vim.split(header, "\n", { plain = true })
end

function M.open_browser(url)
  local ok = vim.ui.open(url)
  if ok == false then
    vim.notify(("Failed to open browser for %s"):format(url), vim.log.levels.ERROR)
  end
end

function M.open_float(title, text, source_url, page_url)
  local config = common.get_config()
  local float = config.float or {}
  local width = math.min(math.max(math.floor(vim.o.columns * (float.width or 0.8)), 60), vim.o.columns)
  local height = math.min(math.max(math.floor(vim.o.lines * (float.height or 0.8)), 12), vim.o.lines - 2)
  local row = math.floor((vim.o.lines - height) / 2 - 1)
  local col = math.floor((vim.o.columns - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  local lines = render_docs_lines(title, text, source_url, page_url)

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].modifiable = false

  vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = math.max(width, 60),
    height = math.max(height, 12),
    row = math.max(row, 0),
    col = math.max(col, 0),
    style = "minimal",
    border = float.border or "rounded",
    title = (" Godot Docs: %s "):format(title),
    title_pos = "center",
  })

  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, silent = true })
end

local function sanitize_buffer_size(size)
  if type(size) ~= "number" or size <= 0 then
    return 0.4
  end

  return math.min(size, 0.9)
end

local function ensure_docs_buffer()
  local buf = state.docs_buffer
  if buf and vim.api.nvim_buf_is_valid(buf) then
    return buf
  end

  buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].modifiable = false
  vim.bo[buf].buflisted = false
  vim.api.nvim_buf_set_name(buf, "godotdev://docs")
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, silent = true })

  state.docs_buffer = buf
  return buf
end

local function open_buffer_window(buf)
  local config = common.get_config()
  local buffer_config = config.buffer or {}
  local position = buffer_config.position or "right"
  local size = sanitize_buffer_size(buffer_config.size)

  if position == "current" then
    vim.api.nvim_set_current_buf(buf)
    state.docs_window = vim.api.nvim_get_current_win()
    return state.docs_window
  end

  local width = math.max(math.floor(vim.o.columns * size), 40)
  local height = math.max(math.floor(vim.o.lines * size), 10)

  if position == "bottom" then
    vim.cmd(("botright %dsplit"):format(height))
  else
    vim.cmd(("botright %dvsplit"):format(width))
  end

  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)
  state.docs_window = win
  return win
end

local function focus_or_open_docs_buffer()
  local buf = ensure_docs_buffer()
  local win = state.docs_window

  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_set_current_win(win)
    if vim.api.nvim_win_get_buf(win) ~= buf then
      vim.api.nvim_win_set_buf(win, buf)
    end
    return buf, win
  end

  return buf, open_buffer_window(buf)
end

function M.open_buffer(title, text, source_url, page_url)
  local buf, win = focus_or_open_docs_buffer()
  local lines = render_docs_lines(title, text, source_url, page_url)

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false
  vim.api.nvim_buf_set_name(buf, ("godotdev://docs/%s"):format(common.class_slug(title)))
  vim.bo[buf].readonly = false

  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_set_cursor(win, { 1, 0 })
    vim.wo[win].wrap = true
    vim.wo[win].number = false
    vim.wo[win].relativenumber = false
    vim.wo[win].signcolumn = "no"
    vim.wo[win].cursorline = false
    vim.wo[win].winfixwidth = false
    vim.wo[win].winfixheight = false
  end
end

return M
