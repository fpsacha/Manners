-- The cure button's cover (Prompt/CureFight.lua): while the button is out of
-- sight in a fight an unprotected frame over it swallows the click, so a click
-- casts only while somebody needs a cure; it comes down when somebody does, dim
-- or bright (visible means clickable). With a key bound the button takes no
-- mouse and no cover is used. A click that reaches the button with the cover up
-- and no key bound is counted and said by /manners debug.
--
-- The mock's aura list knows no debuffs, so the session stands its own
-- C_UnitAuras in front of it, as tests/scenarios/curefight.lua does. Held to the
-- mock's model of the client (Mock.clickAt: the highest mouse-enabled frame
-- takes the click), not to the client: whether the cover swallows a click there
-- only a fight can say, which is what the leak counter is for (STATUS.md).
--
-- Every name starts with "curefight-cover:".

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

local COMMAND = "CLICK MannersCureFight:LeftButton"
local PARTY = { party1 = { "Gwen", "Hale" }, party2 = { "Hugo", "Holt" } }
local MOTW, CURE_POISON, REMOVE_CURSE = 1126, 8946, 2782
local NAMES = { [1126] = "Mark of the Wild", [8946] = "Cure Poison", [2782] = "Remove Curse" }
local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "UnitInParty", "C_UnitAuras", "C_Spell", "UnitIsUnit",
	"UnitGUID", "UnitCanAssist" }

