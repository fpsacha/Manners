# Mutations for "Skip players flagged for PvP": the rule in the queue's walk,
# the owed fallback and the memory of passers-by (Queue.lua), the group casts
# and shouts that land on a whole party (GroupBuffs.lua, Queue.lua), the flag
# read with a favour (Favours.lua), the prompt's hold and press (Prompt.lua),
# the setting and its repair (Core.lua, Options.lua), what /manners debug says
# (Commands.lua) and what the ledger's owed row says (Ledger.lua). Each is
# caught by the scenario in tests/scenarios/pvp.lua that names it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# ------------------------------------------------ the walk

# The rule never applied: a flagged passer-by is offered.
mutate("Queue.lua",
       "\t\t\tif pvpHeld and flag == true then\n",
       "\t\t\tif false then\n",
       "pvp: flagged passer-by offered",
       expect="a flagged passer-by was offered while you are not flagged", script=S)

# Held back but not written down as a verdict, so the prompt's hold cannot
# tell it from a token lost.
mutate("Queue.lua",
       "\t\t\t\trejected[full] = true\n\t\t\t\tpvpHeld[full] = true\n\t\t\t\treturn\n",
       "\t\t\t\tpvpHeld[full] = true\n\t\t\t\treturn\n",
       "pvp: held back without a verdict",
       expect="holding a flagged passer-by back is not a verdict the prompt can read", script=S)

# Written down, and walked on into the queue all the same: the panel under the
# cursor stays on them.
mutate("Queue.lua",
       "\t\t\t\tpvpHeld[full] = true\n\t\t\t\treturn\n",
       "\t\t\t\tpvpHeld[full] = true\n",
       "pvp: flagged person walked on",
       expect="under the cursor the prompt lets go of somebody who becomes flagged", script=S)

# A favour made the exception, as the never-offer list makes it.
mutate("Queue.lua",
       "\t\t\tif pvpHeld and flag == true then\n",
       "\t\t\tif pvpHeld and flag == true and not owed[full] then\n",
       "pvp: a favour exempt",
       expect="offered their favour back while a token found them flagged", script=S)

# Your target made the exception, as the city rule makes it.
mutate("Queue.lua",
       "\t\t\tif pvpHeld and flag == true then\n",
       "\t\t\tif pvpHeld and flag == true and not pointed then\n",
       "pvp: your target exempt",
       expect="your target was offered while flagged for PvP", script=S)

# The setting not read.
mutate("Queue.lua",
       "\tlocal pvpRead = f.skipPvP == true\n",
       "\tlocal pvpRead = true\n",
       "pvp: the setting ignored",
       expect="a flagged passer-by was held back with Skip players flagged for PvP off", script=S)

# The rule never stands aside while you are flagged yourself.
mutate("Queue.lua",
       "\t\tlocal you, countdown = YouAreFlagged()\n",
       "\t\tlocal you, countdown = nil, nil\n",
       "pvp: never stands aside",
       expect="a flagged passer-by was not offered while you are flagged too", script=S)

# Applied to yourself as well.
mutate("Queue.lua",
       "\tif mine then\n\t\tqueue[#queue + 1] = mine\n",
       "\tif mine and not pvpHeld then\n\t\tqueue[#queue + 1] = mine\n",
       "pvp: applied to yourself",
       expect="you were not offered your own buff while the rule held a passer-by back", script=S)

# ------------------------------------------------ reading a flag

# The free-for-all flag not counted.
mutate("Queue.lua",
       "\tif pvp == true or ffa == true then return true end\n",
       "\tif pvp == true then return true end\n",
       "pvp: free-for-all not counted",
       expect="a passer-by flagged for free-for-all PvP was offered", script=S)

# Cannot tell taken for flagged.
mutate("Queue.lua",
       "\tif pvp == false and ffa == false then return false end\n\treturn nil\nend\n",
       "\tif pvp == false and ffa == false then return false end\n\treturn true\nend\n",
       "pvp: cannot tell holds back",
       expect="a passer-by whose flag cannot be read was held back", script=S)

