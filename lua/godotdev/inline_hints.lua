local M = {}

M.opts = {
  enabled = false,
}

local function has_inlay_hint_api()
  return vim.lsp
    and vim.lsp.inlay_hint
    and type(vim.lsp.inlay_hint.enable) == "function"
    and type(vim.lsp.inlay_hint.is_enabled) == "function"
end

local function set_enabled(enabled, bufnr)
  vim.lsp.inlay_hint.enable(enabled, { bufnr = bufnr })
end

function M.enable_for_buffer(client, bufnr)
  if not M.opts.enabled or not has_inlay_hint_api() then
    return false
  end

  if not client or type(client.supports_method) ~= "function" then
    return false
  end

  if not client:supports_method("textDocument/inlayHint") then
    return false
  end

  set_enabled(true, bufnr)
  return true
end

function M.toggle(bufnr)
  bufnr = bufnr or 0

  if not has_inlay_hint_api() then
    vim.notify("godotdev.nvim: Neovim inlay hints are not available in this build", vim.log.levels.WARN)
    return false
  end

  local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr })
  set_enabled(not enabled, bufnr)
  vim.notify(("Godot inline hints %s"):format(enabled and "disabled" or "enabled"), vim.log.levels.INFO)
  return true
end

function M.setup(opts)
  M.opts = vim.tbl_deep_extend("force", M.opts, opts or {})

  if vim.fn.exists(":GodotToggleInlineHints") ~= 2 then
    vim.api.nvim_create_user_command("GodotToggleInlineHints", function()
      M.toggle(0)
    end, { desc = "Toggle Godot inline hints for the current buffer" })
  end
end

return M
