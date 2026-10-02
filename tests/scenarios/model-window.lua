-- What the options window reads from the model and nowhere else: the sidebar's
-- red dots (Page.Warn), the status strip's state (ns.LauncherState's `kind`),
-- the header's Snooze (its entries' own hidden rules), the footer's per-page
-- reset (Page.RESET, Page.ResetPage) and the old dialog's, Who to skip's PvP
-- lines read once a paint, and the ledger opening over the window rather than
-- shutting it.
--
-- Every scenario name starts with "model:" so the mutations in
-- tests/mutations/window-model.py can name the one that has to catch them.
--
-- Called by scenarios.lua with the addon directory and its helpers.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive
local findOption, optionText = H.findOption, H.optionText

local HAWK, MONKEY = 13165, 13163

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

local function shown(option)
	if not option then return false end
	local hidden = option.hidden
	if type(hidden) == "function" then hidden = hidden({}) end
	return not hidden
end

-- Globals a scenario may replace, put back after each: Mock.reset owns none.
local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "IsMounted", "UnitExists" }

-- One driven session as `class`, knowing only `known` (spell ids) when given,
-- with body(ns) run and everything put back whether it finished or threw.
local function with(scenario, class, known, body)
	Mock.reset()
	Mock.sv = {}
	if class then Mock.class = class end
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	if known then
		local set = {}
		for _, id in ipairs(known) do set[id] = true end
		IsSpellKnown = function(id) return set[id] == true end
		IsPlayerSpell = IsSpellKnown
	end
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		drive(scenario, ns)
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.Prompt:ExitTest()
		body(ns)
	end)
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function warn(ns, pageId)
	local fn = ns.OptionsPage.Warn and ns.OptionsPage.Warn[pageId]
	if type(fn) ~= "function" then return "missing" end
	return fn()
end

local function red(option)
	return optionText(option and option.name):find("|cffff8080", 1, true) ~= nil
end

-- A click as the client delivers it, to one of the window's buttons.
local function press(button)
	local onClick = button and button:GetScript("OnClick")
	if onClick then onClick(button, "LeftButton", false) end
end

-- ------------------------------------------------------------------ red dots
-- Start here: no key and no macro, the line under step 2 in red.
do
	local scenario = "model: Start here's red dot is the missing key"
	with(scenario, nil, nil, function(ns)
		local status = findOption(ns.optionsTable, "bindStatus")
		if warn(ns, "general") ~= true then
			fail(scenario, "no key and no macro, and Start here has no red dot")
		elseif not red(status) then
			fail(scenario, "SKIPPED -- the key line is not red with no key")
		end
		ns.Setup.SetKey("F7")
		if warn(ns, "general") ~= false then
			fail(scenario, "a key is bound and Start here still has its red dot")
		end
		ns.Setup.SetKey("")
		Mock.macros = { Manners = 1 }
		if warn(ns, "general") ~= false then
			fail(scenario, "the macro is made and Start here still has its red dot")
		end
		Mock.macros = nil
		noErrors(scenario, ns)
	end)
	with(scenario, "ROGUE", nil, function(ns)
		if warn(ns, "general") ~= false then
			fail(scenario, "a rogue, who has no prompt to put on a key, gets a red dot for the key")
		end
	end)
end

