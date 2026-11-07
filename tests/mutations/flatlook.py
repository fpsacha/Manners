# Mutations for a flat prompt (Prompt/Panel.lua's bezel, Prompt/Text.lua's shadow
# and outline, Core.lua's defaults). Each is caught by the scenario in
# tests/scenarios/flatlook.lua that names it.

S = "runscenarios.py"

mutate("Prompt/Panel.lua",
       "\t\t\tt:SetShown(framed)\n",
       "\t\t\tt:Show()\n",
       "flatlook: the bezel is always drawn",
       expect="flatlook: the icon's frame is drawn by default and can be taken away", script=S)

mutate("Prompt/Panel.lua",
       "\t\tR.iconShade:SetShown(framed)\n",
       "\t\tR.iconShade:Show()\n",
       "flatlook: the shade under the icon is always drawn",
       expect="flatlook: the icon's frame is drawn by default and can be taken away", script=S)

mutate("Prompt/Text.lua",
       "\tlocal flat = p.textShadow == false\n",
       "\tlocal flat = false\n",
       "flatlook: the text is never flat",
       expect="flatlook: the text's shadow and outline are drawn by default and can be taken away", script=S)

mutate("Prompt/Text.lua",
       "\tlocal outline = (bare and not flat) and \"OUTLINE\" or \"\"\n",
       "\tlocal outline = bare and \"OUTLINE\" or \"\"\n",
       "flatlook: Minimal keeps its outline flat",
       expect="flatlook: the text's shadow and outline are drawn by default and can be taken away", script=S)

mutate("Core.lua",
       "\t\t\ticonFrame = true,\n",
       "\t\t\ticonFrame = false,\n",
       "flatlook: no frame by default",
       expect="flatlook: the icon's frame is drawn by default and can be taken away", script=S)

mutate("Core.lua",
       "\t\t\ttextShadow = true,\n",
       "\t\t\ttextShadow = false,\n",
       "flatlook: flat text by default",
       expect="flatlook: the text's shadow and outline are drawn by default and can be taken away", script=S)
