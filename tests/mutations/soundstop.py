# Mutations for the sound that will not stop and the preview that will not go
# (Prompt/Prompt.lua, Options/Look.lua, Core.lua's OnEnable, Prompt/Press.lua).
# Each is caught by the scenario in tests/scenarios/soundstop.lua that names it.

S = "runscenarios.py"

mutate("Prompt/Prompt.lua",
       "\tif not data then return end\n\tns.StopPromptSound()\n",
       "\tif not data then return end\n",
       "soundstop: sounds pile up",
       expect="soundstop: a new sound stops the one before it", script=S)

mutate("Prompt/Prompt.lua",
       "\t\t\t\tif playGen == gen and playing == handle then ns.StopPromptSound() end\n",
       "",
       "soundstop: a sound plays to its end",
       expect="soundstop: a sound is cut off after a few seconds", script=S)

mutate("Prompt/Prompt.lua",
       "local SOUND_SECONDS = 4\n",
       "local SOUND_SECONDS = 600\n",
       "soundstop: a sound plays for ten minutes",
       expect="soundstop: a sound is cut off after a few seconds", script=S)

mutate("Options/Look.lua",
       "\t\t\t\t\tif not v then ns.Guard(\"sound stop\", ns.StopPromptSound) end\n",
       "",
       "soundstop: switching the sound off leaves it playing",
       expect="soundstop: switching the sound off stops it", script=S)

mutate("Core.lua",
       "\tns.Guard(\"leftover sound\", ns.StopLeftoverSound)\n",
       "",
       "soundstop: the next session leaves the sound playing",
       expect="soundstop: a sound left playing by the session before is stopped", script=S)

mutate("Prompt/Prompt.lua",
       "\t\tif ns.db and ns.db.char then ns.db.char.soundHandle = handle end\n",
       "",
       "soundstop: the handle is not kept",
       expect="soundstop: a sound left playing by the session before is stopped", script=S)

mutate("Prompt/Press.lua",
       "\tif S == Prompt.state and S.testMode and not InCombatLockdown() then\n",
       "\tif false then\n",
       "soundstop: a click leaves the preview up",
       expect="soundstop: a click on the preview puts it away", script=S)
