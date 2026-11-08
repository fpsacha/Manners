# Mutations for the buffs for somebody else that go to one target at a time,
# and Season of Discovery's Commanding Shout (1.11.11): Buffs.lua's entries and
# their `oneTarget` rule (Core.lua, Castable and PickBuffFor; Queue.lua,
# OneTargetHolders; Requests.lua, AskedFor), the classes no longer listed as
# having nothing, the greeting, and Who to buff's note. Each is caught by the
# scenario in tests/scenarios/others-buffs.lua that names it.

S = "runscenarios.py"
P = "others-buffs: "

# ------------------------------------------------ the entries, held to one target

for old, new, label, expect in [
    ('{ key = "earthshieldtank", ranks = { 408514 }, oneTarget = true,',
     '{ key = "earthshieldtank", ranks = { 408514 },',
     "vanilla: Earth Shield offered to everybody", "vanilla: earthshieldtank goes to the tank alone"),
    ('{ key = "earthshieldtank", ranks = { 32594, 32593, 974 }, oneTarget = true,',
     '{ key = "earthshieldtank", ranks = { 32594, 32593, 974 },',
     "tbc: Earth Shield offered to everybody", "tbc: earthshieldtank goes to the tank alone"),
    ('\t\t{ key = "earthshieldtank", ranks = { 974 }, oneTarget = true, neverSelf = true,\n\t\t\ttalent = true, alone = true, switchable = true },',
     '\t\t{ key = "earthshieldtank", ranks = { 974 }, neverSelf = true,\n\t\t\ttalent = true, alone = true, switchable = true },',
     "mists: Earth Shield offered to everybody", "mists: earthshieldtank goes to the tank alone"),
    ('MAINLINE.SHAMAN[#MAINLINE.SHAMAN + 1] = { key = "earthshieldtank", ranks = { 974 }, oneTarget = true,',
     'MAINLINE.SHAMAN[#MAINLINE.SHAMAN + 1] = { key = "earthshieldtank", ranks = { 974 },',
     "mainline: Earth Shield offered to everybody", "mainline: earthshieldtank goes to the tank alone"),
    ('{ key = "beacon", ranks = { 407613 }, oneTarget = true,',
     '{ key = "beacon", ranks = { 407613 },',
     "vanilla: Beacon of Light offered to everybody", "vanilla: beacon goes to the tank alone"),
    ('MISTS.PALADIN[#MISTS.PALADIN + 1] = { key = "beacon", ranks = { 53563 }, oneTarget = true,',
     'MISTS.PALADIN[#MISTS.PALADIN + 1] = { key = "beacon", ranks = { 53563 },',
     "mists: Beacon of Light offered to everybody", "mists: beacon goes to the tank alone"),
    ('{ key = "beacon", ranks = { 53563 }, oneTarget = true, neverSelf = true, talent = true, alone = true,',
     '{ key = "beacon", ranks = { 53563 }, neverSelf = true, talent = true, alone = true,',
     "mainline: Beacon of Light offered to everybody", "mainline: beacon goes to the tank alone"),
    ('{ key = "oathoflight", ranks = { 1328548 }, oneTarget = true,',
     '{ key = "oathoflight", ranks = { 1328548 },',
     "camelot: Oath of Light offered to everybody", "camelot: oathoflight goes to the tank alone"),
    ('{ key = "blisteringscales", ranks = { 360827 }, oneTarget = true,',
     '{ key = "blisteringscales", ranks = { 360827 },',
     "mainline: Blistering Scales offered to everybody", "mainline: blisteringscales goes to the tank alone"),
]:
    mutate("Buffs.lua", old, new, "others-buffs: " + label, expect=P + expect, script=S)

# Symbiosis held to the tank like the rest: nobody in a party with no roles.
mutate("Buffs.lua",
       'oneTarget = true, notOwnClass = true,',
       'oneTarget = true,',
       "others-buffs: Symbiosis held to the tank",
       expect=P + "mists: Symbiosis goes to a member who is not a druid", script=S)

# ------------------------------------------------ the rule (Core.lua, Castable)

# Held by somebody, offered to anybody all the same.
mutate("Core.lua",
       "\t\t\t\t\tif holder ~= opts.name then return false end\n",
       "",
       "others-buffs: yours on a member moved to the tank",
       expect=P + "vanilla: earthshieldtank on a member who is no tank is left there", script=S)

