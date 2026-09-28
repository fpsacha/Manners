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
-- thank-you (and what that spell does), how often the two of you have traded
-- this session, whether this is a city, the wilds, a dungeon or a battlefield,
-- the hour (and whether it is the speaker's people's hour), and the class of
-- the person being helped. Each of those is a pool of lines below; a pool
-- joins the draw only when the moment is known to be its moment, and anything
-- the client will not say (a secret, a missing function, a throw) simply
-- leaves its pool out. See RP.Pick for how the pools are weighed against each
-- other, and for the short memory that keeps a line from being heard twice in
-- a row.
--
-- It is active while "In character" is the chosen set and the box still holds
-- the examples it put there; editing the box makes the lines the player's own,
-- as editing any set does. Speech.lua's ns.PickPhrase and ns.PhraseSetText ask this
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
-- name and {buff} the spell going out; {gift} is for RP.TRADE and RP.GIFT
-- alone, the only pools that join when somebody has given you something.

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
-- "asked" for answering a request, "offer" for a buff nobody asked for, "group"
-- for somebody in your own party -- no road, no stranger, no "well met" to a
-- person you have fought beside for an hour -- and "kin" for somebody of the
-- same people. A people with the hour in its bones (the night elves' night,
-- the pandaren's breakfast) has "night" or "morning" lines too, heard next to
-- everybody's at that hour (RP.TIME). Every line is a whole literal so it can be
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
			L["Thank ye, {name}! I'd have been fine without it, mind. But thank ye."],
			L["Bless ye, {name}! I'd hug ye, but ye'd be needin' a healer after."],
			L["Paid back already, {name}. Quicker than I've ever settled a bar tab."],
			L["I'll tell this at the Thunderbrew like ye saved me life, {name}. Thank ye!"],
			L["Grand, {name}! I'd carve ye a statue, but this is quicker."],
			L["The Titans made us of stone, {name}, but that still touched me. Thank ye."],
		},
		asked = {
			L["Aye, {name}, ye only had to ask. Hold still now, like a good anvil."],
			L["Say no more, {name}. Stone and steel, here it comes."],
			L["Ask a dwarf fer help, {name}, and ye'll get it. Loudly."],
			L["Right, {name}. Brace yerself; I do everything like I'm swingin' a hammer."],
			L["Aye, {name}, and a story about it ye didn't ask fer. Where to begin..."],
			L["One {buff}, pulled fresh like a proper pint, {name}."],
			L["Done, {name}. Dwarven work: over-built, under-priced and guaranteed."],
		},
		offer = {
			L["Here, {name}, a wee somethin' to keep ye on yer feet. Wee, like me."],
			L["Off ye go, {name}, steady as the mountain."],
			L["Here, {name}. Ale's for after; this is for before."],
			L["Magni turned to diamond fer the cause, {name}. This is the cheaper option."],
			L["A dwarf's got yer back, {name}. Well, yer knees. Close enough."],
			L["If a trogg bothers ye, {name}, tell it a dwarf sent ye. Then run."],
			L["If it wears off, {name}, give it a good thump. That's how we fix everything."],
			L["Take this, {name}. I'd give ye some stubbornness too, but I'm usin' all mine."],
		},
		kin = {
			L["Stone and hammer keep ye, cousin {name}!"],
			L["Three Hammers, one round, cousin {name}!"],
			L["Yer cousin's cousin married mine, {name}, I'd wager. It's a small mountain."],
			L["Two dwarves together, {name}. Pity whatever's standin' in our way."],
		},
		group = {
			L["Stand behind me, {name}. Aye, I know. Crouch a bit."],
			L["Right, {name}: I take the front, ye take the loot, and we argue after."],
			L["If I start singin', {name}, the fight's gone well. Or very badly."],
			L["Dwarves never leave a mate behind, {name}. Nor a keg. Mates first, mind."],
			L["Beards out, {name}! Them without beards, look fierce. It's nearly as good."],
		},
		morning = {
			L["Mornin', {name}! Too early for ale. Almost. Have this first."],
			L["Up with the forge fires, {name}! A dwarf's day starts with a hammer and this."],
			L["Early, {name}? Nonsense. The mine's been open two hours. Here."],
		},
	},
	human = {
		thanks = {
			L["My thanks, {name}. Let me return the kindness before a bard gets it wrong."],
			L["Kindly done, {name}. Let no one say we forget a friend."],
			L["Thank you, {name}. I'd knight you, but apparently I 'need permission'."],
			L["Repaid on the spot, {name}. In Stormwind that'd take three forms and a stamp."],
			L["Thanks, {name}. I'd pay in gold, but Stormwind still owes the stonemasons."],
			L["Much obliged, {name}. Mother said always return a kindness. And the dish."],
			L["Thank you, {name}. Consider the scales balanced, by royal decree. Mine."],
			L["You shame me, {name}; I should have thought of it first. Allow me."],
		},
		asked = {
			L["Of course, {name}. Hold still and look heroic; it helps the bards."],
			L["Right away, {name}. Keep your shield high."],
			L["More work? Gladly, {name}. It beats the lumber mill."],
			L["Of course, {name}. Humans excel at helping and overpromising. This is helping."],
			L["Certainly, {name}. Humans are quick learners; I learned this one yesterday."],
			L["Hold still, {name}, like a statue in the Valley of Heroes. You'd fit right in."],
			L["Right away, {name}. The Light helps those who ask. So do I, and I'm quicker."],
		},
		offer = {
			L["The road ahead is long, {name}. This won't shorten it, but it'll help."],
			L["Fair winds and following seas, {name}."],
			L["Take this, {name}. Elves have centuries to be generous; I've got fifty years."],
			L["A little something, {name}. Don't tell the guards; they'll all want one."],
			L["Here, {name}. If a kobold asks, you don't have a candle."],
			L["For you, {name}. A human gift: well meant, hastily made, surprisingly sturdy."],
			L["Mind the murlocs, {name}. Take this; I've seen what they do to a picnic."],
			L["Every road needs a hero, {name}. Today it's me, apparently. Take this."],
		},
		-- Stormwind and Kul Tiras are both this family, and both Arathor's.
		kin = {
			L["Arathor's children stand together, {name}."],
			L["A fellow human, {name}! Quick, let's found a kingdom before lunch."],
			L["Stormwind or Boralus, {name}, we'll both complain about the weather."],
			L["Human to human, {name}: no, I don't know why everything happens to us either."],
		},
		group = {
			L["Keep close, {name}. Humans have always won by outnumbering things."],
			L["Stay in formation, {name}. We haven't got one, but stay in it anyway."],
			L["I'll draw up a plan, {name}, and then we can all ignore it together."],
			L["Every hero in the songs had friends, {name}. Nobody sings about them. I will."],
			L["Shields up, {name}. Stormwind taught me to march; nobody taught me to stop."],
		},
	},
	nightelf = {
		thanks = {
			L["Ishnu-alah, {name}. Returned the same day, which for a kaldorei is rushing."],
			L["Thank you, {name}. Elune smiles on the generous."],
			L["Thank you, {name}. Even the wisps glow brighter, and they're hard to impress."],
			L["Elune saw that, {name}. She sees everything, so I had best return it."],
			L["Thank you, {name}. Returned before I nap for a century or two."],
			L["Thank you, {name}. The Ancients will hear of this. They're dreadful gossips."],
			L["Thank you, {name}. I'll tell the Sentinels to stop aiming at you."],
			L["My people never hurry, {name}. For you, an exception."],
		},
		asked = {
			L["Gladly, {name}. Be still, and let the moonlight find you."],
			L["Of course, {name}. Elune's blessings are meant to be shared."],
			L["At last, {name}! I've waited ten thousand years for someone to ask."],
			L["No riddle, no omen from Elune, {name}. Just a plain yes, for once."],
			L["Of course, {name}. Ask in Darnassian next time and I'll add a bow."],
			L["Elune already said yes, {name}. I'm merely catching up."],
			L["Of course, {name}. Stand still and pretend you're a tree. It helps."],
		},
		offer = {
			L["Elune-adore, {name}. Walk softly; the trees are light sleepers."],
			L["May the forest shelter you, {name}, wherever you roam."],
			L["A gift from the shadows, {name}. No, don't look. You won't find me."],
			L["Elune lights your path, {name}. I'm merely holding the lantern."],
			L["The owls pointed you out, {name}. They have strong opinions. Here."],
			L["Tyrande would insist, {name}, and nobody argues with Tyrande."],
			L["Take this, {name}. The last one went to a hippogryph. It was less grateful."],
			L["Mind the wildlife, {name}. Half of it is a druid, and all of it is watching."],
		},
		kin = {
			L["Ishnu-alah, {name}. Elune keeps her children close."],
			L["Of course I saw you, {name}. It takes a kaldorei to spot a kaldorei."],
			L["One kaldorei to another, {name}: we lost a tree, never each other."],
			L["A kaldorei never leaves kin in the dark, {name}. Unless it's for cover."],
		},
		group = {
			L["Quick one, {name}? By kaldorei reckoning we'll be done before we start."],
			L["I'll be the one you can't see, {name}. That's not a mistake; that's the plan."],
			L["Elune watches the whole party, {name}. I'm just the one who waves at her."],
			L["Ten thousand years of companions, {name}. You lot rank rather high."],
			L["Stay close, {name}. We kaldorei misplaced two World Trees. Not you, though."],
		},
		night = {
			L["The moon's up, {name}. For a kaldorei, this is the middle of the morning."],
			L["Everyone sensible is asleep, {name}. Elune and I prefer it this way."],
			L["Moonlight suits you, {name}. This is merely a second layer."],
		},
		morning = {
			L["Morning, {name}. My people slept through these for millennia. I'm adapting."],
			L["Dawn, {name}. Elune's gone to bed, so I'm covering for her."],
			L["The sun's up, {name}, and so, reluctantly, am I."],
		},
	},
	voidelf = {
		thanks = {
			L["The shadows remember kindness, {name}. So do I."],
			L["My thanks, {name}. The ren'dorei do not forget a kindness."],
			L["Thank you, {name}. The voices approve of you, which is frankly alarming."],
			L["Thank you, {name}. Few give gifts to someone who glows this ominously."],
			L["Kindness is rare in the Void, {name}. I'll return yours before it notices."],
			L["Silvermoon threw us out, {name}. People like you make it hard to mind."],
			L["Returned in full, {name}. It may be slightly purple. That's normal."],
			L["The Void only takes, {name}. I, however, give back."],
		},
		asked = {
			L["As you wish, {name}. The shadows answer kindly today."],
			L["Consider it done, {name}. The Void obeys us, not the other way round."],
			L["Certainly, {name}. The whispers said no, so it's an easy yes."],
			L["Of course, {name}. One {buff}, lightly seasoned with the Void."],
			L["Of course, {name}. Hold still; the shadows are shy with strangers."],
			L["Gladly, {name}. Ren'dorei manners: the Void waits its turn."],
			L["Asked so nicely, {name}? The Void never says please. Here."],
		},
		offer = {
			L["A touch of shadow for you, {name}. Quite safe. Mostly."],
			L["Walk carefully in the dark places, {name}."],
			L["A little something from the Telogrus Rift, {name}. It's cleaner than it sounds."],
			L["Take this, {name}. Any tentacles you see are purely decorative."],
			L["The shadows asked after you, {name}. I told them to mind their manners."],
			L["Here, {name}. We walked into the Void so you wouldn't have to."],
			L["I checked your shadow, {name}. Nothing lurking. Take this anyway."],
			L["Umbric sends his regards, {name}. He doesn't, but he would."],
		},
		kin = {
			L["We ren'dorei look after our own, {name}."],
			L["Silvermoon's loss, {name}. We're doing splendidly without it."],
			L["Your whispers and mine should really meet sometime, {name}."],
			L["Two ren'dorei in one place, {name}. Quick, look brooding. It's expected."],
		},
		group = {
			L["Stay close, {name}. The whispers are much quieter in company."],
			L["If the shadows start giving orders, {name}, ignore them. I usually do."],
			L["Keep an eye on my shadow, {name}. It wanders off when there's a fight."],
			L["If I start glowing purple, {name}, carry on. It only means I'm keen."],
			L["We ren'dorei make fine companions, {name}. We bring our own dark to hide in."],
		},
		night = {
			L["Night suits the ren'dorei, {name}. We match the decor."],
			L["The shadows are longest now, {name}, and in a very generous mood."],
			L["Late, {name}? The whispers love a late hour. Lately, so do I."],
		},
	},
	gnome = {
		thanks = {
			L["Thanks, {name}! Kindness received, catalogued and returned!"],
			L["Reciprocity engaged! Much obliged, {name}."],
			L["By my calculations, {name}, you're owed exactly one {buff}."],
			L["Thanks, {name}! I'd build you a thank-you machine, but it'd explode."],
			L["Thank you, {name}! This calls for a celebration. Stand back, I'll build one."],
			L["You're too kind, {name}! Returning the favour took only four schematics."],
			L["Drat, {name}! I was going to invent gratitude, but you beat me to it."],
			L["Oh, {name}, how kind! My heart's doing that whirring thing again."],
		},
		asked = {
			L["Request received, {name}! Processing... done!"],
			L["One upgrade, coming right up, {name}! Stand still for calibration."],
			L["Of course, {name}! I built a machine for this. It's in pieces, so: by hand."],
			L["Certainly, {name}! Stand on the X. There's no X. Stand anywhere."],
			L["Right away, {name}! Goggles on. Not for you, I just like them."],
			L["{buff}, {name}? Simple in theory AND practice. Suspicious!"],
			L["Happy to, {name}! Keep hands, feet and eyebrows well clear."],
		},
		offer = {
			L["Hold still, {name}, this is perfectly safe. Probably!"],
			L["Science says you need this, {name}. Who am I to argue?"],
			L["A small upgrade for you, {name}. No cogs required."],
			L["Take it, {name}, I've a spare. I've three spares of everything."],
			L["Try this, {name}! Version one had legs. Version two is much better."],
			L["The High Tinker says share our genius, {name}. Here's a sample!"],
			L["Gnomeregan Forever, {name}! This lasts rather less, but it's free."],
			L["I'm small, {name}, but my gifts come full-sized. Here!"],
			L["Don't worry, {name}! It worked on the chicken, and the chicken's thrilled."],
		},
		kin = {
			L["For Gnomeregan, {name}! Always nice to talk to somebody at eye level."],
			L["A fellow gnome, {name}! I'll hold the schematic; you hold the bucket."],
			L["Flesh or cogs, {name}, we're all gnomes. Some of us just need oiling."],
			L["One gnome to another, {name}: you did turn the reactor off, didn't you?"],
		},
		group = {
			L["Party-wide calibration complete, {name}! Nobody touch anything shiny."],
			L["I've run the numbers, {name}: with you here, we win. I rounded up."],
			L["If I shout 'duck', {name}, don't look for a duck. That went badly last time."],
			L["Formation, {name}: tall folk at the front, me somewhere safe and clever."],
			L["Everyone gets one, {name}! Standardised parts are the secret of a good machine."],
		},
		morning = {
			L["Morning, {name}! Up since three. The toaster needed a new engine."],
			L["Good morning, {name}! The coffee's brewing itself. It learned how. Worrying."],
			L["Early start, {name}! Best ideas come before breakfast. So do the explosions."],
		},
	},
	draenei = {
		thanks = {
			L["The Light rewards kindness, {name}. I'm simply its fastest courier."],
			L["Archenon poros, {name}. Your gift is returned."],
			L["Thanks, {name}. I'd offer a lift in the Exodar, but you've seen how it lands."],
			L["A gift freely given, {name}. The naaru hum a little louder. Returned."],
			L["Kindly done, {name}. On Argus we'd have carved that in crystal. Here."],
			L["Across a dozen worlds, {name}, kindness is the one tongue I never had to learn."],
			L["What a kindness, {name}. It almost makes up for the Legion. Almost."],
			L["Thank you, {name}. I'd say it in Draenei, but that takes eleven minutes."],
		},
		asked = {
			L["Of course, {name}. The naaru guide your steps; this puts a spring in them."],
			L["Gladly, {name}. The Light answers those who ask."],
			L["Velen foresaw you asking, {name}. I foresaw saying yes."],
			L["The Light is not rationed, {name}. Take as much as you like."],
			L["Of course, {name}. I've outrun the Burning Legion; I can manage this."],
			L["At once, {name}. Hooves planted, crystals humming, here it comes."],
			L["Gladly, {name}. I followed a talking crystal across the stars. This is easy."],
		},
		offer = {
			L["The Light is with you, {name}. Go in peace, or at least go prepared."],
			L["Walk in the Light, {name}. May it shelter you always."],
			L["Take this, {name}. My people always travel Light."],
			L["Take this, {name}. The Legion is always coming. I'd know."],
			L["I'm out of miracles today, {name}. Will {buff} do?"],
			L["For the road, {name}. Mine has been twenty-five thousand years long."],
			L["Blessed by a naaru, {name}. Well, I stood near one. It still counts."],
			L["Take this, {name}. It glows a bit. Everything we own does."],
		},
		kin = {
			L["Archenon poros, {name}! The children of Argus look after one another."],
			L["Home is wherever two draenei meet, {name}. Today, it's here."],
			L["Horns high, {name}. Two draenei, and nobody's mentioned the Legion. Progress."],
			L["Tails up, {name}. Argus would be proud of what we've made of exile."],
		},
		group = {
			L["Stay near, {name}. I lost a world once; I'm keeping hold of this party."],
			L["Twenty-five thousand years on the run, {name}. Walking with friends is nicer."],
			L["The naaru would call this a fellowship, {name}. I call it good luck."],
			L["I've watched worlds end, {name}. Whatever's ahead of us hardly worries me."],
			L["Stay together, {name}. The Light finds us easier when we're all in one place."],
		},
	},
	worgen = {
		thanks = {
			L["Much obliged, {name}. Gilneas never forgets a kindness, and nor does my nose."],
			L["Thank you, {name}. You have my gratitude, and my best howl."],
			L["Thank you, {name}. If worgen had tails, mine would be wagging."],
			L["You've made a friend for life, {name}. Loyalty is rather our thing."],
			L["The beast in me wants to growl, {name}. The Gilnean in me insists on thanks."],
			L["Much appreciated, {name}. I'd shake your hand, but, claws. Here instead."],
			L["We walled ourselves off for years, {name}. You make that look silly."],
			L["Obliged, {name}. You've earned a spot by the fire. The good spot."],
		},
		asked = {
			L["Certainly, {name}. Hold still, I don't bite. Much."],
			L["Right you are, {name}. Stand steady now."],
			L["Right away, {name}. Stay, now. I've always wanted to say that."],
			L["Gladly, {name}. Rain or shine, and in Gilneas it's rain."],
			L["Certainly, {name}. I'll try not to shed on you."],
			L["Say no more, {name}. These ears heard you before you'd decided to ask."],
			L["Of course, {name}. You asked nicer than the last fellow who threw me a stick."],
		},
		offer = {
			L["Stay off the moors after dark, {name}. Take this."],
			L["Keep your wits about you, {name}. Something is always hunting."],
			L["I'd have brought this sooner, {name}, but I stopped to chase something."],
			L["For you, {name}. No, I don't want a treat. Well. Perhaps a small one."],
			L["Gilneans always offer, {name}. The claws are just part of the outfit."],
			L["An old Gilnean remedy, {name}. Good for colds, gloom and most curses. Not mine."],
			L["Run with this, {name}. Trust me, I know about running."],
			L["Fetched this for you, {name}. Don't make a thing of it."],
		},
		kin = {
			L["The curse binds us, {name}, but Gilneas binds us tighter."],
			L["No need to explain the ears to you, {name}."],
			L["Fur, fog and rain, {name}. Only a Gilnean understands all three."],
			L["Pack looks after pack, {name}. Always has."],
		},
		group = {
			L["Pack rules, {name}: nobody wanders off, and nobody mentions the fleas."],
			L["A pack again, {name}. I hadn't known how much I'd missed one."],
			L["I'll catch the scent of trouble first, {name}. It's the one perk of the curse."],
			L["If I howl, {name}, it's a battle cry. Probably. Don't look at me like that."],
			L["Lead on, {name}. I'll trot. It's undignified, but it's much quicker."],
		},
		night = {
			L["Night again, {name}. I'm at my best and my worst. This is the best part."],
			L["Look at that moon, {name}. Don't mind me; I'm not howling. Much."],
			L["Gilneas at night was fog and footsteps, {name}. These days I'm the footsteps."],
		},
		morning = {
			L["Morning, {name}. I'd have been up sooner, but the rug by the fire was so warm."],
			L["Smells like rain this morning, {name}. Everything in Gilneas smelled like rain."],
			L["Up already, {name}? I've chased two rabbits. For exercise. Purely."],
		},
	},
	orc = {
		thanks = {
			L["Throm-ka, {name}! Honour is repaid."],
			L["You give freely, {name}. I return the favour."],
			L["Orcs keep their thanks short, {name}. Thanks."],
			L["Orcs return every blow twice, {name}. The kind ones too."],
			L["You helped me, I help you. Orc poetry, {name}. It doesn't rhyme."],
			L["In the old days I'd have repaid you with a boar, {name}. This keeps better."],
			L["Owing somebody itches worse than Durotar sand, {name}. There. Itch gone."],
			L["Strong stuff, {name}. I could wrestle a kodo now. So can you."],
		},
		asked = {
			-- Dabu: the grunt's "I obey", not the peon's "zug zug".
			L["Dabu, {name}. It is done."],
			L["Hold still, {name}. Strength for the fight ahead."],
			L["Ask an orc for help and you get it, {name}. Ask for subtlety and you wait."],
			L["Help, yes. Hugging, no. Hold still, {name}."],
			L["You want {buff}? You have {buff}, {name}. Next."],
			L["Don't flinch, {name}. My helping face looks exactly like my fighting face."],
			L["Short question, short answer, {name}: yes."],
		},
		offer = {
			L["Lok'tar ogar, {name}! Take this into battle. A tavern brawl also counts."],
			L["Blood and thunder, {name}! Go and earn your glory."],
			L["Among orcs, {name}, making you stronger is how we say we like you."],
			L["An orc giving gifts unasked? Tell no one, {name}. It ruins the image."],
			L["I was told to be more diplomatic, {name}. This is me being diplomatic."],
			L["Go hit something for me, {name}. Or set it on fire. Orcs aren't fussy."],
			L["Don't thank me, {name}. Just win, and do it loudly."],
			L["I'd make a speech, {name}, but it's mostly shouting. Just take it."],
		},
		kin = {
			L["Throm-ka, {name}! The blood of the clans runs strong in you."],
			L["An orc, {name}! Finally, somebody who shouts at my volume."],
			L["Frostwolf, Warsong or Blackrock, {name}, we all argue like family."],
			L["Between orcs no words are needed, {name}. Good. I was out of them."],
		},
		group = {
			L["The plan, {name}: we hit it. Questions? No? Good plan."],
			L["A true warband, {name}. Loud, angry, and all on the same side for once."],
			L["Stay with the warband, {name}. Strength in numbers. And in axes."],
			L["If you fall, {name}, I carry you out. Complaining the whole way, but I carry."],
			L["Fight well, {name}, and tonight you share our fire. And our boasting."],
		},
	},
	forsaken = {
		thanks = {
			L["Thank you, {name}. It would warm my heart, if it still beat."],
			-- Not "from the living": Forsaken buff each other all the time.
			L["Such warmth, for one so cold? Returned in full, {name}."],
			L["Thank you, {name}. I'd blush, but the blood stopped reaching my face."],
			L["My undying gratitude, {name}. For once, the phrase is accurate."],
			L["Most kind, {name}. You've lifted me from 'deceased' to 'mildly deceased'."],
			L["You've added years to my life, {name}. Shame it already ended."],
			L["I felt that, {name}, and I don't feel much these days. Here, feel this."],
			L["I'd shake your hand, {name}, but I'm not sure mine is still attached."],
		},
		asked = {
			L["Certainly, {name}. Try not to die. It's overrated."],
			L["You need only ask, {name}. The dead are patient."],
			L["Ask the dead for a favour, {name}. We rarely have other plans."],
			L["Certainly, {name}. Stand clear; I'd hate to drop anything on you."],
			L["A moment, {name}. Rigor mortis is hard on the casting hand."],
			L["Nice to be asked for something, {name}, besides the way to the graveyard."],
			L["Gladly, {name}. It takes my mind off the smell. Mine, I mean."],
		},
		offer = {
			L["Stay among the living a little longer, {name}."],
			L["Take this, {name}. The grave can wait."],
			L["I was a physician in Lordaeron, {name}. Old habits die harder than I did."],
			L["No charge, {name}. The apothecaries would have made you sign something."],
			L["A gift from the grave, {name}. Don't worry, I washed it."],
			L["Every body needs a little help, {name}. Mine mostly needs stitches."],
			L["I've seen where heroes end up, {name}. I live there. Take this."],
			L["Take this, {name}. I learned the hard way you can't take it with you."],
		},
		kin = {
			L["We Forsaken must look after each other, {name}."],
			L["Between us corpses, {name}, you're remarkably well preserved."],
			L["Lose a finger, {name}, and I've a spare. Forsaken share."],
			L["Is your jaw clicking too, {name}, or is that just me?"],
		},
		group = {
			L["Stay alive, {name}. I've tried the alternative, and I can't recommend it."],
			L["If I fall down, {name}, give it a minute. Old habit."],
			L["I'll take the front, {name}. What's the worst that could happen? Again?"],
			L["Keep upwind of me, {name}. It's better for morale."],
			L["The last party I joined, {name}, I woke up in a crypt. Let's improve on that."],
		},
		night = {
			L["The dead keep terrible hours, {name}. Nice to have company for once."],
			L["Midnight, {name}: the best hour to be up and about when you shouldn't be."],
			L["The living are all asleep, {name}. We Forsaken call this the quiet shift."],
		},
		morning = {
			L["Morning already, {name}? I've been up all night. And all of last decade."],
			L["The sun's up, {name}. I'll stand in the shade, if you don't mind. Things peel."],
			L["Early start, {name}. The dead never sleep in. Or at all, really."],
		},
	},
	tauren = {
		thanks = {
			L["The Earth Mother saw your kindness, {name}. She nudged me. Quite hard."],
			L["Thank you, {name}. May the winds guide you."],
			L["Thank you, {name}. I'm deeply moved, and it takes a lot to move a tauren."],
			L["It's a long way up to a tauren's heart, {name}. You found it."],
			L["I felt that from horn to hoof, {name}. Returned, hoof to horn."],
			L["A gift given is a seed planted, {name}. Here is the harvest."],
			L["That deserves a feast, {name}. The feast can wait; {buff} can't."],
			L["Thank you, {name}. Should you ever need a wall to hide behind, I'm free."],
		},
		asked = {
			L["Of course, {name}. Stand tall and be at peace. I'll handle the tall part."],
			L["Ask and it is given, {name}. The herd shares what it has."],
			L["Of course, {name}. Stand back a pace; I do this with my whole body."],
			L["Gladly, {name}. Mind the tail."],
			L["The Earth Mother gives freely, {name}, and so do her largest children."],
			L["Gladly, {name}. Tauren are slow to anger and quick to help. Quick-ish."],
			L["Refuse you, {name}? My ancestors would never let me hear the end of it."],
		},
		offer = {
			L["Walk with the Earth Mother, {name}. She's everywhere, so you can't get lost."],
			L["May An'she light your path, {name}."],
			L["You looked like you could use a friend, {name}. I'm a very big one."],
			L["Take this, {name}. The Earth Mother would scold me if I walked past."],
			L["Tread lightly, {name}. Take it from someone who never has."],
			L["The wind said you'd pass this way, {name}. The wind is a terrible gossip."],
			L["Take this, {name}. I'd lend you my kodo too, but he's less generous than me."],
			L["The shu'halo say carry what you can for others, {name}. I can carry a lot."],
		},
		kin = {
			L["The Earth Mother watches over us both, {name}."],
			L["Somebody warn the doorframes, {name}. There are two of us now."],
			L["Plains or peaks, {name}, a shu'halo heart is a big one."],
			L["Horns and helmets, {name}. Only another tauren knows the pain."],
		},
		group = {
			L["Get behind me, {name}. There's room back there for the whole party."],
			L["The herd moves together, {name}. Mind my hooves; the herd has learned to."],
			L["Low ceilings ahead, {name}? I'll be the first to find out. Take this."],
			L["I'm slow to anger, {name}, but I hold a grudge for the whole party."],
			L["Need a wall to hide behind, {name}? I'm most of one. Come on."],
		},
		morning = {
			L["An'she rises, {name}, and so do we. Slower, in my case."],
			L["The sun is An'she's eye, {name}. He's watching, so let's look busy."],
			L["Morning, {name}. The kodo are up, the grass is wet, and this is yours."],
		},
		night = {
			L["Mu'sha keeps the night watch, {name}. I'll tell her to keep an eye on you."],
			L["The moon's out, {name}. Mu'sha sees you, and she approves. I asked."],
			L["Late, {name}. The kodo are asleep, and they snore like thunder. Take this."],
		},
	},
	troll = {
		thanks = {
			L["Ya be too kind, {name}! Dis one be from me."],
			L["Thanks, mon! Da spirits smile on ya, {name}."],
			L["Ya gave me good mojo, {name}. Now ya get some back, extra spicy."],
			L["Bwonsamdi gonna be real disappointed, {name}. Thanks, mon."],
			L["Dat be some fine work, {name}. Almost as fine as me. Almost."],
			L["A troll can grow back a hand, {name}. Can't grow back honour. Here."],
			L["Ya just made a troll smile, {name}, and we got a lot of teeth."],
			L["Da loa keep a tally, {name}, and now ya on da good side of it."],
		},
		asked = {
			L["Sure ting, {name}. Hold still; da mojo don't like a movin' target."],
			L["No worries, {name}. Da loa got ya covered."],
			L["Stay away from da voodoo, {name}. ...Except dis voodoo. Dis one fine."],
			L["Close ya eyes, {name}. Da mojo be shy when people watch."],
			L["Ya don't gotta ask twice, {name}. Ya barely gotta ask once."],
			L["Sure, {name}. Bein' a troll be mostly swagger. Da rest be dis."],
			L["Ya asked real polite, {name}. Polite get da good stuff."],
		},
		offer = {
			L["Da loa be watchin' over ya, {name}. Dey real nosy like dat."],
			L["Stay sharp out dere, {name}. Take dis wit' ya."],
			L["Ya look like somebody who appreciate quality, {name}. Here: quality."],
			L["Take dis, {name}. Walk like ya own da jungle. I do."],
			L["Everybody need mojo, {name}. I make so much I gotta give it away."],
			L["A little somethin' for ya, {name}. Don't ask where da loa got it."],
			L["Go on, {name}. Anyting try to eat ya now gonna get indigestion."],
			L["Ya lookin' dangerous now, {name}. Almost troll-level dangerous."],
		},
		kin = {
			L["Hey, {name}! Always good to see family, mon."],
			L["Da rest of Azeroth stand up straight, {name}. We got more style."],
			L["Hey, {name}, ya tusks be lookin' sharp. Mine too, obviously."],
			L["Every troll be family, {name}. Even da ones who still owe me gold."],
		},
		group = {
			L["Stay close, {name}. Trolls regenerate; da rest of ya gotta be careful."],
			L["Dis crew got style, {name}. Now it got mojo too."],
			L["We go in together, {name}, we come out together. Dat be da whole plan, mon."],
			L["Nobody fallin' today, {name}. Bwonsamdi can wait for da next group."],
			L["Keep ya head down, {name}. I keep mine up. Somebody gotta look good."],
		},
		night = {
			L["Night be da best time for mojo, {name}. Nobody see where it come from."],
			L["Da jungle wake up at night, {name}. So do I. Here, dis one fresh."],
			L["Moon be high, {name}, spirits be restless. Dis keep dem off ya."],
		},
	},
	bloodelf = {
		thanks = {
			L["Such courtesy does you credit, {name}. Nearly as much as it does me."],
			L["How gracious, {name}. Allow me to return the favour."],
			L["Thank you, {name}. I haven't felt this radiant since... well, this morning."],
			L["Kind of you, {name}. We sin'dorei never turn down free magic. Ask anyone."],
			L["Exquisite, {name}. I would know; I only accept the exquisite."],
			L["Lovely, {name}. I'll be insufferable about this all day. More than usual."],
			L["Thank you, {name}. It even goes with my gold trim. You have an eye."],
			L["Returned in kind, {name}. A prettier kind, admittedly. I can't help it."],
		},
		asked = {
			L["Naturally, {name}. Only the finest for you."],
			L["For you, {name}? Of course. The sun gives freely."],
			L["Patience, {name}. Radiance can't be rushed, only admired."],
			L["Of course, {name}. {buff}, delivered with impeccable posture."],
			L["You asked nicely, {name}. In Silvermoon that counts for everything."],
			L["One moment, {name}. I never cast anything without checking my hair."],
			L["At once, {name}. Keeping someone waiting is so terribly unfashionable."],
		},
		offer = {
			L["Anar'alah belore, {name}. May the sun guide you, and light your good side."],
			L["Shorel'aran, {name}. Fight with elegance."],
			L["Take this, {name}. Whatever happens out there is merely a setback."],
			L["Everyone deserves to shine, {name}. Only a little less than me, of course."],
			L["The sun is with you, {name}. I simply held the door for it."],
			L["Go on, {name}, take it. The Sunwell's back; we can afford to be generous."],
			L["For you, {name}: {buff}, lightly scented with Silvermoon."],
			L["Here, {name}. Hand-cast in Silvermoon, so do try not to scuff it."],
		},
		kin = {
			L["The Sunwell shines for us both, {name}."],
			L["Two sin'dorei in one place, {name}. The day just got twice as elegant."],
			L["You too, {name}? Two sin'dorei, one mirror. We'll have to take turns."],
			L["Like the phoenix, {name}: we keep rising, and we look good doing it."],
		},
		group = {
			L["Do keep pace, {name}. We have a reputation for arriving beautifully."],
			L["Stand where the light is good, {name}. If we must fight, we'll look splendid."],
			L["A party at last, {name}. I did dress for one."],
			L["The sun shines on all of us, {name}. Mostly on me, but it shares."],
			L["One for you, {name}, and one for the party's image, which I've taken on myself."],
		},
		morning = {
			L["The sun has risen, {name}, and so have I. We coordinate."],
			L["Dawn over Quel'Thalas is lovelier, {name}, but this will do. Just."],
			L["Morning light, {name}. The most flattering hour. For both of us, naturally."],
		},
	},
	nightborne = {
		thanks = {
			L["Your generosity is noted, {name}. In triplicate. Suramar remembers its friends."],
			L["Most gracious, {name}. Allow me to repay you in kind."],
			L["Thank you, {name}. Ten thousand years under a dome; I'm still practising that."],
			L["A gift with no favour owed? The court would faint. Thank you, {name}."],
			L["Returned, {name}. We keep careful accounts of kindness. And of slights."],
			L["I'll mention you to First Arcanist Thalyssra, {name}. Favourably, even."],
			L["Most kind, {name}. In Suramar we'd hold a banquet. Consider it held."],
			L["I'd send a formal letter of thanks, {name}, but this seemed quicker."],
		},
		asked = {
			L["Of course, {name}. A little arcane polish, just for you."],
			L["A reasonable request, {name}. Granted."],
			L["Certainly, {name}. The short version; the long one takes a lunar cycle."],
			L["A request, how refreshing. The court only ever made demands. Here, {name}."],
			L["Done, {name}, and free. Elisande would have charged you a favour for it."],
			L["There, {name}. No need to bow. A small nod would be lovely, though."],
			L["Of course, {name}. I've perfected this since before most cities had walls."],
		},
		offer = {
			L["Take this, {name}. Arcane gifts are wasted on the idle."],
			-- Suramar's arcana, not the Nightwell: they were weaned off it.
			L["A spark of Suramar's arcana for you, {name}. Use it wisely."],
			L["I've gone without magic once, {name}. I don't recommend it. Take this."],
			L["The world outside the dome is so large, {name}. And so under-enchanted. Here."],
			L["Arcwine is traditional, {name}, but {buff} travels better."],
			L["Do take this, {name}. It's rude to refuse Suramar's hospitality. Very rude."],
			L["Here, {name}. I'm told this is how outsiders say hello. Charming custom."],
			L["Take this, {name}. Magic hoarded is magic spoiled, as Suramar learned."],
		},
		kin = {
			L["Suramar's children shine together again, {name}."],
			L["Shal'dorei, {name}! You packed arcwine? Outsider wine is just... grapes."],
			L["Suramar's own, {name}. Try not to be too impressed by the rest of the world."],
			L["We survived the Legion and the withering, {name}. The rest is small talk."],
		},
		group = {
			L["An expedition, {name}! In Suramar this needed six permits and a masquerade."],
			L["The dome kept us safe, {name}. Now we must make do with one another. Gladly."],
			L["Arcane for everyone, {name}. The court would call it waste. I call it company."],
			L["Do follow my lead, {name}. I've had ten thousand years of walking in step."],
			L["In a party one shares one's magic, {name}. How novel. I rather like it."],
		},
		night = {
			L["Night at last, {name}. Add a few thousand lanterns and it's nearly Suramar."],
			L["Under the dome it was always night, {name}. I feel quite at home."],
			L["The stars are out, {name}. We had better ones in Suramar. These will do."],
		},
		morning = {
			L["Daylight, {name}. Ten thousand years under a dome, and it still startles me."],
			L["An early hour, {name}. The court never rose before noon. I'm reforming."],
			L["Morning, {name}. The sun here is so very... unenchanted. Take this instead."],
		},
	},
	goblin = {
		thanks = {
			L["A favour for a favour, {name}! Pleasure doing business."],
			L["Thanks, {name}! Consider your account settled in full."],
			L["Aw, {name}. I'd invoice you, but I'm feeling sentimental. It'll pass."],
			L["Thanks, {name}! I checked it for fine print. There wasn't any. Weird!"],
			L["Returned with interest, {name}. Minus the interest. Don't get used to it."],
			L["Much obliged, {name}! You've just been upgraded to preferred customer."],
			L["I'd name a rocket after you, {name}, but my rockets never last long. Thanks!"],
			L["I'd have charged fifty gold for that, {name}. Let's call us even."],
		},
		asked = {
			L["You got it, {name}! Time is money, friend!"],
			L["Deal, {name}! I'll put it on your tab. Kidding!"],
			L["Right away, {name}! Satisfaction guaranteed or your {buff} back."],
			L["{buff}, {name}! Tips optional. Encouraged. Optional."],
			L["Fast, cheap or good, {name}? Today you get all three. Don't spread it around."],
			L["Sure thing, {name}! No explosions this time, I promise. Mostly promise."],
			L["For you, {name}? No charge. Put that in writing and I'll deny it."],
		},
		offer = {
			L["This one's on the house, {name}. Don't tell the Trade Prince."],
			L["Top-shelf stuff, zero fees, {name}. Today only!"],
			L["Free sample, {name}! If you like it, you know where to find me."],
			L["Here, {name}. If anything explodes near you today, that was unrelated."],
			L["Goodwill's an asset, {name}. Here's some {buff} for my books."],
			L["Take this, {name}. Safety first! Or third. It's on the list somewhere."],
			L["Cast in record time, {name}! The record's mine. I set it just now."],
			L["Kaja'Cola gives you ideas, {name}. This does the rest. Take it!"],
		},
		kin = {
			L["Anything for a fellow entrepreneur, {name}!"],
			L["Kezan's finest, together again, {name}. Keep a hand on your coin purse."],
			L["Fellow goblin, {name}? Then you know this is a very, very rare discount."],
			L["Goblins look after goblins, {name}. It's cheaper than hiring guards."],
		},
		group = {
			L["Group rate, {name}! Everybody here gets it half off. Of free."],
			L["Nobody dies on my contract, {name}. The paperwork's a nightmare."],
			L["We split the loot even, {name}. I'll do the maths. Trust me."],
			L["Team-building, {name}! You make everybody stronger, and they all owe you."],
			L["Stick together, {name}. Mercenaries cost gold; friends only cost this."],
		},
		morning = {
			L["Early bird gets the gold, {name}! Here's a freebie. Don't tell the other birds."],
			L["Morning, {name}! Markets open in an hour. Until then, I'm feeling generous."],
			L["Up early, {name}? Smart. Time is money, and it's cheapest in the morning."],
		},
	},
	vulpera = {
		thanks = {
			L["Thank you, {name}! The caravan always repays a kindness. Usually in string."],
			L["How kind, {name}! You're on the caravan's good list now."],
			L["Oh, I'll keep this, {name}! I keep everything. Here's one for you."],
			L["Thanks, {name}! Here's yours back. Well, a new one. Hardly used."],
			L["My ears just went straight up, {name}. That means I'm very pleased."],
			L["By tonight's campfire, {name}, this story will have a sandworm in it. Thanks!"],
			L["I'd gift-wrap yours, {name}, but all my wrapping is somebody's old map."],
			L["The alpacas saw that, {name}. They'll tell everyone how nice you are. Thanks!"],
		},
		asked = {
			L["Of course, {name}! Shake the sand out and hold still."],
			L["Coming right up, {name}! Caravan service, no waiting."],
			L["Sure, {name}! Let me dig it out... rope, rocks, a nice rock... here it is!"],
			L["Hold on, {name}! Tail's in the way, one moment... there!"],
			L["One {buff}, {name}! Only slightly sandy."],
			L["Ask a vulpera and you'll get something, {name}. Usually odd. Not today!"],
			L["Yours, {name}! Vulpera love giving things. Almost as much as finding them."],
		},
		offer = {
			L["Every traveller needs something for the road, {name}. I checked: not a rock."],
			L["Keep this, {name}. The desert is long and the water is short."],
			L["Found this lying around, {name}. Kidding! It's fresh. Take it!"],
			L["Here, {name}. Best thing in my pack, and I've got a lot of pack."],
			L["In the dunes you share your shade and your spells, {name}. Here."],
			L["Some {buff} for you, {name}. I'd haggle, but you look busy."],
			L["A gift from the whole caravan, {name}! They'll never know."],
			L["For the road, {name}. Roads are the best part. Roads, and snacks."],
		},
		kin = {
			L["A fellow wanderer! The caravan is never far, {name}."],
			L["Ears up, {name}! Always nice to share a spell with a fellow fox."],
			L["One vulpera to another, {name}: I've three spare spoons if you need one."],
			L["Vol'dun raised us both, {name}. Sand in the fur, luck in the pack."],
		},
		group = {
			L["Caravan rules, {name}: stay together, share the water, nobody sells the alpaca."],
			L["Anything shiny in there, {name}, I saw it first. Caravan law."],
			L["One for the party, {name}! A caravan's only as fast as its slowest alpaca."],
			L["Keep your pack shut, {name}. I don't mean to take things. They follow me."],
			L["Lost in a city, {name}, never in a cave. Caves are just houses with no rent."],
		},
		night = {
			L["We vulpera travel by night, {name}. Cool sand, sleepy scorpids."],
			L["Desert nights get cold, {name}. Here, something warm-ish."],
			L["Stars out, {name}. Every one's a signpost if you know how to read it. I don't."],
		},
	},
	pandaren = {
		thanks = {
			L["A kindness returned is a kindness doubled, {name}."],
			L["Thank you, {name}. You have restored my balance."],
			L["Somewhere, a Sha just went hungry. Thank you, {name}."],
			L["Thank you, {name}. Aysa would bow, Ji would cheer. I will do both, badly."],
			L["Thank you, {name}. I will think of you at my next meal, and the one after."],
			L["Chen always said: never refuse a gift. Or a drink. Thank you, {name}."],
			L["I was about to nap, {name}, but this is better. Slightly. Thank you."],
			L["A hozen would have thrown something, {name}. I was raised better. Thank you."],
		},
		asked = {
			L["Of course, {name}. Patience, and it is done. Patience is the slow part."],
			L["With pleasure, {name}. A kind deed is never wasted."],
			L["At once, {name}. Quick for a pandaren, which is not saying much."],
			L["Master Shang Xi said: help whoever asks, {name}. He also said: duck."],
			L["A Tushui master would make you meditate first, {name}. I will skip that part."],
			L["Anything for you, {name}. Except the last dumpling. Let us not be silly."],
			L["One {buff}, {name}, brewed strong. The recipe stays a secret."],
		},
		offer = {
			L["Take this, {name}. And perhaps a cup of tea afterward?"],
			L["Balance in all things, {name}. Now go with a light heart."],
			L["Take this, {name}. A grummle would sell it to you for a luckydo."],
			L["The jinyu say the waters foretold this, {name}. They say that a lot."],
			L["The Huojin say act first. The Tushui say think first. I say: here, {name}."],
			L["A pandaren stood up to give you this, {name}. Treasure it."],
			L["Fight like a monk, {name}: calm, quick, and then a long lunch."],
			L["Go gently, {name}. The turtle got where it was going and never hurried once."],
		},
		kin = {
			L["We must share a brew when the road allows, {name}!"],
			L["Shen-zin Su would be proud of us both, {name}. Or asleep. Hard to tell."],
			L["Two pandaren together, {name}. Somewhere, an innkeeper just felt a chill."],
			L["Liu Lang would approve, {name}: two of us, both a long way from home."],
		},
		group = {
			L["A fight, then a meal, {name}. That is the correct order. Never the reverse."],
			L["Stay together, {name}, like dumplings in a steamer. Warm, and ready."],
			L["We move as one, {name}. Slowly, perhaps, but as one."],
			L["Balance, {name}: one fights, one heals, and one carries the snacks. Me."],
			L["If we fall, {name}, we fall together, and then we nap. Let us not."],
		},
		morning = {
			L["Up before the tea, {name}? Brave. Here, instead of the tea."],
			L["Morning, {name}. First this, then breakfast, then the second breakfast."],
			L["A new day, {name}, and nobody has spilled anything yet. Let us begin gently."],
		},
		night = {
			L["Past my first nap, {name}, and before my second. Quickly, while I'm awake."],
			L["Late, {name}. The brewmasters are asleep. The brews, I suspect, are not."],
			L["Midnight snack time, {name}. This is the appetiser."],
		},
	},
	dracthyr = {
		thanks = {
			L["Your kindness is noted, {name}. Dragons do not forget."],
			L["Thank you, {name}. Returned on swift wings."],
			L["Wings, fire and scales, {name}, and still you thought I needed help. Touching."],
			L["I would bow, {name}, but last time my wings cleared a table. Thank you."],
			L["That goes straight into my hoard, {name}. Kind deeds are the only gold I keep."],
			L["I was made to be a weapon, {name}. I much prefer this part. Thank you."],
			L["Thank you, {name}. Wrathion would have made a speech of it. I will not."],
			L["Returned with a little fire in it, {name}. Only a little. I am practising."],
		},
		asked = {
			L["Very well, {name}. Stand still, I would hate to singe you."],
			L["Granted, {name}. A dragon keeps its word."],
			L["Certainly, {name}. Stand clear of the tail."],
			L["Of course, {name}. Is this still how it is done? I was asleep for a while."],
			L["Gladly, {name}. All five dragonflights are in me, and all five say yes."],
			L["Right away, {name}. Dragon-sized help, in a conveniently smaller form."],
			L["Of course, {name}. Neltharion only gave orders. A request is much nicer."],
		},
		offer = {
			L["Take this, {name}. Even a dragon needs allies. Especially one this size."],
			L["A gift from the Dragon Isles, {name}. Fly well."],
			L["Alexstrasza says every life is precious, {name}. I am starting with yours."],
			L["I slept through ten thousand years of good deeds, {name}. Catching up now."],
			L["Tell them a dragon did this, {name}. It sounds far grander than it was."],
			L["Scalecommander's orders, {name}. I am not a Scalecommander, but still."],
			L["Take this, {name}. Ancient dragon magic, only slightly out of date."],
			L["A dragon giving, {name}, not taking. I am trying something new."],
		},
		kin = {
			L["The Forbidden Reach feels far behind us now, {name}."],
			L["Two dracthyr in one place, {name}. Mind the wings; there is not room for four."],
			L["Remember when the whole world was new to us, {name}? It still is, mostly."],
			L["In visage form nobody can tell, {name}. Between us: we look better in scales."],
		},
		group = {
			L["Tell me when to breathe fire, {name}. And, please, when not to."],
			L["I woke in a cave full of strangers, {name}. This is far better company."],
			L["Neltharion made us to fight alone, {name}. We have improved on him."],
			L["Stay clear of my tail, {name}. It hasn't yet learned whose side it's on."],
			L["A flight of our own, {name}. So this is what the dragons meant."],
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
			L["Thank you, {name}. The Alliance looks after its own, and today that's me."],
			L["Kindness answered, {name}. For the Alliance!"],
			L["Stormwind has a statue for every hero, {name}. I'm putting in a word for yours."],
			L["The Alliance way, {name}: you help me, I help you, a dwarf buys the drinks."],
			L["Genn would growl, Muradin would hug, {name}. I'll just return it."],
			L["If the Alliance gave medals for manners, {name}, you'd need a second tabard."],
			L["Returned in full, {name}. An ally who gives first is worth a whole garrison."],
		},
		asked = {
			L["Of course, {name}. Allies help each other. It's practically in the name."],
			L["At once, {name}. The Alliance does not leave a friend wanting."],
			L["Of course, {name}. It's in the Alliance charter. Somewhere near the back."],
			L["By order of the Alliance, {name}: one {buff}, effective at once."],
			L["Anything for an ally, {name}. Within reason. This is well within reason."],
			L["Right away, {name}. SI:7 knew you would ask. I only just found out."],
		},
		offer = {
			L["For the Alliance, {name}! Stay strong out there. Stronger, now."],
			L["Onward, {name}. The Alliance is with you."],
			L["Take this, {name}. Had a gnome made it, it would come with twelve levers."],
			L["Compliments of the Alliance, {name}. We've done these since the Second War."],
			L["Chin up, {name}. Somewhere in Stormwind, a bard is writing about this."],
			L["Every ally counts, {name}. I counted, actually. You're my favourite so far."],
			L["Anduin would want me to share, {name}, and I'd hate to disappoint him."],
		},
		group = {
			L["Together we stand, {name}. For the Alliance!"],
			L["Right, {name}: shields up, heads down, and nobody charges before the plan does."],
			L["The finest company the Alliance ever fielded, {name}. Or at least the nearest."],
			L["Together, {name}, we're practically a regiment. A small, well-dressed regiment."],
			L["Watch each other's backs, {name}. The Alliance was built by people who did."],
		},
	},
	Horde = {
		thanks = {
			L["Strength and honour, {name}. And kindness, it turns out. Repaid in full."],
			L["The Horde takes care of its own, {name}."],
			L["Strength given, strength returned, {name}. That's all of Horde diplomacy."],
			L["I'd carve your name on Orgrimmar's gates, {name}, but they're full. Thanks."],
			L["Gallywix would've sent you an invoice, {name}. I'm sending this instead."],
			L["You did not have to do that, {name}. That is why the Horde remembers it."],
			L["In the Horde we do not say thank you twice, {name}. So: once, and meant."],
		},
		asked = {
			L["Consider it done, {name}. For the Horde, and for anyone who asks nicely."],
			L["You only had to ask, {name}. The Horde answers."],
			L["The Horde usually helps with axes, {name}. Today, {buff}."],
			L["Done, {name}. No speeches. The Horde has plenty of those already."],
			L["You asked, {name}. In Orgrimmar, that counts as a formal treaty."],
			L["Asking is no weakness, {name}. Refusing an ally would be."],
		},
		offer = {
			L["For the Horde, {name}! Go with strength. I've just handed you some."],
			L["Go with honour, {name}. Victory awaits."],
			L["Go and do something worth a song, {name}. Loud songs. The Horde likes loud."],
			L["Walk tall, {name}. The Horde always made room for those the world turned away."],
			L["Take this, {name}, and a word of Horde wisdom: hit first, apologise never."],
			L["Victory or death, {name}. I'd prefer victory, so take this."],
			L["Like a mak'gora, {name}, except everybody wins. Here."],
		},
		group = {
			L["Our strength is each other, {name}. For the Horde!"],
			L["Forward, {name}. The Horde advances together. Retreats... never, officially."],
			L["Together we're a war band, {name}. Apart, we're just loud."],
			L["Shoulder to shoulder, {name}. Whoever charges first buys the grog."],
			L["Nobody gets left behind, {name}. I've counted us twice."],
		},
	},
	Neutral = {
		thanks = {
			L["Thank you, {name}. Good hearts turn up on every side, and apparently here."],
			L["Thank you, {name}. No side, no title, just kindness. Legends start like this."],
			L["Thank you, {name}. Kindness has no faction, which is handy, since I have none."],
			L["Thank you, {name}. Whichever side gets you is getting a bargain."],
			L["Whoever claims me in the end, {name}, I'll remember you first. Thank you."],
			L["Strictly neutral, {name}, but gratitude doesn't count. Thank you."],
		},
		asked = {
			L["Gladly, {name}, whatever banner you fly. I don't even own a banner."],
			L["Certainly, {name}. I help everyone. It's the one thing I've decided."],
			L["Everyone asks me which side I'm on, {name}. Much nicer to be asked for help."],
			L["Of course, {name}. No war council to ask; just me, and I say yes."],
			L["Here you are, {name}. No oath, no colours, no fee."],
		},
		offer = {
			L["Friends can come from any side, {name}. Or, like me, from none in particular."],
			L["Soon they'll hand us tabards, {name}. Until then, we look after each other."],
			L["I haven't chosen a side yet, {name}, so I'm being kind to both. Take this."],
			L["A gift with no strings, {name}. I don't even have a faction to tie them to."],
			L["Go on, {name}. Two whole factions are waiting to argue over us."],
			L["No quartermaster yet, {name}, so nobody's counting. Have plenty."],
		},
		group = {
			L["Side by side, {name}, whatever comes."],
			L["No flag over this party, {name}, just us. That's plenty."],
			L["One day we'll pick sides, {name}. Today we pick fights, together."],
			L["Whatever side the rest of the world is on, {name}, I'm on this party's."],
			L["Neutral in the war, {name}, but very partial to this group."],
		},
	},
}

