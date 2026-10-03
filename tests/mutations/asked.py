# Mutations for "people who ask for a buff": which chat messages count as a
# request, from whom, for how long, and what the queue does with one. Each is
# caught by the scenario in tests/scenarios/asked.lua that names it.

# The queue never asks whether somebody asked.
mutate("Queue.lua",
       "\t\tlocal asked = not isOwed and not unasked and ns.AskedFor(unit, full, now, candidates) or nil\n",
       "\t\tlocal asked = nil\n",
       "requests never reach the queue",
       expect="a request in any channel is offered, for a minute",
       script="runscenarios.py")

# One channel never registered, so nothing said there is ever heard.
mutate("Core.lua",
       "\t\t\"CHAT_MSG_WHISPER\",\n",
       "",
       "whispers never registered",
       expect="a request in any channel is offered, for a minute",
       script="runscenarios.py")

# A group made by the group finder talks in instance chat, never heard.
mutate("Core.lua",
       "\t\t\"CHAT_MSG_INSTANCE_CHAT\",\n",
       "",
       "instance chat never registered",
       expect="a request in any channel is offered, for a minute",
       script="runscenarios.py")

# A request that never runs out.
mutate("Requests.lua",
       "\t\treturn request.fight or request.expires > now\n",
       "\t\treturn true\n",
       "requests never expire",
       expect="a request in any channel is offered, for a minute",
       script="runscenarios.py")

# Chat values used as they arrive, secrets included.
mutate("Requests.lua",
       "\t\ttext, sender, guid = plain(text), plain(sender), plain(guid)\n",
       "",
       "secret chat text and senders looked at",
       expect="a secret message or sender is not a request",
       script="runscenarios.py")

# Your own messages taken for somebody else's.
mutate("Requests.lua",
       "\t\tif Mine(sender, guid) ~= false then\n",
       "\t\tif false then\n",
       "own messages heard as requests",
       expect="your own messages are not requests",
       script="runscenarios.py")

# The GUID read from the wrong argument, so the player's own GUID is missed.
mutate("Requests.lua",
       "\tns.Guard(\"request\", ns.NoteRequest, \"PARTY\", text, sender, (select(10, ...)))\n",
       "\tns.Guard(\"request\", ns.NoteRequest, \"PARTY\", text, sender, (select(9, ...)))\n",
       "sender GUID read from the wrong argument",
       expect="your own messages are not requests",
       script="runscenarios.py")

# A buff's name found inside other words: "intro" read as "int".
mutate("Requests.lua",
       "\t\t\t\tif not SameWord(words[i + j - 1], name[j]) then all = false break end\n",
       "\t\t\t\tif not words[i + j - 1]:find(name[j], 1, true) then all = false break end\n",
       "names matched inside other words",
       expect="only whole words and real requests count",
       script="runscenarios.py")

# Any mention of a buff by its full name taken for a request.
mutate("Requests.lua",
       "\t\t\t\tcounts = asking or questioned\n",
       "\t\t\t\tcounts = true\n",
       "every mention is a request",
       expect="only whole words and real requests count",
       script="runscenarios.py")

# "no arcane intellect please" heard as asking.
mutate("Requests.lua",
       "\t\t\tif Among(ASK.never, word) then return nil end\n",
       "\t\t\tif false then return nil end\n",
       "a message saying no still asks",
       expect="only whole words and real requests count",
       script="runscenarios.py")

# A question about a buff taken for a question asking for it.
mutate("Requests.lua",
       "\t\tlocal questioned = marked and not Among(ASK.question, words[1])\n",
       "\t\tlocal questioned = marked\n",
       "questions about a buff ask for it",
       expect="only whole words and real requests count",
       script="runscenarios.py")

# "who has arcane intellect?" read as asking for it.
mutate("Requests.lua",
       "\t\t\t\"who\", \"whos\", \"wants\", \"needs\",\n",
       "",
       "who has it read as asking for it",
       expect="only whole words and real requests count",
       script="runscenarios.py")

