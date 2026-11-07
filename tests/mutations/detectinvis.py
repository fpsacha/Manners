# Mutations for a warlock's Detect Invisibility on himself (Buffs.lua's family,
# Core.lua's default, the layout slot). Each is caught by the scenario in
# tests/scenarios/detectinvis.lua that names it.

S = "runscenarios.py"

mutate("Core.lua",
       "\t\tif family.optIn then defaults.profile.ownBuffs.pick[family.key] = \"off\" end\n",
       "",
       "detectinvis: on by default",
       expect="detectinvis: off by default, a switch for a warlock who knows it, and it turns off again", script=S)

mutate("Buffs.lua",
       "\t\t\tspells = { { key = \"detectinvis\", ranks = { 11743, 2970, 132 }, anyCaster = true } } },\n",
       "\t\t\tspells = { { key = \"detectinvis\", ranks = { 11743, 2970, 132 } } } },\n",
       "detectinvis: another warlock's does not count",
       expect="detectinvis: yours or another warlock's on you, nothing offered", script=S)

mutate("Buffs.lua",
       "\t\t\tspells = { { key = \"detectinvis\", ranks = { 11743, 2970, 132 }, anyCaster = true } } },\n",
       "\t\t\tspells = { { key = \"detectinvis\", ranks = { 2970, 132 }, anyCaster = true } } },\n",
       "detectinvis: Greater left out",
       expect="detectinvis: a warlock's family on Forever, Classic Era and Burning Crusade, none on Mists or retail", script=S)

mutate("Buffs.lua",
       "\t\t{ key = \"detectinvis\", optIn = true,\n\t\t\tspells = { { key = \"detectinvis\", ranks = { 132 }, anyCaster = true } } },\n",
       "",
       "detectinvis: none on Burning Crusade",
       expect="detectinvis: tbc: switched on and none up, cast on yourself", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t{ \"who.own_detectinvis\", indent = true },\n",
       "",
       "detectinvis: the switch is not placed on the page",
       expect="every control has one place in the options window", script=S)
