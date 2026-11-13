# Mutations for Dampen Magic and Amplify Magic on yourself (Buffs.lua,
# magicmod; GitHub issue #14). Caught by tests/scenarios/dampenmagic.lua.

S = "runscenarios.py"

mutate("Buffs.lua",
       "\t\t{ key = \"magicmod\", optIn = true,\n\t\t\tspells = {\n\t\t\t\t{ key = \"dampenmagic\", ranks = { 10174,",
       "\t\t{ key = \"magicmod\",\n\t\t\tspells = {\n\t\t\t\t{ key = \"dampenmagic\", ranks = { 10174,",
       "dampenmagic: on for every mage who never asked",
       expect="on a new profile, not off", script=S)

mutate("Buffs.lua",
       "\t\t\t\t{ key = \"amplifymagic\", ranks = { 10170, 10169, 8455, 1008 }, solo = \"amplifyAlone\" },\n",
       "",
       "dampenmagic: Amplify Magic left out on Classic Era and Forever",
       expect="dampenmagic: a mage's family on Forever", script=S)

mutate("Buffs.lua",
       "\t\t\t\t{ key = \"dampenmagic\", ranks = { 33944, 10174,",
       "\t\t\t\t{ key = \"dampenmagic\", ranks = { 10174,",
       "dampenmagic: Burning Crusade's sixth rank forgotten",
       expect="dampenmagic: a mage's family on Forever", script=S)

mutate("Buffs.lua",
       "\t\t{ 600, 10174, 10173, 8451, 8450, 604 }, -- Dampen Magic (10 min)\n\t\t{ 600, 10170, 10169, 8455, 1008 }, -- Amplify Magic (10 min)\n\t\t{ 3600, 1302303,",
       "\t\t{ 3600, 1302303,",
       "dampenmagic: Forever has no length for it",
       expect="its length is not ten minutes", script=S)

# --- only when alone ---

mutate("Core.lua",
       "\t\tif spell.solo and addon.db.profile.ownBuffs[spell.solo] ~= false\n",
       "\t\tif false and addon.db.profile.ownBuffs[spell.solo] ~= false\n",
       "dampenmagic: offered in a group with the switch on",
       expect="offered in a group with the switch on", script=S)

mutate("Core.lua",
       "\t\tif spell.solo and addon.db.profile.ownBuffs[spell.solo] ~= false\n",
       "\t\tif spell.solo\n",
       "dampenmagic: the switch never read",
       expect="the switch off, not offered in a group", script=S)

mutate("Core.lua",
       "\t\t\tand (plain(GetNumGroupMembers and GetNumGroupMembers()) or 0) > 0 then\n\t\t\treturn nil, up, left, \"grouped\", spell\n",
       "\t\t\tthen\n\t\t\treturn nil, up, left, \"grouped\", spell\n",
       "dampenmagic: held back alone too",
       expect="dampenmagic: in a group Dampen Magic waits", script=S)

mutate("Buffs.lua",
       "\t\t\t\t{ key = \"dampenmagic\", ranks = { 10174, 10173, 8451, 8450, 604 }, solo = \"dampenAlone\" },\n",
       "\t\t\t\t{ key = \"dampenmagic\", ranks = { 10174, 10173, 8451, 8450, 604 } },\n",
       "dampenmagic: Forever's not marked solo",
       expect="offered in a group with the switch on", script=S)

mutate("Core.lua",
       "\t\t\tdampenAlone = true,\n",
       "\t\t\tdampenAlone = false,\n",
       "dampenmagic: the switch off by default",
       expect="a new profile's switch is", script=S)

mutate("Commands.lua",
       "\t\telseif why == \"grouped\" then\n",
       "\t\telseif false then\n",
       "dampenmagic: /manners debug quiet about the group",
       expect="/manners debug says", script=S)

mutate("Options/Who.lua",
       "\t\t\t\t\tns.db.profile.ownBuffs.dampenAlone = value == true\n",
       "\t\t\t\t\tns.db.profile.ownBuffs.dampenAlone = true\n",
       "dampenmagic: the switch writes nothing",
       expect="turning it off wrote nothing", script=S)

mutate("Options/Who.lua",
       "\t\t\t\t\treturn not (spell and ns.OwnSpellKnown(spell))\n",
       "\t\t\t\t\treturn false\n",
       "dampenmagic: the switch shown to every mage",
       expect="shown to a mage without Dampen Magic", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t{ \"who.ownDampenAlone\", indent = 2 },\n",
       "",
       "dampenmagic: the switch not placed on the page",
       expect="ownDampenAlone", script=S)

mutate("Buffs.lua",
       "\t\t\t\t{ key = \"amplifymagic\", ranks = { 10170, 10169, 8455, 1008 }, solo = \"amplifyAlone\" },\n",
       "\t\t\t\t{ key = \"amplifymagic\", ranks = { 10170, 10169, 8455, 1008 } },\n",
       "dampenmagic: Amplify Magic not held by its switch",
       expect="dampenmagic: Amplify Magic waits in a group", script=S)

mutate("Buffs.lua",
       "8455, 1008 }, solo = \"amplifyAlone\" },\n",
       "8455, 1008 }, solo = \"dampenAlone\" },\n",
       "dampenmagic: Amplify Magic follows Dampen's switch",
       expect="Dampen's switch off let Amplify Magic through", script=S)

mutate("Options/Who.lua",
       "\t\t\t\t\tns.db.profile.ownBuffs.amplifyAlone = value == true\n",
       "\t\t\t\t\tns.db.profile.ownBuffs.amplifyAlone = true\n",
       "dampenmagic: Amplify's switch writes nothing",
       expect="Amplify's switch off wrote nothing", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t{ \"who.ownAmplifyAlone\", indent = 2 },\n",
       "",
       "dampenmagic: Amplify's switch not placed on the page",
       expect="ownAmplifyAlone", script=S)
