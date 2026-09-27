-- Manners -- the "In character" phrase set.
--
-- The other sets are a list of lines the player can read and edit in the phrase
-- box. This one is chosen at the moment of the click instead, from lines written
-- for the player's own people and side, and for why the buff is going out:
-- thanking somebody who buffed you first, answering somebody who asked, or
-- offering it unasked. A dwarf says something a dwarf would say.
--
-- And it listens to the moment, which is where the best lines come from: the
-- speaker's class, the spell going out, the spell they gave you when this is a
-- thank-you, how often the two of you have traded this session, whether this
-- is a city, the wilds or a dungeon, the hour, and the class of the person
-- being helped. Each of those is a pool of lines below; a pool joins the draw
-- only when the moment is known to be its moment, and anything the client
-- will not say (a secret, a missing function, a throw) simply leaves its pool
-- out. See RP.Pick for how the pools are weighed against each other.
--
-- It is active while "In character" is the chosen set and the box still holds
-- the examples it put there; editing the box makes the lines the player's own,
-- as editing any set does. Core's ns.PickPhrase and ns.PhraseSetText ask this
-- file, and do exactly what they did before whenever it is not the chosen set,
-- or not loaded at all.
--
-- Somebody else's race is asked for one thing, whether they are kin, and their
-- class for one more, which lines about helping their class apply; on this
-- client both are often secrets, and then neither is used.
--
-- Adding lines: every line is a whole L["..."] literal in the pool it belongs
-- to, in the shape the tables below already have. A pool may hold any number;
-- more lines add variety, not airtime (see RP.SPREAD). {name} is their short
-- name and {buff} the spell going out; {gift} is for RP.TRADE alone.

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
--
-- The first thanks, asked and offer line of each people went into the box as
-- examples; move them freely, RP.LEGACY keeps what beta.9 saved.
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
		kin = {
			L["Stone and hammer keep ye, cousin {name}!"],
			L["From one stout heart to another, {name}. The mountain approves."],
		},
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
		kin = {
			L["Arathor's children stand together, {name}."],
			L["We humans stick together, {name}. Somebody has to hold the line."],
		},
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
		kin = {
			L["Ishnu-alah, {name}. Elune keeps her children close."],
			L["Ten thousand years, and we still look after each other, {name}."],
		},
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
		kin = {
			L["We ren'dorei look after our own, {name}."],
			L["Another who heard the whispers and stayed sane, {name}. Mostly."],
		},
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
		kin = {
			L["For Gnomeregan, {name}! Always nice to talk to somebody at eye level."],
			L["Two gnomes, {name}! Statistically, something is about to explode."],
		},
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
		kin = {
			L["Archenon poros, {name}! The children of Argus look after one another."],
			L["Another long road, {name}. The children of Argus walk it together."],
		},
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
		kin = {
			L["The curse binds us, {name}, but Gilneas binds us tighter."],
			L["One of the pack, {name}. We shed together."],
		},
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
		kin = {
			L["Throm-ka, {name}! The blood of the clans runs strong in you."],
			L["Our ancestors would be proud, {name}. Probably. They were hard to please."],
		},
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
		kin = {
			L["We Forsaken must look after each other, {name}."],
			L["One corpse to another, {name}: you're looking well preserved."],
		},
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
		kin = {
			L["The Earth Mother watches over us both, {name}."],
			L["The herd is never far, {name}. Neither am I."],
		},
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
		kin = {
			L["Hey, {name}! Always good to see family, mon."],
			L["Stay mojo, {name}. Us trolls gotta look out for each udda."],
		},
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
		kin = {
			L["The Sunwell shines for us both, {name}."],
			L["Another child of the sun, {name}. Naturally, we both look splendid."],
		},
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
		kin = {
			L["Suramar's children shine together again, {name}."],
			L["Another Shal'dorei, {name}. Suramar's finest, both of us."],
		},
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
		kin = {
			L["Anything for a fellow entrepreneur, {name}!"],
			L["A fellow goblin, {name}! Friends-and-family rate: still not free."],
		},
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
		kin = {
			L["A fellow wanderer! The caravan is never far, {name}."],
			L["Another tail on the dunes, {name}! The caravan grows."],
		},
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
		kin = {
			L["We must share a brew when the road allows, {name}!"],
			L["Another pandaren! The kettle is never too small, {name}."],
		},
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
		kin = {
			L["The Forbidden Reach feels far behind us now, {name}."],
			L["Another of the Reach, {name}. Wings high."],
		},
	},
}

-- For kin of a people with no kin lines of their own (the Haranir, for now).
RP.KIN = {
	L["It is good to see one of our own, {name}."],
	L["Our people are few, {name}. That makes each of us count."],
}

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

---------------------------------------------------------------------------
-- the moment
--
-- Every pool below is somewhere a line can only be said in one kind of
-- moment. Each joins the draw in RP.Pick only when that moment is known to be
-- this one, and every line in them works whichever of the four moments it is
-- (thanks, asked, offer, group) unless its pool says otherwise.
---------------------------------------------------------------------------

