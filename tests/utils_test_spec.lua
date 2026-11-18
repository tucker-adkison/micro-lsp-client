-- the tabs that micro.Tabs() returns; each test sets its own
local mockTabs = { List = {} }

rawset(_G, "import", function(module)
	if module == "micro" then
		return {
			Tabs = function()
				return mockTabs
			end,
		}
	elseif module == "fmt" then
		return {
			Sprintf = function(format, value)
				return string.format(format, value)
			end,
		}
	elseif module == "os" then
		return {
			UserHomeDir = function()
				return "."
			end,
		}
	elseif module == "micro/util" then
		return {
			String = function() end,
		}
	elseif module == "micro/config" then
		return { ConfigDir = "." }
	end
end)

local utils = require("utils")

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

describe("test getLanguageId", function()
	it("translates a micro file type that differs", function()
		assert.are.equal("cpp", utils.getLanguageId("c++", "/src/a.cpp"))
		assert.are.equal("shellscript", utils.getLanguageId("shell", "/src/a.sh"))
	end)

	it("keeps a micro file type that matches", function()
		assert.are.equal("c", utils.getLanguageId("c", "/src/a.c"))
		assert.are.equal("typescript", utils.getLanguageId("typescript", "/src/a.ts"))
	end)

	it("uses the extension when micro shares a file type", function()
		assert.are.equal("typescriptreact", utils.getLanguageId("typescript", "/src/a.tsx"))
		assert.are.equal("bibtex", utils.getLanguageId("tex", "/src/refs.bib"))
	end)

	it("handles a path without an extension", function()
		assert.are.equal("makefile", utils.getLanguageId("makefile", "/src/Makefile"))
		assert.are.equal("go", utils.getLanguageId("go", nil))
	end)
end)

describe("test getOpenBuffer", function()
	local function pane(path)
		return { Buf = { AbsPath = path } }
	end

	it("finds a buffer in any tab and pane", function()
		local wanted = pane("/src/b.c")
		mockTabs = { List = { { Panes = { pane("/src/a.c") } }, { Panes = { pane("/src/x.lua"), wanted } } } }

		assert.are.equal(wanted.Buf, utils.getOpenBuffer("file:///src/b.c"))
	end)

	it("returns nil for a file that is not open", function()
		mockTabs = { List = { { Panes = { pane("/src/a.c") } } } }

		assert.is_nil(utils.getOpenBuffer("file:///src/closed.c"))
	end)

	it("skips panes without a buffer", function()
		local wanted = pane("/src/a.c")
		mockTabs = { List = { { Panes = { {}, wanted } } } }

		assert.are.equal(wanted.Buf, utils.getOpenBuffer("file:///src/a.c"))
	end)
end)
