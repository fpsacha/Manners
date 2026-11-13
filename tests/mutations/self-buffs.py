# Mutations for the buffs you put on yourself added in 1.11.11 (Buffs.lua's own
# families: Shadowform, Moonkin Form, Season of Discovery's runes, Grimoire of
# Sacrifice, the imbues of Mists and retail, the rites; Core.lua's `form`,
# `needs`/`notWith` and `shield` rules; the page, the debug lines, the layout and
# the length tables). Each is caught by the scenario in
# tests/scenarios/self-buffs.lua (or the one named) that names it.

S = "runscenarios.py"
B = "Buffs.lua"
C = "Core.lua"

# ---------------------------------------------------------------- Shadowform

mutate(B,
       "ranks = { 15473 }, talent = true } } },\n\t},\n\n\tWARLOCK = {\n\t\t{\n\t\t\tkey = \"demonarmor\",\n\t\t\tspells = {\n\t\t\t\t-- Season",
       "ranks = { 15474 }, talent = true } } },\n\t},\n\n\tWARLOCK = {\n\t\t{\n\t\t\tkey = \"demonarmor\",\n\t\t\tspells = {\n\t\t\t\t-- Season",
       "self-buffs: Classic Era's Shadowform a wrong id",
       expect="self-buffs: vanilla: a shadow priest out of Shadowform is reminded of it", script=S)

mutate(B,
       "\t\t{ key = \"shadowform\", toggle = true,\n\t\t\tspells = { { key = \"shadowform\", ranks = { 15473 }, talent = true } } },\n\t},\n\n\tWARLOCK = {\n\t\t{\n\t\t\tkey = \"demonarmor\",\n\t\t\tspells = {\n\t\t\t\t-- Season",
       "\t\t{ key = \"shadowform\",\n\t\t\tspells = { { key = \"shadowform\", ranks = { 15473 }, talent = true } } },\n\t},\n\n\tWARLOCK = {\n\t\t{\n\t\t\tkey = \"demonarmor\",\n\t\t\tspells = {\n\t\t\t\t-- Season",
       "self-buffs: Shadowform not a toggle",
       expect="hunt32-durations: vanilla: every id the set holds has a length", script=S)

mutate(B,
       "\tPRIEST = {\n\t\t-- 20 charges on Forever",
       "\tPRIEST = {\n\t\t{ key = \"shadowform\", toggle = true, spells = { { key = \"shadowform\", ranks = { 15473 }, talent = true } } },\n\t\t-- 20 charges on Forever",
       "self-buffs: Shadowform ahead of Inner Fire",
       expect="self-buffs: Inner Fire before Shadowform", script=S)

mutate(B,
       "-- no timer here; every priest buff castable in it (SpellShapeshift, form 28).\n\t\t{ key = \"shadowform\", toggle = true,\n\t\t\tspells = { { key = \"shadowform\", ranks = { 15473 }",
       "-- no timer here; every priest buff castable in it (SpellShapeshift, form 28).\n\t\t{ key = \"shadowform\", toggle = true,\n\t\t\tspells = { { key = \"shadowform\", ranks = { 15474 }",
       "self-buffs: Burning Crusade's Shadowform a wrong id",
       expect="self-buffs: tbc: a shadow priest out of Shadowform is reminded of it", script=S)

mutate(B,
       "\tAt(\"PRIEST\", 2, { key = \"shadowform\", toggle = true,\n\t\tspells = { { key = \"shadowform\", ranks = { 15473 }",
       "\tAt(\"PRIEST\", 2, { key = \"shadowform\", toggle = true,\n\t\tspells = { { key = \"shadowform\", ranks = { 15474 }",
       "self-buffs: Mists' Shadowform a wrong id",
       expect="self-buffs: mists: a shadow priest out of Shadowform is reminded of it", script=S)

mutate(B,
       "spells = { { key = \"shadowform\", ranks = { 232698 }, talent = true } } },",
       "spells = { { key = \"shadowform\", ranks = { 15473 }, talent = true } } },",
       "self-buffs: retail's Shadowform the Classic id",
       expect="self-buffs: mainline: a shadow priest out of Shadowform is reminded of it", script=S)

