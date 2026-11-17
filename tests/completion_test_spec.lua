local mockCursor = {
	Y = 0,
	GotoLoc = function(_, _) end,
}
local mockEventHandler = {
	Remove = function(_, _, _) end,
	Insert = function(...) end,
}
local mockBuf = {
	EventHandler = mockEventHandler,
	GetActiveCursor = function()
		return mockCursor
	end,
	Start = function()
		return 0
	end,
	End = function()
		return 0
	end,
}

rawset(_G, "import", function(module)
	if module == "micro" then
		local mockPane = {
			Buf = mockBuf,
			Cursor = mockCursor,
			NextSplit = function() end,
			PreviousSplit = function() end,
			GetView = function()
				return {
					Width = 50,
				}
			end,
		}
		return {
			Log = function() end,
			CurPane = function()
				return mockPane
			end,
		}
	elseif module == "micro/buffer" then
		return {
			Loc = function(x, y)
				return { X = x, Y = y }
			end,
		}
	elseif module == "os" then
		return {
			UserHomeDir = function()
				return os.getenv("HOME") or "/tmp", nil
			end,
		}
	elseif module == "micro/config" then
		return { ConfigDir = "." }
	end
end)

local function parseCompletionFile(filePath)
	local input = ""
	local lines = {}

	for line in io.lines(filePath) do
		if line == "----" then
			table.insert(lines, input)
			input = ""
		elseif line == "" then
			input = input .. "\r\n\r\n"
		else
			input = input .. line
		end
	end

	table.insert(lines, input)

	return lines
end

local json = require("json")
local Completion = require("completion")

-- the completion items inside a raw LSP message
local function itemsFrom(message)
	local body = message:sub(message:find("\r\n\r\n", 1, true) + 4)
	return json.decode(body).result.items
end

