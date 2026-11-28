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

FREE = "combat-actions: the combat prompt sits above the buff prompt, a place each, and a self row has a macro"
mutate("Modules/Combat/Moments.lua",
       "\t\t\tif free and previewing then\n",
       "\t\t\tif false then\n",
       "combat-actions: no handle for each card",
       expect=FREE, script=S)
mutate("Modules/Combat/Moments.lua",
       "\tdb.moments.places[slot.row.key] = { x = hx - px, y = hy - py }\n",
       "",
       "combat-actions: a dragged card's place is not saved",
       expect=FREE, script=S)
mutate("Modules/Combat/Moments.lua",
       "\t\t\tlocal own = free and places[slot.row.key]\n",
       "\t\t\tlocal own = nil\n",
       "combat-actions: a saved card's place is not used",
       expect=FREE, script=S)
mutate("Modules/Combat/Moments.lua",
       "\tat:EnableMouse(previewing == true and not free)\n",
       "\tat:EnableMouse(previewing == true)\n",
       "combat-actions: the row's frame takes the drag in a free layout",
       expect=FREE, script=S)
mutate("Modules/Combat/Moments.lua",
       "\tdb.moments.places = nil\n",
       "",
       "combat-actions: Reset keeps the cards' own places",
       expect=FREE, script=S)
mutate("Modules/Combat/Moments.lua",
       "\t\tb:SetPoint(\"CENTER\", self, \"CENTER\", 0, 0)\n",
       "",
       "combat-actions: the card does not follow its handle",
       expect=FREE, script=S)

mutate("Modules/Combat/Options.lua",
       "\t\thidden = function() return Off() or #Learned() == 0 or not Moved() end,\n",
       "\t\thidden = function() return Off() or #Learned() == 0 end,\n",
       "combat-actions: Reset position shows with nothing moved",
       expect=FREE, script=S)
mutate("Modules/Combat/Options.lua",
       "\t\t\tif layout == \"stack\" then return L[\"Drag the card: every action shows on that one spot.\"] end\n",
       "",
       "combat-actions: the drag line ignores one spot",
       expect=FREE, script=S)
mutate("Modules/Combat/Options.lua",
       "\t\t\t\"appearance.combatActionLayout\",\n\t\t\t{ \"appearance.combatActionGrow\", indent = true },\n",
       "",
       "combat-actions: the placement choice away from Move the cards",
       expect=FREE, script=S)