-- Anybody's, in character without belonging to one people: they keep a race
-- from repeating itself, and they are all an unknown race has.
RP.GENERAL = {
	thanks = {
		L["One good turn deserves another, {name}."],
		L["Have some {buff} in return, {name}."],
		L["Kindness should go both ways, {name}. Thank you."],
		L["You went first, {name}, so I'll go second and we'll call it friendship."],
		L["I'd write you a song, {name}, but {buff} is less off-key."],
		L["A gift for a gift, {name}. At this rate we'll be unstoppable by supper."],
		L["All square, {name}. Unless you'd like to make it best of three."],
		L["You started it, {name}. I'm only finishing it."],
		L["That was kind, {name}. The day just got noticeably better. Here's my half."],
	},
	asked = {
		L["You asked, {name}, and here it is."],
		L["{buff}, coming right up, {name}."],
		L["Gladly, {name}. One moment."],
		L["Asked and answered, {name}. Next question?"],
		L["Say the word and it's yours, {name}. You said several. Here."],
		L["For you, {name}? Gladly. I was hoping someone would ask."],
		L["Of course, {name}. Easiest yes I'll say all day."],
		L["Right away, {name}. Finally, a question I know the answer to."],
	},
	offer = {
		L["Safe travels, {name}. {buff} packs lighter than a sword."],
		L["A small blessing for the road, {name}."],
		L["Go well, {name}, and come back in one piece."],
		L["No reason, {name}. It just felt like a {buff} sort of day."],
		L["Don't mind me, {name}. Just passing, with a spare {buff}."],
		L["Consider it a gift, {name}. I'd wrap it, but it glows through the paper."],
		L["Here, {name}. Pass it on when you meet someone who needs it."],
		L["Whatever brings you here, {name}, may it go better than planned."],
		L["Just being neighbourly, {name}. Very, very temporary neighbours."],
	},
	group = {
		L["Everyone ready? You are now, {name}."],
		L["A little something for the party, {name}."],
		L["Stay close, {name}. We go further together."],
		L["House rules, {name}: nobody dies, nobody sulks, everybody eats after."],
		L["There, {name}. Now if this goes badly, it won't be my fault."],
		L["All set, {name}. I'd give a speech, but we'd be here all day."],
		L["Look after that, {name}. It's the only one I brought for you."],
		L["Now we look the part, {name}. Let's go and be it."],
		L["Fresh {buff} all round, {name}. The rest is luck and elbows."],
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
			L["Thank you, {name}. I'd conjure a gift in return, but it would only be water."],
			L["Much obliged, {name}. I'll write it up properly later. Several pages."],
			L["Thank you, {name}. They never taught gratitude at Dalaran. I'm self-taught."],
			L["Kind of you, {name}. I'd say it went to my head, but that's my job."],
		},
		asked = {
			L["Of course, {name}. And yes, I suppose you'll want water as well."],
			L["As requested, {name}. Side effects may include footnotes."],
			L["At once, {name}. Carefully, too; I've blinked into two walls today."],
			L["Gladly, {name}. Knowledge should be shared. The Kirin Tor say so, reluctantly."],
		},
		offer = {
			L["Here, {name}. I had a spare thought and nowhere to put it."],
			L["Take this, {name}. I'd add bread, but conjured bread tastes of nothing."],
			L["{buff} for you, {name}. No charge, unlike the portals."],
			L["Here, {name}. Most folk I point at turn into sheep. Today's your lucky day."],
			L["Nothing on fire, nothing frozen, {name}. I'm branching out."],
		},
		group = {
			L["Now that you're clever, {name}, stand between me and the angry things."],
			L["For the record, {name}, I only blink away when it's tactically sound."],
			L["There, {name}. Wiser already: look, you're standing further from me."],
			L["Minds sharpened, {name}. I'll handle the fire, the frost and the panicking."],
		},
	},
	PRIEST = {
		thanks = {
			L["How thoughtful, {name}. The Light keeps accounts; I settle mine early."],
			L["Thank you, {name}. I'll put in a good word with the Light. It owes me several."],
			L["Thank you, {name}. A small miracle, and I didn't even have to pray for it."],
			L["Thank you, {name}. My faith in people is restored. It was only resting."],
		},
		asked = {
			L["Of course, {name}. The Light keeps no hours, and neither, sadly, do I."],
			L["Straight away, {name}. Most prayers take longer; you've found a shortcut."],
			L["Certainly, {name}. The Light shines on those who ask. I just aim it."],
			L["With pleasure, {name}. Faith moves mountains; I'm starting smaller."],
		},
		offer = {
			L["Bless you, {name}. No, you didn't sneeze; I'm simply thorough."],
			L["Here, {name}. Think of it as a prayer that arrived early."],
			L["The Light asked me to pass this along, {name}. I'm paraphrasing."],
			L["Take this, {name}. It saves us both an awkward resurrection later."],
			L["Freely given, {name}. Faith costs nothing. The robes, sadly, did."],
		},
		group = {
			L["Your turn, {name}. Now, I beg you all: make my job boring."],
			L["Everyone stay near me, {name}. The Light has a limited range."],
			L["There, {name}. If anyone falls, I'll be very disappointed, then fix it."],
			L["Done, {name}. I'll be at the back, praying loudly."],
		},
	},
	DRUID = {
		thanks = {
			L["Thank you, {name}. I'd purr, but I'm not in the right shape for it."],
			L["Thanks, {name}. My bear form sends a grateful grunt."],
			L["Much obliged, {name}. My cat form wants to bring you a rabbit. I've said no."],
			L["Thank you, {name}. I'll plant a tree in your honour. Give it a century."],
		},
		asked = {
			L["Certainly, {name}. Give me a moment to remember which shape has hands."],
			L["Of course, {name}. Hold still, like an oak. Oaks are wonderful at it."],
			L["Gladly, {name}. The wild shares everything. Well, not the bears."],
			L["Right away, {name}. Pardon the feathers; I've just come from being an owl."],
		},
		offer = {
			L["Fresh from the Emerald Dream, {name}. Sorry if I yawn."],
			L["Take this, {name}. Nature provides, and I'm its errand runner today."],
			L["The wild calls you friend now, {name}. Handy, since most of it has teeth."],
			L["I brought you flowers as well, {name}, but I was a stag at the time. Sorry."],
			L["Here, {name}. Cenarius would want you to have it. I'm nearly sure."],
		},
		group = {
			L["Ready, {name}? Now, whatever happens, nobody startle the bear."],
			L["There, {name}. I'll be the cat, the bear or, if we must swim, the seal."],
			L["I've one rebirth in me, {name}. Please, nobody make me choose."],
			L["Close ranks, {name}. The forest is watching, and it's rooting for us."],
		},
	},
	PALADIN = {
		thanks = {
			L["Kindness, {name}? My favourite virtue. Just ahead of polishing."],
			L["For that, {name}, my best blessing. Not the second best. The best."],
			L["Virtue rewarded on the spot, {name}! I do love it when that happens."],
			L["Thank you, {name}. My oath says to repay kindness. I'd do it anyway."],
		},
		asked = {
			L["By the Light, {name}, of course! I've been hoping somebody would ask."],
			L["You have my blessing, {name}. Literally, this time."],
			L["Certainly, {name}. Kneel if you like. I won't insist. I'll be delighted."],
			L["Gladly, {name}. I never run short of blessings. Mana, now and then."],
		},
		offer = {
			L["The Light asks nothing in return, {name}. I, however, accept thanks."],
			L["Go with the Light, {name}. I'll be right behind you, clanking."],
			L["The blessing's free, {name}. You've been spared the sermon. This time."],
			L["There, {name}. It won't last forever, so be heroic while it does."],
			L["Stand tall, {name}. The Light walks with you, and it has excellent posture."],
		},
		group = {
			L["You're blessed, {name}. If I bubble later, it's strictly tactical."],
			L["Stand fast, {name}. We have the Light, and I have a very large hammer."],
			L["One blessing each, {name}. The Light is generous, but it insists on turns."],
			L["Splendid, {name}. Now, nobody look directly at me. I'm rather bright today."],
		},
	},
	WARLOCK = {
		thanks = {
			L["How kind, {name}. My imp says thank you too. He's lying, but I'm not."],
			L["Thank you, {name}. It's been ages since anyone gave me something uncursed."],
			L["Thank you, {name}. I'll repay you with something I didn't find in a crypt."],
			L["Most gracious, {name}. I've asked the voidwalker to stop looming at you."],
		},
		asked = {
			L["Of course, {name}. No soul required. This time."],
			L["You asked a warlock for help, {name}. Bold. I like you already."],
			L["Of course, {name}. The imp offered to help, and I said no, for all our sakes."],
			L["Certainly, {name}. Of all my spells, this is the one I can do at parties."],
		},
		offer = {
			L["Here, {name}. Don't ask where it came from. Really, don't."],
			L["Fall in a lake someday, {name}, and you'll think of me fondly."],
			L["Breathe easy, {name}. I'd hate to lose you to anything as dull as water."],
			L["Here, {name}. You'll want a soulstone too, but that's a bigger conversation."],
			L["Take this, {name}. It's the only spell of mine the priests approve of."],
		},
		group = {
			L["Everyone ready, {name}? Souls intact? Good. Let's keep it that way."],
			L["Stay close, {name}. The voidwalker takes the hits; I take the credit."],
			L["Swim all you like, {name}. If anyone drifts off, I'll summon them back."],
			L["Do pet the felhunter, {name}. Just take your spells off first."],
		},
	},
	WARRIOR = {
		thanks = {
			L["Thank you, {name}! Sorry, was that loud? I only have the one volume."],
			L["Much obliged, {name}. No spells to give back, but I do a very sincere shout."],
			L["Thanks, {name}. Now I'm twice as angry. In the good way."],
			L["Thanks, {name}. You've earned a place right behind me. Safest spot there is."],
		},
		asked = {
			L["You want a shout, {name}? I was going to shout anyway."],
			L["Of course, {name}. Cover your ears; this is the only way I know how."],
			L["Right away, {name}. Stay in earshot. For me that's a generous distance."],
			L["Happily, {name}! Words aren't my strength. Volume is."],
		},
		offer = {
			L["Consider yourself shouted at, {name}. Affectionately."],
			L["No incense, no prayers, {name}. Just me, shouting encouragingly."],
			L["Chin up, {name}! If anything bothers you, I'll charge it."],
			L["There, {name}! Anything that doesn't feel braver now wasn't listening."],
			L["Here, {name}, some courage. Warriors make it by yelling. Don't ask how."],
		},
		group = {
			L["Listen up, {name}! That's it. That was the whole speech."],
			L["Where's the danger, {name}? Never mind, I'll find it. Face first."],
			L["Right, {name}! I go first, I shout loudest, and nobody touches the healer."],
			L["Everybody angrier? Good. Onward, {name}, and mind my backswing."],
		},
	},
}

