# Mutations for the "In character" phrase set (Phrases.lua and its hooks in
# Core.lua and Options.lua). Each is caught by the scenario in
# tests/scenarios/rp.lua that names it.

# The hook in ns.PickPhrase never taken: the set speaks its examples as lines.
mutate("Speech.lua",
       "\t\tif inCharacter and inCharacter.Active(db.speech) then\n",
       "\t\tif false then\n",
       "in character never asked by PickPhrase",
       expect="rp: a dwarf of the Alliance thanks like one",
       script="runscenarios.py")

# A set that writes its own text, read as a list of lines it does not have.
mutate("Speech.lua",
       "\tif set.text then return set.text() end\n",
       "",
       "a per-character set read as a list",
       expect="rp: load the set, share it, edit it",
       script="runscenarios.py")

# An allied race left out of its people.
mutate("Phrases.lua",
       '\tDwarf = "dwarf", DarkIronDwarf = "dwarf", EarthenDwarf = "dwarf",\n',
       '\tDwarf = "dwarf", EarthenDwarf = "dwarf",\n',
       "dark iron dwarves not dwarves",
       expect="rp: every race speaks with its own people",
       script="runscenarios.py")

# A favour returned with an offer's words.
mutate("Phrases.lua",
       '\tlocal KIND = { owed = "thanks", asked = "asked", group = "group" }\n',
       '\tlocal KIND = { asked = "asked", group = "group" }\n',
       "thanks said as an offer",
       expect="rp: reasons pick their own lines",
       script="runscenarios.py")

# A group member of a people with no group lines hears none of its offers.
mutate("Phrases.lua",
       '\t\treturn tbl[kind] or (kind == "group" and tbl.offer) or nil\n',
       "\t\treturn tbl[kind]\n",
       "no race lines in a group",
       expect="rp: reasons pick their own lines",
       script="runscenarios.py")

# A group member hears the people's offers to a stranger, not its group lines.
mutate("Phrases.lua",
       "\t\tlocal own = race and race[kind]\n",
       '\t\tlocal own = race and race[kind == "group" and "offer" or kind]\n',
       "rp people's group lines never heard",
       expect="rp: reasons pick their own lines",
       script="runscenarios.py")

# ...and a people without them offers to its group at full weight.
mutate("Phrases.lua",
       '\t\t\tadd(PoolFor(race, kind), weight.race / 2, "race")\n',
       '\t\t\tadd(PoolFor(race, kind), weight.race, "race")\n',
       "rp offers to a group at full weight",
       expect="rp: pools are weighed as documented",
       script="runscenarios.py")

# The friendlier group lines never said.
mutate("Phrases.lua",
       '\t\t\tadd(RP.GENERAL.group, weight.group, "group")\n',
       "",
       "no group lines",
       expect="rp: reasons pick their own lines",
       script="runscenarios.py")

# The general lines gone outside a group, so a people repeats itself.
mutate("Phrases.lua",
       '\t\t\tadd(RP.GENERAL[kind], weight.general, "general")\n',
       "",
       "no general lines",
       expect="rp: a dwarf of the Alliance thanks like one",
       script="runscenarios.py")

# A people's own lines weighed no more than anybody's.
mutate("Phrases.lua",
       "\trace = 36, kin = 12,",
       "\trace = 1, kin = 12,",
       "race lines not weighted highest",
       expect="rp: a dwarf of the Alliance thanks like one",
       script="runscenarios.py")

# A faction the client would not name taken as it came.
mutate("Phrases.lua",
       '\t\tif faction ~= "Alliance" and faction ~= "Horde" then faction = "Neutral" end\n',
       "",
       "no neutral fallback",
       expect="rp: a pandaren with no faction yet",
       script="runscenarios.py")

# Every line kept whatever the room, so a long name pushes the hand-back off.
mutate("Phrases.lua",
       '\t\t\t\t\tif said ~= "" and #line <= budget then\n',
       '\t\t\t\t\tif said ~= "" then\n',
       "in character lines not measured",
       expect="rp: every line fits the macro with a long name",
       script="runscenarios.py")

