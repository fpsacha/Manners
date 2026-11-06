# Mutations for the switch of a lone buff (Buffs.lua switchable, Options/Who.lua,
# the layout's list of controls). Each is caught by the scenario in
# tests/scenarios/loneswitch.lua that names it.

S = "runscenarios.py"

mutate("Buffs.lua",
       "\t\t\tneverSelf = true,\n\t\t\tswitchable = true,\n\t\t},\n\t},\n\n\tWARRIOR",
       "\t\t\tneverSelf = true,\n\t\t},\n\t},\n\n\tWARRIOR",
       "loneswitch: Unending Breath is not switchable on Burning Crusade",
       expect="loneswitch: Unending Breath is switchable on every client that has it", script=S)

mutate("Options/Who.lua",
       "\tif #buffs < 2 and not (buffs[1] and buffs[1].switchable) then return end\n",
       "\tif #buffs < 2 then return end\n",
       "loneswitch: a lone buff never has a switch",
       expect="loneswitch: a warlock's Unending Breath has a switch, and unticked nobody is offered it", script=S)

mutate("Options/Who.lua",
       "\tif #buffs < 2 and not (buffs[1] and buffs[1].switchable) then return end\n",
       "",
       "loneswitch: every lone buff has a switch",
       expect="loneswitch: a mage's lone Arcane Intellect has no switch", script=S)
