# Mutations for "Weapon imbues before the shield" (Core.lua, KnownOwnFamilies;
# asked for on CurseForge). Caught by tests/scenarios/imbuefirst.lua.

S = "runscenarios.py"

mutate("Core.lua",
       "\t\t\tand db.profile.ownBuffs.imbueFirst == true then\n",
       "\t\t\tand false then\n",
       "imbuefirst: the switch never reorders",
       expect="on, the order is", script=S)

mutate("Core.lua",
       "\t\t\tand db.profile.ownBuffs.imbueFirst == true then\n",
       "\t\t\tthen\n",
       "imbuefirst: reordered with the switch off",
       expect="off, the order is", script=S)

mutate("Core.lua",
       "\t\t\t\tlocal into = family.imbue and first or rest\n",
       "\t\t\t\tlocal into = rest\n",
       "imbuefirst: the imbue not moved ahead",
       expect="on, the order is", script=S)

mutate("Core.lua",
       "\t\t\timbueFirst = false,\n",
       "\t\t\timbueFirst = true,\n",
       "imbuefirst: on by default",
       expect="a new profile's switch is", script=S)

mutate("Options/Who.lua",
       "\t\t\t\t\tns.db.profile.ownBuffs.imbueFirst = value == true\n",
       "\t\t\t\t\tns.db.profile.ownBuffs.imbueFirst = true\n",
       "imbuefirst: the switch cannot be turned off",
       expect="turning it off wrote nothing", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t{ \"who.ownImbueFirst\", indent = 2 },\n",
       "",
       "imbuefirst: the switch not placed",
       expect="ownImbueFirst", script=S)

mutate("Options/Who.lua",
       "key == \"ownShout\" or key == \"ownImbueFirst\" or",
       "key == \"ownShout\" or",
       "imbuefirst: hidden with a shaman's nothing-for-others rule",
       expect="hidden from a shaman who knows an imbue", script=S)
