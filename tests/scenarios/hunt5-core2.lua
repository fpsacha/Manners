-- Core.lua fixes from the fifth bug hunt, second half of the file: a late
-- refusal meeting the never-offer list, a rebuff after every buff ran out, the
-- tokenless fallback after a loading screen, a damaged settings file, what is
-- said about a favour or an unlock in a fight, the snooze's clock, requests
-- answered buff by buff, talent buffs asked of your own class, and requests in
-- other languages (questions, long sentences, words inside words, negation).
--
-- Every scenario name starts with "core2:" so the mutations in
-- tests/mutations/hunt5-core2.py can name the one that has to catch them.
--
-- Failures name a message by its place in its list rather than quoting it: the
-- console these run in on Windows cannot print Chinese or Korean.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

local ANNA = "Anna Aim"

local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "UnitInParty", "UnitInSubgroup",
	"GetNumGroupMembers", "C_Spell", "strcmputf8i", "GetCVar", "GetGameTime", "time", "date" }
local original = {}
for _, name in ipairs(TOUCHED) do original[name] = rawget(_G, name) end

-- Runs one scenario with `globals` in place and puts them all back, whether it
-- finished or threw. A throw is a failure of that scenario, named.
local function with(scenario, globals, body)
	for name, value in pairs(globals or {}) do rawset(_G, name, value) end
	local ok, err = pcall(body)
	for _, name in ipairs(TOUCHED) do rawset(_G, name, original[name]) end
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function said()
	return table.concat(Mock.printed, "\n")
end

local function guarded(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

local function entryFor(ns, name)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.name == name then return entry end
	end
	return nil
end

-- One chat line as the client delivers it, the GUID twelfth.
local function hear(ns, event, text, sender, guid)
	ns.addon[event](ns.addon, event, text, sender, "Common", "", "", "", 0, 0, "", 0, 1, guid)
end

-- The prompt settled and only requests switched on as a source.
local function ready(ns, scenario)
	freshPrompt(ns, scenario)
	local db = ns.db.profile
	db.sources.asked = true
	db.sources.strangers = false
	db.sources.group = false
end

-- The ids of a buff out of Buffs.lua, from a copy loaded for nothing else.
local function ranksOf(class, key)
	local probe = load("core2: reading the buff table")
	local buff = probe and probe.FindBuff(class, key)
	return buff and buff.ranks or {}
end

-- A class that knows exactly these buffs, by key.
local function knowing(class, keys)
	local known = {}
	for _, key in ipairs(keys) do
		for _, id in ipairs(ranksOf(class, key)) do known[id] = true end
	end
	local fn = function(id) return known[id] == true end
	return { IsSpellKnown = fn, IsPlayerSpell = fn }
end

-- The prompt armed at `entry` and pressed, and the game reporting the cast
-- going out with a cast guid on it, which is what a late refusal names.
local function pressWithGuid(ns, entry, spellId, guid)
	local button = ns.Prompt:GetButton()
	Mock.advance(1)
	ns.pendingClick = nil
	ns.Prompt:InvalidateMacro()
	ns.Prompt:ApplyTarget(entry)
	local post = button.scripts.PostClick
	if post then pcall(post, button, "LeftButton", true) end
	if not ns.pendingClick then return false end
	ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, guid, spellId)
	return true
end

