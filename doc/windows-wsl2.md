# Windows + WSL2 External Editor

This workflow is for:

- Neovim running inside WSL2
- Godot running on Windows
- opening scripts from Godot into the WSL Neovim instance

The bridge works in two steps:

1. Windows launches a small PowerShell wrapper.
2. The wrapper converts the Windows file path to a WSL path and asks `nvr` inside WSL to open it in the existing Neovim server.

## Requirements

- WSL2 with your Linux distribution installed
- `nvr` installed inside WSL
- Neovim started in WSL with `--listen`, or through the `godotdev` wrapper from this repository
- `wsl.exe` available from Windows, which is standard on recent Windows installations with WSL enabled

For the GDScript LSP itself, the recommended option is the community bridge `godot-wsl-lsp`. It sits between Neovim in WSL and the Godot LSP server on Windows and rewrites Windows and WSL paths in both directions.

- Repository: https://github.com/lucasecdb/godot-wsl-lsp
- Package summary: https://npm.io/package/godot-wsl-lsp

`checkhealth godotdev` will also mention this bridge when it detects a WSL environment.

Microsoft documents both the WSL localhost forwarding behavior and Windows/Linux file-system interop:

- Windows can reach services listening inside WSL on `localhost` when localhost forwarding is enabled.
- Windows paths like `C:\\...` map to WSL paths like `/mnt/c/...`.

## Setup

1. Start Neovim inside WSL with a listening server:

```bash
nvim --listen /tmp/godot.nvim
```

2. In Godot on Windows, point the external editor to the PowerShell bridge:

```text
Exec Path:
powershell.exe

Exec Flags:
-NoProfile -ExecutionPolicy Bypass -File C:\path\to\godotdev-wsl2.ps1 {file} {line} {col}
```

3. If you want to pin a specific WSL distribution, set:

```powershell
$env:GODOT_WSL_DISTRO = "Ubuntu"
```

4. If your Neovim server uses a different socket path, set:

```powershell
$env:GODOT_NVIM_SOCKET = "/tmp/godot.nvim"
```

5. For GDScript LSP, install and run `godot-wsl-lsp` inside WSL instead of connecting Neovim directly to Godot.

```bash
npm install -g godot-wsl-lsp
```

Then point your GDScript LSP setup at `godot-wsl-lsp` as described by the bridge project.

## Script

The bridge script is provided in this repository at:

- [scripts/windows/godotdev-wsl2.ps1](/Users/MateoPanadero/Repositories/godotdev.nvim/scripts/windows/godotdev-wsl2.ps1)

It accepts the standard Godot editor arguments:

- `{file}`
- `{line}`
- `{col}`

The current bridge uses the file and line arguments. The column is accepted for compatibility but ignored by `nvr` in this first version.

## Notes

- This is only for the editor open-file workflow.
- It does not change the plugin's DAP behavior.
- If you are editing files stored on the Windows filesystem, WSL will see them under `/mnt/<drive>/...`.
- If you want to keep everything on the Linux side, store the project inside the WSL filesystem and open that path from Godot through the bridge.
