-- The cure button where only the game knows who needs a cure (Prompt/CureNeed.lua,
-- Prompt/CureFight.lua), GitHub issue 43: on WoW Forever 1.60.1 every aura read
-- of an addon is withheld in a fight and the game's list of the debuffs you can
-- remove throws ("Auras cannot be accessed when secret while tainted"), so the
-- reads never find anybody. The game's own aura container
-- (CustomAuraContainerTemplate) under each cure button shows the debuff itself;
-- the button stays out of sight with its cover up, and a click casts only as
-- the second of two.
--
-- The mock's container (tests/mockwidgets.lua) shows when the unit's hidden
-- debuff list (Mock.hiddenFor), as it was when the box last redrew, holds one
-- the player can remove, of the slot's kinds, and throws when Lua asks its slot
-- frame what it shows in a fight.
--
-- Every name starts with "curefight-container:".

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

local COMMAND = "CLICK MannersCureFight:LeftButton"
local PARTY = { party1 = { "Gwen", "Hale" }, party2 = { "Hugo", "Holt" } }
local MOTW, CURE_POISON, REMOVE_CURSE = 1126, 8946, 2782
local NAMES = { [1126] = "Mark of the Wild", [8946] = "Cure Poison", [2782] = "Remove Curse", [2893] = "Abolish Poison" }
local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "UnitInParty", "C_UnitAuras", "C_Spell", "UnitIsUnit",
	"UnitGUID", "UnitCanAssist" }
local REFUSED = "Auras cannot be accessed when secret while tainted by *** ForceTaint_Strong ***"