# A nickname counted whatever stands beside it: "int the healer pls".
mutate("Requests.lua",
       "\t\t\t\tcounts = small and (asking or questioned)\n",
       "\t\t\t\tcounts = asking or questioned\n",
       "a nickname beside any words asks",
       expect="tactical chat is not a request",
       script="runscenarios.py")

# "buff" counted whatever stands beside it: "rogues need a buff".
mutate("Requests.lua",
       "\t\tif not keys and generic and small and asking then keys = ASK.ANY end\n",
       "\t\tif not keys and generic and asking then keys = ASK.ANY end\n",
       "buff beside any words asks",
       expect="tactical chat is not a request",
       script="runscenarios.py")

# "mark pls" in party chat taken for Mark of the Wild.
mutate("Requests.lua",
       "\t\t\t\tcounts = small and (pleased or only) and not ASK.group[channel]\n",
       "\t\t\t\tcounts = small and (pleased or only)\n",
       "loose words count in group chat",
       expect="tactical chat is not a request",
       script="runscenarios.py")

# The looser words asked for by an opener: "can someone mark?".
mutate("Requests.lua",
       "\t\t\t\tcounts = small and (pleased or only) and not ASK.group[channel]\n",
       "\t\t\t\tcounts = small and (pleased or opens or only) and not ASK.group[channel]\n",
       "loose words asked for by an opener",
       expect="tactical chat is not a request",
       script="runscenarios.py")

# Another mage's "anyone need int?" taken for asking you for it.
mutate("Requests.lua",
       "\t\tif plain(select(2, UnitClass(unit))) == ns.PlayerClass() then return nil end\n",
       "",
       "your own class taken for asking",
       expect="tactical chat is not a request",
       script="runscenarios.py")

# What was asked for ignored: Kings asked, Might offered.
mutate("Requests.lua",
       "\t\t\t\t\tif (request.keys == ASK.ANY or request.keys[buff.key])\n",
       "\t\t\t\t\tif true\n",
       "the asked-for spell ignored",
       expect="a paladin is offered what was asked for, within its pin",
       script="runscenarios.py")

# The spell's own name, as the client spells it, never looked for.
mutate("Requests.lua",
       "\t\t\tif Mark(words, ownWords, covered) then\n",
       "\t\t\tif false then\n",
       "the client's own spell name not heard",
       expect="a request in the client's own language is heard",
       script="runscenarios.py")

# A Chinese name inside a message with no spaces never found.
mutate("Requests.lua",
       "\t\t\t\tand lowered:find(ownWords[1], 1, true) then\n",
       "\t\t\t\tand false then\n",
       "a name without spaces never found",
       expect="a request in the client's own language is heard",
       script="runscenarios.py")

# Words in other scripts compared byte for byte, so case matters.
mutate("Requests.lua",
       "\t\tlocal caseless = _G.strcmputf8i\n\t\tif type(caseless) ~= \"function\" then return false end\n",
       "\t\tdo return false end\n",
       "no case folding outside A to Z",
       expect="a request in the client's own language is heard",
       script="runscenarios.py")

# The word lists looked up byte for byte: "Не" at the start is not "не".
mutate("Requests.lua",
       "\t\t\tif SameWord(word, entry) then return true end\n",
       "",
       "word lists not case-folded",
       expect="a request in the client's own language is heard",
       script="runscenarios.py")

# Anything said in a fight kept for afterwards: interrupt calls offered.
mutate("Requests.lua",
       "\t\tif fighting and channel ~= \"WHISPER\" then\n",
       "\t\tif false then\n",
       "requests made in a fight kept",
       expect="a request in a fight is offered after it",
       script="runscenarios.py")