# A battleground or arena not taken for flagged when your flag is withheld.
mutate("Queue.lua",
       "\tlocal battle = (inside == true or inside == 1) and (kind == \"pvp\" or kind == \"arena\")\n",
       "\tlocal battle = false\n",
       "pvp: a battleground not counted",
       expect="a flagged passer-by was not offered while you are flagged too", script=S)

# Your own flag withheld anywhere taken for flagged.
mutate("Queue.lua",
       "\tif mine == nil or battle then return battle end\n",
       "\tif mine == nil or battle then return true end\n",
       "pvp: your withheld flag taken for flagged",
       expect="your own flag withheld out in the world stood the rule aside", script=S)

# Your flag running out taken for flagged: the rule steps aside just as a buff
# on somebody flagged would start the countdown again (the owner's report).
mutate("Queue.lua",
       "\tif safecall(_G.IsPVPTimerRunning) == true then return false, true end\n",
       "",
       "pvp: a countdown taken for flagged",
       expect="your own flag running out stood the rule aside", script=S)

# The countdown asked inside a battleground too, where everybody is flagged
# and buffing them costs nothing.
mutate("Queue.lua",
       "\tif mine == nil or battle then return battle end\n",
       "\tif mine == nil then return battle end\n",
       "pvp: a countdown in a battleground",
       expect="a flagged passer-by was not offered while you are flagged too", script=S)

# Flagged, and the rule standing all the same, with nothing to say why.
mutate("Queue.lua",
       "\tif pvpScan.countdown then\n",
       "\tif false then\n",
       "pvp: a countdown unsaid",
       expect="does not say your flag running out keeps the rule standing", script=S)

mutate("Queue.lua",
       "\t\tpvpScan.you, pvpScan.countdown = you or nil, countdown or nil\n",
       "\t\tpvpScan.you, pvpScan.countdown = you or nil, nil\n",
       "pvp: a countdown not recorded",
       expect="does not say your flag running out keeps the rule standing", script=S)

mutate("Options/Who.lua",
       ", but not while your own flag is running out.\"],",
       ".\"],",
       "pvp: the tooltip leaves the countdown out",
       expect="the tooltip does not say a flag running out is no exception", script=S)

# ------------------------------------------------ who is named

# Named as held back before the sources are asked, as the check once sat:
# somebody the Passers-by switch or the city rule keeps off anyway is listed
# in /manners debug as though the flag were why.
mutate("Queue.lua",
       "\t\tif seen[full] or rejected[full] then return end\n\n\t\t-- The whole-person block",
       "\t\tif seen[full] or rejected[full] then return end\n"
       "\t\tif pvpHeld and PvPFlag(unit) == true then pvpHeld[full] = true end\n\n\t\t-- The whole-person block",
       "pvp: named before the sources are asked",
       expect="somebody no source would offer is named as held back for PvP", script=S)

# A remembered passer-by let go for the flag and not named.
mutate("Queue.lua",
       "\t\tif flagged then pvpScan.names[name] = true end\n",
       "",
       "pvp: a remembered passer-by let go unnamed",
       expect="a passer-by let go from memory for the flag is not named", script=S)

# ------------------------------------------------ nobody's token

# The owed fallback offers a favour whatever flag the debt keeps.
mutate("Queue.lua",
       "\t\t\t\tif pvpHeld and entry.pvp == true then\n",
       "\t\t\t\tif false then\n",
       "pvp: the owed fallback ignores the flag",
       expect="the owed fallback offered the favour back to somebody last read as flagged", script=S)

# A favour owed to somebody flagged let go rather than kept.
mutate("Queue.lua",
       "\t\t\t\t\trejected[full] = true\n\t\t\t\t\tpvpHeld[full] = true\n",
       "\t\t\t\t\trejected[full] = true\n\t\t\t\t\tpvpHeld[full] = true\n\t\t\t\t\towed[full] = nil\n",
       "pvp: a flagged favour let go",
       expect="the favour owed to somebody flagged was let go", script=S)

