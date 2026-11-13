# Mutations for a favour that is not returned with a buff its giver already
# wears (filters.repayCovered; Core.lua Fresh, Covered and PickBuffFor's third
# value, Queue.lua's spareCovered and LetGoCovered, Favours.lua CoveredAlready,
# Ledger.lua's "covered", the switch on When to offer and the lines that said
# "always"). Each is caught by the scenario in tests/scenarios/covered.lua that
# names it.

S = "runscenarios.py"
P = "covered: "

ARRIVES = P + "Forever: a favour from somebody wearing your buff from another caster is let go, not owed"
ARRIVES_RETAIL = P + "retail: a favour from somebody wearing your buff from another caster is let go, not owed"
SCAN = P + "Forever: a favour owed is let go by the scan that reads them covered"
SCAN_RETAIL = P + "retail: a favour owed is let go by the scan that reads them covered"
QUIET = P + "Forever: a favour let go with no line said about it says nothing"
LEAD = P + "Forever: somebody owed whose buff is under the top-up lead is offered a top-up"
SWITCH = P + "Forever: with the switch on, the buff they wear is offered again to return the favour"
SWITCH_RETAIL = P + "retail: with the switch on, the buff they wear is offered again to return the favour"
ALWAYS = P + "Forever: with Always offer nobody is read, so nothing is let go"
PRESSED = P + "Forever: a buff pressed a moment ago is not read as covered"
KEPT = P + "Forever: a reading kept from before a fight lets no favour go"
PAGE = P + "the switch is on When to offer, off by default, repaired and reset"
WORDS = P + "the pages say a favour is always returned only with the switch on"
CHECKUP = P + "the full check-up names the switch when it is on, and only then"
PALADIN = P + "vanilla: a paladin lets go a favour whose giver wears "
RUNS_OUT = P + "vanilla: a paladin still returns a favour with a blessing about to run out"
WAITS = P + "vanilla: a paladin's favour waits for "
STRONGER = P + "vanilla: a favour waits for a stronger rank about to run out, and goes under one with time to spare"

# ------------------------------------------------------------- Core.lua
# Only a copy known to be yours is spared, as before the change.
mutate("Core.lua",
       "\t\tif opts.spareCovered then\n\t\t\treturn type(remaining) == \"number\" and remaining > (ns.LeadFor(opts, Length(buff, seconds)))\n",
       "\t\tif false then\n\t\t\treturn type(remaining) == \"number\" and remaining > (ns.LeadFor(opts, Length(buff, seconds)))\n",
       "covered: another caster's copy is refreshed for a favour",
       expect=SCAN, script=S)

# A buff about to run out read as covered.
mutate("Core.lua",
       "\t\t\treturn type(remaining) == \"number\" and remaining > (ns.LeadFor(opts, Length(buff, seconds)))\n",
       "\t\t\treturn type(remaining) == \"number\"\n",
       "covered: a buff about to run out is read as covered",
       expect=LEAD, script=S)

# A buff waiting out a press read as covered.
mutate("Core.lua",
       "\t\t\t\tif Blocked(opts, buff) then return false end\n\t\t\t\tlocal held, remaining, mine, _, seconds = has(buff, opts)\n",
       "\t\t\t\tlocal held, remaining, mine, _, seconds = has(buff, opts)\n",
       "covered: a buff on its cooldown is read as covered",
       expect=PRESSED, script=S)

# A stronger rank about to run out read as covering them.
mutate("Core.lua",
       "\t\t\t\tif held ~= true or not Fresh(opts, mine, remaining, buff, seconds) then return false end\n",
       "\t\t\t\tif held ~= true then return false end\n",
       "covered: a stronger rank about to run out lets the favour go",
       expect=STRONGER, script=S)

# The walk never says they are covered.
mutate("Core.lua",
       "\t\tif opts.spareCovered then return nil, true, Covered(candidates, opts, has) end\n",
       "",
       "covered: the walk never says a favour's giver is covered",
       expect=SCAN, script=S)

# A paladin's walk: his own blessing (or nobody's) on them with time to spare.
OWN = "\t\t\t\t\t\tif opts.spareCovered and Fresh(opts, mine, remaining, buff, seconds) then return nil, true, true end\n"
mutate("Core.lua", OWN, "",
       "covered: a paladin's favour waits behind a blessing nobody is named for",
       expect=PALADIN + "a Might nobody the client names cast", script=S)

