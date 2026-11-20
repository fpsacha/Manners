-- Cures (Cures.lua): a poison, a disease, a curse or a harmful spell on a
-- group member, and with a second switch on a passer-by, offered its cure on
-- the prompt, out of combat. Two switches on Who to buff, both off until
-- ticked (sources.cures, sources.curesStrangers), and the seconds a debuff
-- must have left (filters.cureSeconds, 10).
--
-- The mock's aura list knows no debuffs, so each session stands its own
-- C_UnitAuras in front of it: a harmful read answers from `debuffs`, by unit
-- token, and is counted (`reads`); everything else goes to the mock's own.
--
-- Every scenario name starts with "cures:" so the mutations in
-- tests/mutations/cures.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

-- Two others in a party of three.
local PARTY = {
	party1 = { "Gwen", "Hale" },
	party2 = { "Hugo", "Holt" },
}

-- A druid: Mark of the Wild's first rank, Cure Poison and Remove Curse.
local MOTW, CURE_POISON, REMOVE_CURSE = 1126, 8946, 2782
local DRUID = { MOTW, CURE_POISON, REMOVE_CURSE }

local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "UnitInParty", "C_UnitAuras", "IsUsableSpell" }

-- The name somebody is filed under: with a surname on Forever.
local function filed(pair)
	return Mock.surnames and pair[2] and (pair[1] .. " " .. pair[2]) or pair[1]
end

local function flat(text)
	return (tostring(text):gsub("\n", " / "))
end

-- One debuff, as a scenario writes it: its kind by the client's word, how many
-- seconds it has left (nil: no timer), its spell id, and the client's own word
-- on whether you can remove it (nil: a client that says nothing).
local function debuff(kind, left, id, can, name)
	return { kind = kind, left = left, id = id or 90000, can = can, name = name or ((kind or "Plain") .. " thing") }
end

