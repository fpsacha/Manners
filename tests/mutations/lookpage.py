# Mutations for the Look page as a whole: tests/scenarios/lookpage.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts back a mistake the
# picker's tabs, the trying of a look under the pointer, the pictures that
# follow Earlier art or the chosen look's own settings could plausibly make,
# and names the scenario that objects.

T = "Options/Window/WidgetsTheme.lua"
LOOKS = "Looks/Looks.lua"
LOOK = "Options/Look.lua"
LAYOUT = "Options/Window/Layout.lua"
S = "runscenarios.py"

# --- the tabs ---------------------------------------------------------------

mutate(T, "local TABS = { \"mine\", \"all\", \"minimal\", \"classic\", \"themed\", \"class\" }\n",
       "local TABS = { \"all\", \"mine\", \"minimal\", \"classic\", \"themed\", \"class\" }\n",
       "lookpage: For my class is not the first tab",
       expect="lookpage: a mage's tabs", script=S)

mutate(LOOKS, "\t\tif Looks.FOR_CLASS[key] == class then out[#out + 1] = key end\n",
       "\t\tif Looks.FOR_CLASS[key] then out[#out + 1] = key end\n",
       "lookpage: For my class holds every class look",
       expect="For my class holds", script=S)

mutate(T, "\tif tab == \"mine\" then return mine[key] == true end\n",
       "\tif tab == \"mine\" then return true end\n",
       "lookpage: For my class shows every look",
       expect="For my class holds", script=S)

mutate(T, "\t\tb.shown = n > 0\n", "\t\tb.shown = true\n",
       "lookpage: For my class shown with nothing in it",
       expect="For my class is shown with nothing in it", script=S)

mutate(T, "\t\tif not (row.tab and (row.counts[row.tab] or 0) > 0) then\n",
       "\t\tif true then\n",
       "lookpage: the tab chosen is forgotten at the next paint",
       expect="lookpage: the tab chosen is kept", script=S)

# --- trying a look ------------------------------------------------------------

mutate(T, "\tp.style = card.key\n\tRestyle()\nend\n", "\tp.style = card.key\nend\n",
       "lookpage: the pointer on a card does not restyle the prompt",
       expect="the pointer on Frost Mage left the prompt", script=S)

mutate(T, "\tLook(card)\n\tif card.trying then EndTrial(true) end\nend\n", "\tLook(card)\nend\n",
       "lookpage: leaving a card leaves its look on the prompt",
       expect="after the pointer left", script=S)

mutate(T, "\tif card.trying then EndTrial(false) end\n", "",
       "lookpage: a click on the card tried is undone when the pointer leaves",
       expect="clicked and left", script=S)

mutate(T, "\tcard.hover = false\n\tif card.trying then EndTrial(true) end\n", "\tcard.hover = false\n",
       "lookpage: a card put away leaves its look on",
       expect="a card put away left its look on", script=S)

mutate(T, "\t\tif win and win.HookScript then win:HookScript(\"OnHide\", away) end\n", "",
       "lookpage: the window shut keeps the look tried",
       expect="the window shut on a tried look", script=S)

mutate(T, "\t\tevents:RegisterEvent(\"PLAYER_REGEN_DISABLED\")\n", "",
       "lookpage: a fight begins on the look tried",
       expect="a fight began on a tried look", script=S)

mutate(T, "\t\tevents:RegisterEvent(\"PLAYER_LOGOUT\")\n", "",
       "lookpage: a look tried is saved at logout",
       expect="logged out with a tried look saved", script=S)

mutate(T, "\tif not (p and card.key) or InCombatLockdown() or W.Off(card.row) then return end\n",
       "\tif not (p and card.key) or W.Off(card.row) then return end\n",
       "lookpage: the pointer tries a look in a fight",
       expect="the pointer in a fight", script=S)