# ...a stronger rank of it, with time to spare.
mutate("Core.lua", OWN,
       "\t\t\t\t\t\tif opts.spareCovered and not over and Fresh(opts, mine, remaining, buff, seconds) then return nil, true, true end\n",
       "covered: a paladin's favour waits behind a stronger blessing nobody is named for",
       expect=PALADIN + "a stronger Might nobody the client names cast", script=S)

# ...and a stronger rank about to run out read as covering them.
mutate("Core.lua", OWN,
       "\t\t\t\t\t\tif opts.spareCovered and (over or Fresh(opts, mine, remaining, buff, seconds)) then return nil, true, true end\n",
       "covered: a stronger blessing about to run out lets a paladin's favour go",
       expect=WAITS + "nobody's stronger blessing about to run out", script=S)

# ...another paladin's, with time to spare, refreshed all the same.
THEIRS = "\t\t\t\t\t\t\telseif opts.spareCovered and Fresh(opts, mine, remaining, buff, seconds) then\n"
mutate("Core.lua", THEIRS,
       "\t\t\t\t\t\t\telseif false then\n",
       "covered: a paladin refreshes another paladin's blessing for a favour",
       expect=PALADIN + "another paladin's Might, the only blessing you know", script=S)

# ...another paladin's stronger rank not read as covering them.
mutate("Core.lua", THEIRS,
       "\t\t\t\t\t\t\telseif opts.spareCovered and not over and Fresh(opts, mine, remaining, buff, seconds) then\n",
       "covered: a paladin's favour waits behind another paladin's stronger blessing",
       expect=PALADIN + "another paladin's stronger Might", script=S)

# ...and their stronger rank about to run out read as covering them.
mutate("Core.lua", THEIRS,
       "\t\t\t\t\t\t\telseif opts.spareCovered and (over or Fresh(opts, mine, remaining, buff, seconds)) then\n",
       "covered: another paladin's stronger blessing about to run out lets the favour go",
       expect=WAITS + "another paladin's stronger blessing about to run out", script=S)

# ...and the walk's end never says so.
mutate("Core.lua",
       "\t\t\tif not pick and spared then return nil, true, true end\n",
       "",
       "covered: a paladin's walk never says a favour's giver is covered",
       expect=PALADIN + "another paladin's Might, the only blessing you know", script=S)

# A blessing about to run out read as covering them.
mutate("Core.lua",
       "\t\t\t\t\t\t\telseif not theirs and not over then\n\t\t\t\t\t\t\t\ttheirs = buff\n",
       "\t\t\t\t\t\t\telseif not theirs and not over and not opts.spareCovered then\n\t\t\t\t\t\t\t\ttheirs = buff\n",
       "covered: a paladin's favour is not returned with a blessing about to run out",
       expect=RUNS_OUT, script=S)

# The switch is on by default.
mutate("Core.lua",
       "\t\t\trepayCovered = false,\n",
       "\t\t\trepayCovered = true,\n",
       "covered: the refresh is on by default",
       expect=PAGE, script=S)

# ------------------------------------------------------------- Queue.lua
# The switch is never read by the scan.
mutate("Queue.lua",
       "\t\topts.spareCovered = isOwed and checked and f.repayCovered ~= true or nil\n",
       "\t\topts.spareCovered = isOwed and checked or nil\n",
       "covered: the scan spares a covered favour with the switch on",
       expect=SWITCH, script=S)

mutate("Queue.lua",
       "\t\topts.spareCovered = isOwed and checked and f.repayCovered ~= true or nil\n",
       "\t\topts.spareCovered = nil\n",
       "covered: the scan refreshes a covered favour",
       expect=SCAN_RETAIL, script=S)

# The debt is never marked for letting go.
mutate("Queue.lua",
       "\t\t\tif remaining == true and isOwed then owed[full].covered = guid or true end\n",
       "",
       "covered: a covered favour is left owed with nothing on the prompt",
       expect=SCAN, script=S)

