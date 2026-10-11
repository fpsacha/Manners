-- The Lua half of tools/migration_check.py: load an old release of the addon on
-- the current mock, play a little, write its saved variables out; then load the
-- current addon on such a file and look at what became of the player's choices.
--
-- Run by migration_check.py, one Lua state per stage. Everything the stages
-- need from outside arrives in the global MIG:
--   repo       this checkout (tests/mockapi.lua, tests/addonfiles.lua)
--   libs       a folder holding CallbackHandler-1.0, AceDB-3.0 and AceDBOptions-3.0
--              (the real libraries: the mock's AceDB keeps no profileKeys and
--              never strips a default, so it cannot say what a saved file holds)
--   flavour    the client the mock stands in for
--   class      the player's class (PRIEST: it has three buffs to pin among)
--   charName   the character's name; charSurname its surname on Forever
-- and a stage's own inputs.
--
-- Not shipped, not loaded by the game.

local M = {}

---------------------------------------------------------------------------
-- small things
---------------------------------------------------------------------------

local function copy(v)
	if type(v) ~= "table" then return v end
	local out = {}
	for k, inner in pairs(v) do out[k] = copy(inner) end
	return out
end
M.copy = copy

local function keyText(k) return type(k) == "number" and ("[" .. k .. "]") or tostring(k) end

