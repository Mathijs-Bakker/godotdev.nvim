local common = require("godotdev.docs.common")
local rst = require("godotdev.docs.rst")

local M = {}

local state = {
  index_cache = nil,
  doc_url_cache = {},
  rst_cache = {},
  markdown_cache = {},
}

function M.reset()
  state.index_cache = nil
  state.doc_url_cache = {}
  state.rst_cache = {}
  state.markdown_cache = {}
end

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

local function is_cache_enabled()
  local config = common.get_config()
  if config.cache == nil then
    return true
  end

  if type(config.cache) == "boolean" then
    return config.cache
  end

  return config.cache.enabled ~= false
end

local function cache_max_entries()
  local config = common.get_config()
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

local function page_url_from_symbol(symbol)
  return ("%s/classes/class_%s.html"):format(common.build_base_url(), common.class_slug(symbol))
end

local function rst_url_from_symbol(symbol)
  return ("%s/classes/class_%s.rst"):format(common.build_docs_source_base_url(), common.class_slug(symbol))
end

local function shell_argv(url)
  local config = common.get_config()
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
        local stderr = common.trim(result.stderr or "")
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
    local name = common.trim(decode_html_entities(label:gsub("<[^>]->", "")))
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

  local index_url = ("%s/classes/index.html"):format(common.build_base_url())
  fetch_url(index_url, function(html)
    state.index_cache = parse_index(html)
    callback(state.index_cache)
  end, function(_)
    callback({})
  end)
end

function M.resolve_doc_url(symbol, callback)
  local key = cache_key({ common.build_base_url(), symbol:lower() })
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

      local resolved_url = href:match("^https?://") and href or (common.build_base_url() .. "/" .. href:gsub("^/", ""))
      fetch_text(resolved_url, state.rst_cache, cache_key({ "page-html", resolved_url }), function(html)
        cache_put(state.doc_url_cache, key, { url = resolved_url, html = html })
        callback(resolved_url, html)
      end, function(_)
        callback(nil, nil)
      end)
    end)
  end)
end

function M.fetch_markdown(symbol, on_success, on_error)
  local rst_url = rst_url_from_symbol(symbol)
  local source_key = cache_key({ common.build_docs_source_base_url(), symbol:lower() })

  fetch_text(rst_url, state.rst_cache, source_key, function(rst_text)
    local markdown_key = cache_key({ source_key, "markdown" })
    local markdown = cache_get(state.markdown_cache, markdown_key)
    if markdown == nil then
      markdown = cache_put(state.markdown_cache, markdown_key, rst.to_markdown(rst_text))
    end

    on_success(markdown, rst_url)
  end, on_error)
end

return M
