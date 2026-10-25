local mockCursor = {
  Y = 0,
  X = 1
}
local mockBuf = {
  GetActiveCursor = function()
    return mockCursor
  end,
  FileType = function() 
    return "c"
  end,
  AbsPath = "Desktop",
  Bytes = function() return "Hello World" end,
}

_G.import = function(module)
  if module == "os" then
      return {
          UserHomeDir = function()
              return "."
          end,
          Getwd = function() 
            return "."
          end,
          Getpid = function() 
            return 12345
          end
      }
  elseif module == "fmt" then 
    return {
      Sprintf = function() return mockBuf.AbsPath end
    }
  elseif module == "micro/util" then
    return {
      String = function(bytes) return "Hello World" end
    }
  elseif module == "micro/config" then
    return { ConfigDir = "." }
  end
end

local Lsp = require "lsp"
local server = {
  sendMessage = function(id, command, body) return end
}
local bp = {
  Buf = mockBuf
}

describe("test completion", function()
  it("completion request correct", function() 
    local s = spy.on(server, "sendMessage")
    local lsp = Lsp.new(server)

    assert.are.equal(lsp:completion(bp), 0)
    assert.spy(server.sendMessage).was_called_with(
      server, 0, "textDocument/completion", {
        textDocument = {
          uri = mockBuf.AbsPath,
        },
        position = {
          line = mockCursor.Y,
          character = mockCursor.X,
        },
      }
    )
  end) 

  it("didChange request correct", function() 
    local s = spy.on(server, "sendMessage")
    local lsp = Lsp.new(server)

    lsp:didChange(bp)
    assert.spy(server.sendMessage).was_called_with(
      server, nil, "textDocument/didChange", {
        textDocument = {
          uri = mockBuf.AbsPath,
          version = 0
        },
        contentChanges = {{ text = mockBuf.Bytes() }}
      }
    )
  end) 

  it("initialize request correct", function() 
    local s = spy.on(server, "sendMessage")
    local lsp = Lsp.new(server)

    lsp:initialize()
    assert.spy(server.sendMessage).was_called_with(
      server, 0, "initialize", match.is_table()
    )
    assert.spy(server.sendMessage).was_called_with(
      server, nil, "initialized", {}
    )
  end) 

  it("didOpen request correct", function() 
    local s = spy.on(server, "sendMessage")
    local lsp = Lsp.new(server)

    lsp:didOpen(bp)
    assert.spy(server.sendMessage).was_called_with(
      server, nil, "textDocument/didOpen", {
        textDocument = {
          uri = mockBuf.AbsPath,
          languageId = mockBuf.FileType(),
          version = 0,
          text = mockBuf.Bytes()
        }
      }
    )
  end) 

  it("shudown request correct", function() 
    local s = spy.on(server, "sendMessage")
    local lsp = Lsp.new(server)

    lsp:shutdown()
    assert.spy(server.sendMessage).was_called_with(
      server, nil, "shutdown", {}
    )
  end) 
end)