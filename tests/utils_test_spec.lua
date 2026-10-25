_G.import = function(module)
  if module == "os" then
    return {
        UserHomeDir = function()
            return "."
        end
    }
  elseif module == "micro/util" then
    return {
      String = function(...) return end
    }
  elseif module == "micro/config" then
    return { ConfigDir = "." }
  end
end

local utils = require "utils"

describe("test getLspArgs", function()
  it("returns jdtls args with -data flag", function()
    local args = utils.getLspArgs("jdtls", "/home/user/project")
    assert.are.equal(1, #args)
    assert.are.equal("-data /home/user/project", args[1])
  end)

  it("returns gopls debug flags", function()
    local args = utils.getLspArgs("gopls", "Desktop")
    assert.are.equal(4, #args)
    assert.are.equal("-logfile=auto", args[1])
    assert.are.equal("-debug=:0", args[2])
  end)

  it("returns empty table for unknown lsp", function()
    local args = utils.getLspArgs("other", "Desktop")
    assert.are.equal(0, #args)
  end)
end)

describe("test parseMessage", function() 
  it("parseMessage returns nil on invalid json", function() 
    assert.are.equal(utils.parseMessage("Content-Length: 8\r\n\r\nHelloWorld"), nil)
  end)
end)