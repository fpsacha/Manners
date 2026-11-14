-- The review of resurrection (Resurrect.lua): the rules that hold every other
-- unasked offer back hold a resurrection too (Offer nothing in cities and inns
-- or in dungeons, the mana floor, a flagged member under the one cast for the
-- group), a resurrection switched off is nothing to cast, and the tooltip of
-- the cast for the whole group is its own. The session is res.lua's.
--
-- Every scenario name starts with "res-review:" so the mutations in
-- tests/mutations/res-review.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, pressButton, owe = H.strangers, H.freshPrompt, H.pressButton, H.owe

-- Three others in a party of four.
local PARTY = {
	party1 = { "Anna", "Aim" },
	party2 = { "Bert", "Beside" },
	party3 = { "Cara", "Close" },
}

-- The mock names every spell it has not heard of "Arcane Intellect": these are
-- the resurrections the scenarios learn, by the names their clients give them.
local NAMES = {
	[2006] = "Resurrection", [2010] = "Resurrection", [20770] = "Resurrection",
	[437138] = "Revive", [1237948] = "Revive", [115178] = "Resuscitate",
	[83968] = "Mass Resurrection",
}

local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "UnitIsDeadOrGhost", "UnitIsGhost",
	"UnitHasIncomingResurrection", "UnitIsFeignDeath", "UnitAffectingCombat", "UnitIsVisible",
	"UnitInParty", "C_Spell", "IsInInstance" }

-- The name somebody is filed under: with a surname on Forever.
local function filed(pair)
	return Mock.surnames and pair[2] and (pair[1] .. " " .. pair[2]) or pair[1]
end

local function flat(text)
	return (tostring(text):gsub("\n", " / "))
end

