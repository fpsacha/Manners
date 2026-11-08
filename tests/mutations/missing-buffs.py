# Mutations for the buffs the missing-buffs round added in 1.11.11 (Buffs.lua: a
# warlock's Demonic Sacrifice and Soul Link, Tree of Life, Spirit of the Alpha,
# retail's Beacon of Faith and Symbiotic Relationship, the consumables; Core.lua's
# `apartFrom`; tools/make_consumables.py's output; the page). Each is caught by
# the scenario in tests/scenarios/missing-buffs.lua that it names.

S = "runscenarios.py"
B = "Buffs.lua"
C = "Core.lua"
K = "Consumables.lua"

# ---------------------------------------------------------------- Demonic Sacrifice

mutate(B,
       "\t\t\t{ key = \"demonicsacrifice\", ranks = { 18788, 18789, 18790, 18791, 18792 }, talent = true },",
       "\t\t\t{ key = \"demonicsacrifice\", ranks = { 18788 }, talent = true },",
       "missing-buffs: the sacrifice's auras not read",
       expect="missing-buffs: vanilla: Demonic Sacrifice with a demon out, up on each demon's aura", script=S)

mutate(B,
       "\t\t\t{ key = \"demonicsacrifice\", ranks = { 18788, 18789, 18790, 18791, 18792, 35701 }, talent = true },",
       "\t\t\t{ key = \"demonicsacrifice\", ranks = { 18788, 18789, 18790, 18791, 18792 }, talent = true },",
       "missing-buffs: Burning Crusade's Felguard sacrifice not read",
       expect="missing-buffs: tbc: Demonic Sacrifice with a demon out, up on each demon's aura", script=S)

mutate(B,
       "\ttable.insert(VANILLA_OWN.WARLOCK, 2, { key = \"demonicsacrifice\", toggle = true,\n\t\tspells = {\n"
       "\t\t\t{ key = \"soullink\", ranks = { 19028, 25228 }, talent = true },\n",
       "\ttable.insert(VANILLA_OWN.WARLOCK, 2, { key = \"demonicsacrifice\", toggle = true,\n\t\tspells = {\n",
       "missing-buffs: no Soul Link in the vanilla family",
       expect="missing-buffs: vanilla: a Soul Link warlock is never told to sacrifice his demon", script=S)

mutate(B,
       "\t\t\t{ key = \"soullink\", ranks = { 19028, 25228 }, talent = true },\n"
       "\t\t\t{ key = \"demonicsacrifice\", ranks = { 18788, 18789, 18790, 18791, 18792, 35701 }, talent = true },",
       "\t\t\t{ key = \"demonicsacrifice\", ranks = { 18788, 18789, 18790, 18791, 18792, 35701 }, talent = true },\n"
       "\t\t\t{ key = \"soullink\", ranks = { 19028, 25228 }, talent = true },",
       "missing-buffs: Burning Crusade's sacrifice ahead of Soul Link",
       expect="missing-buffs: tbc: a Soul Link warlock is never told to sacrifice his demon", script=S)

mutate(B,
       "\ttable.insert(TBC_OWN.WARLOCK, 2, { key = \"demonicsacrifice\", toggle = true,",
       "\ttable.insert(TBC_OWN.WARLOCK, 2, { key = \"demonicsacrifice\", toggle = true, optIn = true,",
       "missing-buffs: Burning Crusade's sacrifice off by default",
       expect="missing-buffs: the families each client has, every one on by default", script=S)

# ---------------------------------------------------------------- Tree of Life

mutate(B,
       "\t\t\ttable.insert(druid, i + 1, { key = \"treeoflife\", toggle = true, form = true,",
       "\t\t\ttable.insert(druid, i + 1, { key = \"treeoflife\", toggle = true,",
       "missing-buffs: Season of Discovery's Tree of Life nags in another form",
       expect="missing-buffs: vanilla: Tree of Life in caster form, never in another form", script=S)

