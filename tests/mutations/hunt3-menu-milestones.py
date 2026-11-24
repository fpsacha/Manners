# Hunt 3 of the day's work, the options window (Options/Window/WindowSearch.lua,
# WindowPage.lua, Layout.lua, Widgets.lua, WindowChrome.lua): search says "turn
# on" only a switch that is off and would show the control, no fine-print
# caption over What's new, what Show spell icon governs goes with it, and a
# greyed button runs its tooltip. Each fault is caught by the
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
       "hunt3-menu-milestones: the fine-print caption over What's new",
       expect=P + "no fine-print caption over What's new on Start here", script=S)

mutate("Options/Window/Layout.lua",
       "header = \"general.newsHeader\", fold = true, plain = true, items = {\n",
       "header = \"general.newsHeader\", fold = true, items = {\n",
       "hunt3-menu-milestones: What's new is fine print",
       expect=P + "no fine-print caption over What's new on Start here", script=S)

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
