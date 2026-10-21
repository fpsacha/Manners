-- What goes on a weapon from the bags -- a rogue's poisons, a sharpening stone
-- or a weightstone, a wizard or mana oil, a fishing lure on a pole -- as your
-- own buffs, one family per kind and hand, on the clients that have them as
-- items (WoW Forever, Classic Era, Burning Crusade, Mists); and a rogue's
-- poisons as spells on Mists and retail, two families, the lethal and the
-- non-lethal. Buffs.lua holds the items (ids read from each client's own
-- item data, which tools/audit_ids.py holds them to), Core.lua reads the bags,
-- the weapon in each hand and the enchants on it (ScrollReady, ReadImbue),
-- Prompt/Macro.lua uses the item and aims it at the hand, and Core.lua's
-- REPLACE_ENCHANT answers the game's question about replacing an enchant for
-- a press of ours alone.
--
-- The mock's item API is the weapon's enchant list alone, so each scenario
-- stands the rest in as the mage's scroll scenarios do: what the bags hold,
-- the weapon in each hand (a made-up item id and its class and subclass, as
-- C_Item.GetItemInfoInstant answers them), the enchants on each hand and
-- your level. The list the client reads (Forever's C_Item.GetWeaponEnchantInfo)
-- and the global the Classic clients read (GetWeaponEnchantInfo, four values to
-- a hand) are the mock's own, off Mock.weaponEnchants.
--
-- Every scenario name starts with "hunt26-weapons:" so the mutations in
-- tests/mutations/hunt26-weapons.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, findOption = H.strangers, H.freshPrompt, H.findOption

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

-- Items, as Buffs.lua has them (poisons a rogue's, stones and oils anybody's).
local INSTANT_VI, DEADLY_V = 8928, 20844
local ROUGH_STONE, ROUGH_WEIGHT, COARSE_STONE, COARSE_WEIGHT = 2862, 3239, 2863, 3240
local DENSE_STONE, DENSE_WEIGHT, ELEMENTAL = 12404, 12643, 18262
local ELEMENTAL_NEW, ROUGH_NEW = 287980, 287978
local MINOR_OIL, WIZARD_OIL = 20744, 20750
local SHINY_BAUBLE = 6529
local ADAMANTITE, ANESTHETIC = 23529, 21835
local RAT = 275069
-- Their enchants (the enchant on the weapon says which item made it).
local INSTANT_VI_ENCHANT, DEADLY_IV_ENCHANT = 625, 627
local DENSE_STONE_ENCHANT, BRILLIANT_OIL_ENCHANT, CRUSADER = 1643, 2628, 1900
-- Enum.ItemEnchantType: a classic poison's is of the Imbue kind (the spell effect
-- the scrolls use), a stone's Temporary, an enchanter's Permanent.
local PERMANENT, TEMPORARY, IMBUE = 1, 2, 3
-- What each item's use casts (ItemEffect), which settles the press.
local INSTANT_VI_USE, DENSE_STONE_USE = 11340, 16138

-- Weapons by made-up item id, with the class and subclass GetItemInfoInstant
-- would give: a sword (7), a dagger (15), a mace (4), a staff (10), a fishing
-- pole (20), a shield (armor class, 6), and a book held in the off hand
-- (armor class, 0).
local SWORD, DAGGER, MACE, STAFF, POLE, SHIELD, BOOK = 900007, 900015, 900004, 900010, 900020, 900100, 900101
local INFO = {
	[SWORD] = { 2, 7 }, [DAGGER] = { 2, 15 }, [MACE] = { 2, 4 }, [STAFF] = { 2, 10 }, [POLE] = { 2, 20 },
	[SHIELD] = { 4, 6 }, [BOOK] = { 4, 0 },
}

local ITEM_NAMES = {
	[INSTANT_VI] = "Instant Poison VI", [DEADLY_V] = "Deadly Poison V",
	[ROUGH_STONE] = "Rough Sharpening Stone", [ROUGH_WEIGHT] = "Rough Weightstone",
	[COARSE_STONE] = "Coarse Sharpening Stone", [COARSE_WEIGHT] = "Coarse Weightstone",
	[DENSE_STONE] = "Dense Sharpening Stone", [DENSE_WEIGHT] = "Dense Weightstone",
	[ELEMENTAL] = "Elemental Sharpening Stone", [ELEMENTAL_NEW] = "Elemental Sharpening Stone",
	[ROUGH_NEW] = "Rough Sharpening Stone",
	[MINOR_OIL] = "Minor Wizard Oil", [WIZARD_OIL] = "Wizard Oil", [SHINY_BAUBLE] = "Shiny Bauble",
	[ADAMANTITE] = "Adamantite Sharpening Stone", [ANESTHETIC] = "Anesthetic Poison",
	[3776] = "Crippling Poison II",
	[RAT] = "Scroll of Rat Familiar",
}

local function icon(item) return 7100000 + item end
local function flat(text) return (tostring(text):gsub("\n", " / ")) end
local function macro(ns) return ns.Prompt:GetButton():GetAttribute("macrotext1") end
local function key(entry) return tostring(entry and entry.buff and entry.buff.key) end
local function said() return table.concat(Mock.printed, "\n") end
local function lines(ns) return table.concat(ns.MyselfLines(GetTime()), " / ") end

-- Your own entry in the queue as it stands, or nil.
local function mine(ns)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.reason == "self" then return entry end
	end
	return nil
end

local function family(ns, name)
	for _, known in ipairs(ns.KnownOwnFamilies()) do
		if known.key == name then return known end
	end
	return nil
end

-- One enchant as the client lists it: time left in milliseconds, from seconds.
local function entry(id, kind, seconds)
	return { hasEnchant = true, enchantType = kind, timeLeft = seconds * 1000, charges = 0, enchantID = id,
		enchantIconID = 0 }
end

