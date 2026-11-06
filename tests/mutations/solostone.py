# Mutation for a weapon enhancement not being topped up early while alone
# (Core.lua, OwnVerdict). Caught by the stone scenario in hunt26-weapons.lua.

S = "runscenarios.py"

mutate("Core.lua",
       "\t\t\tlocal topUps = ctx.whenBuffed == \"refresh\"\n\t\t\t\tand not (family.enhance and (plain(GetNumGroupMembers and GetNumGroupMembers()) or 0) <= 0)\n",
       "\t\t\tlocal topUps = ctx.whenBuffed == \"refresh\"\n",
       "solostone: a stone is topped up early while alone",
       expect="hunt26-weapons: a bare hand is offered a stone, a hand with an enchant is not", script=S)

mutate("Core.lua",
       "\t\t\t\tand not (family.enhance and (plain(GetNumGroupMembers and GetNumGroupMembers()) or 0) <= 0)\n",
       "\t\t\t\tand not (family.enhance and true)\n",
       "solostone: a stone is never topped up early, in a group either",
       expect="hunt26-weapons: a bare hand is offered a stone, a hand with an enchant is not", script=S)
