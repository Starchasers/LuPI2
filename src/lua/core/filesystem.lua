--Native side at lnative.c

local filesystem = {}

local function segments(path)
  path = path:gsub("\\", "/")
  repeat local n; path, n = path:gsub("//", "/") until n == 0
  local parts = {}
  for part in path:gmatch("[^/]+") do
    table.insert(parts, part)
  end
  local i = 1
  while i <= #parts do
    if parts[i] == "." then
      table.remove(parts, i)
    elseif parts[i] == ".." then
      table.remove(parts, i)
      i = i - 1
      if i > 0 then
        table.remove(parts, i)
      else
        i = 1
      end
    else
      i = i + 1
    end
  end
  return parts
end

local function canonical(path)
  local result = table.concat(segments(path), "/")
  if string.sub(path, 1, 1) == "/" then
    return "/" .. result
  else
    return result
  end
end

local function concat(pathA, pathB, ...)
  checkArg(1, pathA, "string")
  checkArg(2, pathB, "string", "nil")
  local function _concat(n, a, b, ...)
    if not b then
      return a
    end
    checkArg(n, b, "string")
    return _concat(n + 1, a .. "/" .. b, ...)
  end
  return canonical(_concat(2, pathA, pathB, ...))
end

function filesystem.register(basePath, uuid)
  checkArg(1, basePath, "string")

  if not native.fs_exists(basePath) then
    native.fs_mkdir(basePath)
  end
  if not native.fs_isdir(basePath) then
    error("Filesystem root is not a directory!")
  end
  local function realpath(path)
    checkArg(1, path, "string")
    return concat(basePath, path)
  end

  --TODO: checkArg all
  local fs = {}
  function fs.spaceUsed()
    return native.fs_spaceUsed(basePath)
  end
  function fs.open(path, mode)
    checkArg(1, path, "string")
    checkArg(2, path, "string", "nil")
    local m = "r"
    mode = mode or ""
    if mode:match("a") then m = "a"
    elseif mode:match("w") then m = "w" end
    local fd = native.fs_open(realpath(path), m)
    if not fd then
      return nil, path
    end
    return fd
  end
  function fs.seek(handle, whence, offset) --TODO: Test
    checkArg(1, handle, "number")
    checkArg(2, whence, "string")
    checkArg(3, offset, "number")
    local w = 0
    if whence == "cur" then w = 0
    elseif whence == "set" then w = 1
    elseif whence == "end" then w = 2
    else error("Invalid whence") end
    return native.fs_seek(handle, w, offset or 0)
  end
  function fs.makeDirectory(path) --TODO: check if creates parrent dirs
    checkArg(1, path, "string")
    return native.fs_mkdir(realpath(path))
  end
  function fs.exists(path)
    checkArg(1, path, "string")
    return native.fs_exists(realpath(path))
  end
  function fs.isReadOnly()
    return false --TODO: Implement
  end
  function fs.write(handle, value) --TODO: check behaviour on invalid FDs
    checkArg(1, handle, "number")
    checkArg(2, value, "string")
    return native.fs_write(handle, value)
  end
  function fs.spaceTotal()
    return native.fs_spaceTotal(basePath)
  end
  function fs.isDirectory(path)
    checkArg(1, path, "string")
    return native.fs_isdir(realpath(path))
  end
  function fs.rename(from, to)
    checkArg(1, from, "string")
    checkArg(2, to, "string")
    return native.fs_rename(realpath(from), realpath(to))
  end
  function fs.list(path)
    checkArg(1, path, "string")
    return native.fs_list(realpath(path)) --TODO: Test, check if dirs get / at end
  end
  function fs.lastModified(path)
    checkArg(1, path, "string")
    return native.fs_lastModified(realpath(path))
  end
  function fs.getLabel()
    return basePath --TODO: Implement, use real labels
  end
  function fs.remove(path) --TODO: TEST!!
    checkArg(1, path, "string")
    return native.fs_remove(realpath(path))
  end
  function fs.close(handle)
    checkArg(1, handle, "number")
    return native.fs_close(handle)
  end
  function fs.size(path)
    checkArg(1, path, "string")
    return native.fs_size(realpath(path))
  end
  function fs.read(handle, count) --FIXME: Hudgeread, fix in general
    if count == math.huge then
      count = 4294967295
    end
    checkArg(1, handle, "number")
    checkArg(2, count, "number")
    return native.fs_read(handle, count)
  end
  function fs.setLabel(value)
    checkArg(1, value, "number")
    return value --TODO: Implement, use real labels
  end
  return modules.component.api.register(uuid, "filesystem", fs)
end

return filesystem