local M = {}

local state = {
  index_cache = nil,
  doc_url_cache = {},
  rst_cache = {},
  markdown_cache = {},
  docs_buffer = nil,
  docs_window = nil,
}

local heading_levels = {
  ["="] = "#",
  ["-"] = "##",
  ["~"] = "###",
  ["^"] = "####",
  ['"'] = "#####",
}

local function codepoint_to_char(codepoint)
  if vim.fn.has("nvim-0.11") == 1 then
    return vim.fn.nr2char(codepoint)
  end

  local ok, utf8_lib = pcall(require, "utf8")
  if ok and utf8_lib and utf8_lib.char then
    return utf8_lib.char(codepoint)
  end

  if codepoint < 128 then
    return string.char(codepoint)
  end

  return ""
end

local function get_config()
  local ok, godotdev = pcall(require, "godotdev")
  if not ok then
    return {}
  end

  return godotdev.opts.docs or {}
end

local function show_feedback(message)
  local config = get_config()
  local mode = config.missing_symbol_feedback or "message"

  if mode == "notify" then
    vim.notify(message, vim.log.levels.WARN)
    return
  end

  vim.api.nvim_echo({ { message, "WarningMsg" } }, false, {})
end

local function trim(text)
  local trimmed = (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
  return trimmed
end

local function decode_html_entities(text)
  local entities = {
    ["&nbsp;"] = " ",
    ["&amp;"] = "&",
    ["&lt;"] = "<",
    ["&gt;"] = ">",
    ["&quot;"] = '"',
    ["&#39;"] = "'",
    ["&apos;"] = "'",
    ["&ndash;"] = "-",
    ["&mdash;"] = "-",
    ["&hellip;"] = "...",
    ["&para;"] = "",
  }

  for entity, value in pairs(entities) do
    text = text:gsub(entity, value)
  end

  text = text:gsub("&#(%d+);", function(num)
    return codepoint_to_char(tonumber(num))
  end)

  text = text:gsub("&#x([%da-fA-F]+);", function(num)
    return codepoint_to_char(tonumber(num, 16))
  end)

  return text
end

local function build_base_url()
  local config = get_config()
  local language = config.language or "en"
  local version = config.version or "stable"

  if config.base_url and config.base_url ~= "" then
    return config.base_url:gsub("/$", "")
  end

  return ("https://docs.godotengine.org/%s/%s"):format(language, version)
end

local function build_docs_source_base_url()
  local config = get_config()

  if config.source_base_url and config.source_base_url ~= "" then
    return config.source_base_url:gsub("/$", "")
  end

  local ref = config.source_ref or "master"
  return ("https://raw.githubusercontent.com/godotengine/godot-docs/%s"):format(ref)
end

local function is_cache_enabled()
  local config = get_config()
  if config.cache == nil then
    return true
  end

  if type(config.cache) == "boolean" then
    return config.cache
  end

  return config.cache.enabled ~= false
end

local function cache_max_entries()
  local config = get_config()
  local cache = config.cache
  if type(cache) == "table" and type(cache.max_entries) == "number" and cache.max_entries > 0 then
    return math.floor(cache.max_entries)
  end
  return 64
end

local function cache_key(parts)
  return table.concat(parts, "::")
end

local function cache_get(bucket, key)
  if not is_cache_enabled() then
    return nil
  end

  local entry = bucket[key]
  if not entry then
    return nil
  end

  entry.last_used = vim.loop.hrtime()
  return entry.value
end

local function cache_put(bucket, key, value)
  if not is_cache_enabled() then
    return value
  end

  bucket[key] = {
    value = value,
    last_used = vim.loop.hrtime(),
  }

  local max_entries = cache_max_entries()
  local count = 0
  local oldest_key
  local oldest_time

  for existing_key, entry in pairs(bucket) do
    count = count + 1
    if not oldest_time or entry.last_used < oldest_time then
      oldest_time = entry.last_used
      oldest_key = existing_key
    end
  end

  if count > max_entries and oldest_key then
    bucket[oldest_key] = nil
  end

  return value
end

local function class_slug(symbol)
  return symbol:lower():gsub("%s+", "")
end

local function page_url_from_symbol(symbol)
  return ("%s/classes/class_%s.html"):format(build_base_url(), class_slug(symbol))
end

local function rst_url_from_symbol(symbol)
  return ("%s/classes/class_%s.rst"):format(build_docs_source_base_url(), class_slug(symbol))
end

local function extract_symbol(input)
  local symbol = trim(input)
  if symbol == "" then
    symbol = trim(vim.fn.expand("<cword>"))
  end

  return symbol
end

local function shell_argv(url)
  local config = get_config()
  local timeout = tostring(config.timeout_ms or 10000)

  return { "curl", "-fsSL", "--max-time", timeout, url }
end

local function fetch_url(url, on_success, on_error)
  if vim.fn.executable("curl") ~= 1 then
    on_error("`curl` is required to render Godot docs in Neovim.")
    return
  end

  vim.system(shell_argv(url), { text = true }, function(result)
    vim.schedule(function()
      if result.code == 0 and result.stdout and result.stdout ~= "" then
        on_success(result.stdout)
      else
        local stderr = trim(result.stderr or "")
        on_error(stderr ~= "" and stderr or ("Failed to fetch %s"):format(url))
      end
    end)
  end)
end

local function fetch_text(url, bucket, key, on_success, on_error)
  local cached = cache_get(bucket, key)
  if cached ~= nil then
    on_success(cached)
    return
  end

  fetch_url(url, function(text)
    on_success(cache_put(bucket, key, text))
  end, on_error)
end

local function parse_index(html)
  local items = {}

  for href, label in html:gmatch('<a[^>]-href="([^"]-class_[^"]-%.html)"[^>]->(.-)</a>') do
    local name = trim(decode_html_entities(label:gsub("<[^>]->", "")))
    if name ~= "" then
      items[name:lower()] = href
    end
  end

  return items
end

local function fetch_index(callback)
  if state.index_cache then
    callback(state.index_cache)
    return
  end

  local index_url = ("%s/classes/index.html"):format(build_base_url())
  fetch_url(index_url, function(html)
    state.index_cache = parse_index(html)
    callback(state.index_cache)
  end, function(_)
    callback({})
  end)
end

local function resolve_doc_url(symbol, callback)
  local key = cache_key({ build_base_url(), symbol:lower() })
  local cached = cache_get(state.doc_url_cache, key)
  if cached ~= nil then
    callback(cached.url, cached.html)
    return
  end

  local direct_url = page_url_from_symbol(symbol)

  fetch_text(direct_url, state.rst_cache, cache_key({ "page-html", direct_url }), function(html)
    cache_put(state.doc_url_cache, key, { url = direct_url, html = html })
    callback(direct_url, html)
  end, function(_)
    fetch_index(function(index)
      local href = index[symbol:lower()]
      if not href then
        callback(nil, nil)
        return
      end

      local resolved_url = href:match("^https?://") and href or (build_base_url() .. "/" .. href:gsub("^/", ""))
      fetch_text(resolved_url, state.rst_cache, cache_key({ "page-html", resolved_url }), function(html)
        cache_put(state.doc_url_cache, key, { url = resolved_url, html = html })
        callback(resolved_url, html)
      end, function(_)
        callback(nil, nil)
      end)
    end)
  end)
end

local function normalize_whitespace(text)
  text = text:gsub("\r\n", "\n")
  text = text:gsub("[ \t]+\n", "\n")
  text = text:gsub("\n[ \t]+", "\n")
  text = text:gsub("\n\n\n+", "\n\n")
  return trim(text)
end

local function normalize_inline_rst(text)
  if text == "" then
    return ""
  end

  if
    not text:find("\\ ", 1, true)
    and not text:find("|", 1, true)
    and not text:find("`", 1, true)
    and not text:find(":", 1, true)
  then
    return trim(text)
  end

  text = text:gsub("\\ ", "")
  text = text:gsub("|bitfield|", "BitField")
  text = text:gsub("|const|", "const")
  text = text:gsub("|virtual|", "virtual")
  text = text:gsub("|vararg|", "vararg")
  text = text:gsub("|static|", "static")
  text = text:gsub("|operator|", "operator")
  text = text:gsub("``([^`]+)``", "`%1`")
  text = text:gsub(":ref:`([^`<]+)%s*<[^`>]+>`", "`%1`")
  text = text:gsub(":ref:`([^`]+)`", "`%1`")
  text = text:gsub(":doc:`([^`<]+)%s*<[^`>]+>`", "%1")
  text = text:gsub(":doc:`([^`]+)`", "%1")
  text = text:gsub(":abbr:`([^`<]+)%s*%(([^`]+)%)`", "%1 (%2)")
  text = text:gsub(":abbr:`([^`]+)`", "%1")
  text = text:gsub(":code:`([^`]+)`", "`%1`")
  text = text:gsub(":kbd:`([^`]+)`", "`%1`")
  text = text:gsub(":math:`([^`]+)`", "`%1`")
  text = text:gsub(":literal:`([^`]+)`", "`%1`")
  text = text:gsub("`([^`]+)`__", "%1")
  text = text:gsub("__%s*%.%.?$", "")
  return trim(text)
end

local function is_admonition(line)
  return line:match("^%.%. note::")
    or line:match("^%.%. warning::")
    or line:match("^%.%. tip::")
    or line:match("^%.%. important::")
    or line:match("^%.%. deprecated::")
end

local function consume_paragraph(lines, index)
  local paragraph = {}
  local i = index

  while i <= #lines do
    local line = lines[i]
    local next_line = lines[i + 1]

    if line == "" or line:match("^%s+$") then
      break
    end

    if line:match("^%.%. ") or line:match("^%+") or line:match("^%- ") then
      break
    end

    if next_line and next_line:match('^([=~%^"%-])%1+$') and #trim(line) > 0 then
      break
    end

    table.insert(paragraph, normalize_inline_rst(trim(line)))
    i = i + 1
  end

  return table.concat(paragraph, " "), i
end

local function split_table_row(line)
  local row = {}
  local inner = line:sub(2, -2)

  for cell in (inner .. "|"):gmatch("(.-)|") do
    table.insert(row, normalize_inline_rst(trim(cell)))
  end

  return row
end

local function format_markdown_table(rows)
  if #rows == 0 then
    return {}
  end

  local columns = 0
  for _, row in ipairs(rows) do
    columns = math.max(columns, #row)
  end

  for _, row in ipairs(rows) do
    while #row < columns do
      table.insert(row, "")
    end
  end

  local header = rows[1]
  local separator = {}
  local markdown = {
    "| " .. table.concat(header, " | ") .. " |",
  }

  for _ = 1, columns do
    table.insert(separator, "---")
  end
  table.insert(markdown, "| " .. table.concat(separator, " | ") .. " |")

  for i = 2, #rows do
    table.insert(markdown, "| " .. table.concat(rows[i], " | ") .. " |")
  end

  return markdown
end

local function consume_grid_table(lines, index)
  local rows = {}
  local i = index

  while i <= #lines do
    local line = lines[i]
    if not line:match("^%+") and not line:match("^|") then
      break
    end

    if line:match("^|") then
      table.insert(rows, split_table_row(line))
    end

    i = i + 1
  end

  return format_markdown_table(rows), i
end

local function consume_indented_block(lines, index, indent)
  local block = {}
  local i = index

  while i <= #lines do
    local line = lines[i]
    if line == "" then
      table.insert(block, "")
      i = i + 1
    elseif line:match("^" .. indent .. "%S") then
      table.insert(block, line:gsub("^" .. indent, "", 1))
      i = i + 1
    else
      break
    end
  end

  return block, i
end

local function append_lines(output, lines_to_add)
  for _, line in ipairs(lines_to_add) do
    table.insert(output, line)
  end
end

local function rst_to_markdown(rst)
  local lines = vim.split(rst:gsub("\r\n", "\n"), "\n", { plain = true })
  local output = {}
  local i = 1

  while i <= #lines do
    local line = lines[i]
    local next_line = lines[i + 1]
    local trimmed = trim(line)

    if next_line and next_line:match('^([=~%^"%-])%1+$') and #trimmed > 0 then
      local marker = next_line:sub(1, 1)
      local heading = heading_levels[marker] or "##"
      table.insert(output, ("%s %s"):format(heading, normalize_inline_rst(trimmed)))
      table.insert(output, "")
      i = i + 2
    elseif line:match("^%.%. _") then
      i = i + 1
    elseif line:match("^%.%. rst%-class::") then
      i = i + 1
    elseif line:match("^%.%. code%-block::") then
      local language = trim(line:match("^%.%. code%-block::%s*(.*)$") or "")
      local block, next_index = consume_indented_block(lines, i + 1, "   ")
      table.insert(output, "```" .. language)
      append_lines(output, block)
      table.insert(output, "```")
      table.insert(output, "")
      i = next_index
    elseif is_admonition(line) then
      local kind = line:match("^%.%.%s+([%a_]+)::"):upper()
      local block, next_index = consume_indented_block(lines, i + 1, "   ")
      local markdown_block = { ("> [!%s]"):format(kind) }
      for _, block_line in ipairs(block) do
        if block_line == "" then
          table.insert(markdown_block, ">")
        else
          table.insert(markdown_block, "> " .. normalize_inline_rst(block_line))
        end
      end
      append_lines(output, markdown_block)
      table.insert(output, "")
      i = next_index
    elseif line:match("^%.%. ") then
      i = i + 1
    elseif line:match("^%+") then
      local markdown_table, next_index = consume_grid_table(lines, i)
      append_lines(output, markdown_table)
      table.insert(output, "")
      i = next_index
    elseif line:match("^%- ") then
      table.insert(output, "- " .. normalize_inline_rst(trim(line:sub(3))))
      i = i + 1
    elseif line:match("^%s+$") or line == "" then
      table.insert(output, "")
      i = i + 1
    else
      local paragraph, next_index = consume_paragraph(lines, i)
      if paragraph ~= "" then
        table.insert(output, paragraph)
        table.insert(output, "")
      end
      i = next_index
    end
  end

  return normalize_whitespace(table.concat(output, "\n"))
end

local function open_in_float(title, text, source_url, page_url)
  local config = get_config()
  local float = config.float or {}
  local width = math.min(math.max(math.floor(vim.o.columns * (float.width or 0.8)), 60), vim.o.columns)
  local height = math.min(math.max(math.floor(vim.o.lines * (float.height or 0.8)), 12), vim.o.lines - 2)
  local row = math.floor((vim.o.lines - height) / 2 - 1)
  local col = math.floor((vim.o.columns - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  local header = ("# %s\n\nSource: %s\nDocs: %s\n\n%s"):format(title, source_url, page_url, text)
  local lines = vim.split(header, "\n", { plain = true })

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
  local config = get_config()
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

local function render_docs_lines(title, text, source_url, page_url)
  local header = ("# %s\n\nSource: %s\nDocs: %s\n\n%s"):format(title, source_url, page_url, text)
  return vim.split(header, "\n", { plain = true })
end

local function open_in_buffer(title, text, source_url, page_url)
  local buf, win = focus_or_open_docs_buffer()
  local lines = render_docs_lines(title, text, source_url, page_url)

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false
  vim.api.nvim_buf_set_name(buf, ("godotdev://docs/%s"):format(class_slug(title)))
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

local function open_in_browser(url)
  local ok = vim.ui.open(url)
  if ok == false then
    vim.notify(("Failed to open browser for %s"):format(url), vim.log.levels.ERROR)
  end
end

local function open_from_rst(symbol, page_url, renderer)
  local rst_url = rst_url_from_symbol(symbol)
  local config = get_config()
  local source_key = cache_key({ build_docs_source_base_url(), symbol:lower() })

  fetch_text(rst_url, state.rst_cache, source_key, function(rst)
    local markdown_key = cache_key({ source_key, "markdown" })
    local markdown = cache_get(state.markdown_cache, markdown_key)
    if markdown == nil then
      markdown = cache_put(state.markdown_cache, markdown_key, rst_to_markdown(rst))
    end

    if markdown == "" then
      if config.fallback_renderer == "browser" then
        open_in_browser(page_url)
        return
      end

      if config.fallback_renderer == "buffer" and renderer ~= "buffer" then
        open_from_rst(symbol, page_url, "buffer")
        return
      end

      show_feedback(("Could not render Godot docs for `%s`."):format(symbol))
      return
    end

    if renderer == "buffer" then
      open_in_buffer(symbol, markdown, rst_url, page_url)
      return
    end

    open_in_float(symbol, markdown, rst_url, page_url)
  end, function(_)
    if config.fallback_renderer == "browser" then
      open_in_browser(page_url)
      return
    end

    if config.fallback_renderer == "buffer" and renderer ~= "buffer" then
      open_from_rst(symbol, page_url, "buffer")
      return
    end

    show_feedback(("Could not find Godot docs for `%s`."):format(symbol))
  end)
end

function M.open(symbol, renderer)
  local resolved_symbol = extract_symbol(symbol)
  if resolved_symbol == "" then
    show_feedback("No Godot symbol provided and nothing found under cursor.")
    return
  end

  local config = get_config()
  local chosen_renderer = renderer or config.renderer or "float"

  resolve_doc_url(resolved_symbol, function(url, _)
    if not url then
      show_feedback(("Could not find Godot docs for `%s`."):format(resolved_symbol))
      return
    end

    if chosen_renderer == "browser" then
      open_in_browser(url)
      return
    end

    if chosen_renderer == "buffer" then
      open_from_rst(resolved_symbol, url, "buffer")
      return
    end

    open_from_rst(resolved_symbol, url, "float")
  end)
end

function M.setup()
  if vim.g._godot_docs_commands_defined then
    return
  end

  vim.api.nvim_create_user_command("GodotDocs", function(opts)
    M.open(opts.args, nil)
  end, {
    nargs = "?",
    desc = "Open Godot class docs using the configured renderer",
  })

  vim.api.nvim_create_user_command("GodotDocsFloat", function(opts)
    M.open(opts.args, "float")
  end, {
    nargs = "?",
    desc = "Open Godot class docs in a floating window",
  })

  vim.api.nvim_create_user_command("GodotDocsBrowser", function(opts)
    M.open(opts.args, "browser")
  end, {
    nargs = "?",
    desc = "Open Godot class docs in the browser",
  })

  vim.api.nvim_create_user_command("GodotDocsBuffer", function(opts)
    M.open(opts.args, "buffer")
  end, {
    nargs = "?",
    desc = "Open Godot class docs in a reusable buffer",
  })

  vim.api.nvim_create_user_command("GodotDocsCursor", function()
    M.open(vim.fn.expand("<cword>"), nil)
  end, {
    nargs = 0,
    desc = "Open Godot docs for the symbol under cursor",
  })

  vim.g._godot_docs_commands_defined = true
end

return M
