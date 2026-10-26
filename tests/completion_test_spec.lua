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
			Loc = function(_, _)
				return 0
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
			.was.called_with(completion, "printf(${1:constchar*restrict,...})", "printf()", 1, 3)
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
			.was.called_with(mockEventHandler, 0, "printf(constchar*restrict,...)                int\n")
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
			.was.called_with(mockEventHandler, 0, "void                                             \n")
	end)
end)
