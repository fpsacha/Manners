# Mutations for round 22's fixes outside the options window: Salvation read on
# somebody it cannot be cast on (Core.lua), a favour from another raid group to
# a Salvation-only paladin (Favours.lua, Ledger.lua), the PvP hold counting
# raiders a group spell cannot reach (GroupBuffs.lua), Luxe on a light panel
# (Looks/Luxe.lua, Prompt/Text.lua), the pleases and punctuation of other
# languages (Requests.lua), Toast's keycap, the preview's count, the ledger's
# group cast line, a silent press holding the line (Clicks.lua, Queue.lua) and
# a shout's thank-you beyond 20 yards (Core.lua, Prompt/Macro.lua). Each undoes
# a fix and is caught by the scenario in tests/scenarios/hunt22-core.lua (or
# readable-luxe.lua) it names.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# ------------------------------------------------------------ Salvation
# Salvation read only where it can be cast: yours on a passer-by goes unseen
# and the walk offers Wisdom over it.
mutate("Core.lua",
       "\t\t\t\tif castable or buff.groupOnly then\n",
       "\t\t\t\tif castable then\n",
       "hunt22-core: Salvation unread outside the group",
       expect="core22: a passer-by wearing your Blessing of Salvation is offered nothing", script=S)

# Yours on them, owed: the debt repaid with a Salvation the game refuses.
mutate("Core.lua",
       "\t\t\t\t\t\tif skipped or not castable or Blocked(opts, buff) then return nil, true end\n",
       "\t\t\t\t\t\tif skipped or Blocked(opts, buff) then return nil, true end\n",
       "hunt22-core: a debt repaid with Salvation outside the group",
       expect="core22: a passer-by wearing your Salvation, and owed is offered nothing", script=S)

# Another paladin's Salvation kept as the debt's fallback, on a stranger.
mutate("Core.lua",
       "\t\t\t\t\t\tif castable and not skipped then\n",
       "\t\t\t\t\t\tif not skipped then\n",
       "hunt22-core: another paladin's Salvation offered to a stranger",
       expect="core22: a passer-by wearing another paladin's Salvation, owed, Salvation pinned", script=S)

# A Salvation the stranger lacks picked, now that it is read.
mutate("Core.lua",
       "\t\t\t\t\telseif castable and not skipped then\n",
       "\t\t\t\t\telseif not skipped then\n",
       "hunt22-core: a missing Salvation picked for a stranger",
       expect="core22: a passer-by wearing nothing, owed, Salvation pinned", script=S)

# ------------------------------------------------------------ the favour
# (The favour's reach judged as a shout's, in your own subgroup or nowhere, and
# the line blind to the raid, went with the line: nothing is said about a
# favour in a raid group, Favours.lua QuietHere. The scenario still checks
# the prompt offers them.)

# The ledger row's lines chosen by the shout's subgroup rule again.
mutate("Ledger.lua",
       "\tif ns.GroupMeansSubgroup() then return \"SUBGROUP\" end\n",
       "\tif ns.PARTY_IS_SUBGROUP then return \"SUBGROUP\" end\n",
       "hunt22-core: a Salvation row says subgroup",
       expect="the row says Salvation reaches only your own subgroup", script=S)

# ...and Salvation's own wording dropped for the party's.
mutate("Ledger.lua",
       "\t\tif buff.groupOnly and not buff.partyOnly then return \"GROUP\" end\n",
       "",
       "hunt22-core: a Salvation row says party only",
       expect="the row does not say Salvation reaches your party or raid", script=S)

# ------------------------------------------------------------ the PvP hold
mutate("GroupBuffs.lua",
       "\tif plain(UnitIsVisible and UnitIsVisible(unit)) == false then return false end\n",
       "",
       "hunt22-core: a flagged raider out of sight holds the cast",
       expect="core22: a flagged raider out of sight does not hold the raid's group cast", script=S)

mutate("GroupBuffs.lua",
       "\tif plain(UnitIsDeadOrGhost(unit)) == true then\n",
       "\tif false then\n",
       "hunt22-core: a flagged raider lying dead holds the cast",
       expect="core22: a flagged raider dead does not hold the raid's group cast", script=S)

mutate("GroupBuffs.lua",
       "\t\treturn plain(feigning(unit)) ~= false\n",
       "\t\treturn false\n",
       "hunt22-core: a feigning hunter counted dead",
       expect="core22: a flagged raider a hunter feigning death holds the raid's group cast", script=S)

