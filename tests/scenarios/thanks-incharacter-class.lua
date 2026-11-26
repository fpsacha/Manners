-- The In character thank-you for a class with nothing to give others.
-- GitHub issue 39: the In character thank-you lines "are available on my human
-- warlock but not my dwarf hunter". The lines were never missing (every people
-- and class has its thanks pools); the options window hid Start here's voice
-- choice, which leads What I say, from a class with nothing for others, and
-- that choice is where In character is picked. Such a class now has a voice
-- choice of its own (Options/Start.lua, Quick.THANKS): Stay silent, Just /thank
-- them, and In character, which loads the In character set and turns the
-- whispered thank-you on, and none of them touches the line said with a cast
-- (speech.*), which on a shared profile is another character's.
--
-- Every scenario name starts with "thanks-incharacter-class:" so the mutations
-- in tests/mutations/thanks-incharacter-class.py can name the one that has to
-- catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, primeAuras, favourFrom, findOption =
	H.strangers, H.freshPrompt, H.primeAuras, H.favourFrom, H.findOption

local TOUCHED = { "IsInInstance", "DoEmote", "SendChatMessage", "C_ChatInfo" }
local original = {}
for _, name in ipairs(TOUCHED) do original[name] = rawget(_G, name) end

local whispers = {}

