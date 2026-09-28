-- Manners -- group buffs: one cast for a whole party in place of the single
-- casts the queue lined up for its members.
--
-- From level 48 to 60 a buffer learns a version of the buff that covers the
-- target's whole party (Prayer of Fortitude, Arcane Brilliance, Gift of the
-- Wild), or for a paladin everybody of the target's class in the raid or
-- party (the Greater Blessings), each for a reagent. When the player knows it,
-- carries the reagent, and enough of one party (or class) are waiting for the
-- single buff, BuildQueue gets one entry for the group cast instead of theirs.
--
-- The entry is aimed at one of them, the anchor, so the macro, the settle and
-- the ledger see a person as they always have. What it adds is `groupCast`:
-- the spell, the reagent, and everybody else the cast covers, which PostClick,
-- the settle and the ledger read. Everybody it covered drops off the prompt
-- the way anybody buffed does: their auras read the buff once it lands.

local ns = select(2, ...)
-- Player-facing text, in the client's language: see Locales/Init.lua.
local L = ns.L
local addon = ns.addon

-- Core.lua's, which loads first.
local plain, safecall = ns.plain, ns.safecall

---------------------------------------------------------------------------
-- the reagent
---------------------------------------------------------------------------

-- How many of an item the player carries, or nil where the client will not
-- say. Both generations of the call, as SpellNameFor asks for a spell's name.
local function ReagentCount(item)
	local count = safecall(C_Item and C_Item.GetItemCount, item)
	if type(count) ~= "number" then count = safecall(_G.GetItemCount, item) end
	if type(count) ~= "number" or count < 0 then return nil end
	return count
end
ns.ReagentCount = ReagentCount

-- The reagent's name for the tooltip and the note, or nil while the client
-- has not loaded the item yet (it answers nil until then, not an error).
local function ReagentName(item)
	local name = safecall(C_Item and C_Item.GetItemNameByID, item)
	if type(name) ~= "string" then name = safecall(_G.GetItemInfo, item) end
	if type(name) ~= "string" or name == "" then return nil end
	return name
end
ns.ReagentName = ReagentName

-- The client's own word on whether the spell can be cast: it says no without
-- the reagent, which checks the pairing in Buffs.lua against the game. Only a
-- definite no that is not about mana counts; the queue already turns away a
-- player with none, and a client that will not say is taken at the table's word.
local function Usable(spellId)
	local check = C_Spell and C_Spell.IsSpellUsable
	if type(check) ~= "function" then check = _G.IsUsableSpell end
	local usable, noMana = safecall(check, spellId)
	return not (usable == false and noMana ~= true)
end

-- Reagents seen in the bags this session, and those whose running out has
-- been said. Said once a session: it is news the first time and nagging after.
local stocked, told = {}, {}

-- The gentle note, the moment the last reagent goes: without it the prompt
-- quietly goes back to one person at a time and looks broken.
local function NoteStock(info, count, db)
	local item = info.groupReagent
	if count and count > 0 then
		stocked[item] = true
		return
	end
	if count ~= 0 or not stocked[item] or told[item] then return end
	told[item] = true
	if not db.verbose then return end
	local single = ns.BuffName(info.buff)
	local what = ReagentName(item)
	if what then
		addon:Print(L["you are out of %s, so the prompt offers %s one person at a time again until you buy more."]
			:format(what, single))
	else
		addon:Print(L["you are out of the reagent %s needs, so the prompt offers %s one person at a time again until you buy more."]
			:format(info.groupName or single, single))
	end
end

---------------------------------------------------------------------------
-- who a cast reaches
---------------------------------------------------------------------------

local TOKENS = { raid = {}, party = {} }
for i = 1, 40 do
	TOKENS.raid[i] = "raid" .. i
	TOKENS.party[i] = "party" .. i
end

