-- Bug hunt: the thank-you and Quick setup's voice.
--
-- Every scenario name starts with "thanks-hunt:".

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, primeAuras, favourFrom, findOption =
	H.strangers, H.freshPrompt, H.primeAuras, H.favourFrom, H.findOption

-- Power Word: Fortitude.
local FORTITUDE = 10938

-- Stay silent with the whispered thank-you switched on earlier: the choice
-- reads as silent, so nothing may be whispered to the next person who buffs you.
do
	local scenario = "thanks-hunt: Stay silent whispers no thank-you"
	local TOUCHED = { "IsInInstance", "DoEmote", "SendChatMessage", "C_ChatInfo" }
	local original = {}
	for _, name in ipairs(TOUCHED) do original[name] = rawget(_G, name) end
	local whispers = {}
	Mock.reset()
	Mock.nameplates = { "nameplate1" }
	Mock.class = "ROGUE"
	rawset(_G, "IsInInstance", function() return false, "none" end)
	rawset(_G, "DoEmote", function() end)
	rawset(_G, "C_ChatInfo", nil)
	rawset(_G, "SendChatMessage", function(text, channel, _, target)
		whispers[#whispers + 1] = { text = text, channel = channel, target = target }
	end)
	local undo = strangers({ nameplate1 = { "Anna", "Aim" } })
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		local db = ns.db.profile
		db.prompt.thankWhisper = true
		local voice = findOption(ns.optionsTable, "quickVoice")
		if not voice then fail(scenario, "SKIPPED -- no quickVoice control") return end
		voice.set({ "quickVoice" }, "silent")
		if voice.get({ "quickVoice" }) ~= "silent" then
			fail(scenario, "SKIPPED -- the voice reads " .. tostring(voice.get({ "quickVoice" })))
			return
		end
		primeAuras(ns)
		if not ns.auraScan.primed then fail(scenario, "SKIPPED -- the baseline never settled") return end
		favourFrom(ns, "nameplate1", FORTITUDE, 9901)
		if #whispers ~= 0 then
			fail(scenario, ("Stay silent chosen, yet %d thank-you whispered: %s"):format(#whispers,
				tostring(whispers[1] and whispers[1].text)))
		end
		-- The whisper switched back on by hand: the summary may not say "Silent."
		db.prompt.thankWhisper = true
		local quick = ns.QuickSetup
		local summary = quick and quick.VoiceSummary() or ""
		if summary == "Silent." or not summary:find("thank-you", 1, true) then
			fail(scenario, "with the whispered thank-you on, the voice summary reads: " .. summary)
		end
	end)
	undo()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, original[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- A pasted settings line never switches on the whispered thank-you: it sends
-- chat to other players as the /thank does, which a paste may not switch on.
do
	local scenario = "thanks-hunt: a pasted line does not switch the whispered thank-you on"
	Mock.reset()
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		local db = ns.db.profile
		db.prompt.thankEmote, db.prompt.thankWhisper = true, true
		local theirs = ns.ExportSettings()
		db.prompt.thankEmote, db.prompt.thankWhisper = false, false
		local applied, message = ns.ImportSettings(theirs)
		if not applied then
			fail(scenario, "SKIPPED -- the string was refused: " .. tostring(message))
			return
		end
		if db.prompt.thankEmote ~= false then
			fail(scenario, "SKIPPED -- the /thank was switched on too, so the rule itself is gone")
		end
		if db.prompt.thankWhisper ~= false then
			fail(scenario, "a pasted line switched the whispered thank-you on; the import said: "
				.. tostring(message))
		elseif not tostring(message):find("whispering a thank-you", 1, true) then
			fail(scenario, "the import held the whispered thank-you off without a word: " .. tostring(message))
		end
	end)
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- /manners debug with the whisper alone on and "People who buff me" off: the
-- walk still watches (Favours.lua, watching), so the debug may not say it is
-- not watching, and the whisper that went should show by the name it went to.
do
	local scenario = "thanks-hunt: debug shows a whisper-only setup watching, and the whisper that went"
	local TOUCHED = { "IsInInstance", "DoEmote", "SendChatMessage", "C_ChatInfo" }
	local original = {}
	for _, name in ipairs(TOUCHED) do original[name] = rawget(_G, name) end
	local whispers = {}
	Mock.reset()
	Mock.nameplates = { "nameplate1" }
	Mock.class = "MAGE"
	rawset(_G, "IsInInstance", function() return false, "none" end)
	rawset(_G, "DoEmote", function() end)
	rawset(_G, "C_ChatInfo", nil)
	rawset(_G, "SendChatMessage", function(text, channel, _, target)
		whispers[#whispers + 1] = { text = text, channel = channel, target = target }
	end)
	local undo = strangers({ nameplate1 = { "Anna", "Aim" } })
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		local db = ns.db.profile
		db.prompt.thankWhisper = true
		db.prompt.thankEmote = false
		db.sources.owed = false
		primeAuras(ns)
		if not ns.auraScan.primed then fail(scenario, "SKIPPED -- the baseline never settled") return end
		favourFrom(ns, "nameplate1", FORTITUDE, 9701)
		if #whispers ~= 1 then fail(scenario, ("SKIPPED -- %d whispers went"):format(#whispers)) return end
		local L = ns.L
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		local said = table.concat(Mock.printed, "\n")
		local notWatching = L["not watching for favours -- |cffffd100People who buff me|r is switched off."]
		if said:find(notWatching, 1, true) then
			fail(scenario, "debug says it is not watching for favours while the whisper watches and just went")
		end
		if not said:find("Anna", 1, true) then
			fail(scenario, "debug has no line naming who was just whispered")
		end
	end)
	undo()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, original[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- A warrior with the whispered thank-you on, buffed by a stranger with
-- Fortitude: his shout reaches only his party, so nothing of his goes back
-- to her, and the thank-you is whispered.
do
	local scenario = "thanks-hunt: a warrior whispers a stranger who buffs him"
	local TOUCHED = { "IsInInstance", "DoEmote", "SendChatMessage", "C_ChatInfo", "IsSpellKnown", "IsPlayerSpell" }
	local original = {}
	for _, name in ipairs(TOUCHED) do original[name] = rawget(_G, name) end
	local whispers = {}
	Mock.reset()
	Mock.nameplates = { "nameplate1" }
	Mock.class = "WARRIOR"
	Mock.groupSize = 0
	rawset(_G, "IsInInstance", function() return false, "none" end)
	rawset(_G, "DoEmote", function() end)
	rawset(_G, "C_ChatInfo", nil)
	rawset(_G, "SendChatMessage", function(text, channel, _, target)
		whispers[#whispers + 1] = { text = text, channel = channel, target = target }
	end)
	local undo = strangers({ nameplate1 = { "Anna", "Aim" } })
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		local known = {}
		for _, id in ipairs(ns.FindBuff("WARRIOR", "battleshout").ranks) do known[id] = true end
		rawset(_G, "IsSpellKnown", function(id) return known[id] == true end)
		rawset(_G, "IsPlayerSpell", function(id) return known[id] == true end)
		freshPrompt(ns, scenario)
		local db = ns.db.profile
		db.prompt.thankWhisper = true
		db.prompt.thankEmote = false
		db.sources.owed = true
		primeAuras(ns)
		if not ns.auraScan.primed then fail(scenario, "SKIPPED -- the baseline never settled") return end
		Mock.printed = {}
		favourFrom(ns, "nameplate1", FORTITUDE, 9801)
		local said = table.concat(Mock.printed, " | ")
		if not said:find("Anna", 1, true) then
			fail(scenario, "SKIPPED -- the favour was not noticed: " .. said)
			return
		end
		if #whispers ~= 1 then
			fail(scenario, ("a warrior buffed by a stranger whispered %d thank-you; the line said: %s"):format(#whispers, said))
		end
	end)
	undo()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, original[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- Wait a moment before thanking: A's thank is waiting out its pause, B buffs
-- you, then A is gone when the pause ends. A is rightly not thanked, but B
-- must not have been passed over for a thank that never went.
do
	local scenario = "thanks-hunt: a favour during a pause whose thank never goes is still thanked"
	local TOUCHED = { "IsInInstance", "DoEmote", "SendChatMessage", "C_ChatInfo" }
	local original = {}
	for _, name in ipairs(TOUCHED) do original[name] = rawget(_G, name) end
	local emotes = {}
	Mock.reset()
	Mock.nameplates = { "nameplate1", "nameplate2" }
	Mock.class = "MAGE"
	rawset(_G, "IsInInstance", function() return false, "none" end)
	rawset(_G, "DoEmote", function(emote, target) emotes[#emotes + 1] = { emote, target } end)
	rawset(_G, "C_ChatInfo", nil)
	rawset(_G, "SendChatMessage", function() end)
	local undo = strangers({ nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bo", "Brisk" } })
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		local db = ns.db.profile
		db.prompt.thankEmote = true
		db.prompt.thankWhisper = false
		db.prompt.thankDelay = true
		primeAuras(ns)
		if not ns.auraScan.primed then fail(scenario, "SKIPPED -- the baseline never settled") return end
		local spell = ns.BUFF_BY_ID and ns.BUFF_BY_ID[FORTITUDE] and FORTITUDE or 21562
		local bo = ns.UnitFullName("nameplate2")
		favourFrom(ns, "nameplate1", spell, 9701)
		if #emotes ~= 0 then fail(scenario, "SKIPPED -- the pause did not hold the first thank") return end
		Mock.advance(0.3)
		favourFrom(ns, "nameplate2", spell, 9702)
		-- Anna rides off: her nameplate goes to somebody else.
		Mock.unitNames.nameplate1 = { "Zed", "Gone" }
		Mock.runTimers(3)
		Mock.runTimers(3)
		local log = ns.thankLog.skipped
		if #emotes == 0 then
			fail(scenario, ("nobody was thanked: Bo was passed over for a thank that never went (last skip: %s, %s)")
				:format(tostring(log and log.name), tostring(log and log.why)))
		elseif emotes[1][2] ~= "nameplate2" then
			fail(scenario, "the /thank went to " .. tostring(emotes[1][2]) .. ", not Bo " .. tostring(bo))
		end
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	undo()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, original[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end
