-- Prompt fixes (bug hunt 35, area prompt): the Cozy Sleeping Bag's family
-- (Well-Rested, 1.11.10) against its own cast, a meal, a profile switch and
-- the debug lines.
--
-- Every scenario name starts with "prompt-fix:".

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

local BAG, RESTED, IN_BAG, UNROLL = 211527, 429959, 429960, 429961
local FED_NAME, MEAL_NAME = "Well Fed", "Nutritious Food"

local function key(entry) return tostring(entry and entry.buff and entry.buff.key) end
local function said() return table.concat(Mock.printed, "\n") end
local function flat(s) return (tostring(s):gsub("\n", " / ")) end

local function mine(ns)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.reason == "self" then return entry end
	end
	return nil
end

local world
local TOUCHED = { "C_Item", "C_Spell", "C_UnitAuras", "C_Container", "UnitLevel", "GetMaxPlayerLevel", "IsMounted",
	"IsSpellKnown", "IsPlayerSpell", "IsResting", "UnitCastingInfo" }

local function install()
	rawset(_G, "C_Spell", nil)
	local spells = C_Spell
	rawset(_G, "C_Spell", setmetatable({
		GetSpellName = function(id)
			if world.fed and id == world.fed then return FED_NAME end
			if world.meals[id] then return MEAL_NAME end
			return spells.GetSpellName(id)
		end,
	}, { __index = spells }))
	rawset(_G, "C_Item", {
		GetItemCount = function(id)
			world.counted[id] = (world.counted[id] or 0) + 1
			return world.bags[id] or 0
		end,
		GetItemNameByID = function(id) return "Item " .. id end,
		RequestLoadItemDataByID = function() end,
		GetItemIconByID = function(id) return 7100000 + id end,
		GetItemInfoInstant = function(id) return id, "Consumable", "", "", 7100000 + id, 0, 5 end,
	})
	rawset(_G, "UnitLevel", function(unit)
		if unit == "player" then return world.level end
		return 12
	end)
	rawset(_G, "GetMaxPlayerLevel", function() return 60 end)
	rawset(_G, "IsMounted", function() return false end)
	rawset(_G, "IsResting", function() return false end)
	-- The bag's own cast, while it runs: what the client says of it.
	rawset(_G, "UnitCastingInfo", function(unit)
		local c = world.casting
		if unit ~= "player" or not c or GetTime() >= c.ends then return nil end
		return "Unroll Bag", "Unroll Bag", 133662, c.starts * 1000, c.ends * 1000, false, c.guid, false, UNROLL
	end)
	local container = rawget(_G, "C_Container")
	rawset(_G, "C_Container", setmetatable({
		GetItemCooldown = function() return 0, 0, 1 end,
	}, { __index = container or {} }))
	rawset(_G, "C_UnitAuras", nil)
	local base = C_UnitAuras
	rawset(_G, "C_UnitAuras", setmetatable({
		GetUnitAuraBySpellID = function(unit, id)
			if unit ~= "player" then return nil end
			local expires = world.byId[id]
			if expires == nil then return nil end
			return { spellId = id, name = "Aura " .. id, expirationTime = expires, duration = 7200, sourceUnit = "player" }
		end,
		GetAuraDataBySpellName = function(unit, name)
			if unit ~= "player" then return nil end
			local expires = world.byName[name]
			if expires == nil then return nil end
			return { name = name, expirationTime = expires, sourceUnit = "player" }
		end,
	}, { __index = base }))
end

-- One session as a warrior on opts.flavour (Forever), level opts.level (30),
-- with opts.bags and the switches in opts.on (family key -> true).
local function with(scenario, opts, body)
	Mock.reset()
	Mock.setFlavour(opts.flavour or "camelot")
	Mock.class = "WARRIOR"
	world = { bags = opts.bags or {}, level = opts.level or 30, byId = {}, byName = {}, counted = {},
		meals = {}, fed = nil, casting = nil }
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local undo = strangers({})
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		local data = ns.FOODS and ns.FOODS[opts.flavour or "camelot"]
		if data then
			world.fed = data.fed
			for _, row in ipairs(data) do world.meals[row[3]] = true end
		end
		install()
		rawset(_G, "IsSpellKnown", function() return false end)
		rawset(_G, "IsPlayerSpell", function() return false end)
		Mock.playerHeld = {}
		freshPrompt(ns, scenario)
		Mock.playerHeld = {}
		for family in pairs(opts.on or {}) do ns.db.profile.ownBuffs.pick[family] = "auto" end
		ns.ForgetScrolls()
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

-- The prompt pressed on the bag, and the SENT that starts its cast of
-- `seconds` (wago.tools: 15 on Forever, 6 on Classic Era).
local function pressBag(ns, scenario, guid, seconds)
	ns.Prompt:Refresh()
	if key(ns.Prompt:Showing()) ~= "rested" .. BAG then
		fail(scenario, "SKIPPED -- the prompt is on " .. key(ns.Prompt:Showing()) .. ", not the bag")
		return false
	end
	local pressed = H.pressButton(ns)
	if pressed ~= "/use item:" .. BAG or not (ns.pendingClick and ns.pendingClick.onSelf) then
		fail(scenario, "SKIPPED -- the press did not go out: " .. flat(pressed))
		return false
	end
	ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, guid, UNROLL)
	world.casting = { starts = GetTime(), ends = GetTime() + seconds, guid = guid }
	if ns.addon.UNIT_SPELLCAST_START then ns.addon:UNIT_SPELLCAST_START(nil, "player", guid, UNROLL) end
	if ns.pendingClick then fail(scenario, "SKIPPED -- the bag's use was never settled") return false end
	return true
