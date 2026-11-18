rawset(_G, "import", function(module)
	if module == "micro/config" then
		return { ConfigDir = "." }
	elseif module == "micro/buffer" then
		return {
			-- the values of micro's MsgType constants (iota in internal/buffer/message.go)
			MTInfo = 0,
			MTWarning = 1,
			MTError = 2,
			Loc = function(x, y)
				return { X = x, Y = y }
			end,
			NewMessage = function(owner, msg, start, finish, kind)
				return { Owner = owner, Msg = msg, Start = start, End = finish, Kind = kind }
			end,
		}
	end
end)

local Diagnostics = require("diagnostics")

-- a buffer with micro's message methods: ClearMessages removes one owner's messages
local function newBuf(...)
	local buf = { Messages = { ... } }

	function buf:AddMessage(m)
		table.insert(self.Messages, m)
	end

	function buf:ClearMessages(owner)
		for i = #self.Messages, 1, -1 do
			if self.Messages[i].Owner == owner then
				table.remove(self.Messages, i)
			end
		end
	end

	return buf
end

local function diagnostic(line, severity, message)
	return {
		range = { start = { line = line, character = 1 }, ["end"] = { line = line, character = 4 } },
		severity = severity,
		message = message,
	}
end

local function message(owner, kind)
	return { Owner = owner, Kind = kind }
end

describe("test Diagnostics.show", function()
	it("adds a message for each diagnostic clangd sends", function()
		local buf = newBuf()

		-- from clangd 23 for: int x = "a"; foo(); return 0 (no semicolon)
		Diagnostics.show(buf, "lsp clangd", {
			{
				range = { start = { line = 1, character = 5 }, ["end"] = { line = 1, character = 6 } },
				severity = 1,
				message = "Incompatible pointer to integer conversion initializing 'int' with an expression of type 'char[2]'",
			},
			{
				range = { start = { line = 2, character = 1 }, ["end"] = { line = 2, character = 4 } },
				severity = 1,
				message = "Call to undeclared function 'foo'; ISO C99 and later do not support implicit function declarations",
			},
			{
				range = { start = { line = 4, character = 0 }, ["end"] = { line = 4, character = 1 } },
				severity = 1,
				message = "Expected ';' after return statement (fix available)",
			},
		})

		assert.are.equal(3, #buf.Messages)
		assert.are.same({
			Owner = "lsp clangd",
			Msg = "Incompatible pointer to integer conversion initializing 'int' with an expression of type 'char[2]'",
			Start = { X = 5, Y = 1 },
			End = { X = 6, Y = 1 },
			Kind = 2,
		}, buf.Messages[1])
		assert.are.same({ X = 0, Y = 4 }, buf.Messages[3].Start)
	end)

	it("maps each LSP severity to a micro message kind", function()
		local buf = newBuf()

		Diagnostics.show(buf, "lsp clangd", {
			diagnostic(0, 1, "error"),
			diagnostic(1, 2, "warning"),
			diagnostic(2, 3, "information"),
			diagnostic(3, 4, "hint"),
			diagnostic(4, nil, "no severity"),
		})

		local kinds = {}
		for i, m in ipairs(buf.Messages) do
			kinds[i] = m.Kind
		end
		-- a missing severity counts as an error
		assert.are.same({ 2, 1, 0, 0, 2 }, kinds)
	end)

	it("replaces the diagnostics of an earlier publish", function()
		local buf = newBuf()

		Diagnostics.show(buf, "lsp clangd", { diagnostic(0, 1, "old"), diagnostic(1, 1, "old") })
		Diagnostics.show(buf, "lsp clangd", { diagnostic(2, 2, "new") })

		assert.are.equal(1, #buf.Messages)
		assert.are.equal("new", buf.Messages[1].Msg)
	end)

	it("an empty publish removes all of the server's messages", function()
		local buf = newBuf()

		Diagnostics.show(buf, "lsp clangd", { diagnostic(0, 1, "fixed soon") })
		Diagnostics.show(buf, "lsp clangd", {})

		assert.are.equal(0, #buf.Messages)
	end)

	it("keeps the messages of other owners", function()
		local buf = newBuf(message("gcc", 2), message("lsp lua-language-server", 1))

		Diagnostics.show(buf, "lsp clangd", { diagnostic(0, 1, "from clangd") })
		Diagnostics.show(buf, "lsp clangd", {})

		assert.are.same({ "gcc", "lsp lua-language-server" }, { buf.Messages[1].Owner, buf.Messages[2].Owner })
	end)
end)

describe("test Diagnostics.summary", function()
	it("is empty without messages", function()
		assert.are.equal("", Diagnostics.summary(newBuf()))
	end)

	it("counts exactly one error", function()
		assert.are.equal("E1", Diagnostics.summary(newBuf(message("lsp clangd", 2))))
	end)

	it("counts errors and warnings", function()
		assert.are.equal("E1 W1", Diagnostics.summary(newBuf(message("lsp clangd", 2), message("lsp clangd", 1))))
	end)

	it("counts every message, not only the first", function()
		local buf = newBuf(message("lsp clangd", 1), message("lsp clangd", 2), message("lsp clangd", 2))

		assert.are.equal("E2 W1", Diagnostics.summary(buf))
	end)

	it("ignores information, hints and other owners", function()
		local buf = newBuf(message("gcc", 2), message("lsp clangd", 0), message("lsp clangd", 1))

		assert.are.equal("W1", Diagnostics.summary(buf))
	end)

	it("counts the messages that show adds", function()
		local buf = newBuf()

		Diagnostics.show(buf, "lsp clangd", { diagnostic(0, 1, "e"), diagnostic(1, 1, "e"), diagnostic(2, 4, "hint") })

		assert.are.equal("E2", Diagnostics.summary(buf))
	end)
end)
