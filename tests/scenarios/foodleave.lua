-- Foods left out (1.11.14): a Warlock on GitHub (issue 11) keeps a fishing
-- food in his bags for when he fishes, and Automatic offered that one, the
-- first of its level, over his ordinary food, with no way to pass it by. Food
-- is now the one family from the bags that can be ticked under "Never remind
-- me about": Automatic skips a food ticked there and takes the next it can use.
--
-- Every scenario name starts with "foodleave:" so the mutations in
-- tests/mutations/foodleave.py can name the one that has to catch them.

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

-- Two foods of the same level that both fit a level 60: the first one is what
-- Automatic takes, and `second` is what it takes once the first is left out.
local function pair(data, level)
	local first
	for _, row in ipairs(data) do
		if row[2] <= level then
			if not first then
				first = row
			elseif row[1] ~= first[1] then
				return first, row
			end
		end
	end
end

do
	local scenario = "foodleave: a food ticked under Never remind me about is passed over"
	with(scenario, { on = true, level = 60 }, function(ns, data)
		local first, second = pair(data, 60)
		stock(ns, { [first[1]] = 1, [second[1]] = 1 })
		if key(mine(ns)) ~= "food" .. first[1] then
			fail(scenario, "with nothing ticked, offered " .. key(mine(ns)) .. ", not food" .. first[1])
			return
		end
		ns.db.profile.ownBuffs.leave["food" .. first[1]] = true
		Mock.advance(1)
		local entry = mine(ns)
		if key(entry) ~= "food" .. second[1] then
			fail(scenario, "the first food ticked, offered " .. key(entry) .. ", not food" .. second[1])
		end
		ns.Prompt:Refresh()
		if macro(ns) ~= "/use item:" .. second[1] then
			fail(scenario, "the macro is " .. tostring(macro(ns)) .. ", not /use item:" .. second[1])
		end
	end)
end

do
	local scenario = "foodleave: with every food in the bags ticked nothing is offered"
	with(scenario, { on = true, level = 60 }, function(ns, data)
		local first, second = pair(data, 60)
		stock(ns, { [first[1]] = 1, [second[1]] = 1 })
		ns.db.profile.ownBuffs.leave["food" .. first[1]] = true
		ns.db.profile.ownBuffs.leave["food" .. second[1]] = true
		Mock.advance(1)
		if mine(ns) then fail(scenario, "every food in the bags is ticked, and offered " .. key(mine(ns))) end
		if ns.OwnReminds(ns.FindOwnFamily("food")) then
			fail(scenario, "the family still says it reminds, with every food in the bags ticked")
		end
	end)
end

do
	local scenario = "foodleave: unticking brings the food back"
	with(scenario, { on = true, level = 60 }, function(ns, data)
		local first, second = pair(data, 60)
		stock(ns, { [first[1]] = 1, [second[1]] = 1 })
		ns.db.profile.ownBuffs.leave["food" .. first[1]] = true
		Mock.advance(1)
		ns.db.profile.ownBuffs.leave["food" .. first[1]] = false
		Mock.advance(1)
		if key(mine(ns)) ~= "food" .. first[1] then
			fail(scenario, "unticked, offered " .. key(mine(ns)) .. ", not food" .. first[1])
		end
	end)
end

do
	local scenario = "foodleave: every food has a tick, false by default"
	with(scenario, { on = true }, function(ns, data)
		local leave = ns.db.profile.ownBuffs.leave
		for _, row in ipairs(data) do
			if leave["food" .. row[1]] ~= false then
				fail(scenario, ("food%d is %s by default, not false"):format(row[1], tostring(leave["food" .. row[1]])))
				return
			end
		end
	end)
end

do
	local scenario = "foodleave: Never remind me about lists the foods in the bags, by name"
	with(scenario, { on = true, level = 60 }, function(ns, data)
		local first, second = pair(data, 60)
		local box = ns.optionsTable.args.who.args.own_leave
		if not box then fail(scenario, "Who to buff has no Never remind me about") return end
		if next(box.values()) ~= nil then fail(scenario, "foods nobody holds are listed") end
		stock(ns, { [first[1]] = 1 })
		local values = box.values()
		if values["food" .. first[1]] ~= "Food " .. first[1] then
			fail(scenario, "the food in the bags is listed as " .. tostring(values["food" .. first[1]]))
		end
		if values["food" .. second[1]] then fail(scenario, "a food not in the bags is listed") end
	end)
end

do
	local scenario = "foodleave: a scroll is still not something that can be ticked"
	with(scenario, { on = true, class = "MAGE" }, function(ns)
		local items = 0
		for class, families in pairs(ns.OWN_BUFFS or {}) do
			for _, family in ipairs(families) do
				if (family.bagged or family.scroll or family.enhance) and not family.food then
					items = items + 1
					if ns.OwnLeaveable(family) then fail(scenario, class .. "'s " .. family.key .. " can be ticked") end
				end
			end
		end
		if items == 0 then fail(scenario, "SKIPPED -- no family from the bags to look at") end
		if not ns.OwnLeaveable(ns.FindOwnFamily("food")) then fail(scenario, "food cannot be ticked") end
	end)
end
