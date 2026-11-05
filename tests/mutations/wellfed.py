# Mutations for Well Fed (Buffs.lua FOOD and Foods.lua, Core.lua, Options/Who.lua,
# the layout): off by default and unread until switched on, read as an aura by
# name, never offered while a meal is on or mounted, the best food first, named
# by its item, on every class of the four clients with a table. Each is caught
# by the scenario in tests/scenarios/wellfed.lua that names it (or layout.lua).

S = "runscenarios.py"

# --- off until switched on ---

mutate("Core.lua",
       "\t\tif family.food then defaults.profile.ownBuffs.pick[family.key] = \"off\" end\n",
       "",
       "wellfed: on by default",
       expect="wellfed: off by default", script=S)

mutate("Core.lua",
       "\t\t\t\t\tlocal listed = family.scroll or (family.food and ns.OwnPick(family) ~= \"off\")\n",
       "\t\t\t\t\tlocal listed = family.scroll or family.food\n",
       "wellfed: the bags read for food with the switch off",
       expect="wellfed: off by default", script=S)

mutate("Core.lua",
       "\t\t\t\t\tlocal listed = family.scroll or (family.food and ns.OwnPick(family) ~= \"off\")\n",
       "\t\t\t\t\tlocal listed = family.scroll\n",
       "wellfed: food never counted in the bags",
       expect="wellfed: off by default", script=S)

mutate("Options/Who.lua",
       "\t\t\t\tif family.food and ns.ForgetScrolls then ns.ForgetScrolls() end\n",
       "",
       "wellfed: the bags not read again when it is switched on",
       expect="wellfed: off by default", script=S)

# --- what is offered ---

mutate("Core.lua",
       "\t\tif family.scroll or family.food then\n\t\t\tlocal held, heldWhy\n",
       "\t\tif family.scroll then\n\t\t\tlocal held, heldWhy\n",
       "wellfed: Automatic does not choose among foods",
       expect="wellfed: the best food you can use is the one offered", script=S)

mutate("Core.lua",
       "\t\tif family.food then return ReadWellFed(family, GetTime()) end\n",
       "",
       "wellfed: the aura never read",
       expect="wellfed: Well Fed up", script=S)

mutate("Core.lua",
       "\t\tif type(aura) == \"table\" then return true, nil, Left(aura, now) end\n",
       "\t\tif false then return true, nil, Left(aura, now) end\n",
       "wellfed: a Well Fed on you not seen",
       expect="wellfed: Well Fed up", script=S)

mutate("Core.lua",
       "\t\tif not ok or Withheld(aura) then return nil end\n\t\tif type(aura) == \"table\"",
       "\t\tif not ok then return nil end\n\t\tif type(aura) == \"table\"",
       "wellfed: a refused read taken as none",
       expect="wellfed: Well Fed up", script=S)

mutate("Core.lua",
       "\t\t\tif Eating(family) then return nil, up, left, \"tried\", spell end\n",
       "",
       "wellfed: another food offered mid-meal",
       expect="wellfed: not while a meal is on", script=S)

mutate("Core.lua",
       "\t\t\tif type(_G.IsMounted) == \"function\" and plain(_G.IsMounted()) == true then\n",
       "\t\t\tif false then\n",
       "wellfed: food offered mounted",
       expect="wellfed: not while a meal is on", script=S)

mutate("Core.lua",
       "\t\t\t\tlocal name = SpellNameFor(spell.ranks[1])\n\t\t\t\tif name and not seen[name] then\n",
       "\t\t\t\tlocal name = nil\n\t\t\t\tif name and not seen[name] then\n",
       "wellfed: no meal names known",
       expect="wellfed: not while a meal is on", script=S)

mutate("Buffs.lua",
       "\t\t\t\tnameFromItem = L[\"Well Fed\"] }\n",
       "\t\t\t\t}\n",
       "wellfed: a food named for the spell its use casts",
       expect="wellfed: food in the bags and no Well Fed is offered", script=S)

mutate("Core.lua",
       "buff.family and (buff.family.enhance or buff.family.food) then\n",
       "buff.family and buff.family.enhance then\n",
       "wellfed: a food never probed",
       expect="wellfed: food in the bags and no Well Fed is offered", script=S)

# --- the data and its place in every class ---

mutate("Foods.lua",
       "\t\t{ 238637, 55, 1225769 },\n\t\t{ 238638, 55, 1225771 },\n",
       "\t\t{ 238638, 55, 1225771 },\n\t\t{ 238637, 55, 1225769 },\n",
       "wellfed: the table out of order",
       expect="wellfed: every client's table of food is whole and in order", script=S)

mutate("Buffs.lua",
       "\tAddFood(VANILLA_OWN[class], \"vanilla\")\n",
       "",
       "wellfed: Classic Era has no food",
       expect="wellfed: every class on a client with the table", script=S)

mutate("Buffs.lua",
       "\t\tAddFood(TBC_OWN[class], \"tbc\")\n",
       "",
       "wellfed: Burning Crusade has no food",
       expect="wellfed: every class on a client with the table", script=S)

mutate("Buffs.lua",
       "\t\tAddFood(list, \"camelot\")\n",
       "",
       "wellfed: Forever has no food",
       expect="wellfed: every class on a client with the table", script=S)

mutate("Buffs.lua",
       "\t\tAddFood(MISTS_OWN[class], \"mists\")\n",
       "",
       "wellfed: Mists has no food",
       expect="wellfed: every class on a client with the table", script=S)

mutate("Buffs.lua",
       "\t\t\tif family.key ~= \"omen\" and not family.enhance and not family.food then list[#list + 1] = family end\n",
       "\t\t\tif family.key ~= \"omen\" and not family.enhance then list[#list + 1] = family end\n",
       "wellfed: Classic Era's food copied to Forever",
       expect="wellfed: every class on a client with the table", script=S)

# --- the page ---

mutate("Options/Who.lua",
       "\t\t\t\t\tif family.food then return false end\n\t\t\t\t\tfor _, known in ipairs(ns.KnownOwnFamilies()) do\n",
       "\t\t\t\t\tfor _, known in ipairs(ns.KnownOwnFamilies()) do\n",
       "wellfed: the switch hidden until food is in the bags",
       expect="wellfed: off by default", script=S)

mutate("Options/Who.lua",
       "\t\t\tif (#family.spells > 1 or family.tank) and not family.food then\n",
       "\t\t\tif #family.spells > 1 or family.tank then\n",
       "wellfed: the switch a list of every food",
       expect="wellfed: off by default", script=S)

mutate("Options/Who.lua",
       "\t\tif family.food then return false end\n\tend\n\treturn #ns.SelfBuffs() == 0",
       "\t\tif false then return false end\n\tend\n\treturn #ns.SelfBuffs() == 0",
       "wellfed: a warrior has no Myself",
       expect="wellfed: Myself is a warrior's too", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t{ \"who.own_food\", indent = true },\n",
       "",
       "wellfed: the switch not placed on the page",
       expect="own_food", script=S)
