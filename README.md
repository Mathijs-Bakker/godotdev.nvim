<div align="center"><img src="assets/godotdev-nvim-logo.svg" width="300"></div>

# godotdev.nvim

**godotdev.nvim** is a batteries-included Neovim plugin for Godot 4.x game development.
It allows you to use Neovim as a fully featured external editor for Godot, with minimal setup.

This plugin provides:

- **LSP support** for GDScript and Godot shaders (`.gdshader` files)
- **Debugging** via `nvim-dap` for GDScript
- **Treesitter syntax highlighting** for Godot shader files
- **Automatic formatting** of `.gd` files using `gdformat`
- **Optional C# support** including LSP, debugging, and tooling
- **Built-in health checks** to verify environment, dependencies, and editor integration

While it is possible to configure Neovim manually for Godot development, this plugin **simplifies setup** and ensures a consistent, cross-platform workflow. It automatically configures LSP, debugging, keymaps, formatting, and environment checks, so you can focus on writing game code rather than troubleshooting editor setup.

## Features

godotdev.nvim provides a complete Neovim environment for Godot 4.x development, with minimal setup. Key features include:

### LSP Support
- Full GDScript language support (Go to definition, references, hover, rename, code actions, etc.)
- `.gdshader` syntax highlighting and language features via Treesitter
- Optional C# LSP support (`csharp-ls` or OmniSharp) for Godot projects with C# scripts

### Debugging (DAP)
- Debug GDScript directly from Neovim using `nvim-dap`
- Keymaps for standard debugging actions:
  - Continue/Start: `F5`
  - Step over: `F10`
  - Step into: `F11`
  - Step out: `F12`
  - Toggle breakpoints: `<leader>db` / `<leader>dB`
- Optional C# debugging via `netcoredbg`

