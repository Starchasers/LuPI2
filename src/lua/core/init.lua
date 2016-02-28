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

lprint = function (...)
  print(...)
  native.log(table.concat({...}, " "))
end

lprint("LuPI L1 INIT")
modules = {}
deadhooks = {}

local function loadModule(name)
  lprint("LuPI L1 INIT > Load module > " .. name)
  io.flush()
  --TODO: PRERELEASE: Module sandboxing, preferably secure-ish
  --TODO: ASAP: Handle load errors
  if not moduleCode[name] then
    error("No code for module " .. tostring(name))
  end
  local code, reason = load(moduleCode[name], "=Module "..name)
  if not code then
    lprint("Failed loading module " .. name .. ": " .. reason)
    io.flush()
  else
    modules[name] = code()
  end
end

function main()
  --Load modules
  --Utils
  if native.debug then
    loadModule("debug")
  end
  loadModule("random")
  loadModule("color")
  loadModule("buffer")

  modules.address = modules.random.uuid() --TODO: PREALPHA: Make constant

  --Core
  loadModule("component")
  loadModule("computer")

  --Components
  loadModule("eeprom")
  loadModule("gpio")

  if framebuffer.isReady() then
    loadModule("fbgpu")
  else
    loadModule("textgpu")
  end
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
  modules.gpio.register()
  modules.internet.start()
  modules.filesystem.register("root")
  if native.debug and native.platform():match("unix") then
    modules.filesystem.register("/", "11111111-1111-1111-1111-111111111111")
  end
  modules.computer.tmp = modules.filesystem.register("/tmp/lupi-" .. modules.random.uuid())

  if framebuffer.isReady() then
    modules.fbgpu.start()
  else
    local textgpuAddr, tgfail = modules.textgpu.start()
    if not textgpuAddr then
      lprint("Couldn't initialize text gpu: " .. tostring(tgfail))
    end
  end

  if native.debug then
    modules.debug.hook()
  end

  modules.boot.boot()
end

local tb = ""

local state, cause = xpcall(main, function(e)
  tb = debug.traceback(e, 2)
end)

lprint("Running shutdown hooks")
for k, hook in ipairs(deadhooks) do
  local state, cause = pcall(hook)
  if not state then
    lprint("Shutdown hook with following error:")
    lprint(cause)
  end
end

lprint("Hooks executed: " .. #deadhooks)

if not state then
  lprint("LuPI finished with following error:")
  lprint(tb)
end
