-- Resurrection (Resurrect.lua). Until it a dead player was nobody: the walk
-- turns the dead down and offers them nothing. Now, out of a fight, a dead
-- member of the group within reach is offered your resurrection, first of
-- everything on the prompt, and with a second switch a dead passer-by too. A
-- press is the usual macro; nothing is said; whoever was pressed rests until
-- they live or the cast is seen to fail.
--
-- Every scenario name starts with "res:" so the mutations in
-- tests/mutations/res.py can name the one that has to catch them.

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
	"UnitInParty", "C_Spell" }

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

local ANNA_PAIR, BERT_PAIR = PARTY.party1, PARTY.party2

-- ------------------------------------------------------------------ res 1
-- Somebody of the group who is dead is offered your resurrection, ahead of
-- everybody: the member missing your buff, and your own target. The macro is
-- the one every press is: their name, the spell, your target handed back.
do
	local scenario = "res: a dead member of the group is offered your resurrection, first of everything"
	local names = { party1 = PARTY.party1, party2 = PARTY.party2, party3 = PARTY.party3, target = { "Dora", "Deep" } }
	with(scenario, { names = names }, function(ns, world)
		local ANNA, BERT, DORA = filed(ANNA_PAIR), filed(BERT_PAIR), filed(names.target)
		ns.db.profile.sources.strangers = true
		local before = queue(ns)
		if resFor(before, ANNA) then fail(scenario, "a resurrection is offered to somebody alive") end
		-- The prompt is on your target, the best of the buffs, when she dies.
		ns.addon:Tick()
		if ns.Prompt:PanelName() ~= DORA then
			fail(scenario, "SKIPPED -- the prompt was not on your target: " .. tostring(ns.Prompt:PanelName()))
			return
		end
		world.dead.party1 = true
		local list = queue(ns)
		local anna = resFor(list, ANNA)
		if not anna then
			fail(scenario, "a dead member of the group is offered no resurrection")
			return
		end
		local others = {}
		for _, entry in ipairs(list) do
			if not entry.res then others[entry.name] = entry end
		end
		if not (others[BERT] and others[DORA]) then
			fail(scenario, "SKIPPED -- nobody else is waiting for a buff")
			return
		end
		if others[DORA].priority ~= 0 then
			fail(scenario, "SKIPPED -- your target is not at the front of the buffs")
			return
		end
		if list[1] ~= anna then
			fail(scenario, "the dead member is not first: " .. tostring(list[1].name) .. " is, for "
				.. tostring(list[1].buff and list[1].buff.key))
		end
		if others[ANNA] then fail(scenario, "somebody dead is offered a buff as well") end
		if anna.buff.key ~= "resurrect" or anna.reason ~= "group" or anna.inGroup ~= true then
			fail(scenario, ("the entry reads %s, %s"):format(tostring(anna.buff.key), tostring(anna.reason)))
		end
		-- The prompt leaves your target for her (before anything here arms it).
		ns.addon:Tick()
		if ns.Prompt:PanelName() ~= ANNA then
			fail(scenario, "the prompt is on " .. tostring(ns.Prompt:PanelName()) .. ", not the dead member")
		end
		local ran = macroFor(ns, anna)
		local want = "/target " .. ANNA .. "\n/cast Resurrection\n/targetlasttarget"
		if ran ~= want then fail(scenario, "the macro reads " .. flat(ran) .. ", not " .. flat(want)) end
	end)
end

