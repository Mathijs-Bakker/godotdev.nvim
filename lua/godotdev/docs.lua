local M = {}

local state = {
  index_cache = nil,
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
  return (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
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

local function class_slug(symbol)
  return symbol:lower():gsub("%s+", "")
end

local function page_url_from_symbol(symbol)
  return ("%s/classes/class_%s.html"):format(build_base_url(), class_slug(symbol))
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

local function html_to_text(html)
  local content = html:match("<main.->(.*)</main>") or html

  content = content:gsub("<script.-</script>", "")
  content = content:gsub("<style.-</style>", "")
  content = content:gsub("<nav.->.-</nav>", "")
  content = content:gsub("<table", "\n<table")
  content = content:gsub("</h[1-6]>", "\n")
  content = content:gsub("<h1[^>]->", "\n# ")
  content = content:gsub("<h2[^>]->", "\n## ")
  content = content:gsub("<h3[^>]->", "\n### ")
  content = content:gsub("<h4[^>]->", "\n#### ")
  content = content:gsub("<h5[^>]->", "\n##### ")
  content = content:gsub("<h6[^>]->", "\n###### ")
  content = content:gsub("<br%s*/?>", "\n")
  content = content:gsub("</p>", "\n\n")
  content = content:gsub("</div>", "\n")
  content = content:gsub("</section>", "\n")
  content = content:gsub("</article>", "\n")
  content = content:gsub("</li>", "\n")
  content = content:gsub("<li[^>]->", "- ")
  content = content:gsub("</tr>", "\n")
  content = content:gsub("</td>", " ")
  content = content:gsub("</th>", " ")
  content = content:gsub("<pre[^>]->", "\n```text\n")
  content = content:gsub("</pre>", "\n```\n")
  content = content:gsub("<code[^>]->", "`")
  content = content:gsub("</code>", "`")
  content = content:gsub('<span[^>]-class="pre"[^>]->', "`")
  content = content:gsub("</span>", "")
  content = content:gsub('<a [^>]-href="([^"]+)"[^>]->(.-)</a>', function(href, label)
    local clean_label = label:gsub("<[^>]->", "")
    if clean_label == "" then
      return href
    end
    return ("%s (%s)"):format(clean_label, href)
  end)
  content = content:gsub("<[^>]->", "")
  content = decode_html_entities(content)
  content = content:gsub("[ \t]+\n", "\n")
  content = content:gsub("\n[ \t]+", "\n")
  content = content:gsub("\n\n\n+", "\n\n")

  return trim(content)
end

local function open_in_float(title, text, url)
  local config = get_config()
  local float = config.float or {}
  local width = math.min(math.max(math.floor(vim.o.columns * (float.width or 0.8)), 60), vim.o.columns)
  local height = math.min(math.max(math.floor(vim.o.lines * (float.height or 0.8)), 12), vim.o.lines - 2)
  local row = math.floor((vim.o.lines - height) / 2 - 1)
  local col = math.floor((vim.o.columns - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  local lines = vim.split(("# %s\n\nSource: %s\n\n%s"):format(title, url, text), "\n", { plain = true })

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

function M.open(symbol, renderer)
  local resolved_symbol = extract_symbol(symbol)
  if resolved_symbol == "" then
    show_feedback("No Godot symbol provided and nothing found under cursor.")
    return
  end

  local config = get_config()
  local chosen_renderer = renderer or config.renderer or "float"

  if chosen_renderer == "browser" then
    resolve_doc_url(resolved_symbol, function(url, _)
      open_in_browser(url or page_url_from_symbol(resolved_symbol))
    end)
    return
  end

  resolve_doc_url(resolved_symbol, function(url, html)
    if not url or not html then
      show_feedback(("Could not find Godot docs for `%s`."):format(resolved_symbol))
      return
    end

    local fallback = config.fallback_renderer
    if chosen_renderer ~= "browser" and fallback == "browser" and not html_to_text(html):match("%S") then
      open_in_browser(url)
      return
    end

    open_in_float(resolved_symbol, html_to_text(html), url)
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
