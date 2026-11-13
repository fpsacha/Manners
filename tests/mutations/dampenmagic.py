# Mutations for Dampen Magic and Amplify Magic on yourself (Buffs.lua,
# magicmod; GitHub issue #14). Caught by tests/scenarios/dampenmagic.lua.

S = "runscenarios.py"

mutate("Buffs.lua",
       "\t\t{ key = \"magicmod\", optIn = true,\n\t\t\tspells = {\n\t\t\t\t{ key = \"dampenmagic\", ranks = { 10174,",
       "\t\t{ key = \"magicmod\",\n\t\t\tspells = {\n\t\t\t\t{ key = \"dampenmagic\", ranks = { 10174,",
       "dampenmagic: on for every mage who never asked",
       expect="on a new profile, not off", script=S)

mutate("Buffs.lua",
       "\t\t\t\t{ key = \"amplifymagic\", ranks = { 10170, 10169, 8455, 1008 } },\n",
       "",
       "dampenmagic: Amplify Magic left out on Classic Era and Forever",
       expect="dampenmagic: a mage's family on Forever", script=S)

mutate("Buffs.lua",
       "\t\t\t\t{ key = \"dampenmagic\", ranks = { 33944, 10174,",
       "\t\t\t\t{ key = \"dampenmagic\", ranks = { 10174,",
       "dampenmagic: Burning Crusade's sixth rank forgotten",
       expect="dampenmagic: a mage's family on Forever", script=S)

mutate("Buffs.lua",
       "\t\t{ 600, 10174, 10173, 8451, 8450, 604 }, -- Dampen Magic (10 min)\n\t\t{ 600, 10170, 10169, 8455, 1008 }, -- Amplify Magic (10 min)\n\t\t{ 3600, 1302303,",
       "\t\t{ 3600, 1302303,",
       "dampenmagic: Forever has no length for it",
       expect="its length is not ten minutes", script=S)
