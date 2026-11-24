-- The self-test's fight group (Selftest.lua, "Fight buttons and keys"): the cure
-- buttons and their keys, what the game answers in a fight, the healthstone's
-- reagent, the shape of the mute list, and every key Manners holds. Every line
-- is a PASS or a WARN, never a FAIL: a missing call is a fact about the client.
--
-- Every name starts with "selftest-fight:" so the mutations in
-- tests/mutations/selftest-fight.py can name exactly one.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

local CURE = "CLICK MannersCureFight:LeftButton"
local CURE2 = "CLICK MannersCureFight2:LeftButton"
local PROMPT = "CLICK MannersPrompt:LeftButton"
local FLAVOURS = { "camelot", "vanilla", "tbc", "mists", "mainline" }

local function everything()
	return setmetatable({}, { __index = function() return true end })
end

-- One session: `opts.class` on `opts.flavour`, every spell known, the prompt
-- made, body(ns) run, the globals put back.
local function with(scenario, body, opts)
	opts = opts or {}
	Mock.reset()
	Mock.setFlavour(opts.flavour or "camelot")
	Mock.class = opts.class or "DRUID"
	Mock.knownSpells = everything()
	local saved = {}
	for _, name in ipairs({ "OlympusMuteDB", "C_UnitAuras", "C_LossOfControl", "UnitIsCharmed", "C_Item" }) do
		saved[name] = rawget(_G, name)
	end
	local restore = strangers({})
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		Mock.timers = {}
		Mock.eventSink = ns.addon
		ns.KeyNudge = nil
		Mock.bindings = Mock.bindings or {}
		if opts.edit then opts.edit(ns.db.profile.prompt, ns) end
		ns.addon:Tick()
		Mock.runTimers(0)
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	for name, value in pairs(saved) do rawset(_G, name, value) end
	Mock.modifiers = {}
	restore()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- The results of one check, each as "STATUS value".
