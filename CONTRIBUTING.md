# Contributing to GodotDev.nvim

Thanks for your interest in contributing! 🎉  
Please take a moment to read this guide to make the process smoother for everyone.

---

## 🛠 Prerequisites

Before contributing, make sure you have:

- **Godot**: version 4.x (check [Godot downloads](https://godotengine.org/download))
- **Neovim**: version 0.9 or later (check with `nvim --version`)
- A working **Terminal app** (e.g., Ghostty, Kitty, Alacritty, GNOME Terminal)
- **Git** installed and configured

---

## 🚀 Getting Started

1. **Fork** the repository and clone your fork locally:
   ```bash
   git clone https://github.com/<your-username>/<your-plugin>.git
   cd <your-plugin>
   ```
1. **Create** a branch for your work:
   ```bash
   git checkout -b feature/my-new-feature
   ```
1. **Install** dependencies (if any).
   Example:
   ```bash
   # Neovim plugin manager setup (Lazy, Packer, etc.)
   ```
## 🧪 Testing your changes

- Run the headless test suite:
  ```bash
  nvim --headless -u NONE -i NONE -c "lua dofile('tests/run.lua')" -c qa
  ```
- Run the plugin inside Neovim and test against Godot.
- Make sure you test with the versions you’ll list in your PR:
  - Godot version
  - Neovim version
  - OS + Terminal

### Manual integration checklist

- macOS/Linux:
  - start Neovim with your documented `--listen` or `godotdev` wrapper flow
  - open a Godot project and confirm LSP attaches for `.gd` / `.gdshader`
  - verify `:GodotStartEditorServer`, docs rendering, formatting, and DAP startup
  - if you use the external editor workflow, click a script in Godot and confirm it opens in the running Neovim instance
- Windows:
  - start Neovim with `--listen 127.0.0.1:<port>`
  - confirm `ncat` is available and `:checkhealth godotdev` reports the expected dependencies
  - verify LSP, docs commands, formatting, and DAP startup in a Godot project
  - if you use an external editor/plugin bridge, confirm Godot connects to the same host:port as Neovim

## 📖 Submitting a Pull Request
1. Ensure your code follows the style of the project.
1. Update documentation if needed.
1. Push your branch:
   ```bash
   git push origin feature/my-new-feature
   ```
1. Open a **Pull Request**. The PR template will guide you.

## 🐛 Reporting Bugs
Please use the **Bug Report** issue template and include:
- Godot version
- Neovim version
- OS info
- Terminal app
- Steps to reproduce

## 💡 Suggesting Features
- Use the **Feature Request** template to describe:
- The problem you’re trying to solve
- Your proposed solution
- Alternatives you’ve considered
