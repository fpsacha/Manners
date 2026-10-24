-- Everything the addon holds that names a thing the client owns, for one client,
-- as JSON on stdout-by-return. Driven by tools/audit_ids.py, which compares it to
-- that client's own data tables (wago.tools DB2); run on its own it is a dump.
--
-- Called as chunk(cfg), cfg a table:
--   addon     the addon tree to load, forward slashes
--   flavour   camelot, vanilla, tbc, mists or mainline (Mock.FLAVOURS)
--
-- The addon is loaded on the mock exactly as tests/runscenarios.py loads it (the
-- mock, then the files Manners.toc lists, with the same ns), so what comes back is
-- what the set chosen for that client holds after Buffs.lua has run its lookups.
-- Nothing is changed in the tree.

local cfg = ...
local dir = tostring(cfg.addon):gsub("\\", "/"):gsub("/$", "")

MOCK_DEFAULT_FLAVOUR = cfg.flavour
dofile(dir .. "/tests/mockapi.lua")
Mock.reset()
local files = dofile(dir .. "/tests/addonfiles.lua")(dir)

local ns = {}
for _, file in ipairs(files) do
	local chunk, err = loadfile(dir .. "/" .. file)
	if not chunk then error("load " .. file .. ": " .. tostring(err)) end
	local ok, runErr = pcall(chunk, "Manners", ns)
	if not ok then error("run " .. file .. ": " .. tostring(runErr)) end
end

-- ------------------------------------------------------------------- JSON

local function esc(s)
	return '"' .. tostring(s):gsub('[%c"\\]', function(c)
		return string.format("\\u%04x", c:byte())
	end) .. '"'
end

local function isArray(t)
	local n = 0
	for _ in pairs(t) do n = n + 1 end
	if n == 0 then return true end
	for i = 1, n do if t[i] == nil then return false end end
	return true
end

local function encode(v, seen)
	local kind = type(v)
	if kind == "nil" then return "null" end
	if kind == "boolean" then return tostring(v) end
	if kind == "number" then
		if v ~= v or v == math.huge or v == -math.huge then return "null" end
		if v == math.floor(v) then return string.format("%d", v) end
		return tostring(v)
	end
	if kind == "string" then return esc(v) end
	if kind ~= "table" then return "null" end
	seen = seen or {}
	if seen[v] then return "null" end
	seen[v] = true
	local out = {}
	if isArray(v) then
		for i = 1, #v do out[#out + 1] = encode(v[i], seen) end
		seen[v] = nil
		return "[" .. table.concat(out, ",") .. "]"
	end
	local keys = {}
	for k in pairs(v) do keys[#keys + 1] = k end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
	for _, k in ipairs(keys) do
		out[#out + 1] = esc(k) .. ":" .. encode(v[k], seen)
	end
	seen[v] = nil
	return "{" .. table.concat(out, ",") .. "}"
end

-- ------------------------------------------------------------------ the data

-- Plain fields of a buff or a spell, dropping what the lookups hang on (class,
-- family, auraIds), which point back up the tree.
local SKIP = { class = true, family = true, auraIds = true, alikeIds = true, order = true, own = true }

local function plainCopy(t)
	local out = {}
	for k, v in pairs(t) do
		if not SKIP[k] then
			if type(v) == "table" then
				out[k] = plainCopy(v)
			else
				out[k] = v
			end
		end
	end
	return out
end

local function keysOf(t)
	local out = {}
	for k in pairs(t or {}) do out[#out + 1] = k end
	table.sort(out, function(a, b) return tostring(a) < tostring(b) end)
	return out
end

local function sortedIds(t)
	-- A set { [id] = true } or a list, as a sorted list.
	local out = {}
	if type(t) ~= "table" then return out end
	for k, v in pairs(t) do
		if type(k) == "number" and v == true then out[#out + 1] = k
		elseif type(v) == "number" then out[#out + 1] = v end
	end
	table.sort(out)
	return out
end

local RP = ns.InCharacter or {}

local data = {
	flavour = ns.Flavour and ns.Flavour.flavour,
	family = ns.Flavour and ns.Flavour.family,
	interface = ns.Flavour and ns.Flavour.interface,
	source = ns.BUFFS_SOURCE,
	buffs = plainCopy(ns.BUFFS or {}),
	own = plainCopy(ns.OWN_BUFFS or {}),
	favourOnly = sortedIds(ns.FAVOUR_ONLY_IDS),
	notFavour = sortedIds(ns.NOT_FAVOUR_IDS),
	rankLevel = {},
	-- How long each id lasts, seconds (Buffs.lua, "how long each lasts").
	seconds = ns.SPELL_SECONDS or {},
	classesWithout = keysOf(ns.CLASSES_WITHOUT_BUFFS),
	classesExclusive = keysOf(ns.EXCLUSIVE_BUFFS),
	classAuto = ns.CLASS_AUTO,
	manaClasses = keysOf(ns.MANA_CLASSES),
	flags = {
		partyIsSubgroup = ns.PARTY_IS_SUBGROUP, groupIsRaid = ns.GROUP_IS_RAID,
		wideCasts = ns.WIDE_CASTS, shoutYards = ns.SHOUT_YARDS,
		groupByClass = keysOf(ns.GROUP_BY_CLASS),
	},
	rpFamily = RP.FAMILY or {},
	rpRaceFamilies = keysOf(RP.RACE),
	rpClasses = keysOf(RP.CLASS),
	rpSame = keysOf(RP.SAME),
	rpSpell = keysOf(RP.SPELL),
	rpGift = keysOf(RP.GIFT),
	misc = {
		gcdSpell = 61304,
		soundFile = ns.SOUND_FILE,
	},
}
for id, level in pairs(ns.RANK_LEVEL or {}) do data.rankLevel[tostring(id)] = level end

return encode(data)