mutate(T, "\tif InCombatLockdown() then\n\t\treturn \"|cffffd100\"",
       "\tif false then\n\t\treturn \"|cffffd100\"",
       "lookpage: the page does not say looks wait for the fight",
       expect="in a fight the line under the tabs", script=S)

# --- the pictures -------------------------------------------------------------

mutate(LOOKS, "\tif Earlier(key) then return \"Interface\\\\AddOns\\\\Manners\\\\Textures\\\\Previews\\\\Preview_\" .. key .. \"_earlier\" end\n", "",
       "lookpage: the cards keep the painted picture under Earlier art",
       expect="lookpage: the cards' pictures follow Earlier art", script=S)

mutate(LOOKS, "\tif Earlier(key) then return Looks.previewIconEarlier[key] end\n", "",
       "lookpage: the icon is laid where the painted picture has it under Earlier art",
       expect="lookpage: the cards' pictures follow Earlier art", script=S)

mutate(LOOKS, "\tif Earlier(key) then return Looks.previewTextEarlier[key] end\n", "",
       "lookpage: the words are laid where the painted picture has them under Earlier art",
       expect="lookpage: the cards' pictures follow Earlier art", script=S)

mutate(LOOKS, "data[key] ~= nil and not look.paintedOnly\n", "data[key] ~= nil\n",
       "lookpage: a plain look is said to have an earlier art",
       expect="lookpage: the cards' pictures follow Earlier art", script=S)

mutate("tools/make_look_previews.py",
       "            if ns.Looks.HasEarlierArt and ns.Looks.HasEarlierArt(key) then earlier[#earlier + 1] = key end\n", "",
       "lookpage: the previews tool draws no earlier art",
       expect="theme-picker: the pictures were drawn from the looks as they are now", script=S)

mutate(T, "\t\t\tcard.newTag:SetShown(card.isNew)\n", "\t\t\tcard.newTag:SetShown(true)\n",
       "lookpage: every card is marked New",
       expect="is marked New", script=S)

# --- the chosen look's own settings -------------------------------------------

mutate(LOOK, "\t\t\t\t\treturn L[\"%s: its settings\"]:format((ns.Looks.Card(P().style or \"glass\")))\n",
       "\t\t\t\t\treturn L[\"%s: its settings\"]:format((ns.Looks.Card(\"glass\")))\n",
       "lookpage: the look's settings are headed Glass whatever the look",
       expect="the section is headed", script=S)

mutate(LAYOUT, "\t\t\t\treturn L[\"%s always rounds its icon.\"]:format((ns.Looks.Card(p.style)))\n",
       "\t\t\t\treturn nil\n",
       "lookpage: the round icon greys with no word of why",
       expect="the round icon greys with no word of why", script=S)

mutate(LOOK, "\t\t\t\thidden = function() return not ns.Looks.HasEarlierArt(P().style) end,\n\t\t\t\tget = pGet,\n",
       "\t\t\t\tget = pGet,\n",
       "lookpage: Earlier art offered on a look with none",
       expect="Earlier art is offered on", script=S)

mutate(LOOK, "\t\t\t\t\t\tlook = ns.Looks.KeyDefault(P().style) and L[\"As the look has it (shown)\"] or L[\"As the look has it (hidden)\"],\n",
       "\t\t\t\t\t\tlook = ns.Looks.KeyDefault(P().style) and L[\"As the look has it (hidden)\"] or L[\"As the look has it (shown)\"],\n",
       "lookpage: the key's first choice says the opposite of what the look does",
       expect="does not say what Frost Mage does", script=S)

mutate(LOOK, "\t\t\t\thidden = function() return not ns.Looks.DrawsKey(P().style) end,\n", "",
       "lookpage: Show my key offered on a look that draws none",
       expect="Show my key is offered on", script=S)

mutate(LOOK, "\t\t\t\thidden = function() return P().style ~= \"glass\" end,\n", "",
       "lookpage: Glass's gryphons offered on every look",
       expect="Glass's gryphons are offered on Frost Mage", script=S)
