# Mutations for the choice that offers Unending Breath to everybody
# (buff.unasked; Core.lua, Castable; Options/Who.lua; Layout.lua). Caught by
# the scenario "audit-right-buff: Offer Unending Breath to everybody near me
# puts it back on the walk" in tests/scenarios/audit-right-buff.lua.

S = "runscenarios.py"
ONE = "audit-right-buff: Offer Unending Breath to everybody near me puts it back on the walk"

mutate("Core.lua",
       "\t\t\tif not (everybody and everybody[buff.key]) then return false end\n",
       "\t\t\tif true then return false end\n",
       "unaskedbreath: the choice never read",
       expect="with the choice on it is offered", script=S)

mutate("Core.lua",
       "\t\t\tif not (everybody and everybody[buff.key]) then return false end\n",
       "\t\t\tif not everybody then return false end\n",
       "unaskedbreath: any buff of the kind goes to everybody once one is ticked",
       expect="with the choice off", script=S)

mutate("Core.lua",
       "\tif type(profile.buff.unasked) ~= \"table\" then profile.buff.unasked = {} end\n",
       "",
       "unaskedbreath: a damaged choice kept",
       expect="a damaged choice was left", script=S)

mutate("Commands.lua",
       "\t\t\t\t\t\t\tor name == \"buff.unasked\"\n",
       "",
       "unaskedbreath: the choice does not travel with a profile",
       expect="the export does not carry the choice", script=S)

mutate("Options/Who.lua",
       "\t\t\t\t\tB().unasked[buff.key] = value and true or nil\n",
       "\t\t\t\t\tB().unasked[buff.key] = nil\n",
       "unaskedbreath: the switch writes nothing",
       expect="ticking it wrote", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\tif buff.returnOnly then items[#items + 1] = { \"who.unasked_\" .. tostring(buff.key), indent = true } end\n",
       "",
       "unaskedbreath: the switch not placed on the page",
       expect="unasked_breath", script=S)
