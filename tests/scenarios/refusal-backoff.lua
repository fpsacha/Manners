-- Backing off from somebody the game keeps refusing (beta.8, a level 11 mage in
-- Undercity: "keep getting this prompt even if i cant cast"). Every press on a
-- passer-by was refused after it was sent, and a refusal blocked them for two
-- seconds, so they came straight back, for good. Refusals in a row now back
-- off further each time, gentler for somebody who buffed you, say so once in
-- chat, and are forgotten when a cast lands, when the player targets them, and
-- at a /reload.
--
-- Every scenario name starts with "refusal-backoff:" so the mutations in
-- tests/mutations/refusal-backoff.py can name the one that has to catch them.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

local EJP = "Ejp Ejp"

local function guarded(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- Lines in chat saying the game keeps refusing somebody.
local function told()
	local out = {}
	for _, line in ipairs(Mock.printed) do
		if line:find("keeps refusing", 1, true) then out[#out + 1] = line end
	end
	return out
end

-- A session with Ejp on a nameplate, chat lines off: the line about a person
-- backed off is said whatever that setting is.
local function session(scenario)
	Mock.reset()
	local restore = H.strangers({ nameplate1 = { "Ejp", "Ejp" } })
	local ns = load(scenario)
	if not ns then
		restore()
		return nil
	end
	H.freshPrompt(ns, scenario)
	ns.db.profile.verbose = false
	-- A first login parks the welcome and its preview on the clock; run by the
	-- timers below, the preview would disarm every press after it.
	Mock.timers = {}
	return ns, restore
end

local function entryFor(ns, reason)
	return { name = EJP, short = EJP, targetName = EJP, unit = "nameplate1",
		buff = ns.FindBuff("MAGE", "intellect"), reason = reason or "nearby", ranged = true }
end

local guids = 0

-- One press the client sends and the server refuses, as Ejp's were: the cast
-- goes out, settles, and UNIT_SPELLCAST_FAILED names it a moment later.
-- `err` is an error line arriving with the refusal, "before" or "after" it.
local function refusedPress(ns, reason, err, order)
	guids = guids + 1
	local guid = "Cast-R" .. guids
	local button = ns.Prompt:GetButton()
	Mock.advance(1)
	ns.pendingClick = nil
	ns.Prompt:ApplyTarget(entryFor(ns, reason))
	local post = button.scripts.PostClick
	if post then pcall(post, button, "LeftButton", true) end
	if not ns.pendingClick then return false end
	ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, guid, 1459)
	Mock.advance(0.1)
	if err and order == "before" then ns.addon:UI_ERROR_MESSAGE(nil, 0, err) end
	ns.addon:UNIT_SPELLCAST_FAILED(nil, "player", guid, 1459)
	if err and order == "after" then ns.addon:UI_ERROR_MESSAGE(nil, 0, err) end
	Mock.runTimers(0.5)
	return true
end

-- A press whose cast goes out and is never refused, left to land.
local function landedPress(ns, reason)
	guids = guids + 1
	local button = ns.Prompt:GetButton()
	Mock.advance(1)
	ns.pendingClick = nil
	ns.Prompt:ApplyTarget(entryFor(ns, reason))
	local post = button.scripts.PostClick
	if post then pcall(post, button, "LeftButton", true) end
	if not ns.pendingClick then return false end
	ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, "Cast-L" .. guids, 1459)
	Mock.advance(2.5)
	ns.addon:Tick()
	return true
end

-- Whether Ejp is kept off the prompt `seconds` from now.
local function blockedIn(ns, seconds)
	return ns.IsBlocked(EJP, nil, GetTime() + seconds)
end

-- How long the block the last refusal wrote lasts, to the nearest step.
local function blockLength(ns, steps)
	local found
	for _, step in ipairs(steps) do
		if blockedIn(ns, step - 0.7) and not blockedIn(ns, step + 0.3) then found = step end
	end
	return found
end

