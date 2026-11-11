-- An interrupted meal (1.11.15). A player on CurseForge pressed the reminder to
-- eat, was stood up before Well Fed came, and had to wait out the press's
-- retry block before the reminder came back. Now the end of a meal that left
-- no Well Fed lets the block go for every food of the family, and the reminder
-- is back on the next scan (Core.lua, OwnVerdict, mealOn).
--
-- Every scenario name starts with "mealcut:" so the mutations in
-- tests/mutations/mealcut.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

local FED_NAME, MEAL_NAME = "Well Fed", "Nutritious Food"

local function said() return table.concat(Mock.printed, "\n") end
local function key(entry) return tostring(entry and entry.buff and entry.buff.key) end
local function macro(ns) return ns.Prompt:GetButton():GetAttribute("macrotext1") end

local function mine(ns)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.reason == "self" then return entry end
	end
	return nil
end

-- The world a scenario stands in: bags (item -> count), the player's auras by
-- name, his level, whether he is mounted, and which items were counted.
local world
local TOUCHED = { "C_Item", "C_Spell", "C_UnitAuras", "UnitLevel", "IsMounted", "IsSpellKnown", "IsPlayerSpell",
	"IsResting" }

local function install(ns)
	rawset(_G, "C_Spell", nil)
	local spells = C_Spell
	rawset(_G, "C_Spell", setmetatable({
		GetSpellName = function(id)
			if id == world.fed then return FED_NAME end
			if world.meals[id] then return MEAL_NAME end
			return spells.GetSpellName(id)
		end,
	}, { __index = spells }))
	rawset(_G, "C_Item", {
		GetItemCount = function(id)
			world.counted[id] = (world.counted[id] or 0) + 1
			return world.bags[id] or 0
		end,
		GetItemNameByID = function(id) return "Food " .. id end,
		RequestLoadItemDataByID = function() end,
		GetItemIconByID = function(id) return 7100000 + id end,
		GetItemInfoInstant = function(id) return id, "Consumable", "", "", 7100000 + id, 0, 5 end,
	})
	rawset(_G, "UnitLevel", function(unit)
		if unit == "player" then return world.level end
		return 12
	end)
	rawset(_G, "IsMounted", function() return world.mounted end)
	rawset(_G, "IsResting", function() return false end)
	rawset(_G, "C_UnitAuras", nil)
	local base = C_UnitAuras
	rawset(_G, "C_UnitAuras", setmetatable({
		GetAuraDataBySpellName = function(unit, name)
			if unit ~= "player" then return nil end
			if world.refuse then return Mock.SECRET end
			local expires = world.auras[name]
			if expires == nil then return nil end
			return { name = name, expirationTime = expires, sourceUnit = "player" }
		end,
	}, { __index = base }))
end

-- One session as `opts.class` (a warrior) on `opts.flavour` (Forever), with
-- opts.bags, opts.level, opts.auras (name -> expiry), opts.on (the switch).
local function with(scenario, opts, body)
	Mock.reset()
	Mock.setFlavour(opts.flavour or "camelot")
	Mock.class = opts.class or "WARRIOR"
	world = { bags = opts.bags or {}, level = opts.level or 60, auras = opts.auras or {}, counted = {},
		mounted = false, meals = {}, fed = nil, refuse = false }
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local undo = strangers({})
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		local data = ns.FOODS[opts.flavour or "camelot"]
		-- Retail has no table: nothing to name or to eat.
		if data then
			world.fed = data.fed
			for _, row in ipairs(data) do world.meals[row[3]] = true end
		end
		install(ns)
		rawset(_G, "IsSpellKnown", function() return false end)
		rawset(_G, "IsPlayerSpell", function() return false end)
		Mock.playerHeld = {}
		freshPrompt(ns, scenario)
		Mock.playerHeld = {}
		if opts.on then
			ns.db.profile.ownBuffs.pick.food = "auto"
			ns.ForgetScrolls()
		end
		body(ns, data)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	undo()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.playerHeld = nil
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function stock(ns, bags)
	world.bags = bags
	ns.addon:BAG_UPDATE_DELAYED()
end

-- The press as Press.lua writes it: the food blocked for the retry cooldown.
local function press(ns, entry)
	ns.MarkAttempted(entry.name, entry.buff.key)
end

do
	local scenario = "mealcut: a meal cut short brings the reminder back at once"
	with(scenario, { on = true }, function(ns, data)
		stock(ns, { [data[1][1]] = 3 })
		local entry = mine(ns)
		if not entry then fail(scenario, "SKIPPED -- food was not offered to begin with") return end
		press(ns, entry)
		Mock.advance(1)
		if mine(ns) then fail(scenario, "SKIPPED -- the press did not hold the food back") return end
		world.auras[MEAL_NAME] = GetTime() + 18
		Mock.advance(2)
		if mine(ns) then fail(scenario, "food offered in the middle of a meal") end
		-- Stood up three seconds in: no Well Fed, the cooldown not yet out.
		world.auras[MEAL_NAME] = nil
		Mock.advance(0.5)
		if not mine(ns) then fail(scenario, "the meal was cut short and the reminder waits out the cooldown") end
	end)
end

do
	local scenario = "mealcut: a meal that gave Well Fed offers nothing"
	with(scenario, { on = true }, function(ns, data)
		stock(ns, { [data[1][1]] = 3 })
		local entry = mine(ns)
		if not entry then fail(scenario, "SKIPPED -- food was not offered to begin with") return end
		press(ns, entry)
		world.auras[MEAL_NAME] = GetTime() + 18
		Mock.advance(1)
		mine(ns)
		world.auras[MEAL_NAME] = nil
		world.auras[FED_NAME] = GetTime() + 3600
		Mock.advance(0.5)
		if mine(ns) then fail(scenario, "Well Fed is on, and food is offered: " .. key(mine(ns))) end
	end)
end

do
	local scenario = "mealcut: a press with no meal after it still waits out the cooldown"
	with(scenario, { on = true }, function(ns, data)
		stock(ns, { [data[1][1]] = 3 })
		local entry = mine(ns)
		if not entry then fail(scenario, "SKIPPED -- food was not offered to begin with") return end
		press(ns, entry)
		Mock.advance(3)
		if mine(ns) then fail(scenario, "a press that started no meal was offered again inside the cooldown") end
	end)
end
