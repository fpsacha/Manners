-- The line said once when resting holds your own buffs back (Hints.lua,
-- 1.11.25). A warlock wrote on CurseForge that with no Demon Armor at login
-- "the addon dont pop up to buff": he logs in at an inn, where your own buffs
-- wait by default (My own buffs, Also in cities and inns). The rule stands; the
-- line says so, once a character, and only when something of yours is missing.
--
-- Every scenario name starts with "resting-hint:" so the mutations in
-- tests/mutations/resting-hint.py can name the one that has to catch them.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

local function minimap(entries)
	if entries == nil then
		rawset(_G, "C_Minimap", nil)
		return
	end
	rawset(_G, "C_Minimap", {
		GetNumTrackingTypes = function() return #entries end,
		GetTrackingInfo = function(i) return entries[i] end,
	})
end

local realKnown, realPlayer, realResting = IsSpellKnown, IsPlayerSpell, rawget(_G, "IsResting")
local function learn()
	local known = { [1459] = true, [2383] = true, [2580] = true }
	rawset(_G, "IsSpellKnown", function(id) return known[id] == true end)
	rawset(_G, "IsPlayerSpell", function(id) return known[id] == true end)
end
local function putBack()
	rawset(_G, "IsSpellKnown", realKnown)
	rawset(_G, "IsPlayerSpell", realPlayer)
	rawset(_G, "IsResting", realResting)
	minimap(nil)
end

local function said()
	for _, line in ipairs(Mock.printed) do
		if type(line) == "string" and line:find("Also in cities and inns", 1, true) then return line end
	end
	return nil
end

do
	local scenario = "resting-hint: said once when resting holds something of yours back, and never otherwise"
	Mock.reset()
	-- Find Herbs learned and off: something of yours is missing.
	local list = { { spellID = 2383, active = false }, { spellID = 2580, active = false } }
	minimap(list)
	learn()
	local ns = load(scenario)
	if ns then
		drive(scenario, ns)
		ns.ForgetTrackingList()
		local profile = ns.db.profile
		local function resting(yes) rawset(_G, "IsResting", function() return yes end) end
		local function fresh()
			ns.db.char.hints = nil
			Mock.printed = {}
		end
		if type(ns.RestingHint) ~= "function" then
			fail(scenario, "there is no ns.RestingHint")
		else
			-- Out in the world: nothing is held back, nothing is said.
			resting(false)
			fresh()
			if ns.RestingHint(GetTime()) or said() then fail(scenario, "said out in the world, where nothing is held back") end
			-- Resting with Also in cities and inns on: nothing is held back.
			resting(true)
			profile.ownBuffs.inCities = true
			fresh()
			if ns.RestingHint(GetTime()) or said() then fail(scenario, "said with Also in cities and inns on") end
			profile.ownBuffs.inCities = false
			-- Resting, with nothing of yours missing: nothing to say, and the once is kept.
			list[1].active = true
			ns.ForgetTrackingList()
			fresh()
			if ns.RestingHint(GetTime()) or said() then fail(scenario, "said with nothing of yours missing") end
			if type(ns.db.char.hints) == "table" and ns.db.char.hints.resting then
				fail(scenario, "the once was spent on a moment with nothing to say")
			end
			list[1].active = false
			ns.ForgetTrackingList()
			-- Myself off: that is the player's own doing, not the town's.
			profile.sources.self = false
			fresh()
			if ns.RestingHint(GetTime()) or said() then fail(scenario, "said with Myself switched off") end
			profile.sources.self = true
			-- Resting, something missing, the switch off: said, naming the switch and its page.
			fresh()
			local was = ns.RestingHint(GetTime())
			local line = said()
			if not (was and line) then
				fail(scenario, "resting with tracking off, the line was not said")
			elseif not line:find("My own buffs", 1, true) then
				fail(scenario, "the line does not say which page the switch is on: " .. line)
			end
			-- And never again for this character.
			Mock.printed = {}
			if ns.RestingHint(GetTime()) or said() then fail(scenario, "said a second time to the same character") end
			-- Still held back by the rule itself: the line changes nothing.
			if ns.MyselfHeldBack(profile, GetTime()) ~= "resting" then fail(scenario, "the line lifted the rule it explains") end
		end
	end
	putBack()
	Mock.reset()
end
