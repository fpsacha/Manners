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
--   groupOnly reaches anybody in your party or raid (a raid member in another
--             subgroup too), and nobody outside it: Blessing of Salvation.
--   selfCast  cast on yourself, not on them, so the macro takes no target.
--   neverAuto offerable, but never what "Automatic" reaches for.
--   notSelf   the game will not let you cast it on yourself, so "Myself"
--             (Queue.lua) never offers it to you.
--   neverSelf castable on yourself, but never offered to you by "Myself": a
--             buff you want only for a reason the prompt cannot see (Unending
--             Breath, under water), which would come back every time it ran
--             out, all evening. Offers to others are untouched.
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
local L = ns.L

---------------------------------------------------------------------------
-- vanilla content: Classic Era, Burning Crusade Classic, and WoW Forever
---------------------------------------------------------------------------

-- This data must not move: these are the tables confirmed working in game on
-- Forever, the one client anybody here can test.

-- The reagents the group versions eat, one per cast. The item ids and names
-- were checked against QuestieDB_Camelot (the Forever client's own item data:
-- 17020 Arcane Powder, 17021 Wild Berries, 17026 Wild Thornroot, 17029 Sacred
-- Candle, 21177 Symbol of Kings), Forever's ItemSparse (17028 Holy Candle) and
-- Questie's list of what reagent vendors sell to each class. Which rank eats
-- which is Forever's own SpellReagents (build 1.60.1.70178), the same as
-- Classic Era's: two first ranks take the cheaper reagent, Prayer of
-- Fortitude's (learned at 48) a Holy Candle and Gift of the Wild's (50) Wild
-- Berries; every other rank takes the one paired below. GroupBuffs.lua also
-- asks the client whether the spell is usable, which is false without its
-- reagent, so a wrong pairing costs an offer, not a cast. On Forever the
-- account's Legacy perk Reagent Economy (1225503) waives the reagent of every
-- one of these (its class auras 1262636/38/47/50 list them all), and then the
-- client calls the spell usable with none in the bags: GroupBuffs.lua,
-- ReagentWaived.
local ARCANE_POWDER, WILD_BERRIES, WILD_THORNROOT = 17020, 17021, 17026
local SACRED_CANDLE, HOLY_CANDLE, SYMBOL_OF_KINGS = 17029, 17028, 21177

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
			-- Prayer of Fortitude: rank 1 a Holy Candle, rank 2 a Sacred one.
			groupCast = { { id = 21564, reagent = SACRED_CANDLE }, { id = 21562, reagent = HOLY_CANDLE } },
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
			-- "Places a Blessing on the party member": the game refuses it on
			-- anybody outside your party or raid (target 57 in the spell data,
			-- Forever's and Classic Era's alike), where the other blessings
			-- take any friendly target.
			groupOnly = true,
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
			-- A shaman's Water Breathing is the same aura (82, ten minutes):
			-- somebody wearing it needs no Unending Breath, and it on you is
			-- a favour like any other.
			group = { 131 },
			-- Water breathing is nothing to be reminded of on dry land, and a
			-- ten-minute buff on yourself would come back all evening, ahead
			-- of your Demon Skin or Armor.
			neverSelf = true,
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

---------------------------------------------------------------------------
-- vanilla: what each class puts on itself alone
---------------------------------------------------------------------------

