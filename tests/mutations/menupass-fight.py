# Mutations for the In a fight page: tests/scenarios/menupass-fight.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts one rule back and
# names the scenario that objects.

S = "runscenarios.py"

mutate("Options/Window/Layout.lua",
       "fight = \"appearance.fightCombatNotice\", ",
       "",
       "menupass-fight: strip.combat has no line for In a fight",
       expect="menupass-fight: in combat the page says", script=S)

mutate("Options/Advanced.lua",
       "\t\"prompt.breakFree\", \"beast.fightMend\", \"prompt.cureFight\", \"prompt.fightButtons\",\n",
       "\t\"beast.fightMend\", \"prompt.cureFight\", \"prompt.fightButtons\",\n",
       "menupass-fight: RESET.fight loses prompt.breakFree",
       expect="menupass-fight: In a fight's reset", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t\"appearance.noSound\",\n",
       "\t\t\t\t\t\"appearance.noSound\",\n\t\t\t\t\t\"appearance.breakFree\",\n",
       "menupass-fight: the Will of the Forsaken switch is on Look's attention section too",
       expect="menupass-fight: everything about a fight", script=S)

mutate("Options/Window/WindowChrome.lua",
       "\tif side.bottom and side.bottom > room then\n",
       "\tif false then\n",
       "menupass-fight: the sidebar never goes compact",
       expect="menupass-fight: the sidebar fits", script=S)
