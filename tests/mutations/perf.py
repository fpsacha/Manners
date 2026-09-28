# Mutations for the scan's memory: the answers it keeps between two ticks to
# stop doing the same work two and a half times a second, each put back the way
# it would break -- an answer kept past the moment it stopped being true. Each
# is caught by the scenario in tests/scenarios/perf.lua that names it.

# The never-offer list checked against its copy by size alone, so a name
# swapped for another, which leaves the size alone, is not noticed.
mutate("Queue.lua",
       "\t\t\tif copy[key] ~= flag then fresh = false break end\n",
       "",
       "never-list answers kept over a swapped name",
       expect="the never-offer list edited behind the queue is honoured at once",
       script="runscenarios.py")

# ...and entry by entry alone, so a name taken off it is not noticed.
mutate("Queue.lua",
       "\t\tif size ~= neverSeen.size then fresh = false end\n",
       "",
       "never-list answers kept over a removed name",
       expect="the never-offer list edited behind the queue is honoured at once",
       script="runscenarios.py")

# The answers served under a case-folding compare they were not worked out
# with.
mutate("Queue.lua",
       "\tlocal fresh = neverSeen.list == never and neverSeen.fold == fold\n",
       "\tlocal fresh = neverSeen.list == never\n",
       "never-list answers kept over a new compare",
       expect="a different name compare throws the never-offer answers away",
       script="runscenarios.py")

# The scan's answers left with ns.IsNeverOffered after the walk, for whoever
# asks next -- straight after an edit, among them.
mutate("Queue.lua",
       "\tneverSeen.scan = nil\n",
       "",
       "never-list answers outlive the scan",
       expect="the never-offer list asked between scans reads the list",
       script="runscenarios.py")

# The walk unprotected, so a scan that throws never withdraws them.
mutate("Queue.lua",
       "\tlocal walked, walkError = pcall(IterateUnits, visit)\n",
       "\tIterateUnits(visit)\n\tlocal walked, walkError = true\n",
       "never-list answers outlive a scan that threw",
       expect="the never-offer list asked between scans reads the list",
       script="runscenarios.py")

# The empty-table shortcut backwards: no block is ever read.
mutate("Queue.lua",
       "\t\tif next(tried) == nil then return false end\n",
       "\t\tif next(tried) ~= nil then return false end\n",
       "blocks not read at all",
       expect="a block is read the moment it is written, buff by buff",
       script="runscenarios.py")

# One kept key per person rather than one per buff, so the first buff asked
# about answers for all of them.
mutate("Queue.lua",
       "\t\tlocal key = keys[buffKey]\n"
       "\t\tif not key then\n"
       "\t\t\tkey = name .. \"\\0\" .. buffKey\n"
       "\t\t\tkeys[buffKey] = key\n",
       "\t\tlocal key = keys[1]\n"
       "\t\tif not key then\n"
       "\t\t\tkey = name .. \"\\0\" .. buffKey\n"
       "\t\t\tkeys[1] = key\n",
       "one block key answers for every buff",
       expect="a block is read the moment it is written, buff by buff",
       script="runscenarios.py")

# The shared options written only when set, so a favour owed to one person
# is carried to whoever the walk reaches next.
mutate("Queue.lua",
       "\t\topts.offerAnyway = isOwed\n",
       "\t\tif isOwed then opts.offerAnyway = true end\n",
       "one person's favour carried to the next",
       expect="one person's favour is not carried to the next person",
       script="runscenarios.py")

# The favours out of sight all judged on the class nobody wrote.
mutate("Queue.lua",
       "\t\t\t\ttokenless.hasMana = hasMana\n",
       "",
       "a favour out of sight judged without its class",
       expect="each favour out of sight is judged on its own class",
       script="runscenarios.py")

# A stale aura reading rewritten with its new time and its old answer.
mutate("Core.lua",
       "\t\t\tcached.at, cached.has, cached.expires, cached.mine = now, has, expires, mine\n",
       "\t\t\tcached.at = now\n",
       "an old aura reading kept under a new time",
       expect="an old reading of somebody's buffs is replaced by a new one",
       script="runscenarios.py")

# A hundred and sixty more file-level locals in Core.lua, which still loads but
# leaves 5 free against validate's floor of 10. Core.lua has 165 free as this is
# written (since the split into Range.lua, Queue.lua and the rest); if later
# work frees more, this has to add more to stay caught, and it cannot add more
# than are free, or Core.lua fails to compile and the headroom check has
# nothing to count. Five, not fewer, so a branch that adds a few locals of its
# own does not tip it over the compiler's limit. The per-function limits
# section objects to the same change in its own words, so the expect is this
# section's wording alone.
_fill = ["m%d" % i for i in range(1, 161)]
mutate("Core.lua",
       "local L = ns.L\n",
       "local L = ns.L\n"
       + "".join("local %s\n" % ", ".join(_fill[i:i + 10]) for i in range(0, len(_fill), 10)),
       "Core.lua's main chunk filled to five free",
       expect="free, want 10 -- put helpers",
       script="validate.py")
