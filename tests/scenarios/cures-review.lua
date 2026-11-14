-- The review of cures (Cures.lua and its hooks in Queue.lua, Prompt/Press.lua
-- and Clicks.lua): nothing is offered that would lift a debuff never removed,
-- a passer-by read with nothing to cure is let go by the memory and by the
-- prompt's hold, and a press on a cure leaves the buff rotation where it
-- stood. The session is cures.lua's.
--
-- Every scenario name starts with "cures-review:" so the mutations in
-- tests/mutations/cures-review.py can name the one that has to catch them.

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

-- A paladin on Burning Crusade: Cleanse (poison, disease and magic in one
-- cast) and Purify (poison and disease).
local CLEANSE, PURIFY = 4987, 1152
-- Unstable Affliction there, on the deny list: whoever dispels it is hurt and
-- silenced.
local AFFLICTION = 30108

-- --------------------------------------------------------- cures-review 1
-- A debuff never removed is more than left out. A cure takes one debuff of
-- each kind its spell removes off, and the spell picks which: Cleanse for a
-- poison beside Unstable Affliction lifts the Affliction too. So the poison
-- goes to a spell that leaves magic alone (Purify), and with none, or with a
-- second harmful spell beside the Affliction, nothing is offered at all.
do
	local scenario = "cures-review: nothing that would lift a debuff never removed is offered beside it"
	with(scenario, { flavour = "tbc", class = "PALADIN", known = { CLEANSE, PURIFY } }, function(ns, world)
		world.debuffs.party1 = { debuff("Poison", 60) }
		local entry = queue(ns)[filed(GWEN)]
		local info = entry and ns.BuffInfo(entry.buff)
		if not (entry and entry.cure == "Poison" and info and info.topRank == CLEANSE) then
			fail(scenario, "SKIPPED -- a poison alone is not offered Cleanse: " .. tostring(info and info.topRank))
			return
		end
		-- Beside the Affliction: the poison by Purify, which lifts no magic.
		world.debuffs.party1 = {
			debuff("Magic", 60, AFFLICTION, nil, "Unstable Affliction"),
			debuff("Poison", 60),
		}
		entry = queue(ns)[filed(GWEN)]
		info = entry and ns.BuffInfo(entry.buff)
		if not entry then
			fail(scenario, "a poison beside Unstable Affliction is offered nothing, with Purify known")
		elseif entry.cure ~= "Poison" or not info or info.topRank ~= PURIFY then
			fail(scenario, ("beside Unstable Affliction the offer is %s by spell %s, not the poison by Purify")
				:format(tostring(entry.cure), tostring(info and info.topRank)))
		else
			local ran = macroFor(ns, entry)
			if type(ran) ~= "string" or not ran:find("/cast", 1, true) then
				fail(scenario, "the press for Purify reads " .. flat(ran))
			end
		end
		-- A second harmful spell beside it: whatever lifts magic may lift the
		-- Affliction, so nothing.
		world.debuffs.party1 = {
			debuff("Magic", 60, AFFLICTION, nil, "Unstable Affliction"),
			debuff("Magic", 60, 172, nil, "Corruption"),
		}
		entry = queue(ns)[filed(GWEN)]
		if entry then
			fail(scenario, "a second harmful spell beside Unstable Affliction was offered " .. tostring(entry.buff.key))
		end
		-- And with Cleanse alone, nothing for the poison either.
		world.known[PURIFY] = nil
		ns.Guard("probe", ns.ProbeCapabilities)
		world.debuffs.party1 = {
			debuff("Poison", 60),
			debuff("Magic", 60, AFFLICTION, nil, "Unstable Affliction"),
		}
		entry = queue(ns)[filed(GWEN)]
		if entry then
			info = ns.BuffInfo(entry.buff)
			fail(scenario, ("with Cleanse alone a poison beside Unstable Affliction was offered spell %s")
				:format(tostring(info and info.topRank)))
		end
		if not debugSays(ns):find("never removes", 1, true) then
			fail(scenario, "/manners debug does not say why they were left alone: " .. flat(debugSays(ns)))
		end
		-- The Affliction gone, Cleanse is back for the poison.
		world.debuffs.party1 = { debuff("Poison", 60) }
		if not (queue(ns)[filed(GWEN)] or {}).cure then
			fail(scenario, "the poison is not offered once Unstable Affliction is gone")
		end
	end)
end