local function results(ns, id)
	local out = {}
	for _, r in ipairs(ns.Selftest.Run()) do
		if r.id == id then out[#out + 1] = { status = r.status, value = tostring(r.value) } end
	end
	return out
end

local function show(list)
	local parts = {}
	for _, r in ipairs(list) do parts[#parts + 1] = r.status .. " " .. r.value end
	return table.concat(parts, " | ")
end

local function any(list, status, text)
	for _, r in ipairs(list) do
		if r.status == status and r.value:find(text, 1, true) then return true end
	end
	return false
end

do
	local scenario = "selftest-fight: cure buttons and keys pass when made and bound"
	with(scenario, function(ns)
		Mock.bindings.F = CURE
		ns.addon:Tick()
		Mock.runTimers(0)
		local list = results(ns, "fight.cure")
		if not any(list, "PASS", "cure: button made, header peace, key F") then
			fail(scenario, "the first cure is not a pass with its key: " .. show(list))
		end
		if not any(list, "PASS", "second cure: button made, header peace, no key: a click on it casts") then
			fail(scenario, "the second cure is not a pass with no key: " .. show(list))
		end
		Mock.bindings.G = CURE2
		list = results(ns, "fight.cure")
		if not any(list, "PASS", "second cure: button made, header peace, key G") then
			fail(scenario, "the second cure's key is not read: " .. show(list))
		end
		-- No key at all: a click on it casts.
		Mock.bindings = {}
		list = results(ns, "fight.cure")
		if not any(list, "PASS", "cure: button made, header peace, no key: a click on it casts") then
			fail(scenario, "no key is not said: " .. show(list))
		end
		for _, r in ipairs(list) do
			if r.status == "FAIL" then fail(scenario, "a cure line fails: " .. r.value) end
		end
		-- Off, or no cure at all.
		ns.db.profile.prompt.cureFight = false
		if not any(results(ns, "fight.cure"), "PASS", "switched off") then fail(scenario, "a cure switched off is not said") end
	end, { edit = function(p) p.cureFight, p.cureFightEach = true, true end })
	with(scenario, function(ns)
		local list = results(ns, "fight.cure")
		if not any(list, "PASS", "no cure for this class") then fail(scenario, "a class with no cure: " .. show(list)) end
	end, { class = "ROGUE" })
end

do
	-- A class with a cure on this client, none learned yet, the switch on (its
	-- default): no button is made for it, and that is no fault.
	local scenario = "selftest-fight: a cure not learned yet is no warning"
	with(scenario, function(ns)
		ns.CureFightSpells = function() return nil end
		local list = results(ns, "fight.cure")
		if not any(list, "PASS", "no cure learned yet") then
			fail(scenario, "a cure not learned is not a pass: " .. show(list))
		end
		for _, r in ipairs(list) do
			if r.status == "WARN" then fail(scenario, "a cure not learned warns: " .. r.value) end
		end
	end, { edit = function(p) p.cureFight, p.cureFightEach = true, false end })
end

do
	local scenario = "selftest-fight: a cure switched on and never made warns"
	with(scenario, function(ns)
		ns.CureFight.Button = function() return nil end
		local list = results(ns, "fight.cure")
		if not any(list, "WARN", "switched on, but the button was never made") then
			fail(scenario, "a button never made is not a warning: " .. show(list))
		end
	end, { edit = function(p) p.cureFight, p.cureFightEach = true, false end })
	-- Made, but its header is not at peace.
	with(scenario, function(ns)
		ns.CureFight:Header():SetAttribute("state-mannerscurefight", "fight")
		local list = results(ns, "fight.cure")
		if not any(list, "WARN", "its header says fight, not peace") then
			fail(scenario, "a header not at peace is not a warning: " .. show(list))
		end
	end, { edit = function(p) p.cureFight, p.cureFightEach = true, false end })
end

do
	local scenario = "selftest-fight: the fight APIs are reported as data on every client"
	for _, flavour in ipairs(FLAVOURS) do
		with(scenario .. " (" .. flavour .. ")", function(ns)
			local list = results(ns, "fight.apis")
			if #list ~= 3 then fail(scenario .. " (" .. flavour .. ")", #list .. " lines: " .. show(list)) end
			for _, r in ipairs(list) do
				if r.status ~= "PASS" then fail(scenario .. " (" .. flavour .. ")", "not data only: " .. r.status .. " " .. r.value) end
			end
			local auras = _G.C_UnitAuras
			local want = (type(auras) == "table" and type(auras.GetUnitAuraInstanceIDs) == "function") and "yes" or "no"
			if not any(list, "PASS", "the game's list of debuffs you can remove: " .. want) then
				fail(scenario .. " (" .. flavour .. ")", "the list is not reported as " .. want .. ": " .. show(list))
			end
			if not any(list, "PASS", "loss of control: ") then fail(scenario .. " (" .. flavour .. ")", "no loss-of-control shape") end
			if not any(list, "PASS", "charmed: ") then fail(scenario .. " (" .. flavour .. ")", "no charm line") end
			-- Take the list away and the line says no.
			local copy = {}
			for k, v in pairs(_G.C_UnitAuras or {}) do copy[k] = v end
			copy.GetUnitAuraInstanceIDs = nil
			rawset(_G, "C_UnitAuras", copy)
			rawset(_G, "C_LossOfControl", false)
			list = results(ns, "fight.apis")
			if not any(list, "PASS", "debuffs you can remove: no") then fail(scenario .. " (" .. flavour .. ")", "a missing list is not no: " .. show(list)) end
			if not any(list, "PASS", "loss of control: none") then fail(scenario .. " (" .. flavour .. ")", "a missing API is not none: " .. show(list)) end
		end, { flavour = flavour })
	end
end

do
	local scenario = "selftest-fight: a warlock's healthstone counts, nothing for others"
	with(scenario, function(ns)
		rawset(_G, "C_Item", setmetatable({
			GetItemCount = function(id)
				if id == 5512 then return 2 end
				if id == 6265 then return 5 end
				return 0
			end,
		}, { __index = rawget(_G, "C_Item") }))
		local list = results(ns, "fight.healthstone")
		if not any(list, "PASS", "stones in bags 2") then fail(scenario, "the stones are not counted: " .. show(list)) end
		if not any(list, "PASS", "Soul Shards 5") then fail(scenario, "the shards are not counted: " .. show(list)) end
		if not any(list, "PASS", "spell known yes") then fail(scenario, "the spell is not read: " .. show(list)) end
	end, { class = "WARLOCK" })
	with(scenario, function(ns)
		local list = results(ns, "fight.healthstone")
		if not any(list, "PASS", "Soul Shards none needed") then fail(scenario, "Mists needs no shard: " .. show(list)) end
	end, { class = "WARLOCK", flavour = "mists" })
	with(scenario, function(ns)
		if not any(results(ns, "fight.healthstone"), "PASS", "not a warlock") then fail(scenario, "a mage is not told so") end
	end, { class = "MAGE" })
end

do
	local scenario = "selftest-fight: the mute list's shape, counts only"
	with(scenario, function(ns)
		if not any(results(ns, "fight.mutelist"), "PASS", "not loaded") then fail(scenario, "no table is not 'not loaded'") end
		rawset(_G, "OlympusMuteDB", { enabled = true, names = { Zedrick = true, Yanna = true },
			keywords = { "secretword" }, allow = {}, partyPass = {}, guildAllow = {} })
		local list = results(ns, "fight.mutelist")
		if not any(list, "PASS", "enabled true, names table (2), keywords table (1)") then
			fail(scenario, "the counts are not there: " .. show(list))
		end
		local text = show(list)
		if text:find("Zedrick", 1, true) or text:find("Yanna", 1, true) or text:find("secretword", 1, true) then
			fail(scenario, "a name or a word of the list is in the report: " .. text)
		end
		for _, r in ipairs(list) do if r.status == "WARN" then fail(scenario, "a good list warns: " .. r.value) end end
		-- A list of a shape Manners does not read, with the skip on.
		rawset(_G, "OlympusMuteDB", { enabled = true, names = "none" })
		ns.db.profile.filters.skipMuted = true
		list = results(ns, "fight.mutelist")
		if not any(list, "WARN", "its list has a shape Manners does not read, so nobody is skipped") then
			fail(scenario, "an unreadable list is not a warning: " .. show(list))
		end
		ns.db.profile.filters.skipMuted = false
		for _, r in ipairs(results(ns, "fight.mutelist")) do
			if r.status == "WARN" then fail(scenario, "the skip off still warns: " .. r.value) end
		end
	end)
end

do
	local scenario = "selftest-fight: a Shift key taken by another Manners key warns"
	with(scenario, function(ns)
		Mock.bindings.F = CURE
		Mock.bindings["SHIFT-F"] = PROMPT
		ns.addon:Tick()
		Mock.runTimers(0)
		if not ns.CureFight.ShiftClause() then fail(scenario, "SKIPPED -- the cure macro carries no Shift clause") return end
		local list = results(ns, "fight.keys")
		if not any(list, "WARN", "Shift+F is the key for") then
			fail(scenario, "the taken Shift key is not a warning: " .. show(list))
		end
		-- A key of its own for Shift is no warning.
		Mock.bindings["SHIFT-F"] = nil
		for _, r in ipairs(results(ns, "fight.keys")) do
			if r.status == "WARN" then fail(scenario, "a free Shift key warns: " .. r.value) end
		end
		-- One key on two commands.
		local real = ns.Setup.Key
		ns.Setup.Key = function() return "F" end
		list = results(ns, "fight.keys")
		ns.Setup.Key = real
		if not any(list, "WARN", "F is the key for both") then fail(scenario, "one key on two commands is not a warning: " .. show(list)) end
	end, { edit = function(p) p.cureFight, p.cureFightEach = true, false end })

	with(scenario, function(ns)
		Mock.bindings = { F = PROMPT }
		if not any(results(ns, "fight.keys"), "PASS", "prompt=F") then fail(scenario, "the prompt's key is not listed") end
		if not any(results(ns, "fight.keys"), "PASS", "mark=click") then fail(scenario, "the mark key is not listed") end
	end, { class = "PRIEST" })
end

do
	local scenario = "selftest-fight: nothing fails for a missing API"
	with(scenario, function(ns)
		rawset(_G, "C_UnitAuras", false)
		rawset(_G, "C_LossOfControl", false)
		rawset(_G, "UnitIsCharmed", false)
		rawset(_G, "C_Item", false)
		rawset(_G, "OlympusMuteDB", false)
		local all = ns.Selftest.Run()
		local seen = {}
		for _, r in ipairs(all) do
			if r.group == "fight" then
				seen[r.id] = true
				if r.status == "FAIL" then fail(scenario, r.id .. " fails: " .. tostring(r.value)) end
			end
		end
		for _, id in ipairs({ "fight.cure", "fight.apis", "fight.healthstone", "fight.mutelist", "fight.keys" }) do
			if not seen[id] then fail(scenario, id .. " has no line") end
		end
		local text = ns.Selftest.Report(all)
		if not text:find("[Fight buttons and keys]", 1, true) then fail(scenario, "the report has no group heading") end
	end, { class = "WARLOCK" })
end
