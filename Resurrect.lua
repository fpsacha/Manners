-- Manners -- resurrection: a dead member of your group, and with a second
-- switch a dead passer-by, offered your resurrection on the prompt.
--
-- Until this file a dead player was nobody: Core.lua's IsBuffableUnit answers
-- false for the dead and BuildQueue's walk never offers them. Here, out of a
-- fight, somebody dead and within reach is put first of everything on the
-- prompt with your resurrection, and a press is the usual macro: /target
-- <name>, /cast <spell>, the hand-back. Once they stand, the "revived" sweep
-- (Queue.lua, SweepReason) takes over for the buffs the death cost them.
--
-- How it reaches the rest of the addon, each a single line there:
--   Core.lua    IsBuffableUnit hands every dead unit the walk meets to
--               ns.deadSeen, so the living cost a scan nothing here;
--               ns.BuffInfo answers for the two spell tables below (`res`);
--               ns.CanCastAnything counts a resurrection learned (caps.res);
--               ns.SpellKnown is the probe's own question, shared.
--   Queue.lua   the walk says it ran (ns.deadSeen.walked): without buffs to
--               give there is none, and the group is walked here instead.
--   Prompt/     Paint.lua's reason line (Res.Reason) and Press.lua's PostClick
--               (Res.Pressed), which files a press here and not as a buff.
--   Commands.lua, Options/Diagnostics.lua   ns.ResurrectLines, why it holds back.
-- ns.BuildQueue and ns.ProbeCapabilities are wrapped at the end of this file,
-- as Refresh.lua wraps ns.PutOnNeverList: every caller asks ns at call time.
--
-- The rules, each held by tests/scenarios/res.lua:
--   - never in a fight: yours (the lockdown, UnitAffectingCombat) or the pull's
--     own repaint, so no resurrection is ever frozen onto the button;
--   - never somebody who has released their spirit. A ghost is running back,
--     and the client tells an addon where the spirit is (its range, its
--     sight), never where the body lies: nothing could say the body is in
--     reach, and whoever released has chosen the run;
--   - never somebody with a resurrection already on the way
--     (UnitHasIncomingResurrection, on all five clients), so two healers are
--     not sent to the same body;
--   - never a hunter lying in Feign Death, who reads as dead;
--   - within reach: not out of sight, and not measured out of the spell's
--     range (a range the client will not give is offered);
--   - after a press they rest until they live or the cast is seen to fail;
--   - nothing is said aloud: the entry carries no range reading for the
--     spoken line to be armed on (Prompt/Macro.lua), and the press judges a
--     dead target as a line to leave out (Press.lua, HoldLine).

local _, ns = ...
local L = ns.L
local addon = ns.addon
local plain, safecall, caps = ns.plain, ns.safecall, ns.caps
local GetTime, InCombatLockdown = _G.GetTime, _G.InCombatLockdown

local Res = {}
ns.Resurrect = Res

