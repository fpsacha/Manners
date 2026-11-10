# Mutations for Might held back from mages, warlocks and priests (Core.lua
# Castable and the default, Queue.lua, Buffs.lua's meleeOnly, Options/Who.lua).
# Each is caught by the scenario in tests/scenarios/castersmight.lua that
# names it.

S = "runscenarios.py"

mutate("Core.lua",
       "\t\tif opts.casterOnly and buff.meleeOnly and not opts.asked then return false end\n",
       "",
       "castersmight: the switch is never read",
       expect="castersmight: vanilla: on, a mage, a warlock and a priest are offered Kings, a warrior still Might", script=S)

mutate("Core.lua",
       "\t\tif opts.casterOnly and buff.meleeOnly and not opts.asked then return false end\n",
       "\t\tif opts.casterOnly and buff.meleeOnly then return false end\n",
       "castersmight: somebody who asks by name is held back too",
       expect="castersmight: somebody who asks for Might by name is still offered it", script=S)

mutate("Core.lua",
       "\t\tif opts.casterOnly and buff.meleeOnly and not opts.asked then return false end\n",
       "\t\tif opts.casterOnly and not opts.asked then return false end\n",
       "castersmight: every buff is held back from a caster",
       expect="castersmight: vanilla: on, a mage, a warlock and a priest are offered Kings, a warrior still Might", script=S)

mutate("Queue.lua",
       "\t\topts.casterOnly = skipCasters and ns.CASTER_CLASSES[plain(select(2, UnitClass(unit)))] or nil\n",
       "\t\topts.casterOnly = ns.CASTER_CLASSES[plain(select(2, UnitClass(unit)))] or nil\n",
       "castersmight: held back with the switch off",
       expect="castersmight: vanilla: off by default, casters are offered Might as ever", script=S)

mutate("Core.lua",
       "ns.CASTER_CLASSES = { MAGE = true, WARLOCK = true, PRIEST = true }\n",
       "ns.CASTER_CLASSES = { MAGE = true, WARLOCK = true, PRIEST = true, DRUID = true, SHAMAN = true }\n",
       "castersmight: a druid and a shaman are held back too",
       expect="castersmight: vanilla: on, a druid and a shaman are still offered Might", script=S)

mutate("Core.lua",
       "ns.CASTER_CLASSES = { MAGE = true, WARLOCK = true, PRIEST = true }\n",
       "ns.CASTER_CLASSES = { MAGE = true, WARLOCK = true }\n",
       "castersmight: a priest is offered Might",
       expect="castersmight: vanilla: on, a mage, a warlock and a priest are offered Kings, a warrior still Might", script=S)

mutate("Buffs.lua",
       "\t\t\tkey = \"might\",\n\t\t\tmeleeOnly = true,\n\t\t\tranks = { 25291, 19838, 19837, 19836, 19835, 19834, 19740 },\n",
       "\t\t\tkey = \"might\",\n\t\t\tranks = { 25291, 19838, 19837, 19836, 19835, 19834, 19740 },\n",
       "castersmight: Might is not flagged on Classic Era",
       expect="castersmight: vanilla: on, a mage, a warlock and a priest are offered Kings, a warrior still Might", script=S)

mutate("Buffs.lua",
       "\t\t\tkey = \"might\",\n\t\t\tmeleeOnly = true,\n\t\t\tranks = { 27140, 25291, 19838, 19837, 19836, 19835, 19834, 19740 },\n",
       "\t\t\tkey = \"might\",\n\t\t\tranks = { 27140, 25291, 19838, 19837, 19836, 19835, 19834, 19740 },\n",
       "castersmight: Might is not flagged on Burning Crusade",
       expect="castersmight: tbc: on, a mage, a warlock and a priest are offered Kings, a warrior still Might", script=S)

mutate("Core.lua",
       "\t\t\tskipCasters = false,\n",
       "\t\t\tskipCasters = true,\n",
       "castersmight: on by default",
       expect="castersmight: vanilla: off by default, casters are offered Might as ever", script=S)

mutate("Options/Who.lua",
       "\t\t\t\t\tfor _, buff in ipairs(ns.GetClassBuffs(ns.caps.class) or {}) do\n\t\t\t\t\t\tif buff.meleeOnly then return false end\n\t\t\t\t\tend\n\t\t\t\t\treturn true\n",
       "\t\t\t\t\treturn false\n",
       "castersmight: every class is shown the switch",
       expect="castersmight: Who to buff has the switch for a paladin and for nobody else", script=S)

mutate("Options/Who.lua",
       "\t\t\t\tget = function() return B().skipCasters == true end,\n",
       "\t\t\t\tget = function() return false end,\n",
       "castersmight: the switch shows nothing",
       expect="castersmight: Who to buff has the switch for a paladin and for nobody else", script=S)
