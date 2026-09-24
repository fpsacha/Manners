# The favour ledger's load-bearing parts, each put back wrong and required to
# be caught by the scenario in tests/scenarios/ledger.lua written for it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# The four moments Core tells the ledger about, and the login that reconciles it.
mutate("Core.lua",
       "\tTellLedger(\"Received\", seen, nil, ns.CouldOffer(hasMana, false) == nil)\n",
       "",
       "ledger: a favour is never written down",
       expect="a favour appears in the ledger", script=S)
mutate("Core.lua",
       "\tif not unheard then TellLedger(\"Settled\", pending.name, wasOwed, pending, spellId) end\n",
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
       "\telseif input == \"ledger\" or input == \"log\" then\n",
       "\telseif input == \"nolog\" then\n",
       "ledger: /manners ledger does nothing",
       expect="the ledger window lists entries", script=S)

# Today's headline scores only favours something you cast could return.
mutate("Ledger.lua",
       "\t\t\tif e.kind == \"received\" and e.why == \"useless\" then\n",
       "\t\t\tif false then\n",
       "ledger: a useless favour scored as unreturned",
       expect="only favours you could return are scored", script=S)
mutate("Ledger.lua",
       "\t\treturn (sum.useless or 0) > 0 and TEXT.TODAY_ONLY_USELESS or TEXT.TODAY_NONE\n",
       "\t\treturn TEXT.TODAY_NONE\n",
       "ledger: only useless favours read as none",
       expect="only favours you could return are scored", script=S)

# While nothing can arrive, the window and the tooltip say so.
mutate("Ledger.lua",
       "\tif quiet == \"off\" then return TEXT.EMPTY_OFF end\n",
       "",
       "ledger: switched off still promises rows",
       expect="the ledger says why nothing is being recorded", script=S)
mutate("Ledger.lua",
       "\tif type(p.sources) == \"table\" and not p.sources.owed then return \"owedoff\" end\n",
       "",
       "ledger: owed toggle off still promises favours",
       expect="the ledger says why nothing is being recorded", script=S)
mutate("Ledger.lua",
       "\tif ok and nothing then return \"nothing\" end\n",
       "",
       "ledger: nothing to cast still promises rows",
       expect="the ledger says why nothing is being recorded", script=S)
mutate("Ledger.lua",
       "\tif (quiet == \"off\" or quiet == \"nothing\") and #Ledger.Entries(\"all\") == 0 then\n",
       "\tif false then\n",
       "ledger: a rogue's tooltip gets a line of zeros",
       expect="the ledger says why nothing is being recorded", script=S)

# A favour only a party buff can return waits on them being in the party.
mutate("Core.lua",
       "\tTellLedger(\"Received\", seen, nil, ns.CouldOffer(hasMana, false) == nil)\n",
       "\tTellLedger(\"Received\", seen)\n",
       "ledger: party-only favours not marked",
       expect="a favour only your party can be repaid says so", script=S)
mutate("Ledger.lua",
       "\t\t\tlocal line = not e.partyOnly and TEXT.TIP_OWED\n",
       "\t\t\tlocal line = true and TEXT.TIP_OWED\n",
       "ledger: party-only row promises an offer",
       expect="a favour only your party can be repaid says so", script=S)

# The row forgotten at a reload names the setting as the options name it.
mutate("Ledger.lua",
       "\"Let go: \\\"Remember them across a reload\\\" (When tab",
       "\"Let go: \\\"Remember favours across a reload\\\" (When tab",
       "ledger: not-kept row names a missing setting",
       expect="a favour forgotten at a reload names the setting", script=S)

# The window's first spot is clear of the prompt's.
mutate("Ledger.lua",
       "\t\twindow:SetPoint(DEFAULT_POINT, UIParent, DEFAULT_POINT, DEFAULT_X, DEFAULT_Y)\n",
       "\t\twindow:SetPoint(\"CENTER\", UIParent, \"CENTER\", 0, 60)\n",
       "ledger: opens centred over the prompt",
       expect="the ledger opens clear of the prompt", script=S)

# The General tab's button shuts the options window the ledger would sit under.
mutate("Options.lua",
       "\t\t\t\t\t\t\tns.CloseOptions()\n",
       "",
       "ledger: opens under the options window",
       expect="the ledger summary counts are right", script=S)

# A favour repaints the options only where the count is printed.
mutate("Ledger.lua",
       "\t\tif tab == nil or tab == \"general\" then\n",
       "\t\tif true then\n",
       "ledger: every favour redraws every tab",
       expect="a favour repaints the options only on the General tab", script=S)