# A token's reading not kept on the debt, so the fallback judges on the flag
# read with the favour for good.
mutate("Queue.lua",
       "\t\t\tif owed[full] then owed[full].pvp = flag end\n",
       "",
       "pvp: the debt keeps the favour's reading",
       expect="once a token read the flag gone, the owed fallback still held the favour back", script=S)

# The flag read with the favour not kept, so the fallback offers straight away.
mutate("Favours.lua",
       "\t\t\tguid = seen.guid, class = seen.class, pvp = seen.pvp,\n",
       "\t\t\tguid = seen.guid, class = seen.class,\n",
       "pvp: the favour's flag not filed",
       expect="the owed fallback offered the favour back to somebody last read as flagged", script=S)

# The flag not read with the favour at all.
mutate("Favours.lua",
       "\t\tseen.pvp = ns.PvPFlag(source)\n",
       "",
       "pvp: the favour's flag not read",
       expect="the favour's line does not say returning it waits on the flag", script=S)

# The favour's line saying it is on the prompt when it is not.
mutate("Favours.lua",
       "\t\t\tif reachable and ns.PvPHoldsBack(seen.pvp) then\n",
       "\t\t\tif false then\n",
       "pvp: the favour's line",
       expect="the favour's line does not say returning it waits on the flag", script=S)

# The favour's line promising the return, which a flag lasting longer than
# the favour is kept for mostly makes untrue.
mutate("Favours.lua",
       "so returning it is offered only if their flag drops before the favour runs out\"]",
       "so returning it waits until they are not\"]",
       "pvp: the favour's line promises the return",
       expect="the favour's line promises a return the favour's time may not allow", script=S)

# The favour's line (and the ledger's row) speaking of the flag with the
# setting off or while you are flagged yourself.
mutate("Queue.lua",
       "\treturn flag == true and db ~= nil and PvPRuleStands(db)\n",
       "\treturn flag == true and db ~= nil\n",
       "pvp: the favour's line ignores the rule",
       expect="the favour's line says the flag holds it back with", script=S)

# The ledger's owed row promising a favour the rule holds back.
mutate("Ledger.lua",
       "\tif okPvP and flagged == true then return TEXT.TIP_OWED_PVP end\n",
       "",
       "pvp: the ledger promises a held favour",
       expect="the ledger promises a favour the PvP rule holds back", script=S)

mutate("Ledger.lua",
       "\t\treturn debt ~= nil and ns.PvPHoldsBack(debt.pvp)\n",
       "\t\treturn debt ~= nil and debt.pvp == true\n",
       "pvp: the ledger ignores the rule",
       expect="with the setting off the ledger's row still speaks of the flag", script=S)

# The debt's flag lost on the way out, and on the way back in.
mutate("Queue.lua",
       "\t\t\t\tclass = entry.class,\n\t\t\t\tpvp = entry.pvp == true or nil,\n",
       "\t\t\t\tclass = entry.class,\n",
       "pvp: the flag not saved",
       expect="the flag on a favour owed was not saved with it", script=S)

mutate("Queue.lua",
       "\t\t\t\t\tclass = type(entry.class) == \"string\" and entry.class or nil,\n"
       "\t\t\t\t\tpvp = entry.pvp == true or nil,\n",
       "\t\t\t\t\tclass = type(entry.class) == \"string\" and entry.class or nil,\n",
       "pvp: the flag not restored",
       expect="the flag on a favour owed did not come back after a reload", script=S)

# The memory of a passer-by: the flag ignored, not kept, or never handed over.
mutate("Queue.lua",
       "\t\t\tor flagged\n",
       "",
       "pvp: the memory ignores the flag",
       expect="a passer-by last read as flagged was offered from memory", script=S)

mutate("Queue.lua",
       "\tmemo.pvp = entry.pvp\n",
       "",
       "pvp: the memory forgets the flag",
       expect="a passer-by last read as flagged was offered from memory", script=S)

mutate("Queue.lua",
       "\t\t\tpvp = flag,\n",
       "",
       "pvp: the entry does not carry the flag",
       expect="a passer-by last read as flagged was offered from memory", script=S)

# ------------------------------------------------ a whole party at once

