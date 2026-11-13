# Mutations for the fixes of the "right buff" audit. Each undoes one fix and is
# caught by the scenario in tests/scenarios/audit-right-buff.lua that found it.

S = "runscenarios.py"
P = "audit-right-buff: "

ORDER = P + "a party member with nothing waits behind the first member's second and third buffs"
UNREAD = P + "somebody whose buffs cannot be read is ranked ahead of somebody read as missing the buff"
TOPUP = P + "your own top-up is ranked ahead of a party member with nothing"

# ------------------------------------------------- the order inside a tier
# Name order again, whatever buff it is for: the first of the party gets every
# buff before the second gets one.
mutate("Queue.lua",
       "\t\tif aPlace ~= bPlace then return aPlace < bPlace end\n",
       "\t\tif false then return aPlace < bPlace end\n",
       "audit-right-buff: the queue is not ordered by the buff's place in the walk",
       expect=ORDER, script=S)

# The prompt keeps whoever it is on through every tie of the tier, as before.
mutate("Prompt/Hold.lua",
       "\t\t\t\tif candidate.priority == top.priority and not WorseOffer(candidate, top) then return candidate end\n",
       "\t\t\t\tif candidate.priority == top.priority then return candidate end\n",
       "audit-right-buff: the prompt stays on somebody for their second buff",
       expect=ORDER, script=S)

# A guess ahead of a certain gap.
mutate("Queue.lua",
       "\t\tif aReading ~= bReading then return aReading < bReading end\n",
       "\t\tif false then return aReading < bReading end\n",
       "audit-right-buff: the queue is not ordered by the reading",
       expect=UNREAD, script=S)

# Your own top-up ahead of your group again.
mutate("Queue.lua",
       "\tif has == true then entry.priority = PRIORITY.group end\n",
       "\tif false then entry.priority = PRIORITY.group end\n",
       "audit-right-buff: your own top-up outranks the group",
       expect=TOPUP, script=S)

SHADOW = P + "Shadow Protection is walked for everybody, you included, on a fresh profile"
BREATH = P + "Unending Breath is offered on dry land to the group and to passers-by"
BUFFPLS = P + "'buff pls' from a warrior is answered with Divine Spirit"

# ------------------------------------------- what is walked without asking
# Shadow Protection walked for everybody on a fresh profile again.
mutate("Buffs.lua",
       "\t\t\t-- every ten minutes. Forever's copy and Burning Crusade's are the same.\n\t\t\toptIn = true,\n",
       "\t\t\t-- every ten minutes. Forever's copy and Burning Crusade's are the same.\n",
       "audit-right-buff: Shadow Protection is on until it is switched off",
       expect=SHADOW, script=S)

# Unending Breath walked for the group and passers-by again.
mutate("Buffs.lua",
       "\t\t\t-- walked for every party member and passer-by, every ten minutes.\n\t\t\treturnOnly = true,\n",
       "\t\t\t-- walked for every party member and passer-by, every ten minutes.\n",
       "audit-right-buff: Unending Breath is not kept for favours and requests",
       expect=BREATH, script=S)

mutate("Core.lua",
       "\t\tif buff.returnOnly and not (opts.owed or opts.asked) then return false end\n",
       "",
       "audit-right-buff: a buff kept for favours is offered unasked",
       expect=BREATH, script=S)

# ...and one that takes the favour's return with it.
mutate("Core.lua",
       "\t\tif buff.returnOnly and not (opts.owed or opts.asked) then return false end\n",
       "\t\tif buff.returnOnly and not opts.asked then return false end\n",
       "audit-right-buff: a buff kept for favours does not return one",
       expect=BREATH, script=S)

# The favour's own way onto the prompt, with no token, forgets it is a favour.
mutate("Queue.lua",
       "\t\t\t-- returnOnly).\n\t\t\towed = true,\n",
       "\t\t\t-- returnOnly).\n",
       "audit-right-buff: a favour with no token is not told to the walk",
       expect=BREATH, script=S)

# "Buff pls" lifts "Only buffs they can use" again.
mutate("Queue.lua",
       "\t\t\topts.relevantOnly = f.relevantOnly\n\t\t\topts.tanksOnly = tanksHeld\n",
       "\t\t\topts.tanksOnly = tanksHeld\n",
       "audit-right-buff: buff pls is answered with a buff of no use to them",
       expect=BUFFPLS, script=S)

LOW = P + "a buff none of whose ranks can land on somebody that low is offered anyway"
HELD = P + "a blessing the game said cannot land holds every other blessing off for ten minutes"
BYNAME = P + "a favour returned by name alone casts the top rank at a giver too low for it"

# ------------------------------------------------- too low a level for it
# A buff offered to somebody none of its ranks can land on.
mutate("Core.lua",
       "\t\tif buff.lowLevel and opts.targetLevel and opts.targetLevel + 10 < buff.lowLevel then return false end\n",
       "",
       "audit-right-buff: a buff out of a low level's reach is offered",
       expect=LOW, script=S)

# The walk never says what level they are.
mutate("Queue.lua",
       "\t\topts.targetLevel = level\n",
       "\t\topts.targetLevel = nil\n",
       "audit-right-buff: the walk does not read anybody's level",
       expect=LOW, script=S)

# No buff knows the level its lowest rank is learned at.
mutate("Buffs.lua",
       "\t\t\t\tif low and low > 11 then buff.lowLevel = low end\n",
       "",
       "audit-right-buff: no buff has a lowest level",
       expect=LOW, script=S)

# The ten-minute hold on one blessing read as "offered a moment ago, wait".
mutate("Core.lua",
       "\t\t\tif lifts and lifts > (opts.now or GetTime()) then return false end\n",
       "\t\t\tif false then return false end\n",
       "audit-right-buff: a blessing held off as refused holds the others with it",
       expect=HELD, script=S)

# The favour's own way onto the prompt casts the plain name, the top rank.
mutate("Prompt/Macro.lua",
       "\t\tif not unit and levels and type(entry.level) == \"number\" and entry.level >= 1 then\n",
       "\t\tif false then\n",
       "audit-right-buff: a favour with no token is cast at the top rank",
       expect=BYNAME, script=S)

mutate("Queue.lua",
       "\t\t\t\t\t\tif entry.level then queue[#queue].level = entry.level end\n",
       "",
       "audit-right-buff: the favour's level does not reach its entry",
       expect=BYNAME, script=S)
