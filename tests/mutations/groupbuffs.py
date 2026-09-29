# Group buffs: each load-bearing part put back wrong and required to be
# caught by its scenario in tests/scenarios/groupbuffs.lua.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# ------------------------------------------------ the data and the probe
mutate("Core.lua",
       "\t\t\t\tinfo.groupIcon = safecall(C_Spell and C_Spell.GetSpellTexture, rank.id)\n\t\t\t\tbreak\n",
       "\t\t\t\tinfo.groupIcon = safecall(C_Spell and C_Spell.GetSpellTexture, rank.id)\n",
       "groupbuffs: the lowest rank known is taken",
       expect="Gift of the Wild was offered without the reagent its rank takes", script=S)
mutate("Buffs.lua",
       "{ { id = 21850, reagent = WILD_THORNROOT }, { id = 21849, reagent = WILD_BERRIES } }",
       "{ { id = 21850, reagent = WILD_BERRIES }, { id = 21849, reagent = WILD_BERRIES } }",
       "groupbuffs: the second rank's reagent is the first's",
       expect="Gift of the Wild was offered without the reagent its rank takes", script=S)
mutate("Buffs.lua",
       "\tgroupByClass = { PALADIN = true },\n",
       "",
       "groupbuffs: Greater Blessings go by party",
       expect="no Greater Blessing for four warriors missing Might", script=S)

# ------------------------------------------------ when a group cast is offered
mutate("Queue.lua",
       "\t\t\tqueue = ns.GroupCasts(queue, db, candidates, inRaid)\n",
       "",
       "groupbuffs: the queue never asks",
       expect="no group cast was offered for four people missing the buff", script=S)
mutate("GroupBuffs.lua",
       "\t\tif bucket.missing + bucket.low >= atLeast then\n",
       "\t\tif bucket.missing + bucket.low > atLeast then\n",
       "groupbuffs: the threshold is one too high",
       expect="no group cast for two missing it with the threshold set to two", script=S)
mutate("GroupBuffs.lua",
       "\treturn entry.known == false\n",
       "\treturn entry.known ~= true\n",
       "groupbuffs: an unread aura counts as missing",
       expect="a group cast was offered for people nobody read as missing it", script=S)
mutate("GroupBuffs.lua",
       "\t\t\tif have and have > 0 and Usable(info.groupRank) then\n",
       "\t\t\tif Usable(info.groupRank) then\n",
       "groupbuffs: no reagent is no obstacle",
       expect="groupbuffs: no reagent, they are buffed one by one", script=S)
mutate("GroupBuffs.lua",
       "\treturn usable ~= false\n",
       "\treturn true\n",
       "groupbuffs: the client's no is not asked",
       expect="groupbuffs: the client says it cannot be cast, they are buffed one by one", script=S)
mutate("GroupBuffs.lua",
       "\tif not (settings and settings.use == true and db.sources.group) then return queue end\n",
       "\tif not (settings and settings.use == true) then return queue end\n",
       "groupbuffs: the party source is not asked",
       expect="three favours were folded into a group cast with My party and raid off", script=S)
mutate("GroupBuffs.lua",
       "\tif not (settings and settings.use == true and db.sources.group) then return queue end\n",
       "\tif not (settings and db.sources.group) then return queue end\n",
       "groupbuffs: the switch is not asked",
       expect="groupbuffs: switched off, they are buffed one by one", script=S)

# ------------------------------------------------ who a cast reaches
mutate("GroupBuffs.lua",
       "\t\t\t\twhere = RaidSubgroup(entry.unit)\n",
       "\t\t\t\twhere = \"party\"\n",
       "groupbuffs: a raid is one party",
       expect="the group cast covers people outside the target's subgroup", script=S)
mutate("GroupBuffs.lua",
       "\t\tif not ClassSafe(bucket.where, bucket.buff.key, offered, inRaid) then return nil end\n",
       "",
       "groupbuffs: a Greater Blessing replaces another of ours",
       expect="a Greater Blessing of Might was offered over our own Kings on a warrior", script=S)
mutate("GroupBuffs.lua",
       "\t\t\tif has == nil or (has == true and ours ~= false) then return true end\n",
       "\t\t\tif has == nil then return true end\n",
       "groupbuffs: our other blessing on the class is not read",
       expect="a Greater Blessing of Might was offered over our own Kings on a warrior", script=S)