# A line built around the spell said with a hole where it would go.
mutate("Phrases.lua",
       '\t\t\t\t\tand (buff or not text:find("{buff}", 1, true))\n',
       "",
       "spell lines said without a spell",
       expect="rp: no hole where a spell name would go",
       script="runscenarios.py")

# Kin never greeted.
mutate("Phrases.lua",
       "\t\tlocal kin = RP.IsKin(entry, family)\n",
       "\t\tlocal kin = false\n",
       "kin never greeted",
       expect="rp: kin is greeted as kin",
       script="runscenarios.py")

# Kin, and a class, read off a token that has moved on to somebody else.
mutate("Phrases.lua",
       "\t\tif not ok or name == nil or name ~= entry.name then return nil end\n",
       "\t\tif not ok then return nil end\n",
       "kin read off a recycled token",
       expect="rp: kin is greeted as kin",
       script="runscenarios.py")

# Only this character's class counts as untouched, so a shared profile's set
# reads as edited on a character of another class.
mutate("Phrases.lua",
       "\t\tfor class in pairs(RP.CLASS) do classes[#classes + 1] = class end\n",
       "",
       "shared profile loses in character",
       expect="rp: load the set, share it, edit it",
       script="runscenarios.py")

# ...and of another people.
mutate("Phrases.lua",
       "\t\tfor family in pairs(RP.RACE) do families[#families + 1] = family end\n",
       "",
       "shared profile loses in character across peoples",
       expect="rp: load the set, share it, edit it",
       script="runscenarios.py")

# The set never listed in the dropdown.
mutate("Phrases.lua",
       'table.insert(ns.PHRASE_SET_ORDER, 2, "incharacter")\n',
       "",
       "in character not listed",
       expect="rp: load the set, share it, edit it",
       script="runscenarios.py")

# Every reason rolled, the favours only or not.
mutate("Phrases.lua",
       "\t\tlocal only = speech and speech.onlyWhenReturning\n",
       "\t\tlocal only = false\n",
       "roll ignores only when returning",
       expect="rp: roll a few rolls a line per reason",
       script="runscenarios.py")

# The box shows the examples the profile was saved with, not this character's.
mutate("Options/Say.lua",
       "\t\t\t\t\tif ns.InCharacter and ns.InCharacter.Active(SP()) then\n"
       "\t\t\t\t\t\treturn ns.PhraseSetText(\"incharacter\")\n",
       "\t\t\t\t\tif false then\n"
       "\t\t\t\t\t\treturn ns.PhraseSetText(\"incharacter\")\n",
       "box shows another character's examples",
       expect="rp: load the set, share it, edit it",
       script="runscenarios.py")

# The dropdown blank on a character sharing the profile.
mutate("Options/Say.lua",
       "\t\t\t\t\tif ns.InCharacter and ns.InCharacter.Active(SP()) then return choice end\n",
       "",
       "dropdown blank on a shared profile",
       expect="rp: load the set, share it, edit it",
       script="runscenarios.py")

# Roll a few rolls the box's examples as though they were the lines.
mutate("Options/Say.lua",
       "\t\t\t\t\t\tns.InCharacter.Roll(L[\"Somebody\"])\n"
       "\t\t\t\t\t\treturn\n",
       "",
       "roll a few ignores in character",
       expect="rp: roll a few rolls a line per reason",
       script="runscenarios.py")

# A stranger's race read without ns.plain: a secret compared and used as a
# key, which throws on the live client inside the macro build.
mutate("Phrases.lua",
       "\t\treturn ns.plain(a), ns.plain(b)\n",
       "\t\treturn a, b\n",
       "secret race read unplained",
       expect="rp: a secret race is not read",
       script="runscenarios.py")

# The set spared the only-when-returning check, as a merge that moved its
# hook above that line would leave it: strangers and the group are spoken to.
mutate("Speech.lua",
       "\t\tif db.speech.onlyWhenReturning and not Returning(entry) then return nil end\n",
       "\t\tif db.speech.onlyWhenReturning and not Returning(entry)"
       " and not ns.InCharacter.Active(db.speech) then return nil end\n",
       "in character ignores only when returning",
       expect="rp: in character keeps to returning favours",
       script="runscenarios.py")

