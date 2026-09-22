-- Manners -- what each class can put on somebody else.
--
-- Five clients run this addon and they do not agree about a single spell. The
-- tables below are therefore per flavour, and the one the client gets is chosen
-- at the bottom of this file from ns.Flavour -- which is why Flavour.lua is
-- named before this file in every toc.
--
-- The fields, which mean the same thing in every set:
--
--   ranks     the castable spells, highest first. The macro casts by name, so
--             the game picks the best rank you know; the list is here for aura
--             matching and for "do you know this at all". Ranks were removed
--             game-wide in 4.0.1, so only the vanilla set has more than one.
--   group     every other id that counts as this buff already being there. On
--             vanilla that is the raid-wide version -- a player carrying Gift
--             of the Wild already has Mark of the Wild. On retail it is the
--             thirteen per-class auras Blessing of the Bronze applies, which
--             share no id with the spell that casts them. Either way these are
--             matched exactly as the ranks are: ns.BuildBuffLookups pours both
--             lists into buff.auraIds and every reader walks that.
--   manaOnly  only worth giving somebody with a mana bar.
--   partyOnly reaches your party and nobody else.
--   selfCast  cast on yourself, not on them, so the macro takes no target.
--   neverAuto offerable, but never what "Automatic" reaches for.
--
-- Only buffs worth giving a passer-by are listed. Blessing of Freedom and
-- Protection are emergency spells, not courtesies, and are deliberately absent;
-- so is anything that moves somebody -- Slow Fall, Levitate, Water Walking --
-- for the same reason.

local ADDON, ns = ...

---------------------------------------------------------------------------
-- vanilla content: Classic Era, Burning Crusade Classic, and WoW Forever
---------------------------------------------------------------------------

-- This data must not move. Forever is the only client anybody working on this
-- addon can test, it runs vanilla content on a modern engine, and these tables
-- are the ones confirmed working there in game. Everything else in this file
-- was added around them.

