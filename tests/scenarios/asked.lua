-- People who ask for a buff in chat: which messages count, from whom, on which
-- channels, for how long, and what they are offered.
--
-- Called by scenarios.lua with the addon directory and its helpers. The chat
-- events are driven by calling the addon's handlers with the arguments the
-- client passes them -- text, sender, and the sender's GUID twelfth -- so what
-- is tested is the whole path from the event to the queue. Every global a
-- scenario replaces is put back after it, by rawset, so the mock's own
-- lazily-built namespaces (C_Spell) come back as they were.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe
local pressAndSend, findOption = H.pressAndSend, H.findOption

local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "UnitInParty", "GetNumGroupMembers",
	"C_Spell", "issecretvalue", "strcmputf8i", "UnitPowerMax", "MenuUtil" }
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

local function noErrors(scenario, ns)
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

-- One chat line as the client delivers it: the event name, the text, the
-- sender, then languageName, channelName, target, flags, zoneChannelID,
-- channelIndex, channelBaseName, languageID, lineID -- and the GUID.
local function hear(ns, event, text, sender, guid)
	ns.addon[event](ns.addon, event, text, sender, "Common", "", "", "", 0, 0, "", 0, 1, guid)
end

-- A loaded addon with the prompt settled and only this source switched on, so
-- anybody in the queue is there because they asked.
local function ready(ns, scenario)
	freshPrompt(ns, scenario)
	local db = ns.db.profile
	db.sources.asked = true
	db.sources.strangers = false
	db.sources.group = false
end

-- The ids of a buff straight out of Buffs.lua, from a copy of the addon loaded
-- for nothing else, so `knowing` can be handed to `with` before the one under
-- test loads.
local function ranksOf(class, key)
	local probe = load("reading the buff table")
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

local CHANNELS = { "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
	"CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_INSTANCE_CHAT",
	"CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_WHISPER" }

-- ------------------------------------------------------------------ asked 1
-- Every channel a request can arrive in puts the asker on the prompt, and the
-- request runs out after a minute.
Mock.reset()
do
	local scenario = "a request in any channel is offered, for a minute"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
	with(scenario, {}, function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario)
		if entryFor(ns, "Anna Aim") then
			fail(scenario, "SKIPPED -- Anna is offered before she asks for anything")
			return
		end
		for _, event in ipairs(CHANNELS) do
			-- Called directly below, so the handler working says nothing about
			-- whether the client was ever asked to send the event.
			if not Mock.registeredEvents[event] then
				fail(scenario, event .. " is never registered, so nothing said there is heard")
			end
			hear(ns, event, "int pls", "Anna Aim", "Player-1-nameplate1")
			local anna = entryFor(ns, "Anna Aim")
			if not anna then
				fail(scenario, event .. ": asking for it did not put Anna on the prompt")
			elseif anna.reason ~= "asked" or anna.priority ~= 1.5 then
				fail(scenario, ("%s: Anna is on it as %s (%s), not as somebody who asked")
					:format(event, tostring(anna.reason), tostring(anna.priority)))
			elseif anna.buff.key ~= "intellect" then
				fail(scenario, event .. ": offered " .. tostring(anna.buff.key))
			end
			Mock.advance(59)
			if not entryFor(ns, "Anna Aim") then
				fail(scenario, event .. ": the request ran out before its minute was up")
			end
			Mock.advance(2)
			if entryFor(ns, "Anna Aim") then
				fail(scenario, event .. ": the request was still offered after a minute")
			end
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ asked 2
-- The names players use for a mage's buff, and "buff" on its own, are heard.
Mock.reset()
do
	local scenario = "the common names for a buff are recognised"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
	with(scenario, {}, function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario)
		for _, text in ipairs({
			"int pls", "Int?", "AI?", "ai", "INT PLEASE", "can I get int", "could i have AI",
			"arcane intellect please", "any mage for brilliance?", "anyone got int",
			"mage int", "need int", "int plz ty", "buff pls", "buffs?", "can I get a buff",
			"|cff71d5ff|Hspell:1459:0|h[Arcane Intellect]|h|r pls",
		}) do
			hear(ns, "CHAT_MSG_SAY", text, "Anna Aim", "Player-1-nameplate1")
			local anna = entryFor(ns, "Anna Aim")
			if not (anna and anna.reason == "asked") then
				fail(scenario, ("%q was not heard as asking for a buff"):format(text))
			end
			Mock.advance(61)
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ asked 3
-- Only whole words, and only messages that ask.
--
-- "intro" is not "int", and somebody saying their int is low, thanking
-- somebody for it, saying no to it or asking about it has asked for nothing.
Mock.reset()
do
	local scenario = "only whole words and real requests count"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
	with(scenario, {}, function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario)
		for _, text in ipairs({
			"intro pls", "paint please", "mint?", "ai-generated?x", "my int is too low",
			"thanks for the int", "ty for int!", "no int pls", "don't need int",
			"is int worth it?", "int is great", "nice buffs", "who buffed me?",
			"i was wondering whether anyone here could spare some int please",
			"fort pls", "kings?",
			-- The same rules with the buff's full name, which the rule on
			-- nicknames below does not reach: a question about it, a no, and
			-- a mention that asks for nothing.
			"is arcane intellect worth it?", "who has arcane intellect?",
			"no arcane intellect please", "arcane intellect is great",
		}) do
			hear(ns, "CHAT_MSG_SAY", text, "Anna Aim", "Player-1-nameplate1")
			local anna = entryFor(ns, "Anna Aim")
			if anna then
				fail(scenario, ("%q put Anna on the prompt as %s"):format(text, tostring(anna.reason)))
			end
			Mock.advance(61)
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ asked 4
-- A secret is never compared, matched or kept.
--
-- Chat text and senders can come back as secret values on this client. Two
-- shapes of one here. A secret that throws on everything a secret throws on --
-- comparison, length, concatenation, indexing -- so a single look at it fails
-- the scenario. And a secret that is a string, which is what the client's are:
-- type() says "string" and only issecretvalue says otherwise, so a request read
-- out of one would show up in the queue rather than as a throw. A secret GUID
-- is only a GUID nobody may read: the request still stands on the sender's
-- name.
Mock.reset()
do
	local scenario = "a secret message or sender is not a request"
	local function refuse() error("a secret value was looked at", 2) end
	local hostile = setmetatable({}, { __index = refuse, __newindex = refuse, __len = refuse,
		__concat = refuse, __eq = refuse, __lt = refuse, __le = refuse, __call = refuse,
		__tostring = function() return "<hostile secret>" end })
	local SECRET_STRINGS = { ["int pls "] = true, ["Anna-Withheld"] = true }
	local realSecret = issecretvalue
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
	with(scenario, {
		issecretvalue = function(v)
			return rawequal(v, hostile) or (type(v) == "string" and SECRET_STRINGS[v] == true)
				or realSecret(v)
		end,
	}, function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario)
		hear(ns, "CHAT_MSG_SAY", hostile, "Anna Aim", "Player-1-nameplate1")
		hear(ns, "CHAT_MSG_WHISPER", "int pls", hostile, "Player-1-nameplate1")
		hear(ns, "CHAT_MSG_PARTY", Mock.SECRET, "Anna Aim", "Player-1-nameplate1")
		hear(ns, "CHAT_MSG_SAY", "int pls ", "Anna Aim", "Player-1-nameplate1")
		hear(ns, "CHAT_MSG_YELL", "int pls", "Anna-Withheld", "Player-1-nameplate1")
		if entryFor(ns, "Anna Aim") then
			fail(scenario, "a message that could not be read put Anna on the prompt")
		end
		if ns.askScan.unreadable ~= 5 or ns.askScan.noted ~= 0 then
			fail(scenario, ("expected five unreadable and none noted, got %d and %d")
				:format(ns.askScan.unreadable, ns.askScan.noted))
		end
		hear(ns, "CHAT_MSG_SAY", "int pls", "Anna Aim", hostile)
		local anna = entryFor(ns, "Anna Aim")
		if not (anna and anna.reason == "asked") then
			fail(scenario, "a request whose GUID was secret was thrown away with it")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ asked 5
