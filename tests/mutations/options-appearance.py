# The Look tab (Options.lua, BuildLookTab). Each fault is caught by the
# scenario in tests/scenarios/options-appearance.lua that names it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# --- Quick position ---

# The default place not marked as the default, so nothing says it is the way
# back now that Reset position is gone.
mutate("Options.lua",
       "\t\t\t\t-- so it can be shown but never picked.\n"
       "\t\t\t\tvalues = function()\n"
       "\t\t\t\t\tlocal out = {}\n"
       "\t\t\t\t\tfor _, preset in ipairs(ns.POSITION_PRESETS) do\n"
       "\t\t\t\t\t\tout[preset.key] = preset.key == \"bars\"\n"
       "\t\t\t\t\t\t\tand L[\"Above the action bars (default)\"] or preset.name\n",
       "\t\t\t\t-- so it can be shown but never picked.\n"
       "\t\t\t\tvalues = function()\n"
       "\t\t\t\t\tlocal out = {}\n"
       "\t\t\t\t\tfor _, preset in ipairs(ns.POSITION_PRESETS) do\n"
       "\t\t\t\t\t\tout[preset.key] = preset.name\n",
       "look: default place unmarked",
       expect="the default place is not marked", script=S)

# Where I dragged it offered while the prompt sits on a preset.
mutate("Options.lua",
       "\t\t\t\t-- so it can be shown but never picked.\n"
       "\t\t\t\tvalues = function()\n"
       "\t\t\t\t\tlocal out = {}\n"
       "\t\t\t\t\tfor _, preset in ipairs(ns.POSITION_PRESETS) do\n"
       "\t\t\t\t\t\tout[preset.key] = preset.key == \"bars\"\n"
       "\t\t\t\t\t\t\tand L[\"Above the action bars (default)\"] or preset.name\n"
       "\t\t\t\t\tend\n"
       "\t\t\t\t\tif not ns.CurrentPositionPreset() then out.custom = L[\"Where I dragged it\"] end\n",
       "\t\t\t\t-- so it can be shown but never picked.\n"
       "\t\t\t\tvalues = function()\n"
       "\t\t\t\t\tlocal out = {}\n"
       "\t\t\t\t\tfor _, preset in ipairs(ns.POSITION_PRESETS) do\n"
       "\t\t\t\t\t\tout[preset.key] = preset.key == \"bars\"\n"
       "\t\t\t\t\t\t\tand L[\"Above the action bars (default)\"] or preset.name\n"
       "\t\t\t\t\tend\n"
       "\t\t\t\t\tout.custom = L[\"Where I dragged it\"]\n",
       "look: Where I dragged it always offered",
       expect="Where I dragged it is offered while the prompt sits on a preset", script=S)

# Where I dragged it left out of the order, so it sorts wherever its label falls.
mutate("Options.lua",
       "\t\t\t\t\tif not ns.CurrentPositionPreset() then out[#out + 1] = \"custom\" end\n",
       "",
       "look: Where I dragged it not last",
       expect="Where I dragged it is not last", script=S)

# A dragged prompt reads as nothing: the box goes blank.
mutate("Options.lua",
       "\t\t\t\t\treturn out\n\t\t\t\tend,\n"
       "\t\t\t\tget = function() return ns.CurrentPositionPreset() or \"custom\" end,\n",
       "\t\t\t\t\treturn out\n\t\t\t\tend,\n"
       "\t\t\t\tget = function() return ns.CurrentPositionPreset() end,\n",
       "look: dragged prompt reads blank",
       expect="a dragged prompt reads as", script=S)

# Picking Where I dragged it treated as a place.
mutate("Options.lua",
       "\t\t\t\t\tif value ~= \"custom\" then ns.ApplyPositionPreset(value) end\n",
       "\t\t\t\t\tns.ApplyPositionPreset(value == \"custom\" and \"centre\" or value)\n",
       "look: Where I dragged it moves the prompt",
       expect="picking Where I dragged it moved the prompt", script=S)

# Where it sits (once Quick position) back down under Size, where it sat before.
mutate("Options.lua",
       ":format(Ref(L[\"Exact position\"], TAB.advanced))\n"
       "\t\t\t\tend,\n\t\t\t\torder = 3,\n",
       ":format(Ref(L[\"Exact position\"], TAB.advanced))\n"
       "\t\t\t\tend,\n\t\t\t\torder = 15,\n",
       "look: Quick position under Size",
       expect="Where it sits is not at the top of the tab", script=S)

# --- Style ---