mutate(B,
       "\tTBC_OWN.DRUID[#TBC_OWN.DRUID + 1] = { key = \"treeoflife\", toggle = true, form = true,",
       "\tTBC_OWN.DRUID[#TBC_OWN.DRUID + 1] = { key = \"treeoflife\", toggle = true,",
       "missing-buffs: Burning Crusade's Tree of Life nags in another form",
       expect="missing-buffs: tbc: Tree of Life in caster form, never in another form", script=S)

mutate(B,
       "\t\t\ttable.insert(druid, i + 1, { key = \"treeoflife\", toggle = true, form = true,",
       "\t\t\ttable.insert(druid, i, { key = \"treeoflife\", toggle = true, form = true,",
       "missing-buffs: Tree of Life asked for ahead of Moonkin Form",
       expect="missing-buffs: vanilla: a druid with both forms is asked for Moonkin Form", script=S)

mutate(B,
       "\t\t\t\tspells = { { key = \"treeoflife\", ranks = { 439733 }, talent = true } } })",
       "\t\t\t\tspells = { { key = \"treeoflife\", ranks = { 439733 }, talent = true, notWith = \"moonkinform\" } } })",
       "missing-buffs: Tree of Life never asked for beside Moonkin Form",
       expect="missing-buffs: vanilla: a druid with both forms is asked for Moonkin Form", script=S)

mutate(B,
       "\tVANILLA_SET.notFavour[439745] = true\n",
       "",
       "missing-buffs: the tree's party aura a favour",
       expect="missing-buffs: the lengths and the favours", script=S)

# ---------------------------------------------------------------- Spirit of the Alpha

mutate(B,
       "\t\t\ttable.insert(shaman, i + 1, { key = \"spiritofthealpha\", tank = true,",
       "\t\t\ttable.insert(shaman, i + 1, { key = \"spiritofthealpha\",",
       "missing-buffs: Spirit of the Alpha on a shaman who does not tank",
       expect="missing-buffs: vanilla: a shaman who tanks puts Spirit of the Alpha on himself", script=S)

mutate(B,
       "spells = { { key = \"spiritofthealpha\", ranks = { 408696, 443320 }, talent = true, castOnOthers = true,",
       "spells = { { key = \"spiritofthealpha\", ranks = { 408696 }, talent = true, castOnOthers = true,",
       "missing-buffs: Loyal Beta not the family up",
       expect="missing-buffs: vanilla: a shaman who tanks puts Spirit of the Alpha on himself", script=S)

mutate(B,
       "\tVANILLA.SHAMAN[#VANILLA.SHAMAN + 1] = { key = \"spiritofthealpha\", ranks = { 408696 }, oneTarget = true,",
       "\tVANILLA.SHAMAN[#VANILLA.SHAMAN + 1] = { key = \"spiritofthealpha\", ranks = { 408696 },",
       "missing-buffs: Spirit of the Alpha offered to everybody",
       expect="missing-buffs: vanilla: spiritofthealpha goes to the tank alone", script=S)

mutate(B,
       "\t\tif list[i].key == \"spiritofthealpha\" then table.remove(list, i) end\n",
       "",
       "missing-buffs: Spirit of the Alpha on Forever",
       expect="missing-buffs: the families each client has", script=S)

mutate(B,
       "\t\t{ 1800, 443320 }, -- Loyal Beta, what it gives the shaman cast on another (30 min)\n",
       "",
       "missing-buffs: Loyal Beta has no length",
       expect="missing-buffs: the lengths and the favours", script=S)

# ---------------------------------------------------------------- retail

mutate(C,
       "\t\t\t\tif other ~= nil and (other == true or other == opts.name) then return false end\n",
       "",
       "missing-buffs: Beacon of Faith on the tank wearing your Beacon of Light",
       expect="missing-buffs: mainline: Beacon of Faith goes to the other tank", script=S)

