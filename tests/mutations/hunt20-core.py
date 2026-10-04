# Mutations for round 20's fixes outside the options window: the prompt with
# nothing castable (Refresh.lua), a colour's alpha and a styling fault on a
# profile switch (Core.lua), ledger stamps from a fast clock (Ledger.lua), the
# death watch, SameName and the chat words (Queue.lua, Requests.lua), the
# spellbook without the deprecated calls and a self-buff the client hides
# (Core.lua), the line in a fight and at somebody just dead (Macro.lua,
# Press.lua), and the client's "Unknown" (Core.lua). Each undoes a fix and is
# caught by the scenario in tests/scenarios/hunt20-core.lua it names.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# The nothing-castable branch hides the panel and leaves the macro armed.
mutate("Prompt/Refresh.lua",
       "\t\t-- Ahead of the off and snooze branches, so they never got to.\n"
       "\t\tself:ApplyTarget(nil)\n",
       "\t\t-- Ahead of the off and snooze branches, so they never got to.\n",
       "hunt20-core: nothing castable leaves the macro armed",
       expect="with nothing castable the panel hid and the button still casts", script=S)

# A colour checked on its first three channels only: an alpha of "x" survives.
mutate("Core.lua",
       "\t\tif type(c) ~= \"table\" or not channel(c[1]) or not channel(c[2]) or not channel(c[3])\n"
       "\t\t\tor (c[4] ~= nil and not channel(c[4])) then\n",
       "\t\tif type(c) ~= \"table\" or not channel(c[1]) or not channel(c[2]) or not channel(c[3]) then\n",
       "hunt20-core: a colour's alpha is not checked",
       expect="which every look does sums on", script=S)

# A colour's numbers kept wherever they are, past 0..1 included.
mutate("Core.lua",
       "\t\t\t\tif c[i] ~= nil then c[i] = math.min(math.max(c[i], 0), 1) end\n",
       "",
       "hunt20-core: a colour's channels are not clamped",
       expect="outside 0..1", script=S)

# The restyle on a profile switch unguarded again.
mutate("Core.lua",
       "\tns.Guard(\"ApplyStyle on profile change\", ns.Prompt.ApplyStyle, ns.Prompt)\n",
       "\tns.Prompt:ApplyStyle()\n",
       "hunt20-core: a profile switch restyles unguarded",
       expect="a styling fault on a profile switch threw out of it", script=S)

# A ledger row stamped in the future kept there.
mutate("Ledger.lua",
       "\tif now and at > now then at = now end\n",
       "",
       "hunt20-core: a ledger row from a fast clock stays in the future",
       expect="from rows a fast clock wrote", script=S)

# ...and its settle with it.
mutate("Ledger.lua",
       "\t\t\tif doneAt and now and doneAt > now then doneAt = now end\n",
       "",
       "hunt20-core: a ledger row settled in the future",
       expect="seconds from now", script=S)

# A row settled before it happened kept so.
mutate("Ledger.lua",
       "\t\t\tif doneAt and doneAt < at then doneAt = at end\n",
       "",
       "hunt20-core: a ledger row settled before it happened",
       expect="seconds before it happened", script=S)

# Everybody lying dead asked about Feign Death on every tick.
mutate("Queue.lua",
       "\t\tif dead == true and down[unit] == nil and feigning and plain(feigning(unit)) == true then\n",
       "\t\tif dead == true and feigning and plain(feigning(unit)) == true then\n",
       "hunt20-core: the death watch asks the dead every tick",
       expect="whether three people already down were feigning", script=S)

# A word in another script compared with every English one.
mutate("Requests.lua",
       "\t\tif not a:find(\"[\\128-\\255]\") or not b:find(\"[\\128-\\255]\") then return false end\n",
       "\t\tif not a:find(\"[\\128-\\255]\") then return false end\n",
       "hunt20-core: a Russian word compared with English ones",
       expect="compared with English words", script=S)

# Every pair of names through strcmputf8i, in a pcall.
mutate("Queue.lua",
       "\tif type(fold) == \"function\" and (a:find(\"[\\128-\\255]\") or b:find(\"[\\128-\\255]\")) then\n",
       "\tif type(fold) == \"function\" then\n",
       "hunt20-core: names in A to Z folded by strcmputf8i",
       expect="strcmputf8i calls on names in A to Z", script=S)

# The spellbook read through the deprecated shims alone.
mutate("Core.lua",
       "\t\tlocal book = C_SpellBook\n\t\tif type(book) == \"table\" then\n",
       "\t\tlocal book = C_SpellBook\n\t\tif false then\n",
       "hunt20-core: the spellbook read through the shims only",
       expect="the mage knows nothing to cast", script=S)

# An empty read of an aura the client hides taken as "not up".
mutate("Core.lua",
       "\t\treturn type(ask) == \"function\" and plain(ask(id)) == true\n",
       "\t\treturn false\n",
       "hunt20-core: a hidden self-buff read as missing",
       expect="was read as missing and offered again", script=S)

# The line kept in the macro armed for a fight.
mutate("Prompt/Macro.lua",
       "\t\tand ns.ChannelOpen()\n\t\tand Prompt.armedForFight ~= true\n",
       "\t\tand ns.ChannelOpen()\n",
       "hunt20-core: the line in the fight's macro",
       expect="says the line on every press", script=S)

# A press on somebody just dead keeps the line.
mutate("Prompt/Press.lua",
       "\tif type(deadOrGhost) ~= \"function\" or ns.plain(deadOrGhost(unit)) ~= false then return true end\n",
       "",
       "hunt20-core: a press on the dead keeps the line",
       # The press's fresh scan now also turns the dead away (1.6.5); with this
       # line gone it is the unread-life check that the line breaks.
       expect="speech-range: no line for somebody whose life the client will not read", script=S)

# The client's "Unknown" filed as a person.
mutate("Core.lua",
       "\tif name == (plain(_G.UNKNOWNOBJECT) or \"Unknown\") then return nil end\n",
       "",
       "hunt20-core: \"Unknown\" is a person",
       expect="a buff from a name the client had not loaded", script=S)
