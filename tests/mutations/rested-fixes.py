# Mutations for the rested fixes (bug hunt 35): a Well-Rested or Well Fed aura
# the client keeps secret, a secret bag cooldown, the bag count after a profile
# change, the bag's 15-second cast, and no experience to gain. Each is caught by
# the scenario in tests/scenarios/rested-fixes.lua that names it.

S = "runscenarios.py"

mutate("Core.lua",
       "\t\tif HiddenAura(family.fed) then return nil end\n\t\treturn false\n\tend\n\n\t-- Whether the sleeping bag is busy",
       "\t\treturn false\n\tend\n\n\t-- Whether the sleeping bag is busy",
       "rested-fixes: a secret Well-Rested read as missing",
       expect="rested-fix: a secret Well-Rested is not read as missing", script=S)

mutate("Core.lua",
       "\t\tif ok and (Withheld(start) or Withheld(duration)) then return true end\n",
       "",
       "rested-fixes: a secret bag cooldown read as none",
       expect="rested-fix: a secret Well-Rested is not read as missing", script=S)

mutate("Core.lua",
       "\tns.ForgetScrolls()\n\t-- A profile switched to may",
       "\t-- A profile switched to may",
       "rested-fixes: a profile switch keeps the bag count",
       expect="rested-fix: a profile switch to Well-Rested on counts the bag", script=S)

mutate("Clicks.lua",
       "\t\tif own.family.rest then castingScroll.seconds = REST_SECONDS end\n",
       "",
       "rested-fixes: the bag's cast let go after six seconds",
       expect="rested-fix: the bag's 15-second cast on Forever is held to its end", script=S)

mutate("Core.lua",
       "\t\tif spell.family.rest and ns.HandBusy(spell.family.key, ctx.now) then\n",
       "\t\tif false then\n",
       "rested-fixes: the bag offered during its own cast",
       expect="rested-fix: the bag's 15-second cast on Forever is held to its end", script=S)

mutate("Core.lua",
       "(level >= ns.MaxPlayerLevel() or ns.NoExperience(level))",
       "(level >= ns.MaxPlayerLevel())",
       "rested-fixes: no bag check for experience off or a low cap",
       expect="rested-fix: no bag where there is no experience to gain", script=S)

mutate("Core.lua",
       "\tif type(off) == \"function\" and plain(off()) == true then return true end\n",
       "",
       "rested-fixes: experience turned off not read",
       expect="rested-fix: no bag where there is no experience to gain", script=S)
