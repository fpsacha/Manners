# Mutations for tests/scenarios/hunt31-oils.lua: Forever keeps an Imbue and a
# Temporary enchant on one hand together, so a family is up only for an
# enchant of its own kind (Buffs.lua `enchantKind`, Core.lua ReadImbue and
# CountsFor), a shaman wearing Rockbiter Weapon is offered an oil, a mage
# wearing an oil is offered her scroll's imbue, and the classic clients, which
# list one enchant to a hand, name no kind. Each puts one piece of that back
# and is caught by the scenario that names it.
#
# Run by tests/selftest.py with mutate() in scope.

S = "runscenarios.py"

# --- the rule (Core.lua, CountsFor) ---

# Kinds ignored: any enchant of either kind is the hand seen to, as it was.
mutate("Core.lua",
       "\t\tif own == nil or listed == own then return true end\n",
       "\t\tdo return true end\n",
       "hunt31-oils: kinds ignored, any enchant counts",
       expect="a shaman with Rockbiter on the main hand and a Wizard Oil in the bags was offered", script=S)

# A family with no kind in its data takes none of the list's enchants.
mutate("Core.lua",
       "\t\tif own == nil or listed == own then return true end\n",
       "\t\tif listed == own then return true end\n",
       "hunt31-oils: a family with no kind counts nothing from the list",
       expect="a family with no kind was offered an oil over an Imbue on the list", script=S)

# An enchant of the other kind whose id is hidden: the client not saying, and
# read as "not the family's" it is a reason to offer.
mutate("Core.lua",
       "\t\tif id == nil then return nil end\n",
       "\t\tif id == nil then return false end\n",
       "hunt31-oils: a hidden id of the other kind read as not the family's",
       expect="an Imbue with its id hidden was a reason to offer the oil", script=S)

mutate("Core.lua",
       "\t\t\t\t\tif counts == nil then unknown = true end\n",
       "",
       "hunt31-oils: a hidden id of the other kind not remembered as unknown",
       expect="an Imbue with its id hidden was a reason to offer the oil", script=S)

# The client's word: a family's own enchant listed as the other kind is up, and
# is that family's kind from then on.
mutate("Core.lua",
       "\t\t\tif data and listed ~= data then learnedKind[family.key] = listed end\n",
       "",
       "hunt31-oils: a family's own enchant listed as the other kind teaches nothing",
       expect="after the client listed an oil as an Imbue, Rockbiter on the sword was offered", script=S)

mutate("Core.lua",
       "\t\tlocal own = learnedKind[family.key] or family.enchantKind\n",
       "\t\tlocal own = family.enchantKind\n",
       "hunt31-oils: what a family was taught never used",
       expect="after the client listed an oil as an Imbue, Rockbiter on the sword was offered", script=S)

mutate("Core.lua",
       "\t\t\tif data and listed ~= data then learnedKind[family.key] = listed end\n\t\t\treturn true\n",
       "\t\t\tif data and listed ~= data then learnedKind[family.key] = listed end\n",
       "hunt31-oils: a family's own enchant counts only listed as its kind",
       expect="with the oil's own enchant listed as an Imbue, you were offered", script=S)

# The spell's own kind, where it is not its family's (Season of Discovery's
# poisons): left to the family's, listing one as the data says teaches the
# poison family that stones are poisons.
mutate("Core.lua",
       "\t\t\tlocal data = learnedKind[family.key] or scroll.enchantKind or own\n",
       "\t\t\tlocal data = learnedKind[family.key] or own\n",
       "hunt31-oils: a spell's own kind never read",
       expect="after Occult Poison II was listed as Temporary, a stone on the dagger was taken for a poison", script=S)

# What the client lists the enchant as, read wrongly.
mutate("Core.lua",
       "CountsFor(family, scroll, id, kind == imbue and \"imbue\" or \"temporary\")\n",
       "CountsFor(family, scroll, id, \"temporary\")\n",
       "hunt31-oils: every enchant listed as temporary",
       expect="with the imbue run out under the oil, you were offered", script=S)

# --- the data (Buffs.lua) ---

mutate("Buffs.lua",
       "\tlocal CAMELOT_KINDS = { poison = IMBUE, stone = TEMPORARY, oil = TEMPORARY, lure = TEMPORARY }\n",
       "\tlocal CAMELOT_KINDS = { poison = IMBUE, stone = TEMPORARY, oil = IMBUE, lure = TEMPORARY }\n",
       "hunt31-oils: oils listed as imbues",
       expect="a shaman with Rockbiter on the main hand and a Wizard Oil in the bags was offered", script=S)