-- The speaker's class (UnitClass's second return), by moment as the peoples'
-- lines are; a group member hears the offers when there are no group lines.
-- A class with no lines of its own simply has none here.
RP.CLASS = {
	MAGE = {
		thanks = {
			L["Most kind, {name}. I'd offer water, but everybody already has some."],
			L["Thank you, {name}. Repaid in the one thing mages never run short of."],
		},
		asked = {
			L["Of course, {name}. And no, this does not come with a free portal."],
			L["Certainly, {name}. Tables are a separate request."],
		},
		offer = {
			L["A little arcane for you, {name}. Try not to spend it on one thought."],
			L["Here, {name}. Side effects may include knowing things."],
		},
		group = {
			L["Arcane for all, {name}. Water's on the table, as usual."],
			L["Hold still, {name}. I've done this in my sleep. Literally, once."],
		},
	},
	PRIEST = {
		thanks = {
			L["Bless you, {name}. The Light saw that, and so did I."],
			L["Thank you, {name}. I'll mention you in my prayers. Favourably."],
		},
		asked = {
			L["Of course, {name}. The Light is free; my patience nearly so."],
			L["Ask and receive, {name}. It's practically in the vows."],
		},
		offer = {
			L["The Light asked me to pass this on, {name}. I rarely argue with it."],
			L["A little faith for the road, {name}. Refills are free."],
		},
		group = {
			L["Hold still, {name}. Heals work best on people who stay alive."],
			L["Blessings all round, {name}. Do stay where I can see you."],
		},
	},
	DRUID = {
		thanks = {
			L["Thank you, {name}. I'd shake your hand, but these are paws today."],
			L["Much obliged, {name}. The Dream thanks you too, in its slow way."],
		},
		asked = {
			L["Of course, {name}. Nature provides, and I deliver."],
			L["Gladly, {name}. Hold still, or I'll have to do this as a bear."],
		},
		offer = {
			L["A gift from the wilds, {name}. Locally grown."],
			L["Take this, {name}. Nature's been meaning to have a word with you."],
		},
		group = {
			L["Gather round, {name}. I only have to change back once for this."],
			L["Everybody gets a little wild, {name}. It's good for you."],
		},
	},
	PALADIN = {
		thanks = {
			L["A kindness, {name}? The oath says I must repay it. Happily."],
			L["Thank you, {name}. Justice demands a favour for a favour."],
		},
		asked = {
			L["At once, {name}. Should it go badly, I do have a bubble. For one."],
			L["Of course, {name}. The Light answers, and so does its hammer."],
		},
		offer = {
			L["The Light protects, {name}. I'm just holding the door."],
			L["A blessing, {name}. We hand these out the way others nod."],
		},
		group = {
			L["Blessings for everybody, {name}. I've been told I'm thorough."],
			L["Line up, {name}. No blessing left behind."],
		},
	},
	WARLOCK = {
		thanks = {
			L["Thank you, {name}. My imp says thanks too. He doesn't mean it."],
			L["How kind, {name}. Usually my gifts cost somebody a soul."],
		},
		asked = {
			L["Of course, {name}. It's perfectly clean. I washed the fel off."],
			L["Certainly, {name}. Ignore the smell of sulphur. It's normal."],
		},
		offer = {
			L["Take this, {name}. Don't ask where I got it."],
			L["A small gift, {name}. No strings attached. Chains, perhaps."],
		},
		group = {
			L["Gather round the nice warlock, {name}. Yes, the nice one."],
			L["A little something for the party, {name}. Healthstones after."],
		},
	},
	WARRIOR = {
		thanks = {
			L["Thanks, {name}! I'd return it quietly, but I don't do quiet."],
			L["Much obliged, {name}. Gratitude, at the top of my lungs."],
		},
		asked = {
			L["You want it, {name}? Then brace yourself!"],
			L["Say no more, {name}! I'll do the saying. Loudly."],
		},
		offer = {
			L["Hear that, {name}? That was the sound of you getting stronger."],
			L["Chin up, {name}! Good advice sounds better at volume."],
		},
		group = {
			L["Everybody hear that, {name}? Good. That was the point."],
			L["Stay close, {name}. My voice only carries so far."],
		},
	},
}

