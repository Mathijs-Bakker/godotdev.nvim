# godotdev.nvim

A Neovim plugin for connecting to the Godot editor LSP server to provide code navigation, diagnostics, and LSP features for GDScript projects. Supports Windows, macOS, and Linux.

## Features

- Connect to a running Godot editor's TCP LSP server.
- LSP-based code navigation for GDScript (`gd`/`gdscript`).
- Diagnostics, hover documentation, workspace symbols, and more.
- Healthcheck to validate editor LSP and required tools.
- OS-aware handling for TCP connection (`ncat` required on Windows).

## Requirements

- Neovim 0.11+
- Godot editor with TCP LSP server enabled (Editor Settings → Network → Enable TCP LSP server).
- **Windows:** `ncat` must be installed (via Scoop or Chocolatey).
- **macOS/Linux:** optional `nc` for port check; otherwise assumed reachable.

## Installation

Using [Lazy.nvim](https://github.com/folke/lazy.nvim):
```lua
`return {
  'Mathijs-Bakker/godotdev.nvim',
  lazy = false,
  config = function()
    require("godotdev").setup {
      editor_port = 6005,       -- optional, default is 6005
      editor_host = "127.0.0.1" -- optional, default is localhost
    }
  end
}
```

Quickstart

1. Open your Godot project and ensure the TCP LSP server is enabled.
1. Open Neovim and edit a `.gd` or `.gdscript` file.
1. The plugin automatically attaches the LSP client.
1. Run healthcheck if needed:
    ```
    `:checkhealth godotdev`
    ```
1.  Use LSP keymaps:
    - `gd` → Go to definition
    - `gD` → Go to declaration
    - `gy` → Type definition
    - `gi` → Go to implementation
    - `gr` → List references
    - `K` → Hover documentation
    - `<leader>rn` → Rename symbol
    - `<leader>f` → Format buffer
    - `gl` → Show diagnostics
    - `[d` / `]d` → Navigate diagnostics

## Configuration Options
```lua
`require("godotdev").setup {
  editor_host = "127.0.0.1", -- default
  editor_port = 6005,        -- default
}`
```

## Notes

- The plugin does **not** start a Godot instance automatically; the Godot editor must be running with TCP LSP enabled.
- On Windows, `ncat` is required for the TCP LSP connection. On macOS/Linux, the plugin assumes the port is reachable.

## License

MIT License
