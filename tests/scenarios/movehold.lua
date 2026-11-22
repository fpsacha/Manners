-- The hold on the move is the player's call (GitHub issue 31). Food, a weapon's
-- stone, oil or poison and any use with a cast wait until you stand still
-- (Core.lua, CutByMoving); My own buffs > Hold my food, stones and oils while I
-- move (ownBuffs.holdMoving, on) turns it off, and then they stay on the prompt
-- on the run, the consumables button's press included.
--
-- Every scenario name starts with "movehold: " so tests/mutations/movehold.py
-- can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, findOption = H.strangers, H.freshPrompt, H.findOption

local FED_NAME, MEAL_NAME = "Well Fed", "Nutritious Food"


local function key(entry) return tostring(entry and entry.buff and entry.buff.key) end
local function macro(ns) return ns.Prompt:GetButton():GetAttribute("macrotext1") end
local function lines(ns) return table.concat(ns.MyselfLines(GetTime()), " / ") end

local function mine(ns)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.reason == "self" then return entry end
	end
	return nil
end

-- The world a scenario stands in: bags (item -> count), the player's auras by
-- name, his level, his speed (a number, or Mock.SECRET), whether he falls,
-- and the cast time the client gives every spell (nil: the mock's own).
local world
local TOUCHED = { "C_Item", "C_Spell", "C_UnitAuras", "UnitLevel", "IsMounted", "IsSpellKnown", "IsPlayerSpell",
	"IsResting", "GetUnitSpeed", "IsFalling", "GetInventoryItemID", "StaticPopup_Hide" }

-- Weapons by made-up item id, as hunt33-weapons.lua has them.
local DAGGER = 900015
local ROUGH_STONE = 2862

local function install(ns)
	rawset(_G, "C_Spell", nil)
	local spells = C_Spell
	rawset(_G, "C_Spell", setmetatable({
		GetSpellName = function(id)
			if id == world.fed then return FED_NAME end
			if world.meals[id] then return MEAL_NAME end
			return spells.GetSpellName(id)
		end,
		GetSpellInfo = function(id)
			if world.castTime ~= nil then return { name = "x", castTime = world.castTime } end
			return spells.GetSpellInfo(id)
		end,
	}, { __index = spells }))
	rawset(_G, "C_Item", {
		GetItemCount = function(id) return world.bags[id] or 0 end,
		GetItemNameByID = function(id) return "Food " .. id end,
		RequestLoadItemDataByID = function() end,
		GetItemIconByID = function(id) return 7100000 + id end,
		GetItemInfoInstant = function(id)
			if id == DAGGER then return id, "Weapon", "", "INVTYPE_WEAPON", 7100000 + id, 2, 15 end
			return id, "Consumable", "", "", 7100000 + id, 0, 5
		end,
	})
	rawset(_G, "GetInventoryItemID", function(unit, slot)
		if unit == "player" and slot == 16 then return DAGGER end
		return nil
	end)
	rawset(_G, "StaticPopup_Hide", function() end)
	rawset(_G, "UnitLevel", function(unit)
		if unit == "player" then return world.level end
		return 12
	end)
	rawset(_G, "IsMounted", function() return false end)
	rawset(_G, "IsResting", function() return false end)
	rawset(_G, "GetUnitSpeed", function() return world.speed end)
	rawset(_G, "IsFalling", function() return world.falling end)
	rawset(_G, "C_UnitAuras", nil)
	local base = C_UnitAuras
	rawset(_G, "C_UnitAuras", setmetatable({
		GetAuraDataBySpellName = function(unit, name)
			if unit ~= "player" then return nil end
			local expires = world.auras[name]
			if expires == nil then return nil end
			return { name = name, expirationTime = expires, sourceUnit = "player" }
		end,
		GetUnitAuraBySpellID = function() return nil end,
	}, { __index = base }))
end

-- One session as `opts.class` (a warrior) on `opts.flavour` (Forever), standing
-- still, with opts.bags and opts.on (food switched on). The moving state of
-- another scenario is let go of, and so is every cast time this one caches.
local function with(scenario, opts, body)
	Mock.reset()
	Mock.setFlavour(opts.flavour or "camelot")
	Mock.class = opts.class or "WARRIOR"
	world = { bags = opts.bags or {}, level = 60, auras = {}, meals = {}, fed = nil, speed = 0, falling = false,
		castTime = nil }
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local undo = strangers({})
	local ns
	local ok, err = pcall(function()
		ns = load(scenario)
		if not ns then return end
		local data = ns.FOODS[opts.flavour or "camelot"]
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
		ns.NoteMoving(GetTime(), false)
		Mock.advance(2)
		if opts.on ~= false then
			ns.db.profile.ownBuffs.pick.food = "auto"
			ns.ForgetScrolls()
		end
		body(ns, data)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	-- A cast time cached from a stub must not leak into another file.
	if ns and ns.ForgetCastTimes then ns.ForgetCastTimes() end
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

local function shown(option)
	if not option then return false end
	local hidden = option.hidden
	if type(hidden) == "function" then hidden = hidden({}) end
	return not hidden
end

do
	local scenario = "movehold: on by default, food waits while you move"
	with(scenario, {}, function(ns, data)
		if ns.db.profile.ownBuffs.holdMoving ~= true then
			fail(scenario, "a new profile has holdMoving " .. tostring(ns.db.profile.ownBuffs.holdMoving))
		end
		stock(ns, { [data[1][1]] = 3 })
		if not mine(ns) then
			fail(scenario, "SKIPPED -- food in the bags, standing still, and nothing offered")
			return
		end
		world.speed = 7
		Mock.advance(0.5)
		if mine(ns) then fail(scenario, "moving with the hold on, and offered " .. key(mine(ns))) end
	end)
end

do
	local scenario = "movehold: off, food stays on the prompt while you move"
	with(scenario, {}, function(ns, data)
		stock(ns, { [data[1][1]] = 3 })
		if not mine(ns) then
			fail(scenario, "SKIPPED -- food in the bags, standing still, and nothing offered")
			return
		end
		local control = findOption(ns.optionsTable, "ownHoldMoving")
		if not control then fail(scenario, "My own buffs has no switch for the hold on the move") return end
		if not shown(control) then fail(scenario, "the switch is hidden from a warrior with food") end
		if control.get() ~= true then fail(scenario, "the switch reads off with a new profile") end
		control.set({ "ownHoldMoving" }, false)
		if ns.db.profile.ownBuffs.holdMoving ~= false then fail(scenario, "switching it off wrote nothing") end
		world.speed = 7
		Mock.advance(0.5)
		local entry = mine(ns)
		if not entry then
			fail(scenario, "off, moving, and the food is not offered")
		elseif key(entry) ~= "food" .. data[1][1] then
			fail(scenario, "off, moving, and the offer is " .. key(entry))
		end
		if lines(ns):find("waits until you stand still", 1, true) then
			fail(scenario, "off, and the Myself lines still say it waits: " .. lines(ns))
		end
		ns.addon:Tick()
		ns.addon:PLAYER_STARTED_MOVING()
		local text = macro(ns)
		if not (text and tostring(text):find("/use item:", 1, true)) then
			fail(scenario, "off, and the moving event took the food off the prompt: " .. tostring(text))
		end
		control.set({ "ownHoldMoving" }, true)
		Mock.advance(0.5)
		if mine(ns) then fail(scenario, "switched on again, moving, and offered " .. key(mine(ns))) end
	end)
end

do
	local scenario = "movehold: off, the consumables button still uses food on the move"
	with(scenario, {}, function(ns, data)
		stock(ns, { [data[1][1]] = 3 })
		ns.db.profile.ownBuffs.apart = true
		ns.db.profile.ownBuffs.holdMoving = false
		Mock.advance(1)
		ns.addon:Tick()
		local b = ns.Supplies:Button()
		if not (b and b:GetAttribute("macrotext1")) then
			fail(scenario, "SKIPPED -- the consumables button was not armed to begin with")
			return
		end
		world.speed = 7
		Mock.advance(0.05)
		b.scripts.PreClick(b, "LeftButton", true)
		if b:GetAttribute("macrotext1") == nil then
			fail(scenario, "off, pressed on the move, and the button was disarmed")
		end
	end)
end

do
	local scenario = "movehold: the switch sits on My own buffs, for a class with nothing for others too"
	with(scenario, { class = "HUNTER" }, function(ns, data)
		local layout = ns.WindowLayout
		local count, after, where = 0, nil, nil
		for _, section in ipairs(layout and layout.pages and layout.pages.self and layout.pages.self.sections or {}) do
			local previous
			for _, item in ipairs(section.items or {}) do
				local name = type(item) == "table" and item[1] or item
				if name == "who.ownHoldMoving" then
					count = count + 1
					where, after = section.key, previous
				end
				previous = name
			end
		end
		if count ~= 1 then fail(scenario, "who.ownHoldMoving is on the self page " .. count .. " times") end
		if where ~= "self.when" then fail(scenario, "it sits in " .. tostring(where) .. ", not self.when") end
		if after ~= "who.ownItemsLast" then fail(scenario, "it comes after " .. tostring(after) .. ", not who.ownItemsLast") end
		stock(ns, { [data[1][1]] = 3 })
		local control = findOption(ns.optionsTable, "ownHoldMoving")
		if not shown(control) then fail(scenario, "a hunter with food does not see the switch") end
		ns.db.profile.ownBuffs.holdMoving = false
		local Page = ns.OptionsPage
		if not (Page and Page.ResetPage) then
			fail(scenario, "SKIPPED -- no ns.OptionsPage.ResetPage")
			return
		end
		local ok, err = pcall(Page.ResetPage, "self")
		if not ok then fail(scenario, "the reset threw: " .. tostring(err)) end
		if ns.db.profile.ownBuffs.holdMoving ~= true then
			fail(scenario, "the self page's reset left holdMoving " .. tostring(ns.db.profile.ownBuffs.holdMoving))
		end
	end)
end
