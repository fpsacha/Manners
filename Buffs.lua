-- Manners -- what each class can put on somebody else.
--
-- The clients do not agree about a single spell, so the tables are per
-- flavour, chosen at the bottom of this file from ns.Flavour (Flavour.lua is
-- named before this file in every toc).
--
-- The fields, which mean the same thing in every set:
--
--   ranks     the castable spells, highest first. The macro casts by name, so
--             the game picks the best rank you know; the list is for aura
--             matching and for "do you know this at all". Only vanilla has
--             more than one (ranks were removed game-wide in 4.0.1).
--   group     every other id that counts as this buff already being there:
--             the raid-wide version on vanilla, or the thirteen per-class
--             auras Blessing of the Bronze applies on retail. Matched exactly
--             as the ranks are, through buff.auraIds.
--   manaOnly  only worth giving somebody with a mana bar.
--   partyOnly reaches your party and nobody else.
--   selfCast  cast on yourself, not on them, so the macro takes no target.
--   neverAuto offerable, but never what "Automatic" reaches for.
--   notSelf   the game will not let you cast it on yourself, so "Myself"
--             (Queue.lua) never offers it to you.
--   talent    learned from a talent, so not everybody of the class knows it.
--             Data only: ns.AskedFor still turns away every ask from your own
--             class, talent or not, until it is taught to read this.
--   groupCast the version one cast puts on a whole party (or, for a paladin,
--             on everybody of one class), as { id, reagent } per rank, highest
--             first. Only the rank the player knows best is ever used, because
--             the macro casts by name and the game picks that rank. Offered in
--             place of single casts by GroupBuffs.lua.
--
-- Only buffs worth giving a passer-by are listed: emergency spells (Blessing
-- of Freedom, Protection) and anything that moves somebody (Slow Fall,
-- Levitate, Water Walking) are deliberately absent.

local _, ns = ...
-- Player-facing text, in the client's language: see Locales/Init.lua.
local L = ns.L

---------------------------------------------------------------------------
-- vanilla content: Classic Era, Burning Crusade Classic, and WoW Forever
---------------------------------------------------------------------------

-- This data must not move: these are the tables confirmed working in game on
-- Forever, the one client anybody here can test.

-- The reagents the group versions eat, one per cast. The item ids and names
-- were checked against QuestieDB_Camelot (the Forever client's own item data:
-- 17020 Arcane Powder, 17021 Wild Berries, 17026 Wild Thornroot, 17029 Sacred
-- Candle, 21177 Symbol of Kings) and Questie's list of what reagent vendors
-- sell to each class. Which rank eats which is the 1.12 spell data, not in any
-- file here: the ranks learned at 60 and the 50/56 ones agree except Gift of
-- the Wild, whose first rank takes Wild Berries and whose second Thornroot.
-- GroupBuffs.lua also asks the client whether the spell is usable, which is
-- false without its reagent, so a wrong pairing costs an offer, not a cast.
local ARCANE_POWDER, WILD_BERRIES, WILD_THORNROOT = 17020, 17021, 17026
local SACRED_CANDLE, SYMBOL_OF_KINGS = 17029, 21177

-- A paladin's Greater Blessing, highest rank first: every one of them takes a
-- Symbol of Kings.
local function Greater(...)
	local out = {}
	for i = 1, select("#", ...) do
		out[i] = { id = (select(i, ...)), reagent = SYMBOL_OF_KINGS }
	end
	return out
end

