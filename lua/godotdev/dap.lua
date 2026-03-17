local M = {}

function M.setup(config)
  local dap = require("dap")
  local ok_dapui, dapui = pcall(require, "dapui")

  dap.adapters.godot = {
    type = "server",
    host = config.editor_host or "127.0.0.1",
    port = config.debug_port or 6006,
  }

  dap.configurations.gdscript = {
    {
      type = "godot",
      request = "launch",
      name = "Launch scene",
      project = "${workspaceFolder}",
      launch_scene = true,
    },
  }

  if ok_dapui then
    dapui.setup()
  end

  if ok_dapui then
    dap.listeners.after.event_initialized["dapui_config"] = function()
      dapui.open()
    end
    dap.listeners.before.event_terminated["dapui_config"] = function()
      dapui.close()
    end
    dap.listeners.before.event_exited["dapui_config"] = function()
      dapui.close()
    end
  end
end

return M
