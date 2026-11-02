-- A press of the Manners macro on an action bar (Clicks.lua, click macro;
-- Prompt/Press.lua, OnBarClick; Prompt/Macro.lua, barText).
--
-- The game will not run a macro from inside another one (Blizzard, WoWUIBugs
-- #552), so 1.10.4's "/click MannersPrompt LeftButton 1" cast nothing from a
-- bar on Classic Era while a click on the prompt itself cast. The macro now
-- carries the cast under a first line that clicks MannersBar, a plain button
-- that files the press, and nothing presses the prompt from a macro.
--
-- These hold Manners' own wiring to a model of the client, not the client:
-- tests/mockmacros.lua ("running macros") runs a bar's macro a line at a time,
-- a secure button through the client's own SecureActionButton_OnClick, and
-- each scenario says what the client is assumed to refuse (Mock.macroChain,
-- Mock.clickContext). Whether the game takes the new body is launch day's
-- (STATUS.md).
--
-- Every name starts with "barclick:" so a mutation in tests/mutations/
-- barclick.py can name exactly one.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe, clearClicks = H.strangers, H.freshPrompt, H.owe, H.clearClicks

local BAR_LINE = "/click MannersBar"
local OLD = "/click MannersPrompt LeftButton 1"
local GCD = 61304
local FLAVOURS = { "camelot", "vanilla", "tbc", "mists", "mainline" }
local ANNA = { "Anna", "Aim" }
local BOB = { "Bob", "Bright" }
-- The spoken line's channels (Speech.lua, CHANNEL_COMMANDS).
local CHANNELS = { say = true, yell = true, party = true, raid = true, emote = true, w = true }
local UPDATED = "macro was updated -- the one an older version made no longer pressed the prompt"
local WARNED = "still targets"

-- The globals a scenario replaces, put back whatever happens.
local TOUCHED = { "UnitGUID", "CreateMacro", "MacroFrame", "C_Spell", "IsUsableSpell" }

local function said() return table.concat(Mock.printed, "\n") end
local function flat(text) return (tostring(text):gsub("\n", " / ")) end
local function count(text, needle)
	local n, from = 0, 1
	while true do
		local at = text:find(needle, from, true)
		if not at then return n end
		n, from = n + 1, at + #needle
	end
end
local function macroIndex() return GetMacroIndexByName("Manners") end
local function bodyNow()
	local macro = Mock.macroList[macroIndex()]
	return macro and macro.body or nil
end
local function firstLine(text) return type(text) == "string" and text:match("^[^\n]*") or text end
local function lastLine(text) return type(text) == "string" and text:match("([^\n]*)$") or text end
local function armedText(ns) return ns.Prompt:GetButton():GetAttribute("macrotext1") end

-- The prompt's macro without its spoken line: what the bar macro carries.
local function quiet(ns)
	local text = armedText(ns)
	if not text then return nil end
	local out = {}
	for line in (text .. "\n"):gmatch("([^\n]*)\n") do
		local command = line:match("^/(%S+)")
		if not (command and CHANNELS[command:lower()]) then out[#out + 1] = line end
	end
	return table.concat(out, "\n")
end
local function armedBody(ns)
	local text = quiet(ns)
	return text and (BAR_LINE .. "\n" .. text) or BAR_LINE
end

-- Forever unless a scenario names the client: the fixtures are Forever's
-- (two-part names), whatever client the rest of a run is as.
local function with(scenario, body, opts)
	opts = opts or {}
	Mock.reset()
	Mock.setFlavour(opts.flavour or "camelot")
	if opts.class then Mock.class = opts.class end
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local people = {}
	for unit, n in pairs(opts.people or { nameplate1 = ANNA }) do people[unit] = { n[1], n[2] } end
	local restore = strangers(people)
	local ok, err = true, nil
	local ns = load(scenario)
	if ns then
		ok, err = pcall(function()
			freshPrompt(ns, scenario)
			Mock.secureActions = true
			Mock.eventSink = ns.addon
			body(ns, scenario)
			for _, e in ipairs(ns.errors or {}) do
				fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
			end
		end)
	end
	restore()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- The prompt armed at Anna, who is owed the mage's one buff.
local function armed(ns)
	owe(ns, "Anna Aim")
	ns.addon:Tick()
end

-- Put Manners on an action bar, dropped on `slot`.
local function onBar(ns, slot)
	ns.CreateClickMacro()
	return Mock.dropOnBar(slot)
end

-- Somebody else on a nameplate of their own.
local function arrives(ns, unit, name)
	Mock.unitNames[unit] = { name[1], name[2] }
	ns.nameplateUnits[unit] = true
end
local function leaves(ns, unit)
	Mock.unitNames[unit] = nil
	ns.nameplateUnits[unit] = nil
end

-- A clean start for the next press: the clock past the cooldown and the retry
-- wait, the parked press gone, `who` owed again, a scan.
local function again(ns, who)
	clearClicks(ns)
	for _, name in ipairs(type(who) == "table" and who or { who or "Anna Aim" }) do owe(ns, name) end
	ns.addon:Tick()
	Mock.runTimers(0)
end

-- Scans until the prompt is armed at `name` (or with nobody, for nil), the hold
-- and the fuse let go; whether it got there.
local function settleOn(ns, name)
	for _ = 1, 20 do
		local current = ns.Prompt.state.current
		if (name == nil and not ns.Prompt:GetButton():GetAttribute("type1"))
			or (name and current and current.name == name) then
			Mock.runTimers(0)
			return true
		end
		Mock.advance(1)
		ns.addon:Tick()
	end
	return false
end

-- The id UNIT_SPELLCAST_SENT names: whatever the bar's lines were written for.
local function spellIds(ns)
	return function()
		local entry = ns.Prompt.bar.current or ns.Prompt.state.current
		local info = entry and entry.buff and ns.BuffInfo(entry.buff)
		return info and info.topRank or 0
	end
end

-- What the client is assumed to do with a macro run from a macro, and with a
-- /click from a bar press.
local OLD_COMBOS = {
	{ chain = "refused", context = "none", how = { via = "mouse" }, why = "chain" },
	{ chain = "refused", context = "none", how = { via = "key", keyDown = true }, why = "chain" },
	{ chain = "refused", context = "none", how = { via = "key", keyDown = false }, why = "chain" },
	{ chain = "allowed", context = "inherit", how = { via = "mouse" }, why = "mouse" },
}
local NEW_COMBOS = {}
for _, c in ipairs(OLD_COMBOS) do NEW_COMBOS[#NEW_COMBOS + 1] = c end
NEW_COMBOS[#NEW_COMBOS + 1] = { chain = "allowed", context = "none", how = { via = "mouse" } }

local function combo(c)
	Mock.macroChain, Mock.clickContext = c.chain, c.context
	Mock.cvars.ActionButtonUseKeyDown = c.how.keyDown == false and "0" or "1"
end
local function label(c)
	return ("%s/%s/%s%s"):format(c.chain, c.context, c.how.via,
		c.how.via == "key" and (c.how.keyDown and " down" or " up") or "")
end

-- ------------------------------------------------------------------ 1
-- The old body, pressed from a bar, casts nothing however the client is
-- modelled; the macro Put Manners on an action bar makes now casts once, at
-- the person on the prompt, and is filed as theirs. On every client.
for _, flavour in ipairs(FLAVOURS) do
	with("barclick: the old body casts nothing from a bar, the new one casts once (" .. flavour .. ")", function(ns, scenario)
		armed(ns)
		local entry = ns.Prompt.state.current
		if not (entry and armedText(ns)) then fail(scenario, "SKIPPED -- the prompt is not armed") return end
		Mock.bar[1] = CreateMacro("Old", "INV_MISC_NOTE_03", OLD, false)
		for _, c in ipairs(OLD_COMBOS) do
			combo(c)
			Mock.macroLog = {}
			local casts = Mock.pressBar(1, c.how)
			if #casts ~= 0 then fail(scenario, ("the old body cast %d time(s) under %s"):format(#casts, label(c))) end
			local refused, quietClick = false, false
			for _, e in ipairs(Mock.macroLog) do
				if e.refused == "chain" then refused = true end
				if e.frame == "MannersPrompt" and e.action ~= "click" then quietClick = true end
			end
			if c.why == "chain" and not refused then
				fail(scenario, "the old body's press was not refused as a macro run from a macro under " .. label(c))
			elseif c.why == "mouse" and not quietClick then
				fail(scenario, "the old body's down click acted under " .. label(c))
			end
			again(ns)
		end
		if not onBar(ns, 2) then fail(scenario, "SKIPPED -- the macro could not be put on a bar") return end
		if firstLine(bodyNow()) ~= BAR_LINE then fail(scenario, "the macro made reads " .. flat(bodyNow())) end
		for _, c in ipairs(NEW_COMBOS) do
			combo(c)
			again(ns)
			entry = ns.Prompt.state.current
			Mock.macroLog = {}
			local casts = Mock.pressBar(2, c.how)
			if #casts ~= 1 then
				fail(scenario, ("the bar macro cast %d time(s) under %s: %s"):format(#casts, label(c), flat(bodyNow())))
			elseif not casts[1].target then
				fail(scenario, "the bar macro cast at nobody under " .. label(c))
			end
			for _, e in ipairs(Mock.macroLog) do
				if e.refused then fail(scenario, "the bar macro ran a macro from a macro under " .. label(c)) end
			end
			if not (entry and ns.pendingClick and ns.pendingClick.name == entry.name) then
				fail(scenario, ("the press under %s was filed as %s, not %s"):format(label(c),
					tostring(ns.pendingClick and ns.pendingClick.name), tostring(entry and entry.name)))
			end
		end
	end, { flavour = flavour })
end

-- ------------------------------------------------------------------ 2
-- The press is parked before its cast is sent, and the cast settles it: the
-- record is the bar press's, and the line /manners clicks prints says so. The
-- bar macro never says the line the prompt's own macro says.
for _, timing in ipairs({ "sync", "after" }) do
	with("barclick: a press of the slot is filed before its cast and settled by it (" .. timing .. ")", function(ns, scenario)
		ns.db.profile.speech.enabled = true
		ns.db.profile.debugClicks = true
		armed(ns)
		if not onBar(ns, 2) then fail(scenario, "SKIPPED -- no macro on the bar") return end
		local entry = ns.Prompt.state.current
		if not (armedText(ns) or ""):find("\n/say ", 1, true) then
			fail(scenario, "SKIPPED -- the prompt's macro says no line: " .. flat(armedText(ns)))
		end
		if (bodyNow() or ""):find("/say", 1, true) then fail(scenario, "the bar macro carries the line: " .. flat(bodyNow())) end
		Mock.castEvents = timing
		Mock.spellIdFor = spellIds(ns)
		local parked = nil
		local sent = ns.addon.UNIT_SPELLCAST_SENT
		ns.addon.UNIT_SPELLCAST_SENT = function(self, ...)
			if parked == nil then parked = ns.pendingClick and ns.pendingClick.name or false end
			return sent(self, ...)
		end
		Mock.printed = {}
		local ok, casts = pcall(Mock.pressBar, 2, { via = "mouse" })
		ns.addon.UNIT_SPELLCAST_SENT = sent
		if not ok then error(casts, 0) end
		if #casts ~= 1 then fail(scenario, ("%d casts from one press"):format(#casts)) return end
		if parked ~= entry.name then fail(scenario, "the press was not filed when its cast was sent: " .. tostring(parked)) end
		if ns.pendingClick then fail(scenario, "the cast did not settle the press") end
		if said():find("another press arrived first", 1, true) then fail(scenario, "the cast met a press of its own: " .. said()) end
		local outcome = ns.Prompt.state.outcomeKind
		if outcome ~= "cast" and outcome ~= "sent" then fail(scenario, "the panel says " .. tostring(outcome)) end
		if not said():find("via=bar macro=/target", 1, true) then fail(scenario, "the click line does not say the bar: " .. said()) end
		if #Mock.saidLog ~= 0 then fail(scenario, "the bar macro said: " .. tostring(Mock.saidLog[1].text)) end
		if not ns.LineRested(entry, GetTime()) then fail(scenario, "a line was counted as said to them") end
	end)
end

-- A druid in a form the spell cannot be cast from presses the slot: no line
-- goes out with the cast the game refuses.
with("barclick: the bar macro never speaks, whatever the press meets", function(ns, scenario)
	ns.db.profile.speech.enabled = true
	armed(ns)
	if not onBar(ns, 2) then fail(scenario, "SKIPPED -- no macro on the bar") return end
	if not (armedText(ns) or ""):find("\n/say ", 1, true) then
		fail(scenario, "SKIPPED -- the prompt's macro says no line: " .. flat(armedText(ns)))
	end
	-- The spell unusable for a reason that is not mana, as in a form.
	local spell = rawget(_G, "C_Spell") or C_Spell
	local api = {}
	for k, v in pairs(spell) do api[k] = v end
	api.IsSpellUsable = function() return false, false end
	rawset(_G, "C_Spell", api)
	rawset(_G, "IsUsableSpell", function() return false, false end)
	local casts = Mock.pressBar(2, { via = "key", keyDown = true })
	if #casts ~= 1 then fail(scenario, ("%d casts from one press"):format(#casts)) end
	if #Mock.saidLog ~= 0 then fail(scenario, "the bar macro said: " .. tostring(Mock.saidLog[1].text)) end
	if ns.pendingClick and ns.pendingClick.spoke then fail(scenario, "the press was filed as one that spoke") end
	local body = bodyNow() or ""
	if #body > 255 then fail(scenario, ("the macro is %d characters"):format(#body)) end
	if not (lastLine(body) == "/targetlasttarget" or lastLine(body) == "/cleartarget") then
		fail(scenario, "the macro does not end with the hand-back: " .. flat(body))
	end
end)

-- ------------------------------------------------------------------ 3
-- The macro holds what the prompt's button would cast, without the spoken
-- line, after every scan; somebody new is written in the same scan; with
-- nothing to cast it holds its first line alone.
with("barclick: the macro follows the prompt", function(ns, scenario)
	armed(ns)
	if not onBar(ns, 2) then fail(scenario, "SKIPPED -- no macro on the bar") return end
	local function holds(step, want)
		local now = bodyNow()
		if now ~= want then fail(scenario, ("%s: the macro holds %s, not %s"):format(step, flat(now), flat(want))) end
	end
	holds("armed at Anna", armedBody(ns))
	for _ = 1, 5 do
		Mock.advance(0.4)
		ns.addon:Tick()
		holds("a scan later", armedBody(ns))
	end
	-- Anna goes, Bob comes.
	wipe(ns.owed)
	leaves(ns, "nameplate1")
	arrives(ns, "nameplate2", BOB)
	owe(ns, "Bob Bright")
	if not settleOn(ns, "Bob Bright") then fail(scenario, "SKIPPED -- the prompt never moved to Bob") return end
	if not (bodyNow() or ""):find("/target Bob Bright", 1, true) then fail(scenario, "Bob armed, the macro holds " .. flat(bodyNow())) end
	holds("armed at Bob", armedBody(ns))
	-- Nobody to buff.
	wipe(ns.owed)
	leaves(ns, "nameplate2")
	if not settleOn(ns, nil) then fail(scenario, "SKIPPED -- the prompt never emptied") return end
	holds("nobody to buff", BAR_LINE)
	-- A press then says why, as a press on the empty prompt does.
	Mock.printed = {}
	Mock.pressBar(2)
	if not said():find("nobody to buff right now", 1, true) then fail(scenario, "a press with nobody to buff said: " .. said()) end
	-- Each way of having nothing to cast, from an armed prompt.
	local cases = {
		{ "snoozed", function() ns.addon:HandleSlash("snooze") end, function() ns.addon:HandleSlash("snooze off") end },
		{ "switched off", function() ns.addon:HandleSlash("off") end, function() ns.addon:HandleSlash("on") end },
		{ "unlocked", function() ns.db.profile.prompt.locked = false ns.Prompt:Refresh() end,
			function() ns.db.profile.prompt.locked = true end },
		-- With the options window open, where a preview stands in front of
		-- somebody real.
		{ "previewing", function()
			ns.OptionsOpen = function() return true end
			ns.addon:HandleSlash("test")
		end, function()
			ns.OptionsOpen = nil
			ns.Prompt:ExitTest()
		end },
		{ "running /manners try", function() ns.addon:HandleSlash("try /cast Arcane Intellect") ns.addon:Tick() end,
			function() ns.addon:HandleSlash("try") end },
	}
	arrives(ns, "nameplate1", ANNA)
	for _, case in ipairs(cases) do
		again(ns)
		if not settleOn(ns, "Anna Aim") then fail(scenario, "SKIPPED -- Anna never came back before " .. case[1]) return end
		holds("armed before " .. case[1], armedBody(ns))
		case[2]()
		Mock.runTimers(0)
		holds(case[1], BAR_LINE)
		case[3]()
	end
end)

-- ------------------------------------------------------------------ 4
-- In the last moments of a cooldown a /cast would be queued and go out after
-- the hand-back: the macro holds its first line alone then, and carries the
-- cast again when the cooldown ends, without waiting for a scan. A press
-- earlier in it is refused by the game and filed as nothing.
with("barclick: during the global cooldown the macro holds back at the end", function(ns, scenario)
	armed(ns)
	if not onBar(ns, 2) then fail(scenario, "SKIPPED -- no macro on the bar") return end
	local full = bodyNow()
	if full == BAR_LINE then fail(scenario, "SKIPPED -- the macro carries no cast") return end
	ns.db.profile.debugClicks = true
	-- A cast from another button starts the global cooldown.
	Mock.spellCooldowns = { [GCD] = { startTime = Mock.now, duration = 1.5, isActive = true } }
	ns.addon:SPELL_UPDATE_COOLDOWN()
	if bodyNow() ~= full then fail(scenario, "early in the cooldown the macro let go of the cast: " .. flat(bodyNow())) end
	-- Pressed early in it: the game refuses the cast, nothing is filed, the panel says when.
	Mock.gcdOnCast = 1.5
	Mock.printed = {}
	ns.pendingClick = nil
	local casts = Mock.pressBar(2)
	if #casts ~= 0 then fail(scenario, "a cast went out in the cooldown") end
	if ns.pendingClick then fail(scenario, "a press in the cooldown was filed") end
	if not said():find("held back", 1, true) then fail(scenario, "the click line does not say it was held back: " .. said()) end
	local sub = ns.Prompt.regions.subText:GetText() or ""
	if not sub:find("ready in", 1, true) then fail(scenario, "the panel does not say when it is ready: " .. sub) end
	Mock.runTimers(0)
	-- The last moments, inside the spell queue window.
	Mock.runTimers(1.2)
	if bodyNow() ~= BAR_LINE then fail(scenario, "in the cooldown's last moments the macro still carries " .. flat(bodyNow())) end
	Mock.printed = {}
	casts = Mock.pressBar(2)
	if #casts ~= 0 then fail(scenario, "a press in the last moments cast") end
	if ns.pendingClick then fail(scenario, "a press in the last moments was filed") end
	-- Over: the cast is back, with no scan.
	Mock.runTimers(0.5)
	if bodyNow() ~= full then fail(scenario, "after the cooldown the macro holds " .. flat(bodyNow())) end
end)

-- The spell's own cooldown, longer than the global one, ends the same way.
with("barclick: the spell's own cooldown holds the macro back at its end too", function(ns, scenario)
	armed(ns)
	if not onBar(ns, 2) then fail(scenario, "SKIPPED -- no macro on the bar") return end
	local full = bodyNow()
	local entry = ns.Prompt.state.current
	local spell = entry and ns.PressSpell(entry)
	if full == BAR_LINE or not spell then fail(scenario, "SKIPPED -- the macro carries no cast") return end
	-- No global cooldown, only the spell's own, five seconds.
	Mock.spellCooldowns = { [GCD] = { startTime = Mock.now - 10, duration = 1.5 },
		[spell] = { startTime = Mock.now, duration = 5 } }
	ns.addon:SPELL_UPDATE_COOLDOWN()
	if bodyNow() ~= full then fail(scenario, "early in the spell's cooldown the macro let go of the cast") end
	for _ = 1, 47 do Mock.runTimers(0.1) end
	if bodyNow() ~= BAR_LINE then fail(scenario, "at the end of the spell's own cooldown the macro still carries " .. flat(bodyNow())) end
	for _ = 1, 5 do Mock.runTimers(0.1) end
	if bodyNow() ~= full then fail(scenario, "after the spell's cooldown the macro holds " .. flat(bodyNow())) end
end)

-- Crafting: ten casts with a cast time, each with its cooldown events, cost
-- the macro two writes apiece at most (the hold in and out), not one per event.
with("barclick: a run of casts writes the macro twice a cast at most", function(ns, scenario)
	armed(ns)
	if not onBar(ns, 2) then fail(scenario, "SKIPPED -- no macro on the bar") return end
	local edits = Mock.editCalls
	for _ = 1, 10 do
		Mock.casting = { spellId = 6127, startsAt = Mock.now, endsAt = Mock.now + 3 }
		ns.addon:UNIT_SPELLCAST_START("UNIT_SPELLCAST_START", "player")
		for _ = 1, 3 do ns.addon:SPELL_UPDATE_COOLDOWN() end
		-- A tenth of a second at a time, as frames pass, events on the way.
		for step = 1, 32 do
			Mock.runTimers(0.1)
			if step % 8 == 0 then ns.addon:SPELL_UPDATE_COOLDOWN() end
			if step % 4 == 0 then ns.addon:Tick() end
		end
		Mock.casting = nil
		ns.addon:UNIT_SPELLCAST_SUCCEEDED("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 6127)
		ns.addon:Tick()
	end
	local writes = Mock.editCalls - edits
	if writes > 20 then fail(scenario, ("ten casts wrote the macro %d times"):format(writes)) end
	if writes == 0 then fail(scenario, "SKIPPED -- the casts never held the macro back") end
	if bodyNow() ~= armedBody(ns) then fail(scenario, "after the casts the macro holds " .. flat(bodyNow())) end
end)

-- ------------------------------------------------------------------ 5
-- The fight keeps what the pull wrote, as it keeps the button: nothing is
-- written in it, a press casts at the pull's person and is filed as theirs,
-- and once it ends the macro follows the prompt again.
with("barclick: in a fight the macro keeps what it held at the pull", function(ns, scenario)
	armed(ns)
	if not onBar(ns, 2) then fail(scenario, "SKIPPED -- no macro on the bar") return end
	arrives(ns, "nameplate2", BOB)
	-- Just before the lockdown, as the client sends it.
	ns.addon:PLAYER_REGEN_DISABLED()
	local fight = bodyNow() or ""
	if not fight:find("/target Anna Aim", 1, true) or lastLine(fight) ~= "/targetlasttarget" then
		fail(scenario, "the pull wrote " .. flat(fight))
	end
	Mock.inCombat = true
	Mock.runTimers(0)
	local edits = Mock.editCalls
	Mock.blockedCalls = {}
	wipe(ns.owed)
	owe(ns, "Bob Bright")
	Mock.advance(1)
	ns.addon:Tick()
	if Mock.editCalls ~= edits then fail(scenario, "the macro was asked to change in a fight") end
	if bodyNow() ~= fight then fail(scenario, "in the fight the macro holds " .. flat(bodyNow())) end
	ns.pendingClick = nil
	local casts = Mock.pressBar(2)
	if #casts ~= 1 or casts[1].target ~= "Anna Aim" then
		fail(scenario, "a press in the fight cast at " .. tostring(casts[1] and casts[1].target))
	end
	if not (ns.pendingClick and ns.pendingClick.name == "Anna Aim") then
		fail(scenario, "the press in the fight was filed as " .. tostring(ns.pendingClick and ns.pendingClick.name))
	end
	-- Early in a cooldown, in the fight: the lines go out, nothing is filed.
	ns.pendingClick = nil
	Mock.advance(1)
	Mock.spellCooldowns = { [GCD] = { startTime = Mock.now, duration = 1.5, isActive = true } }
	ns.db.profile.debugClicks = true
	Mock.printed = {}
	casts = Mock.pressBar(2)
	if #casts ~= 1 then fail(scenario, "the fight's lines did not run") end
	if ns.pendingClick then fail(scenario, "a press early in the cooldown was filed in a fight") end
	if not said():find("held back", 1, true) then fail(scenario, "nothing said it was held back: " .. said()) end
	-- Late in it, inside the spell queue window: the client queues the cast, and
	-- the press is filed.
	Mock.advance(1.3)
	casts = Mock.pressBar(2)
	if not (ns.pendingClick and ns.pendingClick.name == "Anna Aim") then
		fail(scenario, "a press the client queues at the end of the cooldown was not filed in a fight")
	end
	-- Switched off in the fight, a moment after that press: the button cannot
	-- be disarmed, nor the macro written (the client would refuse the call
	-- with an error).
	Mock.advance(0.1)
	edits = Mock.editCalls
	ns.addon:HandleSlash("off")
	ns.addon:Tick()
	if Mock.editCalls ~= edits then fail(scenario, "switched off in a fight, the macro was asked to change") end
	ns.addon:HandleSlash("on")
	-- The fight over: the macro follows the prompt to Bob.
	Mock.spellCooldowns = nil
	Mock.inCombat = false
	Mock.advance(2)
	ns.addon:PLAYER_REGEN_ENABLED()
	settleOn(ns, "Bob Bright")
	if not (bodyNow() or ""):find("/target Bob Bright", 1, true) then fail(scenario, "after the fight the macro holds " .. flat(bodyNow())) end
end)

-- A flash about the person just buffed is up as the fight starts: the macro
-- made at the pull still carries the cast the button carries.
with("barclick: a flash at the pull does not leave the fight's macro empty", function(ns, scenario)
	armed(ns)
	if not onBar(ns, 2) then fail(scenario, "SKIPPED -- no macro on the bar") return end
	ns.Prompt:ShowOutcome("cast", "Somebody Else")
	ns.addon:PLAYER_REGEN_DISABLED()
	Mock.inCombat = true
	local fight = bodyNow() or ""
	if not fight:find("/target Anna Aim", 1, true) then fail(scenario, "the pull under a flash wrote " .. flat(fight)) end
	local casts = Mock.pressBar(2)
	if #casts ~= 1 then fail(scenario, ("a press in the fight cast %d time(s)"):format(#casts)) end
	Mock.inCombat = false
end)

-- The macro had nothing to cast when the fight began: a press says why rather
-- than nothing at all.
with("barclick: a press of the empty bar macro in a fight says why", function(ns, scenario)
	if not onBar(ns, 2) then fail(scenario, "SKIPPED -- no macro on the bar") return end
	if bodyNow() ~= BAR_LINE then fail(scenario, "SKIPPED -- the macro carries a cast: " .. flat(bodyNow())) return end
	ns.addon:PLAYER_REGEN_DISABLED()
	Mock.inCombat = true
	if bodyNow() ~= BAR_LINE then fail(scenario, "SKIPPED -- the pull wrote a cast: " .. flat(bodyNow())) return end
	Mock.printed = {}
	Mock.pressBar(2)
	if not said():find("cannot touch macros in combat", 1, true) then fail(scenario, "a press in the fight said: " .. said()) end
	Mock.inCombat = false
end, { people = {} })

-- ------------------------------------------------------------------ 6
-- Everything a cast sets off inside the macro (the cast event, the settle,
-- the repaint onto the next person) leaves the running macro alone: it is
-- written once, the frame after.
with("barclick: nothing is written while the bar macro runs", function(ns, scenario)
	arrives(ns, "nameplate2", BOB)
	owe(ns, "Anna Aim")
	owe(ns, "Bob Bright")
	ns.addon:Tick()
	if not onBar(ns, 2) then fail(scenario, "SKIPPED -- no macro on the bar") return end
	local first = ns.Prompt.state.current
	Mock.castEvents = "sync"
	Mock.spellIdFor = spellIds(ns)
	local edits = Mock.editCalls
	local casts = Mock.pressBar(2)
	if #casts ~= 1 then fail(scenario, "SKIPPED -- the press cast nothing") return end
	if Mock.editCalls ~= edits then fail(scenario, ("the macro was written %d time(s) while it ran"):format(Mock.editCalls - edits)) end
	local current = ns.Prompt.state.current
	if current == first or not current then
		fail(scenario, "SKIPPED -- the prompt did not move on inside the press")
	end
	Mock.runTimers(0)
	if Mock.editCalls - edits ~= 1 then
		fail(scenario, ("the frame after the press wrote the macro %d time(s)"):format(Mock.editCalls - edits))
	end
end)

-- ------------------------------------------------------------------ 7
-- A #showtooltip on top keeps the macro Manners' (and is kept on top); a line
-- of the player's own makes it theirs: left as written, said once, its presses
-- not filed, until Put Manners on an action bar hands it back.
with("barclick: a Manners macro edited by hand", function(ns, scenario)
	armed(ns)
	if not onBar(ns, 2) then fail(scenario, "SKIPPED -- no macro on the bar") return end
	local index = macroIndex()
	EditMacro(index, nil, nil, "#showtooltip\n" .. bodyNow())
	wipe(ns.owed)
	leaves(ns, "nameplate1")
	arrives(ns, "nameplate2", BOB)
	owe(ns, "Bob Bright")
	if not settleOn(ns, "Bob Bright") then fail(scenario, "SKIPPED -- the prompt never moved to Bob") return end
	if bodyNow() ~= "#showtooltip\n" .. armedBody(ns) then
		fail(scenario, "with #showtooltip on top the macro holds " .. flat(bodyNow()))
	end
	ns.pendingClick = nil
	Mock.pressBar(2)
	if not (ns.pendingClick and ns.pendingClick.name == "Bob Bright") then fail(scenario, "a press under #showtooltip was not filed") end
	-- Changed with no word from the client: a press before anything has looked
	-- is not filed, and the next change of the prompt finds it and leaves it.
	again(ns, "Bob Bright")
	local quietly = bodyNow() .. "\n/say changed without a word"
	Mock.macroList[index].body = quietly
	ns.db.profile.debugClicks = true
	Mock.printed = {}
	ns.pendingClick = nil
	Mock.pressBar(2)
	if ns.pendingClick then fail(scenario, "a press of a macro changed without a word was filed") end
	if not said():find("via=bar body=edited", 1, true) then fail(scenario, "the click line does not say it was changed: " .. said()) end
	ns.db.profile.debugClicks = false
	Mock.runTimers(0.1)
	arrives(ns, "nameplate1", ANNA)
	owe(ns, "Anna Aim")
	ns.owed["Bob Bright"] = nil
	settleOn(ns, "Anna Aim")
	if bodyNow() ~= quietly then fail(scenario, "a macro changed without a word was written over: " .. flat(bodyNow())) end
	if count(said(), WARNED) ~= 1 then fail(scenario, "a macro changed without a word was said about: " .. said()) end
	ns.addon:HandleSlash("macro")
	leaves(ns, "nameplate1")
	-- A line of the player's own.
	again(ns, "Bob Bright")
	settleOn(ns, "Bob Bright")
	Mock.printed = {}
	local mine = bodyNow() .. "\n/say I pressed this myself"
	EditMacro(index, nil, nil, mine)
	EditMacro(index, nil, nil, mine)
	if count(said(), WARNED) ~= 1 or not said():find("Bob Bright", 1, true) then
		fail(scenario, "a macro changed by hand was said about: " .. said())
	end
	local edits = Mock.editCalls
	arrives(ns, "nameplate1", ANNA)
	owe(ns, "Anna Aim")
	wipe(ns.tried)
	ns.owed["Bob Bright"] = nil
	settleOn(ns, "Anna Aim")
	for _ = 1, 3 do
		Mock.advance(0.4)
		ns.addon:Tick()
	end
	if Mock.editCalls ~= edits then fail(scenario, "a macro changed by hand was written again") end
	if bodyNow() ~= mine then fail(scenario, "a macro changed by hand now holds " .. flat(bodyNow())) end
	ns.db.profile.debugClicks = true
	Mock.printed = {}
	ns.pendingClick = nil
	Mock.pressBar(2)
	if ns.pendingClick then fail(scenario, "a press of a macro changed by hand was filed") end
	if not said():find("via=bar body=edited", 1, true) then fail(scenario, "the click line does not say so: " .. said()) end
	-- Handed back, a moment after the press.
	Mock.runTimers(0.1)
	ns.addon:HandleSlash("macro")
	if bodyNow() ~= armedBody(ns) then fail(scenario, "/manners macro left " .. flat(bodyNow())) end
end)

-- ------------------------------------------------------------------ 8
-- At login, out of combat: an older version's macro is rewritten, with a line
-- saying so; a body a session before this one left goes back to the first line
-- before anything can press it; anything else is left, a macro of another
-- name included, and no macro is ever made.
local LOGIN = {
	{ name = "Manners", body = "/click MannersPrompt", becomes = BAR_LINE, said = true },
	{ name = "Manners", body = OLD, becomes = BAR_LINE, said = true },
	{ name = "Manners", body = OLD .. "  \n", becomes = BAR_LINE, said = true },
	{ name = "Manners", body = "#showtooltip\n" .. OLD, becomes = "#showtooltip\n" .. BAR_LINE, said = true },
	{ name = "Manners", body = OLD .. "\n/say hi" },
	{ name = "Other", body = OLD },
	{ name = "Manners", body = BAR_LINE .. "\n/target Bob Bright\n/cast Arcane Intellect\n/cleartarget", becomes = BAR_LINE },
	{ name = "Manners", body = OLD, becomes = BAR_LINE, said = true, combat = true },
	{},
}
for i, case in ipairs(LOGIN) do
	local scenario = ("barclick: an old Manners macro is rewritten at login, nothing else is (%d)"):format(i)
	Mock.reset()
	Mock.setFlavour("camelot")
	local restore = strangers({})
	local made = 0
	local create = CreateMacro
	CreateMacro = function(...)
		made = made + 1
		return create(...)
	end
	if case.name then Mock.macroList[1] = { name = case.name, icon = "INV_MISC_NOTE_03", body = case.body } end
	local ns = load(scenario)
	if ns then
		local ok, err = pcall(function()
			Mock.inCombat = case.combat == true
			ns.addon:OnInitialize()
			ns.addon:OnEnable()
			Mock.runTimers(3)
			local now = Mock.macroList[1] and Mock.macroList[1].body
			if case.combat then
				if now ~= case.body then fail(scenario, "a login in a fight touched the macro: " .. flat(now)) end
				Mock.inCombat = false
				ns.addon:PLAYER_REGEN_ENABLED()
				now = Mock.macroList[1] and Mock.macroList[1].body
			end
			if case.becomes and now ~= case.becomes then
				fail(scenario, ("%s at login became %s, not %s"):format(flat(case.body), flat(now), flat(case.becomes)))
			elseif case.name and not case.becomes and now ~= case.body then
				fail(scenario, ("%s (%s) was rewritten: %s"):format(flat(case.body), case.name, flat(now)))
			end
			local lines = count(said(), UPDATED)
			if lines ~= (case.said and 1 or 0) then fail(scenario, ("the update was said %d times: %s"):format(lines, said())) end
			if made > 0 then fail(scenario, "a macro was made at login") end
			if not case.name and next(Mock.macroList) ~= nil then fail(scenario, "a macro appeared at login") end
		end)
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
	end
	CreateMacro = create
	Mock.inCombat = false
	restore()
	Mock.reset()
end

-- ------------------------------------------------------------------ 10
-- A flash about Anna is over the panel while Bob is armed: the macro holds its
-- first line alone, and a press says the prompt has moved on.
with("barclick: a flash about somebody else holds the macro back", function(ns, scenario)
	wipe(ns.owed)
	leaves(ns, "nameplate1")
	arrives(ns, "nameplate2", BOB)
	owe(ns, "Bob Bright")
	ns.addon:Tick()
	if not onBar(ns, 2) then fail(scenario, "SKIPPED -- no macro on the bar") return end
	if not (bodyNow() or ""):find("/target Bob Bright", 1, true) then fail(scenario, "SKIPPED -- Bob is not armed") return end
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	Mock.runTimers(0)
	if bodyNow() ~= BAR_LINE then fail(scenario, "under a flash about Anna the macro holds " .. flat(bodyNow())) end
	Mock.printed = {}
	local casts = Mock.pressBar(2)
	if #casts ~= 0 then fail(scenario, "a press under the flash cast at " .. tostring(casts[1].target)) end
	if not said():find("the prompt has moved on to", 1, true) then fail(scenario, "a press under the flash said: " .. said()) end
end)

-- ------------------------------------------------------------------ 11
-- The prompt itself, by mouse and by its key binding, casts once as it always
-- did, with the client refusing a macro run from a macro.
with("barclick: the prompt itself and its key still cast once", function(ns, scenario)
	armed(ns)
	local prompt = Mock.namedFrames.MannersPrompt
	if not prompt then fail(scenario, "SKIPPED -- no MannersPrompt") return end
	Mock.macroChain = "refused"
	local before = #Mock.castLog
	Mock.mouseClickOn(prompt, "LeftButton")
	if #Mock.castLog - before ~= 1 then fail(scenario, ("a mouse click on the prompt cast %d time(s)"):format(#Mock.castLog - before)) end
	again(ns)
	before = #Mock.castLog
	Mock.pressBinding("CLICK MannersPrompt:LeftButton", { release = true })
	if #Mock.castLog - before ~= 1 then fail(scenario, ("the prompt's key cast %d time(s)"):format(#Mock.castLog - before)) end
end)

-- ------------------------------------------------------------------ 12
-- A loading screen puts the macro back to its first line; the world back, it
-- follows the prompt again.
with("barclick: a loading screen puts the macro back to its first line", function(ns, scenario)
	armed(ns)
	if not onBar(ns, 2) then fail(scenario, "SKIPPED -- no macro on the bar") return end
	local full = bodyNow()
	if full == BAR_LINE then fail(scenario, "SKIPPED -- the macro carries no cast") return end
	ns.addon:PLAYER_LEAVING_WORLD()
	if bodyNow() ~= BAR_LINE then fail(scenario, "leaving the world the macro still holds " .. flat(bodyNow())) end
	ns.addon:Tick()
	if bodyNow() ~= BAR_LINE then fail(scenario, "a scan during the loading screen wrote " .. flat(bodyNow())) end
	ns.addon:PLAYER_ENTERING_WORLD("PLAYER_ENTERING_WORLD", false, false)
	ns.addon:Tick()
	if bodyNow() ~= armedBody(ns) then fail(scenario, "back in the world the macro holds " .. flat(bodyNow())) end
end)

-- ------------------------------------------------------------------ 13
-- With nothing targeted the macro clears the target it takes; target a friend
-- and it hands that one back, at once, without waiting for a scan.
with("barclick: a change of target hands back the right way at once", function(ns, scenario)
	local realGuid = UnitGUID
	local hasTarget = false
	rawset(_G, "UnitGUID", function(unit)
		if unit == "target" and not hasTarget then return nil end
		return realGuid(unit)
	end)
	armed(ns)
	if not onBar(ns, 2) then fail(scenario, "SKIPPED -- no macro on the bar") return end
	if lastLine(bodyNow()) ~= "/cleartarget" then fail(scenario, "SKIPPED -- with nothing targeted the macro ends " .. flat(bodyNow())) return end
	Mock.advance(1)
	hasTarget = true
	ns.addon:PLAYER_TARGET_CHANGED("PLAYER_TARGET_CHANGED")
	if lastLine(bodyNow()) ~= "/targetlasttarget" then
		fail(scenario, "a friend targeted, the macro still ends " .. flat(bodyNow()))
	end
end)

-- /manners selftest says whose the macro is, beside the key.
with("barclick: the self-test says whose the macro is", function(ns, scenario)
	armed(ns)
	if not onBar(ns, 2) then fail(scenario, "SKIPPED -- no macro on the bar") return end
	ns.addon:HandleSlash("selftest")
	local report = tostring(ns.Selftest.last)
	if not report:find("/click macro made (ours)", 1, true) then
		fail(scenario, "the report's binding line does not say the macro is Manners': " .. (report:match("[^\n]*/click macro[^\n]*") or "none"))
	end
end)

-- ------------------------------------------------------------------ 14
-- With the macro window open every write would have it put the saved text back
-- in its box over what the player is typing: the macro goes to its first line
-- as the window opens and is not written while it is up; shut, it follows the
-- prompt again.
with("barclick: nothing is written while the macro window is open", function(ns, scenario)
	armed(ns)
	if not onBar(ns, 2) then fail(scenario, "SKIPPED -- no macro on the bar") return end
	local window = CreateFrame("Frame", "MacroFrame", UIParent)
	local refills = 0
	window:RegisterEvent("UPDATE_MACROS")
	window:SetScript("OnEvent", function() refills = refills + 1 end)
	window:Hide()
	rawset(_G, "MacroFrame", window)
	ns.addon:ADDON_LOADED("ADDON_LOADED", "Blizzard_MacroUI")
	window:Show()
	Mock.fire(window, "OnShow")
	if bodyNow() ~= BAR_LINE then fail(scenario, "with the window open the macro holds " .. flat(bodyNow())) end
	local edits, seen = Mock.editCalls, refills
	wipe(ns.owed)
	leaves(ns, "nameplate1")
	arrives(ns, "nameplate2", BOB)
	owe(ns, "Bob Bright")
	settleOn(ns, "Bob Bright")
	if Mock.editCalls ~= edits or refills ~= seen then
		fail(scenario, ("with the window open the macro was written %d time(s)"):format(Mock.editCalls - edits))
	end
	window:Hide()
	Mock.fire(window, "OnHide")
	if bodyNow() ~= armedBody(ns) then fail(scenario, "the window shut, the macro holds " .. flat(bodyNow())) end
end)
