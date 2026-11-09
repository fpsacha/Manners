-- The Scrolls switch under Myself on Who to buff (a player on CurseForge:
-- "Could we have an option to remove scrolls from 'Your own buffs'?"). One
-- switch for every scroll (Buffs.lua, isScroll): the stat scrolls of every
-- client but retail (Consumables.lua), and a mage's familiar and weapon imbue
-- on Forever. Off, no scroll is offered and their switches leave the page;
-- each scroll's own pick stays in the profile and is back when it is on again.
-- On by default, which is how the scrolls were before the switch.
--
-- Every scenario name starts with "scrolls-switch:" so the mutations in
-- tests/mutations/scrolls-switch.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, findOption = H.strangers, H.freshPrompt, H.findOption

-- Forever's Rat Familiar scroll and the aura its use casts (Buffs.lua).
local RAT = 275069

local function key(entry) return tostring(entry and entry.buff and entry.buff.key) end

local function mine(ns)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.reason == "self" then return entry end
	end
	return nil
end

local function lines(ns) return table.concat(ns.MyselfLines(GetTime()), " / ") end

-- The world a scenario stands in: bags (item -> count), the player's auras by
-- id (id -> expiry) and his level. Nothing is learned, so the scrolls and
-- the bagged families are all there is of your own to offer.
local world
local TOUCHED = { "C_Item", "C_UnitAuras", "UnitLevel", "IsMounted", "IsSpellKnown", "IsPlayerSpell", "IsResting",
	"IsInInstance", "GetInventoryItemID" }

local function install()
	rawset(_G, "C_Item", {
		GetItemCount = function(id) return world.bags[id] or 0 end,
		GetItemNameByID = function(id) return "Item " .. id end,
		RequestLoadItemDataByID = function() end,
		GetItemIconByID = function(id) return 7100000 + id end,
		GetItemInfoInstant = function(id) return id, "Consumable", "", "", 7100000 + id, 0, 2 end,
		GetWeaponEnchantInfo = function() return {} end,
	})
	rawset(_G, "GetInventoryItemID", function() return nil end)
	rawset(_G, "UnitLevel", function(unit)
		if unit == "player" then return world.level end
		return 12
	end)
	rawset(_G, "IsMounted", function() return false end)
	rawset(_G, "IsResting", function() return false end)
	rawset(_G, "IsSpellKnown", function() return false end)
	rawset(_G, "IsPlayerSpell", function() return false end)
	rawset(_G, "IsInInstance", function() return false, "none" end)
	rawset(_G, "C_UnitAuras", nil)
	local base = C_UnitAuras
	rawset(_G, "C_UnitAuras", setmetatable({
		GetUnitAuraBySpellID = function(unit, id)
			if unit ~= "player" then return nil end
			local expires = world.auras[id]
			if expires == nil then return nil end
			return { spellId = id, name = "Aura " .. id, expirationTime = expires, duration = 3600,
				sourceUnit = "player" }
		end,
		GetAuraDataBySpellName = function() return nil end,
	}, { __index = base }))
end

-- One session as opts.class on opts.flavour, with opts.bags, opts.level and
-- opts.on (the family keys switched on).
local function with(scenario, opts, body)
	local flavour = opts.flavour or "camelot"
	Mock.reset()
	Mock.setFlavour(flavour)
	Mock.class = opts.class or "WARRIOR"
	world = { bags = opts.bags or {}, level = opts.level or 60, auras = {} }
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local undo = strangers({})
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		install()
		Mock.playerHeld = {}
		freshPrompt(ns, scenario)
		Mock.playerHeld = {}
		ns.db.profile.sources.self = true
		ns.db.profile.ownBuffs.inCities = true
		for _, k in ipairs(opts.on or {}) do ns.db.profile.ownBuffs.pick[k] = "auto" end
		ns.addon:BAG_UPDATE_DELAYED()
		ns.ForgetScrolls()
		body(ns, ns.CONSUMABLES and ns.CONSUMABLES[flavour])
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

