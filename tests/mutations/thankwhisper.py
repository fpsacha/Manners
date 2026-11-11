# Mutations for "Whisper a thank-you to people I can't buff back"
# (prompt.thankWhisper: Favours.lua, NoteFavour and ThankFavour; Speech.lua,
# ns.ThankWhisper). Each is caught by the scenario in
# tests/scenarios/thankwhisper.lua that names it.

S = "runscenarios.py"

mutate("Core.lua",
       "\t\t\tthankWhisper = false,\n",
       "\t\t\tthankWhisper = true,\n",
       "thankwhisper: on by default",
       expect="thankwhisper: off by default, nothing is whispered", script=S)

mutate("Favours.lua",
       "\t\tlocal whisper = db.prompt.thankWhisper == true and owed[seen.name] == nil\n",
       "\t\tlocal whisper = owed[seen.name] == nil\n",
       "thankwhisper: the switch is not read",
       expect="thankwhisper: off by default, nothing is whispered", script=S)

mutate("Favours.lua",
       "\t\tlocal whisper = db.prompt.thankWhisper == true and owed[seen.name] == nil\n",
       "\t\tlocal whisper = db.prompt.thankWhisper == true\n",
       "thankwhisper: a favour you will return is whispered too",
       expect="thankwhisper: somebody you will buff back is not whispered", script=S)

mutate("Favours.lua",
       "\t\tif db.prompt.thankEmote or whisper then\n",
       "\t\tif db.prompt.thankEmote then\n",
       "thankwhisper: the thank is asked only for the emote",
       expect="thankwhisper: a rogue whispers a thank-you to who buffed her", script=S)

mutate("Favours.lua",
       "\t\tlocal whispered = whisper and ns.ThankWhisper and ns.ThankWhisper(seen, unit) == true\n",
       "\t\tlocal whispered = false\n",
       "thankwhisper: the whisper is never sent",
       expect="thankwhisper: a rogue whispers a thank-you to who buffed her", script=S)

mutate("Favours.lua",
       "\t\tif not ok and not whispered then\n",
       "\t\tif not ok then\n",
       "thankwhisper: a whisper alone holds no limit",
       expect="thankwhisper: never in an instance, and once a person at a time", script=S)

mutate("Favours.lua",
       "\t\tif emote then\n\t\t\t-- pcall covers",
       "\t\tif true then\n\t\t\t-- pcall covers",
       "thankwhisper: the emote goes with the whisper alone",
       expect="thankwhisper: a rogue whispers a thank-you to who buffed her", script=S)

mutate("Favours.lua",
       "\t\t\tand (db.sources.owed or ((db.prompt.thankEmote or db.prompt.thankWhisper)\n",
       "\t\t\tand (db.sources.owed or (db.prompt.thankEmote\n",
       "thankwhisper: casters not read for the whisper",
       expect="thankwhisper: whispered with People who buff me off", script=S)

mutate("Speech.lua",
       "\t\tif not pcall(send, text, \"WHISPER\", nil, to) then return false end\n",
       "\t\tif not pcall(send, text, \"SAY\", nil, to) then return false end\n",
       "thankwhisper: said aloud",
       expect="thankwhisper: a rogue whispers a thank-you to who buffed her", script=S)

mutate("Speech.lua",
       "\t\tlocal text = line:sub(#command + 3)\n",
       "\t\tlocal text = line\n",
       "thankwhisper: the command goes out with the line",
       expect="thankwhisper: a rogue whispers a thank-you to who buffed her", script=S)

mutate("Options/Say.lua",
       "local THANKS_ONLY = { speechHeader = true, thankEmote = true, thankEmoteToken = true, thankWhisper = true }\n",
       "local THANKS_ONLY = { speechHeader = true, thankEmote = true, thankEmoteToken = true }\n",
       "thankwhisper: hidden from a class with nothing to give",
       expect="thankwhisper: the switch is on What I say, for a class with nothing to give too", script=S)

mutate("Options/Say.lua",
       "\t\t\t\tset = function(_, v) P().thankWhisper = v end,\n",
       "\t\t\t\tset = function() end,\n",
       "thankwhisper: the switch stores nothing",
       expect="thankwhisper: the switch is on What I say, for a class with nothing to give too", script=S)
