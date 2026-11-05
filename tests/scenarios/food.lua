-- Buff food on WoW Forever, as your own buff: a family every class has
-- (Buffs.lua, FOOD), offered while you are not Well Fed and the bags hold food
-- your level can eat. Up is any food's buff or any eating aura (Core.lua,
-- ReadFood); it is offered last of your own families and behind everybody
-- else in the queue (Queue.lua, OwnPick and PRIORITY.food), since any cast
-- stands you up mid-meal.
--
-- The world is stood in as hunt26-weapons.lua stands it: what the bags hold,
-- the weapon in each hand, your level and the auras on you (Mock.playerHeld).
-- A rogue, who has nothing else of his own to be reminded of with his bags
-- empty of poisons, so the only own family in play is the one asked about.
--
-- Every scenario name starts with "food:" so the mutations in
-- tests/mutations/food.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

-- Food, as Buffs.lua has it: item, the level it asks for.
local SAGEFISH, SOUP, DUMPLINGS = 21072, 13931, 20452 -- 10, 35, 45
-- The buff Smoked Sagefish and Nightfin Soup land; Smoked Desert Dumplings'.
local SAGEFISH_FED, DUMPLINGS_FED = 1249520, 1248422
-- Candy Bar's Well Fed, which no food in these bags makes.
local CANDY_FED = 19705
-- The eating aura of Smoked Sagefish's level band.
local EATING = 434
-- A rogue's poison and its enchant, for the order of families.
local INSTANT_VI, INSTANT_VI_ENCHANT, IMBUE = 8928, 625, 3

-- Find Herbs: tracking, the one family listed after food.
local FIND_HERBS = 2383

local DAGGER = 900015
local ITEM_NAMES = {
	[SAGEFISH] = "Smoked Sagefish", [SOUP] = "Nightfin Soup", [DUMPLINGS] = "Smoked Desert Dumplings",
	[INSTANT_VI] = "Instant Poison VI",
}

local function key(entry) return tostring(entry and entry.buff and entry.buff.key) end
local function macro(ns) return ns.Prompt:GetButton():GetAttribute("macrotext1") end

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

local world
local TOUCHED = { "C_Item", "GetInventoryItemID", "UnitLevel", "C_Minimap", "IsSpellKnown", "IsPlayerSpell" }

local function install()
	rawset(_G, "C_Item", nil)
	local list = C_Item and C_Item.GetWeaponEnchantInfo
	rawset(_G, "C_Item", {
		GetItemCount = function(id) return world.bags[id] or 0 end,
		GetItemNameByID = function(id) return ITEM_NAMES[id] end,
		RequestLoadItemDataByID = function() end,
		GetItemIconByID = function(id) return 7100000 + id end,
		GetItemInfoInstant = function(id)
			if id == DAGGER then return id, "Weapon", "", "INVTYPE_WEAPON", 7100000 + id, 2, 15 end
			return id, "Consumable", "", "", 7100000 + id, 0, 5
		end,
		GetWeaponEnchantInfo = list,
	})
	rawset(_G, "GetInventoryItemID", function(unit, slot)
		if unit == "player" then return world.hands[slot] end
		return nil
	end)
	rawset(_G, "UnitLevel", function(unit)
		if unit == "player" then return world.level end
		return 12
	end)
	Mock.weaponEnchants = setmetatable({}, { __index = function(_, slot)
		return world.enchants[slot == 0 and 16 or slot == 1 and 17 or 18]
	end })
end

