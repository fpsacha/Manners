# The Who to buff tab (BuildWhoTab in Options.lua): the four questions in
# order, the dropdown in the switches' order, settings greyed out while what
# they narrow is off, and the reagent line. Each fault is caught by the
# scenario in tests/scenarios/options-who.lua that names it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# --- the layout ---

# Ready check back under the group heading it used to share with the raid.
mutate("Options.lua",
       "\t\t\t\tdesc = L[\"From a ready check until the pull, group members missing your buff go first.\"],\n"
       "\t\t\t\torder = 33,\n",
       "\t\t\t\tdesc = L[\"From a ready check until the pull, group members missing your buff go first.\"],\n"
       "\t\t\t\torder = 24,\n",
       "who tab: ready check out of Who comes first",
       expect="readyCheck is not under Who comes first", script=S)

# The passer-by distance left down among the skips.
mutate("Options.lua",
       "\t\t\t\torder = 13.2,\n",
       "\t\t\t\torder = 43,\n",
       "who tab: the distance is not under Passers-by",
       expect="proximity is not under Offer my buff to", script=S)

# The mana-only switch back before the per-spell ones.
mutate("Options.lua",
       "\t\t\t\torder = 4.9,\n",
       "\t\t\t\torder = 4.05,\n",
       "who tab: the per-spell switches after the mana switch",
       expect="the per-spell switches come after Skip players it does nothing for", script=S)

# The heading still named the old way.
mutate("Options.lua",
       "\t\t\tgroupHeader = { type = \"header\", name = L[\"My group and raid\"], order = 20 },\n",
       "\t\t\tgroupHeader = { type = \"header\", name = L[\"Dungeons and raids\"], order = 20 },\n",
       "who tab: the group heading misnamed",
       expect="groupHeader reads", script=S)

# --- what to cast ---

# The dropdown sorted by name again.
mutate("Options.lua",
       "\t\t\t\tsorting = BuffOrder,\n",
       "",
       "who tab: the dropdown sorted by name",
       expect="the dropdown's order is", script=S)

# Automatic walked after the spells.
mutate("Options.lua",
       "\t\tlocal keys = { \"auto\" }\n",
       "\t\tlocal keys = {}\n",
       "who tab: Automatic left out of the order",
       expect="the dropdown's order is", script=S)

# Automatic that does not say what it does.
mutate("Options.lua",
       "\tlocal values = { auto = L[\"Automatic (whatever they are missing)\"] }\n",
       "\tlocal values = { auto = L[\"Automatic\"] }\n",
       "who tab: Automatic unexplained",
       expect="Automatic does not say what it does", script=S)

# The switch's tooltip back to the long one.
mutate("Options.lua",
       "\t\t\tdesc = L[\"Untick to never offer this buff.\"],\n",
       "\t\t\tdesc = L[\"Switched off.\"],\n",
       "who tab: the per-spell switch unexplained",
       expect="a per-spell switch does not say what unticking it does", script=S)

# The note under the dropdown opening with something else.
mutate("Options.lua",
       "\tlocal text = L[\"Automatic may offer, in this order: %s. Each person gets the first one they are missing.\"]\n",
       "\tlocal text = L[\"In this order: %s.\"]\n",
       "who tab: the Automatic note does not open with what it may offer",
       expect="the note under the dropdown does not open with what Automatic may offer", script=S)

# The unlearned pick not pointing at the dropdown.
mutate("Options.lua",
       "\t\t.. L[\"Learn it or set Buff to offer back to Automatic.\"]\n",
       "\t\t.. L[\"Learn it.\"]\n",
       "who tab: the pin warning gives no way back",
       expect="the warning does not say how to undo it", script=S)

# --- who it goes to ---

