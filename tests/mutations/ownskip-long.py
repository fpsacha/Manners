# Mutations for a right-click on your own buffs that skips for minutes
# (Queue.lua's OwnSkipSeconds and SkipOwn, timing.ownSkipMinutes, the call
# sites in Prompt/Press.lua, Prompt/Supplies.lua and Options/Launcher.lua).
# Each is caught by the scenario in tests/scenarios/ownskip-long.lua that
# names it.

S = "runscenarios.py"

mutate("Queue.lua",
       "\t\tif minutes and minutes > 0 then return minutes * 60 end\n",
       "\t\tif false then return minutes * 60 end\n",
       "ownskip-long: the minutes are never used",
       expect="ownskip-long: a right-click on my own buff keeps it away", script=S)

mutate("Queue.lua",
       "\t\tif family and family.food and family.spells then\n",
       "\t\tif false then\n",
       "ownskip-long: a skipped food skips only the one shown",
       expect="ownskip-long: a skipped food keeps every food away", script=S)

mutate("Prompt/Press.lua",
       "\t\t\tns.SkipOwn(victim, ownKey, ns.OwnSkipSeconds())\n",
       "\t\t\tns.MarkAttempted(victim, ownKey, ns.SkipSeconds())\n",
       "ownskip-long: the prompt's right-click keeps the seconds",
       expect="ownskip-long: a right-click on my own buff keeps it away", script=S)

mutate("Prompt/Press.lua",
       "\t\t\tns.BlockPerson(victim, own and ns.OwnSkipSeconds() or ns.SkipSeconds())\n",
       "\t\t\tns.BlockPerson(victim, ns.SkipSeconds())\n",
       "ownskip-long: ctrl-right-click on myself keeps the seconds",
       expect="ownskip-long: ctrl-right-click on myself", script=S)

mutate("Prompt/Press.lua",
       "\t\t\tns.BlockPerson(victim, own and ns.OwnSkipSeconds() or ns.SkipSeconds())\n",
       "\t\t\tns.BlockPerson(victim, ns.OwnSkipSeconds())\n",
       "ownskip-long: a right-click on another person takes the minutes",
       expect="ownskip-long: a right-click on another person keeps the seconds", script=S)

mutate("Prompt/Supplies.lua",
       "\tns.SkipOwn(current.name, current.buff.key, ns.OwnSkipSeconds())\n",
       "\tns.MarkAttempted(current.name, current.buff.key, ns.SkipSeconds())\n",
       "ownskip-long: the consumables button keeps the seconds",
       expect="ownskip-long: the consumables button keeps it away", script=S)

mutate("Core.lua",
       "\t{ \"timing\", \"ownSkipMinutes\", 0, 240 },\n",
       "\t{ \"timing\", \"ownSkipMinutes\", 0, 100000 },\n",
       "ownskip-long: the minutes are not capped",
       expect="ownskip-long: the setting is placed and capped", script=S)

mutate("Core.lua",
       "\t\t\townSkipMinutes = 0,\n",
       "\t\t\townSkipMinutes = 15,\n",
       "ownskip-long: the minutes are on by default",
       expect="ownskip-long: by default", script=S)
