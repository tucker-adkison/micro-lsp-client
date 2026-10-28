-- micro calls the plugin's callbacks (onRune, preinit, ...) as lowercase globals
---@diagnostic disable: lowercase-global

local go_os = import("os")
local config = import("micro/config")
local pluginPath = config.ConfigDir .. "/plug/lspClient/"
package.path = package.path .. ";" .. pluginPath .. "?.lua"

local micro = import("micro")
local buffer = import("micro/buffer")

local sideView = nil
local completionOwner = nil
local settings = nil
local commands = {}
local utils = require("utils")

-- initializing all of our classes
local Completion = require("completion")
local completion = Completion.new()
-- local Logger = require 'logger'
-- local logger = Logger.new()
local Server = require("server")
local Lsp = require("lsp")

local lsps = {}

local mysplit = function(inputstr, sep)
	if sep == nil then
		sep = "%s"
	end
	local t = {}
	for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
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
		local active = micro.CurPane()
		sideView:Quit()
		sideView = nil

		if active ~= nil then
			local tab = micro.CurTab()
			tab:SetActive(tab:GetPane(active:ID()))
		end
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

function preQuit(bp)
	closeDropdownMenu()

	local lsp = clientFor(bp.Buf)

	if lsp ~= nil then
		lsp:sendWhenReady(function()
			lsp:shutdown()
		end, "shutdown")
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
		local line = bp.Buf:Line(cursor.Y)

		local i = cursor.X + 1

		while i < #line + 1 do
			if line:sub(i, i) == ")" then
				cursor:GotoLoc(buffer.Loc(i, cursor.Y))

				local nextTok = line:sub(i + 1, i + 1)
				if nextTok ~= "," then
					completion.snippetActive = false
				end

				return true
			elseif line:sub(i, i) == "," then
				local nextTok = line:sub(i + 1, i + 1)

				if nextTok == "," or nextTok == ")" then
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
	-- makes `help lspClient` open help/lspClient.md
	config.AddRuntimeFile("lspClient", config.RTHelp, "help/lspClient.md")
end

function preinit()
	config.RegisterCommonOption("lsp", "server", "")
	settings = config.GetGlobalOption("lsp.server")

	local fileAndLsps = mysplit(settings, ",")
	for _, fileAndLsp in pairs(fileAndLsps) do
		local fileLspSplit = mysplit(fileAndLsp, "=")
		commands[fileLspSplit[1]] = fileLspSplit[2]
	end
end

function onRune(bp, _)
	local lsp = clientFor(bp.Buf)
	if lsp ~= nil then
		local buf = bp.Buf

		lsp:sendWhenReady(function()
			lsp:didChange(buf)
		end, "didChange")

		completionOwner = lsp

		lsp:sendWhenReady(function()
			lsp:completion(buf, function(items, position)
				if completionOwner ~= lsp then
					return
				end
				completion:fromItems(items, position)
				if completion.didHaveCompletions then
					openDropdownMenu()
					completion:displayText(sideView)
				else
					closeDropdownMenu()
				end
			end)
		end, "completion")
	end

	if micro.CurPane() == sideView then
		micro.CurPane():PreviousSplit()
	end
end

local onStderr = function() end

function onBufferOpen(buf)
	local lsp = startClientFor(buf)

	if lsp ~= nil then
		lsp:sendWhenReady(function()
			lsp:didOpen(buf)
		end, "didOpen")
	end
end

function onAnyEvent()
	local pane = micro.CurPane()

	if pane ~= nil then
		local buf = pane.Buf

		if buf ~= nil then
			local lsp = clientFor(buf)
			if lsp ~= nil then
				lsp:sendWhenReady(function()
					lsp:didChange(buf)
				end, "didChange")
			end
		end
	end

	for _, lsp in pairs(lsps) do
		lsp:closeMissing()
	end
end

function onSave(bp)
	local uri = utils.getRootUri(bp.Buf.AbsPath)
	local lsp = clientFor(bp.Buf)
	if lsp ~= nil then
		lsp:sendWhenReady(function()
			lsp:didChange(bp.Buf)
		end, "didChange")
		lsp:sendWhenReady(function()
			lsp:didSave(uri)
		end, "didSave")
	end
end

function startClientFor(buf)
	local command = commands[buf:FileType()]

	if command == nil then
		return nil
	end

	if lsps[command] == nil then
		local server = Server.new()
		local lsp = Lsp.new(server)

		local wd, _ = go_os.Getwd()
		local args = utils.getLspArgs(command, wd)

		server:startServer(command, args, onStderr, function(output)
			micro.Log("lsp " .. command .. " exited", output)
		end)

		lsp:initialize(function(err)
			micro.InfoBar():Message(tostring(err.message))
		end)

		lsps[command] = lsp
	end

	return lsps[command]
end

function clientFor(buf)
	local command = commands[buf:FileType()]
	if command == nil then
		return nil
	end

	return lsps[command]
end
