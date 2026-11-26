# Mutations for Blessing to ask a paladin for (GitHub issue 57): Ask.lua's Want
# asks for the blessing chosen in ask.blessing, and AskClamp puts back a choice
# that is no blessing. Caught by tests/scenarios/ask-blessing.lua.

S = "runscenarios.py"

mutate("Ask.lua",
       "\t\tif type(pick) == \"string\" and pick ~= \"auto\" and ns.FindBuff(class, pick) then key = pick end\n",
       "",
       "ask-blessing: the chosen blessing ignored",
       expect="ask-blessing: a druid who chose Might asks a paladin for Might", script=S)

mutate("Ask.lua",
       "\tif ask.blessing ~= \"auto\" and not Ask.Blessings()[ask.blessing] then ask.blessing = \"auto\" end\n",
       "",
       "ask-blessing: a choice of no blessing kept",
       expect="ask-blessing: a choice that is no blessing goes back to Automatic", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t{ \"who.askBlessing\", indent = true },\n",
       "",
       "ask-blessing: the choice drawn nowhere",
       expect="ask-blessing: a druid who chose Might asks a paladin for Might", script=S)
