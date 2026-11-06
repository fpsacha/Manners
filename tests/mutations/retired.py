# Mutations for Blessing of Salvation and Light deleted on Forever (Buffs.lua,
# CAMELOT and the length rows). Each is caught by the scenario in
# tests/scenarios/retired.lua that names it.

S = "runscenarios.py"

# the two blessings kept in Forever's set.
mutate("Buffs.lua",
       "\tlocal GONE = { sanctuary = true, salvation = true, light = true }\n",
       "\tlocal GONE = { sanctuary = true }\n",
       "retired: Salvation and Light kept on Forever",
       expect="retired: camelot: a paladin no longer has Salvation and Light", script=S)

# a length left for the ids the client no longer has.
mutate("Buffs.lua",
       "\t\t{ 3600, 20217 }, -- Blessing of Kings (1 h)\n",
       "\t\t{ 3600, 20217 }, -- Blessing of Kings (1 h)\n\t\t{ 3600, 1038 }, -- Blessing of Salvation (1 h)\n",
       "retired: a length kept for Salvation on Forever",
       expect="retired: camelot: a paladin no longer has Salvation and Light", script=S)

# the other clients lose them too.
mutate("Buffs.lua",
       "\tlocal GONE = { sanctuary = true, salvation = true, light = true }\n",
       "\tlocal GONE = { sanctuary = true, salvation = true, light = true }\n\tVANILLA.PALADIN[4] = nil\n",
       "retired: Classic Era's Salvation taken away",
       expect="retired: vanilla: a paladin still has Salvation and Light", script=S)
