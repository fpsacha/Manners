# The ledger window's layout, each load-bearing part put back wrong and
# required to be caught by the scenario in tests/scenarios/ledgerui.lua written
# for it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# Hung by an edge and a centre, as the first window was: where the client puts
# such a string is not settled, so the window avoids the pairing on purpose,
# and a string that leans on it must be caught whichever reading the client
# turns out to use.
mutate("Ledger.lua",
       "\trow.name:SetPoint(\"TOPRIGHT\", row.when, \"TOPLEFT\", -8, 1)\n",
       "\trow.name:SetPoint(\"RIGHT\", row, \"RIGHT\", -70, 0)\n",
       "ledgerui: a row's name hung by an edge and a centre",
       expect="ledgerui: the window is hung by edges", script=S)
mutate("Ledger.lua",
       "\trow.detail:SetPoint(\"BOTTOMRIGHT\", row, \"BOTTOMRIGHT\", -8, 4)\n",
       "\trow.detail:SetPoint(\"RIGHT\", row, \"RIGHT\", -8, 0)\n",
       "ledgerui: a row's detail climbs over its name",
       expect="ledgerui: rows and header are laid out without overlap", script=S)
mutate("Ledger.lua",
       "\twindow.headline:SetPoint(\"TOPRIGHT\", window, \"TOPRIGHT\", -PAD, HEADLINE_TOP)\n",
       "\twindow.headline:SetPoint(\"RIGHT\", window, \"RIGHT\", -PAD, 0)\n",
       "ledgerui: the headline drawn in the list",
       expect="ledgerui: rows and header are laid out without overlap", script=S)

# The badge's plate is sized to its word.
mutate("Ledger.lua",
       "\tlocal plate = math.min(BADGE_MAX, math.ceil(TextWidth(row.badge)) + 10)\n",
       "\tlocal plate = 40\n",
       "ledgerui: badge plate narrower than its word",
       expect="ledgerui: rows and header are laid out without overlap", script=S)

# Labels sized to their text in every language, and the summary given a
# second line rather than cut.
mutate("Ledger.lua",
       "\t\twidths[i] = FitWidth(tab.label, { def.label }, 70, 160)\n",
       "\t\twidths[i] = 70\n",
       "ledgerui: tabs too narrow for German",
       expect="ledgerui: long text fits or ellipsises", script=S)
mutate("Ledger.lua",
       "\tclear:SetWidth(FitWidth(clear.label, { TEXT.CLEAR, TEXT.CLEAR_ARMED }, 90, 180))\n",
       "",
       "ledgerui: Clear too narrow for its second label",
       expect="ledgerui: long text fits or ellipsises", script=S)
mutate("Ledger.lua",
       "\tWrap(window.subline, 2)\n",
       "",
       "ledgerui: summary line cut to one line",
       expect="ledgerui: long text fits or ellipsises", script=S)

# The empty list's mark goes with the rows, and the line saying nothing can
# be recorded stands apart from the ordinary one.
mutate("Ledger.lua",
       "\twindow.emptyIcon:SetShown(#list == 0)\n",
       "",
       "ledgerui: empty mark shown over the rows",
       expect="ledgerui: the empty list says how rows arrive", script=S)
mutate("Ledger.lua",
       "\tlocal c = ordinary and INK_SOFT or COLOUR.owed\n",
       "\tlocal c = INK_SOFT\n",
       "ledgerui: 'switched off' reads like 'nothing yet'",
       expect="ledgerui: the empty list says how rows arrive", script=S)

# The chosen tab is the one marked, and a badge wears its row's colour.
mutate("Ledger.lua",
       "\t\ttab.underline:SetShown(tab.selected)\n",
       "",
       "ledgerui: every tab marked as chosen",
       expect="ledgerui: each tab lists its own rows", script=S)
mutate("Ledger.lua",
       "\trow.badge:SetTextColor(colour[1], colour[2], colour[3])\n",
       "",
       "ledgerui: badge not in its row's colour",
       expect="ledgerui: each tab lists its own rows", script=S)
mutate("Ledger.lua",
       "\tstranger = { 0.64, 0.68, 0.82 },\n",
       "\tstranger = { 0.34, 0.60, 0.96 },\n",
       "ledgerui: strangers badged as the group",
       expect="ledgerui: each tab lists its own rows", script=S)

# Clear only while it has something to take, and never back already armed.
mutate("Ledger.lua",
       "\twindow.clear:SetShown(clearable)\n",
       "",
       "ledgerui: Clear shown over an empty list",
       expect="ledgerui: Clear shows only when there is something to clear", script=S)
mutate("Ledger.lua",
       "\tif not clearable and clearArmedUntil then DisarmClear() end\n",
       "",
       "ledgerui: Clear comes back armed",
       expect="ledgerui: Clear shows only when there is something to clear", script=S)
mutate("Ledger.lua",
       "\t\tif not (e.kind == \"received\" and e.state == \"owed\") then return true end\n",
       "\t\treturn true\n",
       "ledgerui: Clear offered over favours it would keep",
       expect="ledgerui: Clear shows only when there is something to clear", script=S)
