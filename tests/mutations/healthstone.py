# Mutations for GitHub issue 32 (a warlock's healthstone to make: Buffs.lua's
# makehealthstone family, Core.lua's `holds` reading, the layout slot and the
# debug line). Each is caught by the scenario in tests/scenarios/healthstone.lua
# that names it.

S = "runscenarios.py"

# The bags' healthstones never counted: one in the bags is made over.
mutate("Core.lua",
       "\t\t\t\t\tif family.holds and ns.OwnPick(family) ~= \"off\" then\n",
       "\t\t\t\t\tif false and family.holds and ns.OwnPick(family) ~= \"off\" then\n",
       "healthstone: the bags' healthstones never counted",
       expect="healthstone: forever: a healthstone of any rank or Improved copy in the bags, nothing is offered", script=S)

# The family read as never up.
mutate("Core.lua",
       "\t\tif family.holds then return ns.OwnHeldFirst(family) ~= nil end\n",
       "",
       "healthstone: the family never read as up",
       expect="healthstone: forever: a healthstone of any rank or Improved copy in the bags, nothing is offered", script=S)

# No Soul Shard asked for on Classic Era and Forever.
mutate("Buffs.lua",
       "\tPlace(VANILLA_OWN.WARLOCK, MakeHealthstone(CLASSIC_RANKS, CLASSIC_ITEMS, 6265))\n"
       "\tPlace(CAMELOT_OWN.WARLOCK, MakeHealthstone(CLASSIC_RANKS, CLASSIC_ITEMS, 6265))\n",
       "\tPlace(VANILLA_OWN.WARLOCK, MakeHealthstone(CLASSIC_RANKS, CLASSIC_ITEMS))\n"
       "\tPlace(CAMELOT_OWN.WARLOCK, MakeHealthstone(CLASSIC_RANKS, CLASSIC_ITEMS))\n",
       "healthstone: no Soul Shard asked for",
       expect="healthstone: forever: no Soul Shard, nothing is offered and the debug line says so", script=S)

# Made on the run, a cast cut short.
mutate("Buffs.lua",
       "toggle = true, holds = true, still = true,\n",
       "toggle = true, holds = true,\n",
       "healthstone: made on the run",
       expect="healthstone: on the move it waits; standing still it comes back", script=S)

# Retail's Demonic Healthstone not counted.
mutate("Buffs.lua",
       "MakeHealthstone({ 6201 }, { 5512, 224464 })",
       "MakeHealthstone({ 6201 }, { 5512 })",
       "healthstone: Demonic Healthstone not counted",
       expect="healthstone: retail's Demonic Healthstone counts as one in the bags", script=S)

# Mists left without the family.
mutate("Buffs.lua",
       "\tPlace(MISTS_OWN.WARLOCK, MakeHealthstone({ 6201 }, { 5512 }))\n",
       "",
       "healthstone: Mists has no family",
       expect="healthstone: offered on every client where Create Healthstone is learned", script=S)

# The switch not placed on the page.
mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t{ \"who.own_makehealthstone\", indent = true },\n",
       "",
       "healthstone: the switch not placed",
       expect="healthstone: the switch is placed on My own buffs under the warlock's own", script=S)

# The debug line silent about a healthstone in the bags.
mutate("Commands.lua",
       "\t\telseif why == \"up\" and family.holds then\n",
       "\t\telseif why == \"up\" and family.holds and false then\n",
       "healthstone: the debug line silent",
       expect="healthstone: the debug line says a healthstone is in your bags", script=S)