-- The buffs a class can only cast on itself, which "Myself" (Queue.lua,
-- SelfEntry) reminds you of when none of a family is up. Kept apart from the
-- tables above, whose every entry is something to give somebody else: nothing
-- here is offered to anybody but the caster, walked by Automatic, asked for in
-- chat or counted as a favour, and the fields above mean nothing here.
--
-- Per class, a list of families, in the order they are offered (your own
-- group buff, from the tables above, always comes first). A family is the
-- buffs of which only one of yours can be up at once -- a mage's armors, a
-- paladin's auras, a hunter's aspects, a shaman's shields -- and a spell alone
-- is a family of one.
--
--   key       the family's name in the profile (ownBuffs.pick) and in the
--             character's memory of the one last up. Unique across every
--             class, because the profile is shared by every character.
--   label     what a family of several is called on the options page; a
--             family of one goes by its spell's name.
--   spells    each { key, ranks }: ranks highest first, as above, and the key
--             unique across both kinds of table. One spell line may change its
--             name between ranks (Frost Armor becomes Ice Armor at 30, Demon
--             Skin becomes Demon Armor at 20): the macro casts the best rank
--             known by that rank's own name (Core.lua, ProbeBuff).
--             neverAuto on a spell: never what Automatic picks or remembers.
--             talent on a spell: learned from a talent (data only).
--   toggle    stays up until switched off, with no timer (auras, aspects), so
--             never offered as a top-up.
--   dungeon   Automatic's first pick in a dungeon or raid before you have had
--             one up; elsewhere it is the first spell of the family you know.
--   tank      Automatic reminds you only while your group role is tank.
--
-- Every id below was checked against Forever's own spell data (EnhanceQoL's
-- SpellRankData_Camelot, generated from build 1.60.1.69913) and Wowhead
-- Classic. Forever added ranks of its own to two spells (Aspect of the Beast
-- and Trueshot Aura, the 1299xxx ids), which no other vanilla client has; they
-- only ever fail to be known there. Water Shield, one rank and so not in that
-- data, was checked against Wowhead Classic and the Forever build of
-- EnhanceQoL's buff reminder, which puts it in the shaman's one shield family.
-- A spell is "known" by these ids alone, so a wrong id costs the reminder,
-- never a nag.
--
-- Vanilla content only: Burning Crusade gave most of these families a member
-- this table does not have (Molten and Fel Armor, Earth Shield, Aspect of the
-- Viper, Crusader Aura), so the tbc set below leaves it out.
-- The level each rank of the buffs above is learned at (vanilla trainers), for
-- "skip my own class when they can cast it too": somebody of your class at or
-- past the level of your best rank could give themselves the same, and one
-- below it gets yours, which is better. A buff marked `talent` and a shout
-- are never skipped that way, so their levels are never read; a rank missing
-- here counts as learned at level 1.
ns.RANK_LEVEL = {
	-- Arcane Intellect
	[1459] = 1, [1460] = 14, [1461] = 28, [10156] = 42, [10157] = 56,
	-- Power Word: Fortitude
	[1243] = 1, [1244] = 12, [1245] = 24, [2791] = 36, [10937] = 48, [10938] = 60,
	-- Shadow Protection
	[976] = 30, [10957] = 42, [10958] = 56,
	-- Mark of the Wild
	[1126] = 1, [5232] = 10, [6756] = 20, [5234] = 30, [8907] = 40, [9884] = 50, [9885] = 60,
	-- Thorns
	[467] = 6, [782] = 14, [1075] = 24, [8914] = 34, [9756] = 44, [9910] = 54,
	-- Blessing of Wisdom
	[19742] = 14, [19850] = 24, [19852] = 34, [19853] = 44, [19854] = 54, [25290] = 60,
	-- Blessing of Might
	[19740] = 4, [19834] = 12, [19835] = 22, [19836] = 32, [19837] = 42, [19838] = 52, [25291] = 60,
	-- Blessing of Salvation, Blessing of Light, Unending Breath
	[1038] = 26, [19977] = 40, [19978] = 50, [19979] = 60, [5697] = 16,
	-- Blessing of Kings and Divine Spirit: trained on Forever (its SpellLevels),
	-- talents on Classic Era, where `talent` returns before these are read.
	[20217] = 20, [14752] = 30, [14818] = 40, [14819] = 50, [27841] = 60,
}
function ns.RankLevel(id)
	return id and ns.RANK_LEVEL[id] or nil
end