# Marker colour greyed out instead of hidden: a picker on screen with no say.
mutate("Options.lua",
       "\t\t\t\thidden = function() return P().accentByReason end,\n",
       "\t\t\t\tdisabled = function() return P().accentByReason end,\n",
       "look: Marker colour greyed rather than hidden",
       expect="Marker colour is greyed out rather than hidden", script=S)

# Colour marker back above the colours, where it sat before.
mutate("Options.lua",
       "\t\t\t\tdesc = L[\"Framed panels have no stripe.\"],\n"
       "\t\t\t\torder = 26,\n",
       "\t\t\t\tdesc = L[\"Framed panels have no stripe.\"],\n"
       "\t\t\t\torder = 22.5,\n",
       "look: Colour marker out of order",
       expect="is out of order", script=S)

# The grey target sentence back on Colour marker by reason.
mutate("Options.lua",
       "\t\t\t\t\treturn L[\"A colour that shows why this person is on the prompt.\"] .. \"\\n\\n\" .. colours\n",
       "\t\t\t\t\treturn L[\"A colour that shows why this person is on the prompt.\"] .. \"\\n\\n\" .. colours"
       " .. \"\\n\\n|cff888888Whoever I have targeted comes first.|r\"\n",
       "look: grey target sentence kept",
       expect="still carries the grey target sentence", script=S)

# --- dropdown order ---

# Colour marker sorted alphabetically: Both, None, Ring, Stripe.
mutate("Options.lua",
       "\t\t\t\tsorting = { \"icon\", \"stripe\", \"both\", \"off\" },\n",
       "",
       "look: Colour marker unsorted",
       expect="Colour marker lists", script=S)

# The flash sorted alphabetically: Flash once, None, Pulse.
mutate("Options.lua",
       "\t\t\t\tsorting = { \"pulse\", \"once\", \"off\" },\n",
       "",
       "look: flash unsorted",
       expect="Flash when someone buffs me lists", script=S)

# --- the sound ---

# None offered as a sound beside the switch that turns sound off.
mutate("Options.lua",
       "\t\t\t\t\t\tif key ~= \"None\" or chosen == \"None\" then list[key] = key end\n",
       "\t\t\t\t\t\tlist[key] = key\n",
       "look: None offered",
       expect="None is offered as a sound", script=S)

# None left out even when it is the stored value: the box reads "(not loaded)".
mutate("Options.lua",
       "\t\t\t\t\t\tif key ~= \"None\" or chosen == \"None\" then list[key] = key end\n",
       "\t\t\t\t\t\tif key ~= \"None\" then list[key] = key end\n",
       "look: stored None lost",
       expect="a stored None leaves the sound box reading", script=S)

# --- pointers ---

# Text colour no longer names the switch that overrides it.
mutate("Options.lua",
       "\t\t\t\t\t.. \" \" .. Ref(L[\"Colour names by class\"], TAB.appearance),\n",
       ",\n",
       "look: Text colour points nowhere",
       expect="Text colour does not end by pointing at Colour names by class", script=S)

# The cooldown sweep silent about the combat setting that stills it.
mutate("Options.lua",
       "\t\t\t\t\t.. \"|cffffd100\" .. L[\"Keep the prompt dim and still in combat\"] .. \"|r\",\n",
       "\t\t\t\t\t.. L[\"Keep the prompt dim and still in combat\"],\n",
       "look: cooldown points nowhere",
       expect="Show the global cooldown does not point at Keep the prompt dim", script=S)

# Look's text section silent about where the wording is.
mutate("Options.lua",
       "\t\t\t\t\t.. L[\"Change what the prompt says: %s.\"]:format(Ref(L[\"Prompt wording\"], TAB.advanced))\n",
       "\t\t\t\t\t.. L[\"Change what the prompt says: %s.\"]:format(L[\"Prompt wording\"])\n",
       "look: text section points nowhere",
       expect="Text does not point at Prompt wording", script=S)

# Where it sits silent about how to put the prompt back.
mutate("Options.lua",
       "\t\t\t\t\tlocal text = L[\"Pick Above the action bars to put it back where it started.\"]\n"
       "\t\t\t\t\t\t.. \" \" .. L[\"Dragging",
       "\t\t\t\t\tlocal text = L[\"Dragging",
       "look: no way back named",
       expect="posPreset says", script=S)

# The second line's height a constant rather than worked out from the font.
mutate("Options.lua",
       "\t\t\t\t\treturn L[\"Needs a prompt at least %d pixels tall.\"]:format(ns.TwoLineHeight(P().fontSize))\n",
       "\t\t\t\t\treturn L[\"Needs a prompt at least %d pixels tall.\"]:format(39)\n",
       "look: second line height constant",
       expect="the second line's height does not follow the font", script=S)