describe("test fromItems", function()
	it("fromItems sets completion items", function()
		local completion = Completion.new()
		local lines = parseCompletionFile("./tests/completion.txt")

		completion:fromItems(itemsFrom(lines[1]))

		assert.are.equal(#completion.completions, 1)
		assert.is_true(completion.didHaveCompletions)
	end)

	it("fromItems empty if there are no items", function()
		local completion = Completion.new()

		completion:fromItems({})

		assert.are.equal(#completion.completions, 0)
		assert.is_false(completion.didHaveCompletions)
	end)

	it("fromItems didHaveCompletions false if empty items", function()
		local completion = Completion.new()

		completion:fromItems(
			itemsFrom('Content-Length: 67\r\n\r\n{"id":6,"jsonrpc":"2.0","result":{"isIncomplete":false,"items":[]}}')
		)

		assert.are.equal(#completion.completions, 0)
		assert.is_false(completion.didHaveCompletions)
	end)
end)

describe("test autcomplete", function()
	it("autcomplete happened", function()
		local completion = Completion.new()
		local s = spy.on(completion, "findCursorPosition")

		completion:fromItems(
			itemsFrom(
				'Content-Length: 613\r\n\r\n{"id":6,"jsonrpc":"2.0","result":{"isIncomplete":false,"items":[{"additionalTextEdits":[{"newText":"#include<stdio.h>\\n","range":{"end":{"character":0,"line":1},"start":{"character":0,"line":1}}}],"detail":"int","documentation":{"kind":"plaintext","value":"From<stdio.h>"},"filterText":"printf","insertText":"printf(${1:constchar*restrict,...})","insertTextFormat":2,"kind":3,"label":"•printf(constchar*restrict,...)","score":1.3475996255874634,"sortText":"3fd381dbprintf","textEdit":{"newText":"printf(${1:constchar*restrict,...})","range":{"end":{"character":7,"line":3},"start":{"character":1,"line":3}}}}]}}'
			)
		)

		assert.is_true(completion:autoComplete())
		assert
			.spy(s)
			-- line 4, not 3: the #include from additionalTextEdits goes in above
			.was.called_with(completion, "printf(${1:constchar*restrict,...})", "printf()", 1, 4)
	end)

	it("autocomplete findCursorPosition worked when regex did not match", function()
		local completion = Completion.new()
		local s = spy.on(completion, "findCursorPosition")

		completion:fromItems(
			itemsFrom(
				'Content-Length: 1237\r\n\r\n{"id":10,"jsonrpc":"2.0","result":{"isIncomplete":false,"items":[{"filterText":"include","insertText":"include\\"$0\\"","insertTextFormat":2,"kind":15,"label":"include\\"header\\"","score":0.78725427389144897,"sortText":"40367681include","textEdit":{"newText":"include\\"$0\\"","range":{"end":{"character":8,"line":0},"start":{"character":1,"line":0}}}},{"filterText":"include","insertText":"include<$0>","insertTextFormat":2,"kind":15,"label":"include<header>","score":0.78725427389144897,"sortText":"40367681include","textEdit":{"newText":"include<$0>","range":{"end":{"character":8,"line":0},"start":{"character":1,"line":0}}}},{"filterText":"include_next","insertText":"include_next<$0>","insertTextFormat":2,"kind":15,"label":"include_next<header>","score":0.78725427389144897,"sortText":"40b67681include_next","textEdit":{"newText":"include_next<$0>","range":{"end":{"character":8,"line":0},"start":{"character":1,"line":0}}}},{"filterText":"include_next","insertText":"include_next\\"$0\\"","insertTextFormat":2,"kind":15,"label":"include_next\\"header\\"","score":0.78725427389144897,"sortText":"40b67681include_next","textEdit":{"newText":"include_next\\"$0\\"","range":{"end":{"character":8,"line":0},"start":{"character":1,"line":0}}}}]}}'
			)
		)

		assert.is_true(completion:autoComplete())
		assert.spy(s).was.called_with(completion, 'include"$0"', 'include""', 1, 0)
	end)

	it("autocomplete findCursorPosition defaults works", function()
		local completion = Completion.new()
		local s = spy.on(completion, "findCursorPosition")

		completion:fromItems(
			itemsFrom(
				'Content-Length: 311\r\n\r\n{"id":6,"jsonrpc":"2.0","result":{"isIncomplete":false,"items":[{"filterText":"void","insertText":"void","insertTextFormat":1,"kind":14,"label":"void","score":1.3658820390701294,"sortText":"3fd12ac7void","textEdit":{"newText":"void","range":{"end":{"character":5,"line":3},"start":{"character":1,"line":3}}}}]}}'
			)
		)

		assert.is_true(completion:autoComplete())
		assert.spy(s).was.called_with(completion, "void", "void", 1, 3)
	end)

	it("autocomplete did not happen", function()
		local completion = Completion.new()
		local s = spy.on(completion, "findCursorPosition")

		assert.is_false(completion:autoComplete())
		assert
			.spy(s)
			.was.not_called_with(completion, "printf(${1:constchar*restrict,...})", "printf()", 1, 3)
	end)
end)

describe("test additionalTextEdits", function()
	-- the text of each Insert call, in the order autoComplete made them
	local function insertedTexts(s)
		local texts = {}
		for _, call in ipairs(s.calls) do
			table.insert(texts, call.vals[3])
		end
		return texts
	end

	it("clangd #include is inserted after the main edit", function()
		local completion = Completion.new()
		local s = spy.on(mockEventHandler, "Insert")

		completion:fromItems({
			{
				label = "•printf(const char *, ...)",
				textEdit = {
					newText = "printf(${1:const char *, ...})",
					range = { start = { line = 1, character = 1 }, ["end"] = { line = 1, character = 5 } },
				},
				additionalTextEdits = {
					{
						newText = "#include <stdio.h>\n",
						range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 0 } },
					},
				},
			},
		}, { line = 1, character = 5 })

		assert.is_true(completion:autoComplete())
		assert.are.same({ "printf()", "#include <stdio.h>\n" }, insertedTexts(s))
		assert.spy(s).was.called_with(mockEventHandler, { X = 0, Y = 0 }, "#include <stdio.h>\n")
	end)

	it("jdtls import with a blank line moves the cursor down two lines", function()
		local completion = Completion.new()
		local s = spy.on(completion, "findCursorPosition")
		local gotoLoc = spy.on(mockCursor, "GotoLoc")

		completion:fromItems({
			{
				label = "ArrayList - java.util",
				textEdit = {
					newText = "ArrayList",
					range = { start = { line = 2, character = 2 }, ["end"] = { line = 2, character = 9 } },
				},
				additionalTextEdits = {
					{
						newText = "import java.util.ArrayList;\n\n",
						range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 0 } },
					},
				},
			},
		}, { line = 2, character = 9 })

		assert.is_true(completion:autoComplete())
		assert.spy(s).was.called_with(completion, "ArrayList", "ArrayList", 2, 4)
		assert.spy(gotoLoc).was.called_with(mockCursor, { X = 11, Y = 4 })
	end)

	it("pylsp import works without a textEdit", function()
		local completion = Completion.new()
		local s = spy.on(completion, "findCursorPosition")
		local line = mockBuf.Line
		mockBuf.Line = function()
			return "OrderedD"
		end

		completion:fromItems({
			{
				label = "OrderedDict",
				insertText = "OrderedDict",
				additionalTextEdits = {
					{
						newText = "from collections import OrderedDict\n",
						range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 0 } },
					},
				},
			},
		}, { line = 1, character = 8 })

		assert.is_true(completion:autoComplete())
		mockBuf.Line = line
		assert.spy(s).was.called_with(completion, "OrderedDict", "OrderedDict", 0, 2)
	end)

	it("edits are applied from the end of the file to the start", function()
		local completion = Completion.new()
		local insert = spy.on(mockEventHandler, "Insert")
		local find = spy.on(completion, "findCursorPosition")
		local function edit(line, text)
			return { newText = text, range = { start = { line = line, character = 0 }, ["end"] = { line = line, character = 0 } } }
		end

		completion:fromItems({
			{
				label = "main",
				textEdit = {
					newText = "main",
					range = { start = { line = 5, character = 0 }, ["end"] = { line = 5, character = 2 } },
				},
				additionalTextEdits = { edit(0, "a\n"), edit(7, "below\n"), edit(2, "b\n") },
			},
		}, { line = 5, character = 2 })

		assert.is_true(completion:autoComplete())
		assert.are.same({ "below\n", "main", "b\n", "a\n" }, insertedTexts(insert))
		-- only the two edits above the main edit move it
		assert.spy(find).was.called_with(completion, "main", "main", 0, 7)
	end)

	it("an edit that replaces a line does not move the cursor", function()
		local completion = Completion.new()
		local s = spy.on(completion, "findCursorPosition")

		completion:fromItems({
			{
				label = "b",
				textEdit = {
					newText = "b",
					range = { start = { line = 3, character = 0 }, ["end"] = { line = 3, character = 1 } },
				},
				additionalTextEdits = {
					{
						newText = "from x import a, b",
						range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 15 } },
					},
				},
			},
		}, { line = 3, character = 1 })

		assert.is_true(completion:autoComplete())
		assert.spy(s).was.called_with(completion, "b", "b", 0, 3)
	end)