# A cross-realm name said in full.
mutate("Phrases.lua",
       "\t\tlocal name = entry.short or entry.name\n",
       "\t\tlocal name = entry.name\n",
       "in character says the realm",
       expect="rp: a dwarf of the Alliance thanks like one",
       script="runscenarios.py")

# English examples saved before translation count as edited lines.
mutate("Phrases.lua",
       "\t\tlocal answer = IsExamples(text, false, true) or IsExamples(text, true, true)\n",
       "\t\tlocal answer = IsExamples(text, false, true)\n",
       "english examples lose in character",
       expect="rp: english examples still count once the lines are translated",
       script="runscenarios.py")

# The English box never turned into the translated examples.
mutate("Core.lua",
       "\tif ns.InCharacter then ns.InCharacter.Repair(speech) end\n",
       "",
       "in character english box not repaired",
       expect="rp: english examples still count once the lines are translated",
       script="runscenarios.py")

# ---------------------------------------------------------------- the moment

# The speaker's class never heard.
mutate("Phrases.lua",
       '\t\tadd(PoolFor(RP.CLASS[class], kind), weight.class, "class")\n',
       "",
       "rp no class lines",
       expect="rp: each class speaks with its own lines",
       script="runscenarios.py")

# The class read off UnitClass's first return, the display name ("Mage"),
# which no pool is keyed by.
mutate("Phrases.lua",
       '\t\tlocal _, class = Ask(_G.UnitClass, "player")\n',
       '\t\tlocal class = Ask(_G.UnitClass, "player")\n',
       "rp class read as its display name",
       expect="rp: each class speaks with its own lines",
       script="runscenarios.py")

# Nothing said about the spell going out.
mutate("Phrases.lua",
       '\t\tadd(key and RP.SPELL[key], weight.spell * aside, "spell")\n',
       "",
       "rp no spell lines",
       expect="rp: lines about the spell going out",
       script="runscenarios.py")

# The debt forgets which spell they gave.
mutate("Favours.lua",
       '\t\t\tspell = type(seen.key) == "number" and seen.key or nil }\n',
       "\t\t\tspell = nil }\n",
       "rp debt forgets the spell",
       expect="rp: a favour is thanked for by the spell it was",
       script="runscenarios.py")

# A trade line for somebody who never gave anything back.
mutate("Phrases.lua",
       '\t\tlocal gift = kind == "thanks" and RP.Gift(entry) or nil\n',
       "\t\tlocal gift = RP.Gift(entry)\n",
       "rp trade lines for every moment",
       expect="rp: a favour is thanked for by the spell it was",
       script="runscenarios.py")

# "Your Arcane Intellect for my Arcane Intellect."
mutate("Phrases.lua",
       "\t\tif gift ~= nil and (gift == single or (key and RP.GiftKey(entry) == key)) then gift = nil end\n",
       "",
       "rp a spell traded for itself",
       expect="rp: a favour is thanked for by the spell it was",
       script="runscenarios.py")

# The trade lines never joined the draw.
mutate("Phrases.lua",
       '\t\tif gift then add(RP.TRADE, weight.trade, "trade") end\n',
       "",
       "rp no trade lines",
       expect="rp: a favour is thanked for by the spell it was",
       script="runscenarios.py")

# Core never tells the set what happened, so nobody is ever met again.
mutate("Queue.lua",
       '\tif type(heard) == "function" then ns.Guard("in character " .. event, heard, event, ...) end\n',
       "",
       "rp exchanges never heard",
       expect="rp: meeting the same person again",
       script="runscenarios.py")

# Every buff of one favour counted as another meeting.
mutate("Phrases.lua",
       "\t\t\tif not waiting[name] then Count(name, 1) end\n",
       "\t\t\tCount(name, 1)\n",
       "rp one favour counted per buff",
       expect="rp: meeting the same person again",
       script="runscenarios.py")

# A favour returned counted as a second exchange.
mutate("Phrases.lua",
       "\t\t\tif gift or not waiting[a] then Count(a, 1) end\n",
       "\t\t\tCount(a, 1)\n",
       "rp a return counted again",
       expect="rp: meeting the same person again",
       script="runscenarios.py")

# A refused gift still counted.
mutate("Phrases.lua",
       "\t\t\tif undo.gift then Count(a, -1) else waiting[a] = true end\n",
       "",
       "rp a refused gift still counted",
       expect="rp: meeting the same person again",
       script="runscenarios.py")