# The distance live with passers-by off.
mutate("Options.lua",
       "\t\t\t\tsorting = ProximityOrder,\n"
       "\t\t\t\thidden = OnlyReachesGroup,\n"
       "\t\t\t\tdisabled = function() return not S().strangers end,\n",
       "\t\t\t\tsorting = ProximityOrder,\n"
       "\t\t\t\thidden = OnlyReachesGroup,\n",
       "who tab: the distance live without passers-by",
       expect="the distance stays live with Passers-by off", script=S)

# Cities and inns live with passers-by off.
mutate("Options.lua",
       "\t\t\t\torder = 13.3,\n"
       "\t\t\t\twidth = \"full\",\n"
       "\t\t\t\thidden = OnlyReachesGroup,\n"
       "\t\t\t\tdisabled = function() return not S().strangers end,\n",
       "\t\t\t\torder = 13.3,\n"
       "\t\t\t\twidth = \"full\",\n"
       "\t\t\t\thidden = OnlyReachesGroup,\n",
       "who tab: cities and inns live without passers-by",
       expect="cities and inns stays live with Passers-by off", script=S)

# Cities and inns shown to a warrior.
mutate("Options.lua",
       "\t\t\t\torder = 13.3,\n"
       "\t\t\t\twidth = \"full\",\n"
       "\t\t\t\thidden = OnlyReachesGroup,\n",
       "\t\t\t\torder = 13.3,\n"
       "\t\t\t\twidth = \"full\",\n",
       "who tab: cities and inns shown to a warrior",
       expect="restingOnly is shown to a warrior", script=S)

# The distances without their yardage.
mutate("Options.lua",
       "\t\tvalues[tier.key] = tier.about and (\"%s (%s)\"):format(tier.name, tier.about) or tier.name\n",
       "\t\tvalues[tier.key] = tier.name\n",
       "who tab: the distances say no yardage",
       expect="the distances do not say roughly how far", script=S)

# --- greyed out while they cannot do anything ---

# My target first live under Always offer.
mutate("Options.lua",
       "\t\t\t\tdisabled = function() return F().whenBuffed == \"always\" end,\n",
       "",
       "who tab: the target switch live under Always offer",
       expect="My target first stays live under Always offer", script=S)

# The raid groups live with the group off.
mutate("Options.lua",
       "\t\t\t\tdisabled = function() return not S().group end,\n"
       "\t\t\t\t-- Stored as the groups switched off",
       "\t\t\t\t-- Stored as the groups switched off",
       "who tab: the raid groups live without the group",
       expect="the raid groups stay live with My party and raid off", script=S)

# --- the reagent line ---

# Never shown.
mutate("Options.lua",
       "\t\t\t\t\treturn NoGroupBuffs() or not (S().group and ns.db.profile.groupBuffs.use)\n",
       "\t\t\t\t\treturn true\n",
       "who tab: the reagent line never shown",
       expect="the reagent line is hidden with group buffs on", script=S)

# Shown with group buffs off.
mutate("Options.lua",
       "\t\t\t\t\treturn NoGroupBuffs() or not (S().group and ns.db.profile.groupBuffs.use)\n",
       "\t\t\t\t\treturn NoGroupBuffs() or not S().group\n",
       "who tab: the reagent line shown with group buffs off",
       expect="the reagent line is shown with group buffs off", script=S)

# Shown with the group off.
mutate("Options.lua",
       "\t\t\t\t\treturn NoGroupBuffs() or not (S().group and ns.db.profile.groupBuffs.use)\n",
       "\t\t\t\t\treturn NoGroupBuffs() or not ns.db.profile.groupBuffs.use\n",
       "who tab: the reagent line shown with the group off",
       expect="the reagent line is shown with My party and raid off", script=S)

# Shown to a class with no group version.
mutate("Options.lua",
       "\t\t\t\t\treturn NoGroupBuffs() or not (S().group and ns.db.profile.groupBuffs.use)\n",
       "\t\t\t\t\treturn not (S().group and ns.db.profile.groupBuffs.use)\n",
       "who tab: the reagent line shown to a warlock",
       expect="a warlock is shown a reagent line", script=S)

