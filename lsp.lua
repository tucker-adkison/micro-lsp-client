local go_os = import("os")
local config = import("micro/config")
local pluginPath = config.ConfigDir .. "/plug/lspClient/"
package.path = package.path .. ";" .. pluginPath .. "?.lua"

local fmt = import("fmt")
local utils = require "utils"
local micro = import("micro") 

local Lsp = {}
Lsp.__index = Lsp

function Lsp.new(server)
    return setmetatable({
        server = server, 
        lastCompletionId = 0, 
        state="starting",
        queue = {},
        documents = {},
        capabilities = {}
    }, Lsp)
end

function Lsp:completion(buf, onItems)
    local filePath = buf.AbsPath
    local line = buf:GetActiveCursor().Y
    local char = buf:GetActiveCursor().X

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
    local uri = utils.getRootUri(filePath)
    local version = 1

    if self.documents[uri] ~= nil or filePath == "" or filePath == "file://" then 
        return
    end

    self.documents[uri] = {version = version, text = fileText}

    self.server:notify("textDocument/didOpen", {
        textDocument = {
            uri = uri,
            languageId = fileType,
            version = version,
            text = fileText,
        }
    })
end

function Lsp:didChange(buf)
    local filePath = buf.AbsPath
    local fileText = utils.getFileText(buf)
    local uri = utils.getRootUri(filePath)
    local document = self.documents[uri]

    if document ~= nil and document.text ~= fileText then
        local version = document.version + 1

        document.version = version
        document.text = fileText

        self.server:notify("textDocument/didChange", {
            textDocument = {
                uri = uri,
                version = version
            },
            contentChanges = {{ text = fileText }},
        })
    end
end

function Lsp:didSave(uri)
    local document = self.documents[uri]
    local sync = self.capabilities and self.capabilities.textDocumentSync

    if document == nil or type(sync) ~= "table" then
        return
    end

    local save = sync.save
    if save ~= true and type(save) ~= "table" then
        return
    end

    local params = { textDocument = { uri = uri } }
    if type(save) == "table" and save.includeText then
        params.text = document.text
    end

    self.server:notify("textDocument/didSave", params)
end

function Lsp:didClose(uri) 
    self.server:notify("textDocument/didClose", {
        textDocument = {uri = uri}
    })
end 

function Lsp:closeMissing() 
    local open = utils.getOpenPaths()
    for uri, path in pairs(self.documents) do 
        if not open[uri] then
            self.documents[uri] = nil 
            self:sendWhenReady(function() self:didClose(uri) end, "didClose")
        end
    end
end

function Lsp:shutdown()
	self.server:request('shutdown', nil, nil)
end

function Lsp:sendWhenReady(fn, t)
    if self.state == "starting" then
        if t == "didChange" or t == "didOpen" or t == "didClose" then
            table.insert(self.queue, {key=t, value=fn})
        end
    elseif self.state == "ready" then
        fn()
    end
end

return Lsp