# The tank rule gone.
mutate("Core.lua",
       "\t\t\t\telseif not opts.isTank then\n\t\t\t\t\treturn false\n",
       "\t\t\t\telseif false then\n\t\t\t\t\treturn false\n",
       "others-buffs: everybody in the group a tank",
       expect=P + "camelot: oathoflight goes to the tank alone", script=S)

# An ask by name held to the tank too.
mutate("Core.lua",
       "\t\t\tif not opts.asked then\n\t\t\t\tlocal holder = opts.oneHeld",
       "\t\t\tif true then\n\t\t\t\tlocal holder = opts.oneHeld",
       "others-buffs: an ask by name held to the tank",
       expect=P + "tbc: earthshieldtank is given to a member who asks for it by name", script=S)

# A passer-by who asks by name given it.
mutate("Core.lua",
       "\t\tif buff.oneTarget then\n\t\t\tif not (opts.inGroup or opts.inParty) then return false end\n",
       "\t\tif buff.oneTarget then\n",
       "others-buffs: a passer-by who asks given it",
       expect=P + "vanilla: a passer-by who asks for Earth Shield is not offered it", script=S)

# Symbiosis asked for by another druid... the class not read at all: anybody.
mutate("Core.lua",
       "\t\t\t\telseif buff.notOwnClass then\n\t\t\t\t\tif opts.class == nil then return false end\n",
       "\t\t\t\telseif buff.notOwnClass then\n",
       "others-buffs: Symbiosis offered whatever the class",
       expect=P + "mists: Symbiosis goes to a member who is not a druid", script=S)

# ------------------------------------------------ who wears yours (Queue.lua)

mutate("Queue.lua",
       "\t\tfor i = 0, count do\n\t\t\tlocal unit = i == 0 and \"player\" or tokens[i] or (prefix .. i)\n",
       "\t\tfor i = 1, count do\n\t\t\tlocal unit = i == 0 and \"player\" or tokens[i] or (prefix .. i)\n",
       "others-buffs: yours on you not read",
       expect=P + "mists: earthshieldtank on you is not moved to the tank", script=S)

mutate("Queue.lua",
       "\t\t\t\t\tif mine == true or ns.GaveSince(full, buff.key, remaining, (ns.BuffSeconds(buff))) then\n",
       "\t\t\t\t\tif true then\n",
       "others-buffs: somebody else's read as yours",
       expect=P + "mainline: earthshieldtank from another caster holds nothing back", script=S)

mutate("Queue.lua",
       "\tlocal oneHeld = OneTargetHolders(candidates)\n",
       "\tlocal oneHeld = OneTargetHolders(candidates) and {}\n",
       "others-buffs: nobody's reading kept for the walk",
       expect=P + "camelot: oathoflight on a member who is no tank is left there", script=S)

mutate("Queue.lua",
       "\t\t\tif opts.isTank == nil then opts.isTank = ns.IsTankUnit(unit) end\n",
       "",
       "others-buffs: the tank never read",
       expect=P + "vanilla: beacon goes to the tank alone", script=S)

# A paladin's Beacon out of mana kept as a blessing he wears on them.
mutate("Queue.lua",
       "\t\telseif buff.oneTarget then\n\t\t\t-- Not kept for a paladin's walk",
       "\t\telseif false then\n\t\t\t-- Not kept for a paladin's walk",
       "others-buffs: a Beacon out of mana covers them for a blessing",
       expect=P + "camelot: oathoflight out of mana does not cover the tank for a blessing", script=S)

# ------------------------------------------------ "buff pls" (Requests.lua)

mutate("Requests.lua",
       "\t\t\t\t\t\tand not (buff.oneTarget and request.keys == ASK.ANY) then\n",
       "\t\t\t\t\t\tthen\n",
       "others-buffs: buff pls answered with Earth Shield",
       expect=P + "vanilla: earthshieldtank is no answer to buff pls", script=S)

# ------------------------------------------------ a paladin's (Core.lua, PickBuffFor)

