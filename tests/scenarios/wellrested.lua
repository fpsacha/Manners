-- Well-Rested (1.11.10): a player asked for a checkbox under Myself for the
-- sleeping bag's buff. A family of its own (Buffs.lua, REST) for every class on
-- Classic Era and Forever, the two clients with the Cozy Sleeping Bag (item
-- 211527): its use lays the bag down, and resting in it gives Well-Rested
-- (429959). Off until it is switched on and shown while the bag is in the bags;
-- offered when no Well-Rested is on you, read by its id; never at the level cap,
-- while you lie in the bag (its tracking aura, 429960), while its use cools
-- down, or mounted.
--
-- Every scenario name starts with "wellrested:" so the mutations in
-- tests/mutations/wellrested.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, findOption = H.strangers, H.freshPrompt, H.findOption

local BAG, RESTED, IN_BAG = 211527, 429959, 429960

local function key(entry) return tostring(entry and entry.buff and entry.buff.key) end
local function macro(ns) return ns.Prompt:GetButton():GetAttribute("macrotext1") end

local function mine(ns)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.reason == "self" then return entry end
	end
	return nil
end

-- The world a scenario stands in: bags (item -> count), the player's auras by
-- id (id -> expiry), his level, whether he is mounted, the bag's cooldown, and
-- which items were counted.
local world
local TOUCHED = { "C_Item", "C_UnitAuras", "C_Container", "UnitLevel", "GetMaxPlayerLevel", "IsMounted",
	"IsSpellKnown", "IsPlayerSpell", "IsResting" }

local function install()
	rawset(_G, "C_Item", {
		GetItemCount = function(id)
			world.counted[id] = (world.counted[id] or 0) + 1
			return world.bags[id] or 0
		end,
		GetItemNameByID = function(id) return "Item " .. id end,
		RequestLoadItemDataByID = function() end,
		GetItemIconByID = function(id) return 7100000 + id end,
		GetItemInfoInstant = function(id) return id, "Miscellaneous", "", "", 7100000 + id, 15, 0 end,
	})
	rawset(_G, "UnitLevel", function(unit)
		if unit == "player" then return world.level end
		return 12
	end)
	rawset(_G, "GetMaxPlayerLevel", function() return 60 end)
	rawset(_G, "IsMounted", function() return world.mounted end)
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
			if world.refuse and id == RESTED then return Mock.SECRET end
			local expires = world.auras[id]
			if expires == nil then return nil end
			return { spellId = id, name = "Aura " .. id, expirationTime = expires, duration = 7200, sourceUnit = "player" }
		end,
	}, { __index = base }))
end

-- One session as a warrior on `opts.flavour` (Forever), with opts.bags,
-- opts.level (30), opts.on (the switch).
local function with(scenario, opts, body)
	Mock.reset()
	Mock.setFlavour(opts.flavour or "camelot")
	Mock.class = opts.class or "WARRIOR"
	world = { bags = opts.bags or {}, level = opts.level or 30, auras = {}, counted = {}, mounted = false,
		refuse = false, cooldownUntil = nil }
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local undo = strangers({})
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		install()
		rawset(_G, "IsSpellKnown", function() return false end)
		rawset(_G, "IsPlayerSpell", function() return false end)
		Mock.playerHeld = {}
		freshPrompt(ns, scenario)
		Mock.playerHeld = {}
		if opts.on then
			ns.db.profile.ownBuffs.pick.rested = "auto"
			ns.ForgetScrolls()
		end
		body(ns)
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

local function lines(ns) return table.concat(ns.MyselfLines(GetTime()), " / ") end

-- ------------------------------------------------------------------ the data