# ---------------------------------------------------------------- Moonkin Form

mutate(B,
       "\t\t{ key = \"moonkinform\", toggle = true, form = true,\n\t\t\tspells = { { key = \"moonkinform\", ranks = { 24858 }, talent = true } } },\n\t},\n\n\t-- WARRIOR and ROGUE",
       "\t\t{ key = \"moonkinform\", toggle = true,\n\t\t\tspells = { { key = \"moonkinform\", ranks = { 24858 }, talent = true } } },\n\t},\n\n\t-- WARRIOR and ROGUE",
       "self-buffs: Classic Era's Moonkin Form nags in another form",
       expect="self-buffs: vanilla: Moonkin Form in caster form, never in another form", script=S)

mutate(C,
       "\t\tif family.form and not up and ActiveForm() ~= nil then return nil, up, nil, \"form\" end\n",
       "",
       "self-buffs: another form does not hold Moonkin Form back",
       expect="self-buffs: camelot: Moonkin Form in caster form, never in another form", script=S)

mutate("Commands.lua",
       "\t\telseif why == \"form\" then\n",
       "\t\telseif why == \"form!\" then\n",
       "self-buffs: debug quiet about another form",
       expect="self-buffs: mists: Moonkin Form in caster form, never in another form", script=S)

mutate(B,
       "\tAt(\"DRUID\", 1, { key = \"moonkinform\"",
       "\tAt(\"DRUID_\", 1, { key = \"moonkinform\"",
       "self-buffs: no Moonkin Form on Mists",
       expect="self-buffs: mists: Moonkin Form in caster form, never in another form", script=S)

mutate(B,
       "\t\t\tspells = { { key = \"moonkinform\", ranks = { 24858 }, talent = true } } },\n\t},\n}\n",
       "\t\t\tspells = { { key = \"moonkinform\", ranks = { 24859 }, talent = true } } },\n\t},\n}\n",
       "self-buffs: Burning Crusade's Moonkin Form a wrong id",
       expect="self-buffs: tbc: Moonkin Form in caster form, never in another form", script=S)

# ---------------------------------------------------------------- Season of Discovery

mutate(B,
       "\t\t\tcopy.spells = { { key = \"moltenarmor\", ranks = { 428741 } } }\n",
       "\t\t\tcopy.spells = {}\n",
       "self-buffs: no Molten Armor on Classic Era",
       expect="self-buffs: vanilla: Molten Armor is the armor up", script=S)

mutate(B,
       "\t\t{ 1800, 428741 }, -- Molten Armor, Season of Discovery's rune (30 min)\n",
       "",
       "self-buffs: Molten Armor has no length",
       expect="hunt32-durations: vanilla: every id the set holds has a length", script=S)

mutate(B,
       "\t\t\t\t{ key = \"aspectviper\", ranks = { 415423 }, neverAuto = true },\n",
       "\t\t\t\t{ key = \"aspectviper\", ranks = { 415423 } },\n",
       "self-buffs: the Viper Automatic's",
       expect="self-buffs: camelot: the Viper up is the hunter's choice", script=S)

mutate(B,
       "\t\t\t\t{ key = \"aspectviper\", ranks = { 415423 }, neverAuto = true },\n",
       "",
       "self-buffs: the Viper not of the aspects",
       expect="self-buffs: vanilla: the Viper up is the hunter's choice", script=S)

mutate(B,
       "\t\t\t\t{ key = \"aspectfalcon\", ranks = { 469145 } },\n",
       "",
       "self-buffs: the Falcon not of the aspects",
       expect="self-buffs: camelot: the Falcon is Automatic's first", script=S)

mutate(B,
       "\t\t\ttable.insert(hunter, i + 1, { key = \"heartofthelion\", toggle = true,\n",
       "\t\t\ttable.insert(hunter, i + 1, { key = \"heartofthelion\", toggle = true, shared = true,\n",
       "self-buffs: Heart of the Lion shared",
       expect="self-buffs: vanilla: Heart of the Lion, and another hunter's does not cover you", script=S)

