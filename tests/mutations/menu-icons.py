# Mutations for the spell icons in the options window (Widgets.lua, W.SpellIcon).

S = "runscenarios.py"
ICON = "menu-icons: a switch naming your spell wears its icon, one naming none wears nothing"

mutate("Options/Window/Widgets.lua",
       "\tif def and def.image == nil then return W.SpellIcon(W.Name(row)) end\n",
       "",
       "menu-icons: a switch naming a spell wears no icon",
       expect=ICON, script=S)
mutate("Options/Window/Widgets.lua",
       "\t\tif text:find(name, 1, true) then return names[name] end\n",
       "\t\treturn names[name]\n",
       "menu-icons: any words wear the first spell's icon",
       expect=ICON, script=S)
mutate("Options/Window/Widgets.lua",
       "\tif not icon then return text end\n",
       "\tif not icon then return \"|T0:16|t \" .. text end\n",
       "menu-icons: a dropdown naming no spell leads with an icon",
       expect=ICON, script=S)

mutate("Modules/Combat/Options.lua",
       "do section.items[i] = { path, columns = 2 } end",
       "do section.items[i] = path end",
       "combat-actions: the actions one to a row again",
       expect="combat-actions: enabling a learned action exposes its option and one secure button", script=S)

mutate("Options/Window/WindowChrome.lua",
       "\t\tfooter.changed:SetPoint(\"LEFT\", footer.foot, \"LEFT\", 10, 0)\n",
       "\t\tfooter.changed:SetPoint(\"LEFT\", footer.reset, \"RIGHT\", FOOT_GAP, 0)\n",
       "window: the square buttons keep the hidden reset's gap",
       expect="window: the reset button is hidden on Start here, Profiles and Diagnostics", script=S)
