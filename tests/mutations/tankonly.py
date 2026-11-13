# Mutations for Thorns held to the tanks of a group (Core.lua Castable and
# IsTankUnit, Queue.lua's per-person fields, Options/Who.lua, the layout slot,
# ClampSettings and the share list). Each is caught by the scenario in
# tests/scenarios/tankonly.lua that names it.

S = "runscenarios.py"

GATE = "\t\tif opts.tanksOnly and buff.tankChoice and opts.tanksOnly[buff.key] and opts.inGroup\n"

mutate("Core.lua", GATE,
       "\t\tif false and opts.tanksOnly and buff.tankChoice and opts.tanksOnly[buff.key] and opts.inGroup\n",
       "tankonly: the choice never holds a buff back",
       expect="tankonly: held to tanks, only the tank of the party is offered Thorns", script=S)

mutate("Core.lua", GATE,
       "\t\tif opts.tanksOnly and buff.tankChoice and opts.tanksOnly[buff.key]\n",
       "tankonly: held for passers-by too",
       expect="tankonly: held to tanks, a passer-by outside the group is offered Thorns as ever", script=S)

mutate("Core.lua", GATE,
       "\t\tif opts.tanksOnly and opts.tanksOnly[buff.key] and opts.inGroup\n",
       "tankonly: every buff held",
       expect="tankonly: a buff without the choice is never held, whatever the set says", script=S)

mutate("Queue.lua",
       "\t\tlocal tanksOnly = not asked and tanksHeld or nil\n",
       "\t\tlocal tanksOnly = tanksHeld\n",
       "tankonly: a request is held to the tanks",
       expect="tankonly: held to tanks, somebody who asks for Thorns is offered it", script=S)

mutate("Queue.lua",
       "\t\topts.isTank = tanksOnly and inGroup and ns.IsTankUnit(unit) or nil\n",
       "\t\topts.isTank = tanksOnly and inGroup and true or nil\n",
       "tankonly: everybody is a tank",
       expect="tankonly: held to tanks, somebody with no role is not a tank", script=S)

mutate("Core.lua",
       "\t\tif type(roles) == \"function\" and plain(roles(unit)) == \"TANK\" then return true end\n",
       "",
       "tankonly: the assigned role is not read",
       expect="tankonly: held to tanks, only the tank of the party is offered Thorns", script=S)

mutate("Core.lua",
       "\t\t\treturn plain(role) == \"MAINTANK\" or plain(combatRole) == \"TANK\"\n",
       "\t\t\treturn false\n",
       "tankonly: the main tank mark is not read",
       expect="tankonly: held to tanks, the main tank of a raid is offered Thorns", script=S)

