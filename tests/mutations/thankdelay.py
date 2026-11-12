# Mutations for Wait a moment before thanking (prompt.thankDelay: Favours.lua,
# ThankFavour, Blocked and Paused; Options/Say.lua; the layout, the page's reset,
# /manners debug and the full check-up). Each is caught by the scenario in
# tests/scenarios/thankdelay.lua (or model-window.lua) that names it.

S = "runscenarios.py"

# ------------------------------------------------ the setting
mutate("Core.lua",
       "\t\t\tthankDelay = false,\n",
       "\t\t\tthankDelay = true,\n",
       "thankdelay: on by default",
       expect="thankdelay: off by default, the /thank goes at once", script=S)

mutate("Favours.lua",
       "\t\tif not (prompt and prompt.thankDelay == true and type(timer) == \"table\" and type(timer.After) == \"function\") then\n",
       "\t\tif not (prompt and false and type(timer) == \"table\" and type(timer.After) == \"function\") then\n",
       "thankdelay: the switch is never read",
       expect="thankdelay: on, nothing at once and the /thank after the pause", script=S)

mutate("Favours.lua",
       "\t\tif not (prompt and prompt.thankDelay == true and type(timer) == \"table\" and type(timer.After) == \"function\") then\n",
       "\t\tif not (prompt and prompt.thankDelay == true) then\n",
       "thankdelay: a client without timers is asked for one",
       expect="thankdelay: a client without timers thanks at once", script=S)

# ------------------------------------------------ the pause
mutate("Favours.lua",
       "\tlocal PAUSE_MIN, PAUSE_MAX = 1, 3\n",
       "\tlocal PAUSE_MIN, PAUSE_MAX = 0, 3\n",
       "thankdelay: the pause can be no pause at all",
       expect="thankdelay: the pause is one to three seconds, at random", script=S)

mutate("Favours.lua",
       "\t\ttimer.After(PAUSE_MIN + math.random() * (PAUSE_MAX - PAUSE_MIN), function()\n",
       "\t\ttimer.After(PAUSE_MAX, function()\n",
       "thankdelay: the pause is always the same",
       expect="thankdelay: the pause is one to three seconds, at random", script=S)

# ------------------------------------------------ the rules again at the end of it
mutate("Favours.lua",
       "\t\tlocal why, unit = Blocked(seen, now)\n\t\tif why then return Skip(seen.name, now, why) end\n",
       "\t\tlocal unit = seen.unit\n",
       "thankdelay: nothing asked again at the end of the pause",
       expect="thankdelay: somebody gone by the end of the pause is not thanked", script=S)

mutate("Favours.lua",
       "\t\tlocal why, unit = Blocked(seen, now)\n\t\tif why then return Skip(seen.name, now, why) end\n",
       "\t\tlocal why, unit = Blocked(seen, now)\n\t\tif why then return end\n",
       "thankdelay: a skip at the end of the pause is not written down",
       expect="thankdelay: somebody gone by the end of the pause is not thanked", script=S)

mutate("Favours.lua",
       "\t\temote = emote and db.prompt.thankEmote == true\n",
       "",
       "thankdelay: the /thank switched off during the pause still goes",
       expect="thankdelay: switched off during the pause, nothing goes", script=S)

mutate("Favours.lua",
       "\t\t\tns.Guard(\"thank after a pause\", Paused, seen, emote, whisper)\n",
       "\t\t\tns.Guard(\"thank after a pause\", Paused, seen, emote, false)\n",
       "thankdelay: the whisper is dropped by the pause",
       expect="thankdelay: the whisper waits too", script=S)

# ------------------------------------------------ one at a time
mutate("Favours.lua",
       "\t\tif waiting and now - waiting.at < PAUSE_MAX + 2 then\n",
       "\t\tif false then\n",
       "thankdelay: favours during the pause queue a thank each",
       expect="thankdelay: a burst of favours during the pause is one thank", script=S)

mutate("Favours.lua",
       "\t\tif waiting and now - waiting.at < PAUSE_MAX + 2 then\n",
       "\t\tif waiting then\n",
       "thankdelay: a lost pause holds every thank back",
       expect="thankdelay: a pause whose timer never came back holds nothing for long", script=S)

mutate("Favours.lua",
       "\t\t\treturn Skip(name, now, waiting.name == name and L[\"thanked them a moment ago\"]\n",
       "\t\t\treturn Skip(name, now, waiting.name ~= name and L[\"thanked them a moment ago\"]\n",
       "thankdelay: the skip during the pause gives the wrong reason",
       expect="thankdelay: a burst of favours during the pause is one thank", script=S)

mutate("Favours.lua",
       "\t\t\tif ns.thankLog.waiting == mine then ns.thankLog.waiting = nil end\n",
       "",
       "thankdelay: the thank reads as waiting after it went",
       expect="thankdelay: on, nothing at once and the /thank after the pause", script=S)

# ------------------------------------------------ the options
mutate("Options/Say.lua",
       "\t\t\t\tset = function(_, v) P().thankDelay = v end,\n",
       "\t\t\t\tset = function() end,\n",
       "thankdelay: the switch stores nothing",
       expect="thankdelay: What I say has the switch under the /thank", script=S)

mutate("Options/Say.lua",
       "\t\t\t\tdisabled = function() return not (P().thankEmote or P().thankWhisper) end,\n",
       "\t\t\t\tdisabled = function() return not P().thankEmote end,\n",
       "thankdelay: greyed with the whisper alone on",
       expect="thankdelay: What I say has the switch under the /thank", script=S)

mutate("Options/Say.lua",
       "THANKS_ONLY.thankDelay = true\n",
       "",
       "thankdelay: hidden from a class with nothing to give",
       expect="thankdelay: a class with nothing to give keeps the switch", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t{ \"click.thankDelay\", indent = true },\n",
       "",
       "thankdelay: the switch is not placed on What I say",
       expect="thankdelay: What I say has the switch under the /thank", script=S)

mutate("Options/Advanced.lua",
       "\t\t\"prompt.thankDelay\",\n",
       "",
       "thankdelay: What I say's reset leaves the switch",
       expect="model: the reset puts click back", script=S)

# ------------------------------------------------ what it says
mutate("Commands.lua",
       "\t\tself:Print(\"    \" .. L[\"wait a moment before thanking: |cff00ff00on|r\"])\n",
       "",
       "thankdelay: /manners debug does not say the pause is on",
       expect="thankdelay: on, nothing at once and the /thank after the pause", script=S)

mutate("Commands.lua",
       "\t\tself:Print((\"    \" .. L[\"waiting to thank: |cffffffff%s|r\"]):format(thanks.waiting.name))\n",
       "",
       "thankdelay: /manners debug does not say who waits",
       expect="thankdelay: on, nothing at once and the /thank after the pause", script=S)

mutate("Options/Diagnostics.lua",
       "\t\t\ttostring(db.prompt.thankWhisper), tostring(db.prompt.thankDelay))\n",
       "\t\t\ttostring(db.prompt.thankWhisper), \"?\")\n",
       "thankdelay: the full check-up leaves the pause out",
       expect="thankdelay: on, nothing at once and the /thank after the pause", script=S)
