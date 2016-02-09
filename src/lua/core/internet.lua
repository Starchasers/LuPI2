local internet = {}

function internet.start()
  local component = {}

  --Legacy
  function component.isHttpEnabled()
    return true
  end

  function component.isTcpEnabled()
    return true
  end

  --Old TCP
  function component.connect(address, port)
    checkArg(1, address, "string")
    checkArg(2, port, "number", "nil")
    if not port then
      address, port = address:match("(.+):(.+)")
      port = tonumber(port)
    end

    local sfd, reason = net.open(address, port)
    local closed = false
    return {
      finishConnect = function()
        if not sfd then
          error(reason)
        end
        return true
      end,
      read = function(n)
        if closed then return nil, "connection lost" end
        n = n or 65535
        checkArg(1, n, "number")
        local data = net.read(sfd, n)
        if not data then
          closed = true
          native.fs_close(sfd)
          return nil, "connection lost"
        end
        return data
      end,
      write = function(data)
        if closed then return nil, "connection lost" end
        checkArg(1, data, "string")
        local written = net.write(sfd, data)
        if not written then
          closed = true
          native.fs_close(sfd)
          return nil, "connection lost"
        end
        return written
      end,
      close = function()
        closed = true
        native.fs_close(sfd)
      end
    }
  end

  function component.request(url, post)
    local host = url:match("http://([^/]+)")
    if not host then io.stderr:write("LERR" .. url .. "\n") end
    local socket = component.connect(host, 80)
    if socket.finishConnect() then
      socket.write("GET " .. url .. " HTTP/1.1\r\nHost: " .. host .. "\r\nConnection: close\r\n\r\n")
    end

    local stream = {}

    function stream:seek()
      return nil, "bad file descriptor"
    end

    function stream:write()
      return nil, "bad file descriptor"
    end

    function stream:read(n)
      if not socket then
        return nil, "connection is closed"
      end
      return socket.read(n)
    end

    function stream:close()
      if socket then
        socket.close()
        socket = nil
      end
    end

    local connection = modules.buffer.new("rb", stream)
    connection.readTimeout = 10
    local header = nil

    --TODO: GC close
    --TODO: Chunked support

    local finishConnect = function() --Read header
      header = {}
      header.status = connection:read("*l"):match("HTTP/.%.. (%d+) (.+)\r")
      while true do
        local line = connection:read("*l")
        if not line or line == "" or line == "\r" then
          break
        end
        local k, v = line:match("([^:]+): (.+)\r")
        header[k:lower()] = v
      end
      header["content-length"] = tonumber(header["content-length"])
    end

    return {
      finishConnect = finishConnect,
      read = function(n)
        if not header then
          finishConnect()
        end
        if header["content-length"] < 1 then
          return nil
        end
        checkArg(1, n, "number", "nil")
        n = n or math.min(8192, header["content-length"])
        local res = connection:read(n)
        header["content-length"] = header["content-length"] - #res
        return res
      end,
      close = function()
        connection:close()
      end
    }
  end

  modules.component.api.register(nil, "internet", component)
end

return internet