mutate("Core.lua",
       "\t\t\t\t\t\tif held == false then return buff, false end\n\t\t\t\t\t\tif held == true and not over and opts.whenBuffed == \"refresh\" and remaining then\n",
       "\t\t\t\t\t\tif held == true and not over and opts.whenBuffed == \"refresh\" and remaining then\n",
       "others-buffs: a paladin's Beacon never offered ahead of his blessings",
       expect=P + "vanilla: beacon and the blessings are apart", script=S)

mutate("Core.lua",
       "\t\t\t\tcandidates = BLESSINGS_ONLY\n",
       "",
       "others-buffs: a paladin's Beacon read as a blessing",
       expect=P + "mists: beacon and the blessings are apart", script=S)

mutate("Core.lua",
       "\t\t\t\t\tif held == true and mine == false and not all[i].oneTarget then return nil, true end\n",
       "\t\t\t\t\tif held == true and mine == false then return nil, true end\n",
       "others-buffs: another paladin's Oath read as a blessing",
       expect=P + "camelot: another paladin's oathoflight is no blessing to leave alone", script=S)

mutate("Core.lua",
       "if skip[buff.key] and ns.IsBuffKnown(buff) and not buff.oneTarget then",
       "if skip[buff.key] and ns.IsBuffKnown(buff) then",
       "others-buffs: a switched-off Oath on the tank covers them",
       expect=P + "camelot: oathoflight switched off does not cover the tank for a blessing", script=S)

# ------------------------------------------------ Commanding Shout

mutate("Buffs.lua",
       'VANILLA.WARRIOR[#VANILLA.WARRIOR + 1] = { key = "commandingshout", ranks = { 403215 }, selfCast = true,',
       'VANILLA.WARRIOR[#VANILLA.WARRIOR + 1] = { key = "commandingshout", ranks = { 403215 },',
       "others-buffs: Commanding Shout aimed at a target",
       expect=P + "vanilla: a party wearing Battle Shout is offered Commanding Shout", script=S)

# ------------------------------------------------ which client has what

mutate("Buffs.lua",
       "\t\t\tif RUNES[list[i].key] then table.remove(list, i) end\n",
       "",
       "others-buffs: Season of Discovery's runes on Forever",
       expect=P + "camelot: no rune of Season of Discovery is offered on Forever", script=S)

mutate("Buffs.lua",
       "CAMELOT_SET.without = { HUNTER = true, ROGUE = true, SHAMAN = true }\n",
       "",
       "others-buffs: Forever's shaman not listed as having nothing",
       expect=P + "camelot: no rune of Season of Discovery is offered on Forever", script=S)

mutate("Buffs.lua",
       "-- shaman cannot learn it, keeps him here (CAMELOT_SET).\n\twithout = {\n\t\tHUNTER = true,\n",
       "-- shaman cannot learn it, keeps him here (CAMELOT_SET).\n\twithout = {\n\t\tSHAMAN = true,\n\t\tHUNTER = true,\n",
       "others-buffs: Classic Era's shaman told he has nothing",
       expect=P + "vanilla: a shaman is not told he has nothing to give", script=S)

# The greeting for a shaman who has engraved no Earth Shield.
mutate("Commands.lua",
       "\tif not othersOff and not caps.anyKnown and ns.OnlyTalentBuffs() then othersOff = true end\n",
       "",
       "others-buffs: a shaman with no Earth Shield promised passers-by",
       expect=P + "tbc: a shaman is not told he has nothing to give", script=S)

# ------------------------------------------------ Who to buff

mutate("Options/Who.lua",
       "\t\t\t\t\treturn AutoExplanation() .. OneTargetNote(castable)\n",
       "\t\t\t\t\treturn AutoExplanation()\n",
       "others-buffs: Automatic's note silent on who it goes to",
       expect=P + "vanilla: Who to buff says who Beacon of Light goes to", script=S)

mutate("Options/Who.lua",
       "\t\t\t\t\t\t\t.. OneTargetNote(castable)\n",
       "",
       "others-buffs: one spell's note silent on who it goes to",
       expect=P + "tbc: Who to buff says who Earth Shield alone goes to", script=S)

mutate("Core.lua",
       "\t\tif buff.oneTarget then return false end\n\tend\n\treturn true\nend\n",
       "\tend\n\treturn true\nend\n",
       "others-buffs: Earth Shield said to reach your subgroup",
       expect=P + "vanilla: Who to buff says who Earth Shield goes to", script=S)
