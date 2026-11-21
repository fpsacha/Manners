-- The verdicts findings of the second pass, each written red on the tree it
-- was found on (branch pass-2, cut from 1.11.34) and green once it is fixed.
--
--   1  a meal of plain food (no Well Fed) lets go a right-click's skip of
--      every food: OwnVerdict's mealOn branch writes 0 over the minutes-long
--      block ns.SkipOwn wrote (Core.lua)
--   2  Hold back short buffs in cities and inns stops holding your own short
--      buffs once Never in cities and inns is ticked, though that rule never
--      holds you (Queue.lua, SelfEntry's f.quietInTowns ~= true)
--
-- Every scenario name starts with "pass2-verdicts: ".

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

local function key(entry) return tostring(entry and entry.buff and entry.buff.key) end

local function mine(ns)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.reason == "self" then return entry end
	end
	return nil
end

-- ------------------------------------------------------------------ 1 the meal
-- A warrior on Forever with Well Fed food in his bags. The client names most of
-- Forever's Well Fed foods' use spell "Nutritious Food", but six of them (10256
-- among them) cast "Food", the same name plain bread's use (433) has.
local FED_NAME, MEAL_NAME, PLAIN_MEAL = "Well Fed", "Nutritious Food", "Food"
local PLAIN_USE = 10256
local world
local TOUCHED = { "C_Item", "C_Spell", "C_UnitAuras", "UnitLevel", "IsMounted", "IsSpellKnown", "IsPlayerSpell",
	"IsResting" }

local function install()
	rawset(_G, "C_Spell", nil)
	local spells = C_Spell
	rawset(_G, "C_Spell", setmetatable({
		GetSpellName = function(id)
			if id == world.fed then return FED_NAME end
			if id == PLAIN_USE then return PLAIN_MEAL end
			if world.meals[id] then return MEAL_NAME end
			return spells.GetSpellName(id)
		end,
	}, { __index = spells }))
	rawset(_G, "C_Item", {
		GetItemCount = function(id) return world.bags[id] or 0 end,
		GetItemNameByID = function(id) return "Food " .. id end,
		RequestLoadItemDataByID = function() end,
		GetItemIconByID = function(id) return 7100000 + id end,
		GetItemInfoInstant = function(id) return id, "Consumable", "", "", 7100000 + id, 0, 5 end,
	})
	rawset(_G, "UnitLevel", function(unit)
		if unit == "player" then return 60 end
		return 12
	end)
	rawset(_G, "IsMounted", function() return false end)
	rawset(_G, "IsResting", function() return false end)
	rawset(_G, "C_UnitAuras", nil)
	local base = C_UnitAuras
	rawset(_G, "C_UnitAuras", setmetatable({
		GetAuraDataBySpellName = function(unit, name)
			if unit ~= "player" then return nil end
			local expires = world.auras[name]
			if expires == nil then return nil end
			return { name = name, expirationTime = expires, sourceUnit = "player" }
		end,
	}, { __index = base }))
end

local function food(scenario, body)
	Mock.reset()
	Mock.setFlavour("camelot")
	Mock.class = "WARRIOR"
	world = { bags = {}, meals = {}, fed = nil, auras = {} }
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
		ns.db.profile.ownBuffs.pick.food = "auto"
		ns.ForgetScrolls()
		ns.db.profile.ownBuffs.apart = false
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

local function tick(ns)
	Mock.advance(1)
	ns.addon:Tick()
end

do
	local scenario = "pass2-verdicts: a meal of plain bread keeps a skipped food skipped"
	food(scenario, function(ns, data)
		local first
		for _, row in ipairs(data) do
			if row[2] <= 60 then first = row break end
		end
		world.bags = { [first[1]] = 3 }
		ns.addon:BAG_UPDATE_DELAYED()
		ns.db.profile.timing.ownSkipMinutes = 60
		tick(ns)
		ns.Prompt:Refresh()
		local showing = ns.Prompt:Showing()
		if not (showing and showing.reason == "self" and key(showing) == "food" .. first[1]) then
			fail(scenario, "SKIPPED -- the prompt is on " .. key(showing) .. ", not the food")
			return
		end
		-- A right-click on the food: every food skipped for the hour.
		H.pressButton(ns, "RightButton")
		tick(ns)
		local entry = mine(ns)
		if entry and entry.buff and entry.buff.family and entry.buff.family.food then
			fail(scenario, "SKIPPED -- the right-click did not skip the food: " .. key(entry))
			return
		end
		-- Ten minutes on, he sits down to eat plain bread (its aura "Food", no
		-- Well Fed after it), and stands up again.
		Mock.advance(10 * 60)
		world.auras[PLAIN_MEAL] = GetTime() + 18
		tick(ns)
		mine(ns)
		tick(ns)
		world.auras[PLAIN_MEAL] = nil
		tick(ns)
		mine(ns)
		tick(ns)
		entry = mine(ns)
		if entry and entry.buff and entry.buff.family and entry.buff.family.food then
			fail(scenario, "eleven minutes into a sixty-minute skip, a meal of plain bread brought "
				.. key(entry) .. " back")
		end
	end)
end

-- ---------------------------------------------------- 2 short buffs, yourself
-- A druid who knows Mark of the Wild and Thorns, wears the Mark and lets her
-- own buffs through in cities (ownBuffs.inCities), with Hold back short buffs
-- in cities and inns on at fifteen minutes: Thorns (ten) waits for her.
local DRUID_TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "IsInInstance", "C_UnitAuras", "IsResting", "UnitLevel" }
local MOTW = 9885

