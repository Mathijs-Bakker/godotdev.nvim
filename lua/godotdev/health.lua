local M = {}

function M.check()
  vim.health.start("Godotdev.nvim")

  -- ncat
  if vim.fn.executable("ncat") == 1 then
    vim.health.ok("'ncat' is installed")
  else
    vim.health.error("'ncat' is missing! Required to attach to Godot editor LSP")
  end

  -- godot-lsp
  if vim.fn.executable("godot-lsp") == 1 then
    vim.health.ok("'godot-lsp' executable found")
  else
    vim.health.warn("'godot-lsp' not found, standalone LSP mode will not work")
  end

  -- Godot editor port
  local handle = io.popen("nc -z 127.0.0.1 6005 >/dev/null 2>&1 && echo ok || echo fail")
  if handle then
    local result = handle:read("*a")
    handle:close()
    if result:match("ok") then
      vim.health.ok("Godot editor LSP detected on port 6005")
    else
      vim.health.warn("Godot editor LSP not detected on port 6005")
    end
  end
end

return M
