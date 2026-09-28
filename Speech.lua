-- Manners -- speech: the ready-made phrase sets, and the line a click says
-- when speaking is on. The "In character" set is Phrases.lua's own, and it
-- loads after this file.

local ns = select(2, ...)
-- Player-facing text, in the client's language: see Locales/Init.lua.
local L = ns.L
local addon = ns.addon

---------------------------------------------------------------------------
-- speech
--
-- C_ChatInfo.SendChatMessage refuses SAY and YELL outside instances. A /say in
-- the secure button's macro fires from your click, so the game allows it.
---------------------------------------------------------------------------

-- Ready-made phrase sets, loadable from the options: faction-neutral, short
-- enough for a 255-character macro, and in the player's language. The box they
-- fill is saved as text, so a loaded set stays in the language it was loaded in.
ns.PHRASE_SETS = {
	roleplay = {
		label = L["Roleplay"],
		lines = {
			L["May the Light watch over you, {name}."],
			L["The arcane favours you, {name}."],
			L["Strength to your arm, {name}."],
			L["A boon for the road, {name}."],
			L["Safe travels, {name}. The roads are not kind."],
			L["Winds at your back, {name}."],
			L["May your blade stay keen, {name}."],
			L["Fortune favour you, {name}."],
			L["Go well, {name}. You will need it."],
			L["Take this with you, {name}."],
			L["A gift, freely given."],
			L["Stay sharp out there, {name}."],
		},
	},
	polite = {
		label = L["Polite"],
		lines = {
			L["Thanks for the buff, {name}!"],
			L["Returning the favour, {name}."],
			L["Have some {buff}, {name}."],
			L["Cheers, {name}!"],
			L["One good buff deserves another, {name}."],
			L["Least I could do, {name}."],
		},
	},
	cheeky = {
		label = L["Cheeky"],
		lines = {
			L["You dropped this, {name}."],
			L["Buffed. You're welcome, {name}."],
			L["{name}, you look like you need this."],
			L["Consider us even, {name}."],
			L["Don't spend it all at once, {name}."],
			L["This one's on me, {name}."],
		},
	},
	quiet = {
		label = L["Just their name"],
		lines = { L["{name}."], L["For you, {name}."], L["{name} \\o"] },
	},
}

-- Phrases.lua puts "incharacter" second, after the set it is the per-character
-- version of.
ns.PHRASE_SET_ORDER = { "roleplay", "polite", "cheeky", "quiet" }

-- The sets as builds up to 1.0.0-beta.5 stored them in every profile, in
-- English on every client; ClampSettings swaps this text for the translated
-- set. Plain strings, not L[...]: they are what a profile holds (a scenario
-- checks they match the keys above).
local EnglishPhraseSet
do
	local PHRASE_SETS_ENGLISH = {
		roleplay = {
			"May the Light watch over you, {name}.",
			"The arcane favours you, {name}.",
			"Strength to your arm, {name}.",
			"A boon for the road, {name}.",
			"Safe travels, {name}. The roads are not kind.",
			"Winds at your back, {name}.",
			"May your blade stay keen, {name}.",
			"Fortune favour you, {name}.",
			"Go well, {name}. You will need it.",
			"Take this with you, {name}.",
			"A gift, freely given.",
			"Stay sharp out there, {name}.",
		},
		polite = {
			"Thanks for the buff, {name}!",
			"Returning the favour, {name}.",
			"Have some {buff}, {name}.",
			"Cheers, {name}!",
			"One good buff deserves another, {name}.",
			"Least I could do, {name}.",
		},
		cheeky = {
			"You dropped this, {name}.",
			"Buffed. You're welcome, {name}.",
			"{name}, you look like you need this.",
			"Consider us even, {name}.",
			"Don't spend it all at once, {name}.",
			"This one's on me, {name}.",
		},
		quiet = { "{name}.", "For you, {name}.", "{name} \\o" },
	}

	-- The set whose English text this is, or nil for anything else.
	function EnglishPhraseSet(text)
		if type(text) ~= "string" then return nil end
		for _, key in ipairs(ns.PHRASE_SET_ORDER) do
			local english = PHRASE_SETS_ENGLISH[key]
			if english and text == table.concat(english, "\n") then return key end
		end
		return nil
	end
end
-- ClampSettings (Core.lua) repairs a profile's phrase box with it.
ns.EnglishPhraseSet = EnglishPhraseSet

function ns.PhraseSetText(key)
	local set = ns.PHRASE_SETS[key]
	if not set then return nil end
	-- A set written per character ("In character", Phrases.lua) makes its own.
	if set.text then return set.text() end
	return table.concat(set.lines, "\n")
end

ns.CHANNEL_COMMANDS = {
	SAY = "say",
	YELL = "yell",
	PARTY = "party",
	RAID = "raid",
	EMOTE = "emote",
}

ns.MACRO_LIMIT = 255

-- The room a spoken line gets is whatever the cast lines leave, which differs
-- per person: ns.PhraseBudget in Prompt.lua answers it. A block of its own for
-- the main chunk's 200 locals.
do
	local function SanitizePhrase(text)
		if type(text) ~= "string" then return nil end
		text = text:gsub("[\r\n]", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")
		if text == "" then return nil end
		return text
	end

	function ns.PickPhrase(entry, budget)
		local db = addon.db and addon.db.profile
		if not db or not db.speech.enabled then return nil end
		if db.speech.onlyWhenReturning and entry.reason ~= "owed" then return nil end

		local command = ns.CHANNEL_COMMANDS[db.speech.channel]
		if not command then return nil end

		-- "In character" chooses for this person and moment, not from the box.
		local inCharacter = ns.InCharacter
		if inCharacter and inCharacter.Active(db.speech) then
			return inCharacter.Pick(entry, command, budget)
		end

		local pool = {}
		for line in tostring(db.speech.phrases or ""):gmatch("[^\r\n]+") do
			local clean = SanitizePhrase(line)
			if clean then pool[#pool + 1] = clean end
		end
		if #pool == 0 then return nil end

		-- Through Swap, so a "%" in a name cannot throw from inside gsub.
		local phrase = pool[math.random(#pool)]
		phrase = ns.Swap(phrase, "{name}", entry.short or entry.name)
		phrase = ns.Swap(phrase, "{buff}", entry.buff and ns.BuffName(entry.buff))
		phrase = SanitizePhrase(phrase)
		if not phrase then return nil end

		local line = "/" .. command .. " " .. phrase
		if #line > budget then return nil end
		return line
	end
end
