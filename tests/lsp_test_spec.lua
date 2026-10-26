local mockCursor = {
	Y = 0,
	X = 1,
}
local mockBuf = {
	GetActiveCursor = function()
		return mockCursor
	end,
	FileType = function()
		return "c"
	end,
	AbsPath = "Desktop",
	Bytes = function()
		return "Hello World"
	end,
}

rawset(_G, "import", function(module)
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
			end,
		}
	elseif module == "fmt" then
		return {
			Sprintf = function(_, _)
				return mockBuf.AbsPath
			end,
		}
	elseif module == "micro/util" then
		return {
			String = function(_)
				return "Hello World"
			end,
		}
	elseif module == "micro/config" then
		return { ConfigDir = "." }
	end
end)

local Lsp = require("lsp")
local server = {
	request = function()
		return 7
	end,
	notify = function() end,
}

describe("test completion", function()
	it("completion request correct", function()
		local s = spy.on(server, "request")
		local lsp = Lsp.new(server)

		lsp:completion(mockBuf, function() end)
		assert.are.equal(lsp.lastCompletionId, 7)
		assert.spy(s).was.called_with(server, "textDocument/completion", {
			textDocument = {
				uri = mockBuf.AbsPath,
			},
			position = {
				line = mockCursor.Y,
				character = mockCursor.X,
			},
		}, match.is_function())
	end)

	it("didChange request correct", function()
		local s = spy.on(server, "notify")
		local lsp = Lsp.new(server)
		-- didChange only sends for an open document whose text changed
		lsp.documents[mockBuf.AbsPath] = { version = 1, text = "old text" }

		lsp:didChange(mockBuf)
		assert.spy(s).was.called_with(server, "textDocument/didChange", {
			textDocument = {
				uri = mockBuf.AbsPath,
				version = 2,
			},
			contentChanges = { { text = mockBuf.Bytes() } },
		})
	end)

	it("initialize request correct", function()
		local handler
		local initServer = {
			request = function(_, _, _, h)
				handler = h
				return 0
			end,
			notify = function() end,
		}
		local r = spy.on(initServer, "request")
		local n = spy.on(initServer, "notify")
		local lsp = Lsp.new(initServer)

		lsp:initialize(function() end)
		assert.spy(r).was.called_with(initServer, "initialize", match.is_table(), match.is_function())

		-- initialized is sent from the reply handler, after initialize succeeds
		handler({ capabilities = {} }, nil, 0)
		assert.spy(n).was.called_with(initServer, "initialized", {})
		assert.are.equal("ready", lsp.state)
	end)

	it("didOpen request correct", function()
		local s = spy.on(server, "notify")
		local lsp = Lsp.new(server)

		lsp:didOpen(mockBuf)
		assert.spy(s).was.called_with(server, "textDocument/didOpen", {
			textDocument = {
				uri = mockBuf.AbsPath,
				languageId = mockBuf.FileType(),
				version = 1,
				text = mockBuf.Bytes(),
			},
		})
	end)

	it("shudown request correct", function()
		local s = spy.on(server, "request")
		local lsp = Lsp.new(server)

		lsp:shutdown()
		assert.spy(s).was.called_with(server, "shutdown", nil, nil)
	end)
end)
