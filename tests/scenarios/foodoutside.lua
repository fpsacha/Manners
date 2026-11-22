-- Food still offered outside dungeons and raids (ownBuffs.foodOutside, GitHub
-- issue 37), a sub-switch of Consumables only in dungeons and raids
-- (ownBuffs.itemsInDungeons): with both on, food for Well Fed comes up out in the
-- world, while a stone, an oil, a flask, an elixir and a scroll keep waiting for
-- a dungeon or a raid. Off by default: today's behaviour stays for everybody who
-- has the main switch ticked. ns.OwnItemsHeldToDungeons stays the plain
-- classifier (itemsLast and the battleground extras read it); the hold itself is
-- ns.OwnItemsWaitForDungeon, read by ns.OwnVerdict.
--
-- Every scenario name starts with "foodoutside:" so the mutations in
-- tests/mutations/foodoutside.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, findOption = H.strangers, H.freshPrompt, H.findOption

local function key(entry) return tostring(entry and entry.buff and entry.buff.key) end

local function mine(ns)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.reason == "self" then return entry end
	end
	return nil
end

local world
local TOUCHED = { "C_Item", "C_Spell", "C_UnitAuras", "UnitLevel", "IsMounted", "IsSpellKnown", "IsPlayerSpell", "IsResting",
	"IsInInstance" }

-- The world: bags (item -> count), the player's level, where he stands.
local function install(ns)
	rawset(_G, "C_Spell", nil)
	local spells = C_Spell
	local data = ns.FOODS.camelot
	local meals = {}
	for _, row in ipairs(data) do meals[row[3]] = true end
	rawset(_G, "C_Spell", setmetatable({
		GetSpellName = function(id)
			if id == data.fed then return "Well Fed" end
			if meals[id] then return "Nutritious Food" end
			return spells.GetSpellName(id)
		end,
	}, { __index = spells }))
	rawset(_G, "C_UnitAuras", nil)
	local base = C_UnitAuras
	rawset(_G, "C_UnitAuras", setmetatable({
		GetAuraDataBySpellName = function() return nil end,
	}, { __index = base }))
	rawset(_G, "C_Item", {
		GetItemCount = function(id) return world.bags[id] or 0 end,
		GetItemNameByID = function(id) return "Item " .. id end,
		RequestLoadItemDataByID = function() end,
		GetItemIconByID = function(id) return 7100000 + id end,
		GetItemInfoInstant = function(id) return id, "Consumable", "", "", 7100000 + id, 0, 5 end,
	})
	rawset(_G, "UnitLevel", function(unit) if unit == "player" then return 60 end return 12 end)
	rawset(_G, "IsMounted", function() return false end)
	rawset(_G, "IsResting", function() return false end)
	rawset(_G, "IsSpellKnown", function() return false end)
	rawset(_G, "IsPlayerSpell", function() return false end)
	rawset(_G, "IsInInstance", function()
		if world.where then return true, world.where end
		return false, "none"
	end)
end

-- One session as a warrior on Forever, `opts.bags` held.
local function with(scenario, opts, body)
	Mock.reset()
	Mock.setFlavour("camelot")
	Mock.class = opts.class or "WARRIOR"
	world = { bags = opts.bags or {}, where = nil }
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local undo = strangers({})
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		install(ns)
		Mock.playerHeld = {}
		Mock.weaponEnchants = { [0] = {}, [1] = {} }
		freshPrompt(ns, scenario)
		Mock.playerHeld = {}
		ns.db.profile.sources.self = true
		ns.db.profile.ownBuffs.inCities = true
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	undo()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.weaponEnchants = nil
	Mock.playerHeld = nil
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function family(ns, class, test)
	for _, f in ipairs(ns.GetOwnFamilies(class) or {}) do
		if test(f) then return f end
	end
	return nil
end

local function stocked(ns, fam)
	local item = fam.spells[1].item
	world.bags[item] = 1
	ns.ForgetScrolls()
	return item
end

local function verdict(ns, fam)
	return ns.OwnVerdict(fam, { name = "x", now = GetTime(), whenBuffed = "skip", refreshUnder = 300 })
end

local function stone(ns)
	return family(ns, "WARRIOR", function(f) return f.enhance and f.kind == "stone" and f.slot == 16 end)