# A whisper in a fight let go with the rest.
mutate("Requests.lua",
       "\t\tif fighting and channel ~= \"WHISPER\" then\n",
       "\t\tif fighting then\n",
       "whispers in a fight let go",
       expect="a request in a fight is offered after it",
       script="runscenarios.py")

# A request standing when the fight starts let go during it.
mutate("Requests.lua",
       "\t\t\tif Live(request, now) and not request.held then request.fight = true end\n",
       "",
       "requests run out in a fight",
       expect="a request in a fight is offered after it",
       script="runscenarios.py")

# Held through every fight, so chained pulls keep a request alive forever.
mutate("Requests.lua",
       "\t\t\tif Live(request, now) and not request.held then request.fight = true end\n",
       "\t\t\tif Live(request, now) then request.fight = true end\n",
       "requests held through every fight",
       expect="a request in a fight is offered after it",
       script="runscenarios.py")

# Held through the fight, then given no time after it.
mutate("Requests.lua",
       "\t\t\t\trequest.expires = now + ASK_SECONDS\n",
       "",
       "no minute after the fight",
       expect="a request in a fight is offered after it",
       script="runscenarios.py")

# A buff landing does not answer the request.
mutate("Clicks.lua",
       "\tif not unheard then ns.ServeRequest(pending.name, pending.buffKey) end\n",
       "",
       "a request is never served",
       expect="a buff that lands serves the request",
       script="runscenarios.py")

# Serving one person's request serves everybody's.
mutate("Requests.lua",
       "\t\t\tif request.full == name or SameName(request.short, short) then\n",
       "\t\t\tif true then\n",
       "serving one request serves them all",
       expect="a buff that lands serves the request",
       script="runscenarios.py")

# Somebody who asked offered what they already wear, above your group.
mutate("Queue.lua",
       "\t\topts.offerAnyway = isOwed\n",
       "\t\topts.offerAnyway = isOwed or asked ~= nil\n",
       "an asker offered what they have",
       expect="somebody who asked is offered it until they have it",
       script="runscenarios.py")

# A warrior asking for Intellect turned down as having no use for it.
mutate("Queue.lua",
       "\t\topts.relevantOnly = f.relevantOnly and not asked\n",
       "\t\topts.relevantOnly = f.relevantOnly\n",
       "what they asked for judged irrelevant",
       expect="somebody who asked is offered it until they have it",
       script="runscenarios.py")

# The prompt reading "unverified" for somebody who asked.
mutate("Prompt/Paint.lua",
       "\t\tand entry.reason ~= \"asked\" then\n",
       "\t\tthen\n",
       "a request read as unverified",
       expect="somebody who asked is offered it until they have it",
       script="runscenarios.py")

# Every message from one person kept, not the last.
mutate("Requests.lua",
       "\t\t\tif Made(requests[i], guid, short, nil) then table.remove(requests, i) end\n",
       "",
       "asking again adds a request",
       expect="requests are one per person, thirty at most",
       script="runscenarios.py")

# No cap on how many requests are kept.
mutate("Requests.lua",
       "\t\twhile #requests > ASK_KEEP do table.remove(requests, 1) end\n",
       "",
       "requests kept without a cap",
       expect="requests are one per person, thirty at most",
       script="runscenarios.py")

# Matched by name alone: another realm's Anna is the one beside you.
mutate("Requests.lua",
       "\t\tif request.guid and guid then return request.guid == guid end\n",
       "",
       "requests matched by name alone",
       expect="two people with one name are told apart by GUID",
       script="runscenarios.py")

# Heard while Manners is switched off.
mutate("Requests.lua",
       "\t\tif not (db and db.enabled and db.sources.asked) then return end\n",
       "\t\tif not (db and db.sources.asked) then return end\n",
       "heard while switched off",
       expect="nothing is heard while Manners is off",
       script="runscenarios.py")

# Targeting somebody who asked leaves them below every favour.
mutate("Queue.lua",
       "\t\t\tpriority = PRIORITY.target\n",
       "",
       "a targeted asker not moved up",
       expect="a targeted asker comes first",
       script="runscenarios.py")