-- One session: the class and race, one stranger on a nameplate, outdoors, a
-- fresh profile, and the baseline of your own buffs settled.
local function with(scenario, who, body)
	Mock.reset()
	Mock.nameplates = { "nameplate1" }
	Mock.class, Mock.playerRace = who.class, who.race
	whispers = {}
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
		primeAuras(ns)
		if not ns.auraScan.primed then
			fail(scenario, "SKIPPED -- the baseline never settled")
			return
		end
		ns.nameplateUnits.nameplate1 = true
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	undo()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, original[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local HUNTER = { class = "HUNTER", race = "Dwarf", label = "a dwarf hunter", gives = false }
local WARLOCK = { class = "WARLOCK", race = "Human", label = "a human warlock", gives = true }

local function keysOf(values)
	local out = {}
	for key in pairs(values) do out[#out + 1] = key end
	table.sort(out)
	return table.concat(out, ",")
end

-- The lines are there, for both: In character's pick for being buffed, many
-- times over, never nothing.
for _, who in ipairs({ HUNTER, WARLOCK }) do
	local scenario = "thanks-incharacter-class: " .. who.label .. " has In character thank-you lines"
	with(scenario, who, function(ns)
		if (ns.caps.hasClassBuffs == true) ~= who.gives then
			fail(scenario, "SKIPPED -- hasClassBuffs is " .. tostring(ns.caps.hasClassBuffs))
			return
		end
		local rp = ns.InCharacter
		if not (rp and rp.Pick) then fail(scenario, "SKIPPED -- no In character set") return end
		local misses = 0
		for _ = 1, 40 do
			local entry = { name = "Anna-Aim", short = "Anna", reason = "owed", inGroup = false }
			if not rp.Pick(entry, "w Anna-Aim", ns.MACRO_LIMIT) then misses = misses + 1 end
		end
		if misses > 0 then fail(scenario, ("%d of 40 thank-you picks gave no line"):format(misses)) end
	end)
end

-- The voice choice is there for both, with In character among the choices; for
-- the hunter it is the thanks alone.
for _, who in ipairs({ HUNTER, WARLOCK }) do
	local scenario = "thanks-incharacter-class: " .. who.label .. " can choose In character"
	with(scenario, who, function(ns)
		local voice = findOption(ns.optionsTable, "quickVoice")
		if not voice then fail(scenario, "SKIPPED -- no quickVoice control") return end
		if type(voice.hidden) == "function" and voice.hidden({ "quickVoice" }) then
			fail(scenario, "the voice choice is hidden for " .. who.label)
			return
		end
		local values = voice.values()
		if not values.incharacter then
			fail(scenario, "In character is not among " .. who.label .. "'s voice choices: " .. keysOf(values))
		end
		if not who.gives and keysOf(values) ~= "incharacter,silent,thank" then
			fail(scenario, "a class with nothing to give is offered more than the thanks: " .. keysOf(values))
		end
	end)
end

-- The pick: the whispered thank-you goes on with the In character set loaded,
-- and a class with nothing to give leaves the cast-line settings alone.
do
	local scenario = "thanks-incharacter-class: a hunter picks In character and is whispered a thank-you"
	with(scenario, HUNTER, function(ns)
		local db = ns.db.profile
		-- A shared profile: the priest's own line with a cast is on already.
		db.speech.enabled, db.speech.channel, db.speech.onlyWhenReturning = true, "WHISPER", true
		local voice = findOption(ns.optionsTable, "quickVoice")
		if not voice then fail(scenario, "SKIPPED -- no quickVoice control") return end
		voice.set({ "quickVoice" }, "incharacter")
		if voice.get({ "quickVoice" }) ~= "incharacter" then
			fail(scenario, "the voice reads " .. tostring(voice.get({ "quickVoice" })) .. " after picking In character")
		end
		if db.prompt.thankWhisper ~= true then
			fail(scenario, "choosing In character turned the whispered thank-you on for a class with nothing to give: it did not")
		end
		if not (ns.InCharacter and ns.InCharacter.Active(db.speech)) then
			fail(scenario, "the In character set was not loaded")
		end
		local speech = ("%s/%s/%s"):format(tostring(db.speech.enabled), tostring(db.speech.channel),
			tostring(db.speech.onlyWhenReturning))
		if speech ~= "true/WHISPER/true" then
			fail(scenario, "a hunter's voice choice left the line said with a cast alone: speech " .. speech)
		end
		local summary = ns.QuickSetup.VoiceSummary()
		if not summary:find("thank-you", 1, true) or summary:find("when you buff someone", 1, true) then
			fail(scenario, "a hunter's voice summary reads: " .. summary)
		end
		-- And it works: somebody buffs the dwarf, who whispers back in character.
		local spell = ns.BUFF_BY_ID and ns.BUFF_BY_ID[10938] and 10938 or 21562
		favourFrom(ns, "nameplate1", spell, 9801)
		Mock.runTimers(3)
		if #whispers ~= 1 then
			fail(scenario, ("%d thank-you whispers for one favour"):format(#whispers))
			return
		end
		local sent = whispers[1]
		if sent.channel ~= "WHISPER" or sent.target ~= ns.UnitFullName("nameplate1") or (sent.text or "") == "" then
			fail(scenario, "the whisper was " .. tostring(sent.channel) .. " to " .. tostring(sent.target)
				.. ": " .. tostring(sent.text))
		end
	end)
end

-- Turning off a whispered thank-you is a separate choice. It must not make
-- the hunter's In character voice choice disappear from the Manners menu.
do
	local scenario = "thanks-incharacter-class: turning off the whisper keeps hunter RP selected"
	with(scenario, HUNTER, function(ns)
		local db = ns.db.profile
		local voice = findOption(ns.optionsTable, "quickVoice")
		if not voice then fail(scenario, "SKIPPED -- no quickVoice control") return end
		voice.set({ "quickVoice" }, "incharacter")
		db.prompt.thankWhisper = false
		if voice.get({ "quickVoice" }) ~= "incharacter" then
			fail(scenario, ("turning off the whispered thank-you removed the In character choice (list=%s, whisper=%s, preset=%s, active=%s)")
				:format(tostring(voice.get({ "quickVoice" })), tostring(db.prompt.thankWhisper),
					tostring(db.speech.presetChoice),
					tostring(ns.InCharacter and ns.InCharacter.Active(db.speech))))
		end
		if ns.InCharacter and not ns.InCharacter.Active(db.speech) then
			fail(scenario, "turning off the whispered thank-you turned off In character")
		end
	end)
end

-- Stay silent and Just /thank them for such a class are about the thanks alone.
for _, key in ipairs({ "silent", "thank" }) do
	local scenario = "thanks-incharacter-class: a hunter's " .. key .. " leaves the line said with a cast alone"
	with(scenario, HUNTER, function(ns)
		local db = ns.db.profile
		db.speech.enabled, db.speech.channel = true, "WHISPER"
		db.prompt.thankWhisper = true
		local voice = findOption(ns.optionsTable, "quickVoice")
		if not voice then fail(scenario, "SKIPPED -- no quickVoice control") return end
		voice.set({ "quickVoice" }, key)
		if db.speech.enabled ~= true or db.speech.channel ~= "WHISPER" then
			fail(scenario, "a hunter's voice choice changed the line said with a cast: "
				.. tostring(db.speech.enabled) .. "/" .. tostring(db.speech.channel))
		end
		if db.prompt.thankWhisper ~= false then
			fail(scenario, "the whispered thank-you stayed on after " .. key)
		end
		if (db.prompt.thankEmote == true) ~= (key == "thank") then
			fail(scenario, "the /thank is " .. tostring(db.prompt.thankEmote) .. " after " .. key)
		end
		if voice.get({ "quickVoice" }) ~= key then
			fail(scenario, "the voice reads " .. tostring(voice.get({ "quickVoice" })) .. " after " .. key)
		end
	end)
end

-- A warlock's choice is the one it had: it also speaks with a cast.
do
	local scenario = "thanks-incharacter-class: a warlock's In character is the set it had"
	with(scenario, WARLOCK, function(ns)
		local db = ns.db.profile
		local voice = findOption(ns.optionsTable, "quickVoice")
		if not voice then fail(scenario, "SKIPPED -- no quickVoice control") return end
		voice.set({ "quickVoice" }, "incharacter")
		if db.speech.enabled ~= true or db.speech.presetChoice ~= "incharacter" then
			fail(scenario, "a warlock's In character does not speak with a cast")
		end
		if voice.get({ "quickVoice" }) ~= "incharacter" then
			fail(scenario, "the voice reads " .. tostring(voice.get({ "quickVoice" })))
		end
	end)
end
