# Mutations for Detect Invisibility for your group (Buffs.lua's detectgroup,
# membersOnly, optIn and gift; Core.lua's Castable, ns.OptedOut and the walk; the
# options page, the settings string, the reset; Requests.lua's names; the own
# family's favour). Each is caught by the scenario in
# tests/scenarios/detectgroup.lua that names it.

S = "runscenarios.py"

# ------------------------------------------------ the data
mutate("Buffs.lua",
       "\t\t\tkey = \"detectgroup\",\n\t\t\tranks = { 11743, 2970, 132 },\n",
       "\t\t\tkey = \"detectgroupX\",\n\t\t\tranks = { 11743, 2970, 132 },\n",
       "detectgroup: none on Classic Era and Forever",
       expect="detectgroup: a warlock's buff for his group on Forever, Classic Era and Burning Crusade", script=S)

mutate("Buffs.lua",
       "\t\t\tkey = \"detectgroup\",\n\t\t\tranks = { 132 },\n",
       "\t\t\tkey = \"detectgroupX\",\n\t\t\tranks = { 132 },\n",
       "detectgroup: none on Burning Crusade",
       expect="detectgroup: tbc: a party member is offered the one rank", script=S)

mutate("Buffs.lua",
       "\t\t\tkey = \"detectgroup\",\n\t\t\tranks = { 11743, 2970, 132 },\n",
       "\t\t\tkey = \"detectgroup\",\n\t\t\tranks = { 2970, 132 },\n",
       "detectgroup: Greater left out",
       expect="detectgroup: a warlock's buff for his group on Forever, Classic Era and Burning Crusade", script=S)

mutate("Buffs.lua",
       "\t[132] = 26, [2970] = 38, [11743] = 50,\n",
       "",
       "detectgroup: no rank levels",
       expect="detectgroup: a warlock's buff for his group on Forever, Classic Era and Burning Crusade", script=S)

mutate("Buffs.lua",
       "\tfavourOnly = { 6346, 546, 20765, 20764, 20763, 20762, 20707 },\n",
       "\tfavourOnly = { 6346, 546, 11743, 2970, 132, 20765, 20764, 20763, 20762, 20707 },\n",
       "detectgroup: still a favour Manners never offers",
       expect="detectgroup: a warlock's buff for his group on Forever, Classic Era and Burning Crusade", script=S)

# ------------------------------------------------ who it reaches
mutate("Buffs.lua",
       "\t\t\tranks = { 11743, 2970, 132 },\n\t\t\tmembersOnly = true,\n",
       "\t\t\tranks = { 11743, 2970, 132 },\n",
       "detectgroup: not held to the group",
       expect="detectgroup: never offered to a passer-by, nor to one who asks", script=S)

mutate("Core.lua",
       "\t\tif buff.membersOnly and not (opts.inGroup or opts.inParty) then return false end\n",
       "",
       "detectgroup: a passer-by offered it",
       expect="detectgroup: never offered to a passer-by, nor to one who asks", script=S)

mutate("Core.lua",
       "\t\tif not (buff.partyOnly or buff.groupOnly or buff.oneTarget or buff.membersOnly) then return false end\n",
       "\t\tif not (buff.partyOnly or buff.groupOnly or buff.oneTarget) then return false end\n",
       "detectgroup: said to reach passers-by",
       expect="detectgroup: never offered to a passer-by, nor to one who asks", script=S)

mutate("Options/Who.lua",
       "\tif buff.membersOnly and not (buff.partyOnly or buff.groupOnly or buff.oneTarget) then\n",
       "\tif false then\n",
       "detectgroup: the switch not marked group only",
       expect="detectgroup: never offered to a passer-by, nor to one who asks", script=S)