local VANILLA = {
	MAGE = {
		{
			key = "intellect",
			ranks = { 10157, 10156, 1461, 1460, 1459 },
			group = { 23028 },
			manaOnly = true,
			-- Arcane Brilliance.
			groupCast = { { id = 23028, reagent = ARCANE_POWDER } },
		},
	},

	PRIEST = {
		{
			key = "fortitude",
			ranks = { 10938, 10937, 2791, 1245, 1244, 1243 },
			group = { 21564, 21562 },
			-- Prayer of Fortitude.
			groupCast = { { id = 21564, reagent = SACRED_CANDLE }, { id = 21562, reagent = SACRED_CANDLE } },
		},
		{
			key = "spirit",
			ranks = { 27841, 14819, 14818, 14752 },
			group = { 27681 },
			manaOnly = true,
			talent = true,
			-- Prayer of Spirit.
			groupCast = { { id = 27681, reagent = SACRED_CANDLE } },
		},
		{
			key = "shadow",
			ranks = { 10958, 10957, 976 },
			group = { 27683 },
			-- Prayer of Shadow Protection.
			groupCast = { { id = 27683, reagent = SACRED_CANDLE } },
		},
	},

	DRUID = {
		{
			key = "motw",
			ranks = { 9885, 9884, 8907, 5234, 6756, 5232, 1126 },
			group = { 21850, 21849 },
			-- Gift of the Wild: each rank its own reagent.
			groupCast = { { id = 21850, reagent = WILD_THORNROOT }, { id = 21849, reagent = WILD_BERRIES } },
		},
		{
			key = "thorns",
			ranks = { 9910, 9756, 8914, 1075, 782, 467 },
		},
	},

	PALADIN = {
		{
			key = "wisdom",
			ranks = { 25290, 19854, 19853, 19852, 19850, 19742 },
			group = { 25918, 25894 },
			manaOnly = true,
			groupCast = Greater(25918, 25894),
		},
		{
			key = "might",
			ranks = { 25291, 19838, 19837, 19836, 19835, 19834, 19740 },
			group = { 25916, 25782 },
			groupCast = Greater(25916, 25782),
		},
		{
			key = "kings",
			ranks = { 20217 },
			group = { 25898 },
			talent = true,
			groupCast = Greater(25898),
		},
		{
			key = "salvation",
			ranks = { 1038 },
			group = { 25895 },
			groupCast = Greater(25895),
		},
		{
			key = "light",
			ranks = { 19979, 19978, 19977 },
			group = { 25890 },
			groupCast = Greater(25890),
		},
		{
			key = "sanctuary",
			ranks = { 20914, 20913, 20912, 20911 },
			group = { 25899 },
			talent = true,
			groupCast = Greater(25899),
		},
	},

	WARLOCK = {
		{
			key = "breath",
			ranks = { 5697 },
		},
	},

	-- Battle Shout is cast on yourself and reaches the party, so it has no
	-- target. Still the courteous thing a warrior can offer back.
	WARRIOR = {
		{
			key = "battleshout",
			ranks = { 25289, 11551, 11550, 11549, 6192, 5242, 6673 },
			selfCast = true,
			partyOnly = true,
		},
	},
}

local VANILLA_SET = {
	name = "vanilla",
	buffs = VANILLA,
	-- Classes whose buffs overwrite one another, so a target carries only one
	-- of yours and walking the list would replace a blessing they have.
	exclusive = { PALADIN = true },
	-- Which buff "auto" reaches for, where it depends on who is standing there.
	auto = { PALADIN = { mana = "wisdom", other = "might" } },
	-- Classes with nothing to give, so the options screen can say so plainly.
	without = {
		HUNTER = true,
		ROGUE = true,
		SHAMAN = true, -- totems are placed, not cast on a person
	},
	-- A partyOnly buff reaches the caster's own subgroup of a raid and nobody
	-- else in it. Vanilla's Battle Shout is party-wide in a raid, not raid-wide;
	-- the later sets made their shouts reach the whole raid, and leave this out.
	partyIsSubgroup = true,
	-- Classes whose groupCast reaches everybody of the target's class in the
	-- raid or party rather than the target's party: the Greater Blessings.
	groupByClass = { PALADIN = true },
}

---------------------------------------------------------------------------
-- Mists of Pandaria Classic
---------------------------------------------------------------------------