-- Nothing you say yourself is a request.
--
-- By GUID where there is one, and by your whole name where there is not. The
-- nameplate carries your name so that a request taken for somebody else's
-- would be visible in the queue, not only in a counter.
Mock.reset()
do
	local scenario = "your own messages are not requests"
	local restoreUnits = strangers({ nameplate1 = { "Mort", "Defrette" } })
	with(scenario, {}, function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario)
		hear(ns, "CHAT_MSG_PARTY", "int pls", "Somebody", "Player-1-player")
		hear(ns, "CHAT_MSG_SAY", "int pls", "Mort Defrette", nil)
		hear(ns, "CHAT_MSG_RAID", "buffs?", "Mort-Firemaw", nil)
		if entryFor(ns, "Mort Defrette") then
			fail(scenario, "your own message put somebody with your name on the prompt")
		end
		if ns.askScan.own ~= 3 or ns.askScan.noted ~= 0 then
			fail(scenario, ("expected three of your own and none noted, got %d and %d")
				:format(ns.askScan.own, ns.askScan.noted))
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ asked 6
-- Somebody the game cannot see waits for a unit, and only for their minute.
--
-- A whisper can come from across the zone. Nothing is offered by name alone:
-- they are offered once a nameplate (or any unit the scan walks) turns out to
-- be them, and not at all if that happens after the request has run out.
Mock.reset()
do
	local scenario = "a request waits for the asker to be seen"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" },
		nameplate2 = { "Zed", "Far" }, nameplate3 = { "Yan", "Late" } })
	with(scenario, {}, function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario)
		ns.nameplateUnits.nameplate2 = nil
		ns.nameplateUnits.nameplate3 = nil
		hear(ns, "CHAT_MSG_WHISPER", "int pls", "Zed Far", "Player-1-nameplate2")
		hear(ns, "CHAT_MSG_WHISPER", "ai?", "Yan Late", nil)
		if entryFor(ns, "Zed Far") or entryFor(ns, "Yan Late") then
			fail(scenario, "somebody no unit reaches was offered by name alone")
		end
		Mock.advance(30)
		ns.nameplateUnits.nameplate2 = true
		local zed = entryFor(ns, "Zed Far")
		if not (zed and zed.reason == "asked") then
			fail(scenario, "Zed was not offered when his nameplate came into view")
		end
		Mock.advance(31)
		ns.nameplateUnits.nameplate3 = true
		if entryFor(ns, "Yan Late") then
			fail(scenario, "Yan turned up after his request ran out and was offered anyway")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ asked 7
