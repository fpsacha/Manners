-- Your cure in a fight (Prompt/CureFight.lua): a button of its own beside the
-- prompt, with a key of its own, that is out of sight (alpha 0, no tooltip, no
-- highlight) for every fight until Manners has detected in the fight somebody
-- near you carrying something the cure takes off, then fades in naming the
-- spell, who and why, and fades out again once nobody needs it.
--
-- The mock's aura list knows no debuffs, so each session stands its own
-- C_UnitAuras in front of it (as tests/scenarios/cures.lua does): a harmful
-- read answers from `world.debuffs`, by unit token, and is counted in
-- `world.reads` (every GetAuraDataByIndex call: one walk of a unit wearing k
-- debuffs is k + 1 calls). world.secret hands every harmful slot back secret,
-- as Forever and retail do in a fight.
--
-- These hold Manners to the mock's model of the client (the state driver and
-- the restricted snippet in tests/mockwidgets.lua, the macro run by a secure
-- click and its conditionals in tests/mockmacros.lua and tests/mockapi.lua),
-- not to the client: whether Forever and retail hand back a player's own
-- debuffs plain in a fight, and what the alpha-0 button does to a click, only
-- a fight can say (STATUS.md).
--
-- Every name starts with "curefight:".

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

local COMMAND = "CLICK MannersCureFight:LeftButton"
local COMMAND2 = "CLICK MannersCureFight2:LeftButton"
local PROMPT_KEY = "CLICK MannersPrompt:LeftButton"

-- Two others in a party of three.
local PARTY = {
	party1 = { "Gwen", "Hale" },
	party2 = { "Hugo", "Holt" },
}

local MOTW, CURE_POISON, REMOVE_CURSE = 1126, 8946, 2782
local DRUID = { MOTW, CURE_POISON, REMOVE_CURSE }

-- The names the client gives each spell, on the clients the scenarios use.
local NAMES = {
	[1126] = "Mark of the Wild", [8946] = "Cure Poison", [2782] = "Remove Curse",
	[475] = "Remove Lesser Curse", [988] = "Dispel Magic", [528] = "Cure Disease",
	[4987] = "Cleanse", [1152] = "Purify", [526] = "Cure Poison", [2870] = "Cure Disease",
}

local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "UnitInParty", "C_UnitAuras", "C_Spell", "UnitIsUnit",
	"UnitGUID", "UnitCanAssist", "UnitIsDeadOrGhost", "UnitIsConnected" }

local function debuff(kind, left, id, can, name)
	return { kind = kind, ends = Mock.now + (left or 0), id = id or 90000, can = can, name = name or ((kind or "Plain") .. " thing") }
end

