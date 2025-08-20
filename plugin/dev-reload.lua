local plugin_name = "godotdev.nvim"
local plugin_path = vim.fn.expand("~/Repositories/" .. plugin_name)

vim.api.nvim_create_autocmd("BufWritePost", {
  pattern = plugin_path .. "/**/*.lua",
  callback = function(args)
    -- Clear all godotdev modules so they reload
    for name, _ in pairs(package.loaded) do
      if name:match("^godotdev") then
        package.loaded[name] = nil
      end
    end

    -- Re-require plugin
    local ok, mod = pcall(require, "godotdev")
    if not ok then
      vim.notify("Failed to reload godotdev.nvim: " .. mod, vim.log.levels.ERROR)
      return
    end

    -- Run setup (if available)
    if mod.setup then
      pcall(mod.setup, {})
    end

    -- Reattach keymaps + lsp
    local ok_keymaps, keymaps = pcall(require, "godotdev.keymaps")
    if ok_keymaps and keymaps.attach and vim.api.nvim_get_current_buf() then
      keymaps.attach(vim.api.nvim_get_current_buf())
    end

    local ok_lsp, lsp = pcall(require, "godotdev.lsp")
    if ok_lsp and lsp.setup then
      lsp.setup({})
    end

    vim.notify("Reloaded " .. plugin_name .. " (after saving " .. args.file .. ")", vim.log.levels.INFO)
  end,
})
