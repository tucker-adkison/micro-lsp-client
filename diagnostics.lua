local config = import("micro/config")
local pluginPath = config.ConfigDir .. "/plug/lspClient/"
package.path = package.path .. ";" .. pluginPath .. "?.lua"

local buffer = import("micro/buffer")

local Diagnostics = {}

local kinds = { buffer.MTError, buffer.MTWarning, buffer.MTInfo, buffer.MTInfo }

function Diagnostics.show(buf, owner, diagnostics)
	buf:ClearMessages(owner)

	for _, d in ipairs(diagnostics) do
		local s, e = d.range.start, d.range["end"]
		buf:AddMessage(
			buffer.NewMessage(
				owner,
				d.message,
				buffer.Loc(s.character, s.line),
				buffer.Loc(e.character, e.line),
				kinds[d.severity or 1]
			)
		)
	end
end

function Diagnostics.summary(buf)
	local errors, warnings = 0, 0

	for i = 1, #buf.Messages do
		local m = buf.Messages[i]
		if string.sub(m.Owner, 1, 4) == "lsp " then
			if m.Kind == buffer.MTError then
				errors = errors + 1
			elseif m.Kind == buffer.MTWarning then
				warnings = warnings + 1
			end
		end
	end

	local parts = {}
	if errors > 0 then
		table.insert(parts, "E" .. errors)
	end
	if warnings > 0 then
		table.insert(parts, "W" .. warnings)
	end
	return table.concat(parts, " ")
end

return Diagnostics
