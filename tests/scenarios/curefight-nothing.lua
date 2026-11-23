-- With Shift or With Ctrl set to Nothing on the cure button (Prompt/CureFight.lua,
-- ChoseNothing and Build; GitHub issue 43): that modifier casts nothing. The
-- macro gives it an empty clause, so the press does not fall through to the
-- plain cure; a key bound with that modifier in it keeps casting.
--
-- Every name starts with "curefight-nothing:".

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

local COMMAND = "CLICK MannersCureFight:LeftButton"
local PARTY = { party1 = { "Gwen", "Hale" }, party2 = { "Hugo", "Holt" } }
local MOTW, CURE_POISON, ABOLISH_POISON, REMOVE_CURSE = 1126, 8946, 2893, 2782
local NAMES = { [1126] = "Mark of the Wild", [8946] = "Cure Poison", [2782] = "Remove Curse", [2893] = "Abolish Poison" }
local DRUID = { MOTW, CURE_POISON, ABOLISH_POISON, REMOVE_CURSE }
local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "UnitInParty", "C_Spell", "UnitGUID" }

-- A druid who knows Remove Curse, Cure Poison and Abolish Poison, in a party
-- of three, on WoW Forever unless env.flavour; env.key the key bound ("F").
local function with(scenario, env, body)
	Mock.reset()
	Mock.setFlavour(env.flavour or "camelot")
	Mock.class = "DRUID"
	Mock.groupSize = 3
	Mock.held = { [MOTW] = true }
	local restore = strangers(PARTY)
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local known = {}
	for _, id in ipairs(DRUID) do known[id] = true end
	local ok, err = pcall(function()
		rawset(_G, "IsSpellKnown", function(id) return known[id] == true end)
		rawset(_G, "IsPlayerSpell", function(id) return known[id] == true end)
		rawset(_G, "UnitInParty", function(unit) return type(unit) == "string" and unit:find("^party%d+$") ~= nil end)
		local baseSpell = C_Spell
		rawset(_G, "C_Spell", setmetatable({
			GetSpellName = function(id) return NAMES[id] or baseSpell.GetSpellName(id) end,
			IsSpellUsable = function() return true, false end,
		}, { __index = baseSpell }))
		rawset(_G, "UnitGUID", function(unit) return "G-" .. tostring(unit) end)
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		Mock.timers = {}
		Mock.secureActions = true
		Mock.eventSink = ns.addon
		ns.KeyNudge = nil
		ns.db.profile.prompt.cureFight = true
		ns.db.profile.prompt.cureFightEach = false
		ns.Guard("probe", ns.ProbeCapabilities)
		Mock.bindings = Mock.bindings or {}
		Mock.bindings[env.key or "F"] = COMMAND
		ns.addon:Tick()
		Mock.runTimers(0)
		body(ns)
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

local function macro(ns)
	local button = ns.CureFight:Button(1)
	return button and tostring(button:GetAttribute("macrotext1")) or "no button"
end

-- A choice made on the window, as the player makes it.
local function pick(ns, key, spellId)
	local control = H.findOption(ns.optionsTable, key)
	if not control then return false end
	control.set(nil, spellId and tostring(spellId) or "none")
	ns.addon:Tick()
	Mock.runTimers(0)
	return true
end

-- What a press of the key casts with `mods` held: the spell, or nil.
local function press(mods, key)
	Mock.castLog = {}
	Mock.modifiers = mods
	Mock.pressKey(key or "F")
	Mock.modifiers = {}
	for _, e in ipairs(Mock.castLog or {}) do
		if e.spell and not e.refused then return e.spell end
	end
	return nil
end

do
	local s = "curefight-nothing: Ctrl set to Nothing casts nothing"
	with(s, {}, function(ns)
		if not pick(ns, "cureFightCtrl", nil) then fail(s, "no With Ctrl control") return end
		local want = "/cast [mod:ctrl] ; [mod:shift] Cure Poison; Remove Curse"
		if macro(ns) ~= want then fail(s, "the macro reads " .. macro(ns)) end
		if press({ ctrl = true }) ~= nil then fail(s, "Ctrl cast " .. tostring(press({ ctrl = true }))) end
		if press({ shift = true }) ~= "Cure Poison" then fail(s, "Shift cast " .. tostring(press({ shift = true }))) end
		if press({}) ~= "Remove Curse" then fail(s, "the plain press cast " .. tostring(press({}))) end
	end)
	with(s, { flavour = "vanilla" }, function(ns)
		pick(ns, "cureFightCtrl", nil)
		if not macro(ns):find("^/cast %[mod:ctrl%] ; ") then fail(s, "Classic Era's macro reads " .. macro(ns)) end
		if #macro(ns) > 255 then fail(s, "the macro is over 255 characters") end
	end)
end

do
	local s = "curefight-nothing: Shift set to Nothing casts nothing"
	with(s, {}, function(ns)
		if not pick(ns, "cureFightShift", nil) then fail(s, "no With Shift control") return end
		local want = "/cast [mod:ctrl] Abolish Poison; [mod:shift] ; Remove Curse"
		if macro(ns) ~= want then fail(s, "the macro reads " .. macro(ns)) end
		if press({ shift = true }) ~= nil then fail(s, "Shift cast " .. tostring(press({ shift = true }))) end
		if press({ ctrl = true }) ~= "Abolish Poison" then fail(s, "Ctrl cast " .. tostring(press({ ctrl = true }))) end
	end)
end

do
	local s = "curefight-nothing: a key bound with Ctrl keeps casting with Ctrl on Nothing"
	with(s, { key = "CTRL-F" }, function(ns)
		pick(ns, "cureFightCtrl", nil)
		if macro(ns):find("mod:ctrl", 1, true) then fail(s, "the Ctrl key's own press is swallowed: " .. macro(ns)) end
		if press({ ctrl = true }, "CTRL-F") ~= "Remove Curse" then fail(s, "the Ctrl key cast " .. tostring(press({ ctrl = true }, "CTRL-F"))) end
	end)
end