# A thank-you counts the favour it thanks for a second time.
mutate("Phrases.lua",
       '\t\t\tif not (kind == "thanks" and waiting[name]) then n = n + 1 end\n',
       "\t\t\tn = n + 1\n",
       "rp a thank-you counted twice",
       expect="rp: meeting the same person again",
       script="runscenarios.py")

# Nobody is ever a regular.
mutate("Phrases.lua",
       '\t\tif n >= 4 then return "regular" end\n',
       "",
       "rp no regulars",
       expect="rp: meeting the same person again",
       script="runscenarios.py")

# The lines about meeting again never joined the draw.
mutate("Phrases.lua",
       '\t\tadd(RP.HISTORY[RP.Familiar(entry, kind)], weight.history, "history")\n',
       "",
       "rp no history lines",
       expect="rp: meeting the same person again",
       script="runscenarios.py")

# Nothing said about where this is.
mutate("Phrases.lua",
       '\t\t\tadd(RP.PLACE[place], weight.place * aside, "place")\n',
       "",
       "rp no place lines",
       expect="rp: lines for where you are",
       script="runscenarios.py")

# A scenario read as the wilds.
mutate("Phrases.lua",
       '\t\t\tif what == "pvp" or what == "arena" then return "battle" end\n'
       "\t\t\treturn nil\n",
       '\t\t\tif what == "pvp" or what == "arena" then return "battle" end\n',
       "rp a scenario is the wilds",
       expect="rp: lines for where you are",
       script="runscenarios.py")

# An arena not taken for a battlefield.
mutate("Phrases.lua",
       '\t\t\tif what == "pvp" or what == "arena" then return "battle" end\n',
       '\t\t\tif what == "pvp" then return "battle" end\n',
       "rp an arena is no battlefield",
       expect="rp: lines for where you are",
       script="runscenarios.py")

# A secret answer from the client taken as an answer.
mutate("Phrases.lua",
       "\t\tif secret and (secret(a) or secret(b)) then return false end\n",
       "",
       "rp a secret world read",
       expect="rp: lines for where you are",
       script="runscenarios.py")

# A client with no such question taken as having answered it.
mutate("Phrases.lua",
       '\t\tif type(fn) ~= "function" then return false end\n',
       '\t\tif type(fn) ~= "function" then return true end\n',
       "rp an unknown world guessed",
       expect="rp: lines for where you are",
       script="runscenarios.py")

# Morning starting an hour late, night an hour late and ending one early.
mutate("Phrases.lua",
       '\t\tif hour >= 5 and hour <= 10 then return "morning" end\n',
       '\t\tif hour > 5 and hour <= 10 then return "morning" end\n',
       "rp morning off by one",
       expect="rp: lines for the hour",
       script="runscenarios.py")

mutate("Phrases.lua",
       '\t\tif hour >= 22 or hour <= 4 then return "night" end\n',
       '\t\tif hour > 22 or hour < 4 then return "night" end\n',
       "rp night off by one",
       expect="rp: lines for the hour",
       script="runscenarios.py")

# Nothing said about the hour.
mutate("Phrases.lua",
       '\t\tadd(RP.TIME[hour], weight.time * aside, "time")\n',
       "",
       "rp no time lines",
       expect="rp: lines for the hour",
       script="runscenarios.py")

# Nothing said about the class being helped.
mutate("Phrases.lua",
       '\t\tadd(Both(them, onto and onto[helped]), weight.target * aside, "target")\n',
       "",
       "rp no target lines",
       expect="rp: lines for the class being helped",
       script="runscenarios.py")

# Two mages meeting hear what any two of a kind would.
mutate("Phrases.lua",
       '\t\tlocal them = helped == "sameclass" and RP.SAME[class] or RP.TARGET[helped]\n',
       '\t\tlocal them = RP.TARGET[helped]\n',
       "rp same class not by class",
       expect="rp: lines for the class being helped",
       script="runscenarios.py")

# Two mages meeting, and neither notices.
mutate("Phrases.lua",
       '\t\tif theirs == mine then return "sameclass" end\n',
       "",
       "rp same class not noticed",
       expect="rp: lines for the class being helped",
       script="runscenarios.py")