local function shown(ns, name)
	local control = findOption(ns.optionsTable, name)
	if not control then return nil end
	return not (control.hidden and control.hidden())
end

-- The switch as the page sets it, the window's way.
local function switch(ns, on)
	local control = findOption(ns.optionsTable, "ownScrolls")
	control.set({ "ownScrolls" }, on)
end

-- ------------------------------------------------------------------ the default

for _, flavour in ipairs({ "camelot", "vanilla" }) do
	local scenario = "scrolls-switch: " .. flavour .. ": on by default, every scroll marked"
	with(scenario, { flavour = flavour }, function(ns)
		if ns.defaults.profile.ownBuffs.scrolls ~= true or ns.db.profile.ownBuffs.scrolls ~= true then
			fail(scenario, ("Scrolls is %s by default (the profile %s), not on"):format(
				tostring(ns.defaults.profile.ownBuffs.scrolls), tostring(ns.db.profile.ownBuffs.scrolls)))
		end
		local control = findOption(ns.optionsTable, "ownScrolls")
		if not control or control.type ~= "toggle" then
			fail(scenario, "Who to buff has no Scrolls switch")
		elseif control.get() ~= true then
			fail(scenario, "the switch reads off on a new profile")
		end
		-- Every stat scroll is one, and nothing else of the warrior's.
		for _, family in ipairs(ns.GetOwnFamilies("WARRIOR") or {}) do
			local stat = family.key:sub(1, 6) == "scroll"
			if (family.isScroll == true) ~= stat then
				fail(scenario, family.key .. " is " .. (stat and "not " or "") .. "a scroll")
			end
		end
		if not ns.HasScrollFamilies() then fail(scenario, "a warrior here has no scroll") end
		-- A mage's familiar and imbue on Forever are scrolls too.
		if flavour == "camelot" then
			for _, k in ipairs({ "familiar", "imbue" }) do
				local family = ns.FindOwnFamily(k)
				if not (family and family.isScroll) then fail(scenario, "Forever's " .. k .. " is not a scroll") end
			end
		end
		-- A damaged file's value is put right, to on.
		ns.db.profile.ownBuffs.scrolls = "no"
		ns.ClampSettings()
		if ns.db.profile.ownBuffs.scrolls ~= true then
			fail(scenario, "a damaged Scrolls value was left as " .. tostring(ns.db.profile.ownBuffs.scrolls))
		end
	end)
end

do
	local scenario = "scrolls-switch: retail has no scroll and no switch"
	with(scenario, { flavour = "mainline" }, function(ns)
		if ns.HasScrollFamilies() then fail(scenario, "retail has a scroll") end
		if shown(ns, "ownScrolls") then fail(scenario, "the Scrolls switch is shown on retail") end
	end)
end

-- ------------------------------------------------------------------ Forever

