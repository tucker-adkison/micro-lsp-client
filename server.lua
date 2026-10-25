local config = import("micro/config")
local pluginPath = config.ConfigDir .. "/plug/lspClient/"
package.path = package.path .. ";" .. pluginPath .. "?.lua"

local shell = import("micro/shell")
local micro = import("micro")
local json = require "json"

local Server = {}
Server.__index = Server

-- every line starts with "lsp " so `grep "lsp " log.txt` shows only this plugin
local function log(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[i] = tostring(select(i, ...))
    end
    micro.Log("lsp " .. table.concat(parts))
end

local function describeError(err)
    return "error " .. tostring(err.code) .. " (" .. tostring(err.message) .. ")"
end

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

    if id ~= nil then
        log("→ request #", id, " ", method)
    else
        log("→ notify ", method)
    end

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

    shell.JobSend(self.server, content)
end

function Server:startServer(lsp, args, onStderr, onExit)
    log("starting ", lsp, " ", table.concat(args, " "))

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
            log("← header without Content-Length, skipped: ", self.readBuffer:sub(1, startPos))
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
                    log("← dispatch failed: ", err)
                end
            else
                log("← could not decode message: ", result)
            end
        end
    end
end

function Server:dispatch(msg)
    if msg.id ~= nil and msg.method == nil then
        local entry = self.pending[msg.id]
        self.pending[msg.id] = nil

        if entry == nil then
            log("← reply #", msg.id, ": unknown id")
            return
        end

        local outcome = "ok"
        if msg.error ~= nil then
            outcome = describeError(msg.error)
        end

        if entry.handler == nil then
            outcome = outcome .. ", no handler"
        else
            local status, err = pcall(entry.handler, msg.result, msg.error, msg.id)

            if not status then
                outcome = outcome .. ", handler failed: " .. tostring(err)
            end
        end

        log("← reply #", msg.id, " ", entry.method, ": ", outcome)
    elseif msg.id == nil and msg.method ~= nil then
        local handler = self.notificationHandlers[msg.method]
        local outcome = "ok"

        if handler == nil then
            outcome = "no handler"
        else
            local status, err = pcall(handler, msg.params)

            if not status then
                outcome = "handler failed: " .. tostring(err)
            end
        end

        log("← notify ", msg.method, ": ", outcome)
    elseif msg.id ~= nil and msg.method ~= nil then
        local handler = self.notificationHandlers[msg.method]
        local outcome

        if handler == nil then
            self:respond(msg.id, nil, { code = -32601, message = "Method not found" })
            outcome = 'answered "method not found"'
        else
            local status, result = pcall(handler, msg.params)

            if status then
                self:respond(msg.id, result)
                outcome = "answered"
            else
                self:respond(msg.id, nil, { code = -32603, message = tostring(result) })
                outcome = "handler failed: " .. tostring(result)
            end
        end

        log("← request #", msg.id, " ", msg.method, ": ", outcome)
    else
        log("← message with neither id nor method")
    end
end

function Server:request(method, params, handler)
    self.nextId = self.nextId + 1 
    local id = self.nextId
    -- keep the method so the reply can be logged with it
    self.pending[id] = { method = method, handler = handler }

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