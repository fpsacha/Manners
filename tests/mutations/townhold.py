# Mutations for where Offer nothing in cities and inns holds
# (filters.quietInTownsWhere: Queue.lua inTown, Range.lua ns.InCity and its
# capitals, Core.lua's default and repair, Options/Who.lua, the layout, the
# page's reset and the full check-up). Each is caught by the scenario in
# tests/scenarios/townhold.lua (or model-window.lua) that names it.

S = "runscenarios.py"

# ------------------------------------------------ the setting
mutate("Core.lua",
       "\t\t\tquietInTownsWhere = \"both\",\n",
       "\t\t\tquietInTownsWhere = \"cities\",\n",
       "townhold: cities only by default",
       expect="townhold: cities and inns by default, both held back as before", script=S)

mutate("Core.lua",
       "\toneOf(profile.filters, \"quietInTownsWhere\", { both = true, cities = true, inns = true }, \"both\")\n",
       "",
       "townhold: a damaged value is kept",
       expect="townhold: When to offer has the choice under the switch, greyed while it is off", script=S)

mutate("Core.lua",
       "\toneOf(profile.filters, \"quietInTownsWhere\", { both = true, cities = true, inns = true }, \"both\")\n",
       "\toneOf(profile.filters, \"quietInTownsWhere\", { both = true, inns = true }, \"both\")\n",
       "townhold: the repair undoes cities only",
       expect="townhold: When to offer has the choice under the switch, greyed while it is off", script=S)

# ------------------------------------------------ the queue
mutate("Queue.lua",
       "\tif inTown and f.quietInTownsWhere ~= \"both\" then\n",
       "\tif false then\n",
       "townhold: the choice is never read",
       expect="townhold: cities only, an inn offers as ever", script=S)

mutate("Queue.lua",
       "\tif inTown and f.quietInTownsWhere ~= \"both\" then\n",
       "\tif f.quietInTowns == true and f.quietInTownsWhere ~= \"both\" then\n",
       "townhold: a capital's map holds back out in the world too",
       expect="townhold: out in the world, Where changes nothing", script=S)

mutate("Queue.lua",
       "\t\t\tinTown = f.quietInTownsWhere ~= \"inns\"\n",
       "\t\t\tinTown = false\n",
       "townhold: a capital never holds back",
       expect="townhold: cities only, a capital offers nothing but the target", script=S)

mutate("Queue.lua",
       "\t\t\tinTown = f.quietInTownsWhere ~= \"inns\"\n",
       "\t\t\tinTown = true\n",
       "townhold: inns only holds back in a capital",
       expect="townhold: inns only, a capital offers as ever", script=S)

mutate("Queue.lua",
       "\t\t\tinTown = f.quietInTownsWhere ~= \"cities\"\n",
       "\t\t\tinTown = false\n",
       "townhold: an inn never holds back",
       expect="townhold: inns only, an inn offers nothing", script=S)

mutate("Queue.lua",
       "\t\telseif city == false then\n",
       "\t\telse\n",
       "townhold: a map the client will not name is taken for an inn",
       expect="townhold: a map the client will not name holds back both", script=S)

# ------------------------------------------------ what a city is
mutate("Range.lua",
       "\t\t\tat = parent\n",
       "\t\t\tbreak\n",
       "townhold: the map's parents are not walked",
       expect="townhold: a part of a capital is the capital", script=S)

mutate("Range.lua",
       "\t\tif id == lastMap and capitals == lastSet then return lastCity end\n",
       "\t\tif lastMap then return lastCity end\n",
       "townhold: the first map's answer kept for every map",
       expect="townhold: a part of a capital is the capital", script=S)

mutate("Range.lua",
       "\t\tlocal ok, id = pcall(maps.GetBestMapForUnit, \"player\")\n",
       "\t\tlocal ok, id = true, maps.GetBestMapForUnit(\"player\")\n",
       "townhold: a map call that throws is not caught",
       expect="townhold: a map the client will not name holds back both", script=S)

