local M = {}

local AUGROUP = "godotdev_formatting"

local function get_config()
  local ok, godotdev = pcall(require, "godotdev")
  if not ok then
    return {}
  end

  return godotdev.opts or {}
end

local function formatter_disabled(config)
  return config.formatter_cmd == nil and config.formatter == false
end

local function command_argv()
  local config = get_config()
  if formatter_disabled(config) then
    return nil
  end

  local cmd = config.formatter_cmd or config.formatter or "gdformat"

  if type(cmd) == "table" then
    return vim.deepcopy(cmd)
  end

  if type(cmd) ~= "string" or cmd == "" then
    return { "gdformat" }
  end

  return vim.split(cmd, "%s+", { trimempty = true })
end

local function executable_name(argv)
  return argv[1]
end

local function format_buffer(bufnr)
  local config = get_config()
  if formatter_disabled(config) then
    return
  end

  local argv = command_argv()
  local bin = executable_name(argv)
  local file = vim.api.nvim_buf_get_name(bufnr)

  if file == "" or bin == nil or bin == "" then
    return
  end

  if vim.fn.executable(bin) ~= 1 then
    vim.notify(bin .. " not found in PATH. Run `:checkhealth godotdev` for more info.", vim.log.levels.WARN)
    return
  end

  table.insert(argv, file)

  vim.system(argv, { text = true }, function(result)
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(bufnr) then
        return
      end

      if result.code ~= 0 then
        local stderr = vim.trim(result.stderr or "")
        local stdout = vim.trim(result.stdout or "")
        local message = stderr ~= "" and stderr or stdout
        if message == "" then
          message = ("Formatter `%s` failed for %s"):format(bin, vim.fn.fnamemodify(file, ":t"))
        end
        vim.notify(message, vim.log.levels.ERROR)
        return
      end

      vim.api.nvim_buf_call(bufnr, function()
        vim.cmd("checktime")
      end)
    end)
  end)
end

function M.setup()
  local group = vim.api.nvim_create_augroup(AUGROUP, { clear = true })

  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    pattern = "*.gd",
    callback = function(args)
      format_buffer(args.buf)
    end,
    desc = "Format GDScript files after save",
  })
end

return M
