local d = {}

local function getCallerInfo()
  local caller = debug.getinfo(3)
  return caller.short_src .. ":".. caller.currentline
end

function d.hook()
  local sb = modules.sandbox

  local otb = sb.debug.traceback
  function sb.debug.traceback(m, l, ...)
    local s = otb(m, l and (type(l) == "number" and (l + 1) or l) or 2, ...)
    native.log("Native traceback requested for:")
    native.log(s)
    return s --TODO: check if there actually is only one return value
  end

  local oload = sb.load
  function sb.load(ld, source, mode, env)
    native.log("load from " .. getCallerInfo() .. ", loading \"" .. (source or type(ld)) .. "\"")
    return oload(ld, source, mode, env)
  end
end

return d