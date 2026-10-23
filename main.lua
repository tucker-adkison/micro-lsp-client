local go_os = import("os")
local home, _ = go_os.UserHomeDir()
local pluginPath = home .. "/.config/micro/plug/lspClient/"
package.path = package.path .. ";" .. pluginPath .. "?.lua"

local micro = import("micro")
local config = import("micro/config")
local util = import("micro/util")
local buffer = import("micro/buffer")

local sideView = nil
local settings = nil
local lsps = {}
local utils = require 'utils'
local pid = nil
local lspInitialized = false
local didOpen = false

-- initializing all of our classes 
local Completion = require "completion"
local completion = Completion.new()
-- local Logger = require 'logger'
-- local logger = Logger.new()
local Server = require "server"
local server = Server.new()
local Lsp = require "lsp"
local lsp = Lsp.new(server)

local mysplit = function(inputstr, sep)
    if sep == nil then
      sep = "%s"
    end
    local t = {}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
      table.insert(t, str)
    end
    return t
end

local openDropdownMenu = function()
    if sideView == nil then
        micro.CurPane():HSplitIndex(buffer.NewBuffer("", "dropdownMenu"), true)

        sideView = micro.CurPane()
        sideView.Buf.Type.Scratch = true
        sideView.Buf.Type.Readonly = true
        sideView.Buf:SetOptionNative("ruler", false)
        sideView.Buf:SetOptionNative("autosave", false)
        sideView.Buf:SetOptionNative("statusformatr", "")
        sideView.Buf:SetOptionNative("statusformatl", "filemanager")
        sideView.Buf:SetOptionNative("scrollbar", false)

        micro.CurPane():PreviousSplit()
    end
end

local closeDropdownMenu = function()
	if sideView ~= nil then
		sideView:Quit()
		sideView = nil
	end
end

local arrowKeyCommands = function()
    if sideView ~= nil then
        if micro.CurPane() ~= sideView then
            micro.CurPane():NextSplit()
            sideView.Buf:GetActiveCursor():GotoLoc(buffer.Loc(0, -1))
        end

        sideView.Cursor:Relocate()
        sideView.Cursor:SelectLine()
    end
end

function onCursorUp(_)
	arrowKeyCommands()
end

function onCursorDown(_)
	arrowKeyCommands()
end

function preQuit()
    closeDropdownMenu()

    --TODO remove this iff
    if server.server ~= nil then
        lsp:shutdown()
    end
end

function preInsertNewline()
    if sideView ~= nil and sideView == micro.CurPane() then
        if completion:autoComplete() then
            closeDropdownMenu()
        end
    end
end

function preEscape()
    closeDropdownMenu()
    completion.snippetActive = false
    return false
end

function nextParam(bp) 
    if completion ~= nil and completion.snippetActive then
        local cursor = bp.Buf:GetActiveCursor()
        local line =  bp.Buf:Line(cursor.Y)

        local i = cursor.X + 1   

        while i < #line + 1 do 
            if line:sub(i, i) == ')' then 
                cursor:GotoLoc(buffer.Loc(i, cursor.Y))

                local nextTok = line:sub(i+1, i+1)
                if nextTok ~= ',' then
                    completion.snippetActive = false
                end
                
                return true 
            elseif line:sub(i, i) == ',' then
                local nextTok = line:sub(i+1, i+1)

                if nextTok == ',' or nextTok == ')' then 
                    cursor:GotoLoc(buffer.Loc(i, cursor.Y))
                    return true
                end
            end

            i = i + 1
        end

        completion.snippetActive = false

        return true
    else 
        completion.snippetActive = false
        return false 
    end
end

function init() 
    config.TryBindKey("Tab", "lua:lspClient.nextParam|InsertTab", false)
end

function preinit()
    config.RegisterCommonOption("lsp", "server",'')
    settings = config.GetGlobalOption("lsp.server")

    local fileAndLsps = mysplit(settings, ',')
    for _, fileAndLsp in pairs(fileAndLsps) do
        local fileLspSplit = mysplit(fileAndLsp, '=')
        lsps[fileLspSplit[1]] = fileLspSplit[2]
    end
end

function onRune(bp, _)
    if server.server == nil or lsps[bp.Buf:FileType()] == nil then
        return
    end

    if not lspInitialized then
        lspInitialized = true
        lsp:initialize()
    end

    if lspInitialized then
        if not didOpen then 
            lsp:didOpen(bp)
            
            didOpen = true
        end

        lsp:didChange(bp)

        lsp:completion(bp, function(items) 
            completion:fromItems(items)
            if completion.didHaveCompletions then
                openDropdownMenu()
                completion:displayText(sideView)
            else
                closeDropdownMenu()
            end
        end)

        if (micro.CurPane() == sideView) then
            micro.CurPane():PreviousSplit()
        end
    end
end

local onStderr = function(output) end

local onExit = function(output)
    micro.Log("Exit", output)
end

function onBufferOpen(buf)
    local fileType = buf:FileType()
    local lspClient = lsps[fileType]

    if lspClient ~= nil and not server.server then
        local wd, _ = go_os.Getwd()
        local args = utils.getLspArgs(lspClient, wd)

        server:startServer(lspClient, args, onStderr, onExit)
    end
end

