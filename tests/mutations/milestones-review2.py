# Mutations for the second review of milestones (Milestones.lua, with its
# hooks in Resurrect.lua and Core.lua). Each undoes one fix and is caught by
# the scenario in tests/scenarios/milestones-review2.lua that names it.

S = "runscenarios.py"

RES = "milestones-review2: a raid brought back to life was not given a buff"
RAID = "milestones-review2: a raid is everybody by name, each once and never yourself"
STRANGER = "milestones-review2: a stranger who asked or was brought back is not one buffed unprompted"
RELOAD = "milestones-review2: a settle cut off by a reload is counted at the next login"
PROFILE = "milestones-review2: a profile changed to one with milestones on toasts nothing passed while off"
WAIT = "milestones-review2: a favour returned counts once its own refusal can no longer come"
WEEK = "milestones-review2: a week is not kept by a favour still inside its refusal wait"
ROOM = "milestones-review2: an earned row keeps the room for its line"

# A resurrection filed in the ledger is a buff for the raid's milestone.
mutate("Milestones.lua",
       "\t\t\t\telseif e.to == \"group\" and not IsRes(e.spell) then\n",
       "\t\t\t\telseif e.to == \"group\" then\n",
       "milestones-review2: a resurrection counts towards everybody in your raid",
       expect=RES, script=S)
mutate("Resurrect.lua",
       "\treturn id ~= nil and EVERY[id] == true\n",
       "\treturn false\n",
       "milestones-review2: no spell is known for a resurrection",
       expect=RES, script=S)

# Who a cast reached: yourself among them, and once per anchor.
mutate("Milestones.lua",
       "\t\tif not ns.IsPlayerName(name) then cast[name] = clock end\n",
       "\t\tcast[name] = clock\n",
       "milestones-review2: the caster is one of the raid he buffed",
       expect=RAID, script=S)
mutate("Milestones.lua",
       "\t\tif not ns.IsPlayerName(name) then cast[name] = clock end\n",
       "\t\tif not ns.IsPlayerName(name) then cast[name .. \"\\0\" .. tostring(names[1])] = clock end\n",
       "milestones-review2: the same people count again under another anchor",
       expect=RAID, script=S)

# A hundred strangers: one who asked, one brought back, and the ledger's past.
mutate("Milestones.lua",
       "\telseif e.to == \"stranger\" and not IsRes(e.spell) then\n",
       "\tend\n\tif e.to == \"stranger\" and not IsRes(e.spell) then\n",
       "milestones-review2: a stranger who asked is one buffed unprompted",
       expect=STRANGER, script=S)
mutate("Milestones.lua",
       "\telseif e.to == \"stranger\" and not IsRes(e.spell) then\n",
       "\telseif e.to == \"stranger\" then\n",
       "milestones-review2: a stranger brought back is one buffed",
       expect=STRANGER, script=S)
mutate("Milestones.lua",
       "\tst.n.strangers = math.max(st.n.strangers, Count(Count(sum.totals.strangers) - other))\n",
       "\tst.n.strangers = math.max(st.n.strangers, Count(sum.totals.strangers))\n",
       "milestones-review2: the ledger's past counts every stranger as buffed unprompted",
       expect=STRANGER, script=S)

# A reload inside the refusal wait.
mutate("Milestones.lua",
       "\tBegin(st)\n\tResume(st)\nend\n",
       "\tBegin(st)\nend\n",
       "milestones-review2: a login counts nothing a reload cut off",
       expect=RELOAD, script=S)
mutate("Milestones.lua",
       "\tif #st.due < MAX_DUE then st.due[#st.due + 1] = w.due end\n",
       "",
       "milestones-review2: a settle waiting is not written down",
       expect=RELOAD, script=S)
mutate("Milestones.lua",
       "\tst.due = {}\n\tlocal now = K.Wall()\n",
       "\tlocal now = K.Wall()\n",
       "milestones-review2: what a login counted is counted at every login",
       expect=RELOAD, script=S)

# A profile change is the switch turned.
mutate("Core.lua",
       "\tif ns.Milestones then ns.Guard(\"milestones\", ns.Milestones.Switched) end\n",
       "",
       "milestones-review2: a profile change tells milestones nothing",
       expect=PROFILE, script=S)

# The ledger's count of favours returned, read before the refusal's wait is over.
mutate("Milestones.lua",
       "\tsum.totals.returned = math.max(0, (sum.totals.returned or 0) - held)\n",
       "\tsum.totals.returned = math.max(0, sum.totals.returned or 0)\n",
       "milestones-review2: a favour returned counts at the press",
       expect=WAIT, script=S)
mutate("Milestones.lua",
       "\t\t\tif e.state ~= \"returned\" or Unsettled(e) then return false end\n",
       "\t\t\tif e.state ~= \"returned\" then return false end\n",
       "milestones-review2: the week is kept by a favour still waiting",
       expect=WEEK, script=S)

# The link button as wide as its words were.
mutate("Milestones.lua",
       "local LINK_WIDTH = 22\n",
       "local LINK_WIDTH = 130\n",
       "milestones-review2: the link button takes the row's line",
       expect=ROOM, script=S)
