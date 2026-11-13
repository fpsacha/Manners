-- Fixes from the twentieth bug hunt, outside the options window: a prompt with
-- nothing castable left armed, a colour whose alpha is not a number, ledger
-- rows stamped by a clock that ran fast, the cost of the death watch, of a
-- chat line in another script and of remembered askers, the spellbook with the
-- deprecated calls gone, a self-buff the client hides, the spoken line in a
-- fight and at somebody just dead, and the client's "Unknown" for a name it
-- has not loaded.
--
-- Every scenario name starts with "core20:" so the mutations in
-- tests/mutations/hunt20-core.py can name the one that has to catch them.
-- Globals a scenario replaces are put back by `with`, whether it finished or
-- threw.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe
local pressButton, favourFrom, savedProfile = H.pressButton, H.favourFrom, H.savedProfile

local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "C_SpellBook", "strcmputf8i",
	"UnitIsDeadOrGhost", "UnitIsFeignDeath", "C_Spell" }
local original = {}
for _, name in ipairs(TOUCHED) do original[name] = rawget(_G, name) end

local function with(scenario, globals, body)
	for name, value in pairs(globals or {}) do rawset(_G, name, value) end
	local ok, err = pcall(body)
	for _, name in ipairs(TOUCHED) do rawset(_G, name, original[name]) end
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- A macro on one line, for a failure message.
local function flat(text)
	return (tostring(text):gsub("\n", " / "))
end

local function entryFor(ns, name)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.name == name then return entry end
	end
	return nil
end