# A targeted asker read as "your target" rather than as having asked.
mutate("Queue.lua",
       "\t\t\tif not asked then reason = \"target\" end\n",
       "\t\t\treason = \"target\"\n",
       "a targeted asker loses their reason",
       expect="a targeted asker comes first",
       script="runscenarios.py")

# A request ranked below your group.
mutate("Queue.lua",
       "local PRIORITY = { target = 0, owed = 1, asked = 1.5, group = 2, nearby = 3 }\n",
       "local PRIORITY = { target = 0, owed = 1, asked = 2.5, group = 2, nearby = 3 }\n",
       "requests ranked below the group",
       expect="somebody who asked comes after a favour and before your group",
       script="runscenarios.py")

# A standing request still offered once the source is switched off.
mutate("Requests.lua",
       "\t\tif not (db and db.sources.asked) then return nil end\n",
       "",
       "requests offered with the source off",
       expect="somebody who asked comes after a favour and before your group",
       script="runscenarios.py")

# The prompt reading "needs {buff}" for somebody who asked.
mutate("Prompt/Prompt.lua",
       "\tgroup = \"reasonGroup\", nearby = \"reasonNearby\", asked = \"reasonAsked\" }\n",
       "\tgroup = \"reasonGroup\", nearby = \"reasonNearby\" }\n",
       "no wording of its own for a request",
       expect="somebody who asked comes after a favour and before your group",
       script="runscenarios.py")

# A saved wording that is not text kept, to throw on every repaint.
mutate("Core.lua",
       "\t\t\"reasonNearby\", \"reasonAsked\", \"reasonRefresh\", \"reasonUnknown\" }) do\n",
       "\t\t\"reasonNearby\", \"reasonRefresh\", \"reasonUnknown\" }) do\n",
       "a broken request wording kept",
       expect="a broken saved wording for a request is repaired",
       script="runscenarios.py")

# The page saying the prompt will never appear with requests switched on.
# Re-anchored on Shared.lua's NoSources, which the warning now reads.
mutate("Options/Shared.lua",
       "\treturn not (s.owed or s.group or s.asked or (s.strangers and not OnlyReachesGroup())\n",
       "\treturn not (s.owed or s.group or (s.strangers and not OnlyReachesGroup())\n",
       "requests not counted as a source",
       expect="the empty-sources warning counts requests",
       script="runscenarios.py")

# The launcher calling somebody who asked a passer-by.
mutate("Options/Launcher.lua",
       "\tif reason == \"asked\" then return asked end\n",
       "",
       "the launcher reads a request as nearby",
       expect="the launcher says who asked",
       script="runscenarios.py")

# The press's record without the reason: the ledger files a buff somebody
# asked for as one given unprompted, and counts it among the day's gifts.
mutate("Prompt/Press.lua",
       "\t\treason = S.current.reason,\n",
       "",
       "the press forgets the request",
       expect="a buff given to somebody who asked is filed as asked",
       script="runscenarios.py")

# A request for a buff already worn drops the asker from the prompt for its
# minute, whatever else they lack.
mutate("Queue.lua",
       "\t\t\tif asked then\n\t\t\t\tvisit(unit, pointed, true)\n",
       "\t\t\tif false then\n\t\t\t\tvisit(unit, pointed, true)\n",
       "a covered asker offered nothing",
       expect="an asker covered for what they asked is still offered what they lack",
       script="runscenarios.py")

# Walked again and turned down there, but not for good: the passer-by memory
# offers the asker the buff they are wearing, as asked.
mutate("Queue.lua",
       "\t\t\t\tif not seen[full] then rejected[full] = true end\n",
       "",
       "a covered asker left to the passer-by memory",
       expect="somebody who asked is offered it until they have it",
       script="runscenarios.py")
