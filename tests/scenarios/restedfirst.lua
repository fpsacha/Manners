-- Sleeping bag before food and elixirs (ownBuffs.restedFirst), asked for on
-- CurseForge: a player ate and drank their elixirs, then was reminded to lie
-- in the Cozy Sleeping Bag for Well-Rested, and spent the elixirs' minutes
-- lying down. With the switch on, food, flasks, elixirs and scrolls wait while
-- the bag is due or you lie in it; its cooldown alone holds nothing back. Off
-- by default.
--
-- Every scenario name starts with "restedfirst:" so the mutations in
-- tests/mutations/restedfirst.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, findOption = H.strangers, H.freshPrompt, H.findOption

local BAG, RESTED, IN_BAG = 211527, 429959, 429960
local FED_NAME, MEAL_NAME = "Well Fed", "Nutritious Food"

local function key(entry) return tostring(entry and entry.buff and entry.buff.key) end

local function mine(ns)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.reason == "self" then return entry end
	end
	return nil
end

local world
local TOUCHED = { "C_Item", "C_Spell", "C_UnitAuras", "C_Container", "UnitLevel", "GetMaxPlayerLevel", "IsMounted",
	"IsSpellKnown", "IsPlayerSpell", "IsResting" }

local function install()
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
		GetItemCount = function(id) return world.bags[id] or 0 end,
		GetItemNameByID = function(id) return "Item " .. id end,
		RequestLoadItemDataByID = function() end,
		GetItemIconByID = function(id) return 7100000 + id end,
		GetItemInfoInstant = function(id)
			if id == BAG then return id, "Miscellaneous", "", "", 7100000 + id, 15, 0 end
			return id, "Consumable", "", "", 7100000 + id, 0, 5
		end,
	})
	rawset(_G, "UnitLevel", function(unit)
		if unit == "player" then return world.level end
		return 12
	end)
	rawset(_G, "GetMaxPlayerLevel", function() return 60 end)
	rawset(_G, "IsMounted", function() return false end)
	rawset(_G, "IsResting", function() return false end)
	local container = rawget(_G, "C_Container")
	rawset(_G, "C_Container", setmetatable({
		GetItemCooldown = function(id)
			if id == BAG and world.cooldownUntil then
				return world.cooldownUntil - 3600, 3600, 1
			end
			return 0, 0, 1
		end,
	}, { __index = container or {} }))
	rawset(_G, "C_UnitAuras", nil)
	local base = C_UnitAuras
	rawset(_G, "C_UnitAuras", setmetatable({
		GetUnitAuraBySpellID = function(unit, id)
			if unit ~= "player" then return nil end
			local expires = world.ids[id]
			if expires == nil then return nil end
			return { spellId = id, name = "Aura " .. id, expirationTime = expires, duration = 7200, sourceUnit = "player" }
		end,
		GetAuraDataBySpellName = function(unit, name)
			if unit ~= "player" then return nil end
			local expires = world.names[name]
			if expires == nil then return nil end
			return { name = name, expirationTime = expires, sourceUnit = "player" }
		end,
	}, { __index = base }))
end

-- One session as a level 30 warrior on Forever with a meal and the bag in the
-- bags, Well Fed and Well-Rested both switched on; opts.first sets the switch.
local function with(scenario, opts, body)
	Mock.reset()
	Mock.setFlavour("camelot")
	Mock.class = "WARRIOR"
	world = { bags = {}, level = 30, ids = {}, names = {}, meals = {}, fed = nil, cooldownUntil = nil }
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local undo = strangers({})
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		local data = ns.FOODS.camelot
		world.fed = data.fed
		for _, row in ipairs(data) do world.meals[row[3]] = true end
		install()
		rawset(_G, "IsSpellKnown", function() return false end)
		rawset(_G, "IsPlayerSpell", function() return false end)
		Mock.playerHeld = {}
		freshPrompt(ns, scenario)
		Mock.playerHeld = {}
		local meal
		for _, row in ipairs(data) do
			if row[2] <= world.level then meal = row[1] break end
		end
		world.bags = { [BAG] = 1, [meal] = 1 }
		ns.db.profile.ownBuffs.pick.rested = "auto"
		ns.db.profile.ownBuffs.pick.food = "auto"
		if opts.first then ns.db.profile.ownBuffs.restedFirst = true end
		ns.ForgetScrolls()
		ns.addon:BAG_UPDATE_DELAYED()
		Mock.advance(1)
		body(ns, meal)
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

