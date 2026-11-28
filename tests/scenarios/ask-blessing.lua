-- Which blessing a paladin is asked for (GitHub issue 57, broodwave on
-- CurseForge: "As a druid, it seems to default to ask Paladins for Blessing of
-- Wisdom always ... Especially as a Feral, Wisdom is the least one I need").
-- Ask people for a buff I'm missing has "Blessing to ask a paladin for" under
-- it (ask.blessing, Automatic by default: Wisdom with mana, Might without);
-- a blessing chosen there is the one asked for.
--
-- Every scenario name starts with "ask-blessing:" so the mutations in
-- tests/mutations/ask-blessing.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, findOption = H.strangers, H.freshPrompt, H.findOption

local TOUCHED = { "IsResting", "UnitAffectingCombat" }

local function asking(ns)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.ask then return entry end
	end
	return nil
end

local function with(scenario, body)
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	rawset(_G, "IsResting", function() return false end)
	rawset(_G, "UnitAffectingCombat", function() return false end)
	Mock.reset()
	Mock.class = "DRUID"
	Mock.unitClass = "PALADIN"
	Mock.playerHeld = {}
	-- Everybody else wears Mark of the Wild, so the queue holds only the ask.
	Mock.held = { [1126] = true, [5232] = true, [6756] = true, [5234] = true, [8907] = true, [9884] = true, [9885] = true }
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		ns.db.profile.sources.ask = true
		ns.Ask.ARRIVE_SECONDS = 0
		ns.db.profile.sources.self = false
		ns.db.profile.sources.group = false
		ns.db.profile.sources.strangers = false
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	restoreUnits()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

do
	local scenario = "ask-blessing: a druid who chose Might asks a paladin for Might"
	with(scenario, function(ns)
		local entry = asking(ns)
		if not entry then
			fail(scenario, "a paladin beside a druid with no blessing is not asked")
			return
		end
		if entry.buff.wanted.key ~= "wisdom" then
			fail(scenario, "with Automatic a druid with mana asks for " .. tostring(entry.buff.wanted.key) .. ", not Wisdom")
		end
		local control = findOption(ns.optionsTable, "askBlessing")
		if not control then
			fail(scenario, "Who to buff has no Blessing to ask a paladin for")
			return
		end
		if control.hidden() then fail(scenario, "Blessing to ask a paladin for is hidden with asking on") end
		if control.get() ~= "auto" then fail(scenario, "the choice reads " .. tostring(control.get()) .. " out of the box") end
		if not control.values().might then fail(scenario, "Blessing of Might is not one of the choices") end
		control.set(nil, "might")
		ns.Ask.ForgetWorn()
		entry = asking(ns)
		if not (entry and entry.buff.wanted.key == "might") then
			fail(scenario, "with Might chosen the paladin is asked for " .. tostring(entry and entry.buff.wanted.key))
		end
		local page, section = H.placedOn(ns, "who.askBlessing")
		if page ~= "click" or not (section and section.key == "click.asking") then
			fail(scenario, "who.askBlessing is not drawn on What I say, under Asking for a buff")
		end
	end)
end

do
	local scenario = "ask-blessing: a choice that is no blessing goes back to Automatic"
	with(scenario, function(ns)
		ns.db.profile.ask.blessing = "fortitude"
		ns.ClampSettings()
		if ns.db.profile.ask.blessing ~= "auto" then
			fail(scenario, "a saved choice of no blessing was kept: " .. tostring(ns.db.profile.ask.blessing))
		end
		ns.db.profile.ask.blessing = "might"
		ns.ClampSettings()
		if ns.db.profile.ask.blessing ~= "might" then
			fail(scenario, "Might was not kept: " .. tostring(ns.db.profile.ask.blessing))
		end
	end)
end
