-- Manners -- the "In character" phrase set.
--
-- The other sets are a list of lines the player can read and edit in the phrase
-- box. This one is chosen at the moment of the click instead, from lines written
-- for the player's own people and side, and for why the buff is going out:
-- thanking somebody who buffed you first, answering somebody who asked, or
-- offering it unasked. A dwarf says something a dwarf would say.
--
-- It is active while "In character" is the chosen set and the box still holds
-- the examples it put there; editing the box makes the lines the player's own,
-- as editing any set does. Core's ns.PickPhrase and ns.PhraseSetText ask this
-- file, and do exactly what they did before whenever it is not the chosen set,
-- or not loaded at all.
--
-- Only the player's own race and faction decide the lines. Somebody else's race
-- is asked for one thing, whether they are kin, and on this client that answer
-- is often a secret: then they are simply not greeted as kin.

local _, ns = ...

local RP = {}
ns.InCharacter = RP

-- Player-facing text, in the client's language: see Locales/Init.lua. Read
-- through a proxy that remembers each translation's English key, because the
-- box keeps whatever language it was filled in: a player who picks the set
-- before the lines are translated has English examples saved, and they must
-- still count as untouched once a later release translates them.
-- The proxy only forwards: every key reaching it is written below as a whole
-- L["..."] literal, which is what the translation audit collects.
local ENGLISH = {}
local L = setmetatable({}, {
	__index = function(_, key)
		local translated = ns.L
		local text = translated[key]
		ENGLISH[text] = key
		return text
	end,
})

-- UnitRace's second return, the untranslated file name, to the people whose
-- lines it speaks. Allied races share their parent people's voice: a Mag'har
-- says Lok'tar as readily as any orc. The Haranir are new with Midnight and
-- have no lines of their own yet, so they speak with their faction's voice and
-- the general lines, which is better than guessing at a culture.
RP.FAMILY = {
	Dwarf = "dwarf", DarkIronDwarf = "dwarf", EarthenDwarf = "dwarf",
	Human = "human", KulTiran = "human",
	NightElf = "nightelf",
	VoidElf = "voidelf",
	Gnome = "gnome", Mechagnome = "gnome",
	Draenei = "draenei", LightforgedDraenei = "draenei",
	Worgen = "worgen",
	Orc = "orc", MagharOrc = "orc",
	Scourge = "forsaken",
	Tauren = "tauren", HighmountainTauren = "tauren",
	Troll = "troll", ZandalariTroll = "troll",
	BloodElf = "bloodelf",
	Nightborne = "nightborne",
	Goblin = "goblin",
	Vulpera = "vulpera",
	Pandaren = "pandaren",
	Dracthyr = "dracthyr",
	Haranir = "haranir",
}

