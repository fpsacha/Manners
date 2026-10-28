# Mutations for tests/scenarios/hunt39-decide.lua: each puts one of the faults
# back, or breaks what its fix has to keep.

S = "runscenarios.py"

# A raid group that is switched off turning a member away with no verdict, so
# the memory of them as a passer-by goes on offering them by name.
mutate("Queue.lua",
       "\t\t\tif group and skipGroups[group] then\n\t\t\t\trejected[full] = true\n\t\t\t\treturn\n\t\t\tend\n",
       "\t\t\tif group and skipGroups[group] then return end\n",
       "hunt39-decide: a raid group switched off writes no verdict",
       expect="hunt39-decide: a passer-by who joins a raid group that is switched off",
       script=S)

# A blessing of yours that is switched off not read, so the one offered goes
# over it.
mutate("Core.lua",
       "\t\t\tif not pinned and not opts.asked and skip and next(skip) ~= nil then\n",
       "\t\t\tif false then\n",
       "hunt39-decide: a switched-off blessing of yours is not read",
       expect="hunt39-decide: camelot: a switched-off blessing of yours on them is left alone",
       script=S)

# ...and read for somebody who asked for a blessing by name too, which leaves
# them without what they asked for.
mutate("Core.lua",
       "\t\t\tif not pinned and not opts.asked and skip and next(skip) ~= nil then\n",
       "\t\t\tif not pinned and skip and next(skip) ~= nil then\n",
       "hunt39-decide: a request for a blessing is held off by one switched off",
       expect="hunt39-decide: camelot: somebody who asks for Kings by name is still offered it",
       script=S)

# The memory of an asker or passer-by not asking the /ignore list, so somebody
# ignored who was a member of the group when they asked is offered once it is gone.
mutate("Queue.lua",
       "\t\t\tor (ignoring and ns.Ignored(name, memo.guid))\n\t\t\tor not SafeForMacro(name) then\n",
       "\t\t\tor not SafeForMacro(name) then\n",
       "hunt39-decide: the memory of a passer-by ignores the ignore list",
       expect="hunt39-decide: somebody you ignore who asked as a member is not offered after the group is gone",
       script=S)
