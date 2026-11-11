-- Classes I buff as passers-by (filters.skipNearbyClasses). A player on
-- CurseForge asked to filter certain classes out of the passers-by. A grid of
-- the client's classes on Who to skip, all ticked in a new profile; a class
-- unticked is never offered your buff as a passer-by, remembered or not. Your
-- group, a favour owed, a request and your target or focus are not held to it.
--
-- Every scenario name starts with "classskip:" so the mutations in
-- tests/mutations/classskip.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

-- Anna, a warrior passing by; Bran, a rogue passing by; Gwen, a warrior in
-- your party; Tess, a warrior you target.
local CLASSES = { nameplate1 = "WARRIOR", nameplate2 = "ROGUE", party1 = "WARRIOR", target = "WARRIOR" }

local function with(scenario, body, units)
	Mock.reset()
	Mock.class = "MAGE"
	Mock.groupSize = 2
	local savedClass, savedParty = rawget(_G, "UnitClass"), rawget(_G, "UnitInParty")
	local restore = strangers(units or { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bran", "Bell" },
		party1 = { "Gwen", "Hale" }, target = { "Tess", "Target" } })
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		rawset(_G, "UnitClass", function(unit)
			if unit == "player" then return "Mage", "MAGE" end
			local class = CLASSES[unit]
			return class and (class:sub(1, 1) .. class:sub(2):lower()) or "Priest", class or "PRIEST"
		end)
		rawset(_G, "UnitInParty", function(unit)
			return type(unit) == "string" and unit:find("^party%d") ~= nil
		end)
		freshPrompt(ns, scenario)
		ns.db.profile.sources.strangers = true
		ns.db.profile.sources.group = true
		body(ns)
	end)
	restore()
	rawset(_G, "UnitClass", savedClass)
	rawset(_G, "UnitInParty", savedParty)
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function named(first, last)
	return Mock.surnames and (first .. " " .. last) or first
end

local ANNA, BRAN, GWEN, TESS = named("Anna", "Aim"), named("Bran", "Bell"), named("Gwen", "Hale"),
	named("Tess", "Target")

local function queue(ns)
	Mock.advance(4)
	local out = {}
	for _, entry in ipairs(ns.BuildQueue()) do out[entry.name] = entry end
	return out
end

do
	local scenario = "classskip: every class is offered in a new profile"
	with(scenario, function(ns)
		if next(ns.db.profile.filters.skipNearbyClasses) ~= nil then
			fail(scenario, "a new profile leaves a class out")
		end
		local list = queue(ns)
		for _, name in ipairs({ ANNA, BRAN, GWEN, TESS }) do
			if not list[name] then fail(scenario, name .. " was not offered") end
		end
	end)
end

do
	local scenario = "classskip: a passer-by of an unticked class is left out, others are not"
	with(scenario, function(ns)
		ns.db.profile.filters.skipNearbyClasses.WARRIOR = true
		local list = queue(ns)
		if list[ANNA] then fail(scenario, "a warrior passing by was offered with warriors unticked") end
		if not list[BRAN] then fail(scenario, "a rogue passing by was held back") end
	end)
end

do
	local scenario = "classskip: your group and your target of that class are still offered"
	with(scenario, function(ns)
		ns.db.profile.filters.skipNearbyClasses.WARRIOR = true
		local list = queue(ns)
		if not list[GWEN] then fail(scenario, "a warrior in your party was held back") end
		if not list[TESS] then fail(scenario, "your target, a warrior, was held back") end
	end)
end

do
	local scenario = "classskip: somebody of that class who buffed you is still offered"
	with(scenario, function(ns)
		ns.db.profile.filters.skipNearbyClasses.WARRIOR = true
		H.owe(ns, ANNA)
		local list = queue(ns)
		if not list[ANNA] then fail(scenario, "a favour owed to a warrior was dropped") end
	end)
end

-- Seen once while every class was offered, then gone from the nameplates: the
-- memory of them is let go as soon as their class is unticked.
do
	local scenario = "classskip: a passer-by remembered is let go when the class is unticked"
	with(scenario, function(ns)
		local list = queue(ns)
		if not list[ANNA] then fail(scenario, "SKIPPED -- Anna was not offered to begin with") return end
		Mock.unitNames.nameplate1 = nil
		ns.nameplateUnits.nameplate1 = nil
		Mock.advance(0.5)
		list = {}
		for _, entry in ipairs(ns.BuildQueue()) do list[entry.name] = entry end
		if not list[ANNA] then fail(scenario, "SKIPPED -- Anna was not remembered once out of sight") return end
		ns.db.profile.filters.skipNearbyClasses.WARRIOR = true
		Mock.advance(0.5)
		list = {}
		for _, entry in ipairs(ns.BuildQueue()) do list[entry.name] = entry end
		if list[ANNA] then fail(scenario, "a warrior remembered as a passer-by was still offered") end
	end)
end

do
	local scenario = "classskip: the grid lists the client's classes, ticked, and unticking stores it"
	with(scenario, function(ns)
		local option = H.findOption(ns.optionsTable, "skipNearbyClasses")
		if not option then fail(scenario, "Who to skip has no class grid") return end
		local values = type(option.values) == "function" and option.values() or option.values
		local count = 0
		for _ in pairs(values) do count = count + 1 end
		if count ~= 9 or not values.WARRIOR or not values.DRUID or values.MONK then
			fail(scenario, ("the grid holds %d classes on WoW Forever"):format(count))
		end
		if option.get(nil, "WARRIOR") ~= true then fail(scenario, "warriors are not ticked in a new profile") end
		option.set(nil, "WARRIOR", false)
		if ns.db.profile.filters.skipNearbyClasses.WARRIOR ~= true or option.get(nil, "WARRIOR") ~= false then
			fail(scenario, "unticking warriors was not stored")
		end
		option.set(nil, "WARRIOR", true)
		if ns.db.profile.filters.skipNearbyClasses.WARRIOR ~= nil then
			fail(scenario, "ticking warriors again did not put them back")
		end
		local disabled = option.disabled
		ns.db.profile.sources.strangers = false
		if not (type(disabled) == "function" and disabled()) then
			fail(scenario, "the grid is not greyed with passers-by off")
		end
	end)
end

do
	local scenario = "classskip: a damaged set is repaired and the set travels with a profile"
	with(scenario, function(ns)
		local p = ns.db.profile
		p.filters.skipNearbyClasses = { WARRIOR = true, ROGUE = "yes", [3] = true, mage = true }
		ns.ClampSettings(p)
		local set = p.filters.skipNearbyClasses
		if set.WARRIOR ~= true or set.ROGUE ~= nil or set[3] ~= nil or set.mage ~= nil then
			fail(scenario, "the repair kept something that is not a class token set to true")
		end
		p.filters.skipNearbyClasses = "all"
		ns.ClampSettings(p)
		if type(p.filters.skipNearbyClasses) ~= "table" then fail(scenario, "a set that is not a table was kept") end
		p.filters.skipNearbyClasses = { HUNTER = true, PRIEST = true }
		local text = ns.ExportSettings()
		if not text:find("filters.skipNearbyClasses=HUNTER,PRIEST", 1, true) then
			fail(scenario, "the export does not carry the classes left out: " .. text)
		end
		p.filters.skipNearbyClasses = {}
		local ok = ns.ImportSettings(text)
		p = ns.db.profile
		if not ok or p.filters.skipNearbyClasses.HUNTER ~= true or p.filters.skipNearbyClasses.PRIEST ~= true then
			fail(scenario, "restoring an export lost the classes left out")
		end
	end)
end
