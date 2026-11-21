# Mutations for Snooze until I log out and the header's search entries:
# tests/scenarios/menupass-snooze.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts one rule back and
# names the scenario that objects.

S = "runscenarios.py"

mutate("Commands.lua",
       "\tif minutes == ns.SNOOZE_SESSION then\n\t\tsnoozeUntil = math.huge\n",
       "\tif minutes == ns.SNOOZE_SESSION then\n\t\tsnoozeUntil = GetTime() + ns.SNOOZE_DEFAULT * 60\n",
       "menupass-snooze: a session snooze is a fifteen minute one",
       expect="menupass-snooze: Until I log out keeps", script=S)

mutate("Commands.lua",
       "\tif ns.SnoozeSession() then return L[\"you log out\"] end\n",
       "\tif ns.SnoozeSession() then return nil end\n",
       "menupass-snooze: a session snooze has no end to name",
       expect="menupass-snooze: every line says", script=S)

mutate("Options/Launcher.lua",
       "\tif ns.SnoozeLeft() then\n\t\tDivider(snooze)",
       "\tif ends and not ns.SnoozeSession() then\n\t\tDivider(snooze)",
       "menupass-snooze: the launcher cannot stop a session snooze",
       expect="menupass-snooze: the header menu and the launcher", script=S)

mutate("Options/Window/WindowSearch.lua",
       "\tHeaderEntries(out)\n",
       "",
       "menupass-snooze: search skips the header",
       expect="menupass-snooze: search finds Snooze", script=S)
