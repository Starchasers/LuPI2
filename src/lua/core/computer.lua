local computer = {}
local api = {}
computer.api = api

function computer.prepare( ... )
	
end

function api.pushSignal(...)
  --FIXME: ASAP: Implement
end

function api.beep(freq, time)
	if not freq then freq = 1000 end
	if not time then time = 0.2 end
	native.beep(freq, time * 1000)
end

return computer