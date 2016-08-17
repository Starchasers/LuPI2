local gpudetect = {}

local function tryText()
  lprint("Trying text-mode gpu")
  loadModule("textgpu")
  local textgpuAddr, tgfail = modules.textgpu.start()
  if not textgpuAddr then
    lprint("Couldn't initialize text gpu: " .. tostring(tgfail))
    return false
  end
  return true
end

local function tryFb()
  lprint("Trying framebuffer-mode gpu")
  if framebuffer.isReady() then
    loadModule("fbgpu")
    modules.fbgpu.start()
    return true
  end
  return false
end

local function tryWindows()
  loadModule("winapigpu")
  return modules.winapigpu.start() and true or false
end

function gpudetect.run()
  local s = false
  if hasOpt("-t", "--text") then
    s = tryText()
    return
  end
  if hasOpt("-f", "--fb") or native.isinit() then
    s = tryFb()
  end
  if not s then
    lprint("Falling back to text gpu")
    s = tryText()
  end
  if not s and winapigpu then
    lprint("Falling back to windows gpu")
    s = tryWindows()
  end
end

return gpudetect