-- --------------------------------------------------------- cures-review 2
-- A passer-by remembered for a cure is let go the moment a token reads them
-- with nothing to cure, with Cure passers-by on and the buff switch for
-- passers-by off: no entry from the memory, and a verdict for the prompt's
-- hold.
do
	local scenario = "cures-review: a passer-by read clean is not offered the cure from memory"
	local names = { party1 = GWEN, nameplate1 = { "Nell", "Nash" } }
	with(scenario, { names = names, group = 2 }, function(ns, world)
		local sources = ns.db.profile.sources
		sources.cures, sources.curesStrangers, sources.strangers = false, true, false
		world.debuffs.nameplate1 = { debuff("Curse", 300) }
		local nell = filed(names.nameplate1)
		local entry = queue(ns)[nell]
		if not (entry and entry.cure == "Curse") then
			fail(scenario, "SKIPPED -- the cursed passer-by is not offered a cure")
			return
		end
		-- Somebody else lifts the curse; their nameplate is still there.
		world.debuffs.nameplate1 = nil
		Mock.advance(4)
		local list, rejected = ns.BuildQueue()
		for _, e in ipairs(list) do
			if e.name == nell then
				fail(scenario, "read clean through their nameplate, the passer-by is still offered " .. tostring(e.buff.key))
			end
		end
		if type(rejected) ~= "table" then
			fail(scenario, "SKIPPED -- BuildQueue hands back no verdicts")
		elseif rejected[nell] ~= true then
			fail(scenario, "read clean, the passer-by has no verdict for the prompt's hold: " .. tostring(rejected[nell]))
		end
	end)
end

-- The same end by the reading itself, whatever the walk goes on to do with
-- them: the hook answering "nothing to cure" for somebody ends their memory.
do
	local scenario = "cures-review: a reading with nothing to cure ends the memory of a passer-by"
	local names = { party1 = GWEN, nameplate1 = { "Nell", "Nash" } }
	with(scenario, { names = names, group = 2 }, function(ns, world)
		local sources = ns.db.profile.sources
		sources.cures, sources.curesStrangers, sources.strangers = false, true, false
		world.debuffs.nameplate1 = { debuff("Curse", 300) }
		local nell = filed(names.nameplate1)
		if not (queue(ns)[nell] or {}).cure then
			fail(scenario, "SKIPPED -- the cursed passer-by is not offered a cure")
			return
		end
		world.debuffs.nameplate1 = nil
		Mock.advance(4)
		if not ns.CureScan(ns.db.profile, GetTime()) then
			fail(scenario, "SKIPPED -- no scan for cures")
			return
		end
		local answer = ns.CureFor("nameplate1", nell, ns.plain(UnitGUID("nameplate1")), false, false, nil)
		if answer then
			fail(scenario, "SKIPPED -- the passer-by read clean is still offered a cure")
		else
			-- The memory is the addon's own: seen by what it does. Their
			-- nameplate gone, a passer-by still remembered would be offered
			-- by name for the rest of the ten seconds.
			world.names.nameplate1 = nil
			for _, e in ipairs(ns.BuildQueue()) do
				if e.name == nell then
					fail(scenario, "read with nothing to cure, the passer-by is still remembered for one")
				end
			end
		end
	end)
end

-- --------------------------------------------------------- cures-review 3
-- A press on a cure leaves the buff rotation where it stood: ns.lastGave is
-- where the walk had got to among your buffs for somebody whose auras cannot
-- be read, and a cure is none of them. Neither the press nor its settle
-- writes the cure's key there.
do
	local scenario = "cures-review: a cure pressed leaves the buff rotation where it stood"
	with(scenario, {}, function(ns, world)
		world.debuffs.party1 = { debuff("Poison", 60) }
		local gwen = filed(GWEN)
		local entry = queue(ns)[gwen]
		if not (entry and entry.cure) then
			fail(scenario, "SKIPPED -- the poisoned member is not offered a cure")
			return
		end
		if not ns.RotatesBuffs() then
			fail(scenario, "SKIPPED -- a druid's buffs are not rotated")
			return
		end
		ns.lastGave[gwen] = "motw"
		local button = ns.Prompt:GetButton()
		Mock.advance(1)
		macroFor(ns, entry)
		button.scripts.PostClick(button, "LeftButton", true)
		if not (ns.pendingClick and ns.pendingClick.cure) then
			fail(scenario, "SKIPPED -- the press parked no cure")
			return
		end
		if ns.lastGave[gwen] ~= "motw" then
			fail(scenario, "the press on a cure moved the rotation to " .. tostring(ns.lastGave[gwen]))
		end
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, nil, CURE_POISON)
		if ns.pendingClick then
			fail(scenario, "SKIPPED -- the cast did not settle the press")
			return
		end
		if ns.lastGave[gwen] ~= "motw" then
			fail(scenario, "the settle of a cure moved the rotation to " .. tostring(ns.lastGave[gwen]))
		end
	end)
end
