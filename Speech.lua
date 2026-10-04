-- Manners -- speech: the ready-made phrase sets, and the line a click says
-- when speaking is on. The "In character" set is Phrases.lua's own, and it
-- loads after this file.

local ns = select(2, ...)
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
-- `summary` is how Start here's sentence names the set ("Says a polite line
-- in /say"): a phrase of its own, never the label dropped into one.
ns.PHRASE_SETS = {
	roleplay = {
		label = L["Azeroth"],
		summary = L["a line from Azeroth"],
		lines = {
			L["Azeroth needs you on your feet, {name}."],
			L["The Titans shaped this world, {name}. Keeping it whole falls to the likes of us."],
			L["The Scourge is always recruiting, {name}. Don't give them the satisfaction."],
			L["The Legion's been at this world for ten thousand years, {name}. It hasn't won yet."],
			L["If something whispers to you in the dark, {name}, don't answer."],
			L["Some of Deathwing's brood wear human faces, {name}. Mind who you trust."],
			L["Ley lines run under all of Azeroth, {name}. Today a little runs your way."],
			L["Watch the long grass in Stranglethorn, {name}. The panthers are watching you."],
			L["Careful by the shore, {name}. Where there's one murloc, there are nine."],
			L["No charge, {name}. They'd call me mad in Booty Bay."],
			L["May the Barrens be kinder to you than they were to me, {name}."],
			L["Stay out of the Plaguelands if you can, {name}. Go well armed if you can't."],
			L["One good turn, {name}. Azeroth could use a few more of those."],
			L["Ragnaros still burns under Blackrock Mountain, {name}. Let's keep him down there."],
			L["From Kalimdor to the Eastern Kingdoms, {name}, may every road bring you home."],
			L["From one wanderer of Azeroth to another."],
		},
	},
	polite = {
		label = L["Polite"],
		summary = L["a polite line"],
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
		summary = L["a cheeky line"],
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
		summary = L["just their name"],
		lines = { L["{name}."], L["For you, {name}."], L["{name} \\o"] },
	},
}

-- Phrases.lua puts "incharacter" second, after the set it is the per-character
-- version of.
ns.PHRASE_SET_ORDER = { "roleplay", "polite", "cheeky", "quiet" }

