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

function api.pushSignal(...)
  signalQueue[#signalQueue + 1] = {...}
end

function api.pullSignal(timeout)
  if signalQueue[1] then return table.remove(signalQueue, 1) end
  if type(timeout) == "number" then
    native.sleep(timeout * 1000000);
  end
  if signalQueue[1] then return table.remove(signalQueue, 1) end
  --print(debug.traceback())
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

return computer