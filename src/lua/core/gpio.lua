local gpio = {}

local fopen = native.fs_open
local fread = native.fs_read
local fwrite = native.fs_write
local fclose = native.fs_close
local fexists = native.fs_exists

local function _read(file)
  local fd = fopen(file, "r")
  if not fd then
    return nil, "Can't open " .. file .. " for reading"
  end
  local v = fread(fd, 1024)
  fclose(fd)
  return v
end

local function _write(file, value)
  local fd = fopen(file, "w")
  if not fd then
    return false, "Can't open " .. file .. " for writing"
  end
  fwrite(fd, value)
  fclose(fd)
  return true
end

gpio.register = function ()
  if not fexists("/sys/class/gpio") then
    return
  end
  local component = {}
  function component.pinMode(pin, mode) --TODO: return current mode if no new is specified
    checkArg(1, pin, "number")
    checkArg(2, mode, "string")
    pin = tostring(math.floor(pin))
    if mode ~= "in" and mode ~= "out" then
      return false, "Invalid mode string"
    end
    if not fexists("/sys/class/gpio/gpio" .. pin) then
      _write("/sys/class/gpio/export", pin)
    end
    if not _write("/sys/class/gpio/gpio" .. pin .. "/direction", mode) then
      return false, "Couldn't set pin mode"
    end
    return mode
  end

  function component.write(pin, value)
    checkArg(1, pin, "number")
    checkArg(2, pin, "boolean", "number", "nil")
    pin = tostring(math.floor(pin))
    value = (value == true or value > 0) and "1" or "0"
    if not fexists("/sys/class/gpio/gpio" .. pin) then
      return false, "Set pin mode first"
    end
    if not _write("/sys/class/gpio/gpio" .. pin .. "/value", value) then
      return false, "Couldn't set pin value"
    end
  end

  function component.read(pin)
    checkArg(1, pin, "number")
    pin = tostring(math.floor(pin))
    if not fexists("/sys/class/gpio/gpio" .. pin) then
      return false, "Set pin mode first"
    end
    return _read("/sys/class/gpio/gpio" .. pin .. "/value")
  end
  return modules.component.api.register(uuid, "gpio", component)
end

return gpio
