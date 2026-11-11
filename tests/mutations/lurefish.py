# Mutations for a lure above your Fishing skill (Buffs.lua, `fishing`;
# Core.lua, ScrollReady and ns.FishingSkill). Each is caught by the scenario in
# tests/scenarios/lurefish.lua that names it.

S = "runscenarios.py"

mutate("Core.lua",
       "\t\t\tif skill and skill < spell.fishing then return false, \"fishing\" end\n",
       "",
       "lurefish: the skill is never compared",
       expect="lurefish: Bright Baubles is not offered with Fishing below 100", script=S)

mutate("Core.lua",
       "\t\t\tif skill and skill < spell.fishing then return false, \"fishing\" end\n",
       "\t\t\tif skill and skill <= spell.fishing then return false, \"fishing\" end\n",
       "lurefish: a skill equal to the lure's held back",
       expect="lurefish: at Fishing 100 it is offered", script=S)

mutate("Core.lua",
       "\t\t\tif skill and skill < spell.fishing then return false, \"fishing\" end\n",
       "\t\t\tif (skill or 0) < spell.fishing then return false, \"fishing\" end\n",
       "lurefish: an unanswered skill read as none",
       expect="lurefish: never learned is Fishing 0, and an unanswered skill holds nothing", script=S)

mutate("Buffs.lua",
       "item = row[1], level = row[2], fishing = row.fishing,",
       "item = row[1], level = row[2],",
       "lurefish: the rows' Fishing never read",
       expect="lurefish: Bright Baubles is not offered with Fishing below 100", script=S)

mutate("Core.lua",
       "\t\t\treturn 0\n\t\tend\n\t\tlocal okInfo, _, _, rank = pcall(info, fishing)\n",
       "\t\t\treturn nil\n\t\tend\n\t\tlocal okInfo, _, _, rank = pcall(info, fishing)\n",
       "lurefish: never learned read as unknown",
       expect="lurefish: never learned is Fishing 0", script=S)

mutate("Core.lua",
       "\t\tlocal okInfo, _, _, rank = pcall(info, fishing)\n",
       "\t\tlocal okInfo, _, rank = pcall(info, fishing)\n",
       "lurefish: the wrong return read as the rank",
       expect="lurefish: Bright Baubles is not offered with Fishing below 100", script=S)
