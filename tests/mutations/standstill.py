# Mutations for nothing of your own on the run (1.11.30): food, a stone, an oil
# and every use with a cast wait until you stand still (Core.lua, Moving,
# NeedsStill and OwnVerdict's "moving"; Prompt/Hold.lua; Prompt/Supplies.lua;
# the moving events). Each is caught by the scenario in
# tests/scenarios/standstill.lua that names it.

S = "runscenarios.py"

WAITS = "standstill: food waits while you move and comes back once you stand still"
SECRET = "standstill: a speed the client keeps secret is read from the moving events"
JUMP = "standstill: a jump counts as moving"
PRESS = "standstill: a press made on the move eats nothing"
HOLD = "standstill: the hold lets go of food on the move"
FAMILIES = "standstill: which families wait for you to stand still, on every client"
BUTTON = "standstill: the consumables button uses nothing on the move"
EVENT = "standstill: starting to move takes the food off the prompt at once"
STONE = "standstill: a weapon stone waits on the move, a flask does not"
STALE = "standstill: a plain standing speed beats a stale moving event"

mutate("Core.lua",
       "\t\tif CutByMoving(family, spell, ctx.now or GetTime()) then return nil, up, left, \"moving\", spell end\n",
       "",
       "standstill: the verdict never holds anything back",
       expect=WAITS, script=S)

mutate("Core.lua",
       "\t\t\tmoving = stepping == true\n\t\telseif type(speed) == \"number\" then",
       "\t\t\tmoving = false\n\t\telseif type(speed) == \"number\" then",
       "standstill: a secret speed ignores the moving events",
       expect=SECRET, script=S)

mutate("Core.lua",
       "\t\tlocal speed\n\t\tif type(speedOf) == \"function\" then speed = speedOf(\"player\") end\n",
       "\t\tlocal speed = type(speedOf) == \"function\" and speedOf(\"player\") or nil\n",
       "standstill: the speed is tested for truth before issecretvalue sees it",
       expect=SECRET, script=S)

mutate("Core.lua",
       "\t\t\tmoving = speed > 0\n",
       "\t\t\tmoving = stepping == true or speed > 0\n",
       "standstill: a stale moving event beats a plain standing speed",
       expect=STALE, script=S)

mutate("Core.lua",
       "if falling == true or falling == 1 then moving = true end",
       "if false then moving = true end",
       "standstill: a jump is not moving",
       expect=JUMP, script=S)

mutate("Core.lua",
       "\tlocal STILL_HOLD = 1\n",
       "\tlocal STILL_HOLD = 0\n",
       "standstill: no hold past the last step",
       expect=WAITS, script=S)

mutate("Core.lua",
       "\t\treturn type(id) == \"number\" and CastMs(id) > 0\n",
       "\t\treturn false\n",
       "standstill: the client's cast time holds nothing",
       expect=FAMILIES, script=S)

mutate("Buffs.lua",
       "food = true, bagged = true, toggle = true, still = true,",
       "food = true, bagged = true, toggle = true,",
       "standstill: food is not flagged still",
       expect=WAITS, script=S)

mutate("Buffs.lua",
       "scroll = true, enhance = true, still = true, spells = spells,",
       "scroll = true, enhance = true, spells = spells,",
       "standstill: a weapon's stone is not flagged still",
       expect=STONE, script=S)

mutate("Prompt/Hold.lua",
       "\tif ns.StillCut(entry, now) then return true end\n",
       "",
       "standstill: the press and the fuse keep food on the move",
       expect=PRESS, script=S)

mutate("Prompt/Hold.lua",
       "\tif ns.StillCut(S.heldEntry, now) then return false end\n",
       "",
       "standstill: the hold keeps food on the move",
       expect=HOLD, script=S)

mutate("Modules/MyBuffs/Supplies.lua",
       "\tif ns.StillCut(current, _G.GetTime()) then\n",
       "\tif false then\n",
       "standstill: the consumables button presses on the move",
       expect=BUTTON, script=S)

mutate("Core.lua",
       "\tif Prompt and Prompt.state and ns.StillCut(Prompt.state.current, now) then ns.Guard(\"moving\", Prompt.Refresh, Prompt) end\n",
       "",
       "standstill: starting to move leaves the prompt as it was",
       expect=EVENT, script=S)

mutate("Core.lua",
       "\tns.NoteMoving(now, true)\n",
       "\tns.NoteMoving(now, false)\n",
       "standstill: the start of moving is noted as a stop",
       expect=SECRET, script=S)

mutate("Commands.lua",
       "\t\telseif why == \"moving\" then\n",
       "\t\telseif why == \"moving-x\" then\n",
       "standstill: the Myself lines do not say why",
       expect=WAITS, script=S)
