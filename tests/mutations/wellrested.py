# Mutations for Well-Rested (Buffs.lua REST, Core.lua ReadRested and BagBusy,
# OwnVerdict, Commands.lua, Options/Who.lua, the layout): the sleeping bag's
# family on Forever and Classic Era, off by default and unread until switched
# on, shown while the bag is in the bags, read by its aura's id, never at the
# level cap, in the bag, while it cools down or mounted. Each is caught by the
# scenario in tests/scenarios/wellrested.lua that names it (or layout.lua).

S = "runscenarios.py"

# --- the family ---

mutate("Buffs.lua",
       "for _, client in ipairs({ \"camelot\", \"vanilla\" }) do\n\tREST[client]",
       "for _, client in ipairs({ \"camelot\" }) do\n\tREST[client]",
       "wellrested: Classic Era has no bag",
       expect="wellrested: Forever and Classic Era give every class the family", script=S)

mutate("Buffs.lua",
       "\tfor _, family in ipairs({ FOOD[client] or false, REST[client] or false, PET[client] or false }) do\n",
       "\tfor _, family in ipairs({ FOOD[client] or false, PET[client] or false }) do\n",
       "wellrested: the family in no class's list",
       expect="wellrested: Forever and Classic Era give every class the family", script=S)

mutate("Buffs.lua",
       "\t\tfed = 429959, resting = 429960,\n",
       "\t\tfed = 429960, resting = 429960,\n",
       "wellrested: the tracking aura read for Well-Rested",
       expect="wellrested: Forever and Classic Era give every class the family", script=S)

# --- off until switched on ---

mutate("Core.lua",
       "\t\tif family.rest then defaults.profile.ownBuffs.pick[family.key] = \"off\" end\n",
       "",
       "wellrested: on by default",
       expect="wellrested: off by default", script=S)

# --- the reading ---

mutate("Core.lua",
       "\t\tif family.rest then return ReadRested(family, GetTime()) end\n",
       "",
       "wellrested: read as an aura of a spell you know",
       expect="wellrested: the bag in the bags and no Well-Rested is offered", script=S)

mutate("Core.lua",
       "\t\tlocal ok, aura = pcall(byId, \"player\", family.fed)\n\t\tif not ok or Withheld(aura) then return nil end\n",
       "\t\tlocal ok, aura = pcall(byId, \"player\", family.fed)\n\t\tif not ok then return nil end\n",
       "wellrested: a refused read taken as none",
       expect="wellrested: Well-Rested up, or no bag", script=S)

mutate("Core.lua",
       "\t\tlocal ok, aura = pcall(byId, \"player\", family.fed)\n\t\tif not ok or Withheld(aura) then return nil end\n\t\tif type(aura) == \"table\" then",
       "\t\tlocal ok, aura = pcall(byId, \"player\", family.fed)\n\t\tif not ok or Withheld(aura) then return nil end\n\t\tif false then",
       "wellrested: Well-Rested on you not seen",
       expect="wellrested: Well-Rested up, or no bag", script=S)

# --- when it is held back ---

mutate("Core.lua",
       "\t\t\tif type(level) == \"number\" and (level >= ns.MaxPlayerLevel() or ns.NoExperience(level)) then\n\t\t\t\treturn nil, up, left, \"maxlevel\", spell\n",
       "\t\t\tif false then\n\t\t\t\treturn nil, up, left, \"maxlevel\", spell\n",
       "wellrested: offered at the level cap",
       expect="wellrested: not at the level cap", script=S)

mutate("Core.lua",
       "\t\t\tif type(level) == \"number\" and (level >= ns.MaxPlayerLevel() or ns.NoExperience(level)) then\n\t\t\t\treturn nil, up, left, \"maxlevel\", spell\n",
       "\t\t\tif type(level) == \"number\" and (level >= ns.MaxPlayerLevel() - 1 or ns.NoExperience(level)) then\n\t\t\t\treturn nil, up, left, \"maxlevel\", spell\n",
       "wellrested: held back a level early",
       expect="wellrested: not at the level cap", script=S)

mutate("Core.lua",
       "\t\t\tif ok and type(aura) == \"table\" then return true end\n\t\t\tif ok and aura == nil",
       "\t\t\tif ok and aura == nil",
       "wellrested: offered while you lie in the bag",
       expect="wellrested: not at the level cap", script=S)

mutate("Core.lua",
       "\t\treturn type(start) == \"number\" and type(duration) == \"number\" and start > 0 and duration > 2\n",
       "\t\treturn false and type(start) == \"number\" and type(duration) == \"number\" and start > 0 and duration > 2\n",
       "wellrested: offered while the bag cools down",
       expect="wellrested: not at the level cap", script=S)

mutate("Core.lua",
       "\t\t\tif BagBusy(family, spell) then return nil, up, left, \"resting\", spell end\n"
       "\t\t\tif type(_G.IsMounted) == \"function\" and plain(_G.IsMounted()) == true then\n",
       "\t\t\tif BagBusy(family, spell) then return nil, up, left, \"resting\", spell end\n"
       "\t\t\tif false then\n",
       "wellrested: offered mounted",
       expect="wellrested: not at the level cap", script=S)

mutate("Commands.lua",
       "\t\t\treturn L[\"%s: you are resting in the bag, or it is cooling down.\"]:format(label)\n",
       "\t\t\treturn L[\"%s: the game will not say whether it is up, so it is not offered.\"]:format(label)\n",
       "wellrested: the debug line about the bag unsaid",
       expect="wellrested: not at the level cap", script=S)

mutate("Commands.lua",
       "\t\telseif why == \"mounted\" then\n",
       "\t\telseif false then\n",
       "wellrested: mounted said to be the game's refusal",
       expect="wellrested: not at the level cap", script=S)

# --- the page ---

mutate("Options/Who.lua",
       "\t\t\t\t\t\treturn not (type(n) == \"number\" and n > 0)\n",
       "\t\t\t\t\t\treturn true\n",
       "wellrested: the switch hidden with the bag in the bags",
       expect="wellrested: off by default", script=S)

mutate("Options/Who.lua",
       "\t\t\t\t\t\tif pick() ~= \"off\" then return false end\n",
       "",
       "wellrested: the switch hidden once on, with the bag gone",
       expect="wellrested: off by default", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t\"who.own_rested\",\n",
       "",
       "wellrested: the switch not placed on the page",
       expect="own_rested", script=S)