-- About the spell going out, whichever moment it is, by the entry's buff key
-- (Buffs.lua). A spell with no lines here simply has none.
RP.SPELL = {
	intellect = {
		L["A sharper mind for you, {name}. Mine cost me an eyebrow in Dalaran."],
		L["More mana for you, {name}. Try not to spend it all on one fireball."],
		L["Thoughts humming, {name}? Normal. If they hum back, come and find me."],
		L["A little arcane for your thoughts, {name}. Keep the change."],
		L["Brilliance, bottled, {name}. The Kirin Tor would charge you for the bottle."],
		-- On retail it goes to warriors and rogues too: a line for whoever.
		L["Sharper wits, {name}. Spend them on spells, locks or riddles; I won't judge."],
	},
	fortitude = {
		L["Fortitude, {name}: a priest's polite way of saying 'stand in front'."],
		L["Every bit of stamina is one less panicked prayer from me, {name}."],
		L["Tougher already, {name}. Please don't take that as a dare."],
		L["There are other Power Words, {name}. 'Shield', and in emergencies, 'Run'."],
		L["Sturdier now, {name}. Falls, bears and bad decisions all hurt a bit less."],
		L["{buff}, {name}. Three words where 'be tougher' would do."],
	},
	spirit = {
		L["Consider your spirits lifted, {name}. Divinely, as it happens."],
		L["Like a good night's sleep, {name}, without all the lying down."],
		L["A second helping of spirit, {name}. The Light always insists on seconds."],
		L["Keep your spirit where it is, {name}. The Spirit Healers are busy enough."],
	},
	shadow = {
		L["Proof against shadow, {name}. I know its tricks; I've borrowed a few."],
		L["Should the Void call, {name}, you can now pretend you're out."],
		L["For when the dark gets personal, {name}. It usually does."],
		L["The shadows will have to knock first now, {name}."],
	},
	motw = {
		L["Marked by the wild, {name}. The deer will tip their antlers as you pass."],
		L["You may smell faintly of moss, {name}. That's how you know it's working."],
		L["Mark of the Wild, {name}. The wolves will still bite, but they'll feel bad."],
		L["The wild's own seal of approval, {name}. The squirrels were consulted."],
		L["A little of the wild in you now, {name}. Resist the urge to howl."],
		L["Hide, claw and a thick coat, {name}. The wild packs light but thorough."],
	},
	thorns = {
		L["Anything that bites you now gets a mouthful, {name}."],
		L["Let the boar charge, {name}. It'll leave with regrets and splinters."],
		L["Like a rose, {name}: lovely to look at, a mistake to grab."],
		L["Thorns, {name}. I grew them myself, so do be polite to them."],
	},
	kings = {
		L["Blessing of Kings, {name}. No crown, no throne, no taxes owed."],
		L["Long may you reign, {name}. For the next while, anyway."],
		L["A little more of everything, {name}. Kings never did settle for less."],
		L["A king's blessing, {name}. Worn by better heads than mine, and some worse."],
		L["Every strength a little higher, {name}. Kings like to hedge their bets."],
		L["Crown not included, {name}. Everything else is, a little."],
	},
	might = {
		L["Might doesn't make right, {name}, but it does help the argument."],
		L["A firmer swing for you, {name}. The Light loves a good follow-through."],
		L["Stronger arms, {name}. Kindly point them at something that deserves it."],
		L["Blessing of Might, {name}. It'll surprise you. It'll surprise them far more."],
		L["Swing away, {name}. The Light will take the credit if it goes well."],
		L["Hit harder, {name}. Them, I mean. Not me. Never the paladin."],
	},
	wisdom = {
		L["Wisdom for you, {name}. I kept a little back for myself. Very little."],
		L["Wisdom for your mana, {name}. The other kind still comes from bad decisions."],
		L["Your mana creeps back on its own now, {name}, like a cat that's forgiven you."],
		L["Fewer sips between fights, {name}. The innkeepers will be heartbroken."],
		L["Drink less, cast more, {name}. The Light's own budget advice."],
		L["Blessing of Wisdom, {name}: the one blessing that pays for itself."],
	},
	salvation = {
		L["A blessing of quiet, {name}. Monsters will forget whose fault it was."],
		L["Blessing of Salvation, {name}. You are now somebody else's problem."],
		L["Saved, {name}. Not your soul, mind. Just your hide."],
		L["Hit hard, {name}. If anything turns round, look innocent. The Light will."],
	},
	light = {
		L["The Light will find you easier now, {name}. Try not to squint."],
		L["Holy Light lands harder on you now, {name}. Please don't make me prove it."],
		L["You'll heal easier, {name}. The Light appreciates a willing patient."],
		L["Blessing of Light, {name}. Saving you is simpler now. Not that you'll need it."],
	},
	sanctuary = {
		L["Block a blow now, {name}, and the Light hits back for you. It's petty."],
		L["Every blow lands softer now, {name}. Complaints go to the Light."],
		L["All the shelter of a temple, {name}, and none of the roof repairs."],
		L["Claim sanctuary, {name}. It's easier when you bring your own."],
	},
	battleshout = {
		L["Instructions, {name}: hit things harder. There is no page two."],
		L["Your sword arm is sorted, {name}. For the rest of you, see a priest."],
		L["Battle Shout, {name}. Not a spell, really. A strongly worded suggestion."],
		L["RAAAGH! That one was for you, {name}. Everyone else just overheard."],
	},
	breath = {
		L["A little breath from the damned, {name}. They weren't using it."],
		L["Unending Breath, {name}. The fish will have so many questions."],
		L["Stay down as long as you like, {name}. Something else is holding its breath."],
		L["Swim deep, {name}. If a murloc asks, you're only visiting."],
	},
}

