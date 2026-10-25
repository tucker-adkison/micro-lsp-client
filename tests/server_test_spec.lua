local shell = {
  JobSend = function(server, content) return end,
  JobSpawn = function(lsp, args, onStdout, onStderr, onExit, dic) return end
}

_G.import = function(module)
  if module == "micro" then
    return {
      Log = function(...) return end
    } 
  elseif module == "os" then
    return {
        UserHomeDir = function()
            return "."
        end
    }
  elseif module == "micro/shell" then
    return shell
  elseif module == "micro/config" then
    return { ConfigDir = "." }
  end
end

local json = require "json"
local utils = require "utils"
local Server = require "server"

describe("test sendMessage", function()
  it("sendMessage request correct with id", function() 
    local server = Server.new()
    local s = spy.on(shell, "JobSend")

    local content = json.encode({
      jsonrpc = "2.0",
      method = "initialize",
      params = {},
      id = 1,
    })

    server:sendMessage(1, "initialize", {})
    assert.spy(shell.JobSend).was_called_with(
      sever, "Content-Length: " .. #content .. "\r\n\r\n" .. content
    )
  end) 

  it("sendMessage request correct without id", function() 
    local server = Server.new()
    local s = spy.on(shell, "JobSend")

    local content = json.encode({
      jsonrpc = "2.0",
      method = "initialize",
      params = {},
    })

    server:sendMessage(nil, "initialize", {})
    assert.spy(shell.JobSend).was_called_with(
      sever, "Content-Length: " .. #content .. "\r\n\r\n" .. content
    )
  end) 

end)

describe("test startServer", function() 
  it("startServer works as expected for each LSP", function() 
    local server = Server.new()
    local s = spy.on(shell, "JobSpawn")
     
    server:startServer("jdtls", {}, {}, {}, {})
    assert.spy(shell.JobSpawn).was_called_with(
      "jdtls", {}, {}, {}, {}, {}
    )
  end) 
end)