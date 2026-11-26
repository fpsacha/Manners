# Mutations for cures (sources.cures, sources.curesStrangers,
# filters.cureSeconds): the tables and the reading (Cures.lua), the walk's
# hooks (Queue.lua), what answers for a cure and whether there is a prompt for
# one (Core.lua), the press and its settle (Prompt/Press.lua, Clicks.lua), the
# silence (Speech.lua), the words (Prompt/Paint.lua, Prompt/Button.lua), the
# reading forgotten at UNIT_AURA (Favours.lua), /manners debug and the check-up
# (Commands.lua, Options/Diagnostics.lua) and the settings (Options/Who.lua,
# Options/Advanced.lua, Options/Window/Layout.lua). Each is caught by the
# scenario in tests/scenarios/cures.lua that names it.

S = "runscenarios.py"

# ------------------------------------------------------------ the switches
# On in a new profile: nobody asked to cure their group.
mutate("Core.lua",
       "\t\t\tcures = false,\n",
       "\t\t\tcures = true,\n",
       "cures: on in a new profile",
       expect="cures: off by default, and nobody's debuffs are read", script=S)

# One switch for everybody: a passer-by cured on the group's, a member on theirs.
mutate("Queue.lua",
       "\t\t\tand (inGroup and opts.cures.group or not inGroup and opts.cures.strangers) or nil\n",
       "\t\t\tand (opts.cures.group or opts.cures.strangers) or nil\n",
       "cures: one switch reaches everybody",
       expect="cures: passers-by have a switch of their own", script=S)

# ------------------------------------------------------------ the walk
# The walk never asks for a cure.
mutate("Queue.lua",
       "\t\tif curing and ns.CureFor then\n",
       "\t\tif false then\n",
       "cures: the walk asks for no cure",
       expect="cures: a poisoned party member is offered the cure, by the usual press", script=S)

# A cure answered for as a buff of the set, which it is not: no name, no rank.
mutate("Core.lua",
       "\tif buff.cure then return ns.CureInfo(buff) end\n",
       "",
       "cures: a cure is asked of the buff set",
       expect="cures: a poisoned party member is offered the cure, by the usual press", script=S)

# A cure ranked with the passers-by: a buff for the group comes first.
mutate("Modules/Combat/Cures.lua",
       "local PRIORITY = 1.25\n",
       "local PRIORITY = 2.5\n",
       "cures: a cure ranked after the group's buffs",
       expect="cures: a cure comes before a buff, for the same person and in the queue", script=S)

# A cure ranked over a favour owed.
mutate("Modules/Combat/Cures.lua",
       "local PRIORITY = 1.25\n",
       "local PRIORITY = 0.75\n",
       "cures: a cure ranked over a favour owed",
       expect="cures: a favour owed comes before a cure", script=S)

# Somebody owed a favour is cured first, and their buff back waits.
mutate("Queue.lua",
       "\t\tlocal curing = opts.cures and not isOwed and not owner\n",
       "\t\tlocal curing = opts.cures and not owner\n",
       "cures: a cure before the favour owed them",
       expect="cures: a favour owed comes before a cure", script=S)

# ------------------------------------------------------------ what is offered
# Any time left will do.
mutate("Modules/Combat/Cures.lua",
       "\t\telseif debuff.expires - now <= scan.seconds then\n",
       "\t\telseif debuff.expires - now <= 0 then\n",
       "cures: a debuff about to run out is offered",
       expect="cures: a debuff about to run out is left alone", script=S)

# The first of a kind in the list is the one read, however little it has left.
mutate("Modules/Combat/Cures.lua",
       "\t\t\t\t\telseif expires > found.expires then\n",
       "\t\t\t\t\telseif false then\n",
       "cures: a short debuff hides a long one of its kind",
       expect="cures: a debuff about to run out is left alone", script=S)

# No timer read as a timer of nothing.
mutate("Modules/Combat/Cures.lua",
       "\t\t\t\telseif type(expires) ~= \"number\" or expires <= 0 then\n",
       "\t\t\t\telseif false then\n",
       "cures: no timer is not said",
       expect="cures: a debuff with no timer is never offered", script=S)

