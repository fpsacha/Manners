# Mutations for the line that says who makes Manners (Options/Diagnostics.lua,
# Clicks.lua): it names the author's character and asks for nothing. Caught by
# tests/scenarios/about.lua.

S = "runscenarios.py"

mutate("Options/Diagnostics.lua",
       "\t\t\t\t\treturn L[\"Manners is made by fpsacha, who plays %s on the RP-PvP server of WoW Forever.\"]\n\t\t\t\t\t\t:format(\"|cffffffff\" .. tostring(ns.AUTHOR) .. \"|r\")\n",
       "\t\t\t\t\treturn L[\"Manners is made by fpsacha, who plays %s on the RP-PvP server of WoW Forever.\"]\n\t\t\t\t\t\t:format(\"|cffffffff\" .. \"somebody\" .. \"|r\")\n",
       "about: the line names nobody",
       expect="the line does not name the author's character", script=S)

mutate("Options/Window/WindowChrome.lua",
       "\tfs:SetShown(about ~= \"\")\n",
       "\tfs:SetShown(false)\n",
       "about: the line in no footer",
       expect="the footer does not say who makes Manners", script=S)

mutate("Options/Window/WindowChrome.lua",
       "\t\tif path and wide > room then\n",
       "\t\tif false then\n",
       "about: a long line left to run under the footer's buttons",
       expect="a long line is", script=S)

mutate("Options/Window/WindowChrome.lua",
       "\t\tfooter.build:SetPoint(\"CENTER\", footer.mid, \"CENTER\", 0, FOOT_LINE / 2)\n",
       "\t\tfooter.build:SetPoint(\"CENTER\", footer.mid, \"CENTER\", 0, 0)\n",
       "about: the line drawn over the build",
       expect="the line is not under the build", script=S)

mutate("Options/Window/WindowChrome.lua",
       "\t\tif path then fs:SetFont(path, size, flags) end\n\t\tfs:SetText(about)\n",
       "\t\tfs:SetText(about)\n",
       "about: a line once shrunk stays small",
       expect="the line stayed small once it fitted again", script=S)
