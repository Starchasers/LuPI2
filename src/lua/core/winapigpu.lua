local wingpu = {}

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

local win = winapigpu

for k,v in pairs(mapping) do
  win.setPalette(k, v)
end

local background = 0
local foreground = 0

function wingpu.start()
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
    background = win.getNearest(color)
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
    foreground = win.getNearest(color)
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
    win.setPalette(index, value)
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
    return win.getWidth(), win.getHeight()
  end
  function gpu.getResolution()
    return win.getWidth(), win.getHeight()
  end
  function gpu.getViewport()
    return win.getWidth(), win.getHeight()
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
    return utf8.char(win.get(x-1, y-1))
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
        win.put(x+i-1, y-1, background, foreground, utf8.codepoint(c))
        i = i+1
      end)
    else
      local i = 0
      value:gsub(".", function(c)
        win.put(x-1, y+i-1, background, foreground, utf8.codepoint(c))
        i = i+1
      end)
    end
    return true
  end
  function gpu.copy(x, y, w, h, tx, ty) --TODO: Check(check X multiple times)
    checkArg(1, x, "number")
    checkArg(2, y, "number")
    checkArg(3, w, "number")
    checkArg(4, h, "number")
    checkArg(5, tx, "number")
    checkArg(6, ty, "number")
    win.copy(x-1, y-1, w, h, tx, ty);
    return true
  end
  function gpu.fill(x, y, w, h, ch)
    checkArg(1, x, "number")
    checkArg(2, y, "number")
    checkArg(3, w, "number")
    checkArg(4, h, "number")
    checkArg(5, ch, "string")
    ch = ch:sub(1, 1)
    win.fill(x-1, y-1, x+w-2, y+h-2, background, foreground, utf8.codepoint(ch))
    return true
  end

  local w, h = gpu.getResolution()
  gpu.setForeground(0xFFFFFF)
  gpu.setBackground(0x000000)


  local s, reason = win.open()
  if not s then
    lprint("Couldn't open window: " .. tostring(reason))
  end

  modules.component.api.register(nil, "gpu", gpu)
  modules.component.api.register(nil, "screen", {getKeyboards = function() return {"TODO:SetThisUuid"} end}) --verry dummy screen, TODO: make it better, kbd uuid also in epoll.c
  modules.component.api.register("TODO:SetThisUuid", "keyboard", {})

  return s
end



return wingpu
