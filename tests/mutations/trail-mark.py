# Mark this moment and a fuller trail (Options/BugReport.lua, Core.lua,
# tests/scenarios/trail-mark.lua): each fault put back has to be caught by the
# scenario that names it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

HOLDS = "trail-mark: a mark holds the prompt, the queue and the buttons"
ALIAS = "trail-mark: the people in a mark are aliased in the report"
KEYS = "trail-mark: the key, the menu and /manners mark all mark"
SUMMARY = "trail-mark: a fight's end writes one summary line"
HOLD = "trail-mark: a change of hold-back reason is written once"
KEEPS = "trail-mark: the trail keeps 300"

# The prompt's mark line names nobody, so the report cannot alias them.
mutate("Options/BugReport.lua",
       "\t\t\ttostring(entry.reason)), type(entry.name) == \"string\" and entry.name or nil)\n",
       "\t\t\ttostring(entry.reason)))\n",
       "trail-mark: the prompt's line has no who",
       expect=ALIAS,
       script=S)

# The queue's mark lines name nobody.
mutate("Options/BugReport.lua",
       "\t\t\ttostring(e.reason), tostring(e.priority)), type(e.name) == \"string\" and e.name or nil)\n",
       "\t\t\ttostring(e.reason), tostring(e.priority)))\n",
       "trail-mark: the queue's lines have no who",
       expect=ALIAS,
       script=S)

# The buttons line is left out.
mutate("Options/BugReport.lua",
       "\tns.Trail(\"MARK\", ButtonLine())\n",
       "",
       "trail-mark: no buttons line",
       expect=HOLDS,
       script=S)

# The key's button marks nothing.
mutate("Options/BugReport.lua",
       "\tmark:SetScript(\"OnClick\", function() ns.Guard(\"mark this moment\", ns.MarkMoment) end)\n",
       "\tmark:SetScript(\"OnClick\", function() end)\n",
       "trail-mark: the key's button marks nothing",
       expect=KEYS,
       script=S)

# The binding is not declared.
mutate("Bindings.xml",
       "\t<Binding name=\"CLICK MannersMark:LeftButton\" category=\"Manners\"/>\n",
       "",
       "trail-mark: no binding for the mark",
       expect=KEYS,
       script=S)

# The minimap menu has no Mark this moment.
mutate("Options/Launcher.lua",
       "\troot:CreateButton(L[\"Mark this moment\"], Act(function() ns.MarkMoment() end))\n",
       "",
       "trail-mark: the minimap menu has no mark",
       expect=KEYS,
       script=S)

# /manners mark is not a word.
mutate("Commands.lua",
       "\telseif input == \"mark\" then\n",
       "\telseif input == \"markk\" then\n",
       "trail-mark: /manners mark is not a command",
       expect=KEYS,
       script=S)

# A fight's end writes no summary.
mutate("Core.lua",
       "\tns.Guard(\"fight summary\", ns.FightSummary)\n",
       "",
       "trail-mark: a fight's end writes no summary",
       expect=SUMMARY,
       script=S)

# A pull does not start the count.
mutate("Core.lua",
       "\tns.fightTally.started = GetTime()\n",
       "",
       "trail-mark: a pull does not start the tally",
       expect=SUMMARY,
       script=S)

# The hold-back watch writes every time.
mutate("Options/BugReport.lua",
       "\tif kind ~= lastKind then\n",
       "\tif true then\n",
       "trail-mark: the hold-back watch writes every time",
       expect=HOLD,
       script=S)

# The trail is back at 200.
mutate("Core.lua",
       "local TRAIL_MAX = 300\n",
       "local TRAIL_MAX = 200\n",
       "trail-mark: the trail keeps 200",
       expect=KEEPS,
       script=S)
