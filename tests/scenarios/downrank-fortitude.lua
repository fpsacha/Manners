-- Fortitude for a low-level player (GitHub issue 42): a priest's action bar
-- lowers the rank for somebody who cannot take the best one, and the prompt's
-- macro kept casting the best and was refused. The macro names the rank since
-- issue 9 (downrank.lua); what still sent the best rank out:
--
--   * a rank skipped at the trainer was named all the same, and the client
--     has no "Power Word: Fortitude(Rank 4)" to cast for a priest who never
--     learned it: the best rank you KNOW within ten levels of theirs now;
--   * the client's words for a rank ("Rank 3") are empty until it has loaded
--     the spell's data, and an empty answer left the plain name: the probe
--     asks for every rank you know, and the macro asks again for one not there;
--   * a passer-by remembered after the token that found them is gone (the
--     cursor moving to the prompt) carried no level, so the plain name went out.
--
-- Run on Forever (the default), Classic Era and Burning Crusade shapes. Every
-- name starts with "downrank-fort:" for tests/mutations/downrank-fortitude.py.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

local ANNA = "Anna Aim"
local FORT = "Power Word: Fortitude"
-- Rank by id, Classic Era and Forever (1243 .. 10938), and Burning Crusade's 25389.
local FORT_RANKS = { [1243] = 1, [1244] = 2, [1245] = 3, [2791] = 4, [10937] = 5, [10938] = 6, [25389] = 7 }