-- One session: a druid in a party of three on Classic Era; env.key = false binds
-- no key. body(ns, world): world.debuffs[unit] is a unit's harmful auras.
local function with(scenario, env, body)
	Mock.reset()
	Mock.setFlavour("vanilla")
	Mock.class = "DRUID"
	Mock.groupSize = 3
	Mock.held = { [MOTW] = true }
	local restore = strangers(PARTY)
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local world = { debuffs = {}, known = {} }
	for _, id in ipairs({ MOTW, CURE_POISON, REMOVE_CURSE }) do world.known[id] = true end
	local ok, err = pcall(function()
		rawset(_G, "IsSpellKnown", function(id) return world.known[id] == true end)
		rawset(_G, "IsPlayerSpell", function(id) return world.known[id] == true end)
		rawset(_G, "UnitInParty", function(unit) return type(unit) == "string" and unit:find("^party%d+$") ~= nil end)
		local baseAuras, baseSpell = C_UnitAuras, C_Spell
		rawset(_G, "C_UnitAuras", setmetatable({
			GetAuraDataByIndex = function(unit, index, filter)
				if filter ~= "HARMFUL" then return baseAuras.GetAuraDataByIndex(unit, index, filter) end
				local d = world.debuffs[unit] and world.debuffs[unit][index]
				if not d then return nil end
				return { name = "Poison thing", spellId = 90000, dispelName = d.kind, expirationTime = Mock.now + d.left,
					duration = 60, canActivePlayerDispel = true, isHarmful = true, auraInstanceID = 9000 + index }
			end,
		}, { __index = baseAuras }))
		rawset(_G, "C_Spell", setmetatable({
			GetSpellName = function(id) return NAMES[id] or baseSpell.GetSpellName(id) end,
			IsSpellUsable = function()
				if world.noMana then return false, true end
				return true, false
			end,
		}, { __index = baseSpell }))
		local realIsUnit, realCanAssist = saved.UnitIsUnit or UnitIsUnit, saved.UnitCanAssist or UnitCanAssist
		rawset(_G, "UnitIsUnit", function(a, b) return realIsUnit(a, b) end)
		rawset(_G, "UnitGUID", function(unit) return "G-" .. tostring(unit) end)
		rawset(_G, "UnitCanAssist", function(a, b) return realCanAssist(a, b) end)
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		Mock.timers = {}
		Mock.secureActions = true
		Mock.eventSink = ns.addon
		ns.KeyNudge = nil
		ns.db.profile.verbose = true
		ns.db.profile.prompt.cureFight = true
		-- One button, Shift for the second cure: the poison is the first button's.
		ns.db.profile.prompt.cureFightEach = false
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

local function settle(seconds) Mock.runTimers(seconds or 0.11) end

local function drain()
	for _ = 1, 6 do settle() end
end

local function landed(unit)
	Mock.frameEvent("UNIT_AURA", unit, { addedAuras = { { isHarmful = true, dispelName = "Poison" } } })
	settle()
end

local function cleared(unit)
	Mock.frameEvent("UNIT_AURA", unit, {})
	settle()
	drain()
end

local function casts()
	local n = 0
	for _, e in ipairs(Mock.castLog or {}) do
		if e.spell and not e.refused then n = n + 1 end
	end
	return n
end

local function lineHas(ns, text)
	for _, line in ipairs(ns.CureFightLines()) do
		if line:find(text, 1, true) then return true end
	end
	return false
end

do
	local s = "curefight-cover: no key: a click while nobody needs a cure casts nothing and is counted"
	with(s, { key = false }, function(ns)
		local button, cover = ns.CureFight:Button(), ns.CureFight:Cover()
		if not (button and cover) then fail(s, "no button or no cover made") return end
		if cover:IsShown() then fail(s, "the cover stands out of a fight") end
		pull(ns)
		drain()
		if not cover:IsShown() then fail(s, "no cover over the button at the pull") end
		local hit = Mock.clickAt(button)
		if hit == button or casts() ~= 0 then fail(s, "a click with nobody in need cast") end
		if hit ~= cover then fail(s, "the cover did not take the click") end
		if not lineHas(ns, "took 1 clicks") then fail(s, "the swallowed click was not counted: " .. table.concat(ns.CureFightLines(), " / ")) end
	end)
end

do
	local s = "curefight-cover: no key: while somebody needs a cure the cover is down and a click casts"
	with(s, { key = false }, function(ns, world)
		local button, cover = ns.CureFight:Button(), ns.CureFight:Cover()
		pull(ns)
		drain()
		world.debuffs.party1 = { { kind = "Poison", left = 30 } }
		landed("party1")
		drain()
		if cover:IsShown() then fail(s, "the cover stood over a lit cure") end
		local hit = Mock.clickAt(button)
		if hit ~= button or casts() ~= 1 then fail(s, "a click on a lit cure did not cast: " .. casts()) end
		-- Cured: out of sight again, the cover back.
		world.debuffs.party1 = nil
		cleared("party1")
		if not cover:IsShown() then fail(s, "the cover did not come back when nobody needed the cure") end
		local again = Mock.clickAt(button)
		if again == button or casts() ~= 1 then fail(s, "a click after the cure cast again") end
	end)
end

do
	local s = "curefight-cover: shown dim on a cooldown or without mana it is still clickable"
	with(s, { key = false }, function(ns, world)
		local button, cover = ns.CureFight:Button(), ns.CureFight:Cover()
		world.noMana = true
		pull(ns)
		drain()
		world.debuffs.party1 = { { kind = "Poison", left = 30 } }
		landed("party1")
		drain()
		local look = ns.CureFight:Look()
		if not (look.alpha and look.alpha > 0 and look.alpha < 1) then fail(s, "not shown dim: " .. tostring(look.alpha)) end
		if cover:IsShown() then fail(s, "the cover stood over a button that is on the screen") end
		if Mock.clickAt(button) ~= button then fail(s, "a click on the dim button did not reach it") end
	end)
end

do
	local s = "curefight-cover: with a key bound there is no cover and no mouse"
	with(s, { key = "F" }, function(ns)
		local button, cover = ns.CureFight:Button(), ns.CureFight:Cover()
		pull(ns)
		drain()
		if cover:IsShown() then fail(s, "a cover with a key bound") end
		if button._mouse == true then fail(s, "the button takes the mouse with a key bound") end
		if Mock.clickAt(button) ~= "world" then fail(s, "a click beside the prompt did not reach the world") end
		Mock.pressKey("F")
		if casts() ~= 1 then fail(s, "the key did not cast") end
	end)
end

do
	local s = "curefight-cover: nothing protected is called through a fight"
	with(s, { key = false }, function(ns, world)
		local button = ns.CureFight:Button()
		Mock.protect(button)
		pull(ns)
		Mock.protectedCalls = {}
		drain()
		world.debuffs.party1 = { { kind = "Poison", left = 30 } }
		landed("party1")
		drain()
		Mock.clickAt(button)
		world.debuffs.party1 = nil
		cleared("party1")
		Mock.clickAt(button)
		if #Mock.protectedCalls > 0 then
			fail(s, "a protected call under the lockdown: " .. tostring(Mock.protectedCalls[1].method or Mock.protectedCalls[1]))
		end
		release(ns)
		if ns.CureFight:Cover():IsShown() then fail(s, "the cover stood after the fight") end
	end)
end

do
	local s = "curefight-cover: a click that gets past the cover is counted and said"
	with(s, { key = false }, function(ns)
		local button = ns.CureFight:Button()
		pull(ns)
		drain()
		Mock.coverLeaks = true
		Mock.clickAt(button)
		Mock.coverLeaks = nil
		if (ns.db.global.cureCoverLeaks or 0) ~= 1 then fail(s, "the leak was not counted on the account: " .. tostring(ns.db.global.cureCoverLeaks)) end
		if not lineHas(ns, "let 1 through") or not lineHas(ns, "1 times") then fail(s, "/manners debug does not say so: " .. table.concat(ns.CureFightLines(), " / ")) end
		local found
		for _, e in ipairs(ns.addon.db.char.trail or {}) do
			if tostring(e.text):find("the cover let a click through", 1, true) then found = true end
		end
		if not found then fail(s, "the trail does not say so") end
	end)
end

do
	local s = "curefight-cover: out of a fight the cover is hidden and the debug line says never"
	with(s, { key = false }, function(ns)
		pull(ns)
		drain()
		release(ns)
		if ns.CureFight:Cover():IsShown() then fail(s, "the cover stood after the release") end
		if not lineHas(ns, "let a click through on this account: never") then fail(s, "the debug line: " .. table.concat(ns.CureFightLines(), " / ")) end
	end)
end
