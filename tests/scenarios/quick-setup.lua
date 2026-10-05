-- First use: the two questions a new profile is asked on Start here
-- (Options/Start.lua, Quick.Asking), and the friendly nameplate hint on What I
-- say (Speech.lua, ns.FriendlyPlatesOff and ns.NoteTokenlessHold).
--
-- The questions are Start here's own presets put plainly, so Done must leave
-- the profile exactly as picking the same two presets does; Skip leaves it as
-- it was; and a profile from before -- the anchor stamp ClampSettings writes
-- on every profile it has seen -- is never asked at all.
--
-- The hint: with friendly nameplates off a passer-by seldom has a unit token,
-- and a line goes only with a press on somebody a token names (Prompt/Press.lua,
-- HoldLine), so every line to a stranger is held back without a word. What I
-- say says so while speaking with them off, its button turns them on only out
-- of combat and only when clicked, and the first such hold says it in chat
-- once a session.
--
-- Every scenario name starts with "quick-setup:" so the mutations in
-- tests/mutations/quick-setup.py can name the one that has to catch them.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

local FIRST = { "general.firstWho", "general.firstVoice", "general.firstDone", "general.firstSkip" }

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

local function shut(ns)
	ns.CloseOptions()
	ns.Prompt:ExitTest()
end

-- The client's settings, as GetCVar and SetCVar see them, with every SetCVar
-- written down. Answers the table and a function that puts the real ones back.
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

local function session(scenario, class)
	Mock.reset()
	if class then Mock.class = class end
	local ns = load(scenario)
	if not ns then return nil end
	drive(scenario, ns)
	ns.Prompt:ExitTest()
	Mock.printed = {}
	return ns
end

-- A copy of everything in the profile, for comparing before and after.
local function copy(t)
	if type(t) ~= "table" then return t end
	local out = {}
	for k, v in pairs(t) do out[k] = copy(v) end
	return out
end

-- The first path where the two differ, or nil.
local function differs(a, b, path)
	path = path or "profile"
	if type(a) ~= "table" or type(b) ~= "table" then
		if a ~= b then return path end
		return nil
	end
	for k, v in pairs(a) do
		local d = differs(v, b[k], path .. "." .. tostring(k))
		if d then return d end
	end
	for k, v in pairs(b) do
		if a[k] == nil then return path .. "." .. tostring(k) end
	end
	return nil
end

local function anyShown(UI)
	for _, path in ipairs(FIRST) do
		if UI.RowShown(path) then return path end
	end
	return nil
end

