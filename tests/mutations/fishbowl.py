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

# GitHub issue 17: the Greater Blessing of Kings, and the strict switch
# (buff.neverFishBowl).

mutate("GroupBuffs.lua",
       "\t\t\tif bowl and not (name and offered[name]) and ByFishBowl(unit) then return false end\n",
       "",
       "fishbowl: a Greater Blessing of Kings over a member by a Fish Bowl",
       expect="fishbowl: on, no Greater Blessing of Kings for a class with somebody by a Fish Bowl", script=S)

mutate("GroupBuffs.lua",
       "\t\tif buff.key == key and buff.strongest then bowl = true end\n",
       "\t\tif buff.key == key and buff.strongest then bowl = false end\n",
       "fishbowl: the Fish Bowl never asked about for a Greater Blessing",
       expect="fishbowl: on, no Greater Blessing of Kings for a class with somebody by a Fish Bowl", script=S)

mutate("GroupBuffs.lua",
       "\treturn ns.SparesFishBowl(BOWL_ASK) == true\n",
       "\treturn true\n",
       "fishbowl: every member read as by a Fish Bowl for a Greater Blessing",
       expect="fishbowl: the Greater Blessing of Kings is still offered with no Fish Bowl, or the switch off", script=S)

mutate("Core.lua",
       "\t\t\tif bowled then kingsLater = nil end\n",
       "",
       "fishbowl: the strict switch still gives Kings",
       expect="fishbowl: never Kings, somebody by a Fish Bowl with nothing else missing is left alone", script=S)

mutate("Core.lua",
       "\t\t\tlocal bowled = kingsLater and db.buff.neverFishBowl == true and not opts.asked\n",
       "\t\t\tlocal bowled = kingsLater and not opts.asked\n",
       "fishbowl: strict whether its switch is on or not",
       expect="fishbowl: on, Kings once nothing else is missing for them", script=S)

mutate("Core.lua",
       "\t\t\tneverFishBowl = false,\n",
       "\t\t\tneverFishBowl = true,\n",
       "fishbowl: the strict switch on by default",
       expect="fishbowl: the strict switch sits under the first one on Who to buff", script=S)

mutate("Options/Who.lua",
       "\t\t\t\tdisabled = function() return B().spareFishBowl ~= true end,\n",
       "",
       "fishbowl: the strict switch drawn while the first is off",
       expect="fishbowl: the strict switch sits under the first one on Who to buff", script=S)

mutate("Options/Window/Layout.lua",
       "\titems[#items + 1] = { \"who.neverFishBowl\", indent = true }\n",
       "\titems[#items + 1] = \"who.neverFishBowl\"\n",
       "fishbowl: the strict switch not indented under the first",
       expect="fishbowl: the strict switch sits under the first one on Who to buff", script=S)

# GitHub issue 20: your own pick, and Camp Benefits.

mutate("Core.lua",
       "\t\tif unit == nil and opts.own then unit = \"player\" end\n",
       "",
       "fishbowl: your own pick read as no unit",
       expect="fishbowl: Camp Benefits naming the Fish Bowl holds Kings off you and off others", script=S)

mutate("Core.lua",
       "\t\treturn fine and holds == true\n",
       "\t\treturn fine\n",
       "fishbowl: any Camp Benefits counts as a Fish Bowl",
       expect="fishbowl: Camp Benefits without the Fish Bowl line holds nothing back", script=S)

mutate("Core.lua",
       "\t\tok, aura = pcall(read, unit, CAMP_BENEFITS)\n",
       "\t\tok, aura = false, nil\n",
       "fishbowl: Camp Benefits never read",
       expect="fishbowl: Camp Benefits naming the Fish Bowl holds Kings off you and off others", script=S)
