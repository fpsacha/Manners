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
       "\t\tif bucket.missing >= atLeast then\n",
       "\t\tif bucket.missing > atLeast then\n",
       "groupbuffs: the threshold is one too high",
       expect="no group cast for two missing it with the threshold set to two", script=S)
mutate("GroupBuffs.lua",
       "\treturn entry.known == false or (entry.known == true and entry.remaining ~= nil)\n",
       "\treturn entry.known ~= true or entry.remaining ~= nil\n",
       "groupbuffs: an unread aura counts as missing",
       expect="a group cast was offered for people nobody read as missing it", script=S)
mutate("GroupBuffs.lua",
       "\t\t\tif have and have > 0 and Usable(info.groupRank) then\n",
       "\t\t\tif Usable(info.groupRank) then\n",
       "groupbuffs: no reagent is no obstacle",
       expect="groupbuffs: no reagent, they are buffed one by one", script=S)
mutate("GroupBuffs.lua",
       "\treturn not (usable == false and noMana ~= true)\n",
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
       "\t\t\t\t\t\tif has == nil or (has == true and ours ~= false) then return false end\n",
       "\t\t\t\t\t\tif has == nil then return false end\n",
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
       "\t\treturn L[\"%s -- %d missing\"]:format(ns.EntrySpellName(entry), group.missing)\n",
       "\t\tgroup = nil\n",
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
       "\tlocal members = pending.group and SettleGroup(pending, spellId) or nil\n",
       "\tlocal members = nil\n",
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
