local micro = import("micro")
local buffer = import("micro/buffer")
local config = import("micro/config")
local pluginPath = config.ConfigDir .. "/plug/lspClient/"
package.path = package.path .. ";" .. pluginPath .. "?.lua"
local json = require "json"
local utils = require "utils"

local Completion = {
    didHaveCompletions = false,
    snippetActive = false
}
Completion.__index = Completion

function Completion.new()
    return setmetatable({completions = {}}, Completion)
end

function Completion:fromItems(items)
    self.completions = {}
    self.didHaveCompletions = false

    if #items == 0 then 
        self.didHaveCompletions = false
        return 
    end

    self.didHaveCompletions = true

    for _, item in ipairs(items) do
        table.insert(self.completions, {
            label = item.label,              -- Display text: "•printf(const char *restrict, ...)"
            insertText = item.insertText,    -- Text to insert: "printf(${1:const char *restrict, ...})"
            detail = item.detail,            -- Type info: "int"
            documentation = item.documentation and item.documentation.value,  -- "From <stdio.h>"
            kind = item.kind,                -- 3 = Function
            sortText = item.sortText,        -- For ordering
            textEdit = item.textEdit         -- Range to replace
        })
    end

    -- Then sort by sortText (or label if sortText is missing)
    table.sort(self.completions, function(a, b)
        local sortA = a.sortText or a.label
        local sortB = b.sortText or b.label
        return sortA < sortB
    end)
end

local function repeatStr(str, len)
    -- Do NOT try to concat in a loop, it freezes micro...
	-- instead, use a temporary table to hold values
	local string_table = {}
	for i = 1, len do
		string_table[i] = str
	end
	-- Return the single string of repeated characters
	return table.concat(string_table)
end

function Completion:displayText(sideView)
    local textToDisplay = {}

    for _, comp in ipairs(self.completions) do
        local label = comp.label
        local detail = comp.detail

        local width = micro.CurPane():GetView().Width

        if label and detail then
            local label = comp.label:gsub("^•", "") 
            local padding = repeatStr(" ", width - string.len(label) - string.len(detail) - 1)
            table.insert(textToDisplay, label .. padding .. detail .. "\n")
        elseif label then
            local padding = repeatStr(" ", width - string.len(label) - 1)
            table.insert(textToDisplay, label .. padding .. "\n")
        end
    end

    sideView.Buf.EventHandler:Remove(sideView.Buf:Start(), sideView.Buf:End())
    for k, v in pairs(textToDisplay) do
        sideView.Buf.EventHandler:Insert(buffer.Loc(0, k - 1), v)
    end
end

function Completion:autoComplete()
    local item = self.completions[micro.CurPane().Buf:GetActiveCursor().Y + 1]

    if item == nil then
        return false
    end
    
    local textEdit = item['textEdit']
    local range = textEdit['range']
    local rangeStart = range['start']
    local rangeEnd = range['end']
    
    micro.Log('New text before cleaning:', textEdit['newText'])
    
    local originalText = textEdit['newText']
    originalText = string.gsub(originalText, ",%s+%$", ",$")

    local newText = string.gsub(originalText, "%$%{%d+:?[^}]*%}", "")
    newText = string.gsub(newText, "%$%d+", "")

    micro.Log('New text after cleaning:', newText)
    
    local startLoc = buffer.Loc(rangeStart['character'], rangeStart['line'])
    local endLoc = buffer.Loc(rangeEnd['character'], rangeEnd['line'])

    if originalText ~= nil and self.snippetActive == false then 
        self.snippetActive = string.find(originalText, "%${%d") ~= nil or self.snippetActive
    end

    micro.CurPane():PreviousSplit()
    local curPane = micro.CurPane()
    curPane.Buf.EventHandler:Remove(startLoc, endLoc)
    curPane.Buf.EventHandler:Insert(startLoc, newText)
    
    local cursor_pos = self:findCursorPosition(originalText, newText, rangeStart['character'], rangeStart['line'])
    curPane.Cursor:GotoLoc(cursor_pos)
    
    return true
end

function Completion:findCursorPosition(originalText, cleanedText, baseChar, baseLine)
    local matchStart, matchEnd = string.find(originalText, "%$%{%d:?[^}]*%}")
    if matchStart then
        local prefix = string.sub(originalText, 1, matchStart - 1)
        local cleanedPrefix = string.gsub(prefix, "%$%{%d+:?[^}]*%}", "")
        cleanedPrefix = string.gsub(cleanedPrefix, "%$%d+", "")
        return buffer.Loc(baseChar + string.len(cleanedPrefix), baseLine)
    end
    
    if string.len(cleanedText) >= 2 then
        local lastTwo = string.sub(cleanedText, -2)
        local pairs = {
            ["[]"] = true,
            ["{}"] = true,
            ["<>"] = true,
            ["''"] = true,
            ['""'] = true,
            ["``"] = true
        }
        
        if pairs[lastTwo] then
            return buffer.Loc(baseChar + string.len(cleanedText) - 1, baseLine)
        end
    end
    
    return buffer.Loc(baseChar + string.len(cleanedText), baseLine)
end

return Completion