-- Thanks only, and only when the spell they gave you is known: {gift} is
-- theirs, {buff} is yours. Left out when the two are the same spell.
RP.TRADE = {
	L["Folk will think we're duelling, {name}. Thanks for the {gift}."],
	L["{gift} for {buff}. No auctioneer's cut, {name}."],
	L["Beaten to it, {name}! Your {gift} was quicker than my manners."],
	L["{gift} in, {buff} out. Finest economy in all Azeroth."],
	L["{gift}, for me? All I have is this, {name}, but it's heartfelt."],
	L["Your {gift} fits perfectly, {name}. Did you measure me?"],
	L["A treaty in spells, {name}: {gift} for {buff}."],
	L["{gift}! I feel taller already. Have some {buff}."],
	L["I was about to ask for {gift}, {name}. You read my mind."],
	L["Your {gift} still fizzes, {name}. Here's some fizz back."],
	L["Such a kind {gift}, {name}. I'll tell the whole inn. Twice."],
	L["You cast {gift} first, {name}? My mother would despair of me."],
	L["I'll remember your {gift} fondly, {name}. Until it wears off."],
	L["{gift} for {buff}, free. Somewhere, a goblin weeps."],
	L["Your {gift}, my {buff}. We'll be unbearable now."],
	L["Thanks for the {gift}, {name}. I'll earn it before it fades."],
	L["For {gift} I'd hand you both moons, {name}. This'll have to do."],
	L["You brought {gift}, I brought {buff}. Now it's a party."],
}

