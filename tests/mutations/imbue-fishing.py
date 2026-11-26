# Mutations for a shaman's weapon imbue with a fishing pole in the main hand
# (GitHub issue 56): Core.lua's OwnVerdict holds the imbue back while the hand
# holds weapon subclass 20. Caught by tests/scenarios/imbue-fishing.lua.

S = "runscenarios.py"

mutate("Core.lua",
       "\t\telseif family.imbue and HandWeapon(family.slot or 16) == 20 then\n",
       "\t\telseif false then\n",
       "imbue-fishing: an imbue offered for a fishing pole",
       expect="imbue-fishing: a fishing pole in the main hand is not offered an imbue", script=S)

mutate("Core.lua",
       "\t\telseif family.imbue and HandWeapon(family.slot or 16) == 20 then\n",
       "\t\telseif family.imbue then\n",
       "imbue-fishing: every weapon held back from its imbue",
       expect="imbue-fishing: a mace in the main hand is still offered its imbue", script=S)