-- Every place two values differ, "path: a -> b", sorted.
local function diff(a, b, path, out)
	out = out or {}
	path = path or ""
	if type(a) == "table" and type(b) == "table" then
		local seen = {}
		for k, v in pairs(a) do
			seen[k] = true
			diff(v, b[k], path .. (path == "" and "" or ".") .. keyText(k), out)
		end
		for k, v in pairs(b) do
			if not seen[k] then diff(nil, v, path .. (path == "" and "" or ".") .. keyText(k), out) end
		end
	elseif a ~= b and not (a ~= a and b ~= b) then
		local function show(v)
			if type(v) == "string" then return ("%q"):format(#v > 60 and v:sub(1, 57) .. "..." or v) end
			return tostring(v)
		end
		out[#out + 1] = path .. ": " .. show(a) .. " -> " .. show(b)
	end
	table.sort(out)
	return out
end
M.diff = diff

local function getp(root, path)
	local t = root
	local keys = {}
	for seg in path:gmatch("[^%.]+") do keys[#keys + 1] = seg end
	for i = 1, #keys - 1 do
		if type(t) ~= "table" then return nil, nil end
		t = t[keys[i]]
	end
	if type(t) ~= "table" then return nil, nil end
	return t, keys[#keys]
end

---------------------------------------------------------------------------
-- the world
---------------------------------------------------------------------------

function M.env()
	if MIG.flavour and MIG.flavour ~= "camelot" then MOCK_DEFAULT_FLAVOUR = MIG.flavour end
	dofile(MIG.repo .. "/tests/mockapi.lua")
	Mock.reset()
	Mock.class = MIG.class or "PRIEST"
	if MIG.locale then Mock.locale = MIG.locale end
	-- The mock's player knows one spell, Arcane Intellect rank 1. A priest who
	-- is to have a prompt knows her own.
	IsSpellKnown = function() return true end
	IsPlayerSpell = IsSpellKnown

	-- What the real libraries ask the client for and the mock has no reason to
	-- answer. Only what is missing is added.
	local function shim(name, fn)
		if rawget(_G, name) == nil then _G[name] = fn end
	end
	shim("securecallfunction", function(fn, ...) return fn(...) end)
	shim("geterrorhandler", function() return function(e) error(e, 0) end end)
	shim("strlenutf8", function(s) return #(s:gsub("[\128-\191]", "")) end)
	shim("UnitFactionGroup", function() return "Alliance", "Alliance" end)
	shim("GetRealmName", function() return "Realm" end)
	shim("GetCurrentRegionName", function() return "EU" end)
	shim("GetCurrentRegion", function() return 3 end)
	shim("NORMAL_FONT_COLOR_CODE", "|cffffd200")
	shim("FONT_COLOR_CODE_CLOSE", "|r")
	local name, surname = MIG.charName or "Mort", MIG.charSurname or "Defrette"
	shim("UnitNameUnmodified", function() return name, Mock.surnames and surname or nil end)
	if Mock.surnames then
		-- Forever's player has a surname, and AceDB keys the character by
		-- "Name Surname" (the library's RegionalUniqueNames branch, minor 39).
		-- Offered only while the library loads: the addon asks the same
		-- question, and the mock's answer to it is the standard scenarios'.
		RegionalUniqueNamesEnabled = function() return true end
		C_GameRules = { IsGameRuleActive = function() return false end }
		Enum = Enum or {}
		Enum.GameRule = { HardcoreRuleset = 1, RPRuleset = 2, PvPRuleset = 3 }
	end

	-- The mock's LibStub has no NewLibrary: the real one's, so the real
	-- libraries can register.
	LibStub.NewLibrary = LibStub.NewLibrary or function(self, major, minor)
		minor = assert(tonumber(tostring(minor):match("%d+")), "bad minor")
		local old = self.minors[major]
		if old and old >= minor then return nil end
		self.minors[major], self.libs[major] = minor, self.libs[major] or {}
		return self.libs[major], old
	end
	for _, major in ipairs({ "CallbackHandler-1.0", "AceDB-3.0", "AceDBOptions-3.0" }) do
		LibStub.libs[major], LibStub.minors[major] = nil, nil
		local path = MIG.libs .. "/" .. major .. "/" .. major .. ".lua"
		local chunk, err = loadfile(path)
		if not chunk then error("cannot load " .. path .. ": " .. tostring(err), 0) end
		chunk()
	end
	if Mock.surnames then
		RegionalUniqueNamesEnabled, C_GameRules = nil, nil
	end
	-- Real libraries stay for the whole state: Mock.reset() is not called again.
end

-- A file compiled once per Lua state and loaded again from its bytecode, as
-- tests/runscenarios.py does: compiling is most of what a load costs.
local kept = {}
local function compiled(path)
	local bytes = kept[path]
	if bytes then return loadstring(bytes, "@" .. path) end
	local chunk, err = loadfile(path)
	if chunk then kept[path] = string.dump(chunk) end
	return chunk, err
end

-- AceDB keeps every database it makes for the session, which in the game is
-- one; a tool that loads the addon again and again would keep each copy (about
-- 4 MB) for ever. The one a load replaces is let go of.
local function forgetDatabases()
	local lib = LibStub and LibStub.libs and LibStub.libs["AceDB-3.0"]
	local registry = lib and lib.db_registry
	if type(registry) == "table" then
		for db in pairs(registry) do registry[db] = nil end
	end
	-- And AceDBOptions the same, a table of controls and a handler per database.
	local options = LibStub and LibStub.libs and LibStub.libs["AceDBOptions-3.0"]
	for _, name in ipairs({ "optionTables", "handlers" }) do
		if options and type(options[name]) == "table" then
			for db in pairs(options[name]) do options[name][db] = nil end
		end
	end
end

-- The addon's files in toc order, as tests/scenarios.lua's load() does.
function M.load(src)
	forgetDatabases()
	local files = dofile(MIG.repo .. "/tests/addonfiles.lua")(src)
	local ns = {}
	for _, file in ipairs(files) do
		local chunk, err = compiled(src .. "/" .. file)
		if not chunk then return nil, "load " .. file .. ": " .. tostring(err) end
		local ok, runErr = pcall(chunk, "Manners", ns)
		if not ok then return nil, "run " .. file .. ": " .. tostring(runErr) end
	end
	return ns
end

local function guarded(ns)
	local out = {}
	for _, e in ipairs(ns.errors or {}) do
		out[#out + 1] = tostring(e.where) .. " -> " .. tostring(e.err)
	end
	return out
end

-- Run each step, collecting the ones that threw.
local function steps(list)
	local failed = {}
	for _, step in ipairs(list) do
		local ok, err = pcall(step[2])
		if not ok then failed[#failed + 1] = step[1] .. " -> " .. tostring(err) end
	end
	return failed
end

local function lifecycle(ns)
	return {
		{ "OnInitialize", function() ns.addon:OnInitialize() end },
		{ "OnEnable", function() ns.addon:OnEnable() end },
		{ "PLAYER_ENTERING_WORLD", function() ns.addon:PLAYER_ENTERING_WORLD() end },
		{ "BuildQueue", function() return ns.BuildQueue() end },
		{ "Tick", function() ns.addon:Tick() end },
		{ "Tick again", function() ns.addon:Tick() end },
	}
end

-- AceDB's logout: every default stripped from the saved tables, exactly as
-- the game's file is written.
function M.logout()
	local frame = LibStub("AceDB-3.0").frame
	local onEvent = frame and frame.scripts and frame.scripts.OnEvent
	if not onEvent then error("AceDB registered no logout handler", 0) end
	onEvent(frame, "PLAYER_LOGOUT")
end

---------------------------------------------------------------------------
-- stage 1: an old release plays a little and logs out
---------------------------------------------------------------------------

-- What a player might have set. Applied only where the old release has a
-- setting of that name and kind; the report says which were.
local EDITS = {
	{ "filters.minLevel", 23 }, { "filters.requireInRange", false },
	{ "filters.whenBuffed", "refresh" }, { "filters.refreshUnder", 9 },
	{ "filters.proximity", "cast" }, { "filters.restoreTarget", false },
	{ "filters.hideMounted", true }, { "filters.skipSameClass", true },
	{ "filters.manaFloor", 30 }, { "filters.relevantOnly", false },
	{ "filters.reachableOnly", false }, { "filters.skipPvP", false },
	{ "filters.restingOnly", true },
	{ "sources.owed", false }, { "sources.strangers", false }, { "sources.asked", true },
	{ "sources.self", false }, { "sources.group", false },
	{ "priority.friends", false }, { "priority.target", false },
	{ "groupBuffs.use", false }, { "groupBuffs.atLeast", 4 },
	{ "speech.enabled", true }, { "speech.channel", "YELL" },
	{ "speech.onlyWhenReturning", true },
	{ "speech.phrases", "Merci beaucoup, {name}\nDanke schoen\nBlessings upon you, friend" },
	{ "prompt.point", "TOPLEFT" }, { "prompt.relPoint", "TOPLEFT" },
	{ "prompt.x", 120 }, { "prompt.y", -80 }, { "prompt.scale", 1.25 },
	{ "prompt.width", 260 }, { "prompt.height", 52 }, { "prompt.alpha", 0.8 },
	{ "prompt.style", "framed" }, { "prompt.fontSize", 15 }, { "prompt.iconSize", 36 },
	{ "prompt.hideInCombat", true }, { "prompt.showQueue", true }, { "prompt.queueRows", 4 },
	{ "prompt.classColor", false }, { "prompt.showSub", false }, { "prompt.format", "{name} !" },
	{ "prompt.reasonOwed", "owes you" }, { "prompt.thankEmote", true },
	{ "prompt.fontColor", { 1, 0.8, 0, 1 } }, { "prompt.bgColor", { 0.1, 0.2, 0.3, 0.7 } },
	{ "prompt.accentColor", { 0.9, 0.1, 0.5, 1 } },
	{ "timing.reciprocateWindow", 90 }, { "timing.graceSeconds", 60 },
	{ "sound.enabled", true }, { "sound.owedOnly", false },
	{ "verbose", false }, { "minimap.hide", true }, { "minimap.minimapPos", 100 },
}
-- A second profile, different from the first where it matters.
local ALT_EDITS = {
	{ "speech.channel", "EMOTE" }, { "prompt.scale", 0.8 }, { "prompt.x", 15 },
	{ "prompt.y", 40 }, { "filters.minLevel", 12 }, { "sources.asked", true },
	{ "prompt.format", "{name}" }, { "speech.phrases", "Hi there\nWell met" },
}
local NEVER = { "Rudeman", "Zed Quill", "Bart-Stormrage" }

local function applyEdits(profile, list, applied)
	for _, edit in ipairs(list) do
		local holder, key = getp(profile, edit[1])
		if holder then
			local current = holder[key]
			if current ~= nil and type(current) == type(edit[2]) then
				holder[key] = copy(edit[2])
				applied[edit[1]] = copy(edit[2])
			end
		end
	end
end

function M.old()
	M.env()
	local report = { fixture = {}, alt = {}, steps = {}, notes = {} }
	local ns, why = M.load(MIG.src)
	if not ns then
		report.status = "skip"
		report.reason = why
		return report
	end
	local function add(list)
		for _, line in ipairs(list) do report.steps[#report.steps + 1] = line end
	end
	add(steps(lifecycle(ns)))
	if not ns.db then
		report.status = "skip"
		report.reason = "OnInitialize made no database: " .. tostring(report.steps[1])
		return report
	end

	-- A favour the way the game brings one -- a buff landing on the player from
	-- a nameplate -- while the filters are still the defaults, so the ledger has
	-- a row to carry across.
	add(steps({ { "a favour", function()
		Mock.advance(10)
		for _ = 1, 3 do
			ns.ScanOwnBuffs()
			Mock.runTimers(0.3)
		end
		Mock.extraAura = 4001
		Mock.extraAuraSpell = 1243
		Mock.extraAuraSource = "nameplate1"
		ns.addon:UNIT_AURA(nil, "player")
		if ns.FlushOwnScan then ns.FlushOwnScan() end
	end } }))

	-- The options model, as a player opens it (the current window builds
	-- several tabs; an old release has its AceConfig table).
	add(steps({ { "options", function()
		if type(ns.OpenOptions) == "function" then ns.OpenOptions() end
	end } }))
	report.hasOptionsTable = type(ns.optionsTable) == "table"

	local profile = ns.db.profile
	local before = copy(profile)

	-- A pinned buff: a class buff the release has, not the first.
	local okList, list = pcall(function() return ns.GetClassBuffs(Mock.class) end)
	if okList and type(list) == "table" and type(profile.buff) == "table" then
		local pick = list[2] or list[1]
		if pick and pick.key then
			profile.buff.choice = pick.key
			report.fixture["buff.choice"] = pick.key
			report.pinned = pick.key
		end
	end
	if type(profile.buff) == "table" and type(profile.buff.skip) == "table" and okList and type(list) == "table"
		and list[3] and list[3].key then
		profile.buff.skip[list[3].key] = true
		report.fixture["buff.skip." .. list[3].key] = true
	end
	if type(profile.never) == "table" then
		for _, name in ipairs(NEVER) do
			profile.never[name] = true
			report.fixture["never." .. name] = true
		end
	end
	if type(profile.filters) == "table" and type(profile.filters.skipRaidGroups) == "table" then
		profile.filters.skipRaidGroups[3] = true
		profile.filters.skipRaidGroups[8] = true
		report.fixture["filters.skipRaidGroups.[3]"] = true
		report.fixture["filters.skipRaidGroups.[8]"] = true
	end
	applyEdits(profile, EDITS, report.fixture)
	-- Settings a later release renamed or turned into another kind: the old
	-- value is written when the release still has the setting.
	if type(profile.filters) == "table" and profile.filters.skipIfBuffed ~= nil then
		profile.filters.skipIfBuffed = false
		report.fixture["filters.skipIfBuffed"] = false
	end
	-- A pick of an own-buff family, if the release has them.
	if type(profile.ownBuffs) == "table" and type(profile.ownBuffs.pick) == "table" then
		for family in pairs(profile.ownBuffs.pick) do
			profile.ownBuffs.pick[family] = "off"
			report.fixture["ownBuffs.pick." .. family] = "off"
			break
		end
	end

	-- The slash commands an old release has (an unknown word prints help).
	add(steps({
		{ "/never", function() ns.addon:HandleSlash("never Plainfolk") end },
		{ "/restore", function() ns.addon:HandleSlash("restore") ns.addon:HandleSlash("restore") end },
		{ "/snooze", function() ns.addon:HandleSlash("snooze 5") end },
		{ "/macro", function() ns.addon:HandleSlash("macro") end },
		{ "/unlock", function() ns.addon:HandleSlash("unlock") ns.addon:HandleSlash("lock") end },
		{ "/export", function() ns.addon:HandleSlash("export") end },
	}))
	if type(profile.never) == "table" and profile.never["Plainfolk"] then
		report.fixture["never.Plainfolk"] = true
	end
	-- A debt, which the logout saves, and a favour the way the game brings one:
	-- a buff landing on the player from a nameplate, so the ledger has a row.
	pcall(function()
		ns.owed["Dunmore"] = { expires = GetTime() + 100, at = GetTime(), class = "PRIEST" }
	end)
	report.profileChanges = diff(before, profile)

	-- A second profile and back.
	add(steps({
		{ "SetProfile Alt", function() ns.db:SetProfile("Alt") end },
		{ "edit Alt", function() applyEdits(ns.db.profile, ALT_EDITS, report.alt) end },
		{ "SetProfile Default", function() ns.db:SetProfile("Default") end },
	}))

	-- The two ends of every slider this release drew, each in a profile of its
	-- own: what the player could have set, whatever the current limits are.
	report.extremes = {}
	pcall(function()
		local function control(tab, key) return ns.optionsTable.args[tab].args[key] end
		local ranges = {}
		for tab, group in pairs(ns.optionsTable.args or {}) do
			for key, def in pairs(group.args or {}) do
				if def.type == "range" and tab ~= "profiles" then ranges[#ranges + 1] = { tab, key, def, group } end
			end
		end
		table.sort(ranges, function(a, b) return a[1] .. a[2] < b[1] .. b[2] end)
		for _, which in ipairs({ "min", "max" }) do
			local name = "Slider-" .. which
			ns.db:SetProfile(name)
			for _, r in ipairs(ranges) do
				local tab, key, def, group = r[1], r[2], r[3], r[4]
				local info = { tab, key, options = ns.optionsTable, option = def, handler = group.handler or ns.optionsTable.handler,
					arg = def.arg, type = "range", appName = "Manners", uiType = "dialog", uiName = "Manners" }
				info[0] = "Manners"
				local limit = def[which]
				if type(limit) == "function" then limit = limit(info) end
				local set = def.set or group.set or ns.optionsTable.set
				local before = copy(ns.db.profile)
				if type(limit) == "number" and type(set) == "function" then
					pcall(set, info, limit)
					for _, line in ipairs(diff(before, ns.db.profile)) do
						local path, value = line:match("^(.-): .- %-> (.*)$")
						if path and tonumber(value) then
							report.extremes[#report.extremes + 1] = { profile = name, path = path, value = tonumber(value),
								control = tab .. "." .. key, offered = limit }
						end
					end
				end
			end
			ns.db:SetProfile("Default")
		end
	end)

	-- One profile per ready-made phrase set, its text exactly as this release
	-- wrote it into the box (a set picked before 1.0.0-beta.5 stays in English
	-- on every client, and sets were rewritten since).
	report.sets = {}
	local setKeys = {}
	pcall(function()
		for key, set in pairs(ns.PHRASE_SETS or {}) do
			if type(set) == "table" then setKeys[#setKeys + 1] = key end
		end
	end)
	table.sort(setKeys)
	for _, key in ipairs(setKeys) do
		local okText, text = pcall(function()
			if type(ns.PhraseSetText) == "function" then return ns.PhraseSetText(key) end
			return table.concat(ns.PHRASE_SETS[key].lines, "\n")
		end)
		if okText and type(text) == "string" and text ~= "" then
			add(steps({
				{ "SetProfile Set-" .. key, function() ns.db:SetProfile("Set-" .. key) end },
				{ "box Set-" .. key, function()
					ns.db.profile.speech.phrases = text
					ns.db.profile.speech.presetChoice = key
				end },
			}))
			report.sets[key] = text
		end
	end
	add(steps({ { "SetProfile Default", function() ns.db:SetProfile("Default") end } }))

	-- The player's tick, then the logout.
	add(steps({ { "Tick", function() Mock.advance(1) ns.addon:Tick() end } }))
	-- The defaults this release stripped from the file at logout, so a value
	-- the new release reads differently because the DEFAULT moved is told
	-- from one it lost.
	report.defaults = copy(ns.db.defaults and ns.db.defaults.profile or {})
	report.owedBefore = {}
	for name in pairs(ns.owed or {}) do report.owedBefore[#report.owedBefore + 1] = name end
	table.sort(report.owedBefore)
	local errs = guarded(ns)
	report.guarded = errs
	local ok, err = pcall(M.logout)
	if not ok then
		report.status = "nologout"
		report.reason = tostring(err)
		return report
	end
	report.status = "ok"
	report.charKey = nil
	for k in pairs(MannersDB and MannersDB.profileKeys or {}) do report.charKey = k end
	report.sv = MannersDB
	report.version = ns.BUILD
	report.firstRun = {}
	for name, saved in pairs(MannersDB and MannersDB.profiles or {}) do
		report.firstRun[name] = type(saved) == "table" and saved.firstRun or false
	end
	return report
end

---------------------------------------------------------------------------
-- stage 2: the current addon on such a file
---------------------------------------------------------------------------

local function reasonLines(ns)
	local out = {}
	for _, line in ipairs(ns.repairLog or {}) do out[#out + 1] = line end
	return out
end

-- The fixture's values against a profile: what differs.
local function fixtureDiffs(profile, fixture, log)
	local out = {}
	for path, want in pairs(fixture) do
		local got, key
		local setKey = path:match("^(.-)%.%[%d+%]$")
		if setKey then
			local num = tonumber(path:match("%[(%d+)%]$"))
			local holder, k = getp(profile, setKey)
			got = holder and type(holder[k]) == "table" and holder[k][num]
			key = k
		else
			local holder, k = getp(profile, path)
			got, key = holder and holder[k], k
			if holder == nil then
				-- never.<name> and buff.skip.<key> carry the name after the dot
				local parent, name = path:match("^(.-)%.([^%.]+)$")
				local h, kk = getp(profile, parent or "")
				if parent and (parent == "never" or parent == "buff.skip") then
					local holder2 = (parent == "never") and profile.never or (profile.buff and profile.buff.skip)
					got = holder2 and holder2[name]
					key = name
				end
			end
		end
		if type(want) == "table" then
			if #diff(want, got or {}) > 0 then
				out[#out + 1] = { path = path, want = want, got = got, logged = false }
			end
		elseif got ~= want then
			local logged = false
			for _, line in ipairs(log) do
				if key and line:find(tostring(key), 1, true) then logged = true end
			end
			out[#out + 1] = { path = path, want = want, got = got, logged = logged }
		end
	end
	table.sort(out, function(a, b) return a.path < b.path end)
	return out
end

local function ids(ns)
	local list = {}
	local layout = ns.WindowLayout
	if type(layout) == "table" and type(layout.groups) == "table" then
		for _, group in ipairs(layout.groups) do
			for _, id in ipairs(group) do list[#list + 1] = id end
		end
	end
	return list
end

function M.new()
	M.env()
	local report = { findings = {}, notes = {} }
	local function finding(kind, detail) report.findings[#report.findings + 1] = { kind = kind, detail = detail } end

	-- The dump becomes the SavedVariables global, as the game reads the file.
	if MIG.svFile then
		-- A real SavedVariables file: Lua source that sets MannersDB.
		local chunk, err = loadfile(MIG.svFile)
		if not chunk then error("cannot read " .. MIG.svFile .. ": " .. tostring(err), 0) end
		chunk()
	else
		_G.MannersDB = MIG.sv
	end
	local ns, why = M.load(MIG.repo)
	if not ns then
		report.status = "fail"
		finding("load", why)
		return report
	end
	local failed = steps(lifecycle(ns))
	for _, line in ipairs(failed) do finding("step", line) end
	if not ns.db then
		report.status = "fail"
		finding("database", "OnInitialize made no database")
		return report
	end
	local charProfile = ns.db:GetCurrentProfile()
	report.profile = charProfile
	local first = ns.db.profile
	local log = reasonLines(ns)
	report.repairLog = log

	-- The repair twice over.
	local snap = copy(first)
	local okClamp, clampErr = pcall(ns.ClampSettings)
	if not okClamp then finding("clamp", "ClampSettings threw the second time: " .. tostring(clampErr)) end
	local again = diff(snap, ns.db.profile)
	for _, line in ipairs(again) do finding("not idempotent", line) end

	-- What the player chose, and what is left of it. A value that was the OLD
	-- default was never in the file (AceDB strips it), so a changed default
	-- takes it with it: told apart as a note, not a loss.
	local oldDefaults = MIG.oldDefaults or {}
	local newDefaults = ns.db.defaults and ns.db.defaults.profile or {}
	report.defaultsMoved = diff(oldDefaults, newDefaults)
	local function show(v)
		if type(v) == "table" then
			local t = {}
			for k, x in pairs(v) do t[#t + 1] = tostring(k) .. "=" .. tostring(x) end
			table.sort(t)
			return "{" .. table.concat(t, ",") .. "}"
		end
		return tostring(v)
	end
	local function atPath(root, path)
		local holder, key = getp(root, path)
		return holder and holder[key]
	end
	report.moved = {}
	for _, d in ipairs(fixtureDiffs(ns.db.profile, MIG.fixture or {}, log)) do
		local wasDefault = atPath(oldDefaults, d.path)
		if wasDefault ~= nil and type(wasDefault) ~= "table" and wasDefault == d.want
			and atPath(newDefaults, d.path) ~= wasDefault then
			report.moved[#report.moved + 1] = d.path .. ": " .. show(d.want) .. " -> " .. show(d.got)
				.. " (the default moved from " .. show(wasDefault) .. " to " .. show(atPath(newDefaults, d.path)) .. ")"
		elseif d.path == "buff.choice" and not ns.AnyClassHasBuff(d.want) then
			-- The old releases run their own (Forever) buff keys: on another
			-- client the spell may not exist, and a pin nobody's class has goes.
			report.moved[#report.moved + 1] = d.path .. ": " .. show(d.want) .. " -> " .. show(d.got)
				.. " (no class has that buff on this client)"
		else
			finding(d.logged and "changed (logged)" or "changed", d.path .. ": " .. show(d.want) .. " -> " .. show(d.got))
		end
	end

	-- A profile the old release had marked keeps its mark; one from before the
	-- mark existed is a returning player's, not a new one.
	report.firstRun = ns.db.profile.firstRun
	local wantFirst = MIG.oldFirstRun or "existing"
	if ns.db.profile.firstRun ~= wantFirst then
		finding("first run", "the profile is marked " .. tostring(ns.db.profile.firstRun)
			.. ", it was " .. (MIG.oldFirstRun and ("marked " .. MIG.oldFirstRun) or "from before the mark existed"))
	end

	-- The other profile, switched to as a player would.
	if MIG.altFixture and next(MIG.altFixture) ~= nil then
		local ok, err = pcall(function() ns.db:SetProfile("Alt") end)
		if not ok then
			finding("switch", "SetProfile(Alt) threw: " .. tostring(err))
		else
			local altLog = reasonLines(ns)
			for _, d in ipairs(fixtureDiffs(ns.db.profile, MIG.altFixture, altLog)) do
				local wasDefault = atPath(oldDefaults, d.path)
				if wasDefault ~= nil and type(wasDefault) ~= "table" and wasDefault == d.want
					and atPath(newDefaults, d.path) ~= wasDefault then
					report.moved[#report.moved + 1] = "Alt " .. d.path .. ": " .. show(d.want) .. " -> "
						.. show(d.got) .. " (the default moved)"
				else
					finding("changed in Alt", d.path .. ": " .. show(d.want) .. " -> " .. show(d.got))
				end
			end
			local wantAlt = MIG.oldFirstRunAlt or "existing"
			if ns.db.profile.firstRun ~= wantAlt then
				finding("first run", "the Alt profile is marked " .. tostring(ns.db.profile.firstRun)
					.. ", it was " .. (MIG.oldFirstRunAlt and ("marked " .. MIG.oldFirstRunAlt)
						or "from before the mark existed"))
			end
			pcall(function() ns.db:SetProfile(charProfile) end)
		end
	end

	-- Debts and the favour ledger, as the old release saved them.
	report.owed = {}
	for name in pairs(ns.owed or {}) do report.owed[#report.owed + 1] = name end
	table.sort(report.owed)
	local savedDebts = false
	for _, store in pairs(MIG.sv and MIG.sv.char or {}) do
		if type(store) == "table" and type(store.debts) == "table" and next(store.debts) then savedDebts = true end
	end
	if savedDebts and #report.owed == 0 then
		finding("debts", "the file held debts and none came back")
	end
	local okLedger, entries = pcall(function() return ns.Ledger.Entries("all") end)
	if not okLedger then
		finding("ledger", "Ledger.Entries threw: " .. tostring(entries))
	else
		report.ledgerRows = type(entries) == "table" and #entries or -1
		local savedRows = 0
		for _, store in pairs(MIG.sv and MIG.sv.char or {}) do
			local ledger = type(store) == "table" and store.ledger
			if type(ledger) == "table" and type(ledger.entries) == "table" then
				for _ in pairs(ledger.entries) do savedRows = savedRows + 1 end
			end
		end
		report.ledgerSaved = savedRows
		if savedRows > 0 and report.ledgerRows == 0 then
			finding("ledger", "the file held " .. savedRows .. " ledger row(s) and the ledger lists none")
		end
	end
	local okShow, showErr = pcall(function() ns.Ledger.Toggle() ns.Ledger.Toggle() end)
	if not okShow then finding("ledger", "the ledger window threw: " .. tostring(showErr)) end

	-- The ends of the sliders the old release drew, in what this one keeps.
	report.extremeMoves = {}
	for _, e in ipairs(MIG.extremes or {}) do
		local ok = pcall(function() ns.db:SetProfile(e.profile) end)
		if ok then
			local holder, key = getp(ns.db.profile, e.path)
			local now = holder and holder[key]
			if now ~= e.value and not (type(now) == "number" and math.abs(now - e.value) < 1e-9) then
				report.extremeMoves[#report.extremeMoves + 1] = e.control .. " (" .. e.path .. ") offered " .. tostring(e.offered)
					.. ", saved " .. tostring(e.value) .. ", now " .. tostring(now)
			end
		end
	end
	pcall(function() ns.db:SetProfile(charProfile) end)

	-- A ready-made phrase set in the box, as the old release wrote it: the
	-- box must not come back empty, and must be the set as it reads now, the
	-- old text (a custom box), or the old text in this client's language.
	local setKeys = {}
	for key in pairs(MIG.sets or {}) do setKeys[#setKeys + 1] = key end
	table.sort(setKeys)
	report.setResults = {}
	for _, key in ipairs(setKeys) do
		local old = MIG.sets[key]
		local ok, err = pcall(function() ns.db:SetProfile("Set-" .. key) end)
		if not ok then
			finding("switch", "SetProfile(Set-" .. key .. ") threw: " .. tostring(err))
		else
			local sp = ns.db.profile.speech
			local now = sp.phrases
			local want = ns.PHRASE_SETS[key] and ns.PhraseSetText(key)
			local kind
			if type(now) ~= "string" or now:match("^%s*$") then
				kind = "empty"
				finding("phrases", "the " .. key .. " set came back as an empty box")
			elseif now == old then
				kind = "kept"
			elseif now == want then
				kind = "current"
			else
				kind = "other"
				finding("phrases", "the " .. key .. " set box is neither the old text nor the set now: "
					.. tostring(now):sub(1, 70))
			end
			report.setResults[key] = kind .. (sp.presetChoice and (" / " .. tostring(sp.presetChoice)) or "")
			if sp.presetChoice ~= nil and not ns.PHRASE_SETS[sp.presetChoice] then
				finding("phrases", "the " .. key .. " set left the dropdown on " .. tostring(sp.presetChoice)
					.. ", which is no set")
			end
		end
	end
	pcall(function() ns.db:SetProfile(charProfile) end)

	-- The options window, every page.
	local okOpen, openErr = pcall(function() ns.OpenOptions() end)
	if not okOpen then finding("options", "OpenOptions threw: " .. tostring(openErr)) end
	for _, id in ipairs(ids(ns)) do
		local ok, err = pcall(function() ns.OpenOptions(id) end)
		if not ok then finding("options", "page " .. id .. " threw: " .. tostring(err)) end
	end
	pcall(function() ns.CloseOptions() end)
	report.windowBuilt = ns.OptionsWindow ~= nil

	-- A prompt: the test card, then a real person.
	local okTest, testErr = pcall(function() ns.Prompt:ToggleTest() ns.Prompt:Refresh() ns.Prompt:ExitTest() end)
	if not okTest then finding("prompt", "the test card threw: " .. tostring(testErr)) end
	local okQ, queue = pcall(function() return ns.BuildQueue() end)
	report.queue = okQ and type(queue) == "table" and #queue or -1
	local button = ns.Prompt and ns.Prompt:GetButton()
	report.macro = button and button:GetAttribute("macrotext1") or nil

	-- Export and import of the migrated profile come back the same.
	local okE, s1 = pcall(ns.ExportSettings)
	if not okE or type(s1) ~= "string" then
		finding("export", "ExportSettings: " .. tostring(s1))
	else
		report.export = s1
		local okI, applied, said = pcall(ns.ImportSettings, s1)
		if not okI then
			finding("import", "ImportSettings threw: " .. tostring(applied))
		elseif not applied then
			finding("import", "the profile's own export was refused: " .. tostring(said))
		else
			local s2 = ns.ExportSettings()
			if s2 ~= s1 then
				finding("import", "export, import, export changed the string")
				report.exportAfter = s2
			end
			local okU, undone, usaid = pcall(ns.UndoImport)
			if not okU or not undone then finding("import", "UndoImport: " .. tostring(usaid or undone)) end
			local s3 = ns.ExportSettings()
			if s3 ~= s1 then finding("import", "the undo did not put the export back") end
		end
	end

	-- A real person on the prompt. The player's own filters are set aside
	-- first (they may well have everything off): the question is whether the
	-- migrated profile can still show one at all.
	pcall(function()
		local p = ns.db.profile
		p.enabled = true
		p.sources.owed, p.sources.strangers, p.sources.group = true, true, true
		p.filters.requireInRange, p.filters.minLevel, p.filters.skipPvP = false, 1, false
		p.filters.relevantOnly, p.filters.reachableOnly = false, false
		p.filters.skipSameClass = false
		p.prompt.locked, p.prompt.hideMounted = true, false
		pcall(ns.StopSnooze, true)
		Mock.unitNames = { nameplate1 = { "Anna", "Aim" } }
		local real = UnitExists
		UnitExists = function(unit) return unit == "player" or unit == "nameplate1" end
		ns.nameplateUnits["nameplate1"] = true
		Mock.advance(60)
		pcall(function() wipe(ns.tried) wipe(ns.refusals) end)
		ns.Guard("probe", ns.ProbeCapabilities)
		local q = ns.BuildQueue()
		local found = false
		for _, entry in ipairs(q) do
			if entry.name == "Anna Aim" or entry.name == "Anna" then found = true end
		end
		ns.Prompt:Refresh()
		local macro = ns.Prompt:GetButton():GetAttribute("macrotext1")
		UnitExists = real
		report.promptQueue = #q
		report.promptMacro = macro
		-- A warrior's shout, a hunter's nothing and the like never go to a
		-- stranger: nothing to expect of a class with no buff for others.
		local forOthers = false
		for _, buff in ipairs(ns.CastableBuffs() or {}) do
			if not buff.selfCast and not buff.partyOnly and not buff.groupOnly then forOthers = true end
		end
		report.classHasBuffForOthers = forOthers
		if forOthers and (not found or type(macro) ~= "string" or not macro:find("/cast", 1, true)) then
			finding("prompt", "with the filters opened, a stranger beside the player is not on the prompt (queue "
				.. #q .. ", macro " .. tostring(macro) .. ")")
		end
	end)

	for _, line in ipairs(guarded(ns)) do finding("guarded error", line) end
	report.status = #report.findings == 0 and "ok" or "findings"
	report.repairLogAfter = reasonLines(ns)
	return report
end

return M
