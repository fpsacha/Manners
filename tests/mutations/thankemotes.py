# Mutations for the longer list of thank emotes (Core.lua, ns.THANK_EMOTES).
# Each is caught by the scenario in tests/scenarios/thankemotes.lua that names it.

S = "runscenarios.py"

mutate("Core.lua",
       "\t\"KISS\", \"KNEEL\", \"LOVE\", \"PRAISE\", \"PROUD\", \"WELCOME\" }\n",
       "}\n",
       "thankemotes: the last six dropped",
       expect="thankemotes: Emote to use offers the longer list", script=S)

mutate("Core.lua",
       "\t\"APPLAUD\", \"BLUSH\", \"CURTSEY\", \"FLEX\", \"GREET\", \"GRIN\", \"HAIL\", \"HAPPY\", \"HIGHFIVE\", \"HUG\",\n",
       "\t\"APPLAUD\", \"BLUSH\", \"CURTSEY\", \"FLEX\", \"GREET\", \"GRIN\", \"HAIL\", \"HAPPY\", \"HUG\",\n",
       "thankemotes: /highfive left out",
       expect="thankemotes: Emote to use offers the longer list", script=S)