local function druid(scenario, body)
	Mock.reset()
	Mock.setFlavour("camelot")
	Mock.class = "DRUID"
	Mock.groupSize = 0
	Mock.nameplates = {}
	local restoreUnits = strangers({})
	local saved = {}
	for _, name in ipairs(DRUID_TOUCHED) do saved[name] = rawget(_G, name) end
	local known = {}
	local function isKnown(id) return known[id] == true end
	rawset(_G, "IsSpellKnown", isKnown)
	rawset(_G, "IsPlayerSpell", isKnown)
	rawset(_G, "IsInInstance", function() return false, "none" end)
	rawset(_G, "IsResting", function() return true end)
	rawset(_G, "UnitLevel", function() return 60 end)
	local base = C_UnitAuras
	rawset(_G, "C_UnitAuras", setmetatable({
		GetUnitAuraBySpellID = function(unit, spellId)
			if unit ~= "player" or spellId ~= MOTW then return nil end
			return { spellId = spellId, expirationTime = Mock.now + 3000, sourceUnit = "player" }
		end,
	}, { __index = base }))
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		for _, k in ipairs({ "motw", "thorns" }) do
			local buff = ns.FindBuff("DRUID", k)
			if not buff then fail(scenario, "SKIPPED -- no " .. k .. " for a druid on this client") return end
			for _, id in ipairs(buff.ranks or {}) do
				if (ns.RankLevel(id) or 1) <= 60 then known[id] = true end
			end
		end
		freshPrompt(ns, scenario)
		local db = ns.db.profile
		db.sources.self = true
		db.ownBuffs.inCities = true
		db.filters.quietShortInTowns = true
		db.filters.quietShortMinutes = 15
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.Prompt:ApplyTarget(nil)
		ns.Prompt:InvalidateMacro()
		ns.addon:Tick()
		body(ns, db)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	for _, name in ipairs(DRUID_TOUCHED) do rawset(_G, name, saved[name]) end
	restoreUnits()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function selfKey(ns)
	Mock.advance(4)
	local entry = mine(ns)
	return entry and entry.buff and entry.buff.key or "nothing"
end

do
	local scenario = "pass2-verdicts: Never in cities and inns does not let your own short buffs through"
	druid(scenario, function(ns, db)
		db.filters.quietInTowns = false
		if selfKey(ns) == "thorns" then
			fail(scenario, "SKIPPED -- Thorns is offered to yourself in town with the short hold on and nothing else")
			return
		end
		-- (a) the stricter rule ticked, in a city: it never holds you, so the
		-- short hold has to hold your Thorns still.
		db.filters.quietInTowns = true
		db.filters.quietInTownsWhere = "both"
		if selfKey(ns) == "thorns" then
			fail(scenario, "with Never in cities and inns ticked, Thorns (ten minutes) is offered to yourself in town")
		end
		-- (b) the rule limited to cities, resting in an inn out in the world.
		local inCity = ns.InCity
		ns.InCity = function() return false end
		db.filters.quietInTownsWhere = "cities"
		local got = selfKey(ns)
		ns.InCity = inCity
		if got == "thorns" then
			fail(scenario, "with the rule limited to cities, in an inn, Thorns is offered to yourself")
		end
	end)
end