-- The raid subgroup a unit is in, or nil where nothing says. A party-wide
-- spell reaches the target's own subgroup of a raid and nobody else in it.
local function RaidSubgroup(unit)
	local index = tonumber(unit:match("^raid(%d+)$")) or plain(UnitInRaid and UnitInRaid(unit))
	if type(index) ~= "number" then return nil end
	local _, _, subgroup = safecall(_G.GetRaidRosterInfo, index)
	if type(subgroup) ~= "number" then return nil end
	return subgroup
end

-- Whether a Greater Blessing for everybody of `class` takes nothing of ours
-- away. Blessings from one paladin replace one another, and the Greater one
-- lands on the whole class, the people the queue never offered included --
-- so one of them carrying another of ours, or unreadable, says no. `offered`
-- is who the queue did offer; their blessing was read already.
local function ClassSafe(class, key, offered, inRaid)
	local n = plain(GetNumGroupMembers and GetNumGroupMembers()) or 0
	local tokens = inRaid and TOKENS.raid or TOKENS.party
	local count = math.min(inRaid and n or (n - 1), 40)
	local mine = ns.GetClassBuffs(ns.PlayerClass()) or {}
	for i = 1, count do
		local unit = tokens[i]
		if plain(UnitExists(unit)) and plain(UnitIsUnit(unit, "player")) ~= true
			and plain(select(2, UnitClass(unit))) == class then
			local name = ns.UnitFullName(unit)
			if not (name and offered[name]) then
				local guid = plain(UnitGUID(unit))
				for _, buff in ipairs(mine) do
					if buff.key ~= key then
						local has, _, ours = ns.UnitHasBuff(unit, buff, guid)
						if has == nil or (has == true and ours ~= false) then return false end
					end
				end
			end
		end
	end
	return true
end

-- The class's name as the game spells it, for "every Warrior".
local function ClassName(class)
	local names = _G.LOCALIZED_CLASS_NAMES_MALE
	local name = type(names) == "table" and plain(names[class]) or nil
	if type(name) == "string" then return name end
	return class:sub(1, 1) .. class:sub(2):lower()
end

---------------------------------------------------------------------------
-- the group cast in the queue
---------------------------------------------------------------------------

-- Who counts towards the threshold: read as missing the buff, or as running
-- out of it (a top-up). A reading nobody could make is not counted -- a reagent
-- spent on people who may be covered is wasted -- though the cast covers them.
local function Counts(entry)
	return entry.known == false or (entry.known == true and entry.remaining ~= nil)
end

-- Which of a party the macro aims at: the one the queue ranks highest, then
-- somebody measured in range, then by name so the choice holds still.
local function Better(a, b)
	if a.priority ~= b.priority then return a.priority < b.priority end
	if (a.ranged == true) ~= (b.ranged == true) then return a.ranged == true end
	return (a.name or "") < (b.name or "")
end

