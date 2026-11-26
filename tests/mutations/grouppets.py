# Mutations for My group's pets too (sources.pets): the walk of partypetN and
# raidpetN (Queue.lua IterateUnits, ns.GroupNames and the walk's visit), what
# lets a pet through (Core.lua IsBuffableUnit, Castable), the fold
# (GroupBuffs.lua), the words (Prompt/Paint.lua), the silence (Speech.lua), the
# ledger (Ledger.lua, Prompt/Press.lua) and the setting (Core.lua,
# Options/Who.lua, Options/Advanced.lua, Options/Diagnostics.lua,
# Options/Window/Layout.lua). Each is caught by the scenario in
# tests/scenarios/grouppets.lua that names it.

S = "runscenarios.py"

# ------------------------------------------------------------ the switch
# On in a new profile: nobody asked for their group's pets on the prompt.
mutate("Core.lua",
       "\t\t\tpets = false,\n",
       "\t\t\tpets = true,\n",
       "grouppets: on in a new profile",
       expect="grouppets: off by default, and no pet is walked", script=S)

# The pets walked whatever the switch says: forty more questions a raid scan.
mutate("Queue.lua",
       "\t\tif pets then\n\t\t\towners, petTokens =",
       "\t\tif true then\n\t\t\towners, petTokens =",
       "grouppets: the pets are walked with the switch off",
       expect="grouppets: off by default, and no pet is walked", script=S)

# The pets walked with My party and raid off.
mutate("Queue.lua",
       "db.sources.pets == true and db.sources.group == true)\n",
       "db.sources.pets == true)\n",
       "grouppets: the pets are walked with the group switch off",
       expect="grouppets: with the group switch off no pet is walked", script=S)

# No default, so nothing to repair a damaged value to.
mutate("Core.lua",
       "\t\t\tpets = false,\n",
       "",
       "grouppets: no default for the switch",
       expect="grouppets: a damaged value is repaired to off", script=S)

# The page's reset leaves the switch as it was.
mutate("Options/Advanced.lua",
       "\"sources.group\", \"sources.pets\", ",
       "\"sources.group\", ",
       "grouppets: the page's reset leaves the switch",
       expect="grouppets: a damaged value is repaired to off", script=S)

# Shown with My party and raid off, when it offers nobody.
mutate("Options/Who.lua",
       "\t\t\t\thidden = function() return not S().group end,\n",
       "",
       "grouppets: the switch is shown with the group switch off",
       expect="grouppets: the switch sits under My party and raid, and is hidden with it off", script=S)

# Drawn level with My party and raid, as a source of its own.
mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t{ \"who.pets\", indent = true },\n",
       "\t\t\t\t\t{ \"who.pets\" },\n",
       "grouppets: the switch is not a step in under the group switch",
       expect="grouppets: the switch sits under My party and raid, and is hidden with it off", script=S)

# Search cannot say which switch shows it.
mutate("Options/Window/Layout.lua",
       "\t\t[\"who.pets\"] = \"who.group\",\n",
       "",
       "grouppets: search is not told the switch's parent",
       expect="grouppets: the switch sits under My party and raid, and is hidden with it off", script=S)

# The bug report without the switch.
mutate("Options/Diagnostics.lua",
       "\t\ttostring(db.sources.pets),\n",
       "\t\t\"?\",\n",
       "grouppets: the bug report leaves the switch out",
       expect="grouppets: the bug report says whether the switch is on", script=S)

# ------------------------------------------------------------ the walk
# A pet turned away for not being a player, as everybody's was before.
mutate("Context.lua",
       "\tif pet then\n\t\tif player == true then\n",
       "\tif player ~= true then\n",
       "grouppets: a pet is turned away as no player",
       expect="grouppets: a party pet missing your buff is offered, targeted by its name", script=S)

# UnitInParty asked of a pet, which answers false: a passer-by, and not offered.
mutate("Queue.lua",
       "local inGroup = owner ~= nil or plain(UnitInParty and UnitInParty(unit))",
       "local inGroup = plain(UnitInParty and UnitInParty(unit))",
       "grouppets: a pet is asked whether it is in the party",
       expect="grouppets: a party pet missing your buff is offered, targeted by its name", script=S)

# The entry says neither that it is a pet nor whose.
mutate("Queue.lua",
       "\t\t\tmade.pet, made.owner = true, ns.UnitFullName(owner)\n",
       "",
       "grouppets: the entry is not marked as a pet",
       expect="grouppets: a party pet missing your buff is offered, targeted by its name", script=S)

# The client's class for a pet left on its entry.
mutate("Queue.lua",
       "\t\t\tmade.class, made.guild = nil, nil\n",
       "",
       "grouppets: the entry keeps the client's class for a pet",
       expect="grouppets: a party pet missing your buff is offered, targeted by its name", script=S)

# Every pet taken to have mana.
mutate("Queue.lua",
       "\t\tlocal hasMana = UnitHasMana(unit)\n",
       "\t\tlocal hasMana = owner and true or UnitHasMana(unit)\n",
       "grouppets: every pet is taken to have mana",
       expect="grouppets: a pet with no mana is not offered Arcane Intellect", script=S)

