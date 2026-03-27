local common = require("godotdev.docs.common")
local fetch = require("godotdev.docs.fetch")
local render = require("godotdev.docs.render")

local M = {}

fetch.reset()
render.reset()

local function open_from_rst(symbol, page_url, renderer)
  local config = common.get_config()

  fetch.fetch_markdown(symbol, function(markdown, rst_url)
    if markdown == "" then
      if config.fallback_renderer == "browser" then
        render.open_browser(page_url)
        return
      end

      if config.fallback_renderer == "buffer" and renderer ~= "buffer" then
        open_from_rst(symbol, page_url, "buffer")
        return
      end

      common.show_feedback(("Could not render Godot docs for `%s`."):format(symbol))
      return
    end

    if renderer == "buffer" then
      render.open_buffer(symbol, markdown, rst_url, page_url)
      return
    end

    render.open_float(symbol, markdown, rst_url, page_url)
  end, function(_)
    if config.fallback_renderer == "browser" then
      render.open_browser(page_url)
      return
    end

    common.show_feedback(("Could not find Godot docs for `%s`."):format(symbol))
  end)
end

function M.open(symbol, renderer)
  local resolved_symbol = common.extract_symbol(symbol)
  if resolved_symbol == "" then
    common.show_feedback("No Godot symbol provided and nothing found under cursor.")
    return
  end

  local config = common.get_config()
  local chosen_renderer = renderer or config.renderer or "float"

  fetch.resolve_doc_url(resolved_symbol, function(url, _)
    if not url then
      common.show_feedback(("Could not find Godot docs for `%s`."):format(resolved_symbol))
      return
    end

    if chosen_renderer == "browser" then
      render.open_browser(url)
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
