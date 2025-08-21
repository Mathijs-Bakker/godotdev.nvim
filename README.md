# godotdev.nvim

Batteries-included Neovim plugin for **Godot game development** (Godot 4.3+), using Neovim as an external editor. Provides LSP support for GDScript and Godot shaders, DAP debugging, and Treesitter syntax highlighting.

## Features

- Connect to Godot editor LSP over TCP (`127.0.0.1:6005` by default)
- Full GDScript language support
- `.gdshader` syntax highlighting via Treesitter
- Debug GDScript with `nvim-dap` (`127.0.0.1:6006` by default)
- Keymaps for common LSP actions
- Batteries included: everything you need for Godot development in Neovim

## Requirements

- Neovim 0.9+  
- Godot 4.3+ with TCP LSP enabled  
- `nvim-lspconfig`  
- `nvim-dap` and `nvim-dap-ui` for debugging  
- `nvim-treesitter`  
- Windows users must have [`ncat`](https://nmap.org/ncat/) in PATH

## Installation (Lazy.nvim)

```lua
{
  'Mathijs-Bakker/godotdev.nvim',
  lazy = false,
  dependencies = { 'nvim-lspconfig', 'nvim-dap', 'nvim-dap-ui', 'nvim-treesitter' },
  config = function()
    require("godotdev").setup()
  end,
}
```
## Quickstart

1. Open your Godot project in Neovim
1. Start Godot editor with TCP LSP enabled (Editor Settings → Network → Enable TCP LSP server)
1. Open a .gd or .gdshader file
1. LSP will automatically attach
1. Use <leader>rn to rename, gd to go to definition, gr for references, etc.
1. Start debugging with DAP (Launch scene configuration)

## Configuration

```lua
require("godotdev").setup({
  editor_host = "127.0.0.1", -- Godot editor host
  editor_port = 6005,        -- LSP port
  debug_port = 6006,         -- DAP port
})
```
# Keymaps

### LSP
`gd` → Go to definition
`gD` → Go to declaration
`gy` → Type definition
`gi` → Go to implementation
`gr` → List references
`K` → Hover
`<C-k>` → Signature help
`<leader>rn` → Rename symbol
`<leader>ca` → Code action
`<leader>f` → Format buffer
`gl` → Show diagnostics
`[d` / `]d` → Previous/next diagnostic

### DAP
  `F5` -> Continue/Start
  `F10` -> Step over
  `F11` -> Step into
  `F12` -> Step out
  `<leader>db` -> Toggle Breakpoint
  `<leader>dB` -> Conditional breakpoint

### DAP UI
  `<leader>du` -> , Toggle UI 
  `<leader>dr` -> , Open REPL


## License

MI
