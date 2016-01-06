local boot = {}

function boot.boot()
	local gpu = modules.component.api.proxy(modules.component.api.list("gpu", true)())
	local w, h = gpu.getResolution()
	print("r= " .. tostring(w) .. " " .. tostring(h))
	gpu.fill(0, 0, w, h, " ")
	print("LuPI L2 INIT")
	print("FIXME: boot stub")
	error("Unable to boot")
end

return boot