local VANILLA_OWN = {
	MAGE = {
		{
			key = "armor",
			label = L["Armor"],
			spells = {
				-- Frost Armor 1-3, then Ice Armor 1-4 from level 30: one line.
				{ key = "frostarmor", ranks = { 10220, 10219, 7320, 7302, 7301, 7300, 168 } },
				{ key = "magearmor", ranks = { 22783, 22782, 6117 } },
			},
			-- The mana back in a long fight; out in the world, and in a
			-- battleground, the armor.
			dungeon = "magearmor",
		},
	},

	PRIEST = {
		{ key = "innerfire", spells = { { key = "innerfire", ranks = { 10952, 10951, 1006, 602, 7128, 588 } } } },
		-- An undead priest's and a troll priest's racials in 1.12. Whether
		-- Forever keeps them racial, the guides disagree; it does not matter
		-- here, since each is shown and offered only to a priest who has
		-- learned it. On by default like the rest, as the approved design has
		-- it: a priest who trains a charge-spent shield wants it back after a
		-- fight, and one who does not is never asked. Kept apart rather than
		-- as one family: nothing says one replaces the other.
		{ key = "touchofweakness",
			spells = { { key = "touchofweakness", ranks = { 19266, 19265, 19264, 19262, 19261, 2652 } } } },
		{ key = "shadowguard",
			spells = { { key = "shadowguard", ranks = { 19312, 19311, 19310, 19309, 19308, 18137 } } } },
	},

	WARLOCK = {
		{
			key = "demonarmor",
			spells = {
				-- Demon Skin 1-2, then Demon Armor 1-5 from level 20: one line.
				{ key = "demonarmor", ranks = { 11735, 11734, 11733, 1086, 706, 696, 687 } },
			},
		},
	},

	PALADIN = {
		{
			key = "aura",
			label = L["Aura"],
			spells = {
				{ key = "devotionaura", ranks = { 10293, 10292, 1032, 10291, 643, 10290, 465 } },
				{ key = "retributionaura", ranks = { 10301, 10300, 10299, 10298, 7294 } },
				{ key = "concentrationaura", ranks = { 19746 } },
				{ key = "shadowresaura", ranks = { 19896, 19895, 19876 } },
				{ key = "frostresaura", ranks = { 19898, 19897, 19888 } },
				{ key = "fireresaura", ranks = { 19900, 19899, 19891 } },
				-- Classic Era's talent. Forever took it out of the game, so
				-- there it is never known, never shown and never offered.
				{ key = "sanctityaura", ranks = { 20218 }, talent = true },
			},
			toggle = true,
		},
		{
			key = "righteousfury",
			spells = { { key = "righteousfury", ranks = { 25780 } } },
			tank = true,
		},
	},

	HUNTER = {
		{
			key = "aspect",
			label = L["Aspect"],
			spells = {
				{ key = "aspecthawk", ranks = { 25296, 14322, 14321, 14320, 14319, 14318, 13165 } },
				{ key = "aspectmonkey", ranks = { 13163 } },
				{ key = "aspectwild", ranks = { 20190, 20043 } },
				-- The three 1299xxx ranks are Forever's own.
				{ key = "aspectbeast", ranks = { 1299447, 1299446, 1299445, 13161 } },
				-- Up counts as your choice, so neither is ever nagged over; but
				-- nobody wants to be reminded to run everywhere, so Automatic
				-- never picks or remembers them.
				{ key = "aspectcheetah", ranks = { 5118 }, neverAuto = true },
				{ key = "aspectpack", ranks = { 13159 }, neverAuto = true },
			},
			toggle = true,
		},
		{
			key = "trueshot",
			-- The two 1299xxx ranks are Forever's own, below the talent's three.
			spells = { { key = "trueshot", ranks = { 20906, 20905, 19506, 1299348, 1299346 }, talent = true } },
		},
	},

	SHAMAN = {
		{
			key = "shield",
			label = L["Shield"],
			spells = {
				{ key = "lightningshield", ranks = { 10432, 10431, 8134, 945, 905, 325, 324 } },
				-- Forever's own: a Restoration talent (the Season of Discovery
				-- rune's id, as Forever's Lava Burst and Riptide are), and "only
				-- one Elemental Shield" may be up, so a healer wearing it has
				-- chosen and is never told to put Lightning Shield over it. Not
				-- in Forever's rank data (one rank); a wrong id only means it is
				-- never known here, and then never read as up either.
				{ key = "watershield", ranks = { 408510 }, talent = true },
			},
		},
	},

	DRUID = {
		{ key = "omen", spells = { { key = "omen", ranks = { 16864 }, talent = true } } },
	},

	-- WARRIOR and ROGUE: nothing of their own that is a buff. Poisons and a
	-- shaman's weapon imbues are weapon enchants, not auras.
}