-- The keys a question offers, in order.
local function offered(ns, path)
	local row = ns.WindowUI.RowFor(path)
	local keys = {}
	if not row then return keys end
	for _, pair in ipairs(ns.WindowBind.Values(row.item)) do keys[#keys + 1] = pair[1] end
	return keys
end

-- ------------------------------------------------------------ asked once
-- Opened with no page asked for, even after the last session left it on When
-- to offer: Start here, the two questions at the top.
do
	local scenario = "quick-setup: a new profile is asked two questions on Start here"
	local ns = session(scenario)
	if ns then
		local UI = ns.WindowUI
		local quick = ns.QuickSetup
		if ns.db.profile.firstRun ~= "pending" then
			fail(scenario, "a new profile's firstRun is " .. tostring(ns.db.profile.firstRun) .. ", not pending")
		end
		UI.State().page = "when"
		ns.OpenOptions()
		if ns.OptionsTab() ~= "general" then
			fail(scenario, "the first open landed on " .. tostring(ns.OptionsTab()) .. ", not Start here")
		end
		for _, path in ipairs(FIRST) do
			if not UI.RowShown(path) then fail(scenario, path .. " is not shown on a new profile") end
		end
		-- The first section of the page.
		local w = UI.Where("general.firstWho")
		local first = ns.WindowLayout.pages.general.sections[1]
		if not (w and w.sec and w.sec.def == first and first.header == "general.firstHeader") then
			fail(scenario, "the questions are not the first section of Start here, under Quick setup")
		end
		local who = table.concat(offered(ns, "general.firstWho"), " ")
		if who ~= "favours group nearby raid" then
			fail(scenario, "Who do you want to buff? offers " .. who)
		end
		local voice = table.concat(offered(ns, "general.firstVoice"), " ")
		if voice ~= "silent thank polite incharacter" then
			fail(scenario, "Should your character talk? offers " .. voice)
		end
		if not quick.Asking() then fail(scenario, "Quick.Asking() is false on a new profile") end
		shut(ns)
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------ Done
-- Every pair of answers leaves the profile as the two presets would, and the
-- questions never come back: not on reopening, not after a reload.
local WHO = { "favours", "group", "nearby", "raid" }
local VOICE = { "silent", "thank", "polite", "incharacter" }
for i = 1, 4 do
	local who, voice = WHO[i], VOICE[5 - i]
	local scenario = "quick-setup: Done sets what the presets set (" .. who .. ", " .. voice .. ")"
	-- What picking the two presets on a new profile writes.
	local want
	local base = session(scenario)
	if base then
		local quick = base.QuickSetup
		quick.Apply(quick.WHO, who)
		quick.Apply(quick.VOICE, voice)
		want = copy(base.db.profile)
		base.Prompt:ExitTest()
	end
	local ns = want and session(scenario)
	if ns then
		local UI, B = ns.WindowUI, ns.WindowBind
		ns.OpenOptions()
		local whoRow, voiceRow = UI.RowFor("general.firstWho"), UI.RowFor("general.firstVoice")
		local done = UI.RowFor("general.firstDone")
		if not (whoRow and voiceRow and done and done.button) then
			fail(scenario, "SKIPPED -- the questions were not drawn")
		else
			B.Commit(whoRow.item, who)
			B.Commit(voiceRow.item, voice)
			-- A pick is only a pick until Done.
			if ns.QuickSetup.Match(ns.QuickSetup.VOICE) ~= "silent" and voice ~= "silent" then
				fail(scenario, "picking an answer changed the settings before Done")
			end
			press(done.button)
			if ns.db.profile.firstRun ~= "answered" then
				fail(scenario, "after Done firstRun is " .. tostring(ns.db.profile.firstRun))
			end
			local got = copy(ns.db.profile)
			got.firstRun, want.firstRun = nil, nil
			local d = differs(want, got)
			if d then fail(scenario, "Done and the presets differ at " .. d) end
			local quick = ns.QuickSetup
			if quick.Match(quick.WHO) ~= who or quick.Match(quick.VOICE) ~= voice then
				fail(scenario, "Start here now shows " .. quick.Match(quick.WHO) .. " and " .. quick.Match(quick.VOICE))
			end
			if not said():find("Set up: ", 1, true) then
				fail(scenario, "Done said nothing in chat")
			end
			local left = anyShown(UI)
			if left then fail(scenario, left .. " is still shown after Done") end
			shut(ns)
			UI.State().page = "when"
			ns.OpenOptions()
			left = anyShown(UI)
			if left or ns.OptionsTab() ~= "when" then
				fail(scenario, "reopened, the questions came back (" .. tostring(left) .. ", on " .. tostring(ns.OptionsTab()) .. ")")
			end
			shut(ns)
			local again = load(scenario)
			if again then
				drive(scenario, again)
				again.Prompt:ExitTest()
				if again.QuickSetup.Asking() or again.db.profile.firstRun ~= "answered" then
					fail(scenario, "after a reload the profile is asked again")
				end
				again.Prompt:ExitTest()
			end
		end
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------ Skip
do
	local scenario = "quick-setup: Skip changes nothing and is never asked again"
	local ns = session(scenario)
	if ns then
		local UI, B = ns.WindowUI, ns.WindowBind
		ns.OpenOptions()
		local whoRow, skip = UI.RowFor("general.firstWho"), UI.RowFor("general.firstSkip")
		if not (whoRow and skip and skip.button) then
			fail(scenario, "SKIPPED -- the questions were not drawn")
		else
			-- A pick, then Skip: the pick goes unused.
			B.Commit(whoRow.item, "favours")
			local before = copy(ns.db.profile)
			press(skip.button)
			if ns.db.profile.firstRun ~= "skipped" then
				fail(scenario, "after Skip firstRun is " .. tostring(ns.db.profile.firstRun))
			end
			local after = copy(ns.db.profile)
			before.firstRun, after.firstRun = nil, nil
			local d = differs(before, after)
			if d then fail(scenario, "Skip changed " .. d) end
			local left = anyShown(UI)
			if left then fail(scenario, left .. " is still shown after Skip") end
			shut(ns)
			ns.OpenOptions()
			if anyShown(UI) then fail(scenario, "reopened, the questions came back") end
			shut(ns)
			-- Skipped, then the window reopened on a new session: still nothing.
			local again = load(scenario)
			if again then
				drive(scenario, again)
				again.Prompt:ExitTest()
				again.OpenOptions()
				if anyShown(again.WindowUI) then fail(scenario, "after a reload the questions came back") end
				shut(again)
			end
		end
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------ existing
-- A profile saved by 1.6.5: the anchor stamp is there, firstRun is not. It is
-- set up already and is never asked, and the window opens where it was left.
-- A value no version writes reads the same way.
for _, case in ipairs({ { "saved by 1.6.5", nil }, { "a damaged value", "maybe" } }) do
	local label, value = case[1], case[2]
	local scenario = "quick-setup: an existing profile is never asked (" .. label .. ")"
	local first = session(scenario)
	if first then
		first.Prompt:ExitTest()
		if Mock.sv.profile.prompt.anchorCarried ~= true then
			fail(scenario, "SKIPPED -- the first session left no anchor stamp")
		end
		Mock.sv.profile.firstRun = value
		Mock.sv.global = Mock.sv.global or {}
		local ns = load(scenario)
		if ns then
			drive(scenario, ns)
			ns.Prompt:ExitTest()
			if ns.db.profile.firstRun ~= "existing" then
				fail(scenario, "firstRun reads " .. tostring(ns.db.profile.firstRun) .. ", not existing")
			end
			ns.WindowUI.State().page = "when"
			ns.OpenOptions()
			if ns.OptionsTab() ~= "when" then
				fail(scenario, "the window opened on " .. tostring(ns.OptionsTab()) .. ", not where it was left")
			end
			ns.OpenOptions("general")
			local left = anyShown(ns.WindowUI)
			if left then fail(scenario, left .. " is shown on a profile that was set up long ago") end
			shut(ns)
			noErrors(scenario, ns)
		end
	end
end

-- ------------------------------------------------------------ the fallback
-- AceConfig's own dialog, used when the window fails: the same five controls
-- on Start here, ahead of the rest, gone once answered.
do
	local scenario = "quick-setup: the fallback dialog asks the same questions"
	local ns = session(scenario)
	if ns then
		local args = ns.optionsTable and ns.optionsTable.args.general.args
		local info = { "general" }
		local keys = { "firstHeader", "firstWho", "firstVoice", "firstDone", "firstSkip" }
		for _, key in ipairs(keys) do
			local def = args and args[key]
			if not def then
				fail(scenario, "Start here has no " .. key)
			elseif def.hidden(info) then
				fail(scenario, key .. " is hidden on a new profile")
			elseif not (def.order < args.enabled.order) then
				fail(scenario, key .. " is not ahead of the rest of Start here")
			end
		end
		if args and args.firstVoice then
			local values = args.firstVoice.values(info)
			if values.whisper or values.custom or not values.incharacter then
				fail(scenario, "the fallback's voice question offers the wrong choices")
			end
			args.firstVoice.set(info, "thank")
			args.firstDone.func(info)
			if ns.QuickSetup.Match(ns.QuickSetup.VOICE) ~= "thank" then
				fail(scenario, "the fallback's Done did not apply Just /thank them")
			end
			for _, key in ipairs(keys) do
				if not args[key].hidden(info) then fail(scenario, key .. " is still shown after Done") end
			end
		end
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------ no buffs
do
	local scenario = "quick-setup: a class with nothing to give is not asked"
	local ns = session(scenario, "ROGUE")
	if ns then
		if ns.QuickSetup.Asking() then fail(scenario, "a rogue is asked who to buff") end
		ns.OpenOptions()
		if anyShown(ns.WindowUI) then fail(scenario, "a rogue sees the questions") end
		shut(ns)
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------ the hint
for _, case in ipairs({
	{ "speaking, nameplates off", true, "0", true },
	{ "silent, nameplates off", false, "0", false },
	{ "speaking, nameplates on", true, "1", false },
	{ "speaking, the client will not say", true, nil, false },
}) do
	local label, speaking, value, want = case[1], case[2], case[3], case[4]
	local scenario = "quick-setup: the nameplate note shows only while speaking with them off (" .. label .. ")"
	local box, restore = cvars({ nameplateShowFriendlyPlayers = value })
	local ns = session(scenario)
	if ns then
		ns.db.profile.speech.enabled = speaking
		ns.OpenOptions("click")
		local UI = ns.WindowUI
		local note, button = UI.RowShown("click.platesNote"), UI.RowShown("click.showPlates")
		if note ~= want or button ~= want then
			fail(scenario, ("the note is %s and the button %s, where both should be %s")
				:format(note and "shown" or "hidden", button and "shown" or "hidden", want and "shown" or "hidden"))
		end
		if want then
			local text = UI.RowFor("click.platesNote") and ns.WindowBind.Text(UI.RowFor("click.platesNote").item, "name")
			if not (text and text:find("Turn on friendly nameplates so Manners can tell when strangers are in range to hear you", 1, true)) then
				fail(scenario, "the note says " .. tostring(text))
			end
		end
		if #box.sets > 0 then fail(scenario, "the setting was changed without a click") end
		shut(ns)
		noErrors(scenario, ns)
	end
	restore()
end

-- The button: greyed and refused in a fight, and out of one sets the setting
-- once, after which the note has nothing to say.
do
	local scenario = "quick-setup: Show friendly nameplates sets the setting only out of combat"
	local box, restore = cvars({ nameplateShowFriendlyPlayers = "0" })
	local ns = session(scenario)
	if ns then
		ns.db.profile.speech.enabled = true
		ns.OpenOptions("click")
		local UI = ns.WindowUI
		local row = UI.RowFor("click.showPlates")
		if not (row and row.button and UI.RowShown("click.showPlates")) then
			fail(scenario, "SKIPPED -- the button was not drawn")
		else
			Mock.inCombat = true
			UI.Refresh()
			if not UI.Disabled(row.item) then fail(scenario, "the button is live in a fight") end
			-- Reached anyway (a click that lands as the fight starts).
			ns.WindowBind.Run(row.item)
			if #box.sets > 0 then fail(scenario, "the setting was changed in a fight") end
			Mock.inCombat = false
			UI.Refresh()
			if UI.Disabled(row.item) then fail(scenario, "the button stayed grey after the fight") end
			press(row.button)
			if #box.sets ~= 1 or box.sets[1][1] ~= "nameplateShowFriendlyPlayers" or tostring(box.sets[1][2]) ~= "1" then
				fail(scenario, ("the click made %d changes"):format(#box.sets))
			end
			if UI.RowShown("click.platesNote") or UI.RowShown("click.showPlates") then
				fail(scenario, "the note stayed up with the nameplates on")
			end
		end
		shut(ns)
		noErrors(scenario, ns)
	end
	restore()
end

-- Which setting: WoW Forever answers nameplateShowFriendlyPlayers and not the
-- old nameplateShowFriends (a 1.6.6 self-test read nil there); the Classic
-- clients answer only the old one. The button sets the one that answered.
for _, case in ipairs({
	{ "Forever's name", "nameplateShowFriendlyPlayers" },
	{ "Classic's name", "nameplateShowFriends" },
}) do
	local label, cvar = case[1], case[2]
	local scenario = "quick-setup: the nameplate setting is read by the name the client answers to (" .. label .. ")"
	local box, restore = cvars({ [cvar] = "0" })
	local ns = session(scenario)
	if ns then
		local name, value = ns.FriendlyPlatesCVar()
		if name ~= cvar or value ~= "0" then
			fail(scenario, ("read %s = %s, not %s = 0"):format(tostring(name), tostring(value), cvar))
		end
		if not ns.FriendlyPlatesOff() then fail(scenario, "the nameplates were not read as off") end
		ns.ShowFriendlyPlates()
		if #box.sets ~= 1 or box.sets[1][1] ~= cvar then
			fail(scenario, "the button set " .. tostring(box.sets[1] and box.sets[1][1]) .. ", not " .. cvar)
		end
		noErrors(scenario, ns)
	end
	restore()
end

-- The chat line: the first press whose line is held back for want of a token,
-- with the nameplates off, says why; the next one does not. Two people owed
-- and seen by no token, so both presses reach the hold.
local WEIRBEARD, MUNIN = "Weirbeard Jenkins", "Munin Hugins"
local function hintLines()
	local n = 0
	for _, line in ipairs(Mock.printed or {}) do
		if line:find("friendly nameplates off", 1, true) then n = n + 1 end
	end
	return n
end

for _, case in ipairs({
	{ "nameplates off", "0", true, 1 },
	{ "nameplates on", "1", true, 0 },
	{ "speech off", "0", false, 0 },
	{ "chat messages off", "0", true, 0, true },
}) do
	local label, value, speaking, want, quiet = case[1], case[2], case[3], case[4], case[5]
	local scenario = "quick-setup: a line held back for want of nameplates is said once a session (" .. label .. ")"
	local box, restore = cvars({ nameplateShowFriendlyPlayers = value })
	Mock.reset()
	local restoreUnits = H.strangers({})
	local ns = load(scenario)
	if ns then
		H.freshPrompt(ns, scenario)
		local speech = ns.db.profile.speech
		speech.enabled = speaking
		ns.db.profile.verbose = not quiet
		speech.onlyWhenReturning = false
		speech.channel = "SAY"
		speech.phrases = "Thanks, {name}."
		ns.db.profile.sources.self = false
		H.owe(ns, WEIRBEARD)
		H.owe(ns, MUNIN)
		ns.Prompt:InvalidateMacro()
		ns.addon:Tick()
		Mock.printed = {}
		local targets = {}
		for _ = 1, 2 do
			Mock.advance(1)
			local ran = H.pressButton(ns) or ""
			targets[#targets + 1] = ran:match("/target ([^\n]+)") or "nobody"
			if ran:find("\n/say ", 1, true) then fail(scenario, "a press with no token spoke: " .. ran) end
			ns.addon:Tick()
		end
		if targets[1] == targets[2] or targets[1] == "nobody" then
			fail(scenario, "SKIPPED -- the two presses went to " .. table.concat(targets, " and "))
		end
		if hintLines() ~= want then
			fail(scenario, ("said the nameplate line %d times, not %d: %s"):format(hintLines(), want, said()))
		end
		if #box.sets > 0 then fail(scenario, "a press changed the nameplate setting") end
		noErrors(scenario, ns)
		ns.Prompt:ExitTest()
	end
	restoreUnits()
	restore()
end
Mock.reset()
