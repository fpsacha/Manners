# Mutations for what the spoken line says and who reads it: ready-made
# thank-yous only to somebody owed, /party and /raid only in your own group
# and only to its members, and an emote that quotes the addon's lines. Each is
# caught by the scenario in tests/scenarios/speech-lines.lua that names it.

# A ready-made thank-you to anybody, as before.
mutate("Speech.lua",
       "\t\t\tif clean and (returning or not RETURN_ONLY[clean]) then pool[#pool + 1] = clean end\n",
       "\t\t\tif clean then pool[#pool + 1] = clean end\n",
       "ready-made thank-you to a passer-by",
       expect="speech-lines: a ready-made thank-you only to somebody owed",
       script="runscenarios.py")

# Every press taken for a return.
mutate("Speech.lua",
       "\t\treturn entry.reason == \"owed\"\n",
       "\t\treturn true\n",
       "every press a return",
       expect="speech-lines: a ready-made thank-you only to somebody owed",
       script="runscenarios.py")

# The game's instance group counted as your own party or raid.
mutate("Speech.lua",
       "\tif home == nil then return ns.plain(fn()) end\n\treturn ns.plain(fn(home))\n",
       "\treturn ns.plain(fn())\n",
       "instance group counted as a party",
       expect="speech-lines: no party line in an instance group alone",
       script="runscenarios.py")

# A /party line to somebody outside the party.
mutate("Speech.lua",
       "\tif entry.inGroup ~= true then return false end\n",
       "",
       "party line to a stranger",
       expect="speech-lines: no party line to somebody outside the party",
       script="runscenarios.py")

# ...and the macro never says who the line is for.
mutate("Prompt/Macro.lua",
       "\t\tand ns.ChannelOpen(speaker)\n",
       "\t\tand ns.ChannelOpen()\n",
       "channel asked without the person",
       expect="speech-lines: no party line to somebody outside the party",
       script="runscenarios.py")

# /party in a raid taken for the whole raid.
mutate("Speech.lua",
       "\t\t\treturn ns.plain(_G.UnitInSubgroup(entry.unit)) ~= false\n",
       "\t\t\treturn true\n",
       "party line to another subgroup",
       expect="speech-lines: no party line to another subgroup of the raid",
       script="runscenarios.py")

# ...and on a client without UnitInSubgroup, by the roster.
mutate("Speech.lua",
       "\t\treturn theirs == nil or ours == nil or theirs == ours\n",
       "\t\treturn true\n",
       "party line to another subgroup by the roster",
       expect="speech-lines: no party line to another subgroup of the raid",
       script="runscenarios.py")

# A ready-made line said as an action: "Mortimer Cheers, Bram!".
mutate("Speech.lua",
       "\t\t\t\tif quote and SHIPPED[raw] then phrase = quote:format(phrase) end\n",
       "",
       "emote never quotes a set's line",
       expect="speech-lines: an emote quotes the addon's lines",
       script="runscenarios.py")

# A line the player wrote for an emote quoted too: "says, "bows to Bram.""
mutate("Speech.lua",
       "\t\t\t\tif quote and SHIPPED[raw] then phrase = quote:format(phrase) end\n",
       "\t\t\t\tif quote then phrase = quote:format(phrase) end\n",
       "emote quotes the player's own line",
       expect="speech-lines: an emote quotes the addon's lines",
       script="runscenarios.py")

# In character said as an action.
mutate("Speech.lua",
       "\t\t\tif not quote then return inCharacter.Pick(entry, command, budget) end\n",
       "\t\t\tif true then return inCharacter.Pick(entry, command, budget) end\n",
       "in character emote unquoted",
       expect="speech-lines: an emote quotes the addon's lines",
       script="runscenarios.py")

# In character quoted after it was measured, so the frame overruns the macro.
mutate("Speech.lua",
       "inCharacter.Pick(entry, command, budget - #quote:format(\"\"))",
       "inCharacter.Pick(entry, command, budget)",
       "in character emote measured without its frame",
       expect="speech-lines: an emote quotes the addon's lines",
       script="runscenarios.py")

# The tooltip quoting the frame along with the words.
mutate("Speech.lua",
       "\t\t\t\trest = rest:sub(#before + 1, #rest - #after)\n",
       "",
       "tooltip quotes the emote frame",
       expect="speech-lines: an emote quotes the addon's lines",
       script="runscenarios.py")
