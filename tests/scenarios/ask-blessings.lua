-- A chosen Paladin blessing, and a second reachable Paladin for another one.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, pressButton = H.strangers, H.freshPrompt, H.pressButton
local findOption = H.findOption

local TOUCHED = { "IsResting", "UnitAffectingCombat", "IsInInstance", "UnitIsAFK", "UnitIsDND",
	"UnitLevel", "UnitExists", "UnitInRange" }
local original = {}
for _, name in ipairs(TOUCHED) do original[name] = rawget(_G, name) end

local function restore()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, original[name]) end
end

local function ready(scenario)
	Mock.reset()
	Mock.setFlavour("camelot")
	Mock.class = "WARRIOR"
	Mock.unitClass = "PALADIN"
	Mock.playerHeld = {}
	rawset(_G, "IsResting", function() return false end)
	rawset(_G, "UnitAffectingCombat", function() return false end)
	local restoreUnits = strangers({
		nameplate1 = { "Anna", "Aim" },
		nameplate2 = { "Bert", "Brave" },
	})
	local ns = load(scenario)
	if not ns then
		restoreUnits()
		restore()
		return nil
	end
	freshPrompt(ns, scenario)
	ns.db.profile.sources.ask = true
	ns.Ask.ARRIVE_SECONDS = 0
	return ns, function()
		restoreUnits()
		restore()
	end
end

local function asking(ns)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.ask then return entry end
	end
end

do
	local scenario = "ask-blessings: a chosen Paladin blessing is the one Manners asks for"
	local ns, done = ready(scenario)
	if ns then
		local db = ns.db.profile
		local kings = ns.FindBuff("PALADIN", "kings")
		if not kings then
			fail(scenario, "SKIPPED -- this client has no Kings")
		else
			db.ask.blessing = "kings"
			local might = ns.FindBuff("PALADIN", "might")
			Mock.playerHeld = { [might.ranks[1]] = true }
			ns.Ask.ForgetWorn()
			local entry = asking(ns)
			if not entry or entry.buff.wanted.key ~= "kings" then
				fail(scenario, "the explicit choice asked for "
					.. tostring(entry and entry.buff and entry.buff.wanted and entry.buff.wanted.key))
			end
			local values, sorting = ns.Ask.Blessings()
			if values.auto ~= ns.L["Automatic"] or values.kings == nil or sorting[1] ~= "auto" then
				fail(scenario, "the blessing control does not list Automatic and this client's blessings")
			end
			local control = findOption(ns.optionsTable, "askBlessing")
			if not control or control.name ~= ns.L["Blessing to ask a paladin for"] then
				fail(scenario, "the blessing control does not list Automatic and this client's blessings")
			end
		end
		done()
	end
end

do
	local scenario = "ask-blessings: Automatic asks another reachable Paladin for a different blessing"
	local ns, done = ready(scenario)
	if ns then
		local first = asking(ns)
		if not first then
			fail(scenario, "no Paladin was asked for the first blessing")
		else
			local firstKey = first.buff.wanted.key
			ns.Prompt:Refresh()
			pressButton(ns)
			Mock.playerHeld = { [first.buff.wanted.ranks[1]] = true }
			ns.Ask.ForgetWorn()
			Mock.advance(121)
			local second = asking(ns)
			if not second then
				fail(scenario, "the other Paladin was not offered after the first request")
			elseif second.name == first.name then
				fail(scenario, "the same Paladin was asked for both blessings")
			elseif second.buff.wanted.key == firstKey then
				fail(scenario, "the other Paladin was asked for the same blessing")
			end
		end
		done()
	end
end

do
	local scenario = "ask-blessings: an invalid saved choice is repaired to Automatic"
	local ns, done = ready(scenario)
	if ns then
		ns.db.profile.ask.blessing = "missing"
		ns.AskClamp(ns.db.profile)
		if ns.db.profile.ask.blessing ~= "auto" then
			fail(scenario, "the invalid Paladin choice was kept as " .. tostring(ns.db.profile.ask.blessing))
		end
		if ns.defaults.profile.ask.blessing ~= "auto" then
			fail(scenario, "a new profile's Paladin choice is not Automatic")
		end
		done()
	end
end
