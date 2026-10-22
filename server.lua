local go_os = import("os")
local home, _ = go_os.UserHomeDir()
local pluginPath = home .. '/.config/micro/plug/lspClient/'
package.path = package.path .. ";" .. pluginPath .. "?.lua"

local shell = import("micro/shell")
local micro = import("micro")
local json = require "json"

local Server = {}
Server.__index = Server

function Server.new()
    return setmetatable({ readBuffer = "", pending = {} }, Server)
end

function Server:sendMessage(id, method, params)
    local bodyJson = {
        jsonrpc = "2.0",
        method = method,
        params = params,
    }

    if id ~= nil then
        bodyJson["id"] = id 
    end

    local body = json.encode(bodyJson)
    local content = "Content-Length: " .. #body .. "\r\n\r\n" .. body

    micro.Log("Sending message:\n" .. content)
    shell.JobSend(self.server, content)
end

function Server:startServer(lsp, args, onMessage, onStderr, onExit)
    micro.Log("Starting server", lsp, args)

    self.onMessage = onMessage;
    self.lsp = lsp
    self.server = shell.JobSpawn(lsp, args, function(chunk)
        self:read(chunk)
    end, onStderr, onExit, {})
end

function Server:read(chunk) 
    self.readBuffer = self.readBuffer .. chunk 

    while true do
        local startPos, endPos = string.find(self.readBuffer, "\r\n\r\n", 1, true)

        if startPos == nil or endPos == nil then 
            break 
        end

        local length = string.match(self.readBuffer:sub(1, startPos), "Content%-Length:%s*(%d+)")

        if length == nil then 
            micro.Log("No Content-Length found in message: ", self.readBuffer:sub(1, startPos))
            self.readBuffer = self.readBuffer:sub(endPos + 1)
        else 
            length = tonumber(length)

            local jsonBody = self.readBuffer:sub(endPos + 1, endPos + length)

            if #self.readBuffer < endPos + length then 
                break 
            end
            
            self.readBuffer = self.readBuffer:sub(endPos + length + 1)

            local status, body = pcall(json.decode, jsonBody)

            if status then 
                status, _ = pcall(self.onMessage, body)

                if not status then 
                    micro.Log("Error when processing message: ", body)
                end
            else 
                micro.Log("Could not decode message: ", jsonBody)
            end
        end
    end
end

return Server