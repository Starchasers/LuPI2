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

local usub
local function insertString(main, sub, at)
  checkArg(1, main, "string")
  checkArg(2, sub, "string")
  checkArg(3, at, "number")

  return usub(main, 1, at - 1)
    .. sub .. usub(main, at + (utf8.len(sub) or 0))
end

function textgpu.start()
  usub = modules.sandbox.unicode.sub
  local _height = 0
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
    
    return tbuffer[y]:sub(x,x), mapping[fbuffer[y]:sub(x,x)], mapping[bbuffer[y]:sub(x,x)]
  end
  function gpu.set(x, y, value, vertical)
    checkArg(1, x, "number")
    checkArg(2, y, "number")
    checkArg(3, value, "string")
    checkArg(4, vertical, "boolean", "nil")
    x = math.floor(x)
    y = math.floor(y)
    if not vertical then
      if not tbuffer[y] then
        native.log("GPU Set failed: under buffer")
        return false
      end
      tbuffer[y] = insertString(tbuffer[y], value, x)
      bbuffer[y] = insertString(bbuffer[y], background:rep(utf8.len(value)), x)
      fbuffer[y] = insertString(fbuffer[y], foreground:rep(utf8.len(value)), x)
      write("\x1b[" .. y .. ";" .. x .. "H" .. value)
    else
      --TODO: Buffers!
      write("\x1b[" .. y .. ";" .. x .. "H")
      value:gsub("([%z\1-\127\194-\244][\128-\191]*)", function(c)
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
      if i + y - 2 <= _height and i + y > 1 then
        ttbuf[i] = tbuffer[y + i - 1] and usub(tbuffer[y + i - 1], x, x + w - 1) or (" "):rep(w)
        btbuf[i] = bbuffer[y + i - 1] and bbuffer[y + i - 1]:sub(x, x + w - 1) or background:rep(w)
        ftbuf[i] = fbuffer[y + i - 1] and fbuffer[y + i - 1]:sub(x, x + w - 1) or foreground:rep(w)
      else
        ttbuf[i] = (" "):rep(w)
        btbuf[i] = background:rep(w)
        ftbuf[i] = foreground:rep(w)
      end
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
          local wx = (tx + x + linex - 1)|0
          local wy = (ty + y + i - 1)|0
          if tbuffer[wy] then
            write("\x1b[4" .. bg .. "m\x1b[3" .. fg .. "m\x1b[" .. wy .. ";" .. wx .. "H" .. line)
            tbuffer[wy] = insertString(tbuffer[wy], line, wx)
            bbuffer[wy] = insertString(bbuffer[wy], bg:rep(utf8.len(line)), wx)
            fbuffer[wy] = insertString(fbuffer[wy], fg:rep(utf8.len(line)), wx)
          end
        
          bg = btbuf[i]:sub(j,j)
          fg = ftbuf[i]:sub(j,j)
          line = nil
          linex = nil
          lwrite = false
        end
        if not line then linex = j end
        line = (line or "") .. usub(ttbuf[i], j,j)
      end
      if line then
        local wx = (tx + x + linex - 1)|0
        local wy = (ty + y + i - 1)|0
        if tbuffer[wy] then
          write("\x1b[4" .. bg .. "m\x1b[3" .. fg .. "m\x1b[" .. wy .. ";" .. wx .. "H" .. line)
          tbuffer[wy] = insertString(tbuffer[wy], line, wx)
          bbuffer[wy] = insertString(bbuffer[wy], bg:rep(utf8.len(line)), wx)
          fbuffer[wy] = insertString(fbuffer[wy], fg:rep(utf8.len(line)), wx)
        end
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
    ch = usub(ch, 1, 1):rep(math.floor(w))
    for i=1, h do
      if i + y - 1 <= _height and i + y > 1 then
        gpu.set(x, y + i - 1, ch)
      end
    end
    return true
  end

  local screenAddr

  function gpu.getScreen()
    return screenAddr
  end

  if not termutils.init() then
    return nil, "Cannot initialize terminal based gpu"
  end
  write("\x1b[?25l") --Disable cursor
  local w, h = gpu.getResolution()
  _height = h
  prepareBuffers(w, h)
  gpu.setForeground(0xFFFFFF)
  gpu.setBackground(0x000000)

  local gpuaddr = modules.component.api.register(nil, "gpu", gpu)
  screenAddr = modules.component.api.register(nil, "screen", {getKeyboards = function() return {"TODO:SetThisUuid"} end}) --verry dummy screen, TODO: make it better, kbd uuid also in epoll.c
  modules.component.api.register("TODO:SetThisUuid", "keyboard", {})

  deadhooks[#deadhooks + 1] = function()
    write("\x1b[?25h\x1b[" .. ((h-1)|0) .. ";1H") --Enable cursor on quit
    io.flush()
    termutils.restore()
  end

  return gpuaddr
end

return textgpu
