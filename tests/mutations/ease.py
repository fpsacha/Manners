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

# The unit the help itself uses, refused.
mutate("Core.lua",
       "\t[\"\"] = 1, m = 1, min = 1, mins = 1, minute = 1, minutes = 1,\n",
       "\t[\"\"] = 1, m = 1, min = 1, mins = 1,\n",
       "a snooze that refuses 15 minutes",
       expect="/manners snooze 15 minutes snoozed for",
       script="runscenarios.py")

mutate("Core.lua",
       "\th = 60, hr = 60, hrs = 60, hour = 60, hours = 60,\n",
       "",
       "a snooze that refuses hours",
       expect="/manners snooze 1h snoozed for",
       script="runscenarios.py")

# A 24-hour time for somebody whose clock says PM.
mutate("Core.lua",
       "\treturn ok and plain(value) == \"0\"\n",
       "\treturn false\n",
       "a snooze end on a clock not the player's",
       expect="a 12-hour clock was told",
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
       "\tlocal allowed = #word >= 6 and 2 or 1\n",
       "\tlocal allowed = 99\n",
       "a did-you-mean that always guesses",
       expect="was answered with a guess",
       script="runscenarios.py")

# Two slips allowed in a five-letter word, which makes "reset" into "test".
mutate("Core.lua",
       "\tlocal allowed = #word >= 6 and 2 or 1\n",
       "\tlocal allowed = #word <= 4 and 1 or 2\n",
       "a did-you-mean that guesses test for reset",
       expect="/manners reset was answered with a guess",
       script="runscenarios.py")

# Two letters swapped counted as two slips, so "tset" finds nothing.
mutate("Core.lua",
       "\t\t\t\tbest = math.min(best, rows[i - 2][j - 2] + 1)\n",
       "\t\t\t\tbest = best\n",
       "a did-you-mean blind to swapped letters",
       expect="/manners tset did not suggest",
       script="runscenarios.py")

# A command suggested to itself: the guess a missing branch hides behind.
mutate("Core.lua",
       "\tfor _, candidate in ipairs(words) do\n\t\tif candidate == word then return nil end\n\tend\n",
       "",
       "a command suggested to itself",
       expect="a real command, would be answered with a guess",
       script="runscenarios.py")

# An advertised command with no branch. The walk in the main file finds it by
# the full help it falls through to, which a guess of itself used to replace.
mutate("Core.lua",
       "\telseif input == \"forms\" then\n",
       "\telseif false then\n",
       "an advertised command with no branch",
       expect="every advertised command exists",
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
       "\t\tif value == nil then value = CopyValue(field.default) end\n",
       "\t\tif value == nil then value = holder[field.key] end\n",
       "an import that does not reset what it leaves out",
       expect="did not put the old settings back",
       script="runscenarios.py")

mutate("Core.lua",
       "\t\tif not own and SHARE_KEEP_MINE[field.name] then\n",
       "\t\tif false then\n",
       "an import that switches speech on",
       expect="switched on speaking to other players",
       script="runscenarios.py")

# The switch kept and everything behind it handed over: the player who says
# "thanks" in /say starts yelling a stranger's words.
mutate("Core.lua",
       "\t\telseif not own and speaking and SHARE_SPEECH[field.name] then\n",
       "\t\telseif false then\n",
       "an import that rewrites a speaker's words",
       expect="changed what a player who speaks says",
       script="runscenarios.py")

mutate("Core.lua",
       "\t[\"prompt.locked\"] = true,\n",
       "",
       "an import that unlocks the prompt",
       expect="unlocked this one",
       script="runscenarios.py")

mutate("Core.lua",
       "\t[\"prompt.x\"] = true,\n",
       "",
       "an import that moves the prompt",
       expect="the import moved the prompt",
       script="runscenarios.py")

# The undo run as an import, the way it first was: it keeps the settings it
# replaced as a new undo, so a second undo puts the import back -- and the
# first says "settings imported" and tells the player to undo it.
mutate("Core.lua",
       "\tlocal parsed = ns.ParseSettings(lastImportUndo)\n\tlastImportUndo = nil\n",
       "\tdo return ns.ImportSettings(lastImportUndo) end\n\tlocal parsed\n",
       "an undo that can be run twice",
       expect="a second /manners import undo",
       script="runscenarios.py")

# The undo outliving a profile switch, and landing on the wrong profile.
mutate("Core.lua",
       "\tns.ForgetImportUndo()\n\tself:StartScanner()\n",
       "\tself:StartScanner()\n",
       "an undo that follows a profile switch",
       expect="an undo made on one profile rewrote another",
       script="runscenarios.py")

mutate("Core.lua",
       "\tif not offset(p.x) or not offset(p.y) then\n",
       "\tif false then\n",
       "an offset no screen has, kept",
       expect="an offset of 1e300 survived the repair",
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
       "\t-- undo, which each caller then sets as it needs.\n"
       "\taddon:RefreshConfig()\n",
       "\t-- undo, which each caller then sets as it needs.\n",
       "an import that is never repaired",
       expect="outside what the page allows survived",
       script="runscenarios.py")

mutate("Options.lua",
       "\tif which == \"export\" then shareOpen = true end\n",
       "",
       "/manners export with the box shut",
       expect="left the box with the settings in it shut",
       script="runscenarios.py")

# The game cannot copy, so a button that says it does is a promise broken.
mutate("Options.lua",
       "or L[\"Show my settings as text\"]\n",
       "or L[\"Copy my settings\"]\n",
       "a button that says it copies",
       expect="copies nothing",
       script="runscenarios.py")