# Every line of a pool weighed in full, so whoever wrote most is heard most.
mutate("Phrases.lua",
       "\t\t\tlocal each = share * math.min(fits, spread) / fits\n",
       "\t\t\tlocal each = share\n",
       "rp pools weighed per line",
       expect="rp: pools are weighed as documented",
       script="runscenarios.py")

# A lone line heard as often as a full pool.
mutate("Phrases.lua",
       "\t\t\tlocal each = share * math.min(fits, spread) / fits\n",
       "\t\t\tlocal each = share * spread / fits\n",
       "rp a lone line heard as a pool",
       expect="rp: pools are weighed as documented",
       script="runscenarios.py")

# Roll a few's context rows not leaning on their pools.
mutate("Phrases.lua",
       "\t\tlocal lean = entry.lean\n",
       "\t\tlocal lean = nil\n",
       "rp roll does not lean",
       expect="rp: roll a few rolls a line per reason",
       script="runscenarios.py")

# Roll a few without the rows that show the moment.
mutate("Phrases.lua",
       "\t\trows[#rows + 1] = only and AGAIN_OWED or AGAIN\n",
       "",
       "rp roll shows no meeting again",
       expect="rp: roll a few rolls a line per reason",
       script="runscenarios.py")

# The box without the lines that show the moment.
mutate("Phrases.lua",
       "\t\tput(pools.HISTORY.again, 1, 1)\n",
       "",
       "rp box shows no moment",
       expect="rp: the box shows the moment, and beta.9's box still counts",
       script="runscenarios.py")

# A box beta.9 saved counted as the player's own lines.
mutate("Phrases.lua",
       "\t\tlocal answer = IsExamples(text, false, true) or IsExamples(text, true, true)\n",
       "\t\tlocal answer = IsExamples(text, false) or IsExamples(text, true)\n",
       "rp beta.9 box lost",
       expect="rp: the box shows the moment, and beta.9's box still counts",
       script="runscenarios.py")

# ...and left as beta.9 saved it.
mutate("Phrases.lua",
       "\t\tif not RP.Active(speech) or IsExamples(speech.phrases) then return end\n",
       "\t\tif not RP.Active(speech) or IsExamples(speech.phrases, false, true) then return end\n",
       "rp beta.9 box not repaired",
       expect="rp: the box shows the moment, and beta.9's box still counts",
       script="runscenarios.py")

# The same line written into two pools.
mutate("Phrases.lua",
       '\t\tL["You were not prepared, {name}. Now you are."],\n',
       '\t\tL["You were not prepared, {name}. Now you are."],\n'
       '\t\tL["Tell the bear this is for them too, {name}."],\n',
       "rp a line written twice",
       expect="rp: the lines are short and safe in a macro",
       script="runscenarios.py")

# The same words again, punctuated differently.
mutate("Phrases.lua",
       '\t\tL["You were not prepared, {name}. Now you are."],\n',
       '\t\tL["You were not prepared, {name}. Now you are."],\n'
       '\t\tL["Tell the bear: this is for them, too, {name}!"],\n',
       "rp a line written twice in other words",
       expect="rp: the lines are short and safe in a macro",
       script="runscenarios.py")

# A line longer than one breath.
mutate("Phrases.lua",
       '\t\tL["Quick, {name}, before you vanish again."],\n',
       '\t\tL["Quick, {name}, before you vanish again into whatever shadow you came out of this time."],\n',
       "rp a line too long to say",
       expect="rp: the lines are short and safe in a macro",
       script="runscenarios.py")

# A spell's lines filed under a key no buff has.
mutate("Phrases.lua",
       "\tthorns = {\n",
       "\tthorn = {\n",
       "rp spell lines misfiled",
       expect="rp: every moment the set knows has lines",
       script="runscenarios.py")

# A class helped whose lines are filed under a token no class has.
mutate("Phrases.lua",
       "\tEVOKER = {\n",
       "\tEVOKR = {\n",
       "rp target lines misfiled",
       expect="rp: every moment the set knows has lines",
       script="runscenarios.py")

# ------------------------------------------- the gift, the hour, the memory