-- ------------------------------------------------------------------ res 2
-- Never in a fight: not under the lockdown, not while the game says you are in
-- one before it, and the pull's own repaint takes the resurrection off the
-- button, since what it arms is frozen for the whole fight.
do
	local scenario = "res: nothing is offered in a fight, and the pull leaves none on the button"
	with(scenario, {}, function(ns, world)
		local ANNA = filed(ANNA_PAIR)
		world.dead.party1 = true
		if not resFor(queue(ns), ANNA) then
			fail(scenario, "SKIPPED -- no resurrection out of a fight")
			return
		end
		world.combat = true
		if resFor(queue(ns), ANNA) then fail(scenario, "offered while the game says you are in a fight") end
		world.combat = false
		Mock.inCombat = true
		if resFor(queue(ns), ANNA) then fail(scenario, "offered under the combat lockdown") end
		local said = table.concat(ns.ResurrectLines(true), "\n")
		if not said:find("in a fight", 1, true) then
			fail(scenario, "the debug lines do not say a fight holds it back: " .. said)
		end
		Mock.inCombat = false
		Mock.advance(4)
		ns.addon:Tick()
		local button = ns.Prompt:GetButton()
		if not tostring(button:GetAttribute("macrotext1")):find("Resurrection", 1, true) then
			fail(scenario, "SKIPPED -- the resurrection was not on the button before the pull")
			return
		end
		ns.addon:PLAYER_REGEN_DISABLED()
		local frozen = button:GetAttribute("macrotext1")
		if tostring(frozen):find("Resurrection", 1, true) then
			fail(scenario, "the pull froze a resurrection onto the button: " .. flat(frozen))
		end
		Mock.runTimers(1)
		ns.addon:PLAYER_REGEN_ENABLED()
	end)
end

-- ------------------------------------------------------------------ res 3
-- Somebody with a resurrection already on its way is left alone, so two
-- healers are not sent to the same body, and the prompt lets go of them at the
-- next scan, not after its hold. Once the other cast stops they are back.
do
	local scenario = "res: somebody with a resurrection on the way is left alone, at once"
	with(scenario, {}, function(ns, world)
		local ANNA = filed(ANNA_PAIR)
		world.dead.party1 = true
		Mock.advance(4)
		ns.addon:Tick()
		local current = ns.Prompt.state.current
		if not (current and current.res and current.name == ANNA) then
			fail(scenario, "SKIPPED -- the dead member was not on the prompt")
			return
		end
		world.incoming.party1 = true
		-- No time passes: the hold would keep her for a second and a half.
		ns.addon:Tick()
		if resFor(ns.BuildQueue(), ANNA) then
			fail(scenario, "offered while another resurrection is on its way to her")
		end
		current = ns.Prompt.state.current
		if current and current.res and current.name == ANNA then
			fail(scenario, "the prompt still holds her resurrection while somebody else casts theirs")
		end
		local said = table.concat(ns.ResurrectLines(true), "\n")
		if not said:find("already on its way", 1, true) then
			fail(scenario, "the debug lines do not say why she is left alone: " .. said)
		end
		world.incoming.party1 = nil
		if not resFor(queue(ns), ANNA) then
			fail(scenario, "not offered again once the other resurrection stopped")
		end
	end)
end

-- ------------------------------------------------------------------ res 4
-- Somebody who has released is a spirit running back. The client reads where
-- the spirit is, never where the body lies, so nothing is offered, and the
-- debug lines say so.
do
	local scenario = "res: somebody who released their spirit is left alone"
	with(scenario, {}, function(ns, world)
		local ANNA, BERT = filed(ANNA_PAIR), filed(BERT_PAIR)
		world.dead.party2 = true
		world.ghost.party1 = true
		local list = queue(ns)
		if not resFor(list, BERT) then
			fail(scenario, "SKIPPED -- nobody dead is offered a resurrection")
			return
		end
		if resFor(list, ANNA) then fail(scenario, "a resurrection is offered to a spirit") end
		local said = table.concat(ns.ResurrectLines(true), "\n")
		if not said:find("released their spirit", 1, true) then
			fail(scenario, "the debug lines do not say she released: " .. said)
		end
	end)
end

-- ------------------------------------------------------------------ res 5
-- A hunter lying in Feign Death reads as dead and is not.
do
	local scenario = "res: a hunter lying in Feign Death is not dead"
	with(scenario, {}, function(ns, world)
		local ANNA, BERT = filed(ANNA_PAIR), filed(BERT_PAIR)
		world.dead.party1, world.dead.party2 = true, true
		world.feign.party1 = true
		local list = queue(ns)
		if not resFor(list, BERT) then
			fail(scenario, "SKIPPED -- nobody dead is offered a resurrection")
			return
		end
		if resFor(list, ANNA) then fail(scenario, "a resurrection is offered to somebody feigning death") end
	end)
end

