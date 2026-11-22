# Mutations for the trail's line about a loss of control (Prompt/BreakFree.lua).
# Each is caught by the scenario in tests/scenarios/loc-trail.lua that names it.

S = "runscenarios.py"
BF = "Prompt/BreakFree.lua"

mutate(BF,
       "if not (lastLoss and lastLoss.kind == k and lastLoss.how == h and GetTime() - lastLoss.at < SAME_LOSS) then",
       "if true then",
       "loc-trail: every report of a loss of control is a line",
       expect="loc-trail: one loss of control told twice is one trail line", script=S)

mutate(BF,
       "local SAME_LOSS = 0.5",
       "local SAME_LOSS = 5",
       "loc-trail: two losses a second apart are one line",
       expect="loc-trail: two losses a second apart are two lines", script=S)

mutate(BF,
       "if type(who) == \"string\" and who ~= \"player\" then return end",
       "if false then return end",
       "loc-trail: another unit's loss of control is taken as yours",
       expect="loc-trail: a loss of control on another unit writes nothing and lights nothing", script=S)

mutate(BF,
       "if lit then return \"lit\" end",
       "if false then return \"lit\" end",
       "loc-trail: the line never says the button lit",
       expect="loc-trail: the line says break free was lit", script=S)