-- A buff that lands serves the request, and only theirs.
Mock.reset()
do
	local scenario = "a buff that lands serves the request"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bert", "Beside" } })
	with(scenario, {}, function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario)
		hear(ns, "CHAT_MSG_SAY", "int pls", "Anna Aim", "Player-1-nameplate1")
		hear(ns, "CHAT_MSG_SAY", "ai?", "Bert Beside", "Player-1-nameplate2")
		local anna = entryFor(ns, "Anna Aim")
		if not anna then
			fail(scenario, "SKIPPED -- Anna was not offered after asking")
			return
		end
		if not pressAndSend(ns, anna, 1459) then
			fail(scenario, "SKIPPED -- the press on Anna was not recorded")
			return
		end
		-- Past the retry block the press wrote, well inside the minute.
		Mock.advance(15)
		if entryFor(ns, "Anna Aim") then
			fail(scenario, "Anna was offered again after the buff she asked for landed")
		end
		if not entryFor(ns, "Bert Beside") then
			fail(scenario, "buffing Anna served Bert's request too")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ asked 8
-- Fights. A request standing when one starts, and a whisper made in one, are
-- offered after it, for a minute, once. Anything else said in a fight is
-- tactics -- "ai pls" in /party there is an interrupt -- and is let go.
--
-- Anna asks before the fight, Bert says "ai pls" in /party during it and Cara
-- whispers "int pls" during it. After the fight Anna and Cara have their
-- minute and Bert has nothing. Then a second pull half a minute later lasts
-- longer than what is left of that minute: neither is held through it again,
-- so chained pulls cannot keep one "int pls" standing all dungeon long.
Mock.reset()
do
	local scenario = "a request in a fight is offered after it"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bert", "Beside" },
		nameplate3 = { "Cara", "Crew" } })
	with(scenario, {}, function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario)
		local function fight(seconds)
			-- The client sends this just before lockdown begins.
			ns.addon:PLAYER_REGEN_DISABLED()
			Mock.inCombat = true
			Mock.advance(seconds)
			Mock.inCombat = false
			ns.addon:PLAYER_REGEN_ENABLED()
		end
		hear(ns, "CHAT_MSG_SAY", "int pls", "Anna Aim", "Player-1-nameplate1")
		Mock.advance(50)
		ns.addon:PLAYER_REGEN_DISABLED()
		Mock.inCombat = true
		hear(ns, "CHAT_MSG_PARTY", "ai pls", "Bert Beside", "Player-1-nameplate2")
		hear(ns, "CHAT_MSG_WHISPER", "int pls", "Cara Crew", "Player-1-nameplate3")
		Mock.advance(120)
		Mock.inCombat = false
		ns.addon:PLAYER_REGEN_ENABLED()
		if not entryFor(ns, "Anna Aim") then
			fail(scenario, "Anna asked before the fight and was let go during it")
		end
		if not entryFor(ns, "Cara Crew") then
			fail(scenario, "Cara whispered during the fight and was not offered after it")
		end
		local bert = entryFor(ns, "Bert Beside")
		if bert and bert.reason == "asked" then
			fail(scenario, "\"ai pls\" said in /party during a fight was taken for a request")
		end
		if ns.askScan.fight ~= 1 then
			fail(scenario, ("expected one message let go for the fight, counted %d")
				:format(ns.askScan.fight))
		end
		Mock.advance(59)
		if not (entryFor(ns, "Anna Aim") and entryFor(ns, "Cara Crew")) then
			fail(scenario, "the minute after the fight was cut short")
		end
		Mock.advance(2)
		if entryFor(ns, "Anna Aim") or entryFor(ns, "Cara Crew") then
			fail(scenario, "a request held through a fight never ran out after it")
		end

		-- Chained pulls: asked, held through one, then a second begins before
		-- the minute after the first is out, and ends after it would have.
		Mock.advance(61)
		hear(ns, "CHAT_MSG_SAY", "int pls", "Anna Aim", "Player-1-nameplate1")
		Mock.advance(10)
		fight(40)
		Mock.advance(30)
		fight(45)
		if entryFor(ns, "Anna Aim") then
			fail(scenario, "a request was held through a second fight and outlived both")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ asked 9
