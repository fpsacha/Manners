# The first hour, said plainly (tests/scenarios/par-clarity.lua): why the
# prompt is empty with no key to press, a place rule named where the player
# looks, a new character's greeting held for the first buff learned, the
# warrior's shout told truly per client, and the dungeon switch's name. Each
# fault is caught by the scenario that names it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"
P = "par-clarity: "

# ------------------------------------------------------- the place rules (Queue.lua)

mutate("Queue.lua",
       "\tlocal f = db and db.filters\n\tif type(f) ~= \"table\" then return nil end\n\tif ns.Battle.State(now) then\n",
       "\tlocal f = db and db.filters\n\tif true then return nil end\n\tif ns.Battle.State(now) then\n",
       "par-clarity: no place rule is ever named",
       expect=P + "a city rule is named by the launcher", script=S)

mutate("Queue.lua",
       "\t\tif not ns.Battle.On(\"team\") then return \"battle\" end\n",
       "",
       "par-clarity: Buff my team there off is never named",
       expect="in a battleground with the team off the launcher says", script=S)

mutate("Queue.lua",
       "\t\t\tif city == (where == \"cities\") then return where end\n",
       "\t\t\tif true then return where end\n",
       "par-clarity: Where named in the other kind of place",
       expect="Cities only, at an inn, is said to hold back", script=S)

mutate("Queue.lua",
       "\t\t\tif city == nil then return \"both\" end\n",
       "\t\t\tif city == nil then return nil end\n",
       "par-clarity: a map the client will not name holds nothing back, by the line",
       expect=P + "the rule named is the rule the queue keeps", script=S)

mutate("Queue.lua",
       "\t\tif f.quietInInstances == true and Inside() then return \"instances\" end\n",
       "",
       "par-clarity: the dungeon rule is never named",
       expect="in a dungeon the launcher says", script=S)

mutate("Queue.lua",
       "\tif f.restingOnly == true and db.sources.strangers == true and Resting() == false then return \"world\" end\n",
       "\tif f.restingOnly == true and Resting() == false then return \"world\" end\n",
       "par-clarity: passers-by said to be left alone with passers-by off",
       expect="passers-by off, and still said to be left alone", script=S)

# ------------------------------------------------- the launcher (Options/Launcher.lua)

mutate("Options/Launcher.lua",
       "\tif place then return true, place, 1, 0.82, 0, true, nil, \"placeheld\" end\n",
       "",
       "par-clarity: the launcher reads a city rule as watching",
       expect="Offer nothing in cities and inns, resting, reads as", script=S)

mutate("Options/Launcher.lua",
       "\tlocal always = ns.db.profile.filters.quietTargets == true\n",
       "\tlocal always = false\n",
       "par-clarity: the target promised with Hold back my target and focus too on",
       expect="with the target held too, the line says", script=S)

mutate("Options/Launcher.lua",
       "\tif mana then return true, mana, 1, 0.82, 0, true, nil, \"mana\" end\n",
       "",
       "par-clarity: the launcher reads the mana floor as watching",
       expect="under the mana floor the launcher reads", script=S)

mutate("Options/Launcher.lua",
       "\tif PassersHeld() then\n",
       "\tif false then\n",
       "par-clarity: passers-by left alone out in the world read as watching",
       expect="Only in cities and inns out in the world reads as", script=S)

mutate("Options/Launcher.lua",
       "\tif kind == \"placeheld\" then\n\t\tlocal mana = SavingManaLine()\n",
       "\tif false then\n\t\tlocal mana = SavingManaLine()\n",
       "par-clarity: Diagnostics says one hold where two stand",
       expect="a city rule and the mana floor at once", script=S)

# --------------------------------------------- the strip, the press, debug, Diagnostics

mutate("Options/Window/WindowChrome.lua",
       "\tplates = true, placeheld = true, mana = true }\n",
       "\tplates = true, placeheld = false, mana = true }\n",
       "par-clarity: the strip says nothing of a place rule",
       expect="general's strip says", script=S)

mutate("Options/Window/WindowChrome.lua",
       "\tplates = true, placeheld = true, mana = true }\n",
       "\tplates = true, placeheld = true, mana = false }\n",
       "par-clarity: the strip says nothing of the mana floor",
       expect=P + "saving mana is said by the launcher and the strip: the strip says", script=S)

mutate("Prompt/Press.lua",
       "\t\telseif ns.PlaceHeldLine and ns.PlaceHeldLine(now) then\n",
       "\t\telseif false then\n",
       "par-clarity: a press on the empty prompt says nobody, not the rule",
       expect=P + "a press on the empty prompt names the place rule: the press says", script=S)