-- ------------------------------------------------------------------ core2-1
-- A shift-right-click after the press that repaid somebody finds no debt to
-- let go, lists them and says they will not be offered again. A refusal of
-- that press arriving a moment later put the debt back, and owed people are
-- exempt from the list, so they were offered again once the skip ran out.
Mock.reset()
do
	local scenario = "core2: a late refusal does not bring back somebody just never-offered"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
	local ns = load(scenario)
	if ns then
		freshPrompt(ns, scenario)
		ns.db.char.ledger = nil
		ns.Ledger.Load()
		local s = ns.db.char.ledger
		H.primeAuras(ns)
		H.favourFrom(ns, "nameplate1", 1459, 4101)
		local entry = H.inQueue(ns)[ANNA]
		if not (ns.owed[ANNA] and entry) then
			fail(scenario, "SKIPPED -- Anna is not owed and offered")
		elseif not pressWithGuid(ns, entry, 1459, "Cast-7") or ns.owed[ANNA] then
			fail(scenario, "SKIPPED -- the press did not settle her favour")
		else
			ns.PutOnNeverList(ANNA)
			Mock.advance(0.5)
			ns.addon:UNIT_SPELLCAST_FAILED(nil, "player", "Cast-7", 1459)
			if ns.owed[ANNA] then
				fail(scenario, "the refusal put back the debt of somebody just put on the never-offer list")
			end
			local row
			for i = #s.entries, 1, -1 do
				local e = s.entries[i]
				if e.kind == "received" and e.name == ANNA then row = e break end
			end
			if not row then
				fail(scenario, "her favour has no ledger row")
			elseif row.state ~= "letgo" or row.why ~= "never" then
				fail(scenario, "her ledger row reads " .. tostring(row.state) .. "/" .. tostring(row.why)
					.. ", not let go for the never-offer list")
			end
			Mock.advance(13)
			ns.addon:Tick()
			if H.inQueue(ns)[ANNA] then
				fail(scenario, "she is offered again after the skip ran out")
			end
		end
		guarded(scenario, ns)
	end
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ core2-2
-- The only buff running out (or death taking every buff) reads as nothing
-- while the baseline holds something, which the scan doubts and so never
-- rewrites the previous reading. The buff recast under the number it had was
-- then taken for the one already filed, and the favour was lost. The same aura
-- handed back with the same end is still not a favour.
for _, case in ipairs({
	{ label = "a later end", ends = 3000, favour = true },
	{ label = "the same end", ends = 2000, favour = false },
}) do
	Mock.reset()
	local scenario = "core2: a rebuff after the last buff ran out is a favour (" .. case.label .. ")"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
	local ns = load(scenario)
	if ns then
		freshPrompt(ns, scenario)
		Mock.auraCount = 0
		Mock.extraAura, Mock.extraAuraSpell = 4001, 1459
		Mock.extraAuraSource, Mock.extraAuraUntil = "nameplate1", 2000
		ns.ResetAuraBaseline()
		H.primeAuras(ns)
		wipe(ns.owed)
		if not ns.auraScan.primed then
			fail(scenario, "SKIPPED -- the baseline never settled")
		else
			Mock.extraAura = false
			for _ = 1, 3 do
				Mock.advance(1)
				ns.addon:UNIT_AURA(nil, "player")
			end
			if ns.auraScan.doubt ~= "empty" then
				fail(scenario, "SKIPPED -- the scans after it ran out read as " .. tostring(ns.auraScan.doubt))
			else
				Mock.extraAura, Mock.extraAuraUntil = 4001, case.ends
				Mock.printed = {}
				ns.addon:UNIT_AURA(nil, "player")
				if case.favour then
					if not ns.owed[ANNA] then
						fail(scenario, "the rebuff under its old number was not taken for a favour")
					end
					if not said():find("buffed you", 1, true) then
						fail(scenario, "nothing was said about the rebuff")
					end
				elseif ns.owed[ANNA] then
					fail(scenario, "the same aura handed back with the same end was taken for a favour")
				end
			end
		end
		guarded(scenario, ns)
	end
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ core2-3
-- Buffing you proves a stranger was in casting range, which is why somebody
-- with no token is offered for a grace window. A loading screen leaves them
-- behind: the favour is kept, but not offered on that evidence. A /reload
-- moves nobody, and a favour noticed after the loading screen is fresh.
for _, case in ipairs({
	{ label = "a loading screen", args = { false, false }, offered = false },
	{ label = "a reload", args = { false, true }, offered = true },
	{ label = "a favour after the loading screen", args = { false, false }, offered = true,
		after = true },
}) do
	Mock.reset()
	local scenario = "core2: a stranger left behind by a loading screen is not offered (" .. case.label .. ")"
	with(scenario, {
		UnitInParty = function() return false end,
		UnitInSubgroup = function() return false end,
		GetNumGroupMembers = function() return 0 end,
	}, function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		local name = "Zed Wanderer"
		if not case.after then owe(ns, name) end
		Mock.advance(10)
		ns.addon:PLAYER_ENTERING_WORLD(nil, case.args[1], case.args[2])
		if case.after then
			Mock.advance(1)
			owe(ns, name)
		end
		local entry = entryFor(ns, name)
		if case.offered and not entry then
			fail(scenario, "the tokenless favour is not offered")
		elseif not case.offered and entry then
			fail(scenario, "a stranger who buffed you before the loading screen is offered at priority "
				.. tostring(entry.priority))
		end
		if not ns.owed[name] then
			fail(scenario, "the favour itself was let go")
		end
		guarded(scenario, ns)
	end)