-- Only the buffs this class casts are heard.
--
-- A priest reading "int pls" has been asked for nothing; "fort pls" and
-- "stam?" are Fortitude. A mage reading "fort pls" is covered by asked 3.
Mock.reset()
do
	local scenario = "a class only hears requests for its own buffs"
	Mock.class = "PRIEST"
	-- Not a priest: one would cast it themselves, and asked 15 says so.
	Mock.unitClass = "WARRIOR"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
	with(scenario, knowing("PRIEST", { "fortitude" }), function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario)
		hear(ns, "CHAT_MSG_SAY", "int pls", "Anna Aim", "Player-1-nameplate1")
		if entryFor(ns, "Anna Aim") then
			fail(scenario, "a priest was asked for Arcane Intellect and offered something")
		end
		for _, text in ipairs({ "fort pls", "stam?", "pw:f please", "buff pls" }) do
			Mock.advance(61)
			hear(ns, "CHAT_MSG_SAY", text, "Anna Aim", "Player-1-nameplate1")
			local anna = entryFor(ns, "Anna Aim")
			if not (anna and anna.reason == "asked" and anna.buff.key == "fortitude") then
				fail(scenario, ("%q did not offer Fortitude: %s"):format(text,
					anna and tostring(anna.buff.key) or "nothing"))
			end
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ asked 10
-- A paladin: the loose words, a buff asked for by name, and a pin.
--
-- "might be lag?" asks for nothing; "might pls" asks for Might. Somebody asking
-- for Kings is offered Kings rather than whatever Automatic would reach for --
-- unless the paladin has pinned Might, which means only ever Might.
Mock.reset()
do
	local scenario = "a paladin is offered what was asked for, within its pin"
	Mock.class = "PALADIN"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
	with(scenario, knowing("PALADIN", { "might", "kings" }), function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario)
		hear(ns, "CHAT_MSG_SAY", "might be lag?", "Anna Aim", "Player-1-nameplate1")
		if entryFor(ns, "Anna Aim") then
			fail(scenario, "\"might be lag?\" was taken for a request")
		end
		local cases = { { "might pls", "might" }, { "bok?", "kings" }, { "kings", "kings" } }
		for _, case in ipairs(cases) do
			Mock.advance(61)
			hear(ns, "CHAT_MSG_SAY", case[1], "Anna Aim", "Player-1-nameplate1")
			local anna = entryFor(ns, "Anna Aim")
			if not (anna and anna.buff.key == case[2]) then
				fail(scenario, ("%q offered %s, not %s"):format(case[1],
					anna and tostring(anna.buff.key) or "nothing", case[2]))
			end
		end
		ns.db.profile.buff.choice = "might"
		Mock.advance(61)
		hear(ns, "CHAT_MSG_SAY", "kings pls", "Anna Aim", "Player-1-nameplate1")
		if entryFor(ns, "Anna Aim") then
			fail(scenario, "a paladin pinned to Might was put on the prompt for Kings")
		end
		Mock.advance(61)
		hear(ns, "CHAT_MSG_SAY", "buff pls", "Anna Aim", "Player-1-nameplate1")
		local anna = entryFor(ns, "Anna Aim")
		if not (anna and anna.buff.key == "might") then
			fail(scenario, "\"buff pls\" to a paladin pinned to Might offered "
				.. (anna and tostring(anna.buff.key) or "nothing"))
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ asked 11
-- The spell's own name, as the client spells it.
--
-- A German client asked "Arkane Intelligenz bitte", a Chinese one asked
-- "求奥术智慧" -- which has no spaces in it at all, so the name is found inside
-- the message -- and a Russian one asked in lower case for a name the client
-- capitalises, which only the client's own case folding can match. The English
-- words still work on a German client.
--
-- Failures name a message by its place in the list rather than quoting it: the
-- console these run in on Windows cannot print Chinese, and a runner that
-- throws while reporting a failure hides which one it was.
Mock.reset()
do
	local scenario = "a request in the client's own language is heard"
	local function foldCh(s) return (s:gsub("Ч", "ч"):gsub("Н", "н"):gsub("П", "п")) end
	local cases = {
		{ locale = "deDE", name = "Arkane Intelligenz",
			yes = { "Arkane Intelligenz bitte", "arkane intelligenz?", "int pls" },
			no = { "Intelligenz ist toll", "Arkane Intelligenz nicht bitte" } },
		{ locale = "zhCN", name = "奥术智慧",
			yes = { "求奥术智慧", "奥术智慧", "奥术智慧？" },
			no = { "奥术智慧很好" } },
		{ locale = "ruRU", name = "Чародейский интеллект",
			-- The last of each: a please, and a no, with a capital at the start
			-- of the sentence, which Words leaves as typed outside A to Z.
			yes = { "чародейский интеллект пж", "Чародейский интеллект?",
				"Пожалуйста, чародейский интеллект" },
			no = { "чародейский интеллект не нужен пж", "Не нужен чародейский интеллект?" },
			-- The client's own comparison, folding the capitals in play.
			fold = function(a, b) return foldCh(a) == foldCh(b) and 0 or 1 end },
	}
	for _, case in ipairs(cases) do
		Mock.reset()
		Mock.locale = case.locale
		local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
		local realSpell = C_Spell
		local spell = setmetatable({
			GetSpellName = function(id)
				if id == 10157 or id == 1459 then return case.name end
				return realSpell.GetSpellName(id)
			end,
		}, { __index = realSpell })
		with(scenario, { C_Spell = spell, strcmputf8i = case.fold }, function()
			local ns = load(scenario)
			if not ns then return end
			ready(ns, scenario)
			if ns.BuffName(ns.FindBuff("MAGE", "intellect")) ~= case.name then
				fail(scenario, case.locale .. ": SKIPPED -- the spell is not named as the"
					.. " client names it")
				return
			end
			for i, text in ipairs(case.yes) do
				hear(ns, "CHAT_MSG_SAY", text, "Anna Aim", "Player-1-nameplate1")
				local anna = entryFor(ns, "Anna Aim")
				if not (anna and anna.reason == "asked") then
					fail(scenario, ("%s: request %d was not heard as one"):format(case.locale, i))
				end
				Mock.advance(61)
			end
			for i, text in ipairs(case.no) do
				hear(ns, "CHAT_MSG_SAY", text, "Anna Aim", "Player-1-nameplate1")
				if entryFor(ns, "Anna Aim") then
					fail(scenario, ("%s: non-request %d was taken for a request")
						:format(case.locale, i))
				end
				Mock.advance(61)
			end
			noErrors(scenario, ns)
		end)
		restoreUnits()
	end
