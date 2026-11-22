-- A right-click on your own buffs can skip for minutes, not seconds (asked for
-- on CurseForge: a food fed to the pet came straight back as the next food in
-- the bags). "A right-click skips my own buffs for"
-- (timing.ownSkipMinutes, 0 follows skipSeconds) is the length of a
-- right-click on one of your own buffs on the prompt, the consumables button
-- and Not now in the menu; other people keep skipSeconds. A skipped food skips
-- every food in the bags, since any of them gives Well Fed (Queue.lua,
-- OwnSkipSeconds and SkipOwn).
--
-- Every scenario name starts with "ownskip-long:" so the mutations in
-- tests/mutations/ownskip-long.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, findOption = H.strangers, H.freshPrompt, H.findOption

-- The player as the addon files him: a two-part name on Forever, one name off it.
local function me(ns) return ns.UnitFullName("player") end
local ANNA = "Anna Aim"
-- Arcane Intellect, and the armor family.
local KNOWN = { 1459, 168, 7300, 7301, 7302, 6117 }

local function key(entry) return tostring(entry and entry.buff and entry.buff.key) end

-- Your own entry in the queue as it stands, or nil.
local function mine(ns)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.reason == "self" then return entry end
	end
	return nil
end

-- ---------------------------------------------------------------- the mage
-- A mage who knows Arcane Intellect and her armors and wears none of them.
-- `others` is a table of units for strangers() (nobody by default).
local MAGE_TOUCHED = { "IsSpellKnown", "IsPlayerSpell" }

local function mageWith(scenario, others, body)
	Mock.reset()
	Mock.class = "MAGE"
	local saved = {}
	for _, name in ipairs(MAGE_TOUCHED) do saved[name] = rawget(_G, name) end
	local known = {}
	for _, id in ipairs(KNOWN) do known[id] = true end
	rawset(_G, "IsSpellKnown", function(id) return known[id] == true end)
	rawset(_G, "IsPlayerSpell", function(id) return known[id] == true end)
	local undo = strangers(others or {})
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		Mock.playerHeld = {}
		freshPrompt(ns, scenario)
		Mock.runTimers(0)
		ns.Prompt:ExitTest()
		Mock.playerHeld = {}
		ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	undo()
	for _, name in ipairs(MAGE_TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.playerHeld = nil
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- The prompt on your first own buff: its key, or nil.
local function onFirst(ns)
	ns.Prompt:Refresh()
	local showing = ns.Prompt:Showing()
	if not (showing and showing.reason == "self") then return nil end
	return key(showing)
end

do
	local scenario = "ownskip-long: by default a right-click on my own buff skips as before"
	mageWith(scenario, nil, function(ns)
		if ns.defaults.profile.timing.ownSkipMinutes ~= 0 then
			fail(scenario, "the default is " .. tostring(ns.defaults.profile.timing.ownSkipMinutes))
		end
		local first = onFirst(ns)
		if not first then fail(scenario, "SKIPPED -- the prompt is not on your own buff") return end
		H.pressButton(ns, "RightButton")
		Mock.advance(11)
		if not ns.IsBlocked(me(ns), first) then fail(scenario, first .. " was offered again after 11 seconds") end
		Mock.advance(2)
		if ns.IsBlocked(me(ns), first) then fail(scenario, first .. " was still skipped after 13 seconds") end
	end)
end

do
	local scenario = "ownskip-long: a right-click on my own buff keeps it away for the minutes set"
	mageWith(scenario, nil, function(ns)
		ns.db.profile.timing.ownSkipMinutes = 15
		local first = onFirst(ns)
		if not first then fail(scenario, "SKIPPED -- the prompt is not on your own buff") return end
		H.pressButton(ns, "RightButton")
		Mock.advance(14 * 60)
		if not ns.IsBlocked(me(ns), first) then fail(scenario, first .. " came back after 14 minutes of a 15 minute skip") end
		Mock.advance(2 * 60)
		if ns.IsBlocked(me(ns), first) then fail(scenario, first .. " was still skipped after 16 minutes") end
	end)
end

do
	local scenario = "ownskip-long: ctrl-right-click on myself skips every buff of mine for the minutes set"
	mageWith(scenario, nil, function(ns)
		ns.db.profile.timing.ownSkipMinutes = 15
		if not onFirst(ns) then fail(scenario, "SKIPPED -- the prompt is not on your own buff") return end
		Mock.modifiers.ctrl = true
		H.pressButton(ns, "RightButton")
		Mock.modifiers.ctrl = nil
		Mock.advance(14 * 60)
		if not ns.IsBlocked(me(ns), nil) then fail(scenario, "your own buffs came back after 14 minutes of a 15 minute skip") end
		Mock.advance(2 * 60)
		if ns.IsBlocked(me(ns), nil) then fail(scenario, "your own buffs were still skipped after 16 minutes") end
		Mock.modifiers = {}
	end)
end

do
	local scenario = "ownskip-long: a right-click on another person keeps the seconds"
	mageWith(scenario, { party1 = { "Anna", "Aim" } }, function(ns)
		ns.db.profile.timing.ownSkipMinutes = 15
		Mock.groupSize = 2
		ns.owed[ANNA] = { expires = GetTime() + 100000, at = GetTime(), class = "PRIEST" }
		Mock.advance(1)
		ns.Prompt:Refresh()
		local showing = ns.Prompt:Showing()
		if not (showing and showing.name == ANNA) then
			fail(scenario, "SKIPPED -- the prompt is not on Anna")
			return
		end
		H.pressButton(ns, "RightButton")
		Mock.advance(11)
		if not ns.IsBlocked(ANNA, showing.buff and showing.buff.key) then
			fail(scenario, "Anna was offered again after 11 seconds")
		end
		Mock.advance(2)
		if ns.IsBlocked(ANNA, showing.buff and showing.buff.key) then
			fail(scenario, "Anna was still skipped after 13 seconds: the minutes were used for her")
		end
	end)
end

-- ---------------------------------------------------------------- the food
-- A warrior with food in his bags, as supplies.lua has him.
local FED_NAME, MEAL_NAME = "Well Fed", "Nutritious Food"
local world
local TOUCHED = { "C_Item", "C_Spell", "C_UnitAuras", "UnitLevel", "IsMounted", "IsSpellKnown", "IsPlayerSpell",
	"IsResting" }

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
		GetAuraDataBySpellName = function(unit) return nil end,
	}, { __index = base }))
