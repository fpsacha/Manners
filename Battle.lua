-- Manners -- battlegrounds and arenas, a situation of their own.
--
-- A player wrote that in a battleground, after each death, the prompt reminded
-- him of Find Minerals and not of his class's buff. Tracking is quiet there
-- since (Core.lua, OwnVerdict: "battle"); this file is the rest of what a
-- battleground or an arena changes, behind the four switches of When to
-- offer's "In battlegrounds and arenas" (db.battle):
--
--   team   (on)   your team is offered your buffs there. Off, nobody else is,
--                 as with Offer nothing in dungeons, raids and battlegrounds:
--                 somebody you target or focus still is (until Hold back my
--                 target and focus too is ticked), your own buffs too.
--   speak  (off)  the line said with a cast is said there too.
--   thank  (on)   the /thank and the whispered thank-you go there too, to
--                 somebody of your own team and nobody else.
--   items  (off)  what Consumables only in dungeons and raids holds back comes
--                 up there as it does in a dungeon.
--
-- And three states, read once a scan (Battle.State):
--
--   "prep"   the gates are shut (the Preparation aura is on you): a cast costs
--            nothing, so the mana floor holds nobody back, every raid group is
--            offered, and a group cast comes ahead of everything but your
--            target.
--   "fight"  the gates are open and you are in combat: nobody else is offered,
--            so the prompt holds no team-mate's macro through the fight.
--   "open"   the gates are open and you are not: your team is offered, and only
--            somebody a token names who is not measured out of range.
--
-- In all three, what you are missing of your own comes ahead of the team's
-- (Battle.Rank), what you fight with before the long extras -- food, flasks,
-- scrolls, an oil or a stone, a companion pet -- and what is missing before
-- what only runs low (Battle.OwnPick): after a graveyard's resurrection the
-- people it raised beside you were all "back from the dead" and stood ahead of
-- your own armor.
--
-- How it meets Offer nothing in dungeons, raids and battlegrounds
-- (filters.quietInInstances): inside a battleground or an arena `team` alone
-- decides. Ticking that switch unticks `team` (Options/Who.lua), and a profile
-- that had it ticked before this section existed has `team` unticked once
-- (Battle.Carry), so nobody who asked for silence there loses it.
--
-- Nothing here is read outside a battleground or an arena.

local _, ns = ...
local L = ns.L
local addon = ns.addon
local plain, safecall = ns.plain, ns.safecall
local GetTime = _G.GetTime
local InCombatLockdown = _G.InCombatLockdown

local Battle = {}
ns.Battle = Battle

-- Where the entries this file ranks go (Queue.lua, PRIORITY: your target 0, a
-- ready check or a death 0.5, a favour 1, a request 1.5, yourself 1.75, your
-- group 2, passers-by 3).
Battle.GROUP_FIRST = 0.3
Battle.SELF_FIRST = 0.4
Battle.EXTRAS = 2.5

-- The aura everybody wears while a battleground's or an arena's gates are
-- shut, by spell id, from each client's own SpellName and SpellEffect (the
-- builds CLAUDE.md cites): it takes the whole cost off every spell (aura 72,
-- -100). Classic Era 1.15.9.70003 and Forever 1.60.1.70790 have one,
-- Preparation 422621; Burning Crusade 2.5.6.69795, Mists 5.5.4.70032 and
-- retail 12.1.0.69933 have the battleground's Preparation 44521 and the
-- arena's Arena Preparation, 32727 and its area form 32728. A client nobody
-- has named is asked about them all: an id it lacks reads as no aura.
Battle.PREPARATION = {
	camelot = { 422621 },
	vanilla = { 422621 },
	tbc = { 44521, 32727, 32728 },
	mists = { 44521, 32727, 32728 },
	mainline = { 44521, 32727, 32728 },
}
local PREPARATION = Battle.PREPARATION[ns.Flavour and ns.Flavour.flavour]
	or { 422621, 44521, 32727, 32728 }