mutate("GroupBuffs.lua",
       "\tif plain(UnitIsVisible and UnitIsVisible(unit)) == false then return false end\n",
       "\tif plain(UnitIsVisible and UnitIsVisible(unit)) ~= true then return false end\n",
       "hunt22-core: an unread visibility counted out of sight",
       expect="core22: a flagged raider somebody whose visibility the client will not give holds", script=S)

mutate("GroupBuffs.lua",
       "\t\t\tif inside and Asked(memo, \"flag\", unit, Flag) == true and Reached(unit) then\n",
       "\t\t\tif inside and Asked(memo, \"flag\", unit, Flag) == true then\n",
       "hunt22-core: the PvP hold asks nobody's reach",
       expect="core22: a flagged raider dead does not hold the raid's group cast", script=S)

# ------------------------------------------------------------ Luxe on a light panel
# The tag's words held to the panel again: dark on the tag's dark fill.
mutate("Looks/Luxe.lua",
       "\tif kit.ink.light then tr, tg, tb = kit.Legible(tr, tg, tb, 4.5) end\n",
       "\ttr, tg, tb = kit.Legible(tr, tg, tb, 4.5)\n",
       "hunt22-core: Luxe's tag words held to a light panel",
       expect="Luxe's tag and count keep their own ground on a light panel", script=S)

# ...and the count on its chip.
mutate("Looks/Luxe.lua",
       "\tkit.count:SetTextColor(0.80, 0.81, 0.86, 1)\n",
       "\tkit.count:SetTextColor(kit.Legible(0.80, 0.81, 0.86, 4.5))\n",
       "hunt22-core: Luxe's count held to a light panel",
       expect="the count reads", script=S)

# ...and the colour codes the lines bring, taken dark for the panel.
mutate("Looks/Luxe.lua",
       "\tsubOnDark = true,\n",
       "",
       "hunt22-core: Luxe's tag codes taken dark",
       expect="a reason line in |cffb0b0b0", script=S)

# ------------------------------------------------------------ chat
mutate("Requests.lua",
       "\t\t\tif Mark(words, phrase, covered) then pleased = true end\n",
       "",
       "hunt22-core: por favor is no please",
       expect="core22: a request in esES with its own please and punctuation is heard", script=S)

mutate("Requests.lua",
       "\t\tlocal split = text:gsub(\"\\194[\\161\\171\\187\\191]\", \" \"):gsub(",
       "\t\tlocal split = text:gsub(\"\\194[\\171\\187]\", \" \"):gsub(",
       "hunt22-core: inverted marks stick to the word",
       expect="core22: a request in enUS with its own please and punctuation is heard", script=S)

mutate("Requests.lua",
       ":gsub(\"\\226\\128[\\147\\148\\156\\157\\166]\", \" \")\n",
       ":gsub(\"\\226\\128[\\156\\157]\", \" \")\n",
       "hunt22-core: the ellipsis and dashes stick to the word",
       expect="core22: a request in enUS with its own please and punctuation is heard", script=S)

mutate("Requests.lua",
       ":gsub(\"\\239\\188[\\129\\140\\159]\", \" \")",
       ":gsub(\"\\239\\188[\\140]\", \" \")",
       "hunt22-core: the full-width question mark sticks",
       expect="core22: a request in enUS with its own please and punctuation is heard", script=S)

mutate("Requests.lua",
       ":gsub(\"\\227\\128[\\129\\130]\", \" \")\n",
       "\n",
       "hunt22-core: the ideographic full stop sticks",
       expect="core22: a request in enUS with its own please and punctuation is heard", script=S)

mutate("Requests.lua",
       "\t\t\t:gsub(\"\\226\\128[\\152\\153]\", \"'\")\n",
       "\t\t\t:gsub(\"\\226\\128[\\152\\153]\", \" \")\n",
       "hunt22-core: a curly apostrophe splits s'il",
       expect="core22: a request in frFR with its own please and punctuation is heard", script=S)

# The Chinese cap counted per word once a comma splits the sentence.
mutate("Requests.lua",
       "\t\tfor run in lowered:gmatch(\"[A-Za-z0-9\\128-\\255']+\") do\n",
       "\t\tfor _, run in ipairs(words) do\n",
       "hunt22-core: a Chinese sentence capped per clause",
       expect="core22: a request in zhCN with its own please and punctuation is heard", script=S)

