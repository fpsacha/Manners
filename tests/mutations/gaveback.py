# Mutations for "a favour repaid is not asked for again" (Queue.lua NoteGave and
# GaveSince, Core.lua Fresh, Clicks.lua's settle). Each is caught by the scenario
# in tests/scenarios/gaveback.lua that names it.

S = "runscenarios.py"

# the settle never notes the cast it saw land.
mutate("Clicks.lua",
       "\tif not unheard then ns.NoteGave(pending.name, pending.buffKey) end\n",
       "",
       "gaveback: the settle notes nothing",
       expect="gaveback: a favour is not repaid with the Might they wear from you", script=S)

# a buff that names nobody is never read as the cast that was noted.
mutate("Core.lua",
       "\t\tif mine == nil and not ns.GaveSince(opts.name, buff.key, remaining, length) then return false end\n",
       "\t\tif mine == nil then return false end\n",
       "gaveback: a buff naming nobody is never ours",
       expect="gaveback: a favour is not repaid with the Might they wear from you", script=S)

# any buff that names nobody is read as ours.
mutate("Core.lua",
       "\t\tif mine == nil and not ns.GaveSince(opts.name, buff.key, remaining, length) then return false end\n",
       "",
       "gaveback: a buff naming nobody is always ours",
       expect="gaveback: Might from nobody Manners cast is still offered back for a favour", script=S)

# a buff that outlasts the noted cast is still taken for it.
mutate("Queue.lua",
       "\t\treturn at + length + 5 >= GetTime() + remaining\n",
       "\t\treturn true\n",
       "gaveback: a newer buff taken for the noted cast",
       expect="gaveback: a Might that outlasts the cast Manners saw is not taken for it", script=S)

# the buff of the cast is not asked for.
mutate("Queue.lua",
       "\t\tlocal at = entry and entry[buffKey]\n",
       "\t\tlocal at = entry and (entry[buffKey] or select(2, next(entry)))\n",
       "gaveback: another blessing's cast taken for this one",
       expect="gaveback: a cast noted for another blessing says nothing of this one", script=S)

# a buff another paladin cast is read as paid up too.
mutate("Core.lua",
       "\t\tif opts.paidUp == nil or mine == false or type(remaining) ~= \"number\" then return false end\n",
       "\t\tif opts.paidUp == nil or type(remaining) ~= \"number\" then return false end\n",
       "gaveback: another paladin's buff paid a favour up",
       expect="a favour is not repaid with a rank weaker than the one they wear", script=S)