mutate(B,
       "spells = { { key = \"heartofthelion\", ranks = { 409583, 409580 } } } })",
       "spells = { { key = \"heartofthelion\", ranks = { 409583 } } } })",
       "self-buffs: the hunter's own rune not read",
       expect="self-buffs: vanilla: Heart of the Lion, and another hunter's does not cover you", script=S)

mutate(B,
       "\t\t\ttable.insert(hunter, i + 1, { key = \"heartofthelion\", toggle = true,\n",
       "\t\t\ttable.insert(hunter, i + 1, { key = \"heartofthelion\",\n",
       "self-buffs: Heart of the Lion not a toggle",
       expect="hunt32-durations: vanilla: every id the set holds has a length", script=S)

# ---------------------------------------------------------------- Grimoire of Sacrifice

mutate(B,
       "\tAt(\"WARLOCK\", 1, { key = \"grimoireofsacrifice\",",
       "\tAt(\"WARLOCK_\", 1, { key = \"grimoireofsacrifice\",",
       "self-buffs: no Grimoire of Sacrifice on Mists",
       expect="self-buffs: mists: Grimoire of Sacrifice with a demon out", script=S)

mutate(B,
       "\t\t{ 3600, 108503 }, -- Grimoire of Sacrifice (1 h)\n",
       "",
       "self-buffs: Mists' Grimoire of Sacrifice has no length",
       expect="hunt32-durations: mists: every id the set holds has a length", script=S)

mutate(B,
       "\t\t{ key = \"grimoireofsacrifice\", toggle = true,\n",
       "\t\t{ key = \"grimoireofsacrifice\",\n",
       "self-buffs: retail's Grimoire of Sacrifice not a toggle",
       expect="hunt32-durations: mainline: every id the set holds has a length", script=S)

# ---------------------------------------------------------------- a shaman's imbues

mutate(B,
       "\t\tlabel = L[\"Weapon imbue\"],\n\t\timbue = true,\n\t\tspells = {\n\t\t\t{ key = \"windfuryweapon\", ranks = { 8232 }",
       "\t\tlabel = L[\"Weapon imbue\"],\n\t\tspells = {\n\t\t\t{ key = \"windfuryweapon\", ranks = { 8232 }",
       "self-buffs: Mists' imbues read as auras",
       expect="self-buffs: mists: a shaman's imbue on the main hand", script=S)

mutate(B,
       "\t\t\t{ key = \"earthlivingweapon\", ranks = { 51730 }, talent = true },\n\t\t\t{ key = \"flametongueweapon\", ranks = { 8024 } },\n",
       "\t\t\t{ key = \"flametongueweapon\", ranks = { 8024 } },\n\t\t\t{ key = \"earthlivingweapon\", ranks = { 51730 }, talent = true },\n",
       "self-buffs: Mists' Flametongue ahead of Earthliving",
       expect="self-buffs: mists: a shaman's imbue on the main hand", script=S)

mutate(B,
       "ranks = { 318038 }, talent = true, notWith = \"windfuryweapon\" },",
       "ranks = { 318038 }, talent = true },",
       "self-buffs: retail's Flametongue the main hand's beside Windfury",
       expect="self-buffs: mainline: Windfury on the main hand, Flametongue on the off hand", script=S)

mutate(B,
       "talent = true, needs = \"windfuryweapon\",",
       "talent = true,",
       "self-buffs: retail's Flametongue the off hand's without Windfury",
       expect="self-buffs: mainline: an Elemental shaman's Flametongue is the main hand's", script=S)

mutate(C,
       "\t\t\tif with ~= (spell.needs ~= nil) then return false end\n",
       "",
       "self-buffs: needs and notWith not read",
       expect="self-buffs: mainline: Windfury on the main hand, Flametongue on the off hand", script=S)

mutate(B,
       "\t\t\timbue = true,\n\t\t\tslot = 17,\n",
       "\t\t\timbue = true,\n",
       "self-buffs: the off hand's imbue read off the main hand",
       expect="self-buffs: mainline: Windfury on the main hand, Flametongue on the off hand", script=S)