### Formatting
- Automatic `.gd` file formatting using [`gdtoolkit`](https://pypi.org/project/gdtoolkit/)
- Reloads buffer after formatting for immediate feedback
- Recommended `.editorconfig` included for consistent indentation (4 spaces per indent)

### Health Checks
- `:checkhealth godotdev` validates:
  - Required dependencies: `nvim-lspconfig`, `nvim-dap`, `nvim-dap-ui`, `nvim-treesitter`
  - Godot editor LSP and debug servers
  - Optional C# tooling: `dotnet`, `csharp-ls`/OmniSharp, `netcoredbg`
  - Formatter: `gdformat` (with installation instructions)
- Detects common issues like mixed indentation in GDScript/C# files

### Editor Integration
- Commands to start or reconnect to Godot’s editor LSP:
  - `:GodotStartEditorServer`
  - `:GodotReconnectLSP`
- Automatic LSP attachment for Godot filetypes (`.gd`, `.gdshader`, `.gdresource`, optional `.cs`)
- Works cross-platform (macOS, Linux, Windows) with TCP or named pipes

### Keymaps
- LSP: `gd`, `gD`, `gr`, `K`, `<leader>rn`, `<leader>ca`, `<leader>f`, etc.
- DAP: `F5`, `F10`, `F11`, `F12`, `<leader>db`, `<leader>dB`
- DAP UI: `<leader>du` (toggle), `<leader>dr` (REPL)

### Optional C# Support
- Enable by setting `csharp = true` in `require("godotdev").setup()`
- Health checks and DAP integration included
- Supports cross-platform debugging and LSP integration

## Requirements

- Neovim 0.11+
- Godot 4.x+ with TCP LSP enabled
- `nvim-lspconfig`
- `nvim-dap` and `nvim-dap-ui` for debugging
- `nvim-treesitter`
- Windows users must have [`ncat`](https://nmap.org/ncat/) in PATH
- Optional C# support requires:
  - .NET SDK (dotnet)
  - C# LSP server (csharp-ls recommended or omnisharp)
  - netcoredbg debugger

## Installation (Lazy.nvim)

```lua
{
  'Mathijs-Bakker/godotdev.nvim',
  dependencies = { 'nvim-lspconfig', 'nvim-dap', 'nvim-dap-ui', 'nvim-treesitter' },
}
```
## Quickstart

1. Open your Godot project in Neovim
1. Start Godot editor with TCP LSP enabled (Editor Settings → Network → Enable TCP LSP server)
1. Open a `.gd` or `.gdshader` file
1. LSP will automatically attach
1. Use `<leader>rn` to rename, `gd` to go to definition, `gr` for references, etc.
1. Start debugging with DAP (Launch scene configuration)
1. Optional: Enable C# support by setting `csharp = true` in the plugin setup
1. Run `:checkhealth godotdev` at any time to verify plugin, LSP, debug server, and C# dependencies

## Configuration

### Optional settings
```lua
require("godotdev").setup({
  editor_host = "127.0.0.1", -- Godot editor host
  editor_port = 6005,        -- Godot LSP port
  debug_port = 6006,         -- Godot debugger port
  csharp = true,             -- Enable C# Installation Support
  autostart_editor_server = true,  -- Enable auto start Nvim server
})
```

### Optimize Godot editor for Neovim

Below are the recommended settings for configuring the Godot editor for optimal integration with Neovim as your external editor. To access these settings, make sure that the **Advanced Settings switch is enabled** at the top of the **Editor Settings dialog**.

- `Editor Settings > Text Editor > Behavior > Auto Reload Scripts on External Change`

   <details><summary>Show Screenshot -> Godot Editor Settings</summary><img src="assets/godot-editor-auto-reload-script.png"></details>
- `Editor Settings > Interface > Editor > Save on Focus Loss`

  <details><summary>Show Screenshot -> Godot Editor Settings</summary><img src="assets/godot-editor-focus.png"></details>
- `Editor Settings > Interface > Editor > Import Resources When Unfocused`

  <details><summary>Show Screenshot -> Godot Editor Settings</summary><img src="assets/godot-editor-focus.png"></details>

### Open .gdscript/.gdshader from Godot in Neovim

When you click on a gdscript in Godot's FileSystem dock it doesn't open automatically in Neovim.
A [workaround](doc/neovim-external-editor-setup.md) is to to create a small script which launches the file in Neovim.

#### >> macOS/Linux
Complete instructions [here](doc/neovim-external-editor-setup.md)

#### >> Windows

1. Set Neovim to listen on a TCP port
   ```bash
   nvim --listen 127.0.0.1:6666
   ```
   --listen works with host:port on Windows.
1. Tell Godot to connect to that port
   In Godot, configure your external editor or plugin to connect to `127.0.0.1:6666`.
   Make sure the TCP port you choose is free and consistent between Neovim and Godot.

## Godot editor server

You can manually start the Neovim editor server used by Godot:

```vim
:GodotStartEditorServer
```

Or automatically on plugin setup:

```lua
require("godotdev").setup({
  autostart_editor_server = true,
})
```

This ensures Godot can communicate with Neovim as an external editor.

## Reconnect to Godot's LSP server

If the LSP disconnects or you opened a script before Neovim, run:

```vim
:GodotReconnectLSP
```

Reconnects **all Godot buffers** to the LSP.

## Keymaps

### LSP
- `gd` → Go to definition
- `gD` → Go to declaration
- `gy` → Type definition
- `gi` → Go to implementation
- `gr` → List references
- `K` → Hover
- `<C-k>` → Signature help
- `<leader>rn` → Rename symbol
- `<leader>ca` → Code action
- `<leader>f` → Format buffer
- `gl` → Show diagnostics
- `[d` / `]d` → Previous/next diagnostic

### DAP
- `F5` -> Continue/Start
- `F10` -> Step over
- `F11` -> Step into
- `F12` -> Step out
- `<leader>db` -> Toggle Breakpoint
- `<leader>dB` -> Conditional breakpoint

### DAP UI
- `<leader>du` -> , Toggle UI
- `<leader>dr` -> , Open REPL

## C# Installation Support

- Enable by setting `csharp = true` in `require("godotdev").setup()`
- Health checks via `:checkhealth godotdev` will verify:
  - .NET SDK (`dotnet`)
  - C# LSP server (`csharp-ls` or `omnisharp`)
  - Debugger (`netcoredbg`)

## Autoformatting / Indentation

Godot expects **spaces, 4 per indent** (for both GDScript and C#).
This plugin automatically sets buffer options for `.gd` files.

Additionally, `.gd` files are autoformatted on save with [`gdformat`](https://github.com/godotengine/gdformat):

```vim
:w
```

Make sure `gdformat` is installed and in your PATH. If not, you will see a warning notification.

For more info on indentation: `:help godotdev-indent`

## Hints/Tips

- [Hide Godot related files in file explorers](doc/hide-files-in-file-explorers.md)