-- ------------------------------------------------------------------ core20-1
-- A prompt that has nothing left to cast is disarmed, not just hidden.
--
-- The capability probe can answer "nothing known" for a moment (a client still
-- loading spell data), and the branch for that hid the panel without taking
-- the macro off the button. It ran ahead of the off and snooze branches, so
-- /manners off could not disarm it either, and a fight starting then froze
-- the last person's macro onto the binding: every press in it went out.
Mock.reset()
do
	local scenario = "core20: a prompt with nothing castable is disarmed"
	local PETRA = "Petra Stonewell"
	local restoreUnits = strangers({ nameplate1 = { "Petra", "Stonewell" } })
	with(scenario, nil, function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		-- Greeted already: the first greeting's preview, waiting for the end
		-- of a fight, would otherwise disarm the button on its own.
		ns.db.char.welcomed = true
		owe(ns, PETRA)
		ns.Prompt:Refresh()
		local button = ns.Prompt:GetButton()
		local armed = button:GetAttribute("macrotext1")
		if not (armed and armed:find(PETRA, 1, true)) then
			fail(scenario, "SKIPPED -- Petra was never armed: " .. flat(armed))
			return
		end

		-- The probe answers nothing for a moment.
		rawset(_G, "IsSpellKnown", function() return false end)
		rawset(_G, "IsPlayerSpell", function() return false end)
		ns.Guard("probe", ns.ProbeCapabilities)
		if ns.CanCastAnything() then
			fail(scenario, "SKIPPED -- the probe still finds something to cast")
			return
		end
		ns.Prompt:Refresh()
		if button:IsShown() then
			fail(scenario, "SKIPPED -- with nothing castable the panel stayed up")
		end
		local left = button:GetAttribute("macrotext1")
		if left then
			fail(scenario, "with nothing castable the panel hid and the button still casts: " .. flat(left))
		end
		ns.addon:HandleSlash("off")
		left = button:GetAttribute("macrotext1")
		if left then
			fail(scenario, "switched off with nothing castable, the button still casts: " .. flat(left))
		end
		ns.addon:HandleSlash("on")

		-- And in a fight: armed at Petra when it starts, the probe going blank
		-- in it. The macro cannot change until the fight ends, and then it must.
		rawset(_G, "IsSpellKnown", original.IsSpellKnown)
		rawset(_G, "IsPlayerSpell", original.IsPlayerSpell)
		ns.Guard("probe", ns.ProbeCapabilities)
		Mock.advance(5)
		owe(ns, PETRA)
		ns.Prompt:Refresh()
		armed = button:GetAttribute("macrotext1")
		if not (armed and armed:find(PETRA, 1, true)) then
			fail(scenario, "SKIPPED -- Petra was not armed again before the fight: " .. flat(armed))
			return
		end
		Mock.protect(button)
		ns.addon:PLAYER_REGEN_DISABLED()
		Mock.inCombat = true
		Mock.runTimers(0)
		rawset(_G, "IsSpellKnown", function() return false end)
		rawset(_G, "IsPlayerSpell", function() return false end)
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.Prompt:Refresh()
		Mock.advance(1)
		Mock.inCombat = false
		ns.addon:PLAYER_REGEN_ENABLED()
		left = button:GetAttribute("macrotext1")
		if left then
			fail(scenario, "after a fight with nothing castable, the next fight's presses still cast: "
				.. flat(left))
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ core20-2
-- A saved colour whose alpha is not a number is repaired at login.
--
-- ClampSettings checked a colour's first three numbers only, and every look
-- does arithmetic on the fourth: a hand-edited or damaged file with an alpha
-- of "x" or true broke styling at every login, and a profile switch back to it
-- threw out of RefreshConfig. A number past 0..1 is put back inside, as an
-- imported colour is.
for _, case in ipairs({
	{ style = "glass", key = "bgColor", value = { 0.04, 0.04, 0.06, "x" } },
	{ style = "luxe", key = "bgColor", value = { 0.04, 0.04, 0.06, true } },
	{ style = "toast", key = "bgColor", value = { 0.04, 0.04, 0.06, "x" } },
	{ style = "glass", key = "fontColor", value = { 1, 1, 1, "x" } },
	{ style = "glass", key = "accentColor", value = { 0.4, 0.4, 0.9, {} } },
	{ style = "glass", key = "bgColor", value = { 2, -1, 0.5, 3 }, want = { 1, 0, 0.5, 1 } },
}) do
	Mock.reset()
	Mock.sv = {}
	local scenario = ("core20: a saved colour with a bad alpha is repaired (%s, %s, %s)")
		:format(case.style, case.key, type(case.value[4]) == "number" and "out of range" or type(case.value[4]))
	with(scenario, nil, function()
		local saved = savedProfile(scenario, function(profile)
			profile.prompt = profile.prompt or {}
			profile.prompt.style = case.style
			profile.prompt[case.key] = case.value
		end)
		local ns = saved and load(scenario)
		if not ns then
			fail(scenario, "SKIPPED -- the session would not start")
			return
		end
		drive(scenario, ns)
		local c = ns.db.profile.prompt[case.key]
		if type(c) ~= "table" then
			fail(scenario, "the colour is gone: " .. tostring(c))
			return
		end
		for i = 1, 4 do
			if c[i] ~= nil and type(c[i]) ~= "number" then
				fail(scenario, ("the colour's channel %d was kept as %s, which every look does sums on")
					:format(i, type(c[i])))
			elseif type(c[i]) == "number" and (c[i] < 0 or c[i] > 1) then
				fail(scenario, ("the colour's channel %d was kept at %s, outside 0..1"):format(i, tostring(c[i])))
			end
		end
		if case.want then
			for i = 1, 4 do
				if c[i] ~= case.want[i] then
					fail(scenario, ("channel %d reads %s, not %s"):format(i, tostring(c[i]), tostring(case.want[i])))
				end
			end
		end
	end)
end
Mock.reset()

-- The same colour arriving through a profile switch, which runs the clamp and
-- then restyles. And a styling fault the clamp cannot mend does not take the
-- rest of the switch -- the scanner, the macro -- with it.
Mock.reset()
do
	local scenario = "core20: a profile switch to a colour with a bad alpha restyles cleanly"
	with(scenario, nil, function()
		local ns = load(scenario)
		if not ns then return end
		drive(scenario, ns)
		ns.db.profile.prompt.bgColor = { 0.04, 0.04, 0.06, true }
		local ok, err = pcall(ns.addon.RefreshConfig, ns.addon, "OnProfileChanged")
		if not ok then
			fail(scenario, "switching to the profile threw: " .. tostring(err))
		end
		local alpha = ns.db.profile.prompt.bgColor[4]
		if type(alpha) ~= "number" then
			fail(scenario, "the switch kept an alpha of " .. type(alpha))
		end
		noErrors(scenario, ns)
	end)
end
Mock.reset()

Mock.reset()
do
	local scenario = "core20: a styling fault on a profile switch does not stop the switch"
	with(scenario, nil, function()
		local ns = load(scenario)
		if not ns then return end
		drive(scenario, ns)
		local scanned = false
		local realStart = ns.addon.StartScanner
		ns.addon.StartScanner = function(self, ...)
			scanned = true
			return realStart(self, ...)
		end
		local realStyle = ns.Prompt.ApplyStyle
		ns.Prompt.ApplyStyle = function() error("a look that cannot paint") end
		local ok, err = pcall(ns.addon.RefreshConfig, ns.addon, "OnProfileChanged")
		ns.Prompt.ApplyStyle = realStyle
		ns.addon.StartScanner = realStart
		if not ok then
			fail(scenario, "a styling fault on a profile switch threw out of it: " .. tostring(err))
		end
		if not scanned then
			fail(scenario, "a styling fault on a profile switch left the scanner unstarted")
		end
		local named = false
		for _, e in ipairs(ns.errors or {}) do
			if tostring(e.err):find("a look that cannot paint", 1, true) then named = true end
		end
		if not named then
			fail(scenario, "the styling fault was not named in /manners errors")
		end
	end)
end
Mock.reset()

-- ------------------------------------------------------------------ core20-3
-- Ledger rows stamped by a clock that ran fast count as now, not as the future.
--
-- A session with the computer clock days ahead wrote every row with a future
-- stamp. Put right, the clock left them "today" on every later day until real
-- time caught up: the headline counted favours nobody did today. A remembered
-- favour's stamp from the future already counts as now (RestoreDebts).
Mock.reset()
do
	local scenario = "core20: ledger rows from a clock that ran fast are not today's for ever"
	with(scenario, nil, function()
		local ns = load(scenario)
		if not ns then return end
		drive(scenario, ns)
		local now = time()
		local entries = {}
		for i = 1, 5 do
			entries[#entries + 1] = { kind = "received", name = "Old" .. i, class = "PRIEST",
				spells = { 1459 }, at = now - 7 * 86400 + i, times = 1, state = "returned",
				doneAt = now - 7 * 86400 + i + 10, gave = 1459 }
		end
		for i = 1, 3 do
			local ahead = now + 40 * 86400 + i
			entries[#entries + 1] = { kind = "received", name = "Fast" .. i, class = "MAGE",
				spells = { 1459 }, at = ahead, times = 1, state = "returned",
				doneAt = ahead + 10, gave = 1459 }
		end
		-- And a row settled, by a damaged file, before it happened.
		entries[#entries + 1] = { kind = "received", name = "Early", class = "MAGE",
			spells = { 1459 }, at = now - 3 * 86400, times = 1, state = "letgo", why = "expired",
			doneAt = now - 9 * 86400 }
		ns.db.char.ledger = { entries = entries }
		ns.Ledger.Load()
		local s = ns.db.char.ledger
		for _, e in ipairs(s.entries) do
			if e.at > now then
				fail(scenario, ("%s was kept %d seconds in the future"):format(e.name, e.at - now))
			end
			if e.doneAt and e.doneAt > now then
				fail(scenario, ("%s was kept as settled %d seconds from now"):format(e.name, e.doneAt - now))
			end
			if e.doneAt and e.doneAt < e.at then
				fail(scenario, ("%s was kept as settled %d seconds before it happened")
					:format(e.name, e.at - e.doneAt))
			end
		end
		Mock.advance(10 * 86400)
		local sum = ns.Ledger.Summary()
		if sum.received ~= 0 or sum.returned ~= 0 then
			fail(scenario, ("ten days on, today reads %d received and %d returned, from rows a fast clock wrote")
				:format(sum.received, sum.returned))
		end
		noErrors(scenario, ns)
	end)
end
Mock.reset()

-- ------------------------------------------------------------------ core20-4
-- The death watch asks whether somebody is feigning death only as they go
-- down, not again on every tick for as long as they stay down.
--
-- For somebody already down neither answer changes anything, and a wiped raid
-- lying dead paid one pcall each on every tick, Manners on or off. A hunter
-- feigning death is still not taken for dead, and the others still come back
-- as just revived.
Mock.reset()
do
	local scenario = "core20: the death watch asks about feigning once, as somebody goes down"
	local names = { party1 = { "Anna", "Aim" }, party2 = { "Bert", "Beside" },
		party3 = { "Cara", "Close" }, party4 = { "Dora", "Deep" } }
	local restoreUnits = strangers(names)
	local dead, feigning, asked = {}, {}, {}
	local function deadOrGhost(unit)
		if unit == "player" then return Mock.dead end
		return dead[unit] == true
	end
	local function feignDeath(unit)
		asked[unit] = (asked[unit] or 0) + 1
		return feigning[unit] == true
	end
	with(scenario, { UnitIsDeadOrGhost = deadOrGhost, UnitIsFeignDeath = feignDeath }, function()
		local ns = load(scenario)
		if not ns then return end
		Mock.groupSize = 5
		freshPrompt(ns, scenario)
		ns.db.profile.sources.strangers = false
		for _, unit in ipairs({ "party1", "party2", "party3", "party4" }) do dead[unit] = true end
		-- Cara is a hunter lying in Feign Death.
		feigning.party3 = true
		Mock.advance(0.4)
		ns.addon:Tick()
		if (asked.party1 or 0) == 0 then
			fail(scenario, "SKIPPED -- nobody was asked whether they were feigning as they went down")
			return
		end
		wipe(asked)
		for _ = 1, 5 do
			Mock.advance(0.4)
			ns.addon:Tick()
		end
		local again = (asked.party1 or 0) + (asked.party2 or 0) + (asked.party4 or 0)
		if again > 0 then
			fail(scenario, ("asked %d times in five ticks whether three people already down were feigning")
				:format(again))
		end
		for unit in pairs(dead) do dead[unit] = nil end
		feigning.party3 = nil
		Mock.advance(0.4)
		ns.addon:Tick()
		for _, who in ipairs({ "Anna Aim", "Bert Beside", "Dora Deep" }) do
			local entry = entryFor(ns, who)
			if not (entry and entry.sweep == "revived") then
				fail(scenario, who .. " stood up and was not offered as just revived")
			end
		end
		local cara = entryFor(ns, "Cara Close")
		if cara and cara.sweep == "revived" then
			fail(scenario, "a hunter standing up from Feign Death was offered as just revived")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ core20-5
-- A chat line in another script is compared with the words it could match,
-- not with every English one.
--
-- With People who ask me in chat on, every Russian, Korean or Chinese line of
-- eight words or fewer went through strcmputf8i against every word of every
-- list, English ones included, which only ever match by equality: about seven
-- hundred pcalls for a Russian line asking for nothing. A Russian request is
-- still heard, whatever its capitals.
Mock.reset()
do
	local scenario = "core20: a line in another script is not compared with English words"
	local function foldCh(s) return (s:gsub("Ч", "ч"):gsub("Н", "н"):gsub("П", "п")) end
	local english = 0
	local function fold(a, b)
		if not tostring(a):find("[\128-\255]") or not tostring(b):find("[\128-\255]") then
			english = english + 1
		end
		return foldCh(a) == foldCh(b) and 0 or 1
	end
	Mock.locale = "ruRU"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
	local realSpell = C_Spell
	local spell = setmetatable({
		GetSpellName = function(id)
			if id == 10157 or id == 1459 then return "Чародейский интеллект" end
			return realSpell.GetSpellName(id)
		end,
	}, { __index = realSpell })
	with(scenario, { C_Spell = spell, strcmputf8i = fold }, function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		local db = ns.db.profile
		db.sources.asked = true
		db.sources.strangers = false
		db.sources.group = false
		english = 0
		ns.addon:CHAT_MSG_SAY("CHAT_MSG_SAY", "Продам кожу и железо недорого пишите", "Anna Aim",
			"Common", "", "", "", 0, 0, "", 0, 1, "Player-1-nameplate1")
		if english > 0 then
			fail(scenario, ("a Russian line asking for nothing was compared with English words %d times")
				:format(english))
		end
		if entryFor(ns, "Anna Aim") then
			fail(scenario, "SKIPPED -- a Russian line asking for nothing was heard as a request")
		end
		Mock.advance(61)
		ns.addon:CHAT_MSG_SAY("CHAT_MSG_SAY", "Чародейский интеллект пж", "Anna Aim",
			"Common", "", "", "", 0, 0, "", 0, 1, "Player-1-nameplate1")
		local anna = entryFor(ns, "Anna Aim")
		if not (anna and anna.reason == "asked") then
			fail(scenario, "a Russian request with a capital at the start was not heard")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ core20-6
-- Two names in A to Z are compared without the client's strcmputf8i.
--
-- SameName asked it, inside a pcall, of every pair of names: the scan checks
-- each asker it remembers against every request standing, on every pass, so a
-- bank of people saying "int pls" put a city scan at five times its budget.
-- Names in other scripts are still folded by it.
Mock.reset()
do
	local scenario = "core20: names in A to Z are compared without strcmputf8i"
	local plain, folded = 0, 0
	local function foldCy(s)
		s = s:gsub("\208([\144-\159])", function(c) return "\208" .. string.char(c:byte() + 32) end)
		s = s:gsub("\208([\160-\175])", function(c) return "\209" .. string.char(c:byte() - 32) end)
		return s:lower()
	end
	local function fold(a, b)
		if tostring(a):find("[\128-\255]") or tostring(b):find("[\128-\255]") then
			folded = folded + 1
		else
			plain = plain + 1
		end
		a, b = foldCy(a), foldCy(b)
		if a == b then return 0 end
		return a < b and -1 or 1
	end
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bert", "Beside" },
		nameplate3 = { "Cara", "Close" } })
	with(scenario, { strcmputf8i = fold }, function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		local db = ns.db.profile
		db.sources.asked = true
		db.sources.strangers = false
		db.sources.group = false
		for i, who in ipairs({ "Anna Aim", "Bert Beside", "Cara Close" }) do
			ns.addon:CHAT_MSG_SAY("CHAT_MSG_SAY", "int pls", who, "Common", "", "", "", 0, 0, "", 0, 1,
				"Player-1-nameplate" .. i)
		end
		if not entryFor(ns, "Bert Beside") then
			fail(scenario, "SKIPPED -- the askers were not offered")
			return
		end
		plain = 0
		for _ = 1, 5 do
			Mock.advance(0.4)
			ns.addon:Tick()
		end
		-- The scan itself no longer asks SameName of a request a token has
		-- matched (it compares the full names), so the compare is asked
		-- directly: it is still what the never-offer list and a request nobody
		-- has matched go through on every pass.
		for _ = 1, 5 do
			ns.SameName("Anna Aim", "Bert Beside")
			ns.SameName("Cara", "Cara Close")
		end
		if plain > 0 then
			fail(scenario, ("five scans with three askers made %d strcmputf8i calls on names in A to Z")
				:format(plain))
		end
		if not ns.SameName("Bert Beside", "bert beside") then
			fail(scenario, "two spellings of one name in A to Z are no longer the same name")
		end
		folded = 0
		if not ns.SameName("Аня Иванова", "аня иванова") or folded == 0 then
			fail(scenario, "a Russian name in two cases is no longer folded by strcmputf8i")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ core20-7
-- The spellbook is read through the client's own calls.
--
-- IsSpellKnown and IsPlayerSpell are, on Forever 1.60.1, shims that load only
-- with the loadDeprecationFallbacks setting on. With it off, every class read
-- as knowing nothing: no prompt, no reminders, and no error.
Mock.reset()
do
	local scenario = "core20: the spellbook is read without the deprecated calls"
	local book = {
		IsSpellInSpellBook = function(id, bank, overrides)
			return id == 1459 and bank == 0 and overrides == false
		end,
		IsSpellKnown = function() return false end,
	}
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
	with(scenario, { C_SpellBook = book }, function()
		rawset(_G, "IsSpellKnown", nil)
		rawset(_G, "IsPlayerSpell", nil)
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		if not ns.caps.anyKnown or not ns.CanCastAnything() then
			fail(scenario, "with the deprecated spellbook calls gone, the mage knows nothing to cast")
		elseif not entryFor(ns, "Anna Aim") then
			fail(scenario, "with the deprecated spellbook calls gone, a stranger is not offered")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ core20-8
-- A self-buff the client hides just now is not cast again.
--
-- The aura reads hand back nothing at all for an aura the client keeps secret
-- (a battleground match, say), so a mage wearing Ice Armor read as wearing
-- nothing, was reminded, and every press cast it again. The restriction can
-- start after the probe ran, so it is asked at read time. Without the
-- restriction, a mage wearing none is still reminded.
for _, case in ipairs({ { hidden = false }, { hidden = true } }) do
	Mock.reset()
	local scenario = "core20: a self-buff the client hides is not cast again"
		.. (case.hidden and "" or " (control: none on, nothing hidden)")
	local armor = {}
	local known = { [1459] = true }
	with(scenario, nil, function()
		local probe = load(scenario)
		if not probe then return end
		local family
		for _, f in ipairs(probe.OWN_BUFFS.MAGE or {}) do
			if f.key == "armor" then family = f end
		end
		if not family then
			fail(scenario, "SKIPPED -- no armor family for a mage")
			return
		end
		for _, spell in ipairs(family.spells) do
			for _, id in ipairs(spell.ranks) do known[id] = true end
			for _, id in ipairs(spell.auraIds) do armor[id] = true end
		end
		rawset(_G, "IsSpellKnown", function(id) return known[id] == true end)
		rawset(_G, "IsPlayerSpell", function(id) return known[id] == true end)
		local restoreUnits = strangers({})
		-- Wearing Intellect and, as far as the reads can tell, no armor.
		Mock.playerHeld = { [1459] = true }
		local ns = load(scenario)
		if ns then
			freshPrompt(ns, scenario)
			local offeredBefore
			for _, entry in ipairs(ns.BuildQueue()) do
				if entry.reason == "self" then offeredBefore = entry.buff.key end
			end
			if not offeredBefore then
				fail(scenario, "SKIPPED -- a mage wearing no armor was not reminded of it")
			elseif case.hidden then
				-- The match goes live after the probe ran: the armor is secret now.
				Mock.secretAuraIds = armor
				local offered
				for _, entry in ipairs(ns.BuildQueue()) do
					if entry.reason == "self" then offered = entry.buff.key end
				end
				if offered then
					fail(scenario, "an armor the client hides was read as missing and offered again: "
						.. tostring(offered))
				end
			end
			noErrors(scenario, ns)
		end
		restoreUnits()
	end)
end
Mock.reset()

-- ------------------------------------------------------------------ core20-8b
-- A group buff read on somebody is not "absent" while the client hides it.
--
-- The same empty read, through the reader every group buff uses (the offer of
-- your own Intellect, a stranger's, a blessing carried): a match that began
-- after the probe left it a definite "no", and a mage wearing Arcane Intellect
-- was offered it on every press. It answers "cannot tell" instead, and still
-- says yes for one that reads as worn and no for one not hidden.
for _, case in ipairs({
	{ name = " (control: nothing hidden)", secret = nil, worn = false, expect = false },
	{ name = " (control: worn)", secret = nil, worn = true, expect = true },
	{ name = "", secret = { [1459] = true }, worn = false, expect = "unknown" },
}) do
	Mock.reset()
	local scenario = "core20: a group buff the client hides does not read as absent" .. case.name
	with(scenario, nil, function()
		local probe = load(scenario)
		if not probe then return end
		local found = probe.FindBuff("MAGE", "intellect")
		if not found then
			fail(scenario, "SKIPPED -- no Intellect buff for a mage")
			return
		end
		local known = {}
		for _, id in ipairs(found.ranks) do known[id] = true end
		rawset(_G, "IsSpellKnown", function(id) return known[id] == true end)
		rawset(_G, "IsPlayerSpell", function(id) return known[id] == true end)
		local ns = load(scenario)
		if not ns then return end
		ns.Guard("probe", ns.ProbeCapabilities)
		local buff = ns.FindBuff("MAGE", "intellect")
		local info = ns.BuffInfo(buff)
		if not (info and info.readable) then
			fail(scenario, "SKIPPED -- the Intellect buff was not readable at the probe")
			return
		end
		-- The match goes live after the probe ran.
		Mock.playerHeld = case.worn and { [buff.auraIds[1]] = true } or {}
		Mock.secretAuraIds = case.secret
		local has = ns.UnitHasBuff("player", buff)
		local want = case.expect
		if want == "unknown" then want = nil end
		if has ~= want then
			fail(scenario, ("an Intellect read as %s, not %s"):format(tostring(has), tostring(want)))
		end
		noErrors(scenario, ns)
	end)
end
Mock.reset()

-- ------------------------------------------------------------------ core20-9
-- The macro armed for a fight carries no spoken line.
--
-- Every press in a fight runs the text armed at the pull, so the line went out
-- on a press the global cooldown turned away and again after the favour was
-- repaid. Back after the fight.
for _, mode in ipairs({ "returning", "always" }) do
	Mock.reset()
	local scenario = "core20: no spoken line in the macro armed for a fight (" .. mode .. ")"
	local ANNA = "Anna Aim"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
	with(scenario, nil, function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		local speech = ns.db.profile.speech
		speech.enabled = true
		speech.onlyWhenReturning = (mode == "returning")
		speech.channel = "SAY"
		speech.phrases = "Thanks for the buff, {name}!"
		owe(ns, ANNA)
		ns.Prompt:InvalidateMacro()
		ns.addon:Tick()
		local button = ns.Prompt:GetButton()
		local before = button:GetAttribute("macrotext1")
		if not (before and before:find("/say", 1, true)) then
			fail(scenario, "SKIPPED -- the line was not armed before the fight: " .. flat(before))
			return
		end
		Mock.protect(button)
		ns.addon:PLAYER_REGEN_DISABLED()
		Mock.inCombat = true
		Mock.runTimers(0)
		local fight = button:GetAttribute("macrotext1")
		if not (fight and fight:find(ANNA, 1, true)) then
			fail(scenario, "SKIPPED -- Anna was not armed for the fight: " .. flat(fight))
		elseif fight:find("/say", 1, true) then
			fail(scenario, "the macro armed for the fight says the line on every press: " .. flat(fight))
		end
		Mock.advance(2)
		Mock.inCombat = false
		ns.addon:PLAYER_REGEN_ENABLED()
		local after = button:GetAttribute("macrotext1")
		if after and after:find(ANNA, 1, true) and not after:find("/say", 1, true) then
			fail(scenario, "after the fight the line did not come back: " .. flat(after))
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ core20-10
-- A press on somebody who died since the scan carries no spoken line.
--
-- The 1.5 s hold and the empty-queue fuse keep them on the panel a moment, and
-- the reach asked at the press measured only distance: the press said "thanks"
-- to a corpse while the game refused the cast.
for _, case in ipairs({
	{ label = "held, Bert queued", bert = true },
	{ label = "the fuse, nobody else", bert = false },
}) do
	Mock.reset()
	local scenario = "core20: a press on somebody just dead says nothing (" .. case.label .. ")"
	local ANNA = "Anna Aim"
	local units = { nameplate1 = { "Anna", "Aim" } }
	if case.bert then units.nameplate2 = { "Bert", "Beside" } end
	local restoreUnits = strangers(units)
	local realDead = UnitIsDeadOrGhost
	local corpse = false
	local function deadOrGhost(unit)
		if corpse and unit == "nameplate1" then return true end
		return realDead(unit)
	end
	with(scenario, { UnitIsDeadOrGhost = deadOrGhost }, function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		local speech = ns.db.profile.speech
		speech.enabled = true
		speech.onlyWhenReturning = true
		speech.channel = "SAY"
		speech.phrases = "Thanks for the buff, {name}!"
		owe(ns, ANNA)
		ns.Prompt:InvalidateMacro()
		ns.addon:Tick()
		local button = ns.Prompt:GetButton()
		local before = button:GetAttribute("macrotext1")
		if not (before and before:find(ANNA, 1, true) and before:find("/say", 1, true)) then
			fail(scenario, "SKIPPED -- Anna was not armed with the line: " .. flat(before))
			return
		end
		corpse = true
		Mock.advance(0.4)
		ns.addon:Tick()
		if ns.Prompt:PanelName() ~= ANNA and not (ns.Prompt:Showing() and ns.Prompt:Showing().name == ANNA) then
			fail(scenario, "SKIPPED -- the panel let go of Anna at once")
			return
		end
		Mock.advance(0.3)
		local ran = pressButton(ns)
		if ran and ran:find("/say", 1, true) then
			fail(scenario, "a press on somebody who just died said the line: " .. flat(ran))
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ core20-11
-- The client's "Unknown", for a name it has not loaded yet, is nobody.
--
-- Filed as a person, it was owed for a buff whoever cast it, offered for ten
-- seconds as a passer-by while the real person waited behind it, and armed as
-- "/target Unknown", which finds nobody and leaves the /cast to whoever is
-- targeted.
Mock.reset()
do
	local scenario = "core20: a favour from a name not loaded yet is filed under nobody"
	local units = { nameplate1 = { "Unknown" } }
	local restoreUnits = strangers(units)
	with(scenario, nil, function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		ns.db.profile.sources.strangers = false
		H.primeAuras(ns)
		favourFrom(ns, "nameplate1", 1459, 4101)
		if ns.owed.Unknown then
			fail(scenario, "a buff from a name the client had not loaded was owed to \"Unknown\"")
		end
		ns.addon:Tick()
		local macro = ns.Prompt:GetButton():GetAttribute("macrotext1")
		if macro and macro:find("/target Unknown", 1, true) then
			fail(scenario, "the prompt was armed at \"Unknown\": " .. flat(macro))
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

Mock.reset()
do
	local scenario = "core20: a passer-by whose name has not loaded is not offered as Unknown"
	local units = { nameplate1 = { "Unknown" } }
	local restoreUnits = strangers(units)
	with(scenario, nil, function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		ns.addon:Tick()
		if entryFor(ns, "Unknown") then
			fail(scenario, "somebody whose name had not loaded was offered as \"Unknown\"")
		end
		units.nameplate1 = { "Cora", "Cast" }
		Mock.advance(0.4)
		ns.addon:Tick()
		local showing = ns.Prompt:Showing()
		local name = type(showing) == "table" and showing.name or nil
		if name ~= "Cora Cast" then
			fail(scenario, "once her name loaded the panel showed " .. tostring(name) .. ", not Cora")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()