# ...or never let go after the walk.
mutate("Queue.lua",
       "\tif f.repayCovered ~= true and next(owed) ~= nil then LetGoCovered(db, candidates) end\n",
       "",
       "covered: the favours read as covered are never let go",
       expect=SCAN_RETAIL, script=S)

# Let go on a reading kept from before a fight.
mutate("Queue.lua",
       "\t\t\t\t\tif ns.ReadingSource(guid, candidates[i].key) == \"kept\" then\n",
       "\t\t\t\t\tif false then\n",
       "covered: the scan lets a favour go on a kept reading",
       expect=KEPT, script=S)

# The ledger is told the time ran out.
mutate("Queue.lua",
       "\t\tTellLedger(\"LetGo\", name, \"covered\")\n\t\tns.Trail(",
       "\t\tTellLedger(\"LetGo\", name)\n\t\tns.Trail(",
       "covered: the scan's let-go reads as time run out",
       expect=SCAN, script=S)

# The line said for a favour nothing was ever said of.
mutate("Queue.lua",
       "\t\tif said and db.verbose then\n",
       "\t\tif db.verbose then\n",
       "covered: the let-go line follows no line about the favour",
       expect=QUIET, script=S)

# ...and with chat lines off.
mutate("Queue.lua",
       "\t\tif said and db.verbose then\n",
       "\t\tif said then\n",
       "covered: the let-go line is said with chat lines off",
       expect=QUIET, script=S)

# The saved file keeps the favour let go.
mutate("Queue.lua",
       "\t\t\taddon:Print(L[\"|cff80ff80%s already has your buff|r -- nothing to return, so the favour is let go\"]:format(name))\n\t\tend\n\tend\n\tSaveDebts()\n",
       "\t\t\taddon:Print(L[\"|cff80ff80%s already has your buff|r -- nothing to return, so the favour is let go\"]:format(name))\n\t\tend\n\tend\n",
       "covered: a favour let go stays in the saved file",
       expect=SCAN, script=S)

# ------------------------------------------------------------- Favours.lua
# Nobody is read as the favour arrives.
mutate("Favours.lua",
       "\t\tif not owed[seen.name] and CoveredAlready(db, seen, hasMana, inParty, inGroup) then\n",
       "\t\tif false then\n",
       "covered: a covered favour is announced as on the prompt",
       expect=ARRIVES, script=S)

# The switch is not asked as the favour arrives.
mutate("Favours.lua",
       "\t\tif f.repayCovered == true or whenBuffed == \"always\" then return false end\n",
       "\t\tif whenBuffed == \"always\" then return false end\n",
       "covered: a favour is let go on arrival with the switch on",
       expect=SWITCH_RETAIL, script=S)

# Read on arrival though nobody's buffs are read.
mutate("Favours.lua",
       "\t\tif f.repayCovered == true or whenBuffed == \"always\" then return false end\n",
       "\t\tif f.repayCovered == true then return false end\n",
       "covered: a favour is let go on arrival under Always offer",
       expect=ALWAYS, script=S)

# Let go on arrival on a reading kept from before a fight.
mutate("Favours.lua",
       "\t\t\tif ns.ReadingSource(guid, candidates[i].key) == \"kept\" then return false end\n",
       "",
       "covered: a favour is let go on arrival on a kept reading",
       expect=KEPT, script=S)

# The ledger is told the time ran out.
mutate("Favours.lua",
       "\t\t\tTellLedger(\"LetGo\", seen.name, \"covered\")\n",
       "\t\t\tTellLedger(\"LetGo\", seen.name)\n",
       "covered: the arrival's let-go reads as time run out",
       expect=ARRIVES_RETAIL, script=S)

# The debt forgets that a line was said about it.
mutate("Favours.lua",
       "\t\tif speak then owed[seen.name].said = true end\n",
       "",
       "covered: the scan's let-go says nothing after the buffed-you line",
       expect=SCAN, script=S)

# ------------------------------------------------------------- Ledger.lua
# The reason is not one the ledger knows.
mutate("Ledger.lua",
       "WHY.covered = true\n",
       "",
       "covered: the ledger reads the reason as time run out",
       expect=ARRIVES, script=S)

# Today's count scores it against you.
mutate("Ledger.lua",
       "\tif why == \"covered\" and s.today and s.today.day == StartOfToday(e.at) then\n",
       "\tif false then\n",
       "covered: today's count scores a covered favour as unreturned",
       expect=SCAN, script=S)