local VANILLA = {
	MAGE = {
		{
			key = "intellect",
			ranks = { 10157, 10156, 1461, 1460, 1459 },
			group = { 23028 },
			manaOnly = true,
		},
	},

	PRIEST = {
		{
			key = "fortitude",
			ranks = { 10938, 10937, 2791, 1245, 1244, 1243 },
			group = { 21564, 21562 },
		},
		{
			key = "spirit",
			ranks = { 27841, 14819, 14818, 14752 },
			group = { 27681 },
			manaOnly = true,
		},
		{
			key = "shadow",
			ranks = { 10958, 10957, 976 },
			group = { 27683 },
		},
	},

	DRUID = {
		{
			key = "motw",
			ranks = { 9885, 9884, 8907, 5234, 6756, 5232, 1126 },
			group = { 21850, 21849 },
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
		},
		{
			key = "might",
			ranks = { 25291, 19838, 19837, 19836, 19835, 19834, 19740 },
			group = { 25916, 25782 },
		},
		{
			key = "kings",
			ranks = { 20217 },
			group = { 25898 },
		},
		{
			key = "salvation",
			ranks = { 1038 },
			group = { 25895 },
		},
		{
			key = "light",
			ranks = { 19979, 19978, 19977 },
			group = { 25890 },
		},
		{
			key = "sanctuary",
			ranks = { 20914, 20913, 20912, 20911 },
			group = { 25899 },
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
	-- Classes whose buffs overwrite one another, so a target can only ever
	-- carry one of yours. Walking the list for these would mean replacing a
	-- blessing somebody already has, which is worse than doing nothing.
	exclusive = { PALADIN = true },
	-- Which buff "auto" should reach for. Paladins are the only class where the
	-- right answer depends on who is standing there.
	auto = { PALADIN = { mana = "wisdom", other = "might" } },
	-- Classes with nothing to give. Listed explicitly so the options screen can
	-- say so plainly rather than looking broken.
	without = {
		HUNTER = true,
		ROGUE = true,
		SHAMAN = true, -- totems are placed, not cast on a person
	},
}

---------------------------------------------------------------------------
-- Mists of Pandaria Classic
---------------------------------------------------------------------------

-- 5.0.4 consolidated the buffs: the raid-wide versions were folded into the
-- single-target spells, the duplicates within a class were deleted outright
-- (Divine Spirit, Shadow Protection, Thorns, the lesser Blessings), and ranks
-- had already gone in 4.0.1. So every list here is one id long.
--
-- One thing about this set is NOT established, and pretending otherwise would
-- be the expensive kind of quiet: 5.0.4 also made these buffs apply to the
-- whole party or raid at once, and whether the cast still reaches a friendly
-- player who is in neither has not been verified on a live Mists client by
-- anybody here. If it does not, every entry below wants partyOnly and this
-- addon has nothing to offer a stranger on Mists. The honest failure is the
-- cheap one -- a buff cast that lands on the caster's own group instead of the
-- passer-by -- so they are listed as targetable until somebody can say.
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

	-- A class this file has never had. The two Legacies are different buff
	-- categories -- 5% stats and 5% crit -- so a monk gives both rather than
	-- choosing, which is why MONK is deliberately absent from `exclusive`.
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

	-- Horn of Winter is the death knight's Battle Shout and is here for the
	-- same reason that is: no target, party only, and the one courteous thing
	-- the class can offer back. It is the only entry in this file that the
	-- round's research did not name -- it was listed by omission, as a class
	-- retail is said to have "removed" -- so it is the first thing to check if
	-- a Mists death knight reports the wrong spell.
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
	-- Nothing here depends on who is standing there any more: Blessing of
	-- Wisdom is gone, and Kings suits everybody. An empty table rather than a
	-- missing one, so ns.CLASS_AUTO is a table on every client.
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

-- Five class buffs are left in the game, one per class, each an hour long and
-- each castable on somebody who is not in your group. Three classes that used
-- to be the backbone of this addon now have nothing at all: the Blessings died
-- in 7.0.3 and Blessing of the Seasons in 12.0.0, and Horn of Winter went in
-- 11.2.0. They are named in `without` so the options page can say so.
local MAINLINE = {
	MAGE = {
		{
			key = "intellect",
			ranks = { 1459 },
			-- Not manaOnly here. Arcane Intellect is intellect and a mana
			-- pool's worth of nothing to a rogue on vanilla, but on retail it
			-- is one of five raid buffs everybody carries, and filtering it by
			-- who has a mana bar would silently skip most of the game.
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
			-- The thirteen auras one cast can apply, one per class. The spell
			-- that casts it shares an id with none of them, so without this
			-- list a target carrying the buff reads as missing it and every
			-- evoker in the game rebuffs the same person forever. All thirteen
			-- are here rather than a guess about which maps to which class:
			-- matching the wrong one is the same silence as matching none.
			group = {
				381732, 381741, 381746, 381748, 381749, 381750, 381751,
				381752, 381753, 381754, 381756, 381757, 381758,
			},
		},
		{
			-- Talent-gated, so it is gated on `known` like every other spell in
			-- this file rather than on the class: the probe asks the client
			-- whether this character has it, and an evoker who has not taken it
			-- simply never offers it. Second in the list on purpose -- only one
			-- ally can carry it, so Automatic must reach for the Blessing first
			-- and never pull this off somebody's healer.
			key = "sourceofmagic",
			ranks = { 369459 },
			manaOnly = true,
		},
	},

	WARRIOR = {
		{ key = "battleshout", ranks = { 6673 }, selfCast = true, partyOnly = true },
	},
}

local MAINLINE_SET = {
	name = "mainline",
	buffs = MAINLINE,
	-- Nothing overwrites anything any more, and nothing depends on who is
	-- standing there.
	exclusive = {},
	auto = {},
	without = {
		PALADIN = true,      -- Kings, Might and Wisdom died in 7.0.3
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
	-- verified there in game. This line is the whole reason the flavour
	-- detector tries the 16xxx band before the 11xxx one.
	camelot = VANILLA_SET,
	mists = MISTS_SET,
	mainline = MAINLINE_SET,
}

-- A client whose interface number matched no band still has somebody sitting in
-- front of it. Flavour.lua always leaves a family behind -- that is its job --
-- so an unrecognised client is handed the set for the family it was classified
-- into rather than nothing at all. It is a guess, and ns.BUFFS_SOURCE says so
-- in /manners debug so a bug report from that client is readable.
local BY_FAMILY = { classic = VANILLA_SET, modern = MAINLINE_SET }

local function ChooseSet()
	local flavour = ns.Flavour
	if type(flavour) ~= "table" then
		-- Flavour.lua is named before this file in every toc and validate.py
		-- fails a build whose toc lost it, so this is not reachable from a
		-- release. It is reachable from a hand-assembled addon folder, and the
		-- complaint below is the only thing that would ever say so.
		return nil, "Flavour.lua did not load, so there is nothing to choose from"
	end

	local set = SETS[flavour.flavour]
	if set then return set, set.name end

	set = BY_FAMILY[flavour.family]
	if set then
		return set, ("%s, guessed from the %s family"):format(set.name, tostring(flavour.family))
	end

	return nil, ("no set for %s/%s"):format(tostring(flavour.flavour), tostring(flavour.family))
end

local chosen, source = ChooseSet()
ns.BUFFS_SOURCE = source

if chosen then
	ns.BUFFS = chosen.buffs
	ns.EXCLUSIVE_BUFFS = chosen.exclusive
	ns.CLASS_AUTO = chosen.auto
	ns.CLASSES_WITHOUT_BUFFS = chosen.without
end

---------------------------------------------------------------------------
-- derived lookups
---------------------------------------------------------------------------

-- Every id any class can apply, used to tell a real class buff from a stray
-- heal-over-time or proc when deciding whether we owe somebody a favour.
ns.ALL_BUFF_IDS = {}
ns.BUFF_BY_ID = {}

-- A function rather than a bare loop at file scope, for one reason: so the
-- case where there is no table to walk has somewhere to be reported from.
--
-- ipairs over nil throws, and a file that throws while loading does not leave a
-- broken addon behind -- it leaves no addon at all. No frame, no slash command,
-- no error anybody without script errors turned on will ever see. From the
-- user's side that is indistinguishable from never having installed it, and
-- the bug report is "it does nothing", which is the least actionable sentence
-- in this project's history.
--
-- Reachable now that the data is split: a client that matches no flavour and no
-- family gets nil. The three tables beside ns.BUFFS are defended the same way
-- and for the same reason -- Core.lua indexes ns.EXCLUSIVE_BUFFS and
-- ns.CLASS_AUTO without asking, and the options page indexes
-- ns.CLASSES_WITHOUT_BUFFS, so a nil there throws somewhere unrelated.
function ns.BuildBuffLookups()
	wipe(ns.ALL_BUFF_IDS)
	wipe(ns.BUFF_BY_ID)

	if type(ns.EXCLUSIVE_BUFFS) ~= "table" then ns.EXCLUSIVE_BUFFS = {} end
	if type(ns.CLASS_AUTO) ~= "table" then ns.CLASS_AUTO = {} end
	if type(ns.CLASSES_WITHOUT_BUFFS) ~= "table" then ns.CLASSES_WITHOUT_BUFFS = {} end

	if type(ns.BUFFS) ~= "table" then
		ns.BUFFS = {}
		ns.BUFFS_MISSING = ("no buff data for this client -- %s"):format(
			(ns.FlavourSummary and ns.FlavourSummary()) or "flavour unknown")
		-- Said out loud here as well as from /manners debug. This runs during
		-- load, before the addon has a Print of its own, and a user who never
		-- opens the options screen would otherwise be told nothing at all.
		if type(print) == "function" then
			print("|cffff4040Manners:|r " .. ns.BUFFS_MISSING
				.. " -- nobody will be offered a buff. Please report this,"
				.. " with the output of /manners debug.")
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