do
	local scenario = "scrolls-switch: forever: off, a mage's familiar and a stat scroll are gone and kept"
	with(scenario, { flavour = "camelot", class = "MAGE", level = 12, on = { "scrollstamina" } }, function(ns, data)
		local stamina = data.scroll.stamina[#data.scroll.stamina]
		world.bags = { [RAT] = 1, [stamina[1]] = 1 }
		ns.addon:BAG_UPDATE_DELAYED()
		ns.db.profile.ownBuffs.pick.familiar = "ratfamiliar"
		-- On: both rows, the switch, and the familiar first.
		if not shown(ns, "own_familiar") or not shown(ns, "own_scrollstamina") then
			fail(scenario, "SKIPPED -- with the switch on, the familiar's or the stamina scroll's row is not shown")
			return
		end
		if not shown(ns, "ownScrolls") then fail(scenario, "a scroll's row is shown, and the Scrolls switch is not") end
		local first = key(mine(ns))
		if first ~= "ratfamiliar" then
			fail(scenario, "SKIPPED -- with the switch on, offered " .. first .. ", not the Rat Familiar")
			return
		end

		switch(ns, false)
		if ns.db.profile.ownBuffs.scrolls ~= false then
			fail(scenario, "switching it off wrote " .. tostring(ns.db.profile.ownBuffs.scrolls))
		end
		for _, row in ipairs({ "own_familiar", "own_imbue", "own_scrollstamina", "own_scrollagility" }) do
			if shown(ns, row) then fail(scenario, "with Scrolls off, the row " .. row .. " is still shown") end
		end
		if not shown(ns, "ownScrolls") then fail(scenario, "switched off, the Scrolls switch hid itself") end
		if mine(ns) then fail(scenario, "with Scrolls off, you were offered " .. key(mine(ns))) end
		for _, family in ipairs(ns.KnownOwnFamilies()) do
			if family.isScroll then fail(scenario, "with Scrolls off, " .. family.key .. " is a known family") end
		end
		if not lines(ns):find("Scrolls: switched off", 1, true) then
			fail(scenario, "/manners debug does not say Scrolls is off: " .. lines(ns))
		end
		-- Every scroll's own setting as it was.
		local pick = ns.db.profile.ownBuffs.pick
		if pick.familiar ~= "ratfamiliar" or pick.scrollstamina ~= "auto" or pick.scrollagility ~= "off" then
			fail(scenario, ("switching Scrolls off changed the picks: familiar %s, stamina %s, agility %s"):format(
				tostring(pick.familiar), tostring(pick.scrollstamina), tostring(pick.scrollagility)))
		end

		-- On again: each as it was.
		switch(ns, true)
		if not shown(ns, "own_familiar") or not shown(ns, "own_scrollstamina") then
			fail(scenario, "Scrolls on again, and the familiar's or the stamina scroll's row is not back")
		end
		if shown(ns, "own_scrollagility") then fail(scenario, "Scrolls on again, and Agility's row shows with none and it off") end
		if (ns.OwnPick(ns.FindOwnFamily("familiar"))) ~= "ratfamiliar" then
			fail(scenario, "Scrolls on again, and the familiar reads " .. tostring((ns.OwnPick(ns.FindOwnFamily("familiar")))))
		end
		if key(mine(ns)) ~= "ratfamiliar" then fail(scenario, "Scrolls on again, and offered " .. key(mine(ns))) end
		-- The familiar on: the stamina scroll is next, as before.
		world.auras[1296202] = GetTime() + 1500
		ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
		Mock.advance(1)
		if key(mine(ns)) ~= "scroll" .. stamina[1] then
			fail(scenario, "Scrolls on again, the familiar up: offered " .. key(mine(ns)) .. ", not the stamina scroll")
		end
	end)
end

-- ------------------------------------------------------------------ Classic Era

do
	local scenario = "scrolls-switch: era: off, no stat scroll is offered or shown, and on again it is"
	with(scenario, { flavour = "vanilla", on = { "scrollagility", "flask" } }, function(ns, data)
		local agility, spirit = data.scroll.agility[1], data.scroll.spirit[1]
		world.bags = { [agility[1]] = 1, [spirit[1]] = 1 }
		ns.addon:BAG_UPDATE_DELAYED()
		if key(mine(ns)) ~= "scroll" .. agility[1] then
			fail(scenario, "SKIPPED -- with the switch on, offered " .. key(mine(ns)) .. ", not the Scroll of Agility")
			return
		end
		-- Spirit is off, its scroll in the bags: its row shows, as before.
		if not shown(ns, "own_scrollspirit") then fail(scenario, "SKIPPED -- Spirit's row is not shown with one in the bags") end

		switch(ns, false)
		if mine(ns) then fail(scenario, "with Scrolls off, you were offered " .. key(mine(ns))) end
		for _, stat in ipairs({ "agility", "strength", "protection", "intellect", "stamina", "spirit" }) do
			if shown(ns, "own_scroll" .. stat) then fail(scenario, "with Scrolls off, the row own_scroll" .. stat .. " is shown") end
		end
		-- Nothing else goes with them.
		if not shown(ns, "own_flask") then fail(scenario, "with Scrolls off, the flask's row went too") end
		if not shown(ns, "own_food") then fail(scenario, "with Scrolls off, Well Fed's row went too") end
		if not shown(ns, "ownScrolls") then fail(scenario, "switched off, the Scrolls switch hid itself") end
		-- Read as Don't remind me, wherever a pick is asked for (the report,
		-- the counts of the bags), while the profile keeps its own.
		if (ns.OwnPick(ns.FindOwnFamily("scrollagility"))) ~= "off" then
			fail(scenario, "with Scrolls off, Agility's pick reads " .. tostring((ns.OwnPick(ns.FindOwnFamily("scrollagility")))))
		end
		local pick = ns.db.profile.ownBuffs.pick
		if pick.scrollagility ~= "auto" or pick.scrollspirit ~= "off" then
			fail(scenario, ("switching Scrolls off changed the picks: agility %s, spirit %s"):format(
				tostring(pick.scrollagility), tostring(pick.scrollspirit)))
		end
		-- A flask switched on is offered still.
		local flask = data.flask[1]
		world.bags[flask[1]] = 1
		ns.addon:BAG_UPDATE_DELAYED()
		if key(mine(ns)) ~= "flask" .. flask[1] then
			fail(scenario, "with Scrolls off and a flask in the bags, offered " .. key(mine(ns)))
		end
		world.bags[flask[1]] = nil
		ns.addon:BAG_UPDATE_DELAYED()
		-- The bags read again with Scrolls off, the scrolls not counted.
		if mine(ns) then fail(scenario, "with Scrolls off and the flask gone, you were offered " .. key(mine(ns))) end

		switch(ns, true)
		if (ns.OwnPick(ns.FindOwnFamily("scrollagility"))) ~= "auto" then
			fail(scenario, "Scrolls on again, and Agility's pick reads " .. tostring((ns.OwnPick(ns.FindOwnFamily("scrollagility")))))
		end
		if key(mine(ns)) ~= "scroll" .. agility[1] then
			fail(scenario, "Scrolls on again, and offered " .. key(mine(ns)) .. ", not the Scroll of Agility")
		end
		if not shown(ns, "own_scrollagility") or not shown(ns, "own_scrollspirit") then
			fail(scenario, "Scrolls on again, and the scrolls' rows are not back")
		end
	end)
