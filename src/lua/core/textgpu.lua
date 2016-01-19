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

--[[local nw = io.write
io.write = function(...)
  nw(...)
  io.flush()
  native.sleep(20000)
end]]--

local write = io.write
local flush = io.flush

local background = "0"
local foreground = "0"

local tbuffer = {}
local bbuffer = {}
local fbuffer = {}

local function prepareBuffers(w, h)
  local tbline = (" "):rep(w)
  local bbline = ("0"):rep(w)
  local fbline = ("7"):rep(w)
  for i=1, h do
    tbuffer[i] = tbline
    bbuffer[i] = bbline
    fbuffer[i] = fbline
  end
end

local usub = modules.sandbox.utf8.sub
local function insertString(main, sub, at)
  return usub(main, 1, at - 1) .. sub .. usub(main, at + utf8.len(sub))
end

function textgpu.start()
  local gpu = {}
  function gpu.bind() return false, "This is static bound gpu" end
  function gpu.setBackground(color, isPaletteIndex)
    checkArg(1, color, "number")
    checkArg(2, isPaletteIndex, "boolean", "nil")
    if isPaletteIndex then
      return --TODO: Maybe?
    end
    local old = background
    background = tostring(math.floor(modules.color.nearest(color, mapping)))
    write("\x1b[4" .. background .. "m")
    flush()
    return mapping[old]
  end
  function gpu.setForeground(color, isPaletteIndex)
    checkArg(1, color, "number")
    checkArg(2, isPaletteIndex, "boolean", "nil")
    if isPaletteIndex then
      return --TODO: Maybe?
    end
    local old = foreground
    foreground = tostring(math.floor(modules.color.nearest(color, mapping)))
    write("\x1b[3" .. foreground .. "m")
    flush()
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
  function gpu.getViewport()
    return termutils.getSize()
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
      tbuffer[y] = insertString(tbuffer[y], value, x)
      bbuffer[y] = insertString(bbuffer[y], background:rep(utf8.len(value)), x)
      fbuffer[y] = insertString(fbuffer[y], foreground:rep(utf8.len(value)), x)
      write("\x1b[" .. y .. ";" .. x .. "H" .. value)
    else
      write("\x1b[" .. y .. ";" .. x .. "H")
      value:gsub(".", function(c)
        write(c .. "\x1b[D\x1b[B")
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
    local ttbuf = {}
    local btbuf = {}
    local ftbuf = {}
    for i=1, h do
      ttbuf[i] = tbuffer[y + i - 1] and tbuffer[y + i - 1]:sub(x, x + w - 1) or (" "):rep(w)
      btbuf[i] = bbuffer[y + i - 1] and bbuffer[y + i - 1]:sub(x, x + w - 1) or background:rep(w)
      ftbuf[i] = fbuffer[y + i - 1] and fbuffer[y + i - 1]:sub(x, x + w - 1) or foreground:rep(w)
    end
    local bg = background
    local fg = foreground

    for i=1, h do
      local line, linex
      local lwrite = false
      for j=1, w do
        if btbuf[i]:sub(j,j) ~= bg then
          lwrite = true
        end
        if ftbuf[i]:sub(j,j) ~= fg then
          lwrite = true
        end
        if not line then linex = j end
        line = (line or "")
        if lwrite then
          local wx = (tx + linex)|0
          local wy = (ty + y + i - 1)|0
          write("\x1b[4" .. bg .. "m")
          write("\x1b[3" .. fg .. "m")
          write("\x1b[" .. wy .. ";" .. wx .. "H" .. line)
          tbuffer[wy] = insertString(tbuffer[wy], line, wx)
          bbuffer[wy] = insertString(bbuffer[wy], bg:rep(utf8.len(line)), wx)
          fbuffer[wy] = insertString(fbuffer[wy], fg:rep(utf8.len(line)), wx)
          bg = btbuf[i]:sub(j,j)
          fg = ftbuf[i]:sub(j,j)
          line = nil
          linex = nil
          lwrite = false
        end
        if not line then linex = j end
        line = (line or "") .. ttbuf[i]:sub(j,j)
      end
      if line then
        local wx = (tx + linex)|0
        local wy = (ty + y + i - 1)|0
        write("\x1b[4" .. bg .. "m")
        write("\x1b[3" .. fg .. "m")
        write("\x1b[" .. wy .. ";" .. wx .. "H" .. line)
        tbuffer[wy] = insertString(tbuffer[wy], line, wx)
        bbuffer[wy] = insertString(bbuffer[wy], bg:rep(utf8.len(line)), wx)
        fbuffer[wy] = insertString(fbuffer[wy], fg:rep(utf8.len(line)), wx)
        line = nil
        linex = nil
        lwrite = false
      end
    end
    write("\x1b[4" .. background .. "m")
    write("\x1b[3" .. foreground .. "m")
    flush()
    return true
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

  local screenAddr

  function gpu.getScreen()
    return screenAddr
  end

  write("\x1b[?25l") --Disable cursor
  local w, h = gpu.getResolution()
  prepareBuffers(w, h)
  gpu.setForeground(0xFFFFFF)
  gpu.setBackground(0x000000)

  modules.component.api.register(nil, "gpu", gpu)
  screenAddr = modules.component.api.register(nil, "screen", {getKeyboards = function() return {"TODO:SetThisUuid"} end}) --verry dummy screen, TODO: make it better, kbd uuid also in epoll.c
  modules.component.api.register("TODO:SetThisUuid", "keyboard", {})

  deadhooks[#deadhooks + 1] = function()
    write("\x1b[?25h") --Enable cursor on quit
  end
end

return textgpu