-- One session, a druid in a party of three on Classic Era unless `env` says
-- otherwise:
--   env.flavour     the client (vanilla)
--   env.class       the player's class (DRUID)
--   env.known       spell ids known (DRUID)
--   env.names       the units that exist, by token (PARTY)
--   env.spellNames  spell names that replace NAMES
--   env.key         the key bound to the button ("F"; false: none)
--   env.keep        leave the switch as a new profile has it (on)
--   env.watchLoad   world.loadAsked lists what CureFight asked the client up to
--                   and in the first scan
--   env.owe         a person on a nameplate the prompt owes a buff
--   env.raid        { size, names } a raid of that many, in place of the party
--   env.single      "A button for each cure" off: one button, Shift for the second
--   env.dispelList  the stub C_UnitAuras has the game's own list of the debuffs
--                   you can remove (GetUnitAuraInstanceIDs, "HARMFUL|RAID"):
--                   world.listSecret withholds it, world.listReads counts it
-- body(ns, world): world.debuffs[unit] is that unit's harmful auras, in the
-- client's order; world.reads counts the harmful reads asked of the client, in
-- all (`n`) and by unit; world.setTarget(token, hostile) puts your target on a
-- unit; world.dead and world.offline are sets of tokens.
local function with(scenario, env, body)
	Mock.reset()
	Mock.setFlavour(env.flavour or "vanilla")
	Mock.class = env.class or "DRUID"
	Mock.groupSize = env.group or 3
	Mock.held = { [MOTW] = true }
	local names = {}
	for token, pair in pairs(env.names or PARTY) do names[token] = pair end
	if env.owe then names.nameplate1 = { "Anna", "Aim" } end
	if env.raid then
		Mock.raid = { size = env.raid, player = 1 }
		names = {}
		for i = 1, env.raid do names["raid" .. i] = { "Raider" .. i, "Test" } end
	end
	local restore = strangers(names)
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local callsReal = InCombatLockdown
	local world = { debuffs = {}, reads = { n = 0 }, known = {}, names = names, dead = {}, offline = {},
		spellNames = {}, ids = {}, loadAsked = {}, listReads = {} }
	for id, name in pairs(NAMES) do world.spellNames[id] = name end
	for id, name in pairs(env.spellNames or {}) do world.spellNames[id] = name end
	for _, id in ipairs(env.known or DRUID) do world.known[id] = true end
	local function canon(unit)
		if unit == "target" then return world.target or "target" end
		return unit
	end
	function world.setTarget(token, hostile)
		world.target, world.hostile = token, hostile == true
		names.target = token and (hostile and { "Grunt", "Hide" } or names[token]) or nil
	end
	function world.resetReads()
		for key in pairs(world.reads) do world.reads[key] = nil end
		world.reads.n = 0
	end
	local ok, err = pcall(function()
		rawset(_G, "IsSpellKnown", function(id) return world.known[id] == true end)
		rawset(_G, "IsPlayerSpell", function(id) return world.known[id] == true end)
		rawset(_G, "UnitInParty", function(unit)
			return type(unit) == "string" and unit:find("^party%d+$") ~= nil
		end)
		local baseAuras, baseSpell = C_UnitAuras, C_Spell
		local stub = {
			GetAuraDataByIndex = function(unit, index, filter)
				if filter ~= "HARMFUL" then return baseAuras.GetAuraDataByIndex(unit, index, filter) end
				local reads = world.reads
				reads.n = reads.n + 1
				reads[unit] = (reads[unit] or 0) + 1
				if world.secret then return Mock.SECRET end
				local list = world.debuffs[canon(unit)]
				local d = list and list[index]
				if not d then return nil end
				return {
					name = d.name, spellId = d.id, dispelName = d.kind, expirationTime = d.ends,
					duration = 60, canActivePlayerDispel = d.can, isHarmful = true, auraInstanceID = 9000 + index,
				}
			end,
		}
		if env.dispelList then
			stub.GetUnitAuraInstanceIDs = function(unit, filter)
				world.listReads[unit] = (world.listReads[unit] or 0) + 1
				world.listFilter = filter
				if world.listSecret then return Mock.SECRET end
				local out = {}
				for i, d in ipairs(world.debuffs[canon(unit)] or {}) do
					if d.kind and d.can ~= false then out[#out + 1] = 9000 + i end
				end
				return out
			end
		end
		rawset(_G, "C_UnitAuras", setmetatable(stub, { __index = baseAuras }))
		rawset(_G, "C_Spell", setmetatable({
			GetSpellName = function(id) return world.spellNames[id] or baseSpell.GetSpellName(id) end,
			IsSpellUsable = function()
				if world.noMana then return false, true end
				return true, false
			end,
		}, { __index = baseSpell }))
		local realIsUnit, realCanAssist = saved.UnitIsUnit or UnitIsUnit, saved.UnitCanAssist or UnitCanAssist
		rawset(_G, "UnitIsUnit", function(a, b) return realIsUnit(canon(a), canon(b)) end)
		rawset(_G, "UnitGUID", function(unit) return "G-" .. tostring(canon(unit)) end)
		rawset(_G, "UnitCanAssist", function(a, b)
			if b == "target" then return world.target ~= nil and not world.hostile end
			return realCanAssist(a, b)
		end)
		local realDead, realConn = saved.UnitIsDeadOrGhost or UnitIsDeadOrGhost, saved.UnitIsConnected or UnitIsConnected
		rawset(_G, "UnitIsDeadOrGhost", function(unit)
			if world.dead[canon(unit)] then return true end
			return realDead(unit)
		end)
		rawset(_G, "UnitIsConnected", function(unit)
			if world.offline[canon(unit)] then return false end
			return realConn(unit)
		end)
		-- The first scans (the load's, the one below): what the fight's cure asked
		-- the client in them (a call to a mock made by its Wanted or Refresh).
		if env.watchLoad then
			debug.sethook(function()
				local callee, caller = debug.getinfo(2, "nS"), debug.getinfo(3, "nS")
				if callee and caller and tostring(callee.source):find("tests[/\]mock")
					and tostring(caller.source):find("Prompt[/\]CureFight")
					and (caller.name == "Wanted" or caller.name == "Refresh") and callee.name ~= "issecretvalue" then
					world.loadAsked[#world.loadAsked + 1] = tostring(callee.name)
				end
			end, "c")
		end
		local ns = load(scenario)
		if not ns then debug.sethook() return end
		-- A profile that switched it off from the start: the default the load
		-- reads is false, so nothing is made at login.
		if env.off then ns.defaults.profile.prompt.cureFight = false end
		-- A profile with it switched on from the start (off by default since
		-- 1.12): the load reads true, as a player who ticked it has.
		if env.on then ns.defaults.profile.prompt.cureFight = true end
		freshPrompt(ns, scenario)
		Mock.timers = {}
		Mock.secureActions = true
		Mock.eventSink = ns.addon
		ns.KeyNudge = nil
		ns.db.profile.verbose = true
		if env.off then ns.db.profile.prompt.cureFight = false
		elseif not env.keep then ns.db.profile.prompt.cureFight = true end
		if env.single then ns.db.profile.prompt.cureFightEach = false end
		ns.Guard("probe", ns.ProbeCapabilities)
		Mock.bindings = Mock.bindings or {}
		if env.key ~= false then Mock.bindings[env.key or "F"] = COMMAND end
		if env.owe then owe(ns, "Anna Aim") end
		ns.addon:Tick()
		Mock.runTimers(0)
		debug.sethook()
		world.resetReads()
		body(ns, world)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	Mock.inCombat = false
	Mock.modifiers = {}
	Mock.mouseover = nil
	InCombatLockdown = callsReal
	restore()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- The pull as the client orders it (tests/scenarios/fight-rota.lua), and the
-- first flushes of the reads it asks for.
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

-- One flush of reads.
local function settle(seconds)
	Mock.runTimers(seconds or 0.11)
end

-- Everything the pull asks for, however many flushes it takes.
local function drain(n)
	for _ = 1, n or 6 do settle() end
end

-- A harmful aura landing on `unit`, and the flush it asks for.
local function landed(unit)
	Mock.frameEvent("UNIT_AURA", unit, { addedAuras = { { isHarmful = true, dispelName = "Poison" } } })
	settle()
end

-- What a button shows (the first, or `index`): its alpha (the fade's target),
-- its glow, and its two lines.
local function shows(ns, index)
	local look = ns.CureFight:Look(index)
	if not look then return nil, false, "", "" end
	return look.alpha, look.glow:IsShown() == true, tostring(look.name:GetText() or ""), tostring(look.key:GetText() or "")
end

local function castsSince(n)
	local out = {}
	for i = n + 1, #Mock.castLog do
		local e = Mock.castLog[i]
		if e.spell and not e.refused then out[#out + 1] = e end
	end
	return out
end

local function printedHas(text)
	for _, line in ipairs(Mock.printed or {}) do
		if tostring(line):find(text, 1, true) then return true end
	end
	return false
end

local function option(ns, key)
	return H.findOption(ns.optionsTable, key)
end

local function hidden(node)
	if type(node.hidden) == "function" then return node.hidden() == true end
	return node.hidden == true
end

local DRUID_MACRO = "/cast [mod:shift,@mouseover,help,nodead][mod:shift,help,nodead][mod:shift,@player] Cure Poison; "
	.. "[@mouseover,help,nodead][help,nodead][@player] Remove Curse"

-- ------------------------------------------------------------------ 1
with("curefight: off out of the box; switched on, nothing shown until needed", { keep = true }, function(ns)
	local scenario = "curefight: off out of the box; switched on, nothing shown until needed"
	-- Off in a new profile since 1.12; switched on here, it still shows nothing
	-- until somebody needs a cure.
	if ns.db.profile.prompt.cureFight ~= false then fail(scenario, "the switch is " .. tostring(ns.db.profile.prompt.cureFight) .. " in a new profile") end
	ns.db.profile.prompt.cureFight = true
	ns.Guard("cure in a fight", ns.CureFight.Refresh, ns.CureFight)
	local button = ns.CureFight:Button()
	if not button then fail(scenario, "no button for a druid in a new profile") return end
	if button:IsShown() then fail(scenario, "shown out of a fight with nobody in need") end
	pull(ns)
	drain()
	local alpha = shows(ns)
	if alpha ~= nil and alpha > 0 then fail(scenario, "visible (alpha " .. tostring(alpha) .. ") in a fight with nobody needing a cure") end
	if button:GetAlpha() > 0 then fail(scenario, "the button's alpha is " .. tostring(button:GetAlpha()) .. " with nobody in need") end
end)

-- ------------------------------------------------------------------ 1b
with("curefight: switched off in the profile, nothing is made", { keep = true, off = true }, function(ns)
	local scenario = "curefight: switched off in the profile, nothing is made"
	if ns.db.profile.prompt.cureFight ~= false then fail(scenario, "the switch is " .. tostring(ns.db.profile.prompt.cureFight)) end
	ns.addon:Tick()
	if rawget(_G, "MannersCureFight") ~= nil or (Mock.namedFrames and Mock.namedFrames.MannersCureFight) then
		fail(scenario, "a frame was made with the switch off")
	end
	local lines = table.concat(ns.CureFightLines(), " / ")
	if not lines:find("switch off", 1, true) then fail(scenario, "the debug line does not say it is off: " .. lines) end
end)

-- ------------------------------------------------------------------ 2
with("curefight: armed out of combat, shown by its own driver at alpha 0, nothing protected from Lua", { single = true }, function(ns, world)
	local scenario = "curefight: armed out of combat, shown by its own driver at alpha 0, nothing protected from Lua"
	local button = ns.CureFight:Button()
	if not button then fail(scenario, "no button for a druid with the switch on") return end
	if button:GetAttribute("type1") ~= "macro" or button:GetAttribute("macrotext1") ~= DRUID_MACRO then
		fail(scenario, "not armed with the druid's macro out of combat: " .. tostring(button:GetAttribute("macrotext1")))
	end
	if button:IsShown() then fail(scenario, "shown out of a fight") end
	Mock.protect(button)
	pull(ns)
	if not button:IsShown() then fail(scenario, "its driver did not show it at the pull") end
	if button:GetAlpha() ~= 0 then fail(scenario, "shown at the pull with alpha " .. tostring(button:GetAlpha())) end
	Mock.protectedCalls = {}
	-- A poison lands and is cured: lit and dark again, all by alpha and its own regions.
	world.debuffs.party1 = { debuff("Poison", 30) }
	landed("party1")
	if (shows(ns)) ~= 1 then fail(scenario, "SKIPPED -- not lit for a poison") end
	world.debuffs.party1 = nil
	Mock.frameEvent("UNIT_AURA", "party1", { removedAuraInstanceIDs = { 1 } })
	settle()
	for _ = 1, 3 do
		Mock.advance(0.4)
		ns.addon:Tick()
		Mock.runTimers(1)
	end
	local switch = option(ns, "cureFight")
	if switch then
		switch.set({ "appearance", "cureFight" }, false)
		switch.set({ "appearance", "cureFight" }, true)
	end
	ns.Prompt:Refresh()
	if #Mock.protectedCalls > 0 then
		fail(scenario, "Lua called " .. table.concat(Mock.protectedCalls, ", ") .. " on the cure button in the fight")
	end
	if not button:IsShown() or button:GetAttribute("macrotext1") ~= DRUID_MACRO then
		fail(scenario, "the fight left it hidden or disarmed")
	end
	release(ns)
	if button:IsShown() then fail(scenario, "still shown after the fight") end
end)

-- ------------------------------------------------------------------ 3
with("curefight: nothing shows until somebody needs a cure", {}, function(ns)
	local scenario = "curefight: nothing shows until somebody needs a cure"
	pull(ns)
	drain()
	Mock.runTimers(2)
	local alpha, glow, name, key = shows(ns)
	if alpha ~= 0 or glow or name ~= "" or key ~= "" then
		fail(scenario, ("lit for nobody: alpha %s, glow %s, lines '%s' / '%s'"):format(tostring(alpha), tostring(glow), name, key))
	end
	release(ns)
end)

-- ------------------------------------------------------------------ 4
with("curefight: somebody poisoned at the pull shows at once", { single = true }, function(ns, world)
	local scenario = "curefight: somebody poisoned at the pull shows at once"
	world.debuffs.party1 = { debuff("Poison", 30) }
	pull(ns)
	settle()
	local alpha, glow, name, key = shows(ns)
	if alpha ~= 1 or not glow then fail(scenario, ("not lit: alpha %s, glow %s"):format(tostring(alpha), tostring(glow))) end
	for _, word in ipairs({ "Cure Poison", "Gwen", "Poisoned" }) do
		if not name:find(word, 1, true) then fail(scenario, "its name line lacks " .. word .. ": " .. name) end
	end
	if key ~= "point at Gwen and press Shift-F" then fail(scenario, "its key line reads " .. key) end
	release(ns)
end)

-- ------------------------------------------------------------------ 5
with("curefight: a debuff that lands in the fight shows, and it fades once the debuff is gone", {}, function(ns, world)
	local scenario = "curefight: a debuff that lands in the fight shows, and it fades once the debuff is gone"
	pull(ns)
	drain()
	if (shows(ns)) ~= 0 then fail(scenario, "SKIPPED -- lit before any debuff") return end
	world.debuffs.party2 = { debuff("Curse", 30) }
	landed("party2")
	local alpha, _, name = shows(ns)
	if alpha ~= 1 or not name:find("Hugo", 1, true) then fail(scenario, "not shown for the curse that landed: " .. tostring(alpha) .. " " .. name) end
	world.debuffs.party2 = nil
	Mock.frameEvent("UNIT_AURA", "party2", { removedAuraInstanceIDs = { 1 } })
	settle()
	local a2, g2, n2, k2 = shows(ns)
	if a2 ~= 0 or g2 or n2 ~= "" or k2 ~= "" then fail(scenario, "still shown once the curse was gone: " .. tostring(a2) .. " " .. n2) end
	release(ns)
end)

-- ------------------------------------------------------------------ 6
with("curefight: it fades when the debuff runs out with no event", {}, function(ns, world)
	local scenario = "curefight: it fades when the debuff runs out with no event"
	world.debuffs.party1 = { debuff("Curse", 10) }
	pull(ns)
	settle()
	if (shows(ns)) ~= 1 then fail(scenario, "SKIPPED -- not shown for a ten-second curse") return end
	Mock.advance(11)
	Mock.runTimers(0.5)
	settle()
	local alpha = shows(ns)
	if alpha ~= 0 then fail(scenario, "still shown eleven seconds on, alpha " .. tostring(alpha)) end
	release(ns)
end)

-- ------------------------------------------------------------------ 7
with("curefight: your target is named first", {}, function(ns, world)
	local scenario = "curefight: your target is named first"
	world.setTarget("party2")
	world.debuffs.party1 = { debuff("Curse", 30) }
	world.debuffs.party2 = { debuff("Curse", 20) }
	pull(ns)
	settle()
	local alpha, _, name, key = shows(ns)
	if alpha ~= 1 then fail(scenario, "SKIPPED -- not shown") return end
	if not name:find("Hugo", 1, true) or not name:find("and 1 more", 1, true) then fail(scenario, "its name line reads " .. name) end
	if key ~= "press F to cure your target" then fail(scenario, "its key line reads " .. key) end
	release(ns)
end)

-- ------------------------------------------------------------------ 8
with("curefight: on yourself the key line says so", {}, function(ns, world)
	local scenario = "curefight: on yourself the key line says so"
	world.debuffs.player = { debuff("Curse", 30) }
	pull(ns)
	settle()
	local alpha, _, name, key = shows(ns)
	if alpha ~= 1 then fail(scenario, "SKIPPED -- not shown for a curse on you") return end
	if not name:find("You", 1, true) then fail(scenario, "its name line does not say you: " .. name) end
	if key ~= "press F to cure yourself" then fail(scenario, "its key line reads " .. key) end
	-- A friendly target who is not cursed: a press would go to them.
	world.setTarget("party1")
	Mock.frameEvent("PLAYER_TARGET_CHANGED")
	settle()
	local _, _, _, key2 = shows(ns)
	if key2 ~= "point at yourself and press F" then fail(scenario, "with a friend targeted its key line reads " .. key2) end
	-- A dead friend targeted: the macro's [nodead] passes them over, so a press
	-- lands on you.
	world.dead.party2 = true
	world.setTarget("party2")
	Mock.frameEvent("PLAYER_TARGET_CHANGED")
	settle()
	local _, _, _, key3 = shows(ns)
	if key3 ~= "press F to cure yourself" then fail(scenario, "with a dead friend targeted its key line reads " .. key3) end
	release(ns)
end)

-- Forever's bare cast does go to a dead friend, so it says so.
with("curefight: forever: a dead friend targeted still takes a bare cast", { flavour = "camelot", class = "MAGE",
	known = { 475 } }, function(ns, world)
	local scenario = "curefight: forever: a dead friend targeted still takes a bare cast"
	world.dead.party1 = true
	world.setTarget("party1")
	world.debuffs.player = { debuff("Curse", 30) }
	pull(ns)
	settle()
	local alpha, _, _, key = shows(ns)
	if alpha ~= 1 then fail(scenario, "SKIPPED -- not shown for a curse on you") return end
	if key ~= "target yourself and press F" then fail(scenario, "its key line reads " .. key) end
	release(ns)
end)

-- ------------------------------------------------------------------ 9
do
	local scenario = "curefight: what the cure cannot take off, a debuff never removed, one about to end or one the client says no to is never shown"
	local function never(label, env, debuffs)
		with(scenario, env, function(ns, world)
			world.debuffs.party1 = debuffs()
			pull(ns)
			drain(2)
			local alpha, glow, name = shows(ns)
			if alpha ~= 0 or glow or name ~= "" then fail(scenario, label .. ": shown, " .. tostring(alpha) .. " " .. name) end
			release(ns)
		end)
	end
	never("(a) magic for a druid on the older clients", {}, function() return { debuff("Magic", 30) } end)
	never("(b) Delusions of Jin'do alone", {}, function() return { debuff("Curse", 30, 24306) } end)
	never("(c) a debuff with a second left", {}, function() return { debuff("Curse", 1) } end)
	never("(d) one the client says you cannot remove", {}, function() return { debuff("Curse", 30, nil, false) } end)
	never("(e) Cleanse would lift Unstable Affliction too", { class = "PALADIN", known = { 4987 } },
		function() return { debuff("Magic", 30, 427717, nil, "Unstable Affliction"), debuff("Poison", 30) } end)
	with(scenario, { single = true }, function(ns, world)
		world.debuffs.party1 = { debuff("Curse", 30, 24306), debuff("Poison", 30) }
		pull(ns)
		settle()
		local alpha, _, name, key = shows(ns)
		if alpha ~= 1 or not name:find("Cure Poison", 1, true) then
			fail(scenario, "(f) a poison beside Delusions is not offered Cure Poison: " .. tostring(alpha) .. " " .. name)
		end
		if not key:find("Shift-F", 1, true) then fail(scenario, "(f) its key line reads " .. key) end
		release(ns)
	end)
end

-- ------------------------------------------------------------------ 10
with("curefight: somebody out of reach is not shown", {}, function(ns, world)
	local scenario = "curefight: somebody out of reach is not shown"
	world.debuffs.party1 = { debuff("Curse", 60) }
	Mock.rangeByUnit = { party1 = false }
	pull(ns)
	settle()
	if (shows(ns)) ~= 0 then fail(scenario, "shown for somebody out of reach") end
	-- Back in reach with no aura event: the recheck finds them.
	Mock.rangeByUnit = nil
	Mock.runTimers(0.6)
	if (shows(ns)) ~= 1 then fail(scenario, "not shown once they came back into reach") end
	release(ns)
end)

-- ------------------------------------------------------------------ 11
with("curefight: a dead or offline member is not shown", {}, function(ns, world)
	local scenario = "curefight: a dead or offline member is not shown"
	world.debuffs.party1 = { debuff("Curse", 60) }
	world.debuffs.party2 = { debuff("Curse", 60) }
	world.dead.party1 = true
	world.offline.party2 = true
	pull(ns)
	drain(2)
	local alpha, _, name = shows(ns)
	if alpha ~= 0 then fail(scenario, "shown for a dead or offline member: " .. tostring(alpha) .. " " .. name) end
	release(ns)
end)

-- ------------------------------------------------------------------ 12
with("curefight: a druid's second cure is on Shift", { single = true }, function(ns)
	local scenario = "curefight: a druid's second cure is on Shift"
	local macro = ns.CureFight:Button():GetAttribute("macrotext1")
	if macro ~= DRUID_MACRO then fail(scenario, "the druid's macro reads " .. tostring(macro)) end
end)
with("curefight: a druid's second cure is on Shift", { single = true, class = "PRIEST", known = { 988, 528 } }, function(ns)
	local scenario = "curefight: a druid's second cure is on Shift"
	local macro = ns.CureFight:Button():GetAttribute("macrotext1")
	local want = "/cast [mod:shift,@mouseover,help,nodead][mod:shift,help,nodead][mod:shift,@player] Cure Disease; "
		.. "[@mouseover,help,nodead][help,nodead][@player] Dispel Magic"
	if macro ~= want then fail(scenario, "the priest's macro reads " .. tostring(macro)) end
end)

-- ------------------------------------------------------------------ 13
with("curefight: the key line names Shift for the second cure", { single = true }, function(ns, world)
	local scenario = "curefight: the key line names Shift for the second cure"
	world.debuffs.party1 = { debuff("Poison", 30) }
	pull(ns)
	settle()
	local _, _, _, poison = shows(ns)
	if poison ~= "point at Gwen and press Shift-F" then fail(scenario, "for a poison the key line reads " .. poison) end
	world.debuffs.party1 = { debuff("Curse", 30) }
	landed("party1")
	local _, _, _, curse = shows(ns)
	if curse ~= "point at Gwen and press F" then fail(scenario, "for a curse the key line reads " .. curse) end
	release(ns)
end)
with("curefight: the key line names Shift for the second cure", { single = true, key = false }, function(ns, world)
	local scenario = "curefight: the key line names Shift for the second cure"
	world.debuffs.party1 = { debuff("Poison", 30) }
	pull(ns)
	settle()
	local _, _, _, poison = shows(ns)
	if poison ~= "point at Gwen and shift-click" then fail(scenario, "with no key, for a poison it reads " .. poison) end
	world.debuffs.party1 = { debuff("Curse", 30) }
	landed("party1")
	local _, _, _, curse = shows(ns)
	if curse ~= "point at Gwen and click" then fail(scenario, "with no key, for a curse it reads " .. curse) end
	release(ns)
end)

-- ------------------------------------------------------------------ 14
for _, flavour in ipairs({ "vanilla", "tbc", "mists", "mainline" }) do
	local env = { flavour = flavour, single = true }
	if flavour == "mists" then
		env.known = { 88423, 2782 }
		env.spellNames = { [88423] = "Nature's Cure", [2782] = "Remove Corruption" }
	elseif flavour == "mainline" then
		env.known = { 88423, 2782 }
		env.spellNames = { [88423] = "Nature's Cure", [2782] = "Remove Corruption" }
	end
	with("curefight: the macro cures your mouseover, else your target, else you (" .. flavour .. ")", env, function(ns)
		local scenario = "curefight: the macro cures your mouseover, else your target, else you (" .. flavour .. ")"
		local list = ns.CureFightSpells()
		if not (list and list[1]) then fail(scenario, "SKIPPED -- no cure learned") return end
		local function press(label, want, spell)
			local before = #Mock.castLog
			Mock.pressBinding(COMMAND)
			local casts = castsSince(before)
			if #casts ~= 1 then fail(scenario, label .. ": " .. #casts .. " casts") return end
			if casts[1].spell ~= spell then fail(scenario, label .. ": cast " .. tostring(casts[1].spell) .. ", not " .. spell) end
			if casts[1].onto ~= want then fail(scenario, label .. ": cast at " .. tostring(casts[1].onto) .. ", not " .. want) end
		end
		Mock.modifiers = Mock.modifiers or {}
		Mock.mouseover = { name = "Mo" }
		Mock.runTarget = { name = "Tess" }
		press("a friend under the mouse", "mouseover", list[1].name)
		Mock.mouseover = nil
		press("no mouse, a friendly target", "target", list[1].name)
		Mock.runTarget = { name = "Grunt", hostile = true }
		press("a hostile target", "player", list[1].name)
		Mock.runTarget = { name = "Tess", dead = true }
		press("a dead friendly target", "player", list[1].name)
		Mock.runTarget = nil
		press("nobody", "player", list[1].name)
		if list[2] then
			Mock.modifiers.shift = true
			press("with Shift held", "player", list[2].name)
			Mock.modifiers.shift = false
		end
	end)
end

-- ------------------------------------------------------------------ 15
with("curefight: forever: the macro is a bare cast", { single = true, flavour = "camelot" }, function(ns)
	local scenario = "curefight: forever: the macro is a bare cast"
	local macro = ns.CureFight:Button():GetAttribute("macrotext1")
	if macro ~= "/cast [mod:shift] Cure Poison; Remove Curse" then fail(scenario, "the druid's macro reads " .. tostring(macro)) end
end)
with("curefight: forever: the macro is a bare cast", { flavour = "camelot", class = "MAGE", known = { 475 } }, function(ns)
	local scenario = "curefight: forever: the macro is a bare cast"
	local macro = ns.CureFight:Button():GetAttribute("macrotext1")
	if macro ~= "/cast Remove Lesser Curse" then fail(scenario, "the mage's macro reads " .. tostring(macro)) end
end)

-- ------------------------------------------------------------------ 16
with("curefight: forever: the game hides debuffs, nothing is read of the group and nothing shows", { flavour = "camelot" }, function(ns, world)
	local scenario = "curefight: forever: the game hides debuffs, nothing is read of the group and nothing shows"
	world.secret = true
	world.debuffs.party1 = { debuff("Poison", 30) }
	pull(ns)
	drain(2)
	if (world.reads.party1 or 0) ~= 0 then fail(scenario, "the group was read " .. tostring(world.reads.party1) .. " times") end
	local alpha, glow, name = shows(ns)
	if alpha ~= 0 or glow or name ~= "" then fail(scenario, "shown with every aura withheld: " .. tostring(alpha) .. " " .. name) end
	local line = ns.CureFightLines()[2] or ""
	if not line:find("%d+ reads, [1-9]%d* withheld") then fail(scenario, "the debug line does not count the withheld reads: " .. line) end
	local before = #Mock.castLog
	Mock.pressBinding(COMMAND)
	local casts = castsSince(before)
	if #casts ~= 1 or casts[1].spell ~= "Remove Curse" then
		fail(scenario, "its key did not cast: " .. #casts .. " casts, " .. tostring(casts[1] and casts[1].spell))
	end
	release(ns)
end)

-- ------------------------------------------------------------------ 17
with("curefight: forever: a debuff the client hands back plain on you shows", { flavour = "camelot" }, function(ns, world)
	local scenario = "curefight: forever: a debuff the client hands back plain on you shows"
	world.debuffs.player = { debuff("Curse", 30) }
	pull(ns)
	settle()
	local alpha, _, _, key = shows(ns)
	if alpha ~= 1 then fail(scenario, "not shown for a plain curse on you") return end
	if key ~= "press F to cure yourself" then fail(scenario, "its key line reads " .. key) end
	release(ns)
end)

-- ------------------------------------------------------------------ 18
with("curefight: retail: the game hides debuffs and nothing shows", { flavour = "mainline", known = { 88423, 2782 },
	spellNames = { [88423] = "Nature's Cure", [2782] = "Remove Corruption" } }, function(ns, world)
	local scenario = "curefight: retail: the game hides debuffs and nothing shows"
	local macro = ns.CureFight:Button():GetAttribute("macrotext1") or ""
	if not macro:find("@mouseover", 1, true) then fail(scenario, "retail's macro is not the conditional one: " .. macro) end
	world.secret = true
	world.debuffs.party1 = { debuff("Magic", 30) }
	pull(ns)
	drain(2)
	if (world.reads.party1 or 0) ~= 0 then fail(scenario, "the group was read on retail") end
	local alpha, glow, name = shows(ns)
	if alpha ~= 0 or glow or name ~= "" then fail(scenario, "shown with every aura withheld: " .. tostring(alpha) .. " " .. name) end
	release(ns)
end)

-- ------------------------------------------------------------------ 19
with("curefight: a raid's buffs in a fight read nobody's debuffs", { raid = 40 }, function(ns, world)
	local scenario = "curefight: a raid's buffs in a fight read nobody's debuffs"
	pull(ns)
	drain(8)
	world.resetReads()
	local timers = #Mock.timers
	for i = 1, 200 do
		Mock.frameEvent("UNIT_AURA", "raid" .. (((i - 1) % 40) + 1), { addedAuras = { { isHarmful = false } } })
	end
	if world.reads.n ~= 0 then fail(scenario, "200 buffs in a raid asked for " .. world.reads.n .. " reads") end
	if #Mock.timers ~= timers then fail(scenario, "buffs in a raid queued a timer") end
	settle()
	if world.reads.n ~= 0 then fail(scenario, "a flush read " .. world.reads.n .. " times for buffs") end
	release(ns)
end)

-- ------------------------------------------------------------------ 20
with("curefight: a burst of debuffs is read once a person", {}, function(ns, world)
	local scenario = "curefight: a burst of debuffs is read once a person"
	world.debuffs.party1 = { debuff("Poison", 30) }
	world.debuffs.party2 = { debuff("Poison", 30) }
	world.debuffs.player = { debuff("Poison", 30) }
	pull(ns)
	drain(3)
	world.resetReads()
	for i = 1, 30 do
		local unit = ({ "party1", "party2", "player" })[(i % 3) + 1]
		Mock.frameEvent("UNIT_AURA", unit, { addedAuras = { { isHarmful = true, dispelName = "Poison" } } })
	end
	settle()
	for _, unit in ipairs({ "party1", "party2", "player" }) do
		if world.reads[unit] ~= 2 then fail(scenario, unit .. " was walked " .. tostring(world.reads[unit]) .. " calls, not one walk of 2") end
	end
	release(ns)
end)
with("curefight: a burst of debuffs is read once a person", { raid = 16 }, function(ns, world)
	local scenario = "curefight: a burst of debuffs is read once a person"
	pull(ns)
	drain(4)
	world.resetReads()
	for i = 2, 16 do
		Mock.frameEvent("UNIT_AURA", "raid" .. i, { addedAuras = { { isHarmful = true, dispelName = "Curse" } } })
	end
	-- Your own raid token comes with "player"'s own, and is read once, there.
	Mock.frameEvent("UNIT_AURA", "raid1", { addedAuras = { { isHarmful = true, dispelName = "Curse" } } })
	settle()
	local function people()
		local n = 0
		for unit in pairs(world.reads) do
			if unit ~= "n" and unit:find("^raid%d+$") then n = n + 1 end
		end
		return n
	end
	if people() ~= 10 then fail(scenario, "the first flush read " .. people() .. " of 15, not ten") end
	settle()
	if people() ~= 15 then fail(scenario, "the second flush left " .. people() .. " of 15 read, not all") end
	if world.reads.raid1 then fail(scenario, "your own raid token was read " .. tostring(world.reads.raid1) .. " times") end
	release(ns)
end)

-- ------------------------------------------------------------------ 21
with("curefight: out of a fight it listens to nothing", {}, function(ns, world)
	local scenario = "curefight: out of a fight it listens to nothing"
	world.debuffs.party1 = { debuff("Poison", 30) }
	pull(ns)
	settle()
	release(ns)
	world.resetReads()
	local timers = #Mock.timers
	Mock.frameEvent("UNIT_AURA", "party1", { addedAuras = { { isHarmful = true, dispelName = "Poison" } } })
	Mock.frameEvent("PLAYER_TARGET_CHANGED")
	if #Mock.timers ~= timers then fail(scenario, "an event after the fight queued a timer") end
	local heard = ns.CureFight.frame._events or {}
	for _, event in ipairs({ "UNIT_AURA", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "GROUP_ROSTER_UPDATE", "UNIT_SPELLCAST_SUCCEEDED" }) do
		if heard[event] then fail(scenario, "still registered for " .. event .. " after the fight") end
	end
	settle()
	if world.reads.n ~= 0 then fail(scenario, "an aura after the fight asked for " .. world.reads.n .. " reads") end
	-- A settled scan asks the client nothing: what changed is worked out first,
	-- and the lockdown is asked only when something did.
	ns.addon:Tick()
	local asked = {}
	debug.sethook(function()
		local info = debug.getinfo(2, "nS")
		if info and tostring(info.source):find("tests[/\\]mock") and info.name ~= "issecretvalue" then
			asked[#asked + 1] = tostring(info.name)
		end
	end, "c")
	local wanted = ns.CureFight:Wanted()
	debug.sethook()
	if #asked > 0 then fail(scenario, "a settled scan asked the client " .. table.concat(asked, ", ")) end
	if wanted then fail(scenario, "a settled scan wants work") end
end)

-- ------------------------------------------------------------------ 22
with("curefight: switched off, a scan pays nothing for it", { keep = true, off = true, watchLoad = true, class = "MAGE", known = { 475 } }, function(ns, world)
	local scenario = "curefight: switched off, a scan pays nothing for it"
	if #world.loadAsked > 0 then fail(scenario, "the login scans asked the client " .. table.concat(world.loadAsked, ", ") .. " with the switch off") end
	local asked = {}
	debug.sethook(function()
		local info = debug.getinfo(2, "nS")
		if info and tostring(info.source):find("tests[/\\]mock") and info.name ~= "issecretvalue" then
			asked[#asked + 1] = tostring(info.name)
		end
	end, "c")
	local wanted = ns.CureFight:Wanted()
	debug.sethook()
	if wanted then fail(scenario, "wants work with the switch off") end
	if #asked > 0 then fail(scenario, "asked the client " .. table.concat(asked, ", ") .. " with the switch off") end
	ns.addon:Tick()
	if ns.CureFight:Button() or (Mock.namedFrames and Mock.namedFrames.MannersCureFight) then fail(scenario, "made a frame with the switch off") end
end)

-- ------------------------------------------------------------------ 22b
-- The switch is on for everybody: a class with no cure to offer (a warrior, a
-- mage below Remove Lesser Curse) must still pay a scan nothing, and make no
-- frame.
for _, row in ipairs({
	{ "a warrior", { keep = true, on = true, watchLoad = true, class = "WARRIOR", known = {} } },
	{ "a mage with no cure known", { keep = true, on = true, watchLoad = true, class = "MAGE", known = {} } },
}) do
	local scenario = "curefight: switched on, a scan costs " .. row[1] .. " nothing"
	with(scenario, row[2], function(ns, world)
		if ns.db.profile.prompt.cureFight ~= true then fail(scenario, "the switch is not on") end
		if #world.loadAsked > 0 then fail(scenario, "the login scans asked the client " .. table.concat(world.loadAsked, ", ")) end
		-- What the class can cure is worked out once per probe and kept.
		ns.CureFightSpells()
		local asked = {}
		debug.sethook(function()
			local info = debug.getinfo(2, "nS")
			if info and tostring(info.source):find("tests[/\]mock") and info.name ~= "issecretvalue" then
				asked[#asked + 1] = tostring(info.name)
			end
		end, "c")
		local wanted = ns.CureFight:Wanted()
		debug.sethook()
		if wanted then fail(scenario, "wants work with no cure to offer") end
		if #asked > 0 then fail(scenario, "asked the client " .. table.concat(asked, ", ")) end
		ns.addon:Tick()
		if ns.CureFight:Button() or (Mock.namedFrames and Mock.namedFrames.MannersCureFight) then
			fail(scenario, "made a frame with no cure to offer")
		end
	end)
end

-- ------------------------------------------------------------------ 22c
-- With no key bound (the default profile) the button takes a click out of a
-- fight, the only way to cast it; with a key bound it takes none, so a click
-- beside the prompt reaches the world behind. Nothing is printed either way.
with("curefight: with no key the button takes a click, with a key it takes none", { keep = true, on = true, key = false }, function(ns, world)
	local scenario = "curefight: with no key the button takes a click, with a key it takes none"
	local button = ns.CureFight:Button()
	if not button then fail(scenario, "no button for a druid") return end
	if button._mouse ~= true then fail(scenario, "out of a fight with no key it takes no click (mouse " .. tostring(button._mouse) .. ")") end
	if printedHas("has no key") then fail(scenario, "a line was printed about the missing key") end
	pull(ns)
	drain()
	world.debuffs.party1 = { debuff("Poison", 30) }
	landed("party1")
	if printedHas("has no key") then fail(scenario, "a line was printed about the missing key in a fight") end
	release(ns)
	ns.db.profile.prompt.fightButtons = "always"
	ns.CureFight:Refresh()
	if button._mouse ~= true then fail(scenario, "with no key and All fight it takes no click (mouse " .. tostring(button._mouse) .. ")") end
end)

with("curefight: with a key bound the button takes no click", { keep = true, on = true }, function(ns)
	local scenario = "curefight: with a key bound the button takes no click"
	local button = ns.CureFight:Button()
	if not button then fail(scenario, "no button for a druid") return end
	if button._mouse ~= false then fail(scenario, "out of a fight with a key it takes a click (mouse " .. tostring(button._mouse) .. ")") end
	if printedHas("has no key") then fail(scenario, "a line was printed about a key") end
end)

-- ------------------------------------------------------------------ 23
with("curefight: its press lets the prompt's waiting press go", { owe = true }, function(ns)
	local scenario = "curefight: its press lets the prompt's waiting press go"
	pull(ns)
	drain(2)
	if not ns.Prompt.state.current then fail(scenario, "SKIPPED -- nobody on the prompt") return end
	Mock.printed = {}
	H.pressButton(ns)
	if not ns.pendingClick then fail(scenario, "SKIPPED -- the prompt's press filed nothing") return end
	Mock.advance(0.1)
	Mock.pressBinding(COMMAND)
	if not printedHas("you cured somebody instead") then fail(scenario, "the prompt's press was not let go as cured") end
	if ns.pendingClick then fail(scenario, "the prompt's press is still waiting") end
	release(ns)
end)

-- ------------------------------------------------------------------ 24
with("curefight: its key casts the cure alone, steps no rota and files nothing", { owe = true }, function(ns)
	local scenario = "curefight: its key casts the cure alone, steps no rota and files nothing"
	pull(ns)
	local prompt, header = ns.Prompt:GetButton(), ns.Prompt:FightHeader()
	local macro, at = prompt:GetAttribute("macrotext1"), header and header:GetAttribute("manners-rota-i")
	local before = #Mock.castLog
	Mock.pressBinding(COMMAND)
	local casts = castsSince(before)
	if #casts ~= 1 or casts[1].spell ~= "Remove Curse" then
		fail(scenario, "its key cast " .. #casts .. " spells: " .. tostring(casts[1] and casts[1].spell))
	end
	if prompt:GetAttribute("macrotext1") ~= macro then fail(scenario, "its key changed the prompt's macro") end
	if header and header:GetAttribute("manners-rota-i") ~= at then fail(scenario, "its key stepped the fight's rota") end
	if ns.pendingClick then fail(scenario, "its key filed a press for " .. tostring(ns.pendingClick.name)) end
	before = #Mock.castLog
	ns.CureFight:Button():Click("RightButton", true)
	if #castsSince(before) > 0 then fail(scenario, "a right click cast it") end
	release(ns)
end)

-- ------------------------------------------------------------------ 25
with("curefight: no tooltip while it is out of sight", { single = true }, function(ns, world)
	local scenario = "curefight: no tooltip while it is out of sight"
	local button = ns.CureFight:Button()
	pull(ns)
	drain(2)
	Mock.tooltipOwner = nil
	button.scripts.OnEnter(button)
	if Mock.tooltipOwner ~= nil then fail(scenario, "a tooltip was shown for a button nobody can see") end
	world.debuffs.party1 = { debuff("Poison", 30) }
	landed("party1")
	if (shows(ns)) ~= 1 then fail(scenario, "SKIPPED -- not lit") return end
	button.scripts.OnEnter(button)
	if Mock.tooltipOwner ~= button then fail(scenario, "no tooltip while it is lit") end
	do
		local where = ns.OptionsPage.TabOf("appearance.cureFight")
		if not (where and table.concat(Mock.tooltip, "\n"):find(where, 1, true)) then
			fail("menupass-pointers: the fight buttons say where their settings are",
				"the cure button: its tooltip does not name " .. tostring(where) .. ": " .. table.concat(Mock.tooltip, " | "))
		end
	end
	release(ns)
end)

-- ------------------------------------------------------------------ 26
with("curefight: one person under two tokens is counted once", { single = true }, function(ns, world)
	local scenario = "curefight: one person under two tokens is counted once"
	world.setTarget("party1")
	world.debuffs.party1 = { debuff("Poison", 30) }
	pull(ns)
	settle()
	local alpha, _, name = shows(ns)
	if alpha ~= 1 then fail(scenario, "SKIPPED -- not shown") return end
	if name:find("more", 1, true) then fail(scenario, "counted twice: " .. name) end
	release(ns)
end)

-- ------------------------------------------------------------------ 27
with("curefight: switched off, nothing is shown or armed", { single = true }, function(ns)
	local scenario = "curefight: switched off, nothing is shown or armed"
	local button, header = ns.CureFight:Button(), ns.CureFight:Header()
	local switch = option(ns, "cureFight")
	if not (button and switch) then fail(scenario, "no button or no switch") return end
	switch.set({ "appearance", "cureFight" }, false)
	ns.addon:Tick()
	if button:GetAttribute("macrotext1") ~= nil or button:GetAttribute("type1") ~= nil then fail(scenario, "still armed with the switch off") end
	if header and header:GetAttribute("manners-on") ~= false then fail(scenario, "its driver is still on") end
	pull(ns)
	if button:IsShown() then fail(scenario, "shown in a fight with the switch off") end
	release(ns)
	switch.set({ "appearance", "cureFight" }, true)
	ns.addon:Tick()
	if button:GetAttribute("macrotext1") ~= DRUID_MACRO then fail(scenario, "not armed again once switched on") end
end)

-- ------------------------------------------------------------------ 28
with("curefight: mists: a cure cooling down shows dim, never for nobody", { flavour = "mists", class = "PRIEST", known = { 527 },
	spellNames = { [527] = "Purify" } }, function(ns, world)
	local scenario = "curefight: mists: a cure cooling down shows dim, never for nobody"
	world.debuffs.party1 = { debuff("Disease", 60) }
	pull(ns)
	settle()
	if (shows(ns)) ~= 1 then fail(scenario, "SKIPPED -- not lit for a disease") return end
	Mock.pressBinding(COMMAND)
	Mock.spellCooldowns = { [527] = { startTime = Mock.now, duration = 8, isActive = true } }
	Mock.dispatch("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-purify", 527)
	local alpha, glow, _, key = shows(ns)
	if alpha ~= 0.6 or glow then fail(scenario, "not dim while the cure cools down: alpha " .. tostring(alpha)) end
	if key ~= "your cure is cooling down" then fail(scenario, "its key line reads " .. key) end
	world.debuffs.party1 = nil
	Mock.frameEvent("UNIT_AURA", "party1", { removedAuraInstanceIDs = { 1 } })
	settle()
	local a2, _, n2 = shows(ns)
	if a2 ~= 0 or n2 ~= "" then fail(scenario, "shown for nobody while the cure cooled: " .. tostring(a2)) end
	release(ns)
end)

-- ------------------------------------------------------------------ 29
with("curefight: a class with no cure never sees it", { class = "WARRIOR", known = { 1126 }, keep = true }, function(ns)
	local scenario = "curefight: a class with no cure never sees it"
	ns.db.profile.prompt.cureFight = true
	ns.addon:Tick()
	local look = option(ns, "cureFight")
	if look and not hidden(look) then fail(scenario, "Look shows the switch to a warrior") end
	local key = option(ns, "cureFightKey")
	if key and not hidden(key) then fail(scenario, "Look shows the key to a warrior") end
	local who = option(ns, "curesFight")
	if who and not hidden(who) then fail(scenario, "Who to buff shows the switch to a warrior") end
	if ns.CureFight:Button() or (Mock.namedFrames and Mock.namedFrames.MannersCureFight) then fail(scenario, "a warrior has a cure button") end
end)

-- ------------------------------------------------------------------ 30
with("curefight: the switch and its key sit under In a fight, after Mend Pet", {}, function(ns)
	local scenario = "curefight: the switch and its key sit under In a fight, after Mend Pet"
	local layout = ns.WindowLayout
	if not layout then fail(scenario, "SKIPPED -- no layout") return end
	local function holder(node, path, seen)
		if type(node) ~= "table" then return nil end
		seen = seen or {}
		if seen[node] then return nil end
		seen[node] = true
		if type(node.items) == "table" then
			for i, item in ipairs(node.items) do
				if item == path or (type(item) == "table" and item[1] == path) then return node.items, i end
			end
		end
		for _, child in pairs(node) do
			local items, at = holder(child, path, seen)
			if items then return items, at end
		end
		return nil
	end
	local function pathOf(item) return type(item) == "table" and item[1] or item end
	local items, at = holder(layout, "appearance.cureFight")
	if not items then fail(scenario, "appearance.cureFight is not placed") return end
	-- The one setting for the two fight buttons (When the fight buttons show) sits
	-- between Mend Pet's key and this switch.
	if pathOf(items[at - 1]) ~= "appearance.fightButtons" or pathOf(items[at - 2]) ~= "appearance.mendInFightKey" then
		fail(scenario, "the switch does not follow Mend Pet's key and the fight buttons' setting")
	end
	local keyItem = items[at + 1]
	if pathOf(keyItem) ~= "appearance.cureFightKey" or not (type(keyItem) == "table" and keyItem.indent == true) then
		fail(scenario, "its key is not the next row, indented")
	end
	if layout.parents["appearance.cureFightKey"] ~= "appearance.cureFight" then fail(scenario, "its key has no parent switch") end
	local whoItems, wat = holder(layout, "who.curesFight")
	if not whoItems then fail(scenario, "who.curesFight is not placed") return end
	if pathOf(whoItems[wat - 1]) ~= "who.cureSeconds" then fail(scenario, "Who's row does not follow the seconds") end
	-- A key chosen on Look lands on the binding.
	local key = option(ns, "cureFightKey")
	if not key then fail(scenario, "no key control") return end
	key.set(nil, "G")
	if GetBindingKey(COMMAND) ~= "G" then fail(scenario, "the key chosen is bound to " .. tostring(GetBindingKey(COMMAND))) end
end)

-- ------------------------------------------------------------------ 31
do
	local scenario = "curefight: the prompt in a fight is unchanged"
	local seen = {}
	for _, on in ipairs({ false, true }) do
		with(scenario, { owe = true, keep = not on }, function(ns)
			if on then ns.db.profile.prompt.cureFight = true else ns.db.profile.prompt.cureFight = false end
			ns.addon:Tick()
			pull(ns)
			local header = ns.Prompt:FightHeader()
			local before = #Mock.castLog
			Mock.advance(2)
			Mock.pressBinding(PROMPT_KEY)
			local casts = castsSince(before)
			seen[#seen + 1] = {
				macro = ns.Prompt:GetButton():GetAttribute("macrotext1"),
				rota = header and header:GetAttribute("manners-rota-n"),
				cast = casts[1] and casts[1].spell,
				count = #casts,
			}
			release(ns)
		end)
	end
	local a, b = seen[1], seen[2]
	if not (a and b) then
		fail(scenario, "SKIPPED -- a session did not run")
	elseif a.macro ~= b.macro or a.rota ~= b.rota or a.cast ~= b.cast or a.count ~= b.count then
		fail(scenario, ("the prompt differs with the switch on: macro %s / %s, rota %s / %s, cast %s / %s"):format(
			tostring(a.macro), tostring(b.macro), tostring(a.rota), tostring(b.rota), tostring(a.cast), tostring(b.cast)))
	end
end

-- ------------------------------------------------------------------ 32
with("curefight: forever: a priest's own cure with a hostile target says to target yourself", { flavour = "camelot", class = "PRIEST",
	known = { 988, 528 } }, function(ns, world)
	local scenario = "curefight: forever: a priest's own cure with a hostile target says to target yourself"
	world.setTarget("party1", true)
	world.debuffs.player = { debuff("Magic", 30) }
	pull(ns)
	settle()
	local alpha, _, _, key = shows(ns)
	if alpha ~= 1 then fail(scenario, "SKIPPED -- not shown for magic on you") return end
	if key ~= "target yourself and press F" then fail(scenario, "its key line reads " .. key) end
	release(ns)
end)

-- ------------------------------------------------------------------ 33
with("curefight: a key bound with Shift casts the first cure alone", { single = true }, function(ns, world)
	local scenario = "curefight: a key bound with Shift casts the first cure alone"
	Mock.bindings = { ["SHIFT-F"] = COMMAND }
	Mock.frameEvent("UPDATE_BINDINGS")
	ns.addon:Tick()
	local macro = ns.CureFight:Button():GetAttribute("macrotext1")
	if macro ~= "/cast [@mouseover,help,nodead][help,nodead][@player] Remove Curse" then
		fail(scenario, "the macro reads " .. tostring(macro))
	end
	world.debuffs.party1 = { debuff("Curse", 30) }
	world.debuffs.party2 = { debuff("Poison", 30) }
	pull(ns)
	settle()
	local alpha, _, name, key = shows(ns)
	if alpha ~= 1 then fail(scenario, "SKIPPED -- not shown for a curse") return end
	if key:find("Shift-", 1, true) then fail(scenario, "a key line names Shift: " .. key) end
	if name:find("Hugo", 1, true) or name:find("more", 1, true) then fail(scenario, "the poison, which the macro cannot cast, is shown: " .. name) end
	release(ns)
end)

-- ------------------------------------------------------------------ 34
with("curefight: only what the armed macro can cast is chosen", { single = true }, function(ns, world)
	local scenario = "curefight: only what the armed macro can cast is chosen"
	-- SHIFT-F: the macro is Remove Curse alone. The poison (Cure Poison, on
	-- Shift) lasts longer, but it is not what a press can cast.
	Mock.bindings = { ["SHIFT-F"] = COMMAND }
	Mock.frameEvent("UPDATE_BINDINGS")
	ns.addon:Tick()
	world.debuffs.party1 = { debuff("Poison", 30), debuff("Curse", 20) }
	pull(ns)
	settle()
	local alpha, _, name, key = shows(ns)
	if alpha ~= 1 then fail(scenario, "not lit for a curse beside a longer poison: alpha " .. tostring(alpha)) return end
	if not name:find("Remove Curse", 1, true) or not name:find("Gwen", 1, true) then fail(scenario, "its name line reads " .. name) end
	if key:find("Shift-", 1, true) then fail(scenario, "its key line names Shift: " .. key) end
	release(ns)
end)

-- ------------------------------------------------------------------ 35
with("curefight: a debuff never removed that goes lets the cure show", { class = "PALADIN", known = { 4987 } }, function(ns, world)
	local scenario = "curefight: a debuff never removed that goes lets the cure show"
	-- Cleanse would lift Unstable Affliction too: held back while it is there.
	world.debuffs.party1 = { debuff("Magic", 30, 427717, nil, "Unstable Affliction"), debuff("Poison", 30) }
	pull(ns)
	settle()
	if (shows(ns)) ~= 0 then fail(scenario, "SKIPPED -- shown with Unstable Affliction on them") return end
	-- It ends: an event that only removes an aura.
	world.debuffs.party1 = { debuff("Poison", 30) }
	Mock.frameEvent("UNIT_AURA", "party1", { removedAuraInstanceIDs = { 9001 } })
	settle()
	local alpha, _, name = shows(ns)
	if alpha ~= 1 then fail(scenario, "not shown once Unstable Affliction was gone: alpha " .. tostring(alpha)) return end
	if not name:find("Cleanse", 1, true) or not name:find("Poisoned", 1, true) then fail(scenario, "its name line reads " .. name) end
	release(ns)
end)

with("curefight: paladin poison uses Purify when Cleanse would take a debuff never removed", {
	class = "PALADIN", known = { 4987, 1152 },
}, function(ns, world)
	local scenario = "curefight: paladin poison uses Purify when Cleanse would take a debuff never removed"
	world.debuffs.party1 = {
		debuff("Magic", 30, 427717, nil, "Unstable Affliction"),
		debuff("Poison", 30),
	}
	pull(ns)
	settle()
	local _, _, firstName = shows(ns, 1)
	local secondAlpha, _, secondName = shows(ns, 2)
	if (shows(ns, 1)) ~= 0 then fail(scenario, "Cleanse was shown for a dangerous mixed debuff: " .. tostring(firstName)) end
	if secondAlpha ~= 1 or not secondName:find("Purify", 1, true)
		or not secondName:find("Poisoned", 1, true) then
		fail(scenario, "the safe Purify button did not show: " .. tostring(secondAlpha) .. " " .. secondName)
	end
	release(ns)
end)

-- ------------------------------------------------------------------ 36
-- Where the game hides every aura but lists the ones you can remove
-- (C_UnitAuras.GetUnitAuraInstanceIDs with "HARMFUL|RAID"), the group is read
-- through that list: the button shows for a debuff you can remove, the kind
-- unnamed.
local FOREVER_MAGE = { flavour = "camelot", class = "MAGE", known = { 475 }, dispelList = true }

with("curefight: forever: the game hides debuffs, its list of what you can remove shows the button", FOREVER_MAGE, function(ns, world)
	local scenario = "curefight: forever: the game hides debuffs, its list of what you can remove shows the button"
	world.secret = true
	world.debuffs.party1 = { debuff("Curse", 30) }
	pull(ns)
	drain(2)
	if (world.listReads.party1 or 0) < 1 then fail(scenario, "the group was not read through the game's list") end
	if world.listFilter ~= "HARMFUL|RAID" then fail(scenario, "the list was asked for " .. tostring(world.listFilter)) end
	local alpha, glow, name = shows(ns)
	if alpha ~= 1 or not glow then fail(scenario, ("not lit: alpha %s, glow %s"):format(tostring(alpha), tostring(glow))) end
	if not name:find("Remove Lesser Curse|r: Gwen", 1, true) or not name:find("(a debuff you can remove)", 1, true) then
		fail(scenario, "its name line reads " .. name)
	end
	local line = ns.CureFightLines()[2] or ""
	if not line:find("[1-9]%d* from the game's list", 1) then fail(scenario, "the debug line does not count the list: " .. line) end
	local before = #Mock.castLog
	Mock.pressBinding(COMMAND)
	local casts = castsSince(before)
	if #casts ~= 1 or casts[1].spell ~= "Remove Lesser Curse" then
		fail(scenario, "its key did not cast: " .. #casts .. " casts")
	end
	-- Nobody in need any more: the list is empty and the button goes.
	world.debuffs.party1 = nil
	Mock.frameEvent("UNIT_AURA", "party1", { removedAuraInstanceIDs = { 9001 } })
	settle()
	if (shows(ns)) ~= 0 then fail(scenario, "still shown once the list was empty") end
	release(ns)
end)

with("curefight: forever: an empty list asks nothing more and shows nothing", FOREVER_MAGE, function(ns, world)
	local scenario = "curefight: forever: an empty list asks nothing more and shows nothing"
	world.secret = true
	pull(ns)
	drain(2)
	if (world.listReads.party1 or 0) < 1 then fail(scenario, "SKIPPED -- the list was not read") end
	if (world.reads.party1 or 0) ~= 0 then fail(scenario, "an empty list was still walked " .. tostring(world.reads.party1) .. " times") end
	local alpha, glow, name = shows(ns)
	if alpha ~= 0 or glow or name ~= "" then fail(scenario, "shown for an empty list: " .. tostring(alpha) .. " " .. name) end
	release(ns)
end)

with("curefight: forever: a withheld list is passed over", FOREVER_MAGE, function(ns, world)
	local scenario = "curefight: forever: a withheld list is passed over"
	world.secret = true
	world.listSecret = true
	world.debuffs.party1 = { debuff("Curse", 30) }
	pull(ns)
	drain(2)
	local alpha, glow, name = shows(ns)
	if alpha ~= 0 or glow or name ~= "" then fail(scenario, "shown with the list and every aura withheld: " .. tostring(alpha) .. " " .. name) end
	release(ns)
end)

-- A plain read that finds nothing wins over the list: a curse with a second
-- left, on a client that gives plain auras and a list, is not shown.
with("curefight: forever: a plain read that finds nothing wins over the list", FOREVER_MAGE, function(ns, world)
	local scenario = "curefight: forever: a plain read that finds nothing wins over the list"
	world.debuffs.party1 = { debuff("Curse", 1) }
	pull(ns)
	drain(2)
	local alpha, _, name = shows(ns)
	if alpha ~= 0 or name ~= "" then fail(scenario, "shown for a curse with a second left: " .. tostring(alpha) .. " " .. name) end
	release(ns)
end)

-- ------------------------------------------------------------------ 37
-- A button for each cure (prompt.cureFightEach, on by default): a druid on the
-- older clients has Remove Curse and Cure Poison. Each has a button and a key,
-- and shows only for its own kinds.
with("curefight: a druid's poison shows the second button alone", {}, function(ns, world)
	local scenario = "curefight: a druid's poison shows the second button alone"
	Mock.bindings["G"] = COMMAND2
	Mock.frameEvent("UPDATE_BINDINGS")
	ns.addon:Tick()
	if not ns.CureFight:Button(2) then fail(scenario, "no second button for a druid") return end
	world.debuffs.party1 = { debuff("Poison", 30) }
	pull(ns)
	settle()
	local a1, g1, n1 = shows(ns, 1)
	local a2, g2, n2, k2 = shows(ns, 2)
	if a2 ~= 1 or not g2 then fail(scenario, ("the second button is not lit: alpha %s, glow %s"):format(tostring(a2), tostring(g2))) end
	for _, word in ipairs({ "Cure Poison", "Gwen", "Poisoned" }) do
		if not n2:find(word, 1, true) then fail(scenario, "its name line lacks " .. word .. ": " .. n2) end
	end
	if k2 ~= "point at Gwen and press G" then fail(scenario, "its key line reads " .. k2) end
	if a1 ~= 0 or g1 or n1 ~= "" then fail(scenario, "the first button shows for a poison: " .. tostring(a1) .. " " .. n1) end
	release(ns)
end)

with("curefight: a druid's curse shows the first button alone", {}, function(ns, world)
	local scenario = "curefight: a druid's curse shows the first button alone"
	world.debuffs.party1 = { debuff("Curse", 30) }
	pull(ns)
	settle()
	local a1, _, n1, k1 = shows(ns, 1)
	local a2, g2, n2 = shows(ns, 2)
	if a1 ~= 1 or not n1:find("Remove Curse", 1, true) or not n1:find("Gwen", 1, true) then
		fail(scenario, "the first button is not lit for the curse: " .. tostring(a1) .. " " .. n1)
	end
	if k1 ~= "point at Gwen and press F" then fail(scenario, "its key line reads " .. k1) end
	if a2 ~= 0 or g2 or n2 ~= "" then fail(scenario, "the second button shows for a curse: " .. tostring(a2) .. " " .. n2) end
	-- Both kinds on two people: each button names its own.
	world.debuffs.party2 = { debuff("Poison", 30) }
	landed("party2")
	local _, _, m1 = shows(ns, 1)
	local b2, _, m2 = shows(ns, 2)
	if b2 ~= 1 or not m2:find("Hugo", 1, true) or not m1:find("Gwen", 1, true) then
		fail(scenario, "with a curse and a poison, the buttons read '" .. m1 .. "' and '" .. m2 .. "'")
	end
	release(ns)
end)

with("curefight: each cure's key casts its own cure", {}, function(ns)
	local scenario = "curefight: each cure's key casts its own cure"
	local first, second = ns.CureFight:Button(1), ns.CureFight:Button(2)
	if not (first and second) then fail(scenario, "SKIPPED -- two buttons are not made") return end
	local m1, m2 = first:GetAttribute("macrotext1") or "", second:GetAttribute("macrotext1") or ""
	if m2:find("mod:shift", 1, true) then fail(scenario, "the second macro names Shift: " .. m2) end
	-- The first keeps the old two-cure macro: a player who bound a key for the
	-- cure and pressed Shift-key for the second cure keeps doing so.
	if m1 ~= DRUID_MACRO then fail(scenario, "the first macro reads " .. m1) end
	if m2 ~= "/cast [@mouseover,help,nodead][help,nodead][@player] Cure Poison" then fail(scenario, "the second macro reads " .. m2) end
	local before = #Mock.castLog
	Mock.pressBinding(COMMAND)
	local casts = castsSince(before)
	if #casts ~= 1 or casts[1].spell ~= "Remove Curse" then fail(scenario, "the first key cast " .. tostring(casts[1] and casts[1].spell)) end
	before = #Mock.castLog
	Mock.pressBinding(COMMAND2)
	casts = castsSince(before)
	if #casts ~= 1 or casts[1].spell ~= "Cure Poison" then fail(scenario, "the second key cast " .. tostring(casts[1] and casts[1].spell)) end
	-- Shift on the first key still casts the second cure, as it did before there
	-- was a button for each.
	Mock.modifiers.shift = true
	before = #Mock.castLog
	Mock.pressBinding(COMMAND)
	casts = castsSince(before)
	if #casts ~= 1 or casts[1].spell ~= "Cure Poison" then fail(scenario, "with Shift the first key cast " .. tostring(casts[1] and casts[1].spell)) end
	Mock.modifiers.shift = false
end)

with("curefight: forever: the kind hidden, a druid sees both buttons, each naming its cure", { flavour = "camelot", dispelList = true }, function(ns, world)
	local scenario = "curefight: forever: the kind hidden, a druid sees both buttons, each naming its cure"
	world.secret = true
	world.debuffs.party1 = { debuff("Poison", 30) }
	pull(ns)
	drain(2)
	local a1, _, n1 = shows(ns, 1)
	local a2, _, n2 = shows(ns, 2)
	if a1 ~= 1 or a2 ~= 1 then fail(scenario, "not both lit: " .. tostring(a1) .. " / " .. tostring(a2)) return end
	if not n1:find("Remove Curse", 1, true) or not n1:find("(a debuff you can remove)", 1, true) then fail(scenario, "the first reads " .. n1) end
	if not n2:find("Cure Poison", 1, true) or not n2:find("(a debuff you can remove)", 1, true) then fail(scenario, "the second reads " .. n2) end
	release(ns)
end)

with("curefight: a class with one cure makes no second button", { class = "MAGE", known = { 475 } }, function(ns, world)
	local scenario = "curefight: a class with one cure makes no second button"
	if not ns.CureFight:Button(1) then fail(scenario, "SKIPPED -- no first button") return end
	if rawget(_G, "MannersCureFight2") ~= nil or ns.CureFight:Button(2) ~= nil
		or (Mock.namedFrames and Mock.namedFrames.MannersCureFight2) then
		fail(scenario, "a second button was made for a mage")
	end
	world.debuffs.party1 = { debuff("Curse", 30) }
	pull(ns)
	settle()
	if (shows(ns)) ~= 1 then fail(scenario, "the one button does not show for a curse") end
	release(ns)
end)

with("curefight: A button for each cure off keeps one button and Shift", {}, function(ns, world)
	local scenario = "curefight: A button for each cure off keeps one button and Shift"
	local second = ns.CureFight:Button(2)
	local first = ns.CureFight:Button(1)
	if not (first and second) then fail(scenario, "SKIPPED -- two buttons are not made") return end
	local each = option(ns, "cureFightEach")
	local key2 = option(ns, "cureFightKey2")
	if not (each and key2) then fail(scenario, "no switch or no second key on Look") return end
	if hidden(each) or hidden(key2) then fail(scenario, "the switch or the second key is hidden for a druid") end
	each.set({ "appearance", "cureFightEach" }, false)
	ns.addon:Tick()
	if second:GetAttribute("macrotext1") ~= nil then fail(scenario, "the second button is still armed") end
	if first:GetAttribute("macrotext1") ~= DRUID_MACRO then fail(scenario, "the first macro reads " .. tostring(first:GetAttribute("macrotext1"))) end
	if not hidden(key2) then fail(scenario, "the second key is shown with the switch off") end
	local header = ns.CureFight:Header()
	if header and header:GetAttribute("manners-two") ~= false then fail(scenario, "the header still wants the second button") end
	world.debuffs.party1 = { debuff("Poison", 30) }
	pull(ns)
	settle()
	if second:IsShown() then fail(scenario, "the second button is shown in a fight with the switch off") end
	local a1, _, n1, k1 = shows(ns, 1)
	local a2 = shows(ns, 2)
	if a1 ~= 1 or not n1:find("Cure Poison", 1, true) then fail(scenario, "the one button is not lit for a poison: " .. tostring(a1) .. " " .. n1) end
	if k1 ~= "point at Gwen and press Shift-F" then fail(scenario, "its key line reads " .. k1) end
	if a2 ~= 0 then fail(scenario, "the second button is lit with the switch off") end
	release(ns)
	-- On again, the second button is armed again.
	each.set({ "appearance", "cureFightEach" }, true)
	ns.addon:Tick()
	if second:GetAttribute("macrotext1") ~= "/cast [@mouseover,help,nodead][help,nodead][@player] Cure Poison" then
		fail(scenario, "not armed again once switched on: " .. tostring(second:GetAttribute("macrotext1")))
	end
	if first:GetAttribute("macrotext1") ~= DRUID_MACRO then
		fail(scenario, "the first button lost its Shift clause: " .. tostring(first:GetAttribute("macrotext1")))
	end
end)

with("curefight: the second button sits below the first, on a frame, and no protected call in a fight", {}, function(ns, world)
	local scenario = "curefight: the second button sits below the first, on a frame, and no protected call in a fight"
	local first, second = ns.CureFight:Button(1), ns.CureFight:Button(2)
	if not (first and second) then fail(scenario, "SKIPPED -- two buttons are not made") return end
	local at = second.points and second.points[#second.points]
	if not at or at[1] ~= "TOP" or at[2] ~= first or at[3] ~= "BOTTOM" then
		fail(scenario, "the second button is not anchored TOP to the first's BOTTOM")
	end
	if at and type(at[2]) == "table" and (at[2]._frameType == "FontString" or at[2]._frameType == "Texture") then
		fail(scenario, "the second button is anchored to a region")
	end
	if first:GetWidth() ~= second:GetWidth() or first:GetHeight() ~= second:GetHeight() then
		fail(scenario, "the buttons are not the same size")
	end
	Mock.protect(first)
	Mock.protect(second)
	pull(ns)
	if not (first:IsShown() and second:IsShown()) then fail(scenario, "its driver did not show both at the pull") end
	if first:GetAlpha() ~= 0 or second:GetAlpha() ~= 0 then fail(scenario, "shown at the pull with alpha") end
	Mock.protectedCalls = {}
	world.debuffs.party1 = { debuff("Poison", 30) }
	landed("party1")
	world.debuffs.party2 = { debuff("Curse", 30) }
	landed("party2")
	if (shows(ns, 2)) ~= 1 or (shows(ns, 1)) ~= 1 then fail(scenario, "SKIPPED -- not both lit") end
	world.debuffs.party1, world.debuffs.party2 = nil, nil
	Mock.frameEvent("UNIT_AURA", "party1", { removedAuraInstanceIDs = { 1 } })
	Mock.frameEvent("UNIT_AURA", "party2", { removedAuraInstanceIDs = { 1 } })
	settle()
	for _ = 1, 3 do
		Mock.advance(0.4)
		ns.addon:Tick()
		Mock.runTimers(1)
	end
	local each = option(ns, "cureFightEach")
	if each then
		each.set({ "appearance", "cureFightEach" }, false)
		each.set({ "appearance", "cureFightEach" }, true)
	end
	ns.Prompt:Refresh()
	if #Mock.protectedCalls > 0 then
		fail(scenario, "Lua called " .. table.concat(Mock.protectedCalls, ", ") .. " on a cure button in the fight")
	end
	if not (first:IsShown() and second:IsShown()) then fail(scenario, "the fight left one hidden") end
	release(ns)
	if first:IsShown() or second:IsShown() then fail(scenario, "still shown after the fight") end
end)

-- A debuff lands on somebody in the group while the game withholds what it
-- added: the read still happens, and the game's list says it is removable.
with("curefight: forever: a withheld payload of a debuff landing is read through the list", FOREVER_MAGE, function(ns, world)
	local scenario = "curefight: forever: a withheld payload of a debuff landing is read through the list"
	world.secret = true
	pull(ns)
	drain(2)
	if (shows(ns)) ~= 0 then fail(scenario, "SKIPPED -- lit before any debuff") return end
	world.debuffs.party1 = { debuff("Curse", 30) }
	Mock.frameEvent("UNIT_AURA", "party1", { addedAuras = Mock.SECRET })
	settle()
	local alpha, _, name = shows(ns)
	if alpha ~= 1 or not name:find("(a debuff you can remove)", 1, true) then
		fail(scenario, "not shown for a debuff landing with the payload withheld: " .. tostring(alpha) .. " " .. name)
	end
	release(ns)
end)
