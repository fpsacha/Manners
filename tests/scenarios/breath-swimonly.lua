-- Unending Breath for others only while you swim. GitHub issue 41, a warlock
-- alt on CurseForge: "Is there any way to only offer unending breath to others
-- only if I am swimming? Have had to turn this off as I don't want it to be on
-- my screen 24/7." *Offer Unending Breath to others only while I am swimming*
-- (buff.swimOnly, off by default) is under the buff's own switches on Who to
-- buff, for the buff Buffs.lua flags `swimGate` (a warlock's Unending Breath,
-- on every client; a shaman's Water Breathing is not a buff Manners offers).
-- On, the group and passers-by are offered it only while IsSwimming says so and
-- for a moment after (Core.lua, Swimming, as your own reminder reads it); a
-- favour returned with it still goes; the warlock's own reminder is not a
-- Castable buff and is untouched.
--
-- Every scenario name starts with "breath-swimonly:" so the mutations in
-- tests/mutations/breath-swimonly.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load

local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "UnitClass", "UnitLevel", "UnitInParty", "IsInInstance",
	"UnitIsVisible", "IsSwimming" }

local world

-- A warlock on `flavour` who knows Unending Breath, with Anna (a mage) in the
-- party and Pat (a priest) on a nameplate, both wearing nothing; swimming while
-- world.swimming is true.
local function session(scenario, class, flavour, body)
	Mock.reset()
	Mock.setFlavour(flavour or "camelot")
	Mock.class = class
	world = { swimming = false }
	local units = {
		party1 = { name = { "Anna", "Aim" }, class = "MAGE" },
		nameplate1 = { name = { "Pat", "Passer" }, class = "PRIEST" },
	}
	local names = { party1 = units.party1.name, nameplate1 = units.nameplate1.name }
	Mock.groupSize = 2
	Mock.nameplates = { "nameplate1" }
	local undo = H.strangers(names)
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local known = {}
	local function isKnown(id) return known[id] == true end
	rawset(_G, "IsSpellKnown", isKnown)
	rawset(_G, "IsPlayerSpell", isKnown)
	rawset(_G, "IsInInstance", function() return false, "none" end)
	rawset(_G, "UnitIsVisible", function() return true end)
	rawset(_G, "IsSwimming", function() return world.swimming end)
	rawset(_G, "UnitClass", function(unit)
		local u = units[unit]
		if u then return u.class, u.class end
		return saved.UnitClass(unit)
	end)
	rawset(_G, "UnitLevel", function() return 60 end)
	rawset(_G, "UnitInParty", function(unit)
		return type(unit) == "string" and unit:find("^party%d") ~= nil
	end)
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		local breath = ns.FindBuff and ns.FindBuff(class, "breath")
		if breath then
			for _, id in ipairs(breath.ranks) do known[id] = true end
		end
		H.freshPrompt(ns, scenario)
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.Prompt:ApplyTarget(nil)
		ns.Prompt:InvalidateMacro()
		ns.addon:Tick()
		body(ns, breath)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	undo()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- How many of the two are offered Unending Breath by the next scan, `later`
-- seconds on (the aura cache is three seconds deep, so the first reading is
-- taken four on).
local function offered(ns, later)
	Mock.advance(later)
	local n = 0
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.buff.key == "breath" and (entry.reason == "group" or entry.reason == "nearby") then n = n + 1 end
	end
	return n
end

do
	local scenario = "breath-swimonly: off by default, the group and passers-by are offered it on dry land"
	session(scenario, "WARLOCK", "camelot", function(ns, breath)
		if not breath then fail(scenario, "SKIPPED -- no Unending Breath") return end
		local only = ns.db.profile.buff.swimOnly
		if type(only) ~= "table" or next(only) ~= nil then
			fail(scenario, "a new profile's buff.swimOnly is not an empty set")
		end
		local control = H.findOption(ns.optionsTable, "swim_breath")
		if not control then fail(scenario, "Who to buff has no swim switch under Unending Breath") return end
		if control.get() ~= false then fail(scenario, "the switch reads on in a new profile") end
		local n = offered(ns, 4)
		if n ~= 2 then fail(scenario, "with the switch off, Unending Breath is offered to " .. n .. " of the two") end
	end)
end

