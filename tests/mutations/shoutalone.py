# Mutations for a warrior's Battle Shout offered to himself when he is alone
# (Core.lua CastsOnSelf and HasShout, the default, Options/Who.lua). Each is
# caught by the scenario in tests/scenarios/shoutalone.lua that names it.

S = "runscenarios.py"

mutate("Core.lua",
       "\tif not (db and db.ownBuffs and db.ownBuffs.shoutAlone == true) then return false end\n",
       "\tif not db then return false end\n",
       "shoutalone: the switch is never read",
       expect="shoutalone: off by default, a warrior alone is not offered his shout", script=S)

mutate("Core.lua",
       "\treturn (plain(GetNumGroupMembers and GetNumGroupMembers()) or 0) == 0\nend\n",
       "\treturn true\nend\n",
       "shoutalone: offered inside a group too",
       expect="shoutalone: on, in a group the shout is not offered to him", script=S)

mutate("Core.lua",
       "\t\t\tshoutAlone = false,\n",
       "\t\t\tshoutAlone = true,\n",
       "shoutalone: on by default",
       expect="shoutalone: off by default, a warrior alone is not offered his shout", script=S)

mutate("Options/Who.lua",
       "\t\t\t\thidden = function() return not ns.HasShout() end,\n",
       "\t\t\t\thidden = false,\n",
       "shoutalone: every class is shown the switch",
       expect="shoutalone: a mage is not shown the switch", script=S)

mutate("Options/Who.lua",
       "\t\t\t\t\tns.db.profile.ownBuffs.shoutAlone = value == true\n",
       "\t\t\t\t\tns.db.profile.ownBuffs.shoutAlone = false\n",
       "shoutalone: the switch keeps nothing",
       expect="shoutalone: the switch is shown to a warrior and to nobody else", script=S)