---------------------------------------------------------------------------
-- the spells
--
-- Each client's own, from its tables at wago.tools for the build
-- .claude/docs/data-sources.md cites (SpellName, SpellEffect, SkillLineAbility, SpellLevels, SpellMisc,
-- SpellCastTimes, SpellCooldowns, SpellReagents; retail's mass resurrections
-- from SpecializationSpells): every spell a class is given whose effect brings
-- somebody back, that cannot be cast in a fight (SpellMisc Attributes_0,
-- 0x10000000), has no cooldown and no reagent. Best rank first, as Buffs.lua
-- lists ranks; ten seconds to cast, every one of them.
--
-- Left out, by the same data:
--   - Rebirth (20484 and its ranks), on every client: castable in a fight,
--     ten to thirty minutes of cooldown and, on Forever, Classic Era and
--     Burning Crusade, a reagent. A druid there has it for fights and nothing
--     for afterwards, except Revive below;
--   - Raise Ally (61999) and retail's Intercession (391054): for fights, on a
--     ten-minute cooldown; a warlock's Soulstone, which is cast on the living;
--   - Burning Crusade's "Mass Resurrection" (32841): a spell the client's
--     tables file for a priest in the paladin's Holy line, taught by nothing.
--
-- A druid's Revive: Forever has five ranks of it (437138 at 12, then 1237948
-- to 1237951), Classic Era the one id 437138 (Season of Discovery's), Mists
-- and retail 50769. Burning Crusade has none.
--
-- `mass` is the one cast for everybody dead in the party or raid: Mists
-- Classic gives each of its five healing classes one at level 44, retail the
-- healing specializations. Offered when several of the group are dead.
---------------------------------------------------------------------------

local CLASSIC = {
	PRIEST = { single = { 20770, 10881, 10880, 2010, 2006 } },
	PALADIN = { single = { 20773, 20772, 10324, 10322, 7328 } },
	SHAMAN = { single = { 20777, 20776, 20610, 20609, 2008 } },
}

local SPELLS = {
	camelot = {
		PRIEST = CLASSIC.PRIEST,
		PALADIN = CLASSIC.PALADIN,
		SHAMAN = CLASSIC.SHAMAN,
		DRUID = { single = { 1237951, 1237950, 1237949, 1237948, 437138 } },
	},
	vanilla = {
		PRIEST = CLASSIC.PRIEST,
		PALADIN = CLASSIC.PALADIN,
		SHAMAN = CLASSIC.SHAMAN,
		-- A rune's, of one season: no druid of another realm of this client
		-- can learn it, so it is his only once it is learned (Res.Has).
		DRUID = { single = { 437138 }, rune = true },
	},
	tbc = {
		PRIEST = { single = { 25435, 20770, 10881, 10880, 2010, 2006 } },
		PALADIN = CLASSIC.PALADIN,
		SHAMAN = { single = { 25590, 20777, 20776, 20610, 20609, 2008 } },
	},
	mists = {
		PRIEST = { single = { 2006 }, mass = { 83968 } },
		PALADIN = { single = { 7328 }, mass = { 450761 } },
		SHAMAN = { single = { 2008 }, mass = { 450762 } },
		DRUID = { single = { 50769 }, mass = { 450759 } },
		MONK = { single = { 115178 }, mass = { 1245934 } },
	},
	mainline = {
		PRIEST = { single = { 2006 }, mass = { 212036 } },
		PALADIN = { single = { 7328 }, mass = { 212056 } },
		SHAMAN = { single = { 2008 }, mass = { 212048 } },
		DRUID = { single = { 50769 }, mass = { 212040 } },
		MONK = { single = { 115178 }, mass = { 212051 } },
		EVOKER = { single = { 361227 }, mass = { 361178 } },
	},
}
Res.SPELLS = SPELLS

-- Every resurrection of every class on every client, by id: a row of the
-- favour ledger that holds one was somebody brought back, whichever character
-- or client wrote it (Milestones.lua counts no buff for it).
local EVERY = {}
for _, set in pairs(SPELLS) do
	for _, mine in pairs(set) do
		for _, ids in pairs(mine) do
			for _, id in ipairs(type(ids) == "table" and ids or {}) do EVERY[id] = true end
		end
	end
end

function Res.IsSpell(id)
	return id ~= nil and EVERY[id] == true
end

-- This class's, on this client, or nil: a client nobody here has seen gets its
-- family's, as it gets its family's buffs (Buffs.lua).
local function Mine()
	local flavour = ns.Flavour or {}
	local set = SPELLS[flavour.flavour]
	if not set then set = flavour.family == "classic" and SPELLS.vanilla or SPELLS.mainline end
	local class = caps.class or (ns.PlayerClass and ns.PlayerClass())
	return class and set[class] or nil
end

local Info -- below

-- Whether this class has a resurrection on this client at all, learned or
-- not: what shows the two switches on Who to buff, and the milestone. One a
-- season's rune teaches (`rune`) only once it is learned: on every other
-- realm of that client the class has none.
function Res.Has()
	local mine = Mine()
	if mine == nil then return false end
	return mine.rune ~= true or Info() ~= nil
end

-- What the prompt casts. Shaped as a buff is, for everything that names,
-- draws or arms one (ns.BuffInfo answers `info` for a table flagged `res`),
-- and with no `ranks`: a resurrection lands on any level, so the macro never
-- names a lower rank (Prompt/Macro.lua, ns.CastName). The mass one is cast at
-- nobody (`selfCast`: a bare /cast).
local KEY, MASS_KEY = "resurrect", "massresurrect"
local SINGLE = { key = KEY, res = true }
local MASS = { key = MASS_KEY, res = true, selfCast = true }
Res.KEY, Res.MASS_KEY = KEY, MASS_KEY

-- Every id of this class's, for telling its own cast from any other.
local mineIds = {}

local function ProbeOne(buff, ids)
	local info = { key = buff.key, buff = buff, unresolved = {}, secrecy = {} }
	local known = ns.SpellKnown
	for _, id in ipairs(ids or {}) do
		mineIds[id] = true
		if known and known(id) then
			info.known = true
			info.topRank = info.topRank or id
		end
	end
	-- The macro casts by name, so the name of the best rank known; one the
	-- client cannot name is not one to offer.
	local named = info.topRank or (ids and ids[1])
	info.name = named and ns.SpellNameFor(named) or nil
	info.icon = named and safecall(C_Spell and C_Spell.GetSpellTexture, named) or nil
	info.known = info.known == true and info.name ~= nil
	buff.info = info
	return info
end

-- Asked with every capability probe (the wrap at the end of this file), and
-- kept in caps.res, which the probe empties with the rest: a table while
-- anything is learned, false otherwise.
function Res.Learn()
	wipe(mineIds)
	local mine = Mine()
	local info = false
	if mine then
		local single, mass = ProbeOne(SINGLE, mine.single), ProbeOne(MASS, mine.mass)
		if single.known or mass.known then info = { single = single, mass = mass } end
	end
	caps.res = info
	return info
end

function Info()
	local info = caps.res
	if info == nil then info = Res.Learn() end
	return info or nil
end
Res.Info = Info

-- Whether My group's dead is on: with it off a resurrection learned is
-- nothing to cast (Core.lua, ns.CanCastAnything), as a cure with its switches
-- off is none.
function Res.Wanted()
	local db = addon.db and addon.db.profile
	return db ~= nil and db.sources.res == true
end

---------------------------------------------------------------------------
-- who
---------------------------------------------------------------------------

-- A dead member of the group ranks first of everything on the prompt, your
-- own target included (Queue.lua's PRIORITY starts at 0), and the one cast for
-- them all ahead of any one of them.
local PRIORITY = -1
Res.PRIORITY = PRIORITY

-- How long the game is given to answer a press with a cast; how long a cast
-- under way rests them (every spell above takes ten seconds: SpellCastTimes);
-- how long a cast that finished does (the game's question to them stays up
-- sixty seconds past any corpse delay: Blizzard's own StaticPopupDialogs
-- RESURRECT, `timeleft = GetCorpseRecoveryDelay() + 60`); and how long after a
-- cast seen to fail, or after a scan finds them no longer in need, as a press
-- that went nowhere rests somebody (Clicks.lua, RewindClick).
local ANSWER_SECONDS, CAST_SECONDS, ACCEPT_SECONDS, RETRY_SECONDS = 2, 12, 65, 2

-- The scan in hand: the dead units the walk met (the array), and whether the
-- walk ran at all (`walked`, Queue.lua). One table, emptied each scan.
local scan = {}
Res.scan = scan
-- What the last scan made of it, for ns.ResurrectLines.
local counts = { offered = 0, ghost = 0, incoming = 0, far = 0, pvp = 0, resting = 0 }
Res.counts = counts
-- One verdict a name a scan, as the walk keeps it.
local taken = {}
-- Whether a dead member of the group reads as flagged for PvP while the rule
-- stands: the one cast for everybody would reach them, and flag you.
local flaggedDead = false
-- The press waiting on the game: { names, at, sent, name, mass, ... }.
Res.pending = nil
-- [name] = the token they were pressed through, while a press rests them: read
-- each scan so that standing up ends the rest at once.
local rested = {}
Res.rested = rested
-- What the last scan offered, by name and spell key, for the scan after it to
-- let go of whoever is seen to need it no longer.
local last, fresh = {}, {}

local GROUP_TOKENS = { raid = {}, party = {} }

-- The group's dead, where BuildQueue made no walk (nothing of yours to give
-- anybody: a monk on retail, every buff switched off): its own tokens, and
-- with dead passers-by on, the three a player points with.
local function OwnWalk(db)
	local function add(unit)
		if plain(UnitExists(unit)) and plain(UnitIsDeadOrGhost(unit)) == true then scan[#scan + 1] = unit end
	end
	if db.sources.resStrangers == true then
		add("target")
		add("focus")
		add("mouseover")
	end
	local n = plain(GetNumGroupMembers and GetNumGroupMembers()) or 0
	if n <= 0 then return end
	local raid = plain(IsInRaid and IsInRaid()) == true
	local prefix = raid and "raid" or "party"
	local tokens = GROUP_TOKENS[prefix]
	for i = 1, math.min(raid and n or (n - 1), 40) do
		local unit = tokens[i]
		if not unit then
			unit = prefix .. i
			tokens[i] = unit
		end
		add(unit)
	end
end

-- Your own state, where BuildQueue refused everybody for it (its second
-- return true) before any walk: dead, charmed, in a vehicle, on a taxi, or
-- mounted with the prompt hidden. Asked only then.
local function YouCannot()
	if plain(UnitIsDeadOrGhost("player")) == true then return true end
	if plain(UnitIsCharmed and UnitIsCharmed("player")) == true then return true end
	if UnitInVehicle and plain(UnitInVehicle("player")) == true then return true end
	if UnitOnTaxi and plain(UnitOnTaxi("player")) == true then return true end
	return ns.HiddenWhileMounted() and true or false
end

-- A function of the client's by name, or nil: asked for at the call, since
-- not every one is on every client.
local function Client(name)
	local fn = _G[name]
	if type(fn) == "function" then return fn end
	return nil
end

-- One dead unit: nil for somebody not to be resurrected by you now, counted
-- where /manners debug says why, else what is known of them. Called for the
-- dead alone, which is a handful of people on the worst evening.
local function Consider(unit, db, now, strangers, single)
	if plain(UnitIsUnit(unit, "player")) then return nil end
	if plain(UnitIsPlayer(unit)) ~= true then return nil end
	local name = ns.UnitFullName(unit)
	if not name or taken[name] then return nil end
	taken[name] = true

	local inGroup = (plain(UnitInParty and UnitInParty(unit)) or plain(UnitInRaid and UnitInRaid(unit))) and true or false
	if not inGroup and not strangers then return nil end
	-- A hunter lying in Feign Death reads as dead (Queue.lua, WatchGroupDeaths).
	local feign = Client("UnitIsFeignDeath")
	if feign and plain(feign(unit)) == true then return nil end
	if plain(UnitCanAssist("player", unit)) ~= true then return nil end
	if plain(UnitIsConnected(unit)) == false then return nil end
	-- Helping somebody flagged for PvP flags you, and the cast for the whole
	-- group reaches every dead member of it, whatever else is true of them
	-- below: released, out of reach, on the never-offer list.
	local flagged = db.filters.skipPvP == true and ns.PvPHoldsBack(ns.PvPFlag(unit))
	if flagged and inGroup then flaggedDead = true end
	-- Offer nothing in cities and inns, or in dungeons, raids and battlegrounds
	-- (Queue.lua, inTown): nobody, the dead included, but your target or focus.
	if scan.quiet and (db.filters.quietTargets == true
		or not (plain(UnitIsUnit(unit, "target")) or plain(UnitIsUnit(unit, "focus")))) then
		return nil
	end
	-- The never-offer list is of people you offer nothing, and nobody you
	-- /ignore outside your group is offered anything either (ns.Ignored).
	if ns.IsNeverOffered(name) then return nil end
	if not inGroup and ns.Ignored(unit) then return nil end

	-- Released: the spirit is what the client reads, and the body is elsewhere.
	local ghost = Client("UnitIsGhost")
	if ghost and plain(ghost(unit)) == true then
		counts.ghost = counts.ghost + 1
		return nil
	end
	-- Somebody else's resurrection is on its way to them, or your own from a bar.
	local incoming = Client("UnitHasIncomingResurrection")
	if incoming and plain(incoming(unit)) == true then
		counts.incoming = counts.incoming + 1
		return nil
	end
	-- Helping somebody flagged for PvP flags you, a resurrection included.
	if flagged then
		counts.pvp = counts.pvp + 1
		return nil
	end
	-- Out of sight is out of reach for certain, which a range check will not
	-- always say (Queue.lua, visit).
	local visible = Client("UnitIsVisible")
	if visible and plain(visible(unit)) == false then
		counts.far = counts.far + 1
		return nil
	end

	local reach
	if single then reach = ns.InRange(unit, SINGLE) end
	-- `resting`: not to be offered for now, whatever the reason (a press, a
	-- right-click's skip, a refusal's back-off); `pressed` says it was a press.
	return { name = name, unit = unit, inGroup = inGroup, reach = reach,
		class = plain(select(2, UnitClass(unit))),
		resting = ns.IsBlocked(name, KEY, now), pressed = rested[name] ~= nil }
end

local function ByReach(a, b)
	local ar = a.reach == true and 0 or (a.reach == nil and 1 or 2)
	local br = b.reach == true and 0 or (b.reach == nil and 1 or 2)
	if ar ~= br then return ar < br end
	return a.name < b.name
end

-- The entries for this scan: the one for the whole group (or nil) and the
-- list of single ones, best first. Nothing in a fight, nothing for your own
-- state, nothing you cannot pay for.
local function Find(db, info, rejected, now)
	if scan.walked and #scan == 0 then return nil, nil end

	-- Never in a fight, and never on the pull's own repaint (Core.lua,
	-- PLAYER_REGEN_DISABLED): what that arms is frozen for the whole fight.
	local prompt = ns.Prompt
	local fighting = Client("UnitAffectingCombat")
	if InCombatLockdown() or (prompt and prompt.armedForFight == true)
		or (fighting and plain(fighting("player")) == true) then
		if #scan > 0 then counts.fight = true end
		return nil, nil
	end

	if not scan.walked then
		if rejected == true and YouCannot() then return nil, nil end
		OwnWalk(db)
		if #scan == 0 then return nil, nil end
	end

	-- Nobody asked for it, so it waits while you keep your mana, as every
	-- unasked offer does (Queue.lua, savingMana).
	if ns.SavingMana() ~= nil then return nil, nil end

	-- What you cannot pay for is a button that fails: only the game's own "not
	-- enough mana" counts, as for a buff (Queue.lua, Affordable).
	local check = C_Spell and C_Spell.IsSpellUsable
	if type(check) ~= "function" then check = _G.IsUsableSpell end
	local function Paid(one)
		if not one.known then return false end
		if type(check) ~= "function" then return true end
		local usable, noMana = safecall(check, one.topRank)
		if usable == false and noMana == true then
			counts.mana = one.name
			return false
		end
		return true
	end
	local single, massReady = Paid(info.single), Paid(info.mass)
	if not single and not massReady then return nil, nil end

	wipe(taken)
	flaggedDead = false
	local strangers = db.sources.resStrangers == true
	local people = {}
	for i = 1, #scan do
		local person = Consider(scan[i], db, now, strangers, single)
		if person then people[#people + 1] = person end
	end
	if #people == 0 then return nil, nil end
	table.sort(people, ByReach)

	local offered = {}
	local singles = {}
	for _, person in ipairs(people) do
		if person.reach == false then
			counts.far = counts.far + 1
		elseif person.resting then
			if person.pressed then counts.resting = counts.resting + 1 end
		elseif not single then
			-- Only the one for the whole group is learned or paid for.
		else
			offered[person.name] = true
			singles[#singles + 1] = {
				name = person.name,
				short = ns.ShortName(person.name),
				targetName = ns.TargetName(person.name),
				unit = person.unit,
				class = person.class,
				buff = SINGLE,
				reason = person.inGroup and "group" or "nearby",
				inGroup = person.inGroup,
				priority = PRIORITY,
				-- No reading of a buff was taken, and none is claimed.
				checked = false,
				res = true,
				-- How far, for the order here alone: the entry carries no
				-- `ranged`, which is what a spoken line is armed on.
				reach = person.reach,
			}
		end
	end

	-- The one cast for everybody: with several of the group dead and not
	-- resting. Anchored on the first of them by name, resting or not, so a
	-- right-click's skip of it holds (the block is on that one person) and the
	-- cast does not form again around the next.
	-- Not while a dead member of the group is flagged and the PvP rule stands,
	-- nor where nothing is offered but to your target or focus: it is cast at
	-- nobody, and reaches them all.
	local mass
	if massReady and not flaggedDead and not scan.quiet then
		local names, units, waiting, anchor = {}, {}, 0, nil
		for _, person in ipairs(people) do
			if person.inGroup then
				if not anchor or person.name < anchor.name then anchor = person end
				if not person.resting then
					waiting = waiting + 1
					names[#names + 1] = person.name
					units[person.name] = person.unit
				end
			end
		end
		if waiting >= 2 and not ns.IsBlocked(anchor.name, MASS_KEY, now) then
			for _, name in ipairs(names) do offered[name] = true end
			mass = {
				name = anchor.name,
				short = ns.ShortName(anchor.name),
				-- Named for who it reaches, as a group cast is (GroupBuffs.lua).
				display = L["Your group"],
				targetName = ns.TargetName(anchor.name),
				unit = anchor.unit,
				buff = MASS,
				reason = "group",
				inGroup = true,
				priority = PRIORITY - 1,
				checked = false,
				res = true,
				resNames = names,
				resUnits = units,
			}
		end
	end

	for _ in pairs(offered) do counts.offered = counts.offered + 1 end
	return mass, singles
end

-- A press that the game never answered, or whose cast is long over, is
-- forgotten; and whoever a press rests is read again, so that standing up
-- ends the rest (they may die again inside the minute).
local function Tend(now)
	local pending = Res.pending
	if pending then
		if (not pending.sent and now - pending.at > ANSWER_SECONDS)
			or (pending.sent and now - pending.sent > CAST_SECONDS + ANSWER_SECONDS) then
			Res.pending = nil
		end
	end
	for name, unit in pairs(rested) do
		if not ns.IsBlocked(name, KEY, now) then
			rested[name] = nil
		elseif plain(UnitExists(unit)) and ns.UnitFullName(unit) == name
			and plain(UnitIsDeadOrGhost(unit)) == false then
			ns.MarkAttempted(name, KEY, 0)
			rested[name] = nil
		end
	end
end

-- BuildQueue's two returns with the resurrections put first.
function Res.Offer(db, info, queue, rejected)
	local now = GetTime()
	counts.offered, counts.ghost, counts.incoming, counts.far, counts.pvp, counts.resting = 0, 0, 0, 0, 0, 0
	counts.fight, counts.mana = nil, nil
	Tend(now)

	local mass, singles
	if info then mass, singles = Find(db, info, rejected, now) end

	wipe(fresh)
	if mass then fresh[mass.name .. "\0" .. MASS_KEY] = mass end
	if singles then
		for _, entry in ipairs(singles) do fresh[entry.name .. "\0" .. KEY] = entry end
	end
	-- Whoever the last scan offered and this one does not, while a token still
	-- names them: they stand, or a resurrection is on its way to them, or they
	-- released. Rested for a moment, which is what takes them off the prompt
	-- now and not after its hold (Prompt/Hold.lua, Retired): two healers must
	-- not be left looking at the same body. Somebody whose token is merely gone
	-- (the cursor moved off them) is the hold's to judge, as ever.
	for id, old in pairs(last) do
		if not fresh[id] and old.unit and not ns.IsBlocked(old.name, old.buff.key, now)
			and plain(UnitExists(old.unit)) and ns.UnitFullName(old.unit) == old.name then
			ns.MarkAttempted(old.name, old.buff.key, RETRY_SECONDS)
		end
	end
	last, fresh = fresh, last
	-- Whether the next scan has anything of this one's to tend with nobody
	-- dead: an offer to let go of, a rest to end, a press to forget, or a
	-- count the debug lines would otherwise go on quoting.
	Res.active = next(last) ~= nil or next(rested) ~= nil or Res.pending ~= nil
		or counts.fight ~= nil or counts.mana ~= nil
		or counts.ghost + counts.incoming + counts.far + counts.pvp + counts.resting > 0

	if not mass and not (singles and #singles > 0) then return queue, rejected end

	local out = {}
	if mass then out[1] = mass end
	for _, entry in ipairs(singles) do out[#out + 1] = entry end
	for _, entry in ipairs(queue) do out[#out + 1] = entry end
	-- The walk turned each of them down as dead, which is a verdict the
	-- prompt's hold reads (Prompt/Hold.lua, NoteVerdicts): not one on somebody
	-- offered here. And a queue refused whole for having nothing to give is
	-- refused no longer.
	if type(rejected) ~= "table" then rejected = {} end
	for i = 1, #out do
		local entry = out[i]
		if not entry.res then break end
		rejected[entry.name] = nil
		for _, name in ipairs(entry.resNames or {}) do rejected[name] = nil end
	end
	return out, rejected
end

---------------------------------------------------------------------------
-- the words
---------------------------------------------------------------------------

-- The reason line (Prompt/Paint.lua, ReasonText): why they are on the prompt.
function Res.Reason(entry)
	if entry.resNames then return L["%d dead"]:format(#entry.resNames) end
	return L["dead"]
end

-- For /manners debug and the full check-up: why a resurrection is, or is not,
-- on the prompt. Nothing for a class without one, with none learned, or with
-- nobody dead. `rescan` builds the queue first, so the counts are this moment's.
function ns.ResurrectLines(rescan)
	local out = {}
	local db = addon.db and addon.db.profile
	if not db then return out end
	local info = Info()
	if not info then return out end
	if db.sources.res ~= true then
		out[1] = L["resurrection: not offered -- %s is switched off."]:format("|cffffd100" .. L["Resurrect my group's dead"] .. "|r")
		return out
	end
	if rescan then ns.Guard("resurrection lines", ns.BuildQueue) end
	local c = counts
	if c.fight then
		out[1] = L["resurrection: nothing is offered in a fight."]
		return out
	end
	if c.offered > 0 then
		out[#out + 1] = L["resurrection: |cffffffff%s|r for %d dead."]
			:format(tostring(info.single.known and info.single.name or info.mass.name), c.offered)
	end
	if c.mana then
		out[#out + 1] = L["resurrection: not offered -- not enough mana for |cffffffff%s|r."]:format(tostring(c.mana))
	end
	if c.ghost > 0 then
		out[#out + 1] = L["resurrection: %d left alone -- they released their spirit, and the game tells where a spirit is, never its body."]
			:format(c.ghost)
	end
	if c.incoming > 0 then
		out[#out + 1] = L["resurrection: %d left alone -- a resurrection is already on its way to them."]:format(c.incoming)
	end
	if c.far > 0 then
		out[#out + 1] = L["resurrection: %d left alone -- out of reach or out of sight."]:format(c.far)
	end
	if c.pvp > 0 then
		out[#out + 1] = L["resurrection: %d left alone -- flagged for PvP."]:format(c.pvp)
	end
	if c.resting > 0 then
		out[#out + 1] = L["resurrection: %d resting after your press, until they live or the cast is seen to fail."]
			:format(c.resting)
	end
	return out
end

---------------------------------------------------------------------------
-- the press, and what became of it
--
-- A resurrection is not a buff, and none of a buff's bookkeeping is true of
-- it: no favour is repaid by it, no rotation moves, and the cast takes ten
-- seconds where the settle (Clicks.lua) gives a buff half of one. So
-- PostClick hands the press here (Prompt/Press.lua) and files nothing.
-- Whoever was pressed rests, as a block on that one spell (Queue.lua,
-- MarkAttempted): two seconds for the game to answer with a cast, the cast's
-- length once it has, a minute once it has finished (their question to
-- answer), and two seconds once it is seen to fail. Standing up ends it (Tend).
---------------------------------------------------------------------------

local function Rest(pending, seconds)
	for _, name in ipairs(pending.names) do ns.MarkAttempted(name, KEY, seconds) end
	if pending.mass then ns.MarkAttempted(pending.name, MASS_KEY, seconds) end
end

function Res.Pressed(entry)
	-- One press at a time, as for a buff: whatever was still waiting on the
	-- game is let go first (Clicks.lua).
	if ns.AbandonPendingClick then ns.AbandonPendingClick() end
	local names = entry.resNames or { entry.name }
	local pending = { names = names, name = entry.name, at = GetTime(), mass = entry.resNames ~= nil,
		class = entry.class, inGroup = entry.inGroup, reason = entry.reason }
	Res.pending = pending
	for _, name in ipairs(names) do
		rested[name] = entry.resUnits and entry.resUnits[name] or entry.unit or "none"
	end
	Rest(pending, ANSWER_SECONDS)
	Res.active = true
	ns.Trail("press", ("pressed: %s, %s"):format(entry.buff.key, tostring(entry.reason)), entry.name)
	if ns.Prompt and ns.Prompt.StopAttention then ns.Prompt:StopAttention() end
end

local function Repaint()
	if ns.Prompt then ns.Guard("resurrection repaint", ns.Prompt.Refresh, ns.Prompt) end
end

-- The player's own casts, and a resurrection starting or stopping on anybody.
function Res.OnEvent(event, unit, second, third, fourth)
	if event == "INCOMING_RESURRECT_CHANGED" then
		-- Somebody's resurrection began or ended: the prompt lets go of them,
		-- or takes them back, now and not at the next scan.
		local db = addon.db and addon.db.profile
		if db and db.sources.res == true and Info() and not InCombatLockdown() then Repaint() end
		return
	end
	if unit ~= "player" then return end
	local pending = Res.pending
	if not pending then return end
	-- UNIT_SPELLCAST_SENT carries the target before the cast's guid and id.
	local spell, guid
	if event == "UNIT_SPELLCAST_SENT" then
		spell, guid = plain(fourth), plain(third)
	else
		spell, guid = plain(third), plain(second)
	end
	-- A spell the client names that is no resurrection of yours is another
	-- cast's business. One it will not name is taken for the press's own.
	if spell ~= nil and not mineIds[spell] then return end
	local now = GetTime()
	local late = not pending.sent and now - pending.at > ANSWER_SECONDS

	if event == "UNIT_SPELLCAST_SENT" or event == "UNIT_SPELLCAST_START" then
		if late then
			Res.pending = nil
		elseif not pending.sent then
			pending.sent = now
			pending.guid = guid
			Rest(pending, CAST_SECONDS)
		end
		return
	end
	-- The end of another cast of the same spell (the bar macro pressed again
	-- while this one runs is refused under its own guid) says nothing of this
	-- one, where the client names casts at all.
	if pending.guid and guid and guid ~= pending.guid then return end
	if event == "UNIT_SPELLCAST_SUCCEEDED" then
		if not pending.sent then return end
		Res.pending = nil
		Rest(pending, ACCEPT_SECONDS)
		ns.Trail("outcome", "resurrection cast", pending.name)
		-- The cast went its whole length and the game took it: a milestone's
		-- worth (Milestones.lua). A refusal or an interruption comes below.
		if ns.Milestones then ns.Milestones.Note("res") end
		-- The favour ledger, as something given: one row, with how many a
		-- cast for the whole group reached (Ledger.lua, Settled).
		local others
		if pending.mass then
			others = {}
			for i = 2, #pending.names do others[#others + 1] = pending.names[i] end
		end
		ns.TellLedger("Settled", pending.mass and pending.names[1] or pending.name, nil, {
			buffKey = pending.mass and MASS_KEY or KEY, class = pending.class, inGroup = pending.inGroup,
			reason = pending.reason, group = others and { spell = spell, members = others } or nil,
		}, spell or (pending.mass and MASS or SINGLE).info.topRank)
		Repaint()
	else
		-- Refused, or stopped part-way: they are offered again in a moment.
		if late then
			Res.pending = nil
			return
		end
		Res.pending = nil
		Rest(pending, RETRY_SECONDS)
		local why = event == "UNIT_SPELLCAST_INTERRUPTED" and L["the cast was interrupted"] or L["the game refused the cast"]
		ns.Trail("outcome", "resurrection failed: " .. why, pending.name)
		local db = addon.db and addon.db.profile
		if db and db.verbose then
			addon:Print(L["|cffff8080%s was not resurrected|r -- %s."]
				:format(pending.mass and L["Your group"] or (ns.ShortName(pending.name) or pending.name), why))
		end
		Repaint()
	end
end

-- A frame of its own, so the addon's own handlers for the same events stay
-- theirs (Clicks.lua); registered only for a class with a resurrection here,
-- and for the player's casts alone where the client filters by unit.
do
	local frame = CreateFrame("Frame")
	Res.frame = frame
	frame:SetScript("OnEvent", function(_, event, ...) ns.Guard("resurrection", Res.OnEvent, event, ...) end)
	local class = plain(select(2, UnitClass("player")))
	local flavour = ns.Flavour or {}
	local set = SPELLS[flavour.flavour] or (flavour.family == "classic" and SPELLS.vanilla or SPELLS.mainline)
	if class and set[class] then
		for _, event in ipairs({ "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED",
			"UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_FAILED_QUIET", "UNIT_SPELLCAST_INTERRUPTED" }) do
			if type(frame.RegisterUnitEvent) == "function" then
				pcall(frame.RegisterUnitEvent, frame, event, "player")
			else
				pcall(frame.RegisterEvent, frame, event)
			end
		end
		pcall(frame.RegisterEvent, frame, "INCOMING_RESURRECT_CHANGED")
	end
end

---------------------------------------------------------------------------
-- the two wraps
---------------------------------------------------------------------------

-- The probe, and what is learned of a resurrection with it: before anything
-- asks ns.CanCastAnything, which counts one.
do
	local probe = ns.ProbeCapabilities
	function ns.ProbeCapabilities(...)
		local result = probe(...)
		Res.Learn()
		return result
	end
end

-- The queue. The walk hands over the dead it meets (ns.deadSeen: Core.lua,
-- IsBuffableUnit), so a scan with nobody dead pays a few table fields here
-- and no call to the client, whatever the class and the switch.
do
	local Build = ns.BuildQueue
	function ns.BuildQueue(watch)
		local db = addon.db and addon.db.profile
		local info = db and db.sources.res == true and Info() or nil
		for i = #scan, 1, -1 do scan[i] = nil end
		scan.walked, scan.quiet = nil, nil
		ns.deadSeen = info and scan or nil
		local queue, rejected = Build(watch)
		ns.deadSeen = nil
		-- The ordinary scan: nothing learned or switched on, or a walk that
		-- met nobody dead, and nothing left of the scan before to tend.
		if not Res.active and (not info or (scan.walked and #scan == 0)) then return queue, rejected end
		return Res.Offer(db, info, queue, rejected)
	end
end
