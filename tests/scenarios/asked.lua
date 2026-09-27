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
	"C_Spell", "issecretvalue", "strcmputf8i" }
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
	"CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_WHISPER" }

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
-- A request made in a fight, or standing when one starts, is offered after it.
Mock.reset()
do
	local scenario = "a request in a fight is offered after it"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bert", "Beside" } })
	with(scenario, {}, function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario)
		hear(ns, "CHAT_MSG_SAY", "int pls", "Anna Aim", "Player-1-nameplate1")
		Mock.advance(50)
		-- The client sends this just before lockdown begins.
		ns.addon:PLAYER_REGEN_DISABLED()
		Mock.inCombat = true
		hear(ns, "CHAT_MSG_PARTY", "ai pls", "Bert Beside", "Player-1-nameplate2")
		Mock.advance(120)
		Mock.inCombat = false
		ns.addon:PLAYER_REGEN_ENABLED()
		if not entryFor(ns, "Anna Aim") then
			fail(scenario, "Anna asked before the fight and was let go during it")
		end
		if not entryFor(ns, "Bert Beside") then
			fail(scenario, "Bert asked during the fight and was not offered after it")
		end
		Mock.advance(59)
		if not (entryFor(ns, "Anna Aim") and entryFor(ns, "Bert Beside")) then
			fail(scenario, "the minute after the fight was cut short")
		end
		Mock.advance(2)
		if entryFor(ns, "Anna Aim") or entryFor(ns, "Bert Beside") then
			fail(scenario, "a request held through a fight never ran out after it")
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
	local function foldCh(s) return (s:gsub("Ч", "ч")) end
	local cases = {
		{ locale = "deDE", name = "Arkane Intelligenz",
			yes = { "Arkane Intelligenz bitte", "arkane intelligenz?", "int pls" },
			no = { "Intelligenz ist toll", "Arkane Intelligenz nicht bitte" } },
		{ locale = "zhCN", name = "奥术智慧",
			yes = { "求奥术智慧", "奥术智慧", "奥术智慧？" },
			no = { "奥术智慧很好" } },
		{ locale = "ruRU", name = "Чародейский интеллект",
			yes = { "чародейский интеллект пж", "Чародейский интеллект?" },
			no = { "чародейский интеллект не нужен пж" },
			-- The client's own comparison, folding the one capital in play.
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
		local toggle = who and who.args.asked
		local wording = who and who.args.reasonAsked
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