do
	local scenario = "wellrested: Forever and Classic Era give every class the family, the others none"
	for _, client in ipairs({ "camelot", "vanilla", "tbc", "mists", "mainline" }) do
		Mock.reset()
		Mock.setFlavour(client)
		local ns = load(scenario)
		if ns then
			local has, total = 0, 0
			for class, families in pairs(ns.OWN_BUFFS or {}) do
				total = total + 1
				for _, family in ipairs(families) do
					if family.rest then
						has = has + 1
						local spell = family.spells[1]
						if family.key ~= "rested" or family.toggle ~= true or family.bagged ~= true
							or family.fed ~= RESTED or family.resting ~= IN_BAG or #family.spells ~= 1
							or spell.item ~= BAG or spell.ranks[1] ~= 429961 then
							fail(scenario, client .. " " .. class .. ": the family is not the sleeping bag's toggle")
						end
					end
				end
			end
			local want = (client == "camelot" or client == "vanilla") and total or 0
			if has ~= want or total == 0 then
				fail(scenario, ("%s: %d of %d classes have the Well-Rested family, not %d"):format(client, has, total, want))
			end
		end
		Mock.reset()
	end
end

-- ------------------------------------------------------------------ the switch

do
	local scenario = "wellrested: off by default, the bags unread, and a switch shown with the bag"
	with(scenario, {}, function(ns)
		if ns.db.profile.ownBuffs.pick.rested ~= "off" then
			fail(scenario, "Well-Rested is " .. tostring(ns.db.profile.ownBuffs.pick.rested) .. " on a new profile, not off")
		end
		stock(ns, { [BAG] = 1 })
		if mine(ns) then fail(scenario, "the bag in the bags, the switch off: offered " .. key(mine(ns))) end
		if world.counted[BAG] then fail(scenario, "the bags were counted for the sleeping bag with the switch off") end
		local control = findOption(ns.optionsTable, "own_rested")
		if not control then
			fail(scenario, "Who to buff has no Well-Rested switch for a warrior")
			return
		end
		if control.type ~= "toggle" then fail(scenario, "the switch is a " .. tostring(control.type)) end
		if control.hidden and control.hidden() then fail(scenario, "the switch is hidden with the bag in the bags") end
		world.bags = {}
		if not (control.hidden and control.hidden()) then fail(scenario, "the switch is shown with no bag and it off") end
		world.bags = { [BAG] = 1 }
		if control.get() ~= false then fail(scenario, "the switch reads on with the profile off") end
		control.set({ "own_rested" }, true)
		if ns.db.profile.ownBuffs.pick.rested ~= "auto" or control.get() ~= true then
			fail(scenario, "switching it on wrote " .. tostring(ns.db.profile.ownBuffs.pick.rested))
		end
		-- Once on, shown whatever the bags hold, so it can be switched off.
		world.bags = {}
		if control.hidden and control.hidden() then fail(scenario, "switched on, the switch hides when the bag is gone") end
		world.bags = { [BAG] = 1 }
		if not mine(ns) then fail(scenario, "switched on, with the bag in the bags: nothing offered") end
		control.set({ "own_rested" }, false)
		if ns.db.profile.ownBuffs.pick.rested ~= "off" then
			fail(scenario, "switching it off wrote " .. tostring(ns.db.profile.ownBuffs.pick.rested))
		end
	end)
end

-- ------------------------------------------------------------------ the offer

do
	local scenario = "wellrested: the bag in the bags and no Well-Rested is offered, used by its item"
	with(scenario, { on = true, bags = { [BAG] = 1 } }, function(ns)
		local entry = mine(ns)
		if not entry then
			fail(scenario, "the bag in the bags, no Well-Rested, the switch on: nothing offered")
			return
		end
		if key(entry) ~= "rested" .. BAG then fail(scenario, "offered " .. key(entry) .. ", not rested" .. BAG) end
		ns.Prompt:Refresh()
		if macro(ns) ~= "/use item:" .. BAG then
			fail(scenario, "the macro is " .. tostring(macro(ns)) .. ", not /use item:" .. BAG)
		end
		local name = ns.BuffName(entry.buff)
		if name ~= "Item " .. BAG then fail(scenario, "the bag is named " .. tostring(name)) end
	end)
end