-- About the spell going out, whichever moment it is, by the entry's buff key
-- (Buffs.lua). A spell with no lines here simply has none.
RP.SPELL = {
	intellect = {
		L["A sharper mind for you, {name}. Please use it for good."],
		L["Some arcane insight, {name}. You'll think of a use for it. Now you can."],
	},
	fortitude = {
		L["Stand a bit sturdier, {name}. Walls will be jealous."],
		L["A little more of you to go round, {name}. The Light fills the gaps."],
	},
	spirit = {
		L["Some spirit for you, {name}. It pairs well with a sit-down."],
		L["Breathe in, {name}. The spirit likes an unhurried host."],
	},
	shadow = {
		L["Something against the shadows, {name}. They can be very clingy."],
		L["Shadow ward, {name}. The dark is full of opinions."],
	},
	motw = {
		L["The wild marks you as a friend, {name}. Wolves will be polite."],
		L["Nature's own mark, {name}. Bears will know you're with me."],
	},
	thorns = {
		L["Now anybody who hits you gets the point, {name}."],
		L["Thorns for you, {name}. Hug nobody you like."],
	},
	kings = {
		L["A blessing fit for a king, {name}. Crown not included."],
		L["For the royal in everybody, {name}."],
	},
	might = {
		L["A little might, {name}. Swing like you mean it."],
		L["Might for you, {name}. Please hit things with it, not me."],
	},
	wisdom = {
		L["Some wisdom, {name}. Mana now, good advice later."],
		L["The Light's way of saying think first, {name}."],
	},
	salvation = {
		L["Salvation, {name}. Things will find you less interesting."],
		L["A little salvation, {name}. The monsters will forget you were rude."],
	},
	light = {
		L["The Light, bottled, {name}. Every heal lands warmer now."],
		L["Every heal you get gets better, {name}. You're welcome."],
	},
	sanctuary = {
		L["Sanctuary, {name}. Hits hurt less. Mostly for them."],
		L["Carry this like a shield you can't drop, {name}."],
	},
	battleshout = {
		L["Consider yourself shouted at, {name}. Kindly."],
		L["That shout was for you, {name}. The birds will get over it."],
	},
	breath = {
		L["Now you can breathe underwater, {name}. The fish will be furious."],
		L["Breathe easy, {name}. Underwater, I mean."],
	},
}

-- Thanks only, and only when the spell they gave you is known: {gift} is
-- theirs, {buff} is yours. Left out when the two are the same spell.
RP.TRADE = {
	L["Your {gift} for my {buff}, {name}. A fine trade."],
	L["{gift} in, {buff} out. We're even, {name}."],
	L["Thanks for the {gift}, {name}! Have some {buff}."],
}

-- How often the two of you have traded this session (RP.Familiar): "again"
-- for the second or third time, "regular" for the fourth and on.
RP.HISTORY = {
	again = {
		L["You again, {name}! We should stop meeting like this. Or not."],
		L["Back so soon, {name}? I'm starting to think you like me."],
	},
	regular = {
		L["At this point, {name}, we should just share a campfire."],
		L["{name}, my favourite regular. The usual?"],
		L["Again, {name}? I'm naming my next spell after you."],
	},
}

-- Where this is (RP.Place): "city" is resting, in a city or an inn; "wild" is
-- outdoors; "instance" is a dungeon or a raid. A battleground, an arena or a
-- scenario is none of the three.
RP.PLACE = {
	city = {
		L["Safe inside the walls, {name}, but take this anyway."],
		L["A little something before the innkeeper notices, {name}."],
	},
	wild = {
		L["Out here, {name}, every little bit helps."],
		L["The wilds are unkind, {name}. I'm not."],
	},
	instance = {
		L["Dungeon rules, {name}: stay close, touch nothing that glows."],
		L["Deep breaths, {name}. Whatever's in there can smell fear."],
	},
}

-- The hour on the realm's clock (RP.Hour): "morning" from five to ten,
-- "night" from ten at night to four.
RP.TIME = {
	morning = {
		L["Morning, {name}. This beats a cup of anything."],
		L["An early start, {name}. Here, something to wake you up."],
	},
	night = {
		L["Late hour, {name}. Take this; the dark gets long."],
		L["Still up, {name}? So is everything that hunts at night."],
	},
}

-- The class of the person being helped (RP.Target): "sameclass" when it is
-- the speaker's own, or their class token otherwise. Gentle, and never at
-- their expense: the joke is on the help, the speaker or the world.
RP.TARGET = {
	sameclass = {
		L["One of my own trade, {name}! We should compare notes."],
		L["From one of us to another, {name}. Professional courtesy."],
	},
	WARRIOR = {
		L["For whoever stands in front, {name}. Thank you for that."],
		L["A little extra for the front line, {name}. It needs it most."],
	},
	ROGUE = {
		L["I'd have given you this sooner, {name}, but I didn't see you."],
		L["Here, {name}. Don't worry, I never saw you. Officially."],
	},
	HUNTER = {
		L["One for you, {name}. Your companion gets the next one."],
		L["For you, {name}, and a pat for your friend."],
	},
	DEATHKNIGHT = {
		L["Something to take the chill off, {name}."],
		L["A little warmth, {name}. Of a sort."],
	},
}