-- Thanks only, like RP.TRADE, and about what the spell they gave you does
-- rather than its name: Arcane Intellect makes you clever, Thorns prickly, a
-- shout loud. By that spell's buff key (Buffs.lua), found from the debt's
-- spell id; heard next to the trade lines, which stay the most varied way to
-- say it, since the same priest will give you Fortitude all evening.
RP.GIFT = {
	intellect = {
		L["{gift}! I just had three clever thoughts, {name}. This was one."],
		L["With {gift}, {name}, I finally understand my own notes. Thanks."],
		L["Cleverer already, {name}. Clever enough to know I owe you one. Here."],
	},
	fortitude = {
		L["{gift}, {name}? I'll stand at the front for once. Briefly."],
		L["Knees, elbows and pride, {name}: all fortified. Thank you."],
		L["Hit me now, {name}. Actually, don't. But thank you; I'd survive it."],
	},
	spirit = {
		L["{gift}! My spirits are lifted, {name}. Literally, it seems."],
		L["I feel twice as calm and half as grumpy, {name}. Thank you."],
	},
	shadow = {
		L["Shadow-proof, thanks to you, {name}. The whispers are furious."],
		L["Nothing dark gets in now, {name}. Here's something bright going the other way."],
	},
	motw = {
		L["{gift}! A squirrel just nodded at me, {name}. Here's yours."],
		L["Tougher hide, sharper senses, {name}. I may have to fight the urge to forage."],
		L["I feel all wild and leafy, {name}. Thank you. Sorry if I shed bark."],
	},
	thorns = {
		L["{gift}, {name}! Nobody's hugging me today. Have this instead."],
		L["Prickly now, thanks to you, {name}. More than usual, I mean."],
	},
	kings = {
		L["{gift} from you, {name}? I'll try not to found a dynasty."],
		L["A little better at everything, {name}. Is this how kings feel? No wonder."],
	},
	might = {
		L["Stronger arms already, {name}. I'll try not to hug anyone. Thank you."],
		L["With {gift} I could lift a kodo, {name}. I won't, but thank you."],
	},
	wisdom = {
		L["{gift} from you, {name}, and my first wise act is this."],
		L["Wiser already, {name}. Wise enough to know a kindness when I see one."],
	},
	salvation = {
		L["{gift}! The monsters forgot me at once, {name}. I won't."],
		L["Nothing wants to fight me now, {name}. It's lovely. Thank you."],
	},
	light = {
		L["The Light finds me easier now, {name}. It says thank you, and so do I."],
		L["Easier to heal now, thanks to you, {name}. My healer thanks you too."],
	},
	sanctuary = {
		L["Blows land softer on me now, {name}. My bruises thank you, and so do I."],
		L["Every hit gentler, thanks to you, {name}. I'll make sure they notice."],
	},
	battleshout = {
		L["You shouted at me, {name}, and I've never felt so encouraged. Here."],
		L["My ears are ringing, {name}, and my arms feel twice as strong. Thank you!"],
	},
	breath = {
		L["I can breathe underwater, {name}! I may never need to, but thank you."],
		L["Lungs like a murloc, thanks to you, {name}. Mrgl. Sorry. Thank you."],
	},
}

