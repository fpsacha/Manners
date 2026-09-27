-- Prompt.lua fixes from the fifth bug hunt: what a press on a held or fused
-- entry claims about range and the hand-back, a pull landing on the hold or the
-- fuse, the bookkeeping after switching off and on inside one fight, a font the
-- client cannot load, the colour-blind palette's colour for askers, the reason
-- carried on a press, and the rotation pointers kept bounded.
--
-- Every scenario name starts with "prompt5:" so the mutations in
-- tests/mutations/hunt5-prompt.py can name the one that has to catch them.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive
local strangers, freshPrompt, pressButton = H.strangers, H.freshPrompt, H.pressButton
local owe, knowShout, inQueue = H.owe, H.knowShout, H.inQueue

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- Runs one scenario body, and names a throw as that scenario's failure.
local function run(scenario, body)
	local ok, err = pcall(body)
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function macroOf(ns)
	return tostring(ns.Prompt:GetButton():GetAttribute("macrotext1") or "")
end

local function oneLine(text)
	return (tostring(text or "nil"):gsub("\n", " / "))
end

-- ------------------------------------------------------------------ prompt5 1
-- A warrior's shout pressed for somebody the latest scan measured out of
-- earshot. The hold (with somebody else in the queue) and the fuse (with nobody)
-- both keep the entry the previous scan built, and its range reading with it;
-- a press there used to count the shout as reaching her and clear the debt.
for _, case in ipairs({ { label = "held", withBert = true }, { label = "fused", withBert = false } }) do
	Mock.reset()
	Mock.class = "WARRIOR"
	Mock.groupSize = case.withBert and 3 or 2
	local seen = { party1 = { "Anna", "Aim" } }
	if case.withBert then seen.party2 = { "Bert", "Beside" } end
	local restoreUnits = strangers(seen)
	Mock.yards = { party1 = 5, party2 = 5 }
	local realKnown, realPlayer = IsSpellKnown, IsPlayerSpell
	local scenario = "prompt5: a shout pressed after she walked out of earshot keeps the debt ("
		.. case.label .. ")"
	run(scenario, function()
		local ns = load(scenario)
		if not ns then return end
		knowShout(ns)
		local ranks = ns.FindBuff("WARRIOR", "battleshout").ranks
		Mock.rangeless = {}
		for _, id in ipairs(ranks) do Mock.rangeless[id] = true end
		drive(scenario, ns)
		Mock.advance(60)
		wipe(ns.owed)
		wipe(ns.tried)
		-- The lifecycle's own press, which would otherwise be swept as reaching
		-- nobody and block whoever it was aimed at.
		ns.pendingClick = nil
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.db.profile.verbose = true

		owe(ns, "Anna Aim")
		ns.addon:Tick()
		local shown = ns.Prompt:Showing()
		if not (shown and shown.name == "Anna Aim" and shown.ranged == true) then
			fail(scenario, "SKIPPED -- Anna was not on the prompt measured inside the shout's reach: "
				.. tostring(shown and shown.name) .. ", ranged " .. tostring(shown and shown.ranged))
			return
		end
		Mock.advance(0.3)
		Mock.yards.party1 = 60
		ns.addon:Tick()
		if inQueue(ns)["Anna Aim"] then
			fail(scenario, "SKIPPED -- Anna sixty yards away was still offered the shout")
			return
		end
		if ns.Prompt:PanelName() ~= "Anna Aim" then
			fail(scenario, "SKIPPED -- the panel let Anna go at once: " .. tostring(ns.Prompt:PanelName()))
			return
		end
		Mock.advance(0.2)
		Mock.printed = {}
		pressButton(ns)
		if not (ns.pendingClick and ns.pendingClick.name == "Anna Aim") then
			fail(scenario, "SKIPPED -- the press filed nothing for Anna")
			return
		end
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, "Cast-Shout", ranks[1])
		local said = table.concat(Mock.printed, "\n")
		if not ns.owed["Anna Aim"] then
			fail(scenario, "a shout counted as repaying Anna after the last scan measured her out"
				.. " of earshot: " .. said)
		end
		if said:find("counted as repaid", 1, true) then
			fail(scenario, "chat said Anna was repaid by a shout she was too far away to hear: " .. said)
		end
		noErrors(scenario, ns)
	end)
	IsSpellKnown, IsPlayerSpell = realKnown, realPlayer
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ prompt5 2
-- Your target offered through the target token, then your target changes. The
-- hold (or the fuse) keeps her entry, whose unit still says "target", so a press
-- used to run /target on her with no hand-back and leave you on her instead of
-- the mob you had just picked. While she is still your target there is nothing
-- to hand back.
for _, case in ipairs({
	{ label = "held", withBert = true, retarget = true },
	{ label = "fused", withBert = false, retarget = true },
	{ label = "still targeted", withBert = true, retarget = false },
}) do
	Mock.reset()
	local seen = { target = { "Anna", "Aim" } }
	if case.withBert then seen.nameplate1 = { "Bert", "Beside" } end
	local restoreUnits = strangers(seen)
	local scenario = "prompt5: a press after your target changed hands it back (" .. case.label .. ")"
	run(scenario, function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		ns.db.profile.filters.restoreTarget = true
		ns.Prompt:InvalidateMacro()
		ns.addon:Tick()
		local before = macroOf(ns)
		if not before:find("Anna Aim", 1, true) or before:find("/targetlasttarget", 1, true) then
			fail(scenario, "SKIPPED -- Anna was not armed as your target without a hand-back: "
				.. oneLine(before))
			return
		end
		Mock.advance(0.3)
		if case.retarget then
			seen.target = nil
			ns.addon:Tick()
			if ns.Prompt:PanelName() ~= "Anna Aim" then
				fail(scenario, "SKIPPED -- the panel let Anna go at once: "
					.. tostring(ns.Prompt:PanelName()))
				return
			end
		end
		Mock.advance(0.2)
		local ran = tostring(pressButton(ns) or "")
		if not ran:find("Anna Aim", 1, true) then
			fail(scenario, "SKIPPED -- the press did not cast at Anna: " .. oneLine(ran))
		elseif case.retarget and not ran:find("/targetlasttarget", 1, true) then
			fail(scenario, "a press on Anna after your target moved on did not hand it back: "
				.. oneLine(ran))
		elseif not case.retarget and ran:find("/targetlasttarget", 1, true) then
			fail(scenario, "a press on your own target handed the target away from her: " .. oneLine(ran))
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ prompt5 3
-- A pull inside the empty-queue fuse: the fuse used to keep the out-of-fight
-- macro, aimed at somebody the queue had dropped and without the fight's
-- hand-back, for every press of the fight.
Mock.reset()
do
	local seen = { target = { "Anna", "Aim" } }
	local restoreUnits = strangers(seen)
	local scenario = "prompt5: a pull inside the fuse does not freeze the dropped person's macro"
	run(scenario, function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		ns.db.profile.filters.restoreTarget = true
		ns.Prompt:InvalidateMacro()
		ns.addon:Tick()
		if not macroOf(ns):find("Anna Aim", 1, true) then
			fail(scenario, "SKIPPED -- Anna was not armed: " .. oneLine(macroOf(ns)))
			return
		end
		Mock.advance(0.3)
		seen.target = nil
		ns.addon:Tick()
		if not ns.Prompt:GetButton():IsShown() or not macroOf(ns):find("Anna Aim", 1, true) then
			fail(scenario, "SKIPPED -- no fuse was burning over Anna")
			return
		end
		Mock.advance(0.2)
		ns.addon:PLAYER_REGEN_DISABLED()
		Mock.inCombat = true
		Mock.runTimers(0.1)
		local frozen = ns.Prompt:GetButton():GetAttribute("macrotext1")
		if frozen and tostring(frozen):find("Anna Aim", 1, true) then
			fail(scenario, "the fight froze the macro at Anna, whom the queue had already dropped: "
				.. oneLine(frozen))
		end
		Mock.inCombat = false
		ns.addon:PLAYER_REGEN_ENABLED()
		noErrors(scenario, ns)
	end)
	Mock.inCombat = false
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ prompt5 4
-- The same inside the hold: the fight froze the held person's macro over
-- somebody actually in the queue.
Mock.reset()
do
	local seen = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bert", "Beside" } }
	local restoreUnits = strangers(seen)
	local scenario = "prompt5: a pull inside the hold arms whoever the queue holds"
	run(scenario, function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		ns.addon:Tick()
		if ns.Prompt:PanelName() ~= "Anna Aim" then
			fail(scenario, "SKIPPED -- the panel named " .. tostring(ns.Prompt:PanelName()) .. " to start with")
			return
		end
		Mock.advance(0.3)
		seen.nameplate1 = nil
		ns.addon:Tick()
		if ns.Prompt:PanelName() ~= "Anna Aim" or inQueue(ns)["Anna Aim"] or not inQueue(ns)["Bert Beside"] then
			fail(scenario, "SKIPPED -- Anna was not held over Bert")
			return
		end
		Mock.advance(0.2)
		ns.addon:PLAYER_REGEN_DISABLED()
		Mock.inCombat = true
		Mock.runTimers(0.1)
		local frozen = macroOf(ns)
		if not frozen:find("Bert Beside", 1, true) then
			fail(scenario, "the fight froze a macro that is not Bert's, though only he was in the"
				.. " queue: " .. oneLine(frozen))
		end
		Mock.inCombat = false
		ns.addon:PLAYER_REGEN_ENABLED()
		noErrors(scenario, ns)
	end)
	Mock.inCombat = false
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ prompt5 5
-- Switched off and on (or unlocked and locked) inside one fight: the macro the
-- fight froze still casts at Anna, and the press has to be filed against her.
for _, case in ipairs({ { "off", "on" }, { "unlock", "lock" } }) do
	Mock.reset()
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
	local scenario = "prompt5: /manners " .. case[1] .. " then " .. case[2]
		.. " in a fight keeps the press filed"
	run(scenario, function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		owe(ns, "Anna Aim")
		ns.addon:Tick()
		if not macroOf(ns):find("Anna Aim", 1, true) then
			fail(scenario, "SKIPPED -- Anna was not armed: " .. oneLine(macroOf(ns)))
			return
		end
		ns.addon:PLAYER_REGEN_DISABLED()
		Mock.inCombat = true
		Mock.runTimers(0.1)
		-- A scan between the two, as there is at 2.5 a second.
		ns.addon:HandleSlash(case[1])
		ns.addon:Tick()
		ns.addon:HandleSlash(case[2])
		ns.addon:Tick()
		Mock.advance(2)
		if not macroOf(ns):find("Anna Aim", 1, true) then
			fail(scenario, "SKIPPED -- the fight's macro was not Anna's any more: " .. oneLine(macroOf(ns)))
			return
		end
		local showing = ns.Prompt:Showing()
		if not (showing and showing.name == "Anna Aim") then
			fail(scenario, "the prompt says it is showing " .. tostring(showing and showing.name)
				.. " while its macro casts at Anna")
		end
		ns.pendingClick = nil
		pressButton(ns)
		if not (ns.pendingClick and ns.pendingClick.name == "Anna Aim") then
			fail(scenario, "a press that cast at Anna was filed against "
				.. tostring(ns.pendingClick and ns.pendingClick.name))
		else
			ns.addon:UNIT_SPELLCAST_SENT(nil, "player", "Anna", "Cast-Fight", 1459)
			if ns.owed["Anna Aim"] then
				fail(scenario, "Anna is still owed after the fight's macro buffed her")
			end
		end
		Mock.inCombat = false
		ns.addon:PLAYER_REGEN_ENABLED()
		noErrors(scenario, ns)
	end)
	Mock.inCombat = false
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ prompt5 6
-- A font a media pack registered but the client cannot load. The strings were
-- left with no font, SetText threw in every repaint, and the prompt never came
-- up while its hidden button still cast.
Mock.reset()
do
	local BAD = "Interface\\Bad.ttf"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
	local scenario = "prompt5: a font the client cannot load falls back rather than hiding the prompt"
	run(scenario, function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		Mock.badFonts = { [BAD] = true }
		LibStub("LibSharedMedia-3.0"):Register("font", "Broken", BAD)
		ns.db.profile.prompt.font = "Broken"
		ns.Guard("style", ns.Prompt.ApplyStyle, ns.Prompt)
		owe(ns, "Anna Aim")
		ns.addon:Tick()
		ns.addon:Tick()
		local regions = ns.Prompt:Regions()
		if not ns.Prompt:GetButton():IsShown() then
			fail(scenario, "the prompt stayed hidden with a font the client could not load")
		end
		local text = regions.name and regions.name:GetText()
		if not (text and tostring(text):find("Anna", 1, true)) then
			fail(scenario, "the name line was not written: " .. tostring(text))
		end
		if ns.db.profile.prompt.font ~= "Broken" then
			fail(scenario, "the saved font was changed to " .. tostring(ns.db.profile.prompt.font))
		end
		noErrors(scenario, ns)
	end)
	Mock.badFonts = nil
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ prompt5 7
-- The colour-blind palette gives askers a colour of their own rather than the
-- passer-by one.
Mock.reset()
do
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
	local scenario = "prompt5: the colour-blind palette has its own colour for askers"
	run(scenario, function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		ns.db.profile.prompt.accentByReason = true
		ns.db.profile.prompt.reasonPalette = "colourblind"
		local ar, ag, ab = ns.Prompt:AccentColor("asked")
		local nr, ng, nb = ns.Prompt:AccentColor("nearby")
		if math.abs(ar - nr) + math.abs(ag - ng) + math.abs(ab - nb) < 0.05 then
			fail(scenario, ("an asker is painted the passer-by colour (%.2f %.2f %.2f)"):format(ar, ag, ab))
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ prompt5 8
-- The press carries why the person was offered, so the ledger can tell a buff
-- somebody asked for from one given unprompted.
for _, case in ipairs({ { label = "asked", want = "asked" }, { label = "group", want = "group" } }) do
	Mock.reset()
	local restoreUnits
	if case.label == "group" then
		Mock.groupSize = 2
		restoreUnits = strangers({ party1 = { "Anna", "Aim" } })
	else
		restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
	end
	local scenario = "prompt5: a press carries the reason it was offered (" .. case.label .. ")"
	run(scenario, function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		local db = ns.db.profile
		if case.label == "asked" then
			db.sources.asked = true
			db.sources.strangers = false
			db.sources.group = false
			ns.addon.CHAT_MSG_SAY(ns.addon, "CHAT_MSG_SAY", "int pls", "Anna Aim", "Common", "", "",
				"", 0, 0, "", 0, 1, "Player-1-nameplate1")
		end
		ns.addon:Tick()
		local shown = ns.Prompt:Showing()
		if not (shown and shown.name == "Anna Aim" and shown.reason == case.want) then
			fail(scenario, "SKIPPED -- Anna was not offered as " .. case.want .. ": "
				.. tostring(shown and shown.reason))
			return
		end
		Mock.advance(0.3)
		ns.pendingClick = nil
		pressButton(ns)
		if not ns.pendingClick then
			fail(scenario, "SKIPPED -- the press filed nothing")
		elseif ns.pendingClick.reason ~= case.want then
			fail(scenario, "the press was filed with reason " .. tostring(ns.pendingClick.reason)
				.. ", not " .. case.want)
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ prompt5 9
-- The rotation pointers stay bounded over a long session of presses, and a
-- second press on the same person still reads what the first gave.
Mock.reset()
do
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
	local scenario = "prompt5: the rotation pointers stay bounded"
	run(scenario, function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		ns.db.profile.verbose = false
		local buff = ns.FindBuff("MAGE", "intellect")
		if not (buff and ns.RotatesBuffs()) then
			fail(scenario, "SKIPPED -- the mage's buffs do not rotate")
			return
		end
		local button = ns.Prompt:GetButton()
		local function press(name)
			Mock.advance(0.3)
			ns.pendingClick = nil
			ns.Prompt:ApplyTarget({ name = name, short = name, targetName = name, buff = buff,
				reason = "nearby", priority = 3, unit = "nameplate1" })
			button.scripts.PostClick(button, "LeftButton", true)
		end
		press("Repeat Person")
		press("Repeat Person")
		if not (ns.pendingClick and ns.pendingClick.gave == "intellect") then
			fail(scenario, "a second press on the same person did not read what the first gave: "
				.. tostring(ns.pendingClick and ns.pendingClick.gave))
		end
		local most = 0
		for i = 1, 1000 do
			press("Person" .. i)
			local n = 0
			for _ in pairs(ns.lastGave) do n = n + 1 end
			if n > most then most = n end
		end
		if most > 401 then
			fail(scenario, ("the rotation pointers grew to %d names over a thousand presses"):format(most))
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()
