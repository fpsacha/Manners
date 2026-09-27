# Mutations for "people who ask for a buff": which chat messages count as a
# request, from whom, for how long, and what the queue does with one. Each is
# caught by the scenario in tests/scenarios/asked.lua that names it.

# The queue never asks whether somebody asked.
mutate("Core.lua",
       "\t\tlocal asked = not isOwed and ns.AskedFor(unit, full, now, candidates) or nil\n",
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

# A request that never runs out.
mutate("Core.lua",
       "\t\treturn request.fight or request.expires > now\n",
       "\t\treturn true\n",
       "requests never expire",
       expect="a request in any channel is offered, for a minute",
       script="runscenarios.py")

# Chat values used as they arrive, secrets included.
mutate("Core.lua",
       "\t\ttext, sender, guid = plain(text), plain(sender), plain(guid)\n",
       "",
       "secret chat text and senders looked at",
       expect="a secret message or sender is not a request",
       script="runscenarios.py")

# Your own messages taken for somebody else's.
mutate("Core.lua",
       "\t\tif Mine(sender, guid) ~= false then\n",
       "\t\tif false then\n",
       "own messages heard as requests",
       expect="your own messages are not requests",
       script="runscenarios.py")

# The GUID read from the wrong argument, so the player's own GUID is missed.
mutate("Core.lua",
       "\tns.Guard(\"request\", ns.NoteRequest, \"PARTY\", text, sender, (select(10, ...)))\n",
       "\tns.Guard(\"request\", ns.NoteRequest, \"PARTY\", text, sender, (select(9, ...)))\n",
       "sender GUID read from the wrong argument",
       expect="your own messages are not requests",
       script="runscenarios.py")

# A buff's name found inside other words: "intro" read as "int".
mutate("Core.lua",
       "\t\t\t\tif not SameWord(words[i + j - 1], name[j]) then all = false break end\n",
       "\t\t\t\tif not words[i + j - 1]:find(name[j], 1, true) then all = false break end\n",
       "names matched inside other words",
       expect="only whole words and real requests count",
       script="runscenarios.py")

# Any mention of a buff taken for a request.
mutate("Core.lua",
       "\t\t\tif pleased or opens or only or (strength == \"strict\" and questioned) then\n",
       "\t\t\tif true then\n",
       "every mention is a request",
       expect="only whole words and real requests count",
       script="runscenarios.py")

# "no int pls" heard as asking.
mutate("Core.lua",
       "\t\t\tif ASK.never[word] then return nil end\n",
       "\t\t\tif false then return nil end\n",
       "a message saying no still asks",
       expect="only whole words and real requests count",
       script="runscenarios.py")

# A question about a buff taken for a question asking for it.
mutate("Core.lua",
       "\t\tlocal questioned = not ASK.question[words[1]]\n",
       "\t\tlocal questioned = true\n",
       "questions about a buff ask for it",
       expect="only whole words and real requests count",
       script="runscenarios.py")

# The loose words given the question mark as well: "might be lag?".
mutate("Core.lua",
       "\t\t\tif pleased or opens or only or (strength == \"strict\" and questioned) then\n",
       "\t\t\tif pleased or opens or only or (strength and questioned) then\n",
       "loose words asked for by a question mark",
       expect="a paladin is offered what was asked for, within its pin",
       script="runscenarios.py")

# What was asked for ignored: Kings asked, Might offered.
mutate("Core.lua",
       "\t\t\t\t\tif (request.keys == ASK.ANY or request.keys[buff.key])\n",
       "\t\t\t\t\tif true\n",
       "the asked-for spell ignored",
       expect="a paladin is offered what was asked for, within its pin",
       script="runscenarios.py")

# The spell's own name, as the client spells it, never looked for.
mutate("Core.lua",
       "\t\t\tif Mark(words, ownWords, covered) then\n",
       "\t\t\tif false then\n",
       "the client's own spell name not heard",
       expect="a request in the client's own language is heard",
       script="runscenarios.py")

# A Chinese name inside a message with no spaces never found.
mutate("Core.lua",
       "\t\t\t\tand lowered:find(ownWords[1], 1, true) then\n",
       "\t\t\t\tand false then\n",
       "a name without spaces never found",
       expect="a request in the client's own language is heard",
       script="runscenarios.py")

# Words in other scripts compared byte for byte, so case matters.
mutate("Core.lua",
       "\t\tlocal caseless = _G.strcmputf8i\n\t\tif type(caseless) ~= \"function\" then return false end\n",
       "\t\tdo return false end\n",
       "no case folding outside A to Z",
       expect="a request in the client's own language is heard",
       script="runscenarios.py")

# A request standing when the fight starts let go during it.
mutate("Core.lua",
       "\t\t\tif Live(request, now) then request.fight = true end\n",
       "",
       "requests run out in a fight",
       expect="a request in a fight is offered after it",
       script="runscenarios.py")

# Held through the fight, then given no time after it.
mutate("Core.lua",
       "\t\t\t\trequest.expires = now + ASK_SECONDS\n",
       "",
       "no minute after the fight",
       expect="a request in a fight is offered after it",
       script="runscenarios.py")

# A buff landing does not answer the request.
mutate("Core.lua",
       "\tif not unheard then ns.ServeRequest(pending.name) end\n",
       "",
       "a request is never served",
       expect="a buff that lands serves the request",
       script="runscenarios.py")

# Serving one person's request serves everybody's.
mutate("Core.lua",
       "\t\t\tif request.full == name or SameName(request.short, short) then\n",
       "\t\t\tif true then\n",
       "serving one request serves them all",
       expect="a buff that lands serves the request",
       script="runscenarios.py")

# A request ranked below your group.
mutate("Core.lua",
       "local PRIORITY = { target = 0, owed = 1, asked = 1.5, group = 2, nearby = 3 }\n",
       "local PRIORITY = { target = 0, owed = 1, asked = 2.5, group = 2, nearby = 3 }\n",
       "requests ranked below the group",
       expect="somebody who asked comes after a favour and before your group",
       script="runscenarios.py")

# A standing request still offered once the source is switched off.
mutate("Core.lua",
       "\t\tif not (db and db.sources.asked) then return nil end\n",
       "",
       "requests offered with the source off",
       expect="somebody who asked comes after a favour and before your group",
       script="runscenarios.py")

# The prompt reading "needs {buff}" for somebody who asked.
mutate("Prompt.lua",
       "\tgroup = \"reasonGroup\", nearby = \"reasonNearby\", asked = \"reasonAsked\" }\n",
       "\tgroup = \"reasonGroup\", nearby = \"reasonNearby\" }\n",
       "no wording of its own for a request",
       expect="somebody who asked comes after a favour and before your group",
       script="runscenarios.py")
