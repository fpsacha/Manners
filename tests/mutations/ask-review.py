# Mutations for the review of asking (Ask.lua and its hooks in Prompt/Press.lua
# and Commands.lua): what you wear is read afresh for a press, an ask the
# press's scan dropped is never said off the fuse, the arming refuses a buff
# now worn, another class's buff of the same kind is no blessing, a paste
# leaves how and where you ask alone while asking is on, and no cooldown holds
# back a press that casts nothing. Each is caught by the scenario in
# tests/scenarios/ask-review.lua that names it.

S = "runscenarios.py"
P = "Prompt/Press.lua"

LANDED = "ask-review: a buff that landed since the last scan is not asked for at the press"
FUSE = "ask-review: somebody the press's scan dropped is not whispered off the fuse"
ARM = "ask-review: the arming refuses an ask for a buff now worn"
MARK = "ask-review: mists: under a druid's Mark the paladin is asked for Might"
PASTE = "ask-review: a paste leaves how and where you ask alone while asking is on"
COOLDOWN = "ask-review: a press on an ask is not held back by the cooldown or a cast of your own"
ROW = "ask-review: an ask's name in the list is said during the cooldown"
ROW_LANDED = "ask-review: an ask's name in the list is not said for a buff that has just landed"

# The press's scan answers from a reading a moment old: the priest is asked
# for the Fortitude he has just given.
mutate(P,
       "\tns.Ask.ForgetWorn()\n\tlocal queue, verdicts = ns.BuildQueue(S.hovering)\n\tNoteVerdicts(verdicts)\n\tlocal top",
       "\tlocal queue, verdicts = ns.BuildQueue(S.hovering)\n\tNoteVerdicts(verdicts)\n\tlocal top",
       "ask-review: the press asks from a stale reading of what you wear",
       expect=LANDED, script=S)

# The same for a name in the list.
mutate(P,
       "\trow.preAt = now\n\tns.Ask.ForgetWorn()\n",
       "\trow.preAt = now\n",
       "ask-review: a name in the list asks from a stale reading of what you wear",
       expect=ROW_LANDED, script=S)

# The fuse keeps an ask under a press whose own scan dropped it: somebody
# gone away is whispered.
mutate(P,
       "\tif not top and S.current and S.current.ask then\n",
       "\tif false then\n",
       "ask-review: an ask the scan dropped said off the fuse",
       expect=FUSE, script=S)

# The arming never asks what you wear.
mutate("Ask.lua",
       "\t\tand not (wanted and Wearing(wanted, now) ~= false) then\n",
       "\t\tand true then\n",
       "ask-review: an ask armed for a buff now worn",
       expect=ARM, script=S)

# Another class's buff of the same kind counts as a blessing worn: no Might
# asked for beside a druid's Mark.
mutate("Ask.lua",
       "local worn = Wearing(buff, now, true)\n",
       "local worn = Wearing(buff, now)\n",
       "ask-review: a druid's Mark taken for a blessing",
       expect=MARK, script=S)

# A paste rewrites how and where an ask already on is said.
mutate("Commands.lua",
       "\t\t\telseif not own and asking and SHARE_ASK[field.name] then\n",
       "\t\t\telseif false then\n",
       "ask-review: a paste rewrites how and where you ask",
       expect=PASTE, script=S)

# Kept, and nothing said of it.
mutate("Commands.lua",
       "\t\tif kept.asking then\n",
       "\t\tif false then\n",
       "ask-review: how you ask kept through a paste without a word",
       expect=PASTE, script=S)

# The cooldown holds a press on an ask as it holds a cast.
mutate(P,
       "\tif not ready and not InCombatLockdown() and S.current and S.current.ask then\n",
       "\tif false then\n",
       "ask-review: an ask held back by the cooldown",
       expect=COOLDOWN, script=S)

# And a click on its name in the list.
mutate(P,
       "\tif entry.ask then ready = true end\n",
       "",
       "ask-review: an ask's name in the list held back by the cooldown",
       expect=ROW, script=S)