end

local function foodWith(scenario, apart, body)
	Mock.reset()
	Mock.setFlavour("camelot")
	Mock.class = "WARRIOR"
	world = { bags = {}, meals = {}, fed = nil }
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
		ns.db.profile.ownBuffs.apart = apart
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

local function tick(ns)
	Mock.advance(1)
	ns.addon:Tick()
end

-- Two foods that both fit a level 60: the first is Automatic's pick, and the
-- second what it takes once the first is gone.
local function pair(data)
	local first
	for _, row in ipairs(data) do
		if row[2] <= 60 then
			if not first then
				first = row
			elseif row[1] ~= first[1] then
				return first, row
			end
		end
	end
end

do
	local scenario = "ownskip-long: a skipped food keeps every food away"
	foodWith(scenario, false, function(ns, data)
		local first, second = pair(data)
		stock(ns, { [first[1]] = 2, [second[1]] = 2 })
		ns.db.profile.timing.ownSkipMinutes = 15
		tick(ns)
		ns.Prompt:Refresh()
		local showing = ns.Prompt:Showing()
		if not (showing and showing.reason == "self" and key(showing) == "food" .. first[1]) then
			fail(scenario, "SKIPPED -- the prompt is on " .. key(showing) .. ", not the first food")
			return
		end
		H.pressButton(ns, "RightButton")
		-- The first stack is fed to the pet; the second food is still in the bags.
		stock(ns, { [second[1]] = 2 })
		Mock.advance(10 * 60)
		tick(ns)
		local entry = mine(ns)
		if entry and entry.buff and entry.buff.family and entry.buff.family.food then
			fail(scenario, "ten minutes into a skip, " .. key(entry) .. " came up")
		end
		Mock.advance(6 * 60)
		tick(ns)
		entry = mine(ns)
		if not (entry and key(entry) == "food" .. second[1]) then
			fail(scenario, "sixteen minutes on, the food did not come back: " .. key(entry))
		end
	end)
end

do
	local scenario = "ownskip-long: the consumables button keeps it away for the minutes set"
	foodWith(scenario, true, function(ns, data)
		stock(ns, { [data[1][1]] = 3 })
		ns.db.profile.timing.ownSkipMinutes = 15
		tick(ns)
		local b = ns.Supplies:Button()
		if not (b and b:IsShown()) then fail(scenario, "SKIPPED -- no button") return end
		b.scripts.OnClick(b, "RightButton", true)
		Mock.advance(14 * 60)
		tick(ns)
		if b:IsShown() then fail(scenario, "the button was back after 14 minutes of a 15 minute skip") end
		Mock.advance(2 * 60)
		tick(ns)
		if not b:IsShown() then fail(scenario, "the button did not come back after 16 minutes") end
	end)
end

do
	local scenario = "ownskip-long: the setting is placed and capped"
	foodWith(scenario, false, function(ns)
		local control = findOption(ns.optionsTable, "ownSkipMinutes")
		if not control then fail(scenario, "no setting for how long a right-click on my own buffs skips") return end
		if control.type ~= "range" or control.max ~= 240 or control.min ~= 0 then
			fail(scenario, "the setting is not a slider from 0 to 240")
		end
		ns.db.profile.timing.ownSkipMinutes = 99999
		ns.ClampSettings()
		if ns.db.profile.timing.ownSkipMinutes ~= 240 then
			fail(scenario, "the length is not capped: " .. tostring(ns.db.profile.timing.ownSkipMinutes))
		end
	end)
end
