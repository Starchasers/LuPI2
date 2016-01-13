local computer = {}
local api = {}
computer.api = api

function computer.prepare( ... )
	
end

function api.pushSignal(...)
  --FIXME: ASAP: Implement
end

function api.pullSignal(timeout)
  if type(timeout) == "number" then
    native.sleep(timeout * 1000000);
  end
  --print(debug.traceback())
end

function api.uptime()
  return native.uptime()
end

function api.beep(freq, time)
  if not freq then freq = 1000 end
  if not time then time = 0.2 end
  native.beep(freq, time * 1000)
end

return computer