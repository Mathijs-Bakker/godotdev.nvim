local M = {}

function M.get_config()
  local ok, godotdev = pcall(require, "godotdev")
  if not ok then
    return {}
  end

  return godotdev.opts.docs or {}
end

function M.show_feedback(message)
  local config = M.get_config()
  local mode = config.missing_symbol_feedback or "message"

  if mode == "notify" then
    vim.notify(message, vim.log.levels.WARN)
    return
  end

  vim.api.nvim_echo({ { message, "WarningMsg" } }, false, {})
end

function M.trim(text)
  local trimmed = (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
  return trimmed
end

function M.class_slug(symbol)
  local slug = symbol:lower():gsub("%s+", "")
  return slug
end

function M.extract_symbol(input)
  local symbol = M.trim(input)
  if symbol == "" then
    symbol = M.trim(vim.fn.expand("<cword>"))
  end

  return symbol
end

function M.build_base_url()
  local config = M.get_config()
  local language = config.language or "en"
  local version = config.version or "stable"

  if config.base_url and config.base_url ~= "" then
    local base_url = config.base_url:gsub("/$", "")
    return base_url
  end

  return ("https://docs.godotengine.org/%s/%s"):format(language, version)
end

function M.build_docs_source_base_url()
  local config = M.get_config()

  if config.source_base_url and config.source_base_url ~= "" then
    local source_base_url = config.source_base_url:gsub("/$", "")
    return source_base_url
  end

  local ref = config.source_ref or "master"
  return ("https://raw.githubusercontent.com/godotengine/godot-docs/%s"):format(ref)
end

return M
