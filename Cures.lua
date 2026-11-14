-- Manners -- curing other people, out of combat.
--
-- A poison, a disease, a curse or a harmful spell on somebody the walk reaches
-- (Queue.lua, visit) is offered its cure on the prompt, by the usual press:
-- /target <name>, /cast <spell>, the hand-back. Two switches on Who to buff,
-- both off until ticked: sources.cures for your party and raid, and
-- sources.curesStrangers for passers-by. They stand apart from the buff
-- switches beside them: a group with "My party and raid" off is still cured,
-- and a class with a cure and no buff for anybody else (a shaman on Classic
-- Era) still has the walk.
--
-- What is offered:
--   - only a kind your class has a spell for on this client, and knows (the
--     tables below, each client's own spell data);
--   - only a debuff the client says is of that kind (the aura's dispelName)
--     and, where the client says so, one you can remove
--     (canActivePlayerDispel);
--   - only with more than filters.cureSeconds left (10), so the press is worth
--     it; a debuff with no timer is never offered, since nothing says it has
--     any left and an area's aura comes straight back;
--   - never a debuff on the deny list (DENY);
--   - never in a fight, your own or the pull's repaint that arms a fight's
--     macro: the client withholds every aura there anyway;
--   - never to somebody you owe a favour, whose buff back comes first, nor to
--     a group member's pet.
--
-- A cure takes the person's one place in the queue, so it comes before a buff
-- for them, and ranks below a favour owed and above everything else unasked
-- (PRIORITY). The press is filed as a cure: no favour settled, nothing in the
-- ledger, no line said (the hooks in Clicks.lua, Prompt/Press.lua, Speech.lua).
--
-- Cost. Nothing here is asked with both switches off. With one on, each
-- person who passes the walk's own tests has their harmful auras read through
-- C_UnitAuras, in one protected call a reading, kept three seconds a person
-- as the buff read keeps its own (Core.lua, READING_SECONDS) and dropped at
-- UNIT_AURA for them (Favours.lua).

local _, ns = ...
local L = ns.L
local addon = ns.addon
local plain, caps = ns.plain, ns.caps
local GetTime, InCombatLockdown = _G.GetTime, _G.InCombatLockdown
-- Read at load, as ns.plain reads it: absent on a client that never had secrets.
local issecretvalue = _G.issecretvalue

local Cures = {}
ns.Cures = Cures

---------------------------------------------------------------------------
-- the spells, per client
--
-- Each row is one spell: its ranks, highest first, and the kinds it removes,
-- by the client's own word for them (an aura's dispelName: "Magic", "Curse",
-- "Disease", "Poison"). A kind written with a number is removed only while
-- that passive is known. A class's rows are in the order they are preferred:
-- the first known spell that removes a kind is the one offered for it.
--
-- Every id, kind and passive is the client's own spell data (wago.tools,
-- SpellEffect: effect 38, Dispel, with the kind in EffectMiscValue and a
-- friendly target in ImplicitTarget; SpellName; Spell for the conditions),
-- read at the builds CLAUDE.md cites: Forever 1.60.1.70790, Classic Era
-- 1.15.9.70003, Burning Crusade 2.5.6.69795, Mists 5.5.4.70032, retail
-- 12.1.0.69933. Spells that dispel an area (Mass Dispel), that a pet casts
-- (Singe Magic) or that sit on a minute's cooldown (Cauterizing Flame) are
-- left out.
---------------------------------------------------------------------------

