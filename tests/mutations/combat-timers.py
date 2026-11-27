# Guards around delayed callbacks in Manners: Combat.

S = "runscenarios.py"
CF = "Modules/Combat/CureFight.lua"
MP = "Modules/Combat/MendPet.lua"
BF = "Modules/Combat/BreakFree.lua"
T = "combat-timers: "

mutate(CF,
       "\t\tflushDue = false\n\t\tif Active() then ns.Guard(\"cure in a fight\", Flush) end\n",
       "\t\tflushDue = false\n\t\tns.Guard(\"cure in a fight\", Flush)\n",
       "combat-timers: the cure flush runs after suspension",
       expect=T + "the cure's delayed flush stops after suspension", script=S)

mutate(CF,
       "\t\tif Active() then\n\t\t\tslots[1].paintedKey, slots[2].paintedKey = nil, nil\n",
       "\t\tif true then\n\t\t\tslots[1].paintedKey, slots[2].paintedKey = nil, nil\n",
       "combat-timers: the cure recheck runs after suspension",
       expect=T + "the cure's delayed recheck stops after suspension", script=S)

mutate(MP,
       "\t\tpaintDue = false\n\t\tif Active() then ns.Guard(\"mend pet\", Paint) end\n",
       "\t\tpaintDue = false\n\t\tns.Guard(\"mend pet\", Paint)\n",
       "combat-timers: Mend Pet's repaint runs after suspension",
       expect=T + "Mend Pet callbacks stop after suspension", script=S)

mutate(MP,
       "\t\t\t\t\tif Active() then\n\t\t\t\t\t\tpaintedKey = nil\n",
       "\t\t\t\t\tif true then\n\t\t\t\t\t\tpaintedKey = nil\n",
       "combat-timers: Mend Pet's busy callback runs after suspension",
       expect=T + "Mend Pet callbacks stop after suspension", script=S)

mutate(BF,
       "\tif not Active() then return end\n",
       "",
       "combat-timers: break free rechecks after suspension",
       expect=T + "break-free rechecks stop after suspension", script=S)
