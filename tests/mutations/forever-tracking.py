# Mutations for Find Treasure beside a gathering tracking on WoW Forever
# (Buffs.lua's FIND_TREASURE family, Core.lua's onceUp rule and
# ns.SplitFindTreasure, the switch on Who to buff and its place in the layout).
# Each is caught by the scenario in tests/scenarios/forever-tracking.lua that
# names it, or by layout.lua for the place.

S = "runscenarios.py"

# ------------------------------------------------ the families
mutate("Buffs.lua",
       "\t\t\t\tlist[i] = CAMELOT_TRACKING\n\t\t\t\ttable.insert(list, i + 1, FIND_TREASURE)\n",
       "",
       "forever-tracking: Find Treasure left in Tracking on Forever",
       expect="forever-tracking: Find Treasure on still reminds you of Find Herbs", script=S)

mutate("Buffs.lua",
       "\t\tif spell.key ~= \"findtreasure\" then\n\t\t\tCAMELOT_TRACKING.spells",
       "\t\tif true then\n\t\t\tCAMELOT_TRACKING.spells",
       "forever-tracking: Find Treasure in both families",
       expect="forever-tracking: Find Treasure on still reminds you of Find Herbs", script=S)

mutate("Buffs.lua",
       "local FIND_TREASURE = { key = \"findtreasure\", tracking = true, toggle = true, onceUp = true,",
       "local FIND_TREASURE = { key = \"findtreasure\", tracking = true, toggle = true,",
       "forever-tracking: Find Treasure asked for before it has been up (Buffs.lua)",
       expect="forever-tracking: never had Find Treasure up, never asked for it", script=S)

mutate("Core.lua",
       "\t\tif family.onceUp then return nil, nil end\n",
       "",
       "forever-tracking: Find Treasure asked for before it has been up (Core.lua)",
       expect="forever-tracking: never had Find Treasure up, never asked for it", script=S)

# ------------------------------------------------ the saved settings
mutate("Core.lua",
       "\tns.SplitFindTreasure(own, addon.db.char)\n",
       "",
       "forever-tracking: the old settings never moved",
       expect="forever-tracking: a memory or a pick of it on Tracking moves across", script=S)

mutate("Core.lua",
       "\t\t\tmemory.findtreasure = \"findtreasure\"\n",
       "",
       "forever-tracking: the memory of it on Tracking dropped",
       expect="forever-tracking: a memory or a pick of it on Tracking moves across", script=S)

mutate("Core.lua",
       "\t\tmemory.tracking = nil\n",
       "",
       "forever-tracking: Tracking keeps the memory of Find Treasure",
       expect="forever-tracking: a memory or a pick of it on Tracking moves across", script=S)

mutate("Core.lua",
       "\t\tpick.findtreasure = \"findtreasure\"\n",
       "",
       "forever-tracking: the pick of it on Tracking dropped",
       expect="forever-tracking: a memory or a pick of it on Tracking moves across", script=S)

mutate("Core.lua",
       "\t\town.leave.findtreasure = nil\n\t\tpick.findtreasure = \"off\"\n",
       "\t\town.leave.findtreasure = nil\n",
       "forever-tracking: a tick of it on Tracking forgotten",
       expect="forever-tracking: a tick or Tracking off keeps it off", script=S)

mutate("Core.lua",
       "\t\tif pick.tracking == \"off\" then\n",
       "\t\tif false then\n",
       "forever-tracking: Tracking off not carried across",
       expect="forever-tracking: a tick or Tracking off keeps it off", script=S)

mutate("Core.lua",
       "\tif not (family and spell and spell.family == family) then return end\n\tlocal pick = own.pick\n",
       "\tif not spell then return end\n\tlocal pick = own.pick\n",
       "forever-tracking: the move made on every client",
       expect="forever-tracking: Classic Era and Burning Crusade keep it in Tracking", script=S)

# ------------------------------------------------ the options page
mutate("Options/Who.lua",
       "\t\t\t\t\tor family.onceUp\n\t\t\t\t\tand L[\"Reminds you when it is not up, once you have had it up yourself.\"]\n",
       "",
       "forever-tracking: the switch does not say it waits",
       expect="forever-tracking: the page has a switch for it", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t{ \"who.own_findtreasure\", indent = true },\n",
       "",
       "forever-tracking: the switch has no place in the window",
       expect="every control has one place in the options window", script=S)