---------------------------------------------------------------------------
-- where you are, and which of the three states
---------------------------------------------------------------------------

-- In a battleground or an arena, by the game's word, kept for HOLD seconds:
-- it changes only across a loading screen, and the scan asks every 0.4 s. A
-- client that will not say (a throw, a secret, no kind) is in none.
-- Protected only until it has answered once: the game's own function takes
-- nothing and, having answered, does not throw the next time, so a scan
-- outside a battleground pays no protected call for this. Another function
-- in its place (`answered` is the one that did) is protected afresh.
local HOLD = 2
local where = { at = nil, battle = false }
local answered
local function Where(now)
	local at = where.at
	if at and now >= at and now - at < HOLD then return where.battle end
	local ask = _G.IsInInstance
	local inside, kind
	if type(ask) ~= "function" then
		inside, kind = nil, nil
	elseif ask == answered then
		inside, kind = ask()
		inside, kind = plain(inside), plain(kind)
	else
		inside, kind = safecall(ask)
		-- Answered, whatever it said: a throw leaves both nil.
		if inside ~= nil or kind ~= nil then answered = ask end
	end
	where.at = now
	where.battle = (inside == true or inside == 1) and (kind == "pvp" or kind == "arena")
	return where.battle
end

-- Whether the gates are still shut: the Preparation aura on you, read once
-- for each moment asked about. A restricted read, so each has its pcall; a
-- refusal is no aura, which leaves the stricter rules of the open gates.
local prep = { at = nil, on = false }
local function Preparing(now)
	if prep.at == now then return prep.on end
	prep.at, prep.on = now, false
	local api = _G.C_UnitAuras
	local byId = api and api.GetUnitAuraBySpellID
	if type(byId) ~= "function" then return false end
	for i = 1, #PREPARATION do
		local ok, aura = pcall(byId, "player", PREPARATION[i])
		if ok and type(plain(aura)) == "table" then
			prep.on = true
			break
		end
	end
	return prep.on
end

-- In combat, as "Myself" reads it (Queue.lua, HeldBackExceptList): the
-- lockdown, or the flag the pull's own repaint finds up just before it.
local function Fighting()
	if InCombatLockdown() then return true end
	local affecting = _G.UnitAffectingCombat
	return type(affecting) == "function" and plain(affecting("player")) == true
end

-- nil anywhere but a battleground or an arena; there "prep", "fight" or
-- "open" (the top of this file).
function Battle.State(now)
	now = now or GetTime()
	if not Where(now) then return nil end
	if Preparing(now) then return "prep" end
	if Fighting() then return "fight" end
	return "open"
end

-- One of the four switches. A profile with no section yet reads as the
-- defaults do.
function Battle.On(key)
	local db = addon.db and addon.db.profile
	local battle = db and db.battle
	if type(battle) ~= "table" then
		local defaults = ns.defaults and ns.defaults.profile and ns.defaults.profile.battle
		return defaults ~= nil and defaults[key] == true
	end
	return battle[key] == true
end

---------------------------------------------------------------------------
-- the queue (Queue.lua, BuildQueue and SelfEntry)
---------------------------------------------------------------------------

