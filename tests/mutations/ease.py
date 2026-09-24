# Mutations for the convenience work: the snooze, "Not while mounted", the
# minimap menu, the help and its did-you-mean, and sharing settings as text.
# Each one is caught by the scenario in tests/scenarios/ease.lua it names.
#
# Run by selftest.py with mutate() in scope.

# ------------------------------------------------------------------ snooze

# The prompt's own reading of the snooze taken out: a snooze that hides nothing.
mutate("Prompt.lua",
       "\tif ns.SnoozeLeft(now) then\n\t\tself:ApplyTarget(nil)\n\t\tbutton:Hide()\n",
       "\tif false then\n\t\tself:ApplyTarget(nil)\n\t\tbutton:Hide()\n",
       "a snooze that hides nothing",
       expect="ease: snooze hides the prompt and brings it back on time",
       script="runscenarios.py")

# The scan never noticing a snooze ran out, so its end is never said.
mutate("Core.lua",
       "\tns.EndSnoozeIfDue(now)\n\tns.Prompt:Refresh()\n",
       "\tns.Prompt:Refresh()\n",
       "a snooze that ends without a word",
       expect="ended without a word",
       script="runscenarios.py")

# The end of a snooze said to somebody who switched chat output off.
mutate("Core.lua",
       "\tif addon.db.profile.verbose then addon:Print(SnoozeOverText()) end\n",
       "\taddon:Print(SnoozeOverText())\n",
       "the snooze's end said with chat output off",
       expect="announced with chat output switched off",
       script="runscenarios.py")

# The obvious way to write a snooze: take the button down straight away. In a
# fight that is a protected call the client refuses.
mutate("Core.lua",
       "\tsnoozeUntil = GetTime() + minutes * 60\n"
       "\t-- Refresh decides for itself what it may do in a fight, and in one it\n"
       "\t-- leaves the panel exactly as the fight found it.\n"
       "\tns.Guard(\"snooze\", ns.Prompt.Refresh, ns.Prompt)\n",
       "\tsnoozeUntil = GetTime() + minutes * 60\n"
       "\tns.Prompt:GetButton():Hide()\n",
       "a snooze that hides the button in a fight",
       expect="ease: a snooze started in a fight waits for the fight to end",
       script="runscenarios.py")

# A snooze started in a fight described as though it had already taken effect.
mutate("Core.lua",
       "\telseif InCombatLockdown() then\n\t\t-- Not \"it goes when the fight ends\"",
       "\telseif false then\n\t\t-- Not \"it goes when the fight ends\"",
       "a snooze in a fight silent about the wait",
       expect="did not say it waits for the fight",
       script="runscenarios.py")

# A keypress on the snoozed prompt told "nobody to buff".
mutate("Prompt.lua",
       "\t\t\telseif ns.SnoozeLeft(now) then\n",
       "\t\t\telseif false then\n",
       "a keypress while snoozed saying nobody to buff",
       expect="did not say it is snoozed",
       script="runscenarios.py")

# The launcher's text knowing nothing about a snooze.
mutate("Options.lua",
       "\tif ends then return (\"Manners |cffffd100snoozed until %s|r\"):format(ends) end\n",
       "",
       "a launcher that never mentions the snooze",
       expect="the launcher's text does not say a snooze is running",
       script="runscenarios.py")

# ------------------------------------------------------------------ mounted

mutate("Core.lua",
       "\tif ns.HiddenWhileMounted() then return {} end\n",
       "",
       "Not while mounted that hides nothing",
       expect="ease: not while mounted",
       script="runscenarios.py")

mutate("Core.lua",
       "\t\t\thideMounted = false,\n",
       "\t\t\thideMounted = true,\n",
       "Not while mounted on by default",
       expect="on by default",
       script="runscenarios.py")

mutate("Core.lua",
       "\tboolean(profile.filters, \"hideMounted\", false)\n",
       "",
       "Not while mounted left out of the repair",
       expect="survived the repair",
       script="runscenarios.py")

mutate("Core.lua",
       "\treturn plain(safecall(IsMounted)) == true\n",
       "\treturn plain(IsMounted()) == true\n",
       "a throwing IsMounted taking the queue down",
       expect="took the queue down with it",
       script="runscenarios.py")

# ------------------------------------------------------------------ minimap

mutate("Options.lua",
       "\t\t\t\tif mouseButton == \"RightButton\" and OpenLauncherMenu(owner) then return end\n",
       "",
       "a right-click that opens no menu",
       expect="ease: the minimap right-click opens a menu",
       script="runscenarios.py")