-- One session: a priest on Forever in a party of four, who knows two ranks of
-- Resurrection and every rank of Fortitude, unless `env` says otherwise.
--   env.flavour  the client (Forever)
--   env.class    the player's class (PRIEST)
--   env.known    spell ids known, or a function of ns that lists them
--   env.names    the units that exist, by token (PARTY)
-- body(ns, world): `world` is who is dead (`dead`), released (`ghost`), being
-- resurrected (`incoming`), feigning (`feign`) or out of sight (`hidden`), by
-- token; whether you are in a fight the lockdown has not caught up with
-- (`combat`); and whether the game says you cannot pay (`noMana`). `asked`
-- counts UnitIsDeadOrGhost by token.
local function with(scenario, env, body)
	Mock.reset()
	if env.flavour then Mock.setFlavour(env.flavour) end
	Mock.class = env.class or "PRIEST"
	Mock.groupSize = 4
	local restore = strangers(env.names or PARTY)
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local world = { dead = {}, ghost = {}, incoming = {}, feign = {}, hidden = {}, asked = {} }
	local ok, err = pcall(function()
		local realDead, realSpell = UnitIsDeadOrGhost, C_Spell
		rawset(_G, "UnitIsDeadOrGhost", function(unit)
			world.asked[unit] = (world.asked[unit] or 0) + 1
			if unit == "player" then return realDead(unit) end
			return world.dead[unit] == true or world.ghost[unit] == true
		end)
		rawset(_G, "UnitIsGhost", function(unit) return world.ghost[unit] == true end)
		rawset(_G, "UnitHasIncomingResurrection", function(unit) return world.incoming[unit] == true end)
		rawset(_G, "UnitIsFeignDeath", function(unit) return world.feign[unit] == true end)
		rawset(_G, "UnitAffectingCombat", function() return world.combat == true end)
		rawset(_G, "UnitIsVisible", function(unit) return world.hidden[unit] ~= true end)
		rawset(_G, "IsInInstance", function() return world.inside == true, world.inside and "party" or "none" end)
		-- The mock answers "in your party" for every token while you are in one.
		rawset(_G, "UnitInParty", function(unit)
			return type(unit) == "string" and unit:find("^party%d") ~= nil
		end)
		rawset(_G, "C_Spell", setmetatable({
			GetSpellName = function(id) return NAMES[id] or realSpell.GetSpellName(id) end,
			IsSpellUsable = function(id)
				if world.noMana and NAMES[id] then return false, true end
				return true, false
			end,
		}, { __index = realSpell }))
		local ns = load(scenario)
		if not ns then return end
		local ids = env.known
		if type(ids) == "function" then ids = ids(ns) end
		if not ids then
			ids = { 2006, 2010 }
			for _, id in ipairs(ns.FindBuff("PRIEST", "fortitude").ranks) do ids[#ids + 1] = id end
		end
		local known = {}
		for _, id in ipairs(ids) do known[id] = true end
		rawset(_G, "IsSpellKnown", function(id) return known[id] == true end)
		rawset(_G, "IsPlayerSpell", function(id) return known[id] == true end)
		freshPrompt(ns, scenario)
		local sources = ns.db.profile.sources
		sources.strangers, sources.self = false, false
		ns.Guard("probe", ns.ProbeCapabilities)
		wipe(world.asked)
		body(ns, world)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	restore()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- The queue a few seconds on (past any two-second rest), as a list.
local function queue(ns, seconds)
	Mock.advance(seconds or 4)
	return ns.BuildQueue()
end

-- The resurrection offered to `name` alone, or nil; and the one for the group.
local function resFor(list, name)
	for _, entry in ipairs(list) do
		if entry.res and not entry.resNames and entry.name == name then return entry end
	end
end
local function massOf(list)
	for _, entry in ipairs(list) do
		if entry.res and entry.resNames then return entry end
	end
end

-- The macro the prompt arms for `entry`.
local function macroFor(ns, entry)
	ns.Prompt:InvalidateMacro()
	ns.Prompt:ApplyTarget(entry)
	return ns.Prompt:GetButton():GetAttribute("macrotext1")
end

-- One of the player's own cast events, as Resurrect.lua's frame hears it.
local function cast(ns, event, ...)
	ns.Resurrect.OnEvent(event, "player", ...)
end

local ANNA_PAIR, BERT_PAIR, CARA_PAIR = PARTY.party1, PARTY.party2, PARTY.party3

local function mistsPriest(ns)
	local ids = { 2006, 83968 }
	for _, id in ipairs(ns.FindBuff("PRIEST", "fortitude").ranks) do ids[#ids + 1] = id end
	return ids
end

-- ----------------------------------------------------------- res-review 1
-- Offer nothing in dungeons, raids and battlegrounds says nobody is offered
-- anything there but your target or focus: a dead member of the group is
-- nobody too, and a dead target is still yours to pick.
do
	local scenario = "res-review: Offer nothing in dungeons holds a resurrection back, but for your target"
	local names = { party1 = PARTY.party1, party2 = PARTY.party2, party3 = PARTY.party3, target = { "Dora", "Deep" } }
	with(scenario, { names = names }, function(ns, world)
		local ANNA, DORA = filed(ANNA_PAIR), filed(names.target)
		local f = ns.db.profile.filters
		ns.db.profile.sources.resStrangers = true
		world.inside = true
		world.dead.party1, world.dead.target = true, true
		local list = queue(ns)
		if not (resFor(list, ANNA) and resFor(list, DORA)) then
			fail(scenario, "SKIPPED -- the dead are not offered inside with the switch off")
			return
		end
		f.quietInInstances = true
		list = queue(ns)
		if resFor(list, ANNA) then
			fail(scenario, "a dead member of the group is offered a resurrection where nothing is offered")
		end
		if not resFor(list, DORA) then fail(scenario, "your dead target is not offered inside") end
		f.quietTargets = true
		if resFor(queue(ns), DORA) then
			fail(scenario, "your dead target is offered with targets held back as well")
		end
		f.quietTargets = false
		world.inside = false
		if not resFor(queue(ns), ANNA) then fail(scenario, "not offered again out in the world") end
	end)
	-- The one cast for the group is cast at nobody: never where nothing is offered.
	-- Even with two of them your target and your focus: it would reach the third.
	local pointed = { party1 = PARTY.party1, party2 = PARTY.party2, party3 = PARTY.party3,
		target = PARTY.party1, focus = PARTY.party2 }
	with(scenario, { flavour = "mists", known = mistsPriest, names = pointed }, function(ns, world)
		world.inside = true
		world.dead.party1, world.dead.party2, world.dead.party3 = true, true, true
		world.dead.target, world.dead.focus = true, true
		-- Your target and focus are of the party (put back by the session).
		rawset(_G, "UnitInParty", function(unit)
			return type(unit) == "string" and (unit:find("^party%d") ~= nil or unit == "target" or unit == "focus")
		end)
		if not massOf(queue(ns)) then
			fail(scenario, "SKIPPED -- two dead are not offered the group's cast inside")
			return
		end
		ns.db.profile.filters.quietInInstances = true
		local list = queue(ns)
		if massOf(list) then
			fail(scenario, "the cast for the whole group is offered where nothing is offered but to your target")
		end
		if not (resFor(list, filed(ANNA_PAIR)) and resFor(list, filed(BERT_PAIR))) then
			fail(scenario, "SKIPPED -- your dead target and focus are not both offered inside")
		end
		if resFor(list, filed(CARA_PAIR)) then
			fail(scenario, "a dead member you did not pick is offered where nothing is offered")
		end
	end)
end

-- ----------------------------------------------------------- res-review 2
-- The one cast for everybody reaches every dead member of the group, the one
-- flagged for PvP included: while the rule stands it does not form, and the
-- unflagged are offered one by one.
do
	local scenario = "res-review: no cast for the whole group while a dead member is flagged for PvP"
	with(scenario, { flavour = "mists", known = mistsPriest }, function(ns, world)
		local ANNA, BERT, CARA = filed(ANNA_PAIR), filed(BERT_PAIR), filed(CARA_PAIR)
		ns.db.profile.filters.skipPvP = true
		world.dead.party1, world.dead.party2, world.dead.party3 = true, true, true
		local mass = massOf(queue(ns))
		if not (mass and #mass.resNames == 3) then
			fail(scenario, "SKIPPED -- three dead are not offered the group's cast")
			return
		end
		Mock.pvp = { party3 = true }
		local list = queue(ns)
		if massOf(list) then
			fail(scenario, "the cast for the whole group is offered with a flagged member dead: it would flag you")
		end
		if resFor(list, CARA) then fail(scenario, "SKIPPED -- the flagged one is offered a resurrection of her own") end
		if not (resFor(list, ANNA) and resFor(list, BERT)) then
			fail(scenario, "the unflagged dead are not offered one by one")
		end
		-- Released as well: the cast would reach her all the same.
		world.dead.party3, world.ghost.party3 = nil, true
		if massOf(queue(ns)) then
			fail(scenario, "the cast for the whole group is offered with a flagged member dead and released")
		end
		-- The rule switched off: the cast is back, for all three.
		world.dead.party3, world.ghost.party3 = true, nil
		ns.db.profile.filters.skipPvP = false
		mass = massOf(queue(ns))
		if not (mass and #mass.resNames == 3) then
			fail(scenario, "the group's cast is not offered with the PvP rule off")
		end
	end)
end

-- ----------------------------------------------------------- res-review 3
-- Save mana: stop below holds back what nobody asked for, a resurrection too.
-- (The mock's mana stands at half.)
do
	local scenario = "res-review: the mana floor holds a resurrection back"
	with(scenario, {}, function(ns, world)
		local ANNA = filed(ANNA_PAIR)
		local f = ns.db.profile.filters
		world.dead.party1 = true
		if not resFor(queue(ns), ANNA) then
			fail(scenario, "SKIPPED -- no resurrection offered with no floor")
			return
		end
		f.manaFloor, f.manaFloorKeeps = 60, "none"
		if not ns.SavingMana() then
			fail(scenario, "SKIPPED -- the floor is not holding anything back")
			return
		end
		if resFor(queue(ns), ANNA) then
			fail(scenario, "a resurrection is offered under the mana floor")
		end
		f.manaFloorKeeps = "asked"
		if resFor(queue(ns), ANNA) then
			fail(scenario, "a resurrection nobody asked for is offered under the mana floor")
		end
		f.manaFloor = 20
		if not resFor(queue(ns), ANNA) then fail(scenario, "not offered above the floor") end
	end)
end

-- ----------------------------------------------------------- res-review 4
-- With My group's dead off, a resurrection learned is nothing to cast: a
-- class with nothing else has no prompt, and a press says its class has no
-- buffs, as before there was a resurrection here.
do
	local scenario = "res-review: switched off, a resurrection learned is nothing to cast"
	with(scenario, { flavour = "mainline", class = "MONK", known = { 115178 } }, function(ns, world)
		if ns.caps.anyKnown or ns.caps.anyOwnKnown then
			fail(scenario, "SKIPPED -- the monk has something else to cast")
			return
		end
		if not ns.CanCastAnything() then
			fail(scenario, "SKIPPED -- the monk has nothing to cast with the switch on")
			return
		end
		ns.db.profile.sources.res = false
		if ns.CanCastAnything() then
			fail(scenario, "a resurrection counts as something to cast with My group's dead off")
		end
		world.dead.party1 = true
		local list, refused = queue(ns)
		if #list ~= 0 or refused ~= true then
			fail(scenario, "the queue is built for a class with nothing to cast")
		end
		ns.addon:Tick()
		Mock.printed = {}
		pressButton(ns)
		local said = table.concat(Mock.printed, "\n")
		if said:find("nobody to buff right now", 1, true) then
			fail(scenario, "a press says nobody to buff, not that the class has no buffs: " .. said)
		end
		ns.db.profile.sources.res = true
		if not ns.CanCastAnything() then fail(scenario, "nothing to cast with the switch back on") end
	end)
end

-- ----------------------------------------------------------- res-review 5
-- The tooltip of the cast for the whole group: nothing is cast on you, and the
-- line under the name is how many it is for, not a word about one member.
do
	local scenario = "res-review: the tooltip of the group's resurrection is not a shout's"
	with(scenario, { flavour = "mists", known = mistsPriest }, function(ns, world)
		world.dead.party1, world.dead.party2 = true, true
		local mass = massOf(queue(ns))
		if not mass then
			fail(scenario, "SKIPPED -- two dead are not offered the group's cast")
			return
		end
		local said = table.concat(ns.Prompt:ClickSummary(mass), " / ")
		if said:find("on you", 1, true) then
			fail(scenario, "the tooltip says the resurrection is cast on you: " .. said)
		end
		if not said:find("Mass Resurrection", 1, true) then
			fail(scenario, "the tooltip does not name the spell: " .. said)
		end
		ns.addon:Tick()
		local current = ns.Prompt.state.current
		if not (current and current.resNames) then
			fail(scenario, "SKIPPED -- the group's cast is not on the prompt")
			return
		end
		local button = ns.Prompt:GetButton()
		Mock.tooltip = {}
		button.scripts.OnEnter(button)
		local lines = table.concat(Mock.tooltip or {}, " / ")
		if not lines:find("Mass Resurrection", 1, true) then
			fail(scenario, "SKIPPED -- the tooltip is not up: " .. lines)
			return
		end
		if lines:find("In your group.", 1, true) then
			fail(scenario, "the tooltip speaks of one member in your group: " .. lines)
		end
		if not lines:find("2 dead", 1, true) then
			fail(scenario, "the tooltip does not say how many it is for: " .. lines)
		end
		if button.scripts.OnLeave then button.scripts.OnLeave(button) end
	end)
end
