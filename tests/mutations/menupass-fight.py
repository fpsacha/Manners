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
       "\t\"prompt.breakFree\", \"beast.fightMend\", \"prompt.cureFight\", \"prompt.cureFightEach\",\n"
       "\t\"prompt.cureFightMods\", \"prompt.reactiveWards\", \"prompt.fightButtons\",\n",
       "\t\"beast.fightMend\", \"prompt.cureFight\", \"prompt.cureFightEach\",\n"
       "\t\"prompt.cureFightMods\", \"prompt.reactiveWards\", \"prompt.fightButtons\",\n",
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

mutate("Options/Look.lua",
       "\t\t\t\thidden = function() return not InCombatLockdown() or not (ns.WindowUI and ns.WindowUI.Shown and ns.WindowUI.Shown()) end,\n",
       "\t\t\t\thidden = function() return not InCombatLockdown() end,\n",
       "menupass-fight: the dialog shows the fight's combat line twice",
       expect="menupass-fight: the dialog shows the combat line once", script=S)

mutate("Options/Say.lua",
       "\t\t\t\thidden = function() return not InCombatLockdown() or not (ns.WindowUI and ns.WindowUI.Shown and ns.WindowUI.Shown()) end,\n",
       "\t\t\t\thidden = function() return not InCombatLockdown() end,\n",
       "menupass-fight: the dialog shows Quiet times' combat line twice",
       expect="menupass-fight: the dialog shows the combat line once", script=S)

mutate("Core.lua",
       "\tif item and UI.Hidden(item) then return end\n",
       "",
       "menupass-fight: a tooltip points at a control that is not shown",
       expect="menupass-fight: a tooltip points only at a control that is shown", script=S)

mutate("Options/Look.lua",
       "\t\thidden = function()\n\t\t\treturn not HasPrompt() and ns.caps.breakFree == nil\n\t\t\t\tand not (ns.MendPet and ns.MendPet.KnowsMend())\n\t\tend,\n",
       "\t\thidden = function() return not HasPrompt() end,\n",
       "menupass-fight: Look is shut to a Forsaken character with no prompt",
       expect="menupass-fight: a Forsaken rogue with no prompt can reach", script=S)
