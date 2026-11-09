# Mutations for tests/scenarios/engine-fixes38.lua (bug hunt 38, engine): each
# puts back one fault the round fixed, and the scenario of that name has to
# catch it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"
P = "engine-fix38: "

# S1: the combat log's record of a favour asks nobody whether they tank.
mutate("Favours.lua",
       "\t\tif seen.tank == nil then seen.tank = inGroup and ns.IsTankUnit(seen.name) or false end\n",
       "",
       "engine-fix38: the log's favour record has no tank flag",
       expect=P + "tbc: the tank's favour read off the combat log is owed", script=S)

# S2: a loose word inside another buff's whole name asks for its own buff too.
mutate("Requests.lua",
       "\t\t\tif not alone then found[key] = nil end\n",
       "\t\t\tif false then found[key] = nil end\n",
       "engine-fix38: beacon of faith asks for Beacon of Light",
       expect=P + "beacon of faith pls is no ask for Beacon of Light", script=S)

# S3: a Mists scroll reads as up under a flask alone, and is offered over an elixir.
mutate("Buffs.lua",
       "\t\t\t\t\tfor _, spell in ipairs(elixir and elixir.spells or {}) do\n",
       "\t\t\t\t\tfor _, spell in ipairs({}) do\n",
       "engine-fix38: a Mists scroll offered over an elixir",
       expect=P + "mists: no scroll of agility over an elixir", script=S)

# S4: the favour's line asks only whether the queue could ever offer it, not
# whether it offers it while yours is on somebody else.
mutate("Favours.lua",
       "\t\t\tif not ns.CouldOffer(hasMana, inParty, inGroup, seen.tank, seen.class, seen.name) then\n",
       "\t\t\tif false then\n",
       "engine-fix38: the favour's line ignores who wears yours",
       expect=P + "the favour's line does not promise the prompt while your Earth Shield is on another", script=S)

# The question read as if nobody wore one.
mutate("Favours.lua",
       "\t\t\toneHeld = name and ns.OneTargetHolders(candidates, FAVOUR_HELD) or nil,\n",
       "\t\t\toneHeld = nil,\n",
       "engine-fix38: CouldOffer never reads who wears yours",
       expect=P + "the favour's line does not promise the prompt while your Earth Shield is on another", script=S)

# B1: only Moonkin Form waits for the group's Mark of the Wild.
mutate("Buffs.lua",
       "\t\t\tif family.key == \"moonkinform\" or (list == TBC_OWN.DRUID and family.key == \"treeoflife\") then\n",
       "\t\t\tif family.key == \"moonkinform\" then\n",
       "engine-fix38: Burning Crusade's Tree of Life does not wait",
       expect=P + "tbc: Tree of Life waits for the group's Mark of the Wild", script=S)

# ...and Season of Discovery's tree, which casts Mark of the Wild, waits too.
mutate("Buffs.lua",
       "\t\t\ttable.insert(druid, i + 1, { key = \"treeoflife\", toggle = true, form = true,\n",
       "\t\t\ttable.insert(druid, i + 1, { key = \"treeoflife\", toggle = true, form = true, shiftedOut = true,\n",
       "engine-fix38: Season of Discovery's Tree of Life waits",
       expect=P + "vanilla: Tree of Life is still offered ahead of the group's Mark of the Wild", script=S)

# B3: Soul Link your demon put on you reads as somebody else's.
mutate("Core.lua",
       "\t\t\t\t\t\tor (spell.byPet and plain(aura.sourceUnit) == \"pet\")) then\n",
       "\t\t\t\t\t\tor false) then\n",
       "engine-fix38: Soul Link from your pet not yours",
       expect=P + "tbc: Soul Link your demon put on you is up", script=S)

# ...and only on Burning Crusade, as 1.11.12 had it: Forever's offered again.
mutate("Buffs.lua",
       "\t\t\t\t\tif spell.key == \"soullink\" then spell.byPet = true end\n",
       "\t\t\t\t\tif spell.key == \"soullink\" and list == TBC_OWN.WARLOCK then spell.byPet = true end\n",
       "engine-fix38: Soul Link from your pet read on TBC only",
       expect=P + "camelot: Soul Link your demon put on you is up", script=S)

# B4: the other Beacon read only while it is switched on.
mutate("Queue.lua",
       "\t\t\tif partner and not Listed(candidates, partner) then ReadHolder(partner, into, count, tokens, prefix) end\n",
       "\t\t\tif false then ReadHolder(partner, into, count, tokens, prefix) end\n",
       "engine-fix38: a switched-off Beacon of Light not read",
       expect=P + "Beacon of Faith is kept off your Beacon of Light's wearer with Beacon of Light switched off", script=S)

# B5: Demonic Sacrifice said to have no timer.
mutate("Buffs.lua",
       "\t\t\t\tfamily.timed = true\n",
       "\t\t\t\tfamily.timed = nil\n",
       "engine-fix38: Demonic Sacrifice has no timer",
       expect=P + "vanilla: Demonic Sacrifice is not said to have no timer", script=S)

# E3: the home party compared by the whole name alone.
mutate("Speech.lua",
       "\t\t\t\tif theirs and (theirs == want or theirs == first) then\n",
       "\t\t\t\tif theirs and theirs == want then\n",
       "engine-fix38: the home party by whole name only",
       expect=P + "camelot: the party line reaches a member the home party lists by first name", script=S)

# E4: the druid read as the one wearing his own Symbiotic Relationship.
mutate("Buffs.lua",
       "\tMAINLINE.DRUID[#MAINLINE.DRUID].notSelf = true\n",
       "\tMAINLINE.DRUID[#MAINLINE.DRUID].notSelf = nil\n",
       "engine-fix38: Symbiotic Relationship read on the druid",
       expect=P + "Symbiotic Relationship's partner is topped up, the druid's own side never read as the holder", script=S)
