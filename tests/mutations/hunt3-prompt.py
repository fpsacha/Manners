# Mutations for the prompt letting go of somebody put on the never-offer list
# from outside it. Each is caught by the scenario in
# tests/scenarios/hunt3-prompt.lua that names it.

# The fuse and the press no longer treat a listed person with nothing owed as
# retired, so the panel stays up and armed at them.
mutate("Prompt.lua",
       "\t\tand (ns.IsBlocked(entry.name, entry.buff and entry.buff.key, now)\n"
       "\t\t\tor ListedWithoutDebt(entry.name, now))\n",
       "\t\tand ns.IsBlocked(entry.name, entry.buff and entry.buff.key, now)\n",
       "never-listed person kept by the fuse",
       expect="a person put on the never list gets no fuse",
       script="runscenarios.py")

# The hold no longer lets go of a listed person with nothing owed.
mutate("Prompt.lua",
       "\tif ListedWithoutDebt(heldEntry.name, now) then return false end\n",
       "",
       "never-listed person kept by the hold",
       expect="a person put on the never list leaves the panel at once",
       script="runscenarios.py")

# The owed exception dropped: every listed person is let go, owed or not.
mutate("Prompt.lua",
       "\treturn not owed\n",
       "\treturn true\n",
       "owed person on the never list let go by the prompt",
       expect="a listed person who is owed still gets the fuse",
       script="runscenarios.py")