-- Each people's lines by what the moment is: "thanks" for returning a favour,
-- "asked" for answering a request, "offer" for a buff nobody asked for (a group
-- member hears these too, next to the friendlier group lines below), and "kin"
-- for somebody of the same people. Every line is a whole literal so it can be
-- translated as a whole. A kin line joins whichever of the others is being
-- said, so it greets nobody: "well met" is wrong to somebody who just buffed
-- you. No line says "buff" either -- the set is in character, and {buff} is
-- the spell's own name.
RP.RACE = {
	dwarf = {
		thanks = {
			L["Thank ye kindly, {name}! First round's on me when we're back at the forge."],
			L["Much obliged, {name}. Ye've a friend in the mountain now."],
		},
		asked = {
			L["Aye, {name}, ye only had to ask. Hold still now!"],
			L["Say no more, {name}. Stone and steel, here it comes."],
		},
		offer = {
			L["Here, {name}, a wee somethin' to keep ye on yer feet."],
			L["Off ye go, {name}, steady as the mountain."],
		},
		kin = L["Stone and hammer keep ye, cousin {name}!"],
	},
	human = {
		thanks = {
			L["My thanks, {name}. Allow me to return the kindness."],
			L["Kindly done, {name}. Let no one say we forget a friend."],
		},
		asked = {
			L["Of course, {name}. Stand fast a moment."],
			L["Right away, {name}. Keep your shield high."],
		},
		offer = {
			L["The road ahead is long, {name}. Take this with you."],
			L["Fair winds and following seas, {name}."],
		},
		-- Stormwind and Kul Tiras are both this family, and both Arathor's.
		kin = L["Arathor's children stand together, {name}."],
	},
	nightelf = {
		thanks = {
			L["Ishnu-alah, {name}. Your kindness is returned."],
			L["Thank you, {name}. Elune smiles on the generous."],
		},
		asked = {
			L["Gladly, {name}. Be still, and let the moonlight find you."],
			L["Of course, {name}. Elune's blessings are meant to be shared."],
		},
		offer = {
			L["Elune-adore, {name}. Walk softly beneath the stars."],
			L["May the forest shelter you, {name}, wherever you roam."],
		},
		kin = L["Ishnu-alah, {name}. Elune keeps her children close."],
	},
	voidelf = {
		thanks = {
			L["The shadows remember kindness, {name}. So do I."],
			L["My thanks, {name}. The ren'dorei do not forget a kindness."],
		},
		asked = {
			L["As you wish, {name}. The shadows answer kindly today."],
			L["Consider it done, {name}. The Void obeys us, not the other way round."],
		},
		offer = {
			L["A touch of shadow for you, {name}. Quite safe. Mostly."],
			L["Walk carefully in the dark places, {name}."],
		},
		kin = L["We ren'dorei look after our own, {name}."],
	},
	gnome = {
		thanks = {
			L["Thanks, {name}! Kindness received, catalogued and returned!"],
			L["Reciprocity engaged! Much obliged, {name}."],
		},
		asked = {
			L["Request received, {name}! Processing... done!"],
			L["One upgrade, coming right up, {name}! Stand still for calibration."],
		},
		offer = {
			L["Hold still, {name}, this is perfectly safe. Probably!"],
			L["Science says you need this, {name}. Who am I to argue?"],
			L["A small upgrade for you, {name}. No cogs required."],
		},
		kin = L["For Gnomeregan, {name}! Always nice to talk to somebody at eye level."],
	},
	draenei = {
		thanks = {
			L["The Light rewards kindness, {name}, and so shall I."],
			L["Archenon poros, {name}. Your gift is returned."],
		},
		asked = {
			L["Of course, {name}. May the Naaru guide your steps."],
			L["Gladly, {name}. The Light answers those who ask."],
		},
		offer = {
			L["The Light is with you, {name}. Go in peace."],
			L["Walk in the Light, {name}. May it shelter you always."],
		},
		kin = L["Archenon poros, {name}! The children of Argus look after one another."],
	},
	worgen = {
		thanks = {
			L["Much obliged, {name}. Gilneas never forgets a kindness."],
			L["Thank you, {name}. You have my gratitude, and my best howl."],
		},
		asked = {
			L["Certainly, {name}. Hold still, I don't bite. Much."],
			L["Right you are, {name}. Stand steady now."],
		},
		offer = {
			L["Stay off the moors after dark, {name}. Take this."],
			L["Keep your wits about you, {name}. Something is always hunting."],
		},
		kin = L["The curse binds us, {name}, but Gilneas binds us tighter."],
	},
	orc = {
		thanks = {
			L["Throm-ka, {name}! Honour is repaid."],
			L["You give freely, {name}. I return the favour."],
		},
		asked = {
			-- Dabu: the grunt's "I obey", not the peon's "zug zug".
			L["Dabu, {name}. It is done."],
			L["Hold still, {name}. Strength for the fight ahead."],
		},
		offer = {
			L["Lok'tar ogar, {name}! Take this into battle."],
			L["Blood and thunder, {name}! Go and earn your glory."],
		},
		kin = L["Throm-ka, {name}! The blood of the clans runs strong in you."],
	},
	forsaken = {
		thanks = {
			L["Thank you, {name}. It would warm my heart, if it still beat."],
			-- Not "from the living": Forsaken buff each other all the time.
			L["Such warmth, for one so cold? Returned in full, {name}."],
		},
		asked = {
			L["Certainly, {name}. Try not to die. It's overrated."],
			L["You need only ask, {name}. The dead are patient."],
		},
		offer = {
			L["Stay among the living a little longer, {name}."],
			L["Take this, {name}. The grave can wait."],
		},
		kin = L["We Forsaken must look after each other, {name}."],
	},
	tauren = {
		thanks = {
			L["The Earth Mother sees your kindness, {name}. I return it."],
			L["Thank you, {name}. May the winds guide you."],
		},
		asked = {
			L["Of course, {name}. Stand tall and be at peace."],
			L["Ask and it is given, {name}. The herd shares what it has."],
		},
		offer = {
			L["Walk with the Earth Mother, {name}."],
			L["May An'she light your path, {name}."],
		},
		kin = L["The Earth Mother watches over us both, {name}."],
	},
	troll = {
		thanks = {
			L["Ya be too kind, {name}! Dis one be from me."],
			L["Thanks, mon! Da spirits smile on ya, {name}."],
		},
		asked = {
			L["Sure ting, {name}. Hold still now."],
			L["No worries, {name}. Da loa got ya covered."],
		},
		offer = {
			L["Da loa be watchin' over ya, {name}."],
			L["Stay sharp out dere, {name}. Take dis wit' ya."],
		},
		kin = L["Hey, {name}! Always good to see family, mon."],
	},
	bloodelf = {
		thanks = {
			L["Such courtesy does you credit, {name}. Anar'alah belore."],
			L["How gracious, {name}. Allow me to return the favour."],
		},
		asked = {
			L["Naturally, {name}. Only the finest for you."],
			L["For you, {name}? Of course. The sun gives freely."],
		},
		offer = {
			L["Anar'alah belore, {name}. May the sun guide you."],
			L["Shorel'aran, {name}. Fight with elegance."],
		},
		kin = L["The Sunwell shines for us both, {name}."],
	},
	nightborne = {
		thanks = {
			L["Your generosity is noted, {name}. Suramar remembers its friends."],
			L["Most gracious, {name}. Allow me to repay you in kind."],
		},
		asked = {
			L["Of course, {name}. A little arcane polish, just for you."],
			L["A reasonable request, {name}. Granted."],
		},
		offer = {
			L["Take this, {name}. Arcane gifts are wasted on the idle."],
			-- Suramar's arcana, not the Nightwell: they were weaned off it.
			L["A spark of Suramar's arcana for you, {name}. Use it wisely."],
		},
		kin = L["Suramar's children shine together again, {name}."],
	},
	goblin = {
		thanks = {
			L["A favour for a favour, {name}! Pleasure doing business."],
			L["Thanks, {name}! Consider your account settled in full."],
		},
		asked = {
			L["You got it, {name}! Time is money, friend!"],
			L["Deal, {name}! I'll put it on your tab. Kidding!"],
		},
		offer = {
			L["This one's on the house, {name}. Don't tell the Trade Prince."],
			L["Top-shelf stuff, zero fees, {name}. Today only!"],
		},
		kin = L["Anything for a fellow entrepreneur, {name}!"],
	},
	vulpera = {
		thanks = {
			L["Thank you, {name}! The caravan always repays a kindness."],
			L["How kind, {name}! You're on the caravan's good list now."],
		},
		asked = {
			L["Of course, {name}! Shake the sand out and hold still."],
			L["Coming right up, {name}! Caravan service, no waiting."],
		},
		offer = {
			L["Every traveller needs something for the road, {name}."],
			L["Keep this, {name}. The desert is long and the water is short."],
		},
		kin = L["A fellow wanderer! The caravan is never far, {name}."],
	},
	pandaren = {
		thanks = {
			L["A kindness returned is a kindness doubled, {name}."],
			L["Thank you, {name}. You have restored my balance."],
		},
		asked = {
			L["Of course, {name}. Patience, and it is done."],
			L["With pleasure, {name}. A kind deed is never wasted."],
		},
		offer = {
			L["Take this, {name}. And perhaps a cup of tea afterward?"],
			L["Balance in all things, {name}. Now go with a light heart."],
		},
		kin = L["We must share a brew when the road allows, {name}!"],
	},
	dracthyr = {
		thanks = {
			L["Your kindness is noted, {name}. Dragons do not forget."],
			L["Thank you, {name}. Returned on swift wings."],
		},
		asked = {
			L["Very well, {name}. Stand still, I would hate to singe you."],
			L["Granted, {name}. A dragon keeps its word."],
		},
		offer = {
			L["Take this, {name}. Even a dragon needs allies."],
			L["A gift from the Dragon Isles, {name}. Fly well."],
		},
		kin = L["The Forbidden Reach feels far behind us now, {name}."],
	},
}

