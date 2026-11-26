# A Paladin blessing choice is real, and the second Paladin is not redundant.

S = "runscenarios.py"

mutate("Core.lua",
       '\t\t\tpaladin = "auto",\n',
       '\t\t\tpaladin = "kings",\n',
       "ask-blessings: a new profile pins one Paladin blessing",
       expect="ask-blessings: an invalid saved choice is repaired to Automatic",
       script=S)

mutate("Ask.lua",
       "\t\tif class == \"PALADIN\" and choice ~= \"auto\" then\n",
       "\t\tif false and class == \"PALADIN\" and choice ~= \"auto\" then\n",
       "ask-blessings: an explicit Paladin blessing is ignored",
       expect="ask-blessings: a chosen Paladin blessing is the one Manners asks for",
       script=S)

mutate("Ask.lua",
       "\t\t\t\t\tand Wearing(other, now) == false and not AskedByOtherPaladin(name, key, now)\n",
       "\t\t\t\t\tand Wearing(other, now) == false and key == preferred\n",
       "ask-blessings: the second Paladin repeats the first blessing",
       expect="ask-blessings: Automatic asks another reachable Paladin for a different blessing",
       script=S)

mutate("Options/Who.lua",
       '\t\tname = L["Blessing to ask a paladin for"],\n',
       '\t\tname = L["Ask in"],\n',
       "ask-blessings: the Paladin choice has no own control",
       expect="ask-blessings: a chosen Paladin blessing is the one Manners asks for: the blessing control does not list Automatic and this client's blessings",
       script=S)
