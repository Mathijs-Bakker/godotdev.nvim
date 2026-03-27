local h = require("tests.helpers")

return {
  {
    name = "start_editor_server removes stale sockets before starting configured address",
    run = function()
      local unlinked
      local started
      local notifications = {}

      local fake_uv = {
        os_uname = function()
          return { sysname = "Darwin" }
        end,
        fs_stat = function(path)
          if path == "/tmp/godot.pipe" then
            return { type = "socket" }
          end
          return nil
        end,
        fs_unlink = function(path)
          unlinked = path
          return true
        end,
      }

      h.with_temp("uv", fake_uv, function()
        h.with_temp("loop", fake_uv, function()
          h.with_package("godotdev", {
            opts = {
              editor_server = {
                address = "/tmp/godot.pipe",
                remove_stale_socket = true,
              },
            },
          }, function()
            h.with_field(vim.fn, "sockconnect", function(_, address)
              h.assert_equal(address, "/tmp/godot.pipe")
              return 0
            end, function()
              h.with_field(vim.fn, "chanclose", function() end, function()
                h.with_field(vim.fn, "serverstart", function(address)
                  started = address
                  return address
                end, function()
                  h.with_temp("notify", function(message, level)
                    table.insert(notifications, { message = message, level = level })
                  end, function()
                    h.clear_module("godotdev.start_editor_server")
                    local mod = require("godotdev.start_editor_server")
                    local ok = mod.start_editor_server()
                    h.assert_equal(ok, true)
                  end)
                end)
              end)
            end)
          end)
        end)
      end)

      h.assert_equal(unlinked, "/tmp/godot.pipe")
      h.assert_equal(started, "/tmp/godot.pipe")
      h.assert_truthy(#notifications >= 2)
    end,
  },
}