-- One session, a druid in a party of three unless `env` says otherwise:
--   env.flavour  the client (Forever)
--   env.class    the player's class (DRUID)
--   env.known    spell ids known (DRUID)
--   env.names    the units that exist, by token (PARTY)
--   env.bare     nobody wears your buff (everybody wears Mark of the Wild)
--   env.keep     leave the switches as a new profile has them
-- body(ns, world): world.debuffs[unit] is that unit's harmful auras, in the
-- client's order; world.reads counts the harmful reads asked of the client,
-- in all (`n`) and by unit; world.known is the set of spells known;
-- world.names the units.
local function with(scenario, env, body)
	Mock.reset()
	if env.flavour then Mock.setFlavour(env.flavour) end
	Mock.class = env.class or "DRUID"
	Mock.groupSize = env.group or 3
	if not env.bare then Mock.held = { [MOTW] = true } end
	local names = {}
	for token, pair in pairs(env.names or PARTY) do names[token] = pair end
	local restore = strangers(names)
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local world = { debuffs = {}, reads = { n = 0 }, known = {}, names = names }
	for _, id in ipairs(env.known or DRUID) do world.known[id] = true end
	local ok, err = pcall(function()
		rawset(_G, "IsSpellKnown", function(id) return world.known[id] == true end)
		rawset(_G, "IsPlayerSpell", function(id) return world.known[id] == true end)
		rawset(_G, "UnitInParty", function(unit)
			return type(unit) == "string" and unit:find("^party%d+$") ~= nil
		end)
		local base = C_UnitAuras
		rawset(_G, "C_UnitAuras", setmetatable({
			GetAuraDataByIndex = function(unit, index, filter)
				if filter ~= "HARMFUL" then return base.GetAuraDataByIndex(unit, index, filter) end
				local reads = world.reads
				reads.n = reads.n + 1
				reads[unit] = (reads[unit] or 0) + 1
				if world.throws and world.throws[unit] then error("the aura list is refused") end
				local d = world.debuffs[unit] and world.debuffs[unit][index]
				if not d then return nil end
				if d == "secret" then return Mock.SECRET end
				return {
					name = d.name, spellId = d.id, dispelName = d.kind,
					expirationTime = d.left and (Mock.now + d.left) or 0,
					duration = d.left and 60 or 0,
					canActivePlayerDispel = d.can, isHarmful = true, auraInstanceID = 9000 + index,
				}
			end,
		}, { __index = base }))
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		local sources = ns.db.profile.sources
		sources.group, sources.strangers, sources.self = true, false, false
		if not env.keep then sources.cures = true end
		ns.Guard("probe", ns.ProbeCapabilities)
		for key in pairs(world.reads) do world.reads[key] = nil end
		world.reads.n = 0
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

-- The queue, by the name each entry is filed under and as a list. Four
-- seconds on first, past every reading kept.
local function queue(ns)
	Mock.advance(4)
	local list, byName = ns.BuildQueue(), {}
	for _, entry in ipairs(list) do byName[entry.name] = entry end
	return byName, list
end

-- The macro the prompt arms for `entry`.
local function macroFor(ns, entry)
	ns.pendingClick = nil
	ns.Prompt:InvalidateMacro()
	ns.Prompt:ApplyTarget(entry)
	return ns.Prompt:GetButton():GetAttribute("macrotext1")
end

-- What /manners debug prints.
local function debugSays(ns)
	Mock.printed = {}
	ns.addon:HandleSlash("debug")
	return table.concat(Mock.printed, "\n")
end

local GWEN, HUGO = PARTY.party1, PARTY.party2

-- ---------------------------------------------------------------- cures 1
-- A new profile has both switches off, and with them off nobody's debuffs are
-- read at all: the cost of the feature is paid only by who wants it.
do
	local scenario = "cures: off by default, and nobody's debuffs are read"
	with(scenario, { keep = true }, function(ns, world)
		local d = ns.defaults.profile
		if d.sources.cures ~= false or d.sources.curesStrangers ~= false then
			fail(scenario, ("the defaults are %s and %s, not off"):format(tostring(d.sources.cures),
				tostring(d.sources.curesStrangers)))
		end
		if d.filters.cureSeconds ~= 10 then
			fail(scenario, "the default seconds are " .. tostring(d.filters.cureSeconds) .. ", not 10")
		end
		world.debuffs.party1 = { debuff("Poison", 60) }
		local byName = queue(ns)
		local entry = byName[filed(GWEN)]
		if entry then fail(scenario, "with the switches off a party member was offered " .. tostring(entry.buff.key)) end
		if world.reads.n ~= 0 then
			fail(scenario, "with the switches off the client was asked for harmful auras " .. world.reads.n .. " times")
		end
		-- And the same party member is cured once the switch is on, so the
		-- silence above was the switch.
		ns.db.profile.sources.cures = true
		if not (queue(ns)[filed(GWEN)] or {}).cure then
			fail(scenario, "SKIPPED -- the party member is not offered a cure with the switch on either")
		end
	end)
end

-- ---------------------------------------------------------------- cures 2
-- On: a poisoned party member is offered Cure Poison, marked as a cure, read
-- as a certain thing (nothing "unverified"), and the press is the usual one:
-- /target by name, /cast, the target handed back. No unit token and no
-- [@...] conditional anywhere in it.
do
	local scenario = "cures: a poisoned party member is offered the cure, by the usual press"
	with(scenario, {}, function(ns, world)
		ns.db.profile.filters.restoreTarget = true
		world.debuffs.party1 = { debuff("Poison", 60, 2818, nil, "Deadly Poison") }
		local byName = queue(ns)
		local entry = byName[filed(GWEN)]
		if not entry then
			fail(scenario, "a poisoned party member is not offered anything")
			return
		end
		if entry.cure ~= "Poison" or not (entry.buff and entry.buff.cure == "Poison") then
			fail(scenario, "the entry is not a cure for a poison: " .. tostring(entry.buff and entry.buff.key))
			return
		end
		local info = ns.BuffInfo(entry.buff)
		if not (info and info.topRank == CURE_POISON) then
			fail(scenario, "the cure is not Cure Poison: " .. tostring(info and info.topRank))
		end
		if entry.known ~= false or entry.checked ~= true or entry.reason ~= "group" or entry.inGroup ~= true then
			fail(scenario, ("the entry reads known=%s checked=%s reason=%s inGroup=%s"):format(tostring(entry.known),
				tostring(entry.checked), tostring(entry.reason), tostring(entry.inGroup)))
		end
		if entry.debuff ~= "Deadly Poison" then
			fail(scenario, "the entry does not carry the debuff's name: " .. tostring(entry.debuff))
		end
		if byName[filed(HUGO)] then
			fail(scenario, "a party member with no debuff and your buff on was offered something")
		end
		local ran = macroFor(ns, entry)
		local want = "/target " .. filed(GWEN) .. "\n/cast " .. ns.BuffName(entry.buff)
		if type(ran) ~= "string" or ran:sub(1, #want) ~= want then
			fail(scenario, "the macro reads " .. flat(ran) .. ", not " .. flat(want) .. " and the hand-back")
		elseif not (ran:find("/targetlasttarget", 1, true) or ran:find("/cleartarget", 1, true)) then
			fail(scenario, "the macro hands no target back: " .. flat(ran))
		elseif ran:find("[@", 1, true) or ran:find("party1", 1, true) then
			fail(scenario, "the macro names a unit token or a conditional: " .. flat(ran))
		elseif #ran > 255 then
			fail(scenario, "the macro is " .. #ran .. " characters")
		end
	end)
end

-- ---------------------------------------------------------------- cures 3
-- A cure is the one entry somebody gets, so it comes before a buff for them,
-- and it ranks ahead of a buff for anybody else in the group. Cured, they are
-- offered the buff.
do
	local scenario = "cures: a cure comes before a buff, for the same person and in the queue"
	with(scenario, { bare = true }, function(ns, world)
		world.debuffs.party2 = { debuff("Curse", 60) }
		local byName, list = queue(ns)
		local gwen, hugo = byName[filed(GWEN)], byName[filed(HUGO)]
		if not (gwen and gwen.buff.key == "motw") then
			fail(scenario, "SKIPPED -- the party member with no debuff is not offered Mark of the Wild")
			return
		end
		if not (hugo and hugo.cure == "Curse") then
			fail(scenario, "somebody cursed and missing your buff is offered " .. tostring(hugo and hugo.buff.key)
				.. ", not the cure")
			return
		end
		local count = 0
		for _, entry in ipairs(list) do
			if entry.name == filed(HUGO) then count = count + 1 end
		end
		if count ~= 1 then fail(scenario, "somebody cursed and missing your buff has " .. count .. " entries") end
		if list[1] ~= hugo then
			fail(scenario, "the cure is not first in the queue: " .. tostring(list[1].name) .. " with "
				.. tostring(list[1].buff.key) .. " is")
		end
		-- The curse gone, as the client says it: the buff is theirs now.
		world.debuffs.party2 = nil
		ns.addon:UNIT_AURA("UNIT_AURA", "party2")
		hugo = queue(ns)[filed(HUGO)]
		if not (hugo and hugo.buff.key == "motw" and not hugo.cure) then
			fail(scenario, "cured, they are offered " .. tostring(hugo and hugo.buff.key) .. ", not Mark of the Wild")
		end
	end)
end

-- ---------------------------------------------------------------- cures 4
-- A favour owed comes first: somebody who buffed you is offered your buff
-- back, cursed or not, and that entry is ahead of anybody's cure.
do
	local scenario = "cures: a favour owed comes before a cure"
	with(scenario, { bare = true }, function(ns, world)
		world.debuffs.party1 = { debuff("Curse", 60) }
		world.debuffs.party2 = { debuff("Curse", 60) }
		H.owe(ns, filed(GWEN))
		local byName, list = queue(ns)
		local gwen, hugo = byName[filed(GWEN)], byName[filed(HUGO)]
		if not (hugo and hugo.cure) then
			fail(scenario, "SKIPPED -- the cursed member owed nothing is not offered a cure")
			return
		end
		if not gwen then
			fail(scenario, "somebody owed a favour and cursed is offered nothing")
		elseif gwen.cure or gwen.reason ~= "owed" or gwen.buff.key ~= "motw" then
			fail(scenario, ("somebody owed a favour and cursed is offered %s for the reason %s"):format(
				tostring(gwen.buff.key), tostring(gwen.reason)))
		elseif list[1] ~= gwen then
			fail(scenario, "the favour owed is not ahead of the cure: " .. tostring(list[1].name) .. " is first")
		end
	end)
end

-- ---------------------------------------------------------------- cures 5
-- Only a debuff with more than the seconds set left: the press has to be worth
-- it. Ten by default; the slider moves it.
do
	local scenario = "cures: a debuff about to run out is left alone"
	with(scenario, {}, function(ns, world)
		world.debuffs.party1 = { debuff("Poison", 8, nil, nil, "Slow Venom") }
		if queue(ns)[filed(GWEN)] then
			fail(scenario, "a poison with 8 seconds left was offered a cure, with 10 set")
		end
		local said = debugSays(ns)
		if not (said:find("Slow Venom", 1, true) and said:find("under 10 seconds left", 1, true)) then
			fail(scenario, "/manners debug does not say the poison was left alone for its time: " .. flat(said))
		end
		world.debuffs.party1 = { debuff("Poison", 14) }
		if not (queue(ns)[filed(GWEN)] or {}).cure then
			fail(scenario, "a poison with 14 seconds left was not offered a cure, with 10 set")
		end
		ns.db.profile.filters.cureSeconds = 30
		if queue(ns)[filed(GWEN)] then
			fail(scenario, "a poison with 14 seconds left was offered a cure, with 30 set")
		end
		-- Two of a kind: the one with time to spare is the one read.
		world.debuffs.party1 = { debuff("Poison", 5), debuff("Poison", 90, nil, nil, "Long Venom") }
		local entry = queue(ns)[filed(GWEN)]
		if not (entry and entry.cure == "Poison" and entry.debuff == "Long Venom") then
			fail(scenario, "a short poison ahead of a long one in the list hid the long one")
		end
	end)
end

-- ---------------------------------------------------------------- cures 6
-- A debuff with no timer is never offered: nothing says it has any time left,
-- and an area's aura comes straight back. /manners debug says so.
do
	local scenario = "cures: a debuff with no timer is never offered"
	with(scenario, {}, function(ns, world)
		world.debuffs.party1 = { debuff("Curse", nil, nil, nil, "Lingering Hex") }
		if queue(ns)[filed(GWEN)] then fail(scenario, "a curse with no timer was offered a cure") end
		local said = debugSays(ns)
		if not (said:find("Lingering Hex", 1, true) and said:find("it has no timer", 1, true)) then
			fail(scenario, "/manners debug does not say the curse has no timer: " .. flat(said))
		end
		world.debuffs.party1 = { debuff("Curse", 60) }
		if not (queue(ns)[filed(GWEN)] or {}).cure then
			fail(scenario, "SKIPPED -- the same curse with a timer is not offered a cure")
		end
	end)
end

-- ---------------------------------------------------------------- cures 7
-- The deny list: a debuff that must not be removed is never offered, whatever
-- its kind and time. Delusions of Jin'do on Forever, a curse a druid could
-- lift and its wearer wants.
do
	local scenario = "cures: a debuff on the deny list is never offered"
	with(scenario, {}, function(ns, world)
		world.debuffs.party1 = { debuff("Curse", 60, 24306, nil, "Delusions of Jin'do") }
		if queue(ns)[filed(GWEN)] then fail(scenario, "Delusions of Jin'do was offered a cure") end
		local said = debugSays(ns)
		if not (said:find("Delusions of Jin'do", 1, true) and said:find("never removes", 1, true)) then
			fail(scenario, "/manners debug does not say why it was left alone: " .. flat(said))
		end
		-- A curse beside it is still lifted.
		world.debuffs.party1 = { debuff("Curse", 60, 24306), debuff("Poison", 60) }
		local entry = queue(ns)[filed(GWEN)]
		if not (entry and entry.cure == "Poison") then
			fail(scenario, "a poison beside a debuff never removed was not offered its cure")
		end
		world.debuffs.party1 = { debuff("Curse", 60, 12345) }
		if not (queue(ns)[filed(GWEN)] or {}).cure then
			fail(scenario, "SKIPPED -- another curse is not offered a cure")
		end
	end)
end

-- ---------------------------------------------------------------- cures 8
-- Only a kind your class has a spell for, and only a spell you know: a druid
-- lifts no disease and no magic, and one who has not learned Remove Curse
-- lifts no curse.
do
	local scenario = "cures: only a kind you have a spell for, and know"
	with(scenario, {}, function(ns, world)
		world.debuffs.party1 = { debuff("Disease", 60), debuff("Magic", 60), debuff(nil, 60) }
		if queue(ns)[filed(GWEN)] then
			fail(scenario, "a druid was offered a cure for a disease, a spell or a debuff of no kind")
		end
		world.debuffs.party1 = { debuff("Curse", 60) }
		if not (queue(ns)[filed(GWEN)] or {}).cure then
			fail(scenario, "SKIPPED -- a druid who knows Remove Curse is not offered it for a curse")
			return
		end
		world.known[REMOVE_CURSE] = nil
		ns.Guard("probe", ns.ProbeCapabilities)
		if queue(ns)[filed(GWEN)] then
			fail(scenario, "a druid who has not learned Remove Curse was offered a cure for a curse")
		end
	end)
end

-- ---------------------------------------------------------------- cures 9
-- Where the client says whether you can remove a debuff, its no is final; a
-- client that says nothing leaves it to the kind.
do
	local scenario = "cures: what the client says you cannot remove is left alone"
	with(scenario, {}, function(ns, world)
		world.debuffs.party1 = { debuff("Poison", 60, nil, false) }
		if queue(ns)[filed(GWEN)] then
			fail(scenario, "a poison the client says you cannot remove was offered a cure")
		end
		world.debuffs.party1 = { debuff("Poison", 60, nil, true) }
		if not (queue(ns)[filed(GWEN)] or {}).cure then
			fail(scenario, "a poison the client says you can remove was not offered a cure")
		end
		-- A debuff the client will not show, and a list it refuses: nothing is
		-- offered on either, and nothing throws.
		world.debuffs.party1 = { "secret" }
		if queue(ns)[filed(GWEN)] then fail(scenario, "a debuff the client withholds was offered a cure") end
		world.debuffs.party1 = { debuff("Poison", 60) }
		world.throws = { party1 = true }
		if queue(ns)[filed(GWEN)] then fail(scenario, "a list the client refused was read as a poison") end
	end)
end

-- --------------------------------------------------------------- cures 10
-- Never in a fight: not in the lockdown, and not on the repaint the pull makes
-- just before it, whose macro every press of the fight runs. Nobody's debuffs
-- are read there either.
do
	local scenario = "cures: nothing is offered or read in a fight"
	with(scenario, {}, function(ns, world)
		world.debuffs.party1 = { debuff("Poison", 60) }
		if not (queue(ns)[filed(GWEN)] or {}).cure then
			fail(scenario, "SKIPPED -- out of a fight the poison is not offered a cure")
			return
		end
		world.reads.n = 0
		Mock.inCombat = true
		local entry = queue(ns)[filed(GWEN)]
		Mock.inCombat = false
		if entry and entry.cure then fail(scenario, "a cure was offered in a fight") end
		if world.reads.n ~= 0 then fail(scenario, "harmful auras were read in a fight") end
		-- The pull's own repaint: no lockdown yet, and the macro it arms stays.
		ns.Prompt.armedForFight = true
		entry = queue(ns)[filed(GWEN)]
		ns.Prompt.armedForFight = false
		if entry and entry.cure then fail(scenario, "a cure was armed for the fight at the pull") end
		local said
		Mock.inCombat = true
		said = debugSays(ns)
		Mock.inCombat = false
		if not said:find("none is offered in a fight", 1, true) then
			fail(scenario, "/manners debug does not say cures wait for the fight to end: " .. flat(said))
		end
	end)
end

-- --------------------------------------------------------------- cures 11
-- Passers-by have a switch of their own: with only the group's on, a passer-by
-- is neither offered nor read; with only theirs on, a group member is not.
do
	local scenario = "cures: passers-by have a switch of their own"
	local names = { party1 = GWEN, nameplate1 = { "Nell", "Nash" } }
	with(scenario, { names = names, group = 2 }, function(ns, world)
		local sources = ns.db.profile.sources
		world.debuffs.party1 = { debuff("Poison", 60) }
		world.debuffs.nameplate1 = { debuff("Curse", 60) }
		local nell = filed(names.nameplate1)
		local byName = queue(ns)
		if not (byName[filed(GWEN)] or {}).cure then
			fail(scenario, "SKIPPED -- the group member is not offered a cure with the group's switch on")
		end
		if byName[nell] then fail(scenario, "a passer-by was offered a cure with only the group's switch on") end
		if world.reads.nameplate1 then
			fail(scenario, "a passer-by's debuffs were read with only the group's switch on")
		end
		sources.cures, sources.curesStrangers = false, true
		world.reads.party1 = nil
		byName = queue(ns)
		local entry = byName[nell]
		if not (entry and entry.cure == "Curse") then
			fail(scenario, "a cursed passer-by is not offered a cure with the passers-by switch on")
		elseif entry.reason ~= "nearby" or entry.inGroup ~= false then
			fail(scenario, ("the passer-by's entry reads reason=%s inGroup=%s"):format(tostring(entry.reason),
				tostring(entry.inGroup)))
		end
		if byName[filed(GWEN)] then
			fail(scenario, "a group member was offered a cure with only the passers-by switch on")
		end
		if world.reads.party1 then
			fail(scenario, "a group member's debuffs were read with only the passers-by switch on")
		end
	end)
end

-- --------------------------------------------------------------- cures 12
-- The cure switches stand apart from the buff switches beside them: with "My
-- party and raid" off a poisoned member is still cured, and one with nothing
-- to cure is turned away as that switch always turned them away; the same for
-- passers-by.
do
	local scenario = "cures: the cure switches stand apart from the buff switches"
	local names = { party1 = GWEN, party2 = HUGO, nameplate1 = { "Nell", "Nash" }, nameplate2 = { "Otto", "Orr" } }
	with(scenario, { names = names, bare = true }, function(ns, world)
		local sources = ns.db.profile.sources
		local nell, otto = filed(names.nameplate1), filed(names.nameplate2)
		sources.group, sources.strangers = true, true
		sources.cures, sources.curesStrangers = true, true
		local byName = queue(ns)
		if not (byName[filed(HUGO)] and byName[otto]) then
			fail(scenario, "SKIPPED -- with the buff switches on, a member and a passer-by missing your buff are not offered it")
			return
		end
		sources.group, sources.strangers = false, false
		world.debuffs.party1 = { debuff("Poison", 60) }
		world.debuffs.nameplate1 = { debuff("Curse", 60) }
		local list, verdicts
		Mock.advance(4)
		list, verdicts = ns.BuildQueue()
		byName = {}
		for _, entry in ipairs(list) do byName[entry.name] = entry end
		if not (byName[filed(GWEN)] or {}).cure then
			fail(scenario, "with My party and raid off, a poisoned member is not offered a cure")
		end
		if not (byName[nell] or {}).cure then
			fail(scenario, "with Passers-by off, a cursed passer-by is not offered a cure")
		end
		if byName[filed(HUGO)] then
			fail(scenario, "with My party and raid off, a member with nothing to cure was offered "
				.. tostring(byName[filed(HUGO)].buff.key))
		elseif type(verdicts) ~= "table" or verdicts[filed(HUGO)] ~= true then
			fail(scenario, "the group switch wrote no verdict on a member with nothing to cure")
		end
		if byName[otto] then
			fail(scenario, "with Passers-by off, a passer-by with nothing to cure was offered "
				.. tostring(byName[otto].buff.key))
		end
	end)
end

-- --------------------------------------------------------------- cures 13
-- A class with a cure and no buff for anybody else still has a prompt and a
-- walk: a shaman on Forever, who knows Cure Poison and nothing more.
do
	local scenario = "cures: a class with a cure and no buff for others still walks"
	with(scenario, { class = "SHAMAN", known = { 526 } }, function(ns, world)
		world.debuffs.party1 = { debuff("Poison", 60) }
		if ns.caps.hasClassBuffs or #ns.CastableBuffs() ~= 0 then
			fail(scenario, "SKIPPED -- the shaman has a buff for somebody else in hand")
			return
		end
		local entry = queue(ns)[filed(GWEN)]
		if not (entry and entry.cure == "Poison") then
			fail(scenario, "a shaman with Cure Poison and no buff for others offers a poisoned member nothing")
			return
		end
		if not ns.CanCastAnything() then fail(scenario, "with a cure switched on there is still no prompt") end
		ns.db.profile.sources.cures = false
		if ns.CanCastAnything() then
			fail(scenario, "SKIPPED -- the shaman has something to cast with the cure switched off")
		end
	end)
end

-- --------------------------------------------------------------- cures 14
-- A press on a cure is settled as one: the press says it was a cure, no favour
-- is returned by it whatever they are owed, and the cure is not offered again
-- the moment after, while the debuff still reads.
do
	local scenario = "cures: a press settles as a cure, and is not offered again at once"
	with(scenario, {}, function(ns, world)
		world.debuffs.party1 = { debuff("Poison", 60) }
		-- Owed a favour, with "People who buff me" off: nothing returns it,
		-- and a cure must not.
		ns.db.profile.sources.owed = false
		H.owe(ns, filed(GWEN))
		local entry = queue(ns)[filed(GWEN)]
		if not (entry and entry.cure) then
			fail(scenario, "SKIPPED -- the poisoned member is not offered a cure")
			return
		end
		local button = ns.Prompt:GetButton()
		Mock.advance(1)
		macroFor(ns, entry)
		button.scripts.PostClick(button, "LeftButton", true)
		local pending = ns.pendingClick
		if not pending then
			fail(scenario, "SKIPPED -- the press parked nothing")
			return
		end
		if pending.cure ~= "Poison" then
			fail(scenario, "the press does not say it was a cure: " .. tostring(pending.cure))
		end
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, nil, CURE_POISON)
		if ns.pendingClick then fail(scenario, "SKIPPED -- the cast did not settle the press") end
		if not ns.owed[filed(GWEN)] then
			fail(scenario, "a cure returned the favour they were owed")
		end
		-- The poison still reads (the client is a moment behind): no second offer.
		local again = ns.BuildQueue()
		for _, e in ipairs(again) do
			if e.name == filed(GWEN) and e.cure then fail(scenario, "the cure was offered again at once") end
		end
	end)
end

-- --------------------------------------------------------------- cures 15
-- Nothing is said over a cure: every line is about a buff given.
do
	local scenario = "cures: nothing is said over a cure"
	with(scenario, { bare = true }, function(ns, world)
		local speech = ns.db.profile.speech
		speech.enabled, speech.onlyWhenReturning, speech.channel = true, false, "SAY"
		speech.phrases = "Here you are, {name}."
		world.debuffs.party2 = { debuff("Poison", 60) }
		local byName = queue(ns)
		local gwen, hugo = byName[filed(GWEN)], byName[filed(HUGO)]
		if not (gwen and hugo and hugo.cure and not gwen.cure) then
			fail(scenario, "SKIPPED -- one member is not offered a buff and the other a cure")
			return
		end
		if not ns.PickPhrase(gwen, 200) then
			fail(scenario, "SKIPPED -- nobody would be spoken to with these settings")
			return
		end
		local line = ns.PickPhrase(hugo, 200)
		if line then fail(scenario, "a line was picked for a cure: " .. tostring(line)) end
		local ran = macroFor(ns, hugo)
		if type(ran) ~= "string" or ran:find("Here you are", 1, true) then
			fail(scenario, "the macro for a cure reads " .. flat(ran))
		end
	end)
end

-- --------------------------------------------------------------- cures 16
-- The reason line says what they are under, each kind in its own words, and
-- the tooltip names the debuff. A paladin's Cleanse for three of them, a
-- druid's Remove Curse for the fourth.
do
	local scenario = "cures: the reason line and the tooltip say what they are under"
	local WORDS = { Poison = "Poisoned", Disease = "Diseased", Magic = "Under a spell", Curse = "Cursed" }
	local function check(ns, world, kind)
		world.debuffs.party1 = { debuff(kind, 60, nil, nil, "Nasty " .. kind) }
		local entry = queue(ns)[filed(GWEN)]
		if not (entry and entry.cure == kind) then
			fail(scenario, "SKIPPED -- no cure is offered for " .. kind)
			return
		end
		local line = ns.Prompt:ReasonText(entry)
		if line ~= WORDS[kind] then
			fail(scenario, ("the reason line for %s reads %q, not %q"):format(kind, tostring(line), WORDS[kind]))
		end
		local button = ns.Prompt:GetButton()
		macroFor(ns, entry)
		ns.db.profile.prompt.tooltip = "full"
		Mock.tooltip = {}
		if button.scripts.OnEnter then button.scripts.OnEnter(button) end
		local tip = table.concat(Mock.tooltip or {}, " / ")
		if not (tip:find(WORDS[kind], 1, true) and tip:find("Nasty " .. kind, 1, true)) then
			fail(scenario, ("the tooltip for %s does not say %q and the debuff's name: %s"):format(kind, WORDS[kind], tip))
		end
		if tip:find("missing it", 1, true) then
			fail(scenario, "the tooltip for a cure speaks of a buff they are missing: " .. tip)
		end
	end
	with(scenario, { class = "PALADIN", known = { 4987 }, bare = true }, function(ns, world)
		for _, kind in ipairs({ "Poison", "Disease", "Magic" }) do check(ns, world, kind) end
	end)
	with(scenario, {}, function(ns, world) check(ns, world, "Curse") end)
end

-- --------------------------------------------------------------- cures 17
-- A cure cooling down, or one there is no mana for, is not offered, and
-- /manners debug says which. A Mists mage's Remove Curse: eight seconds.
do
	local scenario = "cures: a cure cooling down or unpaid for is not offered"
	with(scenario, { flavour = "mists", class = "MAGE", known = { 475, 1459 } }, function(ns, world)
		world.debuffs.party1 = { debuff("Curse", 60, nil, nil, "Old Hex") }
		if not (queue(ns)[filed(GWEN)] or {}).cure then
			fail(scenario, "SKIPPED -- a Mists mage is not offered Remove Curse for a curse")
			return
		end
		Mock.spellCooldowns = { [475] = 8 }
		if (queue(ns)[filed(GWEN)] or {}).cure then
			fail(scenario, "Remove Curse was offered eight seconds into its own cooldown")
		end
		local said = debugSays(ns)
		if not (said:find("Old Hex", 1, true) and said:find("cooling down", 1, true)) then
			fail(scenario, "/manners debug does not say the cure is cooling down: " .. flat(said))
		end
		-- The global cooldown is the press's to wait out, not a reason to hide it.
		Mock.spellCooldowns = { [475] = 1.5 }
		if not (queue(ns)[filed(GWEN)] or {}).cure then
			fail(scenario, "Remove Curse was held back for a global cooldown")
		end
		Mock.spellCooldowns = nil
		rawset(_G, "IsUsableSpell", function(id)
			if id == 475 then return false, true end
			return true, false
		end)
		if (queue(ns)[filed(GWEN)] or {}).cure then
			fail(scenario, "Remove Curse was offered with no mana for it")
		end
		said = debugSays(ns)
		if not said:find("not enough mana", 1, true) then
			fail(scenario, "/manners debug does not say there is no mana for the cure: " .. flat(said))
		end
	end)
end

-- --------------------------------------------------------------- cures 18
-- A passer-by found by the cursor stays offered once it leaves them for the
-- prompt, by name and with no token, for ten seconds and no longer.
do
	local scenario = "cures: a passer-by under the cursor stays offered once it leaves them"
	local names = { party1 = GWEN }
	with(scenario, { names = names, group = 2 }, function(ns, world)
		local sources = ns.db.profile.sources
		sources.curesStrangers = true
		world.names.mouseover = { "Nell", "Nash" }
		world.debuffs.mouseover = { debuff("Curse", 300) }
		local nell = filed(world.names.mouseover)
		Mock.advance(4)
		local first
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.name == nell then first = entry end
		end
		if not (first and first.cure == "Curse" and first.unit == "mouseover") then
			fail(scenario, "SKIPPED -- the passer-by under the cursor is not offered a cure")
			return
		end
		world.names.mouseover = nil
		world.debuffs.mouseover = nil
		Mock.advance(3)
		local later, count = nil, 0
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.name == nell then later, count = entry, count + 1 end
		end
		if count ~= 1 then
			fail(scenario, "three seconds after the cursor left them the passer-by has " .. count .. " entries")
		elseif later.cure ~= "Curse" or later.unit ~= nil or later.reason ~= "nearby" then
			fail(scenario, ("remembered, the entry reads cure=%s unit=%s reason=%s"):format(tostring(later.cure),
				tostring(later.unit), tostring(later.reason)))
		else
			local ran = macroFor(ns, later)
			if type(ran) ~= "string" or not ran:find("/target " .. nell, 1, true) then
				fail(scenario, "the remembered passer-by's macro reads " .. flat(ran))
			end
		end
		Mock.advance(8)
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.name == nell then fail(scenario, "the passer-by is still offered eleven seconds on") end
		end
		-- Found again, and the switch off lets them go at once.
		world.names.mouseover = { "Nell", "Nash" }
		world.debuffs.mouseover = { debuff("Curse", 300) }
		Mock.advance(4)
		ns.BuildQueue()
		world.names.mouseover = nil
		world.debuffs.mouseover = nil
		Mock.advance(1)
		local again = false
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.name == nell and entry.cure then again = true end
		end
		if not again then fail(scenario, "SKIPPED -- found again, the passer-by is not remembered again") end
		sources.curesStrangers = false
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.name == nell then fail(scenario, "the passer-by stayed offered with the switch off") end
		end
	end)
end

-- --------------------------------------------------------------- cures 19
-- A reading is kept three seconds a person, as the buff read keeps its own,
-- and forgotten when the client says their auras changed.
do
	local scenario = "cures: a reading is kept three seconds and forgotten at UNIT_AURA"
	with(scenario, {}, function(ns, world)
		Mock.advance(4)
		ns.BuildQueue()
		local first = world.reads.party1 or 0
		if first == 0 then
			fail(scenario, "SKIPPED -- the group member's debuffs were not read at all")
			return
		end
		Mock.advance(0.4)
		ns.BuildQueue()
		Mock.advance(0.4)
		ns.BuildQueue()
		if world.reads.party1 ~= first then
			fail(scenario, ("the same person was read again within the three seconds: %d reads, then %d")
				:format(first, world.reads.party1))
		end
		ns.addon:UNIT_AURA("UNIT_AURA", "party1")
		Mock.advance(0.4)
		ns.BuildQueue()
		local after = world.reads.party1
		if after == first then fail(scenario, "UNIT_AURA for them did not have their debuffs read again") end
		if (world.reads.party2 or 0) ~= first then
			fail(scenario, "UNIT_AURA for one person had another read again")
		end
		Mock.advance(3.5)
		ns.BuildQueue()
		if world.reads.party1 == after then fail(scenario, "a reading was still trusted past three seconds") end
	end)
end

-- --------------------------------------------------------------- cures 20
-- A kind a spell removes only with a passive is offered only with it: Mists'
-- Cleanse and magic (Sacred Cleansing), retail's Purify and a disease
-- (Improved Purify).
do
	local scenario = "cures: mists: Cleanse lifts magic only with Sacred Cleansing"
	with(scenario, { flavour = "mists", class = "PALADIN", known = { 4987 } }, function(ns, world)
		world.debuffs.party1 = { debuff("Poison", 60) }
		if not (queue(ns)[filed(GWEN)] or {}).cure then
			fail(scenario, "SKIPPED -- a Mists paladin is not offered Cleanse for a poison")
			return
		end
		world.debuffs.party1 = { debuff("Magic", 60) }
		if queue(ns)[filed(GWEN)] then
			fail(scenario, "Cleanse was offered for magic without Sacred Cleansing")
		end
		world.known[53551] = true
		ns.Guard("probe", ns.ProbeCapabilities)
		if (queue(ns)[filed(GWEN)] or {}).cure ~= "Magic" then
			fail(scenario, "Cleanse was not offered for magic with Sacred Cleansing")
		end
	end)
end

do
	local scenario = "cures: mainline: Purify lifts a disease only with Improved Purify"
	with(scenario, { flavour = "mainline", class = "PRIEST", known = { 527 } }, function(ns, world)
		world.debuffs.party1 = { debuff("Magic", 60) }
		if not (queue(ns)[filed(GWEN)] or {}).cure then
			fail(scenario, "SKIPPED -- a retail priest is not offered Purify for magic")
			return
		end
		world.debuffs.party1 = { debuff("Disease", 60) }
		if (queue(ns)[filed(GWEN)] or {}).cure then
			fail(scenario, "Purify was offered for a disease without Improved Purify")
		end
		world.known[390632] = true
		ns.Guard("probe", ns.ProbeCapabilities)
		if (queue(ns)[filed(GWEN)] or {}).cure ~= "Disease" then
			fail(scenario, "Purify was not offered for a disease with Improved Purify")
		end
	end)
end

-- --------------------------------------------------------------- cures 21
-- /manners debug says what this character cures with what, or that the
-- switches are off, and nothing at all for a class with no cure.
do
	local scenario = "cures: /manners debug says what you cure, or that it is switched off"
	with(scenario, { keep = true }, function(ns)
		local said = debugSays(ns)
		if not said:find("cures: switched off.", 1, true) then
			fail(scenario, "with the switches off /manners debug does not say so: " .. flat(said))
		end
		ns.db.profile.sources.cures = true
		said = debugSays(ns)
		if not (said:find("cures: ", 1, true) and said:find("(Curse)", 1, true) and said:find("(Poison)", 1, true)) then
			fail(scenario, "/manners debug does not list a druid's cures by kind: " .. flat(said))
		end
	end)
	with(scenario, { class = "WARRIOR", known = { 6673 }, keep = true }, function(ns)
		local said = debugSays(ns)
		if said:find("cures:", 1, true) then
			fail(scenario, "/manners debug speaks of cures to a warrior: " .. flat(said))
		end
	end)
end

-- --------------------------------------------------------------- cures 22
-- The controls: a heading of their own on Who to buff with the two switches
-- and the seconds, shown only for a class with a cure on this client (a
-- shaman with no buff for others among them), each writing its setting, the
-- seconds greyed with both switches off; the window places every one, and the
-- page's reset reaches them.
do
	local scenario = "cures: the switches are on Who to buff, for a class with a cure"
	local KEYS = { "curesHeader", "curesNote", "cures", "curesStrangers", "curesSelf", "cureSeconds" }
	with(scenario, { keep = true }, function(ns)
		local sources, filters = ns.db.profile.sources, ns.db.profile.filters
		local options = {}
		for _, key in ipairs(KEYS) do
			options[key] = H.findOption(ns.optionsTable, key)
			if not options[key] then
				fail(scenario, "no " .. key .. " control in the options")
				return
			end
			if type(options[key].hidden) ~= "function" or options[key].hidden() then
				fail(scenario, key .. " is hidden from a druid")
			end
		end
		if options.cures.type ~= "toggle" or H.optionText(options.cures.name) ~= "Cure my party and raid" then
			fail(scenario, "the group's switch is a " .. tostring(options.cures.type) .. " called "
				.. H.optionText(options.cures.name))
		end
		if options.curesStrangers.type ~= "toggle" or H.optionText(options.curesStrangers.name) ~= "Cure passers-by" then
			fail(scenario, "the passers-by switch is called " .. H.optionText(options.curesStrangers.name))
		end
		options.cures.set({ "who", "cures" }, true)
		if sources.cures ~= true or options.cures.get({ "who", "cures" }) ~= true then
			fail(scenario, "ticking the group's switch does not write sources.cures")
		end
		options.cures.set({ "who", "cures" }, false)
		options.curesStrangers.set({ "who", "curesStrangers" }, true)
		if sources.curesStrangers ~= true or sources.cures ~= false then
			fail(scenario, "ticking the passers-by switch does not write sources.curesStrangers alone")
		end
		if options.cureSeconds.disabled() then fail(scenario, "the seconds are greyed with a switch on") end
		options.curesStrangers.set({ "who", "curesStrangers" }, false)
		if not options.cureSeconds.disabled() then fail(scenario, "the seconds are not greyed with both switches off") end
		options.cureSeconds.set({ "who", "cureSeconds" }, 25)
		if filters.cureSeconds ~= 25 or options.cureSeconds.get({ "who", "cureSeconds" }) ~= 25 then
			fail(scenario, "the slider does not write filters.cureSeconds")
		end
		local note = H.optionText(options.curesNote.name)
		if not (note:find("(Curse)", 1, true) and note:find("(Poison)", 1, true)) then
			fail(scenario, "the note does not say what a druid cures: " .. note)
		end

		-- A damaged value is put right, and the page's reset reaches all three.
		for _, bad in ipairs({ "yes", 1, {} }) do
			sources.cures, sources.curesStrangers = bad, bad
			ns.ClampSettings()
			if sources.cures ~= false or sources.curesStrangers ~= false then
				fail(scenario, "a " .. type(bad) .. " left in the file is not repaired to off")
			end
		end
		filters.cureSeconds = 999
		ns.ClampSettings()
		if filters.cureSeconds ~= 120 then
			fail(scenario, "999 seconds is repaired to " .. tostring(filters.cureSeconds))
		end
		filters.cureSeconds = "soon"
		ns.ClampSettings()
		if filters.cureSeconds ~= 10 then
			fail(scenario, "a word for the seconds is repaired to " .. tostring(filters.cureSeconds))
		end
		local reset = {}
		for _, path in ipairs(ns.OptionsPage.RESET.who or {}) do reset[path] = true end
		for _, path in ipairs({ "sources.cures", "sources.curesStrangers", "filters.cureSeconds" }) do
			if not reset[path] then fail(scenario, "Who to buff's reset does not reach " .. path) end
		end

		if not H.layoutInToc() then return end
		for _, key in ipairs(KEYS) do
			if key ~= "curesHeader" and not H.placedOn(ns, "who." .. key) then
				fail(scenario, "the window places who." .. key .. " on no page")
			end
		end
	end)
	-- A warrior has no cure on any client: nothing of it is shown.
	with(scenario, { class = "WARRIOR", known = { 6673 }, keep = true }, function(ns)
		for _, key in ipairs(KEYS) do
			local option = H.findOption(ns.optionsTable, key)
			if option and not (type(option.hidden) == "function" and option.hidden()) then
				fail(scenario, key .. " is shown to a warrior")
			end
		end
	end)
	-- A shaman on Forever has no buff for anybody else, so everything about
	-- other people is off the page for one (ForOthersOnly), and still has them.
	with(scenario, { class = "SHAMAN", known = { 526 }, keep = true }, function(ns)
		local group = H.findOption(ns.optionsTable, "group")
		if not (group and type(group.hidden) == "function" and group.hidden()) then
			fail(scenario, "SKIPPED -- My party and raid is not hidden from a shaman with nothing for others")
		end
		for _, key in ipairs(KEYS) do
			local option = H.findOption(ns.optionsTable, key)
			if not option or (type(option.hidden) == "function" and option.hidden()) then
				fail(scenario, key .. " is hidden from a shaman with nothing else for others")
			end
		end
		local note = H.optionText(H.findOption(ns.optionsTable, "curesNote").name)
		if not note:find("(Poison)", 1, true) then
			fail(scenario, "the note does not say what a shaman cures: " .. note)
		end
	end)
end

-- --------------------------------------------------------------- cures 23
-- The bug report, which the full check-up opens with, says how the switches
-- and the seconds are set.
do
	local scenario = "cures: the bug report says how the switches are set"
	with(scenario, { keep = true }, function(ns)
		local report = H.findOption(ns.optionsTable, "report")
		if not (report and report.get) then
			fail(scenario, "SKIPPED -- no bug report on the options page")
			return
		end
		if not tostring(report.get()):find("cures group/passers-by/seconds=false/false/10", 1, true) then
			fail(scenario, "the report does not say the switches are off: " .. flat(report.get()))
		end
		ns.db.profile.sources.curesStrangers = true
		ns.db.profile.filters.cureSeconds = 20
		if not tostring(report.get()):find("cures group/passers-by/seconds=false/true/20", 1, true) then
			fail(scenario, "the report does not follow the settings: " .. flat(report.get()))
		end
	end)
end

-- --------------------------------------------------------------- cures 24
-- Every spell and passive in the tables is one the client names: an id it has
-- never heard of would offer nothing and say nothing. On each client, for
-- every class with a cure there, the cures probe with a name and a rank once
-- every id is known.
do
	local scenario = "cures: every class with a cure on a client is offered one there"
	local CLASSES = {
		camelot = { DRUID = { 8946, 2893, 2782 }, MAGE = { 475 }, PALADIN = { 4987, 1152 },
			PRIEST = { 528, 552, 988, 527 }, SHAMAN = { 526, 2870 } },
		mists = { MAGE = { 475 }, PRIEST = { 527 }, DRUID = { 88423, 2782 }, PALADIN = { 4987 },
			SHAMAN = { 77130, 51886 }, MONK = { 115450 } },
		mainline = { MAGE = { 475 }, PRIEST = { 527, 213634 }, DRUID = { 88423, 2782 }, PALADIN = { 4987, 213644 },
			SHAMAN = { 77130, 51886 }, MONK = { 115450, 218164 }, EVOKER = { 360823, 365585 } },
	}
	CLASSES.vanilla, CLASSES.tbc = CLASSES.camelot, CLASSES.camelot
	for _, flavour in ipairs({ "camelot", "vanilla", "tbc", "mists", "mainline" }) do
		for class, ids in pairs(CLASSES[flavour]) do
			with(scenario, { flavour = flavour, class = class, known = ids, keep = true }, function(ns)
				if not ns.ClassHasCures() then
					fail(scenario, ("%s: a %s has no cure"):format(flavour, class))
					return
				end
				ns.db.profile.sources.cures = true
				if not ns.CuresWanted() then
					fail(scenario, ("%s: a %s who knows every cure has none to offer"):format(flavour, class))
				end
				local summary = ns.CureSummary()
				if type(summary) ~= "string" or not summary:find("(", 1, true) then
					fail(scenario, ("%s: a %s's cures read %s"):format(flavour, class, tostring(summary)))
				end
			end)
		end
		-- And a class with none there has none: a warrior everywhere.
		with(scenario, { flavour = flavour, class = "WARRIOR", known = { 6673 }, keep = true }, function(ns)
			if ns.ClassHasCures() then fail(scenario, flavour .. ": a warrior has a cure") end
			ns.db.profile.sources.cures = true
			if ns.CuresWanted() then fail(scenario, flavour .. ": a warrior has a cure to offer") end
		end)
	end
end

-- --------------------------------------------------------------- cures 25
-- The full check-up is pasted in public: somebody /manners debug names as left
-- alone is in it under an alias, like everybody else it names.
do
	local scenario = "cures: the full check-up does not name somebody left alone"
	with(scenario, {}, function(ns, world)
		world.debuffs.party1 = { debuff("Poison", 4, nil, nil, "Slow Venom") }
		Mock.advance(4)
		local said = debugSays(ns)
		Mock.printed = {}
		if not said:match("Gwen[^\n]*Slow Venom") then
			fail(scenario, "SKIPPED -- /manners debug does not name who was left alone: " .. flat(said):sub(-300))
			return
		end
		if type(ns.FullReport) ~= "function" then
			fail(scenario, "SKIPPED -- no full check-up")
			return
		end
		local text = ns.FullReport()
		if not text:find("Slow Venom", 1, true) then
			fail(scenario, "SKIPPED -- the check-up has no line about the poison left alone")
		end
		local line = text:match("[^\n]*Gwen[^\n]*Slow Venom[^\n]*")
		if line then fail(scenario, "the check-up, pasted in public, names Gwen in clear: " .. tostring(line)) end
	end)
end
