-- Options and diagnostics findings from the r35 bug hunt (area: options). Each
-- scenario is red on the tree before its fix and says why.
--
-- Every scenario name starts with "options-fix:".

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, findOption = H.strangers, H.freshPrompt, H.findOption

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

local function key(entry) return tostring(entry and entry.buff and entry.buff.key) end

local function mine(ns)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.reason == "self" then return entry end
	end
	return nil
end

-- ------------------------------------------------------------------ Well-Rested world
-- As tests/scenarios/wellrested.lua sets it up: bags, auras by id, level,
-- mounted, the bag's cooldown.
local BAG, RESTED = 211527, 429959
local world
local REST_TOUCHED = { "C_Item", "C_UnitAuras", "C_Container", "UnitLevel", "GetMaxPlayerLevel", "IsMounted",
	"IsSpellKnown", "IsPlayerSpell", "IsResting" }

local function installRest()
	rawset(_G, "C_Item", {
		GetItemCount = function(id) return world.bags[id] or 0 end,
		GetItemNameByID = function(id) return "Item " .. id end,
		RequestLoadItemDataByID = function() end,
		GetItemIconByID = function(id) return 7100000 + id end,
		GetItemInfoInstant = function(id) return id, "Miscellaneous", "", "", 7100000 + id, 15, 0 end,
	})
	rawset(_G, "UnitLevel", function(unit)
		if unit == "player" then return world.level end
		return 12
	end)
	rawset(_G, "GetMaxPlayerLevel", function() return 60 end)
	rawset(_G, "IsMounted", function() return world.mounted end)
	rawset(_G, "IsResting", function() return false end)
	local container = rawget(_G, "C_Container")
	rawset(_G, "C_Container", setmetatable({
		GetItemCooldown = function() return 0, 0, 1 end,
	}, { __index = container or {} }))
	rawset(_G, "C_UnitAuras", nil)
	local base = C_UnitAuras
	rawset(_G, "C_UnitAuras", setmetatable({
		GetUnitAuraBySpellID = function(unit, id)
			if unit ~= "player" then return nil end
			local expires = world.auras[id]
			if expires == nil then return nil end
			return { spellId = id, name = "Aura " .. id, expirationTime = expires, duration = 7200, sourceUnit = "player" }
		end,
	}, { __index = base }))
end

