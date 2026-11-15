# Hunt 3 of the day's work, the options window and the milestones
# (Options/Window/WindowSearch.lua, WindowPage.lua, Layout.lua, Widgets.lua,
# WindowChrome.lua, Milestones.lua, Ledger.lua): search says "turn on" only a
# switch that is off and would show the control, no fine-print caption over
# the hall of fame, what Show spell icon governs goes with it, a greyed button
# runs its tooltip, a raid is everybody by the buff and with the one a group
# cast was aimed at, the week without a debt outlasts the rows the ledger
# drops, and a toast steps aside for the prompt. Each fault is caught by the
# scenario in tests/scenarios/hunt3-menu-milestones.lua that names it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"
P = "hunt3-menu-milestones: "

# 1: search asks neither whether the switch is off...
mutate("Options/Window/WindowSearch.lua",
       "\tif Ask(ns.WindowBind.Value, parent) == true then return nil end\n",
       "",
       "hunt3-menu-milestones: search says to turn on a switch that is on",
       expect=P + "search does not say to turn on a switch that is on", script=S)

# ...nor whether it would show the control to this class.
mutate("Options/Window/WindowSearch.lua",
       "\tif type(reach) == \"function\" and not Ask(reach) then return nil end\n",
       "",
       "hunt3-menu-milestones: search offers another class's courtesy behind a switch",
       expect=P + "search offers a courtesy only to the class that has it", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t[\"who.courtesyPortals\"] = function() return ns.Courtesy.Has(\"courtesyPortals\") end,\n",
       "",
       "hunt3-menu-milestones: the portals are anybody's to search for",
       expect=P + "search offers a courtesy only to the class that has it", script=S)

# 2: the caption over any fold again.
mutate("Options/Window/WindowPage.lua",
       "\t\t\tif sec.fold and not sec.def.plain and not captioned then\n",
       "\t\t\tif sec.fold and not captioned then\n",
       "hunt3-menu-milestones: the fine-print caption over the hall of fame",
       expect=P + "no fine-print caption over the hall of fame on Start here", script=S)

mutate("Options/Window/Layout.lua",
       "header = \"general.hallHeader\", fold = true, plain = true, items = {\n",
       "header = \"general.hallHeader\", fold = true, items = {\n",
       "hunt3-menu-milestones: the hall of fame is fine print",
       expect=P + "no fine-print caption over the hall of fame on Start here", script=S)

# 7: a row further out between the switch and what it governs.
mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t{ \"appearance.iconSizeCapped\", indent = true },\n",
       "\t\t\t\t\t\"appearance.iconSizeCapped\",\n",
       "hunt3-menu-milestones: a note stands between Show spell icon and its sub-options",
       expect=P + "with Show spell icon off, its sub-options are not drawn", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t\"appearance.gryphons\",\n",
       "\t\t\t\t\t{ \"appearance.gryphons\", indent = true },\n",
       "hunt3-menu-milestones: the gryphons indented under the icon's switch",
       expect=P + "with Show spell icon off, its sub-options are not drawn", script=S)

# 8: a disabled button is told nothing.
mutate("Options/Window/Widgets.lua",
       "\tframe.row, frame.hover = row, hover\n\tW.TipsWhileOff(frame)\n",
       "\tframe.row, frame.hover = row, hover\n",
       "hunt3-menu-milestones: a greyed switch runs no tooltip",
       expect=P + "a greyed button still runs its tooltip", script=S)

mutate("Options/Window/WindowChrome.lua",
       "\tW.TipsWhileOff(header.move)\n",
       "",
       "hunt3-menu-milestones: Move the prompt runs no tooltip in a fight",
       expect=P + "a greyed button still runs its tooltip", script=S)

# 3: the one a group cast was aimed at is skipped with the people it covered.
mutate("Milestones.lua",
       "\t\tw.grouped = group ~= nil and (pending.member == true or entry.kind ~= \"received\")\n",
       "\t\tw.grouped = group ~= nil\n",
       "hunt3-menu-milestones: a group cast's anchor owed a favour is left out of the raid",
       expect=P + "the one a group cast was aimed at is one of the raid it reached", script=S)

# 4: a sitting per spell id again.
mutate("Milestones.lua",
       "\t\t\t\t\tSat(st, w.key or e.spell, w.names, w.size, w.clock)\n",
       "\t\t\t\t\tSat(st, e.spell, w.names, w.size, w.clock)\n",
       "hunt3-menu-milestones: a sitting is one spell id, not one buff",
       expect=P + "a raid covered by the group version and the single one of one buff is everybody", script=S)

# ...and every buff one sitting is no better.
mutate("Milestones.lua",
       "\tif type(pending) == \"table\" and type(pending.buffKey) == \"string\" then w.key = pending.buffKey end\n",
       "\tif type(pending) == \"table\" and type(pending.buffKey) == \"string\" then w.key = \"buff\" end\n",
       "hunt3-menu-milestones: every buff fills the same sitting",
       expect=P + "a raid covered by the group version and the single one of one buff is everybody", script=S)

# 5: Clear tells the milestones nothing.
mutate("Ledger.lua",
       "\t\t\tns.Guard(\"milestones\", M.Dropped, e)\n",
       "",
       "hunt3-menu-milestones: Clear takes the week's favours with it",
       expect=P + "Clear does not take the week's returned favours with it", script=S)

mutate("Milestones.lua",
       "\t\tif week.broke and week.broke >= now - WEEK_SECONDS then return false end\n",
       "",
       "hunt3-menu-milestones: a favour let go and cleared away bars nothing",
       expect=P + "Clear does not hide a favour left unreturned this week", script=S)

mutate("Milestones.lua",
       "\t\tif not week.broke or e.at > week.broke then week.broke = e.at end\n",
       "",
       "hunt3-menu-milestones: a favour let go is forgotten with its row",
       expect=P + "Clear does not hide a favour left unreturned this week", script=S)

# ...and neither does the trim.
mutate("Ledger.lua",
       "\t\tif M and M.Dropped then ns.Guard(\"milestones\", M.Dropped, entries[i]) end\n",
       "",
       "hunt3-menu-milestones: the trim takes the week's first days with it",
       expect=P + "a busy ledger's trim does not take the week's first days with it", script=S)

# 9: the toast looks once, when it is shown.
mutate("Milestones.lua",
       "\t\tself.lookAt = age + TOAST_LOOK\n\t\tStepAside(self)\n",
       "\t\tself.lookAt = age + TOAST_LOOK\n",
       "hunt3-menu-milestones: a toast stays over a prompt that comes up under it",
       expect=P + "a toast steps aside when the prompt comes up under it", script=S)
