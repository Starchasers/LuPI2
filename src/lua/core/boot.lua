local boot = {}

function boot.boot()
  local gpu = modules.component.api.proxy(modules.component.api.list("gpu", true)())
  local w, h = gpu.getResolution()

  local function bsod(...)
    gpu.setBackground(0x0000FF)
    gpu.setForeground(0xFFFFFF)
    gpu.fill(1, 1, w, h, " ")
    gpu.set(2, 2, "CRITICAL ERROR OCCURED")
    gpu.set(2, 3, "Lua BIOS has failed:")
    for n, v in pairs({...}) do
      gpu.set(2, 4 + n, tostring(v))
    end
    gpu.set(2, h-1, "SYSTEM WILL STOP")
    gpu.setForeground(0xFFFFFF)
    gpu.setBackground(0x000000)

    native.sleep(4000000)
    os.exit(1)
  end

  gpu.fill(1, 1, w, h, " ")
  gpu.set(1, h - 2, "LuPI L2 INIT")
  local code = modules.component.api.invoke(modules.component.api.list("eeprom", true)(), "get")
  if not code then
    bsod("No bootcode")
  end
  local f, reason = load(code, "=USERBIOS", nil, modules.sandbox)
  if not f then
    bsod(reason)
  else
    xpcall(f, function(e)
      local trace = {}
      for s in string.gmatch(debug.traceback(e, 2), "[^\r\n]+") do
        trace[#trace + 1] = s
      end
      bsod("System crashed", "Stack traceback:", table.unpack(trace))
    end)
    bsod("System quit")
  end
end

return boot