-- ------------------------------------------------------------ backoff-1
-- Three refusals in a row: two seconds, half a minute, five minutes, and one
-- line in chat on the third. A fourth keeps the five minutes and says nothing
-- new.
do
	local scenario = "refusal-backoff: refusals in a row back off further each time"
	local ns, restore = session(scenario)
	if ns then
		local STEPS = { 2, 30, 300, 300 }
		for i, want in ipairs(STEPS) do
			if not refusedPress(ns) then
				fail(scenario, "SKIPPED -- press " .. i .. " parked nothing")
				break
			end
			local got = blockLength(ns, { 2, 20, 30, 60, 300 })
			if got ~= want then
				fail(scenario, ("refusal %d blocked Ejp for %s, not %d seconds"):format(
					i, tostring(got or "some other length"), want))
			end
			local lines = told()
			local wantLines = i >= 3 and 1 or 0
			if #lines ~= wantLines then
				fail(scenario, ("after refusal %d chat said it %d times, not %d: %s"):format(
					i, #lines, wantLines, table.concat(lines, " | ")))
			end
			-- Past the block, so the next press is the next refusal in a row.
			Mock.advance(want + 1)
			ns.addon:Tick()
		end
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------ backoff-2
-- The game's own reason goes in the line, whether it arrived just before the
-- refusal or just after it.
for _, order in ipairs({ "before", "after" }) do
	local scenario = "refusal-backoff: the line gives the game's reason (" .. order .. ")"
	local ns, restore = session(scenario)
	if ns then
		for i = 1, 3 do
			if not refusedPress(ns, nil, "Invalid target.", order) then
				fail(scenario, "SKIPPED -- press " .. i .. " parked nothing")
				break
			end
			Mock.advance(301)
		end
		local lines = told()
		if #lines ~= 1 then
			fail(scenario, ("chat said it %d times, not once: %s"):format(#lines, table.concat(lines, " | ")))
		elseif not lines[1]:find("Invalid target", 1, true) then
			fail(scenario, "the line leaves out the game's reason: " .. lines[1])
		elseif not lines[1]:find(EJP, 1, true) then
			fail(scenario, "the line does not say who: " .. lines[1])
		end
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------ backoff-3
-- A cast on them that lands ends the run: the next refusal is a first one.
do
	local scenario = "refusal-backoff: a cast that lands starts the count again"
	local ns, restore = session(scenario)
	if ns then
		refusedPress(ns)
		Mock.advance(3)
		refusedPress(ns)
		Mock.advance(31)
		if not landedPress(ns) then
			fail(scenario, "SKIPPED -- the landing press parked nothing")
		else
			Mock.advance(13)
			ns.addon:Tick()
			if not refusedPress(ns) then
				fail(scenario, "SKIPPED -- the press after it parked nothing")
			else
				local got = blockLength(ns, { 2, 20, 30, 60, 300 })
				if got ~= 2 then
					fail(scenario, ("the first refusal after a cast landed blocked Ejp for %s seconds, not 2")
						:format(tostring(got or "some other length")))
				end
			end
		end
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------ backoff-4
-- Somebody who buffed you: two, twenty, sixty seconds, and the favour stays
-- owed through all of it.
do
	local scenario = "refusal-backoff: somebody owed backs off gently and stays owed"
	local ns, restore = session(scenario)
	if ns then
		H.owe(ns, EJP)
		for i, want in ipairs({ 2, 20, 60 }) do
			if not refusedPress(ns, "owed") then
				fail(scenario, "SKIPPED -- press " .. i .. " parked nothing")
				break
			end
			local got = blockLength(ns, { 2, 20, 30, 60, 300 })
			if got ~= want then
				fail(scenario, ("refusal %d blocked the owed Ejp for %s, not %d seconds"):format(
					i, tostring(got or "some other length"), want))
			end
			if not ns.owed[EJP] then
				fail(scenario, "refusal " .. i .. " let the favour go")
				break
			end
			Mock.advance(want + 0.5)
		end
		if #told() ~= 1 then
			fail(scenario, "the third refusal of somebody owed was not said once in chat")
		end
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------ backoff-5
-- The memory is bounded: a city full of people refused once each is capped,
-- and people not refused again for ten minutes are swept. And none of it is
-- saved: a /reload starts fresh.
do
	local scenario = "refusal-backoff: the memory is swept and capped"
	local ns, restore = session(scenario)
	if ns then
		for i = 1, 260 do
			ns.NoteRefusal("Passer" .. i .. " By", "Invalid target.")
			Mock.advance(0.01)
		end
		local held = 0
		for _ in pairs(ns.refusals) do held = held + 1 end
		if held > 200 then
			fail(scenario, held .. " people held after 260 refusals -- nothing caps it")
		end
		if not ns.refusals["Passer260 By"] then
			fail(scenario, "the newest refusal was the one dropped to make room")
		end
		Mock.advance(700)
		ns.addon:Tick()
		if next(ns.refusals) ~= nil then
			fail(scenario, "people refused ten minutes ago and not since are still held")
		end
		guarded(scenario, ns)
		restore()
	end
end

do
	local scenario = "refusal-backoff: a reload starts fresh"
	local ns, restore = session(scenario)
	if ns then
		for _ = 1, 3 do
			refusedPress(ns)
			Mock.advance(31)
		end
		if not blockedIn(ns, 0) then
			fail(scenario, "SKIPPED -- three refusals did not back Ejp off")
		else
			local shutdown = Mock.dbCallbacks and Mock.dbCallbacks["OnDatabaseShutdown"]
			if shutdown then pcall(function() shutdown.target[shutdown.method](shutdown.target) end) end
			local b = load(scenario)
			if b then
				drive(scenario, b)
				if b.IsBlocked(EJP, nil, GetTime()) then
					fail(scenario, "the back-off came back after a reload")
				end
			end
		end
		restore()
	end
end

-- ------------------------------------------------------------ backoff-6
-- Targeting them on purpose tries them again; the macro's own /target inside a
-- press is not that. And /manners debug says who is backed off and for how
-- long.
do
	local scenario = "refusal-backoff: targeting them lifts it, the press's own targeting does not"
	local ns, restore = session(scenario)
	if ns then
		for _ = 1, 3 do
			refusedPress(ns)
			Mock.advance(31)
		end
		if not blockedIn(ns, 60) then
			fail(scenario, "SKIPPED -- three refusals did not back Ejp off")
		else
			Mock.printed = {}
			ns.addon:HandleSlash("debug")
			local said = table.concat(Mock.printed, "\n")
			if not (said:find("backed off for", 1, true) and said:find(EJP, 1, true)) then
				fail(scenario, "/manners debug does not say Ejp is backed off: " .. said)
			end
			Mock.unitNames.target = { "Ejp", "Ejp" }
			ns.pressAt = GetTime()
			ns.addon:PLAYER_TARGET_CHANGED()
			if not blockedIn(ns, 60) then
				fail(scenario, "the macro's own /target inside a press lifted the back-off")
			end
			Mock.advance(2)
			ns.addon:PLAYER_TARGET_CHANGED()
			if blockedIn(ns, 0) then
				fail(scenario, "targeting Ejp on purpose left the back-off standing")
			end
		end
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------ backoff-7
-- An error about the caster (out of mana) holds the spoken line the press
-- said but says nothing about the person: no back-off past the old two
-- seconds. (A press that said no line holds nothing for it: every press asks
-- the mana again before it says one -- speech-range-7.)
do
	local scenario = "refusal-backoff: out of mana backs nobody off"
	local ns, restore = session(scenario)
	if ns then
		local speech = ns.db.profile.speech
		speech.enabled, speech.onlyWhenReturning = true, false
		speech.channel, speech.phrases = "SAY", "Thanks, {name}."
		local saved = rawget(_G, "ERR_OUT_OF_MANA")
		rawset(_G, "ERR_OUT_OF_MANA", "Not enough mana")
		for i = 1, 3 do
			ns.pendingClick = nil
			ns.Prompt:ApplyTarget(entryFor(ns))
			local button = ns.Prompt:GetButton()
			local armed = button:GetAttribute("macrotext1")
			if i == 1 and not (armed and armed:find("\n/say ", 1, true)) then
				fail(scenario, "SKIPPED -- the first press carried no line: " .. tostring(armed))
				break
			end
			Mock.advance(3)
			pcall(button.scripts.PostClick, button, "LeftButton", true)
			if not ns.pendingClick then
				fail(scenario, "SKIPPED -- press " .. i .. " parked nothing")
				break
			end
			ns.addon:UI_ERROR_MESSAGE(nil, 0, "Not enough mana.")
		end
		if blockedIn(ns, 2.5) then
			fail(scenario, "running out of mana backed Ejp off")
		end
		if #told() > 0 then
			fail(scenario, "running out of mana was blamed on Ejp: " .. told()[1])
		end
		if not ns.SpeechHeld(EJP) then
			fail(scenario, "the spoken line is not held after a press that cast nothing")
		end
		rawset(_G, "ERR_OUT_OF_MANA", saved)
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------ backoff-8
-- In a fight: the frozen macro still casts, the refusals still count, and
-- nothing throws -- the line in chat, the target change and the sweep included.
do
	local scenario = "refusal-backoff: in a fight nothing throws"
	local ns, restore = session(scenario)
	if ns then
		ns.addon:PLAYER_REGEN_DISABLED()
		Mock.inCombat = true
		local ok, err = pcall(function()
			for _ = 1, 3 do
				refusedPress(ns)
				Mock.advance(31)
				ns.addon:Tick()
			end
			Mock.unitNames.target = { "Ejp", "Ejp" }
			ns.addon:PLAYER_TARGET_CHANGED()
			Mock.advance(700)
			ns.addon:Tick()
		end)
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
		if #told() ~= 1 then
			fail(scenario, "the third refusal in a fight was not said once in chat")
		end
		Mock.inCombat = false
		ns.addon:PLAYER_REGEN_ENABLED()
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------ backoff-9
-- The spoken line outlasts every back-off. Somebody the game keeps refusing
-- comes back when a back-off runs out, and the press then would thank them
-- over yet another refused cast (a hold of its own thirty seconds ran out
-- with the thirty-second step, and long before the longer ones).
local function speaking(ns)
	local speech = ns.db.profile.speech
	speech.enabled = true
	speech.onlyWhenReturning = false
	speech.channel = "SAY"
	speech.phrases = "Thanks, {name}."
	ns.Prompt:InvalidateMacro()
end

local function armedSpeaks(ns, reason)
	ns.Prompt:ApplyTarget(entryFor(ns, reason))
	local text = ns.Prompt:GetButton():GetAttribute("macrotext1")
	return text ~= nil and text:find("\n/say ", 1, true) ~= nil, text
end

for _, reason in ipairs({ "nearby", "owed" }) do
	local scenario = "refusal-backoff: the spoken line stays held past the back-off (" .. reason .. ")"
	local ns, restore = session(scenario)
	if ns then
		speaking(ns)
		if reason == "owed" then H.owe(ns, EJP) end
		local steps = reason == "owed" and { 2, 20, 60 } or { 2, 30, 300 }
		if not armedSpeaks(ns, reason) then
			fail(scenario, "SKIPPED -- the line was not armed to begin with")
		else
			for i, step in ipairs(steps) do
				if not refusedPress(ns, reason) then
					fail(scenario, "SKIPPED -- press " .. i .. " parked nothing")
					break
				end
				Mock.advance(step + 0.5)
				ns.addon:Tick()
				local spoke, text = armedSpeaks(ns, reason)
				if blockedIn(ns, 0) then
					fail(scenario, ("SKIPPED -- still backed off after refusal %d"):format(i))
					break
				elseif spoke then
					fail(scenario, ("back from refusal %d's back-off, the line is armed again: %s")
						:format(i, (text:gsub("\n", " / "))))
					break
				end
			end
		end
		guarded(scenario, ns)
		restore()
	end
end

-- A press that went to somebody else only holds the line (no refusal to back
-- off from), and that shorter note must not cut a hold a back-off wrote.
do
	local scenario = "refusal-backoff: a quiet note never shortens the hold"
	local ns, restore = session(scenario)
	if ns then
		speaking(ns)
		local ok = refusedPress(ns) and refusedPress(ns)
		if ok then
			-- Refusal two: backed off for 30 s, the line held for 60. Then a
			-- quiet note from a press whose line is not known (spoke unset). A
			-- press during the hold now carries no line and leaves no note at
			-- all (1.6.5), so the note is written straight to NoteRefusal.
			Mock.advance(1)
			local entry = entryFor(ns)
			ok = entry ~= nil and entry.name ~= nil
			if ok then ns.NoteRefusal(entry.name, nil, true) end
		end
		if not ok then
			fail(scenario, "SKIPPED -- a press parked nothing")
		else
			Mock.advance(35)
			ns.addon:Tick()
			-- The hold itself, not the armed macro: other rules (the line's own
			-- pacing to one person, 1.6.5) can keep the line out of the macro
			-- whatever the hold says, and would hide a hold cut short.
			if blockedIn(ns, 0) then
				fail(scenario, "SKIPPED -- still backed off")
			elseif not ns.SpeechHeld(entryFor(ns).name) then
				fail(scenario, "the press that went elsewhere cut the hold the back-off wrote")
			end
		end
		guarded(scenario, ns)
		restore()
	end
end
