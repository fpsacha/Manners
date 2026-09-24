# The favour ledger's load-bearing parts, each put back wrong and required to
# be caught by the scenario in tests/scenarios/ledger.lua written for it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# The four moments Core tells the ledger about, and the login that reconciles it.
mutate("Core.lua",
       "\tTellLedger(\"Received\", seen)\n",
       "",
       "ledger: a favour is never written down",
       expect="a favour appears in the ledger", script=S)
mutate("Core.lua",
       "\t\tTellLedger(\"Settled\", pending.name, wasOwed, pending, spellId)\n",
       "",
       "ledger: a repayment is never written down",
       expect="a favour repaid is marked returned", script=S)
mutate("Core.lua",
       "\tTellLedger(\"Refused\", settled.name, settled.at)\n",
       "",
       "ledger: a late refusal leaves the row repaid",
       expect="a refused cast puts the ledger back", script=S)
mutate("Core.lua",
       "\t\t\tTellLedger(\"LetGo\", name)\n",
       "",
       "ledger: an expired debt stays owed in the list",
       expect="a favour that runs out is let go", script=S)
mutate("Core.lua",
       "\tTellLedger(\"Load\")\n",
       "",
       "ledger: login never checks owed rows",
       expect="a favour owed at logout is let go", script=S)

# A second buff from somebody already owed is the same favour.
mutate("Ledger.lua",
       "\t\tinto = FindOpen(s, name)\n",
       "\t\tinto = nil\n",
       "ledger: a second buff becomes a second row",
       expect="a favour appears in the ledger", script=S)

# The group flag, carried from the queue through the press to the settle.
mutate("Prompt.lua",
       "\t\t\tinGroup = current.inGroup,\n",
       "",
       "ledger: every gift filed under strangers",
       expect="buffs given unprompted are filed under group or strangers", script=S)

# The bound, the gifts' share of it, and the owed rows it never trims.
mutate("Ledger.lua",
       "local MAX_ENTRIES = 200\n",
       "local MAX_ENTRIES = 2000\n",
       "ledger: the list grows without bound",
       expect="the ledger keeps to its bound", script=S)
mutate("Ledger.lua",
       "local MAX_GIVEN = 100\n",
       "local MAX_GIVEN = 1000\n",
       "ledger: gifts crowd the favours out",
       expect="the ledger keeps to its bound", script=S)
mutate("Ledger.lua",
       "\t\tif entries[i].state == \"owed\" then\n",
       "\t\tif false then\n",
       "ledger: a favour still owed is trimmed",
       expect="the ledger keeps to its bound", script=S)

# The repair of a file the ledger did not write.
mutate("Ledger.lua",
       "\t\ttotals[key] = math.max(Count(old[key]), seen[key])\n",
       "\t\ttotals[key] = old[key]\n",
       "ledger: damaged totals kept as they are",
       expect="a character with a ledger that is damaged loads", script=S)
mutate("Ledger.lua",
       "\tif name:find(\"[%[%]\\n\\r;|]\") then return nil end\n",
       "",
       "ledger: a name with a chat escape is kept",
       expect="a character with a ledger that is damaged loads", script=S)
mutate("Ledger.lua",
       "\tif Secret(name) or type(name) ~= \"string\" then return nil end\n",
       "\tif type(name) ~= \"string\" then return nil end\n",
       "ledger: a secret name is kept",
       expect="the ledger never keeps a secret name", script=S)

# Today is the calendar day, and the summary reaches the tooltip.
mutate("Ledger.lua",
       "\t\treturn now - ((t.hour * 60 + t.min) * 60 + t.sec)\n",
       "\t\treturn now - 86400\n",
       "ledger: today is the last 24 hours",
       expect="the ledger summary counts are right", script=S)
mutate("Options.lua",
       "if ns.Ledger then ns.Guard(\"ledger tooltip\", ns.Ledger.AddTooltip, tooltip) end",
       "",
       "ledger: the minimap tooltip has no summary",
       expect="the ledger summary counts are right", script=S)

# Clear keeps the favours still owed.
mutate("Ledger.lua",
       "\t\tif e.kind == \"received\" and e.state == \"owed\" then kept[#kept + 1] = e end\n",
       "",
       "ledger: Clear drops favours still owed",
       expect="the ledger window lists entries", script=S)

# The slash command reaches the window.
mutate("Core.lua",
       "\telseif input == \"log\" or input == \"ledger\" then\n",
       "\telseif input == \"nolog\" then\n",
       "ledger: /manners log does nothing",
       expect="the ledger window lists entries", script=S)
