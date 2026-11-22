# Mutations for "Food still offered outside dungeons and raids" (GitHub issue 37):
# Core.lua's OwnItemsWaitForDungeon and OwnVerdict, Options/Who.lua's switch, the
# layout slot and the page's reset. Each is caught by the scenario in
# tests/scenarios/foodoutside.lua (or the window scenario that names it).

S = "runscenarios.py"

mutate("Core.lua",
       "\t\tif family.food and own.foodOutside == true then return false end\n",
       "",
       "foodoutside: food is held whatever the sub-switch says",
       expect="foodoutside: on, food is offered out in the world", script=S)

mutate("Core.lua",
       "\t\tif family.food and own.foodOutside == true then return false end\n",
       "\t\tif own.foodOutside == true then return false end\n",
       "foodoutside: the sub-switch lets everything out, not just food",
       expect="foodoutside: on, a stone or an oil still waits out in the world", script=S)

mutate("Core.lua",
       "\t\tif not (own and own.itemsInDungeons == true) then return false end\n",
       "",
       "foodoutside: held whatever the main switch says",
       expect="foodoutside: with Consumables only in dungeons and raids off it holds nothing", script=S)

mutate("Core.lua",
       "\t\tif ns.OwnItemsWaitForDungeon(family)\n",
       "\t\tif ns.OwnItemsHeldToDungeons(family) and addon.db.profile.ownBuffs.itemsInDungeons == true\n",
       "foodoutside: OwnVerdict holds food as before",
       expect="foodoutside: on, food is offered out in the world", script=S)

mutate("Options/Who.lua",
       "\t\t\t\t\tns.db.profile.ownBuffs.foodOutside = value == true\n",
       "",
       "foodoutside: the switch writes nothing",
       expect="foodoutside: the switch sits under Consumables only in dungeons and raids", script=S)

mutate("Options/Who.lua",
       "disabled = function() return not S().self or ns.db.profile.ownBuffs.itemsInDungeons ~= true end,",
       "disabled = function() return not S().self end,",
       "foodoutside: the switch is live with the main switch off",
       expect="foodoutside: the switch sits under Consumables only in dungeons and raids", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t{ \"who.ownFoodOutside\", indent = true },\n",
       "",
       "foodoutside: the switch is not placed on the page",
       expect="foodoutside: the switch sits under Consumables only in dungeons and raids", script=S)

mutate("Options/Advanced.lua",
       "\"ownBuffs.foodOutside\", ",
       "",
       "foodoutside: the reset leaves the switch on",
       expect="foodoutside: the switch sits under Consumables only in dungeons and raids", script=S)