# Nothing said about what the gift does.
mutate("Phrases.lua",
       '\t\tif gift then add(RP.GIFT[RP.GiftKey(entry)], weight.gift, "trade") end\n',
       "",
       "rp no gift lines",
       expect="rp: a favour is thanked for by the spell it was",
       script="runscenarios.py")

# The gift's key never found from the debt's spell.
mutate("Phrases.lua",
       '\t\t\tkey = type(buff) == "table" and buff.key or (id and FAVOUR_KEY[id]) or nil\n',
       "\t\t\tkey = nil\n",
       "rp gift key never found",
       expect="rp: a favour is thanked for by the spell it was",
       script="runscenarios.py")

# A people's own hour never heard.
mutate("Phrases.lua",
       '\t\tadd(race and hour and race[hour], weight.hour, "hour")\n',
       "",
       "rp no people's hour",
       expect="rp: a people's own hour",
       script="runscenarios.py")

# No memory: the same line twice in a row.
mutate("Phrases.lua",
       "\t\t\t\tif latelyCount[texts[i]] then weights[i] = 0 end\n",
       "",
       "rp lines repeat",
       expect="rp: no line twice in a row",
       script="runscenarios.py")

mutate("Phrases.lua",
       "\t\tlately[#lately + 1] = text\n\t\tlatelyCount[text] = (latelyCount[text] or 0) + 1\n",
       "",
       "rp nothing remembered",
       expect="rp: no line twice in a row",
       script="runscenarios.py")

# The memory silences the set once everything that fits was said lately.
mutate("Phrases.lua",
       "\t\tif fresh > 0 and fresh < total then\n",
       "\t\tif fresh < total then\n",
       "rp memory silences",
       expect="rp: no line twice in a row",
       script="runscenarios.py")

# A line with no translation said in English on a translated client.
mutate("Phrases.lua",
       "\t\t\t\tif key ~= nil and rawget(translated, key) ~= nil then kept[#kept + 1] = text end\n",
       "\t\t\t\tif key ~= nil then kept[#kept + 1] = text end\n",
       "rp untranslated lines said",
       expect="rp: an untranslated line is not said on another language's client",
       script="runscenarios.py")

# The pools never thinned at all.
mutate("Phrases.lua",
       "\t\t\tRP[name] = Keep(RP[name])\n",
       "",
       "rp pools never thinned",
       expect="rp: an untranslated line is not said on another language's client",
       script="runscenarios.py")

# An English client loses the lines no other language has yet.
mutate("Phrases.lua",
       '\tif locale ~= nil and locale ~= "enUS" and locale ~= "enGB"\n',
       "\tif locale ~= nil\n",
       "rp english thinned",
       expect="rp: an untranslated line is not said on another language's client",
       script="runscenarios.py")

# A language with no translations at all left with nothing to say.
mutate("Phrases.lua",
       '\t\tand type(translated) == "table" and next(translated) ~= nil then\n',
       '\t\tand type(translated) == "table" then\n',
       "rp untranslated language silenced",
       expect="rp: an untranslated line is not said on another language's client",
       script="runscenarios.py")

# A pool thinned to nothing still stands, so a group never hears the offers.
mutate("Phrases.lua",
       "\t\t\tif kept[1] == nil then return nil end\n",
       "",
       "rp empty pool kept",
       expect="rp: an untranslated line is not said on another language's client",
       script="runscenarios.py")

# ------------------------------------- whose ears, where, and what for whom

# A thank-you hears the spell, the place, the hour and whoever is helped in
# full, so half of it says no thanks at all.
mutate("Phrases.lua",
       '\t\tlocal aside = kind == "thanks" and 0.5 or 1\n',
       "\t\tlocal aside = 1\n",
       "rp thanks hear the moment in full",
       expect="rp: pools are weighed as documented",
       script="runscenarios.py")

# A party member hears the side's offers to a stranger on a road.
mutate("Phrases.lua",
       '\t\t\tif side.group then\n'
       '\t\t\t\tadd(side.group, weight.group, "group")\n'
       "\t\t\telse\n",
       '\t\t\tdo\n'
       '\t\t\t\tadd(side.group, weight.group, "group")\n'
       "\t\t\tend do\n",
       "rp side offers to the group",
       expect="rp: reasons pick their own lines",
       script="runscenarios.py")