-- Classic Era, Forever and Burning Crusade: the same rows in all three. The
-- plain cure comes before the Abolish of its kind: gone at once for less
-- mana, and the reading a moment later is true, where Abolish works over
-- seconds; Abolish stands in for whoever knows it alone.
local OLD = {
	DRUID = {
		{ ranks = { 8946 }, kinds = { Poison = true } }, -- Cure Poison (14)
		{ ranks = { 2893 }, kinds = { Poison = true } }, -- Abolish Poison (26)
		{ ranks = { 2782 }, kinds = { Curse = true } }, -- Remove Curse (24)
	},
	MAGE = {
		{ ranks = { 475 }, kinds = { Curse = true } }, -- Remove Lesser Curse (18)
	},
	PALADIN = {
		{ ranks = { 4987 }, kinds = { Poison = true, Disease = true, Magic = true } }, -- Cleanse (42)
		{ ranks = { 1152 }, kinds = { Poison = true, Disease = true } }, -- Purify (8)
	},
	PRIEST = {
		{ ranks = { 528 }, kinds = { Disease = true } }, -- Cure Disease (14)
		{ ranks = { 552 }, kinds = { Disease = true } }, -- Abolish Disease (32)
		-- Dispel Magic (18, 36): one spell for a friend's harmful magic and an
		-- enemy's helpful (target 25, any unit).
		{ ranks = { 988, 527 }, kinds = { Magic = true } },
	},
	SHAMAN = {
		{ ranks = { 526 }, kinds = { Poison = true } }, -- Cure Poison (16)
		{ ranks = { 2870 }, kinds = { Disease = true } }, -- Cure Disease (22)
	},
}