-- The world a scenario stands in: bags (item -> count), hands (inventory
-- slot -> the weapon in it), enchants (slot -> the client's list), level,
-- `reads` (how many times the bags were asked for a count), `replaced` (how
-- many times ReplaceEnchant was called), `hidden` (the popups taken down),
-- `unloaded` (items the client has not loaded: no name until it has been asked
-- for them, `requested` saying which were).
local world

local TOUCHED = { "C_Item", "C_Spell", "GetInventoryItemID", "UnitLevel", "IsSpellKnown", "IsPlayerSpell",
	"IsResting", "StaticPopup_Hide" }

-- A spell whose name is not the item's: Crippling Poison II is item 3776, and
-- the spell its use casts (11202) is named Crippling Poison, as the client
-- (SpellName) has it.
local CRIPPLING_II, CRIPPLING_II_USE = 3776, 11202

local function install()
	-- The spell names the client has for what an item's use casts, over the
	-- mock's own.
	rawset(_G, "C_Spell", nil)
	local spells = C_Spell
	rawset(_G, "C_Spell", setmetatable({
		GetSpellName = function(id)
			if id == CRIPPLING_II_USE then return "Crippling Poison" end
			return spells.GetSpellName(id)
		end,
	}, { __index = spells }))
	-- The client's own list where the mock has it (Forever's), kept as the
	-- weapon's enchants; the rest of C_Item is the scenario's.
	rawset(_G, "C_Item", nil)
	local list = C_Item and C_Item.GetWeaponEnchantInfo
	rawset(_G, "C_Item", {
		GetItemCount = function(id)
			world.reads = world.reads + 1
			return world.bags[id] or 0
		end,
		-- An item the client has not loaded has no name until it is asked for.
		GetItemNameByID = function(id)
			if world.unloaded and world.unloaded[id] then return nil end
			return ITEM_NAMES[id]
		end,
		RequestLoadItemDataByID = function(id) world.requested[id] = true end,
		GetItemIconByID = function(id) return icon(id) end,
		GetItemInfoInstant = function(id)
			local info = INFO[id]
			if info then return id, "Weapon", "", "INVTYPE_WEAPON", icon(id), info[1], info[2] end
			return id, "Miscellaneous", "", "", icon(id), 15, 0
		end,
		GetWeaponEnchantInfo = list,
		ReplaceEnchant = function() world.replaced = world.replaced + 1 end,
	})
	rawset(_G, "GetInventoryItemID", function(unit, slot)
		if unit == "player" then return world.hands[slot] end
		return nil
	end)
	rawset(_G, "UnitLevel", function(unit)
		if unit == "player" then return world.level end
		return 12
	end)
	rawset(_G, "StaticPopup_Hide", function(which) world.hidden[#world.hidden + 1] = which end)
	-- The enchants are the world's, read when asked.
	Mock.weaponEnchants = setmetatable({}, { __index = function(_, slot)
		return world.enchants[slot == 0 and 16 or slot == 1 and 17 or 18]
	end })
end

-- One session on opts.flavour (WoW Forever by default) as opts.class (a rogue),
-- with opts.bags, opts.hands (the main hand a dagger by default), opts.enchants
-- ({ [16] = list, [17] = list }), opts.level (60), opts.known (the spells
-- learned), opts.held (your own auras; a mage's own Arcane Intellect is up
-- unless she is told otherwise), opts.tree (the frames recorded, for the
-- prompt's icon). body(ns) runs and everything is put back, whether it
-- finished or threw.
local function with(scenario, opts, body)
	Mock.reset()
	Mock.setFlavour(opts.flavour or "camelot")
	Mock.class = opts.class or "ROGUE"
	world = { bags = opts.bags or {}, hands = opts.hands or { [16] = DAGGER }, enchants = opts.enchants or {},
		level = opts.level or 60, reads = 0, replaced = 0, hidden = {}, unloaded = opts.unloaded, requested = {} }
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	install()
	if opts.known then
		local learned = {}
		for _, id in ipairs(opts.known) do learned[id] = true end
		rawset(_G, "IsSpellKnown", function(id) return learned[id] == true end)
		rawset(_G, "IsPlayerSpell", function(id) return learned[id] == true end)
	end
	if opts.tree then FT.install() end
	local undo = strangers({})
	local ok, err = pcall(function()
		local held = {}
		if (opts.class or "ROGUE") == "MAGE" then held[1459] = true end
		for _, id in ipairs(opts.held or {}) do held[id] = true end
		Mock.playerHeld = held
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		Mock.playerHeld = held
		body(ns, held)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	undo()
	if opts.tree then FT.uninstall() end
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.weaponEnchants = nil
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- The bags changed, as the client says so.
local function restock(ns, bags)
	world.bags = bags
	ns.addon:BAG_UPDATE_DELAYED()
end

-- A weapon put in a hand, as the client says so.
local function wield(ns, slot, item)
	world.hands[slot] = item
	ns.addon:PLAYER_EQUIPMENT_CHANGED(nil, slot, item == nil)
end

-- One press of the prompt on `want`, with the question the game asks while the
-- macro runs (`between`, called between PreClick and PostClick) and the SENT
-- that settles it. Returns what the button ran, or nil when the prompt was
-- not on `want`.
local function press(ns, scenario, want, between, spellId, guid)
	ns.Prompt:Refresh()
	if key(ns.Prompt:Showing()) ~= want then
		fail(scenario, ("SKIPPED -- the prompt is on %s, not %s"):format(key(ns.Prompt:Showing()), want))
		return nil
	end
	local button = ns.Prompt:GetButton()
	button.scripts.PreClick(button, "LeftButton", true)
	local ran = button:GetAttribute("macrotext1")
	if between then between() end
	button.scripts.PostClick(button, "LeftButton", true)
	if spellId then ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, guid, spellId) end
	return ran
end

-- ------------------------------------------------------------------ 1
-- A rogue with poisons in the bags and nothing on either dagger: the main
-- hand's first, used by its item id and aimed at slot 16; once that hand
-- carries one, the off hand's, aimed at slot 17. The items are named for the
-- hand they are for, and the prompt is on the item's icon.
do
	local scenario = "hunt26-weapons: a rogue's poisons are offered one hand at a time"
	with(scenario, { bags = { [INSTANT_VI] = 2, [DEADLY_V] = 1 }, hands = { [16] = DAGGER, [17] = DAGGER },
		tree = true }, function(ns)
			local me = mine(ns)
			if key(me) ~= "w8928m" then
				fail(scenario, "a level-60 rogue with Instant Poison VI in the bags and bare daggers was offered " .. key(me))
				return
			end
			ns.Prompt:Refresh()
			if macro(ns) ~= "/use item:" .. INSTANT_VI .. "\n/use 16" then
				fail(scenario, "the main hand's macro reads " .. flat(macro(ns)))
			end
			if ns.Prompt:Regions().icon:GetTexture() ~= icon(INSTANT_VI) then
				fail(scenario, "the prompt shows icon " .. tostring(ns.Prompt:Regions().icon:GetTexture()) .. ", not the poison's")
			end
			if ns.BuffName(me.buff) ~= "Instant Poison VI (Main Hand)" then
				fail(scenario, "the main hand's poison is named " .. tostring(ns.BuffName(me.buff)))
			end
			local summary = ns.Prompt:ClickSummary(ns.Prompt:Showing())
			if summary[1] ~= "Uses |cffffffffInstant Poison VI (Main Hand)|r from your bags." then
				fail(scenario, "the tooltip says " .. flat(table.concat(summary, "\n")))
			end
			if ns.OwnFamilyLabel(family(ns, "poisonmain")) ~= "Poison (Main Hand)"
				or ns.OwnFamilyLabel(family(ns, "poisonoff")) ~= "Poison (Off Hand)" then
				fail(scenario, "the families are called " .. tostring(ns.OwnFamilyLabel(family(ns, "poisonmain"))) .. " and "
					.. tostring(ns.OwnFamilyLabel(family(ns, "poisonoff"))))
			end

			-- The main hand done: the off hand's.
			world.enchants[16] = { entry(INSTANT_VI_ENCHANT, IMBUE, 1800) }
			me = mine(ns)
			if key(me) ~= "w8928o" then
				fail(scenario, "with the main hand poisoned, the off hand was offered " .. key(me))
				return
			end
			ns.Prompt:Refresh()
			if macro(ns) ~= "/use item:" .. INSTANT_VI .. "\n/use 17" then
				fail(scenario, "the off hand's macro reads " .. flat(macro(ns)))
			end
			if ns.BuffName(me.buff) ~= "Instant Poison VI (Off Hand)" then
				fail(scenario, "the off hand's poison is named " .. tostring(ns.BuffName(me.buff)))
			end

			-- Both done.
			world.enchants[17] = { entry(DEADLY_IV_ENCHANT, TEMPORARY, 1800) }
			if mine(ns) then fail(scenario, "with both hands poisoned, you were offered " .. key(mine(ns))) end
		end)
end

-- ------------------------------------------------------------------ 2
-- A hand is offered an enhancement when it is bare: not under a temporary
-- enchant, whoever's, and not over a permanent one, which is no temporary one.
-- With top-ups on, the one that made the enchant is offered again when it runs
-- low, and only that one: another's running low is left to run out.
do
	local scenario = "hunt26-weapons: a bare hand is offered a stone, a hand with an enchant is not"
	with(scenario, { class = "WARRIOR", level = 40, bags = { [DENSE_STONE] = 2 }, hands = { [16] = SWORD } },
		function(ns)
			local me = mine(ns)
			if key(me) ~= "w12404m" then
				fail(scenario, "a warrior with a sword and Dense Sharpening Stones was offered " .. key(me))
				return
			end
			world.enchants[16] = { entry(DENSE_STONE_ENCHANT, TEMPORARY, 1800) }
			if mine(ns) then fail(scenario, "with a stone's enchant on the sword, you were offered " .. key(mine(ns))) end
			if not lines(ns):find("Dense Sharpening Stone (Main Hand) is up.", 1, true) then
				fail(scenario, "/manners debug says: " .. lines(ns))
			end
			if ns.db.char.ownLast.stonemain ~= "w12404m" then
				fail(scenario, "the stone on the weapon was not remembered: " .. tostring(ns.db.char.ownLast.stonemain))
			end

			-- Someone else's enchant, an oil's, is up all the same.
			world.enchants[16] = { entry(BRILLIANT_OIL_ENCHANT, TEMPORARY, 1800) }
			if mine(ns) then fail(scenario, "with an oil on the sword, you were offered " .. key(mine(ns))) end
			if not lines(ns):find("the weapon already carries a temporary enchant.", 1, true) then
				fail(scenario, "/manners debug says, of an oil: " .. lines(ns))
			end

			-- A permanent enchant is no temporary one.
			world.enchants[16] = { entry(CRUSADER, PERMANENT, 0) }
			if key(mine(ns)) ~= "w12404m" then
				fail(scenario, "with only Crusader on the sword, you were offered " .. key(mine(ns)))
			end

			-- Running low, with top-ups on: the stone that made it, not the oil.
			ns.db.profile.filters.whenBuffed = "refresh"
			world.enchants[16] = { entry(DENSE_STONE_ENCHANT, TEMPORARY, 120) }
			me = mine(ns)
			if key(me) ~= "w12404m" or me.remaining == nil or me.remaining > 121 then
				fail(scenario, ("two minutes of Dense Sharpening Stone with top-ups on offered %s, %s left")
					:format(key(me), tostring(me and me.remaining)))
			end
			world.enchants[16] = { entry(DENSE_STONE_ENCHANT, TEMPORARY, 1800) }
			if mine(ns) then fail(scenario, "half an hour of a stone with top-ups on offered " .. key(mine(ns))) end
			world.enchants[16] = { entry(BRILLIANT_OIL_ENCHANT, TEMPORARY, 120) }
			if mine(ns) then fail(scenario, "another's oil running low was topped up with a stone: " .. key(mine(ns))) end
		end)
end

-- ------------------------------------------------------------------ 3
-- The item fits the weapon in the hand: a sharpening stone a sword, a
-- weightstone a mace, an oil any melee weapon, a lure only a pole; and the
-- level asked, and the class: a poison is a rogue's, a mage is offered an oil
-- on a staff.
do
	local scenario = "hunt26-weapons: the item for the weapon, the level and the class"
	with(scenario, { class = "WARRIOR", level = 40, bags = { [DENSE_STONE] = 1, [DENSE_WEIGHT] = 1 },
		hands = { [16] = MACE } }, function(ns)
		if key(mine(ns)) ~= "w12643m" then
			fail(scenario, "a mace with a stone and a weightstone in the bags was offered " .. key(mine(ns)))
		end
		wield(ns, 16, SWORD)
		if key(mine(ns)) ~= "w12404m" then
			fail(scenario, "a sword with a stone and a weightstone in the bags was offered " .. key(mine(ns)))
		end
		restock(ns, { [DENSE_WEIGHT] = 1 })
		if mine(ns) then fail(scenario, "a sword was offered a weightstone: " .. key(mine(ns))) end
		if not lines(ns):find("Dense Weightstone (Main Hand) does not fit the weapon in that hand.", 1, true) then
			fail(scenario, "/manners debug says: " .. lines(ns))
		end
	end)

	local level = "hunt26-weapons: a level asks for its stone"
	with(level, { class = "WARRIOR", level = 4, bags = { [ROUGH_WEIGHT] = 1, [COARSE_WEIGHT] = 1 },
		hands = { [16] = MACE } }, function(ns)
		if key(mine(ns)) ~= "w3239m" then
			fail(level, "a level-4 warrior with a Rough and a Coarse Weightstone was offered " .. key(mine(ns)))
		end
		restock(ns, { [COARSE_WEIGHT] = 1 })
		if mine(ns) then fail(level, "a level-4 warrior was offered a stone that asks for level 5: " .. key(mine(ns))) end
		if not lines(ns):find("Coarse Weightstone (Main Hand) needs level 5.", 1, true) then
			fail(level, "/manners debug says: " .. lines(ns))
		end
		world.level = 5
		if key(mine(ns)) ~= "w3240m" then fail(level, "at level 5 you were offered " .. key(mine(ns))) end
	end)

	local mage = "hunt26-weapons: a mage's oil goes on the staff and a poison is a rogue's"
	with(mage, { class = "MAGE", level = 45, bags = { [WIZARD_OIL] = 1, [INSTANT_VI] = 1 }, hands = { [16] = STAFF } },
		function(ns)
			if key(mine(ns)) ~= "w20750m" then
				fail(mage, "a mage with a staff, a Wizard Oil and a poison was offered " .. key(mine(ns)))
			end
			if family(ns, "poisonmain") or family(ns, "poisonoff") then
				fail(mage, "a mage has a poison family of her own")
			end
			restock(ns, { [INSTANT_VI] = 1 })
			if mine(ns) then fail(mage, "a mage carrying a poison alone was offered " .. key(mine(ns))) end
			if ns.OwnItemsHeld() then fail(mage, "a poison alone is an item a mage can use") end
		end)

	local pole = "hunt26-weapons: a lure goes on a fishing pole, in the main hand alone"
	with(pole, { class = "WARRIOR", level = 50, bags = { [SHINY_BAUBLE] = 3, [DENSE_STONE] = 1, [WIZARD_OIL] = 1 },
		hands = { [16] = POLE } }, function(ns)
		if key(mine(ns)) ~= "w6529m" then
			fail(pole, "a fishing pole with a lure, a stone and an oil in the bags was offered " .. key(mine(ns)))
		end
		ns.Prompt:Refresh()
		if macro(ns) ~= "/use item:" .. SHINY_BAUBLE .. "\n/use 16" then
			fail(pole, "the lure's macro reads " .. flat(macro(ns)))
		end
		if ns.FindOwnFamily("lureoff") then fail(pole, "a lure has an off-hand family") end
		wield(ns, 16, SWORD)
		if key(mine(ns)) ~= "w12404m" then
			fail(pole, "with a sword in hand, the lure and the oil were not left for the stone: " .. key(mine(ns)))
		end
		if not lines(ns):find("Shiny Bauble (Main Hand) does not fit the weapon in that hand.", 1, true) then
			fail(pole, "/manners debug says, of a lure on a sword: " .. lines(ns))
		end
	end)
end

-- ------------------------------------------------------------------ 4
-- The hands are told apart: the off hand's enchants are its own, a weapon in
-- it is what it is offered for, and a shield or a book held in it is nothing a
-- poison goes on. A two-hander has no off hand.
do
	local scenario = "hunt26-weapons: each hand is read for itself, and a shield takes nothing"
	with(scenario, { bags = { [INSTANT_VI] = 2 }, hands = { [16] = DAGGER, [17] = SHIELD } }, function(ns)
		if key(mine(ns)) ~= "w8928m" then
			fail(scenario, "bare dagger and a shield: " .. key(mine(ns)))
		end
		world.enchants[16] = { entry(INSTANT_VI_ENCHANT, IMBUE, 1800) }
		if mine(ns) then
			fail(scenario, "with the main hand poisoned and a shield in the off hand, you were offered " .. key(mine(ns)))
		end
		if not lines(ns):find("Poison (Off Hand): there is no weapon in that hand.", 1, true) then
			fail(scenario, "/manners debug says, of a shield: " .. lines(ns))
		end
		wield(ns, 17, BOOK)
		if mine(ns) then fail(scenario, "a book held in the off hand was offered a poison: " .. key(mine(ns))) end
		wield(ns, 17, nil)
		if mine(ns) then fail(scenario, "an empty off hand was offered a poison: " .. key(mine(ns))) end

		-- A dagger in the off hand: its own, with the enchant on the other hand not its.
		wield(ns, 17, DAGGER)
		if key(mine(ns)) ~= "w8928o" then fail(scenario, "a bare off-hand dagger was offered " .. key(mine(ns))) end
		world.enchants[17] = { entry(DEADLY_IV_ENCHANT, TEMPORARY, 1800) }
		world.enchants[16] = nil
		if key(mine(ns)) ~= "w8928m" then
			fail(scenario, "the off hand poisoned and the main hand bare, you were offered " .. key(mine(ns)))
		end
	end)
end

-- ------------------------------------------------------------------ 5
-- The press is settled by the spell the item's use casts, which takes three
-- seconds: until it is over the hand is busy, so an oil is not offered over the
-- stone going on; a cast cut short is offered again, as a scroll's is, and a
-- lure's five seconds are covered.
do
	local scenario = "hunt26-weapons: a stone going on keeps the hand from an oil, and a cut short cast is offered again"
	with(scenario, { class = "WARRIOR", level = 40, bags = { [DENSE_STONE] = 2, [WIZARD_OIL] = 1 },
		hands = { [16] = SWORD } }, function(ns)
		local ran = press(ns, scenario, "w12404m", nil, DENSE_STONE_USE, "Cast-stone-1")
		if ran ~= "/use item:" .. DENSE_STONE .. "\n/use 16" then
			fail(scenario, "SKIPPED -- the press did not go out: " .. flat(ran))
			return
		end
		if ns.pendingClick then fail(scenario, "the stone's use was never settled") end
		if not ns.IsBlocked(ns.UnitFullName("player"), "w12404m") then
			fail(scenario, "the stone was not given its retry cooldown after the press")
		end
		Mock.advance(1)
		if mine(ns) then
			fail(scenario, "with the stone being put on, the hand was offered " .. key(mine(ns)))
		end
		-- The cast cut short: the stone is back once the short block is out.
		Mock.printed = {}
		ns.addon:UNIT_SPELLCAST_INTERRUPTED(nil, "player", "Cast-stone-1", DENSE_STONE_USE)
		Mock.advance(2.1)
		if key(mine(ns)) ~= "w12404m" then
			fail(scenario, "2 s after the stone's cast was interrupted, you were offered " .. key(mine(ns)))
		end

		-- Succeeded: the enchant on the weapon is the answer, and nothing is
		-- taken back by a later interrupt.
		Mock.advance(5)
		wipe(ns.tried)
		if not press(ns, scenario, "w12404m", nil, DENSE_STONE_USE, "Cast-stone-2") then return end
		Mock.advance(3)
		ns.addon:UNIT_SPELLCAST_SUCCEEDED(nil, "player", "Cast-stone-2", DENSE_STONE_USE)
		world.enchants[16] = { entry(DENSE_STONE_ENCHANT, TEMPORARY, 1800) }
		ns.addon:WEAPON_ENCHANT_CHANGED()
		ns.addon:UNIT_SPELLCAST_INTERRUPTED(nil, "player", "Cast-stone-2", DENSE_STONE_USE)
		Mock.advance(3)
		if mine(ns) then fail(scenario, "with the stone on the sword, you were offered " .. key(mine(ns))) end
	end)

	local lure = "hunt26-weapons: a lure's five-second cast is held to the end"
	with(lure, { class = "WARRIOR", level = 20, bags = { [SHINY_BAUBLE] = 2 }, hands = { [16] = POLE } }, function(ns)
		if not press(ns, lure, "w6529m", nil, 8087, "Cast-lure-1") then return end
		-- Seven seconds in, pushed back by a hit, the cast is stopped: still the lure's.
		Mock.advance(7)
		ns.addon:UNIT_SPELLCAST_INTERRUPTED(nil, "player", "Cast-lure-1", 8087)
		Mock.advance(2.1)
		if key(mine(ns)) ~= "w6529m" then
			fail(lure, "a lure interrupted 7 s after the press was not offered again: " .. key(mine(ns)))
		end
		-- And not after nine.
		Mock.advance(5)
		wipe(ns.tried)
		if not press(ns, lure, "w6529m", nil, 8087, "Cast-lure-2") then return end
		Mock.advance(9)
		ns.addon:UNIT_SPELLCAST_INTERRUPTED(nil, "player", "Cast-lure-2", 8087)
		Mock.advance(2.1)
		if not ns.IsBlocked(ns.UnitFullName("player"), "w6529m") then
			fail(lure, "an interrupt 9 s after the lure's press took the press back")
		end
	end)
end

-- ------------------------------------------------------------------ 6
-- Putting an enhancement over the one on the weapon makes the game ask whether
-- to replace it. The question is answered for a press of ours that is going
-- on -- stamped by PreClick, not yet filed by PostClick -- carrying an
-- enhancement, inside two seconds, once; and for nothing else: not when no
-- press was made, not after it was filed, not late, not for a press that
-- carried no enhancement, not twice, and not again once the game has called
-- the answer forbidden.
do
	local scenario = "hunt26-weapons: the replace question is answered for our own press and never otherwise"
	with(scenario, { class = "WARRIOR", level = 40, bags = { [DENSE_STONE] = 2 }, hands = { [16] = SWORD },
		enchants = { [16] = { entry(DENSE_STONE_ENCHANT, TEMPORARY, 120) } } }, function(ns)
		ns.db.profile.filters.whenBuffed = "refresh"
		if not (Mock.registeredEvents.REPLACE_ENCHANT and Mock.registeredEvents.WEAPON_ENCHANT_CHANGED
			and Mock.registeredEvents.ADDON_ACTION_FORBIDDEN) then
			fail(scenario, "the replace question, the enchant change and the forbidden warning are not watched")
		end

		-- No press at all since the session began: the player's own use of a
		-- stone, say. (Nothing is stamped, so that nothing but the want of a press
		-- can turn the question away.)
		ns.armedWeapon, ns.pressAt, ns.lastClickTime = nil, nil, nil
		ns.addon:REPLACE_ENCHANT(nil, "Dense Sharpening Stone", "Dense Sharpening Stone")
		if world.replaced ~= 0 then fail(scenario, "a question with no press of ours was answered") end

		-- The top-up pressed, the question asked in the middle of the macro.
		local ran = press(ns, scenario, "w12404m", function()
			ns.addon:REPLACE_ENCHANT(nil, "Dense Sharpening Stone", "Dense Sharpening Stone")
		end)
		if ran ~= "/use item:" .. DENSE_STONE .. "\n/use 16" then
			fail(scenario, "SKIPPED -- the top-up's press did not go out: " .. flat(ran))
			return
		end
		if world.replaced ~= 1 then
			fail(scenario, ("the question asked during our press was answered %d times"):format(world.replaced))
		end
		if world.hidden[1] ~= "REPLACE_ENCHANT" then
			fail(scenario, "the question's popup was not taken down: " .. tostring(world.hidden[1]))
		end
		-- Asked again in the same press: one press, one answer.
		world.replaced = 0
		ns.addon:REPLACE_ENCHANT(nil, "Dense Sharpening Stone", "Dense Sharpening Stone")
		if world.replaced ~= 0 then fail(scenario, "a second question after the press was filed was answered") end

		-- A press whose question comes late: not answered.
		Mock.advance(20)
		wipe(ns.tried)
		local late = press(ns, scenario, "w12404m", function()
			Mock.advance(3)
			ns.addon:REPLACE_ENCHANT(nil, "Dense Sharpening Stone", "Dense Sharpening Stone")
		end)
		if not late then return end
		if world.replaced ~= 0 then fail(scenario, "a question 3 s into a press was answered") end

		-- Twice in one press: once.
		Mock.advance(20)
		wipe(ns.tried)
		if not press(ns, scenario, "w12404m", function()
			ns.addon:REPLACE_ENCHANT(nil, "a", "b")
			ns.addon:REPLACE_ENCHANT(nil, "a", "b")
		end) then return end
		if world.replaced ~= 1 then
			fail(scenario, ("two questions in one press were answered %d times"):format(world.replaced))
		end

		-- A press that asked no question, filed, and the player's own question a
		-- moment after it: not ours to answer.
		Mock.advance(20)
		wipe(ns.tried)
		if not press(ns, scenario, "w12404m", nil) then return end
		Mock.advance(0.5)
		world.replaced = 0
		ns.addon:REPLACE_ENCHANT(nil, "a", "b")
		if world.replaced ~= 0 then
			fail(scenario, "a question 0.5 s after a press that asked none was filed was answered")
		end

		-- The game calls the answer forbidden: never again.
		ns.addon:ADDON_ACTION_FORBIDDEN(nil, "Manners", "C_Item.ReplaceEnchant()")
		Mock.advance(20)
		wipe(ns.tried)
		world.replaced = 0
		if not press(ns, scenario, "w12404m", function()
			ns.addon:REPLACE_ENCHANT(nil, "a", "b")
		end) then return end
		if world.replaced ~= 0 then fail(scenario, "the question was answered after the game called the answer forbidden") end
	end)

	-- A press of ours that carries no enhancement: a mage's familiar.
	local scroll = "hunt26-weapons: a press that is no enhancement leaves the replace question to the player"
	with(scroll, { class = "MAGE", level = 12, bags = { [RAT] = 1 }, hands = { [16] = STAFF } }, function(ns)
		local ran = press(ns, scroll, "ratfamiliar", function()
			ns.addon:REPLACE_ENCHANT(nil, "a", "b")
		end)
		if not ran then return end
		if world.replaced ~= 0 then fail(scroll, "the question asked during a familiar's press was answered") end
	end)
end

-- ------------------------------------------------------------------ 7
-- A rogue's poisons are spells on Mists and retail: two families, the lethal
-- and the non-lethal, each up when any one of it is, cast on yourself as any
-- own buff, and offered only for what the rogue knows.
do
	local scenario = "hunt26-weapons: Mists rogue poisons are two families of spells"
	with(scenario, { flavour = "mists", class = "ROGUE", level = 30, known = { 2823, 8679, 3408 }, held = {} },
		function(ns, held)
			local me = mine(ns)
			if key(me) ~= "deadlypoison" then
				fail(scenario, "a Mists rogue with no poison up was offered " .. key(me))
				return
			end
			ns.Prompt:Refresh()
			if not (macro(ns) or ""):find("/cast Deadly Poison", 1, true) then
				fail(scenario, "the poison's macro reads " .. flat(macro(ns)))
			end
			if ns.OwnFamilyLabel(family(ns, "lethal")) ~= "Lethal poison"
				or ns.OwnFamilyLabel(family(ns, "nonlethal")) ~= "Non-lethal poison" then
				fail(scenario, "the families are called " .. tostring(ns.OwnFamilyLabel(family(ns, "lethal"))) .. " and "
					.. tostring(ns.OwnFamilyLabel(family(ns, "nonlethal"))))
			end
			-- A lethal one up: the lethal family is, the non-lethal one is next.
			held[8679] = true
			if key(mine(ns)) ~= "cripplingpoison" then
				fail(scenario, "with Wound Poison up, a rogue was offered " .. key(mine(ns)))
			end
			-- Both families up.
			held[3408] = true
			if mine(ns) then fail(scenario, "with a lethal and a non-lethal poison up, you were offered " .. key(mine(ns))) end
			-- Either of the lethal ones is the family up; and two of them are no worse.
			held[8679], held[2823] = nil, true
			if mine(ns) then fail(scenario, "with Deadly Poison up, you were offered " .. key(mine(ns))) end
			held[8679] = true
			if mine(ns) then fail(scenario, "with both lethal poisons up, you were offered " .. key(mine(ns))) end
			-- Not known: not offered (a talent's poison).
			if family(ns, "nonlethal") and ns.OwnSpellKnown(ns.FindOwnSpell("leechingpoison")) then
				fail(scenario, "a poison nobody taught is known")
			end
			if not (ns.CanCastAnything() and ns.OwnBuffsOnly()) then
				fail(scenario, "a rogue who knows poisons is a class with nothing to do")
			end
		end)

	local retail = "hunt26-weapons: retail rogue poisons are two families of spells, and no item is offered"
	with(retail, { flavour = "mainline", class = "ROGUE", level = 70, known = { 315584, 3408, 5761 }, held = {},
		bags = { [DENSE_STONE] = 1, [INSTANT_VI] = 1 } }, function(ns, held)
		if key(mine(ns)) ~= "instantpoison" then
			fail(retail, "a retail rogue who knows Instant Poison and Crippling Poison was offered " .. key(mine(ns)))
		end
		if ns.FindOwnFamily("stonemain") or ns.FindOwnFamily("poisonmain") then
			fail(retail, "retail has items for a weapon")
		end
		held[315584] = true
		if key(mine(ns)) ~= "cripplingpoison" then
			fail(retail, "with Instant Poison up, a rogue was offered " .. key(mine(ns)))
		end
		held[5761] = true
		if mine(ns) then fail(retail, "with a lethal and a non-lethal poison up, you were offered " .. key(mine(ns))) end
		-- Retail names 5761 Numbing Poison, where Mists calls it Mind-numbing.
		if ns.BuffName(ns.FindOwnSpell("numbingpoison")) ~= "Numbing Poison" then
			fail(retail, "retail's 5761 is named " .. tostring(ns.BuffName(ns.FindOwnSpell("numbingpoison"))))
		end
		-- Two lethal poisons (a talent lifts the limit): the family is up.
		held[2823] = true
		held[315584] = true
		if mine(ns) then fail(retail, "with two lethal poisons up, you were offered " .. key(mine(ns))) end
	end)
end

-- ------------------------------------------------------------------ 8
-- A rogue (or a warrior) with nothing learned and a stone or a poison in the
-- bags has something for the prompt: no longer a class with nothing to do. With
-- the bags empty, it is.
do
	local scenario = "hunt26-weapons: a rogue with a poison in the bags has a prompt"
	with(scenario, { bags = {}, hands = { [16] = DAGGER } }, function(ns)
		if ns.CanCastAnything() or ns.OwnBuffsOnly() then
			fail(scenario, "a rogue with nothing in the bags can cast something")
		end
		if mine(ns) then fail(scenario, "an empty-handed rogue was offered " .. key(mine(ns))) end
		restock(ns, { [INSTANT_VI] = 1 })
		if not ns.CanCastAnything() then fail(scenario, "a rogue with a poison in the bags can cast nothing") end
		if not ns.OwnBuffsOnly() then
			fail(scenario, "a rogue with a poison in the bags is not a class with buffs of his own to watch")
		end
		if key(mine(ns)) ~= "w8928m" then fail(scenario, "the rogue was offered " .. key(mine(ns))) end
		ns.Prompt:Refresh()
		if key(ns.Prompt:Showing()) ~= "w8928m" then
			fail(scenario, "the prompt is not on the poison: " .. key(ns.Prompt:Showing()))
		end
		-- And gone again with the bags.
		restock(ns, {})
		if ns.CanCastAnything() then fail(scenario, "a rogue who put his poison down can still cast something") end

		-- The probe asks the client about no item the bags do not hold: a class has
		-- dozens of them, named when one is first wanted.
		local asked = 0
		local real = C_Item.GetItemNameByID
		rawget(_G, "C_Item").GetItemNameByID = function(id)
			asked = asked + 1
			return real(id)
		end
		ns.ProbeCapabilities()
		if asked ~= 0 then
			fail(scenario, ("the probe asked the client for the names of %d items with none in the bags"):format(asked))
		end
	end)
end

-- ------------------------------------------------------------------ 9
-- The options page lists the families a character carries something for,
-- names the hand, and offers the ones in the bags and the one picked; a
-- pick is kept, and Don't remind me holds a hand back.
do
	local scenario = "hunt26-weapons: the rows show what the bags hold, per hand, and a pick is kept"
	with(scenario, { bags = { [INSTANT_VI] = 1, [DEADLY_V] = 1 }, hands = { [16] = DAGGER, [17] = DAGGER } },
		function(ns)
			local control = findOption(ns.optionsTable, "own_poisonmain")
			if not control or control.hidden() ~= false then
				fail(scenario, "the Poison row is hidden with poisons in the bags")
				return
			end
			local off = findOption(ns.optionsTable, "own_poisonoff")
			if not off or off.hidden() ~= false then fail(scenario, "the off hand's Poison row is hidden") end
			local stone = findOption(ns.optionsTable, "own_stonemain")
			if not stone or stone.hidden() ~= true then fail(scenario, "the stone row is shown with no stone in the bags") end
			local label = control.name()
			if label ~= "Poison (Main Hand)" then fail(scenario, "the row is called " .. tostring(label)) end
			local values = control.values()
			if values["w8928m"] ~= "Instant Poison VI (Main Hand)" or values["w20844m"] ~= "Deadly Poison V (Main Hand)" then
				fail(scenario, "the choices are " .. flat(Mock.dump and Mock.dump(values) or "?"))
			end
			if values["w8927m"] then fail(scenario, "a poison not in the bags is a choice") end
			if not control.desc():find("weapon in your Main Hand", 1, true) then
				fail(scenario, "the row says " .. tostring(control.desc()))
			end
			if not off.desc():find("weapon in your Off Hand", 1, true) then
				fail(scenario, "the off hand's row says " .. tostring(off.desc()))
			end
			-- A pick: Deadly Poison for the main hand.
			control.set({ "own_poisonmain" }, "w20844m")
			if key(mine(ns)) ~= "w20844m" then fail(scenario, "Deadly Poison picked and you were offered " .. key(mine(ns))) end
			-- The pick stays on the list with none left in the bags.
			restock(ns, { [INSTANT_VI] = 1 })
			if control.values()["w20844m"] ~= "Deadly Poison V (Main Hand)" then
				fail(scenario, "the pick left the list with none in the bags")
			end
			if mine(ns) and key(mine(ns)) == "w20844m" then fail(scenario, "a pick with none in the bags was offered") end
			-- Off.
			control.set({ "own_poisonmain" }, "off")
			off.set({ "own_poisonoff" }, "off")
			if mine(ns) then fail(scenario, "Don't remind me still offered " .. key(mine(ns))) end
		end)
end

-- ------------------------------------------------------------------ 10
-- Mists' items are Mists' own: its elemental stone fits no mace or staff (the
-- subclass mask in the client's own data), where Classic Era's does.
do
	local mists = "hunt26-weapons: Mists' elemental stone is not for a mace, Classic Era's is"
	with(mists, { flavour = "mists", class = "WARRIOR", level = 55, bags = { [ELEMENTAL] = 1 }, hands = { [16] = MACE } },
		function(ns)
			if mine(ns) then fail(mists, "on Mists a mace was offered the elemental stone: " .. key(mine(ns))) end
			wield(ns, 16, SWORD)
			if key(mine(ns)) ~= "w18262m" then fail(mists, "on Mists a sword was offered " .. key(mine(ns))) end
		end)
	local era = "hunt26-weapons: Classic Era's elemental stone fits a mace"
	with(era, { flavour = "vanilla", class = "WARRIOR", level = 55, bags = { [ELEMENTAL] = 1 }, hands = { [16] = MACE } },
		function(ns)
			if key(mine(ns)) ~= "w18262m" then fail(era, "on Classic Era a mace was offered " .. key(mine(ns))) end
		end)
end

-- ------------------------------------------------------------------ 11
-- The three Classic clients read the weapon with the global
-- GetWeaponEnchantInfo, four values to a hand: the off hand's are the second
-- four. Each hand is read as its own, and the item on offer is that client's.
do
	for _, case in ipairs({
		{ flavour = "vanilla", item = INSTANT_VI, level = 60, name = "w8928" },
		{ flavour = "tbc", item = ANESTHETIC, level = 68, name = "w21835" },
	}) do
		local scenario = ("hunt26-weapons: %s reads each hand with the global GetWeaponEnchantInfo"):format(case.flavour)
		with(scenario, { flavour = case.flavour, class = "ROGUE", level = case.level, bags = { [case.item] = 2 },
			hands = { [16] = DAGGER, [17] = DAGGER } }, function(ns)
			if key(mine(ns)) ~= case.name .. "m" then
				fail(scenario, "bare daggers on " .. case.flavour .. ": " .. key(mine(ns)))
			end
			-- The enchant on the off hand only: the main hand is still bare.
			world.enchants[17] = { entry(623, TEMPORARY, 1800) }
			if key(mine(ns)) ~= case.name .. "m" then
				fail(scenario, "with the off hand poisoned, the main hand was offered " .. key(mine(ns)))
			end
			-- And the main hand's only: the off hand is next.
			world.enchants[16], world.enchants[17] = { entry(623, TEMPORARY, 1800) }, nil
			if key(mine(ns)) ~= case.name .. "o" then
				fail(scenario, "with the main hand poisoned, the off hand was offered " .. key(mine(ns)))
			end
			world.enchants[17] = { entry(623, TEMPORARY, 1800) }
			if mine(ns) then fail(scenario, "with both hands poisoned, you were offered " .. key(mine(ns))) end
		end)
	end

	local tbc = "hunt26-weapons: Burning Crusade's own stone asks its level"
	with(tbc, { flavour = "tbc", class = "WARRIOR", level = 59, bags = { [ADAMANTITE] = 1, [COARSE_STONE] = 1 },
		hands = { [16] = SWORD } }, function(ns)
		if key(mine(ns)) ~= "w2863m" then
			fail(tbc, "a level-59 warrior with an Adamantite and a Coarse stone was offered " .. key(mine(ns)))
		end
		world.level = 60
		if key(mine(ns)) ~= "w23529m" then fail(tbc, "at level 60 you were offered " .. key(mine(ns))) end
	end)
end

-- ------------------------------------------------------------------ 12
-- WoW Forever's own ids: three items its 1.60.1.70450 build added (a Rough
-- Sharpening Stone that asks level 1, among them), which make the enchant the
-- older item does, so either tops up the other.
do
	local scenario = "hunt26-weapons: Forever's newer stone makes the older one's enchant"
	with(scenario, { class = "WARRIOR", level = 20, bags = { [ROUGH_NEW] = 1 }, hands = { [16] = SWORD } }, function(ns)
		if key(mine(ns)) ~= "w287978m" then
			fail(scenario, "Forever's Rough Sharpening Stone was offered as " .. key(mine(ns)))
			return
		end
		ns.db.profile.filters.whenBuffed = "refresh"
		world.enchants[16] = { entry(40, TEMPORARY, 120) }
		restock(ns, { [ROUGH_STONE] = 1 })
		local me = mine(ns)
		if key(me) ~= "w2862m" then
			fail(scenario, "two minutes of a Rough Sharpening Stone's enchant, with the older one in the bags, offered " .. key(me))
		end
	end)
end

-- ------------------------------------------------------------------ 13
-- Reading the weapon is cheap: the client's list is asked for once by each
-- family of yours that is held, in a queue build, and the bags are read once
-- until the client says they changed.
do
	local scenario = "hunt26-weapons: a queue build reads a hand once for each family held, and the bags once"
	with(scenario, { bags = { [INSTANT_VI] = 1, [DENSE_STONE] = 1 }, hands = { [16] = DAGGER, [17] = DAGGER } },
		function(ns)
			world.enchants[16] = { entry(INSTANT_VI_ENCHANT, IMBUE, 1800) }
			world.enchants[17] = { entry(DEADLY_IV_ENCHANT, TEMPORARY, 1800) }
			mine(ns)
			local before = world.reads
			local reads = 0
			local real = C_Item.GetWeaponEnchantInfo
			rawget(_G, "C_Item").GetWeaponEnchantInfo = function(slot)
				reads = reads + 1
				return real(slot)
			end
			ns.BuildQueue()
			-- A poison and a stone for each hand are held: four families, four reads.
			if #ns.KnownOwnFamilies() ~= 4 then
				fail(scenario, "SKIPPED -- " .. #ns.KnownOwnFamilies() .. " families are held, not four")
				return
			end
			if reads ~= 4 then fail(scenario, ("a queue build read the weapons %d times for four families"):format(reads)) end
			for _ = 1, 5 do
				Mock.advance(1)
				ns.addon:Tick()
				mine(ns)
			end
			if world.reads ~= before then
				fail(scenario, ("the bags were read %d more times over five scans"):format(world.reads - before))
			end
		end)
end

-- ------------------------------------------------------------------ 14
-- The client's word that an enchant went on or came off makes the next tick
-- read your own buffs and write down the one on the weapon (the memory
-- Automatic goes by), rather than wait for something else to.
do
	local scenario = "hunt26-weapons: a weapon's enchant changing is noticed at once"
	with(scenario, { class = "WARRIOR", level = 40, bags = { [DENSE_STONE] = 1 }, hands = { [16] = SWORD } },
		function(ns)
			ns.RememberOwnBuffs()
			ns.ownAurasChanged = false
			world.enchants[16] = { entry(DENSE_STONE_ENCHANT, TEMPORARY, 1800) }
			ns.addon:WEAPON_ENCHANT_CHANGED()
			if ns.ownAurasChanged ~= true then fail(scenario, "the enchant going on did not ask for a reading") end
			Mock.advance(1)
			ns.addon:Tick()
			if ns.db.char.ownLast.stonemain ~= "w12404m" then
				fail(scenario, "the stone on the weapon was not written down: " .. tostring(ns.db.char.ownLast.stonemain))
			end
		end)
end

-- ------------------------------------------------------------------ 15
-- The weapon's enhancements are everybody's but the poisons: every class has
-- a stone, an oil and a lure family where the bags hold one, a poison family
-- only the rogue's, on the clients that have the items.
do
	local scenario = "hunt26-weapons: a poison is a rogue's, every other kind everybody's"
	local seen = {}
	for _, class in ipairs({ "MAGE", "PRIEST", "WARRIOR", "ROGUE", "SHAMAN", "HUNTER", "DRUID", "PALADIN", "WARLOCK" }) do
		with(scenario, { class = class, bags = { [INSTANT_VI] = 1, [DENSE_STONE] = 1, [WIZARD_OIL] = 1, [SHINY_BAUBLE] = 1 } },
			function(ns)
				local want = { stonemain = true, stoneoff = true, oilmain = true, oiloff = true, lure = true }
				if class == "ROGUE" then want.poisonmain, want.poisonoff = true, true end
				for _, name in ipairs({ "poisonmain", "poisonoff", "stonemain", "stoneoff", "oilmain", "oiloff", "lure" }) do
					if (family(ns, name) ~= nil) ~= (want[name] == true) then
						fail(scenario, ("%s: the %s family is %s"):format(class, name, family(ns, name) and "there" or "missing"))
					end
				end
				seen[class] = true
			end)
	end
end

-- ------------------------------------------------------------------ 16
-- Automatic takes the best you can use until you have had one on, then the one
-- you had on last for that hand, while there is one of it left: a rogue who
-- put Deadly Poison V on his main hand and let it run out is offered that one
-- again, not the Instant Poison VI ahead of it in the list; his off hand,
-- which has had nothing on, is offered the best.
do
	local scenario = "hunt26-weapons: Automatic takes the poison last on that hand"
	with(scenario, { bags = { [INSTANT_VI] = 1, [DEADLY_V] = 1 }, hands = { [16] = DAGGER, [17] = DAGGER } },
		function(ns)
			if key(mine(ns)) ~= "w8928m" then
				fail(scenario, "before any was on, the best was not offered first: " .. key(mine(ns)))
				return
			end
			-- Deadly Poison V on the main hand, seen, and worn off.
			world.enchants[16] = { entry(2630, TEMPORARY, 1800) }
			mine(ns)
			world.enchants[16] = nil
			if key(mine(ns)) ~= "w20844m" then
				fail(scenario, "with Deadly Poison V the last on the main hand, you were offered " .. key(mine(ns)))
			end
			-- The off hand has had none on: the best, not the main hand's.
			world.enchants[16] = { entry(2630, TEMPORARY, 1800) }
			if key(mine(ns)) ~= "w8928o" then
				fail(scenario, "the off hand, with nothing on it before, was offered " .. key(mine(ns)))
			end
		end)
end

-- ------------------------------------------------------------------ 17
-- An item the client has not loaded has no name yet: the spell its use casts
-- stands in (Crippling Poison for Crippling Poison II, whose spell is named for
-- the poison), the item is asked for, and the name is the item's once the
-- client has it; the hand follows either.
do
	local scenario = "hunt26-weapons: an item not yet loaded is named by its spell, then by itself"
	with(scenario, { level = 50, bags = { [CRIPPLING_II] = 1 }, hands = { [16] = DAGGER },
		unloaded = { [CRIPPLING_II] = true } }, function(ns)
		local me = mine(ns)
		if key(me) ~= "w3776m" then
			fail(scenario, "Crippling Poison II was offered as " .. key(me))
			return
		end
		if ns.BuffName(me.buff) ~= "Crippling Poison (Main Hand)" then
			fail(scenario, "before the item loaded, Crippling Poison II reads " .. tostring(ns.BuffName(me.buff)))
		end
		if not world.requested[CRIPPLING_II] then fail(scenario, "the item was never asked for") end
		world.unloaded = nil
		if ns.BuffName(me.buff) ~= "Crippling Poison II (Main Hand)" then
			fail(scenario, "once the item loaded, Crippling Poison II reads " .. tostring(ns.BuffName(me.buff)))
		end
	end)
end

-- ------------------------------------------------------------------ 18
-- The in-game report counts what the bags hold with C_Item.GetItemCount. A
-- client without it fails the report for the mage whose scrolls it counts, and
-- is no more than a warning for a class whose only items are stones, poisons,
-- oils and lures, which every client has.
do
	local function countStatus(scenario, class, bags)
		local status
		with(scenario, { class = class, level = 40, bags = bags, hands = { [16] = SWORD } }, function(ns)
			if not ns.Selftest then
				fail(scenario, "SKIPPED -- Selftest.lua did not load")
				return
			end
			C_Item.GetItemCount = nil
			local ok, results = pcall(ns.Selftest.Run)
			if not ok then
				fail(scenario, "Run threw: " .. tostring(results))
				return
			end
			for _, r in ipairs(results) do
				if r.id == "api.itemCount" then status = status or r.status end
			end
		end)
		return status
	end

	local scenario = "hunt26-weapons: a stone is not a scroll to the in-game report"
	local warrior = countStatus(scenario, "WARRIOR", { [DENSE_STONE] = 1 })
	if warrior ~= "WARN" then
		fail(scenario, "with no count of the bags, a warrior holding a stone is reported as " .. tostring(warrior))
	end
	local mage = countStatus(scenario, "MAGE", { [RAT] = 1 })
	if mage ~= "FAIL" then
		fail(scenario, "with no count of the bags, a mage holding a scroll is reported as " .. tostring(mage))
	end
end
