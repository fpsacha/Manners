# The Diagnostics tab (Options.lua, BuildDiagnosticsTab). Each fault is caught
# by the scenario in tests/scenarios/options-diagnostics.lua that names it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# --- Messages in chat ---

# The verbose switch no longer saved.
mutate("Options/Start.lua",
       "\t\t\t\tset = function(_, v) ns.db.profile.verbose = v end,\n",
       "\t\t\t\tset = function() end,\n",
       "diagnostics: verbose not saved",
       expect="the verbose switch does not write profile.verbose", script=S)

# The click log no longer saved.
mutate("Options/Diagnostics.lua",
       "\t\t\t\tset = function(_, v) ns.db.profile.debugClicks = v end,\n",
       "\t\t\t\tset = function() end,\n",
       "diagnostics: click log not saved",
       expect="the click log does not write profile.debugClicks", script=S)

# --- What Manners can see ---

# The class shown as the client's token, MAGE, in every language.
mutate("Options/Diagnostics.lua",
       "\t\t\t\t\tlocal shown = (names and class and names[class]) or class\n",
       "\t\t\t\t\tlocal shown = class\n",
       "diagnostics: class not localized",
       expect="the class is not given in the client's words", script=S)

# Every buff said to be visible, secret or not.
mutate("Options/Diagnostics.lua",
       "(info and info.readable) and L[\"can see who has it: |cff00ff00yes|r\"]",
       "true and L[\"can see who has it: |cff00ff00yes|r\"]",
       "diagnostics: secret buffs read yes",
       expect="a buff Manners cannot see reads no", script=S)

# The footnote dropped.
mutate("Options/Diagnostics.lua",
       "\t\t\t\t\t\t.. L[\"Where Manners cannot see a buff, people are still offered, but some may already have it.\"]\n",
       "\t\t\t\t\t\t.. \"\"\n",
       "diagnostics: footnote dropped",
       expect="the footnote is missing", script=S)

# The distance line with no measurement in it.
mutate("Options/Diagnostics.lua",
       "L[\"Passer-by distance: %s\"]:format(tostring(ns.ProximitySummary()))",
       "L[\"Passer-by distance: %s\"]:format(\"\")",
       "diagnostics: distance line empty",
       expect="the line does not give the measurement", script=S)

# The distance line shown to a warrior, whose shout never reaches a passer-by.
mutate("Options/Diagnostics.lua",
       "\t\t\t\thidden = OnlyReachesGroup,\n"
       "\t\t\t\tname = function()\n"
       "\t\t\t\t\treturn \"|cff888888\"\n"
       "\t\t\t\t\t\t.. L[\"Passer-by distance: %s\"]",
       "\t\t\t\thidden = false,\n"
       "\t\t\t\tname = function()\n"
       "\t\t\t\t\treturn \"|cff888888\"\n"
       "\t\t\t\t\t\t.. L[\"Passer-by distance: %s\"]",
       "diagnostics: warrior shown distance",
       expect="a warrior is not shown passer-by distance", script=S)

# --- Errors this session ---

# The no-errors line hidden whether or not anything went wrong.
mutate("Options/Diagnostics.lua",
       "\t\t\t\thidden = function() return #ns.errors > 0 end,\n",
       "\t\t\t\thidden = function() return true end,\n",
       "diagnostics: no-errors line never shown",
       expect="no errors, and the page does not say so", script=S)
