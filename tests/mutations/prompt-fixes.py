# Mutations for the prompt fixes of bug hunt 35: each undoes one fix and is
# caught by the scenario in tests/scenarios/prompt-fixes.lua that names it.

# The bag's press is let go of after a scroll's six seconds, not its own.
mutate("Clicks.lua",
       "\t\tif own.family.rest then castingScroll.seconds = REST_SECONDS end\n",
       "",
       "prompt-fix: the bag's press kept for a scroll's six seconds",
       expect="prompt-fix: the bag's cast interrupted at second 8 is said and offered again",
       script="runscenarios.py")

# The bag is not read as busy while its own cast runs.
mutate("Core.lua",
       "if type(casting) == \"function\" and plain((select(9, casting(\"player\")))) == spell.ranks[1] then",
       "if false and plain((select(9, casting(\"player\")))) == spell.ranks[1] then",
       "prompt-fix: the bag offered again mid-cast",
       expect="prompt-fix: the bag laid by hand is not offered while its cast runs",
       script="runscenarios.py")

# A meal in progress no longer holds the bag back.
mutate("Core.lua",
       "if EatingNow() then return nil, up, left, \"resting\", spell end",
       "if false then return nil, up, left, \"resting\", spell end",
       "prompt-fix: the bag offered while eating",
       expect="prompt-fix: while eating, the sleeping bag is not offered next",
       script="runscenarios.py")

# A profile switch keeping the old bag count is rested-fixes.py's (one call, in
# RefreshConfig); its scenario here still has to pass.

# The debug line names nobody for a bagged family that is up.
mutate("Commands.lua",
       "local name = about and ns.BuffName(about) or (family.bagged and label or nil)",
       "local name = about and ns.BuffName(about)",
       "prompt-fix: the debug line for a buff up named '?'",
       expect="prompt-fix: the debug lines name Well-Rested and Well Fed when up",
       script="runscenarios.py")

# ------------------------------------------------------------------ hunt 37

# Moonkin Form comes in ahead of the group's Mark of the Wild again.
mutate("Queue.lua",
       "\tif mine and FormWaits(mine, queue) then mine = nil end\n",
       "",
       "prompt-fix: Moonkin Form offered ahead of Mark of the Wild",
       expect="prompt-fix: vanilla: Moonkin Form is not offered ahead of the group's Mark of the Wild",
       script="runscenarios.py")

# Forever's Mark of the Wild flagged as one the form refuses.
mutate("Buffs.lua",
       "\t\t\t\tentry.shiftsOut = nil\n",
       "",
       "prompt-fix: Forever's Moonkin Form held back for Mark of the Wild",
       expect="prompt-fix: camelot: Moonkin Form is still offered ahead of the group's Mark of the Wild",
       script="runscenarios.py")

# A scroll body left by another character is the player's own again.
mutate("Clicks.lua",
       "\t\telseif command == \"use\" and arg:match(\"^item:%d+$\") and OneOfMine(select(2, Command(rest[2]))) then\n\t\t\ti = i + 1\n",
       "\t\telseif command == \"use\" and arg:match(\"^item:%d+$\") and select(2, Command(rest[2])) == OwnTarget() then\n\t\t\ti = i + 1\n",
       "prompt-fix: an alt's scroll body left as foreign",
       expect="prompt-fix: an alt's bar macro body is rewritten at login (a scroll used on another character)",
       script="runscenarios.py")

# The empty press blames the nameplates for a class with nothing to cast on anybody.
mutate("Prompt/Press.lua",
       "\t\t\tand #ns.CastableBuffs() > 0\n",
       "",
       "prompt-fix: nameplates blamed with nothing castable",
       expect="prompt-fix: vanilla: a shaman with no Earth Shield is not told the nameplates hide passers-by",
       script="runscenarios.py")

# The sound stays shut for a class that cannot be owed anything yet.
mutate("Prompt/Refresh.lua",
       "(ns.caps.anyKnown == true or not ns.OnlyTalentBuffs()) and ",
       "",
       "prompt-fix: a shaman's own reminder silenced",
       expect="prompt-fix: vanilla: a shaman with no Earth Shield hears his own reminder",
       script="runscenarios.py")

# The empty press promises something to learn to a talent-only class.
mutate("Prompt/Press.lua",
       " or ns.OnlyTalentBuffs() then\n\t\t\t\tns.addon:Print(ns.NO_CLASS_BUFFS)",
       " then\n\t\t\t\tns.addon:Print(ns.NO_CLASS_BUFFS)",
       "prompt-fix: a paladin with no Beacon promised something to learn",
       expect="prompt-fix: mainline: a paladin with no Beacon is not told nothing is learned yet",
       script="runscenarios.py")
