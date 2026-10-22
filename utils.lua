local go_os = import("os")
local home, _ = go_os.UserHomeDir()
local pluginPath = home .. '/.config/micro/plug/lspClient/'
package.path = package.path .. ";" .. pluginPath .. "?.lua"
local json = require "json"
local fmt = import("fmt")
local util = import("micro/util")

local function getLspArgs(lsp, rootUri)
  if lsp == "jdtls" then
    local args = "-data " .. rootUri
    return {args}
  elseif lsp == "gopls" then 
    return {
      "-logfile=auto",
      "-debug=:0",
      "-remote.debug=:0",
      "-rpc.trace"
    }
  elseif lsp == "clangd" then
    -- wait for the preamble so #include and header symbols complete
    return {"--completion-parse=always"}
  end

  return {}
end

local function parseMessage(message)
  local jsonStart = message:find("\r\n\r\n")

  if jsonStart then
      local jsonBody = message:sub(jsonStart + 4)
      local status, body = pcall(json.decode, jsonBody)

      if status then 
        return body 
      end
  end
  
  return nil
end

local function getFileText(bp) 
  return util.String(bp.Buf:Bytes())
end

local function getRootUri(wd)
  return fmt.Sprintf("file://%s", wd)
end

local function getInitiaizeParams(rootUri, pid) 
  return {
    processId = pid,
    rootPath = projectPath,
    rootUri = rootUri,
    workspaceFolders = workspaceFolders,
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
    parseMessage = parseMessage,
    getFileText = getFileText,
    getLspArgs = getLspArgs,
    getInitiaizeParams = getInitiaizeParams
}