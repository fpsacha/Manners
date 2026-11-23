# Mutations for the In character thank-you of a class with nothing to give
# (Options/Start.lua: Quick.THANKS, Quick.VoiceList, the voice summary). Each is
# caught by the scenario in tests/scenarios/thanks-incharacter-class.lua that
# names it.

S = "runscenarios.py"
N = "thanks-incharacter-class: "

mutate("Options/Start.lua",
       "\treturn HasClassBuffs() and Quick.VOICE or Quick.THANKS\n",
       "\treturn Quick.VOICE\n",
       "thanks-incharacter-class: a class with nothing to give gets the voice list of the others",
       expect="a class with nothing to give is offered more than the thanks", script=S)

mutate("Options/Start.lua",
       "\t\tlines = \"incharacter\", set = { [\"prompt.thankWhisper\"] = true }, applyOnly = {} }\n",
       "\t\tlines = \"incharacter\", set = {}, applyOnly = {} }\n",
       "thanks-incharacter-class: In character does not turn the whispered thank-you on",
       expect=N + "a hunter picks In character and is whispered a thank-you", script=S)

mutate("Options/Start.lua",
       "\t\t[\"prompt.thankEmote\"] = true, [\"prompt.thankWhisper\"] = false,\n\t} },\n}\n",
       "\t\t[\"prompt.thankEmote\"] = true, [\"prompt.thankWhisper\"] = false, [\"speech.enabled\"] = false,\n\t} },\n}\n",
       "thanks-incharacter-class: a thank-only choice silences the line said with a cast",
       expect=N + "a hunter's thank leaves the line said with a cast alone", script=S)

mutate("Options/Start.lua",
       "\tif not HasClassBuffs() then\n\t\tlocal emote, whisper = P().thankEmote == true, P().thankWhisper == true\n",
       "\tif false then\n\t\tlocal emote, whisper = P().thankEmote == true, P().thankWhisper == true\n",
       "thanks-incharacter-class: a class with nothing to give is told it says a line when it buffs",
       expect=N + "a hunter picks In character and is whispered a thank-you", script=S)