local function auras(ns)
	ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
	Mock.advance(1)
end

do
	local scenario = "restedfirst: off by default, food comes up ahead of the bag"
	with(scenario, {}, function(ns, meal)
		if ns.db.profile.ownBuffs.restedFirst ~= false then
			fail(scenario, "a new profile's switch is " .. tostring(ns.db.profile.ownBuffs.restedFirst) .. ", not off")
		end
		if key(mine(ns)) ~= "food" .. meal then
			fail(scenario, "off, both missing: offered " .. key(mine(ns)) .. ", not food" .. meal)
		end
	end)
end

do
	local scenario = "restedfirst: on, the bag comes first and food waits"
	with(scenario, { first = true }, function(ns, meal)
		if key(mine(ns)) ~= "rested" .. BAG then
			fail(scenario, "on, both missing: offered " .. key(mine(ns)) .. ", not the bag")
		end
		local lines = table.concat(ns.MyselfLines(GetTime()), " / ")
		if not lines:find("waits until you have slept in the sleeping bag", 1, true) then
			fail(scenario, "the food's line does not say it waits for the bag: " .. lines)
		end
		-- Lying in the bag, Well-Rested still to come: the food still waits.
		world.ids[IN_BAG] = GetTime() + 120
		auras(ns)
		if key(mine(ns)) == "food" .. meal then fail(scenario, "on, lying in the bag: food offered") end
		-- Well-Rested on you: the food comes up.
		world.ids[IN_BAG] = nil
		world.ids[RESTED] = GetTime() + 7000
		auras(ns)
		if key(mine(ns)) ~= "food" .. meal then
			fail(scenario, "on, Well-Rested up: offered " .. key(mine(ns)) .. ", not food" .. meal)
		end
	end)
end

do
	local scenario = "restedfirst: the bag cooling down holds nothing back"
	with(scenario, { first = true }, function(ns, meal)
		world.cooldownUntil = GetTime() + 3000
		auras(ns)
		if key(mine(ns)) ~= "food" .. meal then
			fail(scenario, "on, the bag on its cooldown: offered " .. key(mine(ns)) .. ", not food" .. meal)
		end
		-- Well-Rested switched off: the switch holds nothing back either.
		world.cooldownUntil = nil
		ns.db.profile.ownBuffs.pick.rested = "off"
		Mock.advance(1)
		if key(mine(ns)) ~= "food" .. meal then
			fail(scenario, "on, Well-Rested off: offered " .. key(mine(ns)) .. ", not food" .. meal)
		end
	end)
end

do
	local scenario = "restedfirst: its switch shows under Well-Rested while that is on"
	with(scenario, {}, function(ns)
		local control = findOption(ns.optionsTable, "ownRestedFirst")
		if not control then
			fail(scenario, "Who to buff has no switch for the bag before food")
			return
		end
		if control.type ~= "toggle" then fail(scenario, "the switch is a " .. tostring(control.type)) end
		if control.hidden and control.hidden() then fail(scenario, "hidden with Well-Rested on") end
		ns.db.profile.ownBuffs.pick.rested = "off"
		if not (control.hidden and control.hidden()) then fail(scenario, "shown with Well-Rested off") end
		if control.get() ~= false then fail(scenario, "reads on with the profile off") end
		control.set({ "ownRestedFirst" }, true)
		if ns.db.profile.ownBuffs.restedFirst ~= true then fail(scenario, "turning it on wrote nothing") end
		control.set({ "ownRestedFirst" }, false)
		if ns.db.profile.ownBuffs.restedFirst ~= false then fail(scenario, "turning it off wrote nothing") end
	end)
end