-- One session: a druid in a party of three on WoW Forever, the game's aura
-- container there unless env.noContainer, "A button for each cure" on unless
-- env.single, no key unless env.key. env.flavour another client.
-- body(ns, world): world.debuffs[unit] the unit's debuffs ({ kind = "Curse" }),
-- which the addon's reads never see in a fight and the game's display does;
-- world.setTarget(token, hostile).
local function with(scenario, env, body)
	Mock.reset()
	Mock.setFlavour(env.flavour or "camelot")
	Mock.class = "DRUID"
	Mock.groupSize = 3
	Mock.held = { [MOTW] = true }
	Mock.auraContainer = not env.noContainer or nil
	local names = {}
	for token, pair in pairs(PARTY) do names[token] = pair end
	local restore = strangers(names)
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local world = { debuffs = {}, known = {}, listThrew = 0 }
	for _, id in ipairs(env.known or { MOTW, CURE_POISON, REMOVE_CURSE }) do world.known[id] = true end
	local function canon(unit)
		if unit == "target" then return world.target or "target" end
		return unit
	end
	function world.setTarget(token, hostile)
		world.target, world.hostile = token, hostile == true
		names.target = token and (hostile and { "Grunt", "Hide" } or names[token]) or nil
	end
	local ok, err = pcall(function()
		rawset(_G, "IsSpellKnown", function(id) return world.known[id] == true end)
		rawset(_G, "IsPlayerSpell", function(id) return world.known[id] == true end)
		rawset(_G, "UnitInParty", function(unit) return type(unit) == "string" and unit:find("^party%d+$") ~= nil end)
		local baseAuras, baseSpell = C_UnitAuras, C_Spell
		rawset(_G, "C_UnitAuras", setmetatable({
			GetAuraDataByIndex = function(unit, index, filter)
				if filter ~= "HARMFUL" then return baseAuras.GetAuraDataByIndex(unit, index, filter) end
				-- Forever in a fight: every harmful aura withheld.
				if Mock.inCombat then return Mock.SECRET end
				local d = world.debuffs[canon(unit)] and world.debuffs[canon(unit)][index]
				if not d then return nil end
				return { name = "Bad thing", spellId = 90000, dispelName = d.kind, expirationTime = Mock.now + 30,
					duration = 60, canActivePlayerDispel = true, isHarmful = true, auraInstanceID = 9000 + index }
			end,
			-- Forever 1.60.1: the list throws for an addon in a fight.
			GetUnitAuraInstanceIDs = function(unit)
				if Mock.inCombat then
					world.listThrew = world.listThrew + 1
					error(REFUSED)
				end
				local out = {}
				for i in ipairs(world.debuffs[canon(unit)] or {}) do out[#out + 1] = 9000 + i end
				return out
			end,
		}, { __index = baseAuras }))
		rawset(_G, "C_Spell", setmetatable({
			GetSpellName = function(id) return NAMES[id] or baseSpell.GetSpellName(id) end,
			IsSpellUsable = function() return true, false end,
		}, { __index = baseSpell }))
		local realIsUnit, realCanAssist = saved.UnitIsUnit or UnitIsUnit, saved.UnitCanAssist or UnitCanAssist
		rawset(_G, "UnitIsUnit", function(a, b) return realIsUnit(canon(a), canon(b)) end)
		rawset(_G, "UnitGUID", function(unit) return "G-" .. tostring(canon(unit)) end)
		rawset(_G, "UnitCanAssist", function(a, b)
			if b == "target" then return world.target ~= nil and not world.hostile end
			return realCanAssist(a, b)
		end)
		Mock.hiddenFor = function(unit) return world.debuffs[canon(unit)] end
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		Mock.timers = {}
		Mock.secureActions = true
		Mock.eventSink = ns.addon
		ns.KeyNudge = nil
		ns.db.profile.verbose = true
		ns.db.profile.prompt.cureFight = true
		if env.single then ns.db.profile.prompt.cureFightEach = false end
		ns.Guard("probe", ns.ProbeCapabilities)
		Mock.bindings = Mock.bindings or {}
		if env.key then Mock.bindings[env.key] = COMMAND end
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
end

local function release(ns)
	Mock.inCombat = false
	ns.addon:PLAYER_REGEN_ENABLED()
	Mock.frameEvent("PLAYER_REGEN_ENABLED")
	Mock.runTimers(0)
end

local function drain()
	for _ = 1, 6 do Mock.runTimers(0.11) end
end

local function casts()
	local n = 0
	for _, e in ipairs(Mock.castLog or {}) do
		if e.spell and not e.refused then n = n + 1 end
	end
	return n
end

-- The units whose debuff the game draws on button `index`'s place now.
local function showingOn(ns, index)
	local button = ns.CureFight:Button(index)
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

local function lines(ns) return table.concat(ns.CureFightLines(), " / ") end

do
	local s = "curefight-container: forever: the game shows the debuff on the cure button in a fight, and nothing outside one"
	with(s, {}, function(ns, world)
		world.debuffs.party1 = { { kind = "Curse" } }
		if showingOn(ns, 1) ~= "" then fail(s, "the game's display shows out of a fight: " .. showingOn(ns, 1)) end
		pull(ns)
		drain()
		if world.listThrew == 0 then fail(s, "SKIPPED -- the game's list was never asked") end
		if showingOn(ns, 1) ~= "party1" then fail(s, "Gwen's curse is not shown on the cure button: '" .. showingOn(ns, 1) .. "'") end
		-- Lua knew nothing: the button itself stays out of sight.
		local look = ns.CureFight:Look()
		if look.alpha ~= 0 then fail(s, "the button was lit from nothing Lua read: " .. tostring(look.alpha)) end
		world.debuffs.party1 = nil
		Mock.frameEvent("UNIT_AURA", "party1")
		if showingOn(ns, 1) ~= "" then fail(s, "still shown once the curse is gone") end
		world.debuffs.party1 = { { kind = "Curse" } }
		release(ns)
		if showingOn(ns, 1) ~= "" then fail(s, "the game's display stays up after the fight: " .. showingOn(ns, 1)) end
	end)
end

do
	local s = "curefight-container: forever: each button's display shows only its own kinds"
	with(s, {}, function(ns, world)
		world.debuffs.party1 = { { kind = "Poison" } }
		world.debuffs.player = { { kind = "Curse" } }
		pull(ns)
		drain()
		if showingOn(ns, 1) ~= "player" then fail(s, "Remove Curse's button shows '" .. showingOn(ns, 1) .. "', not your curse alone") end
		if showingOn(ns, 2) ~= "party1" then fail(s, "Cure Poison's button shows '" .. showingOn(ns, 2) .. "', not Gwen's poison alone") end
		release(ns)
	end)
end

do
	local s = "curefight-container: forever: one button shows every kind its cures take off"
	with(s, { single = true }, function(ns, world)
		world.debuffs.party1 = { { kind = "Poison" } }
		world.debuffs.party2 = { { kind = "Curse" } }
		world.debuffs.player = { { kind = "Magic" } }
		pull(ns)
		drain()
		if showingOn(ns, 1) ~= "party1,party2" then fail(s, "the one button shows '" .. showingOn(ns, 1) .. "'") end
		release(ns)
	end)
end

do
	local s = "curefight-container: forever: an enemy targeted is never shown"
	with(s, {}, function(ns, world)
		world.debuffs.target = { { kind = "Curse" } }
		world.setTarget(nil)
		world.target, world.hostile = "target", true
		pull(ns)
		drain()
		if showingOn(ns, 1):find("target", 1, true) then fail(s, "a hostile target's curse is shown") end
		-- A friend targeted in the fight is.
		world.hostile = false
		Mock.frameEvent("PLAYER_TARGET_CHANGED")
		drain()
		if not showingOn(ns, 1):find("target", 1, true) then fail(s, "a friendly target's curse is not shown: " .. showingOn(ns, 1)) end
		release(ns)
	end)
end

do
	local s = "curefight-container: forever: one click casts nothing, the second of two casts"
	with(s, {}, function(ns, world)
		world.debuffs.party1 = { { kind = "Curse" } }
		local button, cover = ns.CureFight:Button(), ns.CureFight:Cover()
		pull(ns)
		drain()
		if not cover:IsShown() then fail(s, "no cover over the button where only the game knows") end
		if Mock.clickAt(button) == button or casts() ~= 0 then fail(s, "a single click cast") end
		-- A double click: the second, a tenth of a second later, is swallowed too.
		Mock.runTimers(0.1)
		if Mock.clickAt(button) == button or casts() ~= 0 then fail(s, "a double click cast") end
		Mock.runTimers(0.4)
		if cover:IsShown() then fail(s, "the cover stays up after the gap") end
		local hit = Mock.clickAt(button)
		if hit ~= button or casts() ~= 1 then fail(s, "the second of two clicks did not cast: " .. casts()) end
		if not cover:IsShown() then fail(s, "the cover did not go back after the cast") end
		-- A click long after: the first of two again.
		Mock.runTimers(2)
		if Mock.clickAt(button) == button or casts() ~= 1 then fail(s, "a lone click later cast") end
		if not lines(ns):find("1 cast by the second", 1, true) then fail(s, "/manners debug does not count it: " .. lines(ns)) end
		release(ns)
	end)
end

do
	local s = "curefight-container: forever: the first of two closes by itself"
	with(s, {}, function(ns)
		local button, cover = ns.CureFight:Button(), ns.CureFight:Cover()
		pull(ns)
		drain()
		Mock.clickAt(button)
		Mock.runTimers(0.4)
		if cover:IsShown() then fail(s, "the first click did not open it") end
		Mock.runTimers(1.2)
		if not cover:IsShown() then fail(s, "the cover is down a second and a half after the first click") end
		if Mock.clickAt(button) == button or casts() ~= 0 then fail(s, "a click after the moment closed cast") end
		release(ns)
	end)
end

do
	local s = "curefight-container: a click on the dark button never casts without the game's display"
	with(s, { noContainer = true }, function(ns)
		local button, cover = ns.CureFight:Button(), ns.CureFight:Cover()
		pull(ns)
		drain()
		for _ = 1, 2 do
			Mock.clickAt(button)
			Mock.runTimers(0.4)
		end
		if casts() ~= 0 then fail(s, "a click on the dark button cast") end
		if not cover:IsShown() then fail(s, "the cover came down with nobody seen") end
		release(ns)
	end)
end

do
	local s = "curefight-container: forever: a key casts at once"
	with(s, { key = "F" }, function(ns, world)
		world.debuffs.party1 = { { kind = "Curse" } }
		pull(ns)
		drain()
		Mock.pressKey("F")
		if casts() ~= 1 then fail(s, "the key did not cast") end
		release(ns)
	end)
end

do
	local s = "curefight-container: the debug line and the self-test say where the need comes from"
	local function selftest(ns)
		for _, r in ipairs(ns.Selftest.Run()) do
			if r.id == "fight.cure" and tostring(r.value):find("cure need: ", 1, true) then return tostring(r.value) end
		end
		return ""
	end
	with(s, {}, function(ns)
		if not lines(ns):find("cure need: from the game's aura display", 1, true) then fail(s, "Forever with the display: " .. lines(ns)) end
		if not selftest(ns):find("from the game's aura display", 1, true) then fail(s, "the self-test: " .. selftest(ns)) end
	end)
	with(s, { noContainer = true }, function(ns)
		if not lines(ns):find("cure need: withheld (the game's aura display refused", 1, true) then fail(s, "Forever without the display: " .. lines(ns)) end
		if not selftest(ns):find("withheld", 1, true) then fail(s, "the self-test without the display: " .. selftest(ns)) end
	end)
	with(s, { flavour = "vanilla" }, function(ns)
		if not lines(ns):find("cure need: from the auras", 1, true) then fail(s, "Classic Era: " .. lines(ns)) end
		if Mock.auraBoxes and #Mock.auraBoxes > 0 then fail(s, "the game's display was made where the auras are read") end
	end)
end