mutate("Buffs.lua",
       "\t\t\tmembersOnly = true,\n\t\t\toptIn = true,\n\t\t\tneverSelf = true,\n\t\t\tgift = \"detectinvis\",\n\t\t},\n\t},\n\n\t-- Battle Shout",
       "\t\t\tmembersOnly = true,\n\t\t\toptIn = true,\n\t\t\tgift = \"detectinvis\",\n\t\t},\n\t},\n\n\t-- Battle Shout",
       "detectgroup: offered to yourself",
       expect="never on yourself", script=S)

mutate("Requests.lua",
       "\t\tdetectgroup = { \"detect invisibility\", \"detect invis\", \"detect lesser invisibility\",\n",
       "\t\tdetectgroupX = { \"detect invisibility\", \"detect invis\", \"detect lesser invisibility\",\n",
       "detectgroup: no names to ask for it by",
       expect="detectgroup: a party member who asks for detect invis is offered it over Unending Breath", script=S)

# ------------------------------------------------ the switch
mutate("Buffs.lua",
       "\t\t\tmembersOnly = true,\n\t\t\toptIn = true,\n\t\t\tneverSelf = true,\n\t\t\tgift = \"detectinvis\",\n\t\t},\n\t},\n\n\t-- Battle Shout",
       "\t\t\tmembersOnly = true,\n\t\t\tneverSelf = true,\n\t\t\tgift = \"detectinvis\",\n\t\t},\n\t},\n\n\t-- Battle Shout",
       "detectgroup: on by default",
       expect="detectgroup: off by default; ticked, a party member is offered it", script=S)

mutate("Core.lua",
       "\tif not buff.optIn then return false end\n",
       "\tdo return false end\n",
       "detectgroup: the opt-in never read",
       expect="detectgroup: off by default; ticked, a party member is offered it", script=S)

mutate("Core.lua",
       "\t\t\tand (pinned == buff.key or not ns.OptedOut(buff, db and db.buff))\n",
       "",
       "detectgroup: the walk ignores the opt-in",
       expect="detectgroup: off by default; ticked, a party member is offered it", script=S)

mutate("Options/Who.lua",
       "\t\t\t\t\tB().optIn[buff.key] = value or nil\n",
       "\t\t\t\t\tB().skip[buff.key] = (not value) or nil\n",
       "detectgroup: ticking writes the skip set",
       expect="detectgroup: off by default; ticked, a party member is offered it", script=S)

mutate("Commands.lua",
       "\t\t\t\t\t\t\tor name == \"buff.optIn\"\n",
       "",
       "detectgroup: the switch does not travel with a profile",
       expect="detectgroup: the switch travels with a profile and the page's reset turns it off", script=S)

mutate("Options/Advanced.lua",
       "\t\t\"buff.optIn\",\n",
       "",
       "detectgroup: the page's reset leaves the switch",
       expect="detectgroup: the switch travels with a profile and the page's reset turns it off", script=S)

mutate("Core.lua",
       "\tif type(profile.buff.optIn) ~= \"table\" then profile.buff.optIn = {} end\n",
       "",
       "detectgroup: a damaged set is never repaired",
       expect="detectgroup: the switch travels with a profile and the page's reset turns it off", script=S)

# ------------------------------------------------ the favour
mutate("Buffs.lua",
       "\t\t\tspells = { { key = \"detectinvis\", ranks = { 11743, 2970, 132 }, anyCaster = true, castOnOthers = true } } },\n",
       "\t\t\tspells = { { key = \"detectinvis\", ranks = { 11743, 2970, 132 }, anyCaster = true } } },\n",
       "detectgroup: another warlock's is nobody's favour",
       expect="detectgroup: another warlock's Detect Invisibility on you is a favour", script=S)

mutate("Phrases.lua",
       "\t\t\tif type(buff) == \"table\" and type(buff.gift) == \"string\" then key = buff.gift end\n",
       "",
       "detectgroup: its favour thanked with no lines",
       expect="detectgroup: another warlock's Detect Invisibility on you is a favour", script=S)
