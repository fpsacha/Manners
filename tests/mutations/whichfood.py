# Mutations for Which food (ownBuffs.foodOrder; Core.lua, FoodByChoice and
# AutoAnswer; Options/Who.lua; Layout.lua). Caught by the scenarios "wellfed:
# Which food picks the best, the weakest first, or one by name" and "wellfed:
# the Which food choice lists the foods, reads and writes, and is repaired".

S = "runscenarios.py"

mutate("Core.lua",
       "\t\t\tfor n = #spells, 1, -1 do\n\t\t\t\tlocal spell = spells[n]\n",
       "\t\t\tfor n = 1, #spells do\n\t\t\t\tlocal spell = spells[n]\n",
       "whichfood: the weakest first picks the best",
       expect="the weakest first offered", script=S)

mutate("Core.lua",
       "\t\tif family.food then\n\t\t\tlocal chosen = FoodByChoice(family)\n",
       "\t\tif false then\n\t\t\tlocal chosen = FoodByChoice(family)\n",
       "whichfood: the choice never read",
       expect="the weakest first offered", script=S)

mutate("Core.lua",
       "\t\tif named and named.family == family and not LeftOut(named) and ScrollReady(named) then return named end\n",
       "\t\tif named and named.family == family and ScrollReady(named) then return named end\n",
       "whichfood: a food named is offered though ticked to leave out",
       expect="the food named is ticked to leave out", script=S)

mutate("Core.lua",
       "\t\tif named and named.family == family and not LeftOut(named) and ScrollReady(named) then return named end\n",
       "\t\tif named and named.family == family and not LeftOut(named) then return named end\n",
       "whichfood: a food named that is not in the bags",
       expect="the food named is not in the bags", script=S)

mutate("Core.lua",
       "\t\t\t\tif not LeftOut(spell) and ScrollReady(spell) then return spell end\n",
       "\t\t\t\tif ScrollReady(spell) then return spell end\n",
       "whichfood: the weakest ignores what is ticked to leave out",
       expect="the weakest ticked under Never remind me about", script=S)

mutate("Core.lua",
       "\t\t\tfoodOrder = \"best\",\n",
       "\t\t\tfoodOrder = \"weakest\",\n",
       "whichfood: the weakest by default",
       expect="by default the order is", script=S)

mutate("Core.lua",
       "\t\t\toneOf(profile.ownBuffs, \"foodOrder\", { best = true, weakest = true }, \"best\")\n",
       "\t\t\tlocal _ = 0\n",
       "whichfood: a damaged order kept",
       expect="a damaged order was left", script=S)

mutate("Options/Who.lua",
       "\t\t\t\t\tns.db.profile.ownBuffs.foodOrder = value\n",
       "",
       "whichfood: picking a food writes nothing",
       expect="picking a food wrote", script=S)

mutate("Options/Who.lua",
       "\t\t\t\t\t\t\t\tif spell.key == order and ns.OwnSpellKnown(spell) then return order end\n",
       "\t\t\t\t\t\t\t\tif spell.key == order then return order end\n",
       "whichfood: a food out of the bags still read as picked",
       expect="a food not in the bags reads", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t{ \"who.ownFoodChoice\", indent = true },\n",
       "",
       "whichfood: the choice not placed on the page",
       expect="ownFoodChoice", script=S)
