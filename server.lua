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
    return setmetatable({ readBuffer = "", pending = {},  notificationHandlers = {}, nextId = -1}, Server)
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

function Server:respond(id, result, err) 
    local bodyJson = {jsonrpc = "2.0",}
    if err ~= nil then 
        bodyJson["error"] = err
    else 
        bodyJson["result"] = result
    end

    if id ~= nil then
        bodyJson["id"] = id 
    end

    local body = json.encode(bodyJson)

    if err == nil and result == nil then 
       body = body:sub(1, -2) .. ',"result":null}'
    end

    local content = "Content-Length: " .. #body .. "\r\n\r\n" .. body

    micro.Log("Sending response message:\n" .. content)
    shell.JobSend(self.server, content)
end

function Server:startServer(lsp, args, onStderr, onExit)
    micro.Log("Starting server", lsp, args)

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

            local status, result = pcall(json.decode, jsonBody)

            if status and type(result) == "table" then 
                local status, err = pcall(self.dispatch, self, result)

                if not status then 
                    micro.Log("Error when processing message: ", err)
                end
            else 
                micro.Log("Could not decode message: ", result)
            end
        end
    end
end

function Server:dispatch(msg)
    micro.Log("Calling dispatch:", msg.id, msg.method)

    if msg.id ~= nil and msg.method == nil then
        local handler = self.pending[msg.id]
        self.pending[msg.id] = nil

        if handler ~= nil then 
            local status, err = pcall(handler, msg.result, msg.error, msg.id)

            if not status then 
                micro.Log("Reply request failed:", err)
            end
        else 
            micro.Log("Handler not found for id:", msg.id)
        end
    elseif msg.id == nil and msg.method ~= nil then 
        local handler = self.notificationHandlers[msg.method]

        if handler ~= nil then 
            local status, err = pcall(handler, msg.params)

            if not status then 
                micro.Log("Notification request failed:", err)
            end
        else 
            micro.Log("Handler not found for method:", msg.method)
        end
    elseif msg.id ~= nil and msg.method ~= nil then 
        local handler = self.notificationHandlers[msg.method]

        if handler ~= nil then 
            local status, result = pcall(handler, msg.params)

            if status then
                self:respond(msg.id, result)
            else 
                micro.Log("Request failed:", result)
                self:respond(msg.id, nil, { code = -32603,  message = tostring(result)})
            end
        else 
            micro.Log("Handler not found for id and method:", msg.id, msg.method)
            self:respond(msg.id, nil, { code = -32601, message = "Method not found" })
        end
    else
        micro.Log("msg.id and msg.method are both nil")
    end 
end

function Server:request(method, params, handler)
    self.nextId = self.nextId + 1 
    local id = self.nextId
    self.pending[id] = handler 

    self:sendMessage(id, method, params)

    return id
end

function Server:notify(method, params)
    self:sendMessage(nil, method, params)
end

function Server:onNotification(method, handler)
    self.notificationHandlers[method] = handler
end

return Server