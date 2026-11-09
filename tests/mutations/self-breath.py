# Mutations for a warlock's Unending Breath on himself while he swims (Buffs.lua's
# selfbreath family on every client, Core.lua's Swimming and its hold, the
# label, the debug line, the switch and its place on the page). Each is caught by
# the scenario in tests/scenarios/self-breath.lua that names it.

S = "runscenarios.py"

mutate("Core.lua",
       "\t\tif family.swimming and not Swimming(ctx.now or GetTime()) then return nil, nil, nil, \"dry\" end\n",
       "",
       "self-breath: offered on dry land",
       expect="self-breath: camelot: never on dry land, offered while swimming", script=S)

mutate("Core.lua",
       "\t\treturn swamAt ~= nil and now >= swamAt and now - swamAt < SWIM_HOLD\n",
       "\t\treturn false\n",
       "self-breath: no hold past the last stroke",
       expect="self-breath: held a moment past the last stroke, then let go", script=S)

mutate("Core.lua",
       "\t\treturn swamAt ~= nil and now >= swamAt and now - swamAt < SWIM_HOLD\n",
       "\t\treturn swamAt ~= nil\n",
       "self-breath: the hold never lets go",
       expect="self-breath: held a moment past the last stroke, then let go", script=S)

mutate("Core.lua",
       "\t\tif family.swimming then\n\t\t\treturn L[\"%s while swimming\"]",
       "\t\tif false then\n\t\t\treturn L[\"%s while swimming\"]",
       "self-breath: the row named like the buff for others",
       expect="self-breath: on by default, a switch of its own under Myself, and it turns off", script=S)

mutate("Core.lua",
       "\t\tif family.optIn then defaults.profile.ownBuffs.pick[family.key] = \"off\" end\n",
       "\t\tif family.optIn or family.swimming then defaults.profile.ownBuffs.pick[family.key] = \"off\" end\n",
       "self-breath: off by default",
       expect="self-breath: on by default, a switch of its own under Myself, and it turns off", script=S)

mutate("Commands.lua",
       "\t\telseif why == \"dry\" then\n",
       "\t\telseif why == \"dry-\" then\n",
       "self-breath: /manners debug quiet about swimming",
       expect="self-breath: camelot: never on dry land, offered while swimming", script=S)

mutate("Options/Who.lua",
       "\t\t\t\t\tor family.swimming\n\t\t\t\t\tand L[",
       "\t\t\t\t\tor false\n\t\t\t\t\tand L[",
       "self-breath: the switch says nothing of the water",
       expect="self-breath: on by default, a switch of its own under Myself, and it turns off", script=S)

mutate("Buffs.lua",
       "\t\tspells = { { key = \"selfbreath\", ranks = { 5697 }, group = group, anyCaster = true, castOnOthers = true } } }\n",
       "\t\tspells = { { key = \"selfbreath\", ranks = { 5697 }, group = group, castOnOthers = true } } }\n",
       "self-breath: another warlock's does not count",
       expect="self-breath: yours, another warlock's or a shaman's Water Breathing on you, nothing offered", script=S)

mutate("Buffs.lua",
       "\t\tspells = { { key = \"selfbreath\", ranks = { 5697 }, group = group, anyCaster = true, castOnOthers = true } } }\n",
       "\t\tspells = { { key = \"selfbreath\", ranks = { 5697 }, group = group, anyCaster = true } } }\n",
       "self-breath: Unending Breath on you no longer a favour",
       expect="self-breath: a warlock's own family on every client", script=S)

mutate("Buffs.lua",
       "\t\t\t\tfor _, id in ipairs(spell.group or {}) do spell.auraIds[#spell.auraIds + 1] = id end\n",
       "",
       "self-breath: a shaman's Water Breathing not counted",
       expect="self-breath: yours, another warlock's or a shaman's Water Breathing on you, nothing offered", script=S)

mutate("Buffs.lua",
       "table.insert(VANILLA_OWN.WARLOCK, 1, SelfBreath({ 131 }))\n",
       "",
       "self-breath: none on Classic Era and Forever",
       expect="self-breath: vanilla: never on dry land, offered while swimming", script=S)

mutate("Buffs.lua",
       "table.insert(VANILLA_OWN.WARLOCK, 1, SelfBreath({ 131 }))\n",
       "table.insert(VANILLA_OWN.WARLOCK, SelfBreath({ 131 }))\n",
       "self-breath: after the armor",
       expect="self-breath: a warlock's own family on every client, first of his own", script=S)

mutate("Buffs.lua",
       "\ttable.insert(TBC_OWN.WARLOCK, 1, SelfBreath({ 131 }))\n",
       "",
       "self-breath: none on Burning Crusade",
       expect="self-breath: tbc: never on dry land, offered while swimming", script=S)

mutate("Buffs.lua",
       "\tAt(\"WARLOCK\", 1, SelfBreath(nil))\n",
       "",
       "self-breath: none on Mists",
       expect="self-breath: mists: never on dry land, offered while swimming", script=S)

mutate("Buffs.lua",
       "\t\tSelfBreath(nil),\n",
       "",
       "self-breath: none on retail",
       expect="self-breath: mainline: never on dry land, offered while swimming", script=S)

mutate("Queue.lua",
       "\tif InCombatLockdown() or safecall(_G.UnitAffectingCombat, \"player\") == true then return \"fight\" end\n",
       "\tif InCombatLockdown() then return \"fight\" end\n",
       "self-breath: armed on yourself for the fight",
       expect="self-breath: not in a fight, and offered once it ends while still swimming", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t{ \"who.own_selfbreath\", indent = true },\n",
       "",
       "self-breath: the switch is not placed on the page",
       expect="every control has one place in the options window", script=S)