mutate("GroupBuffs.lua",
       "\t\t\tif entry.known == nil then return nil end\n",
       "",
       "groupbuffs: an unread member of the class is let through",
       expect="a Greater Blessing was offered over a warrior nobody could read", script=S)
mutate("GroupBuffs.lua",
       "\t\tif entry.ranged ~= false and (not anchor or Better(entry, anchor)) then anchor = entry end\n",
       "\t\tif not anchor or Better(entry, anchor) then anchor = entry end\n",
       "groupbuffs: aimed at somebody out of range",
       expect="a group cast was aimed at somebody measured out of range", script=S)
mutate("GroupBuffs.lua",
       "\tif a.priority ~= b.priority then return a.priority < b.priority end\n\tif (a.ranged",
       "\tif (a.ranged",
       "groupbuffs: aimed past a favour",
       expect="the group cast is not aimed at somebody owed", script=S)
mutate("Queue.lua",
       "\t\tif (a.groupCast ~= nil) ~= (b.groupCast ~= nil) then return a.groupCast ~= nil end\n",
       "",
       "groupbuffs: the group cast sorts by name",
       expect="the group cast does not come before the single casts of its kind", script=S)

# ------------------------------------------------ the reagent running out
mutate("GroupBuffs.lua",
       "\tif count ~= 0 or not stocked[item] or told[item] then return end\n",
       "\tif count ~= 0 or not stocked[item] then return end\n",
       "groupbuffs: the note nags",
       expect="running out was said", script=S)
mutate("GroupBuffs.lua",
       "\tif count ~= 0 or not stocked[item] or told[item] then return end\n",
       "\tif count ~= 0 or stocked[item] or told[item] then return end\n",
       "groupbuffs: the note is never said",
       expect="running out was said", script=S)

# ------------------------------------------------ the prompt
mutate("Prompt.lua",
       "\tlocal group = entry.groupCast\n\tif group then\n",
       "\tlocal group = entry.groupCast\n\tif false then\n",
       "groupbuffs: the second line is a person's",
       expect="the panel does not name the party and the count", script=S)
mutate("Prompt.lua",
       "\treturn STRATEGIES[StrategyFor(entry)](entry, ns.EntrySpellName(entry))\n",
       "\treturn STRATEGIES[StrategyFor(entry)](entry, ns.BuffName(entry.buff))\n",
       "groupbuffs: the macro casts the single spell",
       expect="the macro does not target one of them and cast Arcane Brilliance", script=S)
mutate("Prompt.lua",
       "\t\ttostring(entry.groupCast and entry.groupCast.spell),\n",
       "",
       "groupbuffs: the macro is not rebuilt for the group cast",
       expect="the macro still casts the single buff at a party", script=S)
mutate("Prompt.lua",
       "\tlocal have = ns.ReagentCount(group.reagent) or group.reagents\n",
       "\tlocal have = 0\n",
       "groupbuffs: the tooltip does not count",
       expect="the tooltip does not count the reagent", script=S)
mutate("Prompt.lua",
       "\tfor _, name in ipairs(group.members) do Note(name) end\n",
       "",
       "groupbuffs: the tooltip names only the anchor's favour",
       expect="the tooltip does not name the favours the group cast returns", script=S)
mutate("Speech.lua",
       "\t\tlocal spell = entry.groupCast and entry.groupCast.spellName\n",
       "\t\tlocal spell = nil\n",
       "groupbuffs: the spoken line names the single spell",
       expect="the spoken line does not name the group spell", script=S)

# ------------------------------------------------ the press and the settle
mutate("Prompt.lua",
       "\t\tfor _, name in ipairs(current.groupCast.members) do\n\t\t\tns.MarkAttempted(name, current.buff.key)\n",
       "\t\tfor _, name in ipairs(current.groupCast.members) do\n",
       "groupbuffs: the press blocks only the anchor",
       expect="of the people it covered were offered again while the press waited for the game", script=S)
mutate("Clicks.lua",
       "\tif pending.group then members, givenAs = SettleGroup(pending, spellId, wasOwed ~= nil) end\n",
       "",
       "groupbuffs: the settle repays only the anchor",
       expect="a favour the group cast covered is still owed", script=S)
