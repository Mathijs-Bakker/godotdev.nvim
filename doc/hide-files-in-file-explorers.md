# File Explorers: hide Godot files
The following setups are for [Lazy.nvim](https://github.com/folke/lazy.nvim)

## Oil.nvim
```lua
return {
  "stevearc/oil.nvim",
  lazy = false,
  opts = {
    default_file_explorer = true,
    -- Make sure you have this in your options:
    view_options = {
      show_hidden = false,
      is_hidden_file = function(name, _)
        local godot_patterns = {
          '%.uid[/]?$',   -- .uid files
          '%.import[/]?$', -- .import files
          '^%.godot[/]?$', -- .godot directory
          '^%.mono[/]?$',  -- .mono directory
          'godot.*%.tmp$', -- godot temp files
        }
        for _, pat in ipairs(godot_patterns) do
          if name:match(pat) then
            return true
          end
        end
        return false
      end,
    },
  },
  dependencies = { "nvim-tree/nvim-web-devicons" },
  keys = {
    { "-", "<CMD>Oil<CR>", desc = "Open parent directory" },
  },
}
```

## mini.files

The filtering option doesn't work as expected in mini.files. Somehow the filtering system is broken.

This monkey patch approach is working because it intercepts the buffer content at the right moment - after mini.files has processed it but before it's displayed, so the plugin doesn't detect any "user modifications" that would trigger the synchronization warning.

[mini.files](https://github.com/echasnovski/mini.files)

```lua
return {
  'echasnovski/mini.files',
  keys = {
    {
      '-',
      function()
        require('mini.files').open()
      end,
      desc = 'Open MiniFiles',
    },
  },
  config = function()
    local original_set_lines = vim.api.nvim_buf_set_lines

    local filter_godot_files = function(lines)
      local filtered = {}
      local godot_patterns = {
        '%.uid[/]?$', -- .uid files
        '%.import[/]?$', -- .import files
        '^%.godot[/]?$', -- .godot directory
        '^%.mono[/]?$', -- .mono directory
        'godot.*%.tmp$', -- godot temp files
      }

      for _, line in ipairs(lines) do
        local should_include = true
        for _, pattern in ipairs(godot_patterns) do
          if line:match(pattern) then
            should_include = false
            break
          end
        end
        if should_include then
          table.insert(filtered, line)
        end
      end
      return filtered
    end

    require('mini.files').setup {
      content = {
        filter = function(fs_entry)
          return true
        end, -- Use our custom filtering instead
      },
      mappings = {
        close = 'q',
        go_in = 'l',
        go_in_plus = 'L',
        go_out = 'h',
        go_out_plus = 'H',
        reset = '<BS>',
        reveal_cwd = '@',
        show_help = 'g?',
        synchronize = '=',
        trim_left = '<',
        trim_right = '>',
      },
      options = {
        permanent_delete = true,
        use_as_default_explorer = true,
      },
      windows = {
        max_number = math.huge,
        preview = false,
        width_focus = 50,
        width_nofocus = 15,
        width_preview = 25,
      },
    }

    vim.api.nvim_buf_set_lines = function(buf_id, start, end_idx, strict_indexing, lines)
      local bufname = vim.api.nvim_buf_get_name(buf_id)
      if bufname:match 'minifiles://' and type(lines) == 'table' then
        lines = filter_godot_files(lines)
      end
      return original_set_lines(buf_id, start, end_idx, strict_indexing, lines)
    end
  end,
}
```