# ------------------------------------------------------------ Toast's keycap
mutate("Looks/Toast.lua",
       "\tif not (self.kit.button:GetAttribute(\"type1\") or (ns.Prompt and ns.Prompt:InTest())) then return nil end\n",
       "\tif not (ns.db and ns.db.profile.prompt.locked) then return nil end\n",
       "hunt22-core: Toast's keycap follows the lock",
       expect="core22: Toast shows its keycap only where a press casts", script=S)

# ------------------------------------------------------------ the preview's count
mutate("Prompt/Refresh.lua",
       "\t\tself:Paint(TestEntry(), math.max(2, #mock))\n",
       "\t\tself:Paint(TestEntry(), 2)\n",
       "hunt22-core: the preview counts two over five rows",
       expect="core22: the preview's count covers its 5 listed rows", script=S)

# ------------------------------------------------------------ the ledger's group cast
mutate("Ledger.lua",
       "\tTIP_GAVE_COVERED = L[\"One cast gave it to %d who needed it, and counts as one buff given.\"],\n",
       "\tTIP_GAVE_COVERED = L[\"One cast gave it to %d who needed it in their party or class, and counts as one buff given.\"],\n",
       "hunt22-core: a raid's cast said to reach a party or class",
       expect="core22: a raid's group cast in the ledger names no party or class", script=S)

# ------------------------------------------------------------ a silent press
mutate("Queue.lua",
       "\t\tlocal hold = spoke ~= false or (not quietOnly and not OneOf(why, RECHECKED))\n",
       "\t\tlocal hold = spoke ~= false or not OneOf(why, RECHECKED)\n",
       "hunt22-core: a silent unanswered press holds the line",
       expect="core22: a silent press where nothing answers it leaves the next press its line", script=S)

mutate("Clicks.lua",
       "\t-- here says the game refused them.\n\tns.NoteRefusal(pending.name, nil, true, pending.spoke)\n",
       "\t-- here says the game refused them.\n\tns.NoteRefusal(pending.name, nil, true)\n",
       "hunt22-core: the expiry blind to a silent press",
       expect="core22: a silent press where nothing answers it leaves the next press its line", script=S)

mutate("Clicks.lua",
       "\t\t-- since the game refused nobody.\n\t\tns.NoteRefusal(pending.name, nil, true, pending.spoke)\n",
       "\t\t-- since the game refused nobody.\n\t\tns.NoteRefusal(pending.name, nil, true)\n",
       "hunt22-core: the settle blind to a silent press",
       expect="core22: a silent press where it went to somebody else leaves the next press its line", script=S)

# ------------------------------------------------------------ a shout's line
mutate("Prompt/Macro.lua",
       "\t\tand not (entry.buff.selfCast and ns.ShoutSure(entry.unit) ~= true)\n",
       "\n",
       "hunt22-core: a shout armed with its line at 25 yards",
       expect="core22: a shout at 25 yards leaves out the thank-you", script=S)

mutate("Core.lua",
       "\t\tlocal trade = plain(_G.CheckInteractDistance(unit, 2))\n",
       "\t\tlocal trade = plain(_G.CheckInteractDistance(unit, 4))\n",
       "hunt22-core: a shout sure out to the follow prompt",
       expect="core22: a shout at 25 yards leaves out the thank-you", script=S)

mutate("Core.lua",
       "\t\tif type(maxRange) == \"number\" and maxRange <= 20 then return true end\n",
       "\t\tif type(maxRange) == \"number\" and maxRange <= 30 then return true end\n",
       "hunt22-core: a shout sure within 30 yards",
       expect="core22: a shout at 25 yards leaves out the thank-you (LibRangeCheck)", script=S)

mutate("Core.lua",
       "\t\tlocal _, maxRange = safecall(lib.GetRange, lib, unit)\n"
       "\t\tif type(maxRange) == \"number\" and maxRange <= 20 then return true end\n"
       "\tend\n"
       "\treturn false\n",
       "\tend\n"
       "\treturn false\n",
       "hunt22-core: a shout's line blind to LibRangeCheck",
       expect="core22: a shout at 15 yards carries the thank-you (LibRangeCheck)", script=S)
