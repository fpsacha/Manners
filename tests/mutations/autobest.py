# Mutations for Automatic taking the best item for you now (Core.lua, Best and
# AutoAnswer; Buffs.lua, the rows' school, oilKind and tier, bonus, line;
# Talents.lua). Each is caught by the scenario in tests/scenarios/autobest.lua
# that names it.

S = "runscenarios.py"

# ------------------------------------------------ the best, not the last
mutate("Core.lua",
       "\t\tlocal last = not family.scroll and Remembered(family) or nil\n",
       "\t\tlocal last = Remembered(family)\n",
       "autobest: an item family takes the one used last",
       expect="autobest: the best, not the imbue used last", script=S)

mutate("Core.lua",
       "\t\tlocal function Worth(spell, family, school, role)\n",
       "\t\tlocal function Worth(spell, family, school, role)\n\t\t\tdo return 0 end\n",
       "autobest: every row worth the same",
       expect="autobest: a fire mage is offered a fire imbue", script=S)

mutate("Core.lua",
       "\t\t\tif spell.school == school then return 100 + (spell.power or 0) end\n\t\t\treturn -1\n",
       "\t\t\tif spell.school == school then return 100 + (spell.power or 0) end\n\t\t\treturn 0\n",
       "autobest: the other school worth as much as none",
       expect="autobest: an arcane mage takes a scroll of no school over a fire one", script=S)

mutate("Core.lua",
       "\t\t\t\t\tif worth > bestWorth then\n",
       "\t\t\t\t\tif worth >= bestWorth then\n",
       "autobest: a tie goes to the last in order",
       expect="autobest: a tie keeps the table's order", script=S)

# ------------------------------------------------ reading the talents
mutate("Core.lua",
       "\t\tfunction ns.ForgetLean() filled = false end\n",
       "\t\tfunction ns.ForgetLean() end\n",
       "autobest: a talent changed never read again",
       expect="autobest: a talent changed is read again", script=S)

mutate("Core.lua",
       "\t\t\tif not filled then\n",
       "\t\t\tif true then\n",
       "autobest: the talents read on every scan",
       expect="autobest: the talents are read once", script=S)

mutate("Core.lua",
       "\t\t\t\t\tif fire > shadow then school = \"fire\" elseif shadow > fire then school = \"shadow\" end\n",
       "\t\t\t\t\tif fire > shadow then school = \"shadow\" elseif shadow > fire then school = \"fire\" end\n",
       "autobest: a warlock's lean read backwards",
       expect="autobest: a warlock's stone by his talents", script=S)

mutate("Core.lua",
       "\t\t\t\t\tif fire > frost then\n",
       "\t\t\t\t\tif (by.arcane or 0) > fire and (by.arcane or 0) > frost then\n"
       "\t\t\t\t\t\tschool = \"arcane\"\n\t\t\t\t\telseif fire > frost then\n",
       "autobest: a mage's deepest tree is the school",
       expect="autobest: deep arcane with frost second reads as frost", script=S)

mutate("Core.lua",
       "\t\t\t\tlocal ok, school, role, trees, fromSpec = pcall(Fill, playerClass)\n",
       "\t\t\t\tlocal ok, school, role, trees, fromSpec = true, select(2, pcall(Fill, playerClass))\n",
       "autobest: a failed talent read kept as the school",
       expect="autobest: a talent read that throws leaves the table's order", script=S)

mutate("Core.lua",
       "\t\t\"TRAIT_CONFIG_UPDATED\",\n",
       "",
       "autobest: TRAIT_CONFIG_UPDATED not registered",
       expect="TRAIT_CONFIG_UPDATED is not registered", script=S)

# ------------------------------------------------ the warlock's stone to make
mutate("Core.lua",
       "\t\tif family.makes then\n\t\t\tlocal spell = Best.Makes(family)\n",
       "\t\tif false then\n\t\t\tlocal spell = Best.Makes(family)\n",
       "autobest: the stone to make by the kind last on the weapon",
       expect="autobest: a shadow warlock makes a Spellstone", script=S)

# ------------------------------------------------ oils
mutate("Core.lua",
       "\t\t\t\tif type(now) == \"string\" then groupRole = now end\n",
       "\t\t\t\tgroupRole = now\n",
       "autobest: a withheld group role forgets the last",
       expect="with the healer's role withheld, offered", script=S)

mutate("Core.lua",
       "\t\t\tif groupRole == \"HEALER\" then return \"healer\" end\n",
       "",
       "autobest: the group role ignored",
       expect="a Shadow priest put down to heal was offered", script=S)

mutate("Core.lua",
       "\t\t\t\tif serves and serves > 0 then return 10 * spell.tier + serves end\n",
       "\t\t\t\tif serves and serves > 0 then return serves end\n",
       "autobest: an oil's tier ignored",
       expect="autobest: a healer's stronger wizard oil over a weak mana oil", script=S)

mutate("Core.lua",
       "\t\t\t\tlocal points = plain(select(7, getInfo(i)))\n",
       "\t\t\t\tlocal points = plain(select(5, getInfo(i)))\n",
       "autobest: the points spent read at the wrong return",
       expect="autobest: vanilla: a priest's tree by the points in it", script=S)

mutate("Core.lua",
       "\t\t\t\t\tif role == \"HEALER\" then return nil, \"healer\", note, true end\n",
       "",
       "autobest: a spec's role never read",
       expect="autobest: mists: a healing spec takes a mana oil", script=S)

