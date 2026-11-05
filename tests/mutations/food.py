# Mutations for buff food on WoW Forever (tests/scenarios/food.lua): the
# family in Buffs.lua's camelot set, the reading in Core.lua (ReadFood), the
# top-up in OwnVerdict and the order in Queue.lua. Each is caught by the
# scenario that names it.

S = "runscenarios.py"

# --- the family (Buffs.lua) ---

mutate("Buffs.lua",
       "\t\tAddEnhancements(list, class, { FOOD })\n",
       "",
       "food: not in Forever's set",
       expect="food: a rogue with food and no Well Fed is offered it", script=S)

mutate("Buffs.lua",
       "\t\t{ 21072, 10, 1249504, 1249520 }, -- Smoked Sagefish\n",
       "\t\t{ 21072, 50, 1249504, 1249520 }, -- Smoked Sagefish\n",
       "food: a level read wrong",
       expect="food: a rogue with food and no Well Fed is offered it", script=S)

# --- the reading (Core.lua) ---

mutate("Core.lua",
       "\t\tif find(family.eating) then return true end\n",
       "",
       "food: a meal under way read as hungry",
       expect="food: nothing offered while Well Fed or eating (eating)", script=S)

mutate("Core.lua",
       "\t\tlocal id, aura = find(family.buffs)\n",
       "\t\tlocal id, aura = nil, nil\n",
       "food: Well Fed never read",
       expect="food: nothing offered while Well Fed or eating (its own buff)", script=S)

mutate("Core.lua",
       "\t\t\tif not upSpell and not family.food then return nil, true, left, \"up\" end\n",
       "\t\t\tif not upSpell then return nil, true, left, \"up\" end\n",
       "food: no top-up when nobody can tell which food is on",
       expect="food: Well Fed running low is topped up", script=S)

mutate("Core.lua",
       "\t\t\tfor _, spell in ipairs((family.enhance or family.food) and {} or family.spells) do\n",
       "\t\t\tfor _, spell in ipairs(family.enhance and {} or family.spells) do\n",
       "food: every food probed at load",
       expect="the probe asked the client for the names of", script=S)

# --- the order (Queue.lua) ---

mutate("Queue.lua",
       "\t\tif family.food then\n\t\t\tfood = family\n",
       "\t\tif false then\n\t\t\tfood = family\n",
       "food: offered ahead of another own family",
       expect="food: offered after tracking, listed after it", script=S)

mutate("Queue.lua",
       "PRIORITY.food = 4\n",
       "PRIORITY.food = 1.75\n",
       "food: sorted with your other buffs",
       expect="food: a rogue with food and no Well Fed is offered it", script=S)
