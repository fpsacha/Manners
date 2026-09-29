-- The Advanced tab (Options.lua, BuildAdvancedTab): the tuning knobs that used
-- to be spread over the other tabs -- favours, timing, targeting, the exact
-- position and the prompt's wording -- under one intro, a combat notice and a
-- button that puts them back to default.
--
-- Every control moved here kept its option key and its get/set, so the profile
-- field it writes is where it always was: a player upgrading keeps every value.
--
-- Called by scenarios.lua with the addon directory and its helpers.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive
local findOption, optionText = H.findOption, H.optionText

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

local function session(scenario, class)
	Mock.reset()
	Mock.sv = {}
	if class then Mock.class = class end
	local ns = load(scenario)
	if not ns then return nil end
	drive(scenario, ns)
	ns.Prompt:ExitTest()
	return ns
end

local function tab(ns)
	return ns.optionsTable and ns.optionsTable.args and ns.optionsTable.args.advanced
end

-- The page as it should read, top to bottom: key, order, and the English label.
local LAYOUT = {
	{ "advIntro", 0.5, "The defaults suit most players; change these only if something bothers you." },
	{ "advCombatNotice", 0.6, "In combat: targeting changes apply once the fight ends." },
	{ "resetAdvanced", 0.7, "Put these back to default" },
	{ "favoursHeader", 10, "Favours" },
	{ "owedClassBuffsOnly", 11, "Ignore shields, heals and trinket procs" },
	{ "reciprocateWindow", 12, "Offer a buff back for (seconds)" },
	{ "reachableOnly", 13, "Stop sooner if they are probably gone" },
	{ "graceSeconds", 14, "Let them go after (seconds)" },
	{ "keepDebts", 15, "Keep favours through a /reload" },
	{ "timingHeader", 20, "Timing" },
	{ "retryCooldown", 21, "Don't repeat a spell on someone for (seconds)" },
	{ "scanInterval", 22, "Check for people every (seconds)" },
	{ "targetingHeader", 30, "Targeting" },
	{ "restoreTarget", 31, "Hand my target back afterwards" },
	{ "noTargetNote", 31.5 },
	{ "exactPosHeader", 40, "Exact position" },
	{ "x", 41, "Left / right" },
	{ "y", 42, "Up / down" },
	{ "wordingHeader", 50, "Prompt wording" },
	{ "formatHelp", 51, "Placeholders: {name} their name" },
	{ "format", 52, "First line" },
	{ "reasonTarget", 53, "Reason text: my target" },
	{ "reasonOwed", 54, "Reason text: buffed me" },
	{ "reasonAsked", 55, "Reason text: asked in chat" },
	{ "reasonGroup", 56, "Reason text: my group" },
	{ "reasonNearby", 57, "Reason text: passer-by" },
	{ "reasonRefresh", 58, "Reason text: top-up" },
	{ "reasonUnknown", 59, "Reason text: can't tell" },
}

-- Each control that writes a setting, and the profile field it writes.
local FIELDS = {
	{ "owedClassBuffsOnly", "sources", "owedClassBuffsOnly" },
	{ "reciprocateWindow", "timing", "reciprocateWindow" },
	{ "reachableOnly", "filters", "reachableOnly" },
	{ "graceSeconds", "timing", "graceSeconds" },
	{ "keepDebts", "timing", "keepDebts" },
	{ "retryCooldown", "timing", "retryCooldown" },
	{ "scanInterval", "timing", "scanInterval" },
	{ "restoreTarget", "filters", "restoreTarget" },
	{ "x", "prompt", "x" },
	{ "y", "prompt", "y" },
	{ "format", "prompt", "format" },
	{ "reasonTarget", "prompt", "reasonTarget" },
	{ "reasonOwed", "prompt", "reasonOwed" },
	{ "reasonAsked", "prompt", "reasonAsked" },
	{ "reasonGroup", "prompt", "reasonGroup" },
	{ "reasonNearby", "prompt", "reasonNearby" },
	{ "reasonRefresh", "prompt", "reasonRefresh" },
	{ "reasonUnknown", "prompt", "reasonUnknown" },
}