-- How often the two of you have traded this session (RP.Familiar): "again"
-- for the second or third time, "regular" for the fourth and on.
RP.HISTORY = {
	again = {
		L["We have to stop meeting like this, {name}. Actually, no, we don't."],
		L["Again, {name}? Splendid. I've been practising since last time."],
		L["You again, {name}? People will start saying we're friends."],
		L["Same face, same spell, {name}. I do love a tradition."],
		L["Another round, {name}? I'm keeping score, and we're both winning."],
		L["Ah, {name}! My favourite repeat customer."],
		L["Our paths keep crossing, {name}. I think the road is dropping hints."],
		L["Hello again, {name}. Do stop me if you've heard this one."],
		L["I kept some aside, {name}, in case you came back. Good instinct, mine."],
		L["Back already, {name}? I'm starting to think you like me."],
	},
	regular = {
		L["{name}, at this point we should just share a reagent pouch."],
		L["Same time tomorrow, {name}? I'll bring {buff}. You bring you."],
		L["I've lost count, {name}, and I've decided that's a compliment."],
		L["Keep this up, {name}, and the bards will write a very dull song about us."],
		L["I could do this one in my sleep by now, {name}. I may have."],
		L["{name}, the usual? Of course the usual. It's always the usual."],
		L["We ought to have a secret handshake by now, {name}. Next time, perhaps."],
		L["By now, {name}, I think we've built a small economy between us."],
		L["Old friends by now, {name}. Well, old acquaintances with excellent timing."],
		L["Let the record show: {name} and I, undefeated at being prepared."],
	},
}

