# Mutations for the third hunt's faults that differ by client. Each is caught
# by the scenario in tests/scenarios/hunt3-clients.lua that names it.

S = "runscenarios.py"

# A season's rune is the class's whether learned or not; and the other way,
# nobody has a resurrection until it is learned.
DRUID = "hunt3-clients: a druid on Classic Era has a resurrection only once the rune is learned"
PRIEST = "hunt3-clients: a priest who has not trained his resurrection still has one"
mutate("Resurrect.lua",
       "\treturn mine.rune ~= true or Info() ~= nil\n",
       "\treturn true\n",
       "hunt3-clients: a rune nobody on the realm can learn counts as a resurrection",
       expect=DRUID, script=S)
mutate("Resurrect.lua",
       "\treturn mine.rune ~= true or Info() ~= nil\n",
       "\treturn Info() ~= nil\n",
       "hunt3-clients: no class has a resurrection until it is trained",
       expect=PRIEST, script=S)

# Mists: the level a refreshment asks.
LEVEL = "hunt3-clients: mists: nobody is handed a refreshment above their level"
mutate("Modules/Services/Courtesy.lua",
       "\t\tif needs and (needs[item] or 0) > level then count = 0 end\n",
       "",
       "hunt3-clients: mists: a refreshment traded to somebody too low for it",
       expect=LEVEL, script=S)
mutate("Modules/Services/Courtesy.lua",
       "\t\t\t\t\tif (needs[item] or 0) > level then return nil, \"level\" end\n",
       "",
       "hunt3-clients: mists: a conjure for somebody too low for what it makes",
       expect=LEVEL, script=S)

# A courtesy's own cooldown.
COOL = "hunt3-clients: mists: a summon or a Soulwell still cooling down is not offered"
CONJURE = "hunt3-clients: a conjure still cooling down is not offered"
mutate("Modules/Services/Courtesy.lua",
       "\t\tif Cooling(spell) then return nil, \"cooldown\" end\n"
       "\t\tif not Usable(spell) then return nil, \"unusable\" end\n"
       "\t\tif kind.targeted and InRange(spell, unit) ~= true then return nil, \"range\" end\n",
       "\t\tif not Usable(spell) then return nil, \"unusable\" end\n"
       "\t\tif kind.targeted and InRange(spell, unit) ~= true then return nil, \"range\" end\n",
       "hunt3-clients: a summon offered while the ritual cools down",
       expect=COOL, script=S)
mutate("Modules/Services/Courtesy.lua",
       "\t\tif Cooling(spell) then return nil, \"cooldown\" end\n",
       "",
       "hunt3-clients: a Soulwell or a portal offered while it cools down",
       expect=COOL, script=S)
mutate("Modules/Services/Courtesy.lua",
       "\tif Cooling(conjure.spell) then return nil, \"cooldown\" end\n",
       "",
       "hunt3-clients: a conjure offered while it cools down",
       expect=CONJURE, script=S)
mutate("Modules/Services/Courtesy.lua",
       "and duration > 3\n\t\tand start + duration > GetTime()\n",
       "and duration > 0\n\t\tand start + duration > GetTime()\n",
       "hunt3-clients: the global cooldown takes a courtesy off the prompt",
       expect=COOL, script=S)