# The raid group asked of the pet's own token, which the roster does not list.
mutate("Queue.lua",
       "\t\t\tlocal group = RaidGroupOf(owner or unit)\n",
       "\t\t\tlocal group = RaidGroupOf(unit)\n",
       "grouppets: a pet's raid group is not its owner's",
       expect="grouppets: a raid pet in a raid group you do not buff is skipped", script=S)

# Your own pet offered as one of the raid's.
mutate("Context.lua",
       "UnitIsUnit(unit, pet and \"pet\" or \"player\")",
       "UnitIsUnit(unit, \"player\")",
       "grouppets: your own pet is one of the raid's",
       expect="grouppets: your own pet in a raid is not offered", script=S)

# A pet named as somebody of the group offered all the same.
mutate("Queue.lua",
       "\t\t\tif opts.groupNames[full] then return end\n",
       "",
       "grouppets: a pet named as a group member is offered",
       expect="grouppets: a pet named as a group member, or as you, is skipped", script=S)

# Only the whole name counts: a pet named Gwen beside Gwen Hale.
mutate("Queue.lua",
       "\t\tif first then names[first] = true end\n",
       "",
       "grouppets: only a whole name is a clash",
       expect="grouppets: a pet named as a group member, or as you, is skipped", script=S)

# A pet read as the debtor whose name it shares.
mutate("Queue.lua",
       "\t\t\tif isOwed then return end\n",
       "",
       "grouppets: a pet is read as somebody owed",
       expect="grouppets: a pet named as somebody you owe is never read as owed", script=S)

# ...and as the asker.
mutate("Queue.lua",
       "\t\t\tunasked = true\n",
       "",
       "grouppets: a pet is read as somebody who asked",
       expect="grouppets: a pet named as somebody who asked is never read as asking", script=S)

# A pet that the client gives the tank role is a tank.
mutate("Queue.lua",
       "\t\t\topts.isTank, opts.class = nil, nil\n",
       "",
       "grouppets: a pet with the tank role is a tank",
       expect="grouppets: a buff held to your tanks is not offered to a pet", script=S)

# A pet of the client's "mage" class skipped as one of your own.
mutate("Queue.lua",
       "\t\t\topts.casterOnly, opts.sameClass, opts.level = nil, false, nil\n",
       "",
       "grouppets: a pet is judged by the client's class for it",
       expect="grouppets: a pet is not skipped for the class the client files it under", script=S)

# A buff for one target at a time given to a pet.
mutate("Core.lua",
       "\t\tif opts.pet and (buff.oneTarget or buff.notPets) then return false end\n",
       "\t\tif opts.pet and buff.notPets then return false end\n",
       "grouppets: a one-target buff is offered to a pet",
       expect="grouppets: a buff for one target at a time is not offered to a pet", script=S)

# ------------------------------------------------------------ the group cast
# A pet counted towards the threshold, and covered by the cast.
mutate("GroupBuffs.lua",
       "\t\tif r and entry.unit and entry.inGroup and not entry.pet then\n",
       "\t\tif r and entry.unit and entry.inGroup then\n",
       "grouppets: a pet is counted for the group cast",
       expect="grouppets: a pet is not counted for a group cast, nor aimed at by one", script=S)

# ------------------------------------------------------------ words and silence
# The reason line a member of the group has, for a pet.
mutate("Prompt/Paint.lua",
       "\tif entry.pet and entry.owner then\n\t\treturn L[\"%s's pet\"]",
       "\tif false then\n\t\treturn L[\"%s's pet\"]",
       "grouppets: the reason line does not say whose pet",
       expect="grouppets: the reason line says whose pet it is", script=S)

# ...nor does the tooltip.
mutate("Prompt/Button.lua",
       "\tif entry.pet and entry.owner then\n\t\tGameTooltip:AddLine(L[\"%s's pet\"]",
       "\tif false then\n\t\tGameTooltip:AddLine(L[\"%s's pet\"]",
       "grouppets: the tooltip does not say whose pet",
       expect="grouppets: the tooltip says whose pet it is", script=S)

# A line said to a pet.
mutate("Speech.lua",
       "\t\tif entry.pet then return nil end\n",
       "",
       "grouppets: a line is said to a pet",
       expect="grouppets: nothing is said to a pet", script=S)

# ------------------------------------------------------------ the ledger
# A buff on a pet filed as a gift to somebody of its name.
mutate("Ledger.lua",
       "\tif type(pending) == \"table\" and pending.pet == true then return end\n",
       "",
       "grouppets: a buff on a pet is filed in the ledger",
       expect="grouppets: a buff on a pet is not filed in the ledger", script=S)

# The press does not say it was a pet's.
mutate("Prompt/Press.lua",
       "\t\tpet = S.current.pet,\n",
       "",
       "grouppets: the press forgets it was a pet's",
       expect="grouppets: a buff on a pet is not filed in the ledger", script=S)

mutate("Core.lua",
       "if opts.pet and (buff.oneTarget or buff.notPets) then return false end",
       "if opts.pet and buff.oneTarget then return false end",
       "grouppets: a pet is offered Mark of the Wild",
       expect="grouppets: Mark of the Wild is not offered to a group member's pet", script=S)
