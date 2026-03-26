local M = {}

local state = {
  index_cache = nil,
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
  local direct_url = page_url_from_symbol(symbol)

  fetch_url(direct_url, function(html)
    callback(direct_url, html)
  end, function(_)
    fetch_index(function(index)
      local href = index[symbol:lower()]
      if not href then
        callback(nil, nil)
        return
      end

      local resolved_url = href:match("^https?://") and href or (build_base_url() .. "/" .. href:gsub("^/", ""))
      fetch_url(resolved_url, function(html)
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

    if next_line and next_line:match('^([=~%^"%-])%1+$') and #trim(line) > 0 then
      local marker = next_line:sub(1, 1)
      local heading = heading_levels[marker] or "##"
      table.insert(output, ("%s %s"):format(heading, normalize_inline_rst(trim(line))))
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
    elseif
      line:match("^%.%. note::")
      or line:match("^%.%. warning::")
      or line:match("^%.%. tip::")
      or line:match("^%.%. important::")
      or line:match("^%.%. deprecated::")
    then
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
      table.insert(output, normalize_inline_rst(line))
      i = i + 1
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

local function open_in_browser(url)
  local ok = vim.ui.open(url)
  if ok == false then
    vim.notify(("Failed to open browser for %s"):format(url), vim.log.levels.ERROR)
  end
end

local function open_in_float_from_rst(symbol, page_url)
  local rst_url = rst_url_from_symbol(symbol)
  local config = get_config()

  fetch_url(rst_url, function(rst)
    local markdown = rst_to_markdown(rst)
    if markdown == "" then
      if config.fallback_renderer == "browser" then
        open_in_browser(page_url)
        return
      end

      show_feedback(("Could not render Godot docs for `%s`."):format(symbol))
      return
    end

    open_in_float(symbol, markdown, rst_url, page_url)
  end, function(_)
    if config.fallback_renderer == "browser" then
      open_in_browser(page_url)
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

    open_in_float_from_rst(resolved_symbol, url)
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

  vim.api.nvim_create_user_command("GodotDocsCursor", function()
    M.open(vim.fn.expand("<cword>"), nil)
  end, {
    nargs = 0,
    desc = "Open Godot docs for the symbol under cursor",
  })

  vim.g._godot_docs_commands_defined = true
end

return M