-- The one entry for a bucket that has reached the threshold, or nil. Built on
-- a copy of the anchor's own entry, so everything that reads an entry reads
-- this one the same way.
local function Build(bucket, byClass, inRaid)
	local anchor
	for _, entry in ipairs(bucket.entries) do
		-- Somebody measured out of reach cannot be the target; the cast still
		-- covers them if the game says it does.
		if entry.ranged ~= false and (not anchor or Better(entry, anchor)) then anchor = entry end
	end
	if not anchor then return nil end

	if byClass then
		local offered = {}
		for _, entry in ipairs(bucket.entries) do
			-- Unread, they may carry another blessing of ours that this replaces.
			if entry.known == nil then return nil end
			offered[entry.name] = true
		end
		if not ClassSafe(bucket.where, bucket.buff.key, offered, inRaid) then return nil end
	end

	local members, priority = {}, anchor.priority
	for _, entry in ipairs(bucket.entries) do
		if entry ~= anchor then members[#members + 1] = entry.name end
		if entry.priority < priority then priority = entry.priority end
	end

	local info = bucket.ready.info
	local group = {}
	for field, value in pairs(anchor) do group[field] = value end
	-- The best of them: a favour owed in the party lifts the whole cast.
	group.priority = priority
	group.groupCast = {
		spell = info.groupRank,
		spellName = info.groupName or ns.BuffName(bucket.buff),
		icon = info.groupIcon,
		reagent = info.groupReagent,
		reagents = bucket.ready.have,
		missing = bucket.missing,
		-- Everybody else the queue had lined up that this covers, by name.
		members = members,
		class = byClass and bucket.where or nil,
	}
	-- What the panel's first line says in place of the anchor's name.
	if byClass then
		group.display = L["every %s"]:format(ClassName(bucket.where))
	else
		group.display = L["%s's party"]:format(anchor.short or anchor.name or "?")
	end
	return group
end

-- The queue with the single casts a group cast replaces taken out and the
-- group cast put in. `candidates` is CastableBuffs' answer for this scan.
-- Nothing changes unless the setting is on, "My party and raid" is on (the
-- cast lands on the whole party, so it is for players offering their party),
-- and a buff has its group version learned, stocked and usable.
function ns.GroupCasts(queue, db, candidates, inRaid)
	local settings = db.groupBuffs
	if not (settings and settings.use == true and db.sources.group) then return queue end
	local atLeast = tonumber(settings.atLeast) or 3

	local ready
	for _, buff in ipairs(candidates) do
		local info = ns.BuffInfo(buff)
		if info and info.groupRank and info.groupReagent then
			local have = ReagentCount(info.groupReagent)
			NoteStock(info, have, db)
			if have and have > 0 and Usable(info.groupRank) then
				ready = ready or {}
				ready[buff.key] = { info = info, have = have }
			end
		end
	end
	if not ready then return queue end

	local byClass = ns.GROUP_BY_CLASS[ns.PlayerClass()] == true
	local buckets, order = {}, {}
	for _, entry in ipairs(queue) do
		local buff = entry.buff
		local r = buff and ready[buff.key]
		-- Only people read through a unit token in the group: the tokenless
		-- favours have no party anybody can name.
		if r and entry.unit and entry.inGroup then
			local where
			if byClass then
				where = entry.class
			elseif inRaid then
				where = RaidSubgroup(entry.unit)
			else
				where = "party"
			end
			if where then
				local key = buff.key .. "\0" .. tostring(where)
				local bucket = buckets[key]
				if not bucket then
					bucket = { entries = {}, missing = 0, ready = r, buff = buff, where = where }
					buckets[key] = bucket
					order[#order + 1] = bucket
				end
				bucket.entries[#bucket.entries + 1] = entry
				if Counts(entry) then bucket.missing = bucket.missing + 1 end
			end
		end
	end

	local absorbed, made
	for _, bucket in ipairs(order) do
		if bucket.missing >= atLeast then
			local group = Build(bucket, byClass, inRaid)
			if group then
				absorbed = absorbed or {}
				made = made or {}
				for _, entry in ipairs(bucket.entries) do absorbed[entry] = true end
				made[#made + 1] = group
			end
		end
	end
	if not made then return queue end

	local out = {}
	for _, entry in ipairs(queue) do
		if not absorbed[entry] then out[#out + 1] = entry end
	end
	for _, group in ipairs(made) do out[#out + 1] = group end
	return out
end

-- The spell an entry's macro casts: the group version's own name for a group
-- cast. Everything that names the spell about to go out asks this.
function ns.EntrySpellName(entry)
	if entry and entry.groupCast and entry.groupCast.spellName then return entry.groupCast.spellName end
	-- BuffName's own answer otherwise, "?" for no buff at all included.
	return ns.BuffName(entry and entry.buff)
end

-- Whether this character has a group version of any of its buffs in the
-- data at all, learned or not, so the options page shows the setting only
-- to classes it means something to.
function ns.ClassHasGroupBuffs()
	for _, buff in ipairs(ns.GetClassBuffs(ns.PlayerClass()) or {}) do
		if buff.groupCast then return true end
	end
	return false
end