end
Mock.reset()

-- ------------------------------------------------------------------ asked 12
-- Where a request stands: after a favour, before your group, on the prompt
-- with its own words -- and nowhere at all while the source is off or the
-- asker is on the never-offer list.
Mock.reset()
do
	local scenario = "somebody who asked comes after a favour and before your group"
	local restoreUnits = strangers({ party1 = { "Cara", "Crew" },
		nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bert", "Beside" } })
	with(scenario, {
		GetNumGroupMembers = function() return 2 end,
		UnitInParty = function(unit) return unit == "party1" end,
	}, function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		local db = ns.db.profile
		if db.sources.asked ~= false then
			fail(scenario, "people who ask are listened to before anybody switched it on")
		end
		hear(ns, "CHAT_MSG_SAY", "int pls", "Bert Beside", "Player-1-nameplate2")
		local bert = entryFor(ns, "Bert Beside")
		if bert and bert.reason == "asked" then
			fail(scenario, "a request was heard with the source switched off")
		end

		db.sources.asked = true
		db.sources.strangers = false
		owe(ns, "Anna Aim")
		hear(ns, "CHAT_MSG_SAY", "int pls", "Bert Beside", "Player-1-nameplate2")
		local names = {}
		for _, entry in ipairs(ns.BuildQueue()) do
			names[#names + 1] = entry.name .. "/" .. tostring(entry.reason)
		end
		local got = table.concat(names, ", ")
		if got ~= "Anna Aim/owed, Bert Beside/asked, Cara Crew/group" then
			fail(scenario, "expected the favour, then the request, then your group: " .. got)
		end

		-- On the prompt, in its own words and colour.
		ns.owed["Anna Aim"] = nil
		ns.addon:Tick()
		bert = entryFor(ns, "Bert Beside")
		if ns.Prompt:PanelName() ~= "Bert Beside" then
			fail(scenario, "SKIPPED -- the prompt shows " .. tostring(ns.Prompt:PanelName()))
		else
			local line = bert and ns.Prompt:ReasonText(bert)
			if line ~= "asked for it" then
				fail(scenario, "the prompt's second line reads " .. tostring(line))
			end
			local button = ns.Prompt:GetButton()
			if button.scripts.OnEnter then button.scripts.OnEnter(button) end
			local tip = table.concat(Mock.tooltip, "\n")
			if not tip:find("Asked you for it in chat.", 1, true) then
				fail(scenario, "the tooltip does not say they asked: " .. tip)
			end
			local r, g, b = ns.Prompt:AccentColor("asked")
			local nr, ng, nb = ns.Prompt:AccentColor("nearby")
			if r == nr and g == ng and b == nb then
				fail(scenario, "somebody who asked is painted in the passer-by's colour")
			end
		end

		-- /manners debug says who is waiting, and where they asked.
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		local said = table.concat(Mock.printed, "\n")
		if not (said:find("Bert Beside", 1, true) and said:find("/say", 1, true)) then
			fail(scenario, "/manners debug does not list the request: " .. said)
		end

		-- The never-offer list applies to a request as it does to everybody
		-- but a favour owed.
		ns.NeverOffer("Bert Beside")
		if entryFor(ns, "Bert Beside") then
			fail(scenario, "somebody on the never-offer list was offered because they asked")
		end
		ns.AllowAgain("Bert Beside")

		-- Off again: the debug line says so, and nobody is offered as asking.
		db.sources.asked = false
		bert = entryFor(ns, "Bert Beside")
		if bert and bert.reason == "asked" then
			fail(scenario, "a standing request was still offered after the source was switched off")
		end
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		said = table.concat(Mock.printed, "\n")
		if not said:find("not listening for requests", 1, true) then
			fail(scenario, "/manners debug does not say requests are off: " .. said)
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ asked 13
-- The switch and its wording are on the Who to buff tab and do what they say.
Mock.reset()
do
	local scenario = "the Who to buff tab switches requests on"
	with(scenario, {}, function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		local who = ns.optionsTable and ns.optionsTable.args.who
		local toggle = who and H.findOption(ns.optionsTable, "asked")
		local wording = who and H.findOption(ns.optionsTable, "reasonAsked")
		if not (toggle and toggle.type == "toggle" and wording and wording.type == "input") then
			fail(scenario, "the switch or its wording is missing from the Who to buff tab")
			return
		end
		toggle.set({ "asked" }, true)
		if ns.db.profile.sources.asked ~= true or toggle.get({ "asked" }) ~= true then
			fail(scenario, "the switch did not reach the profile")
		end
		wording.set({ "reasonAsked" }, "wants {buff}")
		if ns.db.profile.prompt.reasonAsked ~= "wants {buff}" then
			fail(scenario, "the wording did not reach the profile")
		end
		noErrors(scenario, ns)
	end)
end
Mock.reset()

-- ------------------------------------------------------------------ asked 14
-- What somebody who asked is offered: what they asked for whether or not it
-- does them any good, in the request's own words even when their auras cannot
-- be read -- and nothing once they have it.
--
-- Anna is a warrior here, with no mana bar, and "Hide buffs that do nothing
-- for them" is on: she asked for Intellect, so she is offered it. With her
-- auras unreadable the prompt still says she asked, not "unverified". And once
-- she is wearing it -- another mage answered first, or you cast it by hand --
-- she is off the prompt, although nothing was clicked to serve her request.
Mock.reset()
do
	local scenario = "somebody who asked is offered it until they have it"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
	with(scenario, {
		UnitPowerMax = function(unit, ...)
			if unit == "nameplate1" then return 0 end
			return original.UnitPowerMax(unit, ...)
		end,
	}, function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario)
		ns.db.profile.filters.relevantOnly = true
		hear(ns, "CHAT_MSG_SAY", "int pls", "Anna Aim", "Player-1-nameplate1")
		local anna = entryFor(ns, "Anna Aim")
		if not (anna and anna.reason == "asked" and anna.buff.key == "intellect") then
			fail(scenario, "a warrior who asked for Intellect was not offered it")
		end

		Mock.advance(4)
		Mock.auraReadRefuse = { [1459] = "secret" }
		anna = entryFor(ns, "Anna Aim")
		if not anna then
			fail(scenario, "somebody who asked was dropped when their auras could not be read")
		elseif anna.known ~= nil then
			fail(scenario, "SKIPPED -- the aura read was not refused: " .. tostring(anna.known))
		else
			local line = ns.Prompt:ReasonText(anna)
			if line ~= "asked for it" then
				fail(scenario, "with their auras unreadable the prompt reads " .. tostring(line))
			end
		end
		Mock.auraReadRefuse = nil

		Mock.advance(4)
		Mock.held = { [1459] = true }
		anna = entryFor(ns, "Anna Aim")
		if anna then
			fail(scenario, ("Anna is wearing what she asked for and is still offered it, as %s")
				:format(tostring(anna.reason)))
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ asked 15
-- Chat that is not asking for a buff, though it names one.
--
-- An interrupt call, loot talk, class talk and Portuguese "aí" all use a
-- nickname for Intellect. Beside a nickname only small words may stand, so
-- none of these is a request -- in /party, where they are said. Another mage
-- offering theirs ("anyone need int?") is asking nothing of you either. And a
-- druid's "mark" is a raid marker in group chat, where the looser words never
-- count, and needs a please or to stand alone anywhere else.
Mock.reset()
do
	local scenario = "tactical chat is not a request"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
	with(scenario, {}, function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario)
		for _, text in ipairs({
			"can someone int the caster", "need int on caster", "int the healer pls",
			"whos on int?", "who has int?", "kick/int pls", "who needs int?",
			"any int plate drop?", "need int ring", "can i roll on the int ring?",
			"anyone selling int gear", "rogues need a buff", "can you buff arcane pls",
			"any buffs on the boss?", "e ai?", "ta ai?", "vc ta ai?", "can ai do this?",
		}) do
			hear(ns, "CHAT_MSG_PARTY", text, "Anna Aim", "Player-1-nameplate1")
			local anna = entryFor(ns, "Anna Aim")
			if anna then
				fail(scenario, ("%q put Anna on the prompt as %s"):format(text, tostring(anna.reason)))
			end
			Mock.advance(61)
		end

		-- A mage offering theirs. Heard, and the request stands -- it is who
		-- said it that decides, so the same line from a priest is a request.
		Mock.unitClass = "MAGE"
		hear(ns, "CHAT_MSG_PARTY", "anyone need int?", "Anna Aim", "Player-1-nameplate1")
		if entryFor(ns, "Anna Aim") then
			fail(scenario, "another mage offering Intellect was taken for asking for it")
		end
		Mock.unitClass = "PRIEST"
		local anna = entryFor(ns, "Anna Aim")
		if not (anna and anna.reason == "asked") then
			fail(scenario, "SKIPPED -- \"anyone need int?\" from a priest was not a request")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()
do
	local scenario = "tactical chat is not a request"
	Mock.class = "DRUID"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
	with(scenario, knowing("DRUID", { "motw" }), function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario)
		local cases = {
			{ "CHAT_MSG_PARTY", "mark pls", false }, { "CHAT_MSG_PARTY", "can someone mark?", false },
			{ "CHAT_MSG_RAID", "mark skull pls", false }, { "CHAT_MSG_INSTANCE_CHAT", "mark?", false },
			{ "CHAT_MSG_SAY", "can someone mark?", false }, { "CHAT_MSG_SAY", "mark the caster pls", false },
			{ "CHAT_MSG_PARTY", "motw pls", true }, { "CHAT_MSG_SAY", "mark pls", true },
		}
		for _, case in ipairs(cases) do
			hear(ns, case[1], case[2], "Anna Aim", "Player-1-nameplate1")
			local anna = entryFor(ns, "Anna Aim")
			local asked = anna and anna.reason == "asked" and anna.buff.key == "motw"
			if case[3] and not asked then
				fail(scenario, ("a druid did not hear %q in %s as a request"):format(case[2], case[1]))
			elseif not case[3] and anna then
				fail(scenario, ("a druid heard %q in %s as a request"):format(case[2], case[1]))
			end
			Mock.advance(61)
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ asked 16
-- One standing request per person, and thirty at most.
--
-- Asking again replaces the first request: one line for Anna in /manners
-- debug, and the minute starts again. Thirty-one people asking at once keep
-- the thirty most recent.
Mock.reset()
do
	local scenario = "requests are one per person, thirty at most"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
	with(scenario, {}, function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario)
		-- Lines about a request, which start "asked in"; the first line is the
		-- counters.
		local function linesWith(text)
			local n = 0
			for _, line in ipairs(ns.RequestLines()) do
				if line:find("^asked in ") and line:find(text, 1, true) then n = n + 1 end
			end
			return n
		end
		hear(ns, "CHAT_MSG_SAY", "int pls", "Anna Aim", "Player-1-nameplate1")
		Mock.advance(40)
		hear(ns, "CHAT_MSG_WHISPER", "ai?", "Anna Aim", "Player-1-nameplate1")
		if linesWith("Anna Aim") ~= 1 then
			fail(scenario, ("asking twice left %d requests standing for Anna"):format(linesWith("Anna Aim")))
		end
		Mock.advance(30)
		if not entryFor(ns, "Anna Aim") then
			fail(scenario, "asking again did not start the minute again")
		end

		Mock.advance(61)
		for i = 1, 31 do
			hear(ns, "CHAT_MSG_SAY", "int pls", ("Ask%02d Er"):format(i), nil)
		end
		if linesWith("asked in ") ~= 30 then
			fail(scenario, ("thirty-one people asking left %d requests"):format(linesWith("asked in ")))
		end
		if linesWith("Ask01 Er") ~= 0 or linesWith("Ask31 Er") ~= 1 then
			fail(scenario, "the request let go for the thirty-first was not the oldest")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ asked 17
-- Two people with the same name are told apart by their GUIDs.
--
-- A whisper from another Anna Aim -- another realm, the same name -- is not a
-- request from the one standing beside you, and does not replace hers.
Mock.reset()
do
	local scenario = "two people with one name are told apart by GUID"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
	with(scenario, {}, function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario)
		hear(ns, "CHAT_MSG_WHISPER", "int pls", "Anna Aim", "Player-2-faraway")
		if entryFor(ns, "Anna Aim") then
			fail(scenario, "another Anna's whisper put the one beside you on the prompt")
		end
		hear(ns, "CHAT_MSG_SAY", "int pls", "Anna Aim", "Player-1-nameplate1")
		if not entryFor(ns, "Anna Aim") then
			fail(scenario, "SKIPPED -- the Anna beside you was not offered when she asked")
		end
		local standing = 0
		for _, line in ipairs(ns.RequestLines()) do
			if line:find("Anna Aim", 1, true) then standing = standing + 1 end
		end
		if standing ~= 2 then
			fail(scenario, ("two Annas asked and %d requests stand"):format(standing))
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ asked 18
-- Nothing is heard while Manners is switched off, and nothing heard then turns
-- up when it is switched back on.
Mock.reset()
do
	local scenario = "nothing is heard while Manners is off"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
	with(scenario, {}, function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario)
		ns.db.profile.enabled = false
		hear(ns, "CHAT_MSG_SAY", "int pls", "Anna Aim", "Player-1-nameplate1")
		ns.db.profile.enabled = true
		if ns.askScan.heard ~= 0 or entryFor(ns, "Anna Aim") then
			fail(scenario, "a request made while Manners was off was kept for when it came back on")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ asked 19
-- Your target comes first, somebody who asked included.
--
-- With "your target first" on, targeting somebody who asked puts them above a
-- favour owed, as it does anybody targeted and missing the buff -- still
-- reading "asked for it". With it off they are where a request goes.
Mock.reset()
do
	local scenario = "a targeted asker comes first"
	local restoreUnits = strangers({ target = { "Anna", "Aim" }, nameplate2 = { "Bert", "Beside" } })
	with(scenario, {}, function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario)
		local db = ns.db.profile
		db.priority.target = true
		owe(ns, "Bert Beside")
		hear(ns, "CHAT_MSG_SAY", "int pls", "Anna Aim", "Player-1-target")
		local function order()
			local names = {}
			for _, entry in ipairs(ns.BuildQueue()) do
				names[#names + 1] = ("%s/%s/%s"):format(entry.name, tostring(entry.reason),
					tostring(entry.priority))
			end
			return table.concat(names, ", ")
		end
		local got = order()
		if got ~= "Anna Aim/asked/0, Bert Beside/owed/1" then
			fail(scenario, "targeting somebody who asked did not put them first: " .. got)
		end
		db.priority.target = false
		got = order()
		if got ~= "Bert Beside/owed/1, Anna Aim/asked/1.5" then
			fail(scenario, "with the target not first, a request is not where it belongs: " .. got)
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ------------------------------------------------------------------ asked 20
-- A saved wording for a request that is not text is put back at login, as
-- every other wording is: a number there throws on every repaint.
Mock.reset()
do
	local scenario = "a broken saved wording for a request is repaired"
	with(scenario, {}, function()
		if not H.savedProfile(scenario, function(profile)
			profile.prompt = profile.prompt or {}
			profile.prompt.reasonAsked = 5
		end) then
			fail(scenario, "SKIPPED -- no saved profile to break")
			return
		end
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		if ns.db.profile.prompt.reasonAsked ~= "asked for it" then
			fail(scenario, "a number saved as the wording survived login: "
				.. tostring(ns.db.profile.prompt.reasonAsked))
		end
	end)
end
Mock.reset()

-- ------------------------------------------------------------------ asked 21
-- The warning that nothing is switched on counts this source: with only it on,
-- the prompt can appear, and the page does not say it never will.
Mock.reset()
do
	local scenario = "the empty-sources warning counts requests"
	with(scenario, {}, function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		local warning = findOption(ns.optionsTable, "emptyWarning")
		if not (warning and type(warning.hidden) == "function") then
			fail(scenario, "SKIPPED -- no warning on the page")
			return
		end
		local s = ns.db.profile.sources
		-- Yourself off as well, which counts on its own (self.lua).
		s.owed, s.group, s.strangers, s.asked, s.self = false, false, false, true, false
		if not warning.hidden() then
			fail(scenario, "with only requests on, the page says the prompt will never appear")
		end
		s.asked = false
		if warning.hidden() then
			fail(scenario, "SKIPPED -- the warning stays hidden with everything off")
		end
		noErrors(scenario, ns)
	end)
end
Mock.reset()

-- ------------------------------------------------------------------ asked 22
-- The launcher says why somebody who asked is there: its tooltip and its
-- Who's next read "asked for it", as the prompt does, and not "nearby".
Mock.reset()
do
	local scenario = "the launcher says who asked"
	local function newMenu(text)
		local d = { text = text, items = {} }
		local function add(item)
			d.items[#d.items + 1] = item
			return item
		end
		function d:CreateTitle(t) return add(newMenu(t)) end
		function d:CreateDivider() return add(newMenu()) end
		function d:CreateButton(t) return add(newMenu(t)) end
		function d:CreateCheckbox(t) return add(newMenu(t)) end
		function d:CreateRadio(t) return add(newMenu(t)) end
		function d:SetEnabled() end
		function d:SetTooltip() end
		return d
	end
	local opened
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
	with(scenario, {
		MenuUtil = {
			CreateContextMenu = function(owner, generator)
				opened = newMenu()
				generator(owner, opened)
				return opened
			end,
		},
	}, function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario)
		hear(ns, "CHAT_MSG_SAY", "int pls", "Anna Aim", "Player-1-nameplate1")
		ns.addon:Tick()
		local broker = Mock.broker
		if not (broker and broker.OnTooltipShow and ns.Prompt:PanelName() == "Anna Aim") then
			fail(scenario, "SKIPPED -- no launcher, or Anna is not on the prompt")
			return
		end
		local lines = {}
		broker.OnTooltipShow({ AddLine = function(_, text) lines[#lines + 1] = tostring(text) end })
		local tip = table.concat(lines, "\n")
		if not tip:find("Anna Aim|r -- Arcane Intellect, asked for it", 1, true) then
			fail(scenario, "the launcher's tooltip does not say Anna asked: " .. tip)
		end
		broker.OnClick({}, "RightButton")
		local label
		for _, item in ipairs(opened and opened.items or {}) do
			if item.text == "Who's next" then
				for _, person in ipairs(item.items) do
					if tostring(person.text):find("^Anna Aim %-%- ") then label = person.text end
				end
			end
		end
		if not (label and label:find("(asked for it)", 1, true)) then
			fail(scenario, "Who's next does not say Anna asked: " .. tostring(label))
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()
