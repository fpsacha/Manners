# Mutations for the fixes in the favours area: a cast's cover ended by a death
# the walk never saw (Queue.lua, WatchGroupDeaths), and a Greater Blessing on a
# team-mate of another class (Clicks.lua, ClassReachesYou). Each is caught by
# the scenario in tests/scenarios/favours-fixes.lua that it names.

S = "runscenarios.py"

mutate("Queue.lua",
       "\t\t\tif ns.AnyCover() then ns.NoteSeenDead(plain(UnitGUID(unit)), now) end\n",
       "",
       "favours-fix: the tick's death watch ends no cover",
       expect="favours-fix: a team-mate who died while you were dead is offered again after the rez", script=S)

mutate("Queue.lua",
       "\t\t\t\tif plain(UnitIsDeadOrGhost(tokens[i])) == true then ns.NoteSeenDead(plain(UnitGUID(tokens[i])), now) end\n",
       "",
       "favours-fix: with just revived first off no death ends a cover",
       expect="favours-fix: a team-mate who died while you were dead is offered again after the rez (group members just revived first off)",
       script=S)

mutate("Clicks.lua",
       "\t\tif group and ns.GROUP_BY_CLASS[ns.PlayerClass()] == true then group = ClassReachesYou(to) end\n",
       "",
       "favours-fix: a Greater Blessing reaches you whatever the class",
       expect="favours-fix: a Greater Blessing on a team-mate of another class leaves your own reading as it was", script=S)
