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
       expect="prompt-fix: the bag is not offered again partway through its own 15 s cast",
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
