# Mutations for the scan's memory: the answers it keeps between two ticks to
# stop doing the same work two and a half times a second, each put back the way
# it would break -- an answer kept past the moment it stopped being true. Each
# is caught by the scenario in tests/scenarios/perf.lua that names it.

# The never-offer list checked against its copy by size alone, so a name
# swapped for another, which leaves the size alone, is not noticed.
mutate("Core.lua",
       "\t\t\tif copy[key] ~= flag then fresh = false break end\n",
       "",
       "never-list answers kept over a swapped name",
       expect="the never-offer list edited behind the queue is honoured at once",
       script="runscenarios.py")

# ...and entry by entry alone, so a name taken off it is not noticed.
mutate("Core.lua",
       "\t\tif size ~= neverSeen.size then fresh = false end\n",
       "",
       "never-list answers kept over a removed name",
       expect="the never-offer list edited behind the queue is honoured at once",
       script="runscenarios.py")

# The answers served under a case-folding compare they were not worked out
# with.
mutate("Core.lua",
       "\tlocal fresh = neverSeen.list == never and neverSeen.fold == fold\n",
       "\tlocal fresh = neverSeen.list == never\n",
       "never-list answers kept over a new compare",
       expect="a different name compare throws the never-offer answers away",
       script="runscenarios.py")

# The scan's answers left with ns.IsNeverOffered after the walk, for whoever
# asks next -- straight after an edit, among them.
mutate("Core.lua",
       "\tneverSeen.scan = nil\n",
       "",
       "never-list answers outlive the scan",
       expect="the never-offer list asked between scans reads the list",
       script="runscenarios.py")

# The walk unprotected, so a scan that throws never withdraws them.
mutate("Core.lua",
       "\tlocal walked, walkError = pcall(IterateUnits, visit)\n",
       "\tIterateUnits(visit)\n\tlocal walked, walkError = true\n",
       "never-list answers outlive a scan that threw",
       expect="the never-offer list asked between scans reads the list",
       script="runscenarios.py")

# The empty-table shortcut backwards: no block is ever read.
mutate("Core.lua",
       "\t\tif next(tried) == nil then return false end\n",
       "\t\tif next(tried) ~= nil then return false end\n",
       "blocks not read at all",
       expect="a block is read the moment it is written, buff by buff",
       script="runscenarios.py")

# One kept key per person rather than one per buff, so the first buff asked
# about answers for all of them.
mutate("Core.lua",
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
mutate("Core.lua",
       "\t\topts.offerAnyway = isOwed\n",
       "\t\tif isOwed then opts.offerAnyway = true end\n",
       "one person's favour carried to the next",
       expect="one person's favour is not carried to the next person",
       script="runscenarios.py")

# The favours out of sight all judged on the class nobody wrote.
mutate("Core.lua",
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

# Seventy-two more file-level locals in Core.lua, which still loads but leaves
# 3 free against validate's floor of 10. Core.lua has 75 free as this is
# written (its do-blocks and grouped tables); if later work frees more, this
# has to add more to stay caught, and it cannot add more than are free, or
# Core.lua fails to compile and the headroom check has nothing to count. The
# per-function limits section objects to the same change in its own words, so
# the expect is this section's wording alone.
mutate("Core.lua",
       "local PRIORITY = { target = 0, owed = 1, asked = 1.5, group = 2, nearby = 3 }\n",
       "local PRIORITY = { target = 0, owed = 1, asked = 1.5, group = 2, nearby = 3 }\n"
       "local m1, m2, m3, m4, m5, m6, m7, m8, m9, m10\n"
       "local m11, m12, m13, m14, m15, m16, m17, m18, m19, m20\n"
       "local m21, m22, m23, m24, m25, m26, m27, m28, m29, m30\n"
       "local m31, m32, m33, m34, m35, m36, m37, m38, m39, m40\n"
       "local m41, m42, m43, m44, m45, m46, m47, m48, m49, m50\n"
       "local m51, m52, m53, m54, m55, m56, m57, m58, m59, m60\n"
       "local m61, m62, m63, m64, m65, m66, m67, m68, m69, m70\n"
       "local m71, m72\n",
       "Core.lua's main chunk seventy-two locals fuller",
       expect="free, want 10 -- put helpers",
       script="validate.py")