do
	local scenario = "breath-swimonly: on, it is offered only while swimming and a moment after"
	session(scenario, "WARLOCK", "camelot", function(ns, breath)
		if not breath then fail(scenario, "SKIPPED -- no Unending Breath") return end
		local control = H.findOption(ns.optionsTable, "swim_breath")
		if not control then fail(scenario, "SKIPPED -- no swim switch") return end
		control.set(nil, true)
		if ns.db.profile.buff.swimOnly.breath ~= true or control.get() ~= true then
			fail(scenario, "ticking it wrote " .. tostring(ns.db.profile.buff.swimOnly.breath))
		end
		local n = offered(ns, 4)
		if n ~= 0 then fail(scenario, "on dry land it is offered to " .. n) end
		world.swimming = true
		n = offered(ns, 0.1)
		if n ~= 2 then fail(scenario, "while swimming it is offered to " .. n .. " of the two") end
		-- Out of the water at the surface: a jump is still swimming for a moment.
		world.swimming = false
		n = offered(ns, 1)
		if n ~= 2 then fail(scenario, "a second after the last stroke it is offered to " .. n .. " of the two") end
		n = offered(ns, 2)
		if n ~= 0 then fail(scenario, "three seconds after the last stroke it is still offered to " .. n) end
		-- Unticked, as it was.
		control.set(nil, false)
		if ns.db.profile.buff.swimOnly.breath ~= nil then
			fail(scenario, "unticking it left " .. tostring(ns.db.profile.buff.swimOnly.breath))
		end
		n = offered(ns, 0.1)
		if n ~= 2 then fail(scenario, "unticked, it is offered to " .. n .. " of the two on dry land") end
	end)
end

do
	local scenario = "breath-swimonly: a favour returned with it still goes on dry land"
	session(scenario, "WARLOCK", "camelot", function(ns, breath)
		if not breath then fail(scenario, "SKIPPED -- no Unending Breath") return end
		ns.db.profile.buff.swimOnly.breath = true
		Mock.advance(4)
		H.owe(ns, "Pat Passer")
		local pat
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.name == "Pat Passer" then pat = entry end
		end
		if not (pat and pat.reason == "owed" and pat.buff.key == "breath") then
			fail(scenario, "Pat buffed the warlock on dry land and is offered "
				.. (pat and (tostring(pat.reason) .. " " .. tostring(pat.buff.key)) or "nothing")
				.. "; a favour should still be returned with Unending Breath")
		end
	end)
end

do
	local scenario = "breath-swimonly: a damaged set is repaired and travels with a profile and its reset"
	session(scenario, "WARLOCK", "camelot", function(ns, breath)
		if not breath then fail(scenario, "SKIPPED -- no Unending Breath") return end
		ns.db.profile.buff.swimOnly = "yes"
		ns.ClampSettings()
		if type(ns.db.profile.buff.swimOnly) ~= "table" then
			fail(scenario, "a damaged choice was left as " .. tostring(ns.db.profile.buff.swimOnly))
		end
		ns.db.profile.buff.swimOnly = { breath = true }
		local text = ns.ExportSettings and ns.ExportSettings() or ""
		if not text:find("buff.swimOnly=breath", 1, true) then
			fail(scenario, "the export does not carry the choice: " .. tostring(text))
		end
		if ns.OptionsPage.ResetPage("who") ~= true then fail(scenario, "SKIPPED -- the reset did not run") return end
		if next(ns.db.profile.buff.swimOnly) ~= nil then
			fail(scenario, "Who to buff's reset left the swim choice on")
		end
	end)
end

-- The switch is there for a class with Unending Breath on each client, and not
-- for one without.
for _, flavour in ipairs({ "camelot", "vanilla", "tbc", "mists", "mainline" }) do
	local scenario = "breath-swimonly: the switch is on " .. flavour .. " for a warlock with the buff, not for a mage"
	session(scenario, "WARLOCK", flavour, function(ns, breath)
		local control = H.findOption(ns.optionsTable, "swim_breath")
		if breath and not control then
			fail(scenario, "a warlock with Unending Breath has no swim switch")
		elseif control and not breath then
			fail(scenario, "a warlock without Unending Breath has a swim switch")
		end
	end)
	session(scenario, "MAGE", flavour, function(ns)
		if H.findOption(ns.optionsTable, "swim_breath") then
			fail(scenario, "a mage has the Unending Breath swim switch")
		end
	end)
end
