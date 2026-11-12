# Mutations for a buff back that is not a favour owed (Favours.lua
# BuffedBack and OweFavour, Queue.lua ns.GaveLately, Ledger.lua's "back"
# rows). Each is caught by the scenario in tests/scenarios/buffback.lua that
# names it.

S = "runscenarios.py"

# ------------------------------------------------ the favour
mutate("Favours.lua",
       "\t\tif not owed[seen.name] and BuffedBack(db, seen) then\n",
       "\t\tif false then\n",
       "buffback: a buff back filed as owed",
       expect="buffback: Forever: a passer-by you buffed first buffs you back a minute later and is not owed", script=S)

mutate("Favours.lua",
       "\t\tif ns.GaveLately(seen.name, now, leadOf) then return true end\n",
       "",
       "buffback: Manners' own note not asked",
       expect="buffback: Forever: Manners' own note of the cast answers when her auras cannot be read", script=S)

mutate("Favours.lua",
       "\t\t\tif has == true and mine == true and type(remaining) == \"number\"\n",
       "\t\t\tif has == true and mine ~= nil and type(remaining) == \"number\"\n",
       "buffback: another caster's buff taken for yours",
       expect="buffback: retail: somebody wearing another mage's Intellect is owed", script=S)

mutate("Favours.lua",
       "\t\t\tif has == true and mine == true and type(remaining) == \"number\"\n",
       "\t\t\tif false\n",
       "buffback: the caster the client names never read",
       expect="buffback: retail: somebody wearing yours, the client naming you, buffs you back and is not owed", script=S)

mutate("Favours.lua",
       "\t\t\t\tand remaining > leadOf(seconds or (ns.BuffSeconds(buff))) then\n",
       "\t\t\t\tthen\n",
       "buffback: yours about to run out taken for a return",
       expect="buffback: retail: somebody whose copy of yours is about to run out is owed", script=S)

mutate("Queue.lua",
       "\t\t\tif length > 0 and at + length - leadOf(length) > now then return key end\n",
       "\t\t\tif length > 0 and at + length > now then return key end\n",
       "buffback: Manners' note ignores the lead",
       expect="buffback: Forever: somebody whose copy of yours is about to run out is owed", script=S)

mutate("Favours.lua",
       "\t\tlocal unit = ns.UnitFor(seen.name, seen.unit)\n\t\tif not unit then return false end\n",
       "\t\tlocal unit = nil\n\t\tif not unit then return false end\n",
       "buffback: her aura never read",
       expect="buffback: retail: somebody wearing yours, the client naming you, buffs you back and is not owed", script=S)

# A favour returned noted as a gift: a buff from them right after is taken
# for a buff back, and the ledger's refusal fixture loses its second favour.
mutate("Clicks.lua",
       "\tif not unheard then ns.NoteGave(pending.name, pending.buffKey, not wasOwed) end\n",
       "\tif not unheard then ns.NoteGave(pending.name, pending.buffKey, true) end\n",
       "buffback: a favour returned noted as a gift",
       expect="hunt3 ledger: a refusal after a second buff leaves one owed row", script=S)

mutate("Queue.lua",
       "\t\telseif gifts then\n\t\t\tgifts[buffKey] = nil\n",
       "\t\telseif false then\n\t\t\tgifts[buffKey] = nil\n",
       "buffback: a return keeps the gift before it",
       expect="buffback: Forever: a buff after you returned their favour is a new favour", script=S)

# ------------------------------------------------ the ledger
mutate("Ledger.lua",
       "\tif back then\n\t\t-- A priest's three buffs back",
       "\tif false then\n\t\t-- A priest's three buffs back",
       "buffback: the ledger files a buff back as a favour",
       expect="the ledger row reads", script=S)

mutate("Ledger.lua",
       "\telseif e.state == \"back\" then\n\t\treturn TEXT.STATE_BACK, spells, COLOUR.back\n",
       "",
       "buffback: the ledger's badge for a buff back",
       expect="the ledger's badge reads", script=S)

mutate("Ledger.lua",
       "\t\telseif e.state == \"back\" then\n\t\t\tGameTooltip:AddLine(TEXT.TIP_BACK, c[1], c[2], c[3], true)\n",
       "",
       "buffback: the row's tooltip for a buff back",
       expect="the row's tooltip says", script=S)

mutate("Ledger.lua",
       "local STATES = { owed = true, returned = true, letgo = true, back = true }\n",
       "local STATES = { owed = true, returned = true, letgo = true }\n",
       "buffback: a saved buff back read as let go",
       expect="the ledger reads a buff back saved and loaded again as", script=S)

mutate("Ledger.lua",
       "\t\t\telseif e.kind == \"received\" and e.state == \"back\" then\n",
       "\t\t\telseif false then\n",
       "buffback: a buff back scored as a favour received",
       expect="the ledger counts the buff back as a favour", script=S)

# ------------------------------------------------ the line
mutate("Favours.lua",
       "\t\t\t\taddon:Print(L[\"|cff80ff80%s buffed you back|r",
       "\t\t\t\tlocal _ = (L[\"|cff80ff80%s buffed you back|r",
       "buffback: nothing said of the buff back",
       expect="nothing said the buff was a buff back", script=S)