-- Tracking, for every class: Find Herbs and Find Minerals come with a
-- profession, not a class, and drop when you die like a buff ("when I die I
-- often forget to put it on", a player on CurseForge). On this client it is
-- not an aura but the minimap's tracking list (Core.lua, TrackingList), as
-- EnhanceQoL's Forever build reads it; a spell missing from that list is never
-- known, so a wrong id here can only cost the reminder. The gathering ids are
-- EnhanceQoL's, each with the second id Forever also uses. One table shared by
-- every class's list, so the memory of the one you had on is one memory.
local TRACKING = {
	key = "tracking",
	label = L["Tracking"],
	tracking = true,
	toggle = true,
	spells = {
		{ key = "findherbs", ranks = { 2383, 8387 } },
		{ key = "findminerals", ranks = { 2580, 8388 } },
		{ key = "findtreasure", ranks = { 2481 } },
		{ key = "trackbeasts", ranks = { 1494 } },
		{ key = "trackhumanoids", ranks = { 19883, 5225 } },
		{ key = "trackundead", ranks = { 19884 } },
		{ key = "trackhidden", ranks = { 19885 } },
		{ key = "trackelementals", ranks = { 19880 } },
		{ key = "trackdemons", ranks = { 19878 } },
		{ key = "trackgiants", ranks = { 19882 } },
		{ key = "trackdragonkin", ranks = { 19879 } },
		{ key = "senseundead", ranks = { 5502 } },
		{ key = "sensedemons", ranks = { 5500 } },
	},
}
for _, class in ipairs({ "MAGE", "PRIEST", "WARLOCK", "PALADIN", "HUNTER", "SHAMAN", "DRUID", "WARRIOR", "ROGUE" }) do
	VANILLA_OWN[class] = VANILLA_OWN[class] or {}
	table.insert(VANILLA_OWN[class], TRACKING)
end

local VANILLA_SET = {
	name = "vanilla",
	buffs = VANILLA,
	own = VANILLA_OWN,
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
	-- Class buffs others put on you that Manners never offers (an emergency
	-- spell, or one that moves you), counted as favours only: in ALL_BUFF_IDS,
	-- never in BUFF_BY_ID. Fear Ward; Water Walking; Detect Invisibility;
	-- Soulstone Resurrection, every rank. A shaman's Water Breathing comes in
	-- as Unending Breath's group id instead. Amplify and Dampen Magic are left
	-- out: each also works against its target, a raid tactic rather than a
	-- courtesy.
	favourOnly = { 6346, 546, 11743, 2970, 132, 20765, 20764, 20763, 20762, 20707 },
}

-- Burning Crusade Classic: the vanilla set in everything but the class's own
-- buffs. There every family above has a member vanilla lacks (Molten Armor,
-- Fel Armor, Earth Shield, Aspect of the Viper, Crusader Aura), and with one
-- of those up "Myself" would read none of the family as up and offer a spell
-- that replaces it. Empty, as on Mists, until somebody can check the ids; the
-- name stays "vanilla", which is the set its buffs for others come from.
local TBC_SET = setmetatable({ own = {} }, { __index = VANILLA_SET })

---------------------------------------------------------------------------
-- WoW Forever: a mage's scrolls
---------------------------------------------------------------------------

-- Forever's own: scrolls a mage finds -- in a Bundle of Scrolls from Study,
-- or by deciphering an untranslated scroll with Comprehend Scroll (both
-- Comprehension spells) -- and reads from the bags, a familiar and a weapon
-- imbue. "For mages, it would be handy to
-- include the mage-specific scroll buffs as reminders", a player on
-- CurseForge. Items, not spells, so Core.lua reads them apart (the scrolls):
-- offered only with one in the bags, at the level it asks for and, for an
-- imbue, on the weapon it fits, and used with /use item:<id> (Prompt/Macro.lua).
-- Every id is the client's own (ItemSparse, ItemXItemEffect, ItemEffect,
-- SpellEffect, SpellEquippedItems and SpellItemEnchantment, build
-- 1.60.1.70178); Rat Familiar, Chillknife and Lesser Flame were also read off
-- a level-12 mage's bags in game.
--
-- Each family is a family as above, with:
--   scroll    its spells are scrolls: { key, item (the item id), level (the
--             level it asks for), ranks = { the spell its use casts } }, best
--             first, which is the order Automatic tries them in before you
--             have used one. The scroll's name is that spell's, as the client
--             names it; nameFromItem takes the item's instead, and is the
--             name until the client has loaded the item.
--   imbue     up is the main hand carrying a scroll's imbue or any temporary
--             enchant, a wizard oil included, never a permanent one, rather
--             than an aura (Core.lua, ReadImbue); each scroll names its
--             `enchant` and the `weapon` it fits (the weapon's item subclass).
local CAMELOT_OWN = {}
do
	local STAFF, DAGGER, SWORD = 10, 15, 7
	-- The use casts the familiar's own aura (Intellect, an hour).
	local FAMILIAR = {
		key = "familiar",
		label = L["Familiar"],
		scroll = true,
		spells = {
			{ key = "catfamiliar", item = 277493, level = 25, ranks = { 1302303 } },
			{ key = "frogfamiliar", item = 277483, level = 16, ranks = { 1302285 } },
			{ key = "ratfamiliar", item = 275069, level = 5, ranks = { 1296202 } },
		},
	}
	-- The use is aimed at an item (Targets 16), as an oil's is: the macro hands
	-- it the main-hand weapon with /use 16 (Prompt/Macro.lua). It lasts an hour.
	local IMBUE = {
		key = "imbue",
		label = L["Weapon imbue"],
		scroll = true,
		imbue = true,
		spells = {
			{ key = "imbuegreaterflame", item = 277500, level = 46, ranks = { 1302311 }, enchant = 8716, weapon = STAFF },
			{ key = "imbuegreaterfrost", item = 277501, level = 46, ranks = { 1302312 }, enchant = 8717, weapon = STAFF },
			{ key = "imbueprecision", item = 277502, level = 46, ranks = { 1302310 }, enchant = 8718, weapon = STAFF },
			-- The client's data points this one at Lesser Flame's spell and
			-- enchant, so the spell's name would be Lesser Flame's: named by
			-- the item, and by this until the client has loaded the item.
			{ key = "imbuespellbreak", item = 277503, level = 46, ranks = { 1295720 }, enchant = 8700, weapon = STAFF,
				nameFromItem = L["Imbue Spellbreak"] },
			{ key = "imbueaccuracy", item = 277494, level = 25, ranks = { 1302306 }, enchant = 8711, weapon = STAFF },
			{ key = "imbuequickening", item = 277495, level = 25, ranks = { 1302307 }, enchant = 8712, weapon = STAFF },
			{ key = "imbuebalefrost", item = 277496, level = 25, ranks = { 1302305 }, enchant = 8714, weapon = STAFF },
			{ key = "imbueflame", item = 277497, level = 25, ranks = { 1302304 }, enchant = 8713, weapon = STAFF },
			{ key = "imbuemanablade", item = 277498, level = 25, ranks = { 1302308 }, enchant = 8715, weapon = DAGGER },
			{ key = "imbuefrost", item = 277485, level = 16, ranks = { 1302283 }, enchant = 8709, weapon = STAFF },
			{ key = "imbuestriking", item = 277486, level = 16, ranks = { 1302217 }, enchant = 8708, weapon = STAFF },
			{ key = "imbuebaleflame", item = 277487, level = 16, ranks = { 1302219 }, enchant = 8706, weapon = STAFF },
			{ key = "imbueiceknife", item = 277488, level = 16, ranks = { 1302284 }, enchant = 8710, weapon = DAGGER },
			{ key = "imbuespark", item = 277489, level = 16, ranks = { 1302227 }, enchant = 8707, weapon = SWORD },
			{ key = "imbuelesserflame", item = 274947, level = 5, ranks = { 1295720 }, enchant = 8700, weapon = STAFF },
			{ key = "imbuechillknife", item = 275067, level = 5, ranks = { 1296225 }, enchant = 8698, weapon = DAGGER },
		},
	}
	-- Vanilla's lists, with the mage's two after the armor. Forever made Omen
	-- of Clarity a passive every druid has from 20 (16864: Attributes_0 0x40,
	-- no duration): nothing to cast, so a druid there has tracking alone.
	for class, families in pairs(VANILLA_OWN) do
		local list = {}
		for _, family in ipairs(families) do
			if family.key ~= "omen" then list[#list + 1] = family end
		end
		CAMELOT_OWN[class] = list
	end
	table.insert(CAMELOT_OWN.MAGE, 2, FAMILIAR)
	table.insert(CAMELOT_OWN.MAGE, 3, IMBUE)
end

-- Forever's own: the vanilla tables less what its client deleted or moved,
-- copied entry by entry, since Classic Era still needs them as they are and
-- BuildBuffLookups writes class, order and auraIds onto the chosen set's.
-- Blessing of Sanctuary (20911-20914, Greater 25899) has no SpellName there;
-- Kings and Divine Spirit are trained there (SpellLevels 20, and 30 to 60),
-- in neither talent tree. A real table rather than an __index, because the
-- lookups walk ns.BUFFS with pairs.
local CAMELOT = {}
do
	local GONE = { sanctuary = true }
	local TRAINED = { kings = true, spirit = true }
	for class, list in pairs(VANILLA) do
		local copy = {}
		for _, buff in ipairs(list) do
			if not GONE[buff.key] then
				local entry = {}
				for field, value in pairs(buff) do entry[field] = value end
				if TRAINED[entry.key] then entry.talent = nil end
				copy[#copy + 1] = entry
			end
		end
		CAMELOT[class] = copy
	end
end

-- Forever: those buffs, and its own with the mage's scrolls. The name stays
-- "vanilla", which is the set everything else comes from. Its group versions
-- of a priest's, mage's and druid's buff reach the caster's whole party and
-- raid within 100 yards and need no target (target 56 in Forever's spell
-- data, where Classic Era's reach the target's party): groupIsRaid. The
-- Greater Blessings keep their by-class rule, and Battle Shout partyIsSubgroup.
local CAMELOT_SET = setmetatable({ buffs = CAMELOT, own = CAMELOT_OWN, groupIsRaid = true },
	{ __index = VANILLA_SET })

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
		{ key = "breath", ranks = { 5697 }, neverAuto = true, neverSelf = true },
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
	-- No class's own buffs yet: nobody here can check the ids a Mists client
	-- uses, and a table empty is "Myself" offering your group buff alone.
	own = {},
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

	-- New in 11.0, all specs, learned at 16 (Wowhead retail; retail SpellLevels 16).
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
	-- Empty for the same reason as Mists': untested ids, and most of these
	-- spells are gone from retail anyway.
	own = {},
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
	tbc = TBC_SET,
	-- Forever runs vanilla content, and the vanilla tables are the ones
	-- verified there in game, less what its client changed; its own buffs
	-- add the mage's scrolls.
	camelot = CAMELOT_SET,
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
	ns.GROUP_IS_RAID = chosen.groupIsRaid == true
	ns.GROUP_BY_CLASS = chosen.groupByClass
	ns.OWN_BUFFS = chosen.own
	ns.FAVOUR_ONLY_IDS = chosen.favourOnly
end

---------------------------------------------------------------------------
-- derived lookups
---------------------------------------------------------------------------

-- Every id any class can apply, used to tell a real class buff from a stray
-- heal-over-time or proc when deciding whether we owe somebody a favour: the
-- buffs above, and the set's favourOnly ones Manners never offers.
ns.ALL_BUFF_IDS = {}
ns.BUFF_BY_ID = {}
-- The same for the class's own buffs, apart: none of them is anybody's favour
-- (ALL_BUFF_IDS decides that), and none of them is walked by Automatic.
ns.OWN_BY_ID = {}
ns.OWN_SPELL_BY_KEY = {}
ns.OWN_FAMILY_BY_KEY = {}

-- The own-buff lookups, a family and a spell knowing each other: a spell's
-- `family` is what a press on it and the options page read back, and its
-- auraIds are what the reading matches, as for the tables above.
local function BuildOwnLookups()
	wipe(ns.OWN_BY_ID)
	wipe(ns.OWN_SPELL_BY_KEY)
	wipe(ns.OWN_FAMILY_BY_KEY)
	if type(ns.OWN_BUFFS) ~= "table" then ns.OWN_BUFFS = {} end
	for class, families in pairs(ns.OWN_BUFFS) do
		for index, family in ipairs(families) do
			family.class, family.order = class, index
			ns.OWN_FAMILY_BY_KEY[family.key] = family
			for _, spell in ipairs(family.spells) do
				spell.class, spell.family, spell.own = class, family, true
				spell.auraIds = {}
				for _, id in ipairs(spell.ranks) do
					spell.auraIds[#spell.auraIds + 1] = id
					ns.OWN_BY_ID[id] = spell
				end
				ns.OWN_SPELL_BY_KEY[spell.key] = spell
			end
		end
	end
end

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
	-- Ahead of the early return below: a client with no buffs for others
	-- still has an (empty) table of its own buffs to index.
	BuildOwnLookups()

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
	-- A favour, and nothing else: no buff of anybody's is filed under them.
	for _, id in ipairs(type(ns.FAVOUR_ONLY_IDS) == "table" and ns.FAVOUR_ONLY_IDS or {}) do
		ns.ALL_BUFF_IDS[id] = true
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

-- The class's own-buff families (see VANILLA_OWN), or nil for a class with
-- none on this client.
function ns.GetOwnFamilies(class)
	local families = ns.OWN_BUFFS[class or select(2, UnitClass("player"))]
	if families and #families > 0 then return families end
	return nil
end

function ns.FindOwnSpell(key)
	return key and ns.OWN_SPELL_BY_KEY[key] or nil
end

function ns.FindOwnFamily(key)
	return key and ns.OWN_FAMILY_BY_KEY[key] or nil
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