# The deny list unread.
mutate("Modules/Combat/Cures.lua",
       "\t\t\t\tif type(id) == \"number\" and DENIED[id] then\n",
       "\t\t\t\tif false then\n",
       "cures: the deny list is not read",
       expect="cures: a debuff on the deny list is never offered", script=S)

# A spell not learned is offered all the same.
mutate("Modules/Combat/Cures.lua",
       "\t\tif info.known and not state.byKind[cure.cure] and",
       "\t\tif not state.byKind[cure.cure] and",
       "cures: a cure not learned is offered",
       expect="cures: only a kind you have a spell for, and know", script=S)

# Any kind answered with whatever cure there is.
mutate("Modules/Combat/Cures.lua",
       "\t\t\tlocal cure = type(kind) == \"string\" and byKind[kind] or nil\n",
       "\t\t\tlocal cure = type(kind) == \"string\" and (byKind[kind] or byKind.Curse) or nil\n",
       "cures: a kind you cannot remove is offered",
       expect="cures: only a kind you have a spell for, and know", script=S)

# The client's own no ignored.
mutate("Modules/Combat/Cures.lua",
       "\t\t\tif cure and plain(aura.canActivePlayerDispel) ~= false then\n",
       "\t\t\tif cure then\n",
       "cures: the client's no is ignored",
       expect="cures: what the client says you cannot remove is left alone", script=S)

# A passive a kind waits on is not asked for.
mutate("Modules/Combat/Cures.lua",
       " and (not cure.needs or ns.SpellKnown(cure.needs)) then\n",
       " then\n",
       "cures: a kind offered without its passive",
       expect="cures: mists: Cleanse lifts magic only with Sacred Cleansing", script=S)

# Retail given no table.
mutate("Modules/Combat/Cures.lua",
       "mists = MISTS, mainline = MAINLINE }\n",
       "mists = MISTS }\n",
       "cures: a client left without its table",
       expect="cures: every class with a cure on a client is offered one there", script=S)

# ------------------------------------------------------------ never in a fight
mutate("Modules/Combat/Cures.lua",
       "\tif scan.fight then return nil end\n",
       "",
       "cures: offered in a fight",
       expect="cures: nothing is offered or read in a fight", script=S)

# The pull's own repaint arms a cure for every press of the fight.
mutate("Modules/Combat/Cures.lua",
       "\tif prompt and prompt.armedForFight == true then return true end\n",
       "",
       "cures: armed at the pull",
       expect="cures: nothing is offered or read in a fight", script=S)

# ------------------------------------------------------------ apart from the buff switches
# The group switch turns a member away before the cure is read, as it did.
mutate("Queue.lua",
       "\t\tif reason == \"group\" and not db.sources.group and not curing then\n",
       "\t\tif reason == \"group\" and not db.sources.group then\n",
       "cures: the group switch holds back a cure",
       expect="cures: the cure switches stand apart from the buff switches", script=S)

mutate("Queue.lua",
       "\t\tif reason == \"nearby\" and not db.sources.strangers and not curing then return end\n",
       "\t\tif reason == \"nearby\" and not db.sources.strangers then return end\n",
       "cures: the passers-by switch holds back a cure",
       expect="cures: the cure switches stand apart from the buff switches", script=S)

# With nothing to cure the buff switches stand: a member offered a buff with
# My party and raid off, and no verdict written.
mutate("Queue.lua",
       "\t\t\tif reason == \"group\" and not db.sources.group then\n"
       "\t\t\t\trejected[full] = true\n\t\t\t\treturn\n\t\t\tend\n",
       "",
       "cures: a cure switch lets the group past its own",
       expect="cures: the cure switches stand apart from the buff switches", script=S)

mutate("Queue.lua",
       "\t\t\tif reason == \"nearby\" and (not db.sources.strangers or groupOnly) then\n"
       "\t\t\t\trejected[full] = true\n\t\t\t\treturn\n\t\t\tend\n",
       "",
       "cures: a cure switch lets passers-by past their own",
       expect="cures: the cure switches stand apart from the buff switches", script=S)

