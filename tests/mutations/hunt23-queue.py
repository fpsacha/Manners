# Mutations for tests/scenarios/hunt23-queue.lua: each puts one of the four
# faults back, or breaks what its fix has to keep.

S = "runscenarios.py"

# The refusal back-off taking the person the player has selected off the
# prompt, with nothing that lifts it (selecting the selected unit sends no event).
mutate("Queue.lua",
       "\t\tif name == pointedAt and ns.UnitFullName(\"target\") == name then return end\n",
       "",
       "hunt23-queue: the back-off takes the player's own target off the prompt",
       expect="hunt23-queue: your own target is not backed off while you point at them",
       script=S)

# Whoever is the target spared, the prompt's own /target included: somebody the
# game keeps refusing, left targeted by the macro, comes straight back for good.
mutate("Queue.lua",
       "\t\tif name == pointedAt and ns.UnitFullName(\"target\") == name then return end\n",
       "\t\tif ns.UnitFullName(\"target\") == name then return end\n",
       "hunt23-queue: the macro's own target is never backed off",
       expect="hunt23-queue: somebody the macro targeted is still backed off",
       script=S)

# The refusals on the person the player points at not counted, so the one after
# they stop being the target starts the ladder from the bottom.
mutate("Queue.lua",
       "\t\tr.count = r.count + 1\n",
       "\t\tif name ~= pointedAt then r.count = r.count + 1 end\n",
       "hunt23-queue: refusals on the player's target are not counted",
       expect="were not counted",
       script=S)

# A cleared target still the player's choice: the macro's /target on somebody
# they once selected is taken for the player's own.
mutate("Queue.lua",
       "\t\tpointedAt = name\n",
       "\t\tpointedAt = name or pointedAt\n",
       "hunt23-queue: a cleared target stays the player's choice",
       expect="hunt23-queue: your own target is not backed off while you point at them: somebody the player selected once",
       script=S)

# A namesake from another realm read as a friend by the first name alone.
mutate("Queue.lua",
       "\t\t\t\tor friendNames[full:lower()] then\n",
       "\t\t\t\tor friendNames[full:lower()]\n\t\t\t\tor friendNames[(ns.TargetName(full) or full):lower()] then\n",
       "hunt23-queue: a namesake from another realm is a friend",
       expect="hunt23-queue: a namesake from another realm is not a friend (vanilla)",
       script=S)

# The friends found by the name the list gives them dropped: a friend of your
# own realm, listed as "Anna", and a friend of another, listed as
# "Anna-Realm", are no longer found where the client will not say by GUID.
mutate("Queue.lua",
       "\t\t\t\tor friendNames[full:lower()] then\n",
       "\t\t\t\tor false then\n",
       "hunt23-queue: friends are not found by the name on the list",
       expect="hunt23-queue: a namesake from another realm is not a friend (vanilla) by name",
       script=S)
