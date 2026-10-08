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
--             matching and for "do you know this at all". Only the vanilla
--             and Burning Crusade sets have more than one (ranks were removed
--             game-wide in 4.0.1).
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
-- vanilla content: Classic Era and WoW Forever (Burning Crusade's set, below,
-- builds on it)
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
--   shared    a party aura somebody else of your class can put on you too
--             (a paladin's auras, a hunter's aspects and Trueshot), where two
--             of the same do not stack: Automatic passes over one that already
--             reaches you from them for the next you know, and offers nothing
--             when every one does. A pick is offered all the same.
--   charges   on a spell: how many charges a cast gives (a shaman's
--             Lightning Shield, Shadowguard, Inner Fire). With top-ups on,
--             one down to its last few is topped up like one running out.
--   anyCaster on a spell: one of it on you fills the family whoever cast it,
--             since the game allows one of the family on a target (another
--             shaman's Earth Shield, Burning Crusade). Somebody else's reads
--             as the family up, so nothing of yours is offered over it, and
--             is never topped up with yours.
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
-- Viper, Crusader Aura), so the tbc set below has a table of its own
-- (TBC_OWN).
--
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
		-- 20 charges on Forever ("Lasts 10 min or until 20 charges are used").
		{ key = "innerfire", spells = { { key = "innerfire", ranks = { 10952, 10951, 1006, 602, 7128, 588 }, charges = 20 } } },
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
			spells = { { key = "shadowguard", ranks = { 19312, 19311, 19310, 19309, 19308, 18137 }, charges = 3 } } },
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
			-- "Players may only have one Aura on them per Paladin", and two
			-- of the same from two paladins do not stack.
			shared = true,
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
			-- The Wild and the Pack reach the party.
			shared = true,
		},
		{
			key = "trueshot",
			-- The two 1299xxx ranks are Forever's own, below the talent's three.
			-- Every hunter has it from level 40 on Forever, and it reaches the
			-- party.
			spells = { { key = "trueshot", ranks = { 20906, 20905, 19506, 1299348, 1299346 }, talent = true } },
			shared = true,
		},
	},

	SHAMAN = {
		{
			key = "shield",
			label = L["Shield"],
			spells = {
				{ key = "lightningshield", ranks = { 10432, 10431, 8134, 945, 905, 325, 324 }, charges = 3 },
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

---------------------------------------------------------------------------
-- Burning Crusade Classic Anniversary
---------------------------------------------------------------------------

-- 2.5.6: the vanilla buffs with the ranks Burning Crusade added from 61 to
-- 70, and its new spells. Without a new rank in these lists, a level-70
-- wearing it reads as not having the buff at all. Every id, rank, level,
-- reagent and talent below is the client's own (SpellName, Spell,
-- SpellLevels, SpellReagents, SkillLineAbility, SpellEffect and Talent, build
-- 2.5.6.69795, from wago.tools); the vanilla ranks under the new ones are the
-- same ids at the same levels there.
--
-- What else differs from vanilla: Gift of the Wild's third rank eats Wild
-- Quillvine (ItemSparse 22148); Commanding Shout (469, learned at 68) is a
-- second shout, cast on yourself and reaching "all party members within 20
-- yards" like Battle Shout (target 20, radius 20); and Detect Invisibility is
-- one spell (132), the vanilla ranks above it gone. The reach is vanilla's:
-- a group version reaches the target's party (target 37), a Greater Blessing
-- everybody of the target's class (61), Salvation only your party or raid
-- (57). Kings, Sanctuary and Divine Spirit are still talents (Talent).
local WILD_QUILLVINE = 22148

-- One rank of a group version and the reagent it eats, as Greater does for
-- the Greater Blessings.
local function Rank(id, reagent)
	return { id = id, reagent = reagent }
end

local TBC = {
	MAGE = {
		{
			key = "intellect",
			ranks = { 27126, 10157, 10156, 1461, 1460, 1459 },
			group = { 27127, 23028 },
			manaOnly = true,
			-- Arcane Brilliance, both ranks an Arcane Powder.
			groupCast = { Rank(27127, ARCANE_POWDER), Rank(23028, ARCANE_POWDER) },
		},
	},

	PRIEST = {
		{
			key = "fortitude",
			ranks = { 25389, 10938, 10937, 2791, 1245, 1244, 1243 },
			group = { 25392, 21564, 21562 },
			-- Prayer of Fortitude: rank 1 a Holy Candle, ranks 2 and 3 a Sacred one.
			groupCast = { Rank(25392, SACRED_CANDLE), Rank(21564, SACRED_CANDLE), Rank(21562, HOLY_CANDLE) },
		},
		{
			key = "spirit",
			ranks = { 25312, 27841, 14819, 14818, 14752 },
			group = { 32999, 27681 },
			manaOnly = true,
			talent = true,
			-- Prayer of Spirit.
			groupCast = { Rank(32999, SACRED_CANDLE), Rank(27681, SACRED_CANDLE) },
		},
		{
			key = "shadow",
			ranks = { 25433, 10958, 10957, 976 },
			group = { 39374, 27683 },
			-- Prayer of Shadow Protection.
			groupCast = { Rank(39374, SACRED_CANDLE), Rank(27683, SACRED_CANDLE) },
		},
	},

	DRUID = {
		{
			key = "motw",
			ranks = { 26990, 9885, 9884, 8907, 5234, 6756, 5232, 1126 },
			group = { 26991, 21850, 21849 },
			-- Gift of the Wild: each rank its own reagent.
			groupCast = { Rank(26991, WILD_QUILLVINE), Rank(21850, WILD_THORNROOT), Rank(21849, WILD_BERRIES) },
		},
		{
			key = "thorns",
			ranks = { 26992, 9910, 9756, 8914, 1075, 782, 467 },
		},
	},

	PALADIN = {
		{
			key = "wisdom",
			ranks = { 27142, 25290, 19854, 19853, 19852, 19850, 19742 },
			group = { 27143, 25918, 25894 },
			manaOnly = true,
			groupCast = Greater(27143, 25918, 25894),
		},
		{
			key = "might",
			ranks = { 27140, 25291, 19838, 19837, 19836, 19835, 19834, 19740 },
			group = { 27141, 25916, 25782 },
			groupCast = Greater(27141, 25916, 25782),
		},
		{
			key = "kings",
			ranks = { 20217 },
			talent = true,
			group = { 25898 },
			groupCast = Greater(25898),
		},
		{
			key = "salvation",
			ranks = { 1038 },
			group = { 25895 },
			groupCast = Greater(25895),
			-- Your party or raid only (target 57), as on vanilla.
			groupOnly = true,
		},
		{
			key = "light",
			ranks = { 27144, 19979, 19978, 19977 },
			group = { 27145, 25890 },
			groupCast = Greater(27145, 25890),
		},
		{
			key = "sanctuary",
			ranks = { 27168, 20914, 20913, 20912, 20911 },
			group = { 27169, 25899 },
			talent = true,
			groupCast = Greater(27169, 25899),
		},
	},

	WARLOCK = {
		{
			key = "breath",
			ranks = { 5697 },
			group = { 131 }, -- a shaman's Water Breathing, as on vanilla
			neverSelf = true,
		},
	},

	WARRIOR = {
		{
			key = "battleshout",
			ranks = { 2048, 25289, 11551, 11550, 11549, 6192, 5242, 6673 },
			selfCast = true,
			partyOnly = true,
		},
		-- After Battle Shout, so Automatic gives that first. Nothing in the
		-- client's data makes the two exclusive: a party can wear both.
		{
			key = "commandingshout",
			ranks = { 469 },
			selfCast = true,
			partyOnly = true,
		},
	},
}

-- The levels of the ranks above that vanilla's RANK_LEVEL does not have
-- (SpellLevels, same build). No other set names these ids, so adding them
-- where every set looks changes nothing anywhere else. The shouts and
-- Sanctuary have none, as on vanilla.
for id, level in pairs({
	[27126] = 70, [25389] = 70, [25433] = 68, [26990] = 70, [26992] = 64,
	[27142] = 65, [27140] = 70, [27144] = 69, [25312] = 70,
}) do
	ns.RANK_LEVEL[id] = level
end

-- What each class puts on itself alone, as VANILLA_OWN, with every family's
-- Burning Crusade ranks and members: Molten Armor, Fel Armor, Crusader Aura,
-- Aspect of the Viper, Water Shield (trained at 62 here, no talent) and Earth
-- Shield. Without them one of those up would read as none of the family up,
-- and "Myself" would offer a spell that replaces it.
local TBC_OWN = {
	MAGE = {
		{
			key = "armor",
			label = L["Armor"],
			spells = {
				-- Frost Armor 1-3, then Ice Armor 1-5 from level 30: one line.
				{ key = "frostarmor", ranks = { 27124, 10220, 10219, 7320, 7302, 7301, 7300, 168 } },
				{ key = "magearmor", ranks = { 27125, 22783, 22782, 6117 } },
				{ key = "moltenarmor", ranks = { 30482 } },
			},
			dungeon = "magearmor", -- the mana back in a long fight
		},
	},

	PRIEST = {
		{ key = "innerfire",
			spells = { { key = "innerfire", ranks = { 25431, 10952, 10951, 1006, 602, 7128, 588 }, charges = 20 } } },
		-- Racials, each with a seventh rank: Touch of Weakness the undead's and
		-- now the blood elf's, Shadowguard the troll's (SkillLineAbility's
		-- race masks).
		{ key = "touchofweakness",
			spells = { { key = "touchofweakness", ranks = { 25461, 19266, 19265, 19264, 19262, 19261, 2652 } } } },
		{ key = "shadowguard",
			spells = { { key = "shadowguard", ranks = { 25477, 19312, 19311, 19310, 19309, 19308, 18137 }, charges = 3 } } },
	},

	WARLOCK = {
		{
			-- The family keeps vanilla's key, so a pick made there still reads.
			key = "demonarmor",
			label = L["Armor"],
			spells = {
				-- Demon Skin 1-2, then Demon Armor 1-6 from level 20: one line.
				{ key = "demonarmor", ranks = { 27260, 11735, 11734, 11733, 1086, 706, 696, 687 } },
				{ key = "felarmor", ranks = { 28189, 28176 } },
			},
			-- "Only one type of Armor spell can be active on the Warlock": the
			-- spell power for a dungeon, the armor out in the world.
			dungeon = "felarmor",
		},
	},

	PALADIN = {
		{
			key = "aura",
			label = L["Aura"],
			spells = {
				{ key = "devotionaura", ranks = { 27149, 10293, 10292, 1032, 10291, 643, 10290, 465 } },
				{ key = "retributionaura", ranks = { 27150, 10301, 10300, 10299, 10298, 7294 } },
				{ key = "concentrationaura", ranks = { 19746 } },
				{ key = "shadowresaura", ranks = { 27151, 19896, 19895, 19876 } },
				{ key = "frostresaura", ranks = { 27152, 19898, 19897, 19888 } },
				{ key = "fireresaura", ranks = { 27153, 19900, 19899, 19891 } },
				{ key = "sanctityaura", ranks = { 20218 }, talent = true },
				-- Mounted speed: up counts as your choice, but nobody wants to be
				-- reminded to ride faster, so Automatic never picks it.
				{ key = "crusaderaura", ranks = { 32223 }, neverAuto = true },
			},
			toggle = true,
			shared = true,
		},
		{
			key = "righteousfury",
			spells = { { key = "righteousfury", ranks = { 25780 } } },
			tank = true, -- Automatic reminds you only while you tank
		},
	},

	HUNTER = {
		{
			key = "aspect",
			label = L["Aspect"],
			spells = {
				{ key = "aspecthawk", ranks = { 27044, 25296, 14322, 14321, 14320, 14319, 14318, 13165 } },
				{ key = "aspectmonkey", ranks = { 13163 } },
				{ key = "aspectwild", ranks = { 27045, 20190, 20043 } },
				{ key = "aspectbeast", ranks = { 13161 } },
				{ key = "aspectviper", ranks = { 34074 } },
				-- Up counts as your choice; Automatic never runs you everywhere.
				{ key = "aspectcheetah", neverAuto = true, ranks = { 5118 } },
				{ key = "aspectpack", neverAuto = true, ranks = { 13159 } },
			},
			toggle = true,
			shared = true,
		},
		{
			key = "trueshot",
			spells = { { key = "trueshot", ranks = { 27066, 20906, 20905, 19506 }, talent = true } },
			shared = true,
		},
	},

	SHAMAN = {
		{
			key = "shield",
			label = L["Shield"],
			spells = {
				{ key = "lightningshield", ranks = { 25472, 25469, 10432, 10431, 8134, 945, 905, 325, 324 }, charges = 3 },
				{ key = "watershield", ranks = { 33736, 24398 }, charges = 3 },
				-- A Restoration talent, and "only one Elemental Shield can be
				-- active on a target" (Spell 974, 32593, 32594): a shaman wearing
				-- his own has chosen it, and one wearing another shaman's has had
				-- it chosen for him, so either way the family is up (anyCaster),
				-- talent or not. Never Automatic's pick, being the one for the tank.
				{ key = "earthshield", ranks = { 32594, 32593, 974 }, talent = true, neverAuto = true, charges = 6,
					anyCaster = true },
			},
		},
	},

	DRUID = {
		{
			key = "omen",
			spells = { { key = "omen", ranks = { 16864 }, talent = true } },
		},
	},
}

-- Tracking as on vanilla, every id there in this client too, and Find Fish
-- (43308, the Weather-Beaten Journal's): only one tracking is on at a time,
-- so with it missing here, Find Fish on would read as none and have another
-- offered over it.
do
	local spells = {}
	for _, spell in ipairs(TRACKING.spells) do spells[#spells + 1] = { key = spell.key, ranks = spell.ranks } end
	spells[#spells + 1] = { key = "findfish", ranks = { 43308 } }
	local tracking = { key = TRACKING.key, label = TRACKING.label, tracking = true, toggle = true, spells = spells }
	for _, class in ipairs({ "MAGE", "PRIEST", "WARLOCK", "PALADIN", "HUNTER", "SHAMAN", "DRUID", "WARRIOR", "ROGUE" }) do
		TBC_OWN[class] = TBC_OWN[class] or {}
		table.insert(TBC_OWN[class], tracking)
	end
end

local TBC_SET = setmetatable({
	name = "tbc",
	buffs = TBC,
	own = TBC_OWN,
	-- Vanilla's, less the two Detect Invisibility ranks this client deleted,
	-- with the sixth Soulstone (27239).
	favourOnly = { 6346, 546, 132, 27239, 20765, 20764, 20763, 20762, 20707 },
}, { __index = VANILLA_SET })

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
			-- The client's data points this one at Lesser Flame's spell and
			-- enchant, so the spell's name would be Lesser Flame's: named by
			-- the item, and by this until the client has loaded the item.
			-- Ranked with the level-5 scrolls, just above Lesser Flame, since
			-- what it puts on is Lesser Flame's +4 Fire (SpellItemEnchantment
			-- 8700; Wowhead Forever's tooltip for 277503 says as much): fourth
			-- in the list, Automatic used it over Flame's +12 at 46. Recheck
			-- when a build gives 277503's ItemEffect a spell of its own. Before
			-- Lesser Flame, the twin order ImbueScroll and the top-up rely on.
			{ key = "imbuespellbreak", item = 277503, level = 46, ranks = { 1295720 }, enchant = 8700, weapon = STAFF,
				nameFromItem = L["Imbue Spellbreak"] },
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
-- Every id below is the Mists client's own (wago.tools DB2 for build
-- 5.5.4.70032: SpellName, SkillLineAbility, SpellLevels, SpellEffect,
-- SpecializationSpells) and Wowhead MoP Classic's. Each buff for others is
-- cast at target 118 there, the target alone or, when the target is in your
-- party or raid, the whole party and raid ("If target is in your party or
-- raid, all party and raid members will be affected"): a stranger can be
-- given one, so none is partyOnly. The shouts are target 56, the caster's
-- whole party and raid within 100 yards, so they need no target and reach
-- past your own subgroup (partyIsSubgroup is left off).
local MISTS = {
	MAGE = {
		{
			key = "intellect",
			ranks = { 1459 }, -- Arcane Brilliance
			-- Dalaran Brilliance is the same buff learned from a different
			-- book; a target carrying it does not want ours on top.
			group = { 61316 },
			-- Not manaOnly here: 10% spell power and 5% critical strike, and
			-- the crit (SpellEffect 1459, effect 1: aura 290, 5) is the same
			-- aura Legacy of the White Tiger gives, worth as much to a warrior,
			-- a rogue, a death knight or a hunter (Focus on this client, so no
			-- mana bar either) as to a caster.
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
		{
			key = "emperor",
			ranks = { 115921 }, -- Legacy of the Emperor
			-- The cast is a dummy (SpellEffect: effect 3, no aura) that lands as
			-- one of two auras of its own: 117666 on your party and raid when
			-- the target is in it, 117667 on a target outside it. Without them
			-- somebody wearing a monk's Legacy reads as missing it, and a
			-- stranger's Legacy on you is nobody's favour.
			group = { 117666, 117667 },
		},
		{
			key = "whitetiger",
			ranks = { 116781 }, -- Legacy of the White Tiger
			-- Windwalker's alone (SpecializationSpells, spec 269), so not every
			-- monk knows it.
			talent = true,
		},
	},

	WARLOCK = {
		{ key = "darkintent", ranks = { 109773 } },
		-- Kept because somebody might want it, and kept away from Automatic
		-- because nobody standing in a city wants to be handed water breathing.
		-- A shaman's Water Breathing (131), its group id on vanilla, is gone
		-- from this client.
		{ key = "breath", ranks = { 5697 }, neverAuto = true, neverSelf = true },
	},

	WARRIOR = {
		{ key = "battleshout", ranks = { 6673 }, selfCast = true, partyOnly = true },
	},

	-- Horn of Winter is the death knight's Battle Shout: no target, the party
	-- and raid within 100 yards (Death Knight skill line, level 65).
	DEATHKNIGHT = {
		{ key = "hornofwinter", ranks = { 57330 }, selfCast = true, partyOnly = true },
	},
}

-- The level each buff above is learned at on this client (SpellLevels), for
-- "skip my own class when they can cast it too". Vanilla's table has the
-- same ids at a rank's level -- 1459 and 1126 at 1, Blessing of Might at 4 --
-- so read there a level-40 mage was taken for one who could cast Arcane
-- Brilliance (58) and skipped. Legacy of the White Tiger is a talent and the
-- shouts are cast on yourself, so their levels are never read.
local MISTS_RANK_LEVEL = {
	[1459] = 58, [21562] = 22, [1126] = 62, [20217] = 30, [19740] = 81,
	[115921] = 22, [109773] = 82, [5697] = 24,
}

---------------------------------------------------------------------------
-- Mists: what each class puts on itself alone
---------------------------------------------------------------------------

-- As VANILLA_OWN. The armors, Inner Fire and Inner Will, Righteous Fury and
-- the aspects last until they are cancelled or you die (SpellDuration -1),
-- so those families are toggles: none is ever a top-up. A shaman's shields
-- are timed (an hour, Earth Shield ten minutes). Each family's members are the
-- ones its client text says only one of may be up: "A Mage can only have one
-- Armor spell active at a time", "You can only have Inner Will or Inner Fire
-- active at a time", "Only one Aspect can be active at a time", "Only one of
-- your Elemental Shields can be active on you at once" (Lightning, Water and
-- Earth Shield all say it).
--
-- Left out, from the same data: Fel Armor (a passive here), Trueshot Aura
-- and Omen of Clarity (passives), a paladin's seals and auras (Devotion Aura
-- is a cooldown in 5.x; the resistance auras are gone), a death knight's
-- presences and a monk's or warrior's stances (stances), and tracking: the
-- minimap's menu here is checkboxes (Blizzard_Minimap's
-- MinimapTracking_Dropdown, loaded off vanilla), several on at once, so one
-- on says nothing about the rest being wanted.
local MISTS_OWN = {
	MAGE = {
		{
			key = "armor",
			label = L["Armor"],
			spells = {
				-- Learned at 34, 54 and 80, so the first a mage knows is Molten.
				{ key = "moltenarmor", ranks = { 30482 } },
				{ key = "frostarmor", ranks = { 7302 } },
				{ key = "magearmor", ranks = { 6117 } },
			},
			toggle = true,
		},
	},

	PRIEST = {
		{
			-- Vanilla's family key, which the options window already places
			-- (Options/Window/Layout.lua). No word of its own: named by the one
			-- you know first, Inner Fire (9) before Inner Will (80).
			key = "innerfire",
			spells = {
				{ key = "innerfire", ranks = { 588 } },
				{ key = "innerwill", ranks = { 73413 } },
			},
			toggle = true,
		},
	},

	PALADIN = {
		{ key = "righteousfury", tank = true, spells = { { key = "righteousfury", ranks = { 25780 } } } },
	},

	HUNTER = {
		{
			key = "aspect",
			label = L["Aspect"],
			spells = {
				-- The talent that replaces Aspect of the Hawk, first so a hunter
				-- who took it is reminded of it rather than of the Hawk.
				{ key = "aspectironhawk", ranks = { 109260 }, talent = true },
				{ key = "aspecthawk", ranks = { 13165 } },
				-- Up counts as your choice, so none of these is ever nagged over;
				-- but nobody wants to be reminded to run everywhere or to be
				-- untrackable (a glyph's), so Automatic never picks them.
				{ key = "aspectcheetah", neverAuto = true, ranks = { 5118 } },
				{ key = "aspectpack", neverAuto = true, ranks = { 13159 } },
				{ key = "aspectbeast", neverAuto = true, ranks = { 61648 } },
			},
			toggle = true,
		},
	},

	SHAMAN = {
		{
			key = "shield",
			label = L["Shield"],
			spells = {
				-- An hour each, with no charges to spend in 5.x.
				{ key = "lightningshield", ranks = { 324 } },
				{ key = "watershield", ranks = { 52127 } },
				-- Restoration's alone (SpecializationSpells, spec 264), and
				-- mostly the tank's; but it can go on yourself, and then it is
				-- your one Elemental Shield ("only one of your Elemental
				-- Shields can be active on you at once"): up, it is your
				-- choice, and Lightning or Water Shield would replace it.
				-- Never what Automatic picks or remembers, so a healer who put
				-- it on herself once is not told to again in a group. Ten
				-- minutes, nine charges (SpellAuraOptions ProcCharges 9).
				{ key = "earthshield", ranks = { 974 }, neverAuto = true, talent = true, charges = 9 },
			},
		},
	},

	-- WARLOCK, DRUID, ROGUE, WARRIOR, DEATHKNIGHT and MONK: nothing of their
	-- own that is a buff here, as above.
}

local MISTS_SET = {
	name = "mists",
	buffs = MISTS,
	own = MISTS_OWN,
	rankLevel = MISTS_RANK_LEVEL,
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
	-- As vanilla's: class buffs Manners never offers, counted as favours only.
	-- Fear Ward (Priest, 54), Water Walking (Shaman, 24) and Soulstone
	-- (Warlock, 18), each the client's own id here.
	favourOnly = { 6346, 546, 20707 },
}

---------------------------------------------------------------------------
-- retail: Midnight 12.1
---------------------------------------------------------------------------

-- Five class buffs are left, one per class, each an hour long and castable on
-- somebody outside your group. Paladins and death knights have nothing left,
-- and are named in `without` so the options page can say so.
--
-- Every id below was checked against retail's own spell data, build
-- 12.1.0.69933 (wago.tools: SpellName, Spell, SpellEffect, SpellMisc,
-- SpellLevels, SkillLineAbility, TraitDefinition), and the tooltips on Wowhead.
-- Arcane Intellect, Fortitude, Mark of the Wild and Skyfury apply their own id
-- to the target (aura effect, ImplicitTarget 118: "if the target is in your
-- party or raid, all party and raid members will be affected"), so a stranger
-- takes them and the one id is the aura. Battle Shout's targets are 56, the
-- caster's raid within 100 yards: no target, and the whole raid rather than
-- one subgroup, which is why this set leaves partyIsSubgroup out. Each of the
-- six also triggers an eight-second "Highlight" on its caster (1271904 to
-- 1271912), which is nothing anybody else wears and is left out.
local MAINLINE = {
	MAGE = {
		{
			key = "intellect",
			ranks = { 1459 },
			-- "Increasing their Intellect by 3%": nothing to a warrior, a rogue,
			-- a hunter, a death knight or a demon hunter, none of whom has a
			-- mana bar (ChrClasses.DisplayPower). It is the Mists reasoning: a
			-- buff only a caster benefits from, which manaOnly is how this
			-- addon says, and what "Skip players it does nothing for" (on by
			-- default) promises.
			manaOnly = true,
		},
	},

	PRIEST = {
		{ key = "fortitude", ranks = { 21562 } },
	},

	DRUID = {
		{ key = "motw", ranks = { 1126 } },
	},

	-- New in 11.0, all specs, learned at 16 (Wowhead retail; retail SpellLevels 16).
	-- Trained (SkillLineAbility), in no talent tree (no TraitDefinition row).
	SHAMAN = {
		{ key = "skyfury", ranks = { 462854 } },
	},

	EVOKER = {
		{
			key = "bronze",
			ranks = { 364342 },
			-- The thirteen auras the cast applies (its SpellEffect rows 0 to
			-- 12 trigger exactly these), one per class, none sharing the
			-- cast's id: without them a buffed target reads as missing it.
			-- Five more spells are named Blessing of the Bronze (432652,
			-- 432655, 432658, 432674, 442744); nothing in the client's spell
			-- data applies them, so they are not what an evoker's cast puts on
			-- anybody.
			group = {
				381732, 381741, 381746, 381748, 381749, 381750, 381751,
				381752, 381753, 381754, 381756, 381757, 381758,
			},
		},
		{
			-- Talent-gated (TraitDefinition), so gated on `known` like every
			-- spell here: an evoker without it never offers it.
			key = "sourceofmagic",
			ranks = { 369459 },
			manaOnly = true,
			talent = true,
			-- It goes to another player, never the evoker casting it.
			notSelf = true,
			-- "Limit 1": one ally carries it, and casting it on another takes
			-- it off the first. Every other mana user is always missing it, so
			-- Automatic walking on to it would move it from one passer-by to
			-- the next, off the healer it was meant for. Offered when it is
			-- pinned, and to whoever asks for it by name (ns.AskOnlyBuffs).
			neverAuto = true,
		},
	},

	WARRIOR = {
		{ key = "battleshout", ranks = { 6673 }, selfCast = true, partyOnly = true },
	},
}

local MAINLINE_SET = {
	name = "mainline",
	buffs = MAINLINE,
	-- Empty on purpose. What a retail class casts on itself alone is either a
	-- toggle with no end (the paladin's auras: duration -1 in SpellMisc), or a
	-- shield whose one-at-a-time rule a talent lifts (Elemental Orbit, 383010,
	-- lets a shaman wear two of Lightning, Water and Earth Shield), which a
	-- family of "only one of these up" would get wrong; and a rogue's poisons
	-- would need words of their own. "Myself" offers your own group buff.
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
	-- Class buffs others put on you that Manners never offers, counted as
	-- favours only, as the vanilla set counts them: Soulstone (20707, its
	-- "Soul stored by" aura on the target), a shaman's Water Walking (546) and
	-- a warlock's Unending Breath (5697). Fear Ward and Detect Invisibility are
	-- gone from retail's SpellName.
	favourOnly = { 20707, 546, 5697 },
	-- A paladin's auras reach the party and raid as their own ids (SpellEffect
	-- 65, an area aura on everybody within 40 yards) and land again each time
	-- you walk back into range: nobody's favour, as on vanilla, where the own
	-- table above is what says so. Here no family holds them, since they
	-- outlast death (SpellMisc Attributes_3 0x100000) and there is nothing to
	-- remind a paladin of. Devotion (465), Concentration (317920), Crusader
	-- (32223) and Retribution Aura (183435): retail SpellName and SpellEffect,
	-- and Wowhead ("Requires Paladin").
	notFavour = { [465] = true, [317920] = true, [32223] = true, [183435] = true },
	-- The level each buff above is learned at on retail (SpellLevels, build
	-- 12.1.0.69933; Wowhead "Requires level"), for "Skip my own class": the
	-- vanilla trainers' table (ns.RANK_LEVEL) puts Arcane Intellect and Mark
	-- of the Wild at 1. Source of Magic is a talent and Battle Shout a shout,
	-- neither read.
	rankLevel = { [1459] = 8, [21562] = 6, [1126] = 9, [462854] = 16, [364342] = 30 },
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
	-- Retail's (MAINLINE_SET): party auras that are nobody's favour though no
	-- family holds them.
	ns.NOT_FAVOUR_IDS = chosen.notFavour
	-- A set whose buffs are learned at other levels than vanilla's ranks
	-- brings its own (Mists, retail); the others read vanilla's.
	if chosen.rankLevel then ns.RANK_LEVEL = chosen.rankLevel end
end

-- The key of every own-buff family on any client, not only this one's. A
-- settings string names the families of the client it was made on
-- (ownBuffs.pick.<key>), and an import here tells another client's from a
-- setting a later version added with this (Commands.lua).
ns.OWN_FAMILY_ANY_CLIENT = {}
for _, set in pairs(SETS) do
	for _, families in pairs(set.own or {}) do
		for _, family in ipairs(families) do ns.OWN_FAMILY_ANY_CLIENT[family.key] = true end
	end
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
	if type(ns.NOT_FAVOUR_IDS) ~= "table" then ns.NOT_FAVOUR_IDS = {} end
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