mutate("Buffs.lua",
       "\tlocal CAMELOT_KINDS = { poison = IMBUE, stone = TEMPORARY, oil = TEMPORARY, lure = TEMPORARY }\n",
       "\tlocal CAMELOT_KINDS = { poison = IMBUE, stone = IMBUE, oil = TEMPORARY, lure = TEMPORARY }\n",
       "hunt31-oils: stones listed as imbues",
       expect="with Rockbiter alone on the sword, you were offered", script=S)

mutate("Buffs.lua",
       "\tlocal CAMELOT_KINDS = { poison = IMBUE, stone = TEMPORARY, oil = TEMPORARY, lure = TEMPORARY }\n",
       "\tlocal CAMELOT_KINDS = { poison = TEMPORARY, stone = TEMPORARY, oil = TEMPORARY, lure = TEMPORARY }\n",
       "hunt31-oils: poisons listed as temporary enchants",
       expect="with a stone on the dagger, the poison was not offered", script=S)

mutate("Buffs.lua",
       "\tlocal CAMELOT_KINDS = { poison = IMBUE, stone = TEMPORARY, oil = TEMPORARY, lure = TEMPORARY }\n",
       "\tlocal CAMELOT_KINDS = { poison = IMBUE, stone = TEMPORARY, oil = TEMPORARY, lure = IMBUE }\n",
       "hunt31-oils: lures listed as imbues",
       expect="a temporary family (a stone, an oil, a lure) is not of the Temporary kind", script=S)

# A family's kind never set, or a spell's own never read.
mutate("Buffs.lua",
       "\t\t\t\t\t\tenchantKind = kinds and kinds[kind.kind] or nil,\n",
       "",
       "hunt31-oils: a family's kind never set",
       expect="a shaman with Rockbiter on the main hand and a Wizard Oil in the bags was offered", script=S)

mutate("Buffs.lua",
       "enchantKind = kinds and (row.enchantKind or kinds[kind.kind]) or nil }\n",
       "enchantKind = kinds and kinds[kind.kind] or nil }\n",
       "hunt31-oils: a row's own kind never read",
       expect="a Season of Discovery poison is not a Temporary enchant", script=S)

mutate("Buffs.lua",
       "\t\t\t{ 234444, 60, 7651, 1214171, MELEE, enchantKind = TEMPORARY }, -- Occult Poison II\n",
       "\t\t\t{ 234444, 60, 7651, 1214171, MELEE }, -- Occult Poison II\n",
       "hunt31-oils: Occult Poison II taken for an imbue",
       expect="after Occult Poison II was listed as Temporary, a stone on the dagger was taken for a poison", script=S)

mutate("Buffs.lua",
       "\t\tscroll = true,\n\t\timbue = true,\n\t\tenchantKind = \"imbue\",\n",
       "\t\tscroll = true,\n\t\timbue = true,\n\t\tenchantKind = \"temporary\",\n",
       "hunt31-oils: the mage's imbue listed as a temporary enchant",
       expect="with a wizard oil on the staff, you were offered", script=S)

mutate("Buffs.lua",
       "\t\tscroll = true,\n\t\timbue = true,\n\t\tenchantKind = \"imbue\",\n",
       "\t\tscroll = true,\n\t\timbue = true,\n",
       "hunt31-oils: the mage's imbue with no kind",
       expect="with a wizard oil on the staff, you were offered", script=S)

# --- the clients that list one enchant to a hand name no kind ---

for client, rows in (("vanilla", "VANILLA_ROWS"), ("tbc", "TBC_ROWS"), ("mists", "MISTS_ROWS")):
    mutate("Buffs.lua",
           "\tENHANCEMENTS.%s = Families(%s)\n" % (client, rows),
           "\tENHANCEMENTS.%s = Families(%s, CAMELOT_KINDS)\n" % (client, rows),
           "hunt31-oils: %s's enhancements given Forever's kinds" % client,
           expect="hunt31-oils: %s's families name no kind of enchant" % client, script=S)

# --- the in-game report (Selftest.lua) ---

# A wizard oil listed and the mage's imbue not on: the old comparison called it
# the 1.6.3 bug.
mutate("Selftest.lua",
       "\telseif listedImbue and up == false then\n",
       "\telseif listedOn and up == false then\n",
       "hunt31-oils: the report faults an oil on the staff",
       expect="with an oil on the staff, the main hand's comparison reads", script=S)

mutate("Selftest.lua",
       "\telseif listedOn and not listedImbue and up == false then\n",
       "\telseif false then\n",
       "hunt31-oils: the report says nothing of an oil on the staff",
       expect="with an oil on the staff, the main hand's comparison reads", script=S)
