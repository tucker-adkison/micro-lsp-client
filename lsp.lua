local go_os = import("os")
local home, _ = go_os.UserHomeDir()
local pluginPath = home .. '/.config/micro/plug/lspClient/'
package.path = package.path .. ";" .. pluginPath .. "?.lua"

local fmt = import("fmt")
local utils = require "utils"
local micro = import("micro") 

local Lsp = {}
Lsp.__index = Lsp

function Lsp.new(server)
    return setmetatable({
        server = server, 
        version = -1, 
        lastCompletionId = 0, 
        state="starting",
        queue = {}
    }, Lsp)
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
    local fileText = utils.getFileText(bp.Buf)

    self.version = self.version + 1
	self.server:notify("textDocument/didChange", {
      textDocument = {
        uri = utils.getRootUri(filePath),
        version = self.version,
      },
      contentChanges = {{ text = fileText }},
    })
end

function Lsp:initialize(showError)
    local wd, _ = go_os.Getwd()
    local pid = go_os.Getpid()
    local params = utils.getInitiaizeParams(utils.getRootUri(wd), pid)

	self.server:request("initialize", params, function(result, err, id) 
        if err ~= nil then 
            self.state = "failed"
            showError(err)
            self.queue = {}
        else 
            self.capabilities = result.capabilities
            self.serverInfo = result.serverInfo
            self.server:notify("initialized", {})
            self.state = "ready"

            local queued = self.queue
            self.queue = {} 

            for _, item in ipairs(queued) do
                local status, result = pcall(item.value)

                if not status then 
                    micro.Log("Error calling method", item.key, result)
                end
            end
        end
    end)
end

function Lsp:didOpen(buf)
    local fileType = buf:FileType()
    local filePath = buf.AbsPath
    local fileText = utils.getFileText(buf)

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

function Lsp:sendWhenReady(fn, t)
    if self.state == "starting" then
        if t == "didChange" or t == "didOpen" then
            table.insert(self.queue, {key=t, value=fn})
        end
    elseif self.state == "ready" then
        fn()
    end
end

return Lsp