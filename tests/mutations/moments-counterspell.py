# Mutations for Counterspell for the moment: tests/scenarios/moments-counterspell.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts one guard back to
# its absence and names the scenario that objects.

S = "runscenarios.py"

mutate("Prompt/Moments.lua",
       "\treturn (row.stop and \"/stopcasting\\n\" or \"\") .. \"/cast \" .. slot.name\n",
       "\treturn \"/cast \" .. slot.name\n",
       "moments-counterspell: the /stopcasting line is dropped",
       expect="moments-counterspell: the press stops your cast first", script=S)

mutate("Prompt/MomentsSense.lua",
       "\t\tinner:SetAlphaFromBoolean(rawA, 0, 1)\n",
       "\t\tinner:SetAlphaFromBoolean(rawA, 1, 0)\n",
       "moments-counterspell: the alphas of a hidden shield are swapped",
       expect="moments-counterspell: a hidden start value is handed to the game", script=S)

mutate("Prompt/MomentsSense.lua",
       "\tif issecretvalue(rawNotInt) then\n\t\tif CanPaint(\"not\") then",
       "\tif false then\n\t\tif CanPaint(\"not\") then",
       "moments-counterspell: a hidden notInterruptible is treated as plain",
       expect="moments-counterspell: a hidden start value is handed to the game", script=S)

mutate("Prompt/MomentsSense.lua",
       "\tif shape == \"nil\" then return \"yes\" end\n\tif shape ~= \"boolean\" then return \"blind\", \"whether it can be interrupted\" end\n",
       "",
       "moments-counterspell: the type check before the boolean paint is removed",
       expect="moments-counterspell: a hidden nil after a hidden boolean", script=S)

mutate("Prompt/Moments.lua",
       "local TARGET_CAST = { \"UNIT_SPELLCAST_START\", \"UNIT_SPELLCAST_STOP\", ",
       "local TARGET_CAST = { \"UNIT_SPELLCAST_START\", ",
       "moments-counterspell: the STOP event is not registered",
       expect="moments-counterspell: dark the instant the cast stops: UNIT_SPELLCAST_STOP", script=S)

mutate("Prompt/Moments.lua",
       "\t\"UNIT_SPELLCAST_CHANNEL_STOP\", \"UNIT_SPELLCAST_INTERRUPTED\", \"UNIT_SPELLCAST_FAILED\",",
       "\t\"UNIT_SPELLCAST_CHANNEL_STOP\", \"UNIT_SPELLCAST_FAILED\",",
       "moments-counterspell: the INTERRUPTED event is not registered",
       expect="moments-counterspell: dark the instant the cast stops: UNIT_SPELLCAST_INTERRUPTED", script=S)

mutate("Prompt/Moments.lua",
       "\t\t\tif slot and slot.armed and slot.needs.casting then slot.castOn, slot.flip, slot.reread = false, nil, true end\n\t\tend\n\t\tDarken(\"casting\", \"your target is not casting\")\n\t\treturn Schedule()",
       "\t\t\tif slot and slot.armed and slot.needs.casting then slot.flip, slot.reread = nil, true end\n\t\tend\n\t\tJudgeAll(\"casting\")\n\t\treturn Schedule()",
       "moments-counterspell: a stop event re-reads instead of going dark",
       expect="moments-counterspell: dark the instant the cast stops", script=S)

mutate("Prompt/Moments.lua",
       "\t\t\tif slot and slot.armed then slot.castOn, slot.flip = nil, nil end\n\t\tend\n\t\tJudgeAll(\"schoolhit\")\n\t\tJudgeAll(\"casting\")\n\t\treturn Schedule()\n\telseif CAST_STOP[event] then",
       "\t\t\tif slot and slot.armed then slot.castOn = nil end\n\t\tend\n\t\tJudgeAll(\"schoolhit\")\n\t\tJudgeAll(\"casting\")\n\t\treturn Schedule()\n\telseif CAST_STOP[event] then",
       "moments-counterspell: the flip is not cleared at a new cast",
       expect="moments-counterspell: NOT_INTERRUPTIBLE mid-cast", script=S)

mutate("Prompt/Moments.lua",
       "\tRegisterFight()\n\tif moveOn then WatchShow(now) end\n\tJudgeAll()\n\tSchedule()\n",
       "\tRegisterFight()\n\tif moveOn then WatchShow(now) end\n\tSchedule()\n",
       "moments-counterspell: the pull's first look is removed",
       expect="moments-counterspell: a cast under way at the pull lights it with no START", script=S)

mutate("Prompt/MomentsSense.lua",
       "\tif plain(check(slot.id, \"target\")) == false then return \"no\", \"out of range\" end\n",
       "",
       "moments-counterspell: range is ignored",
       expect="moments-counterspell: dark: out of range", script=S)

mutate("Prompt/MomentsSense.lua",
       "\tif usable == false then\n\t\tif noMana == true then",
       "\tif false then\n\t\tif noMana == true then",
       "moments-counterspell: usable is ignored",
       expect="moments-counterspell: dark: not enough mana", script=S)

mutate("Prompt/MomentsSense.lua",
       "\tif plain(UnitExists(\"target\")) ~= true then return \"no\", \"no target\" end\n",
       "",
       "moments-counterspell: a missing target is not checked",
       expect="moments-counterspell: dark: no target", script=S)

mutate("Prompt/MomentsSense.lua",
       "\tif type(UnitCanAttack) ~= \"function\" or plain(UnitCanAttack(\"player\", \"target\")) ~= true then return \"no\", \"your target is not hostile\" end\n",
       "",
       "moments-counterspell: a friendly target is not refused",
       expect="moments-counterspell: dark: a friendly target", script=S)

mutate("Prompt/MomentsSense.lua",
       "\tif plain(UnitIsDeadOrGhost(\"target\")) == true then return \"no\", \"your target is dead\" end\n",
       "",
       "moments-counterspell: a dead target is not refused",
       expect="moments-counterspell: dark: a dead target", script=S)

mutate("Prompt/MomentsData.lua",
       "ranks = { 2139 }, stop = true, guard = \"twice\", blind = \"weak\", cooldown = 30,",
       "ranks = { 2139 }, stop = true, guard = \"twice\", cooldown = 30,",
       "moments-counterspell: Counterspell is not weak when the flag has no route",
       expect="moments-counterspell: hidden with no boolean call", script=S)

mutate("Prompt/Moments.lua",
       "\t\tif slot.pressSerial == serial and not slot.went then",
       "\t\tif false then",
       "moments-counterspell: a press that sent nothing is not said",
       expect="moments-counterspell: pressed lit and nothing went out is said on the trail", script=S)

mutate("Prompt/MomentsSense.lua",
       "\tif slot.castOn == false then return \"no\", \"your target is not casting\" end\n",
       "",
       "moments-counterspell: a stop event no longer overrides a stale read",
       expect="moments-counterspell: dark the instant the cast stops", script=S)

mutate("Prompt/Moments.lua",
       "\telseif event == \"UNIT_SPELLCAST_FAILED\" then\n\t\treturn JudgeAll(\"casting\")",
       "\telseif event == \"UNIT_SPELLCAST_FAILED\" then\n\t\treturn Darken(\"casting\", \"failed\")",
       "moments-counterspell: a FAILED darkens a cast that is still running",
       expect="moments-counterspell: a FAILED with the cast still running leaves it lit", script=S)
