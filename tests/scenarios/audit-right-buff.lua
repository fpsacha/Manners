-- The "right buff" audit. A player called the addon "a buggy mess": "very
-- frequently it retargets the same person when they are buffed and does not
-- notice party members that are unbuffed". Every scenario here is one finding
-- of the audit that followed, written red on the tree it was found on (branch
-- merge-fixes, 4ff8188) and green since its fix: each sets up a situation a
-- player meets, reads what Manners offers, and fails with what was offered and
-- what should have been. The mutations that undo each fix are in
-- tests/mutations/audit-right-buff.py.
--
-- The situations, as they were found:
--   1  a party member with nothing waits behind the first member's second and
--      third buffs (the queue is ordered by name inside a tier)
--   2  Shadow Protection is walked for everybody, you included, on a fresh profile
--   3  Unending Breath is offered on dry land to the group and to passers-by
--   4  Blessing of Might is offered to a mage on a fresh profile
--   5  a buff none of whose ranks can land on somebody that low is offered
--   6  a blessing the game said cannot land holds every other blessing off
--   7  WoW Forever: a raid-wide group cast counts only the members inside a
--      single cast's range
--   8  a group cast is aimed at a member too low for it, and its refusal holds
--      the single buff off the whole party
--   9  a warrior in a group with nobody in reach is never reminded of his shout
--  10  "buff pls" from a warrior is answered with Divine Spirit
--  11  a weaker group version from a lower-level caster covers a level 60
--  12  somebody whose buffs cannot be read is ranked ahead of somebody read as
--      missing the buff
--  13  your own top-up is ranked ahead of a party member with nothing
--  14  a favour returned by name alone casts the top rank at a giver too low
--      for it
--  15  WoW Forever: a camping buff worth more than your rank does not hold
--      your buff off (Boosted Stamina, Intellect, Spirit and the rest)
--
-- Every scenario name starts with "audit-right-buff:".

local dir, H = ...
local fail, load = H.fail, H.load

local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "UnitClass", "UnitLevel", "UnitPowerMax", "UnitInParty",
	"UnitIsDeadOrGhost", "GetItemCount", "GetItemInfo", "C_UnitAuras", "IsInInstance", "UnitIsVisible",
	"SPELL_FAILED_LOWLEVEL", "SPELL_FAILED_AURA_BOUNCED", "GetSpellSubtext" }

local NO_MANA = { WARRIOR = true, ROGUE = true }
local LOWLEVEL = "Target is too low level"
local BOUNCED = "A more powerful spell is already active"
local ARCANE_POWDER = 17020