mutate("Prompt/Press.lua",
       "\t\telseif ns.PassersHeld and ns.PassersHeld(now) and db.sources.strangers == true then\n",
       "\t\telseif false then\n",
       "par-clarity: a press out in the world says nothing of Only in cities and inns",
       expect=P + "a press out in the world names Only in cities and inns", script=S)

mutate("Commands.lua",
       "\t\tif place then self:Print(place) end\n",
       "",
       "par-clarity: /manners debug leaves the place rule out",
       expect="/manners debug does not name the rule", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t{ key = \"diagnostics.now\", items = { \"diagnostics.holdDiag\" } },\n",
       "",
       "par-clarity: Diagnostics draws no line on what holds the prompt back",
       expect="the line is not drawn on Diagnostics", script=S)

# ------------------------------------------------------------ the greeting (Commands.lua)

mutate("Commands.lua",
       "\tif not force and not nothingToGive and not ownOnly and caps.hasClassBuffs and not caps.anyKnown\n",
       "\tif false and not nothingToGive and not ownOnly and caps.hasClassBuffs and not caps.anyKnown\n",
       "par-clarity: the tour spent on a character that can cast nothing",
       expect="the tour is spent on a character that can cast nothing", script=S)

mutate("Commands.lua",
       "\t\tif waitedThisSession and type(store) == \"table\" and store.welcomeWaits and not store.welcomed then\n",
       "\t\tif false then\n",
       "par-clarity: nothing said once the spell is learned",
       expect="the spell is learned and nothing is said", script=S)

mutate("Commands.lua",
       "\t\tif not store.welcomeWaits then\n\t\t\tstore.welcomeWaits = true\n",
       "\t\tif true then\n\t\t\tstore.welcomeWaits = true\n",
       "par-clarity: the trainer line said at every login",
       expect="the trainer line said at every login", script=S)

mutate("Commands.lua",
       "\tif store.welcomeWaits then\n\t\tstore.welcomeWaits = nil\n",
       "\tif false then\n\t\tstore.welcomeWaits = nil\n",
       "par-clarity: the greeting does not say the spell came",
       expect="the greeting does not say the spell came", script=S)

# ---------------------------------------------------------------- the shout (Options/Who.lua)

mutate("Options/Who.lua",
       "\t\t\t\t\t\t.. (ns.PARTY_IS_SUBGROUP\n",
       "\t\t\t\t\t\t.. (true\n",
       "par-clarity: Forever's shout said to reach only the party",
       expect="the page says the shout reaches only the party", script=S)

mutate("Options/Who.lua",
       "\t\t\t\t\tif not S().group then return true end\n\t\t\t\t\tlocal castable = ns.CastableBuffs()\n",
       "\t\t\t\t\tif true then return true end\n\t\t\t\t\tlocal castable = ns.CastableBuffs()\n",
       "par-clarity: the raid groups say nothing of the shout",
       expect="the raid groups say nothing of the shout", script=S)

mutate("Options/Who.lua",
       "\t\t\t\t\t\tif not buff.selfCast then return true end\n",
       "",
       "par-clarity: a mage told about a shout",
       expect="a mage is told about a shout", script=S)

mutate("Options/Who.lua",
       "\t\t\t\t\treturn \"|cff888888\" .. (ns.PARTY_IS_SUBGROUP\n",
       "\t\t\t\t\treturn \"|cff888888\" .. (false\n",
       "par-clarity: Classic Era's raid groups told the shout reaches the raid",
       expect=P + "Classic Era's warrior is told the shout reaches the party: the raid groups say", script=S)

# ------------------------------------------------------- the dungeon switch (Options/Who.lua)

mutate("Options/Who.lua",
       "\tif db and db.filters.quietInInstances == true and type(db.battle) == \"table\" and db.battle.team == true then\n",
       "\tif false then\n",
       "par-clarity: the dungeon switch still claims battlegrounds",
       expect="Buff my team there ticked again, and it still reads", script=S)

mutate("Options/When.lua",
       ":format(\"|cffffd100\" .. Page.InstancesLabel() .. \"|r\")",
       ":format(\"|cffffd100\" .. L[\"Offer nothing in dungeons, raids and battlegrounds\"] .. \"|r\")",
       "par-clarity: Buff my team there names the dungeon switch by its old name",
       expect="names the other switch by another name", script=S)
