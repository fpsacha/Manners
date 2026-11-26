-- The Services module's exact definitions for one client and class, as JSON.
-- Used by tools/audit_services.py; the runtime module stays the source of truth.

local cfg = ...
local dir = tostring(cfg.addon):gsub("\\", "/"):gsub("/$", "")

MOCK_DEFAULT_FLAVOUR = cfg.flavour
dofile(dir .. "/tests/mockapi.lua")
Mock.reset()
Mock.class = cfg.class_name

local files = dofile(dir .. "/tests/addonfiles.lua")(dir)
local ns = {}
for _, file in ipairs(files) do
	local chunk, err = loadfile(dir .. "/" .. file)
	if not chunk then error("load " .. file .. ": " .. tostring(err)) end
	local ok, runErr = pcall(chunk, "Manners", ns)
	if not ok then error("run " .. file .. ": " .. tostring(runErr)) end
end
assert(ns.ProbeCapabilities, "core capability probe is missing")()
for _, file in ipairs({ "Courtesy.lua", "FireShield.lua", "Init.lua" }) do
	local chunk, err = loadfile(dir .. "/Modules/Services/" .. file)
	if not chunk then error("load Services/" .. file .. ": " .. tostring(err)) end
	local ok, runErr = pcall(chunk)
	if not ok then error("run Services/" .. file .. ": " .. tostring(runErr)) end
end

local function esc(s)
	return '"' .. tostring(s):gsub('[%c"\\]', function(c)
		return string.format("\\u%04x", c:byte())
	end) .. '"'
end

local function array(t)
	local n = 0
	for _ in pairs(t) do n = n + 1 end
	if n == 0 then return true end
	for i = 1, n do if t[i] == nil then return false end end
	return true
end

local function encode(value)
	local kind = type(value)
	if kind == "nil" then return "null" end
	if kind == "boolean" then return tostring(value) end
	if kind == "number" then return tostring(value) end
	if kind == "string" then return esc(value) end
	if kind ~= "table" then return "null" end
	local out = {}
	if array(value) then
		for i = 1, #value do out[#out + 1] = encode(value[i]) end
		return "[" .. table.concat(out, ",") .. "]"
	end
	local keys = {}
	for key in pairs(value) do keys[#keys + 1] = key end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
	for _, key in ipairs(keys) do
		out[#out + 1] = esc(key) .. ":" .. encode(value[key])
	end
	return "{" .. table.concat(out, ",") .. "}"
end

return encode(assert(ns.Courtesy.AuditData, "Services audit data is missing")())