mutate("Options/Who.lua",
       "\t\t\t\t\tB().tanksOnly[buff.key] = (value == \"tanks\") or nil\n",
       "\t\t\t\t\tB().tanksOnly[buff.key] = nil\n",
       "tankonly: the choice is never kept",
       expect="tankonly: Who to buff offers the choice for Thorns, and it is kept", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\tif buff.tankChoice then items[#items + 1] = { \"who.tank_\" .. tostring(buff.key), indent = true } end\n",
       "",
       "tankonly: the choice is not placed on the page",
       expect="tank_thorns", script=S)

mutate("Core.lua",
       "\tif type(profile.buff.tanksOnly) ~= \"table\" then profile.buff.tanksOnly = {} end\n",
       "",
       "tankonly: a damaged set is never repaired",
       expect="tankonly: the set is repaired and travels with a profile", script=S)

mutate("Commands.lua",
       "elseif name == \"buff.skip\" or name == \"buff.tanksOnly\" or name == \"buff.meOnly\"\n",
       "elseif name == \"buff.skip\" or name == \"buff.meOnly\"\n",
       "tankonly: the choice does not travel with a profile",
       expect="tankonly: the set is repaired and travels with a profile", script=S)

mutate("Options/Advanced.lua",
       "\t\t\"buff.choice\", \"buff.skip\", \"buff.tanksOnly\", \"buff.meOnly\", \"buff.kingsFirst\", \"buff.order\", \"filters.relevantOnly\",\n",
       "\t\t\"buff.choice\", \"buff.skip\", \"buff.kingsFirst\", \"buff.order\", \"filters.relevantOnly\",\n",
       "tankonly: the page's reset leaves the choice",
       expect="model: the reset puts who back", script=S)


# --- Offer to: Only me (1.11.7) ---
mutate("Core.lua",
       "\t\tif opts.meOnly and buff.tankChoice and opts.meOnly[buff.key] then return false end\n",
       "",
       "tankonly: Only me holds nothing back",
       expect="tankonly: Only me offers nobody else the buff and still reminds you", script=S)

mutate("Queue.lua",
       "\t\topts.meOnly = not asked and meHeld or nil\n",
       "\t\topts.meOnly = meHeld\n",
       "tankonly: a request is held to you alone",
       expect="tankonly: Only me still answers somebody who asks for the buff by name", script=S)

mutate("Options/Who.lua",
       "\t\t\t\t\tB().meOnly[buff.key] = (value == \"me\") or nil\n",
       "",
       "tankonly: Only me is never cleared",
       expect="tankonly: the choice is one of three, and each leaves the others' key behind never", script=S)

mutate("Options/Who.lua",
       "\t\t\t\t\tif B().meOnly[buff.key] then return \"me\" end\n",
       "",
       "tankonly: Only me is never read back",
       expect="tankonly: the choice is one of three, and each leaves the others' key behind never", script=S)

mutate("Core.lua",
       "\tif type(profile.buff.meOnly) ~= \"table\" then profile.buff.meOnly = {} end\n",
       "",
       "tankonly: a damaged Only me set is never repaired",
       expect="tankonly: the Only me set is repaired and travels with a profile", script=S)

mutate("Commands.lua",
       "elseif name == \"buff.skip\" or name == \"buff.tanksOnly\" or name == \"buff.meOnly\"\n",
       "elseif name == \"buff.skip\" or name == \"buff.tanksOnly\"\n",
       "tankonly: Only me does not travel with a profile",
       expect="tankonly: the Only me set is repaired and travels with a profile", script=S)

mutate("Options/Advanced.lua",
       "\"buff.skip\", \"buff.tanksOnly\", \"buff.meOnly\", \"buff.kingsFirst\"",
       "\"buff.skip\", \"buff.tanksOnly\", \"buff.kingsFirst\"",
       "tankonly: the page's reset leaves Only me",
       expect="model: the reset puts who back", script=S)

# --- the two paths the fuzzer found (1.11.9) ---
mutate("Queue.lua",
       "\tif memo.buff.tankChoice and meOnly and meOnly[key] and memo.reason ~= \"asked\" then return false end\n",
       "",
       "tankonly: a remembered passer-by keeps a buff held to you",
       expect="tankonly: Only me holds a passer-by remembered before it was set", script=S)

mutate("Queue.lua",
       "\t\t\tmeOnly = meHeld,\n",
       "",
       "tankonly: a favour out of sight is offered a buff held to you",
       expect="tankonly: Only me holds a favour owed to somebody out of sight", script=S)


# --- Tanks only made to mean it, and the looser choice kept ---
# Tanks only narrowed the group alone until a player took that for a bug:
# nobody outside the group is offered the buff now, and "Tanks, and anyone
# outside my group" (buff.tanksOutside) is what it did before.
STRICT = "\t\tif opts.tanksOnly and buff.tankChoice and opts.tanksOnly[buff.key] and not opts.inGroup\n"

mutate("Core.lua", STRICT,
       "\t\tif false and opts.tanksOnly and buff.tankChoice and opts.tanksOnly[buff.key] and not opts.inGroup\n",
       "tankonly: Tanks only still offers passers-by the buff",
       expect="tankonly: Tanks only offers nobody outside the group Thorns", script=S)

mutate("Core.lua",
       "\t\t\tand not (opts.tanksOutside and opts.tanksOutside[buff.key]) then\n",
       "\t\t\tthen\n",
       "tankonly: the looser choice holds passers-by back too",
       expect="tankonly: held to tanks, a passer-by outside the group is offered Thorns as ever", script=S)

mutate("Core.lua", STRICT,
       "\t\tif opts.tanksOnly and opts.tanksOnly[buff.key] and not opts.inGroup\n",
       "tankonly: every buff held from passers-by",
       expect="tankonly: a buff without the choice is never held, whatever the set says", script=S)

mutate("Queue.lua",
       "\tlocal opts = { unpaid = UNPAID, tanksOutside = tanksOutside }\n",
       "\tlocal opts = { unpaid = UNPAID }\n",
       "tankonly: the scan is not told of the looser choice",
       expect="tankonly: held to tanks, a passer-by outside the group is offered Thorns as ever", script=S)

mutate("Queue.lua",
       "\tlocal tanksOutside = tanksHeld and db.buff.tanksOutside or nil\n",
       "\tlocal tanksOutside = tanksHeld\n",
       "tankonly: Tanks only read as the looser choice",
       expect="tankonly: Tanks only offers nobody outside the group Thorns", script=S)

mutate("Queue.lua",
       "\t\t\ttanksOnly = tanksHeld,\n\t\t\ttanksOutside = tanksOutside,\n",
       "",
       "tankonly: a favour out of sight is offered a buff held to tanks",
       expect="tankonly: Tanks only holds a favour owed to somebody out of sight", script=S)

mutate("Queue.lua",
       "\t\t\ttanksOnly = tanksHeld,\n\t\t\ttanksOutside = tanksOutside,\n",
       "\t\t\ttanksOnly = tanksHeld,\n",
       "tankonly: the looser choice holds a favour out of sight",
       expect="tankonly: Tanks only holds a favour owed to somebody out of sight", script=S)

mutate("Queue.lua",
       "\tif memo.buff.tankChoice and tanksOnly and tanksOnly[key] and memo.reason ~= \"asked\"\n",
       "\tif false and memo.buff.tankChoice and tanksOnly and tanksOnly[key] and memo.reason ~= \"asked\"\n",
       "tankonly: a remembered passer-by keeps a buff held to tanks",
       expect="tankonly: Tanks only holds a passer-by remembered before it was set", script=S)

mutate("Queue.lua",
       "\t\tand not (db.buff.tanksOutside and db.buff.tanksOutside[key]) then\n",
       "\t\tthen\n",
       "tankonly: the looser choice lets a remembered passer-by go",
       expect="tankonly: Tanks only holds a passer-by remembered before it was set", script=S)

mutate("Options/Who.lua",
       "\t\t\t\t\tif B().tanksOnly[buff.key] and B().tanksOutside[buff.key] then return \"outside\" end\n",
       "",
       "tankonly: the looser choice is never read back",
       expect="tankonly: the looser tank choice is kept in both sets, and the others clear it", script=S)

mutate("Options/Who.lua",
       "\t\t\t\t\tif value == \"outside\" then B().tanksOnly[buff.key] = true end\n",
       "",
       "tankonly: the looser choice does not hold the group to its tanks",
       expect="tankonly: the looser tank choice is kept in both sets, and the others clear it", script=S)

mutate("Options/Who.lua",
       "\t\t\t\t\tB().tanksOutside[buff.key] = (value == \"outside\") or nil\n",
       "\t\t\t\t\tif value == \"outside\" then B().tanksOutside[buff.key] = true end\n",
       "tankonly: the looser choice is never cleared",
       expect="tankonly: the looser tank choice is kept in both sets, and the others clear it", script=S)

mutate("Options/Who.lua",
       "\t\t\t\tsorting = { \"all\", \"tanks\", \"outside\", \"me\" },\n",
       "\t\t\t\tsorting = { \"all\", \"outside\", \"tanks\", \"me\" },\n",
       "tankonly: the looser choice listed ahead of Tanks only",
       expect="tankonly: the looser tank choice is kept in both sets, and the others clear it", script=S)

mutate("Core.lua",
       "\tif type(profile.buff.tanksOutside) ~= \"table\" then profile.buff.tanksOutside = {} end\n",
       "",
       "tankonly: a damaged looser set is never repaired",
       expect="tankonly: the looser set is repaired and travels with a profile", script=S)

mutate("Commands.lua",
       "\t\t\t\t\t\t\tor name == \"buff.tanksOutside\"\n",
       "",
       "tankonly: the looser choice does not travel with a profile",
       expect="tankonly: the looser set is repaired and travels with a profile", script=S)

mutate("Options/Advanced.lua",
       "\t\t\"buff.tanksOutside\",\n",
       "",
       "tankonly: the page's reset leaves the looser choice",
       expect="model: the reset puts who back", script=S)
