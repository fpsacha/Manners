-- Battle Shout's opt-in recipient and instance-combat controls.

local dir, H = ...
local fail, load, strangers, freshPrompt = H.fail, H.load, H.strangers, H.freshPrompt

local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "UnitClass", "UnitGroupRolesAssigned",
	"IsInInstance", "UnitAffectingCombat", "GetInspectSpecialization", "C_SpecializationInfo" }

local UNITS = {
	party1 = { "Tank", "" }, party2 = { "Melee", "" }, party3 = { "Caster", "" },
	party4 = { "Delta", "" },
}

local function run(scenario, flavour, world, body)
	Mock.reset()
	Mock.setFlavour(flavour)
	Mock.class = "WARRIOR"
	Mock.groupSize = 5
	Mock.playerHeld = {}
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local restore
	local ok, err = pcall(function()
		restore = strangers(UNITS)
		local known = { [6673] = true, [25289] = true, [11551] = true, [11550] = true,
			[11549] = true, [6192] = true, [5242] = true }
		rawset(_G, "IsSpellKnown", function(id) return known[id] == true end)
		rawset(_G, "IsPlayerSpell", function(id) return known[id] == true end)
		rawset(_G, "UnitClass", function(unit)
			if unit == "player" then return "Warrior", "WARRIOR" end
			local class = world.classes and world.classes[unit] or "MAGE"
			return class, class
		end)
		rawset(_G, "UnitGroupRolesAssigned", function(unit)
			return world.roles and world.roles[unit] or "NONE"
		end)
		rawset(_G, "GetInspectSpecialization", nil)
		local base = C_SpecializationInfo
		rawset(_G, "C_SpecializationInfo", setmetatable({
			GetInspectSpecialization = function(unit)
				return world.specs and world.specs[unit] or 0
			end,
		}, { __index = base or {} }))
		if world.noSpec then rawset(_G, "C_SpecializationInfo", nil) end
		rawset(_G, "IsInInstance", function() return world.inside == true, world.kind or "none" end)
		Mock.inCombat = world.combat == true
		rawset(_G, "UnitAffectingCombat", function(unit) return unit == "player" and Mock.inCombat end)
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		ns.db.profile.sources.self = false
		ns.db.profile.sources.strangers = false
		ns.db.profile.sources.group = true
		Mock.advance(4)
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	if restore then restore() end
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function shouts(ns)
	local out = {}
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.buff and entry.buff.key == "battleshout" then out[entry.name] = entry end
	end
	return out
end

local function listed(entries)
	local out = {}
	for name in pairs(entries) do out[#out + 1] = name end
	table.sort(out)
	return table.concat(out, ",")
end

do
	local scenario = "battleshout-recipients: off by default keeps the old recipients"
	run(scenario, "mists", {
		classes = { party1 = "PALADIN", party2 = "SHAMAN", party3 = "MAGE", party4 = "DRUID" },
		roles = { party1 = "TANK" },
		specs = { party2 = 262, party3 = 0, party4 = 105 },
	}, function(ns)
		if ns.db.profile.buff.shoutMelee or ns.db.profile.buff.shoutCombatInstances then
			fail(scenario, "the new Battle Shout controls are on by default")
		end
		local got = shouts(ns)
		if not (got.Tank and got.Melee and got.Caster and got.Delta) then
			fail(scenario, "the default queue no longer offers Battle Shout to its old recipients: " .. listed(got))
		end
	end)
end

do
	for _, flavour in ipairs({ "mists", "mainline" }) do
		local scenario = "battleshout-recipients: only tanks and reliably identified melee"
		run(scenario, flavour, {
			classes = { party1 = "PALADIN", party2 = "DRUID", party3 = "MAGE", party4 = "SHAMAN" },
			roles = { party1 = "TANK" },
			specs = { party1 = 65, party2 = 103, party3 = 64, party4 = 0 },
		}, function(ns)
			ns.db.profile.buff.shoutMelee = true
			local got = shouts(ns)
			if not got.Tank or not got.Melee or got.Caster or got.Delta then
				fail(scenario, (flavour .. ": recipient set tank=%s melee=%s caster=%s unknown=%s")
					:format(tostring(got.Tank ~= nil), tostring(got.Melee ~= nil),
						tostring(got.Caster ~= nil), tostring(got.Delta ~= nil)))
			end
		end)
	end
end

do
	local scenario = "battleshout-recipients: a pure melee class needs no spec; an unknown hybrid is skipped"
	run(scenario, "vanilla", {
		noSpec = true,
		classes = { party1 = "ROGUE", party2 = "PALADIN", party3 = "PRIEST", party4 = "WARRIOR" },
		roles = { party2 = "DAMAGER", party3 = "NONE", party4 = "NONE" },
	}, function(ns)
		ns.db.profile.buff.shoutMelee = true
		local got = shouts(ns)
		if not got.Tank or not got.Delta or got.Melee or got.Caster then
			fail(scenario, "without specialization inspection fixed melee classes were not kept: " .. listed(got)
				.. "; "
				.. " or a hybrid/unknown recipient was guessed")
		end
	end)
end

do
	local scenario = "battleshout-recipients: secret and absent auras stay unverified"
	run(scenario, "mists", {
		classes = { party1 = "WARRIOR", party2 = "MAGE", party3 = "MAGE", party4 = "MAGE" },
		specs = {},
	}, function(ns)
		ns.db.profile.buff.shoutMelee = true
		Mock.auraReadRefuse = { [6673] = "secret" }
		local got = shouts(ns)
		if not got.Tank or got.Tank.known ~= nil then
			fail(scenario, "a qualifying recipient's withheld aura was treated as a role or absence result")
		end
	end)
end

do
	local scenario = "battleshout-recipients: one cast still reaches the party without targeting"
	run(scenario, "vanilla", {
		classes = { party1 = "ROGUE", party2 = "PRIEST", party3 = "MAGE", party4 = "WARLOCK" },
		noSpec = true,
	}, function(ns)
		ns.db.profile.buff.shoutMelee = true
		ns.addon:Tick()
		local macro = H.pressButton(ns)
		if type(macro) ~= "string" or not macro:find("/cast Battle Shout", 1, true)
			or macro:find("/target ", 1, true) then
			fail(scenario, "the qualifying party member did not keep a bare self-cast shout: "
				.. tostring(macro))
		end
	end)
end

do
	local scenario = "battleshout-recipients: no qualifying member leaves no shout"
	run(scenario, "mists", {
		classes = { party1 = "MAGE", party2 = "PRIEST", party3 = "PALADIN", party4 = "SHAMAN" },
		roles = { party1 = "DAMAGER", party2 = "HEALER", party3 = "NONE", party4 = "DAMAGER" },
		specs = { party1 = 64, party2 = 257, party3 = 0, party4 = 262 },
	}, function(ns)
		ns.db.profile.buff.shoutMelee = true
		if next(shouts(ns)) ~= nil then
			fail(scenario, "Battle Shout was offered with no tank or known melee recipient")
		end
	end)
end

do
	local scenario = "battleshout-recipients: owed favours and explicit asks bypass the filters"
	run(scenario, "mists", {
		classes = { party1 = "PRIEST", party2 = "MAGE", party3 = "MAGE", party4 = "MAGE" },
		roles = {}, specs = {},
		inside = false, combat = false,
	}, function(ns)
		ns.db.profile.buff.shoutMelee = true
		ns.db.profile.buff.shoutCombatInstances = true
		ns.owed.Tank = { expires = GetTime() + 100, at = GetTime(), class = "PRIEST" }
		local got = shouts(ns)
		if not got.Tank then
			fail(scenario, "a favour owed to a caster was held by the new controls")
		end
		ns.db.profile.sources.asked = true
		local real = ns.AskedFor
		ns.AskedFor = function(unit, full, now, candidates)
			if full == "Melee" then return candidates, false end
			return real(unit, full, now, candidates)
		end
		local withAsk = shouts(ns)
		if not withAsk.Melee then
			fail(scenario, "an explicit buff request was held by the new controls")
		end
	end)
end

do
	local scenario = "battleshout-recipients: the never-offer list still excludes an unowed melee"
	run(scenario, "mists", {
		classes = { party1 = "ROGUE", party2 = "MAGE", party3 = "MAGE", party4 = "MAGE" },
	}, function(ns)
		ns.db.profile.buff.shoutMelee = true
		ns.db.profile.never.Melee = nil
		ns.db.profile.never.Tank = true
		if shouts(ns).Tank then
			fail(scenario, "a qualifying recipient on the never-offer list was not excluded")
		end
	end)
end

do
	local scenario = "battleshout-recipients: combat timing waits for a dungeon or raid fight"
	run(scenario, "mists", {
		classes = { party1 = "ROGUE", party2 = "MAGE", party3 = "MAGE", party4 = "MAGE" },
		inside = false, combat = false,
	}, function(ns)
		ns.db.profile.buff.shoutMelee = true
		ns.db.profile.buff.shoutCombatInstances = true
		if next(shouts(ns)) ~= nil then
			fail(scenario, "Battle Shout was offered outside an instance and fight")
		end
		Mock.inCombat = true
		if next(shouts(ns)) ~= nil then
			fail(scenario, "Battle Shout was offered in a world fight")
		end
	end)
end

do
	local scenario = "battleshout-recipients: combat timing allows dungeon and raid fights only"
	local world = {
		classes = { party1 = "ROGUE", party2 = "MAGE", party3 = "MAGE", party4 = "MAGE" },
		inside = true, kind = "party", combat = true,
	}
	run(scenario, "mists", world, function(ns)
		ns.db.profile.buff.shoutMelee = true
		ns.db.profile.buff.shoutCombatInstances = true
		if not shouts(ns).Tank then
			fail(scenario, "Battle Shout was not offered to a melee recipient in a dungeon fight")
		end
		world.kind = "raid"
		Mock.inCombat = true
		if not shouts(ns).Tank then
			fail(scenario, "Battle Shout was not offered to a melee recipient in a raid fight")
		end
	end)
end

do
	local scenario = "battleshout-recipients: controls are on Who to buff"
	run(scenario, "mists", {}, function(ns)
		local melee = H.findOption(ns.optionsTable, "shoutMelee")
		local combat = H.findOption(ns.optionsTable, "shoutCombatInstances")
		local mp, _, _ = H.placedOn(ns, "who.shoutMelee")
		local cp, _, _ = H.placedOn(ns, "who.shoutCombatInstances")
		if not melee or not combat or melee.get() ~= false or combat.get() ~= false
			or mp ~= "who" or cp ~= "who" then
			fail(scenario, ("the two off-by-default controls are missing from Who to buff: "
				.. "melee=%s combat=%s meleePage=%s combatPage=%s")
				:format(tostring(melee ~= nil), tostring(combat ~= nil), tostring(mp), tostring(cp)))
		end
	end)
end