mutate(B,
       "\t\tif buff.key == \"beacon\" then buff.apartFrom = \"beaconoffaith\" end\n",
       "",
       "missing-buffs: Beacon of Light on the tank wearing your Beacon of Faith",
       expect="missing-buffs: mainline: Beacon of Faith goes to the other tank", script=S)

mutate(B,
       "\tMAINLINE.DRUID[#MAINLINE.DRUID + 1] = { key = \"symbioticrelationship\", ranks = { 474750 },\n"
       "\t\tgroup = { 474754 }, oneTarget = true,",
       "\tMAINLINE.DRUID[#MAINLINE.DRUID + 1] = { key = \"symbioticrelationship\", ranks = { 474750 },\n"
       "\t\tgroup = { 474754 },",
       "missing-buffs: Symbiotic Relationship offered to everybody",
       expect="missing-buffs: mainline: symbioticrelationship goes to the tank alone", script=S)

mutate(B,
       "\tMAINLINE.DRUID[#MAINLINE.DRUID + 1] = { key = \"symbioticrelationship\", ranks = { 474750 },\n"
       "\t\tgroup = { 474754 },",
       "\tMAINLINE.DRUID[#MAINLINE.DRUID + 1] = { key = \"symbioticrelationship\", ranks = { 474750 },\n"
       "\t\tgroup = { },",
       "missing-buffs: the bond on the ally not read",
       expect="missing-buffs: mainline: symbioticrelationship goes to the tank alone", script=S)

mutate(B,
       "\tMAINLINE_OWN[class] = MAINLINE_OWN[class] or {}\n\tAddFood(MAINLINE_OWN[class], \"mainline\")\n",
       "\tMAINLINE_OWN[class] = MAINLINE_OWN[class] or {}\n",
       "missing-buffs: retail's classes without their flasks",
       expect="missing-buffs: mainline: every class has the flasks", script=S)

# ---------------------------------------------------------------- the consumables

mutate(K,
       "\t\t\t{ 20007, 40, 24363 },\n\t\t\t{ 21546, 40, 26276 },",
       "\t\t\t{ 21546, 40, 26276 },",
       "missing-buffs: Classic Era without Mageblood Potion",
       expect="missing-buffs: vanilla: Mageblood and the Troll's Blood potions are elixirs", script=S)

mutate(B,
       "\t\t\tif row.auras then spells[i].auras = row.auras end\n",
       "",
       "missing-buffs: the Alchemist's Flask's auras not read",
       expect="missing-buffs: mists: the Alchemist's Flask and the Crystal of Insanity", script=S)

mutate(B,
       "\t\tfor _, id in ipairs(spell.auras or {}) do add(id) end\n",
       "",
       "missing-buffs: the family not up on the Alchemist's Flask's auras",
       expect="missing-buffs: mists: the Alchemist's Flask and the Crystal of Insanity", script=S)

# The elixir family's covers take a flask row's `auras` and also Consumables.lua's
# `fillsBoth` (the same three auras on Mists), so dropping either alone shows
# nothing: newbuffs-fixes.py holds the fillsBoth side.

mutate(K,
       "\t\t\t{ 241320, 81, 1235057 },\n",
       "",
       "missing-buffs: retail's better Thalassian flask left out",
       expect="missing-buffs: mainline: every class has the flasks, and the better tier first", script=S)

# ---------------------------------------------------------------- the page

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t{ \"who.own_demonicsacrifice\", indent = true },\n",
       "",
       "missing-buffs: Demonic Sacrifice not placed on the page",
       expect="who.own_demonicsacrifice is not placed under Myself", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t{ \"who.own_treeoflife\", indent = true },\n",
       "",
       "missing-buffs: Tree of Life not placed on the page",
       expect="who.own_treeoflife is not placed under Myself", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t{ \"who.own_spiritofthealpha\", indent = true },\n",
       "",
       "missing-buffs: Spirit of the Alpha not placed on the page",
       expect="who.own_spiritofthealpha is not placed under Myself", script=S)
