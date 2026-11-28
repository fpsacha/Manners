-- Manners: My Buffs -- page layout owned by the optional module.

local api = assert(MannersAPI, 'Manners is required')
local ns = assert(api:ModuleContext('mybuffs'), 'Manners module API is missing')
local L = ns.L

local layout = {
			title = L["My own buffs"],
			blurb = L["Reminders for your own buffs, weapon oils, food, flasks and scrolls."],
			icon = "Interface\\AddOns\\Manners\\Textures\\Menu\\Self",
			sections = {
				{ key = "self.myself", header = "who.myselfHeader", items = {
					"who.self",
					-- Only the families this character knows are shown (their own rule).
					{ "who.own_omen", indent = true },
					-- A druid's Moonkin Form, never asked for in another form.
					{ "who.own_moonkinform", indent = true },
					-- A druid's Tree of Life (Burning Crusade, Season of Discovery).
					{ "who.own_treeoflife", indent = true },
					{ "who.own_aspect", indent = true },
					{ "who.own_trueshot", indent = true },
					-- Season of Discovery's Heart of the Lion (Classic Era).
					{ "who.own_heartofthelion", indent = true },
					{ "who.own_armor", indent = true },
					-- A mage's Dampen Magic or Amplify Magic, off until picked.
					{ "who.own_magicmod", indent = true },
					{ "who.ownDampenAlone", indent = 2 },
					{ "who.ownAmplifyAlone", indent = 2 },
					-- A mage's Mana Shield, and Fire Ward or Frost Ward, off until
					-- turned on; the line under them says they are reminded outside a
					-- fight only (Options/Who.lua, ownBriefNote).
					{ "who.own_manashield", indent = true },
					{ "who.own_ward", indent = true },
					{ "who.ownBriefNote", indent = true },
					{ "who.own_aura", indent = true },
					{ "who.own_righteousfury", indent = true },
					{ "who.own_innerfire", indent = true },
					{ "who.own_touchofweakness", indent = true },
					{ "who.own_shadowguard", indent = true },
					{ "who.own_shadowform", indent = true },
					{ "who.own_shield", indent = true },
					-- Season of Discovery's Spirit of the Alpha on a shaman who tanks.
					{ "who.own_spiritofthealpha", indent = true },
					{ "who.own_demonarmor", indent = true },
					-- A warlock's Grimoire of Sacrifice (Mists, retail).
					{ "who.own_grimoireofsacrifice", indent = true },
					-- A warlock's Demonic Sacrifice and Soul Link (Classic Era, Forever,
					-- Burning Crusade).
					{ "who.own_demonicsacrifice", indent = true },
					-- Forever's Soul Link of its own, with Demonic Pact known.
					{ "who.own_soullink", indent = true },
					-- A warlock's Detect Invisibility, off until it is turned on.
					{ "who.own_detectinvis", indent = true },
					-- A warlock's healthstone to make, when none is in the bags (every client).
					{ "who.own_makehealthstone", indent = true },
					-- A warlock's Unending Breath on himself, only while he swims.
					{ "who.own_selfbreath", indent = true },
					{ "who.own_tracking", indent = true },
					-- Forever's Find Treasure, kept on beside a gathering tracking.
					{ "who.own_findtreasure", indent = true },
				} },
				{ key = "self.when", title = L["When my own buffs come up"], items = {
					-- Where the reminders come up.
					"who.ownCities",
					"who.ownDungeons",
					{ "who.ownFoodOutside", indent = true },
					"who.ownItemsLast",
					"who.ownHoldMoving",
					-- The consumables on a button of their own (Prompt/Supplies.lua).
					"who.ownApart",
					-- Its key, set here rather than only under Key Bindings.
					{ "who.ownApartKey", indent = true },
					-- A warrior's shout for himself, alone (shown to a warrior only).
					"who.ownShout",
					-- The spells of those families you know, to leave out one by one.
					"who.own_leave",
					-- Why a buff of your own is not being offered, under the switches.
					"diagnostics.ownDiag",
				} },
				{ key = "self.topUp", header = "when.selfHeader", items = {
					"when.selfTopUp",
					{ "when.selfLead", indent = true },
					{ "when.selfLeadNote", indent = true },
				} },
				{ key = "self.weapons", title = L["Weapons"], items = {
					-- A shaman's weapon imbues, spells: one a hand at a time.
					"who.own_shamanimbue",
					-- Retail's off hand: Flametongue beside Windfury, or a shield's ward.
					"who.own_shamanimbueoff",
					-- Imbues ahead of the shield, for a shaman short of mana.
					{ "who.ownImbueFirst", indent = 2 },
					-- A Lightsmith paladin's rites on the weapon (retail).
					"who.own_rite",
					-- What goes on a weapon from the bags, per hand, while there is
					-- one in them; a rogue's poisons as spells on Mists and retail.
					"who.own_poisonmain",
					"who.own_poisonoff",
					"who.own_lethal",
					"who.own_nonlethal",
					"who.own_stonemain",
					"who.own_stoneoff",
					"who.own_oilmain",
					"who.own_oiloff",
					-- A warlock's Firestone or Spellstone on the main hand (Forever).
					"who.own_warlockstone",
					-- Making one when none is in the bags (Forever), off until turned on.
					{ "who.own_makestone", indent = true },
					"who.own_lure",
				} },
				{ key = "self.items", title = L["Food, flasks and scrolls"], items = {
					-- Food that gives Well Fed, off until it is turned on; every class has it.
					-- The foods to leave out right under it.
					"who.own_food",
					-- Which food, asked for on CurseForge: the best, the weakest, or one by name.
					{ "who.ownFoodChoice", indent = true },
					{ "who.own_leave_food", indent = true },
					-- The sleeping bag's Well-Rested, off until it is turned on;
					-- shown while the bag is in the bags (Classic Era, Forever).
					"who.own_rested",
					-- Its last five minutes, asked for on CurseForge.
					{ "who.ownRestedEarly", indent = true },
					-- Food and elixirs wait for the bag, asked for on CurseForge.
					{ "who.ownRestedFirst", indent = true },
					-- A companion pet, off until it is turned on; shown while one is in
					-- the bags or (Forever) the pet journal. Which pet, under it.
					-- HOME: companion pets (the journal's reminder on Mists and
					-- retail, and anything more about them) go here, with these two.
					"who.own_pet",
					{ "who.ownPetChoice", indent = true },
					-- Flasks, elixirs and a scroll of each stat, off until turned on;
					-- shown while one is in the bags (Buffs.lua, CONSUME).
					"who.own_flask",
					-- Battle Elixir on Burning Crusade and Mists, Elixir elsewhere;
					-- Guardian Elixir its own switch there, and on Classic Era and
					-- Forever the elixirs to keep up at once, under the one switch.
					"who.own_elixir",
					{ "who.own_elixirkeep", indent = true },
					"who.own_guardianelixir",
					-- Every scroll at once, then each scroll's own switch under it, one
					-- step further in: off, those switches are gone (Options/Who.lua,
					-- ownScrolls).
					"who.ownScrolls",
					{ "who.own_scrollagility", indent = true },
					{ "who.own_scrollstrength", indent = true },
					{ "who.own_scrollprotection", indent = true },
					{ "who.own_scrollintellect", indent = true },
					{ "who.own_scrollstamina", indent = true },
					{ "who.own_scrollspirit", indent = true },
					-- A mage's scrolls on Forever, while there is one in the bags.
					{ "who.own_familiar", indent = true },
					{ "who.own_imbue", indent = true },
				} },
				-- A buff of your own Manners does not know (OwnSpells.lua): the box,
				-- the answer to the last one typed, and a Remove for each spell.
				{ key = "self.custom", title = L["Add a spell of my own"], items = {
					"who.ownSpellNote",
					"who.ownSpellAdd",
					"who.ownSpellSaid",
					"who.ownSpell1", "who.ownSpell2", "who.ownSpell3", "who.ownSpell4", "who.ownSpell5",
					"who.ownSpell6", "who.ownSpell7", "who.ownSpell8", "who.ownSpell9", "who.ownSpell10",
				} },
			},
			subpages = {
				{ "self.myself", "self.when", "self.topUp" },
				{ "self.weapons" },
				{ "self.items" },
				{ "self.custom" },
			},
		}


api:RegisterOptionsPage("self", function()
	return { type = "group", name = L["My own buffs"], args = {} }
end, layout, "modules")
