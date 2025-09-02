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
|                | ---------------------->  |                         |
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
                                            |   (Ghostty, Alacritty)  |
                                            +-------------------------+

```
- **Step 1:** Click a script in Godot
- **Step 2:** `godot-nvr.sh` is called
- **Step 3:** File opens in Neovim via `nvr`
- **Step 4:** GUI terminal is brought to the front

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
   touch ~/.local/bin/godot-nvr.sh
   ```
1. Create the script:
   Save this as `~/.local/bin/godot-nvr.sh`
   ```bash
   #!/usr/bin/env bash
   #
   # godot-nvr.sh
   #
   # Usage:
   #   godot-nvr.sh [TERMINAL_NAME] [--tab|--vsplit] <file>[:line[:col]]
   #
   # Example:
   #   godot-nvr.sh ghostty --tab ~/project/main.gd:10

   TERMINAL_APP="${1:-ghostty}" # default: ghostty
   shift

   MODE=""
   FILE=""
   while [[ $# -gt 0 ]]; do
     case "$1" in
       --tab)
         MODE="--remote-tab"
         shift
         ;;
       --vsplit)
         MODE="--remote-send '<C-w>v:edit '"
         shift
         ;;
       *)
         FILE="$1"
         shift
         ;;
     esac
   done

   # Open file in Neovim
   if [[ -n "$MODE" && "$MODE" == *remote-send* ]]; then
     nvr --remote-send "<C-\\><C-n><C-w>v:edit ${FILE}<CR>"
   elif [[ -n "$MODE" ]]; then
     nvr $MODE "$FILE"
   else
     nvr --remote "$FILE"
   fi

   # Bring terminal GUI to front
   if command -v osascript &>/dev/null; then
     osascript -e "tell application \"$TERMINAL_APP\" to activate"
   fi

   ```
1. And make it executable:
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

    - Open in a tab:

      ```bash
      --tab +{line} {file}

      ```

    - Open in vertical split:

      ```bash
      --vsplit +{line} {file}

      ```

    - Specify terminal explicitly:

      ```bash
      alacritty +{line} {file}

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

## Troubleshooting

### Quick Test (outside Godot)

Before testing inside Godot, confirm the script works standalone:
```bash
~/.local/bin/godot-nvr.sh /path/to/file.gd:10
```
Expected:
- The file opens in your running Neovim instance.
- The buffer is focused.
- Your terminal (e.g. Ghostty) comes to the front.
If this fails, fix the setup before trying again in Godot.

### `command not found: nvr`

 - Make sure `nvr` is installed and in your `$PATH`:
   ```bash
   pip install neovim-remote
   which nvr
   ```

 - If it’s not found, add `~/.local/bin` to your `$PATH`.

### Godot shows "Cannot execute"

- Check the `Exec Path` in Godot points to the script and is executable:
  ```bash
  chmod +x ~/.local/bin/godot-nvr.sh
  ```
- Use the absolute path (e.g. /Users/you/.local/bin/godot-nvr.sh).

### Terminal doesn’t come to the front (macOS)
- Ensure you set the correct terminal app name (case-sensitive!):
  - `ghostty` → `"Ghostty"`
  - `Terminal` → `"Terminal"`
  - `alacritty` → `"Alacritty"`
  - `kitty` -> `"Kitty"`
- To check the exact name macOS expects, run:
  ```bash
  osascript -e 'name of every application process'
  ```
- Test manually (from another terminal app):
  ```bash
  osascript -e 'tell application "ghostty" to activate'
  ```

## Wrong file/line opens
- Make sure you’re using `{file}:{line}` in Godot’s Exec Flags.
- For column support, you can use `{file}:{line}:{col}`.