-- Mists of Pandaria. A specialization's spell is known only in it, which the
-- probe reads. Cleanse and Detox take Magic off only with their passive (the
-- client's own description: "$?s53551[...Poison, Disease and Magic...]").
local MISTS = {
	MAGE = {
		{ ranks = { 475 }, kinds = { Curse = true } }, -- Remove Curse
	},
	PRIEST = {
		{ ranks = { 527 }, kinds = { Magic = true, Disease = true } }, -- Purify (Discipline, Holy)
	},
	DRUID = {
		{ ranks = { 88423 }, kinds = { Magic = true, Curse = true, Poison = true } }, -- Nature's Cure (Restoration)
		{ ranks = { 2782 }, kinds = { Curse = true, Poison = true } }, -- Remove Corruption
	},
	PALADIN = {
		-- Cleanse; Magic with Sacred Cleansing (Holy, 53551).
		{ ranks = { 4987 }, kinds = { Poison = true, Disease = true, Magic = 53551 } },
	},
	SHAMAN = {
		{ ranks = { 77130 }, kinds = { Curse = true, Magic = true } }, -- Purify Spirit (Restoration)
		{ ranks = { 51886 }, kinds = { Curse = true } }, -- Cleanse Spirit
	},
	MONK = {
		-- Detox; Magic with Internal Medicine (Mistweaver, 115451).
		{ ranks = { 115450 }, kinds = { Poison = true, Disease = true, Magic = 115451 } },
	},
}

-- Retail. A healer's cure takes Magic off, and its other kinds only with the
-- talent that improves it (those effects read 0 in the spell data until it is
-- taken: Improved Purify 390632, Improved Nature's Cure 392378, Improved
-- Cleanse 393024, Improved Purify Spirit 383016, Improved Detox 388874).
local MAINLINE = {
	MAGE = {
		{ ranks = { 475 }, kinds = { Curse = true } }, -- Remove Curse
	},
	PRIEST = {
		{ ranks = { 527 }, kinds = { Magic = true, Disease = 390632 } }, -- Purify (Discipline, Holy)
		{ ranks = { 213634 }, kinds = { Disease = true } }, -- Purify Disease (Shadow)
	},
	DRUID = {
		{ ranks = { 88423 }, kinds = { Magic = true, Curse = 392378, Poison = 392378 } }, -- Nature's Cure (Restoration)
		{ ranks = { 2782 }, kinds = { Curse = true, Poison = true } }, -- Remove Corruption
	},
	PALADIN = {
		{ ranks = { 4987 }, kinds = { Magic = true, Poison = 393024, Disease = 393024 } }, -- Cleanse (Holy)
		{ ranks = { 213644 }, kinds = { Poison = true, Disease = true } }, -- Cleanse Toxins
	},
	SHAMAN = {
		{ ranks = { 77130 }, kinds = { Magic = true, Curse = 383016 } }, -- Purify Spirit (Restoration)
		{ ranks = { 51886 }, kinds = { Curse = true } }, -- Cleanse Spirit
	},
	MONK = {
		{ ranks = { 115450 }, kinds = { Magic = true, Poison = 388874, Disease = 388874 } }, -- Detox (Mistweaver)
		{ ranks = { 218164 }, kinds = { Poison = true, Disease = true } }, -- Detox (Brewmaster, Windwalker)
	},
	EVOKER = {
		{ ranks = { 360823 }, kinds = { Magic = true, Poison = true } }, -- Naturalize (Preservation)
		{ ranks = { 365585 }, kinds = { Poison = true } }, -- Expunge
	},
}

-- By ns.Flavour.flavour. A client no band named has no table and no cures:
-- nothing here is guessed from a family.
local SETS = { camelot = OLD, vanilla = OLD, tbc = OLD, mists = MISTS, mainline = MAINLINE }

---------------------------------------------------------------------------
-- debuffs never removed
--
-- By the debuff's spell id, per client: what must not be removed, or cannot
-- usefully be. Each id is that client's own (SpellName at the builds above).
---------------------------------------------------------------------------

local DENY = {
	camelot = {
		-- Unstable Affliction (the rune's, and Forever's two further ranks):
		-- "if the Unstable Affliction is dispelled it will cause ... damage to
		-- the dispeller and silence them".
		[427717] = true, [1242971] = true, [1242972] = true,
		-- Mutating Injection (Grobbulus): it leaves a poison cloud where its
		-- wearer stands when it goes, so the raid chooses that moment and place.
		[28169] = true,
		-- Delusions of Jin'do: the curse is what lets its wearer see and kill
		-- the shades, and is wanted.
		[24306] = true,
	},
	vanilla = {
		[427717] = true, -- Unstable Affliction (Season of Discovery's rune), as above
		[28169] = true, -- Mutating Injection, as above
		[24306] = true, -- Delusions of Jin'do, as above
	},
	tbc = {
		-- Unstable Affliction, ranks 1 to 3: damage and a silence for whoever
		-- dispels it.
		[30108] = true, [30404] = true, [30405] = true,
		[28169] = true, -- Mutating Injection, as above
		[24306] = true, -- Delusions of Jin'do, as above
	},
	mists = {
		[30108] = true, -- Unstable Affliction: damage and a silence for whoever dispels it
		-- Vampiric Touch: with Sin and Punishment (131556) "the dispeller is
		-- instantly feared in horror".
		[34914] = true,
	},
	mainline = {
		-- Unstable Affliction, both of the casts retail has: "If dispelled,
		-- deals ... damage to the dispeller and silences them for 4 sec."
		[1259790] = true, [1219045] = true,
		-- Vampiric Touch: "If Vampiric Touch is dispelled, the dispeller flees
		-- in Horror for 3 sec."
		[34914] = true,
	},
}

local flavour = ns.Flavour and ns.Flavour.flavour
local SET = SETS[flavour]
local DENIED = DENY[flavour] or {}

---------------------------------------------------------------------------
-- the cures, as the queue reads them
--
-- One object per spell and kind, shaped as a buff is (Buffs.lua) so the
-- prompt, the macro, the range check and the press read it as they read any
-- entry's `buff`: key, ranks, auraIds (none: a cure leaves no aura to match).
-- `cure` is the kind, and what marks it: ns.BuffInfo answers for it from here
-- (ns.CureInfo). `alone`: it lands on its target alone, on the sets whose
-- buffs reach the whole party.
---------------------------------------------------------------------------

-- [class] = { cure, ... } in the rows' order.
local CURES = {}
-- The kinds in the order a list of them is said.
local KINDS = { "Magic", "Curse", "Disease", "Poison" }

for class, rows in pairs(SET or {}) do
	local list = {}
	for _, row in ipairs(rows) do
		for _, kind in ipairs(KINDS) do
			local needs = row.kinds[kind]
			if needs then
				list[#list + 1] = {
					key = "cure:" .. kind:lower(),
					cure = kind,
					ranks = row.ranks,
					auraIds = {},
					alone = true,
					class = class,
					needs = type(needs) == "number" and needs or nil,
				}
			end
		end
	end
	CURES[class] = list
end

-- A cure's place in the queue: below a favour owed (1), above somebody who
-- asked (1.5), yourself, your group and passers-by (Queue.lua, PRIORITY).
local PRIORITY = 1.25
Cures.PRIORITY = PRIORITY

-- The kinds in words: a list of what you can cure, and the prompt's reason
-- line for somebody under one.
local KIND_LABEL = {
	Magic = L["Magic"],
	Curse = L["Curse"],
	Disease = L["Disease"],
	Poison = L["Poison"],
}
local KIND_REASON = {
	Magic = L["Under a spell"],
	Curse = L["Cursed"],
	Disease = L["Diseased"],
	Poison = L["Poisoned"],
}

-- Whether this class has a cure on this client at all, learned or not: the
-- options page shows its controls for nobody else.
function ns.ClassHasCures()
	local class = caps.class
	return class ~= nil and CURES[class] ~= nil
end

local NOTHING = { byKind = {}, list = {}, any = false }

-- What this character can cure, per probe: caps is emptied by every probe
-- (Core.lua, ProbeCapabilities), so the answer kept on it is asked again after
-- one. byKind[kind] is the cure offered for that kind, `list` those cures in
-- the rows' order, `any` whether there is one.
local function State()
	local state = caps.cures
	if state then return state end
	local class = caps.class
	-- Before the first probe there is no class to answer for, and nothing kept.
	if not class then return NOTHING end
	state = { byKind = {}, list = {}, any = false }
	for _, cure in ipairs(CURES[class] or {}) do
		local info = { key = cure.key, buff = cure, unresolved = {}, secrecy = {} }
		for _, id in ipairs(cure.ranks) do
			if ns.SpellKnown(id) then
				info.known = true
				info.topRank = info.topRank or id
			end
		end
		-- Named as a buff is (Core.lua, ProbeBuff): by the best rank known, and
		-- known only with a name the macro can cast by.
		local named = info.topRank or cure.ranks[1]
		info.name = ns.SpellNameFor(named)
		info.icon = ns.safecall(C_Spell and C_Spell.GetSpellTexture, named)
		info.known = info.known == true and info.name ~= nil
		cure.info = info
		if info.known and not state.byKind[cure.cure] and (not cure.needs or ns.SpellKnown(cure.needs)) then
			state.byKind[cure.cure] = cure
			state.list[#state.list + 1] = cure
			state.any = true
		end
	end
	caps.cures = state
	return state
end

-- ns.BuffInfo's answer for a cure (Core.lua): its name, icon and best rank.
function ns.CureInfo(cure)
	State()
	return cure.info
end

-- "Cleanse (Magic, Disease, Poison), Purify (Disease, Poison)": what this
-- character cures with what, for the options page and /manners debug. nil
-- with nothing learned.
local function Summary()
	local state = State()
	if not state.any then return nil end
	-- By spell, which is its ranks: a row's kinds share the one table.
	local spells, kindsOf = {}, {}
	for _, cure in ipairs(state.list) do
		local spell = cure.ranks
		if not kindsOf[spell] then
			kindsOf[spell] = {}
			spells[#spells + 1] = cure
		end
		kindsOf[spell][#kindsOf[spell] + 1] = KIND_LABEL[cure.cure]
	end
	local parts = {}
	for _, cure in ipairs(spells) do
		parts[#parts + 1] = ("%s (%s)"):format(cure.info.name, table.concat(kindsOf[cure.ranks], ", "))
	end
	return table.concat(parts, ", ")
end

-- The note under the options page's heading.
function ns.CureSummary()
	local list = Summary()
	if not list then return L["You have not learned a cure yet."] end
	return L["Your cures: %s."]:format(list)
end

-- Whether a cure switch is on and there is a cure to offer: the scan walks
-- for it with no buff in hand (Queue.lua, BuildQueue), and a class with
-- nothing else learned has a prompt for it (Core.lua, ns.CanCastAnything).
-- Two reads of the profile with both switches off.
function ns.CuresWanted(db)
	db = db or (addon.db and addon.db.profile)
	local sources = db and db.sources
	if not (sources and (sources.cures == true or sources.curesStrangers == true)) then return false end
	return State().any
end

---------------------------------------------------------------------------
-- the scan's answers
---------------------------------------------------------------------------

-- What a scan is told once (ns.CureScan) and hands back for everybody it
-- walks: one table, written again each scan.
local scan = { ready = {} }

-- Who the last scan left alone, and why, for /manners debug: a handful.
local left = { names = {}, what = {}, why = {}, seconds = 0 }
local LEFT_MAX = 6

local function Leave(name, debuff, why)
	if left.why[name] or #left.names >= LEFT_MAX then return end
	left.names[#left.names + 1] = name
	left.what[name], left.why[name] = debuff, why
end

-- In a fight: yours, or the repaint the pull makes just before the lockdown,
-- whose macro every press of the fight runs (Core.lua, PLAYER_REGEN_DISABLED).
local function Fighting()
	if InCombatLockdown() then return true end
	local prompt = ns.Prompt
	if prompt and prompt.armedForFight == true then return true end
	local affecting = _G.UnitAffectingCombat
	return type(affecting) == "function" and plain(affecting("player")) == true
end

-- Asked by BuildQueue once a scan, before the walk: what the walk's hook needs
-- (`group` and `strangers`, the two switches), or nil when no cure is to be
-- offered at all: both switches off, nothing learned, a fight, or a client
-- with no aura list to read. `fight` stays written for /manners debug.
function ns.CureScan(db, now)
	local sources = db.sources
	if not (sources.cures == true or sources.curesStrangers == true) then return nil end
	local state = State()
	if not state.any then return nil end
	for i = #left.names, 1, -1 do left.names[i] = nil end
	wipe(left.what)
	wipe(left.why)
	scan.fight = Fighting()
	if scan.fight then return nil end
	local auras = C_UnitAuras
	if not (type(auras) == "table" and type(auras.GetAuraDataByIndex) == "function") then return nil end
	scan.group, scan.strangers = sources.cures == true, sources.curesStrangers == true
	local seconds = tonumber(db.filters.cureSeconds)
	scan.seconds = seconds or 10
	left.seconds = scan.seconds
	scan.requireInRange = db.filters.requireInRange == true
	scan.owed = sources.owed == true
	scan.now = now
	scan.byKind = state.byKind
	wipe(scan.ready)
	return scan
end

-- Whether the cure can be cast now: true, or why not ("mana", "cooldown").
-- Asked only for a debuff about to be offered, once a scan for each cure.
-- Its own cooldown is one longer than a global cooldown (Mists and retail
-- give every cure eight seconds); the global one is the press's to wait out.
local function Ready(cure)
	local answer = scan.ready[cure.key]
	if answer ~= nil then return answer end
	answer = true
	local id = cure.info.topRank
	local spells = C_Spell
	local check = type(spells) == "table" and spells.IsSpellUsable or nil
	if type(check) ~= "function" then check = _G.IsUsableSpell end
	local usable, noMana = ns.safecall(check, id)
	if usable == false and noMana == true then answer = "mana" end
	if answer == true and type(spells) == "table" then
		local info = ns.safecall(spells.GetSpellCooldown, id)
		if type(info) == "table" then
			local start, duration = plain(info.startTime), plain(info.duration)
			if type(start) == "number" and type(duration) == "number" and duration > 3
				and start + duration > scan.now then
				answer = "cooldown"
			end
		end
	end
	scan.ready[cure.key] = answer
	return answer
end

---------------------------------------------------------------------------
-- reading somebody's debuffs
---------------------------------------------------------------------------

-- How long a reading is trusted, as the buff read's (Core.lua).
local READING_SECONDS = 3
-- [guid] = { trustedTo, list = { { cure, name, expires }, ... }, leftName,
-- leftWhy }: what was last read on somebody. Dropped at UNIT_AURA for them
-- (ns.ForgetCureRead), and whole once it has grown past a city's worth.
local cache, cacheCount = {}, 0
local CACHE_MAX = 300
-- A reading with no GUID to keep it under.
local unkept = { list = {} }

-- The harmful auras of one unit, read together in one protected call: the
-- client restricts this read per aura, and a restricted read can throw. The
-- first `taken` of them wait in `slots`. It stops at the end of the list, a
-- plain nil; a secret is kept as it came and compared with nothing.
local slots, taken = {}, 0
local function TakeSlots(unit)
	taken = 0
	local read = C_UnitAuras.GetAuraDataByIndex
	for index = 1, 40 do
		local aura = read(unit, index, "HARMFUL")
		slots[index] = aura
		taken = index
		if not (issecretvalue and issecretvalue(aura)) and aura == nil then return end
	end
end

-- What on `unit` could be cured, read now: into `record.list`, one debuff a
-- kind (the one with the most time left). Everything that does not change
-- from scan to scan is judged here: the kind, the client's own word on
-- whether you can remove it, the deny list, a timer at all. `leftName` and
-- `leftWhy` keep the first debuff turned down by the last two, for /manners
-- debug.
local function ReadInto(record, unit)
	local list = record.list
	for i = #list, 1, -1 do list[i] = nil end
	record.leftName, record.leftWhy = nil, nil
	-- A read that throws leaves the slots before it taken, and they are read.
	pcall(TakeSlots, unit)
	local byKind = scan.byKind
	for index = 1, taken do
		local aura = slots[index]
		slots[index] = nil
		if not (issecretvalue and issecretvalue(aura)) and type(aura) == "table" then
			local kind = plain(aura.dispelName)
			local cure = type(kind) == "string" and byKind[kind] or nil
			-- false is the client saying no; nil, a client that says nothing.
			if cure and plain(aura.canActivePlayerDispel) ~= false then
				local id, expires = plain(aura.spellId), plain(aura.expirationTime)
				local name = plain(aura.name)
				if type(name) ~= "string" or name == "" then name = KIND_LABEL[kind] end
				if type(id) == "number" and DENIED[id] then
					if not record.leftWhy then record.leftName, record.leftWhy = name, "denied" end
				elseif type(expires) ~= "number" or expires <= 0 then
					if not record.leftWhy then record.leftName, record.leftWhy = name, "untimed" end
				else
					local found
					for i = 1, #list do
						if list[i].cure == cure then found = list[i] break end
					end
					if not found then
						list[#list + 1] = { cure = cure, name = name, expires = expires }
					elseif expires > found.expires then
						found.name, found.expires = name, expires
					end
				end
			end
		end
	end
end

local function Reading(unit, guid)
	local now = scan.now
	if not guid then
		ReadInto(unkept, unit)
		return unkept
	end
	local record = cache[guid]
	if record and now < record.trustedTo then return record end
	if not record then
		if cacheCount >= CACHE_MAX then
			wipe(cache)
			cacheCount = 0
		end
		record = { list = {} }
		cache[guid] = record
		cacheCount = cacheCount + 1
		-- Says to UNIT_AURA that there is something to forget (Favours.lua).
		ns.cureReads = cache
	end
	ReadInto(record, unit)
	record.trustedTo = now + READING_SECONDS
	return record
end

-- UNIT_AURA for `unit` (Favours.lua): what was read of their debuffs is asked
-- again at the next scan, so a cure that landed is not offered a second time.
function ns.ForgetCureRead(unit)
	local guid = plain(UnitGUID(unit))
	if guid and cache[guid] then
		cache[guid] = nil
		cacheCount = cacheCount - 1
	end
end

---------------------------------------------------------------------------
-- passers-by, remembered
--
-- A passer-by is commonly found by the cursor alone, and the cursor leaves
-- them for the prompt: as for a buff (Queue.lua, "passers-by, remembered"),
-- somebody offered a cure through a token nobody pointed at is offered it by
-- name for a few seconds after the token goes. Kept apart from that memory:
-- its rules are the buff switches', and these are the cure's.
---------------------------------------------------------------------------

local LINGER_SECONDS = 10
local LINGER_CAP = 40
-- [name] = { seen, cure, class, targetName, guid, pvp, debuff, expires }
local remembered, rememberedCount = {}, 0
Cures.remembered = remembered

local function Forget(name)
	if remembered[name] then
		remembered[name] = nil
		rememberedCount = rememberedCount - 1
	end
end

local function Remember(entry, guid, now)
	local memo = remembered[entry.name]
	if not memo then
		if rememberedCount >= LINGER_CAP then
			wipe(remembered)
			rememberedCount = 0
		end
		memo = {}
		remembered[entry.name] = memo
		rememberedCount = rememberedCount + 1
	end
	memo.seen, memo.cure, memo.class, memo.targetName = now, entry.buff, entry.class, entry.targetName
	memo.guid, memo.pvp, memo.debuff, memo.expires = guid, entry.pvp, entry.debuff, entry.debuffUntil
end

---------------------------------------------------------------------------
-- the walk's hook
---------------------------------------------------------------------------

-- Asked by the walk (Queue.lua, visit) of somebody a cure switch reaches, once
-- every test of the person has passed and before any buff is read: their
-- queue entry for a cure, or nil for none, when the walk goes on to their
-- buffs. `flag` is their PvP flag as the walk read it, `pointed` whether a
-- target or focus found them.
function ns.CureFor(unit, full, guid, inGroup, pointed, flag)
	local record = Reading(unit, guid)
	local now = scan.now
	for i = 1, #record.list do
		local debuff = record.list[i]
		local cure = debuff.cure
		-- A probe since the reading may have taken the spell away.
		if scan.byKind[cure.cure] ~= cure then
			-- nothing to offer it with
		elseif debuff.expires - now <= scan.seconds then
			Leave(full, debuff.name, "short")
		elseif ns.IsBlocked(full, cure.key, now) then
			-- Pressed a moment ago, or skipped: said by nothing, as for a buff.
		else
			local ready = Ready(cure)
			if ready ~= true then
				Leave(full, debuff.name, ready)
			else
				local ranged = ns.InRange(unit, cure)
				if ranged == nil then ranged = ns.PastFollowReach(unit) end
				if not (scan.requireInRange and ranged == false) then
					local entry = {
						name = full,
						short = ns.ShortName(full),
						targetName = ns.TargetName(full),
						unit = unit,
						class = plain(select(2, UnitClass(unit))),
						buff = cure,
						-- Who they are to you, as the tooltip and the accent
						-- read it; never "asked" or "target", which are reasons
						-- for a buff.
						reason = inGroup and "group" or "nearby",
						inGroup = not not inGroup,
						priority = PRIORITY,
						ranged = ranged,
						-- Read on them, and so nothing "unverified".
						known = false,
						checked = true,
						pvp = flag,
						-- The kind, which marks the entry as a cure for
						-- everything after the queue, and what they are under.
						cure = cure.cure,
						debuff = debuff.name,
						debuffUntil = debuff.expires,
					}
					if not inGroup and not pointed then Remember(entry, guid, now) end
					return entry
				end
			end
		end
	end
	if record.leftWhy then Leave(full, record.leftName, record.leftWhy) end
	return nil
end

-- After the walk (Queue.lua, BuildQueue): the passers-by remembered that no
-- token reached this scan. `seen` and `rejected` are the walk's; `drop` is
-- everything that turns passers-by down as a kind (saving mana, a city-only
-- rule out in the world). One a token did reach was judged afresh there: a
-- cure offered renews the memory, and anything else ends it. A buff offered
-- them from the other memory gives its place to the cure.
function ns.CuresRemembered(queue, seen, rejected, now, drop)
	if rememberedCount == 0 then return end
	local db = addon.db and addon.db.profile
	for name, memo in pairs(remembered) do
		local cure = memo.cure
		if drop or not scan.strangers
			or now - memo.seen >= LINGER_SECONDS
			or (ns.zonedAt and memo.seen < ns.zonedAt)
			or ((seen[name] or rejected[name] == true) and memo.seen ~= now)
			or scan.byKind[cure.cure] ~= cure
			or memo.expires - now <= scan.seconds
			or ns.IsBlocked(name, cure.key, now)
			or ns.IsNeverOffered(name)
			or ns.Ignored(name, memo.guid)
			or ns.PvPHoldsBack(memo.pvp)
			or not ns.SafeForMacro(name) then
			Forget(name)
		elseif not seen[name] and Ready(cure) == true then
			local debt = scan.owed and ns.owed[name]
			-- A favour owed comes first, and its own path offers it.
			if not (debt and ns.DebtExpiry(debt) > now) then
				local entry = {
					name = name,
					short = ns.ShortName(name),
					targetName = memo.targetName,
					class = memo.class,
					buff = cure,
					reason = "nearby",
					inGroup = false,
					priority = PRIORITY,
					-- ranged is left unwritten: nothing measured them this scan.
					known = false,
					checked = true,
					cure = cure.cure,
					debuff = memo.debuff,
					debuffUntil = memo.expires,
				}
				local at = #queue + 1
				for i = 1, #queue do
					if queue[i].name == name then at = i break end
				end
				queue[at] = entry
			end
		end
	end
end

---------------------------------------------------------------------------
-- words
---------------------------------------------------------------------------

-- The prompt's reason line for a cure: what they are under. With `long`, for
-- the tooltip, the debuff by the client's name for it and the time it has left.
function ns.CureReason(entry, long)
	local reason = KIND_REASON[entry.cure] or ""
	if not long or type(entry.debuff) ~= "string" then return reason end
	local seconds = type(entry.debuffUntil) == "number" and (entry.debuffUntil - GetTime()) or nil
	if seconds and seconds > 0 then
		return ("%s: %s (%s)"):format(reason, entry.debuff, ns.TimeText(seconds))
	end
	return ("%s: %s"):format(reason, entry.debuff)
end

-- For /manners debug and the full check-up: what this character cures, and
-- who the last scan left alone and why. Nothing for a class with no cure on
-- this client. Only a person's name is in white: the check-up reads names
-- off that (Options/Diagnostics.lua).
function ns.CureLines()
	local out = {}
	if not ns.ClassHasCures() then return out end
	local list = Summary()
	if not list then
		out[1] = L["cures: nothing learned to cure with yet."]
		return out
	end
	local db = addon.db and addon.db.profile
	local sources = db and db.sources
	if not (sources and (sources.cures == true or sources.curesStrangers == true)) then
		out[1] = L["cures: switched off."]
		return out
	end
	out[1] = L["cures: %s."]:format(list)
	if Fighting() then
		out[2] = L["cures: none is offered in a fight."]
		return out
	end
	local WHY = {
		short = L["under %d seconds left"]:format(left.seconds),
		untimed = L["it has no timer"],
		denied = L["it is one Manners never removes"],
		cooldown = L["your cure is cooling down"],
		mana = L["not enough mana for the cure"],
	}
	for _, name in ipairs(left.names) do
		out[#out + 1] = L["|cffffffff%s|r: %s left alone -- %s"]
			:format(name, tostring(left.what[name]), WHY[left.why[name]] or tostring(left.why[name]))
	end
	return out
end
