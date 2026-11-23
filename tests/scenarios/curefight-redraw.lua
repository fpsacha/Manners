-- The game's aura display under the cure button follows a token that now names
-- somebody else (Prompt/CureNeed.lua, Redraw; GitHub issue 43). Blizzard's
-- AuraContainer redraws on SetUnit, on its OnShow and OnHide, on UNIT_AURA for
-- its unit and on UpdateAllAuras, never on a target or roster change by itself:
-- a box left up keeps drawing the one its token used to name. The mock's box
-- (tests/mockwidgets.lua) keeps the same picture until one of those comes.
--
-- Every name starts with "curefight-redraw:".

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

local MOTW, CURE_POISON, REMOVE_CURSE = 1126, 8946, 2782
local NAMES = { [1126] = "Mark of the Wild", [8946] = "Cure Poison", [2782] = "Remove Curse" }
local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "UnitInParty", "C_UnitAuras", "C_Spell", "UnitIsUnit",
	"UnitGUID", "UnitCanAssist" }

-- A druid in a party of three on WoW Forever, with the game's aura container.
-- world.who[token] the person a token names; world.debuffs[person] their
-- debuffs, which the addon's reads never see in a fight and the game's display
-- does; world.target the person targeted.
local function with(scenario, body)
	Mock.reset()
	Mock.setFlavour("camelot")
	Mock.class = "DRUID"
	Mock.groupSize = 3
	Mock.held = { [MOTW] = true }
	Mock.auraContainer = true
	local world = { debuffs = {}, who = { party1 = "Gwen", party2 = "Hugo" } }
	local names = { party1 = { "Gwen", "Hale" }, party2 = { "Hugo", "Holt" } }
	local restore = strangers(names)
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local function person(unit)
		if unit == "target" then return world.target end
		return world.who[unit] or unit
	end
	function world.reshuffle()
		world.who.party1, world.who.party2 = world.who.party2, world.who.party1
		names.party1, names.party2 = names.party2, names.party1
	end
	function world.setTarget(token)
		world.target = token and world.who[token] or nil
		names.target = token and names[token] or nil
	end
	local ok, err = pcall(function()
		rawset(_G, "IsSpellKnown", function(id) return id == MOTW or id == CURE_POISON or id == REMOVE_CURSE end)
		rawset(_G, "IsPlayerSpell", function(id) return id == MOTW or id == CURE_POISON or id == REMOVE_CURSE end)
		rawset(_G, "UnitInParty", function(unit) return type(unit) == "string" and unit:find("^party%d+$") ~= nil end)
		local baseAuras, baseSpell = C_UnitAuras, C_Spell
		rawset(_G, "C_UnitAuras", setmetatable({
			GetAuraDataByIndex = function(unit, index, filter)
				if filter ~= "HARMFUL" then return baseAuras.GetAuraDataByIndex(unit, index, filter) end
				if Mock.inCombat then return Mock.SECRET end
				return nil
			end,
			GetUnitAuraInstanceIDs = function()
				if Mock.inCombat then error("Auras cannot be accessed when secret while tainted") end
				return {}
			end,
		}, { __index = baseAuras }))
		rawset(_G, "C_Spell", setmetatable({
			GetSpellName = function(id) return NAMES[id] or baseSpell.GetSpellName(id) end,
			IsSpellUsable = function() return true, false end,
		}, { __index = baseSpell }))
		local realIsUnit, realCanAssist = saved.UnitIsUnit or UnitIsUnit, saved.UnitCanAssist or UnitCanAssist
		rawset(_G, "UnitIsUnit", function(a, b) return realIsUnit(a, b) or (person(a) ~= nil and person(a) == person(b)) end)
		rawset(_G, "UnitGUID", function(unit) return "G-" .. tostring(person(unit)) end)
		rawset(_G, "UnitCanAssist", function(a, b)
			if b == "target" then return world.target ~= nil end
			return realCanAssist(a, b)
		end)
		Mock.hiddenFor = function(unit)
			local who = person(unit)
			return who and world.debuffs[who] or nil
		end
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		Mock.timers = {}
		Mock.secureActions = true
		Mock.eventSink = ns.addon
		ns.KeyNudge = nil
		ns.db.profile.prompt.cureFight = true
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.addon:Tick()
		Mock.runTimers(0)
		body(ns, world)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	Mock.inCombat = false
	Mock.modifiers = {}
	restore()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function pull(ns)
	Mock.inCombat = false
	ns.addon:PLAYER_REGEN_DISABLED()
	Mock.inCombat = true
	Mock.frameEvent("PLAYER_REGEN_DISABLED")
	Mock.runTimers(0)
	for _ = 1, 6 do Mock.runTimers(0.11) end
end

local function release(ns)
	Mock.inCombat = false
	ns.addon:PLAYER_REGEN_ENABLED()
	Mock.frameEvent("PLAYER_REGEN_ENABLED")
	Mock.runTimers(0)
end

-- The tokens whose debuff the game draws on the first cure button's place.
local function showingOn(ns)
	local button = ns.CureFight:Button(1)
	local out = {}
	for _, box in ipairs(Mock.auraBoxes or {}) do
		local wrap = box._parentFrame
		local holder = wrap and wrap._parentFrame
		local at = holder and holder.points and holder.points[1]
		if button and at and at[2] == button and Mock.auraShows(box) then out[#out + 1] = box._unit end
	end
	table.sort(out)
	return table.concat(out, ",")
end

do
	local s = "curefight-redraw: forever: a new friend targeted in a fight is drawn, not the last one"
	with(s, function(ns, world)
		world.debuffs.Gwen = { { kind = "Curse" } }
		world.setTarget("party1")
		pull(ns)
		if showingOn(ns) ~= "party1,target" then fail(s, "Gwen targeted, the display shows '" .. showingOn(ns) .. "'") end
		-- Hugo, clean: Gwen's curse is no longer drawn for the target.
		world.setTarget("party2")
		Mock.frameEvent("PLAYER_TARGET_CHANGED")
		for _ = 1, 3 do Mock.runTimers(0.11) end
		if showingOn(ns) ~= "party1" then fail(s, "Hugo targeted, the old target's curse is still drawn: '" .. showingOn(ns) .. "'") end
		-- And back: Gwen's curse drawn for the target again.
		world.setTarget("party1")
		Mock.frameEvent("PLAYER_TARGET_CHANGED")
		for _ = 1, 3 do Mock.runTimers(0.11) end
		if showingOn(ns) ~= "party1,target" then fail(s, "Gwen targeted again, the display shows '" .. showingOn(ns) .. "'") end
		release(ns)
	end)
end

do
	local s = "curefight-redraw: forever: the party reordered in a fight is drawn for who each token names now"
	with(s, function(ns, world)
		world.debuffs.Gwen = { { kind = "Curse" } }
		pull(ns)
		if showingOn(ns) ~= "party1" then fail(s, "Gwen as party1, the display shows '" .. showingOn(ns) .. "'") end
		-- Gwen is party2 now, Hugo (clean) party1.
		world.reshuffle()
		Mock.frameEvent("GROUP_ROSTER_UPDATE")
		for _ = 1, 3 do Mock.runTimers(0.11) end
		if showingOn(ns) ~= "party2" then fail(s, "after the reshuffle the display shows '" .. showingOn(ns) .. "', not Gwen as party2") end
		release(ns)
	end)
end
