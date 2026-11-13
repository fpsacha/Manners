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
