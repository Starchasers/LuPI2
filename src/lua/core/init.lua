print("LuPI L1 INIT")
modules = {}

local function loadModule(name)
  print("LuPI L1 INIT > Load module > " .. name)
  --TODO: PRERELEASE: Module sandboxing, preferably secure-ish
  --TODO: ASAP: Handle load errors
  if not moduleCode[name] then
    error("No code for module " .. tostring(name))
  end
  modules[name] = load(moduleCode[name])()
end

--Load modules
loadModule("random")
loadModule("component")
loadModule("computer")
loadModule("sandbox")
loadModule("boot")

--Setup core modules
modules.component.prepare()

modules.boot.boot()
