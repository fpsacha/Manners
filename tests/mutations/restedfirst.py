# Mutations for Sleeping bag before food and elixirs (ownBuffs.restedFirst:
# Core.lua ns.RestedComesFirst, InBag and OwnVerdict, Commands.lua, the My
# Buffs options): off by default; on, food, flasks, elixirs and scrolls wait
# while the bag is due or you lie in it, not for its cooldown alone. Each is
# caught by the scenario in tests/scenarios/restedfirst.lua that names it.

S = "runscenarios.py"

mutate("Core.lua",
       "\t\t\trestedFirst = false,\n",
       "\t\t\trestedFirst = true,\n",
       "restedfirst: on by default",
       expect="a new profile's switch is", script=S)

mutate("Core.lua",
       "\t\tif (family.consumable or family.food) and ns.RestedComesFirst(ctx) then\n",
       "\t\tif false and (family.consumable or family.food) and ns.RestedComesFirst(ctx) then\n",
       "restedfirst: food never waits for the bag",
       expect="on, both missing", script=S)

mutate("Core.lua",
       "\t\tif not (db and db.profile.ownBuffs.restedFirst == true) then return false end\n",
       "\t\tif not db then return false end\n",
       "restedfirst: the hold works with the switch off",
       expect="off, both missing", script=S)

mutate("Core.lua",
       "\t\t\t\tif spell then return true end\n\t\t\t\tif why == \"moving\" then return true end\n",
       "\t\t\t\tif why == \"moving\" then return true end\n",
       "restedfirst: the bag due holds nothing back",
       expect="on, both missing", script=S)

mutate("Core.lua",
       "\t\t\t\tif (why == \"resting\" or why == \"tried\") and held then return InBag(rest, held) end\n",
       "\t\t\t\tif (why == \"resting\" or why == \"tried\") and held then return false end\n",
       "restedfirst: lying in the bag lets food through",
       expect="on, lying in the bag", script=S)

mutate("Commands.lua",
       "\t\telseif why == \"rested\" then\n",
       "\t\telseif why == \"rested-never\" then\n",
       "restedfirst: the food's line does not say why it waits",
       expect="does not say it waits for the bag", script=S)

mutate("Modules/MyBuffs/Options.lua",
       "\t\t\t\t\tns.db.profile.ownBuffs.restedFirst = value == true\n",
       "\t\t\t\t\tns.db.profile.ownBuffs.restedFirst = true\n",
       "restedfirst: the switch cannot be turned off",
       expect="turning it off wrote nothing", script=S)

mutate("Modules/MyBuffs/Layout.lua",
       "\t\t\t\t\t{ \"who.ownRestedFirst\", indent = true },\n",
       "",
       "restedfirst: the switch not placed on the page",
       expect="who.ownRestedFirst", script=S)
