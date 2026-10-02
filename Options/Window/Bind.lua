-- Manners -- options window: the window's handle on one control of the model.
--
-- A stand-in for the widgets' own tests, written to the contract the window
-- part builds the real one to; the integrator takes that one. It reads the
-- AceConfig-shaped definitions in ns.optionsTable the way AceConfigDialog
-- does: an info table whose last entry is the key, plain values or functions
-- of (info), and method names on the group's handler (AceDBOptions).

local _, ns = ...

local B = {}
ns.WindowBind = B

local function Group(tab)
	local root = ns.optionsTable
	return root and root.args and root.args[tab]
end

-- One field of a definition, evaluated: a function is called with the info
-- table and the rest, a string names a handler method, anything else is the
-- value itself. `get = false` stays false.
local function Ask(item, def, field, ...)
	local v = def[field]
	if type(v) == "function" then return v(item.info, ...) end
	if type(v) == "string" and field ~= "name" and field ~= "desc" and field ~= "confirmText"
		and field ~= "usage" then
		local handler = item.info.handler
		if handler and type(handler[v]) == "function" then return handler[v](handler, item.info, ...) end
	end
	return v
end

function B.Item(path, layoutEntry, ctx)
	local tab, key = tostring(path):match("^([^.]+)%.(.+)$")
	local group = tab and Group(tab)
	local def = group and group.args and group.args[key]
	if type(def) ~= "table" then return nil end
	local info = { tab, key, option = def, options = ns.optionsTable,
		handler = def.handler or group.handler, arg = def.arg, type = def.type }
	return { path = path, tab = tab, key = key, def = def, group = group, info = info,
		layout = layoutEntry or {}, ctx = ctx or {} }
end

function B.Value(item, ...)
	local def = item.def
	if def.get == false then return nil end
	if def.get == nil and item.group.get == nil then return nil end
	return Ask(item, def.get ~= nil and def or item.group, "get", ...)
end

function B.Text(item, field)
	local v = Ask(item, item.def, field)
	if v == nil then return nil end
	return tostring(v)
end

-- values in display order: `sorting` where there is one, by label otherwise.
function B.Values(item)
	local values = Ask(item, item.def, "values")
	if type(values) ~= "table" then return {} end
	local out = {}
	local sorting = Ask(item, item.def, "sorting")
	if type(sorting) == "table" then
		for _, key in ipairs(sorting) do
			if values[key] ~= nil then out[#out + 1] = { key, tostring(values[key]) } end
		end
		return out
	end
	for key, label in pairs(values) do out[#out + 1] = { key, tostring(label) } end
	table.sort(out, function(a, b) return a[2] < b[2] end)
	return out
end

local function Both(item, field)
	if Ask(item, item.group, field) == true then return true end
	return Ask(item, item.def, field) == true
end

function B.Hidden(item) return Both(item, "hidden") end
function B.Disabled(item) return Both(item, "disabled") end

local function Apply(item, ...)
	if item.def.type == "execute" then
		Ask(item, item.def, "func")
	else
		Ask(item, item.def, "set", ...)
	end
	local ctx = item.ctx
	if ctx and ctx.OnChange then ctx.OnChange(item) end
end

-- What the confirm asks, or nil for none.
local function ConfirmText(item, ...)
	local c = item.def.confirm
	if c == nil or c == false then return nil end
	if type(c) == "function" or type(c) == "string" then c = Ask(item, item.def, "confirm", ...) end
	if c == true then return B.Text(item, "confirmText") or B.Text(item, "name") or "" end
	if type(c) == "string" and c ~= "" then return c end
	return nil
end

function B.Commit(item, ...)
	if item.def.validate ~= nil and item.def.validate ~= false then
		local ok = Ask(item, item.def, "validate", ...)
		if type(ok) == "string" then return false, ok end
		if ok ~= true then return false, B.Text(item, "usage") end
	end
	local text = ConfirmText(item, ...)
	if not text then
		Apply(item, ...)
		return true
	end
	local n, args = select("#", ...), { ... }
	local ctx = item.ctx or {}
	ns.WindowWidgets.Modal(ctx.Window or UIParent, text, function()
		Apply(item, unpack(args, 1, n))
	end)
	return true
end

function B.Run(item)
	return B.Commit(item)
end
