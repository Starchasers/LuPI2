local boot = {}

function boot.boot()
	local gpu = modules.component.api.proxy(modules.component.api.list("gpu", true)())
	local w, h = gpu.getResolution()
	print("r= " .. tostring(w) .. " " .. tostring(h))
	gpu.fill(0, 0, w, h, " ")
	gpu.set(10, 5, "HHHHHHHHHHHHH")
	print("LuPI L2 INIT")
	print("FIXME: boot stub")
	native.sleep(1000000)
	error("Unable to boot")
end

return boot