# A full bag read as empty.
mutate("Options.lua",
       "\t\t\t\telseif count > 0 then\n",
       "\t\t\t\telseif count > 99 then\n",
       "who tab: the reagent count not said",
       expect="the reagent line does not count the bags", script=S)

# An empty bag not in red.
mutate("Options.lua",
       "\t\t\t\t\tlines[#lines + 1] = \"|cffff8080\"\n"
       "\t\t\t\t\t\t.. L[\"%s: none in your bags, so group buffs are not offered.\"]:format(name)\n",
       "\t\t\t\t\tlines[#lines + 1] = \"\"\n"
       "\t\t\t\t\t\t.. L[\"%s: none in your bags, so group buffs are not offered.\"]:format(name)\n",
       "who tab: an empty bag not in red",
       expect="an empty bag is not said in red", script=S)

# A reagent the client has not named left blank.
mutate("Options.lua",
       "\t\t\t\tlocal name = (ns.ReagentName and ns.ReagentName(item)) or tostring(item)\n",
       "\t\t\t\tlocal name = (ns.ReagentName and ns.ReagentName(item)) or \"?\"\n",
       "who tab: an unnamed reagent not given by id",
       expect="a reagent the client has not named yet is not given by its id", script=S)

# Three Prayers, three candle lines.
mutate("Options.lua",
       "\t\t\tif item and not seen[item] then\n",
       "\t\t\tif item then\n",
       "who tab: one reagent said once per spell",
       expect="the candles are not said once", script=S)

# The line unguarded.
mutate("Options.lua",
       "\t\t\t\t\tlocal ok, text = pcall(ReagentLines)\n",
       "\t\t\t\t\tlocal ok, text = true, ReagentLines()\n",
       "who tab: the reagent line unguarded",
       expect="the reagent line threw", script=S)

# --- one spell, and the mana-only switch ---

# A mage asked to choose between Automatic and his one spell.
mutate("Options.lua",
       "\t\t\t\thidden = function() return OneBuff() and ns.PinnedBuff() == nil end,\n",
       "\t\t\t\thidden = function() return false end,\n",
       "who tab: one spell offered as a choice",
       expect="a mage is offered Buff to offer", script=S)

# ...and, once pinned, left with no way back to Automatic.
mutate("Options.lua",
       "\t\t\t\thidden = function() return OneBuff() and ns.PinnedBuff() == nil end,\n",
       "\t\t\t\thidden = function() return OneBuff() end,\n",
       "who tab: a pinned single spell stuck",
       expect="a mage with a pin has no way back to Automatic", script=S)

# The one-spell rule reaching a class with more than one.
mutate("Options.lua",
       "\t\treturn #buffs == 1 and not buffs[1].neverAuto\n",
       "\t\treturn #buffs >= 1 and not buffs[1].neverAuto\n",
       "who tab: a priest not asked to choose",
       expect="a priest is not offered Buff to offer", script=S)

mutate("Options.lua",
       "\t\t\t\tif OneBuff() and #castable == 1 then\n",
       "\t\t\t\tif false then\n",
       "who tab: one spell described as Automatic",
       expect="a mage is not told the one spell they offer", script=S)

# The tooltip naming another class's spell again.
mutate("Options.lua",
       "\t\t\t\t\t\treturn L[\"%s is not offered to players without mana, such as warriors and rogues.\"]:format(names[1])\n",
       "\t\t\t\t\t\treturn L[\"%s is not offered to players without mana, such as warriors and rogues.\"]:format(\"Divine Spirit\")\n",
       "who tab: mana-only tooltip names a priest spell",
       expect="a mage's tooltip reads", script=S)

mutate("Options.lua",
       "\t\t\t\thidden = function() return #ManaOnlyNames() == 0 end,\n",
       "",
       "who tab: mana-only switch for a warrior",
       expect="a warrior is shown Skip players it does nothing for", script=S)