local function rested(scenario, opts, body)
	Mock.reset()
	Mock.setFlavour(opts.flavour or "camelot")
	Mock.class = "WARRIOR"
	world = { bags = opts.bags or {}, level = 30, auras = {}, mounted = false }
	local saved = {}
	for _, name in ipairs(REST_TOUCHED) do saved[name] = rawget(_G, name) end
	local undo = strangers({})
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		installRest()
		rawset(_G, "IsSpellKnown", function() return false end)
		rawset(_G, "IsPlayerSpell", function() return false end)
		Mock.playerHeld = {}
		freshPrompt(ns, scenario)
		Mock.playerHeld = {}
		if opts.on then
			ns.db.profile.ownBuffs.pick.rested = "auto"
			ns.ForgetScrolls()
		end
		body(ns)
		noErrors(scenario, ns)
	end)
	undo()
	for _, name in ipairs(REST_TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.playerHeld = nil
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function myself(ns) return table.concat(ns.MyselfLines(GetTime()), " / ") end

-- #0
do
	local scenario = "options-fix: an import that switches Well-Rested on offers the bag already in the bags"
	rested(scenario, { bags = { [BAG] = 1 } }, function(ns)
		local pick = ns.db.profile.ownBuffs.pick
		if pick.rested ~= "off" then
			fail(scenario, "SKIPPED -- Well-Rested is " .. tostring(pick.rested) .. " to begin with")
			return
		end
		-- A scan with the switch off reads the bags without the bag.
		if mine(ns) then fail(scenario, "SKIPPED -- offered with the switch off") return end
		-- The string to paste: the same settings with the switch on.
		pick.rested = "auto"
		local text = ns.ExportSettings()
		pick.rested = "off"
		if not text:find("rested", 1, true) then
			fail(scenario, "SKIPPED -- the export does not carry the Well-Rested switch")
			return
		end
		local ok, message = ns.ImportSettings(text)
		if not ok then
			fail(scenario, "SKIPPED -- the import refused: " .. tostring(message))
			return
		end
		if pick.rested ~= "auto" then
			fail(scenario, "SKIPPED -- the import left Well-Rested " .. tostring(pick.rested))
			return
		end
		-- Nothing in the bags moved: no BAG_UPDATE_DELAYED.
		if key(mine(ns)) ~= "rested" .. BAG then
			local before, said = key(mine(ns)), myself(ns)
			-- The bags read again: what a bag change does.
			ns.addon:BAG_UPDATE_DELAYED()
			fail(scenario, "Well-Rested switched on by an import, the bag in the bags: offered "
				.. before .. ", Myself says '" .. said .. "'; after BAG_UPDATE_DELAYED offered "
				.. key(mine(ns)) .. ", Myself says '" .. myself(ns) .. "'")
		end
	end)
end

-- #2
do
	local scenario = "options-fix: Well-Rested up is named in the Myself line, not ?"
	rested(scenario, { on = true, bags = { [BAG] = 1 } }, function(ns)
		if key(mine(ns)) ~= "rested" .. BAG then
			fail(scenario, "SKIPPED -- the bag was not offered to begin with")
			return
		end
		world.auras[RESTED] = GetTime() + 7000
		ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
		Mock.advance(1)
		if mine(ns) then fail(scenario, "SKIPPED -- Well-Rested up and still offered") return end
		local text = myself(ns)
		if text:find("? is up", 1, true) then
			fail(scenario, "the Myself line for Well-Rested up reads: " .. text)
		end
	end)
end

-- #3
do
	local scenario = "options-fix: Well-Rested is not said to have no timer"
	rested(scenario, { on = true, bags = { [BAG] = 1 } }, function(ns)
		local text = table.concat(ns.LeadLines(), " / ")
		if text:find("Well-Rested: no timer -- never topped up.", 1, true) then
			fail(scenario, "When a top-up is due says a two-hour aura never runs out: " .. text)
		end
	end)
end

-- ------------------------------------------------------------------ #1 Emote to use
do
	local scenario = "options-fix: Emote to use is shown beside the /thank switch for a class with nothing to give"
	Mock.reset()
	Mock.class = "ROGUE"
	local undo = strangers({})
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		if ns.caps.hasClassBuffs then
			fail(scenario, "SKIPPED -- a rogue reads as having buffs to give")
			return
		end
		local thank = findOption(ns.optionsTable, "thankEmote")
		local token = findOption(ns.optionsTable, "thankEmoteToken")
		if not (thank and token) then
			fail(scenario, "SKIPPED -- What I say has no /thank or no Emote to use")
			return
		end
		local function hidden(c)
			local rule = c.hidden
			if type(rule) == "function" then return rule({}) and true or false end
			return rule and true or false
		end
		if hidden(thank) then fail(scenario, "SKIPPED -- the /thank switch is hidden for a rogue") return end
		if hidden(token) then
			fail(scenario, "a rogue sees /thank people who buff me but not Emote to use: always /thank")
		end
		noErrors(scenario, ns)
	end)
	undo()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- ------------------------------------------------------------------ own armor (#4 #5 #6)
local DEMON_SKIN = 687
local OWN_TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "C_UnitAuras", "IsResting", "IsInInstance" }

local function wear(ns, auras)
	rawset(_G, "C_UnitAuras", nil)
	local base = C_UnitAuras
	local byId, byName = {}, {}
	for _, a in ipairs(auras or {}) do
		local aura = { spellId = a.id, name = ns.SpellNameFor(a.id),
			expirationTime = a.left and (Mock.now + a.left) or 0, sourceUnit = "player" }
		byId[a.id] = aura
		if aura.name then byName[aura.name] = aura end
	end
	rawset(_G, "C_UnitAuras", setmetatable({
		GetUnitAuraBySpellID = function(unit, id)
			if unit == "player" and (ns.OWN_BY_ID[id] or byId[id]) then return byId[id] end
			return base.GetUnitAuraBySpellID(unit, id)
		end,
		GetAuraDataBySpellName = function(unit, name)
			if unit == "player" then return byName[name] end
			return nil
		end,
	}, { __index = base }))
	ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
