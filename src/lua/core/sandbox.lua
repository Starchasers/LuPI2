local sandbox

local l_wlen = function(text)
      checkArg(1, text, "string")
      local i = 0
      for p, c in utf8.codes(text) do
        i = i + native.wcwidth(c)
      end
      return utf8.len(text)
    end

sandbox = {
  assert = assert,
  dofile = nil,
  error = error,
  _G = nil,
  getmetatable = function(t)
    if type(t) == "string" then -- don't allow messing with the string mt
      return nil
    end
    local result = getmetatable(t)
    return result
  end,
  ipairs = ipairs,
  load = function(ld, source, mode, env)
    --Should we allow bytecode?
    return load(ld, source, mode, env or sandbox)
  end,
  loadfile = nil,
  next = next,
  pairs = pairs,
  pcall = pcall,
  print = nil,
  rawequal = rawequal,
  rawget = rawget,
  rawlen = rawlen,
  rawset = rawset,
  select = select,
  setmetatable = setmetatable,
  tonumber = tonumber,
  tostring = tostring,
  type = type,
  _VERSION = _VERSION,
  xpcall = xpcall,
  coroutine = {
    create = coroutine.create,
    resume = coroutine.resume,
    running = coroutine.running,
    status = coroutine.status,
    wrap = coroutine.wrap,
    yield = coroutine.yield,
    isyieldable = coroutine.isyieldable
  },
  string = {
    byte = string.byte,
    char = string.char,
    dump = string.dump,
    find = string.find,
    format = string.format,
    gmatch = string.gmatch,
    gsub = string.gsub,
    len = string.len,
    lower = string.lower,
    match = string.match,
    rep = string.rep,
    reverse = string.reverse,
    sub = string.sub,
    upper = string.upper,
    -- Lua 5.3.
    pack = string.pack,
    unpack = string.unpack,
    packsize = string.packsize
  },
  table = {
    concat = table.concat,
    insert = table.insert,
    pack = table.pack,
    remove = table.remove,
    sort = table.sort,
    unpack = table.unpack,
    -- Lua 5.3.
    move = table.move
  },
  math = {
    abs = math.abs,
    acos = math.acos,
    asin = math.asin,
    atan = math.atan,
    atan2 = math.atan2,
    ceil = math.ceil,
    cos = math.cos,
    cosh = math.cosh,
    deg = math.deg,
    exp = math.exp,
    floor = math.floor,
    fmod = math.fmod,
    frexp = math.frexp,
    huge = math.huge,
    ldexp = math.ldexp,
    log = math.log,
    max = math.max,
    min = math.min,
    modf = math.modf,
    pi = math.pi,
    pow = math.pow,
    rad = math.rad,
    random = math.random,
    randomseed = math.randomseed,
    sin = math.sin,
    sinh = math.sinh,
    sqrt = math.sqrt,
    tan = math.tan,
    tanh = math.tanh,
    -- Lua 5.3.
    maxinteger = math.maxinteger,
    mininteger = math.mininteger,
    tointeger = math.tointeger,
    type = math.type,
    ult = math.ult
  },
  io = nil,

  os = {
    clock = os.clock,
    date = os.date,
    difftime = function(t2, t1)
      return t2 - t1
    end,
    execute = nil,
    exit = nil,
    remove = nil,
    rename = nil,
    time = function(table)
      checkArg(1, table, "table", "nil")
      return os.time(table)
    end,
    tmpname = nil,
    sleep = function(time)
      checkArg(1, time, "number")
      native.sleep(time * 1000000)
    end
  },
  debug = { --TODO: Consider expanding
    getinfo = function(...)
      local result = debug.getinfo(...)
      if result then
        return {
          source = result.source,
          short_src = result.short_src,
          linedefined = result.linedefined,
          lastlinedefined = result.lastlinedefined,
          what = result.what,
          currentline = result.currentline,
          nups = result.nups,
          nparams = result.nparams,
          isvararg = result.isvararg,
          name = result.name,
          namewhat = result.namewhat,
          istailcall = result.istailcall
        }
      end
    end,
    traceback = debug.traceback
  },
  utf8 = {
    char = utf8.char,
    charpattern = utf8.charpattern,
    codes = utf8.codes,
    codepoint = utf8.codepoint,
    len = utf8.len,
    offset = utf8.offset
  },
  unicode = {
    char = utf8.char,
    charWidth = function(c)
      return l_wlen(c)
    end,
    isWide = function(c)
      return l_wlen(c) > 1
    end,
    len = utf8.len,
    lower = function(text)
      checkArg(1, text, "string")
      local s = ""
      for p, c in utf8.codes(text) do
        s = s .. utf8.char(native.towlower(c))
      end
      return s
    end,
    upper = function(text)
      checkArg(1, text, "string")
      local s = ""
      for p, c in utf8.codes(text) do
        s = s .. utf8.char(native.towupper(c))
      end
      return s
    end,
    reverse = function(text)
      checkArg(1, text, "string")
      local s = ""
      for p, c in utf8.codes(text) do
        s = utf8.char(c) .. s
      end
      return s
    end,
    sub = function(s, i, j)
      checkArg(1, s, "string")
      i = i or 1
      j = j or math.maxinteger
      if i<1 or j<1 then
        local n = utf8.len(s)
        if not n then return nil end
        if i<0 then i = n+1+i end
        if j<0 then j = n+1+j end
        if i<0 then i = 1 elseif i>n then i = n end
        if j<0 then j = 1 elseif j>n then j = n end
      end
      if j<i then return "" end
      i = utf8.offset(s,i) or math.maxinteger
      j = utf8.offset(s,j+1) or math.maxinteger
      if i and j then return s:sub(i,j-1)
        elseif i then return s:sub(i)
        else return ""
      end
    end,
    wlen = l_wlen,
    wtrunc = function(s, l)
      checkArg(1, s, "string")
      checkArg(2, l, "number")
      local width = 0
      local text = ""
      for p, c in utf8.codes(s) do
        if width < l then
          width = width + native.wcwidth(c)
          if width < l then
            text = text .. utf8.char(c)
          end
        end
      end
      return text
    end,
  },
  checkArg = checkArg,
  og = _G
}

sandbox._G = sandbox
sandbox.component = modules.component.api or error("No component API")
sandbox.computer = modules.computer.api or error("No computer API")

return sandbox
