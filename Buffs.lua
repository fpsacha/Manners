-- Manners -- what each class can put on somebody else.
--
-- Ranks run highest first; the macro casts by name, so the game picks the best
-- rank you know and the list exists for aura matching and "do you know this at
-- all" tests. `group` is the raid-wide version -- a player carrying Gift of the
-- Wild already has Mark of the Wild, so it counts as covered.
--
-- Only buffs worth giving a passer-by are listed. Blessing of Freedom and
-- Protection are emergency spells, not courtesies, and are deliberately absent.

local ADDON, ns = ...

ns.BUFFS = {
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

-- Classes whose buffs overwrite one another, so a target can only ever carry
-- one of yours. Walking the list for these would mean replacing a blessing
-- somebody already has, which is worse than doing nothing.
ns.EXCLUSIVE_BUFFS = {
	PALADIN = true,
}

-- Which buff "auto" should reach for. Paladins are the only class where the
-- right answer depends on who is standing there.
ns.CLASS_AUTO = {
	PALADIN = { mana = "wisdom", other = "might" },
}

-- Classes with nothing to give. Listed explicitly so the options screen can say
-- so plainly rather than looking broken.
ns.CLASSES_WITHOUT_BUFFS = {
	HUNTER = true,
	ROGUE = true,
	SHAMAN = true, -- totems are placed, not cast on a person
}

---------------------------------------------------------------------------
-- derived lookups
---------------------------------------------------------------------------

-- Every id any class can apply, used to tell a real class buff from a stray
-- heal-over-time or proc when deciding whether we owe somebody a favour.
ns.ALL_BUFF_IDS = {}
ns.BUFF_BY_ID = {}

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

function ns.GetClassBuffs(class)
	return ns.BUFFS[class or select(2, UnitClass("player"))]
end

function ns.FindBuff(class, key)
	for _, buff in ipairs(ns.BUFFS[class] or {}) do
		if buff.key == key then return buff end
	end
end
