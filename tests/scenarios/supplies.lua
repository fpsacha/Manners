-- Consumables on a button of their own (1.11.15). A player on CurseForge wanted
-- the buff prompt in plain sight and the consumables out of the way. With "Put
-- consumables on a button of their own" (ownBuffs.apart, off by default) your
-- items -- here a warrior's food -- leave the prompt (Queue.lua, OwnPick) and
-- come up on MannersSupplies (Prompt/Supplies.lua, ns.SupplyEntry): the
-- prompt's own macro for the item, a press that writes the retry block, a
-- right-click that skips it, a place of its own dragged while the prompt is
-- unlocked, and nothing at all in a fight.
--
-- Every scenario name starts with "supplies:" so the mutations in
-- tests/mutations/supplies.py can name the one that has to catch them.

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

local function button(ns) return ns.Supplies:Button() end

-- A scan, and the consumables button's own repaint, as the tick makes them.
local function tick(ns)
	Mock.advance(1)
	ns.addon:Tick()
end

local function shown(ns)
	local b = button(ns)
	return b ~= nil and b:IsShown()
end

local function macro(ns)
	local b = button(ns)
	return b and b:GetAttribute("macrotext1")
end

-- A warrior with food in his bags, the reminder on, the button as `apart`.
local function fed(scenario, apart, body)
	with(scenario, { on = true }, function(ns, data)
		stock(ns, { [data[1][1]] = 3 })
		ns.db.profile.ownBuffs.apart = apart
		tick(ns)
		body(ns, data)
	end)
end

do
	local scenario = "supplies: off by default, food stays on the prompt"
	fed(scenario, nil, function(ns)
		if ns.defaults.profile.ownBuffs.apart ~= false then fail(scenario, "the switch is on by default") end
		ns.db.profile.ownBuffs.apart = false
		tick(ns)
		local entry = mine(ns)
		if not entry or not (entry.buff and entry.buff.family and entry.buff.family.food) then
			fail(scenario, "SKIPPED -- food was not offered on the prompt to begin with")
		end
		if shown(ns) then fail(scenario, "the consumables button shows with the switch off") end
	end)
end

do
	local scenario = "supplies: on, food leaves the prompt for the button, armed to use it"
	fed(scenario, true, function(ns, data)
		local entry = mine(ns)
		if entry and entry.buff and entry.buff.item then
			fail(scenario, "food is still on the prompt: " .. key(entry))
		end
		if not shown(ns) then fail(scenario, "the consumables button is not shown") return end
		local text = tostring(macro(ns))
		if not text:find("/use item:" .. data[1][1], 1, true) then fail(scenario, "the button's macro is " .. text) end
		if ns.Supplies:Current() == nil then fail(scenario, "the button names nothing") end
		-- Switched off again: the button goes, and food is back on the prompt.
		ns.db.profile.ownBuffs.apart = false
		tick(ns)
		if shown(ns) then fail(scenario, "switched off, the button is still up") end
		local back = mine(ns)
		if not (back and back.buff and back.buff.item) then fail(scenario, "switched off, food did not come back to the prompt") end
	end)
end

do
	local scenario = "supplies: a press holds the food back, as a press on the prompt does"
	fed(scenario, true, function(ns)
		local b = button(ns)
		if not b then fail(scenario, "SKIPPED -- no button") return end
		b.scripts.PreClick(b, "LeftButton", true)
		tick(ns)
		if shown(ns) then fail(scenario, "the food was offered again straight after the press") end
		Mock.advance(20)
		tick(ns)
		if not shown(ns) then fail(scenario, "the food never came back after the retry cooldown") end
	end)
end

do
	local scenario = "supplies: a right-click skips it for the skip time"
	fed(scenario, true, function(ns)
		local b = button(ns)
		if not b then fail(scenario, "SKIPPED -- no button") return end
		ns.db.profile.timing.skipSeconds = 120
		b.scripts.OnClick(b, "RightButton", true)
		Mock.advance(30)
		tick(ns)
		if shown(ns) then fail(scenario, "a right-click did not skip the food") end
		Mock.advance(100)
		tick(ns)
		if not shown(ns) then fail(scenario, "the food did not come back after the skip time") end
	end)
end

