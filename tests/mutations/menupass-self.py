# Mutations for the My own buffs and My pet pages: tests/scenarios/menupass-self.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts one rule back and
# names the scenario that objects.

S = "runscenarios.py"

mutate("Options/Advanced.lua",
       "\"filters.proximity\", \"filters.restingOnly\", \"groupBuffs.use\",",
       "\"filters.proximity\", \"filters.restingOnly\", \"ownBuffs.pick\", \"groupBuffs.use\",",
       "menupass-self: Who to buff's reset wipes the own-buff picks again",
       expect="menupass-self: Who to buff's reset leaves", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t{ \"who.ownApartKey\", indent = true },\n",
       "",
       "menupass-self: the consumables button's key is not placed",
       expect="menupass-self: the consumables button's key", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t{ \"who.beastMend\", indent = true },\n\t\t\t\t\t{ \"who.beastMendFight\", indent = true },\n\t\t\t\t\t{ \"who.beastLeaveFood\", indent = true },\n",
       "\t\t\t\t\t{ \"who.beastMend\", indent = true },\n\t\t\t\t\t{ \"who.beastLeaveFood\", indent = true },\n\t\t\t\t\t{ \"who.beastMendFight\", indent = true },\n",
       "menupass-self: the Mend Pet fight switch is moved away from Mend Pet",
       expect="menupass-self: Mend Pet's two switches", script=S)

mutate("Options/Window/Layout.lua",
       "renamedFolds = { [\"who.myselfPetMoments\"] = \"pet.moments\" },",
       "renamedFolds = {},",
       "menupass-self: a fold's saved state is lost when it moves page",
       expect="menupass-self: an open pet fold stays open", script=S)
