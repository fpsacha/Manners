# Mutation for the hunter whose only spells are Call and Revive Pet (a retail
# hunter has no aspect): Start here, Who to skip and the pet's pages follow his
# pet care, not only the class buffs (Options/Shared.lua HasPrompt).

S = "runscenarios.py"

mutate("Options/Shared.lua",
       "\tif ns.Beast and ns.Beast.KnowsCare and ns.Beast.KnowsCare() then return true end\n",
       "",
       "pet-care-pages: a hunter with only Call and Revive Pet has no prompt for the options",
       expect="menupass-self: a hunter who knows only Call and Revive Pet is shown the pet's pages", script=S)
