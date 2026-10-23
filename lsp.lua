local go_os = import("os")
local home, _ = go_os.UserHomeDir()
local pluginPath = home .. '/.config/micro/plug/lspClient/'
package.path = package.path .. ";" .. pluginPath .. "?.lua"

local fmt = import("fmt")
local utils = require "utils"

local Lsp = {}
Lsp.__index = Lsp

function Lsp.new(server)
    return setmetatable({server = server, version = -1, lastCompletionId = 0}, Lsp)
end

function Lsp:completion(bp, onItems)
    local filePath = bp.Buf.AbsPath
    local line = bp.Buf:GetActiveCursor().Y
    local char = bp.Buf:GetActiveCursor().X

	self.lastCompletionId = self.server:request("textDocument/completion", {
      textDocument = {
        uri = utils.getRootUri(filePath),
      },
      position = {
        line = line,
        character = char,
      },
    }, function(result, err, id) 
		if err ~= nil or id ~= self.lastCompletionId then 
			return 
		elseif result == nil then 
			onItems({})
		else 
			onItems(result.items or result)
		end 
	end)
end

function Lsp:didChange(bp)
    local filePath = bp.Buf.AbsPath
    local fileText = utils.getFileText(bp)

    self.version = self.version + 1
	self.server:notify("textDocument/didChange", {
      textDocument = {
        uri = utils.getRootUri(filePath),
        version = self.version,
      },
      contentChanges = {{ text = fileText }},
    })
end

function Lsp:initialize()
    local wd, _ = go_os.Getwd()
    local pid = go_os.Getpid()
    local params = utils.getInitiaizeParams(utils.getRootUri(wd), pid)

	self.server:request("initialize", params, nil)
    self.server:notify("initialized", {})
end

function Lsp:didOpen(bp)
    local fileType = bp.Buf:FileType()
    local filePath = bp.Buf.AbsPath
    local fileText = utils.getFileText(bp)

    self.version = self.version + 1
    self.server:notify("textDocument/didOpen", {
        textDocument = {
            uri = utils.getRootUri(filePath),
            languageId = fileType,
            version = self.version,
            text = fileText,
        }
    })
end

function Lsp:shutdown()
	self.server:request('shutdown', nil, nil)
end

return Lsp