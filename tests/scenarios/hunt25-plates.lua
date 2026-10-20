-- Passers-by are seen mostly through nameplate tokens, so with the game's
-- friendly nameplates off Manners sees almost nobody outside your group.
-- Who to buff says so beside the passers-by switch -- a grey note and a
-- "Show friendly nameplates" button, only while that source is on and the
-- client plainly says the nameplates are off, the button greyed in a fight --
-- and so does a keypress on an empty prompt, when nobody found is the reason it
-- is empty (Prompt/Press.lua), never in place of a more specific one.
--
-- The setting is nameplateShowFriendlyPlayers on WoW Forever and
-- nameplateShowFriends on the Classic clients (ns.FRIENDLY_PLATES_CVARS), so
-- every scenario that touches it runs as both.
--
-- Called by scenarios.lua with the addon directory and its helpers. Every
-- scenario name starts with "hunt25-plates:" so the mutations in
-- tests/mutations/hunt25-plates.py can name the one that has to catch them.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

local NOTE = "who.strangersPlatesNote"
local BUTTON = "who.strangersShowPlates"

local CASES = {
	{ label = "Forever", flavour = nil, cvar = "nameplateShowFriendlyPlayers" },
	{ label = "vanilla", flavour = "vanilla", cvar = "nameplateShowFriends" },
}

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

local function said()
	return table.concat(Mock.printed or {}, "\n")
end

local function press(button)
	local onClick = button and button:GetScript("OnClick")
	if onClick then onClick(button, "LeftButton", false) end
end