end

-- Food in the bags and Automatic for it, both switches as given.
local function foodSetup(ns, held, outside)
	world.bags[ns.FOODS.camelot[1][1]] = 1
	local own = ns.db.profile.ownBuffs
	own.pick.food = "auto"
	own.itemsInDungeons = held
	own.foodOutside = outside
	ns.ForgetScrolls()
	Mock.advance(5)
end

local function isFood(entry)
	return entry and entry.buff and entry.buff.family and entry.buff.family.food == true
end

do
	local scenario = "foodoutside: on, food is offered out in the world"
	with(scenario, {}, function(ns)
		foodSetup(ns, true, true)
		local entry = mine(ns)
		if not isFood(entry) then
			fail(scenario, "food in the bags was not offered out in the world with both switches on: " .. key(entry))
		end
	end)
end

do
	local scenario = "foodoutside: on, a stone or an oil still waits out in the world"
	with(scenario, {}, function(ns)
		local fam = stone(ns)
		if not fam then fail(scenario, "SKIPPED -- a warrior has no stone family") return end
		stocked(ns, fam)
		ns.db.profile.ownBuffs.itemsInDungeons = true
		ns.db.profile.ownBuffs.foodOutside = true
		local spell, _, _, why = verdict(ns, fam)
		if spell or why ~= "dungeon" then
			fail(scenario, "a stone out in the world with food outside on: " .. tostring(spell and spell.key) .. " / " .. tostring(why))
		end
	end)
end

do
	local scenario = "foodoutside: inside a dungeon or a raid both are offered"
	with(scenario, {}, function(ns)
		local fam = stone(ns)
		if not fam then fail(scenario, "SKIPPED -- a warrior has no stone family") return end
		stocked(ns, fam)
		foodSetup(ns, true, true)
		for _, where in ipairs({ "party", "raid" }) do
			world.where = where
			Mock.advance(5)
			if not isFood(mine(ns)) then fail(scenario, "food was not offered in a " .. where) end
			local _, _, _, why = verdict(ns, fam)
			if why == "dungeon" then fail(scenario, "a stone in a " .. where .. " was still held back") end
		end
	end)
end

do
	local scenario = "foodoutside: off by default, food waits for a dungeon as before"
	with(scenario, {}, function(ns)
		if ns.defaults.profile.ownBuffs.foodOutside ~= false then fail(scenario, "the switch is not off by default") end
		foodSetup(ns, true, nil)
		local entry = mine(ns)
		if entry then fail(scenario, "food was offered out in the world with only the main switch on: " .. key(entry)) end
		world.where = "party"
		Mock.advance(5)
		if not isFood(mine(ns)) then fail(scenario, "food was not offered in a dungeon") end
	end)
end

do
	local scenario = "foodoutside: with Consumables only in dungeons and raids off it holds nothing"
	with(scenario, {}, function(ns)
		local fam = stone(ns)
		if not fam then fail(scenario, "SKIPPED -- a warrior has no stone family") return end
		stocked(ns, fam)
		ns.db.profile.ownBuffs.itemsInDungeons = false
		ns.db.profile.ownBuffs.foodOutside = true
		local _, _, _, why = verdict(ns, fam)
		if why == "dungeon" then fail(scenario, "a stone was held back with the main switch off") end
		if ns.OwnItemsWaitForDungeon(fam) then fail(scenario, "OwnItemsWaitForDungeon says wait with the main switch off") end
	end)
end

do
	local scenario = "foodoutside: the consumables button offers food out in the world"
	with(scenario, {}, function(ns)
		foodSetup(ns, true, true)
		ns.db.profile.ownBuffs.apart = true
		local entry = ns.SupplyEntry(ns.db.profile, GetTime())
		if not isFood(entry) then
			fail(scenario, "the button did not offer food with food outside on: " .. key(entry))
		end
		ns.db.profile.ownBuffs.foodOutside = false
		entry = ns.SupplyEntry(ns.db.profile, GetTime())
		if isFood(entry) then fail(scenario, "the button offered food out in the world with food outside off") end
	end)
end

