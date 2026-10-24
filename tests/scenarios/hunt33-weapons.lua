-- Bug hunt 33, the weapon enhancements (Core.lua HandBusy, NoteScrollPress and
-- ReadImbue, Clicks.lua's settle). Every scenario is red on 1.8.5 and says what
-- it found. The world (bags, hands, enchants, level) is stood in as
-- hunt26-weapons.lua stands it in, and its helpers are repeated here.
--
-- Every scenario name starts with "hunt33-weapons:".

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
-- A hand an enhancement is being put on is busy "until the cast is over ...
-- Let go at the cast's end, or when it is cut short" (Core.lua, above
-- NoteScrollPress). UNIT_SPELLCAST_SUCCEEDED is the cast's end (Clicks.lua
-- drops castingScroll there) but nothing lets the hand go: HandBusy runs on to
-- the eight seconds after the press, so a rogue who has just poisoned the main
-- hand is not offered a stone for that same hand for the five seconds after
-- the poison is on. On WoW Forever the two kinds stay on together, so the
-- stone is due at once.
do
	local scenario = "hunt33-weapons: the hand is let go when the cast succeeds, not eight seconds after the press"
	with(scenario, { bags = { [INSTANT_VI] = 1, [ROUGH_STONE] = 1 }, hands = { [16] = DAGGER } }, function(ns)
		local ran = press(ns, scenario, "w8928m", nil, INSTANT_VI_USE, "Cast-poison-1")
		if not ran then return end
		-- The cast takes three seconds, and the poison is on the weapon at its end.
		Mock.advance(3)
		ns.addon:UNIT_SPELLCAST_SUCCEEDED(nil, "player", "Cast-poison-1", INSTANT_VI_USE)
		world.enchants[16] = { entry(INSTANT_VI_ENCHANT, IMBUE, 1800) }
		ns.addon:WEAPON_ENCHANT_CHANGED()
		-- Past the retry cooldown of the poison (the stone has none of its own).
		Mock.advance(0.5)
		wipe(ns.tried)
		if ns.HandBusy(16, GetTime()) then
			fail(scenario, "the main hand is still busy 0.5 s after the poison's cast succeeded")
		end
		if key(mine(ns)) ~= "w2862m" then
			fail(scenario, "with the poison on and its cast over, the stone for the same hand was not offered: "
				.. key(mine(ns)))
		end
	end)
end
