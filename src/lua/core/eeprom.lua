local eeprom = {}
local default = moduleCode["eepromDefault"]
local size = 4092
local dataSize = 256

function eeprom.register()
  local component = {}
  function component.get()
    local h = io.open("usereeprom.lua", "r")
    if h then
      local data = h:read("*a")
      h:close()
      return data
    else
      return default
    end
  end
  function component.set(data)
    checkArg(1, data, "string")
    data = data:sub(1, size)
    local h = io.open("usereeprom.lua", "w")
    if not h then
      error("Critical: Cannot open EERPOM file")
    end
    h:write(data)
    h:close()
  end
  function component.getLabel()
    return "LUA BIOS"
  end
  function component.setLabel()
    return nil, "Cannot set label"
  end
  function component.getSize()
    return size
  end
  function component.getData()
    local h = io.open("usereepromdata.lua", "r")
    if h then
      local data = h:read("*a")
      h:close()
      return data
    else
      return default
    end
  end
  function component.setData(data)
    checkArg(1, data, "string")
    data = data:sub(1, dataSize)
    local h = io.open("usereepromdata.lua", "w")
    if not h then
      error("Critical: Cannot open EERPOM file")
    end
    h:write(data)
    h:close()
  end

  --FIXME: Implement
  function component.getChecksum()
    error("Method stub")
  end
  function component.makeReadonly()
    return false, "Method stub"
  end
  modules.component.api.register(nil, "eeprom", component)
end

return eeprom