end
Mock.reset()

-- ------------------------------------------------------------------ core2-4
-- A settings file holding a string where a section of the profile should be a
-- table made the clamp throw in OnInitialize: nothing after it ran, and the
-- logout flush wrote the empty debts over the saved ones.
for _, section in ipairs({ "speech", "timing" }) do
	Mock.reset()
	local scenario = "core2: a damaged profile section does not stop the addon (" .. section .. ")"
	local first = load(scenario)
	if first then
		first.addon:OnInitialize()
		Mock.sv.profile[section] = "x"
		Mock.sv.char.debts = { ["Yorick Vane"] = { expires = time() + 60, at = time(), class = "PRIEST" } }
		local ns = load(scenario)
		if ns then
			local commands = {}
			ns.addon.RegisterChatCommand = function(_, command) commands[command] = true end
			local ok, err = pcall(ns.addon.OnInitialize, ns.addon)
			if not ok then
				fail(scenario, "OnInitialize threw: " .. tostring(err))
			end
			local repaired = ns.db and ns.db.profile[section]
			if type(repaired) ~= "table" then
				fail(scenario, "the section is still " .. type(repaired))
			elseif section == "speech" and repaired.channel ~= "SAY" then
				fail(scenario, "the repaired speech section says in " .. tostring(repaired.channel))
			elseif section == "timing" and type(repaired.reciprocateWindow) ~= "number" then
				fail(scenario, "the repaired timing section has no window")
			end
			if not ns.owed["Yorick Vane"] then
				fail(scenario, "the saved debt was not restored")
			end
			if not commands.manners then
				fail(scenario, "/manners was never registered")
			end
			local shutdown = Mock.dbCallbacks["OnDatabaseShutdown"]
			if shutdown then
				pcall(function() shutdown.target[shutdown.method](shutdown.target) end)
			end
			if not (type(Mock.sv.char.debts) == "table" and Mock.sv.char.debts["Yorick Vane"]) then
				fail(scenario, "the saved debts were gone after the logout flush")
			end
			-- A profile switch to a damaged profile goes through the same clamp.
			Mock.sv.profile[section] = "x"
			local refreshed = pcall(ns.addon.RefreshConfig, ns.addon, "OnProfileChanged")
			if not refreshed or type(ns.db.profile[section]) ~= "table" then
				fail(scenario, "RefreshConfig did not repair the section")
			end
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ core2-5
-- A favour done mid-fight was said to be "on the prompt" while the prompt
-- could not show until the fight ended.
for _, fighting in ipairs({ true, false }) do
	Mock.reset()
	local scenario = "core2: a favour in a fight is offered once it ends ("
		.. (fighting and "in a fight" or "out of one") .. ")"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
	local ns = load(scenario)
	if ns then
		freshPrompt(ns, scenario)
		ns.db.profile.sources.strangers = false
		ns.db.profile.sources.group = false
		ns.addon:Tick()
		H.primeAuras(ns)
		if fighting then
			ns.addon:PLAYER_REGEN_DISABLED()
			Mock.inCombat = true
		end
		local text = H.favourFrom(ns, "nameplate1", 1459, 4101)
		if not ns.owed[ANNA] then
			fail(scenario, "SKIPPED -- no favour was filed")
		elseif fighting then
			if not text:find("offered once this fight ends", 1, true) then
				fail(scenario, "the line does not say it is offered after the fight: " .. text)
			end
			if text:find("returning the favour is on the prompt", 1, true) then
				fail(scenario, "the line says the favour is on the prompt in a fight: " .. text)
			end
		elseif not text:find("returning the favour is on the prompt", 1, true) then
			fail(scenario, "out of a fight the line no longer says it is on the prompt: " .. text)
		end
		Mock.inCombat = false
		guarded(scenario, ns)
	end
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ core2-6
-- /manners unlock in a fight said a press still casts what the fight froze
-- when nothing was armed, while the panel and the launcher said nothing is.
for _, armed in ipairs({ false, true }) do
	Mock.reset()
	local scenario = "core2: unlocking in a fight says whether anything is armed ("
		.. (armed and "armed" or "nothing armed") .. ")"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
	local ns = load(scenario)
	if ns then
		freshPrompt(ns, scenario)
		ns.db.profile.sources.strangers = false
		ns.db.profile.sources.group = false
		if armed then owe(ns, ANNA) end
		ns.addon:Tick()
		local macro = ns.Prompt:GetButton():GetAttribute("macrotext1")
		if armed ~= (type(macro) == "string" and macro ~= "") then
			fail(scenario, "SKIPPED -- the button is not " .. (armed and "armed" or "disarmed"))
		else
			ns.addon:PLAYER_REGEN_DISABLED()
			Mock.inCombat = true
			Mock.printed = {}
			ns.addon:HandleSlash("unlock")
			local text = said()
			if armed and not text:find("a press still casts", 1, true) then
				fail(scenario, "an armed prompt unlocked in a fight: " .. text)
			elseif not armed and (text:find("a press still casts", 1, true)
				or not text:find("nothing is armed", 1, true)) then
				fail(scenario, "nothing is armed and chat says: " .. text)
			end
		end
		Mock.inCombat = false
		guarded(scenario, ns)
	end
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ core2-7
-- The snooze's end was printed in the PC's time while the minimap clock shows
-- the realm's unless Local Time is ticked.
for _, case in ipairs({
	{ label = "realm time, 24-hour", localTime = "0", military = "1", want = "15:55" },
	{ label = "realm time, 12-hour", localTime = "0", military = "0", want = "3:55 PM" },
	{ label = "local time", localTime = "1", military = "1", want = "21:55" },
}) do
	Mock.reset()
	local scenario = "core2: the snooze ends on the minimap clock (" .. case.label .. ")"
	local wall = 21 * 3600 + 40 * 60
	with(scenario, {
		GetCVar = function(name)
			if name == "timeMgrUseLocalTime" then return case.localTime end
			if name == "timeMgrUseMilitaryTime" then return case.military end
			return nil
		end,
		GetGameTime = function() return 15, 40 end,
		time = function() return wall end,
		-- The two shapes SnoozeEndsAt asks for, on a UTC wall clock.
		date = function(format, at)
			at = at or wall
			local h, m = math.floor(at / 3600) % 24, math.floor(at / 60) % 60
			if format == "%H:%M" then return ("%02d:%02d"):format(h, m) end
			if format == "%I:%M %p" then
				local twelve = h % 12
				if twelve == 0 then twelve = 12 end
				return ("%02d:%02d %s"):format(twelve, m, h < 12 and "AM" or "PM")
			end
			return "12:00:00"
		end,
	}, function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		Mock.printed = {}
		ns.StartSnooze(15)
		local at = ns.SnoozeEndsAt()
		if at ~= case.want then
			fail(scenario, "the snooze ends at " .. tostring(at) .. ", not " .. case.want)
		end
		if not said():find(case.want, 1, true) then
			fail(scenario, "the snooze line does not say " .. case.want .. ": " .. said())
		end
		ns.StopSnooze(true)
		guarded(scenario, ns)
	end)
