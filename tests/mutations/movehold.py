# Mutations for the hold on the move being the player's call (GitHub issue 31):
# ownBuffs.holdMoving gates CutByMoving (Core.lua) and has a switch under My own
# buffs. Each is caught by the scenario in tests/scenarios/movehold.lua that
# names it.

S = "runscenarios.py"

ON = "movehold: on by default, food waits while you move"
OFF = "movehold: off, food stays on the prompt while you move"
SITS = "movehold: the switch sits on My own buffs, for a class with nothing for others too"

mutate("Core.lua",
       "\t\tif db and db.profile.ownBuffs.holdMoving == false then return false end\n",
       "",
       "movehold: the gate is gone, the switch changes nothing",
       expect=OFF, script=S)

mutate("Core.lua",
       "\t\t\tholdMoving = true,\n",
       "\t\t\tholdMoving = false,\n",
       "movehold: the hold is off by default",
       expect=ON, script=S)

mutate("Modules/MyBuffs/Options.lua",
       "\t\t\t\t\tns.db.profile.ownBuffs.holdMoving = value == true\n",
       "\t\t\t\t\tns.db.profile.ownBuffs.holdMoving = true\n",
       "movehold: the switch cannot be turned off",
       expect=OFF, script=S)

mutate("Options/Who.lua",
       " or key == \"ownHoldMoving\"",
       "",
       "movehold: a hunter never sees the switch",
       expect=SITS, script=S)

mutate("Modules/MyBuffs/Layout.lua",
       "\t\t\t\t\t\"who.ownHoldMoving\",\n",
       "",
       "movehold: the switch is not in the layout",
       expect=SITS, script=S)

mutate("Options/Advanced.lua",
       " \"ownBuffs.holdMoving\",\n",
       "\n",
       "movehold: the reset leaves the switch alone",
       expect=SITS, script=S)