-- One session as `env.class` on `env.client` (WoW Forever unless said), level
-- `env.level` (60), on a profile as a new player has it: nothing is switched
-- but what `env.setup(ns, db)` switches. env.units is everybody else, by token:
--   { name = { "Anna", "Aim" }, class = "WARRIOR", level = 60,
--     wears = { [spell id] = { left = seconds, source = token } }, unreadable = true }
-- A party token is in your party; any other token is a passer-by. env.wears is
-- what you wear yourself (nil: everything, as the shared mock has it).
-- env.knows lists the buff keys known, every rank up to your level;
-- env.groupKnown adds their group versions; env.bags is the item counts.
-- body(ns, db) runs with the lifecycle driven and the slate cleared.
local function session(scenario, env, body)
	Mock.reset()
	Mock.setFlavour(env.client or "camelot")
	Mock.class = env.class
	env.units = env.units or {}
	local names, party, plates = {}, 0, {}
	for token, unit in pairs(env.units) do
		names[token] = unit.name
		if token:find("^party") then party = party + 1 end
		if token:find("^nameplate") then plates[#plates + 1] = token end
	end
	Mock.groupSize = party > 0 and party + 1 or 0
	Mock.nameplates = plates
	-- The names the tokens answer to, for a scenario that takes a token away.
	env.names = names
	local restoreUnits = H.strangers(names)
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local known = {}
	local function isKnown(id) return known[id] == true end
	rawset(_G, "IsSpellKnown", isKnown)
	rawset(_G, "IsPlayerSpell", isKnown)
	rawset(_G, "IsInInstance", function() return false, "none" end)
	rawset(_G, "GetItemCount", function(id) return env.bags and env.bags[id] or 0 end)
	rawset(_G, "GetItemInfo", function() return "Reagent" end)
	rawset(_G, "SPELL_FAILED_LOWLEVEL", LOWLEVEL)
	rawset(_G, "SPELL_FAILED_AURA_BOUNCED", BOUNCED)
	-- Everybody here is within sight (a group spell's hundred yards).
	rawset(_G, "UnitIsVisible", function() return true end)
	rawset(_G, "UnitClass", function(unit)
		local u = env.units[unit]
		if u then return u.class, u.class end
		return saved.UnitClass(unit)
	end)
	rawset(_G, "UnitLevel", function(unit)
		if unit == "player" then return env.level or 60 end
		local u = env.units[unit]
		return u and (u.level or 60) or 60
	end)
	rawset(_G, "UnitPowerMax", function(unit, power)
		local u = env.units[unit]
		if u and NO_MANA[u.class] then return 0 end
		return saved.UnitPowerMax(unit, power)
	end)
	rawset(_G, "UnitInParty", function(unit)
		return type(unit) == "string" and unit:find("^party%d") ~= nil
	end)
	rawset(_G, "UnitIsDeadOrGhost", function(unit)
		local u = env.units[unit]
		if u then return u.dead == true end
		return saved.UnitIsDeadOrGhost(unit)
	end)
	local base = C_UnitAuras
	rawset(_G, "C_UnitAuras", setmetatable({
		GetUnitAuraBySpellID = function(unit, spellId)
			local u = env.units[unit]
			if unit == "player" then
				if env.wears == nil then return base.GetUnitAuraBySpellID(unit, spellId) end
				u = { wears = env.wears }
			end
			if u and u.unreadable then return Mock.SECRET end
			local worn = u and u.wears and u.wears[spellId]
			if not worn then return nil end
			return { spellId = spellId, expirationTime = Mock.now + (worn.left or 3000),
				-- worn.points: what the aura gives, where the client hands it over.
				points = worn.points,
				sourceUnit = worn.source or (unit == "player" and "player" or nil) }
		end,
	}, { __index = base }))

	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		local myLevel = env.level or 60
		for _, key in ipairs(env.knows or {}) do
			local buff = ns.FindBuff(env.class, key)
			if not buff then fail(scenario, "SKIPPED -- no " .. key .. " for a " .. env.class .. " on this client") end
			for _, id in ipairs(buff and buff.ranks or {}) do
				if (ns.RankLevel(id) or 1) <= myLevel then known[id] = true end
			end
			if env.groupKnown and buff then
				-- env.groupRanks: only these ranks of the group version, as a set.
				for _, rank in ipairs(buff.groupCast or {}) do
					if not env.groupRanks or env.groupRanks[rank.id] then known[rank.id] = true end
				end
			end
		end
		H.freshPrompt(ns, scenario)
		local db = ns.db.profile
		if env.setup then env.setup(ns, db) end
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.Prompt:ApplyTarget(nil)
		ns.Prompt:InvalidateMacro()
		ns.addon:Tick()
		body(ns, db)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	restoreUnits()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- The queue as the next scan builds it (the aura cache is three seconds deep),
-- in its order, and by the name each entry is filed under.
local function queued(ns)
	Mock.advance(4)
	local queue, byName = ns.BuildQueue(), {}
	for _, entry in ipairs(queue) do byName[entry.name] = entry end
	return queue, byName
end

-- One entry as words: "Anna Aim: fortitude (group, missing)".
local function words(entry)
	if not entry then return "nothing" end
	local reading = entry.known == false and "missing" or (entry.known == nil and "unread" or "worn")
	return ("%s: %s%s (%s, %s)"):format(tostring(entry.name), tostring(entry.buff and entry.buff.key),
		entry.groupCast and " as a group cast" or "", tostring(entry.reason), reading)
end

-- The whole queue as words, in its order.
local function listed(queue)
	local out = {}
	for i, entry in ipairs(queue) do out[i] = words(entry) end
	return #out > 0 and table.concat(out, "; ") or "nobody"
end

-- Who the prompt is on after a repaint.
local function shown(ns)
	ns.Prompt:Refresh()
	return ns.Prompt:Showing()
end

-- The top rank of one of the player's class's buffs.
local function top(ns, class, key)
	local buff = ns.FindBuff(class, key)
	return buff and buff.ranks[1]
end

-- `id` on the person behind `token`, read afresh at the next scan.
local function lands(ns, env, token, id, left, source)
	local unit = env.units[token]
	unit.wears = unit.wears or {}
	unit.wears[id] = { left = left or 3600, source = source }
	ns.ForgetUnitAuras(ns.plain(UnitGUID(token)))
end

-- ------------------------------------------------------------------------ 1
-- A priest in a party of four, nobody buffed, no Prayer of Fortitude. The
-- first press puts Fortitude on Anna. The prompt then stays on Anna for Divine
-- Spirit and Shadow Protection while Bert and Cora stand there with nothing:
-- the queue is sorted by name inside a tier (Queue.lua, the sort at the end of
-- BuildQueue) and the prompt keeps whoever it is on while they are in it
-- (Prompt/Hold.lua, PickTop). Somebody watching sees the same person
-- targeted again and again, buffed, and the unbuffed ones not noticed.
do
	local scenario = "audit-right-buff: a party member with nothing waits behind the first member's second and third buffs"
	local env = { class = "PRIEST", knows = { "fortitude", "spirit", "shadow" }, units = {
		party1 = { name = { "Anna", "Aim" }, class = "MAGE" },
		party2 = { name = { "Bert", "Beside" }, class = "WARRIOR" },
		party3 = { name = { "Cora", "Vell" }, class = "DRUID" },
	} }
	session(scenario, env, function(ns)
		local first = shown(ns)
		if not (first and first.name == "Anna Aim" and first.buff.key == "fortitude") then
			fail(scenario, "SKIPPED -- the prompt did not start on Anna's Fortitude: " .. words(first))
			return
		end
		-- The press lands: Anna wears your Fortitude, and the press's own retry
		-- cooldown is on it.
		lands(ns, env, "party1", top(ns, "PRIEST", "fortitude"), 3600, "player")
		ns.MarkAttempted("Anna Aim", "fortitude")
		local queue = queued(ns)
		local lead = queue[1]
		if lead and lead.buff.key ~= "fortitude" then
			fail(scenario, ("with Fortitude on Anna the queue leads with %s; Bert and Cora wear nothing and should be"
				.. " offered Power Word: Fortitude before anybody's second buff. The queue: %s")
				:format(words(lead), listed(queue)))
		end
		local now = shown(ns)
		if not (now and now.buff.key == "fortitude" and now.name ~= "Anna Aim") then
			fail(scenario, ("with Fortitude on Anna the prompt is on %s; it should be on Bert's or Cora's Fortitude")
				:format(words(now)))
		end
	end)
end

-- ------------------------------------------------------------------------ 2
-- A priest of 30 or more on a profile nobody has touched. Everybody wears
-- Fortitude and Divine Spirit. Shadow Protection, ten minutes long and of use
-- against shadow damage alone, is walked like the other two: on the priest,
-- on every party member and on every passer-by, and again every ten minutes
-- (Buffs.lua: `shadow` has no flag that holds it back, and Core.lua's defaults
-- switch nothing off). Detect Invisibility is `optIn` for the same reason.
do
	local scenario = "audit-right-buff: Shadow Protection is walked for everybody, you included, on a fresh profile"
	local fort, spirit = 10938, 27841
	local env = { class = "PRIEST", knows = { "fortitude", "spirit", "shadow" },
		wears = { [fort] = { left = 3000 }, [spirit] = { left = 3000 } }, units = {
		party1 = { name = { "Anna", "Aim" }, class = "MAGE",
			wears = { [fort] = { left = 3000 }, [spirit] = { left = 3000 } } },
		nameplate1 = { name = { "Pat", "Passer" }, class = "PRIEST",
			wears = { [fort] = { left = 3000 }, [spirit] = { left = 3000 } } },
	} }
	session(scenario, env, function(ns)
		local queue = queued(ns)
		local offered = {}
		for _, entry in ipairs(queue) do
			if entry.buff.key == "shadow" then offered[#offered + 1] = words(entry) end
		end
		if #offered > 0 then
			fail(scenario, ("everybody wears Fortitude and Divine Spirit, and a fresh profile offers Shadow Protection to %d of"
				.. " them (%s); a ten-minute resistance buff should be offered to nobody until the priest switches it on")
				:format(#offered, table.concat(offered, "; ")))
		end
		-- Switched on, on Who to buff, it is walked as it always was.
		ns.db.profile.buff.optIn.shadow = true
		queue = queued(ns)
		local on = 0
		for _, entry in ipairs(queue) do
			if entry.buff.key == "shadow" then on = on + 1 end
		end
		if on ~= 3 then
			fail(scenario, ("ticked on Who to buff, Shadow Protection is offered to %d of the three: %s"):format(on, listed(queue)))
		end
	end)
end

-- ------------------------------------------------------------------------ 3
-- A warlock on a fresh profile, on dry land. Unending Breath goes to every
-- party member and every passer-by, and comes back every ten minutes. Mists'
-- own set keeps it away from Automatic ("nobody standing in a city wants to be
-- handed water breathing", Buffs.lua), the warlock's own is offered only while
-- he swims, and the README says nobody needs it on dry land; Classic Era's,
-- Burning Crusade's and Forever's sets walk it for everybody.
do
	local scenario = "audit-right-buff: Unending Breath is offered on dry land to the group and to passers-by"
	local env = { class = "WARLOCK", knows = { "breath" }, units = {
		party1 = { name = { "Anna", "Aim" }, class = "MAGE" },
		nameplate1 = { name = { "Pat", "Passer" }, class = "PRIEST" },
	} }
	session(scenario, env, function(ns)
		local queue = queued(ns)
		local offered = {}
		for _, entry in ipairs(queue) do
			if entry.buff.key == "breath" and (entry.reason == "group" or entry.reason == "nearby") then
				offered[#offered + 1] = words(entry)
			end
		end
		if #offered > 0 then
			fail(scenario, ("on dry land, unasked, a fresh profile offers Unending Breath to %s; it should be kept for a"
				.. " favour returned and for whoever asks for it, as Mists' set already does"):format(table.concat(offered, "; ")))
		end
		-- A favour is still returned with it: it is all a warlock has to give,
		-- with a token on them and without one.
		H.owe(ns, "Pat Passer")
		local _, byName = queued(ns)
		local pat = byName["Pat Passer"]
		if not (pat and pat.reason == "owed" and pat.buff.key == "breath") then
			fail(scenario, "Pat buffed the warlock and is offered " .. words(pat) .. "; a favour should still be returned"
				.. " with Unending Breath")
		end
		env.names.nameplate1 = nil
		Mock.nameplates = {}
		ns.nameplateUnits.nameplate1 = nil
		_, byName = queued(ns)
		pat = byName["Pat Passer"]
		if not (pat and pat.reason == "owed" and pat.buff.key == "breath") then
			fail(scenario, "with no token on Pat the favour is offered " .. words(pat) .. "; it should still be returned"
				.. " with Unending Breath")
		end
	end)
end

-- ------------------------------------------------------------------------ 3b
-- The choice that puts it back (a report on 1.11.20: a warlock's only buff for
-- others stopped going to anybody but a favour's giver, and "1.11.18 was working
-- fine"): *Offer Unending Breath to everybody near me* (buff.unasked), off by
-- default, offers it to the group and to passers-by as before 1.11.19.
do
	local scenario = "audit-right-buff: Offer Unending Breath to everybody near me puts it back on the walk"
	local env = { class = "WARLOCK", knows = { "breath" }, units = {
		party1 = { name = { "Anna", "Aim" }, class = "MAGE" },
		nameplate1 = { name = { "Pat", "Passer" }, class = "PRIEST" },
	} }
	session(scenario, env, function(ns)
		if type(ns.db.profile.buff.unasked) ~= "table" or next(ns.db.profile.buff.unasked) ~= nil then
			fail(scenario, "a new profile's buff.unasked is not an empty set")
		end
		local function count()
			local n = 0
			for _, entry in ipairs((queued(ns))) do
				if entry.buff.key == "breath" and (entry.reason == "group" or entry.reason == "nearby") then n = n + 1 end
			end
			return n
		end
		if count() ~= 0 then fail(scenario, "offered to somebody with the choice off") end
		ns.db.profile.buff.unasked.breath = true
		if count() ~= 2 then fail(scenario, "with the choice on it is offered to " .. count() .. " of the two, not both") end
		ns.db.profile.buff.unasked.breath = nil
		if count() ~= 0 then fail(scenario, "with the choice put off again it is still offered") end
		-- The switch under Unending Breath on Who to buff.
		local control = H.findOption(ns.optionsTable, "unasked_breath")
		if not control then fail(scenario, "Who to buff has no choice under Unending Breath") return end
		control.set(nil, true)
		if ns.db.profile.buff.unasked.breath ~= true or control.get() ~= true then
			fail(scenario, "ticking it wrote " .. tostring(ns.db.profile.buff.unasked.breath))
		end
		control.set(nil, false)
		if ns.db.profile.buff.unasked.breath ~= nil then fail(scenario, "unticking it left " .. tostring(ns.db.profile.buff.unasked.breath)) end
		-- A damaged value is repaired, and the choice travels with a profile.
		ns.db.profile.buff.unasked = "yes"
		ns.ClampSettings()
		if type(ns.db.profile.buff.unasked) ~= "table" then fail(scenario, "a damaged choice was left as " .. tostring(ns.db.profile.buff.unasked)) end
		ns.db.profile.buff.unasked = { breath = true }
		local text = ns.ExportSettings and ns.ExportSettings() or ""
		if not text:find("buff.unasked=breath", 1, true) then fail(scenario, "the export does not carry the choice: " .. tostring(text)) end
	end)
end

-- ------------------------------------------------------------------------ 4
-- A paladin with Blessing of Might and nothing else yet (levels 4 to 13), or
-- any paladin once another's Wisdom and Kings are on them: a mage, a priest or
-- a warlock is offered Might, melee attack power. "Don't offer Might to mages,
-- warlocks and priests" exists (buff.skipCasters) and is off on a fresh profile.
do
	local scenario = "audit-right-buff: Blessing of Might is offered to a mage on a fresh profile"
	local env = { class = "PALADIN", level = 10, knows = { "might" }, units = {
		nameplate1 = { name = { "Anna", "Aim" }, class = "MAGE", level = 10 },
		party1 = { name = { "Bert", "Beside" }, class = "PRIEST", level = 10 },
	} }
	session(scenario, env, function(ns)
		local _, byName = queued(ns)
		for _, name in ipairs({ "Anna Aim", "Bert Beside" }) do
			local entry = byName[name]
			if entry and entry.buff.key == "might" then
				fail(scenario, ("a fresh profile offers %s; Might is melee attack power and does nothing for that class,"
					.. " so nothing should be offered"):format(words(entry)))
			end
		end
	end)
end

-- ------------------------------------------------------------------------ 5
-- A cast lands only on somebody within ten levels of a rank's own level
-- (Core.lua, LandingRank; Prompt/Macro.lua names the rank for that reason).
-- Where even the lowest rank is out of reach the buff is offered all the same,
-- and the press is refused ("Target is too low level"): Blessing of Kings
-- (level 20) for a warrior of 8, where Might would land; Divine Spirit and
-- Shadow Protection (level 30) for a mage of 12. Castable never asks the level.
do
	local scenario = "audit-right-buff: a buff none of whose ranks can land on somebody that low is offered anyway"
	local env = { class = "PALADIN", knows = { "wisdom", "might", "kings" }, units = {
		nameplate1 = { name = { "Anna", "Aim" }, class = "WARRIOR", level = 8 },
	} }
	session(scenario, env, function(ns)
		local _, byName = queued(ns)
		local entry = byName["Anna Aim"]
		if not (entry and entry.buff.key == "might") then
			fail(scenario, ("a paladin of 60 is offered %s for a warrior of level 8; Kings is learned at 20 and lands on"
				.. " nobody under 10, so the offer should be Blessing of Might, whose low ranks reach her")
				:format(words(entry)))
		end
	end)
	-- A priest: Fortitude's rank 2 is on her; nothing else of his reaches level 12.
	env = { class = "PRIEST", knows = { "fortitude", "spirit", "shadow" }, units = {
		nameplate1 = { name = { "Anna", "Aim" }, class = "MAGE", level = 12, wears = { [1244] = { left = 3000 } } },
	} }
	session(scenario, env, function(ns)
		local _, byName = queued(ns)
		local entry = byName["Anna Aim"]
		if entry then
			fail(scenario, ("a priest of 60 is offered %s for a mage of level 12 who wears Fortitude; Divine Spirit and"
				.. " Shadow Protection are learned at 30 and land on nobody under 20, so nothing should be offered")
				:format(words(entry)))
		end
	end)
end

-- ------------------------------------------------------------------------ 6
-- "A more powerful spell is already active" or "Target is too low level" holds
-- that one buff off that one person for ten minutes (Queue.lua, NoteRefusal,
-- THIS_BUFF): everything else about them stays as it was. A paladin's walk
-- reads any block on a blessing as "offered a moment ago, wait" (Core.lua,
-- PickBuffFor, onCooldown), so the ten-minute hold on Kings takes Might and
-- Wisdom with it and the warrior is offered nothing at all.
do
	local scenario = "audit-right-buff: a blessing the game said cannot land holds every other blessing off for ten minutes"
	local env = { class = "PALADIN", knows = { "wisdom", "might", "kings" }, units = {
		party1 = { name = { "Bert", "Beside" }, class = "WARRIOR" },
	} }
	session(scenario, env, function(ns)
		local _, byName = queued(ns)
		local before = byName["Bert Beside"]
		if not (before and before.buff.key == "kings") then
			fail(scenario, "SKIPPED -- Bert was not offered Kings to begin with: " .. words(before))
			return
		end
		ns.NoteRefusal("Bert Beside", BOUNCED .. ".", nil, true, "kings")
		Mock.advance(60)
		_, byName = queued(ns)
		local entry = byName["Bert Beside"]
		if not (entry and entry.buff.key == "might") then
			fail(scenario, ("a minute after the game refused Kings on Bert as weaker than what he wears, he is offered %s;"
				.. " only Kings is held off him, so the offer should be Blessing of Might"):format(words(entry)))
		end
	end)
end

-- ------------------------------------------------------------------------ 7
-- WoW Forever's Arcane Brilliance, Prayers and Gift of the Wild have the
-- caster's raid for their target (SpellEffect target 56, radius 100 yards,
-- build 1.60.1.70790; Buffs.lua, groupIsRaid): no unit to aim at, and
-- everybody within a hundred yards is reached. The walk drops every member
-- outside a SINGLE cast's range before the fold sees them (Queue.lua, visit:
-- requireInRange, on by default), so four people missing Intellect, one of
-- them beside you and three across the room, are one single cast and three
-- people never offered until they walk up.
do
	local scenario = "audit-right-buff: Forever: a raid-wide group cast counts only the members inside a single cast's range"
	local env = { class = "MAGE", knows = { "intellect" }, groupKnown = true, bags = { [ARCANE_POWDER] = 20 }, units = {
		party1 = { name = { "Anna", "Aim" }, class = "MAGE" },
		party2 = { name = { "Bert", "Beside" }, class = "PRIEST" },
		party3 = { name = { "Cora", "Vell" }, class = "DRUID" },
		party4 = { name = { "Dain", "Moor" }, class = "WARLOCK" },
	} }
	session(scenario, env, function(ns)
		local queue = queued(ns)
		if not (queue[1] and queue[1].groupCast) then
			fail(scenario, "SKIPPED -- with all four in range there is no group cast: " .. listed(queue))
			return
		end
		-- Three of them forty yards off: past Arcane Intellect, well inside
		-- Arcane Brilliance.
		Mock.rangeByUnit = { party1 = true, party2 = false, party3 = false, party4 = false }
		queue = queued(ns)
		local group
		for _, entry in ipairs(queue) do group = group or (entry.groupCast and entry) end
		if not group then
			fail(scenario, ("four of the party miss Intellect, one beside you and three forty yards off, and the queue is %s;"
				.. " Arcane Brilliance reaches the whole party and raid within 100 yards on Forever, so it should be one group"
				.. " cast aimed at Anna"):format(listed(queue)))
			return
		end
		-- Aimed at the one within reach of a cast, covering the other three.
		if group.name ~= "Anna Aim" or #group.groupCast.members ~= 3 then
			fail(scenario, ("the group cast is aimed at %s and covers %d others; it should be aimed at Anna, beside you,"
				.. " and cover the three across the room"):format(tostring(group.name), #group.groupCast.members))
		end
		if #queue ~= 1 then
			fail(scenario, "the queue holds more than the one group cast: " .. listed(queue))
		end
		-- Two of the three buffed since: two missing is under the threshold of
		-- three, so Anna keeps her single cast and Bert, out of a single cast's
		-- reach, is offered nothing, as before.
		lands(ns, env, "party3", 10157)
		lands(ns, env, "party4", 10157)
		queue = queued(ns)
		if not (#queue == 1 and queue[1].name == "Anna Aim" and not queue[1].groupCast) then
			fail(scenario, "with two missing it, one of them out of a single cast's reach, the queue is " .. listed(queue)
				.. "; it should be Anna's single Intellect and nothing for Bert")
		end
	end)
end

-- ------------------------------------------------------------------------ 8
-- Classic Era (and Burning Crusade; a paladin's Greater Blessings on every
-- client that has them): the group version is aimed at one member, and a macro
-- does not lower a rank for a low target (GitHub issue 9). Arcane Brilliance is
-- learned at 56 (SpellLevels, 1.15.9.70003) and lands on nobody under 46. The
-- fold neither counts levels nor picks its anchor by them (GroupBuffs.lua,
-- Build), so a mage of 60 running three friends of 60 and one of 20 is offered
-- Arcane Brilliance aimed at the one of 20; the game refuses it, and that
-- refusal holds Arcane Intellect itself off all four for ten minutes
-- (Queue.lua, NoteRefusal, THIS_BUFF with `members`).
do
	local scenario = "audit-right-buff: a group cast is aimed at a member too low for it, and its refusal holds the single buff off the party"
	local BRILLIANCE_LEVEL = 56
	local env = { client = "vanilla", class = "MAGE", knows = { "intellect" }, groupKnown = true,
		bags = { [ARCANE_POWDER] = 20 }, units = {
		party1 = { name = { "Anna", "Aim" }, class = "MAGE", level = 20 },
		party2 = { name = { "Bert", "Beside" }, class = "PRIEST", level = 60 },
		party3 = { name = { "Cora", "Vell" }, class = "DRUID", level = 60 },
		party4 = { name = { "Dain", "Moor" }, class = "WARLOCK", level = 60 },
	} }
	session(scenario, env, function(ns)
		local anna = ns.UnitFullName("party1")
		local on = shown(ns)
		if not (on and on.groupCast) then
			fail(scenario, "SKIPPED -- no group cast on the prompt: " .. words(on))
			return
		end
		local level = UnitLevel(on.unit)
		if level + 10 < BRILLIANCE_LEVEL then
			fail(scenario, ("Arcane Brilliance, learned at %d, is aimed at %s, level %d; the game refuses it as too low a"
				.. " level, so the cast should be aimed at one of the three of level 60 (or Anna left out of it)")
				:format(BRILLIANCE_LEVEL, tostring(on.name), level))
		end
		-- Anna is left out of it, and keeps a single Intellect of her own.
		local _, first = queued(ns)
		for _, name in ipairs(on.groupCast.members) do
			if name == anna then fail(scenario, "Anna, level 20, is counted into Arcane Brilliance, which cannot land on her") end
		end
		if not (first[anna] and not first[anna].groupCast) then
			fail(scenario, "Anna, left out of the group cast, is not offered a single Arcane Intellect: " .. words(first[anna]))
		end
		-- The press, and the game refusing it for the one it was aimed at
		-- (something stronger on them, say): the group version is held off
		-- that one as its target, and nobody's single buff with it. Everybody
		-- of level 60 is still reached by an offer, the next group cast aimed
		-- at somebody else.
		local refused = on.name
		H.pressButton(ns)
		ns.addon:UI_ERROR_MESSAGE(nil, nil, BOUNCED)
		Mock.advance(20)
		local queue = queued(ns)
		local reached, again = {}, nil
		for _, entry in ipairs(queue) do
			reached[entry.name] = true
			if entry.groupCast then
				again = entry
				for _, name in ipairs(entry.groupCast.members) do reached[name] = true end
			end
		end
		for token, unit in pairs(env.units) do
			local name = ns.UnitFullName(token)
			if unit.level == 60 and not reached[name] then
				fail(scenario, ("twenty seconds after the game refused that group cast on %s, %s, level 60 and still missing"
					.. " Intellect, is reached by no offer; the queue is %s"):format(tostring(refused), tostring(name), listed(queue)))
			end
		end
		if again and again.name == refused then
			fail(scenario, "the next group cast is aimed at " .. tostring(refused) .. " again, whom the game refused it on")
		end
	end)
end

-- A paladin's Greater Blessing is aimed at one of the class, on every client:
-- WoW Forever's too. Three warriors miss Might, the first by name of level 40:
-- Greater Blessing of Might, learned at 60 by a paladin who knows its second
-- rank, lands on nobody under 50, so he is left out of it and the other two
-- are under the threshold: single blessings for all three, his at a rank that
-- lands.
do
	local scenario = "audit-right-buff: a Greater Blessing leaves out a member too low for it"
	local env = { class = "PALADIN", knows = { "might" }, groupKnown = true, bags = { [21177] = 20 }, units = {
		party1 = { name = { "Anna", "Aim" }, class = "WARRIOR", level = 40 },
		party2 = { name = { "Bert", "Beside" }, class = "WARRIOR", level = 60 },
		party3 = { name = { "Cora", "Vell" }, class = "WARRIOR", level = 60 },
	} }
	session(scenario, env, function(ns)
		local queue, byName = queued(ns)
		for _, entry in ipairs(queue) do
			if entry.groupCast then
				fail(scenario, "a Greater Blessing is offered with a warrior of 40 counted into it: " .. listed(queue))
				return
			end
		end
		for _, name in ipairs({ "Anna Aim", "Bert Beside", "Cora Vell" }) do
			if not (byName[name] and byName[name].buff.key == "might") then
				fail(scenario, name .. " is not offered a single Blessing of Might: " .. listed(queue))
			end
		end
		-- All three of level 60, it is one Greater Blessing.
		env.units.party1.level = 60
		queue = queued(ns)
		if not (queue[1] and queue[1].groupCast) then
			fail(scenario, "SKIPPED -- three warriors of 60 missing Might get no Greater Blessing: " .. listed(queue))
		end
	end)
end

-- ------------------------------------------------------------------------ 9
-- "Remind me of my shout when I'm alone" reminds a warrior of his own Battle
-- Shout only while he is in no group at all (Core.lua, CastsOnSelf): "in a
-- party the group's own offer covers you". It does not when nobody of the
-- group is in reach, or when the one beside him wears another warrior's
-- shout: then nothing is offered and his own shout stays down.
do
	local scenario = "audit-right-buff: a warrior in a group with nobody in reach is never reminded of his own shout"
	local env = { class = "WARRIOR", knows = { "battleshout" }, wears = {}, units = {
		party1 = { name = { "Anna", "Aim" }, class = "MAGE" },
	}, setup = function(ns, db)
		db.ownBuffs.shoutAlone = true
		Mock.rangeless = {}
		for _, id in ipairs(ns.FindBuff("WARRIOR", "battleshout").ranks) do Mock.rangeless[id] = true end
	end }
	session(scenario, env, function(ns)
		local queue = queued(ns)
		if #queue == 0 then
			fail(scenario, "SKIPPED -- with Anna beside him the shout is not offered at all")
			return
		end
		-- Beside him she is the one offered it, and he is not: her offer covers him.
		if queue[1].reason == "self" or #queue ~= 1 then
			fail(scenario, "with Anna beside him and missing the shout, the queue is " .. listed(queue)
				.. "; it should be her offer alone, which covers him")
		end
		Mock.yards = { party1 = 60 }
		queue = queued(ns)
		if not (#queue == 1 and queue[1].reason == "self" and queue[1].buff.key == "battleshout") then
			fail(scenario, "with the switch on, his shout down and his one party member sixty yards off, the queue is "
				.. listed(queue) .. "; nothing of the group's covers him there, so he should be offered Battle Shout for himself")
		end
		-- Beside him again, wearing another warrior's shout: nobody to offer it
		-- to, and his own still down.
		Mock.yards = nil
		lands(ns, env, "party1", top(ns, "WARRIOR", "battleshout"), 100)
		queue = queued(ns)
		if not (#queue == 1 and queue[1].reason == "self") then
			fail(scenario, "with Anna beside him wearing another warrior's shout and his own down, the queue is "
				.. listed(queue) .. "; he should be offered Battle Shout for himself")
		end
		-- With the switch off he is never reminded, as before.
		ns.db.profile.ownBuffs.shoutAlone = false
		queue = queued(ns)
		if #queue ~= 0 then
			fail(scenario, "with the switch off he is offered " .. listed(queue))
		end
	end)
end

-- ----------------------------------------------------------------------- 10
-- People who ask in chat (off until switched on). A request by name is
-- answered relevant or not ("a warrior may want Intellect", Queue.lua). A plain
-- "buff pls" names nothing, and is answered the same way: a warrior wearing
-- Fortitude and Shadow Protection is offered Divine Spirit, which "Only buffs
-- they can use" keeps from every warrior who did not ask.
do
	local scenario = "audit-right-buff: 'buff pls' from a warrior is answered with Divine Spirit"
	local env = { class = "PRIEST", knows = { "fortitude", "spirit", "shadow" }, units = {
		nameplate1 = { name = { "Anna", "Aim" }, class = "WARRIOR",
			wears = { [10938] = { left = 3000 }, [10958] = { left = 500 } } },
	}, setup = function(_, db) db.sources.asked = true end }
	session(scenario, env, function(ns)
		local _, byName = queued(ns)
		if byName["Anna Aim"] then
			fail(scenario, "SKIPPED -- she is offered something before she asks: " .. words(byName["Anna Aim"]))
			return
		end
		ns.addon.CHAT_MSG_SAY(ns.addon, "CHAT_MSG_SAY", "buff pls", "Anna Aim", "Common", "", "", "", 0, 0, "", 0, 1,
			ns.plain(UnitGUID("nameplate1")))
		_, byName = queued(ns)
		local entry = byName["Anna Aim"]
		if entry and entry.buff.manaOnly then
			fail(scenario, ("a warrior who says \"buff pls\" and already wears Fortitude and Shadow Protection is offered %s;"
				.. " she named no buff, so one only a mana user wants should not be offered"):format(words(entry)))
		end
	end)
end

-- ----------------------------------------------------------------------- 11
-- A rank below the one your cast would land covers nothing (Core.lua,
-- UnitHasBuff: "a level-60 wearing a low player's +10 Stamina for an hour,
-- never offered the +70"). That test is made of single ranks alone, so the
-- first rank of a group version, which a caster of 50 puts on a whole party,
-- covers a level 60 for the hour: Bert wearing Mark of the Wild rank 6 is
-- offered rank 7, Anna wearing Gift of the Wild rank 1, the same numbers, is not.
do
	local scenario = "audit-right-buff: a weaker group version from a lower-level caster covers a level 60"
	local GIFT_RANK_1, MARK_RANK_6 = 21849, 9884
	local env = { class = "DRUID", knows = { "motw" }, units = {
		party1 = { name = { "Anna", "Aim" }, class = "MAGE", wears = { [GIFT_RANK_1] = { left = 3000 } } },
		party2 = { name = { "Bert", "Beside" }, class = "PRIEST", wears = { [MARK_RANK_6] = { left = 3000 } } },
	} }
	session(scenario, env, function(ns)
		local _, byName = queued(ns)
		if not byName["Bert Beside"] then
			fail(scenario, "SKIPPED -- Bert, wearing Mark of the Wild rank 6, is not offered rank 7 either")
			return
		end
		if not byName["Anna Aim"] then
			fail(scenario, "Anna, level 60, wears Gift of the Wild rank 1 (learned at 50, the numbers of Mark of the Wild rank 6)"
				.. " and is offered nothing, while Bert wearing rank 6 itself is offered rank 7; she should be offered Mark of the"
				.. " Wild rank 7 as he is")
		end
	end)
	-- Not below the group version you cast yourself: a druid of 60 who never
	-- trained Gift of the Wild past its first rank puts that on the party, and
	-- it must cover them, or the group cast would come straight back for it.
	env = { class = "DRUID", knows = { "motw" }, groupKnown = true, groupRanks = { [GIFT_RANK_1] = true }, units = {
		party1 = { name = { "Anna", "Aim" }, class = "MAGE", wears = { [GIFT_RANK_1] = { left = 3000, source = "player" } } },
	} }
	session(scenario, env, function(ns)
		local queue, byName = queued(ns)
		if byName["Anna Aim"] then
			fail(scenario, "a druid whose own Gift of the Wild is the first rank is offered " .. words(byName["Anna Aim"])
				.. " for somebody wearing it; her own group cast should cover them")
		end
	end)
end

-- ----------------------------------------------------------------------- 12
-- Two party members, the same tier. The client will not show Anna's auras;
-- Bert was read and wears no Intellect. The queue is in name order, so the
-- guess about Anna, who may well be buffed, comes before the certain gap. The
-- walk itself says "a guess must not jump the queue" of a target and of a ready
-- check (Queue.lua, visit).
do
	local scenario = "audit-right-buff: somebody whose buffs cannot be read is ranked ahead of somebody read as missing the buff"
	local env = { class = "MAGE", knows = { "intellect" }, units = {
		party1 = { name = { "Anna", "Aim" }, class = "MAGE", unreadable = true },
		party2 = { name = { "Bert", "Beside" }, class = "PRIEST" },
	} }
	session(scenario, env, function(ns)
		local queue, byName = queued(ns)
		local anna, bert = byName["Anna Aim"], byName["Bert Beside"]
		if not (anna and bert and anna.known == nil and bert.known == false) then
			fail(scenario, "SKIPPED -- not one unread and one read as missing: " .. listed(queue))
			return
		end
		if queue[1] ~= bert then
			fail(scenario, ("the queue is %s; Bert was read and has no Intellect, Anna could not be read at all, so Bert"
				.. " should come first"):format(listed(queue)))
		end
	end)
end

-- ----------------------------------------------------------------------- 13
-- Your own buff outranks your group whatever it is for (Queue.lua,
-- PRIORITY.self 1.75 against the group's 2). A top-up of your own Fortitude
-- with six and a half minutes still to run is put ahead of a party member who
-- wears no Fortitude at all.
do
	local scenario = "audit-right-buff: your own top-up is ranked ahead of a party member with nothing"
	local env = { class = "PRIEST", knows = { "fortitude" }, wears = { [10938] = { left = 400 } }, units = {
		party1 = { name = { "Anna", "Aim" }, class = "MAGE" },
	} }
	session(scenario, env, function(ns)
		local queue, byName = queued(ns)
		local anna = byName["Anna Aim"]
		local you = queue[1] ~= anna and queue[1] or queue[2]
		if not (anna and you and you.reason == "self" and you.remaining) then
			fail(scenario, "SKIPPED -- not a top-up of your own beside Anna's missing Fortitude: " .. listed(queue))
			return
		end
		if queue[1] ~= anna then
			fail(scenario, ("the queue leads with your own Fortitude, which has %d seconds left, ahead of %s; somebody with"
				.. " no Fortitude should come before a top-up of one that still runs"):format(math.floor(you.remaining), words(anna)))
		end
	end)
end

-- ----------------------------------------------------------------------- 14
-- Somebody of level 10 buffs a mage of 60. While a token holds them the macro
-- names the rank that lands on them ("Arcane Intellect(Rank 2)", GitHub issue
-- 9). A favour's giver seldom keeps a token, and the favour's own way onto the
-- prompt (Queue.lua, the tokenless fallback) knows their class and nothing of
-- their level, though a token read it when the favour was noticed: the macro
-- is the plain "/cast Arcane Intellect", rank 5, which the game refuses for
-- anybody under 46, and that refusal holds Intellect off them for ten minutes,
-- five times the favour's two.
do
	local scenario = "audit-right-buff: a favour returned by name alone casts the top rank at a giver too low for it"
	local RANK = { [1459] = 1, [1460] = 2, [1461] = 3, [10156] = 4, [10157] = 5 }
	local env = { class = "MAGE", knows = { "intellect" }, units = {
		nameplate1 = { name = { "Anna", "Aim" }, class = "PRIEST", level = 10 },
	} }
	session(scenario, env, function(ns)
		rawset(_G, "GetSpellSubtext", function(id) return RANK[id] and ("Rank " .. RANK[id]) or "" end)
		H.primeAuras(ns)
		if not ns.auraScan.primed then
			fail(scenario, "SKIPPED -- the baseline never settled")
			return
		end
		-- Anna puts Power Word: Fortitude, rank 1, on you.
		H.favourFrom(ns, "nameplate1", 1243, 7801)
		if not ns.owed["Anna Aim"] then
			fail(scenario, "SKIPPED -- her Fortitude was not filed as a favour")
			return
		end
		local function castLine()
			Mock.advance(1)
			local on = shown(ns)
			if not (on and on.name == "Anna Aim") then return nil, on end
			return (ns.Prompt:GetButton():GetAttribute("macrotext1") or ""):match("/cast ([^\n]*)")
		end
		local withToken, on = castLine()
		if withToken ~= "Arcane Intellect(Rank 2)" then
			fail(scenario, "SKIPPED -- with her nameplate up the macro casts " .. tostring(withToken) .. " (" .. words(on) .. ")")
			return
		end
		-- Her nameplate goes, as it does for most people who buff you in passing.
		env.names.nameplate1 = nil
		Mock.nameplates = {}
		ns.nameplateUnits.nameplate1 = nil
		Mock.advance(12)
		local byName = castLine()
		if byName ~= "Arcane Intellect(Rank 2)" then
			fail(scenario, ("with her nameplate gone the favour's macro casts %q at Anna, level 10; rank 5 lands on nobody"
				.. " under 46, so it should still be \"Arcane Intellect(Rank 2)\", from the level read when she buffed you")
				:format(tostring(byName)))
		end
	end)
end

-- ----------------------------------------------------------------------- 15
-- WoW Forever's camping features put an hour-long aura on everybody who sat by
-- them, each "mutually exclusive with" one class buff in the feature's own text
-- and the same aura in the data (Spell and SpellEffect, build 1.60.1.70790):
--
--   First Aid Kit    Boosted Stamina 1230124           MOD_STAT Stamina +56     Power Word: Fortitude
--   Incense Candle   Boosted Intellect 1229513         MOD_STAT Intellect +25   Arcane Intellect
--   Faction Banner   Boosted Spirit 1229718            MOD_STAT Spirit +32      Divine Spirit
--   Enchanted Lute   Boosted Stats 1230653             armor, stats, resists    Mark of the Wild
--   Lodestone        Boosted Attack Power 1230164      +90 melee attack power   Blessing of Might
--   Mana Well        Boosted Mana Regeneration 1230587 29 mana per 5 s          Blessing of Wisdom
--   Fish Bowl        Boosted Stats 1230098             8% stats                 Blessing of Kings
--
-- (the numbers are a level 60's; the features' text gives less by level:
-- Stamina 3, 8, 21, 34 and 45 below 12, 24, 36, 48 and 60). A Scroll of Stamina
-- is the same aura and holds a weaker Fortitude off (Buffs.lua, `blockers`);
-- none of these is in any list but the Fish Bowl's, behind a switch. So a
-- priest still on rank 4 (+42) is offered Fortitude for a level 60 wearing
-- +56 from a First Aid Kit: the press is refused ("A more powerful spell is
-- already active"), held off ten minutes, and offered again, for the hour.
do
	local scenario = "audit-right-buff: Forever: a camping buff worth more than your rank does not hold your buff off"
	local BOOSTED_STAMINA, SCROLL_OF_STAMINA_IV = 1230124, 12178
	local function priest(level, worn, hers, points)
		return { class = "PRIEST", level = level, knows = { "fortitude" }, units = {
			party1 = { name = { "Anna", "Aim" }, class = "WARRIOR", level = hers or 60,
				wears = { [worn] = { left = 3000, points = points } } },
		} }
	end
	-- Whether Anna is offered Fortitude by a priest of `level`, she of level
	-- `hers` wearing Boosted Stamina (with `points`, where the client says).
	local function offered(level, hers, points)
		local entry
		session(scenario, priest(level, BOOSTED_STAMINA, hers, points), function(ns)
			local _, byName = queued(ns)
			entry = byName["Anna Aim"]
		end)
		return entry ~= nil
	end
	-- The same with a scroll, which is known: a priest of 20 (rank 2, +10) and
	-- her Scroll of Stamina IV (+16).
	local known = true
	session(scenario, priest(20, SCROLL_OF_STAMINA_IV), function(ns)
		local _, byName = queued(ns)
		if byName["Anna Aim"] then
			known = false
			fail(scenario, "SKIPPED -- a Scroll of Stamina worth more than the rank does not hold Fortitude off either")
		end
	end)
	if known then
		session(scenario, priest(47, BOOSTED_STAMINA), function(ns)
			local _, byName = queued(ns)
			local entry = byName["Anna Aim"]
			if entry then
				fail(scenario, ("a priest of 47, whose best Fortitude is rank 4 (+42 Stamina), is offered %s for a level 60"
					.. " wearing a First Aid Kit's Boosted Stamina (+56, the same aura); the game refuses the weaker one, so"
					.. " nothing should be offered, as for a Scroll of Stamina worth more than the rank"):format(words(entry)))
			end
		end)
		-- Worth less than the rank, it is cast over: rank 6 gives +70.
		if not offered(60, 60) then
			fail(scenario, "a priest of 60 (+70) is offered nothing for a level 60 wearing Boosted Stamina (+56); a camping"
				.. " buff worth less than the rank should be cast over")
		end
		-- By the wearer's level: on a level 30 it is +21 (the feature's text),
		-- under rank 3's +26 and over rank 2's +10.
		if not offered(30, 30) then
			fail(scenario, "a priest of 30 (rank 3, +26) is offered nothing for a level 30 wearing Boosted Stamina, +21 at"
				.. " that level; it should be cast over")
		end
		if offered(20, 30) then
			fail(scenario, "a priest of 20 (rank 2, +10) is offered Fortitude for a level 30 wearing Boosted Stamina, +21 at"
				.. " that level; the game refuses it")
		end
		-- The aura's own number, where the client gives it, over the table's.
		if not offered(47, 60, { 30 }) then
			fail(scenario, "a priest of 47 (+42) is offered nothing for a level 60 whose Boosted Stamina the client says"
				.. " gives +30; the aura's own number should decide")
		end
	end
end