-- ------------------------------------------------------------------ res 6
-- Within reach: not somebody measured out of the spell's range, not somebody
-- out of sight. A range the client will not give is offered.
do
	local scenario = "res: somebody out of reach or out of sight is not offered"
	with(scenario, {}, function(ns, world)
		local ANNA = filed(ANNA_PAIR)
		world.dead.party1 = true
		if not resFor(queue(ns), ANNA) then
			fail(scenario, "SKIPPED -- no resurrection within reach")
			return
		end
		Mock.rangeByUnit = { party1 = false }
		if resFor(queue(ns), ANNA) then fail(scenario, "offered to somebody measured out of range") end
		local said = table.concat(ns.ResurrectLines(true), "\n")
		if not said:find("out of reach", 1, true) then
			fail(scenario, "the debug lines do not say she is out of reach: " .. said)
		end
		Mock.rangeByUnit = nil
		world.hidden.party1 = true
		if resFor(queue(ns), ANNA) then fail(scenario, "offered to somebody out of sight") end
		world.hidden.party1 = nil
		Mock.rangeless = { [2006] = true, [2010] = true, Resurrection = true }
		if not resFor(queue(ns), ANNA) then fail(scenario, "not offered when the client gives no range") end
		Mock.rangeless = nil
	end)
end

-- ------------------------------------------------------------------ res 7
-- The second line says why they are on the prompt: they are dead.
do
	local scenario = "res: the reason line says they are dead"
	with(scenario, {}, function(ns, world)
		local ANNA = filed(ANNA_PAIR)
		world.dead.party1 = true
		local anna = resFor(queue(ns), ANNA)
		if not anna then
			fail(scenario, "SKIPPED -- no resurrection offered")
			return
		end
		local line = ns.Prompt:ReasonText(anna)
		if line ~= "dead" then fail(scenario, "the reason line reads '" .. tostring(line) .. "'") end
	end)
end

-- ------------------------------------------------------------------ res 8
-- A press is the resurrection's own: nothing is parked as a buff's press is,
-- no favour is repaid by it, and she rests through the ten seconds of the
-- cast. A cast seen to fail gives her back after a moment; the same spell
-- refused under another cast's guid (the bar macro pressed again) does not.
do
	local scenario = "res: a press rests them through the cast, until it is seen to fail"
	with(scenario, {}, function(ns, world)
		local ANNA = filed(ANNA_PAIR)
		world.dead.party1 = true
		owe(ns, ANNA)
		Mock.advance(4)
		ns.addon:Tick()
		if ns.Prompt:PanelName() ~= ANNA then
			fail(scenario, "SKIPPED -- the dead member was not on the prompt")
			return
		end
		local ran = pressButton(ns)
		if not tostring(ran):find("/cast Resurrection", 1, true) then
			fail(scenario, "SKIPPED -- the press ran " .. flat(ran))
			return
		end
		if ns.pendingClick then fail(scenario, "the press was parked as a buff's press is") end
		if not ns.Resurrect.pending then
			fail(scenario, "the press was not filed as a resurrection")
			return
		end
		if resFor(ns.BuildQueue(), ANNA) then fail(scenario, "offered again in the instant after the press") end
		Mock.advance(0.5)
		cast(ns, "UNIT_SPELLCAST_SENT", ANNA, "cast-1", 2010)
		cast(ns, "UNIT_SPELLCAST_START", "cast-1", 2010)
		if resFor(queue(ns, 5), ANNA) then fail(scenario, "offered again while the resurrection is being cast") end
		-- Another cast of the same spell refused, under its own guid.
		cast(ns, "UNIT_SPELLCAST_FAILED", "cast-2", 2010)
		if resFor(queue(ns, 3), ANNA) then
			fail(scenario, "another cast's refusal ended the rest of the one under way")
		end
		if not ns.Resurrect.pending then
			fail(scenario, "SKIPPED -- the press was forgotten before its cast ended")
			return
		end
		cast(ns, "UNIT_SPELLCAST_INTERRUPTED", "cast-1", 2010)
		if resFor(queue(ns, 1), ANNA) then fail(scenario, "offered again in the same second as the failure") end
		if not resFor(queue(ns, 2), ANNA) then fail(scenario, "not offered again after the cast failed") end
		if not ns.owed[ANNA] then fail(scenario, "the press let go of the favour she is owed") end
	end)
