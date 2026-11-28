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

mutate("Modules/MyBuffs/Supplies.lua",
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

mutate("Core.lua",
       "\t\t\townSkipChoices = false,",
       "\t\t\townSkipChoices = true,",
       "ownskip-long: the skip buttons are on by default",
       expect="ownskip-long: the 15 to 60 minute buttons after a right-click, off by default", script="runscenarios.py")
mutate("Prompt/Press.lua",
       "if db and db.timing and db.timing.ownSkipChoices == true then Prompt:OfferSkipChoices(victim, ownKey) end",
       "if false then Prompt:OfferSkipChoices(victim, ownKey) end",
       "ownskip-long: the skip buttons never come up",
       expect="ownskip-long: the 15 to 60 minute buttons after a right-click, off by default", script="runscenarios.py")
mutate("Prompt/Press.lua",
       "ns.Guard(\"longer skip\", ns.SkipOwn, c.name, c.key, self.minutes * 60)",
       "ns.Guard(\"longer skip\", ns.SkipOwn, c.name, c.key, self.minutes)",
       "ownskip-long: a skip button skips seconds, not minutes",
       expect="ownskip-long: the 15 to 60 minute buttons after a right-click, off by default", script="runscenarios.py")
mutate("Prompt/Press.lua",
       "if choices and choices.shownAt == shownAt then choices.frame:Hide() end",
       "if false then choices.frame:Hide() end",
       "ownskip-long: the skip buttons never go away",
       expect="ownskip-long: the 15 to 60 minute buttons after a right-click, off by default", script="runscenarios.py")
mutate("Prompt/Macro.lua",
       "local at = family and family.rest and ns.caps.conditionalTargeting and \"[@player] \" or \"\"",
       "local at = \"\"",
       "wellrested: the bag waits for a place on the ground",
       expect="wellrested: Classic Era offers it too, laid at your feet in one press", script="runscenarios.py")