-- 5.0.4 folded the raid-wide versions into the single-target spells and
-- deleted the duplicates within a class, so every list here is one id long.
--
-- NOT established: 5.0.4 also made these buffs apply to the whole party or
-- raid at once, and whether the cast still reaches a stranger has not been
-- verified on a live Mists client. If it does not, every entry wants
-- partyOnly. Listed as targetable until somebody can say, because that
-- failure is the cheap one (the cast lands on the caster's own group).
local MISTS = {
	MAGE = {
		{
			key = "intellect",
			ranks = { 1459 }, -- Arcane Brilliance
			-- Dalaran Brilliance is the same buff learned from a different
			-- book; a target carrying it does not want ours on top.
			group = { 61316 },
			-- Spell power rather than mana here, but it is still a buff only a
			-- caster benefits from, and manaOnly is how this addon says that.
			manaOnly = true,
		},
	},

	PRIEST = {
		{ key = "fortitude", ranks = { 21562 } },
	},

	DRUID = {
		{ key = "motw", ranks = { 1126 } },
	},

	-- The cast id is the aura id for these two: the Greater Blessings that used
	-- to carry their own ids are gone, so there is no group version to match.
	PALADIN = {
		{ key = "kings", ranks = { 20217 } },
		{ key = "might", ranks = { 19740 } },
	},

	-- The two Legacies are different buff categories (5% stats, 5% crit), so
	-- a monk gives both, and MONK is deliberately absent from `exclusive`.
	MONK = {
		{ key = "emperor", ranks = { 115921 } },    -- Legacy of the Emperor
		{ key = "whitetiger", ranks = { 116781 } }, -- Legacy of the White Tiger
	},

	WARLOCK = {
		{ key = "darkintent", ranks = { 109773 } },
		-- Kept because somebody might want it, and kept away from Automatic
		-- because nobody standing in a city wants to be handed water breathing.
		{ key = "breath", ranks = { 5697 }, neverAuto = true },
	},

	WARRIOR = {
		{ key = "battleshout", ranks = { 6673 }, selfCast = true, partyOnly = true },
	},

	-- Horn of Winter is the death knight's Battle Shout: no target, party
	-- only. Its id is the least certain in this file, so it is the first thing
	-- to check if a Mists death knight reports the wrong spell.
	DEATHKNIGHT = {
		{ key = "hornofwinter", ranks = { 57330 }, selfCast = true, partyOnly = true },
	},
}

local MISTS_SET = {
	name = "mists",
	buffs = MISTS,
	-- Still one blessing per paladin in 5.5, so the walk would take away what
	-- the last click gave.
	exclusive = { PALADIN = true },
	-- Nothing depends on who is standing there (Wisdom is gone, Kings suits
	-- everybody). An empty table, so ns.CLASS_AUTO is a table on every client.
	auto = {},
	without = {
		HUNTER = true,
		ROGUE = true,
		SHAMAN = true, -- the 5.x shaman buffs are auras, not casts on a person
	},
}

---------------------------------------------------------------------------
-- retail: Midnight 12.1
---------------------------------------------------------------------------

-- Five class buffs are left, one per class, each an hour long and castable on
-- somebody outside your group. Paladins and death knights have nothing left,
-- and are named in `without` so the options page can say so.
local MAINLINE = {
	MAGE = {
		{
			key = "intellect",
			ranks = { 1459 },
			-- Not manaOnly here: on retail it is one of five raid buffs
			-- everybody carries, whether or not they have a mana bar.
		},
	},

	PRIEST = {
		{ key = "fortitude", ranks = { 21562 } },
	},

	DRUID = {
		{ key = "motw", ranks = { 1126 } },
	},

	-- New in 11.0, all specs, learned at 17.
	SHAMAN = {
		{ key = "skyfury", ranks = { 462854 } },
	},

	EVOKER = {
		{
			key = "bronze",
			ranks = { 364342 },
			-- The thirteen auras one cast can apply, one per class, none
			-- sharing the cast's id: without them a buffed target reads as
			-- missing it. All thirteen, rather than a guess at the mapping.
			group = {
				381732, 381741, 381746, 381748, 381749, 381750, 381751,
				381752, 381753, 381754, 381756, 381757, 381758,
			},
		},
		{
			-- Talent-gated, so gated on `known` like every spell here: an
			-- evoker without it never offers it. Second on purpose -- only one
			-- ally can carry it, so Automatic reaches for the Blessing first.
			key = "sourceofmagic",
			ranks = { 369459 },
			manaOnly = true,
			talent = true,
			-- It goes to another player, never the evoker casting it.
			notSelf = true,
		},
	},

	WARRIOR = {
		{ key = "battleshout", ranks = { 6673 }, selfCast = true, partyOnly = true },
	},
}

local MAINLINE_SET = {
	name = "mainline",
	buffs = MAINLINE,
	-- Nothing overwrites anything, and nothing depends on who is there.
	exclusive = {},
	auto = {},
	without = {
		PALADIN = true,      -- Kings, Might and Wisdom died in 7.0.3, Blessing of the Seasons in 12.0.0
		DEATHKNIGHT = true,  -- Horn of Winter removed in 11.2.0
		MONK = true,
		DEMONHUNTER = true,
		HUNTER = true,
		ROGUE = true,
		WARLOCK = true,      -- Unending Breath is not a courtesy
	},
}

---------------------------------------------------------------------------
-- which set this client gets
---------------------------------------------------------------------------

local SETS = {
	vanilla = VANILLA_SET,
	tbc = VANILLA_SET,
	-- Forever runs vanilla content, and the vanilla tables are the ones
	-- verified there in game.
	camelot = VANILLA_SET,
	mists = MISTS_SET,
	mainline = MAINLINE_SET,
}

-- A client whose interface number matched no band gets the set for the family
-- Flavour.lua classified it into. It is a guess, and ns.BUFFS_SOURCE says so
-- in /manners debug.
local BY_FAMILY = { classic = VANILLA_SET, modern = MAINLINE_SET }

local function ChooseSet()
	local flavour = ns.Flavour
	if type(flavour) ~= "table" then
		-- Unreachable from a release (validate.py checks the toc), but not
		-- from a hand-assembled addon folder.
		return nil, L["Flavour.lua did not load, so there is nothing to choose from"]
	end

	-- The set's name stays as it is in every language: it is the data set's
	-- identifier, and the scenarios find it in this string.
	local set = SETS[flavour.flavour]
	if set then return set, set.name end

	set = BY_FAMILY[flavour.family]
	if set then
		return set, L["%s, guessed from the %s family"]:format(set.name, tostring(flavour.family))
	end

	return nil, L["no set for %s/%s"]:format(tostring(flavour.flavour), tostring(flavour.family))
end

local chosen, source = ChooseSet()
ns.BUFFS_SOURCE = source

if chosen then
	ns.BUFFS = chosen.buffs
	ns.EXCLUSIVE_BUFFS = chosen.exclusive
	ns.CLASS_AUTO = chosen.auto
	ns.CLASSES_WITHOUT_BUFFS = chosen.without
	ns.PARTY_IS_SUBGROUP = chosen.partyIsSubgroup == true
	ns.GROUP_BY_CLASS = chosen.groupByClass
end

---------------------------------------------------------------------------
-- derived lookups
---------------------------------------------------------------------------

-- Every id any class can apply, used to tell a real class buff from a stray
-- heal-over-time or proc when deciding whether we owe somebody a favour.
ns.ALL_BUFF_IDS = {}
ns.BUFF_BY_ID = {}

-- A function rather than a bare loop, so a client with no table to walk (no
-- flavour and no family matched) is reported rather than thrown on: a file
-- that throws while loading leaves no addon at all, silently. The three tables
-- beside ns.BUFFS are defaulted for the same reason, since Core.lua, the
-- files after it and the options page index them without asking.
function ns.BuildBuffLookups()
	wipe(ns.ALL_BUFF_IDS)
	wipe(ns.BUFF_BY_ID)

	if type(ns.EXCLUSIVE_BUFFS) ~= "table" then ns.EXCLUSIVE_BUFFS = {} end
	if type(ns.CLASS_AUTO) ~= "table" then ns.CLASS_AUTO = {} end
	if type(ns.CLASSES_WITHOUT_BUFFS) ~= "table" then ns.CLASSES_WITHOUT_BUFFS = {} end
	if type(ns.GROUP_BY_CLASS) ~= "table" then ns.GROUP_BY_CLASS = {} end

	if type(ns.BUFFS) ~= "table" then
		ns.BUFFS = {}
		ns.BUFFS_MISSING = L["no buff data for this client -- %s"]:format(
			(ns.FlavourSummary and ns.FlavourSummary()) or L["flavour unknown"])
		-- Printed here too: this runs during load, before the addon has a
		-- Print of its own, and not every user opens /manners debug.
		if type(print) == "function" then
			print("|cffff4040Manners:|r " .. L["%s -- nobody will be offered a buff. Please report this, with the output of /manners debug."]:format(ns.BUFFS_MISSING))
		end
		return
	end
	ns.BUFFS_MISSING = nil

	for class, list in pairs(ns.BUFFS) do
		for index, buff in ipairs(list) do
			buff.class = class
			buff.order = index

			buff.auraIds = {}
			for _, id in ipairs(buff.ranks) do
				buff.auraIds[#buff.auraIds + 1] = id
			end
			for _, id in ipairs(buff.group or {}) do
				buff.auraIds[#buff.auraIds + 1] = id
			end

			for _, id in ipairs(buff.auraIds) do
				ns.ALL_BUFF_IDS[id] = true
				ns.BUFF_BY_ID[id] = buff
			end
		end
	end
end

ns.BuildBuffLookups()

function ns.GetClassBuffs(class)
	return ns.BUFFS[class or select(2, UnitClass("player"))]
end

function ns.FindBuff(class, key)
	for _, buff in ipairs(ns.BUFFS[class] or {}) do
		if buff.key == key then return buff end
	end
end

-- Whether any class on this client has a buff by that key. A pin lives in the
-- profile every character shares, so one this character cannot cast is still
-- somebody's -- and only a key nobody has is nonsense.
function ns.AnyClassHasBuff(key)
	for class in pairs(ns.BUFFS) do
		if ns.FindBuff(class, key) then return true end
	end
	return false
end
