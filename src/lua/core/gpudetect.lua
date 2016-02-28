local gpudetect = {}

local function tryText()
  loadModule("textgpu")
  local textgpuAddr, tgfail = modules.textgpu.start()
  if not textgpuAddr then
    lprint("Couldn't initialize text gpu: " .. tostring(tgfail))
    return false
  end
  return true
end

local function tryFb()
  if framebuffer.isReady() then
    loadModule("fbgpu")
    modules.fbgpu.start()
    return true
  end
  return false
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
end

return gpudetect