mutate("Clicks.lua",
       "\t\t\tTellLedger(\"Settled\", name, debt, covered, spellId)\n",
       "",
       "groupbuffs: the ledger never hears of the other favours",
       expect="the ledger does not show both favours returned", script=S)
mutate("Clicks.lua",
       "\tif #repaid > 0 and db and db.verbose then\n",
       "\tif false then\n",
       "groupbuffs: the other favours are returned in silence",
       expect="nothing says the group cast returned Dain's favour too", script=S)
mutate("Clicks.lua",
       "\tif settled.members then UnsettleGroup(settled) end\n",
       "",
       "groupbuffs: a late refusal forgets the other favours",
       expect="a favour the refused group cast had returned is not owed again", script=S)
mutate("Clicks.lua",
       "\t\t\tTellLedger(\"Refused\", member.name, settled.at)\n",
       "",
       "groupbuffs: a late refusal leaves the ledger returned",
       expect="the ledger still shows", script=S)
mutate("Clicks.lua",
       "\t\tfor _, name in ipairs(pending.group.members) do\n\t\t\tns.MarkAttempted(name, pending.buffKey, 2)\n",
       "\t\tfor _, name in ipairs(pending.group.members) do\n",
       "groupbuffs: a refused press keeps the party blocked",
       expect="three seconds after a refused press the party is not offered again", script=S)
mutate("Ledger.lua",
       "\t\t\te.covered = #group.members + 1\n",
       "",
       "groupbuffs: the ledger row does not say how many",
       expect="the ledger row does not say one Arcane Brilliance reached four", script=S)

# ------------------------------------------------ the settings
mutate("Core.lua",
       "\t\t\tuse = true,\n",
       "\t\t\tuse = false,\n",
       "groupbuffs: off by default",
       expect="a new profile has use=", script=S)
mutate("Core.lua",
       "\tboolean(profile.groupBuffs, \"use\", true)\n",
       "",
       "groupbuffs: a garbage switch is kept",
       expect="was repaired to", script=S)
mutate("Core.lua",
       "\t{ \"groupBuffs\", \"atLeast\", 2, 5 },\n",
       "",
       "groupbuffs: a garbage threshold is kept",
       expect="was repaired to", script=S)
mutate("Core.lua",
       "\tprofile.groupBuffs.atLeast = math.floor(profile.groupBuffs.atLeast)\n",
       "",
       "groupbuffs: a fractional threshold is kept",
       expect="was repaired to", script=S)
mutate("Options.lua",
       "\t\t\t\tset = function(_, v) ns.db.profile.groupBuffs.use = v end,\n",
       "\t\t\t\tset = function(_, v) end,\n",
       "groupbuffs: the toggle writes nothing",
       expect="the toggle does not switch group buffs off", script=S)
mutate("Options.lua",
       "\t\t\t\tdisabled = function() return not S().group end,\n\t\t\t\tget = function() return ns.db.profile.groupBuffs.use end,\n",
       "\t\t\t\tget = function() return ns.db.profile.groupBuffs.use end,\n",
       "groupbuffs: the toggle is live with the party off",
       expect="the toggle stays live with My party and raid off", script=S)
mutate("Options.lua",
       "\t\t\t\tdisabled = function() return not (S().group and ns.db.profile.groupBuffs.use) end,\n",
       "",
       "groupbuffs: the threshold is live with the switch off",
       expect="the threshold stays live with group buffs off", script=S)
mutate("GroupBuffs.lua",
       "\t\tif buff.groupCast then return true end\n",
       "\t\treturn true\n",
       "groupbuffs: every class is shown the setting",
       expect="a warlock is shown a setting for group buffs", script=S)

# ------------------------------------------------ review round: the spell said
mutate("Prompt.lua",
       "\t\ttostring(entry.groupCast and entry.groupCast.spell), tostring(ns.tryMacro) }, \"\\1\")\n",
       "\t\ttostring(ns.tryMacro) }, \"\\1\")\n",
       "groupbuffs: the spoken line is kept across a change of spell",
       expect="the spoken line kept the group spell for a single cast", script=S)
