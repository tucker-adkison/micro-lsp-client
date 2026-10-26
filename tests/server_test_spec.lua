local shell = {
	JobSend = function() end,
	JobSpawn = function() end,
}

rawset(_G, "import", function(module)
	if module == "micro" then
		return {
			Log = function() end,
		}
	elseif module == "os" then
		return {
			UserHomeDir = function()
				return "."
			end,
		}
	elseif module == "micro/shell" then
		return shell
	elseif module == "micro/config" then
		return { ConfigDir = "." }
	end
end)

local json = require("json")
local Server = require("server")

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
		assert.spy(s).was.called_with(server.server, "Content-Length: " .. #content .. "\r\n\r\n" .. content)
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
		assert.spy(s).was.called_with(server.server, "Content-Length: " .. #content .. "\r\n\r\n" .. content)
	end)
end)

describe("test startServer", function()
	it("startServer works as expected for each LSP", function()
		local server = Server.new()
		local s = spy.on(shell, "JobSpawn")
		local onStderr = function() end
		local onExit = function() end

		server:startServer("jdtls", {}, onStderr, onExit)
		-- the stdout callback is the server's own reader, so match any function
		assert.spy(s).was.called_with("jdtls", {}, match.is_function(), onStderr, onExit, {})
	end)
end)

describe("test read", function()
	it("read skips a message with invalid json", function()
		local server = Server.new()
		local s = spy.on(server, "dispatch")

		local valid = json.encode({ jsonrpc = "2.0", id = 1, result = {} })
		server:read("Content-Length: 10\r\n\r\nHelloWorld" .. "Content-Length: " .. #valid .. "\r\n\r\n" .. valid)

		assert.spy(s).was.called(1)
		assert.spy(s).was.called_with(server, { jsonrpc = "2.0", id = 1, result = {} })
		assert.are.equal("", server.readBuffer)
	end)
end)
