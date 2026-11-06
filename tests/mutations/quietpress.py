# Mutations for an empty press and the chat lines (Prompt/Press.lua,
# ExplainEmptyPress). Each is caught by the scenario in
# tests/scenarios/quietpress.lua that names it.

S = "runscenarios.py"

mutate("Prompt/Press.lua",
       "\tif db and db.verbose == false then return not R.button:IsShown() end\n",
       "",
       "quietpress: an empty press always says why",
       expect="quietpress: with the chat lines off, the prompt's key says nothing", script=S)

mutate("Prompt/Press.lua",
       "\tif db and db.verbose == false then return not R.button:IsShown() end\n",
       "\tif true then return not R.button:IsShown() end\n",
       "quietpress: an empty press never says why",
       expect="quietpress: with the chat lines on, a press on an empty prompt says why", script=S)