-- For kin of a people with no kin line of their own (the Haranir, for now).
RP.KIN = L["It is good to see one of our own, {name}."]

-- Faction pride without a word about the other side. "Neutral" is a pandaren
-- on the Wandering Isle or a dracthyr before choosing, and anybody whose
-- faction the client would not say. A group member hears a side's offers and
-- its group line together, so the two are not allowed to say the same thing.
RP.FACTION = {
	Alliance = {
		thanks = {
			L["Thank you, {name}. The Alliance looks after its own."],
			L["Kindness answered, {name}. For the Alliance!"],
		},
		asked = {
			L["Of course, {name}. Allies help each other."],
			L["At once, {name}. The Alliance does not leave a friend wanting."],
		},
		offer = {
			L["For the Alliance, {name}! Stay strong out there."],
			L["Onward, {name}. The Alliance is with you."],
		},
		group = {
			L["Together we stand, {name}. For the Alliance!"],
		},
	},
	Horde = {
		thanks = {
			L["Strength and honour, {name}. Your kindness is repaid."],
			L["The Horde takes care of its own, {name}."],
		},
		asked = {
			L["Consider it done, {name}. For the Horde."],
			L["You only had to ask, {name}. The Horde answers."],
		},
		offer = {
			L["For the Horde, {name}! Go with strength."],
			L["Go with honour, {name}. Victory awaits."],
		},
		group = {
			L["Our strength is each other, {name}. For the Horde!"],
		},
	},
	Neutral = {
		thanks = { L["Thank you, {name}. Good hearts are found everywhere."] },
		asked = { L["Gladly, {name}, whatever banner you fly."] },
		offer = { L["Friends can come from any side, {name}."] },
		group = { L["Side by side, {name}, whatever comes."] },
	},
}