-- The client's settings, as GetCVar and SetCVar see them (the mock has none),
-- with every SetCVar written down. The client answers only the names in
-- `values`, as each client answers only its own. Hands back the table and a
-- function that puts the real ones back.
local function cvars(values)
	local realGet, realSet = rawget(_G, "GetCVar"), rawget(_G, "SetCVar")
	local box = { values = values or {}, sets = {} }
	rawset(_G, "GetCVar", function(name) return box.values[name] end)
	rawset(_G, "SetCVar", function(name, value)
		box.sets[#box.sets + 1] = { name, value }
		box.values[name] = tostring(value)
	end)
	return box, function()
		rawset(_G, "GetCVar", realGet)
		rawset(_G, "SetCVar", realSet)
	end
end

-- One driven session as `case` says (the client), with the settings the
-- client answers `values`, and nobody in sight unless `opts.crowd` is set.
-- body(ns, box) runs with everything restored after it, however it ends.
local function session(scenario, case, values, opts, body)
	opts = opts or {}
	local box, restoreCVars = cvars(values)
	Mock.reset()
	if case.flavour then Mock.setFlavour(case.flavour) end
	local restoreUnits = (not opts.crowd) and H.strangers({}) or nil
	local realMounted, realResting = rawget(_G, "IsMounted"), rawget(_G, "IsResting")
	local ns
	local ok, err = pcall(function()
		ns = load(scenario)
		if not ns then return end
		drive(scenario, ns)
		ns.Prompt:ExitTest()
		H.clearClicks(ns)
		Mock.printed = {}
		body(ns, box)
	end)
	if ns then
		pcall(ns.CloseOptions)
		pcall(function() ns.Prompt:ExitTest() end)
	end
	if restoreUnits then restoreUnits() end
	rawset(_G, "IsMounted", realMounted)
	rawset(_G, "IsResting", realResting)
	restoreCVars()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
	if ns then noErrors(scenario, ns) end
end

local function plates(case, state)
	if state == "off" then return { [case.cvar] = "0" } end
	if state == "on" then return { [case.cvar] = "1" } end
	return {}
end

-- Whether the model's own `hidden` says the control is shown, as AceConfig
-- reads it, and whether the window draws it.
local function modelShown(ns, key)
	local control = ns.optionsTable and ns.optionsTable.args and ns.optionsTable.args.who
		and ns.optionsTable.args.who.args[key]
	if not control then return "missing" end
	local hidden = control.hidden
	if type(hidden) == "function" then hidden = hidden({}) end
	return not hidden
end

-- ------------------------------------------------------------------ the tab
-- Passers-by on and the nameplates off: the note and the button, the note
-- saying what is wrong, the button the one What I say has.
for _, case in ipairs(CASES) do
	local scenario = "hunt25-plates: " .. case.label .. ": Who to buff says the nameplates are off while passers-by are on"
	session(scenario, case, plates(case, "off"), { crowd = true }, function(ns, box)
		ns.db.profile.sources.strangers = true
		ns.OpenOptions("who")
		local UI = ns.WindowUI
		for _, key in ipairs({ "strangersPlatesNote", "strangersShowPlates" }) do
			if modelShown(ns, key) ~= true then fail(scenario, "the model does not show " .. key) end
		end
		if not UI.RowShown(NOTE) then fail(scenario, "the note is not drawn") end
		if not UI.RowShown(BUTTON) then fail(scenario, "the button is not drawn") end
		local row = UI.RowFor(NOTE)
		local text = row and ns.WindowBind.Text(row.item, "name")
		if not (text and text:find("Turn on friendly nameplates so Manners can see passers-by", 1, true)
			and text:find("almost nobody outside your group", 1, true)) then
			fail(scenario, "the note says " .. tostring(text))
		end
		local button = UI.RowFor(BUTTON)
		local label = button and ns.WindowBind.Text(button.item, "name")
		if label ~= "Show friendly nameplates" then fail(scenario, "the button reads " .. tostring(label)) end
		if #box.sets > 0 then fail(scenario, "the setting was changed without a click") end
	end)
end

-- ------------------------------------------------------------------ placed
-- Right under the passers-by switch, in its section, the note first.
do
	local scenario = "hunt25-plates: the note and the button sit right under the passers-by switch"
	session(scenario, CASES[1], plates(CASES[1], "off"), { crowd = true }, function(ns)
		local page, section, at = H.placedOn(ns, "who.strangers")
		local notePage, noteSection, noteAt = H.placedOn(ns, NOTE)
		local buttonPage, buttonSection, buttonAt = H.placedOn(ns, BUTTON)
		if not (page and notePage and buttonPage) then
			fail(scenario, ("not all placed: %s %s %s"):format(tostring(page), tostring(notePage), tostring(buttonPage)))
		elseif not (notePage == page and buttonPage == page and noteSection == section and buttonSection == section) then
			fail(scenario, "the note or the button is on another page or in another section than the passers-by switch")
		elseif not (noteAt == at + 1 and buttonAt == at + 2) then
			fail(scenario, ("the switch is item %d, the note %d and the button %d"):format(at, noteAt, buttonAt))
		end
	end)
end

-- ------------------------------------------------------------------ hidden
-- Shown only while all of it is so: passers-by on, a class they mean
-- something to, and a client that plainly says the nameplates are off.
for _, case in ipairs(CASES) do
	for _, c in ipairs({
		{ "the nameplates on", "on", true, false },
		{ "the client will not say", "silent", true, false },
		{ "passers-by off", "off", false, false },
		{ "passers-by on, nameplates off", "off", true, true },
		{ "everything reaches only the group", "off", true, false, true },
		{ "a class with nothing for anybody else", "off", true, false, false, true },
	}) do
		local label, state, strangers, want, groupOnly, noClassBuffs = c[1], c[2], c[3], c[4], c[5], c[6]
		local scenario = "hunt25-plates: " .. case.label .. ": the note and the button on Who to buff (" .. label .. ")"
		session(scenario, case, plates(case, state), { crowd = true }, function(ns, box)
			ns.db.profile.sources.strangers = strangers
			if groupOnly then ns.OnlyReachesGroup = function() return true end end
			if noClassBuffs then ns.caps.hasClassBuffs = false end
			ns.OpenOptions("who")
			local UI = ns.WindowUI
			for _, key in ipairs({ "strangersPlatesNote", "strangersShowPlates" }) do
				local got = modelShown(ns, key)
				if got ~= want then
					fail(scenario, ("the model answers %s for %s, which should be %s"):format(
						tostring(got), key, want and "shown" or "hidden"))
				end
			end
			for _, path in ipairs({ NOTE, BUTTON }) do
				if UI.RowShown(path) ~= want then
					fail(scenario, ("the window %s %s, which should be %s"):format(
						UI.RowShown(path) and "draws" or "hides", path, want and "shown" or "hidden"))
				end
			end
			if #box.sets > 0 then fail(scenario, "the setting was changed without a click") end
		end)
	end
end

-- ------------------------------------------------------------------ the button
-- Greyed and refused in a fight; out of one it turns the setting on, once, the
-- game's own name for it, and the note goes at once.
for _, case in ipairs(CASES) do
	local scenario = "hunt25-plates: " .. case.label .. ": Show friendly nameplates turns them on out of combat only"
	session(scenario, case, plates(case, "off"), { crowd = true }, function(ns, box)
		ns.db.profile.sources.strangers = true
		ns.OpenOptions("who")
		local UI = ns.WindowUI
		local row = UI.RowFor(BUTTON)
		if not (row and row.button and UI.RowShown(BUTTON)) then
			fail(scenario, "SKIPPED -- the button was not drawn")
			return
		end
		Mock.inCombat = true
		UI.Refresh()
		if not UI.Disabled(row.item) then fail(scenario, "the button is live in a fight") end
		-- Reached anyway: a click that lands as the fight starts.
		ns.WindowBind.Run(row.item)
		if #box.sets > 0 then fail(scenario, "the setting was changed in a fight") end
		if not UI.RowShown(NOTE) then fail(scenario, "the note went with nothing changed") end
		Mock.inCombat = false
		UI.Refresh()
		if UI.Disabled(row.item) then fail(scenario, "the button stayed grey after the fight") end
		press(row.button)
		if #box.sets ~= 1 or box.sets[1][1] ~= case.cvar or tostring(box.sets[1][2]) ~= "1" then
			fail(scenario, ("the click made %d changes, the first %s"):format(#box.sets,
				box.sets[1] and (tostring(box.sets[1][1]) .. " = " .. tostring(box.sets[1][2])) or "none"))
		end
		if UI.RowShown(NOTE) or UI.RowShown(BUTTON) then
			fail(scenario, "the note stayed up with the nameplates on")
		end
		if ns.FriendlyPlatesOff() then fail(scenario, "the nameplates still read as off") end
	end)
end

-- The page open anywhere is told once the setting has changed, so the note
-- goes: the custom window repaints itself after any button, but the fallback
-- dialog redraws only when asked (AceConfigRegistry:NotifyChange), and reads
-- `hidden` only while it draws.
for _, case in ipairs(CASES) do
	local scenario = "hunt25-plates: " .. case.label .. ": the button has the open page redrawn once the nameplates are on"
	session(scenario, case, plates(case, "off"), { crowd = true }, function(ns, box)
		ns.db.profile.sources.strangers = true
		local registry = LibStub("AceConfigRegistry-3.0")
		local control = ns.optionsTable and ns.optionsTable.args.who and ns.optionsTable.args.who.args.strangersShowPlates
		if not (control and type(control.func) == "function" and registry and registry.NotifyChange) then
			fail(scenario, "SKIPPED -- no button or no repaint to watch")
			return
		end
		local realNotify = registry.NotifyChange
		local told, noteShown = 0, nil
		registry.NotifyChange = function(...)
			told = told + 1
			noteShown = modelShown(ns, "strangersPlatesNote")
			return realNotify(...)
		end
		local ok, err = pcall(control.func, {})
		registry.NotifyChange = realNotify
		if not ok then fail(scenario, "the button threw: " .. tostring(err)) end
		if #box.sets ~= 1 then fail(scenario, ("the button made %d changes"):format(#box.sets)) end
		if told == 0 then
			fail(scenario, "the button never had the open page redrawn")
		elseif noteShown ~= false then
			fail(scenario, "the page was redrawn with the note still due: " .. tostring(noteShown))
		end
	end)
end

-- ------------------------------------------------------------------ the keypress
-- A keypress on an empty prompt: nobody is found, passers-by are on and the
-- nameplates are off, so it says that and names the button and its tab.
for _, case in ipairs(CASES) do
	local scenario = "hunt25-plates: " .. case.label .. ": an empty keypress names the nameplates when they are why"
	session(scenario, case, plates(case, "off"), nil, function(ns)
		ns.db.profile.sources.strangers = true
		if ns.Prompt:GetButton():IsShown() then
			fail(scenario, "SKIPPED -- the prompt is up with nobody to offer")
			return
		end
		Mock.printed = {}
		local ran = H.pressButton(ns)
		local text = said()
		if ran then fail(scenario, "a press on an empty prompt cast: " .. tostring(ran)) end
		if not text:find("nobody to buff right now", 1, true) then
			fail(scenario, "the press never said nobody is wanted: " .. text)
		end
		if not text:find("friendly nameplates are off", 1, true) then
			fail(scenario, "the press never said the nameplates are off: " .. text)
		end
		if not text:find("passers-by", 1, true) then
			fail(scenario, "the press never said passers-by are seen through them: " .. text)
		end
		-- The names as the window shows them, so a translation agrees with it.
		ns.OpenOptions("who")
		local UI = ns.WindowUI
		local row = UI.RowFor(BUTTON)
		local label = row and ns.WindowBind.Text(row.item, "name")
		if not (label and text:find(label, 1, true)) then
			fail(scenario, "the press does not name the button the window shows (" .. tostring(label) .. "): " .. text)
		end
		local tab = ns.OptionsPage and ns.OptionsPage.TAB and ns.OptionsPage.TAB.who
		if not (tab and text:find(tab, 1, true)) then
			fail(scenario, "the press does not name the tab " .. tostring(tab) .. ": " .. text)
		end
		-- ... and what it names is there, under the tab it names.
		if not UI.RowShown(BUTTON) then fail(scenario, "the button the press names is not on the tab") end
		local _, count = text:gsub("\n", "\n")
		if count > 0 then fail(scenario, "the press said more than one line: " .. text) end
	end)
end

-- Not when the nameplates are not what is missing, or passers-by could not be
-- found through them anyway: the plain line.
for _, case in ipairs(CASES) do
	for _, c in ipairs({
		{ "the nameplates on", "on" },
		{ "the client will not say", "silent" },
		{ "passers-by off", "off", { strangers = false } },
		{ "everything reaches only the group", "off", { groupOnly = true } },
		{ "passers-by only in cities, out in the world", "off", { restingOnly = true, resting = false } },
		{ "a class with nothing for anybody else", "off", { noClassBuffs = true } },
	}) do
		local label, state, set = c[1], c[2], c[3] or {}
		local scenario = "hunt25-plates: " .. case.label .. ": an empty keypress does not name the nameplates (" .. label .. ")"
		session(scenario, case, plates(case, state), nil, function(ns)
			ns.db.profile.sources.strangers = set.strangers ~= false
			if set.groupOnly then ns.OnlyReachesGroup = function() return true end end
			if set.restingOnly then
				ns.db.profile.filters.restingOnly = true
				rawset(_G, "IsResting", function() return set.resting end)
			end
			if set.noClassBuffs then ns.caps.hasClassBuffs = false end
			if ns.Prompt:GetButton():IsShown() then
				fail(scenario, "SKIPPED -- the prompt is up with nobody to offer")
				return
			end
			Mock.printed = {}
			H.pressButton(ns)
			local text = said()
			if text:find("nameplate", 1, true) then
				fail(scenario, "the press named the nameplates: " .. text)
			end
			if not text:find("nobody to buff right now.", 1, true) then
				fail(scenario, "the press lost its plain line: " .. text)
			end
		end)
	end
end

-- The same player in a city, where passers-by are offered, is told.
for _, case in ipairs(CASES) do
	local scenario = "hunt25-plates: " .. case.label .. ": passers-by only in cities, in a city, an empty keypress names the nameplates"
	session(scenario, case, plates(case, "off"), nil, function(ns)
		ns.db.profile.sources.strangers = true
		ns.db.profile.filters.restingOnly = true
		rawset(_G, "IsResting", function() return true end)
		if ns.Prompt:GetButton():IsShown() then
			fail(scenario, "SKIPPED -- the prompt is up with nobody to offer")
			return
		end
		Mock.printed = {}
		H.pressButton(ns)
		if not said():find("friendly nameplates are off", 1, true) then
			fail(scenario, "the press never said the nameplates are off: " .. said())
		end
	end)
end

-- Never in place of a more specific reason: each of these keeps its own line,
-- and the nameplates stay unmentioned, with passers-by on and them off.
for _, case in ipairs(CASES) do
	for _, c in ipairs({
		{ "switched off", "switched off", function(ns)
			ns.addon:HandleSlash("off")
			Mock.advance(1)
		end },
		{ "snoozed", "snoozed until", function(ns)
			ns.addon:HandleSlash("snooze 5")
			Mock.advance(1)
		end },
		{ "mounted", "you are mounted", function(ns)
			ns.db.profile.filters.hideMounted = true
			rawset(_G, "IsMounted", function() return true end)
		end },
		{ "nothing learned", "nothing learned to cast yet", function(ns)
			ns.caps.anyKnown, ns.caps.anyOwnKnown = false, false
		end },
		{ "saving mana", "saving mana until you are back to", function(ns)
			ns.SavingMana = function() return 50, 60 end
		end },
	}) do
		local label, wording, arrange = c[1], c[2], c[3]
		local scenario = "hunt25-plates: " .. case.label .. ": an empty keypress keeps its own reason (" .. label .. ")"
		session(scenario, case, plates(case, "off"), nil, function(ns)
			ns.db.profile.sources.strangers = true
			arrange(ns)
			if ns.Prompt:GetButton():IsShown() then
				fail(scenario, "SKIPPED -- the prompt is up")
				return
			end
			Mock.printed = {}
			H.pressButton(ns)
			local text = said()
			if not text:find(wording, 1, true) then
				fail(scenario, "the press never said its own reason (" .. wording .. "): " .. text)
			end
			if text:find("nameplate", 1, true) then
				fail(scenario, "the press named the nameplates in place of its reason: " .. text)
			end
		end)
	end
end
