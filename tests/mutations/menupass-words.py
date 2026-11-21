# Mutations for the plain-English labels and the units:
# tests/scenarios/menupass-words.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts one rule back and
# names the scenario that objects.

S = "runscenarios.py"

mutate("Options/Advanced.lua",
       "\t\t\t\tname = L[\"Look for people every\"],\n",
       "\t\t\t\tname = L[\"Check for people every (seconds)\"],\n",
       "menupass-words: the scan label says its unit in brackets again",
       expect="menupass-words: no label says its unit", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t[\"when.manaFloor\"] = { kind = \"percent\", zero = L[\"Off\"] },\n",
       "",
       "menupass-words: the mana floor box loses its unit",
       expect="menupass-words: every slider with a unit shows it", script=S)

mutate("Options/Advanced.lua",
       "\t\t\t\tdesc = L[\"In seconds.\"] .. \" \" .. L[\"Lower reacts faster and uses a little more CPU.\"],\n",
       "\t\t\t\tdesc = L[\"Lower reacts faster and uses a little more CPU.\"],\n",
       "menupass-words: the scan tooltip loses its unit",
       expect="menupass-words: a label that lost its unit", script=S)
