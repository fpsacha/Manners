-- Well Fed (1.11.2): a player asked for a reminder to eat, as one is given to
-- put on a sharpening stone. A family of its own (Buffs.lua, FOOD) for every
-- class on the four clients with a table of it (Foods.lua, written by
-- tools/make_foods.py from each client's own data): the food in your bags that
-- gives the aura, offered when no Well Fed is on you, the best one first. Off
-- until it is switched on, since it reads every food in the bags; never while a
-- meal is on, while mounted or in a fight; the aura is read by its localised
-- name, as any of the many on a client answers to it.
--
-- Every scenario name starts with "wellfed:" so the mutations in
-- tests/mutations/wellfed.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, findOption = H.strangers, H.freshPrompt, H.findOption

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

-- ------------------------------------------------------------------ the data

do
	local scenario = "wellfed: every client's table of food is whole and in order"
	with(scenario, {}, function(ns)
		local floor = { camelot = 80, vanilla = 40, tbc = 60, mists = 150 }
		for client, minimum in pairs(floor) do
			local data = ns.FOODS[client]
			if type(data) ~= "table" or #data < minimum then
				fail(scenario, ("%s has %s foods, fewer than the %d its data gives"):format(client,
					tostring(data and #data), minimum))
			else
				if type(data.fed) ~= "number" then fail(scenario, client .. " names no Well Fed spell") end
				local seen, last = {}, nil
				for i, row in ipairs(data) do
					local item, level, use = row[1], row[2], row[3]
					if type(item) ~= "number" or type(level) ~= "number" or type(use) ~= "number" then
						fail(scenario, ("%s row %d is not { item, level, spell }"):format(client, i))
						break
					end
					if seen[item] then fail(scenario, ("%s lists item %d twice"):format(client, item)) end
					seen[item] = true
					-- Best first: the highest level, then the lowest item id.
					if last and (level > last[2] or (level == last[2] and item < last[1])) then
						fail(scenario, ("%s row %d (%d, level %d) is out of order after %d, level %d"):format(
							client, i, item, level, last[1], last[2]))
						break
					end
					last = row
				end
			end
		end
		if ns.FOODS.mainline then fail(scenario, "retail has a table of food, which it has no way to read") end
	end)
end

do
	local scenario = "wellfed: every class on a client with the table has the family, retail has none"
	for _, client in ipairs({ "camelot", "vanilla", "tbc", "mists", "mainline" }) do
		Mock.reset()
		Mock.setFlavour(client)
		local ns = load(scenario)
		if ns then
			local has, total = 0, 0
			for class, families in pairs(ns.OWN_BUFFS or {}) do
				total = total + 1
				for _, family in ipairs(families) do
					if family.food then
						has = has + 1
						if family.key ~= "food" or family.toggle ~= true or type(family.fed) ~= "number" then
							fail(scenario, client .. " " .. class .. ": the family is not a toggle named food with its aura")
						end
					end
				end
			end
			if client == "mainline" then
				if has ~= 0 then fail(scenario, "retail's classes have a food family") end
			elseif has ~= total or total == 0 then
				fail(scenario, ("%s: %d of %d classes have the food family"):format(client, has, total))
			end
			for class, families in pairs(ns.OWN_BUFFS or {}) do
				for _, family in ipairs(families) do
					if family.food and #family.spells < 40 then
						fail(scenario, client .. " " .. class .. ": the family lists " .. #family.spells .. " foods")
					end
				end
			end
		end
		Mock.reset()
	end
end

-- ------------------------------------------------------------------ the switch

do
	local scenario = "wellfed: off by default, the bags unread, and a switch on Who to buff"
	with(scenario, {}, function(ns, data)
		if ns.db.profile.ownBuffs.pick.food ~= "off" then
			fail(scenario, "Well Fed is " .. tostring(ns.db.profile.ownBuffs.pick.food) .. " on a new profile, not off")
		end
		stock(ns, { [data[1][1]] = 1 })
		if mine(ns) then fail(scenario, "food in the bags and no Well Fed, with the switch off: offered " .. key(mine(ns))) end
		mine(ns)
		for _, row in ipairs(data) do
			if world.counted[row[1]] then
				fail(scenario, "the bags were counted for food " .. row[1] .. " with the switch off")
				break
			end
		end
		local control = findOption(ns.optionsTable, "own_food")
		if not control then
			fail(scenario, "Who to buff has no Well Fed switch for a warrior")
			return
		end
		if control.type ~= "toggle" then fail(scenario, "the switch is a " .. tostring(control.type)) end
		if control.hidden and control.hidden() then fail(scenario, "the switch is hidden with no food in the bags") end
		if control.get() ~= false then fail(scenario, "the switch reads on with the profile off") end
		control.set({ "own_food" }, true)
		if ns.db.profile.ownBuffs.pick.food ~= "auto" or control.get() ~= true then
			fail(scenario, "switching it on wrote " .. tostring(ns.db.profile.ownBuffs.pick.food))
		end
		-- The bags are asked once it is on, with no event to say they changed.
		if not mine(ns) then fail(scenario, "switched on, with food in the bags: nothing offered") end
		control.set({ "own_food" }, false)
		if ns.db.profile.ownBuffs.pick.food ~= "off" then fail(scenario, "switching it off wrote " .. tostring(ns.db.profile.ownBuffs.pick.food)) end
	end)
end

do
	local scenario = "wellfed: Myself is a warrior's too, for this switch"
	with(scenario, {}, function(ns)
		local a = ns.optionsTable.args.who.args
		for _, k in ipairs({ "myselfHeader", "self", "ownCities", "own_food" }) do
			local hidden = a[k] and type(a[k].hidden) == "function" and a[k].hidden() == true
			if a[k] == nil or hidden then fail(scenario, k .. " is hidden from a warrior") end
		end
	end)
	-- Retail has no food, so a warrior there still has nothing under Myself.
	local scenario2 = "wellfed: a warrior on retail has no switch and no Myself"
	with(scenario2, { flavour = "mainline" }, function(ns)
		local a = ns.optionsTable.args.who.args
		if a.own_food then fail(scenario2, "retail has a Well Fed switch") end
		-- Hidden, all three, from a class with nothing under them: the one place
		-- left where that is so (the checks on Forever are about the opposite).
		for _, k in ipairs({ "myselfHeader", "self", "ownCities" }) do
			local hidden = a[k] and type(a[k].hidden) == "function" and a[k].hidden() == true
			if not hidden then fail(scenario2, k .. " is shown to a warrior on retail, with nothing under it") end
		end
	end)
end

-- ------------------------------------------------------------------ the offer

do
	local scenario = "wellfed: food in the bags and no Well Fed is offered, used by its item"
	with(scenario, { on = true }, function(ns, data)
		local best = data[1]
		stock(ns, { [best[1]] = 3 })
		local entry = mine(ns)
		if not entry then
			fail(scenario, "food in the bags, no Well Fed, the switch on: nothing offered")
			return
		end
		if key(entry) ~= "food" .. best[1] then
			fail(scenario, "offered " .. key(entry) .. ", not food" .. best[1])
		end
		ns.Prompt:Refresh()
		if macro(ns) ~= "/use item:" .. best[1] then
			fail(scenario, "the macro is " .. tostring(macro(ns)) .. ", not /use item:" .. best[1])
		end
		-- Named by its item, not by the spell its use casts.
		local name = ns.BuffName(entry.buff)
		if name ~= "Food " .. best[1] then fail(scenario, "the food is named " .. tostring(name)) end
	end)
end

do
	local scenario = "wellfed: Well Fed up, or nothing in the bags, is not offered"
	with(scenario, { on = true }, function(ns, data)
		local best = data[1]
		if mine(ns) then fail(scenario, "nothing in the bags, and offered " .. key(mine(ns))) end
		stock(ns, { [best[1]] = 1 })
		if not mine(ns) then
			fail(scenario, "SKIPPED -- food in the bags was not offered to begin with")
			return
		end
		world.auras[FED_NAME] = GetTime() + 1500
		ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
		Mock.advance(1)
		if mine(ns) then fail(scenario, "Well Fed on you, and still offered " .. key(mine(ns))) end
		world.auras[FED_NAME] = nil
		Mock.advance(1)
		if not mine(ns) then fail(scenario, "Well Fed gone, and the food is not offered again") end
		-- A client that will not say is no reason to offer.
		world.refuse = true
		Mock.advance(1)
		if mine(ns) then fail(scenario, "the aura read refused, and offered " .. key(mine(ns))) end
		-- Not "up" either: the debug lines say the client would not say.
		local lines = table.concat(ns.MyselfLines(GetTime()), " / ")
		if not lines:find("will not say whether it is up", 1, true) then
			fail(scenario, "a refused aura read is not said to be unread: " .. lines)
		end
	end)
end

do
	local scenario = "wellfed: the best food you can use is the one offered"
	with(scenario, { on = true, level = 60 }, function(ns, data)
		local best, worst = data[1], data[#data]
		if best[2] <= worst[2] then
			fail(scenario, "SKIPPED -- the table's best and worst are the same level")
			return
		end
		stock(ns, { [best[1]] = 1, [worst[1]] = 1 })
		if key(mine(ns)) ~= "food" .. best[1] then
			fail(scenario, "with both in the bags, offered " .. key(mine(ns)) .. ", not the best, food" .. best[1])
		end
		-- Not what your level is short of: the next in the bags.
		world.level = best[2] - 1
		Mock.advance(1)
		if key(mine(ns)) ~= "food" .. worst[1] then
			fail(scenario, ("at level %d, below the best food's %d, offered %s, not food%d"):format(
				world.level, best[2], key(mine(ns)), worst[1]))
		end
		stock(ns, { [best[1]] = 1 })
		if mine(ns) then fail(scenario, "only a food above your level, and offered " .. key(mine(ns))) end
	end)
end

do
	local scenario = "wellfed: not while a meal is on, nor mounted"
	with(scenario, { on = true }, function(ns, data)
		local best = data[1]
		stock(ns, { [best[1]] = 2 })
		if not mine(ns) then
			fail(scenario, "SKIPPED -- food was not offered to begin with")
			return
		end
		-- Eating one: its use spell's aura, by name. A second press with another
		-- food would cut the meal short.
		world.auras[MEAL_NAME] = GetTime() + 18
		Mock.advance(1)
		if mine(ns) then fail(scenario, "a meal is on, and another food is offered: " .. key(mine(ns))) end
		world.auras[MEAL_NAME] = nil
		Mock.advance(1)
		if not mine(ns) then fail(scenario, "the meal is over, Well Fed is not on, and nothing is offered") end
		world.mounted = true
		Mock.advance(1)
		if mine(ns) then fail(scenario, "mounted, and offered food: " .. key(mine(ns))) end
		world.mounted = false
		Mock.advance(1)
		if not mine(ns) then fail(scenario, "dismounted, and nothing is offered") end
	end)
end

do
	local scenario = "wellfed: /manners debug says why food is not offered"
	with(scenario, { on = true }, function(ns, data)
		local best = data[1]
		stock(ns, { [best[1]] = 1 })
		world.mounted = true
		Mock.advance(1)
		local said_ = table.concat(ns.MyselfLines(GetTime()), " / ")
		if not said_:find("Well Fed", 1, true) then
			fail(scenario, "a mounted player's debug lines do not name Well Fed: " .. said_)
		end
	end)
end

-- ------------------------------------------------------------------ the other clients

for _, client in ipairs({ "vanilla", "tbc", "mists" }) do
	local scenario = "wellfed: " .. client .. " offers its own table's food"
	-- Past every level its best food asks.
	with(scenario, { flavour = client, on = true, level = 100 }, function(ns, data)
		local best = data[1]
		stock(ns, { [best[1]] = 1 })
		local entry = mine(ns)
		if not entry or key(entry) ~= "food" .. best[1] then
			fail(scenario, client .. ": offered " .. key(entry) .. ", not food" .. best[1])
		end
	end)
end
