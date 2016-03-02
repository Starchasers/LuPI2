local fbgpu = {}

local mapping = {}

for i=0,15 do
  mapping[i] = (i * 15) << 16 | (i * 15) << 8 | (i * 15)
end

for i=0,239 do
  local b = math.floor((i % 5) * 255 / 4.0)
  local g = math.floor((math.floor(i / 5.0) % 8) * 255 / 7.0)
  local r = math.floor((math.floor(i / 40.0) % 6) * 255 / 5.0)
  mapping[16+i] = r << 16 | g << 8 | b
end

--[[local nw = io.write
io.write = function(...)
  nw(...)
  io.flush()
  native.sleep(20000)
end]]--

local fb = framebuffer
local write = io.write
local flush = io.flush

for k,v in pairs(mapping) do
  fb.setPalette(k, v)
end

local background = 0
local foreground = 0

local usub

function fbgpu.start()
  usub = modules.sandbox.unicode.sub
  local gpu = {}
  function gpu.bind() return false, "This is static bound gpu" end
  function gpu.getScreen() return "n/a" end
  function gpu.setBackground(color, isPaletteIndex)
    checkArg(1, color, "number")
    checkArg(2, isPaletteIndex, "boolean", "nil")
    if isPaletteIndex and color >= 0 and color < 256 then
      background = color
      return mapping[color]
    end
    local old = background
    background = fb.getNearest(color)
    return mapping[old]
  end
  function gpu.setForeground(color, isPaletteIndex)
    checkArg(1, color, "number")
    checkArg(2, isPaletteIndex, "boolean", "nil")
    if isPaletteIndex and color >= 0 and color < 256 then
      foreground = color
      return mapping[color]
    end
    local old = foreground
    foreground = fb.getNearest(color)
    return mapping[old]
  end
  function gpu.getBackground()
    return mapping[background], false
  end
  function gpu.getForeground()
    return mapping[foreground], false
  end
  function gpu.getPaletteColor()
    return nil
  end
  function gpu.setPaletteColor(index, value)
    checkArg(1, index, "number")
    checkArg(2, value, "number")
    fb.setPalette(index, value)
    return value
  end
  function gpu.maxDepth()
    return 8
  end
  function gpu.setDepth()
    return false
  end
  function gpu.getDepth()
    return 8
  end
  function gpu.maxResolution()
    return fb.getWidth(), fb.getHeight()
  end
  function gpu.getResolution()
    return fb.getWidth(), fb.getHeight()
  end
  function gpu.getViewport()
    return fb.getWidth(), fb.getHeight()
  end
  function gpu.setViewport(w, h)
    checkArg(1, w, "number")
    checkArg(2, h, "number")
    return false, "Viewport not supported for this gpu"
  end
  function gpu.setResolution(w, h)
    checkArg(1, w, "number")
    checkArg(2, h, "number")
    return false, "Non resizeable gpu"
  end
  function gpu.get(x, y)
    checkArg(1, x, "number")
    checkArg(2, y, "number")
    return utf8.char(fb.get(x-1, y-1))
  end
  function gpu.set(x, y, value, vertical)
    checkArg(1, x, "number")
    checkArg(2, y, "number")
    checkArg(3, value, "string")
    checkArg(4, vertical, "boolean", "nil")
    x = math.floor(x)
    y = math.floor(y)
    if not vertical then
      local i = 0
      value:gsub(".", function(c)
        fb.put(x+i-1, y-1, background, foreground, utf8.codepoint(c))
        i = i+1
      end)
    else
      local i = 0
      value:gsub(".", function(c)
        fb.put(x-1, y+i-1, background, foreground, utf8.codepoint(c))
        i = i+1
      end)
    end
    flush()
    return true
  end
  function gpu.copy(x, y, w, h, tx, ty) --TODO: Check(check X multiple times)
    checkArg(1, x, "number")
    checkArg(2, y, "number")
    checkArg(3, w, "number")
    checkArg(4, h, "number")
    checkArg(5, tx, "number")
    checkArg(6, ty, "number")
    fb.copy(x-1, y-1, w, h, tx, ty);
    return true
  end
  function gpu.fill(x, y, w, h, ch)
    checkArg(1, x, "number")
    checkArg(2, y, "number")
    checkArg(3, w, "number")
    checkArg(4, h, "number")
    checkArg(5, ch, "string")
    ch = ch:sub(1, 1)
    fb.fill(x-1, y-1, x+w-2, y+h-2, background, foreground, utf8.codepoint(ch))
    return true
  end

  local w, h = gpu.getResolution()
  gpu.setForeground(0xFFFFFF)
  gpu.setBackground(0x000000)

  termutils.init()
  write("\x1b[?25l") --Disable cursor

  modules.component.api.register(nil, "gpu", gpu)
  modules.component.api.register(nil, "screen", {getKeyboards = function() return {"TODO:SetThisUuid"} end}) --verry dummy screen, TODO: make it better, kbd uuid also in epoll.c
  modules.component.api.register("TODO:SetThisUuid", "keyboard", {})

  deadhooks[#deadhooks + 1] = function()
    write("\x1b[?25h") --Enable cursor on quit
  end
end

return fbgpu