-- What the reset puts back, beyond the controls: the anchor the two offsets
-- are measured from.
local RESET = {}
for _, f in ipairs(FIELDS) do RESET[#RESET + 1] = { f[2], f[3] } end
RESET[#RESET + 1] = { "prompt", "point" }
RESET[#RESET + 1] = { "prompt", "relPoint" }

-- A value that is not the default, whatever the field's type.
local function other(value, name)
	if type(value) == "boolean" then return not value end
	if type(value) == "number" then return value + 7 end
	if name == "point" or name == "relPoint" then
		return value == "TOP" and "LEFT" or "TOP"
	end
	return "changed " .. name .. " {name}"
end

-- ------------------------------------------------------------------ 1
do
	local scenario = "advanced: the tab reads top to bottom as laid out"
	local ns = session(scenario)
	local adv = ns and tab(ns)
	if ns and not adv then
		fail(scenario, "there is no Advanced tab")
	elseif ns then
		if optionText(adv.name) ~= "Advanced" then
			fail(scenario, "the tab is called " .. optionText(adv.name))
		end
		if adv.order ~= 6 then
			fail(scenario, "the tab is at order " .. tostring(adv.order) .. ", not 6")
		end
		for _, want in ipairs(LAYOUT) do
			local key, order, label = want[1], want[2], want[3]
			local option = adv.args[key]
			if not option then
				fail(scenario, "advanced: " .. key .. " is not on the tab")
			else
				if option.order ~= order then
					fail(scenario, ("advanced: %s is at order %s, not %s")
						:format(key, tostring(option.order), tostring(order)))
				end
				local text = optionText(option.name)
				if label and not text:find(label, 1, true) then
					fail(scenario, ("advanced: %s reads \"%s\", not \"%s\"")
						:format(key, text, label))
				end
			end
		end
		-- The macro jargon is gone.
		if findOption(ns.optionsTable, "targetingNote") then
			fail(scenario, "the targeting note, with its macro commands, is still on the page")
		end
		-- The help is read before the box it explains.
		local help, box = adv.args.formatHelp, adv.args.format
		if help and box and not (help.order < box.order) then
			fail(scenario, "the placeholder help sits below the box it explains")
		end
		if help and not optionText(help.name):find("The second line always shows the reason.", 1, true) then
			fail(scenario, "the placeholder help no longer says the second line shows the reason")
		end
		-- The reset asks first.
		local reset = adv.args.resetAdvanced
		if reset and not (reset.type == "execute" and reset.confirm
			and optionText(reset.confirmText) == "Put every setting on this tab back to its default?") then
			fail(scenario, "Put these back to default does not ask before it resets")
		end
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------------ 2
-- A class with nothing to give has nothing to tune.
do
	local scenario = "advanced: shown only to a class with buffs"
	local ns = session(scenario)
	local adv = ns and tab(ns)
	if ns and not adv then
		fail(scenario, "SKIPPED -- there is no Advanced tab")
	elseif ns then
		if adv.hidden and adv.hidden() then
			fail(scenario, "the Advanced tab is hidden from a mage")
		end
		local rogue = session(scenario, "ROGUE")
		local radv = rogue and tab(rogue)
		if rogue and not (radv and radv.hidden and radv.hidden()) then
			fail(scenario, "the Advanced tab is shown to a rogue, who has no buff to tune")
		end
	end
end

-- ------------------------------------------------------------------ 3
-- Moving a control must not move its setting.
do
	local scenario = "advanced: every control writes the field it always wrote"
	local ns = session(scenario)
	if ns then
		local profile = ns.db.profile
		for _, f in ipairs(FIELDS) do
			local key, section, name = f[1], f[2], f[3]
			local option = findOption(ns.optionsTable, key)
			if not (option and option.get and option.set) then
				fail(scenario, "advanced: " .. key .. " has no get or set")
			else
				local before = profile[section][name]
				local value = other(before, name)
				option.set({ key }, value)
				if profile[section][name] ~= value then
					fail(scenario, ("advanced: %s did not write %s.%s"):format(key, section, name))
				elseif option.get({ key }) ~= value then
					fail(scenario, ("advanced: %s does not read %s.%s back"):format(key, section, name))
				end
				option.set({ key }, before)
			end
		end
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------------ 4
do
	local scenario = "advanced: controls grey out and hide by what they depend on"
	local ns = session(scenario)
	local adv = ns and tab(ns)
	if ns and not adv then
		fail(scenario, "SKIPPED -- there is no Advanced tab")
	elseif ns then
		local a = adv.args
		local s, f = ns.db.profile.sources, ns.db.profile.filters

		s.owed = false
		if not (a.owedClassBuffsOnly.disabled and a.owedClassBuffsOnly.disabled()) then
			fail(scenario, "Ignore shields, heals and trinket procs is live with People who buffed me off")
		end
		s.owed = true
		if a.owedClassBuffsOnly.disabled and a.owedClassBuffsOnly.disabled() then
			fail(scenario, "Ignore shields, heals and trinket procs is greyed out with People who buffed me on")
		end

		f.reachableOnly = false
		if not (a.graceSeconds.disabled and a.graceSeconds.disabled()) then
			fail(scenario, "Let them go after is live with Stop sooner off")
		end
		f.reachableOnly = true
		if a.graceSeconds.disabled and a.graceSeconds.disabled() then
			fail(scenario, "Let them go after is greyed out with Stop sooner on")
		end

		-- The wording for somebody who asked is edited whether or not asking
		-- is switched on: it is wording, and waits for the switch.
		s.asked = false
		local disabled = a.reasonAsked.disabled
		if disabled == true or (type(disabled) == "function" and disabled()) then
			fail(scenario, "the asked wording is greyed out while asking is off")
		end

		Mock.inCombat = false
		if not (a.advCombatNotice.hidden and a.advCombatNotice.hidden()) then
			fail(scenario, "the combat notice shows out of combat")
		end
		Mock.inCombat = true
		if a.advCombatNotice.hidden and a.advCombatNotice.hidden() then
			fail(scenario, "the combat notice is hidden in combat")
		end
		Mock.inCombat = false
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------------ 5
-- The targeting section follows the macro: a warrior's shout never targets, so
-- the switch is hidden and the grey note says why; a mage sees the switch.
for _, case in ipairs({
	{ class = "MAGE", targets = true },
	{ class = "WARRIOR", targets = false },
}) do
	local scenario = "advanced: the targeting section fits the class (" .. case.class .. ")"
	Mock.reset()
	Mock.class = case.class
	local ns = load(scenario)
	if ns then
		local realKnown = IsSpellKnown
		if case.class == "WARRIOR" then H.knowShout(ns) end
		drive(scenario, ns)
		ns.Guard("probe", ns.ProbeCapabilities)
		local toggle = findOption(ns.optionsTable, "restoreTarget")
		local note = findOption(ns.optionsTable, "noTargetNote")
		if not (toggle and note) then
			fail(scenario, "SKIPPED -- the targeting controls are not on the page")
		else
			local toggleHidden = toggle.hidden and toggle.hidden() and true or false
			local noteHidden = note.hidden and note.hidden() and true or false
			if case.targets and toggleHidden then
				fail(scenario, "advanced: the macro takes a target and the switch that hands it back is hidden")
			elseif not case.targets and not toggleHidden then
				fail(scenario, "advanced: the page offers to hand back a target the macro never takes")
			end
			if noteHidden == toggleHidden then
				fail(scenario, "advanced: the switch and the grey note are both shown, or both hidden")
			end
		end
		IsSpellKnown = realKnown
		IsPlayerSpell = realKnown
		noErrors(scenario, ns)
	end
end
Mock.reset()

-- ------------------------------------------------------------------ 6
-- Put these back to default: this tab's fields and nothing else, kept
-- favours written the way the switch writes them, and the page redrawn.
do
	local scenario = "advanced: put these back to default"
	local ns = session(scenario)
	local reset = ns and findOption(ns.optionsTable, "resetAdvanced")
	if ns and not (reset and reset.func) then
		fail(scenario, "there is no Put these back to default button")
	elseif ns then
		local profile, defaults = ns.db.profile, ns.defaults.profile
		for _, f in ipairs(RESET) do
			profile[f[1]][f[2]] = other(defaults[f[1]][f[2]], f[2])
		end
		-- Two settings from other tabs, which must be left as they are.
		profile.prompt.scale = 1.25
		profile.sources.owed = false

		-- A favour kept with the switch off is on nobody's disk.
		wipe(ns.owed)
		ns.owed["Yorick Vane"] = { expires = GetTime() + 120, at = GetTime() }
		ns.addon:SaveDebts()
		local wasWritten = Mock.sv.char and Mock.sv.char.debts

		local calls = { scan = 0, style = 0, macro = 0, redraw = 0 }
		local realScan = ns.addon.StartScanner
		local realStyle, realMacro = ns.Prompt.ApplyStyle, ns.Prompt.InvalidateMacro
		local realRedraw = ns.RefreshOptionsDisplay
		ns.addon.StartScanner = function(...) calls.scan = calls.scan + 1; return realScan(...) end
		ns.Prompt.ApplyStyle = function(...) calls.style = calls.style + 1; return realStyle(...) end
		ns.Prompt.InvalidateMacro = function(...) calls.macro = calls.macro + 1; return realMacro(...) end
		ns.RefreshOptionsDisplay = function(...) calls.redraw = calls.redraw + 1; return realRedraw(...) end

		reset.func({ "resetAdvanced" })

		ns.addon.StartScanner = realScan
		ns.Prompt.ApplyStyle, ns.Prompt.InvalidateMacro = realStyle, realMacro
		ns.RefreshOptionsDisplay = realRedraw

		for _, f in ipairs(RESET) do
			if profile[f[1]][f[2]] ~= defaults[f[1]][f[2]] then
				fail(scenario, ("advanced reset: %s.%s was not put back (%s, default %s)")
					:format(f[1], f[2], tostring(profile[f[1]][f[2]]), tostring(defaults[f[1]][f[2]])))
			end
		end
		if profile.prompt.scale ~= 1.25 or profile.sources.owed ~= false then
			fail(scenario, "advanced reset: put back a setting from another tab")
		end
		if wasWritten then
			fail(scenario, "SKIPPED -- a favour was written with the switch off")
		elseif not (Mock.sv.char and Mock.sv.char.debts and Mock.sv.char.debts["Yorick Vane"]) then
			fail(scenario, "advanced reset: switched keeping favours back on without saving them,"
				.. " the way the switch itself does")
		end
		if calls.scan == 0 then
			fail(scenario, "advanced reset: the new timings were not handed to the scanner")
		end
		if calls.style == 0 or calls.macro == 0 then
			fail(scenario, "advanced reset: the prompt was not restyled and its macro rebuilt")
		end
		if calls.redraw == 0 then
			fail(scenario, "advanced reset: the page still shows the old values")
		end
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------------ 7
-- The same button pressed in a fight: saved, and the secure button left alone
-- until the fight ends.
do
	local scenario = "advanced: put back in a fight leaves the secure button alone"
	local ns = session(scenario)
	local reset = ns and findOption(ns.optionsTable, "resetAdvanced")
	local button = ns and ns.Prompt:GetButton()
	if ns and not (reset and reset.func and button) then
		fail(scenario, "SKIPPED -- no reset button or no prompt")
	elseif ns then
		local profile, defaults = ns.db.profile, ns.defaults.profile
		profile.prompt.x = defaults.prompt.x + 40
		ns.Prompt:ApplyStyle()
		Mock.protect(button)
		Mock.inCombat = true
		Mock.protectedCalls = {}
		reset.func({ "resetAdvanced" })
		if #Mock.protectedCalls > 0 then
			fail(scenario, "advanced reset in a fight called " .. table.concat(Mock.protectedCalls, ", ")
				.. " on the secure button")
		end
		if profile.prompt.x ~= defaults.prompt.x then
			fail(scenario, "advanced reset in a fight was not saved")
		end
		Mock.inCombat = false
		Mock.protectedCalls = {}
		noErrors(scenario, ns)
	end
end
Mock.reset()
