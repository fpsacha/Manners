# Mutations for the r37 newbuffs fixes: each undoes one fix and is caught by the
# scenario in tests/scenarios/newbuffs-fixes.lua that names it.

S = "runscenarios.py"

# --- Heart of the Lion: another hunter's does not stand in for yours ---

mutate("Buffs.lua",
       "\t\t\ttable.insert(hunter, i + 1, { key = \"heartofthelion\", toggle = true,\n",
       "\t\t\ttable.insert(hunter, i + 1, { key = \"heartofthelion\", toggle = true, shared = true,\n",
       "newbuffs-fixes: Heart of the Lion shared again",
       expect="newbuffs-fix: another hunter's Heart of the Lion does not stand in for your own", script=S)

# --- retail's off-hand Flametongue needs a weapon in the off hand ---

mutate("Core.lua",
       "\t\telseif spell.needsWeapon and HandWeapon(family.slot or 16) == false then\n",
       "\t\telseif false then\n",
       "newbuffs-fixes: the off-hand Flametongue offered with no weapon there",
       expect="newbuffs-fix: no off-hand Flametongue with no weapon in the off hand", script=S)

mutate("Core.lua",
       "\t\t\t\tif auto and spell.needsWeapon and HandWeapon(family.slot or 16) == false then\n",
       "\t\t\t\tif false then\n",
       "newbuffs-fixes: Automatic keeps the off-hand Flametongue over the Ward",
       expect="newbuffs-fix: no off-hand Flametongue with no weapon in the off hand", script=S)

# --- Mists' scrolls are elixirs ---

mutate("Buffs.lua",
       "\t\tif data.scrollSlots then\n",
       "\t\tif false then\n",
       "newbuffs-fixes: a Mists scroll is no elixir",
       expect="newbuffs-fix: a Mists scroll is an elixir, held back under a flask", script=S)

# --- area-only flasks after the others ---

mutate("Consumables.lua",
       "\ttbc = {\n\t\tflaskFills = true,\n\t\tflask = {\n",
       "\ttbc = {\n\t\tflaskFills = true,\n\t\tflask = {\n\t\t\t{ 32901, 70, 41608 },\n",
       "newbuffs-fixes: Shattrath's flask first",
       expect="newbuffs-fix: a Shattrath flask is not Automatic's first outside its raids", script=S)

# --- an experience elixir is no flask ---

mutate("Consumables.lua",
       "\t\t\t{ 35717, 70, 46839 },\n\t\t},\n\t\telixir = {\n\t\t\t{ 76075, 85, 105681 },\n",
       "\t\t\t{ 35717, 70, 46839 },\n\t\t\t{ 103557, 1, 146939 },\n\t\t},\n\t\telixir = {\n\t\t\t{ 76075, 85, 105681 },\n",
       "newbuffs-fixes: the experience elixir a flask",
       expect="newbuffs-fix: an experience elixir is no flask at the level cap", script=S)

# --- what fills both elixir slots ---

mutate("Consumables.lua",
       "\t\tfillsBoth = { 79638, 79639, 79640, 127230 },\n",
       "",
       "newbuffs-fixes: the Alchemist's Flask and the Crystal not read",
       expect="newbuffs-fix: the Alchemist's Flask and the Crystal of Insanity fill both elixir slots", script=S)

mutate("Buffs.lua",
       "\t\tif flask and data.fillsBoth then\n",
       "\t\tif false then\n",
       "newbuffs-fixes: the Flask switch does not read the Crystal",
       expect="newbuffs-fix: the Alchemist's Flask and the Crystal of Insanity fill both elixir slots", script=S)

# --- a weaker class buff holds no scroll back ---

mutate("Buffs.lua",
       "\t\t\t\t\tif not (weakest and value and value < weakest) then add(id) end\n",
       "\t\t\t\t\tadd(id)\n",
       "newbuffs-fixes: any rank of a class buff holds a scroll back",
       expect="newbuffs-fix: a weaker Arcane Intellect does not hold a stronger scroll back", script=S)

# --- Symbiosis is read on the member ---

mutate("Buffs.lua",
       "\t\tgroup = { 110478, 110479, 110482, 110483, 110484, 110485, 110486, 110488, 110490, 110491 } }",
       "\t\t}",
       "newbuffs-fixes: Symbiosis read on the druid alone",
       expect="newbuffs-fix: a member linked by another druid's Symbiosis is not offered it", script=S)

# --- a favour's tank and class reach CouldOffer ---

mutate("Favours.lua",
       "\t\t\tisTank = isTank,\n",
       "",
       "newbuffs-fixes: a favour from the tank turned down",
       expect="newbuffs-fix: the tank's favour is owed to a shaman whose only buff is Earth Shield", script=S)

mutate("Favours.lua",
       "\t\t\tclass = class,\n",
       "",
       "newbuffs-fixes: a favour from a member who is no druid turned down",
       expect="newbuffs-fix: the tank's favour is owed to a shaman whose only buff is Earth Shield", script=S)

# --- the Oath and a blessing are noted apart ---

mutate("Queue.lua",
       "\t\tentry[buffKey] = GetTime()\n",
       "\t\tfor other in pairs(entry) do entry[other] = nil end\n\t\tentry[buffKey] = GetTime()\n",
       "newbuffs-fixes: a blessing's cast forgets the Oath's",
       expect="newbuffs-fix: a blessing after your Oath does not hand the Oath to a second tank", script=S)

# The greeting's one-target line is held by engine-fixes.py
# ("engine-fix: the greeting promises it to the group").
