# Mutations for foods that can be ticked under Never remind me about (Buffs.lua
# OwnLeaveable, Core.lua AutoAnswer and the defaults). Each is caught by the
# scenario in tests/scenarios/foodleave.lua that names it.

S = "runscenarios.py"

mutate("Core.lua",
       "\t\t\t\tif not LeftOut(spell) then\n\t\t\t\t\tlocal ready, why = ScrollReady(spell)\n",
       "\t\t\t\tif true then\n\t\t\t\t\tlocal ready, why = ScrollReady(spell)\n",
       "foodleave: Automatic takes a food that is ticked",
       expect="foodleave: a food ticked under Never remind me about is passed over", script=S)

mutate("Buffs.lua",
       "\t\tor family.tank or (family.bagged and not family.food))\n",
       "\t\tor family.tank or family.bagged)\n",
       "foodleave: food cannot be ticked",
       expect="foodleave: a scroll is still not something that can be ticked", script=S)

mutate("Buffs.lua",
       "\t\tor family.tank or (family.bagged and not family.food))\n",
       "\t\tor family.tank)\n",
       "foodleave: a scroll can be ticked too",
       expect="foodleave: a scroll is still not something that can be ticked", script=S)

mutate("Core.lua",
       "\t\tif ns.OwnLeaveable(family) then\n\t\t\tfor _, spell in ipairs(family.spells) do defaults",
       "\t\tif ns.OwnLeaveable(family) and not family.food then\n\t\t\tfor _, spell in ipairs(family.spells) do defaults",
       "foodleave: no defaults for the ticks of a food",
       expect="foodleave: every food has a tick, false by default", script=S)