end

do
	local scenario = "scrolls-switch: the switch shows only with a scroll about, or while it is off"
	with(scenario, { flavour = "vanilla" }, function(ns, data)
		if shown(ns, "ownScrolls") then fail(scenario, "no scroll in the bags or switched on, and the Scrolls switch shows") end
		world.bags = { [data.scroll.stamina[1][1]] = 1 }
		if not shown(ns, "ownScrolls") then fail(scenario, "a Scroll of Stamina in the bags, and the Scrolls switch is hidden") end
		switch(ns, false)
		world.bags = {}
		ns.addon:BAG_UPDATE_DELAYED()
		if not shown(ns, "ownScrolls") then fail(scenario, "off, with no scroll in the bags, and the switch is gone") end
		local desc = findOption(ns.optionsTable, "ownScrolls").desc
		desc = type(desc) == "function" and desc() or desc
		if type(desc) ~= "string" or not desc:find("as you left it", 1, true) then
			fail(scenario, "the switch says " .. tostring(desc))
		end
		-- Found by the window's search under the scrolls it hides, too.
		local words = ns.WindowLayout and ns.WindowLayout.keywords and ns.WindowLayout.keywords["who.ownScrolls"]
		if type(words) ~= "string" or not words:find("familiar", 1, true) then
			fail(scenario, "the window's search has no other words for the Scrolls switch: " .. tostring(words))
		end
	end)
end
