# Mutations for the choice that offers Unending Breath to everybody
# (buff.keptBack, what the player keeps for favours and requests; Core.lua,
# Castable; Options/Who.lua; Layout.lua). Caught by the scenarios "audit-right-buff:
# Unending Breath is offered on dry land..." and "audit-right-buff: Offer
# Unending Breath to everybody near me keeps it for favours when unticked" in
# tests/scenarios/audit-right-buff.lua.

S = "runscenarios.py"
ONE = "audit-right-buff: Offer Unending Breath to everybody near me keeps it for favours when unticked"

mutate("Core.lua",
       "\t\t\tif kept and kept[buff.key] then return false end\n",
       "\t\t\tif false then return false end\n",
       "unaskedbreath: the choice never read",
       expect="unticked, it is still offered", script=S)

mutate("Core.lua",
       "\t\t\tif kept and kept[buff.key] then return false end\n",
       "\t\t\tif true then return false end\n",
       "unaskedbreath: kept for favours whatever the choice",
       expect="by default it is offered to", script=S)

mutate("Core.lua",
       "\t\t\tkeptBack = {},\n",
       "\t\t\tkeptBack = { breath = true },\n",
       "unaskedbreath: kept for favours by default",
       expect="a new profile's buff.keptBack", script=S)

mutate("Core.lua",
       "\tif type(profile.buff.keptBack) ~= \"table\" then profile.buff.keptBack = {} end\n",
       "",
       "unaskedbreath: a damaged choice kept",
       expect="a damaged choice was left", script=S)

mutate("Commands.lua",
       "\t\t\t\t\t\t\tor name == \"buff.keptBack\"\n",
       "",
       "unaskedbreath: the choice does not travel with a profile",
       expect="the export does not carry the choice", script=S)

mutate("Options/Who.lua",
       "\t\t\t\t\tB().keptBack[buff.key] = (not value) or nil\n",
       "\t\t\t\t\tB().keptBack[buff.key] = nil\n",
       "unaskedbreath: unticking it writes nothing",
       expect="unticking it wrote", script=S)

mutate("Options/Who.lua",
       "\t\t\t\tget = function() return B().keptBack[buff.key] ~= true end,\n",
       "\t\t\t\tget = function() return B().keptBack[buff.key] == true end,\n",
       "unaskedbreath: the switch reads the wrong way",
       expect="the choice reads off on a new profile", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\tif buff.returnOnly then items[#items + 1] = { \"who.everyone_\" .. tostring(buff.key), indent = true } end\n",
       "",
       "unaskedbreath: the switch not placed on the page",
       expect="everyone_breath", script=S)
