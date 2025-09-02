# Godot → Neovim External Editor Setup

This setup allows you to click on a script in Godot and open it directly in Neovim running in a GUI terminal (e.g., Ghostty), with the buffer focused and optional tab or vertical split support.

## Features

- Open files in Neovim from Godot with the same window (default)
- Focus the file buffer automatically
- Bring your GUI terminal (Ghostty, Alacritty, Kitty, Wezterm, etc.) to the front
- Optional `--tab` or `--vsplit` mode
- Terminal name can be passed as an argument; defaults to `ghostty`

## Workflow Diagram

```text
+----------------+      clicks script       +-------------------------+
|                | ----------------------> |                         |
|     Godot      |                          |    godot-nvr.sh script  |
|  (Editor UI)   |                          |  (external launcher)    |
+----------------+                          +-------------------------+
                                                    |
                                                    | opens/jumps file
                                                    v
                                          +-------------------------+
                                          |                         |
                                          |      Neovim             |
                                          |  (remote buffer via     |
                                          |     nvr socket)         |
                                          +-------------------------+
                                                    |
                                                    | brings terminal to front
                                                    v
                                          +-------------------------+
                                          |                         |
                                          |   GUI Terminal          |
                                          |   (Ghostty, Alacritty) |
                                          +-------------------------+

```
- **Step 1:** Click a script in Godot
- **Step 2:** `godot-nvr.sh` is called
- **Step 3:** File opens in Neovim via `nvr`
- **Step 4:** GUI terminal is brought to the front

```mermaid
flowchart TD
    A[Godot Editor] -- clicks script --> B[godot-nvr.sh script]
    B -- opens/jumps file --> C[Neovim (via nvr)]
    C -- brings to front --> D[GUI Terminal (Ghostty, Alacritty, etc.)]
```

## Requirements

- macOS (tested)
- Neovim with `nvr` installed
- A GUI terminal (e.g., Ghostty, Alacritty, iTerm)
- Optional: tmux (pane switching inside tmux is not fully supported)

## Installation

1. Install `nvr` if not already installed:
   ```bash
   pip3 install neovim-remote
   ```
1. Save the launcher script:
   ```bash
   mkdir -p ~/.local/bin
   nano ~/.local/bin/godot-nvr.sh
   ```
1. Paste the script (see previous section) and make executable:
   ```bash
   chmod +x ~/.local/bin/godot-nvr.sh
   ```

## Setup in Godot

1. Go to Editor Settings → External Editor
1. Set Exec Path:

   ```bash
    /Users/YOUR_USERNAME/.local/bin/godot-nvr.sh

   ```
1. Set Exec Flags:
    - Default (same window):

      ```bash
      +{line} {file}

      ```

1. Open in a tab:

   ```bash
   --tab +{line} {file}

   ```

1. Open in vertical split:

   ```bash
   --vsplit +{line} {file}

   ```

1. Specify terminal explicitly:

   ```bash
   Alacritty +{line} {file}

   ```

## Usage

- Click a script in Godot → opens in Neovim
- Neovim buffer is focused
- GUI terminal comes to front
- Optional tab/vsplit works
- Terminal argument overrides default "ghostty"

## Notes

- tmux pane switching is not supported reliably from Godot
- Ensure the Neovim socket path (/private/tmp/nvim.pipe) matches your setup
- Tested with Ghostty, should work with other GUI terminals
- This README now provides clear instructions and a visual workflow so other users can reproduce your Godot → Neovim + Ghostty setup easily.