end

local function warlock(scenario, body)
	Mock.reset()
	Mock.class = "WARLOCK"
	local saved = {}
	for _, name in ipairs(OWN_TOUCHED) do saved[name] = rawget(_G, name) end
	IsSpellKnown = function(id) return id == DEMON_SKIN end
	IsPlayerSpell = IsSpellKnown
	local undo = strangers({})
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		-- Demon Skin is the armor of Forever, Classic Era and TBC; Mists and retail
		-- have other ids and the fixture does not fit them.
		local flavour = ns.Flavour and ns.Flavour.flavour
		if flavour == "mists" or flavour == "mainline" then return end
		wear(ns, {})
		freshPrompt(ns, scenario)
		Mock.runTimers(0)
		ns.Prompt:ExitTest()
		wear(ns, {})
		body(ns)
		noErrors(scenario, ns)
	end)
	undo()
	for _, name in ipairs(OWN_TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- #4
do
	local scenario = "options-fix: Myself says your armor's top-up is due when the prompt offers it, on Skip"
	warlock(scenario, function(ns)
		local f = ns.db.profile.filters
		if f.whenBuffed ~= "skip" or f.selfTopUp ~= true then
			fail(scenario, "SKIPPED -- the defaults are " .. tostring(f.whenBuffed) .. "/" .. tostring(f.selfTopUp))
			return
		end
		wear(ns, { { id = DEMON_SKIN, left = 200 } })
		if key(mine(ns)) ~= "demonarmor" then
			fail(scenario, "SKIPPED -- Demon Skin with 200 s left was not topped up: " .. key(mine(ns)))
			return
		end
		local text = myself(ns)
		if not text:find("running low", 1, true) then
			fail(scenario, "the prompt tops Demon Skin up, and Myself says: " .. text)
		end
	end)
end

-- #5
do
	local scenario = "options-fix: When a top-up is due gives your armor the selfLead moment"
	warlock(scenario, function(ns)
		local f = ns.db.profile.filters
		f.selfLead = 10
		wear(ns, { { id = DEMON_SKIN, left = 500 } })
		if key(mine(ns)) ~= "demonarmor" then
			fail(scenario, "SKIPPED -- ten minutes asked for, Demon Skin with 500 s left: offered " .. key(mine(ns)))
			return
		end
		local line
		for _, l in ipairs(ns.LeadLines()) do
			if l:find(ns.BuffName(ns.FindOwnSpell("demonarmor") or {}) or "\1", 1, true) == 1 or l:find("Demon", 1, true) then
				line = l
			end
		end
		if not line then
			fail(scenario, "SKIPPED -- no line for Demon Skin in " .. table.concat(ns.LeadLines(), " / "))
			return
		end
		if not line:find("topped up at 10m left", 1, true) then
			fail(scenario, "offered at 500 s left (selfLead 10), and the line reads: " .. line)
		end
	end)
end

-- #6
do
	local scenario = "options-fix: the top-up heading does not say off while your own are topped up"
	warlock(scenario, function(ns)
		wear(ns, { { id = DEMON_SKIN, left = 200 } })
		if key(mine(ns)) ~= "demonarmor" then
			fail(scenario, "SKIPPED -- Demon Skin with 200 s left was not topped up: " .. key(mine(ns)))
			return
		end
		local heading = ns.LeadHeading()
		if heading:find("top-ups are off", 1, true) then
			fail(scenario, "defaults: the heading reads '" .. heading .. "' while the prompt tops Demon Skin up"
				.. " under it: " .. table.concat(ns.LeadLines(), " / "))
		end
	end)
end

-- ------------------------------------------------------------------ the full check-up (#7 #8)
local PVP_TOUCHED = { "UnitIsPVP", "UnitIsPVPFreeForAll", "IsPVPTimerRunning" }

local function checkup(scenario, opts, body)
	Mock.reset()
	if opts.flavour then Mock.setFlavour(opts.flavour) end
	local saved = {}
	for _, name in ipairs(PVP_TOUCHED) do saved[name] = rawget(_G, name) end
	local undo = strangers(opts.people or {})
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		Mock.runTimers(0)
		ns.Prompt:ExitTest()
		body(ns)
		noErrors(scenario, ns)
	end)
	undo()
	for _, name in ipairs(PVP_TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function scan(ns, seconds)
	for _ = 1, math.floor(seconds / 0.4 + 0.5) do
		Mock.runTimers(0.4)
		ns.addon:Tick()
	end
end

-- #7 (PvP)
do
	local scenario = "options-fix: the full check-up does not name a player held back for PvP"
	checkup(scenario, { people = { nameplate1 = { "Bobby", "Flagbearer" } } }, function(ns)
		Mock.pvp = { nameplate1 = true }
		scan(ns, 2)
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		local printed = table.concat(Mock.printed, "\n")
		Mock.printed = {}
		if not printed:find("Bobby", 1, true) then
			fail(scenario, "SKIPPED -- /manners debug does not name Bobby: " .. printed:sub(1, 300))
			return
		end
		local text = ns.FullReport()
		-- The /manners debug section's PvP line (the self-test names him too).
		local line = text:match("[^\n]*Bobby[^\n]*flagged for PvP[^\n]*")
		if line then
			fail(scenario, "the check-up, pasted in public, names Bobby in clear: " .. tostring(line))
		end
	end)
end

-- #7 (a request)
do
	local scenario = "options-fix: the full check-up does not name somebody who asked from out of reach"
	checkup(scenario, {}, function(ns)
		ns.db.profile.sources.asked = true
		ns.addon.CHAT_MSG_WHISPER(ns.addon, "CHAT_MSG_WHISPER", "int pls", "Zedd Faraway", "Common", "", "", "",
			0, 0, "", 0, 1, "Player-1-00ZZZZZZ")
		local lines = table.concat(ns.RequestLines(), "\n")
		if not lines:find("Zedd", 1, true) then
			fail(scenario, "SKIPPED -- the request was not noted: " .. lines)
			return
		end
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.name == "Zedd Faraway" then
				fail(scenario, "SKIPPED -- Zedd is queued, so the queue aliases him")
				return
			end
		end
		local text = ns.FullReport()
		if text:find("Zedd", 1, true) then
			local line = text:match("[^\n]*Zedd[^\n]*")
			fail(scenario, "the check-up, pasted in public, names Zedd in clear: " .. tostring(line))
		end
	end)
end

-- #8
do
	local scenario = "options-fix: a player named Bug leaves the check-up's own words alone"
	checkup(scenario, { flavour = "vanilla", people = { nameplate1 = { "Bug" } } }, function(ns)
		H.primeAuras(ns)
		H.favourFrom(ns, "nameplate1", 10938, 9101)
		ns.addon:Tick()
		local text = ns.FullReport()
		if not text:find("Person 1", 1, true) then
			fail(scenario, "SKIPPED -- nobody was aliased: " .. text:sub(1, 200))
			return
		end
		if not text:find("== Bug report ==", 1, true) then
			fail(scenario, "the alias for Bug overwrote the report's heading: "
				.. tostring(text:match("== [^\n]* report ==")))
		end
	end)
end

-- A name is a word of its own: Intel is not the start of Intellect.
do
	local scenario = "options-fix: a player named Intel leaves the word Intellect alone"
	checkup(scenario, { flavour = "vanilla", people = { nameplate1 = { "Intel" } } }, function(ns)
		H.primeAuras(ns)
		H.favourFrom(ns, "nameplate1", 10938, 9101)
		ns.addon:Tick()
		local text = ns.FullReport()
		if not text:find("Person 1", 1, true) then
			fail(scenario, "SKIPPED -- nobody was aliased: " .. text:sub(1, 200))
			return
		end
		if text:find("Person 1lect", 1, true) then
			fail(scenario, "the alias for Intel overwrote the start of Intellect: "
				.. tostring(text:match("[^\n]*Person 1lect[^\n]*")))
		elseif not text:find("Intellect", 1, true) then
			fail(scenario, "SKIPPED -- the report never says Intellect")
		end
	end)
end