-- The sets in English, as builds up to 1.0.0-beta.5 stored them in every
-- profile on every client, and as the box holds a set picked before its lines
-- were translated; ClampSettings swaps this text for the translated set. Plain
-- strings, not L[...]: they are what a profile holds (a scenario checks they
-- match the keys above).
local EnglishPhraseSet
do
	local PHRASE_SETS_ENGLISH = {
		roleplay = {
			"Azeroth needs you on your feet, {name}.",
			"The Titans shaped this world, {name}. Keeping it whole falls to the likes of us.",
			"The Scourge is always recruiting, {name}. Don't give them the satisfaction.",
			"The Legion's been at this world for ten thousand years, {name}. It hasn't won yet.",
			"If something whispers to you in the dark, {name}, don't answer.",
			"Some of Deathwing's brood wear human faces, {name}. Mind who you trust.",
			"Ley lines run under all of Azeroth, {name}. Today a little runs your way.",
			"Watch the long grass in Stranglethorn, {name}. The panthers are watching you.",
			"Careful by the shore, {name}. Where there's one murloc, there are nine.",
			"No charge, {name}. They'd call me mad in Booty Bay.",
			"May the Barrens be kinder to you than they were to me, {name}.",
			"Stay out of the Plaguelands if you can, {name}. Go well armed if you can't.",
			"One good turn, {name}. Azeroth could use a few more of those.",
			"Ragnaros still burns under Blackrock Mountain, {name}. Let's keep him down there.",
			"From Kalimdor to the Eastern Kingdoms, {name}, may every road bring you home.",
			"From one wanderer of Azeroth to another.",
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

	-- Sets as they read before they were rewritten, under the key of the set
	-- that took their place, since a box filled with one then still holds it:
	-- the Fantasy set, which became Azeroth after 1.6.4. Each in English, as
	-- above, and as L[...], whose keys keep the old translations in the
	-- locale files, so a box filled in another language is known too. Never
	-- said.
	local FORMER = {
		roleplay = {
			english = {
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
			translated = {
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
	}

	local function Holds(text, lines)
		return lines ~= nil and text == table.concat(lines, "\n")
	end

	-- The set whose text this is, when it is the addon's and not the
	-- player's: a set in English, or a former set in English or as translated.
	function EnglishPhraseSet(text)
		if type(text) ~= "string" then return nil end
		for _, key in ipairs(ns.PHRASE_SET_ORDER) do
			local former = FORMER[key]
			if Holds(text, PHRASE_SETS_ENGLISH[key])
				or former and (Holds(text, former.english) or Holds(text, former.translated)) then
				return key
			end
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
	-- To the person being buffed and nobody else. PickPhrase writes their name
	-- after it, so it takes more of the macro than the others.
	WHISPER = "w",
}

-- Whether the line's channel reaches anybody right now. /party and /raid
-- outside a party or raid reach nobody: the macro's line went out on every
-- press, the thank-you was lost, and the server answered each one with "You
-- aren't in a party." Asked where the macro is built (Prompt/Macro.lua), not
-- when the line is rolled, so joining or leaving a group arms or drops it on
-- the next repaint. Only a definite no closes it, as with the range: a client
-- that will not say keeps the line.
function ns.ChannelOpen()
	local db = addon.db and addon.db.profile
	local channel = db and db.speech.channel
	local member
	if channel == "PARTY" then
		member = IsInGroup and IsInGroup()
	elseif channel == "RAID" then
		member = IsInRaid and IsInRaid()
	else
		return true
	end
	return ns.plain(member) ~= false
end

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

	-- Whether the chat box splits a "/w" line into name and message the way
	-- regional unique names need (below). Asked of the client, which is what its
	-- own parser asks; a client that will not say is judged by its flavour, since
	-- Camelot is where those names are.
	local function RegionalNames()
		local on = ns.safecall(_G.RegionalUniqueNamesEnabled)
		if on == nil then on = (ns.Flavour and ns.Flavour.flavour) == "camelot" end
		return on == true
	end

	-- Who the client will whisper, given what follows "/w", walked as its
	-- ExtractTellTarget walks it (Blizzard_ChatFrameBase, forever branch): words
	-- come off the end while what is left still looks like more than a name.
	-- With regional unique names a name is two words ("Petra Stonewell"), so it
	-- walks while a separator, a word and a space remain; elsewhere while any
	-- space does. Its autocomplete stop is left out: no name it knows begins with
	-- a whole name and a word of the line.
	local function WhisperTargetOf(text, regional)
		local target = type(text) == "string" and text:match("^%s*(.*)") or ""
		local more = regional and "[%s-](%w+)%s" or "%s"
		if not target:find(more) or target:sub(1, 1) == "|" then return nil end
		while target and target:find(more) do
			target = target:match("(.+)%s+[^%s]*")
		end
		return target
	end

	-- The name a whisper carries: the whole filed name, realm and all, since a
	-- whisper (unlike /target) needs "Mort-Ravencrest" to find somebody from
	-- another realm; on Camelot, name and surname. Nothing for a secret, or for
	-- what SafeForMacro keeps off the /target line.
	local function WhisperName(entry)
		local name = ns.plain(entry.name)
		if not (ns.SafeForMacro and ns.SafeForMacro(name)) then return nil end
		if name:find("%c") then return nil end
		-- A realm withheld as a secret is filed as the bare name (JoinName), and
		-- a whisper to that finds somebody on your own realm instead. Asked of
		-- the unit again, since the filed name no longer shows it.
		if entry.unit then
			local secret = _G.issecretvalue
			if secret then
				local ok, first, second = pcall(_G.UnitName, entry.unit)
				if not ok or secret(first) or secret(second) then return nil end
			end
		elseif entry.targetName ~= nil and not name:find("[%s%-]") then
			-- With no unit (the tokenless fallback) a bare name cannot say whether a
			-- realm was dropped, so the client is asked by the debt's GUID, and the bare
			-- name goes out only if it says plainly: this name, your own realm. A debt
			-- back from disk has no GUID and gets no line, nor has Roll a few's stand-in.
			local debt = ns.owed and ns.owed[name]
			local guid = debt and debt.guid
			if not guid then return nil end
			local ok, _, _, _, _, _, who, realm = pcall(_G.GetPlayerInfoByGUID, guid)
			if not (ok and ns.plain(who) == name and ns.plain(realm) == "") then return nil end
		end
		return name
	end

	-- The spoken line with its channel command taken off, and for a whisper the
	-- name the client will send it to: the part somebody actually reads.
	function ns.SpokenText(line)
		if type(line) ~= "string" then return line end
		local command, rest = line:match("^/(%S+)%s*(.*)$")
		if not command then return line end
		if command == ns.CHANNEL_COMMANDS.WHISPER then
			local target = WhisperTargetOf(rest, RegionalNames())
			if target then rest = rest:sub(#target + 2) end
		end
		return rest
	end

	-- The line, and for "In character" the line as written, which that set
	-- remembers as said only once a press carries it (Prompt/Press.lua).
	local function Roll(db, entry, command, budget)
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

		local phrase = pool[math.random(#pool)]
		phrase = ns.Swap(phrase, "{name}", entry.short or entry.name)
		-- The spell that goes out: a group cast's own name (GroupBuffs.lua).
		local spell = entry.groupCast and entry.groupCast.spellName
		phrase = ns.Swap(phrase, "{buff}", spell or (entry.buff and ns.BuffName(entry.buff)))
		phrase = SanitizePhrase(phrase)
		if not phrase then return nil end

		local line = "/" .. command .. " " .. phrase
		if #line > budget then return nil end
		return line
	end

	-- The line with its channel command, and for "In character" the line as
	-- written (see Roll), or nil.
	function ns.PickPhrase(entry, budget)
		local db = addon.db and addon.db.profile
		if not db or not db.speech.enabled then return nil end
		-- Your own buff says nothing, whatever the settings: a line to
		-- yourself, out loud to everybody near, is the one thing worse than
		-- silence. Here rather than in the macro, so the tooltip never quotes
		-- a line, and "In character" spends none of its memory of lines said
		-- lately on one that never is.
		if entry.reason == "self" then return nil end
		if db.speech.onlyWhenReturning and entry.reason ~= "owed" then return nil end

		local command = ns.CHANNEL_COMMANDS[db.speech.channel]
		if not command then return nil end

		-- A whisper names who it goes to, so the name is part of the command, and
		-- of every length either roll measures against the budget.
		local whisperTo
		if db.speech.channel == "WHISPER" then
			whisperTo = WhisperName(entry)
			if not whisperTo then return nil end
			command = command .. " " .. whisperTo
		end

		local line, source = Roll(db, entry, command, budget)
		-- A whisper the chat box would read as going to somebody else, or would
		-- drop, says nothing: "/w Petra Cheers mate" is Petra Cheers on Camelot,
		-- where names have surnames. Not asked of the stand-ins the Roll a few
		-- buttons make, which carry no targetName (Queue.lua writes one for
		-- everybody real) and a name in the reader's language.
		if line and whisperTo and entry.targetName ~= nil
			and WhisperTargetOf(line:match("^/%S+(.*)$"), RegionalNames()) ~= whisperTo then
			return nil
		end
		return line, source
	end
end