# The group cast offered over a flagged member.
mutate("GroupBuffs.lua",
       "\tif pvp then\n\t\tlocal flagged = FlaggedAmong(bucket.where, byClass, inRaid, memo)\n",
       "\tif false then\n\t\tlocal flagged = FlaggedAmong(bucket.where, byClass, inRaid, memo)\n",
       "pvp: group cast over a flagged member",
       expect="a group cast was offered to a party with a member flagged for PvP", script=S)

# The scan's record never handed to the group casts.
mutate("GroupBuffs.lua",
       "\tlocal pvp = ns.PvPRecord()\n",
       "\tlocal pvp = nil\n",
       "pvp: group casts never told",
       expect="a group cast was offered to a party with a member flagged for PvP", script=S)

# The party walked one short, so its last member is never asked.
mutate("GroupBuffs.lua",
       "\tlocal last = math.min(inRaid and n or (n - 1), 40)\n",
       "\tlocal last = math.min(inRaid and n or (n - 2), 40)\n",
       "pvp: the last party member not asked",
       expect="a group cast was offered to a party with a member flagged for PvP", script=S)

# Every raid subgroup counted, not the target's own.
mutate("GroupBuffs.lua",
       "\t\t\t\tinside = RaidSubgroup(unit, memo) == where\n",
       "\t\t\t\tinside = true\n",
       "pvp: every subgroup counted",
       expect="a raider flagged in another subgroup kept back this subgroup's group cast", script=S)

# Every class counted for a Greater Blessing, not its own.
mutate("GroupBuffs.lua",
       "\t\t\t\tinside = Asked(memo, \"class\", unit, ClassFile) == where\n",
       "\t\t\t\tinside = true\n",
       "pvp: every class counted",
       expect="a flagged mage kept back the warriors' Greater Blessing", script=S)

# A shout offered over a flagged party member.
mutate("Queue.lua",
       "\t\tqueue, held = HoldShoutsForPvP(queue, rejected, inRaid)\n",
       "",
       "pvp: shout over a flagged member",
       expect="Anna was offered a shout that would land on Bert", script=S)

# A raid-wide shout (Mists, retail) asked of your own subgroup alone, so a
# raider flagged in another one is shouted over.
mutate("GroupBuffs.lua",
       "\tif not ns.PARTY_IS_SUBGROUP then return FlaggedAmong(\"raid\", false, true) end\n",
       "",
       "pvp: a raid-wide shout asks your subgroup",
       expect="though it would land on raider8 stone", script=S)

# The whole raid asked for as a subgroup nobody is in.
mutate("GroupBuffs.lua",
       "\t\t\telseif inRaid and where ~= \"raid\" then\n",
       "\t\t\telseif inRaid then\n",
       "pvp: the whole raid never walked",
       expect="though it would land on raider8 stone", script=S)

# A shout for your subgroup (vanilla, Camelot) asking nobody.
mutate("GroupBuffs.lua",
       "\treturn FlaggedAmong(own, false, true)\n",
       "\treturn nil\n",
       "pvp: a subgroup shout asks nobody",
       expect="though it would land on raider3 stone", script=S)

# A raid-wide shout said to be held back for your group.
mutate("Queue.lua",
       "\t\tor ns.PARTY_IS_SUBGROUP and L[\"your group\"] or L[\"your raid\"]\n",
       "\t\tor L[\"your group\"]\n",
       "pvp: a raid-wide shout named for your group",
       expect="does not say why the shout is held back in a raid", script=S)

# ------------------------------------------------ the prompt

# The press on an empty queue follows the panel onto somebody flagged.
mutate("Prompt/Hold.lua",
       "\tif ns.HeldForPvP(entry) then return true end\n",
       "",
       "pvp: retired ignores the flag",
       expect="the press cast at somebody flagged for PvP since the paint", script=S)

# The panel's short hold keeps somebody flagged, and the press follows it.
mutate("Prompt/Hold.lua",
       "\tif ns.HeldForPvP(S.heldEntry) then return false end\n",
       "",
       "pvp: the hold ignores the flag",
       expect="the press cast at somebody flagged for PvP since the paint", script=S)

