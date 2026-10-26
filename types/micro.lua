---@meta

-- Declarations for the Lua language server only. micro loads the .lua files
-- in the plugin folder itself, not in this subfolder, so this file never runs.
-- Panes, buffers and cursors stay `any` until the plugin needs their types.

---@class micro.module
---@field Log fun(...: any)
---@field CurPane fun(): any
---@field Tabs fun(): any
---@field InfoBar fun(): any

---@class micro.config
---@field ConfigDir string
---@field RTHelp integer
---@field RegisterCommonOption fun(plugin: string, name: string, default: any): any
---@field GetGlobalOption fun(name: string): any
---@field TryBindKey fun(key: string, action: string, overwrite: boolean): boolean, any
---@field AddRuntimeFile fun(plugin: string, filetype: integer, path: string)

---@class micro.shell
---@field JobSend fun(job: any, data: string)
---@field JobSpawn fun(command: string, args: string[], onStdout: function?, onStderr: function?, onExit: function?, ...: any): any

---@class micro.buffer
---@field Loc fun(x: integer, y: integer): any
---@field NewBuffer fun(text: string, path: string): any

---@class micro.util
---@field String fun(bytes: any): string

---@class go.os
---@field Getwd fun(): string, any
---@field Getpid fun(): integer

---@class go.fmt
---@field Sprintf fun(format: string, ...: any): string

---micro gives plugins `import` at runtime. It returns a micro module or a Go package.
---@overload fun(module: "micro"): micro.module
---@overload fun(module: "micro/config"): micro.config
---@overload fun(module: "micro/shell"): micro.shell
---@overload fun(module: "micro/buffer"): micro.buffer
---@overload fun(module: "micro/util"): micro.util
---@overload fun(module: "os"): go.os
---@overload fun(module: "fmt"): go.fmt
---@param module string
---@return any
function import(module) end
