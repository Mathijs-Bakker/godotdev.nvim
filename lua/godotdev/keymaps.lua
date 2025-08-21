local M = {}

function M.attach_lsp(bufnr)
  local opts = { buffer = bufnr }

  local has_telescope, telescope_builtin = pcall(require, "telescope.builtin")

  local function map(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, vim.tbl_extend("force", opts, { desc = desc }))
  end

  -- Definitions / Declarations
  map("n", "gd", has_telescope and telescope_builtin.lsp_definitions or vim.lsp.buf.definition, "LSP: Go to definition")
  map("n", "gD", vim.lsp.buf.declaration, "LSP: Go to declaration")
  map(
    "n",
    "gy",
    has_telescope and telescope_builtin.lsp_type_definitions or vim.lsp.buf.type_definition,
    "LSP: Type definition"
  )
  map(
    "n",
    "gi",
    has_telescope and telescope_builtin.lsp_implementations or vim.lsp.buf.implementation,
    "LSP: Go to implementation"
  )
  map("n", "gr", has_telescope and telescope_builtin.lsp_references or vim.lsp.buf.references, "LSP: List references")

  -- Info
  map("n", "K", vim.lsp.buf.hover, "LSP: Hover documentation")
  map("n", "<C-k>", vim.lsp.buf.signature_help, "LSP: Signature help")

  -- Symbols
  map(
    "n",
    "<leader>ds",
    has_telescope and telescope_builtin.lsp_document_symbols or vim.lsp.buf.document_symbol,
    "LSP: Document symbols"
  )
  map(
    "n",
    "<leader>ws",
    has_telescope and telescope_builtin.lsp_dynamic_workspace_symbols or vim.lsp.buf.workspace_symbol,
    "LSP: Workspace symbols"
  )

  -- Actions
  map("n", "<leader>rn", vim.lsp.buf.rename, "LSP: Rename symbol")
  map({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, "LSP: Code action")
  map("n", "<leader>f", function()
    vim.lsp.buf.format({ async = true })
  end, "LSP: Format buffer")

  -- Diagnostics
  map("n", "gl", vim.diagnostic.open_float, "LSP: Show diagnostics")
  map("n", "[d", vim.diagnostic.goto_prev, "LSP: Previous diagnostic")
  map("n", "]d", vim.diagnostic.goto_next, "LSP: Next diagnostic")
end

function M.attach_dap()
  local dap = require("dap")
  local dapui = require("dapui")

  local function map(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, { desc = desc })
  end

  -- Basic debugger controls
  map("n", "<F5>", dap.continue, "DAP: Continue/Start")
  map("n", "<F10>", dap.step_over, "DAP: Step over")
  map("n", "<F11>", dap.step_into, "DAP: Step into")
  map("n", "<F12>", dap.step_out, "DAP: Step out")
  map("n", "<leader>db", dap.toggle_breakpoint, "DAP: Toggle breakpoint")
  map("n", "<leader>dB", function()
    dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
  end, "DAP: Conditional breakpoint")

  -- UI
  map("n", "<leader>du", dapui.toggle, "DAP: Toggle UI")
  map("n", "<leader>dr", dap.repl.open, "DAP: Open REPL")
end
return M