end

-- ------------------------------------------------------------------ #0

do
	local scenario = "prompt-fix: the bag is not offered again partway through its own 15 s cast"
	with(scenario, { on = { rested = true }, bags = { [BAG] = 1 } }, function(ns)
		if not pressBag(ns, scenario, "Cast-bag-1", 15) then return end
		for _, at in ipairs({ 5, 10, 12.5, 14.5 }) do
			Mock.advance(at - (GetTime() - world.casting.starts))
			if mine(ns) then
				fail(scenario, ("%.1f s into the bag's 15 s cast it is offered again: %s"):format(at, key(mine(ns))))
				break
			end
		end
	end)
end

do
	local scenario = "prompt-fix: Classic Era with a 3 s retry block, the bag is not offered mid-cast"
	with(scenario, { flavour = "vanilla", on = { rested = true }, bags = { [BAG] = 1 } }, function(ns)
		ns.db.profile.timing.retryCooldown = 3
		if not pressBag(ns, scenario, "Cast-bag-2", 6) then return end
		Mock.advance(4.5)
		if mine(ns) then fail(scenario, "4.5 s into the bag's 6 s cast it is offered again: " .. key(mine(ns))) end
	end)
end

do
	local scenario = "prompt-fix: the bag's cast interrupted at second 8 is said and offered again"
	with(scenario, { on = { rested = true }, bags = { [BAG] = 1 } }, function(ns)
		ns.db.profile.verbose = true
		if not pressBag(ns, scenario, "Cast-bag-3", 15) then return end
		Mock.advance(8)
		Mock.printed = {}
		world.casting = nil
		ns.addon:UNIT_SPELLCAST_INTERRUPTED(nil, "player", "Cast-bag-3", UNROLL)
		if not said():find("the cast was interrupted", 1, true) then
			fail(scenario, "the bag's cast interrupted at 8 s said nothing of it: " .. flat(said()))
		end
		Mock.advance(2.1)
		if key(mine(ns)) ~= "rested" .. BAG then
			fail(scenario, "2 s after the bag's cast was interrupted, offered " .. key(mine(ns)) .. ", not the bag")
		end
	end)
end

-- ------------------------------------------------------------------ #1

do
	local scenario = "prompt-fix: while eating, the sleeping bag is not offered next"
	with(scenario, { on = { rested = true, food = true }, level = 59 }, function(ns, data)
		local meal
		for _, row in ipairs(data or {}) do
			if row[2] <= 59 then meal = row break end
		end
		if not meal then fail(scenario, "SKIPPED -- no food for level 59") return end
		world.bags = { [meal[1]] = 2, [BAG] = 1 }
		ns.addon:BAG_UPDATE_DELAYED()
		if not tostring(key(mine(ns))):find("^food") then
			fail(scenario, "SKIPPED -- food was not offered first: " .. key(mine(ns)))
			return
		end
		world.byName[MEAL_NAME] = GetTime() + 18
		Mock.advance(1)
		local entry = mine(ns)
		if entry then
			fail(scenario, "a meal is on, and offered " .. key(entry) .. ", whose use would stand you up")
		end
	end)
end

-- ------------------------------------------------------------------ #2

do
	local scenario = "prompt-fix: a profile switch that turns Well-Rested on offers the bag"
	with(scenario, { bags = { [BAG] = 1 } }, function(ns)
		if not ns.db.SetProfile then fail(scenario, "SKIPPED -- the mock database has no profiles") return end
		if mine(ns) then fail(scenario, "SKIPPED -- offered with the switch off: " .. key(mine(ns))) return end
		Mock.sv.profiles = Mock.sv.profiles or {}
		Mock.sv.profiles["Alt"] = { ownBuffs = { pick = { rested = "auto" } } }
		ns.db:SetProfile("Alt")
		if not Mock.dbCallbacks["OnProfileChanged"] then ns.addon:RefreshConfig("OnProfileChanged") end
		if ns.db.profile.ownBuffs.pick.rested ~= "auto" then
			fail(scenario, "SKIPPED -- the Alt profile has Well-Rested " .. tostring(ns.db.profile.ownBuffs.pick.rested))
			return
		end
		Mock.advance(1)
		if key(mine(ns)) ~= "rested" .. BAG then
			fail(scenario, "switched to a profile with Well-Rested on, the bag in the bags: offered " .. key(mine(ns)))
		end
	end)
end

-- ------------------------------------------------------------------ #3

do
	local scenario = "prompt-fix: the debug lines name Well-Rested and Well Fed when up"
	with(scenario, { on = { rested = true, food = true }, level = 59 }, function(ns, data)
		local meal
		for _, row in ipairs(data or {}) do
			if row[2] <= 59 then meal = row break end
		end
		world.bags = { [BAG] = 1, [meal and meal[1] or 0] = 1 }
		ns.addon:BAG_UPDATE_DELAYED()
		world.byId[RESTED] = GetTime() + 7000
		world.byName[FED_NAME] = GetTime() + 1700
		ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
		Mock.advance(1)
		local text = table.concat(ns.MyselfLines(GetTime()), " / ")
		if not text:find("Well-Rested:", 1, true) then
			fail(scenario, "SKIPPED -- no Well-Rested line: " .. flat(text))
			return
		end
		if text:find("? is up", 1, true) then
			fail(scenario, "a buff up is named '?': " .. flat(text))
		end
	end)
end
