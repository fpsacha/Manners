-- The Advanced group (Options/Advanced.lua, BuildAdvancedTab): the tuning
-- knobs -- favours, timing, targeting, the exact position and the prompt's
-- wording -- that the options window draws on When to offer and Look, with its
-- intro (the window's fold caption), its combat notice (the status strip) and
-- "Put these back to default", which is now the window's per-page reset
-- (Page.RESET, Page.ResetPage).
--
-- Every control kept its option key and its get/set, so the profile field it
-- writes is where it always was: a player upgrading keeps every value.
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

local function group(ns)
	return ns.optionsTable and ns.optionsTable.args and ns.optionsTable.args.advanced
end

-- The model, top to bottom: key, order, and the English label.
local MODEL = {
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

-- Where the window draws them, top to bottom (the layout spec, IA.md section
-- 2): When to offer's Favours, then its Timing and Targeting folds; Look's
-- Exact position and Prompt wording folds. Folded or not, by section.
local PLACED = {
	when = {
		{ "advanced.reciprocateWindow" }, { "advanced.owedClassBuffsOnly" },
		{ "advanced.reachableOnly" }, { "advanced.graceSeconds" }, { "advanced.keepDebts" },
		{ "advanced.retryCooldown", folded = true }, { "advanced.scanInterval", folded = true },
		{ "advanced.restoreTarget", folded = true }, { "advanced.noTargetNote", folded = true },
	},
	appearance = {
		{ "advanced.x", folded = true }, { "advanced.y", folded = true },
		{ "advanced.formatHelp", folded = true }, { "advanced.format", folded = true },
		{ "advanced.reasonTarget", folded = true }, { "advanced.reasonOwed", folded = true },
		{ "advanced.reasonAsked", folded = true }, { "advanced.reasonSelf", folded = true },
		{ "advanced.reasonGroup", folded = true }, { "advanced.reasonNearby", folded = true },
		{ "advanced.reasonRefresh", folded = true }, { "advanced.reasonUnknown", folded = true },
	},
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

-- When to offer's reset: its own four, the old Advanced reset's eight favour,
-- timing and targeting fields, which now sit on this page.
local WHEN_RESET = {
	{ "filters", "whenBuffed" }, { "filters", "refreshUnder" }, { "filters", "hideMounted" },
	{ "filters", "manaFloor" },
	{ "timing", "reciprocateWindow" }, { "sources", "owedClassBuffsOnly" },
	{ "filters", "reachableOnly" }, { "timing", "graceSeconds" }, { "timing", "keepDebts" },
	{ "timing", "retryCooldown" }, { "timing", "scanInterval" }, { "filters", "restoreTarget" },
}

-- Look's reset: everything about the prompt itself, the old Advanced reset's
-- nine wording fields included -- but not where it sits, nor its lock.
local LOOK_RESET = {
	{ "prompt", "scale" }, { "prompt", "alpha" }, { "prompt", "width" }, { "prompt", "height" },
	{ "prompt", "style" }, { "prompt", "bgColor" }, { "prompt", "accentByReason" },
	{ "prompt", "reasonPalette" }, { "prompt", "accentColor" }, { "prompt", "accentMode" },
	{ "prompt", "flashStyle" }, { "prompt", "effects" }, { "prompt", "hideInCombat" },
	{ "prompt", "font" }, { "prompt", "fontSize" }, { "prompt", "fontColor" },
	{ "prompt", "classColor" }, { "prompt", "showSub" },
	{ "prompt", "format" }, { "prompt", "reasonTarget" }, { "prompt", "reasonOwed" },
	{ "prompt", "reasonAsked" }, { "prompt", "reasonSelf" }, { "prompt", "reasonGroup" },
	{ "prompt", "reasonNearby" }, { "prompt", "reasonRefresh" }, { "prompt", "reasonUnknown" },
	{ "prompt", "showIcon" }, { "prompt", "iconSize" }, { "prompt", "roundIcon" },
	{ "prompt", "showCooldown" }, { "prompt", "showCount" }, { "prompt", "showQueue" },
	{ "prompt", "queueRows" },
	{ "sound", "enabled" }, { "sound", "file" }, { "sound", "owedOnly" },
}
local LOOK_KEPT = {
	{ "prompt", "x" }, { "prompt", "y" }, { "prompt", "point" }, { "prompt", "relPoint" },
	{ "prompt", "locked" },
}

-- A value that is not the default, whatever the field's type.
local function other(value, name)
	if type(value) == "boolean" then return not value end
	if type(value) == "number" then return value + 7 end
	if type(value) == "table" then return { 0.13, 0.27, 0.41, 0.5 } end
	if name == "point" or name == "relPoint" then
		return value == "TOP" and "LEFT" or "TOP"
	end
	return "changed " .. name .. " {name}"
end

local function same(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then return a == b end
	for k, v in pairs(a) do if not same(v, b[k]) then return false end end
	for k in pairs(b) do if a[k] == nil then return false end end
	return true
end

local function show(value)
	if type(value) ~= "table" then return tostring(value) end
	local parts = {}
	for i = 1, #value do parts[i] = tostring(value[i]) end
	return "{" .. table.concat(parts, ", ") .. "}"
end

-- The hooks a reset runs, counted, with the page the window has open as
-- `pageId`; `run()` presses the reset button. Everything is put back after.
local function pressReset(ns, pageId, calls)
	local realTab = ns.OptionsTab
	local realScan, realSave = ns.addon.StartScanner, ns.addon.SaveDebts
	local realStyle, realMacro = ns.Prompt.ApplyStyle, ns.Prompt.InvalidateMacro
	local realRedraw, realClamp = ns.RefreshOptionsDisplay, ns.ClampSettings
	ns.OptionsTab = function() return pageId end
	ns.addon.StartScanner = function(...) calls.scan = calls.scan + 1; return realScan(...) end
	ns.addon.SaveDebts = function(...) calls.save = calls.save + 1; return realSave(...) end
	ns.Prompt.ApplyStyle = function(...) calls.style = calls.style + 1; return realStyle(...) end
	ns.Prompt.InvalidateMacro = function(...) calls.macro = calls.macro + 1; return realMacro(...) end
	ns.RefreshOptionsDisplay = function(...) calls.redraw = calls.redraw + 1; return realRedraw(...) end
	ns.ClampSettings = function(...) calls.clamp = calls.clamp + 1; return realClamp(...) end
	local reset = findOption(ns.optionsTable, "resetAdvanced")
	local ok, err = pcall(reset.func, { "resetAdvanced" })
	ns.OptionsTab = realTab
	ns.addon.StartScanner, ns.addon.SaveDebts = realScan, realSave
	ns.Prompt.ApplyStyle, ns.Prompt.InvalidateMacro = realStyle, realMacro
	ns.RefreshOptionsDisplay, ns.ClampSettings = realRedraw, realClamp
	return ok, err
end

-- ------------------------------------------------------------------ 1
do
	local scenario = "advanced: the knobs keep their keys, orders and labels"
	local ns = session(scenario)
	local adv = ns and group(ns)
	if ns and not adv then
		fail(scenario, "the Advanced group is gone from the model, and every knob in it")
	elseif ns then
		if adv.order ~= 6 then
			fail(scenario, "the group is at order " .. tostring(adv.order) .. ", not 6")
		end
		for _, want in ipairs(MODEL) do
			local key, order, label = want[1], want[2], want[3]
			local option = adv.args[key]
			if not option then
				fail(scenario, "advanced: " .. key .. " is not in the group")
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
		-- The reset asks first, about this page, and says what it keeps.
		local reset = adv.args.resetAdvanced
		-- A function asks too: it notes the page the question is about.
		if reset and not (reset.type == "execute" and (reset.confirm == true or type(reset.confirm) == "function")
			and optionText(reset.confirmText):find("Put every setting on this page back to its default?", 1, true)) then
			fail(scenario, "Put these back to default does not ask before it resets")
		end
		if reset and not optionText(reset.confirmText):find(
			"Where the prompt sits, the lines you wrote and the never-offer list are kept.", 1, true) then
			fail(scenario, "the reset does not say what it keeps: " .. optionText(reset.confirmText))
		end
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------------ 1b
-- Drawn where the layout spec puts them: no Advanced page, the favours open on
-- When to offer, the rest in folds; the intro, the combat notice and the reset
-- in the window's own frame.
do
	local scenario = "advanced: drawn on When to offer and Look as laid out"
	local ns = session(scenario)
	if ns and H.layoutInToc() and not ns.WindowLayout then
		fail(scenario, "the toc loads the window's layout and ns.WindowLayout is not there")
	elseif ns and ns.WindowLayout then
		local layout = ns.WindowLayout
		if layout.pages.advanced then
			fail(scenario, "Advanced is still a page of its own")
		end
		for pageId, want in pairs(PLACED) do
			local list, sections = H.pagePaths(ns, pageId)
			local got = {}
			for _, path in ipairs(list or {}) do
				if path:find("^advanced%.") then got[#got + 1] = path end
			end
			for i, entry in ipairs(want) do
				if got[i] ~= entry[1] then
					fail(scenario, ("%s: the knob in place %d is %s, not %s")
						:format(pageId, i, tostring(got[i]), entry[1]))
				elseif (sections[entry[1]].fold == true) ~= (entry.folded == true) then
					fail(scenario, entry[1] .. (entry.folded and " is not in a fold" or " is folded away"))
				end
			end
			if #got ~= #want then
				fail(scenario, ("%s draws %d Advanced knobs, not %d"):format(pageId, #got, #want))
			end
		end
		if not (layout.footer and layout.footer.reset == "advanced.resetAdvanced") then
			fail(scenario, "the reset is not the footer's")
		end
		if layout.foldCaption ~= "advanced.advIntro" then
			fail(scenario, "the intro does not caption the folds")
		end
		if not (layout.strip and layout.strip.combat and layout.strip.combat.when == "advanced.advCombatNotice") then
			fail(scenario, "the targeting combat notice is not When to offer's strip line")
		end
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------------ 2
-- A class with nothing to give has nothing to tune.
do
	local scenario = "advanced: shown only to a class with buffs"
	local ns = session(scenario)
	local adv = ns and group(ns)
	if ns and not adv then
		fail(scenario, "SKIPPED -- there is no Advanced group")
	elseif ns then
		if adv.hidden and adv.hidden() then
			fail(scenario, "the Advanced group is hidden from a mage")
		end
		local rogue = session(scenario, "ROGUE")
		local radv = rogue and group(rogue)
		if rogue and not (radv and radv.hidden and radv.hidden()) then
			fail(scenario, "the Advanced group is shown to a rogue, who has no buff to tune")
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
	local adv = ns and group(ns)
	if ns and not adv then
		fail(scenario, "SKIPPED -- there is no Advanced group")
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
-- Put these back to default, on When to offer: its twelve fields, the old
-- Advanced reset's eight favour, timing and targeting fields among them, and
-- nothing from another page -- not Look's wording, which the old reset took
-- with it. Kept favours written the way the switch writes them, and the page
-- redrawn.
do
	local scenario = "advanced: put these back to default on When to offer"
	local ns = session(scenario)
	local reset = ns and findOption(ns.optionsTable, "resetAdvanced")
	if ns and not (reset and reset.func) then
		fail(scenario, "there is no Put these back to default button")
	elseif ns then
		local profile, defaults = ns.db.profile, ns.defaults.profile
		for _, f in ipairs(WHEN_RESET) do
			profile[f[1]][f[2]] = other(defaults[f[1]][f[2]], f[2])
		end
		-- Settings from other pages, which must be left as they are.
		profile.prompt.scale = 1.25
		profile.sources.owed = false
		profile.prompt.format = "changed {name}"

		-- A favour kept with the switch off is on nobody's disk.
		wipe(ns.owed)
		ns.owed["Yorick Vane"] = { expires = GetTime() + 120, at = GetTime() }
		ns.addon:SaveDebts()
		local wasWritten = Mock.sv.char and Mock.sv.char.debts

		local calls = { scan = 0, save = 0, style = 0, macro = 0, redraw = 0, clamp = 0 }
		local ok, err = pressReset(ns, "when", calls)
		if not ok then fail(scenario, "the reset threw -> " .. tostring(err)) end

		for _, f in ipairs(WHEN_RESET) do
			if not same(profile[f[1]][f[2]], defaults[f[1]][f[2]]) then
				fail(scenario, ("when reset: %s.%s was not put back (%s, default %s)")
					:format(f[1], f[2], show(profile[f[1]][f[2]]), show(defaults[f[1]][f[2]])))
			end
		end
		if profile.prompt.scale ~= 1.25 or profile.sources.owed ~= false
			or profile.prompt.format ~= "changed {name}" then
			fail(scenario, "when reset: put back a setting from another page")
		end
		if wasWritten then
			fail(scenario, "SKIPPED -- a favour was written with the switch off")
		elseif not (Mock.sv.char and Mock.sv.char.debts and Mock.sv.char.debts["Yorick Vane"]) then
			fail(scenario, "when reset: switched keeping favours back on without saving them,"
				.. " the way the switch itself does")
		end
		if calls.scan == 0 then
			fail(scenario, "when reset: the new timings were not handed to the scanner")
		end
		if calls.style == 0 or calls.macro == 0 then
			fail(scenario, "when reset: the prompt was not restyled and its macro rebuilt")
		end
		if calls.redraw == 0 then
			fail(scenario, "when reset: the page still shows the old values")
		end
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------------ 6b
-- On Look: everything about the prompt itself, the nine wording fields the old
-- Advanced reset put back included, and never where it sits or its lock.
do
	local scenario = "advanced: put these back to default on Look"
	local ns = session(scenario)
	local reset = ns and findOption(ns.optionsTable, "resetAdvanced")
	if ns and not (reset and reset.func) then
		fail(scenario, "there is no Put these back to default button")
	elseif ns then
		local profile, defaults = ns.db.profile, ns.defaults.profile
		for _, f in ipairs(LOOK_RESET) do
			profile[f[1]][f[2]] = other(defaults[f[1]][f[2]], f[2])
		end
		local kept = {}
		for i, f in ipairs(LOOK_KEPT) do
			kept[i] = other(defaults[f[1]][f[2]], f[2])
			profile[f[1]][f[2]] = kept[i]
		end
		profile.filters.restoreTarget = not defaults.filters.restoreTarget

		local calls = { scan = 0, save = 0, style = 0, macro = 0, redraw = 0, clamp = 0 }
		local ok, err = pressReset(ns, "appearance", calls)
		if not ok then fail(scenario, "the reset threw -> " .. tostring(err)) end

		for _, f in ipairs(LOOK_RESET) do
			if not same(profile[f[1]][f[2]], defaults[f[1]][f[2]]) then
				fail(scenario, ("look reset: %s.%s was not put back (%s, default %s)")
					:format(f[1], f[2], show(profile[f[1]][f[2]]), show(defaults[f[1]][f[2]])))
			end
		end
		-- A fresh copy: a colour picker writing into the profile's table must
		-- never be writing into the defaults.
		for _, name in ipairs({ "bgColor", "fontColor", "accentColor" }) do
			if profile.prompt[name] == defaults.prompt[name] then
				fail(scenario, "look reset: prompt." .. name .. " is the defaults' own table")
			end
		end
		for i, f in ipairs(LOOK_KEPT) do
			if profile[f[1]][f[2]] ~= kept[i] then
				fail(scenario, ("look reset: moved the prompt (%s.%s is %s)")
					:format(f[1], f[2], tostring(profile[f[1]][f[2]])))
			end
		end
		if profile.filters.restoreTarget == defaults.filters.restoreTarget then
			fail(scenario, "look reset: put back a setting from another page")
		end
		if calls.clamp == 0 then
			fail(scenario, "look reset: the icon was not held inside the prompt's size again")
		end
		if calls.style == 0 or calls.macro == 0 then
			fail(scenario, "look reset: the prompt was not restyled")
		end
		if calls.redraw == 0 then
			fail(scenario, "look reset: the page still shows the old values")
		end
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------------ 6c
-- The one button serves whichever page is open: shown where the page has a
-- list, hidden where it has none, and it puts back that page and no other.
do
	local scenario = "advanced: the reset button follows the page in view"
	local ns = session(scenario)
	local reset = ns and findOption(ns.optionsTable, "resetAdvanced")
	if ns and not (reset and reset.func) then
		fail(scenario, "there is no Put these back to default button")
	elseif ns then
		local realTab = ns.OptionsTab
		local function hiddenOn(pageId)
			ns.OptionsTab = function() return pageId end
			local hidden = reset.hidden
			if type(hidden) == "function" then hidden = hidden({ "resetAdvanced" }) end
			ns.OptionsTab = realTab
			return hidden and true or false
		end
		for _, pageId in ipairs({ "who", "skip", "when", "click", "appearance" }) do
			if hiddenOn(pageId) then fail(scenario, "the reset is hidden on " .. pageId) end
		end
		for _, pageId in ipairs({ "general", "profiles", "diagnostics" }) do
			if not hiddenOn(pageId) then
				fail(scenario, "the reset is offered on " .. pageId .. ", which has nothing to put back")
			end
		end
		-- Who to skip open: its four go back, When to offer's stay.
		local f = ns.db.profile.filters
		f.minLevel, f.whenBuffed = 40, "always"
		pressReset(ns, "skip", { scan = 0, save = 0, style = 0, macro = 0, redraw = 0, clamp = 0 })
		if f.minLevel ~= ns.defaults.profile.filters.minLevel then
			fail(scenario, "with Who to skip open, the reset did not put Skip players below level back")
		end
		if f.whenBuffed ~= "always" then
			fail(scenario, "with Who to skip open, the reset put back When to offer's setting")
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
		profile.prompt.format = "changed {name}"
		profile.filters.restoreTarget = not defaults.filters.restoreTarget
		ns.Prompt:ApplyStyle()
		Mock.protect(button)
		Mock.inCombat = true
		Mock.protectedCalls = {}
		local calls = { scan = 0, save = 0, style = 0, macro = 0, redraw = 0, clamp = 0 }
		pressReset(ns, "when", calls)
		pressReset(ns, "appearance", calls)
		if #Mock.protectedCalls > 0 then
			fail(scenario, "reset in a fight called " .. table.concat(Mock.protectedCalls, ", ")
				.. " on the secure button")
		end
		if profile.prompt.format ~= defaults.prompt.format
			or profile.filters.restoreTarget ~= defaults.filters.restoreTarget then
			fail(scenario, "reset in a fight was not saved")
		end
		Mock.inCombat = false
		Mock.protectedCalls = {}
		noErrors(scenario, ns)
	end
end
Mock.reset()
