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
   # Godot → Neovim launcher with GUI terminal focus
   # Usage:
   #   godot-nvr.sh [terminal_name] +{line} {file} [--tab|--vsplit]

   # -----------------------------
   # Arguments
   # -----------------------------
   DEFAULT_TERMINAL="ghostty"
   ARG0="$1"

   if [[ "$ARG0" == +* || "$ARG0" == --* || -f "$ARG0" ]]; then
      # No terminal argument provided, use default
      GODOT_TERMINAL="$DEFAULT_TERMINAL"
   else
      # First argument is terminal name
      GODOT_TERMINAL="$ARG0"
      shift
   fi

   SOCKET="/tmp/godot.pipe"   # Neovim socket path
   NVR="/Library/Frameworks/Python.framework/Versions/3.8/bin/nvr"

   OPEN_MODE="window"
   LINE=""
   FILE=""

   # -----------------------------
   # Parse remaining arguments
   # -----------------------------
   while [[ $# -gt 0 ]]; do
      case "$1" in
        --tab) OPEN_MODE="tab"; shift ;;
        --vsplit) OPEN_MODE="vsplit"; shift ;;
        +[0-9]*) LINE="${1#+}"; shift ;;
        *) FILE="$1"; shift ;;
      esac
   done

   [ -z "$FILE" ] && exit 0

   # -----------------------------
   # Open file in Neovim or jump to buffer
   # -----------------------------
   if $NVR --servername "$SOCKET" --remote-expr \
     "bufexists(fnamemodify('$FILE', ':p'))" | grep -q 1; then
     CMD=":buffer $(basename "$FILE")"
   else
      case "$OPEN_MODE" in
        window) CMD=":e $FILE" ;;
        tab) CMD=":tabedit $FILE" ;;
        vsplit) CMD=":vsplit $FILE" ;;
      esac
   fi

   [ -n "$LINE" ] && CMD="$CMD | call cursor($LINE,1)"
   CMD="$CMD | normal! zz"

   $NVR --servername "$SOCKET" --remote-send "<C-\\><C-N>${CMD}<CR>"

   # -----------------------------
   # Focus GUI terminal (macOS)
   # -----------------------------
   osascript -e "tell application \"$GODOT_TERMINAL\" to activate"

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