end
Mock.reset()

-- ------------------------------------------------------------------ core2-8
-- A buff landing closed the whole request, whatever it was: an owed asker's
-- favour took away what she asked for, and a request for two buffs was closed
-- by the first.
do
	local scenario = "core2: a request is answered buff by buff (owed asker)"
	Mock.reset()
	Mock.class = "PRIEST"
	local globals = knowing("PRIEST", { "fortitude", "spirit", "shadow" })
	Mock.unitClass = "MAGE"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
	with(scenario, globals, function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario)
		owe(ns, ANNA)
		hear(ns, "CHAT_MSG_SAY", "shadow protection please", ANNA, "Player-1-nameplate1")
		local entry = entryFor(ns, ANNA)
		if not (entry and entry.reason == "owed" and entry.buff.key ~= "shadow") then
			fail(scenario, "SKIPPED -- Anna is not offered another buff as a favour ("
				.. tostring(entry and entry.reason) .. ", " .. tostring(entry and entry.buff.key) .. ")")
			return
		end
		if not H.pressAndSend(ns, entry, entry.buff.ranks[1]) or ns.owed[ANNA] then
			fail(scenario, "SKIPPED -- the press did not settle her favour")
			return
		end
		Mock.advance(15)
		ns.addon:Tick()
		local after = H.inQueue(ns)[ANNA]
		if not (after and after.reason == "asked" and after.buff.key == "shadow") then
			fail(scenario, "after her favour was returned she is offered "
				.. (after and (tostring(after.reason) .. " " .. tostring(after.buff.key)) or "nothing")
				.. ", not the Shadow Protection she asked for")
		end
		guarded(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

do
	local scenario = "core2: a request is answered buff by buff (two buffs asked for)"
	Mock.reset()
	Mock.class = "PRIEST"
	local globals = knowing("PRIEST", { "fortitude", "spirit", "shadow" })
	Mock.unitClass = "MAGE"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
	with(scenario, globals, function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario)
		hear(ns, "CHAT_MSG_SAY", "power word fortitude and divine spirit please", ANNA, "Player-1-nameplate1")
		local entry = entryFor(ns, ANNA)
		if not (entry and entry.reason == "asked") then
			fail(scenario, "SKIPPED -- Anna is not offered what she asked for")
			return
		end
		local first = entry.buff.key
		local other = first == "fortitude" and "spirit" or "fortitude"
		if not H.pressAndSend(ns, entry, entry.buff.ranks[1]) then
			fail(scenario, "SKIPPED -- the press on Anna was not recorded")
			return
		end
		Mock.advance(15)
		ns.addon:Tick()
		local after = H.inQueue(ns)[ANNA]
		if not (after and after.reason == "asked" and after.buff.key == other) then
			fail(scenario, "after " .. first .. " landed she is offered "
				.. (after and (tostring(after.reason) .. " " .. tostring(after.buff.key)) or "nothing")
				.. ", not the " .. other .. " she also asked for")
		end
		guarded(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- "buffs please" stands after the first buff lands, and the next one she
-- lacks is offered; the one she now carries is not.
do
	local scenario = "core2: a request is answered buff by buff (buffs please)"
	Mock.reset()
	Mock.class = "PRIEST"
	local globals = knowing("PRIEST", { "fortitude", "spirit", "shadow" })
	Mock.unitClass = "MAGE"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
	with(scenario, globals, function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario)
		hear(ns, "CHAT_MSG_SAY", "buffs please", ANNA, "Player-1-nameplate1")
		local entry = entryFor(ns, ANNA)
		if not (entry and entry.reason == "asked") then
			fail(scenario, "SKIPPED -- Anna is not offered anything after asking")
			return
		end
		local first = entry.buff.key
		if not H.pressAndSend(ns, entry, entry.buff.ranks[1]) then
			fail(scenario, "SKIPPED -- the press on Anna was not recorded")
			return
		end
		-- She carries it now, in every rank.
		Mock.held = {}
		for _, id in ipairs(entry.buff.ranks) do Mock.held[id] = true end
		Mock.advance(15)
		ns.addon:Tick()
		local after = H.inQueue(ns)[ANNA]
		if not (after and after.reason == "asked" and after.buff.key ~= first) then
			fail(scenario, "after " .. first .. " landed she is offered "
				.. (after and (tostring(after.reason) .. " " .. tostring(after.buff.key)) or "nothing")
				.. ", not another buff she lacks")
		end
		guarded(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ core2-9
-- Somebody of your own class casts the baseline buffs themselves, but not a
-- talent buff they lack: a paladin asking a Kings paladin for Kings was taken
-- for a passer-by. A same-class "buff pls" or a baseline buff is still nothing.
do
	local scenario = "core2: your own class asking for a talent buff is heard"
	Mock.reset()
	Mock.class = "PALADIN"
	local globals = knowing("PALADIN", { "kings", "wisdom" })
	Mock.unitClass = "PALADIN"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
	with(scenario, globals, function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario)
		local kings = ns.FindBuff("PALADIN", "kings")
		if not kings then
			fail(scenario, "SKIPPED -- no Kings in the buff table")
			return
		end
		kings.talent = true
		for i, case in ipairs({
			{ text = "kings pls", want = "kings" },
			{ text = "wisdom pls" },
			{ text = "buff pls" },
		}) do
			hear(ns, "CHAT_MSG_SAY", case.text, ANNA, "Player-1-nameplate1")
			local entry = entryFor(ns, ANNA)
			if case.want and not (entry and entry.reason == "asked" and entry.buff.key == case.want) then
				fail(scenario, ("message %d from a paladin: offered %s, not %s"):format(i,
					entry and tostring(entry.buff.key) or "nothing", case.want))
			elseif not case.want and entry then
				fail(scenario, ("message %d from a paladin was taken for a request (%s)"):format(i,
					tostring(entry.buff.key)))
			end
			Mock.advance(61)
		end
		guarded(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

do
	local scenario = "core2: your own class asking for a baseline buff is not heard"
	Mock.reset()
	Mock.unitClass = "MAGE"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
	with(scenario, {}, function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario)
		hear(ns, "CHAT_MSG_SAY", "anyone need int?", ANNA, "Player-1-nameplate1")
		if entryFor(ns, ANNA) then
			fail(scenario, "a mage asking a mage for int was taken for a request")
		end
		guarded(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ core2-10..13
-- Requests in the client's own language, through the real chat handler: what
-- is a question about the buff, a sentence that only mentions it, a name found
-- inside another word, and a request that says no.
local function inLanguage(scenario, locale, class, key, name, yes, no)
	Mock.reset()
	Mock.locale = locale
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
	local ids = {}
	for _, id in ipairs(ranksOf(class, key)) do ids[id] = true end
	local globals = knowing(class, { key })
	Mock.class = class
	local realSpell = C_Spell
	globals.C_Spell = setmetatable({
		GetSpellName = function(id)
			if ids[id] then return name end
			return realSpell.GetSpellName(id)
		end,
	}, { __index = realSpell })
	with(scenario, globals, function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario)
		if ns.BuffName(ns.FindBuff(class, key)) ~= name then
			fail(scenario, locale .. ": SKIPPED -- the spell is not named as the client names it")
			return
		end
		for i, text in ipairs(yes) do
			hear(ns, "CHAT_MSG_SAY", text, ANNA, "Player-1-nameplate1")
			local anna = entryFor(ns, ANNA)
			if not (anna and anna.reason == "asked") then
				fail(scenario, ("%s: request %d was not heard as one"):format(locale, i))
			end
			Mock.advance(61)
		end
		for i, text in ipairs(no) do
			hear(ns, "CHAT_MSG_SAY", text, ANNA, "Player-1-nameplate1")
			if entryFor(ns, ANNA) then
				fail(scenario, ("%s: non-request %d was taken for a request"):format(locale, i))
			end
			Mock.advance(61)
		end
		guarded(scenario, ns)
	end)
	restoreUnits()
	Mock.reset()
end

-- A question about the buff, which only English openers used to recognise.
inLanguage("core2: a question about the buff is not a request (deDE)", "deDE", "MAGE", "intellect",
	"Arkane Intelligenz",
	{ "Arkane Intelligenz?" },
	{ "Ist Arkane Intelligenz gut?", "Wer hat Arkane Intelligenz?" })
inLanguage("core2: a question about the buff is not a request (zhCN)", "zhCN", "MAGE", "intellect",
	"奥术智慧",
	{ "奥术智慧？" },
	{ "奥术智慧有用吗？" })
inLanguage("core2: a question about the buff is not a request (koKR)", "koKR", "MAGE", "intellect",
	"신비한 지능",
	{ "신비한 지능 주세요", "신비한 지능?" },
	{ "신비한 지능 좋아요?" })

-- A Chinese sentence is one "word", so the cap on words never applied; and
-- 求 inside 要求 is not a please.
inLanguage("core2: a long Chinese sentence is not a request", "zhCN", "MAGE", "intellect",
	"奥术智慧",
	{ "请给我奥术智慧", "求奥术智慧", "奥术智慧？" },
	{ "你们觉得这个版本的奥术智慧怎么样？", "请问大家觉得奥术智慧在这个版本还值得点吗",
		"法师的奥术智慧对这个副本的要求很高" })
inLanguage("core2: the Chinese please inside another word is not a please", "zhCN", "MAGE", "intellect",
	"奥术智慧",
	{ "求奥术智慧" },
	{ "奥术智慧要求很高", "奥术智慧的需求" })

-- Korean puts spaces between words, and builds other words out of the same
-- syllables as a short buff name.
inLanguage("core2: a Korean name is not found inside another word", "koKR", "DRUID", "thorns",
	"가시",
	{ "가시 주세요" },
	{ "어디 가시나요?", "이쪽으로 가시면 돼요?", "먼저 가시죠, 부탁해요" })

-- Saying no in the other shipped languages.
inLanguage("core2: a request that says no is not a request (deDE)", "deDE", "MAGE", "intellect",
	"Arkane Intelligenz",
	{ "Arkane Intelligenz bitte" },
	{ "Bitte keine Arkane Intelligenz", "Keine Arkane Intelligenz bitte" })
inLanguage("core2: a request that says no is not a request (zhCN)", "zhCN", "MAGE", "intellect",
	"奥术智慧",
	{ "请给我奥术智慧" },
	{ "请不要给我奥术智慧", "别给我奥术智慧，求你了", "求你了别给我奥术智慧" })
inLanguage("core2: a request that says no is not a request (koKR)", "koKR", "MAGE", "intellect",
	"신비한 지능",
	{ "신비한 지능 주세요" },
	{ "신비한 지능 걸지 말아 주세요", "신비한 지능 걸지 마세요, 부탁해요" })
inLanguage("core2: a request that says no is not a request (itIT)", "itIT", "MAGE", "intellect",
	"Intelletto Arcano",
	{ "Intelletto Arcano per favore" },
	{ "per favore non Intelletto Arcano" })
inLanguage("core2: a request that says no is not a request (ptBR)", "ptBR", "MAGE", "intellect",
	"Intelecto Arcano",
	{ "intelecto arcano por favor" },
	{ "por favor não me dê intelecto arcano", "nao intelecto arcano por favor" })
