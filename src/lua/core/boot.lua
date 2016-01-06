local boot = {}

function boot.boot()
  local gpu = modules.component.api.proxy(modules.component.api.list("gpu", true)())
  local w, h = gpu.getResolution()

  local function bsod(err)
    gpu.setBackground(0x0000FF)
    gpu.setForeground(0xFFFFFF)
    gpu.fill(0, 0, w, h, " ")
    gpu.set(2, 2, "CRITICAL ERROR OCCURED")
    gpu.set(2, 3, "Lua BIOS Has failed:")
    gpu.set(2, 5, tostring(err))
    io.flush()
    native.sleep(2000000)
    gpu.setForeground(0xFFFFFF)
    gpu.setBackground(0x000000)
  end

  print("r= " .. tostring(w) .. " " .. tostring(h))
  gpu.fill(0, 0, w, h, " ")
  gpu.set(10, 5, "HHHHHHHHHHHHH")
  gpu.set(11, 11, "VVVVVVVVVVVVVVVVV", true)
  print("LuPI L2 INIT")

  local code = modules.component.api.invoke(modules.component.api.list("eeprom", true)(), "get")
  if not code then
    print("No bootcode")
    error("No bootcode")
  end
  local f, reason = load(code, "=BIOS", nil, modules.sandbox)
  if not f then
    print(reason)
  else
    local e, reason = pcall(f)
    if not e then
      bsod(reason)      
    end
    print("System quit, Panic")
  end
end

return boot
