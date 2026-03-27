local M = {}

function M.assert_truthy(value, message)
  if not value then
    error(message or ("expected truthy value, got " .. tostring(value)), 2)
  end
end

function M.assert_falsy(value, message)
  if value then
    error(message or ("expected falsy value, got " .. tostring(value)), 2)
  end
end

function M.assert_equal(actual, expected, message)
  if actual ~= expected then
    error(message or ("expected " .. vim.inspect(expected) .. ", got " .. vim.inspect(actual)), 2)
  end
end

function M.with_temp(key, value, fn)
  local original = vim[key]
  vim[key] = value
  local ok, result = pcall(fn)
  vim[key] = original
  if not ok then
    error(result, 2)
  end
  return result
end

function M.with_package(name, value, fn)
  local original = package.loaded[name]
  package.loaded[name] = value
  local ok, result = pcall(fn)
  package.loaded[name] = original
  if not ok then
    error(result, 2)
  end
  return result
end

function M.clear_module(name)
  package.loaded[name] = nil
end

return M