mutate("Ledger.lua",
       "\t\t\telseif e.kind == \"received\" and e.why == \"covered\" then\n",
       "\t\t\telseif false then\n",
       "covered: the list scores a covered favour as unreturned",
       expect=ARRIVES, script=S)

# The row says the time ran out.
mutate("Ledger.lua",
       "\t\tor e.why == \"covered\" and TEXT.LETGO_COVERED or TEXT.LETGO_EXPIRED\n",
       "\t\tor TEXT.LETGO_EXPIRED\n",
       "covered: the ledger's row says the time ran out",
       expect=ARRIVES, script=S)

mutate("Ledger.lua",
       "\t\t\t\tor e.why == \"covered\" and TEXT.TIP_LETGO_COVERED or TEXT.TIP_LETGO_EXPIRED,\n",
       "\t\t\t\tor TEXT.TIP_LETGO_EXPIRED,\n",
       "covered: the ledger's tooltip says the time ran out",
       expect=ARRIVES, script=S)

# The tooltip names a setting that is not there.
mutate("Ledger.lua",
       ":format(L[\"Refresh a buff they already have, to return a favour\"], L[\"When to offer\"], L[\"Buffing back\"])",
       ":format(L[\"Refresh what they already have\"], L[\"When to offer\"], L[\"Buffing back\"])",
       "covered: the ledger's tooltip names a missing setting",
       expect=ARRIVES, script=S)

# ------------------------------------------------------------- the options
mutate("Options/Advanced.lua",
       "\t\t\"filters.restoreTarget\",\n\t\t\"filters.repayCovered\",\n",
       "\t\t\"filters.restoreTarget\",\n",
       "covered: When to offer's reset leaves the switch",
       expect="model: the reset puts when back", script=S)

mutate("Options/Advanced.lua",
       "\t\"prompt.reasonRefresh\", \"prompt.reasonUnknown\",\n\t\"filters.repayCovered\",\n",
       "\t\"prompt.reasonRefresh\", \"prompt.reasonUnknown\",\n",
       "covered: the old dialog's reset leaves the switch",
       expect="model: the reset puts advanced back", script=S)

mutate("Options/Advanced.lua",
       "\t\t\t\torder = 11.5,\n\t\t\t\twidth = \"full\",\n\t\t\t\thidden = NoOthers,\n\t\t\t\tdisabled = function() return not S().owed end,\n",
       "\t\t\t\torder = 11.5,\n\t\t\t\twidth = \"full\",\n\t\t\t\thidden = NoOthers,\n",
       "covered: the switch is live with People who buff me off",
       expect=PAGE, script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t\"advanced.repayCovered\",\n",
       "",
       "covered: the switch is not placed on the page",
       expect="advanced: drawn on When to offer and Look as laid out", script=S)

mutate("Options/Diagnostics.lua",
       "\tif db.filters.repayCovered == true then lines[#lines + 1] = \"repayCovered=on\" end\n",
       "",
       "covered: the full check-up leaves the switch out",
       expect=CHECKUP, script=S)

mutate("Options/Diagnostics.lua",
       "\tif db.filters.repayCovered == true then lines[#lines + 1] = \"repayCovered=on\" end\n",
       "\tlines[#lines + 1] = \"repayCovered=\" .. (db.filters.repayCovered == true and \"on\" or \"off\")\n",
       "covered: the full check-up names the switch at its default",
       expect=CHECKUP, script=S)

# "Always", said whatever the switch says.
mutate("Options/When.lua",
       "\t\t\t\t\tif F().repayCovered ~= true then\n",
       "\t\t\t\t\tif false then\n",
       "covered: If they already have it says always with the switch off",
       expect=WORDS, script=S)

mutate("Options/When.lua",
       "\t\t\t\t\tif F().repayCovered ~= true then\n",
       "\t\t\t\t\tif true then\n",
       "covered: If they already have it never says always",
       expect=WORDS, script=S)

mutate("Options/Start.lua",
       "\t\tif s.owed and f.repayCovered ~= true then text",
       "\t\tif s.owed then text",
       "covered: Start here says both of a favour with the switch on",
       expect=WORDS, script=S)