# The scan's verdicts not consulted by the prompt.
mutate("Queue.lua",
       "\tif pvpScan.names[entry.name] then return true end\n",
       "",
       "pvp: the prompt does not ask the scan",
       expect="the press cast at somebody flagged for PvP since the paint", script=S)

# A group cast on the panel not asked again of its party.
mutate("Queue.lua",
       "\tif entry.groupCast then return ns.GroupCastFlagged(entry) ~= nil end\n",
       "",
       "pvp: a held group cast not asked again",
       expect="the press cast the group spell over a party member flagged for PvP", script=S)

mutate("GroupBuffs.lua",
       "\t\twhere = bucket.where,\n",
       "",
       "pvp: a group cast forgets whom it lands on",
       expect="the press cast the group spell over a party member flagged for PvP", script=S)

# A Greater Blessing on the panel asked again as though it were for a raid
# subgroup, which no class name is: nobody is ever found.
mutate("GroupBuffs.lua",
       "\treturn FlaggedAmong(group.where, group.class ~= nil, plain(IsInRaid and IsInRaid()) == true)\n",
       "\treturn FlaggedAmong(group.where, false, plain(IsInRaid and IsInRaid()) == true)\n",
       "pvp: a held Greater Blessing asked by subgroup",
       expect="the press cast a Greater Blessing over a warrior flagged for PvP", script=S)

# The prompt holding a group cast back for a flagged member while the rule
# stands aside: the setting off, or you flagged yourself.
mutate("Queue.lua",
       "\tif not (entry and entry.name and pvpScan.stands) then return false end\n",
       "\tif not (entry and entry.name) then return false end\n",
       "pvp: the prompt holds back while the rule stands aside",
       expect="the press held the group spell back for a flagged member", script=S)

# A shout on the panel not asked again of the party it lands on.
mutate("Queue.lua",
       "\tif LandsOnParty(entry) then return ns.ShoutFlagged() ~= nil end\n",
       "",
       "pvp: a held shout not asked again",
       expect="the press shouted over a party member flagged for PvP", script=S)

# ------------------------------------------------ the setting

mutate("Core.lua",
       "\t\t\tskipPvP = true,\n",
       "\t\t\tskipPvP = false,\n",
       "pvp: off by default",
       expect="Skip players flagged for PvP is not on by default", script=S)

# With no default it is not a setting the settings text knows.
mutate("Core.lua",
       "\t\t\tskipPvP = true,\n",
       "",
       "pvp: no default",
       expect="the settings text leaves the switch out", script=S)

mutate("Core.lua",
       "\tboolean(profile.filters, \"skipPvP\", true)\n",
       "",
       "pvp: not repaired",
       expect="a saved skipPvP of yes came back as", script=S)

mutate("Options/Who.lua",
       "own flag is running out.\"],\n\t\t\t\torder = 43,\n",
       "own flag is running out.\"],\n\t\t\t\torder = 53,\n",
       "pvp: the switch out of place",
       expect="the switch is not under Who to skip", script=S)

# ------------------------------------------------ saying so

mutate("Commands.lua",
       "\t\tfor _, line in ipairs(ns.PvPLines()) do self:Print(\"  \" .. line) end\n",
       "",
       "pvp: /manners debug silent",
       expect="/manners debug does not say who is held back for PvP", script=S)

mutate("Options/Diagnostics.lua",
       "\t\t\t\thidden = function() return #ns.PvPLines(true) == 0 end,\n",
       "\t\t\t\thidden = function() return true end,\n",
       "pvp: Diagnostics silent",
       expect="Diagnostics does not say who is held back for PvP", script=S)

mutate("Queue.lua",
       "\t\tif i > 5 then\n",
       "\t\tif i > 50 then\n",
       "pvp: every name listed",
       expect="seven held back are not five by name and a count", script=S)

mutate("Queue.lua",
       "\tif pvpScan.you then\n",
       "\tif false then\n",
       "pvp: standing aside unsaid",
       expect="/manners debug does not say the rule stands aside while you are flagged", script=S)