# ------------------------------------------------------------ a cure and nothing else
# No walk with no buff in hand, a cure or not.
mutate("Queue.lua",
       " and not curesScanned then\n",
       " then\n",
       "cures: no walk for a cure alone",
       expect="cures: a class with a cure and no buff for others still walks", script=S)

# No prompt for a class whose one spell is a cure.
mutate("Core.lua",
       "\tif ns.CuresWanted and ns.CuresWanted() then return true end\n",
       "",
       "cures: no prompt for a cure alone",
       expect="cures: a class with a cure and no buff for others still walks", script=S)

# ------------------------------------------------------------ the press
# Settled as a buff: the favour they were owed counted as returned.
mutate("Clicks.lua",
       "\tif pending.cure then unheard, wasOwed = true, nil end\n",
       "",
       "cures: a cure settles as a buff",
       expect="cures: a press settles as a cure, and is not offered again at once", script=S)

mutate("Prompt/Press.lua",
       "\t\tcure = S.current.cure,\n",
       "",
       "cures: the press forgets it was a cure",
       expect="cures: a press settles as a cure, and is not offered again at once", script=S)

# Offered again on the reading from before the press.
mutate("Modules/Combat/Cures.lua",
       "\t\telseif ns.IsBlocked(full, cure.key, now) then\n",
       "\t\telseif false then\n",
       "cures: offered again the moment after the press",
       expect="cures: a press settles as a cure, and is not offered again at once", script=S)

# A line said over a cure.
mutate("Speech.lua",
       "\t\tif entry.cure then return nil end\n",
       "",
       "cures: a line is said over a cure",
       expect="cures: nothing is said over a cure", script=S)

# ------------------------------------------------------------ the words
mutate("Prompt/Paint.lua",
       "\tif entry.cure then return ns.CureReason(entry) end\n",
       "",
       "cures: the reason line does not say what they are under",
       expect="cures: the reason line and the tooltip say what they are under", script=S)

mutate("Prompt/Button.lua",
       "\tif entry.cure then why = ns.CureReason(entry, true) end\n",
       "",
       "cures: the tooltip does not say what they are under",
       expect="cures: the reason line and the tooltip say what they are under", script=S)

# ------------------------------------------------------------ ready to cast
mutate("Modules/Combat/Cures.lua",
       "\tif usable == false and noMana == true then answer = \"mana\" end\n",
       "",
       "cures: offered with no mana for it",
       expect="cures: a cure cooling down or unpaid for is not offered", script=S)

mutate("Modules/Combat/Cures.lua",
       "\t\t\t\tanswer = \"cooldown\"\n",
       "\t\t\t\tanswer = true\n",
       "cures: offered while it cools down",
       expect="cures: a cure cooling down or unpaid for is not offered", script=S)

# The global cooldown taken for the spell's own.
mutate("Modules/Combat/Cures.lua",
       " and type(duration) == \"number\" and duration > 3\n",
       " and type(duration) == \"number\" and duration > 0\n",
       "cures: held back for the global cooldown",
       expect="cures: a cure cooling down or unpaid for is not offered", script=S)

# ------------------------------------------------------------ passers-by, remembered
mutate("Modules/Combat/Cures.lua",
       "\t\t\t\t\tif not inGroup and not pointed then Remember(entry, guid, now) end\n",
       "",
       "cures: a passer-by is not remembered",
       expect="cures: a passer-by under the cursor stays offered once it leaves them", script=S)

mutate("Queue.lua",
       "\tif opts.cures and ns.CuresRemembered then\n"
       "\t\tns.CuresRemembered(queue, seen, rejected, now, savingMana or notResting)\n"
       "\tend\n",
       "",
       "cures: the remembered are not offered",
       expect="cures: a passer-by under the cursor stays offered once it leaves them", script=S)

mutate("Modules/Combat/Cures.lua",
       "\t\t\tor now - memo.seen >= LINGER_SECONDS\n",
       "",
       "cures: the remembered are never let go",
       expect="cures: a passer-by under the cursor stays offered once it leaves them", script=S)

mutate("Modules/Combat/Cures.lua",
       "\t\tif drop or not scan.strangers\n",
       "\t\tif drop\n",
       "cures: the remembered outlast their switch",
       expect="cures: a passer-by under the cursor stays offered once it leaves them", script=S)