mutate("Range.lua",
       "\t\tif type(maps) ~= \"table\" or type(maps.GetBestMapForUnit) ~= \"function\" then return nil end\n",
       "",
       "townhold: a client without C_Map is asked anyway",
       expect="townhold: a map the client will not name holds back both", script=S)

mutate("Range.lua",
       "\t\t[1955] = true, -- Shattrath City\n",
       "",
       "townhold: Burning Crusade's Shattrath left out",
       expect="townhold: each client's capitals are cities", script=S)

mutate("Range.lua",
       "\tfor id in pairs(OLD) do TBC[id] = true end\n",
       "",
       "townhold: Burning Crusade's old capitals left out",
       expect="townhold: each client's capitals are cities", script=S)

mutate("Range.lua",
       "\tfor id in pairs(MISTS) do RETAIL[id] = true end\n",
       "",
       "townhold: retail's old capitals left out",
       expect="townhold: each client's capitals are cities", script=S)

mutate("Range.lua",
       "\tlocal CAPITALS = { camelot = OLD, vanilla = OLD, tbc = TBC, mists = MISTS, mainline = RETAIL }\n",
       "\tlocal CAPITALS = { camelot = OLD, vanilla = OLD, tbc = TBC, mists = RETAIL, mainline = RETAIL }\n",
       "townhold: Mists reads retail's capitals",
       expect="townhold: each client's capitals are cities", script=S)

mutate("Range.lua",
       "\tlocal CAPITALS = { camelot = OLD, vanilla = OLD, tbc = TBC, mists = MISTS, mainline = RETAIL }\n",
       "\tlocal CAPITALS = { camelot = TBC, vanilla = OLD, tbc = TBC, mists = MISTS, mainline = RETAIL }\n",
       "townhold: Forever reads Burning Crusade's capitals",
       expect="townhold: each client's capitals are cities", script=S)

# ------------------------------------------------ the options
mutate("Options/Who.lua",
       "\t\t\t\tsorting = { \"both\", \"cities\", \"inns\" },\n"
       "\t\t\t\tdisabled = function() return F().quietInTowns ~= true end,\n"
       "\t\t\t\tget = fGet,\n\t\t\t\tset = fSet,\n",
       "\t\t\t\tsorting = { \"both\", \"cities\", \"inns\" },\n"
       "\t\t\t\tdisabled = function() return F().quietInTowns ~= true end,\n"
       "\t\t\t\tget = fGet,\n\t\t\t\tset = function() end,\n",
       "townhold: the choice stores nothing",
       expect="townhold: When to offer has the choice under the switch, greyed while it is off", script=S)

mutate("Options/Who.lua",
       "\t\t\t\tdisabled = function() return F().quietInTowns ~= true end,\n",
       "\t\t\t\tdisabled = false,\n",
       "townhold: the choice live with the switch off",
       expect="townhold: When to offer has the choice under the switch, greyed while it is off", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t{ \"who.quietInTownsWhere\", indent = true },\n",
       "",
       "townhold: the choice is not placed on When to offer",
       expect="townhold: When to offer has the choice under the switch, greyed while it is off", script=S)

mutate("Options/Advanced.lua",
       "\t\t\"filters.quietInTownsWhere\", \"filters.quietShortInTowns\", \"filters.quietShortMinutes\",\n",
       "\t\t\"filters.quietShortInTowns\", \"filters.quietShortMinutes\",\n",
       "townhold: When to offer's reset leaves the choice",
       expect="model: the reset puts when back", script=S)

# ------------------------------------------------ the full check-up
mutate("Options/Diagnostics.lua",
       "\t\t:format(tostring(db.filters.quietInTowns), tostring(db.filters.quietInTownsWhere),\n",
       "\t\t:format(tostring(db.filters.quietInTowns), \"?\",\n",
       "townhold: the check-up leaves where out",
       expect="townhold: the full check-up says where, and the map", script=S)

mutate("Options/Diagnostics.lua",
       "\t\t\ttostring(ns.InCity and ns.InCity()))\n",
       "\t\t\t\"?\")\n",
       "townhold: the check-up does not say whether the map is a capital",
       expect="townhold: the full check-up says where, and the map", script=S)
