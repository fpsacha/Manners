# Mutations for somebody too far for the spell where its range check says
# nothing (Core.lua PastFollowReach and ReachNow, Queue.lua BuildQueue and
# NoteRefusal). Each is caught by the scenario in tests/scenarios/range-follow.lua
# that names it.

S = "runscenarios.py"

mutate("Queue.lua",
       "\t\tif ranged == nil then ranged = ns.PastFollowReach(unit) end\n",
       "",
       "range-follow: the scan never asks the follow prompt",
       expect="range-follow: past the follow prompt is not offered", script=S)

mutate("Core.lua",
       "\tif ranged == nil then ranged = ns.PastFollowReach(unit) end\n\treturn ranged\n",
       "\treturn ranged\n",
       "range-follow: the press never asks the follow prompt",
       expect="range-follow: the press hears it too", script=S)

mutate("Core.lua",
       "\tif InCombatLockdown() or type(_G.CheckInteractDistance) ~= \"function\" then return nil end\n\tlocal follow = plain(_G.CheckInteractDistance(unit, 4))\n\tif follow ~= nil and follow ~= true",
       "\tif type(_G.CheckInteractDistance) ~= \"function\" then return nil end\n\tlocal follow = plain(_G.CheckInteractDistance(unit, 4))\n\tif follow ~= nil and follow ~= true",
       "range-follow: the follow prompt asked in a fight",
       expect="range-follow: nothing is asked of the follow prompt in a fight", script=S)

mutate("Core.lua",
       "\tif ns.Flavour.flavour ~= \"camelot\" then return nil end\n\tif InCombatLockdown()",
       "\tif InCombatLockdown()",
       "range-follow: every client asks the follow prompt",
       expect="range-follow: only WoW Forever asks the follow prompt", script=S)

mutate("Core.lua",
       "\tif follow ~= nil and follow ~= true and follow ~= 1 then return false end\n\treturn nil\n",
       "\tif follow ~= true and follow ~= 1 then return false end\n\treturn nil\n",
       "range-follow: the follow prompt's silence read as far",
       expect="range-follow: the follow prompt's silence is still offered", script=S)

mutate("Queue.lua",
       "\t\tif seconds < OUT_OF_RANGE_SECONDS and OneOf(why, OUT_OF_RANGE) then seconds = OUT_OF_RANGE_SECONDS end\n",
       "",
       "range-follow: out of range backs off two seconds",
       expect="range-follow: refused out of range stays off the prompt", script=S)

mutate("Queue.lua",
       "if seconds < OUT_OF_RANGE_SECONDS and OneOf(why, OUT_OF_RANGE) then",
       "if seconds < OUT_OF_RANGE_SECONDS then",
       "range-follow: every refusal backs off ten seconds",
       expect="range-follow: refused out of range stays off the prompt", script=S)