mutate(B,
       "ranks = { 462757 }, talent = true, shield = true },",
       "ranks = { 462757 }, talent = true },",
       "self-buffs: Thunderstrike Ward offered with no shield",
       expect="self-buffs: mainline: Thunderstrike Ward waits for a shield", script=S)

mutate(C,
       "\t\telseif spell.shield and not HandShield(family.slot or 17) then\n",
       "\t\telseif false then\n",
       "self-buffs: the shield not asked for",
       expect="self-buffs: mainline: Thunderstrike Ward waits for a shield", script=S)

mutate(C,
       "\t\t\t\theld = plain(class) == 4 and plain(subclass) == 6\n",
       "\t\t\t\theld = plain(class) == 2\n",
       "self-buffs: a shield not known for one",
       expect="self-buffs: mainline: Thunderstrike Ward waits for a shield", script=S)

mutate("Commands.lua",
       "\t\telseif why == \"noshield\" then\n",
       "\t\telseif why == \"noshield!\" then\n",
       "self-buffs: debug quiet about the shield",
       expect="self-buffs: mainline: Thunderstrike Ward waits for a shield", script=S)

mutate(B,
       "\t\t{ 3600, 33757, 382021, 318038 }, -- Windfury, Earthliving, Flametongue Weapon (1 h)\n",
       "",
       "self-buffs: retail's imbues have no length",
       expect="hunt32-durations: mainline: every id the set holds has a length", script=S)

# ---------------------------------------------------------------- the rites

mutate(B,
       "\t\t\tkey = \"rite\",\n\t\t\tlabel = L[\"Weapon imbue\"],\n\t\t\timbue = true,\n",
       "\t\t\tkey = \"rite\",\n\t\t\tlabel = L[\"Weapon imbue\"],\n",
       "self-buffs: the rites read as auras",
       expect="self-buffs: mainline: a Lightsmith's rite on the main hand", script=S)

# ---------------------------------------------------------------- the page

mutate(C,
       "\t\tif family.imbue and family.slot == 17 then return family.label .. \" (\" .. ns.HandName(17) .. \")\" end\n",
       "",
       "self-buffs: the off hand's imbue not named for its hand",
       expect="self-buffs: mainline: the page names each hand", script=S)

mutate("Options/Who.lua",
       "\t\t\t\t\t\tif family.slot == 17 then\n",
       "\t\t\t\t\t\tif false then\n",
       "self-buffs: the off hand's row speaks of the main hand",
       expect="self-buffs: mainline: the page names each hand", script=S)

mutate("Options/Who.lua",
       "\t\t\t\t\t\telseif family.key ~= \"shamanimbue\" then\n",
       "\t\t\t\t\t\telseif false then\n",
       "self-buffs: the paladin's row speaks of Windfury",
       expect="self-buffs: mainline: the page names each hand", script=S)

mutate("Options/Who.lua",
       "\t\t\t\t\tor family.form\n\t\t\t\t\tand L[\"Reminds you when you are not in it, and never while you are in another form.\"]\n",
       "",
       "self-buffs: the Moonkin switch says nothing of forms",
       expect="self-buffs: mainline: the page names each hand", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t{ \"who.own_shadowform\", indent = true },\n",
       "",
       "self-buffs: Shadowform not placed on the page",
       expect="every control has one place in the options window", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t{ \"who.own_moonkinform\", indent = true },\n",
       "",
       "self-buffs: Moonkin Form not placed on the page",
       expect="every control has one place in the options window", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t\"who.own_shamanimbueoff\",\n",
       "",
       "self-buffs: the off hand's imbue not placed on the page",
       expect="self-buffs: mainline: the page names each hand", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t\"who.own_rite\",\n",
       "",
       "self-buffs: the rites not placed on the page",
       expect="self-buffs: mainline: the page names each hand", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t{ \"who.own_grimoireofsacrifice\", indent = true },\n",
       "",
       "self-buffs: Grimoire of Sacrifice not placed on the page",
       expect="mists: the options window builds", script=S)