do
	local scenario = "supplies: unlocked it shows, arms nothing, and a drag keeps its place"
	fed(scenario, true, function(ns)
		ns.db.profile.prompt.locked = false
		tick(ns)
		local b = button(ns)
		if not shown(ns) then fail(scenario, "unlocked, the button is not shown to be dragged") return end
		if macro(ns) ~= nil then fail(scenario, "unlocked, the button still holds a macro") end
		-- The anchor the client hands back after a drag.
		Mock.geometry = true
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 333, 444)
		b.scripts.OnDragStop(b)
		Mock.geometry = nil
		local s = ns.db.profile.supplies
		if s.point ~= "TOPLEFT" or s.relPoint ~= "BOTTOMLEFT" or s.x ~= 333 or s.y ~= 444 then
			fail(scenario, ("the drag was saved as %s %s %s %s"):format(tostring(s.point), tostring(s.relPoint),
				tostring(s.x), tostring(s.y)))
		end
		ns.db.profile.prompt.locked = true
		tick(ns)
		if not macro(ns) then fail(scenario, "locked again, the button holds nothing") end
	end)
end

do
	local scenario = "supplies: a fight takes it away, disarmed, and the end of it brings it back"
	fed(scenario, true, function(ns)
		Mock.secureActions = true
		Mock.eventSink = ns.addon
		if not shown(ns) then fail(scenario, "SKIPPED -- not shown before the fight") return end
		-- The pull: the event before the lockdown, then the driver's frame.
		Mock.inCombat = false
		ns.addon:PLAYER_REGEN_DISABLED()
		Mock.inCombat = true
		Mock.frameEvent("PLAYER_REGEN_DISABLED")
		Mock.runTimers(0)
		local b = button(ns)
		if b:IsShown() then fail(scenario, "the button is still up in the fight") end
		if b:GetAttribute("macrotext1") ~= nil or b:GetAttribute("type1") ~= nil then
			fail(scenario, "the button still holds a macro in the fight: " .. tostring(b:GetAttribute("macrotext1")))
		end
		Mock.inCombat = false
		ns.addon:PLAYER_REGEN_ENABLED()
		Mock.frameEvent("PLAYER_REGEN_ENABLED")
		Mock.runTimers(0)
		tick(ns)
		if not shown(ns) or not macro(ns) then fail(scenario, "after the fight the button did not come back armed") end
	end)
end

do
	local scenario = "supplies: the fight's snippet disarms and hides it on its own"
	fed(scenario, true, function(ns)
		local header = ns.Supplies:Header()
		if not header then fail(scenario, "no state driver was made for the button") return end
		local b = button(ns)
		if not b:GetAttribute("macrotext1") then fail(scenario, "SKIPPED -- nothing armed") return end
		-- The lockdown with no event before it (a login in a fight): the driver alone.
		Mock.secureActions = true
		Mock.inCombat = true
		Mock.frameEvent("PLAYER_REGEN_DISABLED")
		Mock.runTimers(0)
		if b:GetAttribute("macrotext1") ~= nil or b:GetAttribute("type") ~= nil then
			fail(scenario, "the snippet left a macro on the button")
		end
		if b:IsShown() then fail(scenario, "the snippet left the button up") end
		Mock.inCombat = false
	end)
end

do
	local scenario = "supplies: the switch is under Myself, the size on Look, and the key has a name"
	fed(scenario, false, function(ns)
		local switch = findOption(ns.optionsTable, "ownApart")
		if not switch then fail(scenario, "Who to buff has no switch for it") return end
		switch.set(nil, true)
		if ns.db.profile.ownBuffs.apart ~= true or switch.get() ~= true then fail(scenario, "turning it on was not stored") end
		local size = findOption(ns.optionsTable, "suppliesSize")
		if not size then fail(scenario, "Look has no size for it") return end
		if size.hidden() then fail(scenario, "the size is hidden with the button on") end
		size.set(nil, 56)
		if ns.db.profile.supplies.size ~= 56 then fail(scenario, "the size was not stored") end
		ns.db.profile.supplies.size = 500
		ns.ClampSettings()
		if ns.db.profile.supplies.size ~= 80 then fail(scenario, "a size of 500 was kept as " .. tostring(ns.db.profile.supplies.size)) end
		if type(_G["BINDING_NAME_CLICK MannersSupplies:LeftButton"]) ~= "string" then
			fail(scenario, "the key binding has no name")
		end
	end)
end