# ------------------------------------------------------------ the reading
# Read again on every scan: a raid's worth of protected calls 2.5 times a second.
mutate("Modules/Combat/Cures.lua",
       "\tif record and now < record.trustedTo then return record end\n",
       "",
       "cures: every scan reads everybody again",
       expect="cures: a reading is kept three seconds and forgotten at UNIT_AURA", script=S)

# UNIT_AURA forgets nothing: a cure that landed is offered for three more seconds.
mutate("Favours.lua",
       "\tif ns.cureReads and ns.ModuleActive and ns.ModuleActive(\"combat\") then\n"
       "\t\tns.ForgetCureRead(unit)\n\tend\n",
       "",
       "cures: UNIT_AURA leaves the reading standing",
       expect="cures: a reading is kept three seconds and forgotten at UNIT_AURA", script=S)

# ------------------------------------------------------------ said
mutate("Commands.lua",
       "\t\tfor _, line in ipairs(ns.CureLines and ns.CureLines() or {}) do self:Print(\"  \" .. line) end\n",
       "",
       "cures: /manners debug silent",
       expect="cures: /manners debug says what you cure, or that it is switched off", script=S)

mutate("Options/Diagnostics.lua",
       "\tpcall(function() Heard(ns.CureLines and ns.CureLines() or {}) end)\n",
       "",
       "cures: somebody left alone named in the check-up",
       expect="cures: the full check-up does not name somebody left alone", script=S)

mutate("Options/Diagnostics.lua",
       "\tlines[#lines + 1] = (\"cures group/passers-by/seconds=%s/%s/%s\"):format(tostring(db.sources.cures),\n"
       "\t\ttostring(db.sources.curesStrangers), tostring(db.filters.cureSeconds))\n",
       "",
       "cures: the bug report leaves the switches out",
       expect="cures: the bug report says how the switches are set", script=S)

# ------------------------------------------------------------ the settings
mutate("Modules/Combat/Options.lua",
       "api:RegisterOptionsExtension(\"who\", function(_, args)\n",
       "api:RegisterOptionsExtension(\"none\", function(_, args)\n",
       "cures: no controls on Who to buff",
       expect="cures: the switches are on Who to buff, for a class with a cure", script=S)

# Shown to a class with nothing to cure with.
mutate("Modules/Combat/Options.lua",
       "return not api:ModuleActive(\"combat\") or not ns.ClassHasCures()",
       "return not api:ModuleActive(\"combat\")",
       "cures: the controls shown to a warrior",
       expect="cures: the switches are on Who to buff, for a class with a cure", script=S)

# Added before a class with nothing for others has the page cleared for it.
mutate("Modules/Combat/Options.lua",
       "order = 14.93, width = \"full\", hidden = NoCures,\n",
       "order = 14.93, width = \"full\", hidden = function() return true end,\n",
       "cures: the controls hidden from a shaman",
       expect="cures: the switches are on Who to buff, for a class with a cure", script=S)

mutate("Modules/Combat/Options.lua",
       "api:InsertLayoutItems(\"who\", \"who.resStrangers\", {\n"
       "\t\"who.curesNote\", \"who.cures\", \"who.curesStrangers\", \"who.curesSelf\",\n"
       "\t{ \"who.cureSeconds\", indent = true }, \"who.curesFight\",\n"
       "})\n",
       "api:InsertLayoutItems(\"who\", \"who.missing\", {})\n",
       "cures: the window places no control",
       expect="cures: the switches are on Who to buff, for a class with a cure", script=S)

mutate("Options/Advanced.lua",
       "\t\t\"sources.cures\", \"sources.curesStrangers\", \"sources.curesSelf\", \"filters.cureSeconds\", \"prompt.cureFight\", \"prompt.cureFightEach\",\n",
       "",
       "cures: the page's reset leaves the settings",
       expect="cures: the switches are on Who to buff, for a class with a cure", script=S)

# The seconds unbounded: a hand-edited 999 stands.
mutate("Core.lua",
       "\t{ \"filters\", \"cureSeconds\", 0, 120 },\n",
       "",
       "cures: the seconds are not clamped",
       expect="cures: the switches are on Who to buff, for a class with a cure", script=S)
