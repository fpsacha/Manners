# Mutations for the line that says who makes Manners (Options/Diagnostics.lua,
# Clicks.lua): it names the author's character and asks for nothing. Caught by
# tests/scenarios/about.lua.

S = "runscenarios.py"

mutate("Options/Diagnostics.lua",
       "\t\t\t\t\treturn L[\"Manners is made by fpsacha, who plays %s on the RP-PvP server of WoW Forever.\"]\n\t\t\t\t\t\t:format(\"|cffffffff\" .. tostring(ns.AUTHOR) .. \"|r\")\n",
       "\t\t\t\t\treturn L[\"Manners is made by fpsacha, who plays %s on the RP-PvP server of WoW Forever.\"]\n\t\t\t\t\t\t:format(\"|cffffffff\" .. \"somebody\" .. \"|r\")\n",
       "about: the line names nobody",
       expect="the line does not name the author's character", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t\"diagnostics.aboutNote\",\n",
       "",
       "about: the line on no page",
       expect="the line is not placed on the Diagnostics page", script=S)