mutate("Phrases.lua",
       "\t\tlocal buff = entry.groupCast and ns.EntrySpellName and ns.EntrySpellName(entry) or single\n",
       "\t\tlocal buff = single\n",
       "groupbuffs: in character names the single spell",
       expect="in-character lines named the single spell over a group cast", script=S)
mutate("Phrases.lua",
       "\t\t\t\t\tand not (notSaying and text:find(notSaying, 1, true))\n",
       "",
       "groupbuffs: in character says Mark of the Wild over Gift of the Wild",
       expect="in-character lines named the single spell over a group cast", script=S)

# ------------------------------------------------ review round: mana
mutate("GroupBuffs.lua",
       "\tlocal usable = safecall(check, spellId)\n\treturn usable ~= false\n",
       "\tlocal usable, noMana = safecall(check, spellId)\n\treturn not (usable == false and noMana ~= true)\n",
       "groupbuffs: too little mana for the group spell is no obstacle",
       expect="groupbuffs: mana enough only for the single spell, they are buffed one by one", script=S)

# ------------------------------------------------ review round: the ledger
mutate("Clicks.lua",
       "\t\t\t\tTellLedger(\"Settled\", givenAs, nil, covered, spellId)\n",
       "",
       "groupbuffs: a group cast at a favour is not counted as given",
       expect="a group cast aimed at a favour counted as", script=S)
mutate("Clicks.lua",
       "\tif settled.givenAs then TellLedger(\"Refused\", settled.givenAs, settled.at) end\n",
       "",
       "groupbuffs: a late refusal keeps the group cast's given row",
       expect="a late refusal left the group cast counted as given", script=S)
mutate("Ledger.lua",
       "\t\tif covered > 1 then out.covered = covered end\n",
       "",
       "groupbuffs: a reload drops the count",
       expect="after a reload the row no longer says how many it reached", script=S)
mutate("Ledger.lua",
       "\tid = group and CleanSpell(group.spell)\n",
       "\tid = nil\n",
       "groupbuffs: a withheld id is filed as the single spell",
       expect="with the id withheld the row names", script=S)

# ------------------------------------------------ review round: the settle
mutate("Clicks.lua",
       "\t\tns.ServeRequest(name, pending.buffKey)\n\t\trecords[",
       "\t\trecords[",
       "groupbuffs: a member's request is not answered",
       expect="Dain's request still stands after the group cast covered him", script=S)
mutate("Clicks.lua",
       "\t\t\t\tTellLedger(\"LetGo\", member.name, \"never\")\n",
       "",
       "groupbuffs: a member listed since the settle is owed again",
       expect="the ledger shows Dain's favour", script=S)

# ------------------------------------------------ review round: skipping
mutate("Prompt.lua",
       "\t\tif group and ns.SkipGroupCast then ns.SkipGroupCast(group) end\n",
       "",
       "groupbuffs: not now skips only the anchor",
       expect="offers of Arcane Intellect came straight back after skipping the party", script=S)
mutate("GroupBuffs.lua",
       "\t\tns.MarkAttempted(name, entry.buff.key, nil, true)\n",
       "",
       "groupbuffs: skipping a group cast blocks nobody",
       expect="offers of Arcane Intellect came straight back after skipping the party", script=S)
mutate("Prompt.lua",
       "\t\t\tlocal shown = (group and group.groupCast.label)\n\t\t\t\tor ",
       "\t\t\tlocal shown = ",
       "groupbuffs: the skip line names the anchor",
       expect="chat does not say the party was skipped", script=S)
mutate("Prompt.lua",
       "\t\t\t\tns.addon:Print(L[\"The rest of %s is skipped for now.\"]:format(group.groupCast.label or \"?\"))\n",
       "",
       "groupbuffs: never on a group cast says nothing of the rest",
       expect="chat does not say the rest were skipped", script=S)
mutate("Options.lua",
       "\t-- A group cast is skipped whole, as a right-press on it is.\n\tif ns.SkipGroupCast then ns.SkipGroupCast(entry) end\n",
       "",
       "groupbuffs: the menu's skip skips only the anchor",
       expect="offers came straight back after Skip for now on the party", script=S)
mutate("Options.lua",
       "\treturn tostring(entry.display or entry.short or entry.name)\n",
       "\treturn tostring(entry.short or entry.name)\n",
       "groupbuffs: the launcher names the anchor",
       expect="the launcher's tooltip does not name the group cast", script=S)
