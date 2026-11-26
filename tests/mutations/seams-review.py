# Mutations for the review of the places where one release's features meet:
# the resurrection's switches for a class with no buff for anybody else
# (Options/Who.lua, Options/Shared.lua), a courtesy for an asker who is dead
# or offline (Courtesy.lua), the walk of a class with a cure and no buff
# (Queue.lua, Cures.lua) and the group's switches in the options window
# (Options/Window/Layout.lua). Each undoes one fix and is caught by the
# scenario in tests/scenarios/seams-review.lua that names it.

S = "runscenarios.py"

SWITCHES = "seams-review: a class with no buff for others is shown the resurrection's switches"
PROMPT = "seams-review: a resurrection learned and switched on is a prompt for Start here"
DEAD = "seams-review: a courtesy is not offered to an asker who is dead or offline"
FIGHT = "seams-review: a class with a cure and no buff walks nobody in a fight"
PASSERS = "seams-review: no passer-by is measured for a cure that is the group's alone"
PLACES = "seams-review: the group's own switches sit together, ahead of the resurrection's"

# The resurrection's switches cleared away with the buffs for others, for a
# class that has none.
mutate("Options/Who.lua",
       "\t-- And the resurrection's two switches: a class with nothing else for others\n"
       "\t-- has one too.\n"
       "\tPage.AddResControls(who.args)\n",
       "\tPage.AddResControls(who.args)\n"
       "\tForOthersOnly({ res = who.args.res, resStrangers = who.args.resStrangers })\n",
       "seams-review: the resurrection's switches hidden from a shaman",
       expect=SWITCHES, script=S)

# A resurrection is no prompt for the options.
mutate("Options/Shared.lua",
       "\tif ns.caps.res and ns.Resurrect and ns.Resurrect.Wanted() then return true end\n",
       "",
       "seams-review: Start here has no prompt for a class that only resurrects",
       expect=PROMPT, script=S)

# The asker is whoever a token names, dead or not.
mutate("Context.lua",
       "\tif dead == true then\n"
       "\t\treturn RejectTarget(kind, unit, \"dead\")\n"
       "\tend\n",
       "",
       "seams-review: a courtesy offered to the dead and the offline",
       expect=DEAD, script=S)

# Offline alone is let through.
mutate("Context.lua",
       "\tif connected == false then\n"
       "\t\treturn RejectTarget(kind, unit, \"offline\")\n"
       "\tend\n",
       "\tif false then\n"
       "\t\treturn RejectTarget(kind, unit, \"offline\")\n"
       "\tend\n",
       "seams-review: a courtesy offered to somebody offline",
       expect=DEAD, script=S)

# A cure learned and a switch on walk the group, a fight or not.
mutate("Queue.lua",
       "\tif #candidates == 0 and not (askOnly and #askOnly > 0 and ns.RequestStanding(now)) and not curesScanned then\n",
       "\tif #candidates == 0 and not (askOnly and #askOnly > 0 and ns.RequestStanding(now)) and not ns.CuresWanted(db) then\n",
       "seams-review: a class with a cure alone walks through a fight",
       expect=FIGHT, script=S)

# A passer-by walked down to the distance check with nothing to offer.
mutate("Queue.lua",
       "\t\tif reason == \"nearby\" and #candidates == 0 and not curing then return end\n",
       "",
       "seams-review: passers-by measured for a cure they cannot be given",
       expect=PASSERS, script=S)

# Share the group drawn among the resurrection's switches, out of the group's
# own section.
mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t\"who.res\",\n"
       "\t\t\t\t\t{ \"who.resStrangers\", indent = true },\n",
       "\t\t\t\t\t\"who.res\",\n"
       "\t\t\t\t\t{ \"who.share\", indent = true },\n"
       "\t\t\t\t\t{ \"who.resStrangers\", indent = true },\n",
       "seams-review: Share the group drawn under My group's dead",
       expect=PLACES, script=S)