end)

describe("test displayText", function()
	it("text was displayed with details", function()
		local completion = Completion.new()
		local sideView = {
			Buf = mockBuf,
		}
		local s = spy.on(mockEventHandler, "Insert")

		completion:fromItems(
			itemsFrom(
				'Content-Length: 613\r\n\r\n{"id":6,"jsonrpc":"2.0","result":{"isIncomplete":false,"items":[{"additionalTextEdits":[{"newText":"#include<stdio.h>\\n","range":{"end":{"character":0,"line":1},"start":{"character":0,"line":1}}}],"detail":"int","documentation":{"kind":"plaintext","value":"From<stdio.h>"},"filterText":"printf","insertText":"printf(${1:constchar*restrict,...})","insertTextFormat":2,"kind":3,"label":"•printf(constchar*restrict,...)","score":1.3475996255874634,"sortText":"3fd381dbprintf","textEdit":{"newText":"printf(${1:constchar*restrict,...})","range":{"end":{"character":7,"line":3},"start":{"character":1,"line":3}}}}]}}'
			)
		)
		completion:displayText(sideView)

		assert
			.spy(s)
			.was.called_with(mockEventHandler, { X = 0, Y = 0 }, "printf(constchar*restrict,...)                int\n")
	end)

	it("text was displayed without details", function()
		local completion = Completion.new()
		local sideView = {
			Buf = mockBuf,
		}
		local s = spy.on(mockEventHandler, "Insert")

		completion:fromItems(
			itemsFrom(
				'Content-Length: 311\r\n\r\n{"id":6,"jsonrpc":"2.0","result":{"isIncomplete":false,"items":[{"filterText":"void","insertText":"void","insertTextFormat":1,"kind":14,"label":"void","score":1.3658820390701294,"sortText":"3fd12ac7void","textEdit":{"newText":"void","range":{"end":{"character":5,"line":3},"start":{"character":1,"line":3}}}}]}}'
			)
		)
		completion:displayText(sideView)

		assert
			.spy(s)
			.was.called_with(mockEventHandler, { X = 0, Y = 0 }, "void                                             \n")
	end)
end)
