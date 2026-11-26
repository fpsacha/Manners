-- The cure button's modifiers and its wording (Prompt/CureFight.lua,
-- Options/Look.lua, Options/Who.lua), GitHub issue 43: Shift and Ctrl on the
-- cure key and click, each casting a cure the player picks (Plain press, With
-- Shift, With Ctrl under the switch on In a fight; the class's first cure plain,
-- its second on Shift, its third on Ctrl when none is picked), the key's
-- tooltip naming them, and the switch in one place, Who to buff pointing at it.
--
-- Every name starts with "curefight-mods:".

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

local COMMAND = "CLICK MannersCureFight:LeftButton"
local COMMAND2 = "CLICK MannersCureFight2:LeftButton"
local PARTY = { party1 = { "Gwen", "Hale" }, party2 = { "Hugo", "Holt" } }
local MOTW, CURE_POISON, ABOLISH_POISON, REMOVE_CURSE = 1126, 8946, 2893, 2782
local NAMES = { [1126] = "Mark of the Wild", [8946] = "Cure Poison", [2782] = "Remove Curse", [2893] = "Abolish Poison" }
local DRUID = { MOTW, CURE_POISON, ABOLISH_POISON, REMOVE_CURSE }
local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "UnitInParty", "C_UnitAuras", "C_Spell", "UnitGUID" }

-- One session: a druid who knows Remove Curse, Cure Poison and Abolish Poison,
-- in a party of three, on WoW Forever unless env.flavour; "A button for each
-- cure" off unless env.each; env.key the key bound ("F" unless false).
-- body(ns, world): world.debuffs[unit] the unit's debuffs ({ kind = "Poison" }).
local function with(scenario, env, body)
	Mock.reset()
	Mock.setFlavour(env.flavour or "camelot")
	Mock.class = "DRUID"
	Mock.groupSize = 3
	Mock.held = { [MOTW] = true }
	local restore = strangers(PARTY)
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local world = { debuffs = {}, known = {} }
	for _, id in ipairs(env.known or DRUID) do world.known[id] = true end
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
				return { name = "Bad thing", spellId = 90000, dispelName = d.kind, expirationTime = Mock.now + 30,
					duration = 60, canActivePlayerDispel = true, isHarmful = true, auraInstanceID = 9000 + index }
			end,
		}, { __index = baseAuras }))
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
		ns.db.profile.prompt.cureFightEach = env.each == true
		ns.Guard("probe", ns.ProbeCapabilities)
		Mock.bindings = Mock.bindings or {}
		if env.key ~= false then Mock.bindings[env.key or "F"] = COMMAND end
		if env.key2 then Mock.bindings[env.key2] = COMMAND2 end
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

local function option(ns, key) return H.findOption(ns.optionsTable, key) end

local function macro(ns, index)
	local button = ns.CureFight:Button(index)
	return button and tostring(button:GetAttribute("macrotext1")) or "no button"
end

-- A choice made on the window, as the player makes it.
local function pick(ns, key, spellId)
	local control = option(ns, key)
	if not control then return false end
	control.set(nil, spellId and tostring(spellId) or "none")
	ns.addon:Tick()
	Mock.runTimers(0)
	return true
end

local function lastCast()
	local log = Mock.castLog or {}
	for i = #log, 1, -1 do
		if log[i].spell and not log[i].refused then return log[i].spell end
	end
	return nil
end

do
	local s = "curefight-mods: a druid's three cures go plain, Shift and Ctrl"
	with(s, {}, function(ns)
		local want = "/cast [mod:ctrl] Abolish Poison; [mod:shift] Cure Poison; Remove Curse"
		if macro(ns) ~= want then fail(s, "Forever's macro reads " .. macro(ns)) end
		Mock.castLog = {}
		Mock.pressKey("F")
		if lastCast() ~= "Remove Curse" then fail(s, "the plain key cast " .. tostring(lastCast())) end
		Mock.modifiers = { shift = true }
		Mock.pressKey("F")
		if lastCast() ~= "Cure Poison" then fail(s, "Shift cast " .. tostring(lastCast())) end
		Mock.modifiers = { ctrl = true }
		Mock.pressKey("F")
		if lastCast() ~= "Abolish Poison" then fail(s, "Ctrl cast " .. tostring(lastCast())) end
		Mock.modifiers = {}
	end)
	with(s, { flavour = "vanilla" }, function(ns)
		local want = "/cast [mod:ctrl,@mouseover,help,nodead][mod:ctrl,help,nodead][mod:ctrl,@player] Abolish Poison; "
			.. "[mod:shift,@mouseover,help,nodead][mod:shift,help,nodead][mod:shift,@player] Cure Poison; "
			.. "[@mouseover,help,nodead][help,nodead][@player] Remove Curse"
		if macro(ns) ~= want then fail(s, "Classic Era's macro reads " .. macro(ns)) end
		if #macro(ns) > 255 then fail(s, "the macro is over 255 characters") end
	end)