mutate("Options.lua",
       "\treturn tostring(ns.EntrySpellName and ns.EntrySpellName(entry)\n\t\tor ns.BuffName",
       "\treturn tostring(ns.BuffName",
       "groupbuffs: the launcher names the single spell",
       expect="the launcher's tooltip does not name the group cast", script=S)
mutate("Prompt.lua",
       "\t\tGameTooltip:AddLine(group and L[\"Right-click to skip this group buff for now.\"]\n\t\t\tor L[",
       "\t\tGameTooltip:AddLine(L[",
       "groupbuffs: the tooltip's skip line is a person's",
       expect="the tooltip does not say what a right-click does to a group cast", script=S)

# ------------------------------------------------ review round: the panel
mutate("Prompt.lua",
       "\t\tlocal groupIcon = entry.groupCast and entry.groupCast.icon\n",
       "\t\tlocal groupIcon = nil\n",
       "groupbuffs: the panel shows the single spell's icon",
       expect="the panel shows icon", script=S)
mutate("GroupBuffs.lua",
       "\telseif bucket.where == ownSubgroup then\n",
       "\telseif false then\n",
       "groupbuffs: your own raid group is called by number",
       expect="the raid's group casts are not named by raid group", script=S)
mutate("GroupBuffs.lua",
       "\tlocal ownSubgroup = inRaid and not byClass and RaidSubgroup(\"player\") or nil\n",
       "\tlocal ownSubgroup = nil\n",
       "groupbuffs: the player's own raid group is never read",
       expect="the raid's group casts are not named by raid group", script=S)
mutate("GroupBuffs.lua",
       "\t\t\t\tif Missing(entry) then\n",
       "\t\t\t\tif Missing(entry) or RunningLow(entry) then\n",
       "groupbuffs: running out is counted as missing",
       expect="four running out reads", script=S)
mutate("Prompt.lua",
       "\t\tif low == 0 then return L[\"%s -- %d missing\"]:format(spell, missing) end\n",
       "\t\tif true then return L[\"%s -- %d missing\"]:format(spell, missing + low) end\n",
       "groupbuffs: the second line calls everybody missing",
       expect="four running out reads", script=S)
mutate("Prompt.lua",
       "\tif missing > 0 and low > 0 then\n",
       "\tif false then\n",
       "groupbuffs: the tooltip hides who is running out",
       expect="the tooltip does not tell missing from running out", script=S)

# ------------------------------------------------ review round: running low
mutate("GroupBuffs.lua",
       "\t\tif count <= LOW_STOCK and before and count < before and not warnedLow[item] then\n",
       "\t\tif count <= LOW_STOCK and not warnedLow[item] then\n",
       "groupbuffs: the heads-up comes at login",
       expect="the heads-up came at login", script=S)
mutate("GroupBuffs.lua",
       "\t\tif count <= LOW_STOCK and before and count < before and not warnedLow[item] then\n",
       "\t\tif count <= LOW_STOCK and before and count < before then\n",
       "groupbuffs: the heads-up nags",
       expect="the heads-up was said", script=S)
mutate("GroupBuffs.lua",
       "local LOW_STOCK = 5\n",
       "local LOW_STOCK = 0\n",
       "groupbuffs: the heads-up never comes",
       expect="the heads-up was said", script=S)

# ------------------------------------------------ review round: the settings
mutate("Options.lua",
       "\t\t\t\tname = L[\"When this many need it\"],\n",
       "\t\t\t\tname = L[\"When at least this many are missing\"],\n",
       "groupbuffs: the threshold's name does not stand on its own",
       expect="the threshold's name does not say", script=S)
mutate("GroupBuffs.lua",
       "\t\tif info and info.groupName then names[#names + 1] = info.groupName end\n",
       "",
       "groupbuffs: the toggle does not name the class's spell",
       expect="the toggle does not name the mage's own group spell", script=S)
mutate("GroupBuffs.lua",
       "\tif ns.GROUP_BY_CLASS[ns.PlayerClass()] == true then\n\t\treturn L[",
       "\tif false then\n\t\treturn L[",
       "groupbuffs: a paladin reads about parties",
       expect="a paladin's threshold does not say it counts one class", script=S)