# ...and a side with no group lines says nothing of its own to the group.
mutate("Phrases.lua",
       '\t\t\telse\n'
       '\t\t\t\tadd(side.offer, weight.faction, "faction")\n',
       "",
       "rp side silent to the group",
       expect="rp: reasons pick their own lines",
       script="runscenarios.py")

# A Forsaken tells another Forsaken how the living take to the Forsaken.
mutate("Phrases.lua",
       "\t\t\tlocal outsider = not kin and not home and race.outsider\n",
       "\t\t\tlocal outsider = not home and race.outsider\n",
       "rp outsider lines said to kin",
       expect="rp: lines for outsiders are not said to kin",
       script="runscenarios.py")

# ...and says it in Undercity, where nearly everybody is one.
mutate("Phrases.lua",
       "\t\t\tlocal outsider = not kin and not home and race.outsider\n",
       "\t\t\tlocal outsider = not kin and race.outsider\n",
       "rp outsider lines at home",
       expect="rp: lines for outsiders are not said to kin",
       script="runscenarios.py")

# The lines for outsiders never said at all.
mutate("Phrases.lua",
       "\t\t\tlocal outsider = not kin and not home and race.outsider\n",
       "\t\t\tlocal outsider = nil\n",
       "rp outsider lines never said",
       expect="rp: lines for outsiders are not said to kin",
       script="runscenarios.py")

# Two pools joined as the first alone.
mutate("Phrases.lua",
       "\t\tfor i = 1, #b do out[#a + i] = b[i] end\n",
       "",
       "rp pools joined lose the second",
       expect="rp: a spell on a class it does little for",
       script="runscenarios.py")

# A people's own city never heard.
mutate("Phrases.lua",
       "\t\tlocal city = home and race and race.city\n",
       "\t\tlocal city = nil\n",
       "rp no home city",
       expect="rp: a people's own city",
       script="runscenarios.py")

# Undercity's lines in every city and inn: the lift, in Orgrimmar.
mutate("Phrases.lua",
       '\t\tlocal home = place == "city" and RP.Home(family)\n',
       '\t\tlocal home = place == "city"\n',
       "rp home city in every city",
       expect="rp: a people's own city",
       script="runscenarios.py")

# Undercity's lines next to the warm beds of anybody's city.
mutate("Phrases.lua",
       "\t\telse\n"
       '\t\t\tadd(RP.PLACE[place], weight.place * aside, "place")\n',
       "\t\tend do\n"
       '\t\t\tadd(RP.PLACE[place], weight.place * aside, "place")\n',
       "rp home city beside anybody's",
       expect="rp: a people's own city",
       script="runscenarios.py")

# Undercity known only by Retail's map id, never found on WoW Forever's.
mutate("Phrases.lua",
       "\tforsaken = { [1458] = true, [90] = true },\n",
       "\tforsaken = { [90] = true },\n",
       "rp undercity not found on forever",
       expect="rp: a people's own city",
       script="runscenarios.py")

# The map asked without a guard: a client that throws breaks the pick.
mutate("Phrases.lua",
       '\t\tlocal known, id = Read(C_Map.GetBestMapForUnit, "player")\n',
       '\t\tlocal known, id = true, C_Map.GetBestMapForUnit("player")\n',
       "rp map asked unguarded",
       expect="rp: a people's own city",
       script="runscenarios.py")

# The spell on a class it does little for never heard.
mutate("Phrases.lua",
       "\t\tlocal onto = key and entry.buff.manaOnly and RP.ONTO[key]\n",
       "\t\tlocal onto = nil\n",
       "rp no spell on a class",
       expect="rp: a spell on a class it does little for",
       script="runscenarios.py")

# ...and those lines said in English on a translated client.
mutate("Phrases.lua",
       '\t\t\t"HISTORY", "PLACE", "TIME", "TARGET", "SAME", "ONTO" }) do\n',
       '\t\t\t"HISTORY", "PLACE", "TIME", "TARGET", "SAME" }) do\n',
       "rp spell on a class never thinned",
       expect="an untranslated line for a spell on a class stayed in its pool",
       script="runscenarios.py")
