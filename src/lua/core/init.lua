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
math.randomseed(native.uptime())--TODO: Make it better?

print("LuPI L1 INIT")
modules = {}
deadhooks = {}

local function loadModule(name)
  print("LuPI L1 INIT > Load module > " .. name)
  io.flush()
  --TODO: PRERELEASE: Module sandboxing, preferably secure-ish
  --TODO: ASAP: Handle load errors
  if not moduleCode[name] then
    error("No code for module " .. tostring(name))
  end
  local code, reason = load(moduleCode[name], "=Module "..name)
  if not code then
    print("Failed loading module " .. name .. ": " .. reason)
    io.flush()
  else
    modules[name] = code()
  end
end

function main()
  --Load modules
  --Utils
  loadModule("random")
  loadModule("color")
  loadModule("buffer")

  modules.address = modules.random.uuid() --TODO: PREALPHA: Make constant

  --Core
  loadModule("component")
  loadModule("computer")

  --Components
  loadModule("eeprom")
  loadModule("textgpu")
  loadModule("filesystem")
  loadModule("internet")

  --Userspace
  loadModule("sandbox")
  loadModule("boot")

  --Setup core modules
  modules.component.prepare()
  modules.computer.prepare()
  _G.pushEvent = modules.computer.api.pushSignal

  modules.eeprom.register()
  modules.internet.start()
  modules.filesystem.register("root")
  modules.filesystem.register("/") --TODO: remove from release
  modules.computer.tmp = modules.filesystem.register("/tmp/lupi-" .. modules.random.uuid())
  modules.textgpu.start()

  modules.boot.boot()
end

local state, cause = pcall(main)
if not state then
  print("LuPI finished with following error:")
  print(cause)
end

print("Running shutdown hooks")
for k, hook in ipairs(deadhooks) do
  local state, cause = pcall(hook)
  if not state then
    print("Shutdown hook with following error:")
    print(cause)
  end
end