-- A level-60 priest knowing `known` (a set of Fortitude ids), with Anna at
-- `level`. `found` is "party" (Anna in the party) or "cursor" (a stranger under
-- the cursor). `text(id, now)` is the client's rank words, `loads` collects the
-- ids asked to load. Hands `body` the addon, the units table and a level setter.
local function priest(scenario, opts, body)
	Mock.reset()
	if opts.flavour then Mock.setFlavour(opts.flavour) end
	Mock.class = "PRIEST"
	local saved = {}
	for _, key in ipairs({ "UnitLevel", "GetSpellSubtext", "IsSpellKnown", "IsPlayerSpell", "C_Spell" }) do
		saved[key] = rawget(_G, key)
	end
	local level = opts.level or 60
	local names = {}
	if opts.found ~= "cursor" then names.party1 = { "Anna", "Aim" } end
	local restoreUnits = strangers(names)
	local ok, err = pcall(function()
		local known = opts.known
		rawset(_G, "IsSpellKnown", function(id) return known[id] == true end)
		rawset(_G, "IsPlayerSpell", _G.IsSpellKnown)
		rawset(_G, "UnitLevel", function(unit)
			if (unit == "party1" or unit == "mouseover") and names[unit] then return level end
			return 60
		end)
		local base = C_Spell
		local text = opts.text or function(id) return FORT_RANKS[id] and ("Rank " .. FORT_RANKS[id]) or "" end
		local spell = {
			GetSpellName = function(id)
				if FORT_RANKS[id] then return FORT end
				return base.GetSpellName(id)
			end,
			GetSpellSubtext = function(id) return text(id, Mock.now) end,
			RequestLoadSpellData = function(id)
				if opts.loads then opts.loads[#opts.loads + 1] = { id = id, at = Mock.now } end
			end,
		}
		rawset(_G, "C_Spell", setmetatable(spell, { __index = base }))
		local ns = load(scenario)
		if not ns then return end
		Mock.groupSize = opts.found == "cursor" and 0 or 2
		freshPrompt(ns, scenario)
		Mock.runTimers(0)
		ns.Prompt:ExitTest()
		ns.db.profile.sources.strangers = opts.found == "cursor"
		body(ns, names, function(value) level = value end)
	end)
	restoreUnits()
	for _, key in ipairs({ "UnitLevel", "GetSpellSubtext", "IsSpellKnown", "IsPlayerSpell", "C_Spell" }) do
		rawset(_G, key, saved[key])
	end
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function all(ids)
	local set = {}
	for _, id in ipairs(ids) do set[id] = true end
	return set
end

local VANILLA = { 10938, 10937, 2791, 1245, 1244, 1243 }

-- What the prompt's button casts at Anna, nil when she is not on it.
-- Anna is "Anna Aim" on Forever and "Anna-Aim" where the second name is a
-- realm: the client's own filing of her. `wait` false repaints at once.
local function castLine(ns, wait)
	if wait ~= false then Mock.advance(5) end
	ns.Prompt:Refresh()
	local showing = ns.Prompt.Showing and ns.Prompt:Showing()
	local anna = ns.UnitFullName("party1") or ANNA
	if not (showing and showing.name == anna) then return nil end
	local text = ns.Prompt:GetButton():GetAttribute("macrotext1") or ""
	return text:match("/cast ([^\n]*)")
end

local function check(scenario, opts, want)
	priest(scenario, opts, function(ns)
		local line = castLine(ns)
		if line == nil then
			fail(scenario, "SKIPPED -- Anna was not on the prompt")
		elseif line ~= want then
			fail(scenario, ("level %d: the macro casts %q, wanted %q"):format(opts.level, line, want))
		end
	end)
end

-- The report's own case on each client: somebody low gets the rank that lands.
check("downrank-fort: forever: level 20 gets rank 3",
	{ known = all(VANILLA), level = 20 }, FORT .. "(Rank 3)")
check("downrank-fort: era: level 2 gets rank 2",
	{ flavour = "vanilla", known = all(VANILLA), level = 2 }, FORT .. "(Rank 2)")
check("downrank-fort: era: level 40 gets rank 5",
	{ flavour = "vanilla", known = all(VANILLA), level = 40 }, FORT .. "(Rank 5)")
check("downrank-fort: tbc: level 55 gets rank 6 under the seventh",
	{ flavour = "tbc", known = all({ 25389, 10938, 10937, 2791, 1245, 1244, 1243 }), level = 55 }, FORT .. "(Rank 6)")
check("downrank-fort: tbc: level 60 keeps the plain name",
	{ flavour = "tbc", known = all({ 25389, 10938, 10937, 2791, 1245, 1244, 1243 }), level = 60 }, FORT)

-- A rank skipped at the trainer is never named: the fourth (36) would reach a
-- level 30, but the priest never learned it, so the third.
check("downrank-fort: forever: a rank never learned is skipped",
	{ known = all({ 10938, 10937, 1245, 1244, 1243 }), level = 30 }, FORT .. "(Rank 3)")
check("downrank-fort: era: a rank never learned is skipped",
	{ flavour = "vanilla", known = all({ 10938, 10937, 1245, 1244, 1243 }), level = 30 }, FORT .. "(Rank 3)")

-- The client's words come only once it has loaded the spell's data. The probe
-- at login asks for every rank known, not only the one a macro needs now.
do
	local scenario = "downrank-fort: the rank's words are asked for at login"
	local loads = {}
	priest(scenario, { known = all(VANILLA), level = 60, loads = loads }, function(ns)
		local missing = {}
		for _, id in ipairs(VANILLA) do
			local seen = false
			for _, asked in ipairs(loads) do
				if asked.id == id then seen = true end
			end
			if not seen then missing[#missing + 1] = tostring(id) end
		end
		if #missing > 0 then
			fail(scenario, "the login asked the client for no words of rank " .. table.concat(missing, ", "))
		end
	end)
end

-- And words the client has let go since (or never loaded) are asked for by the
-- macro itself: the press after names the rank, and /manners debug says why the
-- one before did not.
do
	local scenario = "downrank-fort: words not loaded are asked for again by the macro"
	local loads = {}
	local from = math.huge
	local function text(id, now)
		for _, asked in ipairs(loads) do
			if asked.id == id and asked.at >= from and now - asked.at >= 1 then return "Rank " .. FORT_RANKS[id] end
		end
		return ""
	end
	priest(scenario, { known = all(VANILLA), level = 20, loads = loads, text = text }, function(ns)
		-- Whatever the login asked for is forgotten, once the probes it
		-- queued have run (SPELLS_CHANGED's five-second wait).
		Mock.runTimers(10)
		from = Mock.now
		local first = castLine(ns, false)
		if first == nil then
			fail(scenario, "SKIPPED -- Anna was not on the prompt")
			return
		end
		if first ~= FORT then fail(scenario, "with no words loaded the macro casts " .. first) end
		local said = table.concat(ns.RankLines(), " ")
		if not said:find("not loaded", 1, true) then
			fail(scenario, "/manners debug does not say the rank went unnamed: " .. said)
		end
		local second
		for _ = 1, 3 do
			second = castLine(ns)
			if second == FORT .. "(Rank 3)" then break end
		end
		if second ~= FORT .. "(Rank 3)" then
			fail(scenario, "fifteen seconds later the macro still casts " .. tostring(second))
		end
	end)
end

-- A stranger found under the cursor, and the cursor moving on to the prompt:
-- remembered by name with no token, at the level last read of them.
do
	local scenario = "downrank-fort: a passer-by remembered keeps the rank for their level"
	priest(scenario, { known = all(VANILLA), level = 20, found = "cursor" }, function(ns, names)
		names.mouseover = { "Anna", "Aim" }
		ns.addon:Tick()
		local found = false
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.name == ANNA and entry.unit == "mouseover" then found = true end
		end
		if not found then
			fail(scenario, "SKIPPED -- Anna under the cursor was not offered")
			return
		end
		names.mouseover = nil
		for _ = 1, 3 do
			Mock.runTimers(0.4)
			ns.addon:Tick()
		end
		local kept = nil
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.name == ANNA then kept = entry end
		end
		if not (kept and kept.unit == nil and ns.Prompt:PanelName() == ANNA) then
			fail(scenario, ("SKIPPED -- Anna was not kept on the prompt from memory (entry %s, panel %s)"):format(
				tostring(kept and kept.unit or kept), tostring(ns.Prompt:PanelName())))
			return
		end
		local text = ns.Prompt:GetButton():GetAttribute("macrotext1") or ""
		local line = text:match("/cast ([^\n]*)")
		if line ~= FORT .. "(Rank 3)" then
			fail(scenario, "remembered with no token, she is cast " .. tostring(line))
		end
	end)
end