-- The five lines beta.9 put in the box, frozen: a box saved with them is
-- still the untouched set however the pools above are rewritten, and the load
-- repair (RP.Repair) turns it into the examples as they read now. Nothing
-- here is ever said; these only recognise. Per people: its first thanks,
-- asked and offer; per side: the same three; then the general lines. A
-- people with none (the Haranir) saved its side's three and the general
-- thanks and offer; any other saved its three, its side's offer and the
-- general group line.
RP.LEGACY = {
	race = {
		dwarf = {
			L["Thank ye kindly, {name}! First round's on me when we're back at the forge."],
			L["Aye, {name}, ye only had to ask. Hold still now!"],
			L["Here, {name}, a wee somethin' to keep ye on yer feet."],
		},
		human = {
			L["My thanks, {name}. Allow me to return the kindness."],
			L["Of course, {name}. Stand fast a moment."],
			L["The road ahead is long, {name}. Take this with you."],
		},
		nightelf = {
			L["Ishnu-alah, {name}. Your kindness is returned."],
			L["Gladly, {name}. Be still, and let the moonlight find you."],
			L["Elune-adore, {name}. Walk softly beneath the stars."],
		},
		voidelf = {
			L["The shadows remember kindness, {name}. So do I."],
			L["As you wish, {name}. The shadows answer kindly today."],
			L["A touch of shadow for you, {name}. Quite safe. Mostly."],
		},
		gnome = {
			L["Thanks, {name}! Kindness received, catalogued and returned!"],
			L["Request received, {name}! Processing... done!"],
			L["Hold still, {name}, this is perfectly safe. Probably!"],
		},
		draenei = {
			L["The Light rewards kindness, {name}, and so shall I."],
			L["Of course, {name}. May the Naaru guide your steps."],
			L["The Light is with you, {name}. Go in peace."],
		},
		worgen = {
			L["Much obliged, {name}. Gilneas never forgets a kindness."],
			L["Certainly, {name}. Hold still, I don't bite. Much."],
			L["Stay off the moors after dark, {name}. Take this."],
		},
		orc = {
			L["Throm-ka, {name}! Honour is repaid."],
			L["Dabu, {name}. It is done."],
			L["Lok'tar ogar, {name}! Take this into battle."],
		},
		forsaken = {
			L["Thank you, {name}. It would warm my heart, if it still beat."],
			L["Certainly, {name}. Try not to die. It's overrated."],
			L["Stay among the living a little longer, {name}."],
		},
		tauren = {
			L["The Earth Mother sees your kindness, {name}. I return it."],
			L["Of course, {name}. Stand tall and be at peace."],
			L["Walk with the Earth Mother, {name}."],
		},
		troll = {
			L["Ya be too kind, {name}! Dis one be from me."],
			L["Sure ting, {name}. Hold still now."],
			L["Da loa be watchin' over ya, {name}."],
		},
		bloodelf = {
			L["Such courtesy does you credit, {name}. Anar'alah belore."],
			L["Naturally, {name}. Only the finest for you."],
			L["Anar'alah belore, {name}. May the sun guide you."],
		},
		nightborne = {
			L["Your generosity is noted, {name}. Suramar remembers its friends."],
			L["Of course, {name}. A little arcane polish, just for you."],
			L["Take this, {name}. Arcane gifts are wasted on the idle."],
		},
		goblin = {
			L["A favour for a favour, {name}! Pleasure doing business."],
			L["You got it, {name}! Time is money, friend!"],
			L["This one's on the house, {name}. Don't tell the Trade Prince."],
		},
		vulpera = {
			L["Thank you, {name}! The caravan always repays a kindness."],
			L["Of course, {name}! Shake the sand out and hold still."],
			L["Every traveller needs something for the road, {name}."],
		},
		pandaren = {
			L["A kindness returned is a kindness doubled, {name}."],
			L["Of course, {name}. Patience, and it is done."],
			L["Take this, {name}. And perhaps a cup of tea afterward?"],
		},
		dracthyr = {
			L["Your kindness is noted, {name}. Dragons do not forget."],
			L["Very well, {name}. Stand still, I would hate to singe you."],
			L["Take this, {name}. Even a dragon needs allies."],
		},
	},
	side = {
		Alliance = {
			L["Thank you, {name}. The Alliance looks after its own."],
			L["Of course, {name}. Allies help each other."],
			L["For the Alliance, {name}! Stay strong out there."],
		},
		Horde = {
			L["Strength and honour, {name}. Your kindness is repaid."],
			L["Consider it done, {name}. For the Horde."],
			L["For the Horde, {name}! Go with strength."],
		},
		Neutral = {
			L["Thank you, {name}. Good hearts are found everywhere."],
			L["Gladly, {name}, whatever banner you fly."],
			L["Friends can come from any side, {name}."],
		},
	},
	general = {
		thanks = L["One good turn deserves another, {name}."],
		offer = L["Safe travels, {name}. Take some {buff} with you."],
		group = L["Everyone ready? You are now, {name}."],
	},
}