mutate("Options.lua",
       "\tfor _, minutes in ipairs(ns.SNOOZE_CHOICES) do\n",
       "\tfor _, minutes in ipairs({}) do\n",
       "a menu with no snooze in it",
       expect="the menu is missing entries",
       script="runscenarios.py")

mutate("Options.lua",
       "\t\t\t\tif HasLauncherMenu() then\n",
       "\t\t\t\tif false then\n",
       "a tooltip that does not mention the menu",
       expect="the tooltip does not list what the clicks do",
       script="runscenarios.py")

# ------------------------------------------------------------------ help

# A command the dispatcher answers to, dropped from the list the help prints.
mutate("Core.lua",
       "\t{ word = \"export\", group = \"share\", help = \"copy these settings as one line of text\" },\n",
       "",
       "a real command missing from the help",
       expect="is a real command the help never",
       script="runscenarios.py")

# A group missing, so every command in it goes unprinted.
mutate("Core.lua",
       "\t{ key = \"trouble\", title = \"When something is wrong\" },\n",
       "",
       "a help group nobody prints",
       expect="ease: help lists every real command",
       script="runscenarios.py")

mutate("Core.lua",
       "\t\tif closest then\n",
       "\t\tif false then\n",
       "no did-you-mean",
       expect="ease: did you mean",
       script="runscenarios.py")

# A guess for anything at all.
mutate("Core.lua",
       "\tlocal allowed = #word <= 4 and 1 or 2\n",
       "\tlocal allowed = 99\n",
       "a did-you-mean that always guesses",
       expect="was answered with a guess",
       script="runscenarios.py")

# ------------------------------------------------------------------ sharing

# The separators left unescaped, so a line of text with ; or = in it breaks the
# string it is written into.
mutate("Core.lua",
       "\treturn (s:gsub(\"[^%w_%.%-!%?'%(%){}/ ]\", function(c)\n",
       "\treturn (s:gsub(\"[^%w_%.%-!%?'%(%){}/ ;=]\", function(c)\n",
       "an export that does not escape its separators",
       expect="ease: export and import round-trip",
       script="runscenarios.py")

# Everything the string does not name left as it was, so an import is a merge
# and its undo leaves the imported settings behind.
mutate("Core.lua",
       "\t\t\tholder[field.key] = CopyValue(field.default)\n",
       "\t\t\tlocal _ = CopyValue(field.default)\n",
       "an import that does not reset what it leaves out",
       expect="did not put the old settings back",
       script="runscenarios.py")

mutate("Core.lua",
       "\t\tif SHARE_KEEP_MINE[field.name] then\n",
       "\t\tif false then\n",
       "an import that switches speech on",
       expect="switched on speaking to other players",
       script="runscenarios.py")

mutate("Core.lua",
       "\tif Checksum(\"MNR\" .. version .. \":\" .. body) ~= sum:lower() then\n",
       "\tif false then\n",
       "an import that ignores the checksum",
       expect="ease: malformed and hostile import strings are rejected",
       script="runscenarios.py")

mutate("Core.lua",
       "\t\t\t\tif value == nil then return nil, ns.SHARE_ERRORS.badValue:format(name) end\n",
       "",
       "an import that takes a value of the wrong type",
       expect="ease: malformed and hostile import strings are rejected",
       script="runscenarios.py")

# Any name at all taken for a setting. The apply loop walks the known list and
# so still writes none of them -- that is the second guard, and the scenario
# checks the profile too -- but the player is no longer told that a newer
# version's settings were left out.
mutate("Core.lua",
       "\t\t\tlocal field = byName[name]\n",
       "\t\t\tlocal field = byName[name] or { name = name, kind = \"string\", path = {}, key = name }\n",
       "an import that takes unknown names for settings",
       expect="unknown settings were skipped without a word",
       script="runscenarios.py")

# The repair skipped, so a value no slider can reach is kept.
mutate("Core.lua",
       "\tlastImportUndo = undo\n"
       "\t-- What a profile switch runs, for the same reason: every setting changed\n"
       "\t-- at once. It is safe in a fight -- ApplyStyle puts itself off until the\n"
       "\t-- fight ends -- which the line below says.\n"
       "\taddon:RefreshConfig()\n",
       "\tlastImportUndo = undo\n",
       "an import that is never repaired",
       expect="outside what the page allows survived",
       script="runscenarios.py")

mutate("Options.lua",
       "\tif which == \"export\" then shareOpen = true end\n",
       "",
       "/manners export with the box shut",
       expect="left the box with the settings in it shut",
       script="runscenarios.py")
