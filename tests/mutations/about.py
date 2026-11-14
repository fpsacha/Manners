# Mutations for the line that says who makes Manners (Options/Diagnostics.lua,
# Clicks.lua): it names the author's character and asks for nothing. Caught by
# tests/scenarios/about.lua.

S = "runscenarios.py"

mutate("Options/Diagnostics.lua",
       "\t\t\t\t\treturn L[\"Manners is made by %s, who plays on the RP-PvP server of WoW Forever.\"]\n\t\t\t\t\t\t:format(\"|cffffd100\" .. tostring(ns.AUTHOR) .. \"|r\")\n",
       "\t\t\t\t\treturn L[\"Manners is made by %s, who plays on the RP-PvP server of WoW Forever.\"]\n\t\t\t\t\t\t:format(\"|cffffd100\" .. \"somebody\" .. \"|r\")\n",
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
       "\tfooter.build:SetPoint(\"RIGHT\", footer.mid, \"RIGHT\", 0, 0)\n",
       "\tfooter.build:SetPoint(\"CENTER\", footer.mid, \"CENTER\", 0, 0)\n",
       "about: the build back in the middle, under the line",
       expect="the build is not at the right of the footer", script=S)

mutate("Options/Window/WindowChrome.lua",
       "\tfs:SetPoint(\"CENTER\", footer.mid, \"CENTER\", -BuildRoom() / 2, 0)\n",
       "\tfs:SetPoint(\"CENTER\", footer.mid, \"CENTER\", 0, 0)\n",
       "about: the line centred over the build's room",
       expect="the line is not in the middle of the room the build leaves", script=S)

mutate("Options/Window/WindowChrome.lua",
       "local FOOT_GAP, FOOT_ABOUT, FOOT_SMALLEST = 8, 13, 7\n",
       "local FOOT_GAP, FOOT_ABOUT, FOOT_SMALLEST = 8, 10, 7\n",
       "about: the line as small as it was",
       expect="the line is no bigger than the build", script=S)

mutate("Options/Diagnostics.lua",
       "\t\t\t\t\t\t:format(\"|cffffd100\" .. tostring(ns.AUTHOR) .. \"|r\")\n",
       "\t\t\t\t\t\t:format(\"|cffffffff\" .. tostring(ns.AUTHOR) .. \"|r\")\n",
       "about: the name not in gold",
       expect="the name is not in gold", script=S)

mutate("Options/Window/WindowChrome.lua",
       "\t\tif path then fs:SetFont(path, size, flags) end\n\t\tfs:SetText(about)\n",
       "\t\tfs:SetText(about)\n",
       "about: a line once shrunk stays small",
       expect="the line stayed small once it fitted again", script=S)

mutate("Locales/deDE.lua",
       "L[\"Manners is made by %s, who plays on the RP-PvP server of WoW Forever.\"] = \"Manners stammt von %s,",
       "L[\"Manners is made by %s, who plays on the RP-PvP server of WoW Forever.\"] = \"Manners stammt von fpsacha, als %s,",
       "about: a language names the account again",
       expect="the line names the account as well as the character", script=S)
