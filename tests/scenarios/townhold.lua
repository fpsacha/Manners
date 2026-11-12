-- Where Offer nothing in cities and inns holds (filters.quietInTownsWhere,
-- asked for on CurseForge: "I don't want it enabled in cities, but a lot of
-- people in the inns are just doing quests or taking a short break, so I like
-- to try and buff them too"). Under the switch on When to offer: cities and
-- inns (the default, as it always was), cities only, inns only. A city is a
-- capital by the map the client says you are on and its parents, against each
-- client's own UiMap ids (Range.lua, ns.InCity); an inn is resting anywhere
-- else. A map the client will not name holds back both, as before.
--
-- Every scenario name starts with "townhold:" so the mutations in
-- tests/mutations/townhold.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, findOption = H.strangers, H.freshPrompt, H.findOption

local TOUCHED = { "IsResting", "UnitInParty", "C_Map" }

-- A capital, a part of one and a place that is no capital, by the ids the
-- flavour's own maps use (Range.lua): Stormwind City is 1453 on Forever and the
-- Classic clients, 84 on Mists and retail. 99901 is a map of the mock's own
-- whose parent is the capital, as Orgrimmar's Cleft of Shadow is Orgrimmar's.
local CITY = { camelot = 1453, vanilla = 1453, tbc = 1453, mists = 84, mainline = 84 }
local INN = { camelot = 1429, vanilla = 1429, tbc = 1429, mists = 37, mainline = 37 }
local PART = 99901

-- One session as a mage, resting unless `state.resting` says otherwise, on
-- `state.map` (a number, or a function standing in for GetBestMapForUnit), with
-- a passer-by, a party member and a target, and Offer nothing in cities and
-- inns on with `where` (nil leaves the default).
local function with(scenario, opts, body)
	Mock.reset()
	if opts.flavour then Mock.setFlavour(opts.flavour) end
	Mock.class = "MAGE"
	Mock.groupSize = 2
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local state = { resting = true, map = nil, parents = {} }
	local restore = strangers({ nameplate1 = { "Anna", "Aim" }, party1 = { "Gwen", "Hale" },
		target = { "Tess", "Target" } })
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		local flavour = ns.Flavour and ns.Flavour.flavour or "camelot"
		state.city, state.inn = CITY[flavour] or 84, INN[flavour] or 37
		state.parents[PART] = state.city
		state.map = state.inn
		rawset(_G, "IsResting", function() return state.resting end)
		rawset(_G, "UnitInParty", function(unit)
			return type(unit) == "string" and unit:find("^party%d") ~= nil
		end)
		rawset(_G, "C_Map", {
			GetBestMapForUnit = function(unit)
				if unit ~= "player" then return nil end
				if type(state.map) == "function" then return state.map() end
				return state.map
			end,
			GetMapInfo = function(id)
				return { mapID = id, parentMapID = state.parents[id] or 0 }
			end,
		})
		freshPrompt(ns, scenario)
		ns.db.profile.sources.strangers = true
		ns.db.profile.sources.group = true
		if opts.on ~= false then ns.db.profile.filters.quietInTowns = true end
		if opts.where then ns.db.profile.filters.quietInTownsWhere = opts.where end
		body(ns, state)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	restore()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- A name as the queue files it: Forever's two-part names, the others' first.
local function named(first, last)
	return Mock.surnames and (first .. " " .. last) or first
end

local function names(ns)
	Mock.advance(4)
	local out = {}
	for _, entry in ipairs(ns.BuildQueue()) do out[#out + 1] = entry.name end
	table.sort(out)
	return table.concat(out, ",")
end

-- Anna (a passer-by) and Gwen (the party) both offered, or neither.
local function both(ns)
	local out = names(ns)
	return out:find(named("Anna", "Aim"), 1, true) ~= nil and out:find(named("Gwen", "Hale"), 1, true) ~= nil, out
end
local function neither(ns)
	local out = names(ns)
	return out:find(named("Anna", "Aim"), 1, true) == nil and out:find(named("Gwen", "Hale"), 1, true) == nil, out
end

do
	local scenario = "townhold: cities and inns by default, both held back as before"
	with(scenario, {}, function(ns, state)
		if ns.defaults.profile.filters.quietInTownsWhere ~= "both" then
			fail(scenario, "the default is " .. tostring(ns.defaults.profile.filters.quietInTownsWhere))
		end
		state.map = state.inn
		local ok, out = neither(ns)
		if not ok then fail(scenario, "somebody was offered at an inn with the default: " .. out) end
		state.map = state.city
		ok, out = neither(ns)
		if not ok then fail(scenario, "somebody was offered in a capital with the default: " .. out) end
	end)
end

do
	local scenario = "townhold: cities only, an inn offers as ever"
	with(scenario, { where = "cities" }, function(ns, state)
		state.map = state.inn
		local ok, out = both(ns)
		if not ok then fail(scenario, "with cities only, somebody was held back at an inn: " .. out) end
	end)
end

do
	local scenario = "townhold: cities only, a capital offers nothing but the target"
	with(scenario, { where = "cities" }, function(ns, state)
		state.map = state.city
		local ok, out = neither(ns)
		if not ok then fail(scenario, "with cities only, somebody was offered in a capital: " .. out) end
		if not out:find(named("Tess", "Target"), 1, true) then
			fail(scenario, "the target was dropped in a capital: " .. out)
		end
	end)
end

do
	local scenario = "townhold: inns only, a capital offers as ever"
	with(scenario, { where = "inns" }, function(ns, state)
		state.map = state.city
		local ok, out = both(ns)
		if not ok then fail(scenario, "with inns only, somebody was held back in a capital: " .. out) end
	end)
end

do
	local scenario = "townhold: inns only, an inn offers nothing"
	with(scenario, { where = "inns" }, function(ns, state)
		state.map = state.inn
		local ok, out = neither(ns)
		if not ok then fail(scenario, "with inns only, somebody was offered at an inn: " .. out) end
	end)
end

do
	local scenario = "townhold: a part of a capital is the capital"
	with(scenario, { where = "cities" }, function(ns, state)
		state.map = PART
		local ok, out = neither(ns)
		if not ok then fail(scenario, "on a map inside a capital, somebody was offered: " .. out) end
		state.map = PART + 1
		ok, out = both(ns)
		if not ok then fail(scenario, "on a map with no capital above it, somebody was held back: " .. out) end
	end)
end

do
	local scenario = "townhold: out in the world, Where changes nothing"
	with(scenario, { where = "cities" }, function(ns, state)
		state.resting = false
		state.map = state.city
		local ok, out = both(ns)
		if not ok then fail(scenario, "not resting, on a capital's map, somebody was held back: " .. out) end
		ns.db.profile.filters.quietInTownsWhere = "inns"
		state.map = state.inn
		ok, out = both(ns)
		if not ok then fail(scenario, "not resting, inns only, somebody was held back: " .. out) end
	end)
end

do
	local scenario = "townhold: with the switch off, Where holds nothing back"
	with(scenario, { on = false, where = "cities" }, function(ns, state)
		state.map = state.city
		local ok, out = both(ns)
		if not ok then fail(scenario, "with the switch off, somebody was held back in a capital: " .. out) end
	end)
end

do
	local scenario = "townhold: a map the client will not name holds back both"
	with(scenario, { where = "cities" }, function(ns, state)
		for label, fn in pairs({
			none = function() return nil end,
			secret = function() return Mock.SECRET end,
			throws = function() error("refused", 0) end,
			text = function() return "Stormwind" end,
		}) do
			for _, where in ipairs({ "cities", "inns" }) do
				ns.db.profile.filters.quietInTownsWhere = where
				state.map = fn
				local ok, out = neither(ns)
				if not ok then
					fail(scenario, ("%s, %s only: somebody was offered while resting: %s"):format(label, where, out))
				end
			end
		end
		rawset(_G, "C_Map", nil)
		for _, where in ipairs({ "cities", "inns" }) do
			ns.db.profile.filters.quietInTownsWhere = where
			local ok, out = neither(ns)
			if not ok then fail(scenario, ("no C_Map, %s only: somebody was offered: %s"):format(where, out)) end
		end
	end)
end

-- Each client's capitals, as its own UiMap table numbers them (Range.lua).
do
	local scenario = "townhold: each client's capitals are cities"
	local CASES = {
		camelot = { yes = { 1453, 1454, 1455, 1456, 1457, 1458 }, no = { 1429, 84, 1955 } },
		vanilla = { yes = { 1453, 1454, 1455, 1456, 1457, 1458 }, no = { 1429, 1955 } },
		tbc = { yes = { 1453, 1458, 1947, 1954, 1955 }, no = { 1429, 84 } },
		mists = { yes = { 84, 85, 86, 87, 88, 89, 998, 103, 110, 111, 125, 126, 391, 393 }, no = { 37, 1453, 2339 } },
		mainline = { yes = { 84, 90, 998, 111, 627, 391, 394, 622, 624, 1161, 1165, 1670, 2112, 2339, 2393 },
			no = { 37, 594, 501, 41, 1453 } },
	}
	for _, flavour in ipairs({ "camelot", "vanilla", "tbc", "mists", "mainline" }) do
		local case = CASES[flavour]
		with(scenario .. " (" .. flavour .. ")", { flavour = flavour }, function(ns, state)
			if ns.Flavour.flavour ~= flavour then
				fail(scenario, "SKIPPED -- the client is " .. tostring(ns.Flavour.flavour) .. ", not " .. flavour)
				return
			end
			for _, id in ipairs(case.yes) do
				state.map = id
				if ns.InCity() ~= true then fail(scenario, ("%s: map %d is not read as a capital"):format(flavour, id)) end
			end
			for _, id in ipairs(case.no) do
				state.map = id
				if ns.InCity() ~= false then fail(scenario, ("%s: map %d is read as a capital"):format(flavour, id)) end
			end
		end)
	end
end

do
	local scenario = "townhold: When to offer has the choice under the switch, greyed while it is off"
	with(scenario, { on = false }, function(ns)
		local control = findOption(ns.optionsTable, "quietInTownsWhere")
		if not control then fail(scenario, "there is no choice of where") return end
		if control.type ~= "select" then fail(scenario, "the choice is a " .. tostring(control.type)) end
		local values = type(control.values) == "function" and control.values() or control.values or {}
		for _, key in ipairs({ "both", "cities", "inns" }) do
			if not values[key] then fail(scenario, "the choice has no " .. key) end
		end
		local sorting = type(control.sorting) == "function" and control.sorting() or control.sorting or {}
		if table.concat(sorting, ",") ~= "both,cities,inns" then
			fail(scenario, "the choices are in the order " .. table.concat(sorting, ","))
		end
		local info = { "who", "quietInTownsWhere" }
		if control.get(info) ~= "both" then fail(scenario, "a new profile reads " .. tostring(control.get(info))) end
		if not (type(control.disabled) == "function" and control.disabled(info)) then
			fail(scenario, "the choice is live with Offer nothing in cities and inns off")
		end
		ns.db.profile.filters.quietInTowns = true
		if type(control.disabled) == "function" and control.disabled(info) then
			fail(scenario, "the choice is greyed with Offer nothing in cities and inns on")
		end
		control.set(info, "inns")
		if ns.db.profile.filters.quietInTownsWhere ~= "inns" or control.get(info) ~= "inns" then
			fail(scenario, "picking inns only was not kept")
		end
		-- A damaged value is put back to both; a good one is kept.
		ns.db.profile.filters.quietInTownsWhere = "harbours"
		ns.ClampSettings()
		if ns.db.profile.filters.quietInTownsWhere ~= "both" then
			fail(scenario, "a damaged value was kept: " .. tostring(ns.db.profile.filters.quietInTownsWhere))
		end
		ns.db.profile.filters.quietInTownsWhere = "cities"
		ns.ClampSettings()
		if ns.db.profile.filters.quietInTownsWhere ~= "cities" then
			fail(scenario, "the repair undid cities only")
		end
		-- Placed right under the switch, indented, on When to offer.
		local found
		for _, section in ipairs(ns.WindowLayout.pages.when.sections) do
			for i, item in ipairs(section.items) do
				if item == "who.quietInTowns" then
					local nextItem = section.items[i + 1]
					found = type(nextItem) == "table" and nextItem[1] == "who.quietInTownsWhere" and nextItem.indent == true
				end
			end
		end
		if not found then fail(scenario, "the choice is not indented right under the switch on When to offer") end
	end)
end

do
	local scenario = "townhold: the full check-up says where, and the map"
	with(scenario, { where = "cities" }, function(ns, state)
		state.map = state.city
		local text = ns.FullReport()
		if not text:find("quietInTowns=true where=cities", 1, true) then
			fail(scenario, "the check-up does not say where the switch holds")
		end
		if not text:find(("map: %d, a capital: true"):format(state.city), 1, true) then
			fail(scenario, "the check-up does not say the map and that it is a capital")
		end
	end)
end
