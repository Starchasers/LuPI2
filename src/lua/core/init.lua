function checkArg(n, have, ...)
  have = type(have)
  local function check(want, ...)
    if not want then
      return false
    else
      return have == want or check(...)
    end
  end
  if not check(...) then
    local msg = string.format("bad argument #%d (%s expected, got %s)",
                              n, table.concat({...}, " or "), have)
    error(msg, 3)
  end
end

-------------------------------------------------------------------------------

print("LuPI L1 INIT")
modules = {}

local function loadModule(name)
  print("LuPI L1 INIT > Load module > " .. name)
  --TODO: PRERELEASE: Module sandboxing, preferably secure-ish
  --TODO: ASAP: Handle load errors
  if not moduleCode[name] then
    error("No code for module " .. tostring(name))
  end
  local code, reason = load(moduleCode[name])
  if not code then
    print("Failed loading module " .. name .. ": " .. reason)
  else
    modules[name] = code()
  end
end

--Load modules
loadModule("random")
loadModule("color")

loadModule("component")
loadModule("computer")

loadModule("eeprom")
loadModule("textgpu")

loadModule("sandbox")
loadModule("boot")

--Setup core modules
modules.component.prepare()
modules.computer.prepare()

modules.eeprom.register()
modules.textgpu.start()

modules.boot.boot()
