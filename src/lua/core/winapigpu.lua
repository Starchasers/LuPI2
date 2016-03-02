local wingpu = {}

function wingpu.start()
  local s, reason = winapigpu.open()
  if not s then
    lprint("Couldn't open window: " .. tostring(reason))
  end
  return s
end

return wingpu
