local M = {}

local function matches_any_pattern(message, patterns)
  if type(message) ~= "string" or type(patterns) ~= "table" then
    return false
  end

  for _, pattern in ipairs(patterns) do
    if message:match(pattern) then
      return true
    end
  end

  return false
end

function M.wrap_client_handler(client, method, predicate)
  local base_handler = client.handlers[method] or vim.lsp.handlers[method]
  if type(base_handler) ~= "function" then
    return
  end

  client.handlers[method] = function(err, result, ctx, config)
    if predicate(err, result, ctx, config) then
      return
    end

    return base_handler(err, result, ctx, config)
  end
end

--- Suppress specific LSP messages for a single client.
-- @param client vim.lsp.Client
-- @param patterns table List of string patterns to ignore in client messages
function M.suppress_client_messages(client, patterns)
  M.wrap_client_handler(client, "window/showMessage", function(_, params)
    return params and matches_any_pattern(params.message, patterns)
  end)
end

function M.find_project_root()
  local file = vim.api.nvim_buf_get_name(0)
  local start_path = file ~= "" and vim.fs.dirname(file) or vim.uv.cwd()
  local project_file = vim.fs.find("project.godot", {
    upward = true,
    path = start_path,
  })[1]

  if not project_file then
    return nil
  end

  return vim.fs.dirname(project_file)
end

local function normalize_separators(path)
  return path:gsub("\\", "/")
end

local function trim_trailing_slashes(path)
  if path == "/" or path:match("^%a:/$") then
    return path
  end

  return (path:gsub("/+$", ""))
end

function M.is_absolute_path(path)
  return type(path) == "string"
    and (path:match("^/") ~= nil or path:match("^%a:[/\\]") ~= nil or path:match("^[/\\][/\\]") ~= nil)
end

function M.to_res_path(root, path)
  if type(root) ~= "string" or root == "" or type(path) ~= "string" or path == "" then
    return nil
  end

  if path:match("^res://") then
    return path
  end

  local absolute = path
  if not M.is_absolute_path(path) then
    absolute = root .. "/" .. path
  end

  absolute = trim_trailing_slashes(normalize_separators(vim.fs.normalize(absolute)))
  root = trim_trailing_slashes(normalize_separators(vim.fs.normalize(root)))

  local absolute_key = absolute
  local root_key = root
  if absolute:match("^%a:/") or root:match("^%a:/") or absolute:match("^//") or root:match("^//") then
    absolute_key = absolute:lower()
    root_key = root:lower()
  end

  if absolute_key ~= root_key and absolute_key:sub(1, #root_key + 1) ~= root_key .. "/" then
    return nil
  end

  local relative = absolute_key == root_key and "" or absolute:sub(#root + 2)
  return "res://" .. relative
end

return M
