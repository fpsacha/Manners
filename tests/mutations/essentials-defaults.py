# Mutations for 1.12's defaults (Core.lua's own-buff picks and the fight
# buttons). Each is caught by the scenario in
# tests/scenarios/essentials-defaults.lua that names it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"
OWN = "essentials-defaults: camelot: the extras on yourself are off in a new profile"
FIGHT = "essentials-defaults: the fight buttons, the consumables button and the courtesies are off in a new profile"

# The own-buff extras on by default again.
mutate("Core.lua",
       "\t\tif family.enhance or family.isScroll or family.tracking or family.key == \"makehealthstone\" then\n",
       "\t\tif false then\n",
       "essentials-defaults: the own-buff extras on by default",
       expect=OWN, script=S)

# Tracking alone on by default again.
mutate("Core.lua",
       "\t\tif family.enhance or family.isScroll or family.tracking or family.key == \"makehealthstone\" then\n",
       "\t\tif family.enhance or family.isScroll or family.key == \"makehealthstone\" then\n",
       "essentials-defaults: tracking on by default",
       expect=OWN, script=S)

# The Mend Pet button on by default again.
mutate("Core.lua",
       "training = true, fightMend = false,",
       "training = true, fightMend = true,",
       "essentials-defaults: the Mend Pet button on by default",
       expect=FIGHT, script=S)