-- How much of the draw each pool gets. A pool's share is its weight times
-- the number of its lines that fit, counted up to RP.SPREAD, split evenly
-- between them: a pool of one line is heard a third as often as a full one
-- (a single line said too often grates), and a pool of thirty no more often
-- than one of three, so writing more lines buys variety and never airtime.
--
-- A people's own lines weigh most, so a dwarf sounds like a dwarf over a
-- session; the moments that are rare and made for this very click (a trade,
-- kin, somebody met again) weigh as much or nearly, so they come up when they
-- apply; the moments that are nearly always true (a place, an hour, the
-- spell) weigh little each, since several of them apply at once. Worked
-- through for full pools: a stranger outdoors at midday hears their people
-- about a third of the time, and a favour whose spell is known is returned
-- with a trade line about a quarter of the time, as often as the people's.
-- In a group the group lines are the point, so they outweigh the side's.
RP.WEIGHT = {
	race = 8, kin = 8, class = 3, faction = 2, general = 1, group = 3,
	spell = 3, trade = 8, history = 6, place = 2, time = 2, target = 3,
}
RP.SPREAD = 3

do
	-- The reason on a queue entry to the kind of line it wants. The target,
	-- nearby and anything new all get an offer.
	local KIND = { owed = "thanks", asked = "asked", group = "group" }

	local GetTime = _G.GetTime

	-- Our own race, faction and class are ours to read, but through ns.plain
	-- anyway: a secret must never reach a comparison.
	local function Ask(fn, ...)
		if type(fn) ~= "function" then return nil end
		local ok, a, b = pcall(fn, ...)
		if not ok then return nil end
		return ns.plain(a), ns.plain(b)
	end

	-- What the client answers where "no" is an answer too (IsResting says
	-- false, IsInInstance false): known is false when it would not say at
	-- all -- no such function, a throw, or a secret in either answer.
	local function Read(fn, ...)
		if type(fn) ~= "function" then return false end
		local ok, a, b = pcall(fn, ...)
		if not ok then return false end
		local secret = _G.issecretvalue
		if secret and (secret(a) or secret(b)) then return false end
		return true, a, b
	end

	-- A class token that may be compared and used as a key: MAGE, PRIEST.
	local function ClassToken(value)
		value = ns.plain(value)
		if type(value) ~= "string" or #value > 20 or not value:find("^%u+$") then return nil end
		return value
	end

	-- The player's people ("dwarf", or nil for a race with no family), side
	-- ("Alliance", "Horde" or "Neutral") and class token (nil when unknown).
	function RP.Player()
		local _, race = Ask(_G.UnitRace, "player")
		local faction = Ask(_G.UnitFactionGroup, "player")
		if faction ~= "Alliance" and faction ~= "Horde" then faction = "Neutral" end
		local _, class = Ask(_G.UnitClass, "player")
		return RP.FAMILY[race], faction, ClassToken(class)
	end

	-- The lines a table has for this kind of moment; a group member hears the
	-- offers when there are no group lines.
	local function PoolFor(tbl, kind)
		if type(tbl) ~= "table" then return nil end
		return tbl[kind] or (kind == "group" and tbl.offer) or nil
	end
	RP.PoolFor = PoolFor

	-- The unit token on the entry, while it still holds the person on it. It
	-- was taken when the queue was built and may since be somebody else, so
	-- their name has to still be on it.
	local function Holding(entry)
		if type(entry) ~= "table" or type(entry.unit) ~= "string" then return nil end
		local ok, name = pcall(ns.UnitFullName, entry.unit)
		if not ok or name == nil or name ~= entry.name then return nil end
		return entry.unit
	end

	-- Whether the person on the prompt is of our people. Their race is often
	-- a secret for a stranger, and then they are not kin as far as anybody
	-- can tell.
	function RP.IsKin(entry, family)
		if not family then return false end
		local unit = Holding(entry)
		if not unit then return false end
		local _, race = Ask(_G.UnitRace, unit)
		return race ~= nil and RP.FAMILY[race] == family
	end

	-- Which RP.TARGET pool the person being helped calls for: "sameclass" for
	-- our own class, their class token otherwise, nil when it is unknown. The
	-- queue read their class with their name; a token still holding them is
	-- asked when it did not.
	function RP.Target(entry, mine)
		if type(entry) ~= "table" then return nil end
		local theirs = ClassToken(entry.class)
		if not theirs then
			local unit = Holding(entry)
			if unit then
				local _, class = Ask(_G.UnitClass, unit)
				theirs = ClassToken(class)
			end
		end
		if not theirs then return nil end
		if theirs == mine then return "sameclass" end
		return theirs
	end

	local function SpellName(id)
		local spells = _G.C_Spell
		local name = spells and Ask(spells.GetSpellName, id)
		if name == nil then name = Ask(_G.GetSpellInfo, id) end
		return name
	end

	-- The name of the spell they gave you, for {gift}, or nil when it is not
	-- known. The debt records it (Core's NoteFavour files the spell with the
	-- favour); a debt kept across a reload does not, and gets no trade line.
	-- Roll a few hands in a stand-in as entry.gift.
	function RP.Gift(entry)
		if type(entry) ~= "table" then return nil end
		local name = entry.gift
		if name == nil then
			local owed = ns.owed
			local debt = type(owed) == "table" and type(entry.name) == "string" and owed[entry.name]
			local id = type(debt) == "table" and ns.plain(debt.spell) or nil
			if type(id) ~= "number" then return nil end
			name = SpellName(id)
		end
		name = ns.plain(name)
		if type(name) ~= "string" or name == "" or name:find("[|\r\n]") then return nil end
		return name
	end

	-- Where this is, for RP.PLACE: "instance" in a dungeon or raid, "city"
	-- while resting (a city or an inn), "wild" anywhere else outdoors; nil in a
	-- battleground, an arena or a scenario, and whenever the client will not
	-- say, since the wilds guessed in an inn read wrong.
	function RP.Place()
		local known, inside, what = Read(_G.IsInInstance)
		if not known then return nil end
		if inside then
			if what == "party" or what == "raid" then return "instance" end
			return nil
		end
		local sure, resting = Read(_G.IsResting)
		if not sure then return nil end
		if resting then return "city" end
		return "wild"
	end

	-- The hour on the realm's clock, for RP.TIME: "morning" from five until
	-- eleven, "night" from ten at night until five, nil in between and when
	-- the client will not say.
	function RP.Hour()
		local known, hour = Read(_G.GetGameTime)
		if not known or type(hour) ~= "number" then return nil end
		if hour >= 5 and hour <= 10 then return "morning" end
		if hour >= 22 or hour <= 4 then return "night" end
		return nil
	end

	-- How often buffs have passed between the player and each person this
	-- session, for RP.HISTORY. Core tells this file what it tells the ledger
	-- (TellLedger) and it counts as it goes, in memory only: "again" is about
	-- today's session, and the ledger on disk is a record, never a decision.
	-- A favour counts once when it arrives, however many buffs it arrives as,
	-- and its return completes it rather than counting again; a buff given
	-- unasked or asked for counts once.
	local met = {}        -- [name] = exchanges this session
	local waiting = {}    -- [name] = true while a counted favour is unreturned
	local lastSettle = {} -- [name] = the last settle, for a refusal to take back
	local people = 0      -- names in met, so a long session cannot grow it forever
	local MAX_PEOPLE = 500

	local function Count(name, by)
		if met[name] == nil then
			if people >= MAX_PEOPLE then
				wipe(met)
				wipe(waiting)
				wipe(lastSettle)
				people = 0
			end
			people = people + 1
		end
		met[name] = math.max(0, (met[name] or 0) + by)
	end

	function RP.Heard(event, a, b)
		if event == "Received" then
			-- a = the favour (name, spell, class), b = nothing we cast helps them
			local name = type(a) == "table" and a.name
			if type(name) ~= "string" then return end
			if not waiting[name] then Count(name, 1) end
			if not b then waiting[name] = true end
		elseif event == "Settled" then
			-- a = the name, b = the debt that stood, nil for a buff unasked
			if type(a) ~= "string" then return end
			local gift = not b
			-- A debt kept from before a reload was never counted here.
			if gift or not waiting[a] then Count(a, 1) end
			waiting[a] = nil
			lastSettle[a] = { clock = GetTime(), gift = gift }
		elseif event == "Refused" then
			-- a = the name, b = the stamp on the settle the server refused
			local undo = type(a) == "string" and lastSettle[a]
			if not undo or undo.clock ~= b then return end
			lastSettle[a] = nil
			if undo.gift then Count(a, -1) else waiting[a] = true end
		elseif event == "LetGo" then
			if type(a) == "string" then waiting[a] = nil end
		end
	end

	-- Which RP.HISTORY pool this exchange calls for: "again" for the second
	-- or third this session, "regular" from the fourth, nil for the first. A
	-- thank-you is for a favour already counted; anything else is one more.
	-- Roll a few hands in its own count as entry.met.
	function RP.Familiar(entry, kind)
		if type(entry) ~= "table" then return nil end
		local n = entry.met
		if type(n) ~= "number" then
			local name = entry.name
			if type(name) ~= "string" then return nil end
			n = met[name] or 0
			if not (kind == "thanks" and waiting[name]) then n = n + 1 end
		end
		if n >= 4 then return "regular" end
		if n >= 2 then return "again" end
		return nil
	end

	-- One line for this person, now, with the channel command in front, or nil
	-- when nothing fits. Every pool the moment calls for is gathered, each at
	-- its share of the draw (RP.WEIGHT, RP.SPREAD), and every candidate is
	-- measured before the roll rather than after it, so a long name or spell
	-- leaves the shorter lines to choose from instead of silence.
	--
	-- entry.lean (Roll a few's context rows) keeps the draw to the pool of
	-- that name, where it has a line that fits. The queue never sets it.
	function RP.Pick(entry, command, budget)
		if type(entry) ~= "table" or type(command) ~= "string" or type(budget) ~= "number" then
			return nil
		end
		local family, faction, class = RP.Player()
		local kind = KIND[entry.reason] or "offer"
		local name = entry.short or entry.name
		local buff = entry.buff and ns.BuffName(entry.buff)
		local gift = kind == "thanks" and RP.Gift(entry) or nil
		-- "Your Fortitude for my Fortitude" is no trade.
		if gift ~= nil and gift == buff then gift = nil end
		local weight, spread = RP.WEIGHT, RP.SPREAD

		local lines, weights, tags, total = {}, {}, {}, 0
		local function add(pool, share, tag)
			if type(pool) == "string" then pool = { pool } end
			if type(pool) ~= "table" or type(share) ~= "number" then return end
			local first = #lines + 1
			for _, text in ipairs(pool) do
				-- A line that would say an empty name or spell is left out,
				-- not said with a hole in it.
				local usable = type(text) == "string"
					and (name or not text:find("{name}", 1, true))
					and (buff or not text:find("{buff}", 1, true))
					and (gift or not text:find("{gift}", 1, true))
				if usable then
					local said = ns.Swap(ns.Swap(ns.Swap(text, "{name}", name), "{buff}", buff), "{gift}", gift)
					said = said:gsub("[\r\n]", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")
					local line = "/" .. command .. " " .. said
					if said ~= "" and #line <= budget then
						lines[#lines + 1] = line
						tags[#lines] = tag
					end
				end
			end
			local fits = #lines - first + 1
			if fits == 0 then return end
			local each = share * math.min(fits, spread) / fits
			for i = first, #lines do
				weights[i] = each
				total = total + each
			end
		end

		-- Who is speaking.
		local race = RP.RACE[family]
		add(PoolFor(race, kind), weight.race, "race")
		if RP.IsKin(entry, family) then add((race and race.kin) or RP.KIN, weight.kin, "kin") end
		local side = RP.FACTION[faction]
		if kind == "group" then
			add(side.group, weight.group, "group")
			add(side.offer, weight.faction, "faction")
			add(RP.GENERAL.group, weight.group, "group")
		else
			add(PoolFor(side, kind), weight.faction, "faction")
			add(RP.GENERAL[kind], weight.general, "general")
		end
		add(PoolFor(RP.CLASS[class], kind), weight.class, "class")

		-- And the moment.
		add(type(entry.buff) == "table" and RP.SPELL[entry.buff.key], weight.spell, "spell")
		if gift then add(RP.TRADE, weight.trade, "trade") end
		add(RP.HISTORY[RP.Familiar(entry, kind)], weight.history, "history")
		add(RP.PLACE[RP.Place()], weight.place, "place")
		add(RP.TIME[RP.Hour()], weight.time, "time")
		add(RP.TARGET[RP.Target(entry, class)], weight.target, "target")
		if total <= 0 then return nil end

		local lean = entry.lean
		if lean ~= nil then
			local leaning = 0
			for i = 1, #lines do
				if tags[i] == lean then leaning = leaning + weights[i] end
			end
			if leaning > 0 then
				for i = 1, #lines do
					if tags[i] ~= lean then weights[i] = 0 end
				end
				total = leaning
			end
		end

		local roll = math.random() * total
		for i = 1, #lines do
			roll = roll - weights[i]
			if roll < 0 then return lines[i] end
		end
		-- Only rounding gets here: the last line with any share.
		for i = #lines, 1, -1 do
			if weights[i] > 0 then return lines[i] end
		end
		return nil
	end

	-- The first line of a pool, or with english, as it read before
	-- translation.
	local function First(pool, english)
		local text = pool
		if type(pool) == "table" then text = pool[1] end
		if type(text) ~= "string" then return nil end
		return english and ENGLISH[text] or text
	end

	-- The five lines the box opens with for a people and side, from the pools
	-- as they are or, with frozen, from RP.LEGACY as beta.9 saved them.
	local function Head(family, faction, english, frozen)
		local out = {}
		local function put(pool)
			local text = First(pool, english)
			if text then out[#out + 1] = text end
		end
		if frozen then
			local race, side, general = RP.LEGACY.race[family], RP.LEGACY.side[faction] or {}, RP.LEGACY.general
			if race then
				put(race[1]) put(race[2]) put(race[3]) put(side[3]) put(general.group)
			else
				put(side[1]) put(side[2]) put(side[3]) put(general.thanks) put(general.offer)
			end
		else
			local race, side = RP.RACE[family], RP.FACTION[faction] or {}
			if race then
				put(race.thanks) put(race.asked) put(race.offer) put(side.offer) put(RP.GENERAL.group)
			else
				put(side.thanks) put(side.asked) put(side.offer) put(RP.GENERAL.thanks) put(RP.GENERAL.offer)
			end
		end
		return table.concat(out, "\n")
	end

	-- The lines after them that show the set noticing the moment: one of the
	-- class's offers, somebody met again, and a dungeon.
	local function Tail(class, english)
		local out = {}
		local function put(pool)
			local text = First(pool, english)
			if text then out[#out + 1] = text end
		end
		put(PoolFor(RP.CLASS[class], "offer"))
		put(RP.HISTORY.again)
		put(RP.PLACE.instance)
		return table.concat(out, "\n")
	end

	local function Join(head, tail)
		if tail == "" then return head end
		if head == "" then return tail end
		return head .. "\n" .. tail
	end

	-- What the phrase box shows for a people, side and class: a few lines of
	-- each kind, always the same ones, so the box can be recognised as
	-- untouched. With english, the same lines as they read before translation.
	function RP.Examples(family, faction, class, english)
		return Join(Head(family, faction, english), Tail(class, english))
	end

	-- The examples for whoever is logged in.
	function RP.Text()
		return RP.Examples(RP.Player())
	end

	local FACTIONS = { "Alliance", "Horde", "Neutral" }
	local lastText, lastAnswer

	-- Whether text is the examples of any people, side and class, in the
	-- client's language or, with english, as they read before translation;
	-- with frozen, beta.9's five lines count too.
	local function IsExamples(text, english, frozen)
		local tails = { Tail(nil, english) }
		for class in pairs(RP.CLASS) do tails[#tails + 1] = Tail(class, english) end
		local families = { false }
		for family in pairs(RP.RACE) do families[#families + 1] = family end
		for _, faction in ipairs(FACTIONS) do
			for _, family in ipairs(families) do
				family = family or nil
				local head = Head(family, faction, english)
				if text:sub(1, #head) == head then
					for _, tail in ipairs(tails) do
						if text == Join(head, tail) then return true end
					end
				end
				if frozen and text == Head(family, faction, english, true) then return true end
			end
		end
		return false
	end

	-- Whether "In character" is what speaks. The box is compared with the
	-- examples of every people, side and class, not only this character's: a
	-- profile is often shared by several characters, and the dwarf mage who
	-- picked the set has not edited anything the orc warrior on the same
	-- profile should lose. English examples count too, saved by a player who
	-- picked the set before its lines were translated into their language, and
	-- so do the five lines beta.9 saved.
	function RP.Active(speech)
		if type(speech) ~= "table" or speech.presetChoice ~= "incharacter" then return false end
		local text = speech.phrases
		if type(text) ~= "string" then return false end
		if text == lastText then return lastAnswer end
		local answer = IsExamples(text, false, true) or IsExamples(text, true, true)
		lastText, lastAnswer = text, answer
		return answer
	end

	-- The load-time repair (Core's ClampSettings) for this set: examples saved
	-- in English, or in beta.9's five lines, become this character's examples
	-- as they read now in the client's language, as the fixed sets' English
	-- text does, so the box and an export read like an untouched set. On an
	-- English client an untouched box of today's is left as it is.
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
	-- And two moments the set notices, each leaning on the lines written for
	-- it so the row shows one: a favour whose spell is known, and somebody met
	-- for the third time.
	local GIFTED = { reason = "owed", lean = "trade", label = L["Returning a favour of %s:"] }
	local AGAIN = { reason = "nearby", lean = "history", met = 3, label = L["Meeting somebody a third time:"] }
	local AGAIN_OWED = { reason = "owed", lean = "history", met = 3, label = AGAIN.label }

	-- A spell somebody else might have given: the first of these that is not
	-- the one this character gives, named as the client names it.
	local STAND_INS = { { "PRIEST", "fortitude" }, { "DRUID", "motw" }, { "MAGE", "intellect" } }
	local function StandInGift(buff)
		local mine = buff and ns.BuffName(buff)
		for _, pick in ipairs(STAND_INS) do
			local other = ns.FindBuff(pick[1], pick[2])
			local id = other and other.ranks and other.ranks[1]
			local name = id and SpellName(id)
			if type(name) == "string" and name ~= "" and name ~= mine then return name end
		end
		return nil
	end

	-- Roll a few for this set: a line for each reason speech is on for, since
	-- the set speaks differently for each, then a favour whose spell is known
	-- and somebody met again, all through ns.PickPhrase and the same budget
	-- the cast path measures. Speaking only when returning a favour keeps to
	-- the favours.
	function RP.Roll(somebody)
		local speech = ns.db and ns.db.profile and ns.db.profile.speech
		local only = speech and speech.onlyWhenReturning
		local buff = ns.ResolveBuff(true)
		local gift = StandInGift(buff)
		local rows = only and { ROLL[1] } or { ROLL[1], ROLL[2], ROLL[3], ROLL[4] }
		if gift then rows[#rows + 1] = GIFTED end
		rows[#rows + 1] = only and AGAIN_OWED or AGAIN
		for _, row in ipairs(rows) do
			local fake = { short = somebody, name = somebody, reason = row.reason, buff = buff,
				lean = row.lean, met = row.met, gift = row.lean == "trade" and gift or nil }
			local line = ns.PickPhrase(fake, ns.PhraseBudget(fake))
			local label = row.label
			if row == GIFTED then label = label:format(gift) end
			ns.addon:Print("|cff888888" .. label .. "|r "
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