-- Where this is (RP.Place): "city" is resting, in a city or an inn; "wild" is
-- outdoors; "instance" is a dungeon or a raid; "battle" is a battleground or
-- an arena, where the lines keep to pride and say nothing of the other side.
-- A scenario is none of them.
RP.PLACE = {
	city = {
		L["Safe walls, warm beds, and now {buff}. You're spoiled, {name}."],
		L["The guards have it covered, {name}, but I like to be thorough."],
		L["Careful, {name}. Look this capable in town and folk will ask you favours."],
		L["Not a monster for miles, {name}. Still, one never knows about the cooking."],
		L["For the crowds, {name}. In town, they're the real danger."],
		L["Rest easy, {name}. I'll count that my good deed and go find a pint."],
		L["Even in town, {name}, a dragon has been known to drop in. Better safe."],
		L["Best do it in here, {name}. Out there, nobody stands still long enough."],
	},
	wild = {
		L["Out here everything wants to eat you, {name}. Now it'll need a bigger fork."],
		L["No guards for miles, {name}, and the boars know it. Take this."],
		L["Nobody out here but us and the wildlife, {name}. Let's be the tougher half."],
		L["If a bear asks, {name}, you were like this when I found you."],
		L["The wolves have been eyeing you, {name}. This should give them pause."],
		L["Wild country, {name}. Best not to meet it armed with good intentions alone."],
		L["Map, canteen, {buff}. Now you can get lost properly, {name}."],
		L["Camp's a long way off, {name}. Consider this a roof you can carry."],
	},
	instance = {
		L["Somewhere in here a villain is rehearsing a speech, {name}. Let's interrupt."],
		L["Whatever waits at the end of this place, {name}, let's make it regret it."],
		L["They say nobody leaves here alive, {name}. Let's be rude and prove them wrong."],
		L["Our host had years to prepare, {name}. We have {buff}."],
		L["Nobody builds a dungeon with a back door, {name}. Take this instead."],
		L["Dark halls, old traps, worse tempers. At least you're ready, {name}."],
		L["Better I hand you this now, {name}, than a eulogy later."],
		L["There's treasure in here, {name}, and something very large sat on it."],
	},
	battle = {
		L["Flags, towers, graveyards, {name}. Whatever we're fighting over, take this."],
		L["Win or lose, {name}, nobody will say you went in unprepared."],
		L["The graveyard's just over there, {name}. Let's both not visit it."],
		L["Honour's on the line, {name}. So is the flag. Mostly the flag."],
		L["Stay with the group, {name}. Lone heroes end up in the other side's songs."],
	},
}

