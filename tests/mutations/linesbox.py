# Mutations for the box of many lines keeping what was typed when it is left
# (Options/Window/WidgetsEntry.lua MultiLeft). Each is caught by the scenario in
# tests/scenarios/linesbox.lua that names it.

S = "runscenarios.py"

mutate("Options/Window/WidgetsEntry.lua",
       "\tbox:SetScript(\"OnEditFocusLost\", function(self) ns.Guard(\"options box\", MultiLeft, self) end)\n",
       "\tbox:SetScript(\"OnEditFocusLost\", function(self) ns.Guard(\"options box\", MultiFocus, self, false) end)\n",
       "linesbox: leaving the box throws the lines away",
       expect="linesbox: leaving the box keeps the lines typed", script=S)

mutate("Options/Window/WidgetsEntry.lua",
       "\tif row.leaving or row.busy or row.error or ReadOnly(row) or W.Waiting(row) or TypingOnly(row) then return end\n",
       "\tif row.leaving or row.busy or row.error or ReadOnly(row) or W.Waiting(row) then return end\n",
       "linesbox: a box for typing into commits when it is left",
       expect="linesbox: a box for typing into waits for Accept", script=S)

mutate("Options/Window/WidgetsEntry.lua",
       "\tif Submit(row) then\n\t\tAcceptState(row)\n\t\tW.Settle(row)\n\tend\n",
       "\tSubmit(row)\n",
       "linesbox: Accept stays lit after the lines were kept",
       expect="linesbox: leaving the box keeps the lines typed", script=S)