-- Anybody's, in character without belonging to one people: they keep a race
-- from repeating itself, and they are all an unknown race has.
RP.GENERAL = {
	thanks = {
		L["One good turn deserves another, {name}."],
		L["Have some {buff} in return, {name}."],
		L["Kindness should go both ways, {name}. Thank you."],
	},
	asked = {
		L["You asked, {name}, and here it is."],
		L["{buff}, coming right up, {name}."],
		L["Gladly, {name}. One moment."],
	},
	offer = {
		L["Safe travels, {name}. Take some {buff} with you."],
		L["A small blessing for the road, {name}."],
		L["Go well, {name}, and come back in one piece."],
	},
	group = {
		L["Everyone ready? You are now, {name}."],
		L["A little something for the party, {name}."],
		L["Stay close, {name}. We go further together."],
	},
}

-- How often each kind of line comes up, per line: a people's own lines most,
-- so a dwarf mostly sounds like a dwarf, and the rest keep it from repeating.
-- Kin is one line, so it weighs more to be heard when it applies. In a group
-- the group lines are the point, so they weigh as much as the faction's.
RP.WEIGHT = { race = 3, kin = 6, faction = 2, general = 1, group = 2 }

do
	-- The reason on a queue entry to the kind of line it wants. The target,
	-- nearby and anything new all get an offer.
	local KIND = { owed = "thanks", asked = "asked", group = "group" }

	-- Our own race and faction are ours to read, but through ns.plain anyway:
	-- a secret must never reach a comparison.
	local function Ask(fn, ...)
		if type(fn) ~= "function" then return nil end
		local ok, a, b = pcall(fn, ...)
		if not ok then return nil end
		return ns.plain(a), ns.plain(b)
	end

	-- The player's people ("dwarf", or nil for a race with no family) and side
	-- ("Alliance", "Horde" or "Neutral").
	function RP.Player()
		local _, race = Ask(_G.UnitRace, "player")
		local faction = Ask(_G.UnitFactionGroup, "player")
		if faction ~= "Alliance" and faction ~= "Horde" then faction = "Neutral" end
		return RP.FAMILY[race], faction
	end

	-- The lines a table has for this kind of moment; a group member hears the
	-- offers when there are no group lines.
	local function PoolFor(tbl, kind)
		if type(tbl) ~= "table" then return nil end
		return tbl[kind] or (kind == "group" and tbl.offer) or nil
	end
	RP.PoolFor = PoolFor

	-- Whether the person on the prompt is of our people. The unit token was
	-- taken when the queue was built and may since be somebody else, so their
	-- name has to still be on it; their race is often a secret for a stranger,
	-- and then they are not kin as far as anybody can tell.
	function RP.IsKin(entry, family)
		if not family or type(entry) ~= "table" or type(entry.unit) ~= "string" then return false end
		local ok, name = pcall(ns.UnitFullName, entry.unit)
		if not ok or name == nil or name ~= entry.name then return false end
		local _, race = Ask(_G.UnitRace, entry.unit)
		return race ~= nil and RP.FAMILY[race] == family
	end

	-- One line for this person, now, with the channel command in front, or nil
	-- when nothing fits. Every candidate is measured before the roll rather than
	-- after it, so a long name or spell leaves the shorter lines to choose from
	-- instead of silence.
	function RP.Pick(entry, command, budget)
		if type(entry) ~= "table" or type(command) ~= "string" or type(budget) ~= "number" then
			return nil
		end
		local family, faction = RP.Player()
		local kind = KIND[entry.reason] or "offer"
		local name = entry.short or entry.name
		local buff = entry.buff and ns.BuffName(entry.buff)
		local weight = RP.WEIGHT

		local lines, weights, total = {}, {}, 0
		local function add(pool, each)
			if type(pool) == "string" then pool = { pool } end
			if type(pool) ~= "table" then return end
			for _, text in ipairs(pool) do
				-- A line that would say an empty name or spell is left out,
				-- not said with a hole in it.
				local usable = (name or not text:find("{name}", 1, true))
					and (buff or not text:find("{buff}", 1, true))
				if usable then
					local said = ns.Swap(ns.Swap(text, "{name}", name), "{buff}", buff)
					said = said:gsub("[\r\n]", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")
					local line = "/" .. command .. " " .. said
					if said ~= "" and #line <= budget then
						lines[#lines + 1] = line
						weights[#lines] = each
						total = total + each
					end
				end
			end
		end

		local race = RP.RACE[family]
		add(PoolFor(race, kind), weight.race)
		if RP.IsKin(entry, family) then add((race and race.kin) or RP.KIN, weight.kin) end
		local side = RP.FACTION[faction]
		if kind == "group" then
			add(side.group, weight.group)
			add(side.offer, weight.faction)
			add(RP.GENERAL.group, weight.group)
		else
			add(PoolFor(side, kind), weight.faction)
			add(RP.GENERAL[kind], weight.general)
		end
		if total == 0 then return nil end

		local roll = math.random(total)
		for i = 1, #lines do
			roll = roll - weights[i]
			if roll <= 0 then return lines[i] end
		end
		return lines[#lines]
	end

	-- What the phrase box shows for a people and side: one line of each kind,
	-- always the same ones, so the box can be recognised as untouched. With
	-- english, the same lines as they read before translation.
	function RP.Examples(family, faction, english)
		local race = RP.RACE[family]
		local side = RP.FACTION[faction]
		local out = {}
		local function put(pool)
			if type(pool) == "table" and pool[1] then
				out[#out + 1] = english and ENGLISH[pool[1]] or pool[1]
			end
		end
		if race then
			put(race.thanks)
			put(race.asked)
			put(race.offer)
			put(side.offer)
			put(RP.GENERAL.group)
		else
			put(side.thanks)
			put(side.asked)
			put(side.offer)
			put(RP.GENERAL.thanks)
			put(RP.GENERAL.offer)
		end
		return table.concat(out, "\n")
	end

	-- The examples for whoever is logged in.
	function RP.Text()
		return RP.Examples(RP.Player())
	end

	local FACTIONS = { "Alliance", "Horde", "Neutral" }
	local lastText, lastAnswer

	-- Whether text is the examples of any people and side, in the client's
	-- language or, with english, as they read before translation.
	local function IsExamples(text, english)
		for _, faction in ipairs(FACTIONS) do
			if text == RP.Examples(nil, faction, english) then return true end
			for family in pairs(RP.RACE) do
				if text == RP.Examples(family, faction, english) then return true end
			end
		end
		return false
	end

	-- Whether "In character" is what speaks. The box is compared with the
	-- examples of every people and side, not only this character's: a profile
	-- is often shared by several characters, and the dwarf who picked the set
	-- has not edited anything the orc on the same profile should lose. English
	-- examples count too, saved by a player who picked the set before its lines
	-- were translated into their language.
	function RP.Active(speech)
		if type(speech) ~= "table" or speech.presetChoice ~= "incharacter" then return false end
		local text = speech.phrases
		if type(text) ~= "string" then return false end
		if text == lastText then return lastAnswer end
		local answer = IsExamples(text) or IsExamples(text, true)
		lastText, lastAnswer = text, answer
		return answer
	end

	-- The load-time repair (Core's ClampSettings) for this set: examples saved
	-- in English become this character's examples in the client's language, as
	-- the fixed sets' English text does, so the box and an export read like an
	-- untouched set. On an English client the two are the same and nothing moves.
	function RP.Repair(speech)
		if not RP.Active(speech) or IsExamples(speech.phrases) then return end
		speech.phrases = RP.Text()
	end

	-- What each reason is called when Roll a few prints it.
	local ROLL = {
		{ reason = "owed", label = L["Returning a favour:"] },
		{ reason = "asked", label = L["Answering a request:"] },
		{ reason = "group", label = L["In your group:"] },
		{ reason = "nearby", label = L["Offering unasked:"] },
	}

	-- Roll a few for this set: a line for each reason speech is on for, since
	-- the set speaks differently for each, all through ns.PickPhrase and the
	-- same budget the cast path measures. Speaking only when returning a
	-- favour leaves one reason, rolled three times like the other sets.
	function RP.Roll(somebody)
		local speech = ns.db and ns.db.profile and ns.db.profile.speech
		local rows = ROLL
		if speech and speech.onlyWhenReturning then rows = { ROLL[1], ROLL[1], ROLL[1] } end
		local buff = ns.ResolveBuff(true)
		for _, row in ipairs(rows) do
			local fake = { short = somebody, name = somebody, reason = row.reason, buff = buff }
			local line = ns.PickPhrase(fake, ns.PhraseBudget(fake))
			ns.addon:Print("|cff888888" .. row.label .. "|r "
				.. (line or "|cffff8080" .. L["(nothing -- speech off, or no usable lines)"] .. "|r"))
		end
	end
end

-- On the list after Roleplay, which it is the per-character version of.
ns.PHRASE_SETS.incharacter = {
	label = L["In character: your race and faction"],
	text = RP.Text,
}
table.insert(ns.PHRASE_SET_ORDER, 2, "incharacter")