-- The hour on the realm's clock (RP.Hour): "morning" from five until eleven,
-- "night" from ten at night until five. Anybody's; a people whose hour it is
-- has its own lines as well (RP.RACE's "night" and "morning").
RP.TIME = {
	morning = {
		L["Early bird, {name}? Here's something better than a worm."],
		L["Good morning, {name}. Consider this your first cup of something strong."],
		L["Early start, {name}. The day hasn't had a chance to go wrong yet."],
		L["Not even lunch yet, {name}, and you're already better prepared than I am."],
		L["Morning, {name}. Somewhere, the monsters are still yawning."],
		L["A fresh day and a fresh {buff}, {name}. Let's not waste either."],
	},
	night = {
		L["Out this late, {name}? The night is hungrier than the day. Take this."],
		L["Past bedtime, {name}. The sensible folk are asleep, which leaves us."],
		L["Can't sleep either, {name}? Then let's be well-protected insomniacs."],
		L["Mind the dark, {name}. Not everything out there is as friendly as I am."],
		L["It's late, {name}. This should keep you going till the sun remembers us."],
		L["Only the owls and us awake, {name}, and the owls get no {buff}."],
	},
}

-- The class of the person being helped (RP.Target): "sameclass" when it is
-- the speaker's own, or their class token otherwise. Gentle, and never at
-- their expense: the joke is on the help, the speaker or the world. Two of the
-- same class hear RP.SAME for that class, and these "sameclass" lines when it
-- has none.
RP.TARGET = {
	sameclass = {
		L["Takes one to know one, {name}. Takes one to do it properly, too."],
		L["From one of our trade to another, {name}. No need to check my work."],
		L["Professional courtesy, {name}. We don't charge each other."],
		L["Two of a kind, {name}. Between us we could write the manual."],
		L["Don't look so surprised, {name}. Same trainer, I expect."],
		L["I'd critique your technique, {name}, but mine looks exactly the same."],
		L["Don't tell the others, {name}, but ours really is the finest calling."],
		L["Look at us, {name}. Two experts, making it look easy. It isn't, is it?"],
	},
	WARRIOR = {
		L["I'd shout some encouragement, {name}, but you do that far better."],
		L["Charge in as usual, {name}. I'll simply feel better about it now."],
		L["For the one who goes in first, {name}. Somebody has to, and it's never me."],
		L["You take the hits so the rest of us don't, {name}. It's the least I can do."],
		L["Go on, {name}, charge. I'll be right behind you. Quite a long way behind."],
	},
	PALADIN = {
		L["Save the bubble for later, {name}. This one's from me."],
		L["You bless everyone else all day, {name}. Here's one going the other way."],
		L["The Light already likes you, {name}. Consider this a second opinion."],
		L["Even the Light's own champion needs a hand now and then, {name}."],
		L["I'd ask for a blessing back, {name}, but then we'd be here all day."],
	},
	HUNTER = {
		L["One for you, {name}, and a pat on the head for your companion."],
		L["You watch everyone's back from range, {name}. I've got yours."],
		L["Hunter's Mark for them, {buff} for you, {name}. Much nicer."],
		L["Aim true, {name}. And if it charges you anyway, run towards the rest of us."],
		L["Your pet was looking at me hopefully, {name}. This is for you; tell it sorry."],
	},
	ROGUE = {
		L["For the one I never see coming, {name}. Meant as the highest praise."],
		L["Quick, {name}, before you vanish again."],
		L["Poison on the blades, {buff} on you. Very thorough, {name}."],
		L["I'd slip it in your pocket, {name}, but you'd notice. You always notice."],
		L["For the one who opens every locked box, {name}. This one comes unlocked."],
	},
	PRIEST = {
		L["For once, {name}, somebody's looking after the priest."],
		L["Save your prayers for the rest of us, {name}. This one's already answered."],
		L["Light or Shadow, {name}, I don't ask which. This suits both."],
		L["Sit down after this fight, {name}. That's an order, from a grateful patient."],
		L["You keep us all standing, {name}. Here's a little of it coming back."],
	},
	DEATHKNIGHT = {
		L["No voice in your head comes with this one, {name}. Refreshing, isn't it?"],
		L["The Ebon Blade asks no favours, {name}. I'm giving one anyway."],
		L["A little warmth, {name}. I know you don't feel the cold. It's the thought."],
		L["You came back from the dead, {name}. The least I can do is help you stay back."],
		L["Runes, plague and frost, {name}. Take this too; it completes the set."],
	},
	SHAMAN = {
		L["The elements look after you, {name}, but they don't make house calls."],
		L["Tell the spirits I said hello, {name}. They never write back."],
		L["Plant a totem in my honour, {name}. A small one. I'm modest."],
		L["Earth, fire, water, air and me, {name}. Admittedly the least of the five."],
		L["Totems up already, {name}? Then this goes next to them. Don't plant it."],
	},
	MAGE = {
		L["A gift for a mage, {name}? Like bringing water to... well, you."],
		L["You solve most problems with sheep, {name}. This covers the rest."],
		L["You could teleport out of any trouble, {name}. This is for the trouble first."],
		L["For the clever one, {name}. Please don't thank me by making me a sheep."],
		L["Blink wherever you like, {name}. This comes too."],
	},
	WARLOCK = {
		L["Entirely demon-free, {name}. I checked."],
		L["Your imp may be jealous, {name}. Tell it there's plenty to go round."],
		L["No contract, no fine print, {name}. Just a gift."],
		L["For the one who hands out healthstones, {name}. Nobody ever thanks you."],
		L["Here, {name}. Summon the rest of us later and we'll call it even."],
	},
	MONK = {
		L["Roll wherever you like, {name}. This rolls with you."],
		L["Brew first or fight first, {name}? Either way, take this."],
		L["Inner peace for you, {name}, and outer peace too, as long as this lasts."],
		L["Chi flows better with a little help, {name}. Or so a monk once told me."],
		L["Kick, flip, roll, {name}. I'll just stand here and do this bit."],
	},
	DRUID = {
		L["Tell the bear this is for them too, {name}."],
		L["Hold still, {name}. I've never once managed to catch you as a cheetah."],
		L["Nature looks after you already, {name}. Today she sent me to help."],
		L["Whatever shape you're in next, {name}, this goes with you."],
		L["For the forest's friend, {name}. Give my regards to the trees."],
	},
	DEMONHUNTER = {
		L["You were not prepared, {name}. Now you are."],
		L["Ten thousand years in a cell, {name}. You've earned a small kindness."],
		L["You gave up so much to fight the Legion, {name}. Here's a little back."],
		L["For the one who leaps first, {name}. Do land somewhere friendly."],
		L["Fel and fury, {name}, and now a little kindness. It'll balance out."],
	},
	EVOKER = {
		L["For you, {name}. Please don't breathe on it."],
		L["A little help for a dragon, {name}. I'll be telling my grandchildren."],
		L["The Aspects sent you out into the world, {name}. I'm making it friendlier."],
		L["Take to the skies after this, {name}. I'll wave from down here."],
		L["A dragon on our side, {name}. I've never felt safer being generous."],
	},
}

-- The same class meeting itself, by that class (UnitClass's second return),
-- in place of RP.TARGET's "sameclass" lines: two mages have a joke two of
-- anything else do not.
RP.SAME = {
	MAGE = {
		L["{buff} for a mage, {name}. Like lending a library a book."],
		L["Mage to mage, {name}: I won't ask you for water if you won't ask me."],
		L["Two mages, {name}. Between us we can portal anywhere and still be late."],
		L["A mage for a mage, {name}. The Kirin Tor would call this peer review."],
	},
	PRIEST = {
		L["Priest to priest, {name}: who blesses the blessers? Today, me."],
		L["Between us priests, {name}, we'll both pretend the tank listens."],
		L["A priest looking after a priest, {name}. It feels almost forbidden."],
		L["Two priests, {name}. Twice the praying and half the panic."],
	},
	DRUID = {
		L["Two druids, {name}. The Cenarion Circle would call this a quorum."],
		L["Druid to druid, {name}: bear or cat, I'd know you by the leaves in your hair."],
		L["From one shapeshifter to another, {name}: this one fits every shape."],
		L["No handshake, {name}. Two druids, and neither of us has the right shape for it."],
	},
	PALADIN = {
		L["Paladin to paladin, {name}: I won't mention the bubble if you don't."],
		L["A blessing for a paladin, {name}. Now we're both insufferably radiant."],
		L["Two paladins, {name}. Somewhere, a priest is quietly relieved."],
		L["One of us should be humble about this, {name}. Neither of us will be."],
	},
	WARLOCK = {
		L["Warlock to warlock, {name}: keep your imp away from mine. They gossip."],
		L["Fellow warlock, {name}? Then you know this one's actually harmless. Honestly."],
		L["Two warlocks, {name}. Let's not compare soul shards in public."],
		L["Between us, {name}, the demons do all the work. This bit I do myself."],
	},
	WARRIOR = {
		L["Two warriors, {name}. Somewhere, a healer just sighed."],
		L["Warrior to warrior, {name}: first into the fight buys the drinks. I'm buying."],
		L["Shout for shout, {name}. We'll deafen the whole place together."],
		L["No plan, {name}? Perfect. We'll get along."],
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
-- A people's own lines weigh most of what is always there, so a dwarf sounds
-- like a dwarf over a session. The moments that are rare and made for this
-- very click (somebody met again, a gift to answer, kin) weigh as much or
-- more, so they come up when they apply; a third meeting is the one a player
-- notices most, so it weighs most of all. The moments that are nearly always
-- true (a place, the hour, the spell, whom you are helping) weigh little
-- each, since several apply at once; a people's own hour a little more than
-- everybody's. Worked through for full pools: a stranger outdoors at midday
-- hears their people a little under a third of the time; a favour whose
-- spell is known is answered about the gift nearly a third of the time and
-- with the people's own thanks a fifth; somebody met a third time hears about
-- it one pick in five. Kin weighs less than the people's lines because a kin
-- pool is small, and a small pool at full weight is the one heard over and
-- over. In a group the group lines are the point, so they outweigh the side's.
RP.WEIGHT = {
	race = 7, kin = 6, class = 3, faction = 2, general = 1, group = 3,
	spell = 4, trade = 6, gift = 4, history = 10, place = 3, time = 3,
	hour = 4, target = 4,
}
RP.SPREAD = 3

-- How many picks back a line is remembered: one said lately gets no share
-- while any other line still fits, so five people helped in a row hear five
-- different lines. By the line as written, so the same joke to another name
-- still counts. Nothing is saved; a reload forgets.
RP.RECENT = 12

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
	-- offers when there are no group lines (a people's at half weight: see
	-- RP.Pick).
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
	-- our own class (RP.Pick then asks RP.SAME first), their class token
	-- otherwise, nil when it is unknown. The
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

	-- The spell id on the debt for this person, or nil.
	local function GiftId(entry)
		local owed = ns.owed
		local debt = type(owed) == "table" and type(entry.name) == "string" and owed[entry.name]
		local id = type(debt) == "table" and ns.plain(debt.spell) or nil
		if type(id) ~= "number" then return nil end
		return id
	end

	-- The name of the spell they gave you, for {gift}, or nil when it is not
	-- known. The debt records it (Core's NoteFavour files the spell with the
	-- favour); a debt kept across a reload does not, and gets no trade line.
	-- Roll a few hands in a stand-in as entry.gift.
	function RP.Gift(entry)
		if type(entry) ~= "table" then return nil end
		local name = entry.gift
		if name == nil then
			local id = GiftId(entry)
			if not id then return nil end
			name = SpellName(id)
		end
		name = ns.plain(name)
		if type(name) ~= "string" or name == "" or name:find("[|\r\n]") then return nil end
		return name
	end

	-- The buff key of the spell they gave you ("intellect", "thorns"), for
	-- RP.GIFT, or nil: the debt's spell looked up in Buffs.lua's ids, where
	-- any rank or group version of it is filed. Roll a few's stand-in hands
	-- its key in as entry.giftKey.
	function RP.GiftKey(entry)
		if type(entry) ~= "table" then return nil end
		local key = entry.giftKey
		if key == nil then
			local id = GiftId(entry)
			local byId = ns.BUFF_BY_ID
			local buff = id and type(byId) == "table" and byId[id]
			key = type(buff) == "table" and buff.key or nil
		end
		if type(key) ~= "string" then return nil end
		return key
	end

	-- Where this is, for RP.PLACE: "instance" in a dungeon or raid, "battle"
	-- in a battleground or an arena, "city" while resting (a city or an inn),
	-- "wild" anywhere else outdoors; nil in a scenario, and whenever the client
	-- will not say, since the wilds guessed in an inn read wrong.
	function RP.Place()
		local known, inside, what = Read(_G.IsInInstance)
		if not known then return nil end
		if inside then
			if what == "party" or what == "raid" then return "instance" end
			if what == "pvp" or what == "arena" then return "battle" end
			return nil
		end
		local sure, resting = Read(_G.IsResting)
		if not sure then return nil end
		if resting then return "city" end
		return "wild"
	end

	-- The hour on the realm's clock, for RP.TIME and a people's own hour:
	-- "morning" from five until eleven (5:00 to 10:59), "night" from ten at
	-- night until five (22:00 to 4:59), nil in between and when the client
	-- will not say.
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

	-- The lines picked lately, oldest first, and how many times each is among
	-- them, by the line as written (RP.RECENT).
	local lately, latelyCount = {}, {}

	local function Remember(text)
		lately[#lately + 1] = text
		latelyCount[text] = (latelyCount[text] or 0) + 1
		local keep = tonumber(RP.RECENT) or 0
		while #lately > keep do
			local old = table.remove(lately, 1)
			local left = latelyCount[old] - 1
			latelyCount[old] = left > 0 and left or nil
		end
	end

	-- One line for this person, now, with the channel command in front, or nil
	-- when nothing fits. Every pool the moment calls for is gathered, each at
	-- its share of the draw (RP.WEIGHT, RP.SPREAD), and every candidate is
	-- measured before the roll rather than after it, so a long name or spell
	-- leaves the shorter lines to choose from instead of silence. A line
	-- picked in the last RP.RECENT gets no share while another still fits, and
	-- only then: the memory never silences the set.
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

		local lines, weights, tags, texts, total = {}, {}, {}, {}, 0
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
						texts[#lines] = text
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

		-- Who is speaking. A people with no group lines speaks its offers to
		-- the group at half weight: some of them are for a stranger on a road.
		local race = RP.RACE[family]
		local own = race and race[kind]
		if own then
			add(own, weight.race, "race")
		else
			add(PoolFor(race, kind), weight.race / 2, "race")
		end
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
		-- Filed with the trade lines, so Roll a few's favour row shows either.
		if gift then add(RP.GIFT[RP.GiftKey(entry)], weight.gift, "trade") end
		add(RP.HISTORY[RP.Familiar(entry, kind)], weight.history, "history")
		add(RP.PLACE[RP.Place()], weight.place, "place")
		local hour = RP.Hour()
		add(RP.TIME[hour], weight.time, "time")
		add(race and hour and race[hour], weight.hour, "hour")
		local helped = RP.Target(entry, class)
		add(helped == "sameclass" and RP.SAME[class] or RP.TARGET[helped], weight.target, "target")
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

		-- Nothing said lately, while anything else is left to say.
		local fresh = 0
		for i = 1, #lines do
			if not latelyCount[texts[i]] then fresh = fresh + weights[i] end
		end
		if fresh > 0 and fresh < total then
			for i = 1, #lines do
				if latelyCount[texts[i]] then weights[i] = 0 end
			end
			total = fresh
		end

		local roll = math.random() * total
		local chosen
		for i = 1, #lines do
			roll = roll - weights[i]
			if roll < 0 then
				chosen = i
				break
			end
		end
		-- Only rounding misses: the last line with any share.
		if not chosen then
			for i = #lines, 1, -1 do
				if weights[i] > 0 then
					chosen = i
					break
				end
			end
		end
		if not chosen then return nil end
		Remember(texts[chosen])
		return lines[chosen]
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
	-- the one this character gives, named as the client names it, and its key.
	local STAND_INS = { { "PRIEST", "fortitude" }, { "DRUID", "motw" }, { "MAGE", "intellect" } }
	local function StandInGift(buff)
		local mine = buff and ns.BuffName(buff)
		for _, pick in ipairs(STAND_INS) do
			local other = ns.FindBuff(pick[1], pick[2])
			local id = other and other.ranks and other.ranks[1]
			local name = id and SpellName(id)
			if type(name) == "string" and name ~= "" and name ~= mine then return name, pick[2] end
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
		local gift, giftKey = StandInGift(buff)
		local rows = only and { ROLL[1] } or { ROLL[1], ROLL[2], ROLL[3], ROLL[4] }
		if gift then rows[#rows + 1] = GIFTED end
		rows[#rows + 1] = only and AGAIN_OWED or AGAIN
		for _, row in ipairs(rows) do
			local fake = { short = somebody, name = somebody, reason = row.reason, buff = buff,
				lean = row.lean, met = row.met, gift = row.lean == "trade" and gift or nil,
				giftKey = row.lean == "trade" and giftKey or nil }
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
