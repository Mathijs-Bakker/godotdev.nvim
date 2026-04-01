local root = vim.fn.getcwd()
package.path = table.concat({
  root .. "/lua/?.lua",
  root .. "/lua/?/init.lua",
  root .. "/tests/?.lua",
  package.path,
}, ";")

local specs = {
  "tests.spec_utils",
  "tests.spec_tree_sitter",
  "tests.spec_setup",
  "tests.spec_docs",
  "tests.spec_docs_render",
  "tests.spec_formatting",
  "tests.spec_run",
  "tests.spec_start_editor_server",
  "tests.spec_health",
}

local total = 0
local failures = {}

local function run_case(name, fn)
  total = total + 1
  local ok, err = pcall(fn)
  if ok then
    vim.api.nvim_out_write(("ok %d - %s\n"):format(total, name))
    return
  end

  table.insert(failures, { index = total, name = name, err = err })
  vim.api.nvim_err_writeln(("not ok %d - %s"):format(total, name))
  vim.api.nvim_err_writeln(tostring(err))
end

for _, spec in ipairs(specs) do
  package.loaded[spec] = nil
  local cases = assert(require(spec), "failed to load " .. spec)
  for _, case in ipairs(cases) do
    run_case(case.name, case.run)
  end
end

vim.api.nvim_out_write(("1..%d\n"):format(total))

if #failures > 0 then
  error(("%d test(s) failed"):format(#failures))
end