end

do
	local s = "curefight-mods: each modifier casts the cure picked for it, or nothing"
	with(s, {}, function(ns)
		local plain = option(ns, "cureFightPlain")
		if not (plain and option(ns, "cureFightShift") and option(ns, "cureFightCtrl")) then fail(s, "no Plain press, With Shift or With Ctrl") return end
		if plain.hidden() then fail(s, "Plain press is hidden from a druid with three cures") end
		local values = plain.values()
		local names = {}
		for _, name in pairs(values) do names[#names + 1] = tostring(name) end
		table.sort(names)
		if table.concat(names, ",") ~= "Abolish Poison,Cure Poison,Nothing,Remove Curse" then
			fail(s, "the choices are " .. table.concat(names, ","))
		end
		pick(ns, "cureFightPlain", CURE_POISON)
		pick(ns, "cureFightShift", nil)
		pick(ns, "cureFightCtrl", REMOVE_CURSE)
		if macro(ns) ~= "/cast [mod:ctrl] Remove Curse; [mod:shift] ; Cure Poison" then fail(s, "the macro reads " .. macro(ns)) end
		if option(ns, "cureFightShift").get() ~= "none" then fail(s, "With Shift reads " .. tostring(option(ns, "cureFightShift").get())) end
		-- Kept for this class alone: the profile is every character's.
		local mods = ns.db.profile.prompt.cureFightMods
		if not (type(mods) == "table" and type(mods.DRUID) == "table" and mods.DRUID.plain == CURE_POISON and mods.DRUID.shift == 0) then
			fail(s, "the choice is not kept under the druid's class")
		end
		-- Picking a place's own default again stores no choice.
		pick(ns, "cureFightCtrl", ABOLISH_POISON)
		if mods.DRUID and mods.DRUID.ctrl ~= nil then fail(s, "the default picked again is stored as a choice") end
		-- A choice that arrives with the profile (another profile, a reset) is armed by the next scan.
		mods.DRUID.plain = ABOLISH_POISON
		ns.addon:Tick()
		Mock.runTimers(0)
		if not macro(ns):find("; Abolish Poison$") then fail(s, "a choice from the profile is not armed: " .. macro(ns)) end
	end)
end

do
	local s = "curefight-mods: a class with one cure has no modifier choices"
	with(s, { known = { MOTW, REMOVE_CURSE } }, function(ns)
		local plain = option(ns, "cureFightPlain")
		if plain and not plain.hidden() then fail(s, "Plain press is offered for a single cure") end
		if macro(ns) ~= "/cast Remove Curse" then fail(s, "the macro reads " .. macro(ns)) end
	end)
end

do
	local s = "curefight-mods: a key bound with Ctrl casts no Ctrl clause"
	with(s, { key = "CTRL-F" }, function(ns)
		if macro(ns):find("mod:ctrl", 1, true) then fail(s, "the macro keeps Ctrl with a Ctrl key: " .. macro(ns)) end
		if not macro(ns):find("[mod:shift] Cure Poison", 1, true) then fail(s, "Shift is gone too: " .. macro(ns)) end
	end)
end

do
	local s = "curefight-mods: the key line names Ctrl for the Ctrl cure"
	with(s, { flavour = "vanilla" }, function(ns, world)
		pick(ns, "cureFightShift", nil)
		pick(ns, "cureFightCtrl", CURE_POISON)
		world.debuffs.party1 = { { kind = "Poison" } }
		Mock.inCombat = false
		ns.addon:PLAYER_REGEN_DISABLED()
		Mock.inCombat = true
		Mock.frameEvent("PLAYER_REGEN_DISABLED")
		for _ = 1, 4 do Mock.runTimers(0.11) end
		local look = ns.CureFight:Look()
		local line = look and tostring(look.key:GetText() or "") or ""
		if line ~= "point at Gwen and press Ctrl-F" then fail(s, "the key line reads '" .. line .. "'") end
		Mock.inCombat = false
		ns.addon:PLAYER_REGEN_ENABLED()
		Mock.frameEvent("PLAYER_REGEN_ENABLED")
	end)
end

do
	local s = "curefight-mods: the key's tooltip names what Shift and Ctrl cast"
	with(s, {}, function(ns)
		local key = option(ns, "cureFightKey")
		local desc = key and (type(key.desc) == "function" and key.desc() or key.desc) or ""
		if not tostring(desc):find("Hold Shift for Cure Poison, Ctrl for Abolish Poison.", 1, true) then
			local _, shift, ctrl = ns.CureFight.Chosen()
			fail(s, "the key's tooltip reads: " .. tostring(desc) .. " (choices: "
				.. tostring(shift and shift.name) .. ", " .. tostring(ctrl and ctrl.name) .. ")")
		end
		pick(ns, "cureFightShift", nil)
		key = option(ns, "cureFightKey")
		desc = key and key.desc() or ""
		if not tostring(desc):find("Hold Ctrl for Abolish Poison.", 1, true) or tostring(desc):find("Shift", 1, true) then
			fail(s, "with nothing on Shift the tooltip reads: " .. tostring(desc))
		end
	end)
end

do
	local s = "curefight-mods: A button for each cure keeps working with the modifiers"
	with(s, { each = true, key2 = "G" }, function(ns)
		if macro(ns, 2) ~= "/cast Cure Poison" then fail(s, "the second button casts " .. macro(ns, 2)) end
		if not macro(ns, 1):find("[mod:ctrl] Abolish Poison", 1, true) then fail(s, "the first button lost Ctrl: " .. macro(ns, 1)) end
		-- With Shift on Nothing, there is no second cure for a button of its own.
		pick(ns, "cureFightShift", nil)
		local second = ns.CureFight:Button(2)
		if second and second:GetAttribute("macrotext1") ~= nil then fail(s, "a second button stays armed with nothing on Shift") end
	end)
end

do
	local s = "curefight-mods: the switch is set in one place and Who to buff points at it"
	with(s, {}, function(ns)
		local who = option(ns, "curesFight")
		if not who then fail(s, "no row on Who to buff") return end
		if who.type ~= "description" then fail(s, "Who to buff draws a second switch: " .. tostring(who.type)) end
		local text = type(who.name) == "function" and who.name() or tostring(who.name)
		if not tostring(text):find("Show my cure on a button in a fight, only while somebody needs it", 1, true) then
			fail(s, "the pointer does not name the switch: " .. tostring(text))
		end
		local look = option(ns, "cureFight")
		if not (look and look.type == "toggle") then fail(s, "In a fight has no switch") end
	end)
end

do
	local s = "curefight-mods: a choice is marked as changed and In a fight's reset puts it back"
	with(s, {}, function(ns)
		local UI = ns.WindowUI
		if not (UI and UI.Differs) then fail(s, "SKIPPED -- no window to ask") return end
		local function differs(path) return UI.Differs(path, UI.Item and UI.Item(path)) end
		if differs("appearance.cureFightCtrl") then fail(s, "With Ctrl is marked with nothing picked") end
		pick(ns, "cureFightCtrl", nil)
		if not differs("appearance.cureFightCtrl") then fail(s, "With Ctrl is not marked once picked") end
		local ok, answer = pcall(ns.OptionsPage.ResetPage, "fight")
		if not ok or answer ~= true then fail(s, "the reset did not run: " .. tostring(answer)) return end
		if next(ns.db.profile.prompt.cureFightMods or {}) ~= nil then fail(s, "the choice outlives In a fight's reset") end
		ns.db.profile.prompt.cureFight = true
		ns.addon:Tick()
		Mock.runTimers(0)
		if not macro(ns):find("[mod:ctrl] Abolish Poison", 1, true) then fail(s, "the macro is not put back: " .. macro(ns)) end
	end)
end
