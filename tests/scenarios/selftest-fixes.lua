-- Round 30's fixes around /manners selftest (Selftest.lua) and the once-a-
-- session nameplate line it sits beside:
--
--   - window.build built the options window under a bare pcall. A build that
--     threw part-way left UI.frame set and UI.built not, and Register.lua's
--     `broken` unset, so every later opening showed the half-built frame and
--     nothing fell back to the old dialog; a second self-test built a second
--     frame over the first. It now builds through ns.BuildOptionsWindow, the
--     same guard /manners meets the failure in.
--   - range.proximity graded its line by finding the English words "no
--     signal" in a translated summary, so no translated client ever warned.
--     ns.ProximitySummary now says whether nothing measures as a second value.
--   - beliefs.scrolls said nothing for a Forever mage with no scrolls in the
--     bags, so Selftest.Run filled in WARN "said nothing".
--   - the "friendly nameplates off" chat line (Speech.lua, NoteTokenlessHold)
--     and What I say's note were said with the line in /party or /raid, where
--     no stranger is ever spoken to and the nameplates change nothing.
--
-- Called by scenarios.lua with the addon directory and its helpers. Every
-- scenario name starts with "selftest-fix:" so the mutations in
-- tests/mutations/selftest-fixes.py can name the one that has to catch them.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

local function session(scenario, setup)
	Mock.reset()
	if setup then setup() end
	local ns = load(scenario)
	if not ns then return nil end
	drive(scenario, ns)
	ns.Prompt:ExitTest()
	Mock.printed = {}
	return ns
end

