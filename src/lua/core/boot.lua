local boot = {}

function boot.boot()
  local gpu = modules.component.api.proxy(modules.component.api.list("gpu", true)())
  local w, h = gpu.getResolution()
  print("r= " .. tostring(w) .. " " .. tostring(h))
  gpu.fill(0, 0, w, h, " ")
  gpu.set(10, 5, "HHHHHHHHHHHHH")
  gpu.set(11, 11, "VVVVVVVVVVVVVVVVV", true)
  print("LuPI L2 INIT")
  print("FIXME: boot stub")
  native.sleep(1000000)

  local code = modules.component.api.invoke(modules.component.api.list("eeprom", true)(), "get")
  if not code then
    print("No bootcode")
    error("No bootcode")
  end
    ---PASS SANDBOX!!!!!!
  local f, reason = load(code, "=BIOS", nil, modules.sandbox)
  if not f then
    print(reason)
  else
    local e, reason = pcall(f)
    if not e then
      print("ERROR")
      print(reason)
      --TODO: Make fancy bsod here
    end
    print("System quit, Panic")
  end
end

return boot
