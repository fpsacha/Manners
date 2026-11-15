# Hunt 3 of the day's work, the hall of fame and Detect Invisibility for
# passers-by (Options/Who.lua, Queue.lua, Hall.lua): the passers-by switch in
# reach under a pin of its buff, a remembered passer-by let go once the switch
# is unticked, a namesake of another class not the listed character, a listed
# player's own row past the list's cut, and no invitation to copy a code there
# is none of. Each fault is caught by the scenario in
# tests/scenarios/hunt3-hall-detect.lua that names it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"
P = "hunt3-hall-detect: "

# 1: the switch hidden by the buff's own tick although the pin offers it.
mutate("Options/Who.lua",
       "\t\t\t\t\tif ns.PinnedBuff() ~= nil then return false end\n",
       "",
       "hunt3-hall-detect: the passers-by switch hidden under a pin of its own buff",
       expect=P + "pinned and never ticked, Detect Invisibility's passers-by switch is in reach", script=S)

# 2: memory never asks the switch.
mutate("Queue.lua",
       "\tif memo.buff.membersOnly and not ns.PassersToo(memo.buff) then return false end\n",
       "",
       "hunt3-hall-detect: somebody remembered keeps a buff held to the group again",
       expect=P + "the switch unticked, somebody remembered with Detect Invisibility is let go", script=S)

# 3: the class is not asked.
mutate("Hall.lua",
       "\t\tand (type(row.class) ~= \"string\" or Same(row.class, who.class))\n",
       "",
       "hunt3-hall-detect: a namesake of another class is the listed character",
       expect=P + "a namesake of another class is not the listed character", script=S)

# And a row that says no class matches nobody.
mutate("Hall.lua",
       "\t\tand (type(row.class) ~= \"string\" or Same(row.class, who.class))\n",
       "\t\tand Same(row.class, who.class)\n",
       "hunt3-hall-detect: a row with no class is nobody's",
       expect=P + "a namesake of another class is not the listed character", script=S)

# 4: the cut takes the player's own row with the rest.
mutate("Hall.lua",
       "\t\t\tcut = not IsMe(row, who)\n",
       "\t\t\tcut = true\n",
       "hunt3-hall-detect: the player's own row is cut with the rest",
       expect=P + "a listed player past the list's cut still finds their own row", script=S)

# 5: the invitation points at a code that is not there.
mutate("Hall.lua",
       "\tif done and Hall.Code() == nil then return TEXT.NOCODE end\n",
       "",
       "hunt3-hall-detect: invited to copy a code there is none of",
       expect=P + "every milestone and no code to give, the section says so and chat says nothing", script=S)

mutate("Hall.lua",
       "\tif Hall.Code() == nil then return end\n",
       "",
       "hunt3-hall-detect: chat says where a code is that there is none of",
       expect=P + "every milestone and no code to give, the section says so and chat says nothing", script=S)