end

-- ------------------------------------------------------------------ res 9
-- A cast that finished rests her while the game's question is hers to answer,
-- and no longer than that; standing up ends it, so dying again inside the
-- minute is offered at once. And the favour ledger has it as something given.
do
	local scenario = "res: a cast that finished rests them until they live, and is in the ledger"
	with(scenario, {}, function(ns, world)
		local ANNA = filed(ANNA_PAIR)
		ns.db.char.ledger = nil
		ns.Ledger.Load()
		local store = ns.db.char.ledger
		world.dead.party1 = true
		local function pressAndCast()
			Mock.advance(4)
			ns.addon:Tick()
			if ns.Prompt:PanelName() ~= ANNA then return false end
			pressButton(ns)
			if not ns.Resurrect.pending then return false end
			Mock.advance(0.5)
			cast(ns, "UNIT_SPELLCAST_SENT", ANNA, "cast-1", 2010)
			cast(ns, "UNIT_SPELLCAST_START", "cast-1", 2010)
			Mock.advance(10)
			cast(ns, "UNIT_SPELLCAST_SUCCEEDED", "cast-1", 2010)
			return true
		end
		if not pressAndCast() then
			fail(scenario, "SKIPPED -- the press on the dead member was not filed")
			return
		end
		if #store.entries ~= 1 then
			fail(scenario, ("the ledger holds %d rows after the resurrection, not one"):format(#store.entries))
		elseif store.entries[1].kind ~= "given" or store.entries[1].spell ~= 2010 then
			fail(scenario, ("the ledger's row is %s of %s"):format(tostring(store.entries[1].kind),
				tostring(store.entries[1].spell)))
		end
		if resFor(queue(ns, 30), ANNA) then
			fail(scenario, "offered again half a minute after the cast, while the question is hers to answer")
		end
		if not resFor(queue(ns, 40), ANNA) then
			fail(scenario, "still resting long after the game's question has gone")
		end
		-- Again, and this time she takes it: up, and dead once more ten seconds on.
		if not pressAndCast() then
			fail(scenario, "SKIPPED -- the second press was not filed")
			return
		end
		world.dead.party1 = nil
		Mock.advance(3)
		ns.addon:Tick()
		world.dead.party1 = true
		if not resFor(queue(ns, 10), ANNA) then
			fail(scenario, "somebody who stood up and died again is still resting from the first resurrection")
		end
	end)
end

-- ------------------------------------------------------------------ res 10
-- On for the group and off for passers-by in a new profile, and each switch
-- obeyed: a dead stranger you target is offered only with the second ticked,
-- and nobody at all with the first off.
do
	local scenario = "res: on for the group, off for a dead passer-by until ticked"
	local names = { party1 = PARTY.party1, party2 = PARTY.party2, target = { "Dora", "Deep" } }
	with(scenario, { names = names }, function(ns, world)
		local ANNA, DORA = filed(ANNA_PAIR), filed(names.target)
		local defaults = ns.defaults.profile.sources
		if defaults.res ~= true then fail(scenario, "a new profile has My group's dead " .. tostring(defaults.res)) end
		if defaults.resStrangers ~= false then
			fail(scenario, "a new profile has Dead passers-by too " .. tostring(defaults.resStrangers))
		end
		local sources = ns.db.profile.sources
		world.dead.party1, world.dead.target = true, true
		local list = queue(ns)
		if not resFor(list, ANNA) then
			fail(scenario, "SKIPPED -- the dead member of the group is not offered")
			return
		end
		if resFor(list, DORA) then fail(scenario, "a dead passer-by is offered with the switch off") end
		sources.resStrangers = true
		local dora = resFor(queue(ns), DORA)
		if not dora then
			fail(scenario, "a dead passer-by you target is not offered with the switch on")
		elseif dora.reason ~= "nearby" or dora.inGroup ~= false then
			fail(scenario, ("the passer-by is filed as %s, in the group %s"):format(tostring(dora.reason),
				tostring(dora.inGroup)))
		end
		sources.res = false
		list = queue(ns)
		if resFor(list, ANNA) or resFor(list, DORA) then
			fail(scenario, "a resurrection is offered with My group's dead switched off")
		end
		local said = table.concat(ns.ResurrectLines(true), "\n")
		if not said:find("switched off", 1, true) then
			fail(scenario, "the debug lines do not say the switch is off: " .. said)
		end
	end)
end

-- ------------------------------------------------------------------ res 11
-- The two switches on Who to buff, for a class with a resurrection on this
-- client and no other; the second a step in under the first and hidden while
-- it is off; both in the page's reset; a damaged value put back.
do
	local scenario = "res: the switches sit on Who to buff, for a class that has a resurrection"
	with(scenario, {}, function(ns)
		local res, strangersToo = H.findOption(ns.optionsTable, "res"), H.findOption(ns.optionsTable, "resStrangers")
		if not (res and strangersToo) then
			fail(scenario, "the options hold no My group's dead, or no Dead passers-by too")
			return
		end
		if res.type ~= "toggle" or H.optionText(res.name) ~= "My group's dead" then
			fail(scenario, "the control is a " .. tostring(res.type) .. " called " .. H.optionText(res.name))
		end
		if not H.optionText(res.desc):find("Never in a fight", 1, true) then
			fail(scenario, "its description does not say it is never offered in a fight")
		end
		if H.optionText(strangersToo.name) ~= "Dead passers-by too" then
			fail(scenario, "the second control is called " .. H.optionText(strangersToo.name))
		end
		local sources = ns.db.profile.sources
		if type(res.hidden) ~= "function" or res.hidden() then fail(scenario, "hidden from a priest") end
		sources.res = true
		if type(strangersToo.hidden) ~= "function" or strangersToo.hidden() then
			fail(scenario, "the second switch is hidden while the first is on")
		end
		sources.res = false
		if type(strangersToo.hidden) ~= "function" or not strangersToo.hidden() then
			fail(scenario, "the second switch is shown while the first is off")
		end
		res.set({ "who", "res" }, true)
		if sources.res ~= true or res.get({ "who", "res" }) ~= true then
			fail(scenario, "ticking it does not write sources.res: " .. tostring(sources.res))
		end
		strangersToo.set({ "who", "resStrangers" }, true)
		if sources.resStrangers ~= true then
			fail(scenario, "ticking the second does not write sources.resStrangers")
		end

		for _, bad in ipairs({ "yes", 1, {} }) do
			sources.res, sources.resStrangers = bad, bad
			ns.ClampSettings()
			if sources.res ~= true or sources.resStrangers ~= false then
				fail(scenario, ("a %s left in the file reads %s and %s after the repair"):format(type(bad),
					tostring(sources.res), tostring(sources.resStrangers)))
			end
		end
		local listed = {}
		for _, path in ipairs(ns.OptionsPage.RESET.who or {}) do listed[path] = true end
		if not (listed["sources.res"] and listed["sources.resStrangers"]) then
			fail(scenario, "Who to buff's reset does not reach both switches")
		end

		if not H.layoutInToc() then return end
		local page, section, index = H.placedOn(ns, "who.res")
		local petsPage, petsSection, petsIndex = H.placedOn(ns, "who.pets")
		local tooPage, tooSection, tooIndex = H.placedOn(ns, "who.resStrangers")
		if not (page and tooPage) then
			fail(scenario, "the window places one of them on no page")
		elseif page ~= petsPage or section ~= petsSection or index ~= petsIndex + 1 then
			fail(scenario, "the window does not draw My group's dead with the group's switches")
		elseif tooSection ~= section or tooIndex ~= index + 1 or type(section.items[tooIndex]) ~= "table"
			or section.items[tooIndex].indent ~= true then
			fail(scenario, "Dead passers-by too is not a step in under My group's dead")
		end
		local parents = ns.WindowLayout.parents or {}
		if parents["who.resStrangers"] ~= "who.res" then
			fail(scenario, "search is not told which switch shows the second: " .. tostring(parents["who.resStrangers"]))
		end
	end)
	-- A mage has no resurrection on any client: neither switch is shown.
	with(scenario, { class = "MAGE", known = { 1459 } }, function(ns)
		local res, strangersToo = H.findOption(ns.optionsTable, "res"), H.findOption(ns.optionsTable, "resStrangers")
		if not (res and strangersToo) then return end
		if not res.hidden() or not strangersToo.hidden() then
			fail(scenario, "a mage is shown a switch for a resurrection")
		end
	end)
end

-- ------------------------------------------------------------------ res 12
-- Where a client has one cast for everybody dead in the group, several dead
-- are offered it ahead of any one of them: a bare /cast, named for the group,
-- with how many it is for. One dead member is offered the single spell alone.
do
	local scenario = "res: several dead are offered the one cast for the group"
	with(scenario, { flavour = "mists", known = function(ns)
		local ids = { 2006, 83968 }
		for _, id in ipairs(ns.FindBuff("PRIEST", "fortitude").ranks) do ids[#ids + 1] = id end
		return ids
	end }, function(ns, world)
		local ANNA, BERT = filed(ANNA_PAIR), filed(BERT_PAIR)
		world.dead.party1 = true
		local list = queue(ns)
		if not resFor(list, ANNA) then
			fail(scenario, "SKIPPED -- one dead member is offered no resurrection")
			return
		end
		if massOf(list) then fail(scenario, "one dead member is offered the cast for the whole group") end
		world.dead.party2 = true
		list = queue(ns)
		local mass = massOf(list)
		if not mass then
			fail(scenario, "two dead members are not offered the one cast for the group")
			return
		end
		if list[1] ~= mass then fail(scenario, "the cast for the group is not ahead of the single ones") end
		if not (resFor(list, ANNA) and resFor(list, BERT)) then
			fail(scenario, "the single resurrections are not offered behind it")
		end
		if #mass.resNames ~= 2 or mass.buff.key ~= "massresurrect" then
			fail(scenario, ("the cast is %s for %d"):format(tostring(mass.buff.key), #mass.resNames))
		end
		local ran = macroFor(ns, mass)
		if ran ~= "/cast Mass Resurrection" then fail(scenario, "the macro reads " .. flat(ran)) end
		local line = ns.Prompt:ReasonText(mass)
		if line ~= "2 dead" then fail(scenario, "the reason line reads '" .. tostring(line) .. "'") end
		-- Pressed, and cast: both rest, and neither is offered one by one.
		ns.addon:Tick()
		pressButton(ns)
		if not (ns.Resurrect.pending and ns.Resurrect.pending.mass) then
			fail(scenario, "SKIPPED -- the press on the group's cast was not filed")
			return
		end
		Mock.advance(0.5)
		cast(ns, "UNIT_SPELLCAST_SENT", "", "cast-1", 83968)
		Mock.advance(10)
		cast(ns, "UNIT_SPELLCAST_SUCCEEDED", "cast-1", 83968)
		list = queue(ns, 5)
		if massOf(list) or resFor(list, ANNA) or resFor(list, BERT) then
			fail(scenario, "somebody the group's cast reached is offered again straight after it")
		end
	end)
end

-- ------------------------------------------------------------------ res 13
-- Each client's own spells, and nothing that is for fights: no Rebirth, no
-- Raise Ally. A druid on Forever has Revive, on Burning Crusade nothing.
do
	local scenario = "res: each client has its own spells, and none that is for a fight"
	with(scenario, { class = "DRUID", known = { 437138, 1237948, 20484 } }, function(ns, world)
		local ANNA = filed(ANNA_PAIR)
		local S = ns.Resurrect.SPELLS
		local function has(list, id)
			for _, value in ipairs(list or {}) do
				if value == id then return true end
			end
			return false
		end
		for flavour, set in pairs(S) do
			if set.MAGE or set.WARRIOR or set.DEATHKNIGHT or set.WARLOCK then
				fail(scenario, flavour .. " gives a resurrection to a class without one")
			end
			for class, spells in pairs(set) do
				for _, id in ipairs({ 20484, 20748, 61999, 391054, 32841, 20707 }) do
					if has(spells.single, id) or has(spells.mass, id) then
						fail(scenario, ("%s %s holds %d, which is not for after a fight"):format(flavour, class, id))
					end
				end
				if (flavour == "camelot" or flavour == "vanilla" or flavour == "tbc") and spells.mass then
					fail(scenario, flavour .. " " .. class .. " has a cast for the whole group")
				end
			end
		end
		if not (has(S.camelot.DRUID.single, 437138) and S.camelot.DRUID.single[1] == 1237951) then
			fail(scenario, "Forever's druid has no Revive, or not its best rank first")
		end
		if S.tbc.DRUID then fail(scenario, "Burning Crusade's druid has a resurrection for after a fight") end
		if not (S.tbc.PRIEST.single[1] == 25435 and S.tbc.SHAMAN.single[1] == 25590) then
			fail(scenario, "Burning Crusade's priest or shaman lacks its last rank")
		end
		if not (S.mists.MONK and S.mists.MONK.mass[1] == 1245934 and S.mainline.EVOKER.single[1] == 361227) then
			fail(scenario, "a monk on Mists or an evoker on retail lacks its own")
		end
		-- The druid of this session, on Forever, with two ranks learned.
		world.dead.party1 = true
		local anna = resFor(queue(ns), ANNA)
		if not anna then
			fail(scenario, "a druid on Forever who knows Revive is offered nothing for the dead")
			return
		end
		local ran = macroFor(ns, anna)
		if not tostring(ran):find("/cast Revive", 1, true) then
			fail(scenario, "the druid's macro reads " .. flat(ran))
		end
	end)
	with(scenario, { flavour = "tbc", class = "DRUID", known = { 20484, 20748, 26994 } }, function(ns, world)
		world.dead.party1 = true
		if ns.Resurrect.Has() then fail(scenario, "a druid on Burning Crusade is taken to have one") end
		for _, entry in ipairs(queue(ns)) do
			if entry.res then fail(scenario, "a druid on Burning Crusade is offered Rebirth after a fight") end
		end
	end)
end

-- ------------------------------------------------------------------ res 14
-- Nothing is said for a resurrection: with a line switched on that a living
-- member of the group gets, the macro for the dead one carries none.
do
	local scenario = "res: nothing is said for a resurrection"
	with(scenario, {}, function(ns, world)
		local ANNA, BERT = filed(ANNA_PAIR), filed(BERT_PAIR)
		local speech = ns.db.profile.speech
		speech.enabled, speech.onlyWhenReturning, speech.channel = true, false, "SAY"
		speech.phrases = "Here you are, {name}."
		world.dead.party1 = true
		local list = queue(ns)
		local anna, bert = resFor(list, ANNA), nil
		for _, entry in ipairs(list) do
			if entry.name == BERT then bert = entry end
		end
		if not (anna and bert) then
			fail(scenario, "SKIPPED -- the dead and the living member are not both offered")
			return
		end
		if not tostring(macroFor(ns, bert)):find("Here you are", 1, true) then
			fail(scenario, "SKIPPED -- nobody is spoken to with these settings")
			return
		end
		local ran = macroFor(ns, anna)
		if tostring(ran):find("Here you are", 1, true) or tostring(ran):find("/s ", 1, true) then
			fail(scenario, "the resurrection's macro says a line: " .. flat(ran))
		end
		if ns.Prompt.state.phraseArmed then fail(scenario, "a line is armed for the resurrection") end
	end)
end

-- ------------------------------------------------------------------ res 15
-- A class whose only cast is its resurrection has a prompt for it: a monk on
-- retail, with nothing for others and nothing of its own. No walk is made for
-- such a class, so the group's dead are found here.
do
	local scenario = "res: a class with nothing but its resurrection has a prompt for it"
	with(scenario, { flavour = "mainline", class = "MONK", known = { 115178 } }, function(ns, world)
		local ANNA = filed(ANNA_PAIR)
		if ns.caps.anyKnown or ns.caps.anyOwnKnown then
			fail(scenario, "SKIPPED -- the monk has something else to cast")
			return
		end
		if not ns.CanCastAnything() then
			fail(scenario, "a monk who knows Resuscitate has nothing to cast")
			return
		end
		world.dead.party1 = true
		local anna = resFor(queue(ns), ANNA)
		if not anna then
			fail(scenario, "the monk is offered nothing for a dead member of the group")
			return
		end
		ns.addon:Tick()
		local ran = ns.Prompt:GetButton():GetAttribute("macrotext1")
		if not tostring(ran):find("/cast Resuscitate", 1, true) then
			fail(scenario, "the monk's prompt runs " .. flat(ran))
		end
	end)
end

-- ------------------------------------------------------------------ res 16
-- A scan with nobody dead costs nothing more for the switch being on: the
-- walk hands over the dead it meets, and nobody is asked twice.
do
	local scenario = "res: a scan with nobody dead asks the client nothing more"
	with(scenario, {}, function(ns, world)
		local sources = ns.db.profile.sources
		local function asked()
			wipe(world.asked)
			Mock.advance(4)
			ns.BuildQueue()
			return (world.asked.party1 or 0) + (world.asked.party2 or 0) + (world.asked.party3 or 0)
		end
		sources.res = false
		local off = asked()
		sources.res = true
		local on = asked()
		if off == 0 then
			fail(scenario, "SKIPPED -- the walk asked nobody whether they were dead")
			return
		end
		if on ~= off then
			fail(scenario, ("%d questions about the dead with the switch on, %d with it off"):format(on, off))
		end
	end)
end

-- ------------------------------------------------------------------ res 17
-- What you cannot pay for is not offered, on the game's own word, and the
-- debug lines say it is the mana.
do
	local scenario = "res: not offered without the mana for it"
	with(scenario, {}, function(ns, world)
		local ANNA = filed(ANNA_PAIR)
		world.dead.party1 = true
		if not resFor(queue(ns), ANNA) then
			fail(scenario, "SKIPPED -- no resurrection offered")
			return
		end
		world.noMana = true
		if resFor(queue(ns), ANNA) then fail(scenario, "offered while the game says there is not the mana") end
		local said = table.concat(ns.ResurrectLines(true), "\n")
		if not said:find("not enough mana", 1, true) then
			fail(scenario, "the debug lines do not say it is the mana: " .. said)
		end
	end)
end

-- ------------------------------------------------------------------ res 18
-- The never-offer list and the PvP rule hold for the dead as for the living:
-- helping somebody flagged flags you, a resurrection included.
do
	local scenario = "res: the never-offer list and the PvP rule hold for the dead too"
	with(scenario, {}, function(ns, world)
		local ANNA, BERT = filed(ANNA_PAIR), filed(BERT_PAIR)
		world.dead.party1, world.dead.party2 = true, true
		local list = queue(ns)
		if not (resFor(list, ANNA) and resFor(list, BERT)) then
			fail(scenario, "SKIPPED -- the two dead members are not both offered")
			return
		end
		ns.db.profile.filters.skipPvP = true
		Mock.pvp = { party1 = true }
		list = queue(ns)
		if resFor(list, ANNA) then fail(scenario, "offered to somebody flagged for PvP while you are not") end
		if not resFor(list, BERT) then fail(scenario, "SKIPPED -- the unflagged one went with her") end
		Mock.pvp = nil
		ns.PutOnNeverList(BERT)
		list = queue(ns)
		if resFor(list, BERT) then fail(scenario, "offered to somebody on the never-offer list") end
		if not resFor(list, ANNA) then fail(scenario, "not offered again once her flag dropped") end
	end)
end

-- ------------------------------------------------------------------ res 19
-- /manners debug says what a resurrection is doing, in the report a player
-- pastes: who it is offered for, and who rests after a press.
do
	local scenario = "res: /manners debug says what is offered and who rests"
	with(scenario, {}, function(ns, world)
		world.dead.party1, world.dead.party2 = true, true
		Mock.advance(4)
		ns.addon:Tick()
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		local said = table.concat(Mock.printed, "\n")
		if not said:find("resurrection: |cffffffffResurrection|r for 2 dead", 1, true) then
			fail(scenario, "/manners debug does not say who the resurrection is for")
		end
		-- Whichever of the two the prompt is on: it stays with whoever it was on.
		local current = ns.Prompt.state.current
		if not (current and current.res) then
			fail(scenario, "SKIPPED -- no dead member was on the prompt")
			return
		end
		pressButton(ns)
		local lines = table.concat(ns.ResurrectLines(true), "\n")
		if not lines:find("1 resting after your press", 1, true) then
			fail(scenario, "the lines do not say who rests after the press: " .. lines)
		end
	end)
end
