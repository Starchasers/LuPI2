local computer = {}
local api = {}
computer.api = api

--computer.tmp - set in init.lua

function computer.prepare( ... )
	
end

function api.address()
  return modules.address
end

local signalQueue = {}
computer.signalTransformers = setmetatable({}, {__index = function(t, k)
  return function(...)
    return ...
  end
end})

-----
--TODO: Move this out
local keymap = {
  [48] = 0x2,
  [49] = 0x3,
  [50] = 0x4,
  [51] = 0x5,
  [52] = 0x6,
  [53] = 0x7,
  [54] = 0x8,
  [55] = 0x9,
  [56] = 0xA,
  [57] = 0xB,

  [0x40 + 0x01] = 0x1E,
  [0x40 + 0x02] = 0x30,
  [0x40 + 0x04] = 0x2E,
  [0x40 + 0x05] = 0x20,
  [0x40 + 0x06] = 0x12,
  [0x40 + 0x07] = 0x21,
  [0x40 + 0x08] = 0x22,
  [0x40 + 0x09] = 0x23,
  [0x40 + 0x0A] = 0x17,
  [0x40 + 0x0B] = 0x24,
  [0x40 + 0x0C] = 0x25,
  [0x40 + 0x0D] = 0x26,
  [0x40 + 0x0E] = 0x32,
  [0x40 + 0x0F] = 0x31,
  [0x40 + 0x11] = 0x18,
  [0x40 + 0x12] = 0x19,
  [0x40 + 0x13] = 0x10,
  [0x40 + 0x14] = 0x13,
  [0x40 + 0x15] = 0x1F,
  [0x40 + 0x16] = 0x14,
  [0x40 + 0x17] = 0x16,
  [0x40 + 0x18] = 0x2F,
  [0x40 + 0x19] = 0x11,
  [0x40 + 0x1A] = 0x2D,
  [0x40 + 0x1B] = 0x15,
  [0x40 + 0x1C] = 0x2C,

  [0x60 + 0x01] = 0x1E,
  [0x60 + 0x02] = 0x30,
  [0x60 + 0x04] = 0x2E,
  [0x60 + 0x05] = 0x20,
  [0x60 + 0x06] = 0x12,
  [0x60 + 0x07] = 0x21,
  [0x60 + 0x08] = 0x22,
  [0x60 + 0x09] = 0x23,
  [0x60 + 0x0A] = 0x17,
  [0x60 + 0x0B] = 0x24,
  [0x60 + 0x0C] = 0x25,
  [0x60 + 0x0D] = 0x26,
  [0x60 + 0x0E] = 0x32,
  [0x60 + 0x0F] = 0x31,
  [0x60 + 0x11] = 0x18,
  [0x60 + 0x12] = 0x19,
  [0x60 + 0x13] = 0x10,
  [0x60 + 0x14] = 0x13,
  [0x60 + 0x15] = 0x1F,
  [0x60 + 0x16] = 0x14,
  [0x60 + 0x17] = 0x16,
  [0x60 + 0x18] = 0x2F,
  [0x60 + 0x19] = 0x11,
  [0x60 + 0x1A] = 0x2D,
  [0x60 + 0x1B] = 0x15,
  [0x60 + 0x1C] = 0x2C,

  [13] = 28, --Return key
  [127] = 14, --backspace
  [9] = 15, --Tab

}

local asciitr = {
  [127] = 8,
}

function computer.signalTransformers.key_down(s, a, ascii, key, user)
  if key ~= -1 then
    return s, a, ascii, key, user
  end
  return s, a, asciitr[ascii] or ascii, keymap[ascii] or key, user
end

function computer.signalTransformers.key_up(s, a, ascii, key, user)
  if key ~= -1 then
    return s, a, ascii, key, user
  end
  return s, a, asciitr[ascii] or ascii, keymap[ascii] or key, user
end

-----

function api.pushSignal(s, ...)
  signalQueue[#signalQueue + 1] = {computer.signalTransformers[s](s, ...)}
end

function api.pullSignal(timeout)
  --native.log("pullSignal for " .. (timeout or " infinite") .. " s")
  if signalQueue[1] then
    native.log("pullSignal direct: " .. signalQueue[1][1])
    return table.unpack(table.remove(signalQueue, 1))
  end
  local timeoutuptime = math.huge

  if not timeout then
    timeout = -1
  else
    if timeout < 0 then timeout = 0 end
    timeout = timeout * 1000
    timeoutuptime = native.uptime() + timeout
  end
  local nevts = 0
  repeat
    nevts = native.pull(timeout)
  until nevts > 0 or native.uptime() > timeoutuptime
  if signalQueue[1] then
    native.log("pullSignal native: " .. signalQueue[1][1])
    return table.unpack(table.remove(signalQueue, 1))
  end
  --native.log("pullSignal timeout")
end

function api.uptime()
  return native.uptime() / 1000
end

function api.beep(freq, time)
  if not freq then freq = 1000 end
  if not time then time = 0.2 end
  native.beep(freq, time * 1000)
end

function api.tmpAddress()
  return computer.tmp
end


function api.freeMemory()
  return native.freeMemory()
end

function api.totalMemory()
  return native.totalMemory()
end

function api.shutdown()
  --TODO: Longjmp to init somehow?
  print("Running shutdown hooks")
  for k, hook in ipairs(deadhooks) do
    local state, cause = pcall(hook)
    if not state then
      print("Shutdown hook with following error:")
      print(cause)
    end
  end
  print("Hooks executed: " .. #deadhooks)

  os.exit(0)
end

return computer