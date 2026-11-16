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

-- Read through a proxy that remembers each translation's English key, because
-- the box keeps whatever language it was filled in: a player who picks the set
-- before the lines are translated has English examples saved, and they must
-- still count as untouched once a later release translates them. The proxy
-- only forwards: every key reaching it is written below as a whole L["..."]
-- literal, which is what the translation audit collects.
--
-- A line reworded in English may be translated as it was, and then the new
-- and the old English are one text. The pools are read before RP.LEGACY, so
-- ENGLISH_NOW keeps the first key read, for the pools as they are, and
-- ENGLISH the last, for the pools before the rewording (RP.BEFORE) and what
-- RP.LEGACY holds.
local ENGLISH, ENGLISH_NOW = {}, {}
local L = setmetatable({}, {
	__index = function(_, key)
		local translated = ns.L
		local text = translated[key]
		ENGLISH[text] = key
		if ENGLISH_NOW[text] == nil then ENGLISH_NOW[text] = key end
		return text
	end,
})

-- UnitRace's second return, the untranslated file name, to the people whose
-- lines it speaks. Allied races share their parent people's voice: a Mag'har
-- says Lok'tar as readily as any orc. The Haranir, new with Midnight, have
-- had lines of their own since 1.7.2, written from what Blizzard has published
-- of them (warcraft.wiki.gg's Haranir and Harandar pages and the quests they
-- cite); a race missing here speaks with its faction's voice and the general
-- lines, which is better than guessing at a culture. The file name is the
-- client's ChrRaces.ClientFileString, not the race's name: "Scourge" for the
-- Forsaken, "EarthenDwarf" for the Earthen, and "Harronir" for the Haranir
-- (wago.tools ChrRaces 86 and 91; Blizzard's own glue screens say HARRONIR).
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
	Harronir = "haranir",
}

-- Each people's lines by what the moment is: "thanks" for returning a favour,
-- "asked" for answering a request, "offer" for a buff nobody asked for, "group"
-- for somebody in your own party -- no road, no stranger, no "well met" to a
-- person you have fought beside for an hour -- and "kin" for somebody of the
-- same people. A people with the hour in its bones (the night elves' night,
-- the pandaren's breakfast) has "night" or "morning" lines too, heard next to
-- everybody's at that hour (RP.TIME). A people with a city of its own in
-- RP.HOME may have "city" lines, said there in place of anybody's (RP.PLACE),
-- and "outsider" lines, by moment, about how other peoples take to it, which
-- join that moment's lines for somebody who is not kin, away from home. A kin
-- line joins whichever of the others is being said, so it greets nobody:
-- "well met" is wrong to somebody who just buffed you. No line says "buff"
-- either -- the set is in character, and {buff} is the spell's own name.
--
-- The first few lines of a pool are the phrase box's examples (RP.Examples
-- says how many of which), and a box players have saved is recognised by
-- them: reword or reorder those and every box saved with them reads as the
-- player's own lines, and In character stops. Add new lines after them, and
-- a reworded example goes into RP.LEGACY.reworded as it read before (the
-- second rewording's into RP.LEGACY.reworded2).
-- RP.LEGACY also keeps the lines beta.9 saved, which have been rewritten since.
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
			L["Thank ye, {name}. Back at ye, before me pride notices I needed it."],
			L["Thank ye, {name}. Muradin said a debt left unpaid rusts. Here, before it does."],
			L["Thank ye, {name}. Even me ram looked impressed, and he hates everybody."],
			L["The Explorers' League'll ask where ye dug up such manners, {name}. Thanks!"],
			L["Thank ye, {name}. Warmed me right down to me boots, that did."],
			L["Mined half o' Khaz Modan, {name}. Never struck a vein that rich. Yer cut."],
			L["Like a Kharanos hearth in a Dun Morogh blizzard, that, {name}. Thank ye."],
			L["Came back to ye like a Wildhammer's stormhammer, {name}. Less painful, mind."],
			L["Come to Ironforge, {name}. Me mam'll feed ye till ye can't stand. Thank ye!"],
			L["Checked it fer gunpowder out o' habit, {name}. Clean as a whistle. Here's yers!"],
			L["Thank ye, {name}. Ye'll be the talk o' the Great Forge tonight."],
			L["Not even Magni could've done that kinder, {name}. Louder, aye. Thank ye."],
			L["Thank ye, {name}. I'd offer me beard as surety, but I'm terrible fond of it."],
			L["Back at ye, {name}, quick as a ram goin' downhill. Stoppin' is the hard part."],
			L["Thank ye, {name}. Ye'd make a fine honorary dwarf. We'll work on yer singin'."],
			L["Thank ye, {name}. If ye ever need a tunnel dug, I'm yer dwarf."],
			L["Keep yer powder dry and yer friends closer, me da said. Here, {name}."],
		},
		asked = {
			L["Aye, {name}, ye only had to ask. Hold still now, like a good anvil."],
			L["Say no more, {name}. Stone and steel, here it comes."],
			L["Ask a dwarf fer help, {name}, and ye'll get it. Loudly."],
			L["Right, {name}. Brace yerself; I do everything like I'm swingin' a hammer."],
			L["Aye, {name}, and a story about it ye didn't ask fer. Where to begin..."],
			L["One {buff}, pulled fresh like a proper pint, {name}."],
			L["Done, {name}. Dwarven work: over-built, under-priced and guaranteed."],
			L["Easy, {name}. Last time I helped a gnome, it cost me both eyebrows."],
			L["Aye, {name}. Mountain kings never refuse. I'm more a foothill, but same rule."],
			L["Tempered and quenched, {name}. Mind, it's still hot."],
			L["Done afore ye finished, {name}. Dwarves hear 'please' through solid rock."],
			L["Aye, {name}. In Dun Morogh ye help quick, or ye both freeze standin' there."],
			L["Aye, {name}. Ye'll feel it in yer boots first. That's how ye know it's dwarven."],
			L["Aye, {name}. Say no, and ye'd ask a gnome, and then I'd feel responsible."],
			L["Course, {name}. A dwarf who won't help is no dwarf. Just a short, grumpy rock."],
			L["Mountaineer's promise, {name}: done right, done once. Mostly."],
			L["Fer you, {name}? Easy as findin' ale in Ironforge."],
			L["Ask a Bronzebeard, {name}, and ye get it with both hands. Here."],
			L["Aye, {name}. Stand on that rock while I see to ye. Good rock, that. Granite."],
			L["Aye, {name}. In the mines, ye shout and somebody comes runnin'. Here I am."],
		},
		offer = {
			L["Here, {name}, a wee somethin' to keep ye on yer feet. Wee, like me."],
			L["Off ye go, {name}, with a wee blessin' from me. Steady as the mountain."],
			L["Here, {name}. Ale's for after; this is for before."],
			L["Magni'd melt down his crown fer a friend, {name}. This is the cheaper option."],
			L["A dwarf's got yer back, {name}. Well, yer knees. Close enough."],
			L["Take this, {name}. If a trogg bothers ye, tell it a dwarf sent ye. Then run."],
			L["If it wears off, {name}, give it a good thump. That's how we fix everything."],
			L["Take this, {name}. I'd give ye some stubbornness too, but I'm usin' all mine."],
			L["That'll warm ye, {name}. Mind the wendigos: big, hairy and grumpy. Like me."],
			L["Take this, {name}. Me grandad fought three wars with a pickaxe and this."],
			L["Dwarven make, {name}. Drop it off Thandol Span and it'd still work. Don't."],
			L["Stonewrought Dam holds back a whole loch, {name}. This'll hold ye together."],
			L["Won't keep yer boots dry in the Wetlands, {name}. Nothin' does. The rest, aye."],
			L["Old miner's rule, {name}: never go down a hole without a lamp, a mate and this."],
			L["Brann Bronzebeard went explorin' with less, {name}, and wrote three books."],
			L["Mountaineers swear by it, {name}. Ye'll climb no better, but land softer."],
			L["Ironforge's gates have never fallen, {name}. Neither should ye. Take this."],
			L["Me cousins down Blackrock way would've set it alight first, {name}. Fer luck."],
			L["Off to Uldaman, {name}? Take this, and touch nothin' with runes on it."],
			L["Fer the road, {name}. It's no keg o' Thunderbrew, but it travels better."],
			L["A gift from under the mountain, {name}. Mind yer head on the way out."],
			L["A rifleman needs dry powder and a good mate, {name}. I'm the mate. Here."],
			L["If yer road passes Grim Batol, {name}, keep walkin'. And take this."],
			L["From one explorer to another, {name}. The League'll want yer notes after."],
			L["If ye ride a gryphon, {name}, hold on with yer knees and yer prayers. Here."],
			L["A dwarf never lets a friend walk into the dark unready, {name}. Take this."],
		},
		kin = {
			L["Stone and hammer keep ye, cousin {name}!"],
			L["Three Hammers, one round, and this one's on me, cousin {name}!"],
			L["Yer cousin's cousin wed mine, {name}, I'd wager. Family gets the good stuff."],
			L["Two dwarves, and one of us freshly blessed, {name}. Pity whatever's in our way."],
			L["Bronzebeard, Wildhammer, Dark Iron, Earthen, {name}: one family. Here, cousin."],
			L["Here, {name}. Between the pair of us now, we could out-stubborn a mountain."],
			L["Me grandmother'd climb out of her tomb if I did any less fer kin, {name}."],
			L["The Titans carved us from the same rock, {name}, so here's a chip off mine."],
			L["Kin's kin, {name}, far from the mountain or under it. This is how we mind ours."],
		},
		group = {
			L["There, {name}, that'll see ye through. Stand behind me. Aye, I know. Crouch."],
			L["Right, {name}: ye get this, I take the front, and we argue about loot after."],
			L["Here, {name}. If I sing after this, the fight's gone well. Or very badly."],
			L["Dwarves never leave a mate behind, {name}, nor without a blessin'. Nor a keg."],
			L["There, {name}. Beards out! Them without beards, look fierce. This helps."],
			L["Knocked on the nearest rock fer luck, {name}, and put the luck on ye. Solid."],
			L["Here, {name}, from me pack. It's mostly gunpowder in there. And a sandwich."],
			L["That'll hold ye, {name}. Dwarves don't retreat. Our legs aren't built fer it."],
			L["Take this, stay close, {name}. If it goes dark, follow the cursin'. That's me."],
			L["Ye're sorted, {name}. Dwarves always know which way is down. Up's yer problem."],
			L["Here, {name}. Anythin' o' stone, let me talk to it first. Might be a cousin."],
			L["There, {name}, that'll take a knock. If the ceilin' creaks, I'll tell ye."],
			L["There, {name}, some mountain fer ye. I'll hold the line. Mountains don't move."],
			L["That'll stiffen yer ankles, {name}. Troggs go fer ankles. Mine, mostly."],
			L["There, {name}, fer the low beams. Says the only one here who never needs it."],
			L["A hammer, a grudge, a good breakfast, and this fer ye, {name}. We'll be fine."],
			L["Ironforge's carvers never quit halfway, {name}. Nor does a dwarf's blessin'."],
			L["Keep up, {name}! There's a spring in yer step now. Short legs; we never stop."],
		},
		morning = {
			L["Mornin', {name}! Too early for ale. Almost. Have this first."],
			L["Up with the forge fires, {name}! A dwarf's day starts with a hammer and this."],
			L["Early, {name}? Nonsense. The mine's been open two hours. Here."],
			L["Mornin', {name}. Me eyes are still abed, but me hands knew to give ye this."],
			L["Mornin', {name}. Porridge, a pipe and this. The other two are mine."],
			L["The rams had me up at dawn, {name}. Headbutted the door till I came out. Here."],
			L["Mornin', {name}. Ears still ringin' from last night's singin'. Here."],
		},
	},
	human = {
		thanks = {
			L["My thanks, {name}. Let me return the kindness before a bard gets it wrong."],
			L["Kindly done, {name}. Let no one say we forget a friend."],
			L["Thank you, {name}. I'd knight you, but apparently I 'need permission'."],
			L["Repaid on the spot, {name}. In Stormwind that'd take three forms and a stamp."],
			L["Thanks, {name}. Prompter than Stormwind ever paid its stonemasons."],
			L["Much obliged, {name}. Mother said always return a kindness. And the dish."],
			L["Thank you, {name}. In Elwynn, no kindness goes home unanswered."],
			L["You shame me, {name}; I should have thought of it first. Allow me."],
			L["Heartier than Westfall Stew, {name}, and I've wept over that stew. Thank you."],
			L["Thank you, {name}. I'll tell Marshal Dughan. He won't care, but I'll tell him."],
			L["Job's done, {name}! My grandad built half of Stormwind saying that. Thanks."],
			L["Lakeshire will finish its bridge before I forget this, {name}. So, never."],
			L["Kul Tirans say a kindness goes back on the next tide, {name}. There it goes."],
			L["Thank you, {name}. Northshire's brothers would call that the Light at work."],
			L["Not since Mum packed my lunches, {name}, have I felt so looked after. Thanks."],
			L["Into my memoirs, {name}. Chapter nine: 'Everyone Was Lovely'. Thank you."],
			L["I'll toast you at the Pig and Whistle, {name}. Then the pig. Then the whistle."],
			L["Thanks, {name}. My next horse gets your name. He'll be a very good horse."],
			L["I owe you a pint at the Lion's Pride, {name}. This will tide you over."],
			L["Much obliged, {name}. In Elwynn that's neighbourly. Out here, it's heroic."],
			L["Thanks, {name}. We humans don't live long enough to leave a kindness waiting."],
			L["Thanks, {name}. If the Stockade held folk for kindness, you'd be in for life."],
			L["By the Light, {name}, that was good of you. Uther would have liked you."],
			L["Darkshire could use folk like you, {name}. Your kindness, returned."],
		},
		asked = {
			L["Of course, {name}. Hold still and look heroic; it helps the bards."],
			L["Right away, {name}. Keep your shield high."],
			L["More work? Gladly, {name}. It beats the lumber mill."],
			L["Of course, {name}. Humans excel at helping and overpromising. This is helping."],
			L["Certainly, {name}. Westfall farm manners: you help first and ask why later."],
			L["Hold still, {name}, like a statue in the Valley of Heroes. You'd fit right in."],
			L["Right away, {name}. The Light helps those who ask. So do I, and I'm quicker."],
			L["Sailors' rule, {name}: somebody calls for help, you row. Here."],
			L["Of course, {name}. Stand up straight; my old sergeant is watching, somewhere."],
			L["Of course, {name}. A polite request is rarer than a quiet night in Duskwood."],
			L["Right away, {name}. I'll play the Archbishop; you pretend to be impressed."],
			L["Stormwind rose from rubble, {name}. I can manage one {buff}."],
			L["Of course, {name}. Last one I did was a Westfall scarecrow. Long story."],
			L["Aye, {name}. Kul Tiran terms: a handshake, and I spare you the shanty."],
			L["Right away, {name}. Bolvar says the realm runs on small kindnesses."],
			L["Gladly, {name}. Elwynn folk never turn away a neighbour, armour and all."],
			L["Of course, {name}. The Light provides. Today it's using me as the courier."],
			L["Of course, {name}. Stormwind raised me on the Light, porridge and saying yes."],
			L["Right away, {name}. At Northshire we answered before the second bell."],
		},
		offer = {
			L["The road ahead is long, {name}. This won't shorten it, but it'll help."],
			L["Fair winds and following seas, {name}, and this to carry you along."],
			L["Take this, {name}. Elves have centuries to be generous; I've got fifty years."],
			L["A little something, {name}. Don't tell the guards; they'll all want one."],
			L["Here, {name}. If a kobold asks, you don't have a candle."],
			L["For you, {name}. A human gift: well meant, hastily made, surprisingly sturdy."],
			L["Mind the murlocs, {name}. Take this; I've seen what they do to a picnic."],
			L["Every road needs a hero, {name}. Today it's me, apparently. Take this."],
			L["Stay out of Duskwood after dark, {name}. It's always dark. Take this."],
			L["Redridge gnolls take anything not nailed down, {name}. This is nailed down."],
			L["If you meet Hogger, {name}, take this and a friend. Mostly the friend."],
			L["The Light and a good pair of boots, {name}. Now you've got one of them."],
			L["Every hero in Stormwind began with a kindness and a borrowed sword, {name}."],
			L["Here, {name}. The Defias can't steal this one. They've tried everything else."],
			L["Uther blessed strangers on the road, {name}. I've less hammer, same idea."],
			L["Take this, {name}. Goldshire custom: no traveller leaves empty-handed."],
			L["The wolves in Elwynn look friendly, {name}. They are not. Take this."],
			L["Lothar held the line with less, {name}. Granted, he had a very big sword."],
			L["Westfall farmers share even in a bad year, {name}. So here's my share."],
			L["Redridge, Duskwood, Westfall, {name}: worse roads every mile. Take this."],
			L["Take this, {name}. The guards can't be everywhere. Out here, they're nowhere."],
			L["Bound for Hillsbrad, {name}? Southshore's still ours. Barely. Take this."],
			L["Stromgarde still stands, {name}, mostly out of stubbornness. So will you. Here."],
			L["A Stormwind welcome, {name}: a smile, a blessing and the way to the inn."],
			L["The Argent Dawn says the Light is for all who'll carry it, {name}. Carry some."],
		},
		-- Stormwind and Kul Tiras are both this family, and both Arathor's.
		kin = {
			L["Arathor's children stand together, {name}, and share what strength they have."],
			L["A fellow human, {name}! Take this. Then let's found a kingdom before lunch."],
			L["Stormwind or Boralus, {name}, we'll both moan about the weather. This helps."],
			L["Human to human, {name}: everything happens to us, so here's a little help."],
			L["Short lives, long to-do lists, {name}. We humans must help each other along."],
			L["Stormwind stone or Kul Tiran oak, {name}, this will help you outlast them all."],
			L["Humans stick together, {name}, so take this. The rest are taller or furrier."],
			L["We built half the world on bread, stubbornness and favours like this, {name}."],
			L["Don't tell the dwarves, {name}: humans invented the tavern. And this round."],
		},
		group = {
			L["There, {name}. Humans have always won by outnumbering things, and by sharing."],
			L["You're ready, {name}. Stay in formation. We haven't got one, but stay in it."],
			L["Here, {name}. I'll draw up a plan too, and we can all ignore it together."],
			L["Every hero in the songs had friends who did this, {name}. I'll be yours."],
			L["There, {name}. Stormwind taught me to march and to mind who marches with me."],
			L["That should keep us safe, {name}. If not, we regroup at the nearest inn."],
			L["I made us a flag, {name}, and you a blessing. The flag's a hankie on a stick."],
			L["A light of your own, {name}. Humans can't see in the dark, and we hate it."],
			L["That's for your back, {name}; I'll watch it too. The Light has the rest."],
			L["There, {name}. Humans rise to the occasion, and this should stop the tripping."],
			L["Your share, {name}. Do this well; some elf will tell the story for an age."],
			L["Farmers, sailors, bakers, {name}: every army Stormwind raised got one of these."],
			L["Form up, {name}, and take this. One steady line beats a crowd of brave fools."],
			L["We'll make Stormwind proud, {name}. This should keep the town criers kind."],
			L["The Light keeps us, {name}. Here's some for you. I've packed bandages too."],
			L["Take this, {name}. Everyone goes home; I promised somebody's mother. Yours."],
			L["We look like a proper Stormwind patrol now, {name}. Shinier, even."],
			L["Stay sharp, {name}, this'll help. Lordaeron learned: never trust the bread."],
		},
	},
	nightelf = {
		thanks = {
			L["Ishnu-alah, {name}. Returned the same day, which for a kaldorei is rushing."],
			L["Thank you, {name}. Elune smiles on the generous."],
			L["Thank you, {name}. Even the wisps glow brighter, and they're hard to impress."],
			L["Elune saw that, {name}. She sees everything, so I had best return it."],
			L["Thank you, {name}. Kindness planted, kindness grown. Here."],
			L["Thank you, {name}. The Ancients will hear of this. They're dreadful gossips."],
			L["Thank you, {name}. I'll tell the Sentinels to stop aiming at you."],
			L["My people never hurry, {name}. For you, an exception."],
			L["Ande'thoras-ethil, {name}. May your troubles be diminished, as mine just were."],
			L["We gave up immortality at Hyjal, {name}. Kindness has been worth double since."],
			L["Thank you, {name}. My ears went a shade darker. Kaldorei blush there first."],
			L["Azshara's court never gave a thing away, {name}. You've outdone a queen."],
			L["The owls turned their heads for that, {name}. All the way round. High praise."],
			L["I outlived the Sundering, {name}. I'll not outlive a debt to you. Here."],
			L["All those centuries of memories, {name}, and this one goes near the front."],
			L["I'll tell the moon about you tonight, {name}. She likes a good story."],
			L["In Darnassus they'd sing of that, {name}. Quietly, for about a century."],
			L["Thank you, {name}. A Sentinel settles a debt of honour by moonset. So do I."],
			L["Shan'do Stormrage would approve, {name}. He'll tell you himself, when he wakes."],
			L["The Cenarion Circle preaches balance, {name}. You've just tipped it my way."],
			L["Better than a moonwell, {name}. Don't tell the priestesses I said so."],
			L["Even Fandral would smile at that, {name}, and his face has forgotten how."],
			L["Thank you, {name}. I'd send a hippogryph with my thanks, but they bite."],
			L["That warms me like moonlight, {name}. Not very warm, I admit. Still, thank you."],
		},
		asked = {
			L["Gladly, {name}. Be still, and let the moonlight find you."],
			L["Of course, {name}. Elune's blessings are meant to be shared."],
			L["At last, {name}! I've waited ten thousand years for someone to ask."],
			L["No riddle, no omen from Elune, {name}. Just a plain yes, for once."],
			L["Of course, {name}. Ask in Darnassian next time and I'll add a bow."],
			L["Elune already said yes, {name}. I'm merely catching up."],
			L["Of course, {name}. Stand still and pretend you're a tree. It helps."],
			L["Step into the light, {name}. The last kaldorei I did this for Shadowmelded."],
			L["Certainly, {name}. Ask a kaldorei anything, except how old we are."],
			L["In Darnassus, {name}, this takes a moonwell and a priestess. Out here, just me."],
			L["The last army to ask me for help was fighting demons, {name}. You're politer."],
			L["Gladly, {name}. Consider it on loan from Elune. She's never once collected."],
			L["Of course, {name}. One moment; my hair is older than kingdoms, and it tangles."],
			L["Darnassian has nine words for 'yes', {name}. I'll spare you eight of them."],
			L["Of course, {name}. The Sentinels would want a password. I'll accept 'please'."],
			L["Of course, {name}. I'll be swift. Swift for a kaldorei, that is. Do sit down."],
			L["Gladly, {name}. The Sentinels taught me to answer a call before it echoes."],
			L["Be still, {name}. What's done in haste is undone by nightfall, the druids say."],
			L["Gladly, {name}. Elune asks little of us: kindness, patience and good aim."],
			L["Of course, {name}. The forest gave me plenty. It would sulk if I didn't share."],
		},
		offer = {
			L["Elune-adore, {name}. Her light goes with you. Walk softly; trees sleep lightly."],
			L["May the forest shelter you, {name}, wherever you roam."],
			L["A gift from the shadows, {name}. No, don't look. You won't find me."],
			L["Elune lights your path, {name}. I'm merely holding the lantern."],
			L["The owls pointed you out, {name}. They have strong opinions. Here."],
			L["Tyrande would insist, {name}, and nobody argues with Tyrande."],
			L["Take this, {name}. The last one went to a hippogryph. It was less grateful."],
			L["Take this, {name}. Half the wildlife's a druid, and all of it is watching."],
			L["Walk with Elune, {name}. If she's busy, walk with this."],
			L["A ward against satyrs, {name}. Once Highborne; you can tell by the sneer."],
			L["The trees spoke well of you, {name}. I thought I'd add my blessing."],
			L["Most furbolgs are friendly, {name}. This is for the other ones."],
			L["Moonwell water would be better, {name}, but it travels badly. This doesn't."],
			L["A gift from Teldrassil, {name}. It's a long way down; I nearly dropped it."],
			L["I'd stay to chat, {name}, but kaldorei chats run to the next full moon. Here."],
			L["Bandu thoribas, {name}: prepare to fight. There. Now you're prepared."],
			L["From the kaldorei, the moon and a very old tree, {name}. Mostly from me."],
			L["Ashenvale remembers every axe, {name}. Carry this, and leave yours sheathed."],
			L["With this, {name}, the Sentinels will know you're a friend. Probably. Wave."],
			L["May the moon guide you, {name}, and this keep you until it rises."],
			L["Moonglade welcomes all who come in peace, {name}. So does this."],
			L["Darkshore is beautiful, {name}, and full of things that bite. Take this."],
			L["My people learned the hard way not to hoard magic, {name}. So, here."],
			L["Felwood was a forest once, {name}. Take this; stay well where it didn't."],
			L["Bound for Stonetalon, {name}? Take this. Mind the goblins' saws; the trees do."],
			L["Take this, {name}. If you meet an Ancient, bow. They notice, and never forget."],
		},
		kin = {
			L["Ishnu-alah, {name}. Elune keeps her children close, and so do I."],
			L["Of course I saw you, {name}. It takes a kaldorei to spot one in need of this."],
			L["Kaldorei to kaldorei, {name}: we gave up eternity, not each other. Take this."],
			L["A kaldorei never leaves kin in the dark, {name}. Unless it's for cover."],
			L["Two kaldorei, {name}, and no helmet fits either pair of ears. This does."],
			L["Sentinel, druid or simply stubborn, {name}? This suits all three."],
			L["Twenty thousand years of 'we tried that', {name}. This, though, always works."],
			L["There, {name}. Now let's Shadowmeld together sometime and see who notices."],
			L["Our shan'do sleeps in the Dream, {name}. I'll mind you for him until he wakes."],
			L["Our people are few, {name}, so each of us gets looked after. Here."],
		},
		group = {
			L["Quick one, {name}? Take this now. By kaldorei reckoning we're already done."],
			L["That's from the one you can't see, {name}. Not a mistake; that's the plan."],
			L["Elune watches the whole party, {name}. I just pass her light along."],
			L["Ten thousand years of companions, {name}. You lot rank high enough for this."],
			L["Here, {name}. We misplaced half a continent once. I'm not misplacing you."],
			L["Take this, {name}. If I fall, I'll float about as a wisp, looking wise."],
			L["I fought beside Neltharion once, {name}. He never got this from me. You do."],
			L["Take this and follow me, {name}. I know these paths. They were a forest, mind."],
			L["Here, {name}. With this, we shan't fail. If we do, I'll remember you for ages."],
			L["Heroes charge in blind for millennia, {name}. Take this; let's try eyes open."],
			L["That'll keep you till dawn, {name}. I'll take first watch. And second."],
			L["Here, quietly, {name}. Keep your voices low; the forest listens, and remembers."],
			L["We held the Legion with fewer, {name}, and less help than this. We'll be fine."],
			L["A Sentinel never looses an arrow she'd want back, {name}, nor a blessing."],
			L["Dark in there, {name}? Take this and follow me. The night is where we live."],
			L["Moving out, {name}, blessed and silent as owls. Or as dwarves, if we can't."],
			L["Take this, {name}. I watch the shadows; nothing moves in them without my say."],
		},
		night = {
			L["The moon's up, {name}; here's her blessing. For a kaldorei, it's mid-morning."],
			L["Everyone sensible is asleep, {name}, so Elune's light is all yours tonight."],
			L["Elune's light is on you, {name}. Here's a second layer."],
			L["Dark at last, {name}. Now I see perfectly, and you get this before I see more."],
			L["Same stars as ten thousand years ago, {name}. Same blessing. Both aged well."],
			L["Moonrise, {name}. Every kaldorei just woke up a little. Here's my share of it."],
		},
		morning = {
			L["Morning, {name}. My people slept through these; this will help us both adapt."],
			L["Dawn, {name}. Elune's gone to bed, so I'm covering for her."],
			L["The sun's up, {name}, and so, reluctantly, am I. Have this while I wake."],
			L["Too bright, {name}. I'll squint through this one; Elune forgives squinting."],
			L["Daybreak, {name}: the one hour a night elf is easy to spot. Quick, take this."],
			L["Up early, {name}? I'm up late. Let's meet in the middle, with this."],
		},
	},
	voidelf = {
		thanks = {
			L["The shadows remember kindness, {name}. So do I."],
			L["My thanks, {name}. The ren'dorei do not forget a kindness."],
			L["Thank you, {name}. The voices approve of you, which is frankly alarming."],
			L["Thank you, {name}. Few give gifts to someone who glows this ominously."],
			L["Kindness is rare in the Void, {name}. I'll return yours before it notices."],
			L["Silvermoon threw us out, {name}. Kindness like yours deserves returning."],
			L["Returned in full, {name}. It may be slightly purple. That's normal."],
			L["The Void only takes, {name}. I, however, give back."],
			L["Thank you, {name}. The whispers went quiet. That's how I know it was sincere."],
			L["Thank you, {name}. I'd smile, but people say it's unsettling. So: imagine one."],
			L["Returned, {name}: cold hands, warm intentions. That's us in a sentence."],
			L["Returned, {name}. You may hear it twice; my spells echo now."],
			L["The Void offered me forbidden knowledge, {name}. Yours was the nicer gift."],
			L["Alleria says the Void can be mastered, {name}. Kindness, I find, is easier."],
			L["Much obliged, {name}. Most people give us a wide berth. You gave me this."],
			L["Thank you, {name}. My shadow bowed as well. It never does. You've impressed it."],
		},
		asked = {
			L["As you wish, {name}. The shadows answer kindly today."],
			L["Consider it done, {name}. The Void obeys us, not the other way round."],
			L["Certainly, {name}. The whispers said no, so it's an easy yes."],
			L["Of course, {name}. One {buff}, lightly seasoned with the Void."],
			L["Of course, {name}. Hold still; the shadows are shy with strangers."],
			L["Gladly, {name}. Ren'dorei manners: the Void waits its turn."],
			L["Asked so nicely, {name}? Then you'll have my best."],
			L["Of course, {name}. Stand in the light, please; the Void gets ideas in corners."],
			L["Of course, {name}. The Void asked why. I said 'manners'. It's still puzzled."],
			L["Gladly, {name}. Nobody asks us for anything but 'please stop whispering'."],
			L["Happy to, {name}. Just let me finish arguing with myself. There. I won."],
			L["Certainly, {name}. I could rift over there first, but that feels showy."],
			L["Asking questions got us exiled, {name}. Answering one is quite safe, I'm told."],
			L["Of course, {name}. A slight chill and a faint chorus are both perfectly normal."],
		},
		offer = {
			L["A touch of shadow for you, {name}. Quite safe. Mostly."],
			L["Walk carefully in the dark places, {name}. This will light a little of them."],
			L["A little something from the Telogrus Rift, {name}. It's cleaner than it sounds."],
			L["Take this, {name}. Any tentacles you see are purely decorative."],
			L["The shadows asked after you, {name}. Take this; they can mind their manners."],
			L["Here, {name}. We walked into the Void so you wouldn't have to."],
			L["I checked your shadow, {name}. Nothing lurking. Take this anyway."],
			L["Umbric sends his regards, {name}, and this. He doesn't, but he would."],
			L["Take this, {name}. It may whisper a compliment. Pretend you didn't hear."],
			L["Here, {name}. Looks sinister, works beautifully. Rather like me."],
			L["Take this, {name}. The Void had worse in mind for you. I intercepted."],
			L["If the dark whispers at you today, {name}, pay it no mind. Take this."],
			L["Here, {name}. We ren'dorei don't often get to be the nice surprise."],
			L["I left Quel'Thalas with only a knack for the dark, {name}. Here's the knack."],
			L["Here, {name}. Don't thank the shadows; they'll only want something. Thank me."],
			L["I owe a kindness for every ominous look I've given, {name}. I'm badly behind."],
		},
		kin = {
			L["We ren'dorei look after our own, {name}."],
			L["Silvermoon's loss, {name}. Here: we look after our own splendidly without it."],
			L["Your whispers and mine should meet sometime, {name}. Here's a start."],
			L["Two ren'dorei, {name}. Take this; then look brooding. It's expected."],
			L["Nobody else understands the hair, {name}. Here, from one of the few who do."],
			L["Telogrus felt like home in the end, {name}. Draughty, dark. This will warm you."],
			L["Ren'dorei to ren'dorei, {name}: mine whispered to give you this. Yours?"],
		},
		group = {
			L["Stay close, {name}, and take this. The whispers are much quieter in company."],
			L["There, {name}. If the shadows start giving orders, ignore them. I usually do."],
			L["Here, {name}. Keep an eye on my shadow. It wanders off when there's a fight."],
			L["That glow is my gift to you, {name}. If I start glowing purple too, I'm keen."],
			L["Ren'dorei make fine companions, {name}. We bring our own dark, and gifts."],
			L["Here, {name}. If I talk to nobody, I'm fine. If nobody talks back, worry."],
			L["Yours, {name}. If it goes wrong I'll open a rift. Only for me, but I'll wave."],
			L["Enjoy this little gift, {name}. Ren'dorei rarely get invited anywhere twice."],
			L["Take this, {name}. Keep the lanterns lit; not for me, but the shadows behave."],
			L["Here, {name}. Watch the corners; I'll keep an eye on what's in them."],
			L["The Void gave me power, {name}. It never said I'd have friends to share it."],
			L["For you, {name}. If you hear whispers mid-fight, they're cheering. For us."],
			L["Take this, {name}. Anything eldritch turns up, I'll talk. I speak a little."],
		},
		night = {
			L["Night suits the ren'dorei, {name}. We match the decor. Here's a little of it."],
			L["The shadows are longest now, {name}, and in a very generous mood."],
			L["Late, {name}? The whispers love a late hour, and asked me to give you this."],
			L["Midnight, {name}. My shadow and I agree on one thing tonight: you get this."],
			L["Stars out, {name}. I've seen what's between them. This keeps that away."],
		},
	},
	gnome = {
		thanks = {
			L["Thanks, {name}! Kindness received, catalogued and returned!"],
			L["Reciprocity engaged! Much obliged, {name}."],
			L["By my calculations, {name}, you're owed exactly one {buff}."],
			L["Thanks, {name}! I'd build you a thank-you machine, but it'd explode."],
			L["Thank you, {name}! Gnomeregan's finest couldn't have timed that better."],
			L["You're too kind, {name}! Returning the favour took only four schematics."],
			L["Drat, {name}! I was going to invent gratitude, but you beat me to it."],
			L["Oh, {name}, how kind! My heart's doing that whirring thing again."],
			L["Noted in my lab journal, {name}, page four hundred: 'people are lovely'."],
			L["Splendid, {name}! Returning it at once, before I'm tempted to improve it."],
			L["Thanks, {name}! Kindness is a reversible reaction. I checked. Here's yours."],
			L["My mechanostrider would salute you, {name}, but it only knows falling over."],
			L["My transporter would've sent this to Gadgetzan, {name}. Hand-delivered instead!"],
			L["Oh, thank you, {name}! I haven't felt this good since before the troggs."],
			L["I'll name my next invention after you, {name}! It's a very small cannon."],
			L["Thanks, {name}! Ironforge has been good to us gnomes, and so have you."],
			L["Thanks, {name}! You're on my list of favourites. It's short. Mostly clockwork."],
			L["Thanks, {name}! A gift with no gears in it. I didn't know they made those."],
			L["Thank you, {name}! I'd pay you back with interest, but my abacus is in pieces."],
			L["Paid back, {name}! In Gnomeregan, you'll get a window seat. We'll add windows."],
			L["Exactly what I needed, {name}, and I didn't even have to build it. Thanks!"],
			L["The tall folk rarely notice us gnomes, {name}. You did. Thank you!"],
			L["Thanks, {name}! Tinker Town will hear all about it. Loudly, over the machinery."],
			L["It worked first time, {name}! Nothing I make works first time. Marvellous!"],
		},
		asked = {
			L["Request received, {name}! Processing... done!"],
			L["One upgrade, coming right up, {name}! Stand still for calibration."],
			L["Of course, {name}! I built a machine for this. It's in pieces, so: by hand."],
			L["Certainly, {name}! Stand on the X. There's no X. Stand anywhere."],
			L["Right away, {name}! Goggles on. Not for you, I just like them."],
			L["{buff}, {name}? Simple in theory and practice. Suspicious!"],
			L["Happy to, {name}! Keep hands, feet and eyebrows well clear."],
			L["Right away, {name}! Stand back three paces. Four. Five. There, perfect."],
			L["Happy to, {name}! It beats sorting springs by size. Though that's fun too."],
			L["Excellent request, {name}! No moving parts. I'll try to add some next time."],
			L["Standard model or deluxe, {name}? They're the same. Deluxe sounds nicer."],
			L["Coming up, {name}! Fresh off the workbench, still warm, only slightly smoking."],
			L["Approved, {name}! Stamped, signed and filed under 'obviously'."],
			L["Of course, {name}! A twist of the gyromatic micro-adjustor... there!"],
			L["Gnomes never refuse a problem, {name}. Occasionally we cause them. Here!"],
			L["Right away, {name}! Tested on three volunteers and one very brave squirrel."],
			L["Happy to, {name}! Measure twice, zap once. Gnome proverb. Well, my proverb."],
			L["Of course, {name}! The High Tinker says help where you can. I can, so here!"],
			L["On it, {name}! I'll need a ladder. No? Just this, then."],
			L["Delighted, {name}! It's nice to fix something that doesn't fight back."],
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
			L["Field notes say it works on everyone, {name}. Let's make it unanimous!"],
			L["One size fits all, {name}, gnome to tauren. I measured. The tauren was patient."],
			L["Take this, {name}! Unlike my Net-o-Matic, it never lands on me."],
			L["The Gnomish Army Knife does twelve things badly, {name}. This does one well."],
			L["Guarantee void if exposed to troggs, dragonfire or enthusiasm, {name}. Enjoy!"],
			L["Nothing up my sleeves, {name}! Well, a spanner and two fuses. Nothing sinister."],
			L["Here, {name}! It's small, but so is a keystone, and look what those hold up."],
			L["I'd explain how it works, {name}, but that takes three days and a chalkboard."],
			L["That hum's my gift settling, {name}. If you hear ticking, it's my pocket watch."],
			L["A dash of arcane, a pinch of science, {name}, and no troggs involved. Here!"],
			L["Ironforge took us gnomes in when we needed it, {name}. I'm passing it along."],
			L["Here, {name}! It doesn't whistle, spin or catch fire. I'm working on all three."],
			L["Here, {name}! Unwrapped, sorry. The wrapping machine wrapped itself again."],
			L["My mechanostrider wanted to give you something, {name}. It lacks the hands."],
			L["Off on an adventure, {name}? Take this, and bring me back anything that ticks."],
			L["Reliable as the Deeprun Tram, {name}. That's a compliment, I promise. Here!"],
			L["For you, {name}! One part magic to two parts confidence. Mostly confidence."],
		},
		kin = {
			L["For Gnomeregan, {name}! Here, eye to eye. Always nice to give at eye level."],
			L["Fellow gnome, {name}! A boost for you. I'll hold the schematic, you the bucket."],
			L["Flesh or cogs, {name}, we're all gnomes. Some need oiling. This is oil."],
			L["Gnome to gnome, {name}: here's a boost. You did turn the reactor off, yes?"],
			L["Two gnomes, {name}! With this boost and you on my shoulders, we're a night elf."],
			L["I checked my sums on this, {name}. You check yours; we're both offended."],
			L["That one's free, {name}. You still owe me a sprocket. Every gnome does."],
			L["Here, {name}. One day we'll walk back into Gnomeregan together, lights on."],
			L["Between gnomes, {name}: this one won't explode. I checked. Twice. Mostly."],
			L["A start, {name}. Shall we build something huge, to see the tall folk's faces?"],
		},
		group = {
			L["Party-wide calibration complete, {name}! Nobody touch anything shiny."],
			L["I've run the numbers, {name}: with this on you, we win. I rounded up."],
			L["There, {name}. If I shout 'duck', don't look for a duck. Last time went badly."],
			L["There, {name}. Formation: tall folk at the front, me somewhere safe and clever."],
			L["Everyone gets one, {name}! Standardised parts are the secret of a good machine."],
			L["My plan, {name}: step one, give you this. Step two is still in development."],
			L["Don't panic, {name}. That's my gadget for any mishap. Version two next week."],
			L["Here, {name}. If I vanish, check under the nearest boot. Politely, please."],
			L["Yours, {name}. When this is over, I want samples. Of everything. Big one first."],
			L["On purpose, {name}. Like every explosion today. I'll decide which ones later."],
			L["Clipboard ready, {name}! First entry: gave you this. Then everyone's heroics."],
			L["There, {name}. If we get separated, follow the smoke. It'll be me."],
			L["Here, {name}. Everyone keep their fingers. I've counted. I'll recount after."],
			L["Ready, {name}? Spare gears, spare fuses, and now a spare boost for you."],
			L["Take this, {name}, and leave the traps to me. I built most of them. Not these."],
			L["Here, {name}, before we go in. Anyone seen my wrench? It's mildly important."],
			L["For Gnomeregan, {name}! And for you, here. And for everywhere else, too."],
			L["Take this, {name}. If I'm carried off, retrieve my notes first. Then me."],
			L["An experiment, {name}. Hypothesis: with this on you, we win. Let's test it."],
		},
		morning = {
			L["Morning, {name}! Up since three. The toaster needed an engine; you needed this."],
			L["Good morning, {name}! The coffee brews itself now, so I had time for this."],
			L["Early start, {name}! Best ideas come before breakfast. This was one of them."],
			L["Morning, {name}! Tinker Town's been clanking since dawn, and so have I. Here!"],
			L["Up early, {name}? I dreamt of a better sprocket and couldn't wait. Here!"],
			L["Morning, {name}! The sun's a bit dim today, so I made you a brighter one."],
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
			L["Thank you, {name}. My people call that a debt of honour. Here."],
			L["Sargeras once offered my people gifts, {name}. We ran. Yours, I'll keep."],
			L["Thank you, {name}. I've fled demons across the stars, but never from a debt."],
			L["Thank you, {name}. I'll add you to my prayers. The list goes back to Argus."],
			L["The Legion took a world from us, {name}. Folk like you keep giving bits back."],
			L["You gave first, {name}. A prophet would call it an omen. I call it manners."],
			L["With the Light's compliments, {name}. It asked me to add 'nicely done'."],
		},
		asked = {
			L["Of course, {name}. The naaru guide your steps; this puts a spring in them."],
			L["Gladly, {name}. The Light answers those who ask."],
			L["Velen foresaw you asking, {name}. I foresaw saying yes."],
			L["The Light is not rationed, {name}. Take as much as you like."],
			L["Of course, {name}. I've outrun the Burning Legion; I can manage this."],
			L["At once, {name}. Hooves planted, crystals humming, here it comes."],
			L["Gladly, {name}. I followed a talking crystal across the stars. This is easy."],
			L["Certainly, {name}. Velen taught us patience. Luckily, this takes none."],
			L["Gladly, {name}. The naaru never say no. They say 'hmmm', but it means yes."],
			L["On the Exodar this took three crystals and a prayer, {name}. Here: the prayer."],
			L["Of course, {name}. I only refuse demons, and they so rarely say please."],
			L["Gladly, {name}. We were refugees long enough to know what asking costs."],
			L["Of course, {name}. My people crossed the stars looking for friends. Found one."],
			L["Ask a draenei, {name}: one yes, one blessing, possibly a history lesson."],
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
			L["Here, {name}. We draenei pack for the end of the world. We've had the practice."],
			L["Take this, {name}. The crystals only hum like that for friends."],
			L["The naaru shine on all, {name}. Here is your share."],
			L["A stranger shared bread with me on Azuremyst, {name}. I'm still paying it back."],
			L["Velen sees a thousand futures, {name}. I see one: you, better prepared. Here."],
			L["Don't drink from the streams on Bloodmyst, {name}. Do take this."],
			L["Eredar magic from before the fall, {name}. We only kept the good kind. Here."],
		},
		kin = {
			L["Archenon poros, {name}! The children of Argus look after one another."],
			L["Home is where two draenei meet, {name}. Today it's here; this is my welcome."],
			L["We crossed the stars together, {name}. Sharing the Light still means something."],
			L["Tails up, {name}; take this. Argus would be proud of what we made of exile."],
			L["Two draenei, {name}: fifty thousand years of worry. This should ease yours."],
			L["Horns, hooves, hope, {name}, and this. The Legion found no cure for any of it."],
			L["Children of Velen, {name}: exiled, hopeful and dreadfully polite. Hence this."],
			L["Third world's the charm, {name}. Take this; we're owed one that stays put."],
		},
		group = {
			L["There, {name}. I lost a world once; I'm keeping hold of this party."],
			L["Millennia on the run, {name}. Sharing the Light with friends is nicer."],
			L["The naaru would call sharing Light a fellowship, {name}. I call it good luck."],
			L["I've watched worlds end, {name}. With this on you, nothing ahead worries me."],
			L["Stay together, {name}. The Light finds us easier that way; I just proved it."],
			L["Take this; stay close, {name}. We draenei are very good at leaving in a hurry."],
			L["Draenei take the long view, {name}. This fight's a footnote. This gift isn't."],
			L["Here, {name}. Now I go first; anything watching sees a very tall optimist."],
			L["We draenei follow prophets, {name}. Today I'll follow you, blessed as you are."],
			L["The Exodar carried thousands, {name}. I'd rather carry this little party. Here."],
			L["Shoulder to shoulder, blessed, {name}. Mine's higher, but the principle holds."],
			L["A short prayer for the party, {name}. The long one would take an age."],
		},
	},
	worgen = {
		thanks = {
			L["Much obliged, {name}. Gilneas never forgets a kindness, and nor does my nose."],
			L["Thank you, {name}. You have my gratitude, and my best howl."],
			L["Thank you, {name}. If worgen had tails, mine would be wagging."],
			L["You've made a friend for life, {name}. Loyalty is rather our thing."],
			L["The beast in me wants to growl, {name}. The Gilnean in me insists on thanks."],
			L["Thank you, {name}. I'd offer a hand, but mine have claws now."],
			L["We walled ourselves off for years, {name}. You make that look silly."],
			L["Obliged, {name}. You've earned a spot by the fire. The good spot."],
			L["Thank you, {name}. Gilneas had a word for folk like you: neighbour."],
			L["Returned, {name}, with a stiff upper lip. The lower one shows teeth; ignore it."],
			L["Thank you, {name}. I'd tip my hat, but it doesn't fit over the ears these days."],
			L["Thank you, {name}. Most folk just scratch my ears and hope for the best."],
			L["Returned, {name}. A Gilnean pays debts; a worgen pays them at a sprint."],
			L["My mother would have had you round for tea, {name}. Thank you."],
		},
		asked = {
			L["Certainly, {name}. Hold still, I don't bite. Much."],
			L["Right you are, {name}. Stand steady now."],
			L["Right away, {name}. Stay, now. I've always wanted to say that."],
			L["Gladly, {name}. Rain or shine, and in Gilneas it's rain."],
			L["Certainly, {name}. Mind the claws."],
			L["Say no more, {name}. These ears heard you before you'd decided to ask."],
			L["Of course, {name}. You asked nicer than the last fellow who threw me a stick."],
			L["Glad to, {name}. Few people ask a seven-foot wolf for favours. I love it."],
			L["Certainly, {name}. I'll stay in this form. The other one causes a scene."],
			L["Straight to business without tea, {name}? How un-Gilnean."],
			L["Of course, {name}. In Gilneas, nobody had to ask twice."],
			L["Of course, {name}. It would be rude to keep you waiting."],
			L["Of course, {name}. Anything but a bath."],
		},
		offer = {
			L["Stay off the moors after dark, {name}. Take this."],
			L["Keep your wits about you, {name}, and this too. Something is always hunting."],
			L["I'd have brought this sooner, {name}, but I stopped to chase something."],
			L["For you, {name}. No, I don't want a treat. Well. Perhaps a small one."],
			L["Gilneans always offer, {name}. The claws are just part of the outfit."],
			L["An old Gilnean remedy, {name}. Good for colds, gloom and most curses. Not mine."],
			L["Run with this, {name}. Trust me, I know about running."],
			L["Brought you this, {name}. Don't make a fuss over it."],
			L["Here, {name}. Gilnean roads were never safe alone, and nor are these."],
			L["For you, {name}. Not everything that prowls was as well raised as I was."],
			L["From a Gilnean of good family, {name}. The fur is new; the manners are old."],
			L["Someone did this for me in Duskhaven once, {name}. I never forgot."],
			L["Liam would have cried 'For Gilneas!', {name}. I'll just say: for you."],
			L["Tal'doren's druids taught me to leash the beast, {name}. It lets me do this."],
			L["Take this, {name}, and be careful out there. Advice from someone bitten once."],
			L["Here, {name}. In Gilneas we'd have sent it with a jar of preserves."],
			L["Take this, {name}. I'd offer my coat, but it's attached."],
			L["Here, {name}. Chin up, hackles down. Words to live by."],
		},
		kin = {
			L["The curse binds us, {name}; Gilneas binds us tighter. Here, from one of yours."],
			L["No need to explain the ears to you, {name}, nor to thank me for this."],
			L["Fur, fog, rain, {name}. Only a Gilnean knows all three. This helps with them."],
			L["Pack looks after pack, {name}. Always has."],
			L["Shed this badly too, {name}? Take this; I'll knit a third worgen with the rest."],
			L["Two worgen, {name}, one blessing. Somewhere, a cat's having a very bad day."],
			L["Here, {name}. Works in either form; I forget which one I left home in."],
			L["Gilnean to Gilnean, {name}: the best-mannered wolves in Azeroth share. Here."],
		},
		group = {
			L["Pack rules, {name}: nobody wanders off, everyone gets one, no talk of fleas."],
			L["A pack again, {name}, someone to look after. I hadn't known how I'd missed it."],
			L["Take this, {name}. I smell trouble first; it's the curse's one perk."],
			L["There, {name}. If I howl, it's a battle cry. Howl back if you like."],
			L["That'll keep you up, {name}. Lead on. I'll trot. Undignified, but quick."],
			L["Here, {name}. If I stare at a wall, something's behind it. Or it's a wall."],
			L["Years on the Greymane Wall, {name}. A line held with you, blessed? A holiday."],
			L["Take this for the mauling, {name}. After, a proper cup of tea."],
			L["Here, {name}, so you mend as quickly as I do. Worgen mend quickly."],
			L["That sees you to the rest, {name}. I'll take first watch; I hear everything."],
			L["Take this, {name}, and stay together. Being a lone wolf is overrated."],
		},
		night = {
			L["Night again, {name}: my best and my worst. Giving you this is the best part."],
			L["Look at that moon, {name}. Gilneas taught us not to trust it. Trust this."],
			L["Gilneas at night was fog and footsteps, {name}. Now the footsteps bring this."],
			L["Curfew in Gilneas was sundown, {name}. Take this; there's a reason it was."],
			L["Something's rustling out there, {name}. Take this; stay close. I'll look."],
			L["Past dark, {name}: ears up, nose working, manners on. Manners means this."],
		},
		morning = {
			L["Morning, {name}. The rug by the fire was warm, but I got up to give you this."],
			L["Smells like rain this morning, {name}. Here's something to keep you dry inside."],
			L["Up already, {name}? I've prowled since first light, waiting to give you this."],
			L["Morning, {name}. Tea, toast, a shave, and this. The shave takes longer now."],
			L["Morning, {name}. The birds woke me, so I woke the birds. You just get this."],
			L["Morning, {name}. The fog's lifting, as it never did in Gilneas. Take this."],
		},
	},
	orc = {
		thanks = {
			L["Throm-ka, {name}! Honour is repaid."],
			L["You give freely, {name}. I return the favour."],
			L["Orcs keep their thanks short, {name}. Thanks."],
			L["Orcs return every blow twice, {name}. The kind ones too."],
			L["You helped me, I help you, {name}. That is the old way."],
			L["In the old days I'd have repaid you with a boar, {name}. This keeps better."],
			L["Owing somebody itches worse than Durotar sand, {name}. There. Itch gone."],
			L["Strong stuff, {name}. I could wrestle a kodo now. So can you."],
			L["Ambushed by kindness, {name}. No orc trains for that. Returned in full."],
			L["Honour is a debt, {name}, and orcs pay on the spot."],
			L["An orc remembers a kindness like a scar, {name}: fondly, and for good."],
			L["I'd give you my axe, {name}, but we're not that close yet. Take this."],
			L["Thanks, {name}. My wolf growled at you. That's how he says it."],
			L["I've had gifts from shamans and chieftains, {name}. None came so freely."],
			L["We once took strength from demons, {name}. Yours comes on far better terms."],
			L["The spirits saw that, {name}. They'll remember it, and so will I."],
			L["I'll carve that on my axe handle, {name}. Next to the notches. Thank you."],
			L["Kindness unasked is rare as rain in Durotar, {name}. Returned."],
			L["In my clan, {name}, a gift is answered with a bigger one. Here."],
			L["A Frostwolf never counts what a friend gives, {name}. Only what he gives back."],
			L["The camps taught us who our friends are, {name}. You're one. Here."],
			L["Thanks, {name}. Thrall says the Horde's strength is its friends. You count."],
			L["Good. Strong. Kind. Three things I respect, {name}. Have this."],
			L["Grom would have roared his thanks, {name}. I'll spare your ears and send this."],
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
			L["Done, {name}. I was a peon once; I never refuse honest work."],
			L["A challenge, {name}? Ah, a request. I accept either way."],
			L["Yes, {name}. I was sharpening my axe, but it'll keep. It always keeps."],
			L["In the Valley of Honor this would cost you a duel, {name}. For you, a nod."],
			L["Now, {name}? Now. Orcs never learned the word 'later'."],
			L["One {buff}, {name}. Orc style: fast, direct, a bit too hard."],
			L["Stand still, {name}. I aim this like a throwing axe, and I rarely miss."],
			L["Lok'tar, {name}. It means 'victory'. Today it also means 'yes'."],
			L["Done, {name}. If you need anything carried, hit or shouted at, ask again."],
			L["You ask straight, {name}. I answer straight. Here."],
			L["The shamans say the spirits help those who stand still, {name}. Stand still."],
			L["A good request, {name}: clear, brave and short. Like a good battle plan."],
			L["Done, {name}. Thrall says help freely. I say help quickly. Both right."],
		},
		offer = {
			L["Lok'tar ogar, {name}! Take this into battle. A tavern brawl also counts."],
			L["Blood and thunder, {name}! Take my strength and go earn your glory."],
			L["Among orcs, {name}, making you stronger is how we say we like you."],
			L["An orc giving gifts unasked? Tell no one, {name}. It ruins the image."],
			L["The Warchief wants us diplomatic, {name}. This is my diplomacy."],
			L["Take this strength, {name}, and hit something for me. Or set it on fire."],
			L["Don't thank me, {name}. Just win, and do it loudly."],
			L["I'd make a speech, {name}, but it's mostly shouting. Just take it."],
			L["An orc at your back, {name}, even when I'm not there. Take this."],
			L["'Strike first,' Grom always said, {name}. So: here, before you could ask."],
			L["Take it, {name}. A grunt who walks past a comrade gets a talking-to. From me."],
			L["Frostwolves share the hunt, {name}. I caught nothing today, so share this."],
			L["Walk the Durotar way, {name}: head up, sun on your neck, my strength in you."],
			L["Here, {name}. The spirits favour the generous."],
			L["Orcs give two things freely, {name}: advice and this. Skip the advice."],
			L["The Barrens don't end, {name}. They just get more zhevra. Take this."],
			L["Strength for your arm, {name}. The honour, I see, you brought yourself."],
			L["My wolf wanted you to have his bone, {name}. I talked him down to this."],
			L["Any grunt in Razor Hill would do the same, {name}. Most would shout first."],
			L["For the fight ahead, {name}. There's always one. Orcs plan for it."],
			L["We were slaves once, {name}. Now we choose whom we help. Today, it's you."],
			L["Go with this, {name}. Let them hear you coming. Or don't. Surprise works too."],
			L["A gift from Durotar, {name}. Like the land: rough, warm and short on shade."],
			L["The elements are fickle, {name}. I am not. Take this."],
			L["Strength, {name}. Not the kind you lift. The kind you keep."],
			L["Nobody crosses the Barrens alone if an orc can help it, {name}. Here."],
		},
		kin = {
			L["Throm-ka, {name}! The blood of the clans runs strong in you. Stronger now."],
			L["An orc, {name}! Here: somebody who shouts at my volume deserves this."],
			L["Frostwolf, Warsong, Blackrock, {name}: we argue like family, and share like it."],
			L["Between orcs no words are needed, {name}. Good; I'm out of them. Take this."],
			L["Grunt or shaman, {name}, the same stubborn blood. Here's more strength for it."],
			L["Two orcs, {name}, and nobody's shouted yet. This the shamans will call an omen."],
			L["Our clans probably feuded once, {name}. Everybody's did. Let this settle it."],
			L["Between orcs, {name}, 'victory or death'. This should tilt it towards victory."],
			L["Your tusks and mine have seen worse days, {name}. With this, today's better."],
		},
		group = {
			L["The plan, {name}: you take this, we hit it. Questions? No? Good plan."],
			L["A true warband, {name}: loud, angry, blessed, and on the same side for once."],
			L["Stay with the warband, {name}. Strength in numbers, in axes, and in this."],
			L["Take this so I needn't carry you out, {name}. I would. Complaining all the way."],
			L["Fight well with this, {name}, and tonight you share our fire. And our boasting."],
			L["That's courage, {name}. Nobody runs now. Walking briskly away is allowed."],
			L["Here, {name}. Now I go first. I have the thickest skull here, and I'm proud."],
			L["When the drums start, {name}, charge with this in you. No drums? I'll hum."],
			L["That's for your front, {name}. Watch my back; the front's what I hit."],
			L["One clan today, {name}: Whoever Showed Up. Its members get one of these."],
			L["Take this, {name}. Anything big through that door is mine. Bigger, ours."],
			L["Scars are stories, {name}. With this, let's all come out with short ones."],
			L["Old chieftains had war councils, {name}. We have me pointing, and this."],
			L["Take this before I charge, {name}. If I charge early, it's tradition."],
			L["Form up, {name}, and take this! Shamans in the middle, fools at the front. Me."],
			L["Tonight we feast, {name}. First we earn it, and this will help."],
			L["Take this, {name}. If I fall, sing about it loudly in Orgrimmar. Lie a little."],
			L["Strength and honour, {name}. The honour's yours; the strength I just gave you."],
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
			L["The last gift I got was the plague, {name}. Yours is a big improvement."],
			L["Sylvanas says we repay every debt, {name}. She rarely means the nice ones."],
			L["Repaid at once, {name}. We Forsaken never carry debts. They rot."],
			L["Thank you, {name}. I'll keep this somewhere safe. My ribcage has room."],
			L["Kindness returned, {name}. Even the flies around me look impressed."],
			L["I'll drink to you tonight, {name}. It all leaks out, but it's the thought."],
			L["Thank you, {name}. You've made my list of reasons to keep going. It's short."],
			L["Thank you, {name}. No contract, no fine print. Varimathras should take notes."],
			L["Grave dirt and gratitude, {name}: all I own. You'll prefer the gratitude."],
			L["I'd have Lordaeron's bells rung for you, {name}, but they only do funerals now."],
			L["Thank you, {name}. Next time I'm in Brill, I'll name a pumpkin after you."],
			L["Most of the living wouldn't have bothered, {name}. I'll resent them, not you."],
			L["Better than anything I've pulled out of Undercity's sewers, {name}. Thanks."],
			L["Thank you, {name}. One tip in return: never drink what an apothecary hands you."],
			L["Thank you, {name}. I'd shake your hand, but I'd like to keep mine attached."],
			L["You've done what the apothecaries never could, {name}: made me feel something."],
			L["A gift for the dead, {name}? Most people bring flowers. Then they run."],
			L["Gratitude, {name}. Freshly exhumed, barely used."],
			L["That tingled, {name}. Either that was you, or something's nesting in me again."],
			L["Bless you too, {name}. Not literally, please; the Light stings. Thank you."],
			L["Thank you, {name}. If anything of mine drops off, keep it. A little souvenir."],
			L["Nicest spell cast on me since Arthas, {name}. Low bar, but you cleared it."],
			L["I'll have the apothecaries name a plague after you, {name}. A small one."],
			L["I'll rest easier now, {name}. Not in peace, mind. Just easier."],
			L["Please don't tell the Dark Lady I was nice to somebody, {name}."],
			L["Here's {buff}, {name}. Fresh, unlike everything else about me."],
			L["Kindness, {name}? I checked it for poison out of habit. It's clean. So is this."],
			L["You've put a spring in my step, {name}. Possibly literally. Something's loose."],
			L["Death took my pulse, my looks and my sense of smell, {name}. Not my manners."],
			L["Thanks, {name}. Somewhere in Brill, a ghoul is jealous of me right now."],
			L["I'd put you in my will, {name}, but it was read years ago."],
			L["That's going on my headstone, {name}. Under the bit that's already there."],
			L["Thank you, {name}. Don't mind the smell. It's not personal, it's posthumous."],
			L["Thank you, {name}. Most people only cast on me to make me lie back down."],
			L["Thank you, {name}. I'll have Mordo stitch that in, so it can't fall out."],
			L["Faranell will want to know how you did that, {name}. Don't tell him. Thank you."],
			L["Kindly done, {name}. I'd offer you a seat, but mine came with a lid."],
			L["Steadier hands than the man who sewed my arm on, {name}. Thank you."],
			L["First time in years I've been improved without a needle, {name}. Thanks."],
			L["Thank you, {name}. If I twitch, don't be alarmed. It means I'm pleased."],
			L["Gratitude, {name}, from what remains of me. Most of it. The important parts."],
			L["You'd make a fine apothecary, {name}. That's the worst I'll ever say of you."],
			L["Tell nobody in Brill about this, {name}. I've a reputation for being dreadful."],
			L["Last one to look after me was a necromancer, {name}. You're much better at it."],
			L["People rarely put anything into a Forsaken, {name}. Usually it's a sword."],
			L["For that, {name}, I'll stop scowling a while. No promises; the face is set."],
			L["I'd write you a note, {name}, but my writing hand's at the stitcher's."],
			L["Deathknell gave me a shovel and a grudge, {name}. You gave me something better."],
			L["A credit to the living, {name}, thanked by the dead. Not fierce competition."],
			L["Into the ledger it goes, {name}. In ink this time, not the other stuff."],
			L["The Dark Lady says nothing is free, {name}. She hasn't met you."],
			L["I feel that in my bones, {name}. Mostly because they show."],
			L["Mother said always repay a kindness, {name}. She's in Brill now. Under it."],
			L["Shadow I shrug off, {name}. Kindness gets right through. Thank you."],
			L["I can't feel much these days, {name}, so I'll take your word it was lovely."],
			L["Nobody's wished me a long life in years, {name}. I've got one anyway. Thanks."],
			L["Cannibalize is for enemies, {name}. Friends get {buff}."],
			L["The will of the Forsaken shrugs off every charm, {name}. Not yours, it seems."],
			L["My jaw's wired on, {name}, so this thank-you smile is a feat of engineering."],
			L["Thanks, {name}. Most of my old life went with the Plague. There's room for you."],
			L["That's put colour in my cheeks, {name}. Grey, mostly, but it's a start."],
			L["I'd send you flowers, {name}, but they wilt when I pick them up."],
			L["The Scourge never once said thank you, {name}. So let me say it properly."],
			L["Kindness to the dead, {name}? The priests in Brill used to charge for that."],
		},
		asked = {
			L["Certainly, {name}. Try not to die. It's overrated."],
			L["You need only ask, {name}. The dead are patient."],
			L["Ask the dead for a favour, {name}. We rarely have other plans."],
			L["Certainly, {name}. Stand clear; I'd hate to drop anything on you."],
			L["A moment, {name}. Rigor mortis is hard on the casting hand."],
			L["Nice to be asked for something, {name}, besides the way to the graveyard."],
			L["Gladly, {name}. It takes my mind off the smell. Mine, I mean."],
			L["Certainly, {name}. Hold still. My aim drifts when my eye does."],
			L["In Undercity nobody says please, {name}. Mostly they gurgle. Here you are."],
			L["Just {buff}, {name}? The apothecaries always want a sample too."],
			L["I always rise when called, {name}. Unfortunate history. Here you are."],
			L["Anything for you, {name}. Within reason, and what's left of mine."],
			L["Of course, {name}. I'd say 'over my dead body', but that's been tried."],
			L["Right away, {name}. The dead don't dawdle. We shamble with purpose."],
			L["Of course, {name}. Free will is a gift. I spend mine on things like this."],
			L["At once, {name}. I've had far worse requests from the Apothecarium."],
			L["Of course, {name}. After a winter in the Plaguelands, this counts as a holiday."],
			L["{buff}, {name}? With the Dark Lady's compliments."],
			L["Of course, {name}. I don't sleep or eat, so I may as well be useful."],
			L["Glad to, {name}. The Scourge used my hands for worse."],
			L["Certainly, {name}. The apothecaries taught me a steady hand. Mostly on rats."],
			L["The Dark Lady said serve the Horde, {name}. She never said sulk about it."],
			L["Right away, {name}. In Deathknell they woke me with far ruder requests."],
			L["Silverpine's worgen never ask this nicely, {name}. You're a pleasant change."],
			L["Of course, {name}. I've nothing on until the end of the world."],
			L["Done, {name}. Quicker than the bat to the Sepulcher, and you keep your lunch."],
			L["You had me at please, {name}. Or at 'oi, corpse'. Either works."],
			L["Why not, {name}? It's that or stand here decomposing."],
			L["Right away, {name}. I've stood here so long the moss had started to hope."],
			L["With pleasure, {name}. Well. With what passes for it now."],
			L["Here, {name}. I won't ask what it's for. The dead are discreet."],
			L["Ask away, {name}. Death made me patient, and Undercity made me bored."],
			L["Done, {name}. Come back when it fades. I'm not going anywhere. Ever."],
			L["Certainly, {name}. Better work than hauling ichor for Faranell."],
			L["Easiest thing I've done all week, {name}, and I dug myself out of a grave."],
			L["Of course, {name}. Eternity's long; I can spare a moment of it."],
			L["Gladly, {name}. Beats standing in the Ruins of Lordaeron looking haunted."],
			L["Ask a Forsaken, get an answer, {name}. Ask an apothecary, get a waiver."],
			L["At your service, {name}. The Lich King never said please. You did."],
		},
		offer = {
			L["Stay among the living a little longer, {name}."],
			L["Take this, {name}. The grave can wait."],
			L["I was a physician in Lordaeron, {name}. Old habits die harder than I did."],
			L["No charge, {name}. The apothecaries would have made you sign something."],
			L["A gift from the grave, {name}. Don't worry, I washed it."],
			L["I've seen where heroes end up, {name}. I live there. Take this."],
			L["Take this, {name}. I learned the hard way you can't take it with you."],
			L["Take this, {name}. It's the only thing I own that isn't slightly damp."],
			L["Hold on to yourself, {name}; this helps. The pieces are hard to find later."],
			L["Take this, {name}. The Plaguelands are full of people who didn't."],
			L["A small kindness, {name}. Tirisfal could use more of them."],
			L["Tirisfal fog gets into everything, {name}. So does this, but pleasantly."],
			L["Here, {name}. Kept cool for you, like everything I carry."],
			L["I've outlived everyone I knew, {name}. I'd rather not outlive you. Take this."],
			L["Pardon me, {name}. I'm told I lurk. I'm trying to lurk helpfully."],
			L["Out of my own pocket, {name}. The dead don't need much."],
			L["I've already had the worst day there is, {name}. Let's spare you yours."],
			L["Wind's off the Plaguelands, {name}. Take this, and breathe through your mouth."],
			L["The crows have been watching you, {name}. Let's disappoint them."],
			L["Here, {name}. Tirisfal grows nothing but pumpkins and grudges. This is neither."],
			L["Take this, {name}. The only thing in Undercity that needn't be boiled first."],
			L["Eternity is long, {name}, and I've spent a fair bit of it practising this."],
			L["For the road, {name}. Undercity-made, so do keep it away from open flame."],
			L["Take this, {name}. It's odourless, which I'm told makes it my best feature."],
			L["Forsaken are famously patient, {name}. I just couldn't wait to give you this."],
			L["No strings attached, {name}. I cut mine when the Lich King lost his grip."],
			L["Fresh from Tirisfal, {name}. Well, fresh for Tirisfal."],
			L["Take this, {name}. The Bulwark taught me to look out for the living."],
			L["Passing Pyrewood, {name}? Take this. The village has a bad habit after dark."],
			L["The Scarlets would call this unholy, {name}. From me, they'd say it of bread."],
			L["Don't flinch, {name}. It's a spell, not a bite."],
			L["Here, {name}. The Royal Apothecary Society had no hand in this one. Promise."],
			L["You look tired, {name}; from me, that's a professional opinion. So: this."],
			L["You looked a bit peaky, {name}. Then again, I'm a poor judge of colour."],
			L["On the house, {name}. The house is a crypt, but it's paid off."],
			L["Take this, {name}. Agamand Mills is full of folk who also had places to be."],
			L["Bound for Tarren Mill, {name}? Take this. The Southshore lot throw things."],
			L["Living's a fragile hobby, {name}. Let's keep you at it."],
			L["Take this, {name}. I'd hate for us to end up neighbours."],
			L["Every life I keep is one the Lich King doesn't get, {name}."],
			L["Take this, {name}. It's what we do instead of sleeping."],
			L["Mind yourself, {name}, and take this. Not all Tirisfal's dead have my manners."],
			L["Stay warm, {name}. One of us ought to, and this should help."],
			L["Take this, {name}. The Deathguard can't watch every road."],
			L["Don't mind me, {name}. Just a passing corpse doing a good turn."],
			L["It's free, {name}. The embalming afterwards is not, so do be careful."],
			L["A Forsaken's gift, {name}: cold, a little grim, and good for you."],
			L["Off to the Scarlet Monastery, {name}? Take this. They'll take the rest."],
			L["Take this, {name}. I'd give you advice, but mine is mostly about digging."],
			L["Don't mind the hand that gave you this, {name}. It's mine. Usually."],
		},
		kin = {
			L["We Forsaken must look after each other, {name}."],
			L["Between us corpses, {name}, you're well preserved. This should keep you so."],
			L["Lose a finger, {name}, and I've a spare. Forsaken share. Today, it's this."],
			L["Is your jaw clicking too, {name}? Here; it won't help that, but it'll help."],
			L["A small victory for Sylvanas, {name}: one of hers, blessed. It's ours."],
			L["Brill or Deathknell, {name}? We all woke up somewhere. Now wake up to this."],
			L["When the Scourge calls, {name}, we won't be home. Or easy to take. Here."],
			L["The Bulwark holds, {name}, and so do we: held together, and held up by this."],
			L["Lordaeron raised us twice, {name}. Let me raise your spirits a third time."],
			L["In Northrend, {name}, the Lich King is sulking about us. This won't help him."],
			L["The Dark Lady needs us whole, {name}. This gets you near enough."],
			L["You smell of Tirisfal, {name}. From us, a compliment. So is this."],
			L["We've forever, {name}. Take this; let's not spend it waiting for the lift."],
			L["Forsaken to Forsaken, {name}: take this. The sewer shortcut is not a shortcut."],
			L["If the Deathguard ask, {name}, I was issuing supplies. This one's yours."],
			L["Our kind don't get many kindnesses, {name}. Let's keep them in the family."],
			L["Same grave dirt, same Dark Lady, {name}. That's family, and family gets this."],
			L["Keep the faith, {name}. In each other, I mean. Here's mine, in you."],
			L["The dead look after the dead, {name}. The living could learn a thing or two."],
			L["We've both seen the inside of a grave, {name}. Dreadful service. Here's better."],
			L["Mordo did your stitches too, {name}? This should help them hold."],
			L["Our time will come, {name}. We've nothing but time, so I'll spend some on you."],
			L["Recall the Lich King's voice, {name}? Mine's kinder, and it gives you this."],
			L["You kept your nose, {name}. Not all of us did. Keep the rest with this."],
			L["We were all Lordaeron once, {name}. Some kept the accent. I kept the manners."],
			L["The living do try, {name}. Be kind to them, as I am to you. Here."],
			L["Still got both eyes, {name}? Show-off. Take this anyway."],
			L["Did you call on your old family too, {name}? Mine took it badly. You get this."],
		},
		group = {
			L["Take this; stay alive, {name}. Undercity's housing list is already very long."],
			L["That's for you, {name}. If I fall down, give it a minute. Old habit."],
			L["Here, {name}. I'll take the front. What's the worst that could happen? Again?"],
			L["There you are, {name}. Now keep upwind of me. It's better for morale."],
			L["Last party I joined, {name}, I woke in a crypt. This is me improving on that."],
			L["Here, {name}. Anything that bites, point it at me. Nothing left worth eating."],
			L["For you; heal the others first, {name}. I run on spite and embalming fluid."],
			L["Take this, {name}. If it goes badly, don't worry. I've died before; it passes."],
			L["Fought the Scourge from both sides, {name}. This side shares its blessings."],
			L["Stay close, {name}; take this. I won't scream at the ghouls. Old neighbours."],
			L["I've walked the Plaguelands at night, {name}. With this, so can you."],
			L["The corpse at the back blessed you, {name}. That's me. Please don't bury it."],
			L["Take this; stay together, {name}. Easier than putting somebody back together."],
			L["Take this; don't wait for me, {name}. I shamble, but forever. I'll catch up."],
			L["Here, {name}. Keep the torches clear of me. I'm old, dry and very flammable."],
			L["That keeps yours going, {name}. Don't check me for a pulse. It worries people."],
			L["Take this, {name}; mind the green puddles. I've seen what they do. I'm it."],
			L["Lordaeron fell with me in it, {name}. With this on you, today won't be worse."],
			L["Take this and stick together, {name}. The apothecaries pay well for strays."],
			L["For you, {name}. If this ends underwater, don't mind me. Breathing's optional."],
			L["The Dark Lady blesses no one, {name}. I've made an exception for this party."],
			L["When we win, {name}, drinks at the Gallows' End in Brill. This one's on me now."],
			L["That's from me, {name}, not the flies. They're with me, though."],
			L["Here, {name}. I'll watch the rear. Nothing sneaks up on one who can't blink."],
			L["Here, {name}. If I lose an arm in there, bring it out. I'm fond of it."],
			L["That's yours, {name}. Leave the bodies to me afterwards. Waste not."],
			L["Take this and send them my way, {name}. I don't bleed. I come apart a little."],
			L["Here, {name}. When they cast fear, look to me. I'll be the one not running."],
			L["Take this, {name}, and mind the abominations. Distant cousins. We don't speak."],
			L["That's for your legs, {name}. If I walk oddly, it's fine. It's a new leg."],
			L["Here; shout if you need more, {name}. My ears are mostly where I left them."],
			L["Take this so we don't wipe, {name}. If we do, I know the spirit healer."],
			L["Don't fret the odds, {name}. Lordaeron's army had better ones. You have this."],
			L["Good party, {name}. Five of us, all blessed, and only one needs embalming."],
			L["There, {name}. Now watch my back. Some of the stitching there is very old."],
			L["Here, {name}. Should I fall, no hurry raising me. I could use the lie-down."],
		},
		night = {
			L["The dead keep terrible hours, {name}. Nice to have someone to give this to."],
			L["Midnight, {name}: the best hour to be up. Have this, and stay up with me."],
			L["The living are all asleep, {name}. We Forsaken call this the quiet shift. Here."],
			L["Late, {name}? In Undercity, this is lunchtime. Have some."],
			L["The Scourge used to walk at this hour, {name}. Now it's ours, and so is this."],
			L["Night, {name}. Nobody can tell I'm pale. Or that I'm kind. Take this."],
			L["Dark as the Undercity, {name}. Proper lighting. Here's a little glow for you."],
			L["Fog, moonlight, mildew, {name}: Tirisfal weather. This keeps the damp out."],
			L["The banshees start singing now, {name}. Take this; they're only practising."],
			L["Stars over Tirisfal, {name}: the one thing up there that never rotted. Here."],
			L["Past midnight, {name}. The graveyards are quiet. Take this; stay out of them."],
			L["An owl saw me and left, {name}. Sensible bird. You stayed, so this is yours."],
			L["Moonlight suits us, {name}. It hides the stitching. This hides the rest."],
			L["Don't stay up for me, {name}. I gave up sleep years ago. Take this and rest."],
			L["Long night, {name}? Mine's been going since the Plague. This helps with yours."],
			L["Night in Tirisfal, {name}. Even the bats keep their voices down. Here, quietly."],
			L["The banshees call this the witching hour, {name}. Here's some witchery."],
		},
		morning = {
			L["Morning, {name}? I've been up all night, and all of last decade. Have this."],
			L["The sun's up, {name}. Take this; I'll stand in the shade. Things peel."],
			L["Early start, {name}. I miss yawning. Have this and do one for me."],
			L["Sunrise, {name}. My least favourite colour. This is my favourite gift."],
			L["Dawn over Tirisfal, {name}: grey, then less grey. This adds a little colour."],
			L["Morning, {name}. The Gallows' End porridge moved again. Have this instead."],
			L["The roosters in Brill still crow, {name}. Nobody's told them. Here's a wake-up."],
			L["Morning, {name}. The Deathguard just turn round to change shifts. I give this."],
			L["Morning, {name}. I don't wake up now; I stop lying down. Then I hand out this."],
			L["Mornings were the worst of being alive, {name}. This should make yours better."],
			L["The early bird gets the worm, {name}. The early Forsaken gets you this."],
			L["Breakfast, {name}? I'll pass; my appetite went with my insides. Have this."],
			L["Up with the sun, {name}? I'm up with everything. Take this while I am."],
		},
		-- Said in Undercity alone (RP.HOME), in place of anybody's lines for a
		-- city, which were written with Stormwind's warm beds in mind.
		city = {
			L["Take this before the lift, {name}. The last man who rushed it is still falling."],
			L["Undercity has it all, {name}: a bank, an inn, and this, free. Mind the sewers."],
			L["Even the rats bow to the Dark Lady here, {name}. Take this before one asks."],
			L["Take this; mind the canal, {name}. It's green for a reason, and it isn't moss."],
			L["Undercity's lovely this time of year, {name}. It's always this time. Here."],
			L["We moved into Lordaeron's cellar, {name}, kept the good silver, and share this."],
			L["The Royal Quarter's that way, {name}. Take this; the banshees keep score."],
			L["The bat handler swears they're friendly, {name}. Take this before you test it."],
			L["Magic Quarter's that way, {name}. Take this; don't drink the glowing puddles."],
			L["The throne room's upstairs, {name}. Nobody sits in it. Take this instead."],
			L["The Apothecarium's that way, {name}. Take this; don't touch, sniff or sign."],
			L["Rogues' Quarter's through there, {name}. Take this; count your fingers after."],
			L["Varimathras stands by the Dark Lady, {name}. Take this; never turn your back."],
			L["The War Quarter's that way, {name}. Here, so you arrive as cheerful as it is."],
			L["Trade Quarter's round the ring, {name}. It's all second-hand. This isn't."],
		},
		-- Lines about how the living take to a Forsaken, which would be nonsense
		-- to another one: RP.Pick adds them to the moment's own pool only for
		-- somebody who is not kin, and never at home, where nearly everybody is.
		outsider = {
			thanks = {
				L["Most folk greet a Forsaken with holy water, {name}. You're a welcome change."],
				L["Few stop for a Forsaken, {name}. You did, and I noticed. Thank you."],
				L["Warm, generous and alive, {name}. I can only match you on one. Here it is."],
				L["You came near enough to cast, {name}. Most of the living won't. Thank you."],
				L["Kind to a Forsaken, {name}? They'll talk about you in Orgrimmar."],
			},
			asked = {
				L["Contrary to rumour, {name}, not everything a Forsaken hands out is a plague."],
				L["Forsaken can't be charmed, {name}, they say. Asking nicely works, though."],
				L["You asked a Forsaken for help, {name}. Somewhere, a paladin just fainted."],
			},
			offer = {
				L["Take this instead of small talk, {name}. Mine tends to unsettle people."],
				L["They say the Forsaken have no friends, {name}. I'm recruiting. Signing gift."],
				L["Take this, {name}. If anyone asks, the Forsaken were perfectly charming."],
				L["Take this; stay alive, {name}. I've tried the alternative. Can't recommend it."],
				L["I don't bite, {name}. I bless. Not the living, usually. You're an exception."],
				L["Yes, {name}, I'm dead. No, it isn't catching. Here."],
			},
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
			L["Thank you, {name}. My grandmother said kindness comes back on the wind."],
			L["Returned faster than a wind rider, {name}, and with much less screeching."],
			L["Returned, {name}. The quilboar never learned to give back, and look at them."],
			L["Thank you, {name}. My ancestors are all nodding. It's a great deal of nodding."],
			L["In Mulgore we return a gift before the grass under it grows back, {name}."],
			L["Thank you, {name}. I'll name my next kodo calf after you. They're lovely."],
			L["Kindness is rarer than shade in the Barrens, {name}. Here's some back."],
			L["I'll carve this on a totem, {name}. Tauren carve slowly; expect it by spring."],
			L["Bloodhoof Village will hear of this at supper, {name}. Thank you."],
			L["Cairne taught us to honour every kindness, {name}, and so I do."],
			L["Thank you, {name}. Hamuul says the land repays those who tend it. So do I."],
			L["In Thunder Bluff we'd beat a drum for that, {name}. Imagine it. Thank you."],
			L["The Earth Mother gives without counting, {name}. You've been listening to her."],
			L["Thank you, {name}. My heart's as full as a kodo after the spring grass."],
			L["The elders on Elder Rise would approve, {name}. Slowly, after a long talk."],
			L["Thank you, {name}. If you pass through Mulgore, ask for me. The big one."],
		},
		asked = {
			L["Of course, {name}. Stand tall and be at peace. I'll handle the tall part."],
			L["Ask and it is given, {name}. The herd shares what it has."],
			L["Of course, {name}. Stand back a pace; I do this with my whole body."],
			L["Gladly, {name}. Mind the tail."],
			L["The Earth Mother gives freely, {name}, and so do her largest children."],
			L["Gladly, {name}. Tauren are slow to anger and quick to help."],
			L["Refuse you, {name}? My ancestors would never let me hear the end of it."],
			L["Of course, {name}. A tauren says yes the way the plains grow grass: easily."],
			L["Of course, {name}. One moment; my hands are big and the spell is small."],
			L["After a season herding kodo, {name}, a polite request is a holiday. Here."],
			L["The Earth Mother says share, {name}. My stomach says lunch. She outranks it."],
			L["Of course, {name}. Stand still as a totem; this won't take long."],
			L["Spirits of the plains, lend me your strength. Here, {name}."],
			L["Magatha would want a favour for it, {name}. Baine would just say yes. So: yes."],
			L["Hold still, {name}. I've practised on kodo, and they're far less polite."],
			L["Of course, {name}. A shu'halo never refuses a traveller. Or a second helping."],
			L["Of course, {name}. The plains taught me patience; the kodo taught me to share."],
			L["Gladly, {name}. Ancestors, steady my hand. Not my hooves; they're fine."],
			L["Always, {name}. Cairne never refuses a friend, and he's taller than me."],
			L["Ask anything, {name}. A tauren has strength to spare and time to listen."],
		},
		offer = {
			L["Take this, {name}, and walk with the Earth Mother. You can't get lost."],
			L["May An'she light your path, {name}, and this go with you."],
			L["You looked like you could use a friend, {name}. I'm a very big one."],
			L["Take this, {name}. The Earth Mother would scold me if I walked past."],
			L["Tread lightly, {name}, and take this. From someone who never has."],
			L["The wind said you'd pass, {name}, so I had this ready. Terrible gossip."],
			L["Take this, {name}. I'd lend you my kodo too, but he's less generous than me."],
			L["The shu'halo say carry what you can for others, {name}. I can carry a lot."],
			L["Take this, {name}. If the centaur trouble you, say Thunder Bluff sends regards."],
			L["Here, {name}. Plainstriders run from me for no reason at all. You needn't."],
			L["For you, {name}. Visit Mulgore sometime. The grass is soft and nobody hurries."],
			L["Here, {name}. Grandmother blessed travellers and fed them. I'm out of bread."],
			L["The spirits asked me to mind you, {name}. I said yes before they'd finished."],
			L["Here, {name}. Kodo share the watering hole; I can share this."],
			L["Here, {name}. Tauren leave the world a little better, and a little trampled."],
			L["The Earth Mother would offer you a nap, {name}. I offer this."],
			L["Druids call it a blessing, hunters luck, {name}. Tauren call it manners."],
			L["Take this, {name}. If a harpy screeches at you, screech back. They hate that."],
			L["Here, {name}. A tauren blessing: sturdy, slow to fade, smells faintly of sage."],
			L["Here, {name}. The Venture Company would charge you for this. I won't."],
			L["From the high mesas of Thunder Bluff, {name}, where even the wind is friendly."],
			L["The ancestors watch the roads, {name}. I just help them out a little."],
			L["A gift should be heavy with meaning and light to carry, {name}. This is both."],
			L["The Earth Mother made the world wide so I'd meet folk like you, {name}. Here."],
			L["Hunt with respect and the land feeds you, {name}. That's my wisdom. Here."],
			L["Here, {name}. Not every tauren would share. The Grimtotem certainly wouldn't."],
		},
		kin = {
			L["The Earth Mother watches over us both, {name}. Today I'll help her."],
			L["Somebody warn the doorframes, {name}. Two of us, and now you're even sturdier."],
			L["Plains or peaks, {name}, a shu'halo heart is a big one. Here's some of mine."],
			L["Horns and helmets, {name}. Only another tauren knows the pain. This eases it."],
			L["Rain on fur takes a week to dry, {name}. This keeps you warm meanwhile."],
			L["Between tauren, {name}: the lifts were built by somebody smaller. Here."],
			L["Our ancestors watch us both, {name}. Let them see me share this with you."],
			L["From Mulgore to Feralas, {name}, the herd finds itself, and looks after itself."],
		},
		group = {
			L["Take this, {name}, and get behind me. There's room for the whole party."],
			L["The herd moves together, {name}, blessed. Mind my hooves; the herd has learned."],
			L["Low ceilings ahead, {name}? I'll be the first to find out. Take this."],
			L["Here, {name}. I'm slow to anger, but I hold a grudge for the whole party."],
			L["Take this, {name}. Need a wall to hide behind? I'm most of one. Come on."],
			L["That'll steady you, {name}. When I war stomp, everybody sit down anyway."],
			L["Everyone fed? Everyone blessed? Good, {name}. Tauren never lead a hungry herd."],
			L["That'll keep you warm, {name}. Tauren wade. If it's deep, you're riding on me."],
			L["Take this and stay close, {name}. My ancestors walk with us, more quietly."],
			L["Here, {name}. If I fall, don't try to carry me. Drag me. Fondly."],
			L["We move like a stampede, {name}, blessed together. Sorry about the flowers."],
			L["Take this, {name}. Nobody walks alone at the rear; I'll be there, looming."],
			L["There, {name}. Say when to charge. Tauren are slow to start, slower to stop."],
			L["Take this; nobody wander, {name}. The last who did in the Barrens still is."],
			L["Here, {name}. A herd is strongest when nobody wanders off to graze."],
			L["Here, {name}; watch the ground. Quilboar dig traps; I find them hoof first."],
			L["Into the fight with a calm heart and this, {name}. The rage can come later."],
			L["May the Earth Mother keep this herd, {name}. I've done my part."],
		},
		morning = {
			L["An'she rises, {name}, and so do we, with this. Slower, in my case."],
			L["The sun is An'she's eye, {name}. He's watching, so let's look generous."],
			L["Morning, {name}. The kodo are up, the grass is wet, and this is yours."],
			L["I've greeted the sun, the wind, two plainstriders, {name}. Now you, with this."],
			L["Dew on the grass, dew on my fur, {name}. This will dry you out from inside."],
			L["Early, {name}. That mist over Mulgore? Kodo breath. Here's a cleaner one."],
		},
		night = {
			L["Mu'sha keeps the night watch, {name}. I'll keep an eye on you too. Here."],
			L["The moon's out, {name}. Mu'sha sees you and approves of this. I asked."],
			L["Late, {name}. The kodo are asleep, and they snore like thunder. Take this."],
			L["Stars out, {name}. Each one's an ancestor. That one's winking at your blessing."],
			L["Mulgore is so quiet at night you hear the grass argue, {name}. Here, quietly."],
			L["Quiet now, {name}. At this hour, even my hooves tiptoe. And give gifts."],
		},
	},
	troll = {
		thanks = {
			L["Ya too kind, {name}! This one's from me."],
			L["Thanks, mon! Da spirits smile on ya, {name}."],
			L["Ya gave me good mojo, {name}. Now ya get some back, extra spicy."],
			L["Death's gonna be real disappointed, {name}. Thanks, mon."],
			L["Fine work, {name}. Almost as fine as me. Almost."],
			L["A troll can grow back a hand, {name}. Can't grow back honour. Here."],
			L["Ya just made a troll smile, {name}, and we got a lot of teeth."],
			L["Da loa keep a tally, {name}. You're on the good side of it."],
			L["Beat me to it, {name}! Darkspear hate bein' second. Now we're even."],
			L["I owe ya now, {name}, and trolls only like owin' da loa. Settled."],
			L["I'll tell all of Sen'jin 'bout ya, {name}. Makes a change from crabs."],
			L["My hair just stood up taller, {name}. Didn't know it could. Thanks, mon."],
			L["The spirits say give it back, {name}. They nag, but they're right."],
			L["Mojo for mojo, {name}: oldest trade in the jungle."],
			L["Vol'jin said repay kindness quick, {name}. He said a lot. Dat one stuck."],
			L["That deserves a dance, {name}. Lucky ya: {buff} instead."],
			L["Jungle rule, {name}: what ya give comes back, often with teeth. Not this one."],
			L["A gift for a troll, {name}? We never forget a kindness."],
			L["Old Sen'jin said a gift is a promise, {name}. I keep mine. Here."],
			L["Back on the Echo Isles that earned a feast, {name}. Here's the short version."],
			L["That one's goin' in the stories by the fire, {name}. Ya get a good part."],
			L["Nice, {name}. Darkspear pay back quick. We got places to be. Mostly the beach."],
			L["Stranglethorn gives nothin' for free, {name}. Nice to see somebody does."],
			L["Zalazane would've kept that for himself, {name}. Good thing ya ain't him."],
		},
		asked = {
			L["Sure thing, {name}. Hold still; mojo hates a movin' target."],
			L["No trouble, {name}. Da loa like ya."],
			L["Stay away from da voodoo, {name}. Except this one. This one's fine."],
			L["Close ya eyes, {name}. Mojo gets shy when people watch."],
			L["Ya don't gotta ask twice, {name}. Ya barely gotta ask once."],
			L["Sure, {name}. A troll is mostly swagger. The rest is this."],
			L["Ya asked polite, {name}. Polite gets the good stuff."],
			L["Ya came to the right troll, {name}. The wrong one's over there, fishin'."],
			L["Yes, {name}. The loa owe me a favour, and I'm spendin' it on you."],
			L["Got a pouch full of mojo, {name}. Don't touch the other pouch."],
			L["Anything for ya, {name}. Not my hair, though. Hair is sacred."],
			L["Troll magic, {name}, served hot. Blow on it first."],
			L["Right away, {name}. A Zandalari priest would make a week of this."],
			L["Easy one, {name}. Hard one's gettin' a raptor to sit still."],
			L["Troll rule, {name}: never make a friend beg or a raptor wait. Here."],
			L["Don't wiggle, {name}. Last one who did got the spell and a new haircut."],
			L["No problem, {name}. Darkspear always got time for a friend. And a nap."],
			L["Sure, {name}. Hold still, like a fisherman at Sen'jin waitin' on a bite."],
			L["Yes, {name}. Vol'jin says never turn away a friend, and he's usually right."],
			L["Sure thing, {name}. I'll hum a little. Witch doctors say it helps."],
		},
		offer = {
			L["Da loa watch over ya, {name}. They're real nosy that way."],
			L["Stay sharp, {name}. Take this with ya."],
			L["Ya look like somebody who appreciate quality, {name}. Here: quality."],
			L["Here, {name}. Walk like ya own the jungle. I do."],
			L["Everybody need mojo, {name}. I make so much I gotta give it away."],
			L["A little somethin' for ya, {name}. Don't ask where da loa got it."],
			L["Go on, {name}. Whatever tries to eat ya now gets indigestion."],
			L["Ya look dangerous now, {name}. Almost as dangerous as a troll."],
			L["No charge, {name}. Ya don't owe the loa a thing. Probably."],
			L["Raptors got bigger teeth than me, {name}. Now they got a problem."],
			L["Troll hospitality, {name}: ya get mojo, ya get a smile, ya don't get my fish."],
			L["Walk with mojo, {name}. Everybody else is just walkin'."],
			L["Free mojo, {name}! Quick, before the witch doctor finds out."],
			L["The loa said give this to the next good soul, {name}. That's you."],
			L["Here, {name}. Hakkar never shared. Look what happened to him."],
			L["Jungle's got two kinds of folk, {name}: ready, and lunch. You're ready."],
			L["Easy, {name}. This one tickles. Don't laugh; it gets offended."],
			L["Take this, {name}. Darkspear never send a friend off empty-handed."],
			L["Darkspear know what it is to need a friend far from home, {name}. Here."],
			L["Watch for the Bloodscalps, {name}. Same tusks as me, worse manners. Take this."],
			L["Walk easy, {name}, with this. Life's long if ya don't rush it, short if ya do."],
			L["My granny was a witch doctor, {name}. Share, she said, and look scary doin' it."],
			L["From Sen'jin Village, {name}. Smells a bit like fish. Works fine, though."],
			L["Stay loose, {name}. Tense folk trip on roots. Take this, and relax."],
			L["The spirits whisper ya name, {name}. Somebody's. They said give ya this."],
		},
		kin = {
			L["We look after our own, {name}. Always, mon."],
			L["Da rest of Azeroth stand straight, {name}. We got style. Now ya got mojo too."],
			L["Ya tusks look sharp, {name}. Mine too. Now the rest of ya does."],
			L["Every troll's family, {name}, and family gets this. Even ones owin' me gold."],
			L["One day we take the Echo Isles back, {name}. Till then, take this."],
			L["Two trolls, {name}. Da room just got taller, more relaxed, and blessed."],
			L["The loa got their eyes on both of us, {name}. Let 'em see me share."],
			L["Troll to troll, {name}: only we know how hard it is to buy boots. Here."],
			L["Our ancestors had empires, {name}. We got each other, and this. Fair trade."],
		},
		group = {
			L["Stay close, {name}. Trolls regenerate; da rest of ya get this instead."],
			L["Crew's got style, {name}. Now it's got mojo too."],
			L["We go in together, {name}, blessed, and come out together. That's the plan."],
			L["Nobody fallin' today, {name}; ya got this. Death can wait for the next group."],
			L["Take this, {name}; keep ya head down. I keep mine up. Somebody gotta look good."],
			L["Raptor formation, {name}: fast, loud, blessed, and nobody look back."],
			L["Take this, {name}. If a big snake shows up, don't run. Stand behind me."],
			L["Need more mojo, {name}? Just shout. Not too loud; the loa are nappin'."],
			L["Sen'jin will hear of this one, {name}. With this, it gets a happy endin'."],
			L["My tusks can't be everywhere, {name}, but this can. Stay near."],
			L["Nobody panic, {name}. Panic is bad mojo. This here is good mojo."],
			L["Take this, {name}. See an idol with glowin' eyes? Don't touch it. Trust me."],
			L["Stay loose, {name}, and take this. Fights go better when ya smilin'. Mostly."],
			L["Darkspear fight together or not at all, {name}, and share the mojo. Here."],
			L["Ready, {name}? Take this. Any Gurubashi, let me talk first. Then ya hit 'em."],
			L["Take this and watch for traps, {name}. Trolls built half the old temples."],
			L["The loa are watchin' this group, {name}. Let's give 'em a show. Start here."],
			L["I got ya back, {name}. Trolls got long arms for a reason."],
		},
		night = {
			L["Night's the best time for mojo, {name}. Nobody sees where it's from."],
			L["The jungle wakes at night, {name}. So do I. This one's fresh."],
			L["High moon, {name}, restless spirits. This keeps 'em off ya."],
			L["Hir'eek the bat loa keeps late hours too, {name}. This is from us both."],
			L["This late, {name}, only trolls and trouble are up. I'm the nice one. Here."],
			L["Stars out, {name}. Each one a loa, Granny said. They all saw me give ya this."],
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
			L["Thank you, {name}. Visit Silvermoon; I'll show you all of it but Murder Row."],
			L["Returned, {name}. Unlike Kael'thas, I give things back."],
			L["Thank you, {name}. I felt that to the tips of my ears, and that's a long way."],
			L["Thank you, {name}. That was so kind my eyes nearly changed colour again."],
			L["A gift, unasked? Farstriders would call that an ambush. A lovely one, {name}."],
			L["Better than a mana crystal, {name}, and I've given those up. Mostly. Thank you."],
			L["Quick of you, {name}. Elves live for centuries, and you still beat me to it."],
			L["Charming, {name}. The sun favours the generous, and so do I."],
			L["Thank you, {name}. I'll mention you at court. Well, at a very exclusive picnic."],
			L["Thank you, {name}. Courtesy is rare outside Silvermoon. Yours shines."],
			L["Unasked kindness, {name}! Somebody tell Rommath; he'll want to study it."],
		},
		asked = {
			L["Naturally, {name}. Only the finest for you."],
			L["For you, {name}? Of course. The sun gives freely."],
			L["Patience, {name}. Radiance can't be rushed, only admired."],
			L["Of course, {name}. {buff}, delivered with impeccable posture."],
			L["You asked nicely, {name}. In Silvermoon that counts for everything."],
			L["One moment, {name}. I never cast anything without checking my hair."],
			L["At once, {name}. Keeping someone waiting is so terribly unfashionable."],
			L["Certainly, {name}. Stand back a step; my sleeves are enchanted and very wide."],
			L["Magisters would bill you, {name}. Blood Knights would lecture. I merely glow."],
			L["At once, {name}. If it goes well, tell everyone. If not, blame the robe."],
			L["At once, {name}. The dragonhawk can wait; it's used to waiting while I dress."],
			L["Gladly, {name}. We once took the Light from a naaru. Asking is so much nicer."],
			L["Three centuries of casting, {name}, and you're the first to say please."],
			L["Gladly, {name}. Silvermoon's brooms sweep themselves, so my hands are free."],
			L["Of course, {name}. I keep my other spells for the rude."],
		},
		offer = {
			L["Anar'alah belore, {name}. May the sun guide you, and light your good side."],
			L["Shorel'aran, {name}. Fight with elegance, and with this."],
			L["Take this, {name}. Whatever happens out there is merely a setback."],
			L["Everyone deserves to shine, {name}. Only a little less than me, of course."],
			L["The sun is with you, {name}. I simply held the door for it."],
			L["Go on, {name}, take it. The Sunwell's back; we can afford to be generous."],
			L["For you, {name}: {buff}, lightly scented with Silvermoon."],
			L["Here, {name}. Hand-cast in Silvermoon, so do try not to scuff it."],
			L["A little Sunwell for you, {name}. It's been through a lot; treat it kindly."],
			L["Be prepared, {name}. We weren't, once, and now we have a scar for a road."],
			L["Here, {name}. I only give to the worthy. How convenient that you walked by."],
			L["Take this, {name}. It's been in my family for moments."],
			L["We sin'dorei have lost much, {name}. Never our generosity. Or our cheekbones."],
			L["Take this, {name}. Should a mana wyrm follow you, it's only jealous."],
			L["Seven thousand years to perfect generosity, {name}. We started last week."],
			L["Take this, {name}. It came through the Undercity orb, so it's slightly dizzy."],
			L["For you, {name}. It matches everything. I checked, obviously."],
			L["Take this, {name}. If a ghoul stops you, say Silvermoon's still standing."],
		},
		kin = {
			L["The Sunwell shines for us both, {name}. Let me share its light."],
			L["Two sin'dorei, {name}. The day just got twice as elegant, and you blessed."],
			L["You too, {name}? Two sin'dorei, one mirror. Take this; now you look better."],
			L["Like the phoenix, {name}, we keep rising. This helps you look good doing it."],
			L["Between sin'dorei, {name}: yes, the Horde is loud. This, at least, is quiet."],
			L["Sin'dorei to sin'dorei, {name}: we never speak of the green eyes. Take this."],
			L["Magister or Farstrider, {name}, the sun rises for us all. Here's some of it."],
			L["We knew Quel'Thalas before the Scourge, {name}. Here; let's earn the after."],
		},
		group = {
			L["Do keep pace, {name}; you're blessed now. We're known for arriving beautifully."],
			L["Stand where the light is good, {name}. With this on you, we'll look splendid."],
			L["A party at last, {name}. I did dress for one, and I brought gifts."],
			L["The sun shines on all of us, {name}. Mostly on me, but I share it. Here."],
			L["One for you, {name}, and one for the party's image, which I've taken on myself."],
			L["Here, {name}. If I fall, arrange me nicely. The rest I leave to the priest."],
			L["Take this; touch no enchanted relics, {name}. Well, I may. I've had training."],
			L["Every expedition needs a ranger, {name}. I'm not one, but I bless well."],
			L["We fight together, {name}, blessed, then tell it beautifully. I'll tell it."],
			L["Whoever mends us is to be thanked, {name}. Whoever blesses you, admired. Me."],
			L["Take this, {name}. If it goes badly, we blame the Scourge. It's traditional."],
			L["Mana potions are for emergencies, {name}. This is for you. I've had eleven."],
			L["We walked out of the ashes once, {name}. With this, we'll walk out of anything."],
		},
		morning = {
			L["The sun has risen, {name}, and so have I. We coordinate. Here's its light."],
			L["Dawn over Quel'Thalas is lovelier, {name}, but this blessing will do. Just."],
			L["Morning light, {name}: the most flattering hour. This makes it more so."],
			L["Breakfast in Eversong is fruit, tea and arcane, {name}. Skip to the arcane."],
			L["Dawn, {name}. Red and gold across the sky. Here's some of it, for you."],
			L["Morning, {name}. Only Silvermoon's guardians are up this early. And me. Here."],
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
			L["In Elisande's court a gift hid a knife, {name}. Yours hides none. Thank you."],
			L["Thank you, {name}. My manasaber approves of you, and she approves of no one."],
			L["Exquisite, {name}. Once I'd have said 'adequate'. The world has humbled me."],
			L["You fed a mind that once went hungry, {name}. We never forget those who do."],
			L["Centuries of court etiquette, {name}, and 'thank you' still says it best."],
			L["Thank you, {name}. You're invited to the next masquerade. Masks mandatory."],
			L["Thank you, {name}. Oculeth would open a portal to say so. I'll simply cast."],
		},
		asked = {
			L["Of course, {name}. A little arcane polish, just for you."],
			L["A reasonable request, {name}. Granted."],
			L["Certainly, {name}. The short version; the long one takes a lunar cycle."],
			L["A request, how refreshing. The court only ever made demands. Here, {name}."],
			L["Done, {name}, and free. Elisande would have charged you a favour for it."],
			L["There, {name}. No need to bow. A small nod would be lovely, though."],
			L["Of course, {name}. I've perfected this since before most cities had walls."],
			L["Granted, {name}. I'd ask a favour back, but I'm trying to be less Suramar."],
			L["Certainly, {name}. Forgive the flourish. We can't cast plainly; we've tried."],
			L["At once, {name}. Elisande once stopped time. I only need a second."],
			L["Of course, {name}. The ley lines here are shallow, but I'll make do."],
			L["Very well, {name}. Stand in the moonlight. Or by that lamp. Lamps will do."],
			L["Naturally, {name}. Suramar had a spell for everything. I remember several."],
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
			L["Once, I'd have made you bow for this, {name}. We've all grown."],
			L["The Kirin Tor do this too, {name}, bless them. Quite nicely, for newcomers."],
			L["A gift from under the dome, {name}. Kept fresh for a very, very long time."],
			L["Enjoy this, {name}. I used to cast it on nobility. You're an improvement."],
			L["I packed for the outside world like a gala, {name}. Four capes. Take this."],
			L["Here, {name}. Suramar work: overdesigned, overdecorated, and flawless."],
			L["Here, {name}. In Suramar this came with a string quartet. Do hum something."],
		},
		kin = {
			L["Suramar's children shine together again, {name}. Let me add to your glow."],
			L["Shal'dorei, {name}! You packed arcwine? No? Then take this instead."],
			L["Suramar's own, {name}. Take this; the rest of the world won't do it so well."],
			L["We survived the Legion and the withering, {name}. We can spare this."],
			L["Our tailors made it out of Suramar too, {name}. Take this to go with the robes."],
			L["We both remember going hungry, {name}. Never again; here, take what I have."],
			L["Out from under the dome, {name}. The sky's so big. This helps."],
			L["Two shal'dorei, {name}. The locals will think it's a gala. Gifts are expected."],
		},
		group = {
			L["An expedition, {name}! In Suramar this blessing needed six permits."],
			L["The dome kept us safe, {name}. Now one another must. Gladly; here."],
			L["Arcane for everyone, {name}. The court would call it waste. I call it company."],
			L["Take this, {name}, and follow my lead. Ten thousand years of walking in step."],
			L["In a party one shares one's magic, {name}. How novel. I rather like it."],
			L["An outing is a masquerade, {name}: smile, keep moving, and take a gift."],
			L["Stay in the light of my spells, {name}. It's the most flattering in the party."],
			L["After Elisande's court, {name}, this is a holiday. Nobody poisons the gifts."],
			L["Lost? Follow the one who glows, {name}. That's me. Here, now you glow too."],
			L["Take this, {name}. If I start lecturing on ley lines, do interrupt. Politely."],
			L["I watched my people wither, {name}. I won't watch friends fade. Nobody falls."],
			L["Here, {name}. Tell me if I'm being grand. I lose track. It's the millennia."],
		},
		night = {
			L["Night at last, {name}. Add this glow and some lanterns: nearly Suramar."],
			L["Under the dome it was always night, {name}. I feel at home, and generous."],
			L["The stars are out, {name}. We had better ones in Suramar. This will do too."],
			L["Nightborne, {name}, and here's the night. I'm dressed for it; now so are you."],
			L["At this hour, {name}, Suramar dressed for dinner. Here's your finery."],
		},
		morning = {
			L["Daylight, {name}. Ten thousand years under a dome, and it startles me. Here."],
			L["An early hour, {name}. The court never rose before noon. I'm reforming. Here."],
			L["Morning, {name}. The sun here is so very... unenchanted. Take this instead."],
			L["Morning, {name}. We warded Suramar against all but the sun. I've warded you."],
			L["Dawn, {name}: when the court's gossip went to bed. Here's mine, and this."],
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
			L["Thanks, {name}! Quick hands. You'd do well in Booty Bay."],
			L["A deal where both sides profit, {name}! I'd heard of those. Never seen one."],
			L["First free gift since Kezan blew up, {name}. Returning it before I price it."],
			L["Thanks, {name}! I appraised it at priceless. Here's one appraised the same."],
			L["Kindness in, kindness out, {name}. Best returns since the kaja'mite boom."],
			L["Even trade, {name}? My accountant just fainted. He does that around fair deals."],
			L["Thanks, {name}! I'd shake on it, but I count my fingers after. Habit, not you."],
			L["Thanks, {name}! Gadgetzan could use a few more like you."],
		},
		asked = {
			L["You got it, {name}! Time is money, friend!"],
			L["Deal, {name}! I'll put it on your tab. Kidding!"],
			L["Right away, {name}! Satisfaction guaranteed or your {buff} back."],
			L["{buff}, {name}! Tips optional. Encouraged. Optional."],
			L["Fast, cheap or good, {name}? Today you get all three. Don't spread it around."],
			L["Sure thing, {name}! No explosions this time, I promise. Mostly promise."],
			L["For you, {name}? No charge. Put that in writing and I'll deny it."],
			L["Sure, {name}! Quote's zero gold. Lowest I've ever quoted. It stings a little."],
			L["Coming up, {name}! Full warranty included. Valid until it wears off."],
			L["Sure, {name}! I'd tinker with it, but you look in a hurry."],
			L["Easy, {name}. Steamwheedle rule: keep customers alive. They pay longer."],
			L["Gadgetzan's got the water trade, {name}. I've got this. Better margins."],
			L["Kezan standard, {name}: fast, loud, and done before you read the terms."],
			L["On it, {name}! Goblins never keep a customer waiting. Unless it pays."],
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
			L["Here, {name}. Go make your fortune. I'll want a cut."],
			L["Zeppelin's late again, {name}, so I've time to be generous."],
			L["Here, {name}. Patent pending. Try it out and tell your rich friends."],
			L["Consider this an investment, {name}. In you. I expect heroic returns."],
			L["Take it, {name}! My last shipment sank off Kezan, so everything's clearance."],
			L["The Venture Company charges for this, {name}. I'm the competition. Here."],
			L["Every goblin has a soft spot, {name}. Mine's small and guarded. You found it."],
			L["Take this, {name}. It's the only thing I own with no lien on it."],
			L["You'll be rich someday, {name}. I can tell. Remember who gave you this."],
		},
		kin = {
			L["Anything for a fellow entrepreneur, {name}!"],
			L["Kezan's finest, together again, {name}. Here, free. Keep a hand on your purse."],
			L["Fellow goblin, {name}? Then you know this is a very, very rare discount."],
			L["Goblins look after goblins, {name}. It's cheaper than hiring guards."],
			L["Kezan's gone, {name}, but the greed made it out. Not today, though. Here."],
			L["Between goblins, {name}, this never happened. I have a reputation."],
			L["Bilgewater or Steamwheedle, {name}, we float to the top. This helps."],
			L["Remember the volcano, {name}? We sold tickets. This one's free. Proud times."],
		},
		group = {
			L["Group rate, {name}! Everybody here gets it half off. Of free."],
			L["Nobody dies on my contract, {name}. Here's insurance. The paperwork's awful."],
			L["We split the take even, {name}. This is your share. I did the maths. Trust me."],
			L["There, {name}. Everyone's stronger, and everyone owes me. Invoices later."],
			L["Stick together, {name}. Mercenaries cost gold; friends only cost this."],
			L["Everybody's covered, {name}. Not insured, mind. Covered. Different price."],
			L["The risk report on this outing says 'no', {name}. This lowers the risk."],
			L["Take this, {name}. Nobody touches the big red lever. There's always one."],
			L["Here, {name}. If this goes south, I've got a rocket. Seats one. Working on it."],
			L["We're a company now, {name}. I'm treasurer. Here's your benefits package."],
			L["Stay alive, {name}. Nobody sells resurrections yet, so take this. Free."],
			L["Take this, {name}, and stay close. I've already sold the story of this trip."],
		},
		morning = {
			L["Early bird gets the gold, {name}! Here's a freebie. Don't tell the other birds."],
			L["Morning, {name}! Markets open in an hour. Until then, I'm feeling generous."],
			L["Up early, {name}? Smart. Time is money, and this is cheapest in the morning."],
			L["Dawn, {name}. Rich goblins sleep in. I'm not rich yet, so I'm handing out this."],
			L["Fresh day, fresh ledger, {name}. You're the first entry. The good column."],
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
			L["Thank you, {name}! I'd give you my best button, but this is better. Slightly."],
			L["Ooh, a present, {name}! I'll trade you one of mine."],
			L["Thanks, {name}! That goes in the good pouch. Not the rock pouch. The good one."],
			L["In Vol'dun that would've cost a whole waterskin, {name}. Thank you!"],
			L["Thanks, {name}! Your name goes on the wagon. Between the alpaca and the dent."],
			L["Kindness is the one thing the desert never buried, {name}. Thank you."],
			L["Rakera says repay quick, {name}, before you forget which pocket it's in. Here!"],
			L["Nobody's given me anything I didn't dig up first, {name}. Thank you!"],
		},
		asked = {
			L["Of course, {name}! Shake the sand out and hold still."],
			L["Coming right up, {name}! Caravan service, no waiting."],
			L["Sure, {name}! Let me dig it out... rope, rocks, a nice rock... here it is!"],
			L["Hold on, {name}! Tail's in the way, one moment... there!"],
			L["One {buff}, {name}! Only slightly sandy."],
			L["Ask a vulpera and you'll get something, {name}. Usually odd. Not today!"],
			L["Yours, {name}! Vulpera love giving things. Almost as much as finding them."],
			L["Here, {name}! Patched it up myself. Holds better than it looks."],
			L["Sure, {name}! Stand upwind. Sandstorm last week; I'm still shedding it."],
			L["YES! Sorry, {name}, too loud? The desert's very big. You have to shout in it."],
			L["Of course, {name}. Caravan rule: nobody asks twice for water or for help."],
			L["On it, {name}! Small spell, big fox, bigger ears. Wait. Other way round."],
			L["For you, {name}? Easy! Caravan folk never say no to a neighbour."],
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
			L["Here, {name}! I swapped a hat for a thing, and the thing for this. Good trade!"],
			L["Nobody walks past anybody in the dunes, {name}. Bad luck, and rude. Here."],
			L["My nose says trouble's ahead of you, {name}. Take this. My nose is never wrong."],
			L["Too many spells in my pack, {name}. They jingle. Take one, please."],
			L["If you find anything shiny later, {name}, you know where my ears are. Here!"],
			L["Wait, {name}! You nearly left without this. Deserts eat people who do that."],
			L["Stew's not ready yet, {name}, so this is the starter."],
		},
		kin = {
			L["A fellow wanderer! The caravan is never far, {name}, nor its gifts."],
			L["Ears up, {name}! Always nice to share a spell with a fellow fox."],
			L["Vulpera to vulpera, {name}: here's this. I've three spare spoons too."],
			L["Vol'dun raised us both, {name}. Sand in the fur, luck in the pack. Have some."],
			L["Ears to ears, {name}: I heard you needed this."],
			L["Remember the caravan fires, {name}? Everybody sang badly and shared. Here."],
			L["Vol'dun's far behind us, {name}, half of it in our fur. This I brought for you."],
		},
		group = {
			L["Caravan rules, {name}: stick together, share water and this. Never the alpaca."],
			L["Anything shiny in there, {name}, I saw it first. This shiny bit is yours."],
			L["One for the party, {name}! A caravan's only as fast as its slowest alpaca."],
			L["Here, {name}. Keep your pack shut. I don't mean to take things. I give, too."],
			L["Lost in a city, never in a cave, {name}. Caves are houses with no rent. Here."],
			L["Take this, {name}. I'm small, so I'll check the tiny tunnels. You take the big."],
			L["Shout if you need more, {name}. I've probably got it. It's probably dented."],
			L["There, {name}. I'll take the back. Nobody gets left behind in a caravan."],
			L["A caravan with no wagon, {name}! Fast, light, nowhere to nap. Here's a boost."],
			L["Scouted ahead by nose, {name}: danger and old cheese. Take this first."],
			L["Everybody fed? Everybody watered? Good. Now this, {name}. Caravan order."],
		},
		night = {
			L["We vulpera travel by night, {name}. Cool sand, sleepy scorpids, and this."],
			L["Desert nights get cold, {name}. Here, something warm-ish."],
			L["Stars out, {name}. All signposts, and I can't read them. I can give you this."],
			L["Good hour for foxes, {name}. The ears work best when it's quiet. So does this."],
			L["Past dark and I'm just waking up, {name}. First thing: this, for you."],
			L["I'll curl up in my tail later, {name}. Best blanket I own. First, this."],
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
			L["That was very pandaren of you, {name}. All that's missing is a dumpling."],
			L["At Halfhill that earns a prize turnip, {name}. I left mine at home. Thank you."],
			L["Grandmother kept a jar of kindnesses, {name}. Yours goes in; this comes out."],
			L["Thank you, {name}. In the Jade Forest my door is open, and my pantry more so."],
			L["You move like the Shado-Pan, {name}. I never saw that coming. Thank you."],
			L["Like rain on a rice paddy, {name}. The paddy never says thank you. I do."],
			L["Thank you, {name}. Li Li would put this in her travel journal. With drawings."],
			L["Thank you, {name}. The August Celestials are busy, so I thank you for all four."],
			L["Stormstout ale knocks a pandaren flat, {name}. So did that. Thank you."],
			L["Now we are even, {name}. A pandaren never lets a kindness go cold."],
		},
		asked = {
			L["Of course, {name}. Patience, and it is done. Patience is the slow part."],
			L["With pleasure, {name}. A kind deed is never wasted."],
			L["At once, {name}. Quick for a pandaren, which is not saying much."],
			L["Master Shang Xi said: help whoever asks, {name}. I listened."],
			L["A Tushui master would make you meditate first, {name}. I will skip that part."],
			L["Anything for you, {name}. Except the last dumpling. Let us not be silly."],
			L["One {buff}, {name}, brewed strong. The recipe stays a secret."],
			L["Stand like a crane, {name}: one leg, calm face. Two legs is also fine."],
			L["We never refuse a request, {name}. Or a second helping."],
			L["The last to ask me for help, {name}, was an island-sized turtle. You're easier."],
			L["Pandaren help like we cook, {name}: slowly, generously, and far too much of it."],
			L["Certainly, {name}. Let me put down my bowl. ...There. That was the hard part."],
			L["Yes, {name}. Grandfather said never make guests ask twice. He said it twice."],
			L["Hold still, {name}. I am calm, you are calm, the spell is calm. Nobody panic."],
		},
		offer = {
			L["Take this, {name}. And perhaps a cup of tea afterward?"],
			L["Balance in all things, {name}. Take this, and go with a light heart."],
			L["Take this, {name}. A grummle would sell it to you for a luckydo."],
			L["The jinyu say the waters foretold this, {name}. They say that a lot."],
			L["The Huojin say act first. The Tushui say think first. I say: here, {name}."],
			L["A pandaren stood up to give you this, {name}. Treasure it."],
			L["Fight like a monk, {name}: calm, quick, blessed, and then a long lunch."],
			L["Go gently with this, {name}. The turtle got where it was going, unhurried."],
			L["A hug would be forward, {name}. This is next best, and less furry."],
			L["Take this, {name}. If a fight finds you, roll away. Rolling is very underrated."],
			L["For you, {name}. It is warm, round and full of good intentions. Like me."],
			L["Take this, {name}. My kite is stuck in a tree, so I have time for good deeds."],
			L["I carried this from Pandaria, {name}. Also a keg. The keg is mine."],
			L["The virmen stole my carrots, {name}, but this they will never get. Here."],
			L["On the Wandering Isle, {name}, strangers get soup. This travels better."],
			L["Pandaren look soft, {name}. So does this, until it saves you."],
			L["Chi-Ji says there is always hope, {name}. I say there is always a spare. Here."],
		},
		kin = {
			L["We must share a brew when the road allows, {name}! For now, share this."],
			L["Shen-zin Su would be proud of us, {name}, and of this. Or asleep. Hard to tell."],
			L["Two pandaren, {name}. An innkeeper just felt a chill. Here, it warms."],
			L["Liu Lang would approve, {name}: two of us far from home, sharing. Here."],
			L["Tushui or Huojin, {name}, we both left the turtle. Here's a taste of home."],
			L["Pandaren to pandaren, {name}: the brews out here are thin. This is not."],
			L["We both smell of rice wine and road dust, {name}. This smells of neither. Here."],
			L["Pandaren look after pandaren, {name}. Mostly by feeding them. This comes first."],
		},
		group = {
			L["A gift, a fight, then a meal, {name}. That is the correct order."],
			L["Stay together, {name}, like dumplings in a steamer. Warm now, and ready."],
			L["We move as one, {name}, and now blessed as one. Slowly, perhaps."],
			L["Balance, {name}: one fights, one heals, one carries snacks. And one gives this."],
			L["Take this, {name}. If we fall, we fall together, and then nap. Let us not."],
			L["Here, {name}. Stay behind me. I am soft, but I am very wide."],
			L["Take this, {name}. If we win, I will cook. If we lose, I will cook, but sadly."],
			L["Breathe, {name}. In, and out. Feel that? Now hit things, calmly."],
			L["Quickly, {name}, take this. I am in a hurry. It happens about once a decade."],
			L["A party is like a brew, {name}: odd ingredients. I've just added one more."],
			L["Here, {name}. If I fall, roll me somewhere safe. Carrying me is not an option."],
			L["Pandaren fight like water, {name}. This flows into you: calm, then everywhere."],
		},
		morning = {
			L["Up before the tea, {name}? Brave. Here, instead of the tea."],
			L["Morning, {name}. First this, then breakfast, then more breakfast."],
			L["A new day, {name}, and nobody has spilled anything. Let us begin with this."],
			L["Halfhill's farmers have been up for hours, {name}. I just rose, but with this."],
			L["Morning mist, {name}. Just like home, until a kobold walked by. Have this."],
			L["Good morning, {name}. My stomach woke first and ordered me to give you this."],
		},
		night = {
			L["Past my first nap, {name}, before my second. Take this while I'm awake."],
			L["Late, {name}. The brewmasters sleep. The brews don't, and nor does this."],
			L["Midnight snack time, {name}. This is the appetiser."],
			L["Dark already, {name}? Grandfather's stories would start now. Take this first."],
			L["The moon is round and full tonight, {name}, as I am. Here, from both of us."],
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
			L["A mortal gift, {name}: small, brief and kind. I am learning to like all three."],
			L["Thank you, {name}. Mortal customs are new to me. Do I pay you? No? Then this."],
			L["Thank you, {name}. I have scales where most have feelings. That got through."],
			L["You're on my list of favourite mortals, {name}. It was empty until today."],
			L["The red in me is grateful, {name}. The black in me is suspicious. The red wins."],
			L["Thank you, {name}. Dragons are not used to receiving. I find I like it."],
			L["A dragon's thanks comes with a roar, {name}. I will spare the neighbours."],
		},
		asked = {
			L["Very well, {name}. Stand still, I would hate to singe you."],
			L["Granted, {name}. A dragon keeps its word."],
			L["Certainly, {name}. Stand clear of the tail."],
			L["Of course, {name}. Is this still how it is done? I was asleep for a while."],
			L["Gladly, {name}. All five dragonflights are in me, and all five say yes."],
			L["Right away, {name}. Dragon-sized help, in a conveniently smaller form."],
			L["Of course, {name}. Neltharion only gave orders. A request is much nicer."],
			L["Right away, {name}. Stand back a little; I am still learning how big I am."],
			L["Certainly, {name}. Claws are not ideal for spellwork, but I manage."],
			L["Of course, {name}. Dragons usually demand tribute. I'm waiving it, this once."],
			L["Of course, {name}. Please don't scream. Mortals often do. It's the horns."],
			L["My breath is fire, {name}, so we will do this the other way."],
			L["Gladly, {name}. Mortals so rarely ask a dragon for anything but mercy."],
			L["A small magic, {name}, but I cast it with enormous dignity."],
		},
		offer = {
			L["Take this, {name}. Even a dragon needs allies. Especially one this size."],
			L["A gift from the Dragon Isles, {name}. Fly well."],
			L["Alexstrasza says every life is precious, {name}. I am starting with yours."],
			L["I slept through ten thousand years of good deeds, {name}. Catching up now."],
			L["Tell them a dragon did this, {name}. It sounds far grander than it was."],
			L["Scalecommander's orders, {name}: take this. I'm no Scalecommander, but still."],
			L["Take this, {name}. Ancient dragon magic, only slightly out of date."],
			L["A dragon giving, {name}, not taking. I am trying something new."],
			L["In visage form I look harmless, {name}. So did Lady Prestor. I give, not take."],
			L["A gift from above, {name}. I landed specially. It took two tries."],
			L["Here, {name}. Every dragon should guard something. I have chosen you, for now."],
			L["Take this, {name}. It's from five dragonflights, so it clashes with everything."],
			L["I'd fly you there myself, {name}, but dracthyr carry no riders. Take this."],
			L["Dragons gifted the world at its dawn, {name}. Mine is smaller, and later."],
			L["A little essence for you, {name}. It is what I'm made of, so handle it gently."],
			L["Take this, {name}. It will feel warm. Most things do, after I touch them."],
		},
		kin = {
			L["The Forbidden Reach is far behind us, {name}. What we learned there, I share."],
			L["Two dracthyr, {name}. Mind the wings; no room for four. Take this."],
			L["Remember when the world was new to us, {name}? This still feels new."],
			L["In visage form nobody can tell, {name}. Between us: this suits scales best."],
			L["Made for war, {name}, and look at us: sharing. Somebody's plans went wrong."],
			L["Visage or scales, {name}, I'd know one of us anywhere. So here is yours."],
			L["Mortals always ask if we'll fly them, {name}. Still no. But this, yes."],
			L["Between dracthyr, {name}: the horns never get easier with hats. This helps."],
		},
		group = {
			L["Take this, {name}. Then tell me when to breathe fire. And when not to."],
			L["I woke in a cave of strangers, {name}. Now I give gifts to company. Better."],
			L["Neltharion made us to fight alone, {name}. We improved on him. Here."],
			L["Here, {name}. Stay clear of my tail. It hasn't learned whose side it's on."],
			L["A flight of our own, {name}, sharing its gifts. So this is what dragons meant."],
			L["Take this, {name}. If I say 'take cover', I mean behind my wings."],
			L["That's for you, {name}. Stand beside me, never in front. I can't aim my breath."],
			L["Take this, {name}; leave the big ones to me. Well, the ones smaller than me."],
			L["Stay close, {name}, blessed. I can glide us all down. Up is your problem."],
			L["Keep moving, {name}. A dragon in a hurry gives gifts. One waiting is just big."],
			L["Here, {name}. Now tell me the plan slowly. I was made for battles, not plans."],
			L["Mortals live so briefly, {name}. This should make today a little longer."],
		},
	},
	haranir = {
		thanks = {
			L["Thank you, {name}. Where I come from, a kindness is tended like a root."],
			L["Thank you, {name}. Hagar sent me to see the goddess's work. You're her best."],
			L["Kindness echoes, {name}, and I grew up in a cavern. Here it comes back to you."],
			L["My Legacy Stone showed who I'd stand beside, {name}. It forgot you. Thank you."],
			L["We read lives in a root's rings, {name}. Yours just grew a kind one."],
			L["The Shul'ka gave up everything to guard us, {name}. I can give this much."],
			L["The world is more than Harandar, the Song said, {name}. Thanks for proving it."],
			L["Thank you, {name}. Orweyna said outsiders had much to teach us. I'm learning."],
			L["Our oaths forbid speaking to outsiders, {name}. I'll risk a thank you."],
			L["My people lived up here once, {name}. Thanks to you, I can see why."],
			L["We're raised on dedication and humility, {name}, so I'll just say thank you."],
			L["Back home I'd dance for that, {name}. Up here people stare, so: thank you."],
			L["Thank you, {name}. You've left me glowing like a moth back in Harandar."],
			L["Har'mara is the Village of Balance, {name}. I'd hate to go home lopsided."],
			L["If Aln'hara can hear anything where she is, {name}, I hope she heard that."],
		},
		asked = {
			L["Of course, {name}. Protect, tend and serve, my people say. This is the serving."],
			L["Of course, {name}. I answered the goddess's call. Yours is far easier to hear."],
			L["Of course, {name}. Dalnir would call this a distraction. Dalnir isn't here."],
			L["Of course, {name}. The roots never ask for anything. It's nice to be asked."],
			L["Gladly, {name}. Back home I'd have had to pretend I never saw you."],
			L["Of course, {name}. Mind the quills; they're friendlier than they look."],
			L["Gladly, {name}. Don't stand still too long; in Harandar you'd sprout mushrooms."],
			L["Of course, {name}. I was raised to do exactly as I was told. For once, I will."],
			L["No alndust in this one, {name}. Nothing will come to life and bite you."],
			L["Of course, {name}. Half the names up here are new to me. Yours I'll keep."],
			L["{buff}, {name}, grown under the World Trees and picked fresh."],
			L["Of course, {name}. Hagar is handling things at home; I'll handle them up here."],
			L["At my initiation I was asked who I really am, {name}. Someone who says yes."],
		},
		offer = {
			L["Take this, {name}, from a long way below. The roots send their regards."],
			L["Take this, {name}, and may Aln'hara be with you."],
			L["The sky has no ceiling, {name}. Anything could fall on you. Take this."],
			L["Follow the visions, Hagar said, {name}. Today they pointed at you. Take this."],
			L["My people would have watched you from the brush, {name}. I'd rather do this."],
			L["Harandar stayed out of the world's wars, {name}. You weren't so lucky. Here."],
			L["The Zur'ashar paint every tale worth telling, {name}. Here; make yours long."],
			L["Take this, {name}. The goddess's world is a garden, and gardens have thorns."],
			L["We tend roots in Harandar, {name}. You look as if you could use some tending."],
			L["My ancestors grew restless and sought a purpose, {name}. I've found mine. Here."],
			L["Har'mara lives at peace with its neighbours, {name}. This is how it begins."],
			L["The first outsiders I met were fighting off a saptor, {name}. Best take this."],
			L["My people have kept hope alive for ages on very little, {name}. Have some."],
			L["I'm still learning what to say to strangers, {name}. This seemed safest."],
			L["My people live beside a wound that never heals, {name}. Here; come back whole."],
		},
		kin = {
			L["Two haranir out in the world, {name}. The elders would fret. I'll help instead."],
			L["Did the Song call you up as well, {name}? It called me to give you this."],
			L["Keep to the brush, they told us, {name}. We're both bad at it. Take this."],
			L["Harandar's roots run under all this, {name}. Some of their strength, for you."],
			L["Looking for the goddess too, {name}? Two pairs of eyes, then, and this."],
			L["Told to give up childish adventures, {name}? Me too. Here, for the next one."],
			L["Nobody up here speaks Hara'ni, {name}. So I'll just say it with this."],
			L["Outsiders ask where we're from, {name}. I point down. Here's a bit of down."],
		},
		group = {
			L["Stay close, {name}. A haranir needs something to guard, and today it's you."],
			L["We once mastered every beast on our mountain, {name}. With this, these won't."],
			L["Word from Harandar, {name}: the haranir join the fight. This is my part."],
			L["My people's oldest shame is fighting each other, {name}. Here; together, then."],
			L["Here, {name}. Mind your step; where I'm from, the floor is mostly roots."],
			L["Take this, {name}. If anything crawls up from below, leave it to me."],
			L["Dangerous, {name}? My ancestors went into the deep with less than this."],
			L["Do not fear the dark, {name}. Orweyna's words, and my gift, go with you."],
			L["Take this, {name}. I'll take the ledges. Clawed feet were made for them."],
			L["The goddess's world is worth fighting for, {name}. This bit too. Here."],
			L["I've cleared weeds, mud skippers and fungi, {name}. You I'll just bless."],
			L["The Zur'ashar won't paint this fight, {name}. Take this; let's win it anyway."],
		},
	},
}

-- For kin of a people with no kin lines of their own (a race the addon does
-- not know).
RP.KIN = {
	L["It is good to see one of our own, {name}. This is how we greet them."],
	L["Our people are few, {name}. That makes each of us worth this."],
}

-- Faction pride without a word about the other side. "Neutral" is a pandaren
-- on the Wandering Isle or a dracthyr before choosing, and anybody whose
-- faction the client would not say. A group member hears a side's group
-- lines, and its offers (said to a stranger on a road) only while it has
-- none.
RP.FACTION = {
	Alliance = {
		thanks = {
			L["Thank you, {name}. The Alliance looks after its own, and today that's me."],
			L["Kindness answered, {name}. For the Alliance!"],
			L["Thank you, {name}. Stormwind has a statue for every hero. I'll put in a word."],
			L["The Alliance way, {name}: you help me, I help you, a dwarf buys the drinks."],
			L["Bolvar would bow, Magni would hug, {name}. I'll just return it."],
			L["If the Alliance gave medals for manners, {name}, you'd need a second tabard."],
			L["Returned in full, {name}. An ally who gives first is worth a whole garrison."],
			L["Thank you, {name}. I'll mention you in my letter home. Mother reads them aloud."],
			L["Thank you, {name}. Even the Stormwind guards would smile at that."],
			L["The Alliance at its finest, {name}: nobody asked, somebody helped. Thanks."],
			L["I'll tell everyone on the Deeprun Tram, {name}. It's a long tram. Thank you."],
			L["Most gallant, {name}. If I had a lion on my tabard, it would be purring."],
			L["Our kings bicker, {name}, but their people get on splendidly. Thank you."],
			L["The Alliance was forged by folk keeping their word, {name}. Here's mine."],
		},
		asked = {
			L["Of course, {name}. Allies help each other. It's practically in the name."],
			L["At once, {name}. The Alliance does not leave a friend wanting."],
			L["Of course, {name}. It's in the Alliance charter. Somewhere near the back."],
			L["By order of the Alliance, {name}: one {buff}, effective at once."],
			L["Anything for an ally, {name}. Within reason. This is well within reason."],
			L["Right away, {name}. SI:7 knew you would ask. I only just found out."],
			L["Straight away, {name}. The Alliance marches on requests like yours. And bread."],
			L["Yes, {name}. From Stormwind to Ironforge, 'please' opens every gate."],
			L["Right away, {name}. I've worn the blue all day hoping somebody would ask."],
			L["Hold still, {name}. I learned this faster than the Alliance anthem."],
			L["Of course, {name}. Armies win wars; small favours win allies. Here's one."],
		},
		offer = {
			L["For the Alliance, {name}! Stay strong out there. Stronger, now."],
			L["Onward, {name}, and take this. The Alliance is with you."],
			L["Take this, {name}. Had a gnome made it, it would come with twelve levers."],
			L["Compliments of the Alliance, {name}. We've done these since the Second War."],
			L["Chin up, {name}; take this. Somewhere in Stormwind, a bard writes about you."],
			L["Every ally counts, {name}. Today, you count double."],
			L["Anduin would want me to share, {name}, and I'd hate to disappoint him."],
			L["Take this, {name}. Stormwind's walls can't follow you, so this will have to."],
			L["Here, {name}. The gryphons get you there; this gets you back."],
			L["Alliance rule, {name}: keep your word, your walls, your friends. Here, friend."],
			L["Every ally deserves a lion at their back, {name}. I'm the nearest lion."],
			L["A gift from the Alliance, {name}. Signed, sealed and hand-delivered."],
			L["The Alliance never forgets the brave, {name}. Here; give it something to keep."],
		},
		group = {
			L["Together we stand, {name}, and share. For the Alliance!"],
			L["Right, {name}: take this, shields up, and nobody charges before the plan does."],
			L["The finest company the Alliance ever fielded, {name}. Best equipped, too, now."],
			L["Together, {name}, we're practically a regiment. A small, well-blessed regiment."],
			L["That's me watching your back, {name}. The Alliance was built by people who did."],
			L["Shields together, {name}, and take this. The Alliance never won in single file."],
			L["If this goes in the history books, {name}, let it say I blessed you first."],
			L["Take this, {name}. Whoever carries the banner gets painted looking noble."],
			L["Dwarven nerve, elven patience, human stubbornness, {name}, and a gift. Recipe."],
			L["Keep the lion roaring, {name}, with this in you. Softly, mind. We're sneaking."],
		},
	},
	Horde = {
		thanks = {
			L["Strength and honour, {name}. And kindness, it turns out. Repaid in full."],
			L["The Horde takes care of its own, {name}."],
			L["Strength given, strength returned, {name}. That's all of Horde diplomacy."],
			L["I'd carve your name on Orgrimmar's gates, {name}, but they're full. Thanks."],
			L["A goblin would've sent you an invoice, {name}. I'm sending this instead."],
			L["You did not have to do that, {name}. That is why the Horde remembers it."],
			L["In the Horde we do not say thank you twice, {name}. So: once, and meant."],
			L["In the Horde a debt is carried like an axe, {name}: openly, and not for long."],
			L["Thanks, {name}. The gate grunts will hear of it. They'll grunt. Means respect."],
			L["The Horde keeps two lists, {name}: grudges and favours. Yours is the short one."],
			L["Honour says repay you, {name}. Manners say smile. I'm working on the smile."],
			L["That landed softer than any zeppelin I've ridden, {name}. Thank you."],
			L["Thanks, {name}, in Orcish, Taur-ahe, Zandali and Gutterspeak. Pick one."],
			L["Thrall taught the Horde honour, {name}. Nobody had to teach you. Thank you."],
			L["You gave first, {name}. In the Horde that earns first cut of the roast. Here."],
			L["The Warchief can't thank everyone himself, {name}. He's delegated it to me."],
		},
		asked = {
			L["Consider it done, {name}. For the Horde, and for anyone who asks nicely."],
			L["You only had to ask, {name}. The Horde answers."],
			L["The Horde usually helps with axes, {name}. Today, {buff}."],
			L["Done, {name}. No speeches. The Horde has plenty of those already."],
			L["You asked, {name}. In Orgrimmar, that counts as a formal treaty."],
			L["Asking is no weakness, {name}. Refusing an ally would be."],
			L["No need to bang a war drum, {name}. You asked; it's done."],
			L["Of course, {name}. In the Horde, 'please' outranks everyone but the Warchief."],
			L["In Orgrimmar we'd have argued about it first, {name}. Tradition. Here."],
			L["Consider it requisitioned, {name}. The quartermaster needn't hear about it."],
			L["Done, {name}. If anyone asks, I scowled the whole time. I've a reputation."],
			L["Of course, {name}. Horde hospitality: rough edges, full helpings."],
			L["The Horde came together because somebody always said yes, {name}. Yes."],
		},
		offer = {
			L["For the Horde, {name}! Go with strength. I've just handed you some."],
			L["Go with honour, {name}, and with this. Victory awaits."],
			L["Take this, {name}; do something worth a song. Loud songs. The Horde likes loud."],
			L["Walk tall, {name}. The Horde made room for those the world turned away. Here."],
			L["Take this, {name}, and a word of Horde wisdom: hit first, apologise never."],
			L["Victory or death, {name}. I'd prefer victory, so take this."],
			L["Blood and thunder, {name}! Here's your thunder. Go and be it."],
			L["For the Horde, {name}, and for you. The Horde's big; you're closer."],
			L["Here, {name}. Stronger together, they say, and I've just done my half."],
			L["Carry this, {name}. It weighs less than a Horde banner and flies just as proud."],
			L["Here, {name}. The Horde feeds its own, arms its own, and now enchants them."],
			L["Take this, {name}. Whatever's out there is about to meet the Horde."],
			L["Here, {name}. Wherever you're headed, arrive looking like the Horde sent you."],
			L["The Crossroads never turned a traveller away, {name}. Nor do I. This is free."],
			L["The Horde raises you tough, {name}. This is for the days tough isn't enough."],
			L["Take this, {name}. A Horde gift: no ribbon, no speech, no refunds."],
			L["Stand tall, {name}, with this. Taller. The Horde has tauren to keep up with."],
		},
		group = {
			L["Our strength is each other, {name}. Here's some of mine. For the Horde!"],
			L["Forward, {name}, and take this. The Horde advances together. Retreats... never."],
			L["Together we're a war band, {name}. Apart, we're just loud. Take this."],
			L["Shoulder to shoulder, {name}, and blessed. Whoever charges first buys the grog."],
			L["Nobody gets left behind, {name}, or left out. I've counted us twice. Here."],
			L["Rule of the warband, {name}: nobody eats until everybody's back, and blessed."],
			L["Drums up, {name}, and take this. If we can't be quiet, we'll be terrifying."],
			L["The Horde never won a thing alone, {name}. Take this; let's not start now."],
			L["We fight like the Horde, {name}: all at once, nobody waits. So take this now."],
			L["Right, {name}. Spoils shared, blame shared, this shared. Glory to the loudest."],
			L["Look at us, {name}, all blessed. The Warchief would be proud. From a distance."],
			L["Tusks, horns, long ears, bare bone, {name}, all blessed. Finest warband going."],
			L["The war stories get bigger after, {name}. With this, give them a head start."],
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
			L["Thank you, {name}. I carry no banner, so both hands are free to return this."],
			L["The Steamwheedle stay neutral for gold, {name}. I return favours for free."],
			L["Neither side has taught me their thanks yet, {name}, so here's the plain kind."],
			L["Thank you, {name}. I stand between two great banners, and still you noticed me."],
			L["Two sides at war, {name}, and us being lovely right in the middle. Thank you."],
		},
		asked = {
			L["Gladly, {name}, whatever banner you fly. I don't even own a banner."],
			L["Certainly, {name}. I help everyone. It's the one thing I've decided."],
			L["Everyone asks me which side I'm on, {name}. Much nicer to be asked for help."],
			L["Of course, {name}. No war council to ask; just me, and I say yes."],
			L["Here you are, {name}. No oath, no colours, no fee."],
			L["I can't pick a side yet, {name}, but I can pick a good cause. This is one."],
			L["At once, {name}. I have no side to be on, so for now I am entirely on yours."],
			L["Of course, {name}. Nobody pays me to take sides, so I take requests instead."],
			L["Neutral does not mean unwilling, {name}. It means I help first and argue never."],
		},
		offer = {
			L["Friends can come from any side, {name}. Or from none, like me. Here."],
			L["Soon they'll hand us tabards, {name}. Until then, we look after each other."],
			L["I haven't chosen a side yet, {name}, so I'm being kind to both. Take this."],
			L["A gift with no strings, {name}. I don't even have a faction to tie them to."],
			L["Go on, {name}, with this. Two whole factions are waiting to argue over us."],
			L["No quartermaster yet, {name}, so nobody's counting. Have plenty."],
			L["Take this, {name}. Neutral ground travels with me; you're standing on some."],
			L["The Argent Dawn helps whoever needs it, {name}. I'm learning from the best."],
			L["Booty Bay's rule: no fighting on the docks, {name}. Mine: no refusing a gift."],
			L["The one thing both factions agree on, {name}. They just don't know it yet."],
			L["This goes with any tabard, {name}. I made sure by giving it no colours at all."],
			L["For you, {name}. Neither Orgrimmar nor Stormwind sent it. It works anyway."],
			L["Here, {name}. I belong to no nation yet, so I practise belonging to everyone."],
		},
		group = {
			L["Side by side, {name}, whatever comes. Take this."],
			L["No flag over this party, {name}, just us, and this. That's plenty."],
			L["One day we'll pick sides, {name}. Today we share this and pick fights together."],
			L["Whatever side the rest of the world is on, {name}, I'm on yours. Here."],
			L["Neutral in the war, {name}, but generous to this group. Take this."],
			L["They call us a neutral party, {name}. Nobody said it couldn't give gifts."],
			L["Take this, {name}. Whatever we fight today, it's nothing personal. Thorough."],
			L["One side in this party, {name}: ours. Smallest faction, best perks. Here."],
			L["No orders from any capital, {name}. We choose our road, and our gifts. Here."],
			L["No war to win today, {name}, just this one fight. And you've got this for it."],
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
		L["I was about to do that for you, {name}. Honestly. Here's proof."],
		L["Thank you, {name}. I'll sleep better tonight, and I sleep in a ditch."],
		L["Two good things today, {name}: your kindness, and the chance to return it."],
		L["You had me in your debt for all of three seconds, {name}. There."],
		L["Gratitude is best served quickly, {name}. Here it is, still warm."],
		L["Well, {name}, now I have to be a better person all day. Thanks for that."],
		L["Returned with a bow, {name}. A figurative one. My back isn't what it was."],
		L["Thank you, {name}. Somebody had to go first, and I'm glad it was you."],
		L["Thank you, {name}. You've rescued a day I'd written off at breakfast."],
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
		L["Of course, {name}. Nicely asked, gladly given."],
		L["Hold still, {name}. It works best on people who aren't fidgeting. So, nobody."],
		L["Here you are, {name}. I'd make you wait for effect, but that seems rude."],
		L["Yes, {name}. I'd have said it sooner if you'd asked sooner."],
		L["Say no more, {name}. Done before you finished asking."],
		L["There, {name}. Next time, don't ask; just stand near me looking hopeful."],
		L["Coming up, {name}. This is the one part of my day that goes to plan."],
		L["Asking nicely works, {name}. Tell everyone. The world could use the news."],
		L["At once, {name}. Stay put, or this lands on your shadow instead."],
	},
	offer = {
		L["Safe travels, {name}. {buff} packs lighter than a sword."],
		L["A small blessing for the road, {name}."],
		L["Go well, {name}, and take this. Come back in one piece."],
		L["No reason, {name}. It just felt like a {buff} sort of day."],
		L["Don't mind me, {name}. Just passing, with a spare {buff}."],
		L["Consider it a gift, {name}. I'd wrap it, but it glows through the paper."],
		L["Here, {name}. Pass it on when you meet someone who needs it."],
		L["Whatever brings you here, {name}, this should help it go better than planned."],
		L["Just being neighbourly, {name}. Very, very temporary neighbours."],
		L["You looked about to do something brave, {name}. Here, for that."],
		L["No need to stop, {name}. It works while you walk."],
		L["Nothing asked, nothing owed, {name}. Nothing to do but go and be splendid."],
		L["Call it a wager, {name}, that you'll do something worthwhile with it."],
		L["A gift from a passing stranger, {name}. The best kind, the old stories say."],
		L["It's rude to pass someone without a greeting, {name}. This is mine."],
		L["Same road as me, {name}? Then take this for the journey."],
		L["Take this, {name}. If today goes well, remember me. If badly, I was never here."],
		L["Hold still a moment, {name}. There. Best-prepared person in sight."],
	},
	group = {
		L["Everyone ready? You are now, {name}."],
		L["A little something for the party, {name}."],
		L["Stay close, {name}. We go further together, and further still with this."],
		L["House rules, {name}: nobody dies, nobody sulks, everybody gets one of these."],
		L["There, {name}. Now if this goes badly, it won't be my fault."],
		L["All set, {name}. I'd give a speech, but we'd be here all day."],
		L["Look after that, {name}. It's the only one I brought for you."],
		L["Now we look the part, {name}. Let's go and be it."],
		L["Fresh {buff} all round, {name}. The rest is luck and elbows."],
		L["Anyone have a plan, {name}? No? Mine was this. Wonderful. Onward."],
		L["One each, {name}. Don't swap; they're fitted."],
		L["Take this, {name}. Whoever starts the fight has to tell the story afterwards."],
		L["Good friends, sharp steel, {buff}. What else is there, {name}?"],
		L["For you, {name}. Stay where I can see you. I can't help what I can't find."],
		L["If this ends up a legend, {name}, I want a line in it: the one giving you this."],
		L["Brace yourselves, {name}. This helps. And each other, if it comes to that."],
		L["Chin up, {name}, and take this. Whatever's ahead has never met this lot before."],
		L["Here, {name}, to keep you in one piece. I'm only equipped for small repairs."],
		L["Well, {name}, with this on you we look ready. Let's go before we learn more."],
		L["Take this, {name}. If we get lost, we're exploring. Nobody scolds an explorer."],
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

-- A class's line that is about one of its spells, by the line, to that
-- spell's buff key: said only while that spell is the one going out (RP.Pick).
-- The warlock's lines were written when Unending Breath was a warlock's only
-- buff, and four are about water; on Mists a warlock hands out Dark Intent
-- (Buffs.lua: Automatic never casts Unending Breath there). Marked where they
-- stand rather than moved, since a pool's first lines are the box's examples.
RP.ABOUT = {}
local function About(key, text)
	RP.ABOUT[text] = key
	return text
end

-- The speaker's class (UnitClass's second return), by moment as the peoples'
-- lines are; a group member hears the offers when there are no group lines.
-- A class with no lines of its own simply has none here.
RP.CLASS = {
	MAGE = {
		thanks = {
			L["Thank you, {name}. I'd conjure a gift in return, but it would only be water."],
			L["Much obliged, {name}. I'll write it up properly later. Several pages."],
			L["Thank you, {name}. They never taught gratitude at Dalaran. I'm self-taught."],
			L["Kind of you, {name}. Everyone assumes mages need no help. We do."],
			L["Thank you, {name}. I nearly Counterspelled that on reflex. So glad I didn't."],
			L["Even a frost mage would thaw at that, {name}. Thank you."],
			L["Thank you, {name}. Noted in my spellbook, between Frost Nova and lunch."],
			L["Repaid at once, {name}, before I pass a bookshop. I've lost weeks that way."],
			L["Twenty years in the library, {name}, and no book said how to thank you. This."],
			L["Arcane theory says nothing comes free, {name}. Theory was wrong. Thank you."],
		},
		asked = {
			L["Of course, {name}. And yes, I suppose you'll want water as well."],
			L["As requested, {name}. I'll find my page again later."],
			L["At once, {name}. Carefully, too; I've blinked into two walls today."],
			L["Gladly, {name}. Knowledge should be shared. The Kirin Tor say so, reluctantly."],
			L["Certainly, {name}. I'll cast it slowly. The hand movements are the best part."],
			L["Of course, {name}. Think of it as homework, and I've done it for you."],
			L["Of course, {name}. Antonidas taught me this. He also taught me to duck."],
			L["At once, {name}. Arcane, not fire. I did check."],
			L["Certainly, {name}. It's this or a lecture on ley lines, and you've been kind."],
			L["You asked a mage, {name}. The spell is instant; the explanation is not."],
			L["I've cast this a thousand times, {name}. Nine hundred and ninety went well."],
			L["Certainly, {name}. Stand still. Fidgeters have been known to end up woolly."],
		},
		offer = {
			L["Here, {name}. I had a spare thought and nowhere to put it."],
			L["Take this, {name}. I'd add bread, but conjured bread tastes of nothing."],
			L["{buff} for you, {name}. No charge, unlike the portals."],
			L["Here, {name}. Most folk I point at turn into sheep. Today's your lucky day."],
			L["Nothing on fire, nothing frozen, {name}. I'm branching out."],
			L["For you, {name}. I was practising, and you happened to be the nearest head."],
			L["Here, {name}. Freshly cast, and hardly crackling at all."],
			L["Kings once hired Dalaran for this, {name}. You get it for nothing."],
			L["Take this, {name}. It wears off, unlike my last experiment."],
			L["For you, {name}: everything I learned in Dalaran, minus the essays."],
			L["Here, {name}. Arcane magic is best shared, before it gets ideas of its own."],
			L["Evocation takes an age, {name}, so I spend my mana where it counts. Here."],
			L["Here, {name}. A mage who walks past without helping is just a very tall hat."],
		},
		group = {
			L["Now that you're clever, {name}, stand between me and the angry things."],
			L["Take this, {name}. For the record, I only blink away when it's tactical."],
			L["This first, {name}. Water's on me after; please don't ask for it mid-fight."],
			L["Minds sharpened, {name}. I'll handle the fire, the frost and the panicking."],
			L["Here, {name}. If I say 'Frost Nova', run. If I say 'run', also run."],
			L["Take this, {name}. Pyroblast takes a while; interrupt it and it's personal."],
			L["Yours, {name}. If I ice-block, I'm not frozen with fear. It's on purpose."],
			L["This now, {name}; portals home after. Getting there alive is on all of us."],
			L["Take this, {name}. Anything you'd rather not fight, point at. Wool by teatime."],
			L["Here, {name}. I'll drop a Blizzard on them. Watch, but from outside it."],
			L["Take this, {name}. Keep them off me, and I'll keep them on fire."],
			L["That's for you, {name}. If I go quiet, it's Evocation, not sulking. Usually."],
			L["Take this, {name}. If it goes badly, I've a teleport home. I'd never use it."],
		},
	},
	PRIEST = {
		thanks = {
			L["How thoughtful, {name}. The Light keeps accounts; I settle mine early."],
			L["Thank you, {name}. I'll put in a good word with the Light. It owes me several."],
			L["Thank you, {name}. A small miracle, and I didn't even have to pray for it."],
			L["Thank you, {name}. My faith in people is restored. It was only resting."],
			L["Thank you, {name}. You're in tonight's prayers. Near the top."],
			L["Healers are rarely on this end of it, {name}. I'd forgotten how nice it is."],
			L["Thank you, {name}. You've saved me a prayer, and I'm always one short."],
			L["Thank you, {name}. I'd give a sermon on generosity, but you've just given it."],
			L["Thank you, {name}. I'll light a candle for you. Two. I'm feeling reckless."],
			L["Even my shadowy side is smiling, {name}. It has no face, so take my word."],
		},
		asked = {
			L["Of course, {name}. The Light keeps no hours, and neither, sadly, do I."],
			L["Straight away, {name}. Most prayers take longer; you've found a shortcut."],
			L["Certainly, {name}. The Light shines on those who ask. I just aim it."],
			L["With pleasure, {name}. Faith moves mountains; I'm starting smaller."],
			L["Of course, {name}. Confessions are extra, and I'd rather not hear them."],
			L["Of course, {name}. Nobody who asks goes without. The Light's rule, and mine."],
			L["Certainly, {name}. A warm glow means the Light. A cold one, tell me at once."],
			L["Of course, {name}. I'll pray it lasts. I'm told I have an in."],
			L["Certainly, {name}. I heal, I smite, I do funerals. This is the cheerful bit."],
		},
		offer = {
			L["Bless you, {name}. No, you didn't sneeze; I'm simply thorough."],
			L["Here, {name}. Think of it as a prayer that arrived early."],
			L["The Light asked me to pass this along, {name}. I'm paraphrasing."],
			L["Take this, {name}. It saves us both an awkward resurrection later."],
			L["Freely given, {name}. Faith costs nothing. The robes, sadly, did."],
			L["Here, {name}. Think of me as a small, walking temple. No steps to climb."],
			L["A blessing for a stranger, {name}. The Light insists there's no such thing."],
			L["Take this, {name}. No collection plate follows. Look: empty hands."],
			L["Here, {name}. I'd preach, but you look like somebody with somewhere to be."],
			L["Small mercies are my speciality, {name}. Here's one."],
			L["Here, {name}. I'd float over properly, but levitating in public draws a crowd."],
		},
		group = {
			L["Your turn, {name}. Now, I beg you all: make my job boring."],
			L["Everyone near me, {name}; the Light has a limited range. You're in it now."],
			L["There, {name}. If anyone falls, I'll be very disappointed, then fix it."],
			L["Done, {name}. I'll be at the back, praying loudly."],
			L["Here, {name}. If I scream, it's a spell and everything runs. Don't join in."],
			L["That's for you, {name}. If I Fade, I haven't gone. I'm just very uninteresting."],
			L["This one's on me, {name}. Shields come later, one each. Pace yourselves."],
			L["Take this, {name}. Let's all come back from this the usual way: walking."],
			L["That's me keeping you alive, {name}. You keep me from saying 'I told you so'."],
			L["I prayed over this group, {name}. The Light said 'good luck'. I'll take it."],
		},
	},
	DRUID = {
		thanks = {
			L["Thank you, {name}. I'd offer you berries, but I ate them all."],
			L["Thanks, {name}. Like rain in a dry season."],
			L["Much obliged, {name}. My cat form wants to bring you a rabbit. I've said no."],
			L["Thank you, {name}. I'll plant a tree in your honour. Give it a century."],
			L["Thank you, {name}. May your road stay green and your water sweet."],
			L["Kindly done, {name}. I felt that right down to my roots."],
			L["Nature returns everything eventually, {name}. I'm quicker. Thank you."],
			L["Barkskin keeps most things out, {name}. Kindness got straight through. Thanks."],
			L["Thank you, {name}. As a bear this would be a hug. Be glad I'm in this shape."],
		},
		asked = {
			L["Certainly, {name}. Give me a moment to remember which shape has hands."],
			L["Of course, {name}. Hold still, like an oak. Oaks are wonderful at it."],
			L["Gladly, {name}. The wild shares everything. Well, not the bears."],
			L["Right away, {name}. The wild's had a good season; it can spare this."],
			L["Of course, {name}. Nature doesn't take requests, but I do."],
			L["Gladly, {name}. Ask a tree and you'll wait a year. Ask a druid and it's now."],
			L["Of course, {name}. The balance tips a little your way. Don't tell the balance."],
			L["I'd have run over, {name}, but as a cheetah, and you'd have screamed. Here."],
			L["Of course, {name}. The wild is kind to all who ask. Midges excepted."],
		},
		offer = {
			L["Fresh from the Emerald Dream, {name}. Sorry if I yawn."],
			L["Take this, {name}. Nature provides, and I'm its errand runner today."],
			L["The wild calls you friend now, {name}. Handy, since most of it has teeth."],
			L["I'd have picked you flowers, {name}, but this keeps better."],
			L["Here, {name}. Cenarius would want you to have it. I'm nearly sure."],
			L["Here, {name}. For cold nights, sharp claws and long roads."],
			L["Take this, {name}. The wild has been watching you, and it's decided you'll do."],
			L["There, {name}. Walk lightly, and the forest will walk with you."],
			L["For you, {name}. The Moonglade sends its regards. It sends very few."],
			L["Nature is cruel, lovely and damp, {name}. This helps with two of those."],
			L["I tie strangers up in roots most days, {name}. This is the nicer part."],
		},
		group = {
			L["Ready, {name}? Take this. Now, whatever happens, nobody startle the bear."],
			L["There, {name}. I'll be the cat, the bear or, if we must swim, the seal."],
			L["Take this, {name}. I've one rebirth in me. Please, nobody make me choose."],
			L["Close ranks, {name}, and take this. The forest is watching, and rooting for us."],
			L["Here, {name}. I'll heal or I'll maul. Tell me which before it's urgent."],
			L["This is free, {name}. My one Innervate goes to the most desperate. No acting."],
			L["Take this, {name}. If I start glowing and hooting, that's moonkin. Serious."],
			L["For you, {name}. If it gets crowded, I'll call a Hurricane. Hold your hats."],
			L["We move like a herd, {name}, all blessed. Mixed herd. One is sometimes a bear."],
		},
	},
	PALADIN = {
		thanks = {
			L["Kindness, {name}? My favourite virtue. Just ahead of polishing."],
			L["For that, {name}, my best blessing. Not the second best. The best."],
			L["Virtue rewarded on the spot, {name}! I do love it when that happens."],
			L["Thank you, {name}. My oath says to repay kindness. I'd do it anyway."],
			L["I'll judge you favourably, {name}. I judge most things harshly. Thank you."],
			L["Thank you, {name}. My aura just brightened. It does that when I'm touched."],
			L["A kindness, {name}! I'll have it engraved on my shield, beside the dents."],
			L["Much obliged, {name}. My warhorse sends thanks as well. He's more reserved."],
			L["I swore to protect the good, {name}. You've just gone to the top of the list."],
		},
		asked = {
			L["By the Light, {name}, of course! I've been hoping somebody would ask."],
			L["You have my blessing, {name}, in every sense."],
			L["Certainly, {name}. Kneel if you like. I won't insist. I'll be delighted."],
			L["Gladly, {name}. I never run short of blessings. Mana, now and then."],
			L["Certainly, {name}. Hold still. My aim is righteous; my gauntlets are clumsy."],
			L["Gladly, {name}. Helping is the oath. Shining while I do it is a bonus."],
			L["Of course, {name}. Stand fast, chin up, and look deserving. There. You do."],
			L["Of course, {name}. You'd be amazed how rarely anyone asks the tin can for help."],
			L["Of course, {name}. A moment while I pick the blessing. I do have favourites."],
		},
		offer = {
			L["The Light asks nothing in return, {name}. I, however, accept thanks."],
			L["Go with the Light, {name}. I'll be right behind you, clanking."],
			L["The blessing's free, {name}. You've been spared the sermon. This time."],
			L["There, {name}. It won't last forever, so be heroic while it does."],
			L["Stand tall, {name}. The Light walks with you, and it has excellent posture."],
			L["Take this, {name}. I'd give you my hammer too, but it's very attached to me."],
			L["Blessings are for handing out, {name}. Hoarding them is frowned upon. By me."],
			L["Justice for the wicked, blessings for the rest, {name}. You're the rest."],
			L["Take this, {name}. My libram says to share. It says a lot; this bit I like."],
			L["Chivalry isn't dead, {name}. It's in heavy armour, and it brought you this."],
			L["Wear it with pride, {name}. Pride's a sin, but only in large amounts."],
		},
		group = {
			L["You're blessed, {name}. Keep behind my shield and we'll do fine."],
			L["Stand fast, {name}, blessed. We have the Light, and I have a very large hammer."],
			L["One blessing each, {name}. The Light is generous, but it insists on turns."],
			L["Splendid, {name}, you're blessed. Don't look at me. I'm rather bright today."],
			L["That's my blessing, {name}. Stay inside my aura too. It's warmer than it looks."],
			L["Take this, {name}. If I stun something, hit it while it's thinking things over."],
			L["Blessed, {name}. The glowing ground is mine too; stand in it. It bites them."],
			L["Take this blessing, {name}. I judge them, you sentence them. Efficient court."],
			L["Blessed, {name}. If I shout 'for the Light', it means charge. Or pray. Or both."],
			L["Armour polished, hammer blessed, {name}, and now you too. My horse is sulking."],
			L["That's your blessing, {name}. Mine is Righteous Fury. Let them come to me."],
		},
	},
	WARLOCK = {
		thanks = {
			L["How kind, {name}. My imp says thank you too. He's lying, but I'm not."],
			L["Thank you, {name}. It's been ages since anyone gave me something uncursed."],
			L["Thank you, {name}. I'll repay you with something I didn't find in a crypt."],
			L["Most gracious, {name}. I've asked the voidwalker to stop looming at you."],
			L["Thank you, {name}. Most folk cross the road when they see me."],
			L["No blood, no bargain, no binding, {name}? What a strange way to trade. Thanks."],
			L["Thank you, {name}. Should anything haunt you, send it my way."],
			L["How thoughtful, {name}. Everything I'm given, I return. Except souls. Here."],
		},
		asked = {
			L["Of course, {name}. No soul required. This time."],
			L["You asked a warlock for help, {name}. Bold. I like you already."],
			L["Of course, {name}. The imp offered to help, and I said no, for all our sakes."],
			L["Certainly, {name}. Of all my spells, this is the one I can do at parties."],
			L["Gladly, {name}. A good deed on my record; the Shadow Council would be appalled."],
			L["Of course, {name}. Please don't read the book I'm holding. For your own sake."],
			L["Certainly, {name}. Feel watched? That's only the Eye of Kilrogg. Hold still."],
			L["Of course, {name}. I only curse people who don't ask nicely. You're quite safe."],
			L["Yes, {name}, it's the one without screaming. Hold still."],
			About("breath", L["Of course, {name}. Going somewhere wet? I won't ask. Warlocks never ask."]),
		},
		offer = {
			L["Here, {name}. Don't ask where it came from. Really, don't."],
			About("breath", L["Fall in a lake someday, {name}, and you'll think of me fondly."]),
			About("breath", L["Breathe easy, {name}. I'd hate to lose you to anything as dull as water."]),
			L["Here, {name}. You'll want a soulstone too, but that's a bigger conversation."],
			L["Take this, {name}. It's the only spell of mine the priests approve of."],
			L["Take this, {name}. My mother still thinks I'm a mage. Let's keep it that way."],
			L["Here, {name}. It isn't green, it doesn't whisper, and it won't follow you home."],
			L["Here, {name}. Dark magic, used for good. Do tell my old tutor; he'll hate it."],
			L["Here, {name}. I keep the darker spells for people who've earned them."],
			L["Here, {name}. I'm not all curses and fear. Mostly, but not all."],
			L["My grimoire has a chapter on kindness, {name}. It's short, but I've read it."],
		},
		group = {
			L["Everyone ready, {name}? Souls intact? Take this; let's keep it that way."],
			L["Take this and stay close, {name}. The voidwalker takes hits; I take the credit."],
			About("breath", L["Swim all you like, {name}. If anyone drifts off, I'll summon them back."]),
			L["Do pet the felhunter, {name}. Just take your spells off first."],
			L["For you, {name}. If I fear something, don't chase it. It comes back angrier."],
			L["I trade blood for mana, {name}, and mana for this. It looks worse than it is."],
			L["This now, {name}; healthstones after. For a crisis, mind, not as a snack."],
			L["Take this, {name}, and keep clear when I cast Hellfire. I burn too. Tragic."],
			L["That's from me, {name}, not the imp. He's on fire, and ours. Don't douse him."],
			L["Take this, {name}. If something green falls from the sky, that's mine. Cheer."],
		},
	},
	WARRIOR = {
		thanks = {
			L["Thank you, {name}! Sorry, was that loud? I only have the one volume."],
			L["Much obliged, {name}. No spells to give back, but I do a very sincere shout."],
			L["Thanks, {name}. Now I'm twice as angry. In the good way."],
			L["Thanks, {name}. You've earned a place right behind me. Safest spot there is."],
			L["Thank you, {name}. Kindness makes me soft. Luckily I've plenty of armour."],
			L["Thank you, {name}. My armourer thanks you too. I paid for his house."],
			L["Thanks, {name}. I'd bandage something for you, but you look annoyingly fine."],
			L["Thank you, {name}. I switched to my grateful stance for that. It's rarely used."],
			L["You've given me magic, {name}. No idea where to keep it. I'll wear it. Thanks."],
			L["Owing folk makes me restless, {name}, and restless makes me charge things."],
		},
		asked = {
			L["You want a shout, {name}? I was going to shout anyway."],
			L["Of course, {name}. A fighter who asks for courage already has some."],
			L["Right away, {name}. Square your shoulders. There, that's half of it."],
			L["Happily, {name}! Go hit something for me."],
			L["Right, {name}. Deep breath. Not you. Me."],
			L["Happy to, {name}. First request today that didn't involve lifting something."],
			L["Coming up, {name}. Plant your feet. This one has a kick to it."],
			L["Of course, {name}. Most folk only ask me to stop. This is a nice change."],
			L["Of course, {name}. Took me years to learn. Years of yelling at trees, mostly."],
		},
		offer = {
			L["Consider yourself shouted at, {name}. Affectionately."],
			L["No incense, no prayers, {name}. Just me, shouting encouragingly."],
			L["Chin up, {name}, and take this! If anything bothers you, I'll charge it."],
			L["There, {name}! Anything that doesn't feel braver now wasn't listening."],
			L["Here, {name}, some courage. Spend it freely; I've plenty more."],
			L["Here, {name}. Something sharper than a whetstone: morale."],
			L["Take this, {name}. Warriors don't carry spells, so we carry each other."],
			L["Here, {name}. You look about to walk into something big. Walk in harder."],
			L["Here, {name}. No magic in it. Just a warrior believing in you, very firmly."],
			L["Take this, {name}. It's loud, it's free, and I mean it."],
			L["Here, {name}. Tell whatever you fight that a warrior vouched for you."],
			L["That one was for you, {name}. The next one's for whatever's in your way."],
		},
		group = {
			L["Listen up, {name}! That's it. That was the whole speech."],
			L["Take this, {name}. Where's the danger? Never mind, I'll find it. Face first."],
			L["Right, {name}! Take this. I go first, shout loudest; nobody touches the healer."],
			L["Everybody angrier? Good. Onward, {name}, and mind my backswing."],
			L["Here, {name}. I need hitting before I'm useful. Don't panic when it happens."],
			L["This first, {name}. Bandages are in my pack too; I tied the knots. Very secure."],
			L["Right, {name}: take this. I take hits, you take credit, we split the repairs."],
			L["For you, {name}. If I go red and quiet, that's Berserker Rage. Loud is fine."],
			L["Take this, {name}. My shield's seen worse than this. So has my face. Onward."],
		},
	},
	DEATHKNIGHT = {
		thanks = {
			L["The living rarely lend me much, {name}. I'll be prompt, in case it catches on."],
			L["Thank you, {name}. I owe you one fight at your side, on a day of your choosing."],
			L["The skulls came with the armour, {name}. The gratitude is all my own."],
			L["My one healing spell only mends the dead, {name}. Do stay healthy. Thank you."],
			L["Your kindness is safe with me, {name}. Very little else is. Thank you."],
			L["I've stood at the runeforge all night for less than that, {name}. Thank you."],
			L["The Ebon Blade answers courtesy in kind, {name}, and insults with the blade."],
			L["Tonight's watch will pass quicker for that, {name}, and I keep a great many."],
			L["Thank you, {name}. Ride with me a while, if your horse will stand next to mine."],
			L["Thank you, {name}. I'll have the dead salute you. Badly, but with feeling."],
		},
		asked = {
			L["Very well, {name}. Stand fast; the horn is loud, and the cold follows it."],
			L["Of course, {name}. Most of what I do is quick or final. This is the quick kind."],
			L["You have my horn and my word, {name}. One is louder; the other lasts longer."],
			L["Of course, {name}. Mind the runeblade. It doesn't know you yet."],
			L["Gladly, {name}. I'd far rather sound a horn for a friend than a dirge."],
			L["At once, {name}. A knight who makes an ally wait isn't worth their runes."],
			L["Yes, {name}. Step into view; this helm was made for glaring, not for looking."],
			L["The Ebon Blade serves the living now, {name}. Even the impatient ones."],
			L["Of course, {name}. Pay no mind to the frost on your boots. It brushes off."],
			L["The paladins at Light's Hope ask far more stiffly, {name}. They still get it."],
		},
		offer = {
			L["Hear that, {name}? Winter, on your side for once."],
			L["The horn sounds for you, {name}. It used to sound only for the Scourge."],
			L["Take this, {name}, and advice from a death knight: never fight fair, nor alone."],
			L["Acherus floats over the Plaguelands, {name}. It's good to come down and help."],
			L["The road's dark, {name}; I'm usually the darkest thing on it. Take this along."],
			L["You looked a little short of an army, {name}. A horn is the next best thing."],
			L["Here, {name}. My ghoul wanted to say hello. I've spared you that."],
			L["Take this, {name}. Cold, loud and well meant, like most of my order."],
			L["Whatever waits out there, {name}, I've likely killed its cousin. Take this."],
			L["Take this and keep moving, {name}. Trouble tends to follow death knights about."],
		},
		group = {
			L["Take this, {name}. If I raise an army, be civil. They didn't ask to be here."],
			L["That's for you, {name}. Walk where I walk; the frost holds us up over any lake."],
			L["For you, {name}. If I look hurt, let me hit something. That's how I mend."],
			L["Take this, {name}. My ghoul goes in first. He won't mind. Long past minding."],
			L["Here, {name}, to keep up. The dead don't tire, and I forget the living do."],
			L["Take this and don't fall, {name}. I can bring you back, but it's unsettling."],
			L["That's for you, {name}. Leave the fevers to me; they spread on their own."],
			L["The horn has sounded, {name}. Whatever heard it knows we're coming."],
			L["Take this, {name}. Whatever we kill today stays dead. I'll see to it myself."],
			L["Take this, pick a target, {name}, and I'll pick it too. Shorter arguments."],
		},
	},
	MONK = {
		thanks = {
			L["Take a gift with both hands, my master said, {name}. And return it with both."],
			L["Thank you, {name}. I feel light enough to run up a waterfall. I may try."],
			L["I meditated on generosity for years, {name}. You skipped to the end. Thank you."],
			L["I came out into the world to find good people, {name}. That's one. Thank you."],
			L["The masters at the Peak of Serenity would bow to that, {name}. So do I."],
			L["Kindly done, {name}. The next brigand who jumps me gets one kick fewer."],
			L["A kindness is like a strike, {name}: it's all in the timing. Yours was perfect."],
			L["Thank you, {name}. These hands were trained to strike. Today they get to give."],
			L["Thank you, {name}. Answered the monk's way: no wasted motion, no wasted words."],
			L["Gratitude makes even a monk clumsy, {name}. Forgive the elbows. Thank you."],
		},
		asked = {
			L["Of course, {name}. My master took a year to teach me this. I'll take a moment."],
			L["One of the old legacies, {name}, handed down to me and now to you."],
			L["Nothing calms the mind like being useful, {name}. You've done me a favour."],
			L["Of course, {name}. My hands know this one by heart. I just tell them who."],
			L["At once, {name}. The fist is for foes; the open palm is for friends."],
			L["Of course, {name}, one moment. Mid-form; bad luck to stop on the left foot."],
			L["Gladly, {name}. I was only standing still to see what it felt like."],
			L["At once, {name}. If you blinked, you missed it. That's fine; it's on you now."],
			L["Of course, {name}. It costs me a breath and a moment, and I've plenty of both."],
			L["Of course, {name}. Ask me every day, if you like. Monks love a routine."],
		},
		offer = {
			L["I passed you twice on my morning run, {name}. The third time, I stopped. Here."],
			L["Your stance says long day, {name}. Monks notice. Take this."],
			L["A monk gives before being asked, {name}. It saves us both the bowing."],
			L["Take this, {name}. My master said one kind act before every meal. I'm hungry."],
			L["Kindness is the hardest stance to hold, {name}. I'm practising. Here."],
			L["I practised patience by not giving you this, {name}. I lasted three heartbeats."],
			L["Take this, {name}, and be gentle out there. Unless a hozen starts it."],
			L["A calm mind finds the road, {name}. This should keep you steady on it."],
			L["The Last Emperor left Pandaria a legacy, {name}. I'm leaving you a small one."],
			L["For you, {name}. No lesson attached. My masters would be appalled."],
		},
		group = {
			L["For your feet, {name}. Stay light on them; a heavy step is an easy target."],
			L["Take this, {name}. If they surround us, I'll spin. Stand back; I'm not tidy."],
			L["Fight from your centre, {name}. If you can't find yours, borrow mine."],
			L["Take this, {name}. If one freezes mid-swing, that's me. Leave it till last."],
			L["That's for you, {name}. You go high, I'll go low. Nobody guards both at once."],
			L["Ready, {name}? Take this. Loose shoulders, soft knees, firm intentions."],
			L["Take this, {name}. Any weapon I take off them stays taken. They held it badly."],
			L["Here, {name}. Leave the runners to me. Nothing outruns a monk with a grudge."],
			L["Take this, {name}. If I end a fight with one touch, don't ask. It took years."],
			L["This steadies the temper, {name}. Anger opens a door, and the Sha walk in."],
		},
	},
	EVOKER = {
		thanks = {
			L["That was well cast, {name}. I would know. Thank you."],
			L["I have studied fire, time and the Dream, {name}. You still surprised me."],
			L["Dragons give big gifts slowly, {name}. Yours was small and quick. I prefer it."],
			L["I'll dip a wing to you when I next fly over, {name}. Watch for it."],
			L["I've known dragons with worse manners, {name}, and some of them were Aspects."],
			L["Thank you, {name}. I answer in kind, with magic older than your kingdoms."],
			L["Thank you, {name}. I'm delighted. You can tell by the faint smoke."],
			L["Generous, {name}, and not a trace of showing off. I must learn that part."],
			L["Thank you, {name}. Returned at once. My aim is perfect; my patience is not."],
			L["Thank you, {name}. I shall cite you, should I ever write a treatise on manners."],
		},
		asked = {
			L["Gladly, {name}. Help from a dragon once took a quest. Things have improved."],
			L["Hold still, {name}. Or hover, if you are able. No? Standing will do."],
			L["Watch closely, {name}. My casting is said to be a joy to watch. Mostly by me."],
			L["It would be my pleasure, {name}. Truly. I don't say 'truly' lightly."],
			L["Of course, {name}. Magic this old ought to be spent kindly, and you qualify."],
			L["Of course, {name}. Ask again tomorrow; I'll have improved it overnight."],
			L["You need only ask, {name}. I am curious how it will look on you."],
			L["Certainly, {name}. Think of something calm. Not dragons."],
			L["On the Forbidden Reach we practised on rocks, {name}. You are an improvement."],
			L["Of course, {name}. You're standing exactly where I'd have put you. Well done."],
		},
		offer = {
			L["Take this, {name}. I meant to explain the spell first. Too late now."],
			L["For you, {name}. Unasked, unearned and entirely deserved. Draconic logic."],
			L["I spotted you from afar, {name}. Evokers have sharp eyes and little restraint."],
			L["Evokers study for years to cast this well, {name}. You need only stand there."],
			L["You'll be glad of this soon, {name}. Don't ask how I know. Bronze business."],
			L["I could be flying right now, {name}, and instead I'm helping you. Do take note."],
			L["Here, {name}. Old magic, new caster. We're both doing rather well."],
			L["Not my grandest spell, {name}, but the one I'd most like to be known for."],
			L["I have read about heroes, {name}. You look like the early chapters. Take this."],
			L["Magic can't stay up in the sky, {name}. Sooner or later it lands on somebody."],
		},
		group = {
			L["Take this, {name}. If I seize you and fly, it is a rescue, not an abduction."],
			L["That's for you, {name}. I fight from a little way back. The view is better."],
			L["Take this, {name}, and leave their spellcasters to me. Their technique offends."],
			L["Hold the line, {name}, with this. I'll be the bright thing over your shoulder."],
			L["Take this, {name}. Dragons fight in three dimensions; enemies rarely look up."],
			L["I've made you all a little more than you were, {name}. The rest is up to you."],
			L["Here, {name}. If I take a long breath, do not startle me. It is still growing."],
			L["Fight well with this, {name}. I am taking notes on how mortals do it. Loudly."],
			L["Time is on our side, {name}. I have checked with it, and borrowed some for you."],
			L["Take this, {name}, and try to keep up. Not showing off; flying is just quicker."],
		},
	},
	SHAMAN = {
		thanks = {
			L["Rain, fire and a rockslide this week, {name}. That was the first gentle thing."],
			L["The fifth element is spirit, {name}, and yours is a generous one. Thank you."],
			L["Thank you, {name}. The rain can wash everything off me today but that."],
			L["Earth is patient and fire is not, {name}. My thanks takes after fire."],
			L["Most days I speak for the elements, {name}. Today's thanks are my own."],
			L["Thank you, {name}. The elements answer need, not rank. So, it seems, do you."],
			L["The Earthen Ring mends the world a crack at a time, {name}. You've mended one."],
			L["Water carves canyons by never giving up, {name}. I'll repay you the same way."],
			L["Lightning is quick, {name}, but never thoughtful. You were both. Thank you."],
			L["Thank you, {name}. The ground felt steadier under me for that."],
		},
		asked = {
			L["Of course, {name}. I'll ask the sky. It rarely says no to me."],
			L["Feet on the earth, eyes on the sky, {name}. What you asked for, they give."],
			L["Gladly, {name}. Thunder takes a moment to arrive. I don't."],
			L["Gladly, {name}. A shaman who won't share the storm has no business calling it."],
			L["Of course, {name}. Lightning can be gentle. It just prefers not to be."],
			L["Of course, {name}. Let me apologise to the wind for borrowing it. There."],
			L["Gladly, {name}. Calling the wind is easy. Steering it is the trick."],
			L["We serve the elements and they serve the world, {name}. You're in it."],
			L["Gladly, {name}. Mind your hair; the air gets lively."],
			L["Of course, {name}. You'll smell of rain for an hour. Everyone I help does."],
		},
		offer = {
			L["The sky has a little fury to spare, {name}. Take some."],
			L["Take this, {name}. The storm doesn't know you yet, but I've introduced you."],
			L["A storm at your back for once, {name}, instead of in your face."],
			L["Here, {name}. I don't hand storms to just anyone. You've the shoulders for it."],
			L["Rain for the crops, storm for the fight, {name}. You look more like a fight."],
			L["Here, {name}. If you hear thunder later, it isn't weather. It's encouragement."],
			L["From four elements and one shaman, {name}. The shaman did the walking."],
			L["Walk well with this, {name}. The earth holds up everybody, but it likes you."],
			L["I'd give you fair weather, {name}, but the sky only lends me the stormy kind."],
			L["Here, {name}. Thank the next clean stream you drink from. It's listening."],
		},
		group = {
			L["Take this, {name}. If I fall, wait. The spirits sometimes send me back."],
			L["Earth below, sky above, {name}, us between, and this on you. Keep that order."],
			L["Take this, {name}. If I call up an elemental, be polite. They hold grudges."],
			L["That's for you, {name}. Let them bunch together. Lightning loves a crowd."],
			L["This is a taste, {name}. When I call the storm into your blood, you'll know it."],
			L["The wind picked our side today, {name}, and asked me to give you this."],
			L["The elements favour the polite, {name}, and gave you this. Thank the rain."],
			L["Take this, {name}. We're a small storm. Small storms still knock down fences."],
			L["That's from me, {name}, not the totems. Don't kick them. The fire one sulks."],
			L["Take this, {name}. A river in the way? Don't go round. I'll have us walk on it."],
		},
	},
}

-- About the spell going out, whichever moment it is, by the entry's buff key
-- (Buffs.lua). A spell with no lines here simply has none.
RP.SPELL = {
	intellect = {
		L["A sharper mind for you, {name}. Mine cost me an eyebrow in Dalaran."],
		L["A clearer head for you, {name}. What you fill it with is your own affair."],
		L["Thoughts humming, {name}? Normal. If they hum back, come and find me."],
		L["A little arcane for your thoughts, {name}. Keep the change."],
		L["Brilliance, bottled, {name}. The Kirin Tor would charge you for the bottle."],
		-- On retail it goes to warriors and rogues too: a line for whoever.
		L["Sharper wits, {name}. Spend them on spells, locks or riddles; I won't judge."],
		L["On loan from the Violet Citadel, {name}. Late returns are fined in sheep."],
		L["Clever enough to spot the trap now, {name}. Avoiding it is a separate spell."],
		L["There, {name}. Wiser already: look, you're standing further from me."],
		L["The one spell of mine that's never set anything alight, {name}. Enjoy."],
		L["A gnome's instructions make sense now, {name}. Still don't follow them."],
	},
	fortitude = {
		L["Fortitude, {name}: a priest's polite way of saying 'stand in front'."],
		L["Every bit of stamina is one less panicked prayer from me, {name}."],
		L["Tougher already, {name}. Please don't take that as a dare."],
		L["There are other Power Words, {name}. 'Shield', and in emergencies, 'Run'."],
		L["Sturdier now, {name}. Falls, bears and bad decisions all hurt a bit less."],
		L["{buff}, {name}. Three words where 'be tougher' would do."],
		L["A little more of you to go round, {name}. Spend it slowly."],
		L["Harder to knock down now, {name}. The ground will miss you."],
		L["Stubbornness, really, {name}. Dwarves are born with it; the rest of us pray."],
		L["The only armour that never needs repairing, {name}. The smiths hate it."],
	},
	spirit = {
		L["Consider your spirits lifted, {name}. Divinely, as it happens."],
		L["Like a good night's sleep, {name}, without all the lying down."],
		L["A second helping of spirit, {name}. The Light always insists on seconds."],
		L["Keep your spirit where it is, {name}. Loose ones wander off."],
		L["Cheer up, {name}. That's not advice this time; it's a spell."],
		L["Recover faster, {name}, from long fights and longer walks."],
		L["A deep breath's worth of calm, {name}, without having to take one."],
		L["The Light's own second wind, {name}. Don't waste it on arguments."],
	},
	shadow = {
		L["Proof against shadow, {name}. I know its tricks; I've borrowed a few."],
		L["Should the Void call, {name}, you can now pretend you're out."],
		L["For when the dark gets personal, {name}. It usually does."],
		L["The shadows will have to knock first now, {name}."],
		L["The dark still bites, {name}, but now it has to chew."],
		L["A lining against the dark, {name}. Like a cloak, only on the inside."],
		L["Curses slide right off you now, {name}. The cultists will take it personally."],
		L["Priests study the Shadow to guard against it, {name}. Mostly."],
		L["For crypts, cults and Scholomance, {name}. The dark gets chatty in all three."],
		L["It won't keep off gloom, {name}. For that you want company. Here I am."],
	},
	motw = {
		L["Marked by the wild, {name}. The deer will tip their antlers as you pass."],
		L["You may smell faintly of moss, {name}. That's how you know it's working."],
		L["Mark of the Wild, {name}. The wolves will still bite, but they'll feel bad."],
		L["The wild's own seal of approval, {name}. The squirrels were consulted."],
		L["A little of the wild in you now, {name}. Resist the urge to howl."],
		L["Hide, claw and a thick coat, {name}. The wild packs light but thorough."],
		L["Cenarius signs every one of these, {name}. Well, a tree does, on his behalf."],
		L["The forest's own armour, {name}. It doesn't clank, and it smells of rain."],
		L["A tougher hide in seconds, {name}. The oaks took centuries and are furious."],
		L["It's a loan from the wild, {name}. Try not to bring it back chewed."],
	},
	thorns = {
		L["Anything that bites you now gets a mouthful, {name}."],
		L["Let the boar charge, {name}. It'll leave with regrets and splinters."],
		L["Like a rose, {name}: lovely to look at, a mistake to grab."],
		L["Thorns, {name}. I grew them myself, so do be polite to them."],
		L["A hedge you can wear, {name}. Neatly trimmed; I'm not a barbarian."],
		L["Nature never turns the other cheek, {name}. It grows spikes on it."],
		L["Raptors learn slowly, {name}. This teaches them one bite at a time."],
		L["Prickly on the outside, {name}. What's inside is your own business."],
		L["Mind your cloak, {name}. Wool and brambles never did get along."],
	},
	kings = {
		L["Blessing of Kings, {name}. No crown, no throne, no taxes owed."],
		L["Long may you reign, {name}. For the next while, anyway."],
		L["A little more of everything, {name}. Kings never did settle for less."],
		L["A king's blessing, {name}. Worn by better heads than mine, and some worse."],
		L["Every strength a little higher, {name}. Kings like to hedge their bets."],
		L["Crown not included, {name}. Everything else is, a little."],
		L["All of you, only more so, {name}. Wear it well."],
		L["A blessing fit for royalty, {name}. You'll have to do your own waving."],
		L["Stronger, cleverer, hardier, {name}. Kings had advisers for that; you have me."],
		L["Royal treatment, {name}, minus the courtiers and the poisoned wine."],
	},
	might = {
		L["Might doesn't make right, {name}, but it does help the argument."],
		L["A firmer swing for you, {name}. The Light loves a good follow-through."],
		L["Stronger arms, {name}. Kindly point them at something that deserves it."],
		L["Blessing of Might, {name}. It'll surprise you. It'll surprise them far more."],
		L["Swing away, {name}. The Light will take the credit if it goes well."],
		L["Hit harder, {name}. Them, I mean. Not me. Never the paladin."],
		L["More weight behind every swing, {name}. The Light calls it conviction."],
		L["Doors, crates and ogres will all give way easier now, {name}."],
		L["Your weapon will feel lighter, {name}. It isn't. You're just holier."],
		L["The Light's own elbow grease, {name}. Put it somewhere useful."],
	},
	wisdom = {
		L["Wisdom for you, {name}. I kept a little back for myself. Very little."],
		L["Wisdom for your mana, {name}. The other kind still comes from bad decisions."],
		L["Your mana creeps back on its own now, {name}, like a cat that's forgiven you."],
		L["Fewer sips between fights, {name}. The innkeepers will be heartbroken."],
		L["Drink less, cast more, {name}. The Light's own budget advice."],
		L["Blessing of Wisdom, {name}: the one blessing that pays for itself."],
		L["A steadier well to draw from, {name}. Draw deep."],
		L["Wisdom usually comes with age, {name}. This comes with a paladin. Quicker."],
		L["May you know when to fight and when to sit down, {name}."],
		L["A wise blessing for a wise choice, {name}: keeping a paladin around."],
	},
	salvation = {
		L["A blessing of quiet, {name}. Monsters will forget whose fault it was."],
		L["Blessing of Salvation, {name}. You are now somebody else's problem."],
		L["Saved, {name}. Not your soul, mind. Just your hide."],
		L["Hit hard, {name}. If anything turns round, look innocent. The Light will."],
		L["The monsters will find you forgettable now, {name}. Today, that's a compliment."],
		L["Go on, hit it, {name}. It'll blame whoever's wearing the most plate."],
		L["The art of being in the fight, {name}, and out of the argument."],
		L["The Light's kindest alibi, {name}. Use it often."],
	},
	light = {
		L["The Light will find you easier now, {name}. Try not to squint."],
		L["Holy Light lands harder on you now, {name}. Please don't make me prove it."],
		L["You'll heal easier, {name}. The Light appreciates a willing patient."],
		L["Blessing of Light, {name}. Saving you is simpler now. Not that you'll need it."],
		L["The Light knows the way to you now, {name}. Let's keep its visits social."],
		L["A blessing that makes my job easier, {name}. Generous and lazy all at once."],
		L["Holy Light fits you better now, {name}, like a well-cut tabard."],
		L["Mending you just got cheaper, {name}. Not that I'd ever send a bill."],
	},
	sanctuary = {
		L["Block a blow now, {name}, and the Light hits back for you. It's petty."],
		L["Every blow lands softer now, {name}. Complaints go to the Light."],
		L["All the shelter of a temple, {name}, and none of the roof repairs."],
		L["Claim sanctuary, {name}. It's easier when you bring your own."],
		L["Every blow is a little less rude now, {name}. The Light teaches manners."],
		L["Nobody can evict you from this sanctuary, {name}. I checked the deeds."],
		L["An ogre's club lands like a pillow now, {name}. A heavy, angry pillow."],
	},
	battleshout = {
		L["Instructions, {name}: hit things harder. There is no page two."],
		L["Your sword arm is sorted, {name}. For the rest of you, see a priest."],
		L["Battle Shout, {name}. Not a spell, really. A strongly worded suggestion."],
		L["RAAAGH! That one was for you, {name}. Everyone else just overheard."],
		L["Priests pray, mages study, {name}. I clear my throat, and you stand taller."],
		L["Words matter, {name}. Mostly the loud ones. That one was for you."],
		L["The shout lasts a few minutes, {name}. The ringing in your ears, rather longer."],
		L["There were words in that shout once, {name}. They slowed it down."],
	},
	breath = {
		L["A little breath from the damned, {name}. They weren't using it."],
		L["Unending Breath, {name}. The fish will have so many questions."],
		L["Stay down as long as you like, {name}. The air's on me."],
		L["Swim deep, {name}. If a murloc asks, you're only visiting."],
		L["Air from a place where air isn't strictly air, {name}. Breathe it anyway."],
		L["The Vile Reef awaits, {name}. Breathe easy down there; I've seen to it."],
		L["Dropped something in a lake, {name}? Now's your chance."],
		L["No gills, {name}. I read the small print; gills were extra."],
	},
	commandingshout = {
		L["An order, {name}: stay standing. Your bones heard it, even if you didn't."],
		L["Grit is a habit, {name}. I've lent you a few years of mine."],
		L["I command, you endure, {name}. The shortest chain of command in any army."],
		L["Officers order from the back, {name}. I shout from the front, so you hold on."],
		L["A good shout can hold a line together, {name}. A line of one is easy."],
		L["I learned this drilling recruits, {name}. They hated me, and they all lived."],
		L["One shout's for hitting, {name}. This one's for being hit and not minding."],
		L["Most fights go to whoever lasts longest, {name}. Today, that's you."],
	},
	hornofwinter = {
		L["This horn once sounded for a worse master, {name}. It much prefers you."],
		L["I can't runeforge your weapon, {name}, but the horn comes close."],
		L["All Northrend's cold in a single note, {name}. Swing while it's still ringing."],
		L["I'd play something cheerful, {name}, but this horn only knows the one note."],
		L["Winter took me once, {name}. Now it comes when I call, and it comes for you."],
		L["The Ebon Blade charges when this sounds, {name}. Today you charge with us."],
		L["Cold enough to wake the dead, {name}. I would know. It'll wake you up, too."],
		L["No warm words from me, {name}. Cold ones carry further, and carry strength."],
	},
	emperor = {
		L["Shaohao cast out his doubt and fear, {name}. What he kept, I pass to you."],
		L["Shoulders down and jaw loose, {name}. Now it can settle in properly."],
		L["An open palm for friends, {name}. The fist is kept for everyone else."],
		L["I swept temple steps for a year to learn this, {name}. The steps stayed dusty."],
		L["Strength, grace and a clear head, {name}: the emperors' gifts. Now yours."],
		L["A gift from a land that hid in the mists, {name}. Use it out in the open."],
		L["Harmony is hard to find, {name}. Hold on to this bit of it."],
		L["Nothing in it you didn't have already, {name}. I've only woken it up."],
	},
	whitetiger = {
		L["Strength is better shown than talked about, {name}. So I'll say no more."],
		L["Strike where the guard is thin, {name}. The Tiger's eyes will show you where."],
		L["Xuen never strikes by halves, {name}. Now neither do you."],
		L["You don't get the stripes, {name}. Only the nerve that goes with them."],
		L["I trained in Kun-Lai's snow for this, {name}. Your feet stay warm, at least."],
		L["The Tiger's blessing isn't gentle, {name}, but it's on your side."],
		L["Fierce, not angry, {name}. Xuen taught me the difference. Now it's yours."],
		L["Wait, watch, then pounce, {name}. With the tiger's gift, you'll need one try."],
	},
	darkintent = {
		L["Dark Intent, {name}. A grim name for a kind act. Warlocks name things badly."],
		L["Thank the demon who taught me this, {name}. On second thoughts, don't."],
		L["You'll feel no different, {name}. Your enemies will. That's rather the point."],
		L["A little fel, well filtered, {name}. You'll barely smell the sulphur."],
		L["A spark of the Nether rides with you now, {name}. I've trained it to sit."],
		L["Don't feel guilty about the power, {name}. I've done the guilty part already."],
		L["Darkness suits you, {name}. I mean that kindly."],
		L["I'd wish you luck, {name}, but warlocks prefer to arrange it."],
	},
	skyfury = {
		L["The sky lends you its temper, {name}. Strike once, and the storm follows it in."],
		L["The earth keeps you steady, {name}. Now the sky wants a turn."],
		L["The storm rides with you now, {name}. Do warn it before you go indoors."],
		L["If your hair stands on end, {name}, that's the storm agreeing with me."],
		L["I asked the sky to stand behind you, {name}. It's very tall and easily annoyed."],
		L["Lightning never strikes twice, they say, {name}. Mine just struck you. Fury."],
		L["I listen to the wind, {name}. Today it asked me to bless you. Done."],
		L["Thunder in your arms, {name}. Let the next fool who blocks your way hear it."],
	},
	bronze = {
		L["A few borrowed moments from the bronze, {name}. Nozdormu keeps careful count."],
		L["Time won't wait for you, {name}, but for the next while it'll dawdle."],
		L["Not all help arrives in time, {name}. This kind brings its own."],
		L["Should you need to slip away, {name}, time will cover for you."],
		L["Bronze magic, {name}. You'll arrive a breath before you're needed."],
		L["Time is a river, {name}. I've found you a quicker current."],
		L["Time heals all wounds, {name}. I'd rather it helped you dodge them."],
		L["The bronze say I learned this tomorrow, {name}. I've stopped arguing with them."],
	},
	sourceofmagic = {
		L["My spare magic is yours now, {name}. Every spell I overcharge spills your way."],
		L["Only one of you gets this, {name}. I chose. Try to look modest about it."],
		L["I'd give you my patience as well, {name}, but I've barely enough for me."],
		L["We're linked for the hour, {name}. Don't worry, it only runs one way."],
		L["I've seen how hard you work, {name}. Let me carry a little of it."],
		L["My magic runs hot, {name}. By the time it reaches you, it's cooled nicely."],
		L["Cast freely, {name}. Your mana is partly my concern now."],
		L["If you run dry, {name}, it means I've been idle. Do say so."],
	},
	earthshieldtank = {
		L["The earth stands between you and harm now, {name}. Every blow mends you."],
		L["Stone has your back, {name}. Each hit they land patches you up a little."],
		L["The spirits of earth owed me a favour, {name}. I've spent it on you."],
		L["Hold the line, {name}. The ground itself is holding you."],
		L["You take the hits, {name}, and the stone takes them personally."],
		L["Charge in, {name}. What they break, the earth puts back."],
	},
	beacon = {
		L["You're my Beacon, {name}. Every heal I give the others shines on you too."],
		L["The Light will find you wherever you stand, {name}. I've made sure of it."],
		L["Stand tall, {name}. When I mend the others, you get the echo."],
		L["A lighthouse for the whole group, {name}. Try not to stand in the dark."],
		L["Wherever I heal, {name}, a little of it reaches you."],
	},
	oathoflight = {
		L["I swear it, {name}: while this oath holds, my Light finds you first."],
		L["An oath sworn to you alone, {name}. Don't make me regret it."],
		L["My word is yours for a while, {name}. Paladins keep their word."],
		L["I've sworn to keep you standing, {name}. I take oaths seriously."],
	},
	symbiosis = {
		L["A little of you, a little of me, {name}. Nature loves a fair trade."],
		L["We're bound for the hour, {name}. Borrow my gifts; I'll borrow yours."],
		L["Every living thing leans on another, {name}. Today we lean on each other."],
		L["Lend me a trick, {name}, and I'll lend you one of mine."],
		L["The Dream calls this a partnership, {name}. I call it common sense."],
	},
	blisteringscales = {
		L["Scales off my own back, {name}. Let them hit you and see what happens."],
		L["Wear these, {name}. Anything that bites you will regret its teeth."],
		L["Dragonscale armour, freshly shed, {name}. It bites back."],
		L["These scales burst when struck, {name}. Do let them strike."],
		L["A dragon's hide for an hour, {name}. Stand in front and enjoy it."],
	},
	spiritofthealpha = {
		L["Run at the front of the pack, {name}. The wolf spirit makes them all chase you."],
		L["Lead the hunt, {name}. Every beast in here will want your throat, not ours."],
		L["The alpha's spirit is yours now, {name}. Howl, and they'll all turn your way."],
		L["First through the door, {name}. The pack follows, and so does everything else."],
	},
	beaconoffaith = {
		L["My second Beacon, {name}. Whatever I give the others, you share in it too."],
		L["Two lights to steer by tonight, {name}, and you're one of them."],
		L["The Light has room for two, {name}. Keep shining over there."],
		L["Faith marks you as well, {name}. My heals will find both of you."],
	},
	symbioticrelationship = {
		L["We're bonded for the hour, {name}. When I mend myself, you mend too."],
		L["Roots in the same soil, {name}. What heals one of us helps the other."],
		L["A bond of the grove, {name}. Look after yourself and you look after me."],
		L["Nature pairs us up for a while, {name}. Try not to make me regret it."],
	},
	detectgroup = {
		L["Now you'll see what creeps up on us, {name}. Try not to scream."],
		L["A warlock's sight, {name}, lent for a while. Some shadows stare back."],
		L["Eyes open, {name}. Whatever hides near us is about to be found."],
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
	L["{gift} means 'good luck'. {buff} means 'you too'."],
	L["Your {gift} came first; my {buff} tries twice as hard."],
	L["If anyone asks, {buff} came before {gift}. Deal?"],
	L["{gift} made my day; {buff} should make your hour."],
	L["Saved my {buff} for someone worthy. Then came {gift}."],
	L["Your {gift} went to my head; my {buff} goes to yours."],
	L["{gift} on me, {buff} on you. We wear each other's work."],
	L["{gift} and {buff} fade. Kindness lasts. Well, longer."],
	L["You shared {gift}; I share {buff}. Ale's next."],
	L["{gift} caught me empty-handed. Not any more: {buff}."],
	L["{gift}, best thing all day. {buff}, my bid for second."],
	L["{gift} deserves a statue. I'm no sculptor, so: {buff}."],
	L["{gift} for {buff}? Keep this up and we'll draw a queue."],
	L["{gift} was kind. {buff} is kind back, and competitive."],
	L["{gift} came like good news. {buff}, by return post."],
	L["{gift}, meet {buff}. Do get along, you two."],
	L["Trade you {buff} for {gift}? Ah, you've already paid."],
	L["{gift} and {buff}. The inn will say we rehearsed."],
}

-- Thanks only, like RP.TRADE, and about what the spell they gave you does
-- rather than its name: Arcane Intellect makes you clever, Thorns prickly, a
-- shout loud. By that spell's buff key (Buffs.lua), found from the debt's
-- spell id; heard next to the trade lines and more often than them, since
-- what a spell does is the part of the moment only this favour has. The
-- trade lines stay the most varied, and the same priest will give you
-- Fortitude all evening.
RP.GIFT = {
	intellect = {
		L["{gift}! I just had three clever thoughts, {name}. This was one."],
		L["With {gift}, {name}, I finally understand my own notes. Thanks."],
		L["Cleverer already, {name}. Clever enough to know I owe you one. Here."],
		L["Your {gift} found me the word for this, {name}: 'thanks'."],
		L["{gift}! I understood a goblin contract, {name}. I'm appalled."],
		L["Thank you, {name}. My thoughts are lining up politely."],
		L["I'll use your {gift} for more than arguing, {name}. Probably."],
		L["Thank you, {name}. My next spell gets three extra syllables, just to show off."],
	},
	fortitude = {
		L["{gift}, {name}? I'll stand at the front for once. Briefly."],
		L["Knees, elbows and pride, {name}: all fortified. Thank you."],
		L["Hit me now, {name}. Actually, don't. But thank you; I'd survive it."],
		L["Nigh unbreakable now, {name}. Let's never test the 'nigh'. Thank you."],
		L["{gift}! My healer owes you a letter, {name}. I owe you this."],
		L["Every bruise I don't get today, {name}, I owe to your {gift}."],
		L["I could lose an argument with an ogre now and live, {name}. Thank you."],
		L["Thank you, {name}. I feel like a castle wall. A grateful one."],
		L["Thank you, {name}. The next boar to charge me is in for a long afternoon."],
	},
	spirit = {
		L["{gift}! I feel ten years younger, {name}. Thank you."],
		L["I feel twice as calm and half as grumpy, {name}. Thank you."],
		L["Your {gift} nearly made me sing, {name}. Take this. It's kinder."],
		L["{gift}, {name}? I've forgiven three people already. Thank you."],
		L["I was on fumes, {name}. Your {gift} was a hot meal and a hearth."],
		L["I've stopped counting mana between fights, {name}. Thank you."],
		L["My spirit's topped up, {name}, and the rest of me is grateful too."],
	},
	shadow = {
		L["Shadow-proof, thanks to you, {name}. The whispers are furious."],
		L["Nothing dark gets in now, {name}. Here's something bright going the other way."],
		L["{gift}! Shadowfang Keep can keep its shadows, {name}. Thank you."],
		L["The next shadow bolt's in for a letdown, {name}. Thank you."],
		L["On your {gift} I'll brave Duskwood tonight, {name}. Or tomorrow."],
	},
	motw = {
		L["{gift}! A squirrel just nodded at me, {name}. Here's yours."],
		L["Tougher hide, sharper senses, {name}. I may have to fight the urge to forage."],
		L["I feel all wild and leafy, {name}. Thank you. Sorry if I shed bark."],
		L["Thicker skin from your {gift}, {name}. Arrows and insults both."],
		L["{gift}! A bird tried to nest on me, {name}. Thanks, I think."],
		L["Thanks for the {gift}, {name}. The woods feel like home now."],
		L["Thank you, {name}. I've an urge to stand in the rain and grow. I'll resist."],
		L["Every bramble in the Barrens will think twice now, {name}. Thank you."],
		L["Thank you, {name}. Rain, cold and wolves: let them all try."],
	},
	thorns = {
		L["{gift}, {name}! Nobody's hugging me today. Have this instead."],
		L["Prickly now, thanks to you, {name}. More than usual, I mean."],
		L["Your {gift}, {name}! Let the next kobold try for my candle."],
		L["{gift}! I'm a thicket with opinions now, {name}. Thank you."],
		L["Thank you, {name}. The next thing that bites me will need a moment to reflect."],
	},
	kings = {
		L["{gift} from you, {name}? I'll try not to found a dynasty."],
		L["A little better at everything, {name}. Is this how kings feel? No wonder."],
		L["Your {gift}! My first decree, {name}: thank you."],
		L["{gift} on a commoner, {name}? I'll try to look regal."],
		L["With your {gift} I could rule a small kingdom, {name}. Westfall."],
		L["Thank you, {name}. Every bit of me is grateful, and they rarely agree."],
	},
	might = {
		L["Stronger arms already, {name}. I'll try not to hug anyone. Thank you."],
		L["With {gift} I could lift a kodo, {name}. I won't, but thank you."],
		L["Your {gift} has my arms very confident, {name}. Thank you."],
		L["{gift}! Opened a jar I've fought since Stranglethorn, {name}."],
		L["Thank you, {name}. My next swing is dedicated to you. So is the dent."],
	},
	wisdom = {
		L["{gift} from you, {name}, and my first wise act is this."],
		L["Wiser already, {name}. Wise enough to know a kindness when I see one."],
		L["My mana thanks you for {gift}, {name}. It's the shy one of us."],
		L["Your {gift} refills me faster than I spend, {name}. Nearly."],
		L["Your {gift}, {name}: mana back, and an urge to give advice."],
	},
	salvation = {
		L["{gift}! The monsters forgot me at once, {name}. I won't."],
		L["Nothing wants to fight me now, {name}. It's lovely. Thank you."],
		L["{gift}! Nothing's glared at me in minutes, {name}. Thank you."],
		L["{gift}! A mouse at a dragon's feast, {name}: unseen, well fed."],
		L["Thanks to {gift} I'm just a rumour in a fight, {name}."],
	},
	light = {
		L["The Light finds me easier now, {name}. I'll try to deserve it."],
		L["Easier to heal now, {name}. Whoever patches me up thanks you too."],
		L["With your {gift}, {name}, mending feels like coming home."],
		L["{gift}! The Light and I are on first-name terms now, {name}."],
		L["With {gift} the Light hears me first, {name}. No need to shout."],
	},
	sanctuary = {
		L["Blows land softer on me now, {name}. My bruises thank you, and so do I."],
		L["Every hit gentler, thanks to you, {name}. I'll make sure they notice."],
		L["Your {gift} softens every blow, {name}. I'm upholstered."],
		L["{gift}! Now the Light takes every hit personally, {name}."],
		L["With your {gift} I'm half fortress, half chapel, {name}."],
	},
	battleshout = {
		L["You shouted at me, {name}, and I've never felt so encouraged. Here."],
		L["My ears are ringing, {name}, and my arms feel twice as strong. Thank you!"],
		L["{gift}, {name}! I felt that in my teeth. In a good way."],
		L["I'll answer your {gift} quietly, {name}. Somebody should."],
		L["Your {gift} nearly had me charging a wall, {name}. Here, calmly."],
		L["All Azeroth heard your {gift}, {name}. Thank you for my share."],
		L["That shout put iron in my spine, {name}. Thank you."],
		L["I didn't catch the words, {name}, but my arms did. Thank you!"],
		L["Thank you, {name}. I'll hit the next thing twice as hard and blame you."],
	},
	breath = {
		L["I can breathe underwater, {name}! I may never need to, but thank you."],
		L["Lungs like a murloc, thanks to you, {name}. I'll try not to gurgle."],
		L["With {gift} I'll raid every sunken wreck, {name}. Half's yours."],
		L["I won't ask where {gift} gets its air, {name}. Just: thanks."],
		L["With {gift} I'll cross Lordamere Lake, {name}. Underneath."],
	},
	-- The favours Manners never offers (Buffs.lua, favourOnly), which are in
	-- no buff: RP.GiftKey finds these by the spell's own id.
	soulstone = {
		L["If I fall, {name}, I'll be back to thank you properly."],
		L["A spare life in my pocket, {name}. I'll try not to spend it. Thank you."],
		L["Thank you, {name}. Death can knock now; I've a key to the back door."],
		L["Dying's only a delay with your {gift}, {name}. Thank you."],
		L["Thank you, {name}. If the worst happens, I'll get up and say it twice."],
	},
	fearward = {
		L["Let the next thing roar at me, {name}. I'm not running this time. Thank you."],
		L["{gift}! One fright, already dealt with, {name}. Thank you."],
		L["Thank you, {name}. The next scream I hear won't be mine."],
		L["No running in circles for me, {name}. Not the first time, anyway. Thank you."],
		L["Brave on credit, thanks to you, {name}. I'll spend it wisely."],
	},
	waterwalking = {
		L["Thank you, {name}. Lakes, rivers, puddles: all floors now."],
		L["{gift}! The short way across it is, {name}. Dry boots and all."],
		L["Walking on water, {name}. Folk will start a religion. Thank you."],
		L["The murlocs will be furious, {name}. Thank you for the shortcut."],
		L["Thank you, {name}. I'll be across before it fades. Probably."],
	},
	detectinvis = {
		L["{gift}! Whatever hid round here, {name}, hides no more."],
		L["I can see what's hiding now, {name}. Some of it should stay hidden. Thanks."],
		L["Thank you, {name}. Every lurker around just lost their only trick."],
		L["Thank you, {name}. Now I can see what your imp gets up to."],
		L["My eyes see more than my wits can handle, {name}. Thank you."],
	},
	commandingshout = {
		L["I'll be the last one standing, {name}, just to hear you shout again."],
		L["You ordered me to live, {name}. I mean to follow it to the letter. Thanks."],
		L["Thank you, {name}. Every sinew I have just closed ranks."],
		L["Never been shouted into good health before, {name}. Thank you."],
		L["Yes, Sergeant {name}! Your shout brings out the recruit in me. Thank you."],
		L["{gift}! That voice could turn a stampede, {name}. Thanks."],
	},
	hornofwinter = {
		L["That horn froze my breath and fired my arms, {name}. Thank you."],
		L["Most folk hear that horn from the wrong end of a battle, {name}. Thank you."],
		L["I heard your horn and swung harder, {name}. Nobody had to tell me twice."],
		L["Thank you, {name}. I'll be humming that note for the rest of the day."],
		L["Thanks to you, {name}, I'll never grumble about winter again."],
		L["{gift}! I won't ask what the horn's made of, {name}. Thank you."],
	},
	emperor = {
		L["An emperor's legacy, {name}. I'll try to leave it no worse than I found it."],
		L["Like a month of training before breakfast, {name}. Thank you."],
		L["Thank you, {name}. I feel calm enough to brew tea in a thunderstorm."],
		L["Thank you, {name}. I bowed without thinking. Is that part of it?"],
		L["{gift}! Pandaria's finest, {name}. Don't tell the brewmasters."],
		L["Stronger, quicker and steadier at once, {name}. My teachers never managed that."],
	},
	whitetiger = {
		L["{gift}, {name}! Even my mistakes will look deliberate now."],
		L["I feel a tiger pacing in my chest, {name}. It wants to hunt. Thank you."],
		L["Thank you, {name}. I'll be very polite to cats from now on."],
		L["I could out-stare a tiger now, {name}. Not Xuen. A small one."],
		L["Every strike I throw now has claws in it, {name}. Thank you."],
		L["I'd thank Xuen as well, {name}, but he answers thanks with a sparring match."],
	},
	darkintent = {
		L["{gift}! I feel sharper and slightly sinister, {name}. Thanks."],
		L["Dark but generous, {name}, like a good stout. Thank you."],
		L["Thank you, {name}. If I start cackling in a fight, you'll know why."],
		L["Bound to a warlock for the hour, {name}. My family would faint. Thank you."],
		L["Like borrowing a sharp knife from a stranger in an alley, {name}. Thanks."],
		L["More dangerous today and worse sleep tonight, {name}. A fair trade. Thanks."],
	},
	skyfury = {
		L["Thank you, {name}. Now I know why shamans always look so windswept."],
		L["{gift}! Swift as the wind, {name}, and as hard to argue with."],
		L["Your {gift} has me crackling, {name}. Shake hands carefully."],
		L["My weapon keeps hitting things twice, {name}. Thank you, and thank the storm."],
		L["The sky's on my side now, {name}. I'll try not to stand on any hilltops."],
		L["I'm half thunderstorm now, {name}. Thank you, and sorry about the rain."],
	},
	bronze = {
		L["{gift}! A step ahead of everything, {name}, myself included."],
		L["Thank you, {name}. I'll be out of trouble before trouble notices."],
		L["Thank you, {name}. I can feel the sands shifting in my favour."],
		L["Thank you, {name}. Even my running away will look dignified now."],
		L["Haven't I thanked you already, {name}? Time's gone odd. Thanks again."],
		L["Thank you, {name}. Nozdormu won't miss the moments; he has all of them."],
	},
	sourceofmagic = {
		L["Thank you, {name}. Your magic and mine get on surprisingly well."],
		L["Of everyone here, {name}, you chose me? I'm flattered and refreshed."],
		L["{gift}! I'll be the last one here to run dry, {name}. Thank you."],
		L["I could cast till sundown now, {name}. Please keep breathing fire."],
		L["Thank you, {name}. Everyone I help today owes you a little too."],
		L["Your leftovers beat my best, {name}. Most humbling. Thank you."],
	},
	earthshieldtank = {
		L["Thank you, {name}. With the earth at my back, I'll stand anything."],
		L["{gift}! Let them hit me now, {name}. I'll only get better."],
		L["Thank you, {name}. I'll try to deserve every pebble."],
	},
	beacon = {
		L["A Beacon, for me? I'll shine where the hits land, {name}. Thank you."],
		L["Thank you, {name}. Every heal of yours has my address on it now."],
		L["{gift}! I'll lead, {name}, and your Light can follow."],
	},
	oathoflight = {
		L["An oath, sworn to me? Thank you, {name}. I'll try to be worth keeping."],
		L["Thank you, {name}. I'll stand in front; you keep your word."],
	},
	symbiosis = {
		L["Thank you, {name}. I'll take good care of your trick, and you of mine."],
		L["{gift}! We're a matched pair now, {name}. Let's not waste it."],
	},
	blisteringscales = {
		L["Your own scales, {name}? I'll wear them proudly. Thank you."],
		L["{gift}! Let them swing at me now, {name}. They'll regret it."],
	},
	spiritofthealpha = {
		L["Thank you, {name}. I'll lead the pack and keep their eyes on me."],
		L["{gift}! Let them all come for me now, {name}. I am the alpha."],
	},
	beaconoffaith = {
		L["Thank you, {name}. I'll try to be a light worth following."],
		L["{gift}! Two lights on me now, {name}. I will keep mine lit."],
	},
	symbioticrelationship = {
		L["Thank you, {name}. Whatever I mend in myself, I'll send your way."],
		L["{gift}! Bonded, then, {name}. I'll take good care of us both."],
	},
}

-- How often the two of you have traded this session (RP.Familiar): "again"
-- for the second or third time, "regular" for the fourth and on.
RP.HISTORY = {
	again = {
		L["We have to stop meeting like this, {name}. Actually, no. Here's another one."],
		L["Again, {name}? Splendid. I've been practising since last time."],
		L["You again, {name}? Another one for you, then. People will say we're friends."],
		L["Same face, same spell, {name}. I do love a tradition."],
		L["Another round, {name}? I'm keeping score, and we're both winning."],
		L["Ah, {name}! My favourite repeat customer."],
		L["Our paths keep crossing, {name}, and I keep having one of these for you."],
		L["Once more, {name}. Do stop me if you've heard this one."],
		L["I kept some aside, {name}, in case you came back. Good instinct, mine."],
		L["Back already, {name}? The day's improving. Here, same as last time."],
		L["Again, {name}? At this rate I'll learn your middle name. Have another."],
		L["Once is kindness, twice is a habit, {name}. I've never broken a habit yet."],
		L["An encore, {name}, for my most faithful audience."],
		L["One more of these, {name}, and we'll have to draw up a guild charter."],
		L["I'll remember your face now, {name}, and I'm terrible with faces. Here."],
		L["Us again, {name}. The world must be short of people to bless. Here."],
		L["Last time went so well, {name}, I've changed nothing."],
		L["Good to see someone I know, {name}. Rarer than you'd think. Have this."],
		L["Oh, it's you, {name}. Good. I hate giving these to strangers."],
	},
	regular = {
		L["{name}, at this point we should just share a reagent pouch."],
		L["Same time tomorrow, {name}? I'll bring {buff}. You bring you."],
		L["I've lost count of these, {name}, and I've decided that's a compliment."],
		L["Keep this up, {name}, and the bards will write a dull song about our favours."],
		L["I could do this one in my sleep by now, {name}. I may have."],
		L["The usual, {name}? Of course the usual."],
		L["We should have a secret handshake by now, {name}. Until then, this."],
		L["By now, {name}, I think we've built a small economy between us."],
		L["Old friends by now, {name}. Old acquaintances, at least, with this habit."],
		L["Let the record show: {name} and I, undefeated at being prepared."],
		L["My spellbook opens to your page on its own now, {name}."],
		L["If you stopped turning up, {name}, who would I give these to? The guards?"],
		L["We keep this up, {name}, and one of us owes the other a drink."],
		L["We're a local landmark now, {name}: the pair who bless each other. Here."],
		L["Regular as the tides, {name}, and twice as welcome. As is this."],
		L["I'd trust you with my last potion, {name}. For now, take this."],
		L["Next time we share a fire, {name}. This time, take this."],
		L["I'd miss this if it stopped, {name}. So let's not stop."],
		L["There's nobody I'd rather keep blessing, {name}."],
		L["You always turn up at the right moment, {name}, and I'm always ready. Here."],
	},
}

-- Where this is (RP.Place): "city" is resting, in a city or an inn; "wild" is
-- outdoors; "instance" is a dungeon or a raid; "battle" is a battleground or
-- an arena, where the lines keep to pride and say nothing of the other side.
-- A scenario is none of them. A people's own city has its own lines
-- (RP.RACE's "city"), said there in place of these.
RP.PLACE = {
	city = {
		L["Safe walls, warm beds, and now {buff}. You're spoiled, {name}."],
		L["The guards have it covered, {name}, but I like to be thorough."],
		L["Careful, {name}. Look this capable in town and folk will ask you favours."],
		L["Not a monster for miles, {name}. Still, take this. One never knows the cooking."],
		L["For the crowds, {name}. In town, they're the real danger."],
		L["Rest easy, {name}. I'll count that my good deed and go find a pint."],
		L["Even in town, {name}, a dragon has been known to drop in. Better safe."],
		L["Best do it in here, {name}. Out there, nobody stands still long enough."],
		L["Mind the pickpockets, {name}. This is the one thing on you they can't lift."],
		L["City rules, {name}: no blades drawn, no spells thrown. This one's allowed."],
		L["Nothing to fight here but stray cats, {name}. Take this anyway."],
		L["For the walk to the bank, {name}. It's always further than it looks."],
		L["Enjoy a warm hearth while you can, {name}, and take this for the road."],
		L["The watch has the walls, {name}. I'll see to you."],
		L["For the stairs, {name}. Whoever built this place never met a short way up."],
		L["Everything else in town has a price, {name}. This slipped past the merchants."],
		L["Buy nothing from anyone who calls you 'friend', {name}. Except me. It's free."],
	},
	wild = {
		L["Out here everything wants to eat you, {name}. Now it'll need a bigger fork."],
		L["No guards for miles, {name}, and the boars know it. Take this."],
		L["Nobody out here but us and the wildlife, {name}. With this, we're tougher."],
		L["If a bear asks, {name}, you were like this when I found you."],
		L["The wolves have been eyeing you, {name}. This should give them pause."],
		L["Wild country, {name}. Best not to meet it armed with good intentions alone."],
		L["Map, canteen, {buff}. Now you can get lost properly, {name}."],
		L["Camp's a long way off, {name}. Consider this a roof you can carry."],
		L["Out past the last farm, {name}, you're on your own. Nearly."],
		L["Nearest inn's a day's walk, {name}; the nearest teeth, closer. Take this."],
		L["Two hills and a swamp to the next town, {name}. Here; the swamp has opinions."],
		L["Take this; camp carefully, {name}. Every nice clearing has an owner with claws."],
		L["Fresh air, open sky, {name}, and this. Enjoy it while nothing's chasing you."],
		L["Something's following you, {name}. Probably a boar. This is in case it isn't."],
		L["Take this and stay on the road, {name}. The road has guards. Some of the time."],
		L["Rain's coming, {name}, and so are the wolves. One of those I can help with."],
	},
	instance = {
		L["A villain in here rehearses a speech, {name}. Take this, then let's interrupt."],
		L["Whatever waits at the end of this place, {name}, this will make it regret it."],
		L["Nobody leaves here alive, they say, {name}. Take this; let's prove them wrong."],
		L["Our host had years to prepare, {name}. We have {buff}."],
		L["Nobody builds a dungeon with a back door, {name}. Take this instead."],
		L["Dark halls, old traps, worse tempers. At least you're ready, {name}."],
		L["Better I hand you this now, {name}, than a eulogy later."],
		L["There's treasure in here, {name}, and something large sat on it. This first."],
		L["If a door slams shut behind us, {name}, that's tradition. Take this first."],
		L["Take this, {name}, and mind the patrols. They walk the same loop and resent it."],
		L["Whoever built this place spent it all on skulls, {name}. Here's a little light."],
		L["The last lot through here were never seen again, {name}. They lacked this."],
		L["Take this, {name}; check the ceiling. In places like this, something drops in."],
		L["Take this, {name}. If we meet a talking skull, let me do the talking."],
		L["Here, {name}. If the walls start whispering, don't answer. It encourages them."],
		L["Touch nothing that glows, pull nothing that clicks, {name}. Wear this."],
		L["Take this and stick together in here, {name}. Echoes carry, and so do grudges."],
	},
	battle = {
		L["Flags, towers, graveyards, {name}. Whatever we're fighting over, take this."],
		L["Win or lose, {name}, nobody will say you went in unprepared."],
		L["The graveyard's just over there, {name}. Take this; let's both not visit it."],
		L["Honour's on the line, {name}. So is the flag. Here's something for both."],
		L["Take this and stay with the group, {name}. Lone heroes make short songs."],
		L["Our banner looks better with you under it, {name}, and blessed. Stand tall."],
		L["Take this, {name}. Keep your head down and your colours up."],
		L["Hold the line with this, {name}. The songs are about the ones who stood."],
		L["Take this and come back in one piece, {name}. That's all I ask."],
		L["Drums are for courage, {name}. This is for everything else."],
		L["Some fight for glory, {name}. I fight for whoever's beside me, and bless them."],
		L["Take this, {name}. Fight for the banner, come back for the singing. It's awful."],
	},
}

-- The hour on the realm's clock (RP.Hour): "morning" from five until eleven,
-- "night" from ten at night until five. Anybody's; a people whose hour it is
-- has its own lines as well (RP.RACE's "night" and "morning").
RP.TIME = {
	morning = {
		L["Early bird, {name}? Here's something better than a worm."],
		L["Good morning, {name}. Consider this your first cup of something strong."],
		L["Early start, {name}. The day hasn't gone wrong yet, and this should keep it so."],
		L["Not even lunch yet, {name}, and you're already better prepared than I am."],
		L["Morning, {name}. The monsters are still yawning. Take this before they stop."],
		L["A fresh day and a fresh {buff}, {name}. Let's not waste either."],
		L["Up with the sun, {name}? Show-off. Here; the sun doesn't get one."],
		L["Rise and shine, {name}. This is the shine; breakfast can wait."],
		L["Everything's golden and nobody's shouted yet, {name}. Add this to it."],
		L["Too early for heroics, {name}? Nonsense. Here; heroics go best before lunch."],
		L["The birds are singing, {name}. They haven't seen what's out there. Take this."],
		L["First good deed of the day, {name}. It's all downhill from here."],
		L["Still yawning, {name}? This works faster than tea."],
		L["Early, {name}. The dawn patrol thinks we're mad, handing out blessings now."],
	},
	night = {
		L["Out this late, {name}? The night is hungrier than the day. Take this."],
		L["Past bedtime, {name}. The sensible folk are asleep, so you get this."],
		L["Can't sleep either, {name}? Then let me be useful. Here."],
		L["Mind the dark, {name}, and take this. Not everything out there is as friendly."],
		L["It's late, {name}. This should keep you going till the sun remembers us."],
		L["Only the owls and us awake, {name}, and the owls get no {buff}."],
		L["The inns have locked up, {name}. This is the only thing still being served."],
		L["It's the hour for ghost stories, {name}. Take this, in case one is true."],
		L["Candles low, stars high, {name}. A good hour for small kindnesses."],
		L["Quiet hour, {name}. Every creak sounds like an ambush. This helps with that."],
		L["This late, {name}, even the guards talk to themselves. I'd rather bless you."],
		L["This is the hour things climb out of graves, {name}. Take this; walk briskly."],
		L["Tomorrow you'll wonder why you stayed up, {name}. This is one good reason."],
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
		L["Two of a kind, {name}. We could write the manual. This is chapter one."],
		L["Don't look so surprised, {name}. Same trainer, I expect. Same blessing too."],
		L["I'd critique your technique, {name}, but mine looks the same. Here."],
		L["Don't tell the others, {name}: ours is the finest calling. Proof: this."],
		L["Look at us, {name}. Two experts, making this look easy. It isn't, is it?"],
		L["Between colleagues, {name}: I don't know how half of it works. This half, I do."],
		L["We walked the same road to get here, {name}. Take this for the next stretch."],
		L["If anyone asks, {name}, we trained each other. Starting with this."],
		L["Calling to calling, {name}. We should compare notes. Here's mine."],
		L["Colleague, {name}. We look after our own."],
		L["Good to see the old craft in steady hands, {name}. Steadier with this."],
	},
	WARRIOR = {
		L["I'd shout some encouragement, {name}, but you do that far better. Here instead."],
		L["Charge in as usual, {name}. I'll simply feel better about it now."],
		L["For the one who goes in first, {name}. Somebody has to, and it's never me."],
		L["You take the hits so the rest of us don't, {name}. It's the least I can do."],
		L["Take this, {name}, and charge. I'll be right behind you."],
		L["For the one who fixes every problem by hitting it, {name}. It usually works."],
		L["I'd shake your hand, {name}, but both are holding something sharp. Take this."],
		L["A little help for a lot of armour, {name}. I hope it fits under there."],
		L["You'll charge something enormous soon, {name}. I'm just helping it lose."],
	},
	PALADIN = {
		L["Save your Light for later, {name}. This one's from me."],
		L["You bless everyone else all day, {name}. Here's one going the other way."],
		L["The Light already favours you, {name}. Here's a little more of it."],
		L["Even the Light's own champion needs a hand now and then, {name}."],
		L["I'd ask for a blessing back, {name}, but then we'd be here all day."],
		L["For the one who carries a hammer and a conscience, {name}. Heavy load."],
		L["Don't thank the Light for this one, {name}. This was me."],
		L["No need to kneel, {name}. I know it's a habit. Take this standing."],
	},
	HUNTER = {
		L["One for you, {name}, and a pat on the head for your companion."],
		L["You watch everyone's back from range, {name}. I've got yours."],
		L["Hunter's Mark for them, {buff} for you, {name}. Much nicer."],
		L["Take this and aim true, {name}. If it charges anyway, run to the rest of us."],
		L["Keen eye, steady hand, {name}. Here's something for the long hunt."],
		L["Nothing for the pet this time, {name}. It's already had three of my sandwiches."],
		L["I'd have brought arrows, {name}, but I never know which kind you like."],
		L["You can track anything, {name}, but you never saw this one coming."],
	},
	ROGUE = {
		L["Quick hands, quiet feet, {name}. Here's luck to go with them."],
		L["Quick, {name}, before you vanish again."],
		L["Poison on the blades, {buff} on you. Very thorough, {name}."],
		L["I'd slip it in your pocket, {name}, but you'd notice. You always notice."],
		L["For the one who opens every locked box, {name}. This one comes unlocked."],
		L["Nobody sees you coming, {name}. Now it's even worse news when they do."],
		L["Take this, {name}. Very discreet. It even walks quietly."],
		L["I'd have wrapped it, {name}, but you'd only pick the knot."],
		L["Keep this one, {name}. You don't even have to steal it."],
	},
	PRIEST = {
		L["For once, {name}, somebody's looking after the priest."],
		L["Save your prayers for the rest of us, {name}. This one's already answered."],
		L["Light or Shadow, {name}, I don't ask which. This suits both."],
		L["Sit down after this fight, {name}. That's an order. Take this, from a patient."],
		L["You keep us all standing, {name}. Here's a little of it coming back."],
		L["You've knelt beside all of us, {name}. Stand tall a minute, and take this."],
		L["Something that needed no prayer, {name}. You've said plenty of those today."],
	},
	DEATHKNIGHT = {
		L["No voice in your head comes with this one, {name}. Refreshing, isn't it?"],
		L["The Ebon Blade asks no favours, {name}. I'm giving one anyway."],
		L["A little warmth, {name}. I know you don't feel the cold. It's the thought."],
		L["You came back from the dead, {name}. The least I can do is help you stay back."],
		L["Runes, plague and frost, {name}. Take this too; it completes the set."],
		L["A skeletal horse and a sword that talks back, {name}. Here's something normal."],
		L["No need to drag me over on a chain, {name}. I was coming anyway. With this."],
		L["Welcome back to the land of the living, {name}. Its general direction. Here."],
	},
	SHAMAN = {
		L["The elements look after you, {name}, but they don't make house calls."],
		L["Tell the spirits I said hello, {name}, and showed them this."],
		L["Plant a totem in my honour, {name}, for this. A small one. I'm modest."],
		L["Earth, fire, water, air and me, {name}. Admittedly the least of the five."],
		L["Totems up already, {name}? Then this goes with them."],
		L["The wind would have brought you this, {name}, but it's flighty. I'm reliable."],
		L["You speak for the land, {name}. I hope this makes it speak kindly of me."],
		L["The spirits said you'd earned this, {name}. I didn't ask; they volunteered."],
	},
	MAGE = {
		L["A gift for a mage, {name}. Hard to find one you can't conjure."],
		L["You solve most problems with sheep, {name}. This covers the rest."],
		L["You could teleport out of any trouble, {name}. This is for the trouble first."],
		L["For the clever one, {name}. Please don't thank me by making me a sheep."],
		L["Blink wherever you like, {name}. This comes too."],
		L["Stand a little back from the fire you're about to start, {name}. Here."],
		L["You keep us all fed and watered, {name}. Your turn to be looked after."],
		L["Portal fees are steep, {name}. Call this a down payment on my next one."],
	},
	WARLOCK = {
		L["Entirely demon-free, {name}. I checked."],
		L["Your imp may be jealous, {name}. Tell it there's plenty to go round."],
		L["No contract, no fine print, {name}. Just a gift."],
		L["For the one who hands out healthstones, {name}. Nobody ever thanks you."],
		L["Here, {name}. Summon the rest of us later and we'll call it even."],
		L["Your voidwalker can stop hovering, {name}. I mean well."],
		L["Your felhunter eats magic, {name}. Keep it off this one; it's for you."],
		L["For the one who reads what nobody else dares, {name}."],
		L["Carrying a bag of souls all day, {name}? Your shoulders must need this."],
	},
	MONK = {
		L["Roll wherever you like, {name}. This rolls with you."],
		L["Brew first or fight first, {name}? Either way, take this."],
		L["Inner peace for you, {name}, and outer peace too, as long as this lasts."],
		L["Chi flows better with a little help, {name}. Or so a monk once told me."],
		L["Kick, flip, roll, {name}. I'll just stand here and do this bit."],
		L["Teach me to flip without spilling my drink, {name}, and we're even."],
		L["Tea, meditation and this, {name}. The three pillars of a good day."],
	},
	DRUID = {
		L["Tell the bear this is for them too, {name}."],
		L["Hold still, {name}. I've never once managed to catch you as a cheetah."],
		L["Nature looks after you already, {name}. Today she sent me to help."],
		L["Whatever shape you're in next, {name}, this goes with you."],
		L["For the forest's friend, {name}. Give my regards to the trees."],
		L["Cenarion work is never done, {name}. Here's a little help."],
		L["I'd give it to the cat, {name}, but the cat would pretend not to care."],
		L["Take this, {name}. Say hello to your moonkin form; it always looks so startled."],
	},
	DEMONHUNTER = {
		L["You were not prepared, {name}. Now you are."],
		L["Years in a Warden's cell, {name}. You've earned a small kindness."],
		L["You gave up so much to fight the Legion, {name}. Here's a little back."],
		L["For the one who leaps first, {name}. Do land somewhere friendly."],
		L["Fel and fury, {name}, and now a little kindness. It'll balance out."],
		L["I'd ask if you saw this coming, {name}, but you see everything."],
		L["You can see souls, {name}. Mine's the one being generous."],
		L["Illidan never let anyone help him, {name}. You're wiser than your teacher."],
		L["A demon inside and a Legion outside, {name}. Here's one thing on your side."],
	},
	EVOKER = {
		L["For you, {name}. Please don't breathe on it."],
		L["A little help for a dragon, {name}. I'll be telling my grandchildren."],
		L["The Aspects sent you out into the world, {name}. I'm making it friendlier."],
		L["Take to the skies after this, {name}. I'll wave from down here."],
		L["A dragon on our side, {name}. I've never felt safer being generous."],
		L["A gift for a dragon, {name}. Normally folk bring gold and hope to leave again."],
		L["For the one who could fly me to the next town, {name}. Not asking. Hinting."],
		L["I've met a few dragons, {name}. You're the first I didn't run from. Here."],
		L["For the world's youngest ancient, {name}."],
	},
}

-- The same class meeting itself, by that class (UnitClass's second return),
-- in place of RP.TARGET's "sameclass" lines: two mages have a joke two of
-- anything else do not.
RP.SAME = {
	MAGE = {
		L["{buff} for a mage, {name}. Like lending a library a book."],
		L["Mage to mage, {name}: I won't ask you for water if you won't. Take this."],
		L["Two mages, {name}. We can portal anywhere and still be late. Take this."],
		L["A mage for a mage, {name}. Our old masters would approve."],
		L["A mage enchanting a mage, {name}. We'll both pretend we needed it."],
		L["We'd never admit which spells we still read off the page, {name}. Not this one."],
		L["One mage is a scholar, {name}. Two is an argument. Here's my opening point."],
		L["We both know this spell by heart, {name}. Humour me."],
		L["More mana for you, {name}. Try not to spend it all on one fireball."],
	},
	PRIEST = {
		L["Priest to priest, {name}: who blesses the blessers? Today, me."],
		L["Between us, {name}, we'll pretend the warriors listen. Take this."],
		L["A priest looking after a priest, {name}. It feels almost forbidden."],
		L["Two priests, {name}. Twice the praying, half the panic. Here's my share."],
		L["If it all goes wrong, {name}, we two are the last ones standing. Take this."],
		L["Rest your prayers a while, {name}. Mine can keep watch."],
		L["I'd preach to you, {name}, but you've heard it. You've probably given it. Here."],
		L["Same vows and same sore knees, {name}. Here's something for yours."],
		L["If I fall, {name}, you know the words. If you fall, so do I. Here, so neither."],
	},
	DRUID = {
		L["Two druids, {name}. The Cenarion Circle would call this a quorum. Take this."],
		L["Druid to druid, {name}: bear or cat, you'll have this, and leaves in your hair."],
		L["From one shapeshifter to another, {name}: this one fits every shape."],
		L["No handshake, {name}. Two druids, neither the right shape. Take this instead."],
		L["Between us, {name}, we've a shape for every problem, and this for the rest."],
		L["Fellow druid, {name}? The trees told me you were coming, so I had this ready."],
		L["Take this, {name}. If you see me as a cat later, pretend you don't know me."],
	},
	PALADIN = {
		L["Paladin to paladin, {name}: heavy hammer, light heart, and this blessing."],
		L["A blessing for a paladin, {name}. Now we're both insufferably radiant."],
		L["Two paladins, {name}. Somewhere, a priest is relieved. Take this."],
		L["One of us should be humble about this, {name}. Neither of us will be."],
		L["Same oath, different polish, {name}. Yours is shinier. Take this to match."],
		L["Between us, {name}, we could light a cathedral. This lights you, for a start."],
		L["Two suits of plate, {name}. Nobody hears us sneak up. Take this anyway."],
		L["Your libram and mine agree on this one, {name}. Rare, that."],
	},
	WARLOCK = {
		L["Warlock to warlock, {name}: take this, and keep your imp away from mine."],
		L["Fellow warlock, {name}? Then you'll know this one's harmless."],
		L["Two warlocks, {name}. Let's not compare soul shards in public. Take this."],
		L["Between us, {name}, the demons do all the work. This bit I do myself."],
		L["Another warlock, {name}. Let's be polite; I've seen what you summon. Here."],
		L["A spell from one warlock to another, {name}. Check it for curses. I would."],
		L["Fellow warlock, {name}. The only one who won't ask where this came from."],
		L["Two warlocks, one kind deed, {name}. The Burning Legion must be livid."],
		L["I'd summon you a drink, {name}, but you know how summoning goes. Have this."],
	},
	WARRIOR = {
		L["Two warriors, {name}. Somewhere, a healer just sighed. Take this."],
		L["Warrior to warrior, {name}: first into the fight buys the drinks. I'm buying."],
		L["Shout for shout, {name}. We'll deafen the whole place together."],
		L["No plan, {name}? Perfect. Take this; we'll get along."],
		L["Warriors, {name}: the only folk who think shouting is a spell. We're right."],
		L["Warrior to warrior, {name}: take this. Shield up, temper hot."],
		L["You know this one, {name}. You've probably shouted it at me already."],
		L["Our trainer would be proud, {name}. He'd shout it, but he'd be proud."],
		L["Fellow warrior? Then you know the blacksmith's name too, {name}. Here."],
	},
	DEATHKNIGHT = {
		L["We both served the Scourge, {name}. I won't ask what you did. Just take this."],
		L["Two death knights, {name}. We've died twice between us. Take this; stop there."],
		L["Between us, {name}, we can drop the echoing voice. Just take this."],
		L["Mograine would approve of this, {name}. Grimly; he approves of all grimly."],
		L["Two horns and one winter, {name}. Mine sounds today; yours can have tomorrow."],
		L["The living keep their distance from us, {name}. I won't. Here."],
		L["We both broke free at Light's Hope, {name}. Every gift since is our own choice."],
		L["Do you still dream, {name}? I only ask our own kind. Take this either way."],
		L["Walk with me after dark, {name}. With eyes like ours, and this, no lantern."],
	},
	MONK = {
		L["Fellow monk, {name}? Take this; we'll spar later and both pretend we held back."],
		L["Two monks and one teapot, {name}. Whoever pours is the humbler, so I'll pour."],
		L["Compare masters, {name}? Mine was the hardest. Everyone's was. Here."],
		L["Take this, {name}. Meditate with me later. If one of us snores, the other did."],
		L["Monk to monk, {name}: I won't tell you to breathe. I'll just give you this."],
		L["Two monks, {name}. Xuen sees a contest, Yu'lon a lesson. I see a friend. Here."],
		L["Why is every monastery on a mountaintop, {name}? Take this for the climb."],
		L["Take this, {name}; do the forms with me at dawn. Two monks in step is music."],
		L["Strangers ask you for wisdom, {name}? I give them this. And say eat something."],
	},
	EVOKER = {
		L["Some followed Sarkareth into the dark, {name}. We chose the sky, and this."],
		L["Shall we speak Draconic, {name}? The mortals will think this is a quarrel."],
		L["Not even the Aspects knew what to make of us, {name}. I do. Here."],
		L["Do you hold a spell a moment too long, {name}, to feel it gather? I just did."],
		L["Our people are still choosing their customs, {name}. I'd like this one kept."],
		L["Valdrakken was built for grown dragons, {name}. Take this; we'll feel taller."],
		L["Our magic hums when two of us stand close, {name}. Listen. That's this one."],
		L["Scalecommanders drilled us both, {name}. Shouts still straighten my back. Here."],
		L["Whichever side you took, {name}, we were kin before there were sides. Here."],
	},
	SHAMAN = {
		L["Heard the earth grumble just now, {name}? It was giving you this. Good."],
		L["Race you to the next town as wolves, {name}? Take this first. No lightning."],
		L["My ancestors and yours have met by now, {name}. They'd want you to have this."],
		L["Two shamans, one sky, {name}. I asked first, so this storm is mine to give."],
		L["Folk stare when we talk to rocks, {name}. Let them. The rocks gave you this."],
		L["Between two shamans, {name}, a storm is just a conversation. Here's my half."],
		L["The elements could go quiet any day, {name}. Today they answered: this."],
		L["Ever tried to stop listening, {name}? I did. Everything got louder. Here."],
		L["People want storms stopped or started, {name}. I ask the sky; it gave you this."],
	},
}

-- A spell given to a class it does little for, by the spell's buff key and
-- then the class helped (UnitClass's second return): Arcane Intellect fills
-- mana, and a warrior or a rogue has none. Heard as part of RP.TARGET's pool
-- for that class, so whoever is helped gets no more of the draw than before,
-- and only while the buff is manaOnly on this client: on Mists the intellect
-- key is Arcane Brilliance, whose crit a warrior has every use for.
-- The joke is on the spell or on the one casting it, never on the one who has
-- no use for it.
RP.ONTO = {
	intellect = {
		WARRIOR = {
			L["No mana to fill, {name}. It'll just stand about being clever, like me."],
			L["My spell on a warrior, {name}. Call it a small experiment."],
			L["I only know the one spell for friends, {name}. Rage or mana, you're getting it."],
			L["Your rage doesn't need this, {name}, but I'd feel rude walking past you."],
		},
		ROGUE = {
			L["No mana, I know, {name}. A sharp mind never hurt a sharp blade."],
			L["It's meant for mana, {name}. You'll find a use. Rogues always find a use."],
			L["Not your kind of magic, {name}. Call it a very clever lockpick."],
		},
	},
}

-- A people's own city, for its "city" lines, by the ids the client's maps
-- name it with: Undercity is 1458 on WoW Forever's world (as on Classic's) and
-- 90 on Retail's. A people with no city lines needs none.
RP.HOME = {
	forsaken = { [1458] = true, [90] = true },
}

-- The five lines beta.9 put in the box, frozen: a box saved with them is
-- still the untouched set however the pools above are rewritten, and the load
-- repair (RP.Repair) turns it into the examples as they read now. Nothing
-- here is ever said; these only recognise. Per people: its first thanks,
-- asked and offer; per side: the same three; then the general lines. A
-- people with none (the Haranir) saved its side's three and the general
-- thanks and offer; any other saved its three, its side's offer and the
-- general group line.
--
-- And `reworded`: example lines rewritten since boxes were saved with them,
-- each as it reads now and then as it read before, for RP.BEFORE below.
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
	-- The second rewording, after 1.7.x: every example line that was only local
	-- colour now speaks to the spell just cast, as it reads now and then as
	-- it read before. Kept apart from `reworded` because a box saved
	-- between the two holds `reworded`'s new lines with these lines' old ones
	-- (RP.BETWEEN); RP.BEFORE follows both, this list first. Listed before
	-- `reworded` so that, where a translation reads alike for both, the
	-- English key read last is the older one.
	reworded2 = {
		{ L["Off ye go, {name}, with a wee blessin' from me. Steady as the mountain."],
			L["Off ye go, {name}, steady as the mountain."] },
		{ L["There, {name}, that'll see ye through. Stand behind me. Aye, I know. Crouch."],
			L["Stand behind me, {name}. Aye, I know. Crouch a bit."] },
		{ L["Right, {name}: ye get this, I take the front, and we argue about loot after."],
			L["Right, {name}: I take the front, ye take the loot, and we argue after."] },
		{ L["Here, {name}. If I sing after this, the fight's gone well. Or very badly."],
			L["If I start singin', {name}, the fight's gone well. Or very badly."] },
		{ L["Fair winds and following seas, {name}, and this to carry you along."],
			L["Fair winds and following seas, {name}."] },
		{ L["Arathor's children stand together, {name}, and share what strength they have."],
			L["Arathor's children stand together, {name}."] },
		{ L["There, {name}. Humans have always won by outnumbering things, and by sharing."],
			L["Keep close, {name}. Humans have always won by outnumbering things."] },
		{ L["You're ready, {name}. Stay in formation. We haven't got one, but stay in it."],
			L["Stay in formation, {name}. We haven't got one, but stay in it anyway."] },
		{ L["Here, {name}. I'll draw up a plan too, and we can all ignore it together."],
			L["I'll draw up a plan, {name}, and then we can all ignore it together."] },
		{ L["Elune-adore, {name}. Her light goes with you. Walk softly; trees sleep lightly."],
			L["Elune-adore, {name}. Walk softly; the trees are light sleepers."] },
		{ L["Ishnu-alah, {name}. Elune keeps her children close, and so do I."],
			L["Ishnu-alah, {name}. Elune keeps her children close."] },
		{ L["Quick one, {name}? Take this now. By kaldorei reckoning we're already done."],
			L["Quick one, {name}? By kaldorei reckoning we'll be done before we start."] },
		{ L["That's from the one you can't see, {name}. Not a mistake; that's the plan."],
			L["I'll be the one you can't see, {name}. That's not a mistake; that's the plan."] },
		{ L["Elune watches the whole party, {name}. I just pass her light along."],
			L["Elune watches the whole party, {name}. I'm just the one who waves at her."] },
		{ L["The moon's up, {name}; here's her blessing. For a kaldorei, it's mid-morning."],
			L["The moon's up, {name}. For a kaldorei, this is the middle of the morning."] },
		{ L["Morning, {name}. My people slept through these; this will help us both adapt."],
			L["Morning, {name}. My people slept through these for millennia. I'm adapting."] },
		{ L["Walk carefully in the dark places, {name}. This will light a little of them."],
			L["Walk carefully in the dark places, {name}."] },
		{ L["Stay close, {name}, and take this. The whispers are much quieter in company."],
			L["Stay close, {name}. The whispers are much quieter in company."] },
		{ L["There, {name}. If the shadows start giving orders, ignore them. I usually do."],
			L["If the shadows start giving orders, {name}, ignore them. I usually do."] },
		{ L["Here, {name}. Keep an eye on my shadow. It wanders off when there's a fight."],
			L["Keep an eye on my shadow, {name}. It wanders off when there's a fight."] },
		{ L["Night suits the ren'dorei, {name}. We match the decor. Here's a little of it."],
			L["Night suits the ren'dorei, {name}. We match the decor."] },
		{ L["For Gnomeregan, {name}! Here, eye to eye. Always nice to give at eye level."],
			L["For Gnomeregan, {name}! Always nice to talk to somebody at eye level."] },
		{ L["I've run the numbers, {name}: with this on you, we win. I rounded up."],
			L["I've run the numbers, {name}: with you here, we win. I rounded up."] },
		{ L["There, {name}. If I shout 'duck', don't look for a duck. Last time went badly."],
			L["If I shout 'duck', {name}, don't look for a duck. That went badly last time."] },
		{ L["Morning, {name}! Up since three. The toaster needed an engine; you needed this."],
			L["Morning, {name}! Up since three. The toaster needed a new engine."] },
		{ L["There, {name}. I lost a world once; I'm keeping hold of this party."],
			L["Stay near, {name}. I lost a world once; I'm keeping hold of this party."] },
		{ L["Millennia on the run, {name}. Sharing the Light with friends is nicer."],
			L["Twenty-five thousand years on the run, {name}. Walking with friends is nicer."] },
		{ L["The naaru would call sharing Light a fellowship, {name}. I call it good luck."],
			L["The naaru would call this a fellowship, {name}. I call it good luck."] },
		{ L["Keep your wits about you, {name}, and this too. Something is always hunting."],
			L["Keep your wits about you, {name}. Something is always hunting."] },
		{ L["The curse binds us, {name}; Gilneas binds us tighter. Here, from one of yours."],
			L["The curse binds us, {name}, but Gilneas binds us tighter."] },
		{ L["Pack rules, {name}: nobody wanders off, everyone gets one, no talk of fleas."],
			L["Pack rules, {name}: nobody wanders off, and nobody mentions the fleas."] },
		{ L["A pack again, {name}, someone to look after. I hadn't known how I'd missed it."],
			L["A pack again, {name}. I hadn't known how much I'd missed one."] },
		{ L["Take this, {name}. I smell trouble first; it's the curse's one perk."],
			L["I'll catch the scent of trouble first, {name}. It's the one perk of the curse."] },
		{ L["Night again, {name}: my best and my worst. Giving you this is the best part."],
			L["Night again, {name}. I'm at my best and my worst. This is the best part."] },
		{ L["Morning, {name}. The rug by the fire was warm, but I got up to give you this."],
			L["Morning, {name}. I'd have been up sooner, but the rug by the fire was so warm."] },
		{ L["Blood and thunder, {name}! Take my strength and go earn your glory."],
			L["Blood and thunder, {name}! Go and earn your glory."] },
		{ L["Throm-ka, {name}! The blood of the clans runs strong in you. Stronger now."],
			L["Throm-ka, {name}! The blood of the clans runs strong in you."] },
		{ L["The plan, {name}: you take this, we hit it. Questions? No? Good plan."],
			L["The plan, {name}: we hit it. Questions? No? Good plan."] },
		{ L["A true warband, {name}: loud, angry, blessed, and on the same side for once."],
			L["A true warband, {name}. Loud, angry, and all on the same side for once."] },
		{ L["Stay with the warband, {name}. Strength in numbers, in axes, and in this."],
			L["Stay with the warband, {name}. Strength in numbers. And in axes."] },
		{ L["Take this; stay alive, {name}. Undercity's housing list is already very long."],
			L["Stay alive, {name}. Undercity's housing list is already very long."] },
		{ L["That's for you, {name}. If I fall down, give it a minute. Old habit."],
			L["If I fall down, {name}, give it a minute. Old habit."] },
		{ L["Here, {name}. I'll take the front. What's the worst that could happen? Again?"],
			L["I'll take the front, {name}. What's the worst that could happen? Again?"] },
		{ L["The dead keep terrible hours, {name}. Nice to have someone to give this to."],
			L["The dead keep terrible hours, {name}. Nice to have company for once."] },
		{ L["Morning, {name}? I've been up all night, and all of last decade. Have this."],
			L["Morning already, {name}? I've been up all night. And all of last decade."] },
		{ L["Take this, {name}, and walk with the Earth Mother. You can't get lost."],
			L["Walk with the Earth Mother, {name}. She's everywhere, so you can't get lost."] },
		{ L["May An'she light your path, {name}, and this go with you."],
			L["May An'she light your path, {name}."] },
		{ L["The Earth Mother watches over us both, {name}. Today I'll help her."],
			L["The Earth Mother watches over us both, {name}."] },
		{ L["Take this, {name}, and get behind me. There's room for the whole party."],
			L["Get behind me, {name}. There's room back there for the whole party."] },
		{ L["The herd moves together, {name}, blessed. Mind my hooves; the herd has learned."],
			L["The herd moves together, {name}. Mind my hooves; the herd has learned to."] },
		{ L["An'she rises, {name}, and so do we, with this. Slower, in my case."],
			L["An'she rises, {name}, and so do we. Slower, in my case."] },
		{ L["Mu'sha keeps the night watch, {name}. I'll keep an eye on you too. Here."],
			L["Mu'sha keeps the night watch, {name}. I'll tell her to keep an eye on you."] },
		{ L["Stay close, {name}. Trolls regenerate; da rest of ya get this instead."],
			L["Stay close, {name}. Trolls regenerate; da rest of ya gotta be careful."] },
		{ L["We go in together, {name}, blessed, and come out together. That's the plan."],
			L["We go in together, {name}, we come out together. That's the plan, mon."] },
		{ L["Shorel'aran, {name}. Fight with elegance, and with this."],
			L["Shorel'aran, {name}. Fight with elegance."] },
		{ L["The Sunwell shines for us both, {name}. Let me share its light."],
			L["The Sunwell shines for us both, {name}."] },
		{ L["Do keep pace, {name}; you're blessed now. We're known for arriving beautifully."],
			L["Do keep pace, {name}. We have a reputation for arriving beautifully."] },
		{ L["Stand where the light is good, {name}. With this on you, we'll look splendid."],
			L["Stand where the light is good, {name}. If we must fight, we'll look splendid."] },
		{ L["A party at last, {name}. I did dress for one, and I brought gifts."],
			L["A party at last, {name}. I did dress for one."] },
		{ L["The sun has risen, {name}, and so have I. We coordinate. Here's its light."],
			L["The sun has risen, {name}, and so have I. We coordinate."] },
		{ L["Suramar's children shine together again, {name}. Let me add to your glow."],
			L["Suramar's children shine together again, {name}."] },
		{ L["An expedition, {name}! In Suramar this blessing needed six permits."],
			L["An expedition, {name}! In Suramar this needed six permits and a masquerade."] },
		{ L["The dome kept us safe, {name}. Now one another must. Gladly; here."],
			L["The dome kept us safe, {name}. Now we must make do with one another. Gladly."] },
		{ L["Night at last, {name}. Add this glow and some lanterns: nearly Suramar."],
			L["Night at last, {name}. Add a few thousand lanterns and it's nearly Suramar."] },
		{ L["Daylight, {name}. Ten thousand years under a dome, and it startles me. Here."],
			L["Daylight, {name}. Ten thousand years under a dome, and it still startles me."] },
		{ L["Nobody dies on my contract, {name}. Here's insurance. The paperwork's awful."],
			L["Nobody dies on my contract, {name}. The paperwork's a nightmare."] },
		{ L["We split the take even, {name}. This is your share. I did the maths. Trust me."],
			L["We split the take even, {name}. I'll do the maths. Trust me."] },
		{ L["A fellow wanderer! The caravan is never far, {name}, nor its gifts."],
			L["A fellow wanderer! The caravan is never far, {name}."] },
		{ L["Caravan rules, {name}: stick together, share water and this. Never the alpaca."],
			L["Caravan rules, {name}: stay together, share the water, nobody sells the alpaca."] },
		{ L["Anything shiny in there, {name}, I saw it first. This shiny bit is yours."],
			L["Anything shiny in there, {name}, I saw it first. Caravan law."] },
		{ L["We vulpera travel by night, {name}. Cool sand, sleepy scorpids, and this."],
			L["We vulpera travel by night, {name}. Cool sand, sleepy scorpids."] },
		{ L["Balance in all things, {name}. Take this, and go with a light heart."],
			L["Balance in all things, {name}. Now go with a light heart."] },
		{ L["We must share a brew when the road allows, {name}! For now, share this."],
			L["We must share a brew when the road allows, {name}!"] },
		{ L["A gift, a fight, then a meal, {name}. That is the correct order."],
			L["A fight, then a meal, {name}. That is the correct order. Never the reverse."] },
		{ L["Stay together, {name}, like dumplings in a steamer. Warm now, and ready."],
			L["Stay together, {name}, like dumplings in a steamer. Warm, and ready."] },
		{ L["We move as one, {name}, and now blessed as one. Slowly, perhaps."],
			L["We move as one, {name}. Slowly, perhaps, but as one."] },
		{ L["Past my first nap, {name}, before my second. Take this while I'm awake."],
			L["Past my first nap, {name}, and before my second. Quickly, while I'm awake."] },
		{ L["The Forbidden Reach is far behind us, {name}. What we learned there, I share."],
			L["The Forbidden Reach feels far behind us now, {name}."] },
		{ L["Take this, {name}. Then tell me when to breathe fire. And when not to."],
			L["Tell me when to breathe fire, {name}. And, please, when not to."] },
		{ L["I woke in a cave of strangers, {name}. Now I give gifts to company. Better."],
			L["I woke in a cave full of strangers, {name}. This is far better company."] },
		{ L["Neltharion made us to fight alone, {name}. We improved on him. Here."],
			L["Neltharion made us to fight alone, {name}. We have improved on him."] },
		{ L["Thank you, {name}. Hagar sent me to see the goddess's work. You're her best."],
			L["Hagar sent me to see the goddess's work, {name}. You're some of her best."] },
		{ L["Two haranir out in the world, {name}. The elders would fret. I'll help instead."],
			L["Two haranir out in the world, {name}. No wonder the elders are up in arms."] },
		{ L["We once mastered every beast on our mountain, {name}. With this, these won't."],
			L["We once mastered every beast on our mountain, {name}. These won't take long."] },
		{ L["Word from Harandar, {name}: the haranir join the fight. This is my part."],
			L["Word from Harandar, {name}: the haranir are ready to join the fight."] },
		{ L["It is good to see one of our own, {name}. This is how we greet them."],
			L["It is good to see one of our own, {name}."] },
		{ L["Thank you, {name}. Stormwind has a statue for every hero. I'll put in a word."],
			L["Stormwind has a statue for every hero, {name}. I'm putting in a word for yours."] },
		{ L["Onward, {name}, and take this. The Alliance is with you."],
			L["Onward, {name}. The Alliance is with you."] },
		{ L["Together we stand, {name}, and share. For the Alliance!"],
			L["Together we stand, {name}. For the Alliance!"] },
		{ L["Right, {name}: take this, shields up, and nobody charges before the plan does."],
			L["Right, {name}: shields up, heads down, and nobody charges before the plan does."] },
		{ L["The finest company the Alliance ever fielded, {name}. Best equipped, too, now."],
			L["The finest company the Alliance ever fielded, {name}. Or at least the nearest."] },
		{ L["Go with honour, {name}, and with this. Victory awaits."],
			L["Go with honour, {name}. Victory awaits."] },
		{ L["Take this, {name}; do something worth a song. Loud songs. The Horde likes loud."],
			L["Go and do something worth a song, {name}. Loud songs. The Horde likes loud."] },
		{ L["Walk tall, {name}. The Horde made room for those the world turned away. Here."],
			L["Walk tall, {name}. The Horde always made room for those the world turned away."] },
		{ L["Our strength is each other, {name}. Here's some of mine. For the Horde!"],
			L["Our strength is each other, {name}. For the Horde!"] },
		{ L["Forward, {name}, and take this. The Horde advances together. Retreats... never."],
			L["Forward, {name}. The Horde advances together. Retreats... never, officially."] },
		{ L["Together we're a war band, {name}. Apart, we're just loud. Take this."],
			L["Together we're a war band, {name}. Apart, we're just loud."] },
		{ L["Friends can come from any side, {name}. Or from none, like me. Here."],
			L["Friends can come from any side, {name}. Or, like me, from none in particular."] },
		{ L["Side by side, {name}, whatever comes. Take this."],
			L["Side by side, {name}, whatever comes."] },
		{ L["No flag over this party, {name}, just us, and this. That's plenty."],
			L["No flag over this party, {name}, just us. That's plenty."] },
		{ L["One day we'll pick sides, {name}. Today we share this and pick fights together."],
			L["One day we'll pick sides, {name}. Today we pick fights, together."] },
		{ L["Your stance says long day, {name}. Monks notice. Take this."],
			L["Your stance says you've had a long day, {name}. Monks notice these things."] },
		{ L["We have to stop meeting like this, {name}. Actually, no. Here's another one."],
			L["We have to stop meeting like this, {name}. Actually, no, we don't."] },
		{ L["A villain in here rehearses a speech, {name}. Take this, then let's interrupt."],
			L["Somewhere in here a villain is rehearsing a speech, {name}. Let's interrupt."] },
	},
	-- The review of the lines after 1.6.4: the trolls' examples, written
	-- more plainly, and a goblin's group line. Then the race voices: Magni
	-- is the living king of Ironforge in this world, not a diamond.
	reworded = {
		{ L["Ya too kind, {name}! This one's from me."],
			L["Ya be too kind, {name}! Dis one be from me."] },
		{ L["Death's gonna be real disappointed, {name}. Thanks, mon."],
			L["Bwonsamdi gonna be real disappointed, {name}. Thanks, mon."] },
		{ L["Sure thing, {name}. Hold still; mojo hates a movin' target."],
			L["Sure ting, {name}. Hold still; da mojo don't like a movin' target."] },
		{ L["No trouble, {name}. Da loa like ya."],
			L["No worries, {name}. Da loa got ya covered."] },
		{ L["Stay away from da voodoo, {name}. Except this one. This one's fine."],
			L["Stay away from da voodoo, {name}. ...Except dis voodoo. Dis one fine."] },
		{ L["Da loa watch over ya, {name}. They're real nosy that way."],
			L["Da loa be watchin' over ya, {name}. Dey real nosy like dat."] },
		{ L["Stay sharp, {name}. Take this with ya."],
			L["Stay sharp out dere, {name}. Take dis wit' ya."] },
		{ L["Here, {name}. Walk like ya own the jungle. I do."],
			L["Take dis, {name}. Walk like ya own da jungle. I do."] },
		{ L["We look after our own, {name}. Always, mon."],
			L["Hey, {name}! Always good to see family, mon."] },
		{ L["Crew's got style, {name}. Now it's got mojo too."],
			L["Dis crew got style, {name}. Now it got mojo too."] },
		{ L["We go in together, {name}, we come out together. That's the plan, mon."],
			L["We go in together, {name}, we come out together. Dat be da whole plan, mon."] },
		{ L["Night's the best time for mojo, {name}. Nobody sees where it's from."],
			L["Night be da best time for mojo, {name}. Nobody see where it come from."] },
		{ L["We split the take even, {name}. I'll do the maths. Trust me."],
			L["We split the loot even, {name}. I'll do the maths. Trust me."] },
		{ L["Magni'd melt down his crown fer a friend, {name}. This is the cheaper option."],
			L["Magni turned to diamond fer the cause, {name}. This is the cheaper option."] },
	},

}

-- And what the examples' translations read before they were reworded: the
-- 1.6.6 pass "Translations read for fluency" changed lines that are examples
-- (Ishnu-alah spelled in Hangul for the night elves, the dwarves' and trolls'
-- lines in most languages), and a box saved by an earlier release holds them
-- as they read then, in the language it was filled in. Per language (esES
-- answers esMX), each English key with the lines it was translated as, never
-- said: RP.Active reads a line of a box that is one of these as the line it
-- is today. A translation of an example edited from now on needs its old
-- text here too: python tools/legacy_lines.py --check says which are
-- missing, --lua prints the table.
RP.LEGACY_TRANSLATED = {
	deDE = {
		["A gift freely given, {name}. The naaru hum a little louder. Returned."] = { "Freimütig gegeben, {name}. Die Naaru summen etwas lauter. Erwidert." },
		["Bwonsamdi gonna be real disappointed, {name}. Thanks, mon."] = { "Bwonsamdi sein jetzt echt enttäuscht, {name}. Danke, Mann." },
		["Da loa be watchin' over ya, {name}."] = { "Die Loa, die wachen über Euch, {name}." },
		["Da loa be watchin' over ya, {name}. Dey real nosy like dat."] = { "Die Loa wachen über Euch, {name}. Die sein echt neugierig." },
		["Night be da best time for mojo, {name}. Nobody see where it come from."] = { "Nacht sein die beste Zeit für Mojo, {name}. Keiner sieht, woher's kommt." },
		["No worries, {name}. Da loa got ya covered."] = { "Keine Sorge, {name}. Die Loa sein bei Euch." },
		["Stay away from da voodoo, {name}. ...Except dis voodoo. Dis one fine."] = { "Haltet Euch vom Voodoo fern, {name}. ...Außer von dem hier. Das sein gut." },
		["We go in together, {name}, we come out together. Dat be da whole plan, mon."] = { "Zusammen rein, {name}, zusammen raus. Das sein der ganze Plan, Mann." },
	},
	esES = {
		["A gift with no favour owed? The court would faint. Thank you, {name}."] = { "¿Un regalo sin deber favores? La corte se desmayaría. Gracias, {name}." },
		["Bwonsamdi gonna be real disappointed, {name}. Thanks, mon."] = { "Bwonsamdi se va a llevar un buen chasco, {name}. Gracia', mon." },
		["Da loa be watchin' over ya, {name}. Dey real nosy like dat."] = { "Lo' loa velan por ti, {name}. Son mu' fisgones, mon." },
		["Da loa watch over ya, {name}. They're real nosy that way."] = { "Lo' loa te cuidan, {name}. Son bien curioso'." },
		["Death's gonna be real disappointed, {name}. Thanks, mon."] = { "La muerte se va a llevar un buen chasco, {name}. Gracia', mon." },
		["Here, {name}, a wee somethin' to keep ye on yer feet."] = { "Aquí tienes, {name}, algo pa' que no flaquees." },
		["Here, {name}, a wee somethin' to keep ye on yer feet. Wee, like me."] = { "Toma, {name}, un detallito pa' que no flaquees. Chiquito, como yo." },
		["Here, {name}. Ale's for after; this is for before."] = { "Toma, {name}. La cerveza, pa' después; esto, pa' antes." },
		["Mornin', {name}! Too early for ale. Almost. Have this first."] = { "¡Buenos días, {name}! Temprano pa' la cerveza. Casi. Toma esto antes." },
		["Night be da best time for mojo, {name}. Nobody see where it come from."] = { "La noche e' la mejor hora pa'l mojo, {name}. Nadie ve de dónde sale." },
		["No trouble, {name}. Da loa like ya."] = { "Sin problema, {name}. Lo' loa te quieren." },
		["Stay away from da voodoo, {name}. ...Except dis voodoo. Dis one fine."] = { "Aléjate del vudú, {name}. ...Menos de este vudú. Este tá bien." },
		["Stay away from da voodoo, {name}. Except this one. This one's fine."] = { "Aléjate del vudú, {name}. Meno' de este. Este está bien." },
		["Stay close, {name}. Trolls regenerate; da rest of ya gotta be careful."] = { "No te alejes, {name}. Un trol se regenera; lo' demás, cuidadito." },
		["Sure thing, {name}. Hold still; mojo hates a movin' target."] = { "Seguro, {name}. No te mueva': el mojo odia lo que se mueve." },
		["Sure ting, {name}. Hold still now."] = { "Claro que sí, {name}. No te mueva' ahora." },
		["Sure ting, {name}. Hold still; da mojo don't like a movin' target."] = { "Claro, {name}. No te mueva': el mojo odia los blancos móviles." },
		["We go in together, {name}, we come out together. Dat be da whole plan, mon."] = { "Entramo' juntos, {name}, salimo' juntos. Ese e' to' el plan, mon." },
		["We go in together, {name}, we come out together. That's the plan, mon."] = { "Entramo' junto', {name}, y salimo' junto'. Ese e' el plan, mon." },
		["We look after our own, {name}. Always, mon."] = { "Cuidamo' de los nuestro', {name}. Siempre, mon." },
		["Ya be too kind, {name}! Dis one be from me."] = { "¡Ere' mu' amable, {name}! Esta va de mi parte." },
		["Ya look like somebody who appreciate quality, {name}. Here: quality."] = { "Parece' alguien que aprecia la calidad, {name}. Toma: calidad." },
		["Ya too kind, {name}! This one's from me."] = { "¡Qué amable ere', {name}! Esto va de mi parte." },
	},
	frFR = {
		["Ask a dwarf fer help, {name}, and ye'll get it. Loudly."] = { "Demandez d'l'aide à un nain, {name} : vous l'aurez. Et vous l'entendrez." },
		["Aw, {name}. I'd invoice you, but I'm feeling sentimental. It'll pass."] = { "Oh, {name}. J'vous facturerais bien, mais je suis d'humeur sentimentale. Ça passera." },
		["Aye, {name}, ye only had to ask. Hold still now!"] = { "Pour sûr, {name}, suffisait d'demander. Bougez plus !" },
		["Aye, {name}, ye only had to ask. Hold still now, like a good anvil."] = { "Pour sûr, {name}, suffisait d'demander. Bougez plus, comme une bonne enclume." },
		["Bless ye, {name}! I'd hug ye, but ye'd be needin' a healer after."] = { "Merci, {name} ! Une accolade ? Non, z'auriez besoin d'un soigneur après." },
		["Bwonsamdi gonna be real disappointed, {name}. Thanks, mon."] = { "Bwonsamdi, il va être bien déçu, {name}. Merci, l'ami." },
		["Crew's got style, {name}. Now it's got mojo too."] = { "L'équipe a du style, {name}. Et maint'nant, du mojo." },
		["Da loa be watchin' over ya, {name}."] = { "Les loa, ils veillent sur vous, {name}." },
		["Da loa be watchin' over ya, {name}. Dey real nosy like dat."] = { "Les loa, ils veillent sur vous, {name}. Des vrais fouineurs, ceux-là." },
		["Deal, {name}! I'll put it on your tab. Kidding!"] = { "Marché conclu, {name} ! Je le mets sur votre ardoise. J'rigole !" },
		["Dis crew got style, {name}. Now it got mojo too."] = { "C'groupe a du style, {name}. Et maint'nant, du mojo." },
		["Early bird gets the gold, {name}! Here's a freebie. Don't tell the other birds."] = { "L'or appartient à ceux qui se lèvent tôt, {name} ! Un cadeau. Le dites pas aux autres lève-tôt." },
		["Here, {name}, a wee somethin' to keep ye on yer feet."] = { "Tenez, {name}, un p'tit quelque chose pour vous garder d'aplomb." },
		["Here, {name}, a wee somethin' to keep ye on yer feet. Wee, like me."] = { "Tenez, {name}, un p'tit quelque chose pour vous garder d'aplomb. P'tit, comme moi." },
		["Here, {name}. If anything explodes near you today, that was unrelated."] = { "Tenez, {name}. Si quelque chose explose près de vous aujourd'hui, j'y suis pour rien." },
		["Here, {name}. Walk like ya own the jungle. I do."] = { "Tenez, {name}. Marchez comme si la jungle était à vous. Moi, c'est l'cas." },
		["Hey, {name}! Always good to see family, mon."] = { "Hé, {name} ! C'est toujours bon d'voir la famille, ça." },
		["If I start singin', {name}, the fight's gone well. Or very badly."] = { "Si j'me mets à chanter, {name}, c'est qu'le combat s'passe bien. Ou très mal." },
		["Mornin', {name}! Too early for ale. Almost. Have this first."] = { "B'jour, {name} ! Trop tôt pour une bière. Presque. Prenez d'abord ça." },
		["Much obliged, {name}. Ye've a friend in the mountain now."] = { "Mille mercis, {name}. Z'avez un ami dans la montagne, maint'nant." },
		["Night be da best time for mojo, {name}. Nobody see where it come from."] = { "La nuit, c'est l'meilleur moment pour l'mojo, {name}. Personne voit d'où il vient." },
		["Night's the best time for mojo, {name}. Nobody sees where it's from."] = { "La nuit, c'est l'meilleur moment pour l'mojo, {name}. Personne voit d'où il vient." },
		["No trouble, {name}. Da loa like ya."] = { "Pas d'souci, {name}. Les loa vous aiment bien." },
		["No worries, {name}. Da loa got ya covered."] = { "Pas d'souci, {name}. Les loa, ils vous couvrent." },
		["Nobody dies on my contract, {name}. The paperwork's a nightmare."] = { "Personne meurt sous mon contrat, {name}. La paperasse, c'est l'enfer." },
		["Right, {name}: I take the front, ye take the loot, and we argue after."] = { "Bon, {name} : j'prends l'avant, vous prenez l'butin, et on s'dispute après." },
		["Say no more, {name}. Stone and steel, here it comes."] = { "Pas un mot d'plus, {name}. Par la pierre et l'acier, ça vient !" },
		["Stand behind me, {name}. Aye, I know. Crouch a bit."] = { "Derrière moi, {name}. Oui, j'sais. Baissez-vous un peu." },
		["Stay away from da voodoo, {name}. ...Except dis voodoo. Dis one fine."] = { "Restez loin du vaudou, {name}. ...Sauf c'vaudou-là. Lui, il est bien." },
		["Stay close, {name}. Trolls regenerate; da rest of ya gotta be careful."] = { "Restez près d'moi, {name}. Les trolls, ça régénère ; vous autres, faites attention." },
		["Stay sharp out dere, {name}. Take dis wit' ya."] = { "Faites gaffe dehors, {name}. Prenez ça avec vous." },
		["Sure thing, {name}. Hold still; mojo hates a movin' target."] = { "Bien sûr, {name}. Bougez plus ; le mojo déteste les cibles qui bougent." },
		["Sure ting, {name}. Hold still now."] = { "Bien sûr, {name}. Bougez plus, là." },
		["Sure ting, {name}. Hold still; da mojo don't like a movin' target."] = { "Bien sûr, {name}. Bougez plus, là ; le mojo, il aime pas les cibles qui bougent." },
		["Take dis, {name}. Walk like ya own da jungle. I do."] = { "Prenez ça, {name}. Marchez comme si la jungle était à vous. Moi, c'est l'cas." },
		["Thanks, mon! Da spirits smile on ya, {name}."] = { "Merci, l'ami ! Les esprits, ils vous sourient, {name}." },
		["Thanks, {name}! I checked it for fine print. There wasn't any. Weird!"] = { "Merci, {name} ! J'ai cherché les petites lignes. Y en avait pas. Bizarre !" },
		["We go in together, {name}, we come out together. Dat be da whole plan, mon."] = { "On entre ensemble, {name}, on sort ensemble. C'est tout l'plan, l'ami." },
		["We go in together, {name}, we come out together. That's the plan, mon."] = { "On entre ensemble, {name}, on sort ensemble. C'est ça, l'plan, l'ami." },
		["Ya be too kind, {name}! Dis one be from me."] = { "Trop gentil, {name} ! Et çui-là, il vient d'moi." },
		["Ya gave me good mojo, {name}. Now ya get some back, extra spicy."] = { "Vous m'avez donné du bon mojo, {name}. Maint'nant, vous en r'cevez, extra épicé." },
		["Ya look like somebody who appreciate quality, {name}. Here: quality."] = { "Vous avez l'air d'aimer la qualité, {name}. Tenez : d'la qualité." },
		["Ya too kind, {name}! This one's from me."] = { "Trop gentil, {name} ! Çui-là, il vient d'moi." },
	},
	itIT = {
		["Bless ye, {name}! I'd hug ye, but ye'd be needin' a healer after."] = { "Evviva, {name}! Ti abbraccerei, ma poi ti servirebbe un guaritore." },
		["Bwonsamdi gonna be real disappointed, {name}. Thanks, mon."] = { "Bwonsamdi ce resta malissimo, {name}. Grazie, cumpà." },
		["Crew's got style, {name}. Now it's got mojo too."] = { "Stu gruppo tene stile, {name}. E mo' pure 'o mojo." },
		["Da loa be watchin' over ya, {name}."] = { "'E loa te guardano 'e spalle, {name}." },
		["Da loa be watchin' over ya, {name}. Dey real nosy like dat."] = { "'E loa te guardano 'e spalle, {name}. So' curiosi assaje." },
		["Da loa watch over ya, {name}. They're real nosy that way."] = { "'E loa te tengono d'uocchio, {name}. So' curiuse assaje." },
		["Death's gonna be real disappointed, {name}. Thanks, mon."] = { "'A morte ce resta proprio male, {name}. Grazie, cumpà." },
		["Dis crew got style, {name}. Now it got mojo too."] = { "Sta compagnia tene stile, {name}. Mo' tene pure 'o mojo." },
		["Here, {name}. Walk like ya own the jungle. I do."] = { "Piglia, {name}. Cammina comm'a padrone d''a giungla. Io 'o faccio." },
		["Hey, {name}! Always good to see family, mon."] = { "Uè, {name}! Fa sempre piacere vedé 'a famiglia, cumpà." },
		["Night be da best time for mojo, {name}. Nobody see where it come from."] = { "'A notte è l'ora d''o mojo, {name}. Nisciuno vede da dove vene." },
		["Night's the best time for mojo, {name}. Nobody sees where it's from."] = { "'A notte è 'o mumento meglio p''o mojo, {name}. Nisciuno vede 'a do' vene." },
		["No trouble, {name}. Da loa like ya."] = { "Nisciun problema, {name}. 'E loa te vonno bene." },
		["No worries, {name}. Da loa got ya covered."] = { "Nun te preoccupà, {name}. Ce pensano 'e loa." },
		["Stay away from da voodoo, {name}. ...Except dis voodoo. Dis one fine."] = { "Statte luntano d''o voodoo, {name}. ...Tranne chisto. Chisto va bbuono." },
		["Stay away from da voodoo, {name}. Except this one. This one's fine."] = { "Statte luntano d''o voodoo, {name}. Chisto no: chisto è bbuono." },
		["Stay close, {name}. Trolls regenerate; da rest of ya gotta be careful."] = { "Stamme vicino, {name}. 'E troll se rigenerano; vuje no, quindi occhio." },
		["Stay sharp out dere, {name}. Take dis wit' ya."] = { "Occhi aperti llà fore, {name}. Pigliate chisto." },
		["Stay sharp, {name}. Take this with ya."] = { "Uocchie aperte, {name}. Portate chisto." },
		["Sure thing, {name}. Hold still; mojo hates a movin' target."] = { "Va bbuono, {name}. Nun te movere: 'o mojo odia chi se move." },
		["Sure ting, {name}. Hold still now."] = { "Sicuro, {name}. Mo' nun te movere." },
		["Sure ting, {name}. Hold still; da mojo don't like a movin' target."] = { "Sicuro, {name}. Nun te movere: 'o mojo nun ama 'e bersagli mobili." },
		["Take dis, {name}. Walk like ya own da jungle. I do."] = { "Piglia, {name}. Cammina da padrone d''a giungla. Comme a me." },
		["Take it, {name}, I've a spare. I've three spares of everything."] = { "Prendi, {name}, ho il ricambio. Ho tre ricambi di tutto." },
		["Thanks, mon! Da spirits smile on ya, {name}."] = { "Grazie assaje, cumpà! 'E spiriti te sorrideno, {name}." },
		["We go in together, {name}, we come out together. Dat be da whole plan, mon."] = { "Trasimmo insieme, {name}, e ascimmo insieme. Chisto è tutto 'o piano, cumpà." },
		["We go in together, {name}, we come out together. That's the plan, mon."] = { "Trasimmo 'nzieme, {name}, e ascimmo 'nzieme. Chisto è 'o piano, cumpà." },
		["We look after our own, {name}. Always, mon."] = { "Nuje penzammo a 'e nuoste, {name}. Sempe, cumpà." },
		["Ya be too kind, {name}! Dis one be from me."] = { "Si' troppo gentile, {name}! Chisto t'o dong' io." },
		["Ya gave me good mojo, {name}. Now ya get some back, extra spicy."] = { "M'hai dato buon mojo, {name}. Mo' te lo torno, cu 'o peperoncino." },
		["Ya look like somebody who appreciate quality, {name}. Here: quality."] = { "Tieni 'a faccia 'e chi apprezza 'a qualità, {name}. Ecco: qualità." },
		["Ya too kind, {name}! This one's from me."] = { "Si' troppo gentile, {name}! Chisto è da parte mia." },
	},
	koKR = {
		["Anar'alah belore, {name}. May the sun guide you, and light your good side."] = { "Anar'alah belore, {name}. 태양이 그대를 인도하고, 잘 나온 쪽을 비추기를." },
		["Anar'alah belore, {name}. May the sun guide you."] = { "Anar'alah belore, {name}. 태양이 그대를 인도하기를." },
		["Archenon poros, {name}! The children of Argus look after one another."] = { "Archenon poros, {name}! 아르거스의 자손은 서로를 돌보지요." },
		["Archenon poros, {name}. Your gift is returned."] = { "Archenon poros, {name}. 받은 선물을 돌려드립니다." },
		["Dabu, {name}. It is done."] = { "Dabu, {name}. 다 됐다." },
		["Elune-adore, {name}. Walk softly beneath the stars."] = { "Elune-adore, {name}. 별빛 아래 사뿐히 걷기를." },
		["Elune-adore, {name}. Walk softly; the trees are light sleepers."] = { "Elune-adore, {name}. 사뿐히 걸으시오. 나무들은 잠귀가 밝으니." },
		["Ishnu-alah, {name}. Elune keeps her children close."] = { "Ishnu-alah, {name}. 엘룬께선 자녀들을 늘 곁에 두시지요." },
		["Ishnu-alah, {name}. Returned the same day, which for a kaldorei is rushing."] = { "Ishnu-alah, {name}. 당일에 갚다니, 칼도레이로선 서두른 셈이오." },
		["Ishnu-alah, {name}. Your kindness is returned."] = { "Ishnu-alah, {name}. 그대의 호의를 돌려드리리다." },
		["Lok'tar ogar, {name}! Take this into battle."] = { "Lok'tar ogar, {name}! 이걸 품고 전장으로 가라!" },
		["Lok'tar ogar, {name}! Take this into battle. A tavern brawl also counts."] = { "Lok'tar ogar, {name}! 이걸 품고 전장으로 가라. 술집 싸움도 전장이다." },
		["Shorel'aran, {name}. Fight with elegance."] = { "Shorel'aran, {name}. 우아하게 싸우시길." },
		["Such courtesy does you credit, {name}. Anar'alah belore."] = { "그 예의, 칭찬할 만하군요, {name}. Anar'alah belore." },
		["Throm-ka, {name}! Honour is repaid."] = { "Throm-ka, {name}! 명예로 갚는다!" },
		["Throm-ka, {name}! The blood of the clans runs strong in you."] = { "Throm-ka, {name}! 네 안에 부족의 피가 힘차게 흐르는군." },
	},
	ptBR = {
		["A gift freely given, {name}. The naaru hum a little louder. Returned."] = { "Um presente dado de coração, {name}. Os Naarus zumbem mais alto. Retribuído." },
		["Ask a dwarf fer help, {name}, and ye'll get it. Loudly."] = { "Pede ajuda a um anão, {name}, e cê ganha. Aos berros." },
		["Bless ye, {name}! I'd hug ye, but ye'd be needin' a healer after."] = { "Brigadão, {name}! Te daria um abraço, mas depois cê ia precisar de curador." },
		["Much obliged, {name}. Ye've a friend in the mountain now."] = { "Valeu demais, {name}. Agora cê tem amigos na montanha." },
		["Of course, {name}. The naaru guide your steps; this puts a spring in them."] = { "Claro, {name}. Os Naarus guiam seus passos; isto dá um gás neles." },
		["Right, {name}: I take the front, ye take the loot, and we argue after."] = { "Combinado, {name}: eu vou na frente, cê pega o saque e depois a gente briga." },
		["Thanks, mon! Da spirits smile on ya, {name}."] = { "Valeu, mano! Os espíritos sorriem procê, {name}." },
		["The naaru would call this a fellowship, {name}. I call it good luck."] = { "Os Naarus chamariam isto de irmandade, {name}. Eu chamo de sorte." },
		["Ya be too kind, {name}! Dis one be from me."] = { "Cê é gente boa demais, {name}! Essa vai de mim." },
		["Ya gave me good mojo, {name}. Now ya get some back, extra spicy."] = { "Cê me deu mojo bom, {name}. Agora toma de volta, extra apimentado." },
		["Ya look like somebody who appreciate quality, {name}. Here: quality."] = { "Cê tem cara de quem curte qualidade, {name}. Toma: qualidade." },
		["Ya too kind, {name}! This one's from me."] = { "Cê é gentil demais, {name}! Essa é por minha conta." },
	},
	zhCN = {
		["Crew's got style, {name}. Now it's got mojo too."] = { "这队人有派头，{name}。现在还有巫毒咧。" },
		["Da loa be watchin' over ya, {name}."] = { "洛阿在守着你咧，{name}。" },
		["Da loa be watchin' over ya, {name}. Dey real nosy like dat."] = { "洛阿在守着你咧，{name}。他们就是这么爱管闲事。" },
		["Da loa watch over ya, {name}. They're real nosy that way."] = { "洛阿看着你咧，{name}。它们就是这么爱管闲事。" },
		["Death's gonna be real disappointed, {name}. Thanks, mon."] = { "死神这下要失望透咧，{name}。谢啦，老兄。" },
		["Here, {name}, a wee somethin' to keep ye on yer feet. Wee, like me."] = { "喏，{name}，一点小意思，保你站得稳。小，跟俺一个样。" },
		["If I start singin', {name}, the fight's gone well. Or very badly."] = { "要是俺唱起歌来，{name}，就是仗打得顺。或者糟透了。" },
		["No trouble, {name}. Da loa like ya."] = { "小事，{name}。洛阿喜欢你咧。" },
		["No worries, {name}. Da loa got ya covered."] = { "莫担心，{name}。洛阿罩着你咧。" },
		["Right, {name}: I take the front, ye take the loot, and we argue after."] = { "说好了，{name}：俺打头阵，你捡战利品，完事再吵。" },
		["Stand behind me, {name}. Aye, I know. Crouch a bit."] = { "站俺后头，{name}。嗯，俺知道。你蹲低点儿。" },
		["Stay close, {name}. Trolls regenerate; da rest of ya gotta be careful."] = { "跟紧点，{name}。巨魔能再生，你们其他人可得小心咧。" },
		["Stone and hammer keep ye, cousin {name}!"] = { "愿石与锤护着你，老表{name}！" },
		["Such courtesy does you credit, {name}. Nearly as much as it does me."] = { "如此礼数，为你增光，{name}。差不多跟为我增的光一样多。" },
		["Sure thing, {name}. Hold still; mojo hates a movin' target."] = { "没问题，{name}。别动，巫毒最讨厌移动靶咧。" },
		["Sure ting, {name}. Hold still; da mojo don't like a movin' target."] = { "小事一桩，{name}。莫乱动，巫毒不喜欢移动靶咧。" },
		["Thank ye kindly, {name}! First round's on me when we're back at the forge."] = { "多谢啦，{name}！回到熔炉边，头一轮酒俺请！" },
		["Thank ye, {name}! I'd have been fine without it, mind. But thank ye."] = { "谢啦，{name}！没它俺也扛得住，真的。不过还是谢啦！" },
		["Thanks, mon! Da spirits smile on ya, {name}."] = { "谢啦，伙计！众灵在冲你笑咧，{name}。" },
		["The Sunwell shines for us both, {name}."] = { "太阳之井为我们闪耀，{name}。" },
		["Ya gave me good mojo, {name}. Now ya get some back, extra spicy."] = { "你给了我好巫毒，{name}。现在还你一份，加辣的咧。" },
		["Ya too kind, {name}! This one's from me."] = { "你太客气咧，{name}！这个是我送的。" },
	},
	zhTW = {
		["Da loa be watchin' over ya, {name}."] = { "羅亞在看著你哩，{name}。" },
		["Da loa be watchin' over ya, {name}. Dey real nosy like dat."] = { "羅亞在看著你哩，{name}。祂們可愛管閒事了。" },
		["Here, {name}, a wee somethin' to keep ye on yer feet. Wee, like me."] = { "來，{name}，小小心意讓你站穩腳。小，跟俺一樣！" },
		["Here, {name}. Walk like ya own the jungle. I do."] = { "給你，{name}。走路要像叢林是你家的。咱就這樣走。" },
		["If I start singin', {name}, the fight's gone well. Or very badly."] = { "俺要是開唱，{name}，不是打得很順，就是很慘。" },
		["Right, {name}: I take the front, ye take the loot, and we argue after."] = { "好，{name}：俺打頭陣，你撿寶，打完再吵！" },
		["Say no more, {name}. Stone and steel, here it comes."] = { "甭多說，{name}！岩石與鋼鐵，接著！" },
		["Stand behind me, {name}. Aye, I know. Crouch a bit."] = { "躲俺後面，{name}。對，俺知道。蹲低點。" },
		["Take dis, {name}. Walk like ya own da jungle. I do."] = { "{name}，走路要像叢林你家開的。咱就是。" },
		["Thank ye kindly, {name}! First round's on me when we're back at the forge."] = { "多謝啦，{name}！回熔爐頭一杯俺請！" },
		["Thank ye, {name}! I'd have been fine without it, mind. But thank ye."] = { "謝啦，{name}！沒這個俺也行，真的！但還是謝啦。" },
		["Thanks, mon! Da spirits smile on ya, {name}."] = { "謝啦老兄！眾靈對你笑哩，{name}。" },
		["Ya be too kind, {name}! Dis one be from me."] = { "你太客氣啦，{name}！這份算咱的。" },
		["Ya gave me good mojo, {name}. Now ya get some back, extra spicy."] = { "你給咱好巫毒，{name}。現在還你，加辣的。" },
		["Ya too kind, {name}! This one's from me."] = { "你太客氣啦，{name}！這個咱送的。" },
	},
}

-- Every line of a ready-made set and of an "In character" example, in every
-- language the addon is translated into, by the hash of its text (LineHash
-- below) to the English key of the line, which is its place in RP.OTHER_KEYS.
-- A box keeps the language it was filled in, and a client's own Locales file
-- holds only its own language, so a box saved by a client in German and opened
-- by one in English could not be told from the player's own words: In
-- character stopped, and a fixed set stayed German. This is the table that
-- carries the other languages' text; RP.InThisLanguage turns each line of a
-- box into the client's own reading, and the box counts as untouched when the
-- result is a set or the examples. Written by python tools/legacy_lines.py
-- --write-other, which --check says is out of date after any change to a set,
-- an example or a translation of one: do not edit it by hand.
-- BEGIN other-languages (python tools/legacy_lines.py --write-other writes everything up to END)
RP.OTHER_KEYS = {
	"A favour for a favour, {name}! Pleasure doing business.",
	"A fellow wanderer! The caravan is never far, {name}, nor its gifts.",
	"A fellow wanderer! The caravan is never far, {name}.",
	"A fight, then a meal, {name}. That is the correct order. Never the reverse.",
	"A gift freely given, {name}. The naaru hum a little louder. Returned.",
	"A gift from the Dragon Isles, {name}. Fly well.",
	"A gift from the shadows, {name}. No, don't look. You won't find me.",
	"A gift with no favour owed? The court would faint. Thank you, {name}.",
	"A gift, a fight, then a meal, {name}. That is the correct order.",
	"A kindness returned is a kindness doubled, {name}.",
	"A little something from the Telogrus Rift, {name}. It's cleaner than it sounds.",
	"A little something, {name}. Don't tell the guards; they'll all want one.",
	"A pack again, {name}, someone to look after. I hadn't known how I'd missed it.",
	"A pack again, {name}. I hadn't known how much I'd missed one.",
	"A party at last, {name}. I did dress for one, and I brought gifts.",
	"A party at last, {name}. I did dress for one.",
	"A reasonable request, {name}. Granted.",
	"A small upgrade for you, {name}. No cogs required.",
	"A spark of Suramar's arcana for you, {name}. Use it wisely.",
	"A touch of shadow for you, {name}. Quite safe. Mostly.",
	"A true warband, {name}. Loud, angry, and all on the same side for once.",
	"A true warband, {name}: loud, angry, blessed, and on the same side for once.",
	"A villain in here rehearses a speech, {name}. Take this, then let's interrupt.",
	"Alexstrasza says every life is precious, {name}. I am starting with yours.",
	"Among orcs, {name}, making you stronger is how we say we like you.",
	"An expedition, {name}! In Suramar this blessing needed six permits.",
	"An expedition, {name}! In Suramar this needed six permits and a masquerade.",
	"An orc giving gifts unasked? Tell no one, {name}. It ruins the image.",
	"An'she rises, {name}, and so do we, with this. Slower, in my case.",
	"An'she rises, {name}, and so do we. Slower, in my case.",
	"Anar'alah belore, {name}. May the sun guide you, and light your good side.",
	"Anything for a fellow entrepreneur, {name}!",
	"Anything shiny in there, {name}, I saw it first. Caravan law.",
	"Anything shiny in there, {name}, I saw it first. This shiny bit is yours.",
	"Arathor's children stand together, {name}, and share what strength they have.",
	"Arathor's children stand together, {name}.",
	"Arcane for everyone, {name}. The court would call it waste. I call it company.",
	"Archenon poros, {name}! The children of Argus look after one another.",
	"Archenon poros, {name}. Your gift is returned.",
	"As you wish, {name}. The shadows answer kindly today.",
	"Ask a dwarf fer help, {name}, and ye'll get it. Loudly.",
	"Ask an orc for help and you get it, {name}. Ask for subtlety and you wait.",
	"Ask and it is given, {name}. The herd shares what it has.",
	"Ask the dead for a favour, {name}. We rarely have other plans.",
	"At last, {name}! I've waited ten thousand years for someone to ask.",
	"At once, {name}. Quick for a pandaren, which is not saying much.",
	"Aw, {name}. I'd invoice you, but I'm feeling sentimental. It'll pass.",
	"Aye, {name}, ye only had to ask. Hold still now, like a good anvil.",
	"Azeroth needs you on your feet, {name}.",
	"Balance in all things, {name}. Now go with a light heart.",
	"Balance in all things, {name}. Take this, and go with a light heart.",
	"Bless ye, {name}! I'd hug ye, but ye'd be needin' a healer after.",
	"Bless you, {name}. No, you didn't sneeze; I'm simply thorough.",
	"Blood and thunder, {name}! Go and earn your glory.",
	"Blood and thunder, {name}! Take my strength and go earn your glory.",
	"Buffed. You're welcome, {name}.",
	"Bwonsamdi gonna be real disappointed, {name}. Thanks, mon.",
	"By my calculations, {name}, you're owed exactly one {buff}.",
	"Caravan rules, {name}: stay together, share the water, nobody sells the alpaca.",
	"Caravan rules, {name}: stick together, share water and this. Never the alpaca.",
	"Careful by the shore, {name}. Where there's one murloc, there are nine.",
	"Certainly, {name}. Hold still, I don't bite. Much.",
	"Certainly, {name}. Stand clear of the tail.",
	"Certainly, {name}. The short version; the long one takes a lunar cycle.",
	"Certainly, {name}. The whispers said no, so it's an easy yes.",
	"Certainly, {name}. Try not to die. It's overrated.",
	"Cheers, {name}!",
	"Coming right up, {name}! Caravan service, no waiting.",
	"Consider it done, {name}. The Void obeys us, not the other way round.",
	"Consider us even, {name}.",
	"Consider yourself shouted at, {name}. Affectionately.",
	"Crew's got style, {name}. Now it's got mojo too.",
	"Da loa be watchin' over ya, {name}. Dey real nosy like dat.",
	"Da loa watch over ya, {name}. They're real nosy that way.",
	"Dabu, {name}. It is done.",
	"Daylight, {name}. Ten thousand years under a dome, and it startles me. Here.",
	"Daylight, {name}. Ten thousand years under a dome, and it still startles me.",
	"Deal, {name}! I'll put it on your tab. Kidding!",
	"Death's gonna be real disappointed, {name}. Thanks, mon.",
	"Dis crew got style, {name}. Now it got mojo too.",
	"Do keep pace, {name}. We have a reputation for arriving beautifully.",
	"Do keep pace, {name}; you're blessed now. We're known for arriving beautifully.",
	"Don't spend it all at once, {name}.",
	"Early bird gets the gold, {name}! Here's a freebie. Don't tell the other birds.",
	"Elune lights your path, {name}. I'm merely holding the lantern.",
	"Elune saw that, {name}. She sees everything, so I had best return it.",
	"Elune watches the whole party, {name}. I just pass her light along.",
	"Elune watches the whole party, {name}. I'm just the one who waves at her.",
	"Elune-adore, {name}. Her light goes with you. Walk softly; trees sleep lightly.",
	"Elune-adore, {name}. Walk softly; the trees are light sleepers.",
	"Every traveller needs something for the road, {name}. I checked: not a rock.",
	"Everyone deserves to shine, {name}. Only a little less than me, of course.",
	"Fair winds and following seas, {name}, and this to carry you along.",
	"Fair winds and following seas, {name}.",
	"Fall in a lake someday, {name}, and you'll think of me fondly.",
	"Follow the visions, Hagar said, {name}. Today they pointed at you. Take this.",
	"For Gnomeregan, {name}! Always nice to talk to somebody at eye level.",
	"For Gnomeregan, {name}! Here, eye to eye. Always nice to give at eye level.",
	"For the Alliance, {name}! Stay strong out there. Stronger, now.",
	"For the Horde, {name}! Go with strength. I've just handed you some.",
	"For you, {name}.",
	"For you, {name}. No, I don't want a treat. Well. Perhaps a small one.",
	"For you, {name}. Unasked, unearned and entirely deserved. Draconic logic.",
	"For you, {name}? Of course. The sun gives freely.",
	"Forward, {name}, and take this. The Horde advances together. Retreats... never.",
	"Forward, {name}. The Horde advances together. Retreats... never, officially.",
	"Found this lying around, {name}. Kidding! It's fresh. Take it!",
	"Free sample, {name}! If you like it, you know where to find me.",
	"Fresh from the Emerald Dream, {name}. Sorry if I yawn.",
	"Friends can come from any side, {name}. Or from none, like me. Here.",
	"Friends can come from any side, {name}. Or, like me, from none in particular.",
	"From Kalimdor to the Eastern Kingdoms, {name}, may every road bring you home.",
	"From one wanderer of Azeroth to another.",
	"Get behind me, {name}. There's room back there for the whole party.",
	"Gladly, {name}. Be still, and let the moonlight find you.",
	"Gladly, {name}. The Light answers those who ask.",
	"Go and do something worth a song, {name}. Loud songs. The Horde likes loud.",
	"Go with honour, {name}, and with this. Victory awaits.",
	"Go with honour, {name}. Victory awaits.",
	"Go with the Light, {name}. I'll be right behind you, clanking.",
	"Granted, {name}. A dragon keeps its word.",
	"Group rate, {name}! Everybody here gets it half off. Of free.",
	"Hagar sent me to see the goddess's work, {name}. You're some of her best.",
	"Have some {buff}, {name}.",
	"Hear that, {name}? Winter, on your side for once.",
	"Here, {name}, a wee somethin' to keep ye on yer feet. Wee, like me.",
	"Here, {name}. Ale's for after; this is for before.",
	"Here, {name}. Best thing in my pack, and I've got a lot of pack.",
	"Here, {name}. Don't ask where it came from. Really, don't.",
	"Here, {name}. I had a spare thought and nowhere to put it.",
	"Here, {name}. I'll draw up a plan too, and we can all ignore it together.",
	"Here, {name}. I'll take the front. What's the worst that could happen? Again?",
	"Here, {name}. If I sing after this, the fight's gone well. Or very badly.",
	"Here, {name}. If anything explodes near you today, that was unrelated.",
	"Here, {name}. Keep an eye on my shadow. It wanders off when there's a fight.",
	"Here, {name}. Think of it as a prayer that arrived early.",
	"Here, {name}. Walk like ya own the jungle. I do.",
	"Hey, {name}! Always good to see family, mon.",
	"Hold still, {name}, this is perfectly safe. Probably!",
	"Hold still, {name}. Strength for the fight ahead.",
	"How gracious, {name}. Allow me to return the favour.",
	"How kind, {name}! You're on the caravan's good list now.",
	"I passed you twice on my morning run, {name}. The third time, I stopped. Here.",
	"I slept through ten thousand years of good deeds, {name}. Catching up now.",
	"I was a physician in Lordaeron, {name}. Old habits die harder than I did.",
	"I woke in a cave full of strangers, {name}. This is far better company.",
	"I woke in a cave of strangers, {name}. Now I give gifts to company. Better.",
	"I would bow, {name}, but last time my wings cleared a table. Thank you.",
	"I'd have brought this sooner, {name}, but I stopped to chase something.",
	"I'll be the one you can't see, {name}. That's not a mistake; that's the plan.",
	"I'll catch the scent of trouble first, {name}. It's the one perk of the curse.",
	"I'll draw up a plan, {name}, and then we can all ignore it together.",
	"I'll take the front, {name}. What's the worst that could happen? Again?",
	"I've gone without magic once, {name}. I don't recommend it. Take this.",
	"I've run the numbers, {name}: with this on you, we win. I rounded up.",
	"I've run the numbers, {name}: with you here, we win. I rounded up.",
	"If I fall down, {name}, give it a minute. Old habit.",
	"If I shout 'duck', {name}, don't look for a duck. That went badly last time.",
	"If I start singin', {name}, the fight's gone well. Or very badly.",
	"If something whispers to you in the dark, {name}, don't answer.",
	"If the shadows start giving orders, {name}, ignore them. I usually do.",
	"Ishnu-alah, {name}. Elune keeps her children close, and so do I.",
	"Ishnu-alah, {name}. Elune keeps her children close.",
	"Ishnu-alah, {name}. Returned the same day, which for a kaldorei is rushing.",
	"It is good to see one of our own, {name}.",
	"It's a long way up to a tauren's heart, {name}. You found it.",
	"Keep an eye on my shadow, {name}. It wanders off when there's a fight.",
	"Keep close, {name}. Humans have always won by outnumbering things.",
	"Keep this, {name}. The desert is long and the water is short.",
	"Keep your wits about you, {name}, and this too. Something is always hunting.",
	"Keep your wits about you, {name}. Something is always hunting.",
	"Kind of you, {name}. We sin'dorei never turn down free magic. Ask anyone.",
	"Kindly done, {name}. Let no one say we forget a friend.",
	"Kindness echoes, {name}, and I grew up in a cavern. Here it comes back to you.",
	"Least I could do, {name}.",
	"Ley lines run under all of Azeroth, {name}. Today a little runs your way.",
	"Lok'tar ogar, {name}! Take this into battle. A tavern brawl also counts.",
	"Low ceilings ahead, {name}? I'll be the first to find out. Take this.",
	"Magni turned to diamond fer the cause, {name}. This is the cheaper option.",
	"Magni'd melt down his crown fer a friend, {name}. This is the cheaper option.",
	"May An'she light your path, {name}, and this go with you.",
	"May An'she light your path, {name}.",
	"May the Barrens be kinder to you than they were to me, {name}.",
	"May the forest shelter you, {name}, wherever you roam.",
	"Millennia on the run, {name}. Sharing the Light with friends is nicer.",
	"More work? Gladly, {name}. It beats the lumber mill.",
	"Mornin', {name}! Too early for ale. Almost. Have this first.",
	"Morning already, {name}? I've been up all night. And all of last decade.",
	"Morning, {name}! Up since three. The toaster needed a new engine.",
	"Morning, {name}! Up since three. The toaster needed an engine; you needed this.",
	"Morning, {name}. I'd have been up sooner, but the rug by the fire was so warm.",
	"Morning, {name}. My people slept through these for millennia. I'm adapting.",
	"Morning, {name}. My people slept through these; this will help us both adapt.",
	"Morning, {name}. The rug by the fire was warm, but I got up to give you this.",
	"Morning, {name}? I've been up all night, and all of last decade. Have this.",
	"Most gracious, {name}. Allow me to repay you in kind.",
	"Mu'sha keeps the night watch, {name}. I'll keep an eye on you too. Here.",
	"Mu'sha keeps the night watch, {name}. I'll tell her to keep an eye on you.",
	"Much obliged, {name}. Gilneas never forgets a kindness, and nor does my nose.",
	"Much obliged, {name}. Ye've a friend in the mountain now.",
	"My Legacy Stone showed who I'd stand beside, {name}. It forgot you. Thank you.",
	"My thanks, {name}. Let me return the kindness before a bard gets it wrong.",
	"My thanks, {name}. The ren'dorei do not forget a kindness.",
	"My undying gratitude, {name}. For once, the phrase is accurate.",
	"Naturally, {name}. Only the finest for you.",
	"Neltharion made us to fight alone, {name}. We have improved on him.",
	"Neltharion made us to fight alone, {name}. We improved on him. Here.",
	"Night again, {name}. I'm at my best and my worst. This is the best part.",
	"Night again, {name}: my best and my worst. Giving you this is the best part.",
	"Night at last, {name}. Add a few thousand lanterns and it's nearly Suramar.",
	"Night at last, {name}. Add this glow and some lanterns: nearly Suramar.",
	"Night be da best time for mojo, {name}. Nobody see where it come from.",
	"Night suits the ren'dorei, {name}. We match the decor.",
	"Night suits the ren'dorei, {name}. We match the decor. Here's a little of it.",
	"Night's the best time for mojo, {name}. Nobody sees where it's from.",
	"No charge, {name}. The apothecaries would have made you sign something.",
	"No charge, {name}. They'd call me mad in Booty Bay.",
	"No flag over this party, {name}, just us, and this. That's plenty.",
	"No flag over this party, {name}, just us. That's plenty.",
	"No incense, no prayers, {name}. Just me, shouting encouragingly.",
	"No trouble, {name}. Da loa like ya.",
	"No worries, {name}. Da loa got ya covered.",
	"Nobody dies on my contract, {name}. Here's insurance. The paperwork's awful.",
	"Nobody dies on my contract, {name}. The paperwork's a nightmare.",
	"Of course, {name}! I built a machine for this. It's in pieces, so: by hand.",
	"Of course, {name}! Shake the sand out and hold still.",
	"Of course, {name}. A little arcane polish, just for you.",
	"Of course, {name}. Dalnir would call this a distraction. Dalnir isn't here.",
	"Of course, {name}. Elune's blessings are meant to be shared.",
	"Of course, {name}. Hold still and look heroic; it helps the bards.",
	"Of course, {name}. I answered the goddess's call. Yours is far easier to hear.",
	"Of course, {name}. Patience, and it is done. Patience is the slow part.",
	"Of course, {name}. Protect, tend and serve, my people say. This is the serving.",
	"Of course, {name}. Stand back a pace; I do this with my whole body.",
	"Of course, {name}. Stand tall and be at peace. I'll handle the tall part.",
	"Of course, {name}. The naaru guide your steps; this puts a spring in them.",
	"Off ye go, {name}, steady as the mountain.",
	"Off ye go, {name}, with a wee blessin' from me. Steady as the mountain.",
	"Oh, I'll keep this, {name}! I keep everything. Here's one for you.",
	"One day we'll pick sides, {name}. Today we pick fights, together.",
	"One for the party, {name}! A caravan's only as fast as its slowest alpaca.",
	"One good buff deserves another, {name}.",
	"One good turn, {name}. Azeroth could use a few more of those.",
	"One upgrade, coming right up, {name}! Stand still for calibration.",
	"Onward, {name}, and take this. The Alliance is with you.",
	"Onward, {name}. The Alliance is with you.",
	"Orcs keep their thanks short, {name}. Thanks.",
	"Orcs return every blow twice, {name}. The kind ones too.",
	"Our strength is each other, {name}. For the Horde!",
	"Our strength is each other, {name}. Here's some of mine. For the Horde!",
	"Pack rules, {name}: nobody wanders off, and nobody mentions the fleas.",
	"Pack rules, {name}: nobody wanders off, everyone gets one, no talk of fleas.",
	"Party-wide calibration complete, {name}! Nobody touch anything shiny.",
	"Past my first nap, {name}, and before my second. Quickly, while I'm awake.",
	"Past my first nap, {name}, before my second. Take this while I'm awake.",
	"Patience, {name}. Radiance can't be rushed, only admired.",
	"Quick one, {name}? By kaldorei reckoning we'll be done before we start.",
	"Quick one, {name}? Take this now. By kaldorei reckoning we're already done.",
	"Ragnaros still burns under Blackrock Mountain, {name}. Let's keep him down there.",
	"Reciprocity engaged! Much obliged, {name}.",
	"Repaid on the spot, {name}. In Stormwind that'd take three forms and a stamp.",
	"Request received, {name}! Processing... done!",
	"Returning the favour, {name}.",
	"Right away, {name}! Satisfaction guaranteed or your {buff} back.",
	"Right away, {name}. Keep your shield high.",
	"Right away, {name}. Stay, now. I've always wanted to say that.",
	"Right you are, {name}. Stand steady now.",
	"Right, {name}: I take the front, ye take the loot, and we argue after.",
	"Right, {name}: shields up, heads down, and nobody charges before the plan does.",
	"Right, {name}: take this, shields up, and nobody charges before the plan does.",
	"Right, {name}: ye get this, I take the front, and we argue about loot after.",
	"Say no more, {name}. Stone and steel, here it comes.",
	"Science says you need this, {name}. Who am I to argue?",
	"Shorel'aran, {name}. Fight with elegance, and with this.",
	"Shorel'aran, {name}. Fight with elegance.",
	"Side by side, {name}, whatever comes.",
	"Side by side, {name}, whatever comes. Take this.",
	"Some of Deathwing's brood wear human faces, {name}. Mind who you trust.",
	"Somewhere in here a villain is rehearsing a speech, {name}. Let's interrupt.",
	"Somewhere, a Sha just went hungry. Thank you, {name}.",
	"Soon they'll hand us tabards, {name}. Until then, we look after each other.",
	"Stand behind me, {name}. Aye, I know. Crouch a bit.",
	"Stand where the light is good, {name}. If we must fight, we'll look splendid.",
	"Stand where the light is good, {name}. With this on you, we'll look splendid.",
	"Stay alive, {name}. Undercity's housing list is already very long.",
	"Stay among the living a little longer, {name}.",
	"Stay away from da voodoo, {name}. ...Except dis voodoo. Dis one fine.",
	"Stay away from da voodoo, {name}. Except this one. This one's fine.",
	"Stay close, {name}, and take this. The whispers are much quieter in company.",
	"Stay close, {name}. A haranir needs something to guard, and today it's you.",
	"Stay close, {name}. The whispers are much quieter in company.",
	"Stay close, {name}. Trolls regenerate; da rest of ya get this instead.",
	"Stay close, {name}. Trolls regenerate; da rest of ya gotta be careful.",
	"Stay in formation, {name}. We haven't got one, but stay in it anyway.",
	"Stay near, {name}. I lost a world once; I'm keeping hold of this party.",
	"Stay off the moors after dark, {name}. Take this.",
	"Stay out of the Plaguelands if you can, {name}. Go well armed if you can't.",
	"Stay sharp out dere, {name}. Take dis wit' ya.",
	"Stay sharp, {name}. Take this with ya.",
	"Stay together, {name}, like dumplings in a steamer. Warm now, and ready.",
	"Stay together, {name}, like dumplings in a steamer. Warm, and ready.",
	"Stay with the warband, {name}. Strength in numbers, in axes, and in this.",
	"Stay with the warband, {name}. Strength in numbers. And in axes.",
	"Stone and hammer keep ye, cousin {name}!",
	"Stormwind has a statue for every hero, {name}. I'm putting in a word for yours.",
	"Such courtesy does you credit, {name}. Nearly as much as it does me.",
	"Such warmth, for one so cold? Returned in full, {name}.",
	"Suramar's children shine together again, {name}.",
	"Suramar's children shine together again, {name}. Let me add to your glow.",
	"Sure thing, {name}. Hold still; mojo hates a movin' target.",
	"Sure ting, {name}. Hold still; da mojo don't like a movin' target.",
	"Sure, {name}! Let me dig it out... rope, rocks, a nice rock... here it is!",
	"Take dis, {name}. Walk like ya own da jungle. I do.",
	"Take it, {name}, I've a spare. I've three spares of everything.",
	"Take this, {name}, and get behind me. There's room for the whole party.",
	"Take this, {name}, and may Aln'hara be with you.",
	"Take this, {name}, and walk with the Earth Mother. You can't get lost.",
	"Take this, {name}, from a long way below. The roots send their regards.",
	"Take this, {name}. A grummle would sell it to you for a luckydo.",
	"Take this, {name}. And perhaps a cup of tea afterward?",
	"Take this, {name}. Any tentacles you see are purely decorative.",
	"Take this, {name}. Arcane gifts are wasted on the idle.",
	"Take this, {name}. Elves have centuries to be generous; I've got fifty years.",
	"Take this, {name}. Even a dragon needs allies. Especially one this size.",
	"Take this, {name}. I meant to explain the spell first. Too late now.",
	"Take this, {name}. I smell trouble first; it's the curse's one perk.",
	"Take this, {name}. I'd add bread, but conjured bread tastes of nothing.",
	"Take this, {name}. My people always travel Light.",
	"Take this, {name}. Nature provides, and I'm its errand runner today.",
	"Take this, {name}. The Earth Mother would scold me if I walked past.",
	"Take this, {name}. The Legion is always coming. I'd know.",
	"Take this, {name}. The grave can wait.",
	"Take this, {name}. The storm doesn't know you yet, but I've introduced you.",
	"Take this, {name}. Then tell me when to breathe fire. And when not to.",
	"Take this, {name}. Whatever happens out there is merely a setback.",
	"Take this; stay alive, {name}. Undercity's housing list is already very long.",
	"Tell me when to breathe fire, {name}. And, please, when not to.",
	"Thank ye kindly, {name}! First round's on me when we're back at the forge.",
	"Thank ye, {name}! I'd have been fine without it, mind. But thank ye.",
	"Thank you, {name}! The caravan always repays a kindness. Usually in string.",
	"Thank you, {name}. Aysa would bow, Ji would cheer. I will do both, badly.",
	"Thank you, {name}. Elune smiles on the generous.",
	"Thank you, {name}. Even the wisps glow brighter, and they're hard to impress.",
	"Thank you, {name}. Few give gifts to someone who glows this ominously.",
	"Thank you, {name}. Hagar sent me to see the goddess's work. You're her best.",
	"Thank you, {name}. I haven't felt this radiant since... well, this morning.",
	"Thank you, {name}. I'd blush, but the blood stopped reaching my face.",
	"Thank you, {name}. I'd knight you, but apparently I 'need permission'.",
	"Thank you, {name}. I'm deeply moved, and it takes a lot to move a tauren.",
	"Thank you, {name}. If worgen had tails, mine would be wagging.",
	"Thank you, {name}. It would warm my heart, if it still beat.",
	"Thank you, {name}. May the winds guide you.",
	"Thank you, {name}. Returned on swift wings.",
	"Thank you, {name}. Ten thousand years under a dome; I'm still practising that.",
	"Thank you, {name}. The voices approve of you, which is frankly alarming.",
	"Thank you, {name}. Where I come from, a kindness is tended like a root.",
	"Thank you, {name}. You have my gratitude, and my best howl.",
	"Thank you, {name}. You have restored my balance.",
	"Thanks for the buff, {name}!",
	"Thanks, mon! Da spirits smile on ya, {name}.",
	"Thanks, {name}! Consider your account settled in full.",
	"Thanks, {name}! Here's yours back. Well, a new one. Hardly used.",
	"Thanks, {name}! I checked it for fine print. There wasn't any. Weird!",
	"Thanks, {name}! I'd build you a thank-you machine, but it'd explode.",
	"Thanks, {name}! Kindness received, catalogued and returned!",
	"Thanks, {name}. I'd offer a lift in the Exodar, but you've seen how it lands.",
	"That's for you, {name}. If I fall down, give it a minute. Old habit.",
	"That's from the one you can't see, {name}. Not a mistake; that's the plan.",
	"The Earth Mother saw your kindness, {name}. She nudged me. Quite hard.",
	"The Earth Mother watches over us both, {name}.",
	"The Earth Mother watches over us both, {name}. Today I'll help her.",
	"The Forbidden Reach feels far behind us now, {name}.",
	"The Forbidden Reach is far behind us, {name}. What we learned there, I share.",
	"The Legion's been at this world for ten thousand years, {name}. It hasn't won yet.",
	"The Light asks nothing in return, {name}. I, however, accept thanks.",
	"The Light is with you, {name}. Go in peace, or at least go prepared.",
	"The Light rewards kindness, {name}. I'm simply its fastest courier.",
	"The Scourge is always recruiting, {name}. Don't give them the satisfaction.",
	"The Sunwell shines for us both, {name}.",
	"The Sunwell shines for us both, {name}. Let me share its light.",
	"The Titans shaped this world, {name}. Keeping it whole falls to the likes of us.",
	"The curse binds us, {name}, but Gilneas binds us tighter.",
	"The curse binds us, {name}; Gilneas binds us tighter. Here, from one of yours.",
	"The dead keep terrible hours, {name}. Nice to have company for once.",
	"The dead keep terrible hours, {name}. Nice to have someone to give this to.",
	"The dome kept us safe, {name}. Now one another must. Gladly; here.",
	"The dome kept us safe, {name}. Now we must make do with one another. Gladly.",
	"The finest company the Alliance ever fielded, {name}. Or at least the nearest.",
	"The herd moves together, {name}, blessed. Mind my hooves; the herd has learned.",
	"The herd moves together, {name}. Mind my hooves; the herd has learned to.",
	"The horn sounds for you, {name}. It used to sound only for the Scourge.",
	"The jinyu say the waters foretold this, {name}. They say that a lot.",
	"The moon's up, {name}. For a kaldorei, this is the middle of the morning.",
	"The moon's up, {name}; here's her blessing. For a kaldorei, it's mid-morning.",
	"The naaru would call sharing Light a fellowship, {name}. I call it good luck.",
	"The naaru would call this a fellowship, {name}. I call it good luck.",
	"The plan, {name}: we hit it. Questions? No? Good plan.",
	"The plan, {name}: you take this, we hit it. Questions? No? Good plan.",
	"The road ahead is long, {name}. This won't shorten it, but it'll help.",
	"The shadows remember kindness, {name}. So do I.",
	"The sky has a little fury to spare, {name}. Take some.",
	"The sky has no ceiling, {name}. Anything could fall on you. Take this.",
	"The sun has risen, {name}, and so have I. We coordinate.",
	"The sun has risen, {name}, and so have I. We coordinate. Here's its light.",
	"The world outside the dome is so large, {name}. And so under-enchanted. Here.",
	"There, {name}, that'll see ye through. Stand behind me. Aye, I know. Crouch.",
	"There, {name}. Humans have always won by outnumbering things, and by sharing.",
	"There, {name}. I lost a world once; I'm keeping hold of this party.",
	"There, {name}. If I shout 'duck', don't look for a duck. Last time went badly.",
	"There, {name}. If the shadows start giving orders, ignore them. I usually do.",
	"This one's on me, {name}.",
	"This one's on the house, {name}. Don't tell the Trade Prince.",
	"Throm-ka, {name}! Honour is repaid.",
	"Throm-ka, {name}! The blood of the clans runs strong in you.",
	"Throm-ka, {name}! The blood of the clans runs strong in you. Stronger now.",
	"Together we stand, {name}, and share. For the Alliance!",
	"Together we stand, {name}. For the Alliance!",
	"Together we're a war band, {name}. Apart, we're just loud.",
	"Top-shelf stuff, zero fees, {name}. Today only!",
	"Twenty-five thousand years on the run, {name}. Walking with friends is nicer.",
	"Two haranir out in the world, {name}. No wonder the elders are up in arms.",
	"Two haranir out in the world, {name}. The elders would fret. I'll help instead.",
	"Up before the tea, {name}? Brave. Here, instead of the tea.",
	"Velen foresaw you asking, {name}. I foresaw saying yes.",
	"Very well, {name}. Stand still, I would hate to singe you.",
	"Walk carefully in the dark places, {name}.",
	"Walk carefully in the dark places, {name}. This will light a little of them.",
	"Walk in the Light, {name}. May it shelter you always.",
	"Walk tall, {name}. The Horde always made room for those the world turned away.",
	"Walk with the Earth Mother, {name}. She's everywhere, so you can't get lost.",
	"Watch the long grass in Stranglethorn, {name}. The panthers are watching you.",
	"We Forsaken must look after each other, {name}.",
	"We go in together, {name}, blessed, and come out together. That's the plan.",
	"We go in together, {name}, we come out together. Dat be da whole plan, mon.",
	"We go in together, {name}, we come out together. That's the plan, mon.",
	"We have to stop meeting like this, {name}. Actually, no, we don't.",
	"We have to stop meeting like this, {name}. Actually, no. Here's another one.",
	"We look after our own, {name}. Always, mon.",
	"We move as one, {name}, and now blessed as one. Slowly, perhaps.",
	"We move as one, {name}. Slowly, perhaps, but as one.",
	"We must share a brew when the road allows, {name}!",
	"We must share a brew when the road allows, {name}! For now, share this.",
	"We once mastered every beast on our mountain, {name}. These won't take long.",
	"We once mastered every beast on our mountain, {name}. With this, these won't.",
	"We ren'dorei look after our own, {name}.",
	"We split the loot even, {name}. I'll do the maths. Trust me.",
	"We split the take even, {name}. I'll do the maths. Trust me.",
	"We split the take even, {name}. This is your share. I did the maths. Trust me.",
	"We vulpera travel by night, {name}. Cool sand, sleepy scorpids, and this.",
	"We vulpera travel by night, {name}. Cool sand, sleepy scorpids.",
	"Wings, fire and scales, {name}, and still you thought I needed help. Touching.",
	"With pleasure, {name}. A kind deed is never wasted.",
	"Word from Harandar, {name}: the haranir are ready to join the fight.",
	"Word from Harandar, {name}: the haranir join the fight. This is my part.",
	"Ya be too kind, {name}! Dis one be from me.",
	"Ya gave me good mojo, {name}. Now ya get some back, extra spicy.",
	"Ya look like somebody who appreciate quality, {name}. Here: quality.",
	"Ya too kind, {name}! This one's from me.",
	"You dropped this, {name}.",
	"You give freely, {name}. I return the favour.",
	"You got it, {name}! Time is money, friend!",
	"You looked like you could use a friend, {name}. I'm a very big one.",
	"You need only ask, {name}. The dead are patient.",
	"You're ready, {name}. Stay in formation. We haven't got one, but stay in it.",
	"You've made a friend for life, {name}. Loyalty is rather our thing.",
	"Your generosity is noted, {name}. In triplicate. Suramar remembers its friends.",
	"Your kindness is noted, {name}. Dragons do not forget.",
	"Your stance says long day, {name}. Monks notice. Take this.",
	"Your stance says you've had a long day, {name}. Monks notice these things.",
	"{name} \\o",
	"{name}, you look like you need this.",
	"{name}.",
}
RP.OTHER_HASH = {
	[361774] = 444, [874704] = 416, [1257712] = 180, [2650649] = 126, [2788810] = 201, [3693110] = 202,
	[6739775] = 166, [7398612] = 116, [7425467] = 5, [7693751] = 271, [7762479] = 435, [7845183] = 437,
	[8066599] = 40, [9482101] = 82, [10180862] = 53, [10422469] = 440, [10438931] = 468, [15154699] = 1,
	[16134556] = 107, [17900983] = 160, [20075545] = 327, [21275604] = 402, [21798674] = 176, [22358906] = 213,
	[22481666] = 83, [22774299] = 122, [26098017] = 140, [26587171] = 156, [27676140] = 423, [29656001] = 190,
	[29776821] = 179, [30369235] = 367, [30584287] = 405, [31764394] = 302, [32067802] = 257, [32571832] = 222,
	[32592518] = 118, [34220632] = 389, [35601611] = 34, [35949627] = 414, [38276695] = 189, [38329887] = 317,
	[38852408] = 319, [39076519] = 111, [40500865] = 388, [40647239] = 9, [40791608] = 38, [43740096] = 184,
	[44333340] = 230, [45337592] = 197, [46745894] = 455, [47050641] = 231, [48121372] = 256, [48696133] = 388,
	[49109627] = 366, [49901130] = 403, [50708038] = 102, [50991313] = 159, [51491201] = 165, [51519873] = 26,
	[51808301] = 398, [52886693] = 395, [54601514] = 212, [54742705] = 167, [55659669] = 93, [57172643] = 260,
	[57829973] = 333, [58687549] = 349, [60935406] = 445, [61351621] = 381, [62521652] = 243, [62872114] = 426,
	[63905910] = 272, [64622433] = 142, [64859634] = 233, [65364828] = 436, [69014768] = 74, [69022454] = 465,
	[69122703] = 237, [69470207] = 31, [70155693] = 244, [72360037] = 96, [72997857] = 229, [73537956] = 22,
	[74350629] = 390, [74427613] = 106, [75172503] = 122, [76610820] = 340, [77536104] = 251, [78896595] = 122,
	[81117471] = 44, [85322077] = 289, [86587511] = 29, [87162498] = 93, [88132716] = 463, [90138163] = 420,
	[92123577] = 386, [93450262] = 147, [100610976] = 442, [102459263] = 425, [104062761] = 8, [108849327] = 400,
	[109960437] = 192, [111238854] = 186, [112789632] = 232, [113260480] = 357, [115020422] = 312, [115592487] = 85,
	[116105059] = 384, [116798001] = 44, [117200310] = 457, [118299613] = 148, [118808656] = 159, [119163082] = 297,
	[119400822] = 199, [120923255] = 416, [121456284] = 233, [122014669] = 303, [122230856] = 401, [123649611] = 217,
	[123663919] = 461, [124492394] = 121, [124503489] = 44, [125084078] = 215, [125822618] = 441, [127576685] = 272,
	[127857374] = 104, [128406580] = 203, [128844417] = 328, [128918281] = 472, [131925619] = 282, [132562920] = 133,
	[134362469] = 161, [134681744] = 19, [136051397] = 222, [137394030] = 301, [137522975] = 419, [139765472] = 382,
	[140368819] = 191, [140507487] = 345, [140600905] = 82, [141532718] = 458, [142117979] = 110, [143629472] = 332,
	[144289512] = 91, [146511330] = 161, [147047296] = 225, [147350341] = 135, [149660900] = 151, [150538513] = 89,
	[151285745] = 271, [154362536] = 33, [157321985] = 312, [160647714] = 9, [162610247] = 141, [166039623] = 305,
	[166847199] = 426, [167044651] = 48, [167073833] = 452, [167135618] = 295, [168696717] = 17, [168765631] = 209,
	[171599253] = 326, [174379499] = 432, [175304935] = 431, [177553247] = 400, [178308841] = 350, [178956068] = 356,
	[181419114] = 144, [181991410] = 62, [183337516] = 404, [186596265] = 296, [188898673] = 322, [190052505] = 88,
	[190870802] = 145, [190888053] = 199, [191813834] = 420, [193890905] = 90, [194611347] = 360, [195617139] = 236,
	[195847966] = 92, [196106703] = 128, [196453832] = 205, [197223069] = 34, [201830970] = 192, [202025568] = 463,
	[202677795] = 258, [203118764] = 406, [205058686] = 87, [206253708] = 154, [206357278] = 321, [207499730] = 408,
	[208127967] = 411, [210033811] = 111, [210568985] = 117, [212283356] = 304, [213214116] = 240, [214639513] = 372,
	[214661278] = 279, [215101491] = 239, [216130395] = 338, [217126264] = 360, [217443020] = 468, [219441294] = 410,
	[220057581] = 216, [220152650] = 266, [221836807] = 157, [222800576] = 396, [222907188] = 57, [223939681] = 332,
	[224962130] = 321, [226218589] = 4, [227292560] = 436, [228163007] = 409, [230024266] = 218, [230390548] = 461,
	[232368607] = 277, [234383944] = 55, [234908601] = 46, [235327866] = 336, [238763884] = 170, [239337488] = 55,
	[239352818] = 130, [239673459] = 151, [240161805] = 410, [240962530] = 158, [241340568] = 114, [242429141] = 429,
	[242654459] = 116, [242668324] = 42, [243624568] = 191, [243758013] = 278, [243801003] = 197, [245908871] = 374,
	[247539585] = 253, [247896490] = 97, [250790127] = 331, [251564519] = 71, [253340344] = 318, [255829233] = 232,
	[256582965] = 359, [257002103] = 310, [257575457] = 401, [258462977] = 88, [258858677] = 115, [262337611] = 168,
	[264467452] = 291, [265905182] = 103, [266365463] = 429, [266875469] = 369, [267260470] = 133, [268132565] = 246,
	[268722269] = 153, [272192671] = 11, [272606035] = 416, [272925804] = 360, [273726653] = 29, [274762137] = 55,
	[276647943] = 13, [276760983] = 393, [276839012] = 27, [277135286] = 292, [278719608] = 412, [278841027] = 237,
	[279424047] = 452, [280272116] = 199, [280892229] = 194, [281711819] = 69, [282210846] = 3, [282281357] = 28,
	[282378117] = 35, [283032205] = 74, [283073120] = 123, [283443127] = 353, [283863779] = 368, [283881033] = 55,
	[287386589] = 341, [287633404] = 205, [287801488] = 443, [288127992] = 161, [288775558] = 355, [289504698] = 270,
	[290450555] = 130, [292251934] = 214, [292543833] = 128, [293634509] = 321, [294714388] = 50, [295041263] = 31,
	[295514167] = 380, [296759399] = 344, [296909880] = 137, [296983186] = 277, [297619137] = 37, [298110307] = 94,
	[298164909] = 385, [303007848] = 311, [304039254] = 160, [304703405] = 95, [304877739] = 99, [304975177] = 291,
	[305247071] = 267, [305375644] = 214, [306034546] = 111, [307188983] = 393, [310345653] = 187, [311250163] = 250,
	[311852307] = 446, [312894890] = 304, [314744736] = 414, [317818657] = 64, [317993528] = 152, [319795677] = 142,
	[321411895] = 167, [323317363] = 451, [323380071] = 198, [323420248] = 192, [325154573] = 375, [325229454] = 17,
	[327963268] = 43, [328465396] = 396, [328799688] = 26, [330039501] = 450, [330589186] = 61, [330872015] = 404,
	[330906229] = 262, [333327395] = 378, [333568287] = 324, [336246901] = 191, [336516816] = 99, [336990130] = 213,
	[337166320] = 422, [337790808] = 142, [338125738] = 136, [340295021] = 204, [342466653] = 439, [342641033] = 392,
	[343773719] = 198, [344546400] = 358, [346242372] = 102, [348853440] = 147, [348896335] = 401, [349477708] = 422,
	[349824412] = 96, [351525682] = 196, [352690908] = 420, [354605729] = 4, [355927955] = 45, [356760405] = 159,
	[357156890] = 51, [357197598] = 235, [357469596] = 377, [357692271] = 420, [358936192] = 147, [359885276] = 388,
	[362764023] = 19, [363115765] = 168, [363995468] = 15, [366881482] = 98, [368908625] = 29, [369078908] = 295,
	[369437404] = 206, [370576271] = 60, [371154355] = 288, [371977922] = 12, [373174878] = 275, [373475724] = 159,
	[373911219] = 27, [373988268] = 8, [376398533] = 204, [376530652] = 3, [378919873] = 3, [381170695] = 98,
	[382170958] = 424, [382622384] = 51, [383132495] = 199, [385156752] = 59, [385250348] = 164, [387656102] = 116,
	[387931973] = 26, [388351651] = 126, [388743640] = 315, [388866105] = 186, [389579358] = 224, [389679773] = 187,
	[389948250] = 355, [390732851] = 282, [391936245] = 117, [391995398] = 276, [393959941] = 437, [397590146] = 275,
	[397890433] = 19, [398306549] = 329, [399348087] = 4, [400226251] = 283, [400256646] = 285, [400771945] = 247,
	[401879267] = 146, [402451574] = 441, [403234630] = 247, [404304872] = 47, [404710261] = 7, [405703723] = 28,
	[406063892] = 360, [407228526] = 108, [409071975] = 149, [409309098] = 244, [409913787] = 57, [410415062] = 81,
	[410778504] = 194, [412827179] = 92, [413440966] = 402, [417499929] = 230, [419331454] = 111, [419900461] = 8,
	[420743732] = 69, [422933749] = 183, [423351311] = 215, [423556843] = 65, [423943603] = 182, [426111804] = 388,
	[426681076] = 38, [426812082] = 339, [428097045] = 293, [429203519] = 107, [429316643] = 394, [432178161] = 76,
	[434315500] = 223, [435196951] = 83, [436839351] = 136, [437449716] = 244, [437978442] = 108, [438707536] = 141,
	[442152246] = 328, [443897978] = 460, [445222137] = 427, [445297092] = 178, [445345713] = 129, [449356617] = 227,
	[449938165] = 319, [450105699] = 262, [451322581] = 136, [451377611] = 272, [452605458] = 306, [453155189] = 380,
	[454387409] = 33, [454798498] = 283, [460166694] = 203, [460374177] = 214, [460545985] = 110, [465894004] = 131,
	[469312104] = 201, [469750207] = 289, [471588014] = 436, [472420576] = 101, [472522905] = 54, [473034490] = 24,
	[474622399] = 452, [474651415] = 142, [476674272] = 100, [476986517] = 368, [478038685] = 346, [479794606] = 196,
	[480911143] = 268, [480951633] = 73, [481918936] = 273, [482550060] = 347, [484138181] = 340, [485181371] = 278,
	[486224275] = 52, [486345549] = 190, [486747962] = 174, [486790523] = 347, [487627634] = 370, [488550641] = 168,
	[490822636] = 154, [491701801] = 247, [493394062] = 46, [495263478] = 4, [495507245] = 11, [498112626] = 267,
	[499334752] = 80, [501069567] = 302, [501666924] = 306, [501911702] = 141, [501974987] = 163, [503284546] = 188,
	[504684517] = 407, [504750198] = 456, [506832919] = 336, [507283244] = 403, [507844109] = 371, [508018945] = 366,
	[509394808] = 219, [509489174] = 408, [510369132] = 315, [511626962] = 326, [513263939] = 47, [514377179] = 261,
	[514777850] = 323, [515144973] = 325, [517793126] = 161, [517992386] = 208, [519044963] = 93, [519234715] = 169,
	[520823410] = 406, [521321770] = 125, [521489848] = 233, [521841494] = 446, [521882070] = 303, [521936806] = 457,
	[523521669] = 15, [524082481] = 408, [525944418] = 379, [526270069] = 135, [529552061] = 178, [532001071] = 216,
	[532632614] = 412, [533290248] = 467, [533532202] = 429, [533545591] = 292, [537946820] = 245, [538627511] = 126,
	[539960839] = 324, [540046559] = 265, [541723677] = 51, [541807427] = 8, [542076223] = 448, [542279334] = 364,
	[542982037] = 333, [543707680] = 113, [544532832] = 436, [545594409] = 284, [548276449] = 62, [548856273] = 72,
	[549839668] = 117, [552046116] = 229, [552590161] = 265, [553010830] = 134, [555187393] = 330, [555883821] = 277,
	[558382598] = 275, [562276627] = 317, [566291305] = 431, [568787234] = 234, [570188411] = 410, [570384690] = 389,
	[571741614] = 55, [571883797] = 246, [572390761] = 83, [573010573] = 198, [574019749] = 229, [574364236] = 301,
	[574776594] = 10, [575696193] = 206, [576841026] = 314, [577448027] = 52, [581189715] = 201, [581247672] = 281,
	[582755530] = 13, [582935515] = 87, [584215670] = 233, [585185171] = 19, [587875823] = 28, [588278759] = 100,
	[589253950] = 17, [589361773] = 201, [590216189] = 427, [593038117] = 378, [595327646] = 333, [595365984] = 206,
	[595774967] = 259, [596907340] = 313, [597642187] = 260, [598819208] = 128, [598903132] = 223, [599748261] = 15,
	[599837036] = 49, [601808460] = 30, [601846226] = 52, [602173624] = 240, [602317782] = 429, [603404175] = 345,
	[605668431] = 428, [607933347] = 290, [608006692] = 253, [608080483] = 293, [610402385] = 185, [610483190] = 281,
	[611125374] = 291, [612306290] = 286, [612363235] = 363, [612536778] = 255, [612553342] = 105, [613324059] = 184,
	[616229013] = 170, [616720938] = 168, [617228970] = 327, [618236948] = 1, [618436917] = 386, [618949710] = 189,
	[620288699] = 415, [620880082] = 343, [621002243] = 221, [624570933] = 466, [628023288] = 150, [628300666] = 292,
	[629478799] = 408, [629667242] = 112, [630982356] = 261, [631087668] = 95, [632513392] = 193, [632656956] = 124,
	[632702935] = 34, [634588680] = 53, [635378892] = 225, [636816584] = 251, [641676097] = 270, [642444998] = 235,
	[643373325] = 67, [645220857] = 376, [645604770] = 235, [647048209] = 113, [649860255] = 102, [651568973] = 313,
	[652574623] = 452, [653475617] = 99, [655032413] = 373, [655471738] = 410, [655629449] = 12, [655725939] = 42,
	[656089676] = 56, [659488315] = 139, [662493873] = 317, [662847054] = 246, [665811891] = 232, [666746932] = 426,
	[666755077] = 367, [667499805] = 169, [671227336] = 379, [671779421] = 195, [673178195] = 70, [676556960] = 202,
	[676795663] = 52, [676807880] = 434, [678115827] = 39, [678473128] = 157, [679361579] = 137, [679966833] = 211,
	[681071729] = 444, [681803008] = 318, [683618912] = 139, [683967771] = 383, [685132757] = 108, [688445131] = 471,
	[689494953] = 458, [689532728] = 141, [689898140] = 418, [690140479] = 176, [690347760] = 129, [693483055] = 371,
	[693658334] = 127, [693802122] = 109, [694148987] = 66, [696680341] = 405, [697936393] = 249, [700008451] = 216,
	[701895163] = 78, [702315737] = 191, [702886024] = 12, [703093010] = 59, [703158269] = 167, [706913575] = 305,
	[707546992] = 466, [707929522] = 379, [708296553] = 69, [709581009] = 154, [709614677] = 330, [710801364] = 251,
	[714684142] = 37, [715331885] = 208, [715582169] = 467, [715717176] = 335, [715793295] = 338, [716471117] = 440,
	[717504711] = 74, [718615263] = 11, [718677756] = 13, [720941728] = 54, [722476545] = 444, [730142420] = 62,
	[730346882] = 446, [731411427] = 322, [731419287] = 412, [733973285] = 114, [736188716] = 78, [736704701] = 218,
	[738348258] = 127, [738470834] = 317, [738820549] = 468, [739293446] = 311, [740475648] = 276, [741905229] = 268,
	[742112504] = 296, [742565136] = 123, [743114200] = 121, [744051180] = 181, [744111463] = 232, [745151642] = 16,
	[746167991] = 327, [746575209] = 418, [747424168] = 13, [748298649] = 227, [749988290] = 73, [751568664] = 438,
	[753603672] = 423, [755124060] = 285, [756011019] = 33, [756506577] = 417, [756591085] = 114, [757175274] = 297,
	[757400923] = 216, [760450734] = 232, [760722011] = 51, [761906654] = 342, [762753088] = 184, [765219583] = 402,
	[765977320] = 145, [766149730] = 395, [769767945] = 346, [769924434] = 165, [770658082] = 234, [774472758] = 182,
	[774725487] = 252, [775204341] = 305, [776740686] = 50, [778418386] = 177, [780286755] = 12, [780712632] = 291,
	[782020591] = 468, [782427314] = 130, [782535508] = 276, [783152117] = 355, [783727135] = 40, [784506244] = 465,
	[785601958] = 374, [785638072] = 124, [785971653] = 317, [786483965] = 41, [789653640] = 34, [791577929] = 231,
	[792075589] = 282, [792804450] = 143, [793767696] = 336, [794335207] = 76, [794799208] = 48, [795404213] = 182,
	[795889451] = 276, [797152109] = 63, [797813577] = 263, [798230937] = 338, [798485937] = 301, [798892090] = 77,
	[800096829] = 158, [802061043] = 10, [802402993] = 81, [803291860] = 269, [805409818] = 21, [805540986] = 248,
	[806619591] = 314, [807011822] = 276, [807260228] = 234, [808941722] = 248, [809163910] = 358, [809813322] = 71,
	[809905917] = 313, [810460958] = 240, [812115803] = 370, [813677804] = 89, [815978427] = 170, [816386347] = 104,
	[816881746] = 362, [817847217] = 396, [819319319] = 262, [820319202] = 21, [820436469] = 345, [820818380] = 204,
	[820927197] = 30, [821578387] = 296, [822208312] = 102, [822816368] = 6, [823056477] = 235, [823734937] = 224,
	[824204569] = 49, [825046301] = 212, [825850715] = 348, [826735251] = 218, [826958122] = 288, [827801974] = 127,
	[831863295] = 96, [832701882] = 107, [837458219] = 251, [839405896] = 232, [839570191] = 311, [840091018] = 41,
	[840984837] = 416, [842551420] = 210, [842910881] = 416, [843446807] = 239, [845181024] = 213, [846236074] = 87,
	[846271991] = 54, [846551148] = 114, [849531115] = 259, [852349773] = 451, [853484023] = 183, [853745482] = 385,
	[854917878] = 326, [855830482] = 56, [856473688] = 5, [856589139] = 336, [860822859] = 432, [862332446] = 139,
	[863595210] = 58, [863626896] = 345, [865289701] = 459, [865648560] = 174, [869157913] = 152, [870749546] = 163,
	[872419319] = 173, [873282239] = 232, [874272961] = 431, [876789670] = 418, [876897941] = 149, [877076214] = 95,
	[877094626] = 403, [877381589] = 14, [878410050] = 281, [878737740] = 448, [879792623] = 225, [881022774] = 25,
	[881067246] = 132, [881486740] = 220, [881952542] = 437, [882114295] = 446, [883190134] = 207, [886104425] = 188,
	[886430221] = 449, [886860015] = 449, [887380136] = 204, [887850651] = 23, [889320771] = 175, [890814591] = 25,
	[890831062] = 431, [891608427] = 217, [892192433] = 26, [892603322] = 98, [894295042] = 416, [895549245] = 374,
	[898174318] = 41, [899894141] = 441, [900005165] = 359, [900268616] = 61, [903771611] = 272, [904672020] = 223,
	[904686470] = 252, [907576092] = 399, [908659558] = 330, [909258248] = 469, [912057189] = 54, [912639258] = 433,
	[912729155] = 329, [912851765] = 461, [913018253] = 273, [916297794] = 442, [916299960] = 270, [917337761] = 378,
	[917718488] = 401, [917983731] = 100, [922066241] = 337, [922293822] = 410, [924073707] = 162, [925291930] = 409,
	[925889118] = 13, [927434008] = 219, [927891651] = 277, [928429655] = 190, [931630447] = 207, [931679515] = 181,
	[932903605] = 94, [933712128] = 160, [937101639] = 209, [938592621] = 211, [939700726] = 130, [939724023] = 320,
	[939838609] = 110, [941295841] = 402, [941944428] = 372, [942608056] = 119, [942854282] = 443, [946495131] = 327,
	[947246113] = 412, [947642025] = 110, [947650507] = 323, [948120649] = 35, [949641174] = 81, [950187111] = 282,
	[951372519] = 222, [951949624] = 12, [951953216] = 297, [953046205] = 260, [956038193] = 242, [958069942] = 375,
	[958100131] = 201, [958237062] = 370, [958556024] = 8, [960134213] = 146, [962791970] = 350, [963726376] = 24,
	[965820456] = 121, [966161183] = 384, [966194367] = 456, [966528934] = 394, [970034843] = 378, [970099034] = 204,
	[970584921] = 325, [970658774] = 171, [973289176] = 337, [973522840] = 154, [976376990] = 207, [977607476] = 322,
	[977709893] = 346, [978631356] = 288, [980227842] = 104, [980551128] = 68, [981329096] = 121, [981689259] = 303,
	[981798629] = 213, [982213967] = 82, [983616898] = 173, [983864845] = 272, [984349743] = 162, [985975296] = 189,
	[991508705] = 47, [992053175] = 293, [993167969] = 152, [993260607] = 25, [996972565] = 32, [998005328] = 239,
	[998175061] = 361, [999830272] = 205, [999869623] = 127, [1000372873] = 461, [1000920908] = 347, [1001828127] = 396,
	[1002324248] = 15, [1003204015] = 370, [1004001797] = 225, [1004167916] = 17, [1004880517] = 170, [1005787627] = 237,
	[1006178451] = 29, [1006747265] = 383, [1007662944] = 333, [1011081525] = 121, [1014236280] = 322, [1017987228] = 258,
	[1018354402] = 365, [1020249333] = 141, [1020955067] = 71, [1022796217] = 79, [1025598520] = 137, [1025603970] = 310,
	[1026617971] = 261, [1029119777] = 115, [1030210568] = 353, [1030506304] = 375, [1031957448] = 369, [1032650456] = 146,
	[1033020460] = 259, [1033327218] = 442, [1034860093] = 423, [1035297836] = 1, [1035759260] = 10, [1035771276] = 105,
	[1035791950] = 16, [1035809741] = 318, [1036153181] = 377, [1036832404] = 272, [1037713303] = 372, [1038581900] = 376,
	[1039479510] = 303, [1040111796] = 59, [1040283558] = 464, [1041742147] = 284, [1046960467] = 455, [1049128745] = 37,
	[1049300824] = 428, [1049985283] = 453, [1050303494] = 269, [1050632002] = 471, [1052290122] = 326, [1053483600] = 38,
	[1054385604] = 9, [1055151401] = 263, [1056409598] = 181, [1057207175] = 181, [1058159771] = 433, [1058746237] = 405,
	[1058828503] = 48, [1060190435] = 273, [1061026485] = 369, [1061505989] = 423, [1062205487] = 299, [1062604977] = 209,
	[1063074299] = 49, [1063204560] = 337, [1064493985] = 65, [1065170813] = 219, [1066641818] = 82, [1067604364] = 226,
	[1070459407] = 288, [1072135116] = 2, [1073003672] = 295, [1073204674] = 300, [1074955812] = 465, [1076434685] = 266,
	[1076767063] = 79, [1077104629] = 120, [1077661689] = 326, [1078937098] = 311, [1079713633] = 168, [1081199632] = 153,
	[1081966402] = 386, [1083004043] = 339, [1083042499] = 115, [1084554553] = 440, [1084818053] = 62, [1084839024] = 298,
	[1085592790] = 141, [1087578319] = 376, [1088111417] = 419, [1090011724] = 138, [1091221527] = 379, [1092840750] = 359,
	[1094565832] = 215, [1094769687] = 158, [1096148565] = 66, [1096257053] = 148, [1096749199] = 129, [1097800749] = 409,
	[1100048683] = 415, [1100380250] = 354, [1100853514] = 342, [1100983793] = 380, [1101027264] = 272, [1103405556] = 117,
	[1105304225] = 261, [1105428856] = 292, [1108081600] = 421, [1108533260] = 247, [1108984786] = 16, [1109378881] = 52,
	[1109430624] = 338, [1110961243] = 450, [1112028338] = 226, [1112462292] = 82, [1113316770] = 31, [1114431479] = 93,
	[1114615750] = 122, [1116387633] = 299, [1117021496] = 270, [1117233805] = 350, [1117379648] = 334, [1117486618] = 50,
	[1117650809] = 194, [1117936980] = 404, [1119487034] = 245, [1119505946] = 454, [1120193795] = 459, [1121620782] = 292,
	[1123199608] = 237, [1124027765] = 169, [1125672125] = 71, [1125902303] = 305, [1126181827] = 42, [1127553094] = 417,
	[1128246731] = 240, [1129841289] = 438, [1130680048] = 40, [1131595194] = 430, [1131738856] = 243, [1133100193] = 231,
	[1133798907] = 288, [1133963463] = 118, [1134335386] = 390, [1134666697] = 317, [1134957889] = 135, [1135194388] = 193,
	[1135875824] = 402, [1136557545] = 23, [1136642485] = 241, [1138060658] = 389, [1140136716] = 230, [1140526383] = 296,
	[1141157665] = 381, [1141382555] = 76, [1141753363] = 181, [1142199261] = 10, [1143131405] = 293, [1143204748] = 228,
	[1144045078] = 92, [1145551521] = 205, [1150628375] = 291, [1150982498] = 77, [1151306824] = 264, [1152294519] = 187,
	[1152976620] = 74, [1157329308] = 362, [1157395469] = 200, [1157439873] = 400, [1160258047] = 146, [1160293674] = 201,
	[1160532748] = 35, [1161401581] = 246, [1162240557] = 139, [1162797367] = 349, [1164200999] = 277, [1165084813] = 262,
	[1165358210] = 224, [1166410662] = 14, [1168720052] = 47, [1169972221] = 324, [1170135303] = 451, [1171050429] = 172,
	[1173320561] = 14, [1173656854] = 465, [1173881783] = 294, [1174566177] = 437, [1174787955] = 5, [1175070171] = 79,
	[1177457478] = 339, [1178412136] = 66, [1180125948] = 15, [1180142596] = 356, [1180552104] = 258, [1180626803] = 265,
	[1180734375] = 2, [1181842728] = 377, [1182014866] = 119, [1183221550] = 101, [1183390609] = 419, [1183538225] = 363,
	[1183794542] = 255, [1185616600] = 61, [1186094057] = 119, [1188161215] = 196, [1191343432] = 351, [1192559660] = 243,
	[1193994934] = 289, [1194310681] = 439, [1195359637] = 353, [1196531552] = 462, [1199054881] = 424, [1199174033] = 85,
	[1201232440] = 5, [1205458059] = 246, [1206001377] = 175, [1206331960] = 128, [1209274842] = 86, [1212553570] = 468,
	[1212763314] = 455, [1212888795] = 5, [1213286761] = 175, [1214548501] = 155, [1215632487] = 281, [1216957039] = 38,
	[1217089408] = 349, [1218359066] = 169, [1218832322] = 93, [1220167116] = 225, [1221146434] = 434, [1223754991] = 164,
	[1223915298] = 446, [1226657045] = 72, [1227226481] = 115, [1227413570] = 40, [1228063876] = 419, [1228437715] = 413,
	[1232101464] = 434, [1233290115] = 407, [1233806683] = 129, [1235195677] = 161, [1236244879] = 171, [1236524659] = 74,
	[1236790806] = 214, [1238081417] = 121, [1238795487] = 36, [1239338584] = 45, [1239618199] = 409, [1240090465] = 158,
	[1240398034] = 277, [1240696853] = 270, [1242242952] = 43, [1242503214] = 224, [1243780397] = 334, [1244254343] = 427,
	[1244531032] = 219, [1246416477] = 302, [1247273646] = 313, [1247337801] = 180, [1247483415] = 169, [1248263366] = 445,
	[1249147878] = 380, [1249899916] = 262, [1250282326] = 202, [1251036055] = 232, [1255038070] = 122, [1256448939] = 177,
	[1256646685] = 6, [1257317902] = 237, [1259197696] = 194, [1259277062] = 27, [1259823176] = 245, [1260038844] = 457,
	[1260314521] = 99, [1261197186] = 450, [1261848628] = 63, [1262863065] = 359, [1262972837] = 394, [1263997995] = 282,
	[1264667422] = 165, [1266976619] = 457, [1269117209] = 446, [1269390849] = 310, [1269403446] = 451, [1270186005] = 286,
	[1270978326] = 72, [1271562020] = 323, [1272174000] = 248, [1274086711] = 132, [1276335992] = 287, [1276731560] = 228,
	[1276964305] = 132, [1278684594] = 337, [1279031096] = 210, [1279888659] = 226, [1280551509] = 227, [1280926789] = 172,
	[1281971229] = 34, [1283708770] = 24, [1284472646] = 280, [1285316084] = 418, [1286516125] = 20, [1292741295] = 16,
	[1293108129] = 50, [1293926467] = 374, [1296908621] = 108, [1299595076] = 412, [1299685720] = 295, [1301966371] = 348,
	[1302207491] = 443, [1302345180] = 264, [1303340326] = 36, [1304073702] = 407, [1304309327] = 375, [1304863962] = 35,
	[1306455654] = 185, [1307140197] = 298, [1307291178] = 263, [1308544175] = 188, [1308755325] = 12, [1309713963] = 146,
	[1310337488] = 255, [1310427610] = 285, [1310984121] = 402, [1313350276] = 353, [1313789731] = 140, [1314667201] = 155,
	[1314783678] = 214, [1314966104] = 441, [1315613888] = 215, [1316325655] = 34, [1316510993] = 453, [1319121879] = 429,
	[1320367047] = 174, [1322001238] = 260, [1324162298] = 149, [1324530634] = 3, [1324626923] = 295, [1325671703] = 462,
	[1326299310] = 151, [1327569682] = 147, [1334998249] = 245, [1336692402] = 11, [1336780613] = 211, [1336944237] = 377,
	[1337077835] = 151, [1338320730] = 274, [1341309331] = 65, [1341914091] = 91, [1342515292] = 72, [1343614299] = 193,
	[1343934060] = 432, [1344067787] = 156, [1344143063] = 365, [1344270331] = 385, [1345368575] = 100, [1345398210] = 30,
	[1345829658] = 406, [1345976816] = 406, [1346236163] = 105, [1348049792] = 361, [1348598027] = 346, [1349099340] = 217,
	[1349772151] = 153, [1350756187] = 48, [1351685682] = 166, [1351764287] = 461, [1351804830] = 434, [1352191663] = 191,
	[1352290345] = 458, [1353873662] = 382, [1354216808] = 139, [1357134629] = 39, [1357525483] = 175, [1358386707] = 326,
	[1358442627] = 104, [1359828270] = 400, [1362522415] = 373, [1364667123] = 264, [1364804552] = 430, [1365084749] = 424,
	[1367412856] = 331, [1369047227] = 102, [1370740077] = 437, [1371029706] = 323, [1371193955] = 348, [1372928624] = 284,
	[1373839533] = 45, [1375103987] = 410, [1375653317] = 26, [1376086040] = 136, [1377318997] = 442, [1377865462] = 155,
	[1378258182] = 43, [1385219963] = 344, [1385348737] = 212, [1386612600] = 439, [1387788435] = 103, [1387931197] = 207,
	[1387958872] = 459, [1388218912] = 7, [1389331994] = 279, [1389606201] = 155, [1390685165] = 1, [1391872374] = 325,
	[1394081743] = 47, [1395103851] = 205, [1395562718] = 59, [1396993614] = 25, [1397507958] = 365, [1397723446] = 68,
	[1398994091] = 149, [1401939534] = 339, [1402518644] = 387, [1403858784] = 430, [1404890029] = 238, [1405774571] = 432,
	[1406580817] = 340, [1407030746] = 91, [1407269666] = 431, [1407471648] = 389, [1408507220] = 148, [1408667051] = 206,
	[1408718349] = 363, [1409320547] = 224, [1410916263] = 220, [1413480250] = 411, [1413625766] = 258, [1414993351] = 329,
	[1417229148] = 196, [1418258422] = 66, [1420569579] = 43, [1420818027] = 400, [1421022605] = 118, [1421135404] = 373,
	[1421303597] = 370, [1422247722] = 430, [1423494676] = 407, [1423943254] = 384, [1424357266] = 297, [1424906250] = 208,
	[1425059406] = 229, [1425302117] = 226, [1426308655] = 19, [1426386864] = 68, [1426847074] = 380, [1427007212] = 84,
	[1427101234] = 152, [1427898306] = 264, [1428914780] = 334, [1430058086] = 358, [1432381198] = 391, [1432580775] = 56,
	[1433925367] = 306, [1434973327] = 213, [1435952751] = 234, [1436210215] = 427, [1436595445] = 393, [1438173983] = 244,
	[1438899242] = 51, [1440789041] = 128, [1441842709] = 51, [1442410512] = 20, [1444458423] = 95, [1445360344] = 84,
	[1446703410] = 170, [1448552602] = 16, [1450548963] = 202, [1450954350] = 99, [1453251459] = 353, [1454656858] = 364,
	[1456575721] = 63, [1457145782] = 404, [1457501669] = 403, [1459975851] = 456, [1460832159] = 91, [1461604352] = 356,
	[1463778596] = 140, [1464063737] = 44, [1464135564] = 238, [1464291488] = 260, [1464868733] = 252, [1465035119] = 368,
	[1467901944] = 16, [1469133670] = 9, [1470862899] = 42, [1470895744] = 95, [1473549119] = 9, [1474939529] = 331,
	[1475027116] = 135, [1475100228] = 337, [1477677444] = 58, [1477907866] = 28, [1478778507] = 218, [1480984898] = 388,
	[1481043364] = 207, [1482402585] = 309, [1482689220] = 144, [1483344497] = 341, [1483616804] = 215, [1484987227] = 136,
	[1485046431] = 151, [1485738837] = 464, [1487047951] = 108, [1487472891] = 392, [1490077765] = 74, [1491150385] = 421,
	[1492909922] = 118, [1494824005] = 101, [1497167308] = 153, [1497783732] = 6, [1498346671] = 325, [1498751864] = 411,
	[1499095093] = 250, [1500099977] = 12, [1500710160] = 301, [1502522751] = 357, [1505639355] = 200, [1508904690] = 282,
	[1509655081] = 81, [1509803273] = 19, [1509957302] = 358, [1512254826] = 344, [1512900709] = 131, [1517663240] = 267,
	[1518313409] = 156, [1519538198] = 286, [1519946436] = 132, [1520740173] = 198, [1520799895] = 273, [1520856168] = 463,
	[1523356967] = 299, [1523941765] = 394, [1524423776] = 216, [1524822449] = 145, [1524904081] = 137, [1525088709] = 343,
	[1525740827] = 289, [1528772081] = 385, [1528909097] = 468, [1529651731] = 257, [1529701957] = 188, [1531538864] = 211,
	[1531763282] = 339, [1533801629] = 415, [1536666263] = 285, [1536836195] = 375, [1537691049] = 381, [1539635659] = 68,
	[1539714240] = 163, [1540775145] = 258, [1541013982] = 408, [1541673070] = 391, [1541934283] = 291, [1542125114] = 361,
	[1543060296] = 34, [1544690717] = 307, [1545725905] = 448, [1546376553] = 450, [1546609733] = 274, [1547987166] = 124,
	[1549202254] = 440, [1549268899] = 415, [1549311281] = 222, [1549796136] = 254, [1550064203] = 70, [1550107859] = 185,
	[1550657865] = 214, [1550726318] = 418, [1553276648] = 165, [1554355524] = 405, [1554972527] = 254, [1555533776] = 455,
	[1555856268] = 304, [1556571555] = 246, [1556984378] = 204, [1557433990] = 376, [1557953898] = 457, [1558644162] = 244,
	[1558971591] = 174, [1560092631] = 184, [1562154025] = 175, [1562522567] = 344, [1563851975] = 64, [1563905369] = 47,
	[1564601164] = 259, [1566399683] = 126, [1567381925] = 182, [1568112158] = 126, [1569620267] = 133, [1571076186] = 303,
	[1574088999] = 126, [1574481937] = 18, [1575186424] = 222, [1576325270] = 385, [1580461645] = 238, [1581328771] = 354,
	[1583607522] = 128, [1584672825] = 131, [1586890674] = 56, [1586906411] = 25, [1588362636] = 244, [1588557602] = 427,
	[1588868866] = 109, [1589066990] = 253, [1590208426] = 78, [1590841831] = 284, [1594230830] = 47, [1594718172] = 300,
	[1594759557] = 190, [1595803735] = 209, [1596901191] = 452, [1598407436] = 4, [1601324644] = 48, [1601429190] = 393,
	[1601714514] = 362, [1602767098] = 433, [1604587986] = 381, [1605933376] = 348, [1607316669] = 383, [1607677382] = 110,
	[1608285775] = 298, [1609243501] = 106, [1609333911] = 304, [1611915487] = 228, [1613316505] = 182, [1615002676] = 249,
	[1617714550] = 315, [1617749234] = 439, [1620627970] = 210, [1621991209] = 172, [1624023707] = 227, [1625248997] = 239,
	[1627012365] = 305, [1627217601] = 357, [1627256574] = 221, [1627276552] = 21, [1628076484] = 92, [1628278115] = 397,
	[1628457631] = 120, [1631108631] = 453, [1631177455] = 145, [1631787475] = 365, [1634110046] = 460, [1634230918] = 263,
	[1635248045] = 265, [1638150486] = 308, [1638457990] = 142, [1638988818] = 255, [1640256553] = 228, [1640323351] = 83,
	[1645052643] = 215, [1646284383] = 423, [1647077179] = 38, [1651115990] = 391, [1651808034] = 328, [1654516997] = 460,
	[1655675539] = 115, [1656627711] = 172, [1656670980] = 92, [1657097599] = 49, [1658410932] = 24, [1658732981] = 251,
	[1659603758] = 426, [1660263865] = 257, [1662171739] = 38, [1662402380] = 159, [1662755568] = 192, [1663577673] = 321,
	[1663734658] = 98, [1665088638] = 157, [1665804308] = 13, [1666164164] = 219, [1667434208] = 377, [1667451219] = 142,
	[1668761358] = 320, [1669514181] = 469, [1670230662] = 467, [1670303381] = 422, [1672870364] = 303, [1673117906] = 428,
	[1673364413] = 185, [1674303770] = 305, [1676693712] = 463, [1677367011] = 334, [1678045459] = 366, [1678149345] = 11,
	[1680808346] = 429, [1681019875] = 113, [1681162983] = 343, [1681369875] = 4, [1681403658] = 460, [1681662076] = 125,
	[1682063034] = 319, [1682135398] = 340, [1683595991] = 11, [1683926883] = 442, [1687915868] = 395, [1689250111] = 176,
	[1690891714] = 192, [1691481713] = 134, [1693210265] = 130, [1694373097] = 471, [1694662746] = 395, [1695436142] = 240,
	[1695803517] = 106, [1695878265] = 123, [1698656054] = 160, [1699220598] = 376, [1699719933] = 329, [1704991091] = 237,
	[1705498337] = 338, [1707288151] = 104, [1707309149] = 372, [1708785181] = 377, [1710135815] = 2, [1711258643] = 435,
	[1711872759] = 426, [1713286591] = 408, [1713516770] = 180, [1713799330] = 346, [1715279065] = 165, [1716000731] = 308,
	[1717136855] = 336, [1718965382] = 266, [1719843846] = 253, [1720164011] = 432, [1720934866] = 263, [1722358195] = 384,
	[1722980813] = 364, [1724290901] = 423, [1724629326] = 461, [1724854655] = 150, [1725708342] = 267, [1725882056] = 392,
	[1725925081] = 261, [1727053408] = 342, [1727314724] = 166, [1728370844] = 456, [1728475715] = 91, [1729363028] = 181,
	[1729823342] = 2, [1729893056] = 305, [1729919633] = 185, [1730135852] = 257, [1731975409] = 7, [1732664234] = 464,
	[1733750212] = 395, [1738005351] = 177, [1738097050] = 381, [1739024562] = 53, [1740435916] = 326, [1740524079] = 115,
	[1745297992] = 10, [1746476594] = 97, [1746554391] = 24, [1747859430] = 114, [1748242483] = 440, [1748791630] = 37,
	[1751525876] = 75, [1751859209] = 258, [1752410151] = 157, [1754266366] = 331, [1754812723] = 334, [1755288385] = 158,
	[1755695857] = 14, [1755849049] = 310, [1757645112] = 421, [1759646316] = 390, [1760448045] = 24, [1760859123] = 459,
	[1761243477] = 419, [1761526003] = 317, [1761872437] = 316, [1763698239] = 83, [1764155965] = 429, [1767102357] = 153,
	[1767666062] = 241, [1769899532] = 124, [1770031990] = 114, [1771088814] = 358, [1771233771] = 25, [1773373539] = 210,
	[1774438945] = 212, [1774871510] = 325, [1776889411] = 101, [1776970006] = 330, [1780247462] = 168, [1780460430] = 244,
	[1780549130] = 261, [1783348646] = 1, [1783893982] = 328, [1785894709] = 338, [1786261182] = 41, [1790193167] = 296,
	[1791305018] = 184, [1792069615] = 165, [1792157765] = 149, [1792184018] = 57, [1792238830] = 104, [1793173829] = 118,
	[1794358177] = 230, [1794732371] = 346, [1795772111] = 290, [1796157603] = 133, [1796941503] = 187, [1798346898] = 159,
	[1798871310] = 72, [1799064106] = 334, [1800577388] = 320, [1801357284] = 449, [1802645229] = 178, [1803901363] = 27,
	[1803933988] = 324, [1804092675] = 412, [1806116769] = 93, [1807508123] = 157, [1807797046] = 112, [1807988716] = 340,
	[1808874251] = 33, [1810067676] = 145, [1810098223] = 431, [1812137501] = 88, [1814384758] = 396, [1814946516] = 301,
	[1816549953] = 341, [1821509116] = 287, [1823620151] = 262, [1824017342] = 232, [1824281485] = 421, [1825014375] = 61,
	[1826105025] = 378, [1828247815] = 77, [1828712371] = 25, [1830085219] = 276, [1830720929] = 367, [1831245487] = 309,
	[1832180024] = 123, [1832466421] = 458, [1833671972] = 433, [1834777326] = 238, [1835907454] = 256, [1837264463] = 328,
	[1837549509] = 109, [1838371281] = 462, [1839263389] = 188, [1840643097] = 331, [1840672094] = 138, [1841164496] = 66,
	[1841973963] = 44, [1842054507] = 261, [1843459116] = 120, [1843548180] = 96, [1843736322] = 90, [1844405829] = 366,
	[1844475888] = 42, [1845706479] = 331, [1846334904] = 197, [1847627498] = 81, [1847703311] = 366, [1848239126] = 87,
	[1848818152] = 36, [1852036131] = 152, [1852687102] = 431, [1852733968] = 321, [1853209436] = 280, [1855428598] = 384,
	[1856107838] = 226, [1856652108] = 21, [1857315511] = 442, [1857515393] = 347, [1857648220] = 78, [1859630400] = 193,
	[1860326109] = 45, [1862002506] = 358, [1862339040] = 283, [1863448085] = 298, [1865043400] = 159, [1867369259] = 205,
	[1868668168] = 36, [1869384225] = 256, [1869588379] = 294, [1872140669] = 361, [1872334721] = 323, [1872361295] = 131,
	[1873729049] = 184, [1874178032] = 73, [1874946881] = 96, [1875642658] = 196, [1878034543] = 332, [1878129116] = 374,
	[1878840411] = 140, [1879668713] = 49, [1881135178] = 246, [1881207324] = 46, [1889545476] = 94, [1891128369] = 279,
	[1891892607] = 191, [1893113426] = 414, [1893663688] = 280, [1894840770] = 401, [1896435773] = 332, [1896946342] = 7,
	[1897487233] = 396, [1898640540] = 145, [1901215867] = 224, [1902100148] = 436, [1902206483] = 392, [1903355188] = 119,
	[1904537109] = 291, [1904849257] = 382, [1905201744] = 383, [1905264480] = 105, [1905328714] = 375, [1906690001] = 96,
	[1906719182] = 22, [1909176902] = 153, [1909662579] = 16, [1912708247] = 371, [1913119054] = 228, [1915046541] = 315,
	[1915164823] = 382, [1915793558] = 164, [1916417975] = 465, [1917708976] = 13, [1918099373] = 382, [1919073149] = 102,
	[1919924025] = 275, [1920940716] = 351, [1921376878] = 341, [1922622277] = 175, [1923092117] = 382, [1925566287] = 241,
	[1925588361] = 20, [1926307538] = 447, [1926803304] = 402, [1927421811] = 248, [1929335790] = 427, [1929838992] = 308,
	[1932176124] = 269, [1933104254] = 293, [1933791492] = 210, [1935033597] = 73, [1935389813] = 426, [1936413336] = 42,
	[1937891050] = 190, [1938173359] = 405, [1938392557] = 352, [1938630159] = 111, [1940219671] = 308, [1940415326] = 91,
	[1940737916] = 409, [1942267602] = 121, [1943764602] = 245, [1946383993] = 93, [1946783517] = 253, [1947475308] = 439,
	[1949010734] = 168, [1949449045] = 214, [1950101074] = 3, [1950367527] = 42, [1950560279] = 60, [1950937337] = 332,
	[1952851700] = 425, [1954079049] = 394, [1954558163] = 363, [1954839599] = 464, [1957203136] = 352, [1957739891] = 319,
	[1958949741] = 310, [1959901934] = 335, [1960308723] = 136, [1962778087] = 173, [1963316401] = 421, [1963421152] = 205,
	[1965943440] = 345, [1966813884] = 153, [1968622992] = 5, [1971887950] = 406, [1973324311] = 352, [1973548205] = 3,
	[1976404970] = 412, [1977169993] = 351, [1977224755] = 52, [1977991846] = 274, [1979507615] = 179, [1980418557] = 425,
	[1981112453] = 44, [1981949710] = 113, [1982833265] = 125, [1982837780] = 100, [1984593668] = 213, [1985767584] = 428,
	[1985913268] = 69, [1986886648] = 180, [1987235878] = 302, [1987669226] = 216, [1988090099] = 356, [1988187100] = 204,
	[1989379037] = 316, [1989643502] = 300, [1992408673] = 278, [1995910386] = 404, [1997777498] = 255, [1997966346] = 238,
	[1998614326] = 301, [2000185330] = 175, [2000296257] = 227, [2001016501] = 219, [2001019467] = 357, [2003855186] = 270,
	[2004553609] = 17, [2005648325] = 268, [2007893794] = 63, [2008887393] = 97, [2009982212] = 397, [2010191238] = 469,
	[2010794947] = 138, [2012725271] = 10, [2017003367] = 456, [2017903247] = 82, [2019161966] = 93, [2019924315] = 352,
	[2021583117] = 67, [2022942614] = 459, [2023260166] = 314, [2023646062] = 317, [2023732173] = 350, [2024363910] = 387,
	[2024663184] = 306, [2025020971] = 205, [2025481566] = 136, [2027119643] = 166, [2028100615] = 181, [2028780615] = 419,
	[2028873451] = 96, [2028881529] = 346, [2029010968] = 438, [2030512647] = 38, [2031493937] = 374, [2032474245] = 340,
	[2032875693] = 171, [2035072574] = 158, [2035179925] = 186, [2036157350] = 95, [2036904156] = 406, [2036944589] = 443,
	[2039202141] = 437, [2041024448] = 89, [2041386341] = 467, [2041773916] = 8, [2043471955] = 40, [2043513814] = 299,
	[2043534669] = 339, [2046057846] = 209, [2046572188] = 78, [2047898330] = 28, [2048597955] = 295, [2049670495] = 50,
	[2050293814] = 283, [2050347355] = 2, [2050853053] = 22, [2052169623] = 98, [2052242849] = 338, [2053980976] = 178,
	[2054075497] = 316, [2055541825] = 133, [2056143195] = 380, [2056359856] = 356, [2057151322] = 167, [2057505158] = 224,
	[2057771503] = 15, [2058017156] = 391, [2058213173] = 440, [2059193078] = 337, [2059472395] = 41, [2060712464] = 71,
	[2063464541] = 101, [2064097346] = 444, [2064929863] = 377, [2067216822] = 259, [2069743511] = 387, [2069900416] = 23,
	[2072582566] = 318, [2074440778] = 231, [2074501289] = 148, [2075345924] = 269, [2076047057] = 80, [2077674991] = 293,
	[2078293713] = 239, [2078687857] = 465, [2079959089] = 185, [2080098367] = 159, [2080752977] = 106, [2080811505] = 320,
	[2084440926] = 189, [2084565824] = 155, [2086484997] = 55, [2086890406] = 188, [2087001442] = 157, [2087794960] = 12,
	[2089638089] = 464, [2090092752] = 133, [2092263280] = 342, [2093005829] = 265, [2093652334] = 231, [2094350771] = 283,
	[2094581668] = 349, [2095212640] = 202, [2095393746] = 196, [2096702513] = 333, [2097412216] = 422, [2097741920] = 294,
	[2100390046] = 153, [2101164511] = 170, [2105292242] = 116, [2105376187] = 348, [2106043618] = 155, [2107754392] = 39,
	[2110567688] = 302, [2111802232] = 110, [2112436365] = 253, [2113569080] = 6, [2114444678] = 160, [2114627706] = 370,
	[2119286354] = 386, [2121181297] = 42, [2121971035] = 130, [2122207463] = 183, [2124214551] = 193, [2124388225] = 447,
	[2127071893] = 16, [2129016886] = 197, [2130358241] = 18, [2130461513] = 271, [2131071240] = 455, [2131138470] = 209,
	[2131738373] = 10, [2131865141] = 397, [2132108619] = 191, [2132452974] = 327, [2132565349] = 327, [2133058248] = 319,
	[2133112298] = 350, [2135407499] = 276, [2138300899] = 68, [2139722823] = 137, [2141259094] = 251, [2142678360] = 343,
	[2144024924] = 341, [2147082974] = 393, [2148964941] = 24, [2152085784] = 201, [2152930568] = 152, [2153077231] = 221,
	[2153386929] = 158, [2154925510] = 400, [2156283240] = 75, [2156391930] = 102, [2157593073] = 296, [2158001589] = 373,
	[2158927592] = 255, [2161149277] = 364, [2162174516] = 338, [2164253893] = 242, [2165212171] = 139, [2165487278] = 469,
	[2165836932] = 435, [2165870710] = 285, [2166111208] = 360, [2168597523] = 18, [2169090431] = 58, [2170476476] = 11,
	[2171676074] = 33, [2172458745] = 32, [2174669273] = 30, [2174753445] = 178, [2175455275] = 150, [2178496597] = 423,
	[2178999023] = 83, [2179401551] = 266, [2179470395] = 399, [2183148657] = 266, [2184014804] = 454, [2184540389] = 103,
	[2185891544] = 441, [2187264678] = 333, [2187893643] = 360, [2187901217] = 222, [2188550884] = 381, [2189098859] = 413,
	[2190034929] = 55, [2190062816] = 310, [2191129326] = 456, [2192745620] = 63, [2192914146] = 156, [2196676833] = 63,
	[2197149509] = 65, [2198407616] = 107, [2198542418] = 76, [2198550448] = 135, [2201449054] = 119, [2201853398] = 434,
	[2202673751] = 61, [2203795728] = 220, [2204688935] = 167, [2205090556] = 319, [2205939573] = 420, [2206239712] = 234,
	[2206724011] = 452, [2207212170] = 200, [2207238197] = 292, [2209204620] = 457, [2209424172] = 312, [2210177530] = 312,
	[2212351959] = 127, [2213657221] = 445, [2214372058] = 260, [2214650862] = 246, [2216962132] = 342, [2217224304] = 320,
	[2219566856] = 424, [2220671266] = 22, [2221975620] = 30, [2223219033] = 463, [2223536432] = 397, [2223911270] = 147,
	[2226428263] = 360, [2226564557] = 136, [2227055631] = 358, [2227250399] = 316, [2229077983] = 343, [2229709441] = 91,
	[2230002616] = 348, [2230602981] = 265, [2230622390] = 195, [2232784227] = 98, [2232964763] = 90, [2233522537] = 332,
	[2234064154] = 32, [2234127192] = 4, [2236299533] = 88, [2236739232] = 209, [2237607945] = 50, [2238905790] = 249,
	[2241645008] = 36, [2242007641] = 376, [2242399278] = 316, [2242431733] = 252, [2249937662] = 164, [2254360419] = 443,
	[2254659836] = 130, [2255636868] = 101, [2257898239] = 331, [2258215535] = 23, [2258732938] = 434, [2262034141] = 211,
	[2262694945] = 332, [2264186233] = 39, [2265126825] = 234, [2265530423] = 449, [2268587946] = 415, [2270657110] = 329,
	[2270761885] = 458, [2270819754] = 328, [2272356006] = 348, [2272379262] = 73, [2273337552] = 169, [2274016369] = 105,
	[2276422689] = 249, [2277260454] = 345, [2277277873] = 331, [2277440770] = 250, [2279575991] = 72, [2279619613] = 398,
	[2281242496] = 428, [2281303471] = 351, [2282229937] = 281, [2286251965] = 366, [2287123443] = 215, [2287826707] = 306,
	[2288553041] = 275, [2290357168] = 387, [2293852781] = 395, [2293967761] = 37, [2295961605] = 287, [2297984961] = 181,
	[2298615574] = 207, [2299445730] = 208, [2299475711] = 18, [2300017401] = 298, [2303120102] = 43, [2303754113] = 259,
	[2303880944] = 294, [2304162982] = 449, [2304322738] = 341, [2307170215] = 12, [2308075754] = 29, [2308489969] = 173,
	[2310252132] = 86, [2310440902] = 408, [2314941081] = 206, [2315521958] = 5, [2315580894] = 94, [2316528993] = 61,
	[2317057984] = 255, [2317379158] = 176, [2322421040] = 80, [2322712564] = 95, [2324499917] = 294, [2328112464] = 454,
	[2328373379] = 384, [2328885145] = 164, [2331014163] = 329, [2331050132] = 447, [2331560404] = 416, [2332006584] = 371,
	[2334978848] = 236, [2335328037] = 347, [2335346764] = 90, [2336995885] = 405, [2338665782] = 193, [2339678384] = 89,
	[2340068777] = 58, [2340474974] = 179, [2340667267] = 101, [2341181661] = 186, [2342725490] = 310, [2343261127] = 365,
	[2344952710] = 242, [2346844963] = 289, [2348990921] = 197, [2349528723] = 428, [2349975121] = 354, [2350757433] = 420,
	[2351522217] = 208, [2352135411] = 116, [2355799342] = 357, [2356334156] = 64, [2356793477] = 289, [2357077406] = 308,
	[2357227953] = 296, [2358790485] = 41, [2360333388] = 297, [2360885919] = 364, [2362223252] = 50, [2363259553] = 84,
	[2365084755] = 151, [2367768149] = 360, [2368385312] = 299, [2368429288] = 193, [2369871119] = 373, [2370612134] = 14,
	[2372363678] = 235, [2376870710] = 402, [2376962043] = 362, [2377280709] = 111, [2378119393] = 369, [2379347518] = 276,
	[2381512703] = 445, [2381654221] = 464, [2383159114] = 407, [2387255831] = 339, [2390870980] = 178, [2390887242] = 339,
	[2392049959] = 1, [2392227448] = 187, [2392252376] = 197, [2392987018] = 320, [2393385699] = 60, [2393422698] = 231,
	[2393790561] = 434, [2399867418] = 189, [2402246581] = 379, [2402982995] = 170, [2403308629] = 373, [2405468121] = 158,
	[2406568590] = 458, [2408851373] = 371, [2408916184] = 287, [2409904011] = 27, [2410431859] = 425, [2411176188] = 329,
	[2411913039] = 460, [2413247805] = 350, [2414437524] = 114, [2416567198] = 466, [2417812885] = 46, [2420102316] = 365,
	[2420851383] = 307, [2422131797] = 117, [2423000440] = 241, [2424417937] = 147, [2425411620] = 464, [2426569116] = 342,
	[2426788771] = 468, [2430229472] = 274, [2430322720] = 468, [2431203259] = 33, [2431204018] = 59, [2435348132] = 280,
	[2436179063] = 157, [2436556439] = 229, [2436896916] = 453, [2437308052] = 13, [2437344203] = 204, [2437581599] = 285,
	[2439428406] = 144, [2439701251] = 27, [2439943203] = 203, [2439988036] = 344, [2441138781] = 180, [2441584121] = 165,
	[2442779499] = 77, [2444320747] = 438, [2445218116] = 410, [2445794507] = 142, [2445941058] = 398, [2447632476] = 113,
	[2448561749] = 121, [2448999201] = 183, [2449578149] = 218, [2449832634] = 294, [2450454189] = 226, [2452808146] = 143,
	[2456160611] = 323, [2456514449] = 435, [2461874552] = 169, [2463098510] = 23, [2463690051] = 286, [2464453604] = 250,
	[2464577710] = 236, [2464703067] = 409, [2468841443] = 181, [2470927862] = 217, [2472900739] = 281, [2473983127] = 44,
	[2474614777] = 218, [2475886474] = 282, [2475990396] = 220, [2476829247] = 155, [2477909753] = 7, [2478129852] = 454,
	[2478189016] = 280, [2479740045] = 6, [2482605692] = 253, [2483388154] = 400, [2483592182] = 225, [2484551591] = 233,
	[2485181401] = 184, [2485264749] = 135, [2485489894] = 292, [2486783322] = 102, [2487002606] = 362, [2488266830] = 428,
	[2489791673] = 252, [2491664645] = 323, [2492037440] = 195, [2492432694] = 353, [2494302915] = 440, [2494328891] = 67,
	[2494399360] = 413, [2494583535] = 354, [2494957643] = 147, [2495281049] = 132, [2496448651] = 56, [2500667815] = 236,
	[2500710307] = 316, [2503074658] = 401, [2503910745] = 72, [2505839267] = 288, [2506135236] = 89, [2507150314] = 180,
	[2507415505] = 89, [2508263585] = 224, [2508388701] = 251, [2508931935] = 335, [2509613866] = 125, [2509678304] = 282,
	[2511248827] = 259, [2511666834] = 87, [2512363330] = 376, [2513213607] = 330, [2513460586] = 123, [2515672518] = 31,
	[2517069610] = 377, [2518092722] = 124, [2518308813] = 349, [2518689604] = 417, [2519447575] = 173, [2519500341] = 277,
	[2519562582] = 113, [2519872193] = 457, [2521107925] = 312, [2522512431] = 213, [2523704987] = 279, [2525840355] = 131,
	[2529397267] = 391, [2529779467] = 220, [2531328530] = 88, [2532273269] = 6, [2532339793] = 392, [2534066814] = 422,
	[2536318336] = 53, [2537641877] = 216, [2538200302] = 442, [2539055750] = 257, [2540290441] = 280, [2540826998] = 172,
	[2548023563] = 107, [2548518839] = 297, [2548573801] = 100, [2549641415] = 382, [2550307363] = 429, [2551038877] = 184,
	[2551445034] = 55, [2551450116] = 64, [2552816698] = 260, [2553722720] = 351, [2555781896] = 430, [2556800002] = 356,
	[2557578725] = 227, [2558102088] = 120, [2558559558] = 23, [2559487149] = 417, [2560788515] = 322, [2561570643] = 122,
	[2562351392] = 381, [2562750491] = 61, [2563131419] = 130, [2568481511] = 220, [2568682514] = 398, [2569104589] = 460,
	[2569625864] = 406, [2571358656] = 208, [2572215659] = 362, [2572658436] = 119, [2579356335] = 262, [2580144297] = 126,
	[2580341438] = 157, [2580513324] = 267, [2581007957] = 120, [2581498112] = 307, [2581746267] = 268, [2582365878] = 460,
	[2582505772] = 32, [2583174142] = 262, [2584045350] = 127, [2584515700] = 336, [2584806325] = 371, [2585960730] = 388,
	[2586127954] = 422, [2586422887] = 99, [2586451304] = 9, [2586793260] = 409, [2587095918] = 148, [2588382606] = 90,
	[2589112803] = 184, [2589500397] = 85, [2591179391] = 60, [2593660304] = 462, [2593784421] = 166, [2597388352] = 463,
	[2599599336] = 469, [2599960868] = 35, [2600391781] = 256, [2600634636] = 435, [2601529898] = 40, [2605139151] = 2,
	[2605376686] = 316, [2605542875] = 123, [2606850249] = 90, [2608346758] = 393, [2608347177] = 210, [2608389599] = 154,
	[2609022969] = 367, [2609273322] = 172, [2609624068] = 236, [2610609045] = 411, [2612959115] = 417, [2613362603] = 355,
	[2613950819] = 399, [2614161871] = 32, [2614608229] = 103, [2616300632] = 137, [2617787855] = 135, [2620195338] = 241,
	[2620227689] = 461, [2621568239] = 469, [2624318286] = 293, [2625000886] = 132, [2626170427] = 426, [2626510701] = 244,
	[2626897667] = 60, [2627070464] = 314, [2627462485] = 390, [2628247064] = 140, [2629660165] = 115, [2630084627] = 53,
	[2630177856] = 124, [2630534281] = 269, [2635024445] = 120, [2635150071] = 45, [2637081533] = 369, [2638183743] = 272,
	[2638919519] = 243, [2639530786] = 320, [2639907071] = 432, [2640137163] = 285, [2640667162] = 50, [2640687964] = 18,
	[2640926075] = 239, [2641251785] = 186, [2642128642] = 75, [2642372576] = 122, [2643931372] = 95, [2645036015] = 351,
	[2645785023] = 443, [2646430928] = 148, [2649125027] = 273, [2649234125] = 107, [2649802940] = 306, [2652320248] = 23,
	[2652941875] = 417, [2653358892] = 365, [2654769811] = 277, [2655661638] = 177, [2659285620] = 229, [2659293491] = 379,
	[2659404582] = 176, [2660041658] = 217, [2660475167] = 411, [2660618225] = 125, [2660835411] = 122, [2662544725] = 101,
	[2665464989] = 97, [2666234897] = 237, [2666441693] = 257, [2668753918] = 293, [2668834075] = 79, [2671472858] = 59,
	[2673287157] = 81, [2675357770] = 86, [2679212776] = 21, [2679510939] = 180, [2680690573] = 87, [2681066222] = 150,
	[2681420083] = 445, [2682041502] = 32, [2683409454] = 279, [2684818051] = 198, [2686256382] = 194, [2687755319] = 94,
	[2688192022] = 156, [2689331335] = 445, [2689490559] = 304, [2689535385] = 376, [2689644617] = 295, [2689906956] = 349,
	[2690694636] = 407, [2690777493] = 40, [2691671336] = 182, [2691858891] = 75, [2693489705] = 444, [2693987476] = 447,
	[2695401494] = 413, [2695970305] = 65, [2696149334] = 397, [2696189255] = 398, [2696796982] = 31, [2696803749] = 328,
	[2697394416] = 72, [2700366400] = 351, [2700519840] = 6, [2700615662] = 398, [2702800086] = 63, [2703477740] = 294,
	[2704634836] = 79, [2705794809] = 140, [2708251443] = 212, [2709087745] = 171, [2709693379] = 269, [2711556139] = 162,
	[2712106459] = 48, [2712797905] = 163, [2713761677] = 70, [2714714113] = 67, [2716103407] = 254, [2716655515] = 76,
	[2717178957] = 447, [2717758023] = 249, [2720756708] = 167, [2720937150] = 355, [2721215239] = 229, [2722421556] = 29,
	[2722720005] = 13, [2723729935] = 283, [2726421947] = 59, [2726460319] = 40, [2726809554] = 190, [2726818019] = 218,
	[2728205714] = 287, [2729308854] = 330, [2729386770] = 416, [2730152604] = 130, [2730275432] = 57, [2732096900] = 16,
	[2733189353] = 321, [2733733752] = 379, [2734792800] = 358, [2734897538] = 40, [2735438692] = 159, [2735627428] = 148,
	[2735770329] = 299, [2736687795] = 163, [2746148742] = 302, [2747535964] = 326, [2748640862] = 416, [2749857943] = 235,
	[2750437741] = 46, [2750776075] = 347, [2750807893] = 139, [2751363216] = 264, [2751402454] = 30, [2751784635] = 422,
	[2752707334] = 54, [2753064243] = 387, [2753407274] = 420, [2753597652] = 362, [2754858550] = 35, [2755043151] = 363,
	[2755364856] = 5, [2755835149] = 324, [2755987429] = 174, [2755997346] = 343, [2757572580] = 182, [2757576980] = 354,
	[2757704961] = 88, [2759366177] = 250, [2759640297] = 439, [2760443053] = 343, [2760785309] = 278, [2762437064] = 375,
	[2765050524] = 60, [2766163433] = 135, [2767610052] = 276, [2768716812] = 137, [2768911944] = 341, [2770160761] = 75,
	[2771665160] = 231, [2772980253] = 84, [2774631230] = 312, [2775412987] = 269, [2776369376] = 213, [2777106824] = 249,
	[2777612198] = 207, [2780770753] = 337, [2781408981] = 349, [2782073140] = 188, [2782353906] = 379, [2783758949] = 194,
	[2783880939] = 222, [2784084284] = 97, [2784247661] = 404, [2788298016] = 298, [2788576033] = 400, [2790095280] = 307,
	[2790602900] = 3, [2790634436] = 444, [2794649205] = 224, [2795160758] = 82, [2796024340] = 446, [2797651212] = 19,
	[2798157943] = 238, [2801906629] = 268, [2802345855] = 78, [2804878652] = 392, [2806000148] = 31, [2806229472] = 97,
	[2807807952] = 375, [2810930107] = 234, [2812505438] = 109, [2818253534] = 345, [2818376012] = 369, [2819561377] = 173,
	[2820711620] = 187, [2820978486] = 322, [2821162385] = 100, [2822572035] = 64, [2822853548] = 7, [2823760319] = 41,
	[2824615267] = 18, [2824870299] = 149, [2825106097] = 245, [2825527963] = 129, [2825737416] = 285, [2826528100] = 30,
	[2828721760] = 124, [2829501828] = 133, [2829737582] = 459, [2829988336] = 269, [2831859467] = 264, [2833151958] = 471,
	[2834884084] = 428, [2835738178] = 207, [2835803682] = 286, [2835961130] = 286, [2836376353] = 446, [2836962017] = 7,
	[2840186005] = 62, [2840190789] = 4, [2840473890] = 10, [2840812814] = 286, [2841452956] = 363, [2841900602] = 443,
	[2842457319] = 162, [2844121094] = 10, [2844846266] = 381, [2846434049] = 125, [2846445704] = 349, [2848433285] = 151,
	[2848893590] = 46, [2849276704] = 110, [2850221795] = 304, [2851808134] = 390, [2851818194] = 470, [2852628423] = 74,
	[2853664595] = 100, [2854455551] = 290, [2855395026] = 96, [2855858933] = 68, [2857488240] = 401, [2858797136] = 192,
	[2859247012] = 290, [2859792982] = 319, [2860413236] = 266, [2860538941] = 66, [2863546799] = 140, [2864058369] = 288,
	[2865740774] = 20, [2867064291] = 453, [2868393238] = 364, [2870118425] = 14, [2871137169] = 305, [2871189666] = 57,
	[2876273712] = 85, [2876311586] = 48, [2876808705] = 39, [2878175544] = 85, [2880300055] = 129, [2881565832] = 445,
	[2882196665] = 119, [2884157428] = 433, [2886812066] = 234, [2888068293] = 194, [2888379713] = 28, [2888606409] = 253,
	[2888644843] = 53, [2888832503] = 254, [2889280747] = 9, [2891320488] = 149, [2891962523] = 300, [2892713989] = 278,
	[2894637645] = 424, [2894672374] = 396, [2896572306] = 412, [2897957592] = 149, [2898003297] = 462, [2898717691] = 141,
	[2899677154] = 189, [2899995494] = 230, [2900303488] = 314, [2901279180] = 218, [2902172946] = 309, [2902826406] = 406,
	[2903603203] = 280, [2905011030] = 148, [2905515681] = 448, [2907428328] = 37, [2908741025] = 374, [2908988938] = 101,
	[2909756120] = 64, [2909973507] = 431, [2910589784] = 252, [2911542289] = 436, [2915516156] = 451, [2917923385] = 154,
	[2918285820] = 108, [2921762141] = 138, [2922138275] = 15, [2922544464] = 444, [2923463127] = 113, [2923721144] = 398,
	[2925664566] = 199, [2925814127] = 271, [2929147642] = 462, [2929270190] = 357, [2930583552] = 278, [2930815980] = 52,
	[2931475022] = 352, [2932548185] = 433, [2937340209] = 49, [2937564066] = 164, [2938021106] = 268, [2938188319] = 70,
	[2940598476] = 368, [2940800513] = 290, [2941077863] = 383, [2941967179] = 311, [2943308827] = 190, [2944337503] = 104,
	[2946319624] = 369, [2946893471] = 127, [2946958963] = 454, [2948469068] = 306, [2949571091] = 167, [2950350955] = 29,
	[2950594399] = 18, [2951407067] = 46, [2953042598] = 470, [2953256160] = 472, [2953547349] = 465, [2953995229] = 60,
	[2958007211] = 78, [2959318606] = 421, [2960220159] = 302, [2960538977] = 195, [2961096159] = 97, [2961693141] = 391,
	[2961880527] = 217, [2962426990] = 144, [2963951021] = 6, [2965282572] = 335, [2965763078] = 359, [2968473125] = 472,
	[2968786059] = 28, [2970872949] = 18, [2971891877] = 275, [2972413883] = 363, [2973339686] = 412, [2975192269] = 348,
	[2975536379] = 263, [2976019091] = 200, [2976794674] = 189, [2977251863] = 154, [2977778431] = 226, [2978414905] = 102,
	[2979594819] = 185, [2980439878] = 8, [2980996006] = 241, [2981203727] = 114, [2981370296] = 196, [2982113531] = 37,
	[2983432667] = 337, [2984162284] = 105, [2984282541] = 290, [2985878444] = 340, [2986042292] = 461, [2986335894] = 161,
	[2986364476] = 399, [2986738074] = 35, [2988807605] = 431, [2989677534] = 397, [2990496874] = 318, [2993720719] = 462,
	[2995203658] = 420, [2998031625] = 267, [2998296137] = 79, [2999230935] = 91, [2999668200] = 397, [3000840161] = 134,
	[3001314922] = 371, [3002942604] = 51, [3004552515] = 53, [3006012439] = 179, [3006827041] = 105, [3007116394] = 247,
	[3007282507] = 178, [3007316467] = 363, [3009045812] = 87, [3009565316] = 221, [3009722153] = 120, [3012317969] = 388,
	[3013027625] = 173, [3013172555] = 185, [3013342660] = 280, [3013548221] = 386, [3015151178] = 196, [3015514442] = 413,
	[3015760521] = 350, [3016047878] = 465, [3017651416] = 390, [3018453750] = 226, [3018971272] = 203, [3021722773] = 449,
	[3022897058] = 195, [3024115167] = 73, [3024750053] = 57, [3026272626] = 43, [3026388913] = 361, [3027200876] = 468,
	[3027864318] = 195, [3028894131] = 275, [3029114268] = 433, [3029139580] = 366, [3030939569] = 384, [3035086169] = 199,
	[3037321566] = 74, [3040647756] = 363, [3041064829] = 112, [3041406548] = 403, [3042831069] = 453, [3044053122] = 192,
	[3045954569] = 378, [3046369027] = 235, [3047726212] = 252, [3048933961] = 454, [3052006778] = 387, [3055318950] = 430,
	[3059393454] = 418, [3061332088] = 227, [3063197157] = 301, [3067208629] = 283, [3067489084] = 250, [3067667004] = 80,
	[3068264838] = 98, [3068267092] = 141, [3068807126] = 190, [3070041236] = 408, [3071806281] = 248, [3073738536] = 88,
	[3073941855] = 299, [3074102831] = 115, [3075860355] = 307, [3077739157] = 445, [3077803418] = 31, [3078551853] = 70,
	[3079021527] = 270, [3080406197] = 80, [3082247116] = 256, [3084225919] = 407, [3084861654] = 314, [3084880197] = 221,
	[3084974600] = 225, [3087679984] = 372, [3089375113] = 414, [3089938982] = 346, [3090659006] = 126, [3091340384] = 327,
	[3091990512] = 348, [3092274527] = 313, [3094193457] = 20, [3094969202] = 374, [3095606990] = 90, [3095624509] = 421,
	[3097464357] = 8, [3099253519] = 415, [3099786905] = 161, [3100374952] = 104, [3102112129] = 248, [3102347821] = 171,
	[3104255994] = 146, [3111857882] = 191, [3114557925] = 9, [3115220207] = 59, [3117229471] = 315, [3119211963] = 345,
	[3120545032] = 67, [3120718235] = 414, [3121154942] = 240, [3122118681] = 26, [3122564007] = 103, [3123027477] = 409,
	[3124526836] = 62, [3125241311] = 290, [3127329510] = 92, [3127706475] = 275, [3127828435] = 243, [3128655142] = 160,
	[3130445652] = 275, [3131110461] = 76, [3132896083] = 119, [3132971157] = 67, [3133076559] = 112, [3133653937] = 387,
	[3134081066] = 377, [3134328291] = 172, [3134710793] = 66, [3136934146] = 14, [3140409844] = 399, [3140616228] = 424,
	[3141697625] = 254, [3143542113] = 24, [3143667785] = 311, [3144090742] = 256, [3144120212] = 310, [3145290719] = 280,
	[3148021855] = 213, [3149370802] = 356, [3150254044] = 28, [3151971362] = 236, [3152337320] = 418, [3152578053] = 86,
	[3153528310] = 209, [3153843025] = 31, [3153975677] = 456, [3154035276] = 242, [3155456837] = 443, [3156310816] = 459,
	[3156665261] = 466, [3158364768] = 316, [3159195230] = 430, [3161156992] = 26, [3162000382] = 430, [3162091160] = 134,
	[3163547154] = 83, [3165893478] = 157, [3166165247] = 432, [3167354783] = 167, [3168180411] = 304, [3168913316] = 347,
	[3170199705] = 421, [3171116789] = 94, [3171474932] = 402, [3172172742] = 120, [3173186201] = 223, [3173303577] = 435,
	[3173439053] = 128, [3173921631] = 334, [3174005559] = 300, [3174045310] = 382, [3175609629] = 173, [3176216647] = 355,
	[3178589696] = 425, [3178969255] = 239, [3180435041] = 97, [3182045787] = 241, [3184744600] = 235, [3184948682] = 200,
	[3185668934] = 386, [3186147984] = 123, [3186269982] = 247, [3186719012] = 441, [3187654548] = 69, [3188157922] = 284,
	[3188198143] = 278, [3188770983] = 82, [3188842098] = 9, [3189108062] = 68, [3189117489] = 345, [3189648440] = 312,
	[3190045045] = 228, [3190734132] = 298, [3191895661] = 203, [3192935795] = 260, [3193174021] = 296, [3195153674] = 371,
	[3198741662] = 169, [3202238590] = 297, [3204033760] = 338, [3204868325] = 145, [3206789064] = 469, [3208018723] = 143,
	[3209383795] = 394, [3211661701] = 174, [3213015458] = 271, [3213700586] = 359, [3214100619] = 114, [3214810280] = 136,
	[3214887103] = 460, [3214908080] = 389, [3215682597] = 118, [3216642708] = 197, [3216745336] = 450, [3216828780] = 94,
	[3217436823] = 2, [3218067001] = 139, [3218403590] = 302, [3218426911] = 333, [3218896556] = 413, [3220182364] = 404,
	[3220756369] = 392, [3220803985] = 385, [3221781811] = 203, [3225953538] = 195, [3228623910] = 264, [3229642674] = 22,
	[3232041020] = 134, [3233407298] = 309, [3233834078] = 208, [3235521738] = 47, [3235538422] = 268, [3235948876] = 178,
	[3236745502] = 395, [3237781622] = 66, [3238052644] = 454, [3240373689] = 112, [3240622044] = 107, [3243538882] = 61,
	[3244809975] = 287, [3246060697] = 419, [3246435570] = 77, [3246723684] = 371, [3248426149] = 250, [3249595094] = 411,
	[3251497926] = 154, [3253433000] = 467, [3255235072] = 314, [3255573392] = 435, [3256085139] = 183, [3256457615] = 71,
	[3256661909] = 367, [3258213031] = 228, [3258233683] = 166, [3259781843] = 282, [3261043431] = 56, [3263639532] = 77,
	[3263755139] = 62, [3263974764] = 349, [3265788690] = 17, [3267314709] = 116, [3267923806] = 270, [3268113331] = 197,
	[3268664174] = 76, [3269361086] = 266, [3269833230] = 23, [3269833490] = 324, [3269891171] = 54, [3271390684] = 239,
	[3271479519] = 249, [3271694680] = 271, [3271830110] = 459, [3273355665] = 199, [3273365725] = 274, [3275723797] = 113,
	[3277169943] = 313, [3277221270] = 84, [3277808353] = 434, [3277870271] = 76, [3278142443] = 89, [3278796444] = 214,
	[3279359132] = 410, [3279706475] = 422, [3279890545] = 394, [3281325121] = 326, [3281539396] = 463, [3282226944] = 393,
	[3282396964] = 105, [3283386686] = 404, [3288264928] = 187, [3288375833] = 426, [3290012212] = 421, [3291881021] = 203,
	[3292771626] = 138, [3293814577] = 372, [3294366581] = 378, [3294926677] = 180, [3297975728] = 32, [3299027316] = 11,
	[3300285335] = 286, [3301783091] = 455, [3302429127] = 406, [3306135803] = 287, [3306786184] = 324, [3309553293] = 359,
	[3310596643] = 318, [3310916752] = 64, [3311084802] = 171, [3311329319] = 33, [3311813508] = 197, [3311882203] = 266,
	[3312764637] = 467, [3313313062] = 1, [3315978186] = 27, [3316161908] = 258, [3316419223] = 121, [3316738814] = 39,
	[3318203173] = 318, [3318337384] = 146, [3322526688] = 395, [3324400529] = 146, [3325812840] = 188, [3326744738] = 430,
	[3327248699] = 48, [3327375032] = 295, [3327867221] = 36, [3331149120] = 448, [3332669128] = 357, [3333442503] = 45,
	[3337123794] = 79, [3337679219] = 359, [3338866774] = 144, [3338902363] = 312, [3338930809] = 112, [3339586018] = 156,
	[3340080201] = 122, [3340316426] = 471, [3341143644] = 144, [3342387280] = 445, [3343330336] = 322, [3343998954] = 138,
	[3345717667] = 79, [3345920198] = 148, [3346544028] = 342, [3346551234] = 168, [3346999344] = 393, [3348504177] = 277,
	[3348965967] = 257, [3351444627] = 163, [3351509608] = 81, [3351967093] = 110, [3352091905] = 137, [3353143239] = 308,
	[3353536561] = 385, [3354383871] = 222, [3354624223] = 248, [3357735270] = 335, [3358137605] = 286, [3358294054] = 70,
	[3359105121] = 24, [3359636668] = 321, [3363155148] = 231, [3364116133] = 414, [3366815174] = 173, [3367049490] = 171,
	[3367162210] = 266, [3369437710] = 117, [3370724234] = 7, [3372135902] = 36, [3372330646] = 290, [3377153125] = 450,
	[3378435595] = 83, [3378625547] = 174, [3379054910] = 287, [3379611071] = 67, [3380620397] = 19, [3380944003] = 119,
	[3381470071] = 320, [3381747510] = 428, [3384582674] = 36, [3384744470] = 405, [3385717104] = 108, [3386528732] = 333,
	[3389008858] = 223, [3390774270] = 32, [3391909990] = 103, [3392782482] = 451, [3393737667] = 321, [3393789157] = 54,
	[3394705723] = 456, [3395258311] = 438, [3396590197] = 59, [3396705324] = 289, [3397701573] = 32, [3400006386] = 317,
	[3401169778] = 267, [3401406951] = 211, [3402923669] = 442, [3403155927] = 364, [3403189102] = 51, [3403441012] = 331,
	[3405285978] = 393, [3405475996] = 176, [3405524881] = 100, [3405819871] = 143, [3406571938] = 411, [3406884493] = 228,
	[3408309727] = 322, [3409038100] = 300, [3409530888] = 179, [3411365293] = 372, [3412056328] = 389, [3415233454] = 344,
	[3415297543] = 72, [3415574867] = 190, [3416712249] = 311, [3418005806] = 85, [3418111819] = 344, [3419636251] = 357,
	[3421791653] = 307, [3422463701] = 397, [3422754813] = 60, [3423509401] = 150, [3423629982] = 243, [3424885071] = 227,
	[3427193117] = 156, [3428686322] = 370, [3429492693] = 403, [3429554631] = 380, [3429690434] = 409, [3430462846] = 128,
	[3431134778] = 187, [3431663409] = 291, [3432188250] = 427, [3433205458] = 162, [3433304153] = 297, [3433929892] = 84,
	[3435043648] = 325, [3435397793] = 307, [3436105744] = 236, [3440273717] = 43, [3440280058] = 78, [3440796033] = 405,
	[3442860540] = 413, [3443776202] = 201, [3444008872] = 129, [3444141373] = 254, [3444528511] = 418, [3444690053] = 141,
	[3445279831] = 391, [3445960721] = 87, [3446346402] = 457, [3446843976] = 368, [3449244687] = 274, [3451826715] = 109,
	[3451922748] = 448, [3454356524] = 463, [3454369177] = 199, [3454771895] = 368, [3454793370] = 245, [3455542855] = 438,
	[3460305662] = 33, [3463559136] = 247, [3463985648] = 170, [3464193585] = 71, [3464379073] = 94, [3471211102] = 335,
	[3471981763] = 471, [3474814024] = 109, [3476605910] = 452, [3478369083] = 219, [3479352969] = 93, [3479868080] = 43,
	[3480560345] = 97, [3480843815] = 458, [3481779644] = 425, [3481801834] = 131, [3482997983] = 147, [3483805162] = 357,
	[3484062043] = 399, [3486263635] = 98, [3486882290] = 248, [3490736690] = 108, [3490798318] = 110, [3492598667] = 188,
	[3492800426] = 453, [3494253057] = 58, [3496060694] = 172, [3497801225] = 29, [3498695252] = 168, [3499340814] = 425,
	[3499572152] = 454, [3499652969] = 95, [3500112259] = 469, [3500379449] = 34, [3500407199] = 225, [3501113940] = 65,
	[3501504985] = 352, [3502365598] = 373, [3502663291] = 77, [3502819604] = 281, [3504597040] = 344, [3505957004] = 399,
	[3507519029] = 68, [3508254627] = 373, [3508419498] = 413, [3508792525] = 116, [3509300075] = 103, [3511661734] = 365,
	[3511696144] = 461, [3511698576] = 458, [3513177111] = 383, [3513947924] = 391, [3515661870] = 372, [3517658820] = 240,
	[3518293960] = 152, [3519228249] = 380, [3521693463] = 20, [3523172593] = 134, [3525481260] = 254, [3526494737] = 185,
	[3526598649] = 375, [3527094197] = 394, [3529546550] = 3, [3533296458] = 319, [3534637002] = 271, [3534712913] = 15,
	[3535664786] = 139, [3536109561] = 309, [3537323423] = 177, [3538321597] = 449, [3538329596] = 247, [3539140613] = 467,
	[3539207563] = 58, [3539825427] = 403, [3540084115] = 145, [3541513470] = 471, [3541976194] = 206, [3542313528] = 29,
	[3542788569] = 1, [3543577048] = 392, [3544513174] = 67, [3544536026] = 69, [3544831968] = 60, [3545382216] = 171,
	[3546650537] = 202, [3549981341] = 49, [3550970058] = 340, [3551239474] = 30, [3554124538] = 5, [3554612638] = 106,
	[3554963074] = 230, [3555315503] = 278, [3557462538] = 191, [3558250162] = 161, [3558357747] = 335, [3558459476] = 295,
	[3558829986] = 439, [3561380432] = 303, [3562539100] = 252, [3563388380] = 57, [3563438855] = 216, [3563497230] = 356,
	[3564607941] = 323, [3564818329] = 238, [3565352824] = 162, [3565475365] = 343, [3566528792] = 384, [3567064025] = 359,
	[3567833790] = 448, [3568318319] = 423, [3568795973] = 15, [3568874700] = 138, [3569296949] = 155, [3569640935] = 265,
	[3570380863] = 14, [3572279437] = 311, [3572605540] = 11, [3572876476] = 347, [3573440136] = 92, [3573692189] = 284,
	[3575186963] = 316, [3575369549] = 179, [3576129453] = 297, [3576782314] = 392, [3577552432] = 1, [3577752730] = 45,
	[3578792801] = 443, [3579054492] = 287, [3583424411] = 387, [3584486144] = 254, [3584665077] = 203, [3585135092] = 164,
	[3586310657] = 165, [3586428904] = 176, [3587150236] = 387, [3588877570] = 54, [3589250985] = 23, [3589812833] = 354,
	[3592493942] = 448, [3592599694] = 164, [3592730126] = 123, [3592945205] = 339, [3593530577] = 333, [3594965647] = 96,
	[3596567990] = 301, [3596993433] = 256, [3597027287] = 288, [3599982771] = 284, [3601232347] = 284, [3603018104] = 217,
	[3604244936] = 70, [3606252569] = 199, [3606500246] = 447, [3607343691] = 187, [3607888757] = 389, [3608678097] = 198,
	[3609295552] = 28, [3613513243] = 117, [3614425970] = 195, [3616207956] = 6, [3616211342] = 183, [3617760249] = 143,
	[3617870773] = 378, [3622695380] = 372, [3625133633] = 347, [3626154537] = 64, [3628765607] = 239, [3629496685] = 86,
	[3630386428] = 330, [3631259064] = 27, [3638457310] = 69, [3638920079] = 25, [3641141594] = 396, [3641290000] = 127,
	[3642360001] = 189, [3643438154] = 309, [3647581995] = 131, [3647803017] = 455, [3648686334] = 383, [3649271415] = 424,
	[3650569630] = 75, [3651032198] = 198, [3651078667] = 369, [3651606052] = 140, [3651728151] = 249, [3652534788] = 336,
	[3652609896] = 170, [3652758493] = 26, [3653154542] = 150, [3653773919] = 78, [3654699611] = 56, [3656320872] = 166,
	[3657230120] = 256, [3657424501] = 259, [3657484321] = 444, [3659481798] = 330, [3660941273] = 177, [3661463215] = 243,
	[3663100371] = 129, [3663450118] = 420, [3664411894] = 464, [3665651567] = 70, [3666591624] = 125, [3667939504] = 111,
	[3669930927] = 367, [3669960319] = 335, [3671797251] = 183, [3673437633] = 452, [3673682209] = 303, [3673996241] = 342,
	[3674980250] = 200, [3676251781] = 77, [3676866092] = 37, [3677753201] = 242, [3679148435] = 86, [3679716424] = 99,
	[3680371900] = 336, [3680651887] = 245, [3680697012] = 410, [3683443238] = 233, [3683637967] = 365, [3684727453] = 177,
	[3686191963] = 304, [3689873005] = 20, [3694050455] = 22, [3695760751] = 49, [3696411029] = 160, [3696616077] = 158,
	[3697026387] = 436, [3697294856] = 469, [3697940337] = 211, [3698266937] = 336, [3700080991] = 84, [3701397318] = 63,
	[3703432216] = 250, [3704012236] = 325, [3704213739] = 144, [3706004420] = 198, [3706884875] = 109, [3707432027] = 413,
	[3709190106] = 150, [3710089860] = 386, [3710179070] = 75, [3710603915] = 221, [3711171280] = 258, [3711388484] = 88,
	[3712491497] = 314, [3713651969] = 51, [3715004224] = 368, [3715893134] = 417, [3716288197] = 283, [3716457718] = 85,
	[3717081578] = 143, [3717365440] = 456, [3718096042] = 467, [3719118907] = 22, [3720184208] = 117, [3720384323] = 186,
	[3721456319] = 116, [3724289572] = 207, [3725037511] = 341, [3725552984] = 403, [3726541418] = 369, [3727469581] = 137,
	[3727957977] = 17, [3728369909] = 289, [3728669995] = 462, [3729555452] = 301, [3730747840] = 186, [3731289657] = 281,
	[3731321024] = 92, [3731405878] = 466, [3732589494] = 144, [3734745544] = 150, [3735212862] = 125, [3735875590] = 308,
	[3736343693] = 226, [3738326601] = 55, [3739488352] = 209, [3741234584] = 263, [3742155641] = 391, [3742168992] = 243,
	[3742443452] = 25, [3743122172] = 39, [3746360768] = 47, [3746873343] = 219, [3749530101] = 195, [3751427860] = 98,
	[3751787743] = 220, [3751995643] = 41, [3753181243] = 433, [3753474999] = 152, [3753608757] = 314, [3754524459] = 324,
	[3755494846] = 467, [3756213726] = 233, [3758070350] = 439, [3759325323] = 320, [3761584022] = 315, [3761814485] = 255,
	[3762226216] = 246, [3763688408] = 201, [3765297808] = 118, [3766197338] = 189, [3766276793] = 80, [3767874616] = 80,
	[3768113260] = 259, [3768500061] = 429, [3769083378] = 436, [3769368267] = 343, [3769403617] = 438, [3771988995] = 296,
	[3772936830] = 424, [3774555928] = 179, [3776089683] = 128, [3778996051] = 463, [3779081005] = 231, [3780104045] = 274,
	[3781211411] = 422, [3781370149] = 113, [3782765326] = 466, [3782980193] = 172, [3783359140] = 179, [3786963579] = 50,
	[3787606592] = 356, [3787719448] = 309, [3788646987] = 264, [3789416821] = 332, [3790899142] = 361, [3792998802] = 442,
	[3793275219] = 341, [3793287701] = 169, [3794410858] = 355, [3794715192] = 196, [3797674335] = 329, [3799463742] = 212,
	[3799914506] = 304, [3800299665] = 427, [3801016694] = 240, [3801502190] = 407, [3801710797] = 215, [3807213778] = 45,
	[3807651210] = 92, [3808620942] = 244, [3810105489] = 57, [3810126339] = 398, [3810269284] = 313, [3811186085] = 165,
	[3811980627] = 411, [3812001098] = 215, [3814077892] = 398, [3814880716] = 255, [3816227221] = 17, [3816563399] = 267,
	[3817825467] = 340, [3818091545] = 134, [3818530276] = 192, [3819548861] = 7, [3819744161] = 18, [3823617082] = 379,
	[3824124864] = 327, [3825506711] = 163, [3827430759] = 142, [3827550707] = 77, [3827870480] = 299, [3828394640] = 311,
	[3828683340] = 65, [3828965355] = 54, [3829066141] = 89, [3829254492] = 458, [3829382760] = 346, [3831699967] = 65,
	[3832541371] = 257, [3833119522] = 219, [3834713191] = 132, [3836158475] = 444, [3836457343] = 221, [3837495696] = 202,
	[3837734078] = 432, [3838669781] = 124, [3839058960] = 281, [3841028362] = 272, [3842510579] = 86, [3842646717] = 454,
	[3842750311] = 302, [3843920564] = 166, [3844056336] = 39, [3845469760] = 260, [3845492080] = 267, [3846201600] = 466,
	[3847679044] = 203, [3848649442] = 112, [3848746473] = 200, [3849103829] = 400, [3849232473] = 312, [3849340012] = 79,
	[3850763099] = 315, [3851274036] = 75, [3853525564] = 210, [3854972913] = 279, [3855958132] = 354, [3856347497] = 206,
	[3857375270] = 364, [3857481620] = 459, [3858448745] = 126, [3859830621] = 290, [3861243073] = 385, [3861657812] = 53,
	[3862187999] = 284, [3865314192] = 64, [3867297974] = 118, [3868203871] = 453, [3870372375] = 351, [3870456092] = 390,
	[3870663861] = 383, [3870773055] = 243, [3871093065] = 464, [3871847354] = 423, [3873114268] = 53, [3874279644] = 411,
	[3875422752] = 370, [3875511166] = 26, [3875850490] = 162, [3876214595] = 88, [3877685503] = 155, [3878450355] = 230,
	[3878761472] = 408, [3880661870] = 142, [3881935078] = 415, [3882003193] = 273, [3882326547] = 211, [3883323397] = 118,
	[3886668387] = 396, [3887564694] = 306, [3887752473] = 70, [3887900865] = 120, [3888220998] = 367, [3893305933] = 82,
	[3894278447] = 144, [3895502410] = 318, [3896028137] = 249, [3897646916] = 451, [3899576843] = 211, [3900646304] = 37,
	[3900993960] = 202, [3902796523] = 151, [3903778701] = 298, [3903868387] = 309, [3903884537] = 322, [3904209796] = 450,
	[3906019785] = 80, [3908160227] = 20, [3910491790] = 131, [3911886578] = 299, [3911996518] = 403, [3912103464] = 34,
	[3913364193] = 415, [3913747496] = 310, [3913839138] = 241, [3914578848] = 65, [3916520190] = 138, [3916916978] = 45,
	[3917695385] = 14, [3917701627] = 204, [3918987124] = 85, [3919835985] = 417, [3920603630] = 35, [3920860908] = 279,
	[3921376752] = 399, [3922051813] = 233, [3922382397] = 233, [3924591899] = 238, [3924694936] = 334, [3927545161] = 63,
	[3927720784] = 386, [3927976935] = 434, [3928807725] = 210, [3929414962] = 133, [3929627674] = 112, [3930785821] = 427,
	[3932598042] = 236, [3933245482] = 107, [3933271296] = 405, [3934103532] = 83, [3934579294] = 99, [3934836536] = 150,
	[3936737392] = 285, [3937500690] = 112, [3937655740] = 194, [3937757002] = 419, [3938503886] = 94, [3939117903] = 163,
	[3940153006] = 306, [3941473919] = 133, [3941574382] = 381, [3943808221] = 237, [3945397756] = 108, [3945398939] = 87,
	[3946517027] = 56, [3946536659] = 132, [3946627718] = 273, [3947350142] = 175, [3948506689] = 325, [3948649340] = 152,
	[3948835784] = 328, [3949527063] = 22, [3949576241] = 220, [3949670509] = 308, [3950224321] = 241, [3950394247] = 261,
	[3952804936] = 91, [3953041976] = 149, [3954194819] = 376, [3956457110] = 307, [3956712534] = 460, [3959543363] = 257,
	[3960848675] = 230, [3960900123] = 225, [3964868195] = 451, [3966289855] = 274, [3966496109] = 366, [3967510237] = 22,
	[3967663760] = 99, [3968789717] = 84, [3970356274] = 71, [3971449614] = 432, [3973624367] = 401, [3973785306] = 294,
	[3975580113] = 435, [3978272689] = 69, [3979053642] = 182, [3980221751] = 264, [3981448592] = 439, [3983420005] = 124,
	[3984496333] = 307, [3985730814] = 127, [3986020528] = 300, [3986574442] = 383, [3991202429] = 109, [3992049521] = 62,
	[3992137583] = 21, [3992256677] = 291, [3993559979] = 90, [3993614635] = 436, [3993875577] = 367, [3998801319] = 52,
	[3999073108] = 448, [3999397399] = 106, [3999860274] = 46, [4000170599] = 368, [4004643552] = 354, [4004981495] = 361,
	[4005581169] = 350, [4006930437] = 437, [4007780206] = 90, [4008010153] = 389, [4013031963] = 3, [4013422721] = 193,
	[4014508638] = 283, [4014809833] = 268, [4016249592] = 294, [4016506033] = 265, [4016870722] = 194, [4016936349] = 143,
	[4017124134] = 262, [4020389398] = 433, [4021774734] = 160, [4026397888] = 67, [4028264087] = 106, [4034187428] = 73,
	[4034363458] = 270, [4034764778] = 8, [4035807984] = 251, [4036074585] = 180, [4036299969] = 68, [4036878753] = 111,
	[4037079411] = 419, [4039031557] = 178, [4039121956] = 227, [4040050783] = 471, [4041199876] = 140, [4041414323] = 361,
	[4044156018] = 327, [4044279880] = 250, [4045463165] = 21, [4046940086] = 449, [4047205463] = 134, [4048734129] = 370,
	[4048961467] = 52, [4050319437] = 441, [4050672292] = 242, [4051426647] = 129, [4051616254] = 202, [4052450656] = 364,
	[4054063153] = 171, [4054209193] = 404, [4054544524] = 368, [4054561925] = 223, [4055890525] = 48, [4056307012] = 166,
	[4057794397] = 131, [4060316962] = 269, [4062775824] = 466, [4063066572] = 38, [4063087777] = 238, [4063563824] = 38,
	[4064981644] = 17, [4065809820] = 418, [4066042641] = 309, [4067253510] = 401, [4070590894] = 319, [4072219485] = 407,
	[4072405310] = 360, [4074867037] = 183, [4076168289] = 86, [4076577117] = 424, [4076615723] = 66, [4077979835] = 452,
	[4078991404] = 466, [4079606061] = 167, [4080054401] = 353, [4080567911] = 19, [4080898729] = 61, [4081107295] = 39,
	[4081515487] = 210, [4082950760] = 457, [4083579454] = 145, [4083856199] = 438, [4086076272] = 223, [4088251069] = 85,
	[4088638939] = 242, [4088714345] = 390, [4088827723] = 337, [4089060053] = 380, [4089183475] = 279, [4089468407] = 176,
	[4091948122] = 44, [4094474172] = 2, [4096689682] = 437, [4096863380] = 352, [4097030363] = 216, [4097627877] = 230,
	[4099705146] = 329, [4099967099] = 263, [4101530238] = 315, [4103305588] = 212, [4103906982] = 84, [4105434253] = 186,
	[4105584030] = 42, [4106521560] = 186, [4106522790] = 43, [4106657197] = 220, [4107788451] = 471, [4109292533] = 323,
	[4109777003] = 367, [4110306785] = 256, [4110644480] = 151, [4111406539] = 179, [4111538109] = 332, [4112298852] = 27,
	[4112327268] = 245, [4112523771] = 132, [4113072377] = 177, [4113377129] = 334, [4114579224] = 397, [4115128252] = 36,
	[4115642896] = 192, [4115657661] = 221, [4117507375] = 228, [4118422932] = 261, [4118436526] = 438, [4118831076] = 353,
	[4119047898] = 177, [4119321926] = 206, [4119559782] = 103, [4122424858] = 229, [4123587826] = 378, [4127127113] = 146,
	[4128658227] = 174, [4129384219] = 174, [4130605864] = 455, [4131198609] = 288, [4132871024] = 263, [4133165187] = 271,
	[4134822970] = 214, [4137214689] = 325, [4138298989] = 242, [4140632060] = 200, [4140948576] = 417, [4141071041] = 414,
	[4141216281] = 46, [4141506668] = 123, [4141572041] = 222, [4141608309] = 273, [4142079026] = 117, [4142287368] = 300,
	[4142600602] = 80, [4144069623] = 58, [4145268540] = 58, [4145389478] = 318, [4146253646] = 235, [4146696184] = 156,
	[4148211228] = 221, [4148926945] = 374, [4149102979] = 135, [4149108369] = 382, [4150615238] = 292, [4151553215] = 163,
	[4151705880] = 440, [4152195396] = 453, [4154671665] = 355, [4155256177] = 251, [4155548688] = 342, [4155878431] = 44,
	[4155955030] = 273, [4156340825] = 218, [4158134574] = 106, [4158324871] = 253, [4160437485] = 103, [4160543493] = 147,
	[4160759608] = 271, [4161367391] = 315, [4161391131] = 354, [4161982540] = 300, [4162001253] = 2, [4162397119] = 162,
	[4163760315] = 415, [4165693260] = 361, [4169338486] = 58, [4171402261] = 390, [4171514814] = 49, [4171717412] = 384,
	[4172150977] = 449, [4173763752] = 200, [4174924496] = 76, [4176850816] = 206, [4178859314] = 198, [4179917763] = 324,
	[4180590545] = 223, [4181451382] = 279, [4182616518] = 394, [4183272416] = 4, [4183490435] = 292, [4184102950] = 109,
	[4184114435] = 425, [4184532768] = 71, [4184934797] = 116, [4185083420] = 265, [4191832078] = 69, [4192248571] = 258,
	[4193165128] = 435, [4194166038] = 268, [4194437757] = 353, [4195917991] = 234, [4198699924] = 33, [4198743929] = 388,
	[4199195057] = 161, [4199277808] = 223, [4200186237] = 305, [4200206719] = 208, [4200949743] = 111, [4200975453] = 450,
	[4201517171] = 217, [4202077519] = 330, [4202619809] = 446, [4207026266] = 385, [4207082694] = 115, [4207360097] = 366,
	[4207448350] = 352, [4210939591] = 242, [4211828760] = 106, [4212573512] = 164, [4213022474] = 162, [4213536039] = 252,
	[4217799282] = 183, [4218158331] = 237, [4221076296] = 229, [4221715615] = 107, [4222004222] = 254, [4222121400] = 450,
	[4222778035] = 440, [4224784419] = 389, [4226541222] = 105, [4227458923] = 89, [4228677710] = 362, [4229333072] = 74,
	[4231508125] = 358, [4232606725] = 21, [4233071491] = 156, [4233796129] = 308, [4233887556] = 193, [4234125105] = 441,
	[4234749083] = 355, [4235469902] = 182, [4236335593] = 321, [4237999374] = 426, [4238875304] = 30, [4239436774] = 153,
	[4240972449] = 57, [4242317409] = 81, [4242477243] = 205, [4243885554] = 278, [4244034058] = 236, [4245036956] = 274,
	[4245402220] = 437, [4245428428] = 289, [4246047024] = 176, [4246332608] = 248, [4247894803] = 134, [4248238619] = 425,
	[4249882346] = 351, [4250843594] = 75, [4251068962] = 175, [4252282665] = 386, [4253103341] = 344, [4255604911] = 414,
	[4258217246] = 247, [4258680259] = 399, [4258946792] = 56, [4259694191] = 414, [4259839765] = 86, [4260531280] = 352,
	[4260841400] = 335, [4264623560] = 362, [4266609618] = 35, [4268894024] = 125, [4270053009] = 293, [4270068436] = 21,
	[4271226518] = 41, [4274115715] = 20, [4274344233] = 303, [4274862175] = 143, [4275492415] = 328, [4276410443] = 350,
	[4277272201] = 462, [4280734240] = 160, [4281403682] = 81, [4282152913] = 104, [4282160895] = 240, [4283335873] = 451,
	[4283993812] = 465, [4284479679] = 208, [4285472214] = 154, [4286959717] = 62, [4287267472] = 138, [4288145394] = 395,
	[4288745161] = 441, [4289291348] = 373, [4289777965] = 388, [4291705428] = 217, [4292396491] = 143, [4293386001] = 447,
	[4294965476] = 31,
}
-- END other-languages

do
	-- The same sum tools/legacy_lines.py makes: 33 times the sum so far plus the
	-- byte, modulo the largest prime under 2^32, exact in Lua's doubles.
	local function LineHash(line)
		local h = 5381
		for i = 1, #line do h = (h * 33 + line:byte(i)) % 4294967291 end
		return h
	end

	-- The box with each line the addon has in any language as this client reads
	-- it; a line it does not know stays as it is. Never written back: only
	-- compared with this client's sets and examples.
	function RP.InThisLanguage(text)
		local keys, hashes, translated = RP.OTHER_KEYS, RP.OTHER_HASH, ns.L
		return (text:gsub("[^\n]+", function(line)
			local n = hashes[LineHash(line)]
			if n then return translated[keys[n]] end
		end))
	end
end
ns.InThisLanguage = RP.InThisLanguage

-- The pools the examples are drawn from as they read before the lines in
-- RP.LEGACY.reworded were rewritten: a box saved then, by 1.6.4 or by an
-- earlier version, is built from these (RP.Active). Made here, before the
-- thinning below, which thins these as it thins the pools, so that on a
-- client in another language each old line drops out or stays as its
-- translation says, as it did when the box was saved. Never said.
--
-- RP.BETWEEN is the same for RP.LEGACY.reworded2 alone: the box every release
-- from 1.6.5 to the second rewording saved holds `reworded`'s new lines and
-- `reworded2`'s old ones. RP.BEFORE goes back through both, `reworded2` first,
-- so a line reworded twice (a troll's and a goblin's group line) reads as it
-- did in 1.6.4.
do
	local was, since = {}, {}
	for _, pair in ipairs(RP.LEGACY.reworded) do was[pair[1]] = pair[2] end
	for _, pair in ipairs(RP.LEGACY.reworded2) do
		since[pair[1]] = pair[2]
		was[pair[1]] = was[pair[2]] or pair[2]
	end
	-- A copy of a pool with a reworded line in it, or of a table of pools;
	-- any other pool is shared. The thinning replaces the pools inside the
	-- tables that hold them, so those are always copied.
	local function Copy(tbl, map)
		local out, copy = {}, false
		for key, value in pairs(tbl) do
			if type(value) == "table" then
				value, copy = Copy(value, map), true
			elseif map[value] then
				value, copy = map[value], true
			end
			out[key] = value
		end
		return copy and out or tbl
	end
	local function Before(tbl) return Copy(tbl, was) end
	local function Recent(tbl) return Copy(tbl, since) end
	RP.BEFORE, RP.BETWEEN = {}, {}
	for _, name in ipairs({ "RACE", "KIN", "FACTION", "GENERAL", "CLASS", "HISTORY", "PLACE" }) do
		RP.BEFORE[name] = Before(RP[name])
		RP.BETWEEN[name] = Recent(RP[name])
	end
end

-- On a client in another language, a line nobody has translated yet is left
-- out rather than said in English: Locales/Init.lua's English fallback is right
-- for a button and wrong for a line said aloud in /say. A translation is a
-- value its Locales/<code>.lua set on ns.L itself, so rawget finds it where the
-- fallback, in the metatable, is not. Every pool the picking reads is thinned
-- here, at load, so the box's examples, Roll a few and the prompt all keep to
-- the same lines; a pool left with none is taken away and joins no draw (a
-- people with no group lines left speaks its offers, see RP.PoolFor).
-- RP.BEFORE and RP.BETWEEN are thinned the same way; RP.LEGACY only
-- recognises, and is left whole.
--
-- A language with no translations at all keeps its English lines: thinned,
-- the set would have nothing left to say.
do
	local locale, translated = ns.LOCALE, ns.L
	if locale ~= nil and locale ~= "enUS" and locale ~= "enGB"
		and type(translated) == "table" and next(translated) ~= nil then
		-- A list of lines (the first entry is one), or a table of such lists.
		local function Keep(tbl)
			if type(tbl) ~= "table" then return tbl end
			if type(tbl[1]) ~= "string" then
				for key, value in pairs(tbl) do tbl[key] = Keep(value) end
				return tbl
			end
			local kept = {}
			for _, text in ipairs(tbl) do
				local key = ENGLISH[text]
				if key ~= nil and rawget(translated, key) ~= nil then kept[#kept + 1] = text end
			end
			if kept[1] == nil then return nil end
			return kept
		end
		for _, name in ipairs({ "RACE", "KIN", "FACTION", "GENERAL", "CLASS", "SPELL", "TRADE", "GIFT",
			"HISTORY", "PLACE", "TIME", "TARGET", "SAME", "ONTO" }) do
			RP[name] = Keep(RP[name])
		end
		RP.BEFORE = Keep(RP.BEFORE)
		RP.BETWEEN = Keep(RP.BETWEEN)
	end
end

-- How many lines the set can say here, counted once: every pool the pick
-- reads, after the thinning above, so a translated client counts what it
-- will say. What I say names it above the box, which holds only a handful of
-- examples -- a player read those eight lines as all there was (1.5.0).
local lineCount
function RP.Count()
	if lineCount then return lineCount end
	local seen, n = {}, 0
	local function walk(tbl)
		if type(tbl) ~= "table" then return end
		for _, v in pairs(tbl) do
			if type(v) == "string" then
				if not seen[v] then seen[v], n = true, n + 1 end
			else
				walk(v)
			end
		end
	end
	for _, name in ipairs({ "RACE", "KIN", "FACTION", "GENERAL", "CLASS", "SPELL", "TRADE", "GIFT",
		"HISTORY", "PLACE", "TIME", "TARGET", "SAME", "ONTO", "HOME" }) do
		walk(RP[name])
	end
	lineCount = n
	return n
end

-- How much of the draw each pool gets. A pool's share is its weight times
-- the number of its lines that fit, counted up to RP.SPREAD, split evenly
-- between them: a pool of one line is heard a third as often as a full one
-- (a single line said too often grates), and a pool of thirty no more often
-- than one of three, so writing more lines buys variety and never airtime.
--
-- A people's own lines come first, by a long way: a Forsaken should sound
-- Forsaken, a dwarf like a dwarf, in every moment, and above all in a
-- thank-you, the line most players hear. The rare moments made for this very
-- click (somebody met again, a gift to answer, kin, the people's own hour and
-- city) come next, so they are heard when they apply, and of a gift, what it
-- does is said more than its name. The moments that are nearly always true (a
-- place, the hour, the spell, whom you are helping, the speaker's class) weigh
-- little each, since several apply at once, and half that when returning a
-- favour (see RP.Pick). Worked through for full pools: a stranger outdoors at
-- midday hears their people about two times in three, a thank-you for a known
-- spell included (a little less in a busy run, since the memory below skips
-- lines said lately); somebody met a third time hears about it one pick in
-- four. Kin weighs less than the people's lines because a kin pool is small,
-- and a small pool at full weight is heard over and over.
RP.WEIGHT = {
	race = 36, kin = 12, class = 3, faction = 2, general = 1, group = 2,
	spell = 3, trade = 2, gift = 3, history = 17, place = 3, time = 3,
	hour = 8, home = 10, target = 4,
}
RP.SPREAD = 3

-- Lines a language gives a man's voice. The English lines are written for
-- anybody to say ("I'm old, dry and very flammable"); where a language agrees
-- an adjective, a participle or a noun with its speaker, the translation had to
-- pick, and picked the masculine. RP.Pick leaves these out for a woman
-- (UnitSex 3) unless that would leave the pool under RP.SPREAD lines, and says
-- them to everybody else. Keyed by the English line, so a retranslation does not
-- lose its place; esMX reads esES's. Found with tools/audit_i18n_gender.py and
-- read line by line: a line about somebody else, or in a form that does not
-- change with the speaker ("sono felice"), is not one.
RP.MASCULINE = {
	frFR = {
		["A gift for the dead, {name}? Most people bring flowers. Then they run."] = true,
		["Please don't tell the Dark Lady I was nice to somebody, {name}."] = true,
		["Here, {name}. Keep the torches clear of me. I'm old, dry and very flammable."] = true,
		["Hold still, {name}. I've practised on kodo, and they're far less polite."] = true,
		["Thank you, {name}. Somebody had to go first, and I'm glad it was you."] = true,
		["Certainly, {name}. It's this or a lecture on ley lines, and you've been kind."] = true,
		["Thank you, {name}. My aura just brightened. It does that when I'm touched."] = true,
		["Thank you, {name}. I switched to my grateful stance for that. It's rarely used."] = true,
		["Your {gift} softens every blow, {name}. I'm upholstered."] = true,
		["I'll remember your face now, {name}, and I'm terrible with faces. Here."] = true,
		["Take this, {name}. If it goes badly, don't worry. I've died before; it passes."] = true,
	},
	itIT = {
		["A gift for the dead, {name}? Most people bring flowers. Then they run."] = true,
		["Thank ye, {name}. I'd offer me beard as surety, but I'm terrible fond of it."] = true,
		["I was a physician in Lordaeron, {name}. Old habits die harder than I did."] = true,
		["I've outlived everyone I knew, {name}. I'd rather not outlive you. Take this."] = true,
		["Pardon me, {name}. I'm told I lurk. I'm trying to lurk helpfully."] = true,
		["Here, {name}. Keep the torches clear of me. I'm old, dry and very flammable."] = true,
		["Night, {name}. Nobody can tell I'm pale. Or that I'm kind. Take this."] = true,
		["Hold still, {name}. I've practised on kodo, and they're far less polite."] = true,
		["This late, {name}, only trolls and trouble are up. I'm the nice one. Here."] = true,
		["I heard your horn and swung harder, {name}. Nobody had to tell me twice."] = true,
		["I'm half thunderstorm now, {name}. Thank you, and sorry about the rain."] = true,
		-- RP.GIFT's Oath of Light: "degno".
		["An oath, sworn to me? Thank you, {name}. I'll try to be worth keeping."] = true,
	},
	esES = {
		["A gift for the dead, {name}? Most people bring flowers. Then they run."] = true,
	},
	ptBR = {
		["A gift for the dead, {name}? Most people bring flowers. Then they run."] = true,
		["A spare life in my pocket, {name}. I'll try not to spend it. Thank you."] = true,
		["Thank you, {name}. Death can knock now; I've a key to the back door."] = true,
		["Dying's only a delay with your {gift}, {name}. Thank you."] = true,
		["Thank you, {name}. If the worst happens, I'll get up and say it twice."] = true,
		["Let the next thing roar at me, {name}. I'm not running this time. Thank you."] = true,
		["{gift}! One fright, already dealt with, {name}. Thank you."] = true,
		["Thank you, {name}. The next scream I hear won't be mine."] = true,
		["No running in circles for me, {name}. Not the first time, anyway. Thank you."] = true,
		["Thank you, {name}. Lakes, rivers, puddles: all floors now."] = true,
		["Walking on water, {name}. Folk will start a religion. Thank you."] = true,
		["The murlocs will be furious, {name}. Thank you for the shortcut."] = true,
		["Thank you, {name}. I'll be across before it fades. Probably."] = true,
		["Thank you, {name}. Every lurker around just lost their only trick."] = true,
		["Thank you, {name}. Now I can see what your imp gets up to."] = true,
		["My eyes see more than my wits can handle, {name}. Thank you."] = true,
		-- The thanks for a buff for one target at a time (RP.GIFT): "Obrigado".
		["Thank you, {name}. With the earth at my back, I'll stand anything."] = true,
		["Thank you, {name}. I'll try to deserve every pebble."] = true,
		["A Beacon, for me? I'll shine where the hits land, {name}. Thank you."] = true,
		["Thank you, {name}. Every heal of yours has my address on it now."] = true,
		["An oath, sworn to me? Thank you, {name}. I'll try to be worth keeping."] = true,
		["Thank you, {name}. I'll stand in front; you keep your word."] = true,
		["Thank you, {name}. I'll take good care of your trick, and you of mine."] = true,
		["Your own scales, {name}? I'll wear them proudly. Thank you."] = true,
	},
}

-- How many picks back a line is remembered: one said lately gets no share
-- while any other line still fits, so five people helped in a row hear five
-- different lines. By the line as written, so the same joke to another name
-- still counts. Nothing is saved; a reload forgets.
RP.RECENT = 12

do
	-- The reason on a queue entry to the kind of line it wants. A group member
	-- you target keeps the group lines (the reason says "target", inGroup still
	-- says where they stand: see RP.Pick); the target, nearby and anything new
	-- outside your group get an offer.
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

	-- The lines this speaker leaves out: RP.MASCULINE's for a woman, in a
	-- language that has them; nil for everybody else. The sex is the player's
	-- own, which the client always says.
	local function Leaving()
		local code = ns.LOCALE == "esMX" and "esES" or ns.LOCALE
		local list = RP.MASCULINE[code]
		if not list or type(_G.UnitSex) ~= "function" then return nil end
		if ns.plain(_G.UnitSex("player")) ~= 3 then return nil end
		return list
	end

	-- The English a line was read under, for the tests.
	function RP.EnglishOf(text) return ENGLISH[text] end

	-- RP.GIFT's pools, for LeaveOut's floor.
	local GIFT_POOL = {}
	for _, pool in pairs(RP.GIFT) do GIFT_POOL[pool] = true end

	-- Which lines of this pool are left out (text -> true), or nil: none are
	-- flagged, or leaving them out would take the pool below RP.SPREAD lines.
	-- `floor` is how many lines the pool must keep, RP.SPREAD unless said:
	-- the thanks for a gift (RP.GIFT) keep none, since a woman who would hear
	-- only a man's voice in a pool of two is better heard in another pool.
	local function LeaveOut(pool, leaving, floor)
		local out, total, n = nil, 0, 0
		for _, text in ipairs(pool) do
			total = total + 1
			if leaving[ENGLISH[text]] then
				out = out or {}
				out[text] = true
				n = n + 1
			end
		end
		if out and total - n < (floor or RP.SPREAD) then return nil end
		return out
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
	-- otherwise, nil when it is unknown. The queue read their class with their
	-- name; a token still holding them is asked when it did not.
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

	-- The favours no buff of Buffs.lua holds (its favourOnly ids), by every
	-- rank's id: a Soulstone, Fear Ward, Water Walking, and on retail Unending
	-- Breath, which elsewhere is a warlock's buff and found under BUFF_BY_ID
	-- first, as Detect Invisibility now is everywhere it exists (its buff names
	-- these lines as its `gift`). 27239 is Burning Crusade's sixth Soulstone.
	local FAVOUR_KEY = {
		[20707] = "soulstone", [20762] = "soulstone", [20763] = "soulstone",
		[20764] = "soulstone", [20765] = "soulstone", [27239] = "soulstone",
		[6346] = "fearward", [546] = "waterwalking",
		[132] = "detectinvis", [2970] = "detectinvis", [11743] = "detectinvis",
		[5697] = "breath",
	}

	-- The buff key of the spell they gave you ("intellect", "thorns"), for
	-- RP.GIFT, or nil: the debt's spell looked up in Buffs.lua's ids, where
	-- any rank or group version of it is filed, or among the favours above.
	-- Roll a few's stand-in hands its key in as entry.giftKey.
	function RP.GiftKey(entry)
		if type(entry) ~= "table" then return nil end
		local key = entry.giftKey
		if key == nil then
			local id = GiftId(entry)
			local byId = ns.BUFF_BY_ID
			local buff = id and type(byId) == "table" and byId[id]
			key = type(buff) == "table" and buff.key or (id and FAVOUR_KEY[id]) or nil
			-- A buff thanked with another pool's lines (Buffs.lua, gift): Detect
			-- Invisibility for your group, by the lines written for it as a favour.
			if type(buff) == "table" and type(buff.gift) == "string" then key = buff.gift end
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

	-- Whether the player stands in their own people's city (RP.HOME), by the
	-- map the client says they are on: false for a people with none, and
	-- whenever the client will not say.
	function RP.Home(family)
		local maps = family and RP.HOME[family]
		local C_Map = _G.C_Map
		if type(maps) ~= "table" or type(C_Map) ~= "table" then return false end
		local known, id = Read(C_Map.GetBestMapForUnit, "player")
		return known and type(id) == "number" and maps[id] == true
	end

	-- Two lists of lines as one pool, so the moment can add to a pool without
	-- adding to its share of the draw; either alone when the other is missing.
	local function Both(a, b)
		if type(a) == "string" then a = { a } end
		if type(b) ~= "table" or b[1] == nil then return a end
		if type(a) ~= "table" then return b end
		local out = {}
		for i = 1, #a do out[i] = a[i] end
		for i = 1, #b do out[#a + i] = b[i] end
		return out
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
	-- session, for RP.HISTORY: counted from what Core tells the ledger, in memory
	-- only, since "again" is about today's session. A favour counts once when it
	-- arrives and its return completes it; a buff given unasked or asked for
	-- counts once.
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

	-- The lines said lately, oldest first, and how many times each is among
	-- them, by the line as written (RP.RECENT). A line counts once a press
	-- carries it (Prompt/Press.lua, OnPostClick), not when it is picked: the
	-- prompt picks a line for its tooltip, and the press can leave it out.
	local lately, latelyCount = {}, {}
	-- The last line said, as written, for Never say my last line again (What
	-- I say, Options/Say.lua). Kept apart from the memory above, whose length
	-- is RP.RECENT's. Like it, for this session only: a reload forgets it.
	-- false once a press has said one of the player's own lines instead
	-- (RP.SaidOwn): the last line said is then no In character line at all.
	local lastSaid

	function RP.Remember(text)
		if type(text) ~= "string" then return end
		lastSaid = text
		lately[#lately + 1] = text
		latelyCount[text] = (latelyCount[text] or 0) + 1
		local keep = tonumber(RP.RECENT) or 0
		while #lately > keep do
			local old = table.remove(lately, 1)
			local left = latelyCount[old] - 1
			latelyCount[old] = left > 0 and left or nil
		end
	end

	-- The last In character line a press or a whispered thank-you carried this
	-- session, as written ({name} and {buff} still in it), or nil: nil too when
	-- the last line a press carried was one of the player's own (RP.SaidOwn), so
	-- the button never leaves out an older line than the one just heard.
	function RP.Last() return lastSaid or nil end

	-- A press said a line that is no In character line (My own lines, mixed in:
	-- Speech.lua's MixedIn hands it back with no line as written). Called by
	-- Prompt/Press.lua, OnPostClick.
	function RP.SaidOwn() lastSaid = false end

	-- Whether the last line a press carried was one of the player's own.
	function RP.LastWasOwn() return lastSaid == false end

	-- Lines left out (What I say; speech.leftOut): the lines as written that the
	-- pick never chooses, as a set, made again only when the list changes (a
	-- box edit writes a new table, the button adds a row). Repaired at load by
	-- Core's ClampSettings; a row matching no line costs nothing.
	local outList, outCount, outSet = nil, -1, {}
	local function LeftOut()
		local db = ns.db and ns.db.profile
		local list = db and type(db.speech) == "table" and db.speech.leftOut
		if type(list) ~= "table" then return nil end
		if list ~= outList or #list ~= outCount then
			outList, outCount, outSet = list, #list, {}
			for _, text in ipairs(list) do
				if type(text) == "string" then outSet[text] = true end
			end
		end
		if outCount == 0 then return nil end
		return outSet
	end

	-- One line for this person, now, with the channel command in front, and
	-- the line as written for RP.Remember; or nil when nothing fits. Every
	-- pool the moment calls for is gathered, each at its share of the draw
	-- (RP.WEIGHT, RP.SPREAD), and every candidate is measured before the roll
	-- rather than after it, so a long name or spell leaves the shorter lines
	-- to choose from instead of silence. A line said in the last RP.RECENT
	-- gets no share while another still fits, and only then: the memory never
	-- silences the set.
	--
	-- entry.lean (Roll a few's context rows) keeps the draw to the pool of
	-- that name, where it has a line that fits. The queue never sets it.
	function RP.Pick(entry, command, budget)
		if type(entry) ~= "table" or type(command) ~= "string" or type(budget) ~= "number" then
			return nil
		end
		local family, faction, class = RP.Player()
		-- Never a stranger's "for the road" to somebody in your own group.
		local kind = KIND[entry.reason] or (entry.inGroup and "group") or "offer"
		local name = entry.short or entry.name
		-- First name only (Speech.lua, ns.SaidName): the words, never the whisper's address.
		if ns.SaidName then name = ns.SaidName(name) end
		local single = entry.buff and ns.BuffName(entry.buff)
		local key = type(entry.buff) == "table" and entry.buff.key
		-- {buff} is the spell that goes out: a group cast's own name
		-- (GroupBuffs.lua), which the macro casts.
		local buff = entry.groupCast and ns.EntrySpellName and ns.EntrySpellName(entry) or single
		-- A line that names the single spell outright ("Mark of the Wild,
		-- {name}.") would be wrong under Gift of the Wild, so it sits out.
		local notSaying = entry.groupCast and single ~= buff and single or nil
		local gift = kind == "thanks" and RP.Gift(entry) or nil
		-- "Your Fortitude for my Fortitude" is no trade: like with like, by the
		-- single names on both sides or by the buff, since the favour may have
		-- been the group version (a Prayer of Fortitude, filed under the same
		-- key in Buffs.lua), which is named otherwise.
		if gift ~= nil and (gift == single or (key and RP.GiftKey(entry) == key)) then gift = nil end
		-- The same for a buff thanked with another pool's lines (Buffs.lua, gift).
		if gift ~= nil and key and entry.buff.gift and RP.GiftKey(entry) == entry.buff.gift then gift = nil end
		local weight, spread, about = RP.WEIGHT, RP.SPREAD, RP.ABOUT
		local leaving = Leaving()
		-- The lines the player left out (speech.leftOut). A pool all left out
		-- adds nothing, as a pool with nothing that fits; with nothing left in
		-- any pool the pick answers nil, as when no line fits the macro.
		local out = LeftOut()

		local lines, weights, tags, texts, total = {}, {}, {}, {}, 0
		local function add(pool, share, tag)
			if type(pool) == "string" then pool = { pool } end
			if type(pool) ~= "table" or type(share) ~= "number" then return end
			local left = leaving and LeaveOut(pool, leaving, GIFT_POOL[pool] and 0 or nil)
			local first = #lines + 1
			for _, text in ipairs(pool) do
				-- A line that would say an empty name or spell is left out,
				-- not said with a hole in it.
				local usable = type(text) == "string"
					and (name or not text:find("{name}", 1, true))
					and (buff or not text:find("{buff}", 1, true))
					and (gift or not text:find("{gift}", 1, true))
					and not (notSaying and text:find(notSaying, 1, true))
					-- Nor one about a spell of ours (RP.ABOUT) while another goes out.
					and (about[text] == nil or about[text] == key)
					-- Nor a line this language gives a man's voice, for a woman.
					and not (left and left[text])
					-- Nor one the player left out.
					and not (out and out[text])
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
		-- Its lines about how other peoples take to it are the moment's own
		-- too, for somebody who is not kin, away from home.
		local race = RP.RACE[family]
		local kin = RP.IsKin(entry, family)
		local place = RP.Place()
		local home = place == "city" and RP.Home(family)
		local own = race and race[kind]
		if own then
			local outsider = not kin and not home and race.outsider
			add(Both(own, outsider and outsider[kind]), weight.race, "race")
		else
			add(PoolFor(race, kind), weight.race / 2, "race")
		end
		if kin then add((race and race.kin) or RP.KIN, weight.kin, "kin") end
		local side = RP.FACTION[faction]
		if kind == "group" then
			-- The side's offers are for a stranger on a road: said to the
			-- group only while the side has no group lines to say.
			if side.group then
				add(side.group, weight.group, "group")
			else
				add(side.offer, weight.faction, "faction")
			end
			add(RP.GENERAL.group, weight.group, "group")
		else
			add(PoolFor(side, kind), weight.faction, "faction")
			add(RP.GENERAL[kind], weight.general, "general")
		end
		add(PoolFor(RP.CLASS[class], kind), weight.class, "class")

		-- And the moment. Returning a favour, the pools that do not say thank
		-- you -- the spell, the place, the hour, whoever is helped -- weigh
		-- half, so a thank-you mostly sounds like one.
		local aside = kind == "thanks" and 0.5 or 1
		add(key and RP.SPELL[key], weight.spell * aside, "spell")
		if gift then add(RP.TRADE, weight.trade, "trade") end
		-- Filed with the trade lines, so Roll a few's favour row shows either.
		if gift then add(RP.GIFT[RP.GiftKey(entry)], weight.gift, "trade") end
		add(RP.HISTORY[RP.Familiar(entry, kind)], weight.history, "history")
		-- At home, the people's own city in place of anybody's.
		local city = home and race and race.city
		if city then
			add(city, weight.home, "home")
		else
			add(RP.PLACE[place], weight.place * aside, "place")
		end
		local hour = RP.Hour()
		add(RP.TIME[hour], weight.time * aside, "time")
		add(race and hour and race[hour], weight.hour, "hour")
		-- Whoever is helped, and the spell on a class it does little for: a
		-- spell Buffs.lua marks manaOnly on this client, since Mists' Arcane
		-- Brilliance gives a warrior the same crit it gives a mage.
		local helped = RP.Target(entry, class)
		local them = helped == "sameclass" and RP.SAME[class] or RP.TARGET[helped]
		local onto = key and entry.buff.manaOnly and RP.ONTO[key]
		add(Both(them, onto and onto[helped]), weight.target * aside, "target")
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
		return lines[chosen], texts[chosen]
	end

	-- Line n of a pool, or with names (ENGLISH or ENGLISH_NOW), as it read
	-- before translation; a pool of one line as a plain string has only a
	-- line 1. On a client in another language the pools were thinned at load,
	-- so line n there is the nth translated line, and the box shows no line
	-- the set would not say.
	local function Nth(pool, n, names)
		local text = pool
		if type(pool) == "table" then
			text = pool[n]
		elseif n ~= 1 then
			return nil
		end
		if type(text) ~= "string" then return nil end
		return names and names[text] or text
	end

	-- A list of example lines, and put(pool, now, before) to add a pool's
	-- first lines to it: `now` of them for the box as it is, or with older,
	-- `before` of them (none when not given) for the box as beta.10 to 1.5.0
	-- filled it, one line of each of fewer pools. Players still have that one
	-- saved, and it must still read as the untouched set (RP.Active).
	-- Today's box shows each line once, in case two lines were translated
	-- alike; the older box never checked, and is rebuilt as it was. With
	-- english, today's pools (RP) are put back by the key they were read
	-- under first, the older ones (RP.BEFORE) by the last.
	local function Lines(english, older, pools)
		local names = english and (pools == RP and ENGLISH_NOW or ENGLISH)
		local out, seen = {}, {}
		local function put(pool, now, before)
			for i = 1, older and (before or 0) or now do
				local text = Nth(pool, i, names)
				if text == nil then return end
				if older or not seen[text] then
					seen[text] = true
					out[#out + 1] = text
				end
			end
		end
		return out, put
	end

	-- The box begins with a people's lines and its side's: what a thank-you,
	-- an answer and an offer sound like, then a group and kin. The people's
	-- most, since the set speaks mostly as them; beta.10 to 1.5.0 showed a
	-- line of each, the side's offer and the general group line. A people
	-- with no lines of its own (as the Haranir until 1.7.2) has its side's lines in their
	-- place and the general ones in the side's. From pools, RP or RP.BEFORE.
	local function Head(put, family, faction, pools)
		local race, side, general = pools.RACE[family], pools.FACTION[faction] or {}, pools.GENERAL
		if race then
			put(race.thanks, 4, 1) put(race.asked, 3, 1) put(race.offer, 4, 1) put(side.offer, 2, 1)
			put(race.group, 3) put(side.group, 2) put(general.group, 0, 1) put(race.kin or pools.KIN, 1)
		else
			put(side.thanks, 4, 1) put(side.asked, 3, 1) put(side.offer, 4, 1)
			put(general.thanks, 2, 1) put(general.offer, 2, 1) put(side.group, 3) put(general.group, 2)
		end
	end

	-- Then the set noticing the moment: the class's offers, somebody met
	-- again, a dungeon, and the people's own hours where it has them.
	local function Tail(put, class, family, pools)
		put(PoolFor(pools.CLASS[class], "offer"), 2, 1)
		put(pools.HISTORY.again, 1, 1)
		put(pools.PLACE.instance, 1, 1)
		local race = pools.RACE[family]
		if race then put(race.night, 1) put(race.morning, 1) end
	end

	-- What the phrase box shows for a people, side and class: the first few
	-- lines of their pools, always the same ones, so the box can be
	-- recognised as untouched. With english, the same lines as they read
	-- before translation; with older, the box as beta.10 to 1.5.0 filled it;
	-- with pools, from those (RP.BEFORE) rather than from today's.
	local function Examples(family, faction, class, english, older, pools)
		pools = pools or RP
		local out, put = Lines(english, older, pools)
		Head(put, family, faction, pools)
		Tail(put, class, family, pools)
		return table.concat(out, "\n")
	end
	RP.Examples = Examples

	function RP.Text()
		return Examples(RP.Player())
	end

	-- The five lines beta.9 put in the box for a people and side, from
	-- RP.LEGACY, where they are kept as it saved them.
	local function Frozen(family, faction, english)
		local legacy = RP.LEGACY
		local race, side, general = legacy.race[family], legacy.side[faction] or {}, legacy.general
		local five = race and { race[1], race[2], race[3], side[3], general.group }
			or { side[1], side[2], side[3], general.thanks, general.offer }
		local out = {}
		for i = 1, 5 do
			local text = Nth(five[i], 1, english and ENGLISH)
			if text then out[#out + 1] = text end
		end
		return table.concat(out, "\n")
	end

	local FACTIONS = { "Alliance", "Horde", "Neutral" }
	local lastText, lastAnswer

	-- The boxes the examples have been, each as Lines' older and the pools it
	-- is made of: today's; 1.6.5 to the second rewording's, before
	-- RP.LEGACY.reworded2 (RP.BETWEEN); 1.6.4's, today's box of the lines as they
	-- read before both rewordings; and beta.10 to 1.5.0's eight, of those lines
	-- too.
	local TODAY = { false, RP }
	local SAVED = { TODAY, { false, RP.BEFORE }, { true, RP.BEFORE } }
	-- And the box of 1.6.5 to the second rewording (RP.BETWEEN), next to today's.
	SAVED[2], SAVED[3], SAVED[4] = { false, RP.BETWEEN }, SAVED[2], SAVED[3]

	-- Whether text is the examples of any people, side and class, in the
	-- client's language or, with english, as they read before translation;
	-- with older, the boxes earlier versions filled count too: 1.6.4's, the
	-- eight lines of beta.10 to 1.5.0 and beta.9's five. Every class's
	-- examples begin with their people's and side's, so only the classes of a
	-- beginning the text has are tried.
	local function IsExamples(text, english, older)
		local classes = { false }
		for class in pairs(RP.CLASS) do classes[#classes + 1] = class end
		local families = { false }
		for family in pairs(RP.RACE) do families[#families + 1] = family end
		local forms = older and SAVED or { TODAY }
		for _, faction in ipairs(FACTIONS) do
			for _, family in ipairs(families) do
				family = family or nil
				for _, form in ipairs(forms) do
					local out, put = Lines(english, form[1], form[2])
					Head(put, family, faction, form[2])
					local head = table.concat(out, "\n")
					if text:sub(1, #head) == head then
						for _, class in ipairs(classes) do
							if text == Examples(family, faction, class or nil, english, form[1], form[2]) then
								return true
							end
						end
					end
				end
				if older and text == Frozen(family, faction, english) then return true end
			end
		end
		return false
	end

	-- The box with each line that is one of an example's earlier translations
	-- (RP.LEGACY_TRANSLATED) as that line reads now, line by line. A line that
	-- is not one is left as it is, so a box with a line of the player's own in
	-- it still matches no examples.
	local earlier
	local function Modernise(text)
		if earlier == nil then
			earlier = {}
			local byLocale = RP.LEGACY_TRANSLATED
			local set = byLocale and byLocale[ns.LOCALE == "esMX" and "esES" or ns.LOCALE]
			for key, olds in pairs(set or {}) do
				local now = rawget(ns.L, key)
				if now ~= nil then
					for _, old in ipairs(olds) do earlier[old] = now end
				end
			end
		end
		-- A box filled by a client in another language first (RP.OTHER_HASH).
		text = RP.InThisLanguage(text)
		return (text:gsub("[^\n]+", earlier))
	end

	-- Whether "In character" is what speaks. The box is compared with the
	-- examples of every people, side and class, not only this character's: on a
	-- shared profile, the dwarf mage who picked the set has not edited anything
	-- the orc warrior should lose. English examples count too, and the boxes
	-- earlier versions saved (1.6.4's, beta.10 to 1.5.0's eight lines, beta.9's
	-- five), and those with the examples as they were translated then.
	function RP.Active(speech)
		if type(speech) ~= "table" or speech.presetChoice ~= "incharacter" then return false end
		local text = speech.phrases
		if type(text) ~= "string" then return false end
		if text == lastText then return lastAnswer end
		local answer = IsExamples(text, false, true) or IsExamples(text, true, true)
		if not answer then
			local now = Modernise(text)
			answer = now ~= text and IsExamples(now, false, true)
		end
		lastText, lastAnswer = text, answer
		return answer
	end

	-- The load-time repair (Core's ClampSettings) for this set: examples saved in
	-- English, or in an earlier version's shorter box, become this character's
	-- examples as they read now, as the fixed sets' English text does. On an
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
	label = L["In character"],
	summary = L["an in-character line"],
	text = RP.Text,
}
table.insert(ns.PHRASE_SET_ORDER, 2, "incharacter")
