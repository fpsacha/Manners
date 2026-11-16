# Mutations for the bug hunt on why a thank-you never goes out: Quick setup's
# Stay silent and its summary (Options/Start.lua), a pasted settings line
# (Commands.lua, SHARE_KEEP_MINE), /manners debug's favour lines, the warrior's
# whisper (Favours.lua, GoesBack) and a favour during the pause (ThankFavour).
# Each is caught by the scenario in tests/scenarios/thanks-hunt.lua it names.

S = "runscenarios.py"

mutate("Options/Start.lua",
       "\t\t[\"prompt.thankWhisper\"] = false,\n\t} },\n",
       "\t} },\n",
       "thanks-hunt: Stay silent leaves the whisper on",
       expect="thanks-hunt: Stay silent whispers no thank-you", script=S)

mutate("Options/Start.lua",
       "\tif not sp.enabled and whisperLine then\n",
       "\tif false then\n",
       "thanks-hunt: the voice summary says Silent. with the whisper on",
       expect="thanks-hunt: Stay silent whispers no thank-you", script=S)

mutate("Commands.lua",
       "\tSHARE_KEEP_MINE[\"prompt.thankWhisper\"] = \"whisper\"\n",
       "",
       "thanks-hunt: a paste switches the whisper on",
       expect="thanks-hunt: a pasted line does not switch the whispered thank-you on", script=S)

mutate("Commands.lua",
       "\t\tif kept.whisper then\n",
       "\t\tif false then\n",
       "thanks-hunt: the whisper held off by a paste without a word",
       expect="thanks-hunt: a pasted line does not switch the whispered thank-you on", script=S)

mutate("Commands.lua",
       "\t\t\t\tself:Print(\"  \" .. ((db.prompt.thankEmote or db.prompt.thankWhisper)\n",
       "\t\t\t\tself:Print(\"  \" .. ((db.prompt.thankEmote)\n",
       "thanks-hunt: debug says a whisper-only setup is not watching",
       expect="thanks-hunt: debug shows a whisper-only setup watching", script=S)

mutate("Commands.lua",
       "\tif thanks.whispered then\n",
       "\tif false then\n",
       "thanks-hunt: debug never names who was whispered",
       expect="thanks-hunt: debug shows a whisper-only setup watching", script=S)

mutate("Favours.lua",
       "\t\tif not ns.CouldOffer(hasMana, inParty, inGroup, seen.tank, seen.class, seen.name) then return false end\n",
       "",
       "thanks-hunt: a debt kept for if they join counts as going back",
       expect="thanks-hunt: a warrior whispers a stranger who buffs him", script=S)

mutate("Favours.lua",
       "\t\t\tif behind and lastAt == sent then\n",
       "\t\t\tif false then\n",
       "thanks-hunt: a favour during a pause that fails is dropped",
       expect="thanks-hunt: a favour during a pause whose thank never goes is still thanked", script=S)