-- Only somebody within reach: nobody measured out of range, whatever Only in
-- range says, and nobody no token names (a favour's giver or a passer-by
-- remembered, who may be anywhere). Whoever the walk kept for a group cast's
-- reach alone stays for the fold to judge. Each one dropped is a verdict.
function Battle.Reach(queue, rejected)
	local out
	for i = 1, #queue do
		local entry = queue[i]
		local far = not entry.foldOnly and (entry.unit == nil or entry.ranged == false)
		if far then
			if not out then
				out = {}
				for j = 1, i - 1 do out[j] = queue[j] end
			end
			if entry.name then rejected[entry.name] = true end
		elseif out then
			out[#out + 1] = entry
		end
	end
	return out or queue
end

-- Before the gates open a cast costs nothing, so one press for a whole party
-- comes ahead of every single one.
function Battle.GroupFirst(queue)
	for i = 1, #queue do
		local entry = queue[i]
		if entry.groupCast and entry.priority > Battle.GROUP_FIRST then entry.priority = Battle.GROUP_FIRST end
	end
end

-- Whether a family of your own is one of the long extras: what comes out of
-- the bags (food, the sleeping bag, a flask, an elixir, a scroll, a companion
-- pet), an oil or a stone for the weapon, a fishing lure. Everything else is
-- what you fight with: an armor, a shield, an aspect, a form, a poison.
local function Extra(family)
	if not family then return false end
	return family.bagged == true or family.kind == "lure" or ns.OwnItemsHeldToDungeons(family)
end
Battle.Extra = Extra

-- Your class's own buff to offer in a battleground or an arena, as OwnPick
-- (Queue.lua) answers anywhere else, in another order: of what you fight
-- with, the first family missing, then the first running low; only then the
-- extras, in the table's order. `held`: your group buff is running low and is
-- already the offer, which only something you fight with and are missing
-- comes ahead of.
function Battle.OwnPick(db, full, now, held)
	local ctx = { name = full, now = now, whenBuffed = ns.SelfWhenBuffed(db.filters),
		refreshUnder = db.filters.refreshUnder }
	local apart = ns.ItemsApart(db)
	local families = ns.KnownOwnFamilies()
	local low, lowHas, lowRemaining, lowCharges, lowSeconds, lowLead, lowKind
	for pass = 1, 2 do
		for _, family in ipairs(families) do
			if (pass == 2) == Extra(family) and not (apart and ns.ItemFamily(family)) then
				local spell, has, remaining, _, _, charges, seconds, lead, kind = ns.OwnVerdict(family, ctx)
				if spell and (pass == 2 or has == false) then
					return spell, has, remaining, charges, seconds, lead, kind
				elseif spell and not low then
					low, lowHas, lowRemaining, lowCharges, lowSeconds, lowLead, lowKind
						= spell, has, remaining, charges, seconds, lead, kind
				end
			end
		end
		if held then return nil end
		if low then return low, lowHas, lowRemaining, lowCharges, lowSeconds, lowLead, lowKind end
	end
	return nil
end

-- Where your own entry stands there: what you fight with and are missing
-- ahead of everybody but your target, the long extras behind your team. A
-- top-up keeps its place with the group (SelfEntry).
function Battle.Rank(entry)
	local buff = entry.buff
	if buff and Extra(buff.family) then
		entry.priority = Battle.EXTRAS
	elseif entry.known == false then
		entry.priority = Battle.SELF_FIRST
	end
end

---------------------------------------------------------------------------
-- what is said, who is thanked, what comes out of the bags
---------------------------------------------------------------------------

-- Whether the line said with a cast is kept back: in a battleground or an
-- arena, with Say my line there off (Speech.lua, ns.ChannelOpen).
function Battle.Quiet()
	return Where(GetTime()) and not Battle.On("speak")
end

-- A /thank or a whispered thank-you for a favour there (Favours.lua, Held):
-- nil anywhere else, which leaves the rule for an instance to answer; true
-- when it may go; or why not, as the skip is written down. Asked afresh, a
-- thank being rare, of the place it is about to be made in.
function Battle.Thanks(seen)
	local inside, kind = safecall(_G.IsInInstance)
	if not ((inside == true or inside == 1) and (kind == "pvp" or kind == "arena")) then return nil end
	if not Battle.On("thank") then return L["thanks are off in battlegrounds"] end
	if not (type(seen) == "table" and seen.inGroup == true) then
		return L["not on your team, in a battleground"]
	end
	return true
end

-- Whether a battleground or an arena counts as a dungeon for Consumables
-- only in dungeons and raids (Core.lua, OwnVerdict).
function Battle.ItemsThere()
	return Battle.On("items") and Where(GetTime())
end

---------------------------------------------------------------------------
-- settings carried over, and /manners debug
---------------------------------------------------------------------------

-- Offer nothing in dungeons, raids and battlegrounds held a battleground too
-- until this section decided there: a profile that has it ticked keeps its
-- silence, `team` unticked once. `carried` is no setting: it is in no
-- default, so it is never shared, reset or shown.
function Battle.Carry(profile)
	local battle = type(profile) == "table" and profile.battle
	if type(battle) ~= "table" or battle.carried == true then return end
	battle.carried = true
	local filters = profile.filters
	if type(filters) == "table" and filters.quietInInstances == true then battle.team = false end
end

-- A settings string pasted (Commands.lua, ApplySettings): `carried` is not
-- in it, so one made before this section, with that switch ticked, would
-- put `team` back on over a profile carried long ago. A string that has
-- the switch on and does not name `team` is carried as such a profile is;
-- one made since names `team` beside that switch (Battle.Shared).
function Battle.CarryPasted(profile, values)
	if type(profile) ~= "table" or type(values) ~= "table" then return end
	if values["filters.quietInInstances"] ~= true or values["battle.team"] ~= nil then return end
	if type(profile.battle) ~= "table" then profile.battle = {} end
	profile.battle.team = false
end

-- Whether a settings string has to name `team` although it is the default:
-- on beside that switch, which a string from before this section never is.
function Battle.Shared(profile)
	local battle, filters = profile.battle, profile.filters
	return type(battle) == "table" and battle.team == true
		and type(filters) == "table" and filters.quietInInstances == true
end

-- For /manners debug and the check-up: nothing outside a battleground or an
-- arena; there the state, and each switch that is holding something back.
function Battle.Lines(now)
	local out = {}
	local state = Battle.State(now)
	if not state then return out end
	local db = addon.db and addon.db.profile
	if not db then return out end
	local function name(text) return "|cffffd100" .. text .. "|r" end
	if not Battle.On("team") and type(db.filters) == "table" and db.filters.quietTargets == true then
		-- Hold back my target and focus too reaches here (Queue.lua, inTown).
		out[#out + 1] = L["|cffffd100battleground|r -- %s is off: nobody else is offered here, not even your target or focus (%s)"]
			:format(name(L["Buff my team there"]), name(L["Hold back my target and focus too"]))
	elseif not Battle.On("team") then
		out[#out + 1] = L["|cffffd100battleground|r -- %s is off: nobody but your target or focus is offered here"]
			:format(name(L["Buff my team there"]))
	elseif state == "prep" then
		out[#out + 1] = L["|cffffd100battleground|r -- the gates are shut: your team is offered freely, group casts first"]
	elseif state == "fight" then
		out[#out + 1] = L["|cffffd100battleground|r -- you are in a fight: nobody else is offered until it ends"]
	else
		out[#out + 1] = L["|cffffd100battleground|r -- your team is offered while you are out of combat, and only within reach"]
	end
	if db.speech and db.speech.enabled == true and not Battle.On("speak") then
		out[#out + 1] = L["|cffffd100battleground|r -- nothing is said here: %s is off"]:format(name(L["Say my line there"]))
	end
	if db.prompt and (db.prompt.thankEmote == true or db.prompt.thankWhisper == true) and not Battle.On("thank") then
		out[#out + 1] = L["|cffffd100battleground|r -- nobody is thanked here: %s is off"]:format(name(L["Thank people there"]))
	end
	if db.ownBuffs and db.ownBuffs.itemsInDungeons == true and not Battle.On("items") then
		out[#out + 1] = L["|cffffd100battleground|r -- consumables wait here: %s is off"]:format(name(L["Consumables there too"]))
	end
	return out
end