-- One session on Forever as a rogue with opts.bags, opts.level (20),
-- opts.enchants, opts.held (the auras on you) and opts.tracking (the
-- minimap's list, Find Herbs learned, as tracking.lua stands it in). body(ns)
-- runs and everything is put back, whether it finished or threw.
local function with(scenario, opts, body)
	Mock.reset()
	Mock.setFlavour("camelot")
	Mock.class = "ROGUE"
	world = { bags = opts.bags or {}, hands = { [16] = DAGGER }, enchants = opts.enchants or {},
		level = opts.level or 20 }
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	install()
	if opts.tracking then
		local entries = opts.tracking
		rawset(_G, "C_Minimap", {
			GetNumTrackingTypes = function() return #entries end,
			GetTrackingInfo = function(i) return entries[i] end,
		})
		rawset(_G, "IsSpellKnown", function(id) return id == FIND_HERBS end)
		rawset(_G, "IsPlayerSpell", function(id) return id == FIND_HERBS end)
	end
	local undo = strangers({})
	local ok, err = pcall(function()
		local held = {}
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
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.weaponEnchants = nil
	Mock.playerHeldFor, Mock.playerHeldDuration = nil, nil
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function restock(ns, bags)
	world.bags = bags
	ns.addon:BAG_UPDATE_DELAYED()
end

-- ------------------------------------------------------------------ 1
-- Food in the bags and no Well Fed: offered, named by the item, used by it,
-- and after everybody else in the queue.
do
	local scenario = "food: a rogue with food and no Well Fed is offered it"
	with(scenario, { bags = { [SAGEFISH] = 3 } }, function(ns)
		if not family(ns, "food") then
			fail(scenario, "no food family with Smoked Sagefish in the bags")
			return
		end
		local entry = mine(ns)
		if key(entry) ~= "food" .. SAGEFISH then
			fail(scenario, "offered " .. key(entry))
			return
		end
		if ns.BuffName(entry.buff) ~= "Smoked Sagefish" then
			fail(scenario, "named " .. tostring(ns.BuffName(entry.buff)) .. ", not by the item")
		end
		if not (entry.priority and entry.priority > 3) then
			fail(scenario, "the food sorts at " .. tostring(entry.priority) .. ", ahead of passers-by")
		end
		ns.Prompt:Refresh()
		if not tostring(macro(ns)):find("/use item:" .. SAGEFISH, 1, true) then
			fail(scenario, "the prompt does not use the food: " .. tostring(macro(ns)))
		end
	end)
end

-- ------------------------------------------------------------------ 2
-- The best the level allows: Nightfin Soup (35) at 40, not the Dumplings (45)
-- nor the Sagefish (10).
do
	local scenario = "food: Automatic takes the best food the level allows"
	with(scenario, { bags = { [SAGEFISH] = 1, [SOUP] = 1, [DUMPLINGS] = 1 }, level = 40 }, function(ns)
		local entry = mine(ns)
		if key(entry) ~= "food" .. SOUP then fail(scenario, "offered " .. key(entry)) end
	end)
end

-- ------------------------------------------------------------------ 3
-- Fed is fed: the bags' own food's buff, another food's, or a meal under way.
do
	local cases = {
		{ "its own buff", { SAGEFISH_FED } },
		{ "another food's buff", { CANDY_FED } },
		{ "eating", { EATING } },
	}
	for _, case in ipairs(cases) do
		local scenario = "food: nothing offered while Well Fed or eating (" .. case[1] .. ")"
		with(scenario, { bags = { [SAGEFISH] = 2 }, held = case[2] }, function(ns)
			Mock.playerHeldFor, Mock.playerHeldDuration = 600, 900
			local entry = mine(ns)
			if entry then fail(scenario, "offered " .. key(entry)) end
		end)
	end
end

-- ------------------------------------------------------------------ 4
-- No food, no family and nothing offered.
do
	local scenario = "food: none in the bags, nothing offered"
	with(scenario, { bags = {} }, function(ns)
		if family(ns, "food") then fail(scenario, "a food family with no food in the bags") end
		if mine(ns) then fail(scenario, "offered " .. key(mine(ns))) end
	end)
end

-- ------------------------------------------------------------------ 5
-- Last of your own: with a poison to put on as well, the poison first, and the
-- food once the poison is on.
do
	local scenario = "food: offered after every other own family"
	with(scenario, { bags = { [SAGEFISH] = 1, [INSTANT_VI] = 1 }, level = 60 }, function(ns)
		local entry = mine(ns)
		if key(entry) ~= "w8928m" then
			fail(scenario, "with a poison to put on, offered " .. key(entry))
			return
		end
		world.enchants[16] = { { hasEnchant = true, enchantType = IMBUE, timeLeft = 1800000, charges = 0,
			enchantID = INSTANT_VI_ENCHANT, enchantIconID = 0 } }
		ns.addon:PLAYER_EQUIPMENT_CHANGED(nil, 16, false)
		entry = mine(ns)
		if key(entry) ~= "food" .. SAGEFISH then fail(scenario, "with the poison on, offered " .. key(entry)) end
	end)
end

-- ------------------------------------------------------------------ 6
-- A top-up as Well Fed runs low, though nobody can tell which food put it
-- on: any food puts it back, so Automatic's pick is offered.
do
	local scenario = "food: Well Fed running low is topped up"
	with(scenario, { bags = { [SAGEFISH] = 2 }, held = { DUMPLINGS_FED } }, function(ns)
		Mock.playerHeldFor, Mock.playerHeldDuration = 20, 900
		local entry = mine(ns)
		if key(entry) ~= "food" .. SAGEFISH then
			fail(scenario, "with 20 seconds of Well Fed left, offered " .. key(entry))
		end
		-- With plenty left, nothing.
		Mock.playerHeldFor = 600
		entry = mine(ns)
		if entry then fail(scenario, "with ten minutes left, offered " .. key(entry)) end
	end)
end

-- ------------------------------------------------------------------ 7
-- The food above your level alone: nothing offered.
do
	local scenario = "food: food above your level is not offered"
	with(scenario, { bags = { [DUMPLINGS] = 1 }, level = 20 }, function(ns)
		if mine(ns) then fail(scenario, "a level-20 rogue was offered " .. key(mine(ns))) end
	end)
end

-- ------------------------------------------------------------------ 8
-- Last even of the families listed after it: tracking comes after food in
-- every class's list, and with Find Herbs off it is still offered first.
do
	local scenario = "food: offered after tracking, listed after it"
	local list = { { spellID = FIND_HERBS, active = false } }
	with(scenario, { bags = { [SAGEFISH] = 1 }, tracking = list }, function(ns)
		ns.ForgetTrackingList()
		local entry = mine(ns)
		if key(entry) ~= "findherbs" then
			fail(scenario, "with Find Herbs off, offered " .. key(entry))
			return
		end
		list[1].active = true
		ns.ForgetTrackingList()
		entry = mine(ns)
		if key(entry) ~= "food" .. SAGEFISH then fail(scenario, "with Find Herbs on, offered " .. key(entry)) end
	end)
end