do
	local scenario = "wellrested: Well-Rested up, or no bag, is not offered"
	with(scenario, { on = true }, function(ns)
		if mine(ns) then fail(scenario, "no bag in the bags, and offered " .. key(mine(ns))) end
		stock(ns, { [BAG] = 1 })
		if not mine(ns) then
			fail(scenario, "SKIPPED -- the bag was not offered to begin with")
			return
		end
		world.auras[RESTED] = GetTime() + 7000
		ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
		Mock.advance(1)
		if mine(ns) then fail(scenario, "Well-Rested on you, and still offered " .. key(mine(ns))) end
		world.auras[RESTED] = nil
		Mock.advance(1)
		if not mine(ns) then fail(scenario, "Well-Rested gone, and the bag is not offered again") end
		world.refuse = true
		Mock.advance(1)
		if mine(ns) then fail(scenario, "the aura read refused, and offered " .. key(mine(ns))) end
		if not lines(ns):find("will not say whether it is up", 1, true) then
			fail(scenario, "a refused aura read is not said to be unread: " .. lines(ns))
		end
	end)
end

do
	local scenario = "wellrested: not at the level cap, in the bag, while it cools down, nor mounted"
	with(scenario, { on = true, bags = { [BAG] = 1 } }, function(ns)
		if not mine(ns) then
			fail(scenario, "SKIPPED -- the bag was not offered to begin with")
			return
		end
		world.level = 60
		Mock.advance(1)
		if mine(ns) then fail(scenario, "at the level cap, and offered " .. key(mine(ns))) end
		if not lines(ns):find("level cap", 1, true) then
			fail(scenario, "the debug lines do not say the level cap holds it: " .. lines(ns))
		end
		world.level = 59
		Mock.advance(1)
		if not mine(ns) then fail(scenario, "a level short of the cap, and nothing offered") end
		-- Lying in the bag: its tracking aura, the minute before Well-Rested comes.
		world.auras[IN_BAG] = GetTime() + 600
		Mock.advance(1)
		if mine(ns) then fail(scenario, "lying in the bag, and offered " .. key(mine(ns))) end
		if not lines(ns):find("resting in the bag", 1, true) then
			fail(scenario, "the debug lines do not say you are in the bag: " .. lines(ns))
		end
		world.auras[IN_BAG] = nil
		Mock.advance(1)
		if not mine(ns) then fail(scenario, "out of the bag, and nothing offered") end
		-- The bag laid down and walked away from: its use cools down an hour.
		world.cooldownUntil = GetTime() + 3000
		Mock.advance(1)
		if mine(ns) then fail(scenario, "the bag cooling down, and offered " .. key(mine(ns))) end
		world.cooldownUntil = nil
		Mock.advance(1)
		if not mine(ns) then fail(scenario, "the cooldown over, and nothing offered") end
		world.mounted = true
		Mock.advance(1)
		if mine(ns) then fail(scenario, "mounted, and offered the bag: " .. key(mine(ns))) end
		-- Manners holds it back, not the game: the debug line says so (r35).
		if not lines(ns):find("waits until you dismount", 1, true) then
			fail(scenario, "mounted, /manners debug does not say the bag waits for you to dismount: " .. lines(ns))
		end
		world.mounted = false
		Mock.advance(1)
		if not mine(ns) then fail(scenario, "dismounted, and nothing offered") end
	end)
end

do
	local scenario = "wellrested: Classic Era offers it too"
	with(scenario, { flavour = "vanilla", on = true, bags = { [BAG] = 1 } }, function(ns)
		if key(mine(ns)) ~= "rested" .. BAG then fail(scenario, "offered " .. key(mine(ns)) .. ", not the bag") end
	end)
end

do
	local scenario = "wellrested: no Well-Rested switch where there is no bag"
	for _, client in ipairs({ "tbc", "mists", "mainline" }) do
		with(scenario, { flavour = client }, function(ns)
			if ns.optionsTable.args.who.args.own_rested then fail(scenario, client .. " has a Well-Rested switch") end
		end)
	end
end
