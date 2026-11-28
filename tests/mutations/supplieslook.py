# Mutations for the consumables button wearing its look (Prompt/Supplies.lua,
# Wear; Looks/Painted.lua, Painted.Socket). Each is caught by the scenario in
# tests/scenarios/suppliesLook.lua that names it.

S = "runscenarios.py"

mutate("Modules/MyBuffs/Supplies.lua",
       "\tif d and Painted and Painted.Socket and (not earlier",
       "\tif false and d and Painted and Painted.Socket and (not earlier",
       "supplieslook: never wears a socket",
       expect="supplieslook: the button wears the look's socket", script=S)

mutate("Modules/MyBuffs/Supplies.lua",
       "(not earlier or (look and look.paintedOnly))",
       "true",
       "supplieslook: earlier art draws the socket too",
       expect="supplieslook: earlier art leaves it plain", script=S)

mutate("Modules/MyBuffs/Supplies.lua",
       "(not earlier or (look and look.paintedOnly))",
       "(not earlier)",
       "supplieslook: a painted-only look loses its socket under earlier art",
       expect="supplieslook: a painted-only look stays painted", script=S)

mutate("Modules/MyBuffs/Supplies.lua",
       "\tif style == woreStyle and earlier == woreEarlier and size == woreSize then return end",
       "\tif earlier == woreEarlier and size == woreSize then return end",
       "supplieslook: a new look is not noticed",
       expect="supplieslook: a new look reaches the button", script=S)

mutate("Modules/MyBuffs/Supplies.lua",
       "\tif style == woreStyle and earlier == woreEarlier and size == woreSize then return end",
       "\tif false then return end",
       "supplieslook: the socket is redrawn on every scan",
       expect="supplieslook: an idle scan redraws nothing", script=S)

mutate("Modules/MyBuffs/Supplies.lua",
       "\tif round and mask then",
       "\tif false and round and mask then",
       "supplieslook: the icon is never rounded",
       expect="supplieslook: a round socket rounds the icon", script=S)

mutate("Looks/Painted.lua",
       "(d.above + s.y - h) / tall * l.b,",
       "(s.y - h) / tall * l.b,",
       "supplieslook: the socket is cut from the wrong height",
       expect="supplieslook: the button wears the look's socket", script=S)

mutate("Modules/MyBuffs/Supplies.lua",
       "\tWear(db)\n\tplate:SetShown(moving)\n",
       "\tplate:SetShown(moving)\n",
       "supplieslook: the drag placeholder does not wear the look",
       expect="supplieslook: the button wears the look's socket", script=S)
