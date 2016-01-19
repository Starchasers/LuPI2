local color = {}

function color.rgbToYuv(r, g, b)
  return (r * 0.299 + g * 0.587 + b * 0.114), (r * (-0.147) + g * (-0.289) + b * 0.436), (r * 0.615 + g * (-0.515) + b * (-0.1))
end

function color.rgbToHsv(r, g, b)
  local h, s, v
  local min, max, delta
  min = math.min(r, g, b)
  max = math.max(r, g, b)
  v = max
  delta = max - min
  if delta < 0.00001 then
    return 0, 0, v
  end
  if max ~= 0 then
    s = delta / max
  else
    s = 0
    h = -1
    return h, s, v
  end

  if r == max then
    h = (g - b) / delta
  elseif g == max then
    h = 2 + (b - r) / delta
  else
    h = 4 + (r - g) / delta
  end

  h = h * 60
  if h < 0 then h = h + 360 end
  return h, s, v
end

function color.hsvToRgb(h, s, v)
  local i, f, p, q, t
  if s ==  0 then
    return v, v, v
  end
  h = h / 60
  i = math.floor(h)
  f = h - i
  p = v * (1 - s)
  q = v * (1 - s * f)
  t = v * (1 - s * (1 - f))
  if i == 0 then return v, t, p end
  if i == 1 then return q, v, p end
  if i == 2 then return p, v, t end
  if i == 3 then return p, q, v end
  if i == 4 then return t, p, v end
  return v, p, q
end

function color.nearest(to, colors)
  local lowest = math.huge
  local lowestk = nil
  local th, ts, tv = color.rgbToYuv((to & 0xFF0000) >> 16, (to & 0xFF00) >> 8, to & 0xFF)
  for k, col in pairs(colors) do
    if col == to then
      return k
    end
    local h, s, v = color.rgbToYuv((col & 0xFF0000) >> 16, (col & 0xFF00) >> 8, col & 0xFF)
    local d = math.abs(h - th) + math.abs(s - ts) + math.abs(v - tv)
    if d < lowest then
      lowest = d
      lowestk = k
    end
  end
  return lowestk
end

return color
