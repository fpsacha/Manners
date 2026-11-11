# Mutations for "Don't put Kings over a Fish Bowl's Boosted Stats"
# (buff.spareFishBowl: Core.lua, SparesFishBowl and PickBuffFor's exclusive
# branch; GitHub issue 12). Each is caught by the scenario in
# tests/scenarios/fishbowl.lua that names it.

S = "runscenarios.py"

mutate("Core.lua",
       "\t\t\tspareFishBowl = false,\n",
       "\t\t\tspareFishBowl = true,\n",
       "fishbowl: on by default",
       expect="fishbowl: off by default, Kings goes over the Fish Bowl as before", script=S)

mutate("Core.lua",
       "\t\tif not (db and db.buff.spareFishBowl == true) or type(opts.unit) ~= \"string\" then return false end\n",
       "\t\tif type(opts.unit) ~= \"string\" then return false end\n",
       "fishbowl: the switch is not read",
       expect="fishbowl: off by default, Kings goes over the Fish Bowl as before", script=S)

mutate("Core.lua",
       "\t\t\t\t\t\telseif not pick and buff.strongest and SparesFishBowl(opts) then\n",
       "\t\t\t\t\t\telseif false then\n",
       "fishbowl: Kings never held back",
       expect="fishbowl: on, somebody by a Fish Bowl gets another blessing first", script=S)

mutate("Core.lua",
       "\t\tlocal ok, aura = pcall(read, opts.unit, FISH_BOWL)\n",
       "\t\tlocal ok, aura = true, {}\n",
       "fishbowl: everybody read as by a Fish Bowl",
       expect="fishbowl: on, somebody by a Fish Bowl gets another blessing first", script=S)

mutate("Core.lua",
       "\t\t\tif not pick then pick = kingsLater end\n",
       "",
       "fishbowl: Kings never given, even with nothing else missing",
       expect="fishbowl: on, Kings once nothing else is missing for them", script=S)

mutate("Options/Who.lua",
       "\t\t\t\t\tif not (ns.Flavour and ns.Flavour.flavour == \"camelot\") then return true end\n",
       "",
       "fishbowl: the switch shows on every client",
       expect="fishbowl: the switch is on Who to buff for a Forever paladin, and only there", script=S)

mutate("Options/Who.lua",
       "\t\t\t\tget = function() return B().spareFishBowl == true end,\n",
       "\t\t\t\tget = function() return false end,\n",
       "fishbowl: the switch shows off whatever is stored",
       expect="fishbowl: the switch is on Who to buff for a Forever paladin, and only there", script=S)