-- Who to buff: every source off, a pin not learned, nothing castable.
do
	local scenario = "model: Who to buff's red dot is nothing to offer"
	with(scenario, nil, nil, function(ns)
		local empty = findOption(ns.optionsTable, "emptyWarning")
		if warn(ns, "who") ~= false then
			fail(scenario, "a mage offering to everybody has a red dot on Who to buff")
		end
		local s = ns.db.profile.sources
		s.owed, s.group, s.strangers, s.asked, s.self = false, false, false, false, false
		if warn(ns, "who") ~= true then
			fail(scenario, "every source is off and Who to buff has no red dot")
		end
		if not shown(empty) then
			fail(scenario, "the red dot shows over no warning: emptyWarning is hidden")
		end
		s.self = true
		if warn(ns, "who") ~= false or shown(empty) then
			fail(scenario, "Myself alone still offers something, and Who to buff reads as empty")
		end
		s.owed, s.group, s.strangers = true, true, true
		-- Every spell switched off: Automatic has nothing to cast.
		for _, buff in ipairs(ns.GetClassBuffs("MAGE") or {}) do ns.db.profile.buff.skip[buff.key] = true end
		if warn(ns, "who") ~= true then
			fail(scenario, "nothing can be cast and Who to buff has no red dot")
		elseif not red(findOption(ns.optionsTable, "autoNote")) then
			fail(scenario, "the red dot shows over a note that is not red")
		end
		noErrors(scenario, ns)
	end)
	-- A priest with Fortitude, pinned to Shadow Protection he has not learned.
	Mock.reset()
	Mock.class = "PRIEST"
	local probe = load(scenario)
	local known = {}
	if probe then
		for _, id in ipairs(probe.FindBuff("PRIEST", "fortitude").ranks) do known[#known + 1] = id end
	end
	with(scenario, "PRIEST", known, function(ns)
		ns.db.profile.buff.choice = "shadow"
		if not ns.PinnedBuff() then
			fail(scenario, "SKIPPED -- the pin did not hold")
		elseif warn(ns, "who") ~= true then
			fail(scenario, "a pinned spell not learned offers nobody, and Who to buff has no red dot")
		elseif not red(findOption(ns.optionsTable, "pinNote")) then
			fail(scenario, "the red dot shows over a pin note that is not red")
		end
		ns.db.profile.buff.choice = "fortitude"
		if warn(ns, "who") ~= false then
			fail(scenario, "a learned pin still has a red dot on Who to buff")
		end
	end)
	with(scenario, "ROGUE", nil, function(ns)
		if warn(ns, "who") ~= false then
			fail(scenario, "a rogue, who has no Who to buff, has a red dot there")
		end
	end)
end

-- When to offer: Always offer.
do
	local scenario = "model: When to offer's red dot is Always offer"
	with(scenario, nil, nil, function(ns)
		local f = ns.db.profile.filters
		if warn(ns, "when") ~= false then
			fail(scenario, "Skip them has a red dot on When to offer")
		end
		f.whenBuffed = "always"
		if warn(ns, "when") ~= true then
			fail(scenario, "Always offer is chosen and When to offer has no red dot")
		elseif not shown(findOption(ns.optionsTable, "alwaysNote")) then
			fail(scenario, "the red dot shows over no warning: alwaysNote is hidden")
		end
		ns.caps.hasClassBuffs = false
		if warn(ns, "when") ~= false then
			fail(scenario, "a character with nothing for anybody gets the Always offer dot")
		end
		ns.caps.hasClassBuffs = true
		f.whenBuffed = "refresh"
		if warn(ns, "when") ~= false then
			fail(scenario, "Offer a top-up has a red dot on When to offer")
		end
		noErrors(scenario, ns)
	end)
end

-- Look: a silent sound, and a marker colour with nowhere to go.
do
	local scenario = "model: Look's red dot is a silent sound or a dead marker"
	with(scenario, nil, nil, function(ns)
		local p, snd = ns.db.profile.prompt, ns.db.profile.sound
		if warn(ns, "appearance") ~= false then
			fail(scenario, "a new profile has a red dot on Look")
		end
		snd.enabled, snd.file = true, "None"
		if warn(ns, "appearance") ~= true then
			fail(scenario, "Play a sound is on with None picked, and Look has no red dot")
		elseif not shown(findOption(ns.optionsTable, "noSound")) then
			fail(scenario, "the red dot shows over no warning: noSound is hidden")
		end
		snd.enabled = false
		if warn(ns, "appearance") ~= false then
			fail(scenario, "None picked with the sound off still has a red dot")
		end
		p.style, p.accentMode, p.showIcon = "glass", "icon", false
		if warn(ns, "appearance") ~= true then
			fail(scenario, "the marker has nothing left to colour, and Look has no red dot")
		elseif not shown(findOption(ns.optionsTable, "accentDead")) then
			fail(scenario, "the red dot shows over no warning: accentDead is hidden")
		end
		p.accentMode = "off"
		if warn(ns, "appearance") ~= false then
			fail(scenario, "no marker asked for, and Look still has a red dot")
		end
		noErrors(scenario, ns)
	end)
end

-- Diagnostics: something broke.
do
	local scenario = "model: Diagnostics' red dot is an error"
	with(scenario, nil, nil, function(ns)
		if #ns.errors > 0 then
			fail(scenario, "SKIPPED -- the session started with errors")
			return
		end
		if warn(ns, "diagnostics") ~= false then
			fail(scenario, "nothing has broken and Diagnostics has a red dot")
		end
		ns.Guard("model test", error, "on purpose")
		if warn(ns, "diagnostics") ~= true then
			fail(scenario, "an error was caught and Diagnostics has no red dot")
		end
		wipe(ns.errors)
	end)
end

-- The pages that hold no warning have no predicate to show one.
do
	local scenario = "model: only five pages can show a red dot"
	with(scenario, nil, nil, function(ns)
		for _, pageId in ipairs({ "skip", "click", "profiles" }) do
			if ns.OptionsPage.Warn[pageId] ~= nil then
				fail(scenario, pageId .. " has a red-dot predicate and no warning to stand for")
			end
		end
	end)
end

-- ------------------------------------------------------------------ the strip
-- Each branch of the launcher's state line names itself, so the window's
-- status strip can show the states that keep the prompt from working and leave
-- out the ones Start here and Who to buff already say.
local function kind(ns)
	-- In brackets: a state line with no eighth answer reads as nil.
	return (select(8, ns.LauncherState()))
end

do
	local scenario = "model: the strip names the launcher's state"
	with(scenario, nil, nil, function(ns)
		if kind(ns) ~= "watching" then
			fail(scenario, "a mage who can cast reads as " .. tostring(kind(ns)) .. ", not watching")
		end
		ns.db.profile.enabled = false
		if kind(ns) ~= "off" then fail(scenario, "switched off reads as " .. tostring(kind(ns))) end
		ns.db.profile.enabled = true
		ns.db.profile.prompt.locked = false
		if kind(ns) ~= "unlocked" then fail(scenario, "unlocked reads as " .. tostring(kind(ns))) end
		ns.db.profile.prompt.locked = true
		ns.StartSnooze(5)
		if kind(ns) ~= "snoozed" then fail(scenario, "snoozed reads as " .. tostring(kind(ns))) end
		ns.StopSnooze(true)
		ns.db.profile.filters.hideMounted = true
		IsMounted = function() return true end
		if kind(ns) ~= "mounted" then fail(scenario, "kept away on a mount reads as " .. tostring(kind(ns))) end
		ns.db.profile.filters.hideMounted = false
		for _, buff in ipairs(ns.GetClassBuffs("MAGE") or {}) do ns.db.profile.buff.skip[buff.key] = true end
		if kind(ns) ~= "blocked" then
			fail(scenario, "every spell switched off reads as " .. tostring(kind(ns)))
		end
		wipe(ns.db.profile.buff.skip)
		-- A class with buffs whose probe found nothing, and nothing of its own.
		ns.caps.hasClassBuffs, ns.caps.anyOwnKnown = false, false
		if kind(ns) ~= "nothing" then
			fail(scenario, "nothing to cast reads as " .. tostring(kind(ns)))
		end
		noErrors(scenario, ns)
	end)
	with(scenario, "MAGE", {}, function(ns)
		if kind(ns) ~= "unlearned" then
			fail(scenario, "nothing learned yet reads as " .. tostring(kind(ns)))
		end
	end)
	with(scenario, "ROGUE", nil, function(ns)
		if kind(ns) ~= "noclass" then fail(scenario, "a rogue reads as " .. tostring(kind(ns))) end
	end)
	with(scenario, "HUNTER", { HAWK, MONKEY }, function(ns)
		if not ns.OwnBuffsOnly() then
			fail(scenario, "SKIPPED -- the hunter has no prompt of his own")
			return
		end
		if kind(ns) ~= "ownwatch" then
			fail(scenario, "a hunter watching his own buffs reads as " .. tostring(kind(ns)))
		end
		ns.db.profile.filters.hideMounted = true
		IsMounted = function() return true end
		if kind(ns) ~= "mounted" then
			fail(scenario, "a hunter kept away on a mount reads as " .. tostring(kind(ns)))
		end
		ns.db.profile.filters.hideMounted = false
		ns.db.profile.sources.self = false
		if kind(ns) ~= "ownoff" then
			fail(scenario, "a hunter with Myself off reads as " .. tostring(kind(ns)))
		end
	end)
end

-- ------------------------------------------------------------------ the snooze
-- The header's Snooze button is there while any of its entries is, so each
-- entry carries the prompt rule. A rogue can still snooze from chat or the
-- minimap menu, and that gives him no button: IA 1.11, the master switch only.
do
	local scenario = "model: a snoozed rogue gets no Snooze"
	local ENTRIES = { "snoozeHeader", "snoozeNote", "snooze5", "snooze15", "snooze30", "snoozeStop" }
	with(scenario, "ROGUE", nil, function(ns)
		ns.addon:HandleSlash("snooze 15")
		if not ns.SnoozeLeft() then
			fail(scenario, "SKIPPED -- /manners snooze did not snooze the rogue")
			return
		end
		for _, key in ipairs(ENTRIES) do
			if shown(findOption(ns.optionsTable, key)) then
				fail(scenario, "a snoozed rogue, who has no prompt, is shown " .. key)
			end
		end
		ns.OpenOptions("general")
		local header = ns.WindowUI and ns.WindowUI.header
		if not (header and header.snooze) then
			fail(scenario, "SKIPPED -- the window built no Snooze button")
		elseif header.snooze:IsShown() then
			fail(scenario, "a snoozed rogue has a Snooze button reading " .. tostring(header.snoozeLabel))
		end
		ns.StopSnooze(true)
		noErrors(scenario, ns)
	end)
	-- The rule is the prompt's, not the snooze's: a mage keeps Stop snoozing.
	with(scenario, nil, nil, function(ns)
		ns.StartSnooze(5)
		if not shown(findOption(ns.optionsTable, "snoozeStop")) then
			fail(scenario, "a snoozed mage has no Stop snoozing")
		end
		ns.StopSnooze(true)
		noErrors(scenario, ns)
	end)
end

-- ------------------------------------------------------------------ the reset
-- A value that is not the default, whatever the field's type. A set is changed
-- in place, so the reset can be seen to wipe the very table.
local function unsettle(into, name, default)
	local value = into[name]
	if type(default) == "table" and default[1] == nil then
		if type(value) ~= "table" then
			value = {}
			into[name] = value
		end
		for k in pairs(value) do value[k] = "off" end
		value.changed = true
		value[3] = true
		return value
	elseif type(default) == "table" then
		into[name] = { 0.13, 0.27, 0.41, 0.5 }
	elseif type(default) == "boolean" then
		into[name] = not default
	elseif type(default) == "number" then
		into[name] = default + 7
	else
		into[name] = "changed " .. name
	end
end

local function same(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then return a == b end
	for k, v in pairs(a) do if not same(v, b[k]) then return false end end
	for k in pairs(b) do if a[k] == nil then return false end end
	return true
end

-- What each page's reset puts back (IA.md 1.6), written out here so a field
-- dropped from Page.RESET is noticed rather than simply no longer checked.
local EXPECTED = {
	who = {
		"buff.choice", "buff.skip", "filters.relevantOnly", "sources.owed", "sources.group",
		"sources.strangers", "sources.asked", "sources.self", "filters.proximity",
		"filters.restingOnly", "ownBuffs.pick", "ownBuffs.inCities", "groupBuffs.use",
		"groupBuffs.atLeast", "filters.skipRaidGroups", "priority.target", "priority.friends",
		"priority.readyCheck", "priority.revived",
	},
	skip = { "filters.skipPvP", "filters.skipSameClass", "filters.requireInRange", "filters.minLevel" },
	when = {
		"filters.whenBuffed", "filters.refreshUnder", "filters.hideMounted", "filters.manaFloor",
		"timing.reciprocateWindow", "sources.owedClassBuffsOnly", "filters.reachableOnly",
		"timing.graceSeconds", "timing.keepDebts", "timing.retryCooldown", "timing.scanInterval",
		"filters.restoreTarget",
	},
	click = { "prompt.thankEmote", "speech.enabled", "speech.channel", "speech.onlyWhenReturning" },
	appearance = {
		"prompt.scale", "prompt.alpha", "prompt.width", "prompt.height", "prompt.style",
		"prompt.bgColor", "prompt.accentByReason", "prompt.reasonPalette", "prompt.accentColor",
		"prompt.accentMode", "prompt.flashStyle", "prompt.effects", "prompt.hideInCombat",
		"prompt.font", "prompt.fontSize", "prompt.fontColor", "prompt.classColor", "prompt.showSub",
		"prompt.format", "prompt.reasonTarget", "prompt.reasonOwed", "prompt.reasonAsked",
		"prompt.reasonSelf", "prompt.reasonGroup", "prompt.reasonNearby", "prompt.reasonRefresh",
		"prompt.reasonUnknown", "prompt.showIcon", "prompt.iconSize", "prompt.roundIcon",
		"prompt.showCooldown", "prompt.showCount", "prompt.showQueue", "prompt.queueRows",
		"sound.enabled", "sound.file", "sound.owedOnly",
	},
	-- Not a page of the window: the old dialog's Advanced tab, which the
	-- window falls back to (Register.lua). Its reset is the old one's
	-- seventeen, When to offer's favours, timings and targeting and Look's
	-- wording, and never the exact position drawn on the same tab.
	advanced = {
		"sources.owedClassBuffsOnly", "timing.reciprocateWindow", "filters.reachableOnly",
		"timing.graceSeconds", "timing.keepDebts", "timing.retryCooldown", "timing.scanInterval",
		"filters.restoreTarget", "prompt.format", "prompt.reasonTarget", "prompt.reasonOwed",
		"prompt.reasonAsked", "prompt.reasonSelf", "prompt.reasonGroup", "prompt.reasonNearby",
		"prompt.reasonRefresh", "prompt.reasonUnknown",
	},
}

-- What each page's reset must leave alone, set to something of its own.
local KEPT = {
	who = { { "enabled", false } },
	skip = { { "never", { ["Petra Stonewell"] = true } } },
	when = { { "prompt.scale", 1.25 } },
	click = { { "speech.phrases", "my very own line" }, { "speech.presetChoice", "polite" } },
	appearance = { { "prompt.x", 41 }, { "prompt.y", 123 }, { "prompt.point", "TOP" },
		{ "prompt.relPoint", "TOP" }, { "prompt.locked", false } },
	advanced = { { "prompt.x", 41 }, { "prompt.y", 123 }, { "prompt.point", "TOP" },
		{ "prompt.relPoint", "TOP" }, { "prompt.scale", 1.25 }, { "filters.whenBuffed", "always" } },
}
-- The hooks each page's fields' own setters run, which its reset must run too.
local HOOKS = {
	who = { "style", "macro", "refresh", "broker" },
	skip = {},
	when = { "save", "scan", "style", "macro" },
	click = { "macro" },
	appearance = { "clamp", "style", "macro" },
	advanced = { "save", "scan", "style", "macro" },
}

local function field(profile, path)
	local section, name = path:match("^(%w+)%.(%w+)$")
	if section then return profile[section], name end
	return profile, path
end

for _, pageId in ipairs({ "who", "skip", "when", "click", "appearance", "advanced" }) do
	local scenario = "model: the reset puts " .. pageId .. " back"
	with(scenario, nil, nil, function(ns)
		local Page = ns.OptionsPage
		local list = Page.RESET and Page.RESET[pageId]
		if type(list) ~= "table" or #list == 0 then
			fail(scenario, pageId .. " has nothing on its reset list")
			return
		end
		local listed = {}
		for _, path in ipairs(list) do listed[path] = true end
		for _, path in ipairs(EXPECTED[pageId]) do
			if not listed[path] then fail(scenario, pageId .. " reset: the list leaves out " .. path) end
			listed[path] = nil
		end
		for path in pairs(listed) do
			fail(scenario, pageId .. " reset: the list reaches " .. path .. ", which is not on this page")
		end
		local profile, defaults = ns.db.profile, ns.defaults.profile
		local sets = {}
		for _, path in ipairs(list) do
			local into, name = field(profile, path)
			local from = field(defaults, path)
			sets[path] = unsettle(into, name, from[name])
		end
		for _, keep in ipairs(KEPT[pageId]) do
			local into, name = field(profile, keep[1])
			into[name] = keep[2]
		end

		local calls = { style = 0, macro = 0, refresh = 0, broker = 0, save = 0, scan = 0, clamp = 0, redraw = 0 }
		local real = {
			style = ns.Prompt.ApplyStyle, macro = ns.Prompt.InvalidateMacro, refresh = ns.Prompt.Refresh,
			broker = ns.RefreshBrokerText, save = ns.addon.SaveDebts, scan = ns.addon.StartScanner,
			clamp = ns.ClampSettings, redraw = ns.RefreshOptionsDisplay,
		}
		local function count(name)
			return function(...) calls[name] = calls[name] + 1; return real[name](...) end
		end
		ns.Prompt.ApplyStyle, ns.Prompt.InvalidateMacro = count("style"), count("macro")
		ns.Prompt.Refresh, ns.RefreshBrokerText = count("refresh"), count("broker")
		ns.addon.SaveDebts, ns.addon.StartScanner = count("save"), count("scan")
		ns.ClampSettings, ns.RefreshOptionsDisplay = count("clamp"), count("redraw")
		-- Who to buff's in a fight: ApplyStyle holds off there, so only the
		-- reset's own Refresh puts an own buff's pick on the prompt at once,
		-- as the pick's control does.
		Mock.inCombat = pageId == "who"
		local ok, answer = pcall(Page.ResetPage, pageId)
		Mock.inCombat = false
		ns.Prompt.ApplyStyle, ns.Prompt.InvalidateMacro = real.style, real.macro
		ns.Prompt.Refresh, ns.RefreshBrokerText = real.refresh, real.broker
		ns.addon.SaveDebts, ns.addon.StartScanner = real.save, real.scan
		ns.ClampSettings, ns.RefreshOptionsDisplay = real.clamp, real.redraw
		if not ok or answer ~= true then
			fail(scenario, "the reset did not run: " .. tostring(answer))
			return
		end

		for _, path in ipairs(list) do
			local into, name = field(profile, path)
			local from = field(defaults, path)
			if not same(into[name], from[name]) then
				fail(scenario, pageId .. " reset: " .. path .. " was not put back")
			elseif sets[path] and into[name] ~= sets[path] then
				fail(scenario, pageId .. " reset: " .. path .. " is a new table, not the one wiped")
			end
		end
		for _, keep in ipairs(KEPT[pageId]) do
			local into, name = field(profile, keep[1])
			if not same(into[name], keep[2]) then
				fail(scenario, pageId .. " reset: put back " .. keep[1] .. ", which it keeps")
			end
		end
		for _, hook in ipairs(HOOKS[pageId]) do
			if calls[hook] == 0 then
				fail(scenario, pageId .. " reset: the " .. hook .. " hook did not run")
			end
		end
		if calls.redraw == 0 then
			fail(scenario, pageId .. " reset: the page still shows the old values")
		end
		noErrors(scenario, ns)
	end)
end

do
	local scenario = "model: the reset leaves a page with no list alone"
	with(scenario, nil, nil, function(ns)
		local Page = ns.OptionsPage
		ns.db.profile.verbose = false
		ns.db.profile.minimap.hide = true
		for _, pageId in ipairs({ "general", "profiles", "diagnostics" }) do
			if Page.RESET[pageId] ~= nil then
				fail(scenario, pageId .. " has a reset list")
			elseif Page.ResetPage(pageId) ~= false then
				fail(scenario, "a reset of " .. pageId .. ", which has no list, said it ran")
			end
		end
		if ns.db.profile.verbose ~= false or ns.db.profile.minimap.hide ~= true then
			fail(scenario, "a reset of a page with no list put a setting back")
		end
	end)
end

-- YES puts back the page the question was asked on. The box stays up while
-- the page under it changes: the minimap button or a slash command opening
-- Look, /manners export opening Profiles.
do
	local scenario = "model: the reset puts back the page it asked about"
	with(scenario, nil, nil, function(ns)
		local UI, W = ns.WindowUI, ns.WindowWidgets
		if not (UI and W and W.Asking) then
			fail(scenario, "SKIPPED -- no options window")
			return
		end
		local timing, prompt = ns.db.profile.timing, ns.db.profile.prompt
		local defaults = ns.defaults.profile
		local function ask()
			ns.OpenOptions("when")
			ns.Prompt:ExitTest()
			timing.scanInterval, prompt.scale = 1.5, 2
			press(UI.footer.reset)
			return W.Asking()
		end

		local box = ask()
		if not (box and box.yes) then
			fail(scenario, "Put these back to default did not ask first")
			return
		end
		ns.OpenOptions("appearance")
		press(box.yes)
		if timing.scanInterval ~= defaults.timing.scanInterval then
			fail(scenario, "asked on When to offer, YES with Look opened under the box left Check for people every at "
				.. tostring(timing.scanInterval))
		end
		if prompt.scale ~= 2 then
			fail(scenario, "asked on When to offer, YES put back Look's scale, the page opened under the box")
		end

		box = ask()
		ns.ShowShareBox("export")
		if box then press(box.yes) end
		if timing.scanInterval ~= defaults.timing.scanInterval then
			fail(scenario, "asked on When to offer, YES with Profiles opened under the box put nothing back")
		end
		if W.Asking() then fail(scenario, "the box is still asking after YES") end
		noErrors(scenario, ns)
	end)
end

-- The window that will not show falls back to the old dialog, whose Advanced
-- tab is the one place it draws the reset: shown there, and putting back that
-- tab's settings -- even when another tab is clicked while the dialog asks.
do
	local scenario = "model: the old dialog's Advanced tab keeps its reset"
	with(scenario, nil, nil, function(ns)
		local UI = ns.WindowUI
		local dialog = LibStub("AceConfigDialog-3.0")
		local reset = findOption(ns.optionsTable, "resetAdvanced")
		if not (UI and reset and reset.func) then
			fail(scenario, "SKIPPED -- no window or no reset to fall back from")
			return
		end
		local status = { groups = { selected = "advanced" } }
		local realStatus, realOpen = dialog.GetStatusTable, UI.Open
		dialog.GetStatusTable = function(_, app)
			if app == "Manners" then return status end
			return {}
		end
		UI.Open = function() error("no window today", 0) end
		local ok, err = pcall(function()
			ns.OpenOptions("when")
			if ns.OptionsTab() ~= "advanced" then
				fail(scenario, "SKIPPED -- the fallback reads its tab as " .. tostring(ns.OptionsTab()))
				return
			end
			local info = { "advanced", "resetAdvanced" }
			local hidden = reset.hidden
			if type(hidden) == "function" then hidden = hidden(info) end
			if hidden then fail(scenario, "the old dialog's Advanced tab hides Put these back to default") end

			local profile, defaults = ns.db.profile, ns.defaults.profile
			for _, path in ipairs(EXPECTED.advanced) do
				local into, name = field(profile, path)
				local from = field(defaults, path)
				unsettle(into, name, from[name])
			end
			profile.prompt.x, profile.sources.strangers = 41, not defaults.sources.strangers
			-- Pressed as the dialog presses it: its question asked, then
			-- Who to buff's tab clicked while the question is up, then YES.
			if type(reset.confirm) == "function" then reset.confirm(info) end
			status.groups.selected = "who"
			reset.func(info)
			for _, path in ipairs(EXPECTED.advanced) do
				local into, name = field(profile, path)
				local from = field(defaults, path)
				if not same(into[name], from[name]) then
					fail(scenario, "the old dialog's reset left " .. path .. " as it was")
				end
			end
			if profile.prompt.x ~= 41 then fail(scenario, "the old dialog's reset moved the prompt") end
			if profile.sources.strangers == defaults.sources.strangers then
				fail(scenario, "the old dialog's reset put back Who to buff, the tab clicked while it asked")
			end
		end)
		dialog.GetStatusTable, UI.Open = realStatus, realOpen
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
		for _, e in ipairs(ns.errors or {}) do
			if e.where ~= "options window" then
				fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
			end
		end
	end)
end

-- ------------------------------------------------------------------ the PvP note
-- Who to skip's PvP lines rebuild the queue to be read, so a paint reads them
-- once (IA.md, Who to skip): their hidden and their text share one scan, with
-- somebody flagged and the note up as much as with nobody.
do
	local scenario = "model: a paint of Who to skip builds the queue once"
	with(scenario, nil, nil, function(ns)
		local UI = ns.WindowUI
		if not UI then
			fail(scenario, "SKIPPED -- no options window")
			return
		end
		H.strangers({ nameplate1 = { "Flagga", "Bearer" } })
		H.clearClicks(ns)
		Mock.pvp = { nameplate1 = true }
		ns.OpenOptions("skip")
		ns.Prompt:ExitTest()
		local real, built = ns.BuildQueue, 0
		ns.BuildQueue = function(...) built = built + 1 return real(...) end
		ns.RefreshOptionsDisplay()
		local paint = built
		-- A slider tick on the same page is a paint too.
		local minLevel = ns.WindowBind.Item("who.minLevel", nil, UI.ctx)
		built = 0
		if minLevel then ns.WindowBind.Commit(minLevel, 5) end
		local tick = built
		ns.BuildQueue = real
		local row = UI.RowFor("diagnostics.pvpDiag")
		local text = row and row.text and row.text:GetText() or ""
		if not (UI.RowShown("diagnostics.pvpDiag") and text:find("Flagga", 1, true)) then
			fail(scenario, "SKIPPED -- the PvP lines are not up for Flagga: " .. text)
		end
		if paint ~= 1 then fail(scenario, ("one paint of Who to skip built the queue %d times"):format(paint)) end
		if not minLevel then
			fail(scenario, "SKIPPED -- no Skip players below level")
		elseif ns.db.profile.filters.minLevel ~= 5 then
			fail(scenario, "SKIPPED -- Skip players below level did not move")
		elseif tick ~= 1 then
			fail(scenario, ("one tick of Skip players below level built the queue %d times"):format(tick))
		end
		noErrors(scenario, ns)
	end)
end

-- ------------------------------------------------------------------ the ledger
-- Both windows are HIGH and toplevel, so whichever was opened last is on top:
-- Show raises the ledger, and Open the ledger no longer shuts the options.
do
	local scenario = "model: the ledger raises its window"
	with(scenario, nil, nil, function(ns)
		if not ns.Ledger then
			fail(scenario, "SKIPPED -- no ledger")
			return
		end
		ns.Ledger.Show()
		local window = ns.Ledger.Window()
		if not window then
			fail(scenario, "SKIPPED -- the ledger built no window")
			return
		end
		local raised = 0
		window.Raise = function(self) raised = raised + 1 return self end
		window:Hide()
		ns.Ledger.Show()
		if not window:IsShown() then
			fail(scenario, "SKIPPED -- the ledger did not show")
		elseif raised == 0 then
			fail(scenario, "the ledger opened without raising its window, under one opened before it")
		end
		noErrors(scenario, ns)
	end)
end

do
	local scenario = "model: Open the ledger leaves the options open"
	with(scenario, nil, nil, function(ns)
		local open = findOption(ns.optionsTable, "ledgerOpen")
		if not (open and open.func and ns.Ledger) then
			fail(scenario, "SKIPPED -- no Open the ledger button")
			return
		end
		local realClose, closed = ns.CloseOptions, 0
		ns.CloseOptions = function(...) closed = closed + 1 return realClose(...) end
		local wasOpen = ns.OptionsOpen()
		open.func({ "ledgerOpen" })
		ns.CloseOptions = realClose
		local window = ns.Ledger.Window()
		if not (window and window:IsShown()) then
			fail(scenario, "Open the ledger did not open it")
		end
		if closed > 0 or ns.OptionsOpen() ~= wasOpen then
			fail(scenario, "Open the ledger shut the options window it was pressed on")
		end
		noErrors(scenario, ns)
	end)
end
