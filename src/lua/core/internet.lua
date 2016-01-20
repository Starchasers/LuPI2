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
    checkArg(2, port, "number")

    local sfd, reason = net.open(address, tostring(port))
    return {
      finishConnect = function()
        if not sfd then
          return false, reason
        end
        return true
      end,
      read = function(n)
        n = n or 65535
        checkArg(1, n, "number")
        return net.read(sfd, n)
      end,
      write = function(data)
        checkArg(1, data, "string")
        return net.write(sfd, data)
      end,
      close = function()
        native.close(sfd)
      end
    }
  end

  modules.component.api.register(nil, "internet", component)
end

return internet
