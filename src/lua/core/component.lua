local component = {}
local api = {}
local components = {}

component.api = api
component.components = components

local componentCallback = {
  __call = function(self, ...) return components[self.address].rawproxy[self.name](...) end,
  __tostring = function(self) return (components[self.address] ~= nil and components[self.address].doc[self.name] ~= nil) and components[self.address].doc[self.name] or "function" end
}

function component.prepare()
  print("Assembling initial component tree")
end

function api.register(address, ctype, proxy, doc)
  checkArg(2, ctype, "string")
  checkArg(3, proxy, "table")
  if type(address) ~= "string" then
    address = modules.random.uuid()
  end
  if components[address] ~= nil then
    return nil, "component already at address"
  end
  components[address] = {address = address, type = ctype, doc = doc or {}}
  components[address].rawproxy = proxy
  components[address].proxy = {}
  for k,v in pairs(proxy) do
    if type(v) == "function" then
      components[address].proxy[k] = setmetatable({name=k,address=address}, componentCallback)
    else
      components[address].proxy[k] = v
    end
  end
  modules.computer.api.pushSignal("component_added", address, ctype)
  return address
end

function api.unregister(address)
  checkArg(1, address, "string")
  if components[address] == nil then
    return nil, "no component at address"
  end
  local ctype = components[address].type
  components[address] = nil
  modules.computer.api.pushSignal("component_removed", address, ctype)
  return true
end

function api.doc(address, method)
  checkArg(1, address, "string")
  checkArg(2, method, "string")
  if not components[address] then
    error("No such component")
  end
  return components[address].doc[method]
end

function api.invoke(address, method, ...)
  checkArg(1, address, "string")
  checkArg(2, method, "string")
  if not components[address] then
    error("No such component")
  end
  if not components[address].rawproxy[method] then
    error("No such method: " .. tostring(components[address].type) .. "." .. tostring(method))
  end
  return components[address].rawproxy[method](...)
end

function api.list(filter, exact)
  checkArg(1, filter, "string", "nil")
  local list = {}
  for addr, c in pairs(components) do
    if not filter or ((exact and c.type or c.type:sub(1, #filter)) == filter) then
      list[addr] = c.type
    end
  end
  local key = nil
  return setmetatable(list, {__call=function()
        key = next(list, key)
        if key then
            return key, list[key]
        end
    end})
end

function api.methods(address)
  checkArg(1, address, "string")
  if not components[address] then
    return nil, "No such component"
  end
  local list = {}
  for k, v in pairs(components[address].rawproxy) do
    if type(v) == "function" then
      list[k] = true
    end
  end
  return list
end

function api.fields(address)
  checkArg(1, address, "string")
  if not components[address] then
    return nil, "No such component"
  end
  local list = {}
  for k, v in pairs(components[address].rawproxy) do
    if type(v) ~= "function" then
      list[k] = true
    end
  end
  return list
end

function api.proxy(address)
  if not components[address] then
    return nil, "No such component"
  end
  return components[address].proxy
end

function api.slot() --legacy
  return 0
end

function api.type(address)
  return components[address].type
end

return component
