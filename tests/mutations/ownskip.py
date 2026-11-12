# Mutations for a right-click on your own buff that skips that buff alone,
# ctrl-right-click all of yours (Prompt/Press.lua ShownBuffKey and the
# right-click branch, Prompt/Paint.lua's outcomeBuff, Clicks.lua's
# ShowOutcome, the tooltip in Prompt/Button.lua and the launcher's Not now).
# Each is caught by the scenario in tests/scenarios/ownskip.lua that names it.

S = "runscenarios.py"

mutate("Prompt/Press.lua",
       "\t\tlocal ownKey = own and not ctrl and ShownBuffKey(S, victim) or nil\n",
       "\t\tlocal ownKey = nil\n",
       "ownskip: a right-click skips every buff of yours",
       expect="ownskip: a right-click skips that buff of yours alone", script=S)

mutate("Prompt/Press.lua",
       "\t\tlocal ctrl = IsControlKeyDown and ns.plain(IsControlKeyDown())\n",
       "\t\tlocal ctrl = false\n",
       "ownskip: ctrl changes nothing",
       expect="ctrl-right-click did not skip every buff of yours", script=S)

mutate("Prompt/Press.lua",
       "\tif S.outcomePainted then\n\t\treturn S.outcomePainted == victim and S.outcomeBuff or nil\n\tend\n",
       "",
       "ownskip: under the flash the buff armed underneath is skipped",
       expect="a right-click under the flash skipped", script=S)

mutate("Prompt/Paint.lua",
       "\tS.outcomeBuff = buffKey\n",
       "",
       "ownskip: the flash forgets which buff it is about",
       expect="a right-click under the flash skipped every buff of yours", script=S)

mutate("Clicks.lua",
       "\tShowOutcome(\"cast\", pending.name, nil, pending.buffKey)\n",
       "\tShowOutcome(\"cast\", pending.name)\n",
       "ownskip: a press on yourself flashes with no buff",
       expect="a right-click under the flash skipped every buff of yours", script=S)

mutate("Prompt/Press.lua",
       "\t\t\tlocal buff = ownKey and (ns.FindBuff(ns.caps.class, ownKey) or ns.FindOwnSpell(ownKey))\n",
       "\t\t\tlocal buff = nil\n",
       "ownskip: the skip line names no buff",
       expect="ownskip: a right-click skips that buff of yours alone, and the next comes up: the skip reads", script=S)

mutate("Prompt/Button.lua",
       "\t\t\tor ownBuff and L[\"Right-click to skip this buff",
       "\t\t\tor false and L[\"Right-click to skip this buff",
       "ownskip: the tooltip says a right-click skips you",
       expect="ownskip: the tooltip and Not now agree: the tooltip says", script=S)

mutate("Options/Launcher.lua",
       "\tif entry.reason == \"self\" and entry.buff then\n",
       "\tif false then\n",
       "ownskip: Not now skips every buff of yours",
       expect="Not now skipped every buff of yours", script=S)