do
	local scenario = "foodoutside: /manners debug says a stone waits and food does not"
	with(scenario, {}, function(ns)
		local fam = stone(ns)
		if not fam then fail(scenario, "SKIPPED -- a warrior has no stone family") return end
		stocked(ns, fam)
		foodSetup(ns, true, true)
		local foodFam = family(ns, "WARRIOR", function(f) return f.food == true end)
		if not foodFam then fail(scenario, "SKIPPED -- a warrior has no food family") return end
		local reason = "only offered in a dungeon or a raid"
		local stoneLabel, foodLabel = ns.OwnFamilyLabel(fam), ns.OwnFamilyLabel(foodFam)
		local stoneSays, foodSays = false, false
		for _, line in ipairs(ns.MyselfLines(GetTime()) or {}) do
			if line:find(reason, 1, true) then
				if line:sub(1, #stoneLabel + 1) == stoneLabel .. ":" then stoneSays = true end
				if line:sub(1, #foodLabel + 1) == foodLabel .. ":" then foodSays = true end
			end
		end
		if not stoneSays then fail(scenario, "the stone's line does not give the dungeon reason") end
		if foodSays then fail(scenario, "the food's line says it waits for a dungeon, with food outside on") end
	end)
end

do
	local scenario = "foodoutside: food still goes after everybody else with My food, stones and oils after everybody else on"
	with(scenario, {}, function(ns)
		foodSetup(ns, true, true)
		ns.db.profile.ownBuffs.itemsLast = true
		Mock.advance(5)
		local foodFam = family(ns, "WARRIOR", function(f) return f.food == true end)
		if not (foodFam and ns.OwnItemsHeldToDungeons(foodFam)) then
			fail(scenario, "food is no longer classed with the consumables")
		end
		local entry = mine(ns)
		if not isFood(entry) then fail(scenario, "food was not offered: " .. key(entry)) return end
		if entry.priority ~= ns.PRIORITY.selfLast then
			fail(scenario, "the food stands at " .. tostring(entry.priority) .. ", not behind everybody else")
		end
	end)
end

do
	local scenario = "foodoutside: the switch sits under Consumables only in dungeons and raids, off, greyed while that is off, and kept"
	with(scenario, {}, function(ns)
		local control = findOption(ns.optionsTable, "ownFoodOutside")
		if not control then fail(scenario, "Who to buff has no switch for food outside") return end
		if control.type ~= "toggle" then fail(scenario, "the switch is a " .. tostring(control.type)) end
		if control.get() ~= false then fail(scenario, "the switch is on in a new profile") end
		if control.hidden and control.hidden() then fail(scenario, "the switch is hidden from a warrior") end
		ns.db.profile.ownBuffs.itemsInDungeons = false
		if not (control.disabled and control.disabled()) then
			fail(scenario, "the switch is live with Consumables only in dungeons and raids off")
		end
		ns.db.profile.ownBuffs.itemsInDungeons = true
		if control.disabled and control.disabled() then fail(scenario, "the switch is greyed with the main switch on") end
		control.set(nil, true)
		if ns.db.profile.ownBuffs.foodOutside ~= true or not control.get() then fail(scenario, "the switch was not kept") end
		local layout = ns.WindowLayout
		local section = nil
		for _, sec in ipairs(layout and layout.pages and layout.pages.self and layout.pages.self.sections or {}) do
			if sec.key == "self.when" then section = sec end
		end
		if not section then fail(scenario, "the self.when section is missing") else
			local at, indent
			for i, item in ipairs(section.items) do
				local name = type(item) == "table" and item[1] or item
				if name == "who.ownFoodOutside" then at, indent = i, type(item) == "table" and item.indent end
			end
			local before = at and section.items[at - 1]
			before = type(before) == "table" and before[1] or before
			if not at then fail(scenario, "who.ownFoodOutside is not placed in self.when")
			else
				if before ~= "who.ownDungeons" then fail(scenario, "it comes after " .. tostring(before) .. ", not who.ownDungeons") end
				if indent ~= true then fail(scenario, "it is not indented under the main switch") end
			end
		end
		local reset = ns.OptionsPage and ns.OptionsPage.RESET and ns.OptionsPage.RESET.self or {}
		local listed = false
		for _, path in ipairs(reset) do if path == "ownBuffs.foodOutside" then listed = true end end
		if not listed then fail(scenario, "My own buffs' reset does not list ownBuffs.foodOutside") end
	end)
end