-- Every line check `id` gave, and the worst of their statuses.
local function status(results, id)
	local worst, rank = nil, { PASS = 1, WARN = 2, FAIL = 3 }
	local lines = {}
	for _, r in ipairs(results) do
		if r.id == id then
			if not worst or rank[r.status] > rank[worst] then worst = r.status end
			lines[#lines + 1] = r.status .. " " .. r.value
		end
	end
	return worst, table.concat(lines, " / ")
end

-- ------------------------------------------------------------ window.build
-- The failure is put in at the footer, standing in for any client API the
-- window's last steps need and a client lacks: the frame exists by then.

-- Counts the times the old dialog is opened.
local function spyDialog()
	local dialog = LibStub("AceConfigDialog-3.0")
	local real = dialog.Open
	local box = { opened = 0 }
	dialog.Open = function(...)
		box.opened = box.opened + 1
		return real(...)
	end
	return box, function() dialog.Open = real end
end

local function breakFooter(ns)
	ns.WindowUI.BuildFooter = function() error("injected: the footer needs an API this client lacks", 0) end
end

-- What /manners does with it, which the self-test has to end the same way as.
do
	local scenario = "selftest-fix: without the self-test a window that will not build falls back"
	local ns = session(scenario)
	if ns then
		if ns.WindowUI.built or ns.WindowUI.frame then
			fail(scenario, "SKIPPED -- the window was built before the scenario")
		else
			breakFooter(ns)
			local box, restore = spyDialog()
			ns.OpenOptions()
			restore()
			if not ns.OptionsFallback() or box.opened ~= 1 then
				fail(scenario, ("fallback %s, the dialog opened %d times"):format(
					tostring(ns.OptionsFallback()), box.opened))
			end
		end
	end
end

-- The same failure met first by /manners selftest: its report says so, its
-- box and the next /manners open the old dialog, and no half-built window is
-- on screen.
do
	local scenario = "selftest-fix: after the self-test a window that will not build still falls back"
	local ns = session(scenario)
	if ns then
		if ns.WindowUI.built or ns.WindowUI.frame then
			fail(scenario, "SKIPPED -- the window was built before the scenario")
		else
			breakFooter(ns)
			local box, restore = spyDialog()
			ns.addon:HandleSlash("selftest")
			local selftestOpened = box.opened
			local text = ns.Selftest.last or ""
			if not text:find("FAIL  builds: building it threw: injected: the footer", 1, true) then
				fail(scenario, "the report does not say the window threw: " .. text:sub(1, 300))
			end
			if not text:find("FAIL  fallback: the window failed this session", 1, true) then
				fail(scenario, "the report does not say the old dialog stands in")
			end
			if selftestOpened == 0 then
				fail(scenario, "the self-test's report box did not open in the old dialog")
			end
			ns.CloseOptions()
			ns.OpenOptions()
			restore()
			local frame = ns.WindowUI.frame
			if not ns.OptionsFallback() or box.opened <= selftestOpened then
				fail(scenario, ("the options never fall back to the old dialog (fallback %s, dialog opened %d times)")
					:format(tostring(ns.OptionsFallback()), box.opened))
			end
			if frame and frame:IsShown() and not ns.WindowUI.built then
				fail(scenario, "a half-built options window is on screen in place of the settings")
			end
		end
	end
end

-- And a second run in the same session builds nothing over the first: one
-- frame, hidden, still the one the MannersOptions global names.
do
	local scenario = "selftest-fix: a second self-test builds no second window"
	local ns = session(scenario)
	if ns then
		if ns.WindowUI.built or ns.WindowUI.frame then
			fail(scenario, "SKIPPED -- the window was built before the scenario")
		else
			breakFooter(ns)
			ns.addon:HandleSlash("selftest")
			local first = ns.WindowUI.frame
			ns.addon:HandleSlash("selftest")
			local second = ns.WindowUI.frame
			if first ~= second then
				fail(scenario, ("a second frame was built, and _G.MannersOptions is %s")
					:format(_G.MannersOptions == first and "the first" or "the second"))
			end
			if first and first:IsShown() then
				fail(scenario, "the half-built frame is on screen")
			end
			local worst, lines = status(ns.Selftest.Run(), "window.build")
			if worst ~= "FAIL" or not lines:find("failed earlier this session", 1, true) then
				fail(scenario, "the second run's window.build reads " .. lines)
			end
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------ range.proximity
-- No LibRangeCheck (the mock's default) and no CheckInteractDistance: nothing
-- on this client can say how far anybody is, and every passer-by in casting
-- range is offered. A WARN in every language; with something to measure by,
-- a PASS in every language.
for _, case in ipairs({
	{ "enUS", "gone", "WARN" }, { "deDE", "gone", "WARN" }, { "frFR", "gone", "WARN" },
	{ "koKR", "gone", "WARN" }, { "deDE", "on", "PASS" }, { "koKR", "on", "PASS" },
}) do
	local locale, interact, want = case[1], case[2], case[3]
	local scenario = ("selftest-fix: range.proximity reads %s %s (%s)"):format(want,
		interact == "gone" and "with no distance signal" or "with a distance signal", locale)
	local ns = session(scenario, function() Mock.locale = locale end)
	if ns then
		ns.db.profile.filters.proximity = "near"
		ns.db.profile.sources.strangers = true
		ns.db.profile.filters.restingOnly = false
		Mock.setInteract(interact)
		ns.Guard("scenario", ns.ProbeCapabilities)
		ns.ForgetProximity()
		local worst, lines = status(ns.Selftest.Run(), "range.proximity")
		local source = ns.proximity and ns.proximity.source
		if (interact == "gone") ~= (source == nil) then
			fail(scenario, "SKIPPED -- measuring with " .. tostring(source))
		elseif worst ~= want then
			fail(scenario, "reads " .. tostring(lines))
		end
	end
	Mock.setInteract("on")
end
Mock.reset()

-- ------------------------------------------------------------ beliefs.scrolls
-- WoW Forever's C_Item.GetItemCount, which the mock's C_Item leaves out (so
-- ingame-selftest.lua only ever sees the "missing" line): a mage carrying no
-- scrolls is a PASS of its own, a count the client will not give a WARN that
-- says so, and neither is "said nothing". Forever's own data whatever client
-- the suite runs as: only Forever has scrolls.
-- The last field is words that must not be there: a count is its own line.
for _, case in ipairs({
	{ "none in the bags", function() return 0 end, "PASS", "none in the bags" },
	{ "a count the client will not give", function() error("no", 0) end, "WARN", "would not say how many" },
	{ "two of one scroll", "two", "PASS", "2, ", "none in the bags" },
}) do
	local label, answer, want, words, never = case[1], case[2], case[3], case[4], case[5]
	local scenario = "selftest-fix: a Forever mage's scrolls get a line of their own (" .. label .. ")"
	local ns = session(scenario, function()
		Mock.setFlavour("camelot")
		Mock.class = "MAGE"
	end)
	if ns then
		local first
		for _, family in ipairs(ns.GetOwnFamilies("MAGE") or {}) do
			for _, spell in ipairs(family.scroll and family.spells or {}) do first = first or spell.item end
		end
		if answer == "two" then
			answer = function(item) return item == first and 2 or 0 end
		end
		local list = C_Item and C_Item.GetWeaponEnchantInfo
		rawset(_G, "C_Item", { GetWeaponEnchantInfo = list, GetItemCount = answer })
		ns.ForgetScrolls()
		local ok, results = pcall(ns.Selftest.Run)
		rawset(_G, "C_Item", nil)
		if not first then
			fail(scenario, "SKIPPED -- no scroll families for a mage")
		elseif not ok then
			fail(scenario, "Run threw: " .. tostring(results))
		else
			local worst, lines = status(results, "beliefs.scrolls")
			if lines:find("said nothing", 1, true) or worst ~= want or not lines:find(words, 1, true)
				or (never and lines:find(never, 1, true)) then
				fail(scenario, "reads " .. lines)
			end
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------ the nameplate line
-- With the line in /party or /raid a stranger is never spoken to
-- (ns.ChannelOpen), so friendly nameplates are not why a line was left out:
-- neither the chat line nor What I say's note says so. In /say both do
-- (tests/scenarios/quick-setup.lua's own cases, kept here as the control).
local WEIRBEARD, MUNIN = "Weirbeard Jenkins", "Munin Hugins"

local function hintLines()
	local n = 0
	for _, line in ipairs(Mock.printed or {}) do
		if line:find("friendly nameplates off", 1, true) then n = n + 1 end
	end
	return n
end

-- Friendly nameplates off, as GetCVar answers; SetCVar does nothing.
local function platesOff()
	local realGet, realSet = rawget(_G, "GetCVar"), rawget(_G, "SetCVar")
	rawset(_G, "GetCVar", function(name)
		if name == "nameplateShowFriendlyPlayers" then return "0" end
		return nil
	end)
	rawset(_G, "SetCVar", function() end)
	return function()
		rawset(_G, "GetCVar", realGet)
		rawset(_G, "SetCVar", realSet)
	end
end

for _, case in ipairs({ { "SAY", "say", 1 }, { "PARTY", "party", 0 }, { "RAID", "raid", 0 } }) do
	local channel, command, want = case[1], case[2], case[3]
	local scenario = "selftest-fix: the nameplate line is said only where a line could go (" .. channel .. ")"
	local restorePlates = platesOff()
	Mock.reset()
	-- Two strangers owed, and no token names either.
	local restoreUnits = H.strangers({})
	local ns = load(scenario)
	if ns then
		H.freshPrompt(ns, scenario)
		local speech = ns.db.profile.speech
		speech.enabled = true
		ns.db.profile.verbose = true
		speech.onlyWhenReturning = false
		speech.channel = channel
		speech.phrases = "Thanks, {name}."
		ns.db.profile.sources.self = false
		H.owe(ns, WEIRBEARD)
		H.owe(ns, MUNIN)
		ns.Prompt:InvalidateMacro()
		ns.addon:Tick()
		Mock.printed = {}
		local spoke = false
		local targets = {}
		for _ = 1, 2 do
			Mock.advance(1)
			local ran = H.pressButton(ns) or ""
			targets[#targets + 1] = ran:match("/target ([^\n]+)") or "nobody"
			if ran:find("\n/" .. command .. " ", 1, true) then spoke = true end
			ns.addon:Tick()
		end
		if targets[1] == "nobody" then
			fail(scenario, "SKIPPED -- the presses went to " .. table.concat(targets, " and "))
		elseif spoke then
			fail(scenario, "SKIPPED -- a press with no token carried a /" .. command .. " line")
		elseif hintLines() ~= want then
			fail(scenario, ("said the nameplate line %d times, not %d: %s"):format(hintLines(), want,
				table.concat(Mock.printed or {}, " / ")))
		end
		ns.Prompt:ExitTest()
	end
	restoreUnits()
	restorePlates()
end
Mock.reset()

for _, case in ipairs({ { "SAY", true }, { "PARTY", false }, { "RAID", false } }) do
	local channel, want = case[1], case[2]
	local scenario = "selftest-fix: What I say's nameplate note shows only where a line could go (" .. channel .. ")"
	local restorePlates = platesOff()
	local ns = session(scenario)
	if ns then
		ns.db.profile.speech.enabled = true
		ns.db.profile.speech.channel = channel
		ns.OpenOptions("click")
		local UI = ns.WindowUI
		local note, button = UI.RowShown("click.platesNote"), UI.RowShown("click.showPlates")
		if note ~= want or button ~= want then
			fail(scenario, ("the note is %s and the button %s, where both should be %s")
				:format(note and "shown" or "hidden", button and "shown" or "hidden", want and "shown" or "hidden"))
		end
		ns.CloseOptions()
	end
	restorePlates()
end
Mock.reset()
