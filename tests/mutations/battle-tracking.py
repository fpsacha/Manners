# Mutations for the tracking reminder held back in a battleground or an arena
# (Core.lua, ns.InBattleground and OwnVerdict's "battle"; Commands.lua's line
# for it). Caught by tests/scenarios/battle-tracking.lua.

S = "runscenarios.py"

mutate("Core.lua",
       "\t\tif family.tracking and ns.InBattleground() then return nil, nil, nil, \"battle\" end\n",
       "",
       "battle-tracking: tracking reminded in a battleground",
       expect="instance tracking is still offered", script=S)

mutate("Core.lua",
       "\t\tif family.tracking and ns.InBattleground() then return nil, nil, nil, \"battle\" end\n",
       "\t\tif ns.InBattleground() then return nil, nil, nil, \"battle\" end\n",
       "battle-tracking: every own buff held back in a battleground",
       expect="is held back in a battleground as tracking is", script=S)

mutate("Core.lua",
       "\t\treturn (inside == true or inside == 1) and (kind == \"pvp\" or kind == \"arena\")\n\tend\n\n\t-- What Automatic",
       "\t\treturn (inside == true or inside == 1) and (kind == \"pvp\")\n\tend\n\n\t-- What Automatic",
       "battle-tracking: an arena is not a battleground",
       expect="in a arena instance tracking is still offered", script=S)

mutate("Core.lua",
       "\t\treturn (inside == true or inside == 1) and (kind == \"pvp\" or kind == \"arena\")\n\tend\n\n\t-- What Automatic",
       "\t\treturn (inside == true or inside == 1)\n\tend\n\n\t-- What Automatic",
       "battle-tracking: a dungeon read as a battleground",
       expect="party is read as a battleground", script=S)

mutate("Core.lua",
       "\t\treturn (inside == true or inside == 1) and (kind == \"pvp\" or kind == \"arena\")\n\tend\n\n\t-- What Automatic",
       "\t\treturn (inside == true) and (kind == \"pvp\" or kind == \"arena\")\n\tend\n\n\t-- What Automatic",
       "battle-tracking: the game's 1 for inside not read",
       expect="the game's 1 for inside is not read as inside", script=S)

mutate("Core.lua",
       "\t\tlocal ask = _G.IsInInstance\n\t\tif type(ask) ~= \"function\" then return false end\n",
       "\t\tlocal ask = _G.IsInInstance\n\t\tif type(ask) ~= \"function\" then return true end\n",
       "battle-tracking: a battleground assumed with nothing to ask",
       expect="with no IsInInstance, a battleground is assumed", script=S)

mutate("Commands.lua",
       "\t\telseif why == \"battle\" then\n",
       "\t\telseif why == \"battle!\" then\n",
       "battle-tracking: the explanation has no line for it",
       expect="the explanation does not say tracking waits in a battleground", script=S)
