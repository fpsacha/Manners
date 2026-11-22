# Mutations for the Queue.lua fixes, each caught by the scenario in
# tests/scenarios/queue-fixes.lua that names it.

# The game's "a more powerful spell" arriving after the failed cast no longer
# ends the death's guess.
mutate("Queue.lua",
       "\t\t\tif not late.members and ns.IsPlayerName(name) and OneOf(message, BOUNCED) then ns.NoteCastSinceDeath(late.key) end\n",
       "",
       "late bounce leaves the death guessed",
       expect="queue-fix: a stronger one on you said after the failed cast still ends the guess",
       script="runscenarios.py")

# The death watch no longer ends a cover noted before the death.
mutate("Queue.lua",
       "\t\t\tif ns.AnyCover() then ns.NoteSeenDead(plain(UnitGUID(unit)), now) end\n",
       "",
       "death watch keeps the cover",
       expect="queue-fix: a team-mate who died while you were dead is offered your buff again",
       script="runscenarios.py")
