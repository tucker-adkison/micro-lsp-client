local config = import("micro/config")
local pluginPath = config.ConfigDir .. "/plug/lspClient/"
package.path = package.path .. ";" .. pluginPath .. "?.lua"
local fmt = import("fmt")
local util = import("micro/util")
local micro = import("micro")

local function getLspArgs(lsp, rootUri)
	if lsp == "jdtls" then
		local args = "-data " .. rootUri
		return { args }
	elseif lsp == "gopls" then
		return {
			"-logfile=auto",
			"-debug=:0",
			"-remote.debug=:0",
			"-rpc.trace",
		}
	elseif lsp == "clangd" then
		-- wait for the preamble so #include and header symbols complete
		return { "--completion-parse=always" }
	end

	return {}
end

local function getFileText(buf)
	return util.String(buf:Bytes())
end

local function getRootUri(wd)
	return fmt.Sprintf("file://%s", wd)
end

local function getOpenPaths()
	local open = {}
	local tabs = micro.Tabs()
	for i = 1, #tabs.List do
		local tab = tabs.List[i]
		for j = 1, #tab.Panes do
			local buf = tab.Panes[j].Buf
			if buf ~= nil then
				local uri = getRootUri(buf.AbsPath)
				open[uri] = true
			end
		end
	end

	return open
end

local function getInitiaizeParams(rootUri, pid)
	return {
		processId = pid,
		rootUri = rootUri,
		-- The capabilities supported.
		-- TODO the capabilities set to false/undefined are TODO. See {ls.ServerCapabilities} for a full list.
		capabilities = {
			workspace = {
				applyEdit = true,
				configuration = false,
				workspaceEdit = {
					documentChanges = true,
				},
				workspaceFolders = false,
				didChangeConfiguration = {
					dynamicRegistration = false,
				},
				didChangeWatchedFiles = {
					dynamicRegistration = false,
				},
				symbol = {
					dynamicRegistration = false,
				},
				executeCommand = {
					dynamicRegistration = false,
				},
			},
			textDocument = {
				synchronization = {
					dynamicRegistration = false,
					willSave = true,
					willSaveWaitUntil = true,
					didSave = true,
				},
				completion = {
					dynamicRegistration = false,
					completionItem = {
						snippetSupport = true,
						commitCharactersSupport = false,
					},
					contextSupport = true,
				},
				hover = {
					dynamicRegistration = false,
				},
				signatureHelp = {
					dynamicRegistration = false,
				},
				references = {
					dynamicRegistration = false,
				},
				documentHighlight = {
					dynamicRegistration = false,
				},
				documentSymbol = {
					dynamicRegistration = false,
					hierarchicalDocumentSymbolSupport = true,
				},
				formatting = {
					dynamicRegistration = false,
				},
				rangeFormatting = {
					dynamicRegistration = false,
				},
				onTypeFormatting = {
					dynamicRegistration = false,
				},
				definition = {
					dynamicRegistration = false,
				},
				codeAction = {
					dynamicRegistration = false,
				},
				codeLens = {
					dynamicRegistration = false,
				},
				documentLink = {
					dynamicRegistration = false,
				},
				rename = {
					dynamicRegistration = false,
				},
			},
			experimental = {},
		},
	}
end

return {
	getRootUri = getRootUri,
	getFileText = getFileText,
	getLspArgs = getLspArgs,
	getInitiaizeParams = getInitiaizeParams,
	getOpenPaths = getOpenPaths,
}
