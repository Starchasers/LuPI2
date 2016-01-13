local textgpu = {}

local mapping = {
  ["0"] = 0x000000,
  ["1"] = 0xFF0000,
  ["2"] = 0x00FF00,
  ["3"] = 0xFFFF00,
  ["4"] = 0x0000FF,
  ["5"] = 0xFF00FF,
  ["6"] = 0x00FFFF,
  ["7"] = 0xFFFFFF,
}

local background = "0"
local foreground = "0"

function textgpu.start()
  local gpu = {}
  function gpu.bind() return false, "This is static bound gpu" end
  function gpu.getScreen() return "n/a" end
  function gpu.setBackground(color, isPaletteIndex)
    checkArg(1, color, "number")
    checkArg(2, isPaletteIndex, "boolean", "nil")
    if isPaletteIndex then
      return --TODO: Maybe?
    end
    background = modules.color.nearest(color, mapping)
    io.write("\x1b[4" .. math.floor(background) .. "m")
    io.flush()
  end
  function gpu.setForeground(color, isPaletteIndex)
    checkArg(1, color, "number")
    checkArg(2, isPaletteIndex, "boolean", "nil")
    if isPaletteIndex then
      return --TODO: Maybe?
    end
    foreground = modules.color.nearest(color, mapping)
    io.write("\x1b[3" .. math.floor(foreground) .. "m")
    io.flush()
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
  function gpu.setPaletteColor()
    return nil
  end
  function gpu.maxDepth()
    return 3
  end
  function gpu.setDepth()
    return false
  end
  function gpu.getDepth()
    return 3
  end
  function gpu.maxResolution()
    return termutils.getSize()
  end
  function gpu.getResolution()
    return termutils.getSize()
  end
  function gpu.setResolution(w, h)
    checkArg(1, w, "number")
    checkArg(2, h, "number")
    return false, "Non resizeable gpu"
  end
  function gpu.get(x, y)
    checkArg(1, x, "number")
    checkArg(2, y, "number")
    --FIXME: ASAP: Implement
    return " "
  end
  function gpu.set(x, y, value, vertical)
    checkArg(1, x, "number")
    checkArg(2, y, "number")
    checkArg(3, value, "string")
    checkArg(4, vertical, "boolean", "nil")
    x = math.floor(x)
    y = math.floor(y)
    if not vertical then
      io.write("\x1b[" .. y .. ";" .. x .. "H" .. value)
    else
      io.write("\x1b[" .. y .. ";" .. x .. "H")
      value:gsub(".", function(c)
        io.write(c .. "\x1b[D\x1b[B")
      end)
    end
    io.flush()
    return true
  end
  function gpu.copy(x, y, w, h, tx, ty)
    checkArg(1, x, "number")
    checkArg(2, y, "number")
    checkArg(3, w, "number")
    checkArg(4, h, "number")
    checkArg(5, tx, "number")
    checkArg(6, ty, "number")
    --FIXME: ASAP: Implement
    return false
  end
  function gpu.fill(x, y, w, h, ch)
    checkArg(1, x, "number")
    checkArg(2, y, "number")
    checkArg(3, w, "number")
    checkArg(4, h, "number")
    checkArg(5, ch, "string")
    ch = ch:sub(1, 1):rep(math.floor(w))
    for i=1, h do
      gpu.set(x, y + i - 1, ch)
    end
    return true
  end

  io.write("\x1b[?25l") --Disable cursor
  gpu.setForeground(0xFFFFFF)
  gpu.setBackground(0x000000)

  modules.component.api.register(nil, "gpu", gpu)
  modules.component.api.register(nil, "screen", {getKeyboards = function() return {} end}) --verry dummy screen, TODO: make it better

  deadhooks[#deadhooks + 1] = function()
    io.write("\x1b[?25h") --Enable cursor on quit
  end
end

return textgpu