mutate("Core.lua",
       "\t\t\tif spent then return nil, Leading(order, counts), table.concat(parts, \" \"), false end\n",
       "\t\t\tif false then return nil, Leading(order, counts), table.concat(parts, \" \"), false end\n",
       "autobest: classic's spec index read before the points spent",
       expect="autobest: vanilla: a Shadow priest by his points, not the spec's role", script=S)

mutate("Core.lua",
       "\t\t\t\t\tif role == \"DAMAGER\" and SPEC_ROLE[specId] then return nil, SPEC_ROLE[specId], note, true end\n",
       "",
       "autobest: a damage spec's role never read",
       expect="autobest: mists: a Shadow spec takes a wizard oil", script=S)

mutate("Core.lua",
       "\t\tlocal CLASS_ROLE = { WARRIOR = \"physical\",",
       "\t\tlocal CLASS_ROLE = { WARRIORX = \"physical\",",
       "autobest: a warrior's class role lost",
       expect="autobest: an oil by the class", script=S)

mutate("Core.lua",
       "\t\t\tMAGE = \"caster\", WARLOCK = \"caster\" }\n",
       "\t\t\tWARLOCK = \"caster\" }\n",
       "autobest: a mage's class role lost",
       expect="autobest: an oil by the class", script=S)

mutate("Core.lua",
       "\t\t\t\tif class == \"PALADIN\" and not talentFromSpec then return nil end\n\t\t\t\treturn \"physical\"\n",
       "\t\t\t\tif class == \"PALADIN\" and not talentFromSpec then return nil end\n",
       "autobest: a tank's group role read as no lean",
       expect="a druid put down to tank was offered", script=S)

mutate("Core.lua",
       "\t\t\t\tif class == \"PALADIN\" and not talentFromSpec then return nil end\n",
       "",
       "autobest: a paladin tank read as a fighter",
       expect="a paladin put down to tank was offered", script=S)

mutate("Core.lua",
       "\t\t\tif groupRole == \"DAMAGER\" and class == \"PRIEST\" and treeRole == \"healer\" then return \"caster\" end\n",
       "",
       "autobest: a Holy priest put down for damage still a healer",
       expect="a Holy priest put down for damage was offered", script=S)

mutate("Buffs.lua",
       "\t\t[26] = { \"proc\", 24 }, [25] = { \"proc\", 24 },\n",
       "\t\t[26] = { \"proc\", 24 },\n",
       "autobest: Shadow Oil untagged",
       expect="autobest: an oil by the class", script=S)

# ------------------------------------------------ reading again
mutate("Core.lua",
       "\t\tif ns.ForgetLean then ns.ForgetLean() end\n",
       "",
       "autobest: the probe keeps the old lean",
       expect="and probe came", script=S)

mutate("Core.lua",
       "function addon:CHARACTER_POINTS_CHANGED() ns.ForgetLean() end\n",
       "function addon:CHARACTER_POINTS_CHANGED() end\n",
       "autobest: CHARACTER_POINTS_CHANGED reads nothing again",
       expect="and CHARACTER_POINTS_CHANGED came", script=S)

mutate("Core.lua",
       "function addon:PLAYER_TALENT_UPDATE() ns.ForgetLean() end\n",
       "function addon:PLAYER_TALENT_UPDATE() end\n",
       "autobest: PLAYER_TALENT_UPDATE reads nothing again",
       expect="and PLAYER_TALENT_UPDATE came", script=S)

mutate("Core.lua",
       "function addon:ACTIVE_TALENT_GROUP_CHANGED() ns.ForgetLean() end\n",
       "function addon:ACTIVE_TALENT_GROUP_CHANGED() end\n",
       "autobest: ACTIVE_TALENT_GROUP_CHANGED reads nothing again",
       expect="and ACTIVE_TALENT_GROUP_CHANGED came", script=S)

# ------------------------------------------------ the stone to make, the top-up, the memory
mutate("Core.lua",
       "\t\t\t\tif spell.school == school and Known(spell) and not LeftOut(spell)\n",
       "\t\t\t\tif spell.school == school and not LeftOut(spell)\n",
       "autobest: a stone not learned is made",
       expect="autobest: a stone the warlock has not learned is not made", script=S)

mutate("Core.lua",
       "\t\t\t-- The top-up is of the one you are wearing, whatever the pick.\n\t\t\tspell = upSpell\n",
       "\t\t\t-- The top-up is of the one you are wearing, whatever the pick.\n",
       "autobest: a top-up of Automatic's pick, not the imbue worn",
       expect="autobest: a top-up is of the imbue worn", script=S)

mutate("Core.lua",
       "\t\t\tand not (spell.item and not ScrollReady(spell))\n",
       "",
       "autobest: a bagged item used last offered out of reach",
       expect="autobest: a flask used last and out of reach gives way", script=S)

# ------------------------------------------------ lures
mutate("Buffs.lua",
       "\t\t\t\t\t\tif kind.kind == \"lure\" then spell.bonus = LURE[spell.enchant] end\n",
       "",
       "autobest: a lure's bonus never copied",
       expect="autobest: the strongest lure Fishing allows", script=S)

# ------------------------------------------------ poisons
mutate("Core.lua",
       "\t\t\t\tif spell.line == last.line and not LeftOut(spell) and ScrollReady(spell) then\n",
       "\t\t\t\tif spell == last and not LeftOut(spell) and ScrollReady(spell) then\n",
       "autobest: a poison's kind never taken at a better rank",
       expect="autobest: a poison keeps its kind at its best rank", script=S)
