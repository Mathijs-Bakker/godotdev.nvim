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

## Quickstart

```lua
-- Lazy.nvim
return {
  'Mathijs-Bakker/godotdev.nvim',
  config = function()
    require("godotdev").setup({
      editor_host = "127.0.0.1", -- Default: 127.0.0.1
      editor_port = 6005,        -- GDScript language server, default: 6005
      debug_port = 6006,         -- Debug adapter server, default: 6006
    })
  end,
}
```

### LSP

- Open any `.gd` or `.gdscript` file in your Godot project.
- The plugin connects automatically to the running Godot editor LSP.
- Keymaps for LSP features (definitions, references, symbols, etc.) are attached per buffer.

### DAP

- Requires `nvim-dap` and `nvim-dap-ui`.
- Launch your game or scene directly from Neovim:
    1. Make sure Godot is running with the debugger server enabled.
    1. Open a `.gd` or `.gdscript` file.
    1. Use DAP commands:
     - `:DapContinue` – Start/Continue debugging
     - `:DapStepOver`, `:DapStepInto`, `:DapStepOut`
    1. The DAP UI automatically opens when debugging starts.

### Healthcheck

```
:checkhealth godotdev
```
- Checks if the Godot editor LSP port is reachable.
- On Windows, also checks if `ncat` is installed.
- Gives clear instructions to fix missing dependencies or misconfigured ports.

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
