local component = {}
local api = {}
local components = {}

component.api = api
component.components = components

local componentCallback = {
  __call = function(self, ...) return components[self.address].rawproxy[self.name](...) end,
  __tostring = function(self) return (components[self.address] ~= nil and components[self.address].doc[self.name] ~= nil) and components[self.address].doc[self.name] or "function" end
}

--Debug only
local start = native.uptime()
local last = native.uptime()

if native.debug then
  componentCallback.__call = function(self, ...)
    local t = {}
    for k,v in pairs({...}) do
      if type(v) == "string" then
        v = "\"" .. v .. "\""
      end
      t[k] = tostring(v)
    end

    local caller = debug.getinfo(2)
    local msg = tostring((native.uptime() - start) / 1000) .. " [+" .. native.uptime() - last .. "] " .. caller.short_src .. ":".. caller.currentline .. " > invoke(" .. self.address .. "): "
      .. components[self.address].type ..  "." .. self.name
      .. "(" .. table.concat(t, ", ") .. ")"

    native.log(msg)
    last = native.uptime()
    return components[self.address].rawproxy[self.name](...)
  end
end

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
  if native.debug then
    local caller = debug.getinfo(2)
    local msg = caller.short_src .. ":".. caller.currentline .. " > component.register(" .. address .. ", " .. ctype .. ")"
    native.log(msg)
  end
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
  if native.debug then  --TODO: This may generate little performance hit
    local t = {}
    for k,v in pairs({...}) do
      if type(v) == "string" then
        v = "\"" .. v .. "\""
      end
      t[k] = tostring(v)
    end
    
    local caller = debug.getinfo(2)
    local msg = tostring((native.uptime() - start) / 1000) .. " [+" .. native.uptime() - last .. "] " .. caller.short_src .. ":".. caller.currentline .. " > c.invoke(" .. address .. "): "
      .. components[address].type ..  "." .. method
      .. "(" .. table.concat(t, ", ") .. ")"
    native.log(msg)
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
