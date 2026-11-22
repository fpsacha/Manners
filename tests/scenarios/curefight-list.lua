-- What the cure line says about the game's list of debuffs you can remove
-- (Prompt/CureFight.lua, Selftest.lua): "3 withheld, 0 from the game's list" was
-- a withheld list, a read that threw or no list at all. The line now counts the
-- times the list was asked, how often it came back withheld or empty, and says
-- whether the game has it; the self-test asks it once out of a fight.
--
-- Every name starts with "curefight-list:".

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
	[4987] = "Cleanse", [526] = "Cure Poison", [2870] = "Cure Disease",
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


local FOREVER_MAGE = { flavour = "camelot", class = "MAGE", known = { 475 }, dispelList = true }

with("curefight-list: a withheld list is counted on the cure line", FOREVER_MAGE, function(ns, world)
	local scenario = "curefight-list: a withheld list is counted on the cure line"
	world.secret = true
	world.listSecret = true
	world.debuffs.party1 = { debuff("Curse", 30) }
	pull(ns)
	drain(2)
	local line = ns.CureFightLines()[2] or ""
	if not line:find("asked [1-9]%d* times, [1-9]%d* withheld, 0 empty") then fail(scenario, "the withheld list is not counted: " .. line) end
	release(ns)
end)

with("curefight-list: an empty list is counted on the cure line", FOREVER_MAGE, function(ns, world)
	local scenario = "curefight-list: an empty list is counted on the cure line"
	world.secret = true
	pull(ns)
	drain(2)
	local line = ns.CureFightLines()[2] or ""
	if not line:find("asked [1-9]%d* times, 0 withheld, [1-9]%d* empty") then fail(scenario, "the empty list is not counted: " .. line) end
	release(ns)
end)

with("curefight-list: the cure line says whether the game has the list", FOREVER_MAGE, function(ns, world)
	local scenario = "curefight-list: the cure line says whether the game has the list"
	pull(ns)
	drain(2)
	local line = ns.CureFightLines()[2] or ""
	if not line:find("the game's list of debuffs you can remove: yes", 1, true) then fail(scenario, "a list the game has is not yes: " .. line) end
	release(ns)
end)

with("curefight-list: the cure line says whether the game has the list", { flavour = "camelot", class = "MAGE", known = { 475 } }, function(ns, world)
	local scenario = "curefight-list: the cure line says whether the game has the list"
	pull(ns)
	drain(2)
	local line = ns.CureFightLines()[2] or ""
	if not line:find("the game's list of debuffs you can remove: no", 1, true) then fail(scenario, "no list is not no: " .. line) end
	release(ns)
end)

local function apis(ns)
	local out = {}
	for _, r in ipairs(ns.Selftest.Run()) do
		if r.id == "fight.apis" then out[#out + 1] = tostring(r.value) end
	end
	return table.concat(out, " | ")
end

with("curefight-list: the self-test says what the game's list answers now", FOREVER_MAGE, function(ns, world)
	local scenario = "curefight-list: the self-test says what the game's list answers now"
	world.debuffs.player = { debuff("Curse", 30), debuff("Poison", 30) }
	local text = apis(ns)
	if not text:find("asked now: a list of 2", 1, true) then fail(scenario, "the answer is not a list of 2: " .. text) end
	world.listSecret = true
	text = apis(ns)
	if not text:find("asked now: withheld", 1, true) then fail(scenario, "a withheld list is not said: " .. text) end
end)
