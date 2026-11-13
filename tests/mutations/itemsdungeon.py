# Mutations for oils, stones and food only in dungeons and raids (Core.lua
# OwnItemsHeldToDungeons and OwnVerdict, Options/Who.lua, the layout slot,
# Commands.lua's reasons and the page's reset). Each is caught by the scenario in
# tests/scenarios/itemsdungeon.lua (or model-window.lua) that names it.

S = "runscenarios.py"

mutate("Core.lua",
       "\t\t\tand not InDungeon() then\n\t\t\treturn nil, nil, nil, \"dungeon\"\n",
       "\t\t\tand false then\n\t\t\treturn nil, nil, nil, \"dungeon\"\n",
       "itemsdungeon: the switch never holds anything back",
       expect="itemsdungeon: on, food waits for a dungeon or a raid", script=S)

mutate("Core.lua",
       "ns.OwnItemsHeldToDungeons(family) and addon.db.profile.ownBuffs.itemsInDungeons == true\n",
       "ns.OwnItemsHeldToDungeons(family)\n",
       "itemsdungeon: held whatever the switch says",
       expect="itemsdungeon: with it off, food is offered in the world as it was", script=S)

mutate("Core.lua",
       "\t\tif family.food then return true end\n",
       "",
       "itemsdungeon: food is not held",
       expect="itemsdungeon: the families it holds are oils, stones and food", script=S)

mutate("Core.lua",
       "\t\treturn family.enhance == true and family.kind ~= \"poison\" and family.kind ~= \"lure\"\n",
       "\t\treturn family.enhance == true and family.kind ~= \"poison\"\n",
       "itemsdungeon: a fishing lure is held",
       expect="itemsdungeon: the families it holds are oils, stones and food", script=S)

mutate("Core.lua",
       "\t\treturn family.enhance == true and family.kind ~= \"poison\" and family.kind ~= \"lure\"\n",
       "\t\treturn family.enhance == true and family.kind ~= \"lure\"\n",
       "itemsdungeon: a poison is held",
       expect="itemsdungeon: the families it holds are oils, stones and food", script=S)

mutate("Options/Who.lua",
       "\t\t\t\t\tns.db.profile.ownBuffs.itemsInDungeons = value\n",
       "",
       "itemsdungeon: the switch writes nothing",
       expect="itemsdungeon: Who to buff has the switch, off by default, and it is kept", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t\"who.ownDungeons\",\n",
       "",
       "itemsdungeon: the switch is not placed on the page",
       expect="ownDungeons", script=S)

mutate("Commands.lua",
       "\t\telseif why == \"dungeon\" then\n",
       "\t\telseif why == \"dungeon-never\" then\n",
       "itemsdungeon: the reason is not said",
       expect="itemsdungeon: /manners debug says why an oil is not offered in the world", script=S)

mutate("Options/Advanced.lua",
       "\"ownBuffs.inCities\", \"ownBuffs.itemsInDungeons\",",
       "\"ownBuffs.inCities\",",
       "itemsdungeon: the page's reset leaves the switch",
       expect="model: the reset puts who back", script=S)
