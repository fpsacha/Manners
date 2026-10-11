# Mutations for round 34's data fixes: Mists' Commanding Shout (Buffs.lua), Water
# Shield's three charges on Forever and Classic Era (Buffs.lua), and the
# self-test's checks about Forever's scrolls on the clients that have none
# (Selftest.lua). Each undoes a fix and is caught by the scenario in
# tests/scenarios/data-fixes.lua it names.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# ------------------------------------------------ Mists: Commanding Shout
# The warrior's second shout gone from the set: a party wearing Battle Shout is
# offered nothing, and another warrior's Commanding Shout on you is no favour.
mutate("Buffs.lua",
       "\t\t{ key = \"commandingshout\", ranks = { 469 }, selfCast = true, partyOnly = true, alike = { 21562, 109773 } },\n",
       "",
       "data-fix: Mists warrior without Commanding Shout",
       expect="data-fix: mists: a party wearing Battle Shout is offered Commanding Shout", script=S)

mutate("Buffs.lua",
       "\t\t{ key = \"commandingshout\", ranks = { 469 }, selfCast = true, partyOnly = true, alike = { 21562, 109773 } },\n",
       "",
       "data-fix: Mists Commanding Shout from another warrior no favour",
       expect="data-fix: mists: Commanding Shout from another warrior is a favour", script=S)

mutate("Buffs.lua",
       "\t\t{ key = \"commandingshout\", ranks = { 469 }, selfCast = true, partyOnly = true, alike = { 21562, 109773 } },\n",
       "",
       "data-fix: Mists Commanding Shout out of the raid's reach",
       expect="data-fix: mists: Commanding Shout reaches a raider in another raid group", script=S)

# Cast at a target, as the TBC mutation does for its own entry.
mutate("Buffs.lua",
       "ranks = { 469 }, selfCast = true, partyOnly = true, alike = { 21562, 109773 } },",
       "ranks = { 469 }, partyOnly = true, alike = { 21562, 109773 } },",
       "data-fix: Mists Commanding Shout aimed at a target",
       expect="data-fix: mists: a party wearing Battle Shout is offered Commanding Shout", script=S)

# Offered to a passer-by it does not reach.
mutate("Buffs.lua",
       "ranks = { 469 }, selfCast = true, partyOnly = true, alike = { 21562, 109773 } },",
       "ranks = { 469 }, selfCast = true, alike = { 21562, 109773 } },",
       "data-fix: Mists Commanding Shout offered to passers-by",
       expect="data-fix: mists: a party wearing Battle Shout is offered Commanding Shout", script=S)

# The other 10% Stamina buffs: somebody wearing Fortitude or Dark Intent is
# offered a shout that would add nothing.
mutate("Buffs.lua",
       "ranks = { 469 }, selfCast = true, partyOnly = true, alike = { 21562, 109773 } },",
       "ranks = { 469 }, selfCast = true, partyOnly = true, alike = { 109773 } },",
       "data-fix: Mists Commanding Shout over Fortitude",
       expect="data-fix: mists: a party wearing Power Word: Fortitude is not offered Commanding Shout", script=S)

mutate("Buffs.lua",
       "ranks = { 469 }, selfCast = true, partyOnly = true, alike = { 21562, 109773 } },",
       "ranks = { 469 }, selfCast = true, partyOnly = true, alike = { 21562 } },",
       "data-fix: Mists Commanding Shout over Dark Intent",
       expect="data-fix: mists: a party wearing Dark Intent is not offered Commanding Shout", script=S)

# ------------------------------------------------ Water Shield's charges
mutate("Buffs.lua",
       "\t\t\t\t{ key = \"watershield\", ranks = { 408510 }, talent = true, charges = 3 },\n",
       "\t\t\t\t{ key = \"watershield\", ranks = { 408510 }, talent = true },\n",
       "data-fix: Forever's Water Shield without its charges",
       expect="data-fix: camelot: a Water Shield on its last charge is topped up", script=S)

mutate("Buffs.lua",
       "\t\t\t\t{ key = \"watershield\", ranks = { 408510 }, talent = true, charges = 3 },\n",
       "\t\t\t\t{ key = \"watershield\", ranks = { 408510 }, talent = true },\n",
       "data-fix: Classic Era's Water Shield without its charges",
       expect="data-fix: vanilla: a Water Shield on its last charge is topped up", script=S)

# ------------------------------------------------ the self-test and Forever's scrolls
# Each of the four checks asked on a client and a class that have no imbue.
mutate("Selftest.lua",
       "\tend, NoImbueWhy)\n",
       "\tend)\n",
       "data-fix: selftest api.weaponEnchants warns without scrolls",
       expect="data-fix: vanilla: the selftest does not warn about Forever's scrolls", script=S)

mutate("Selftest.lua",
       "\t\tlocal idle = NoImbueWhy()\n\t\tif idle then\n",
       "\t\tlocal idle = NoImbueWhy()\n\t\tif false then\n",
       "data-fix: selftest api.enums warns without scrolls",
       expect="data-fix: vanilla: the selftest does not warn about Forever's scrolls", script=S)

mutate("Selftest.lua",
       "is missing\", nil, NoImbueWhy)\n",
       "is missing\")\n",
       "data-fix: selftest api.tempEnchant warns without scrolls",
       expect="data-fix: vanilla: the selftest does not warn about Forever's scrolls", script=S)

mutate("Selftest.lua",
       "\t\tlocal idle = okL == MISSING and NoImbueWhy()\n",
       "\t\tlocal idle = nil\n",
       "data-fix: selftest beliefs.mainHand warns without scrolls",
       expect="data-fix: vanilla: the selftest does not warn about Forever's scrolls", script=S)

# A class that has an imbue is always asked (the control), and one that has
# none never is.
mutate("Selftest.lua",
       "\tif ImbueFamily() then return nil end\n",
       "\tif false then return nil end\n",
       "data-fix: selftest never asks for weapon imbues",
       expect="data-fix: camelot: a mage's missing weapon enchant calls are still reported", script=S)

mutate("Selftest.lua",
       "\tif ImbueFamily() then return nil end\n",
       "\tdo return nil end\n",
       "data-fix: selftest always asks for weapon imbues",
       expect="data-fix: camelot: a warrior's selftest does not ask for weapon imbues", script=S)
