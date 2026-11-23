# Mutations for Unending Breath offered to others only while swimming
# (Core.lua Castable and Swimming, Buffs.lua swimGate, Options/Who.lua's
# switch, Layout.lua, the reset and the export). Each is caught by the scenario
# in tests/scenarios/breath-swimonly.lua that names it.

S = "runscenarios.py"

mutate("Core.lua",
       "\t\t\tif only and only[buff.key] and not ns.Swimming(opts.now or GetTime()) then return false end\n",
       "",
       "breath-swimonly: the switch holds nothing back",
       expect="on dry land it is offered to", script=S)

mutate("Core.lua",
       "\t\tif buff.swimGate and not (opts.owed or opts.asked) then\n",
       "\t\tif buff.swimGate then\n",
       "breath-swimonly: a favour returned is held to the water too",
       expect="a favour should still be returned with Unending Breath", script=S)

mutate("Core.lua",
       "not ns.Swimming(opts.now or GetTime()) then return false end\n",
       "not (_G.IsSwimming and _G.IsSwimming()) then return false end\n",
       "breath-swimonly: no moment past the last stroke",
       expect="a second after the last stroke it is offered to", script=S)

mutate("Core.lua",
       "\tif type(profile.buff.swimOnly) ~= \"table\" then profile.buff.swimOnly = {} end\n",
       "",
       "breath-swimonly: a damaged set is never repaired",
       expect="a damaged choice was left as", script=S)

mutate("Options/Advanced.lua",
       "\"buff.keptBack\", \"buff.swimOnly\", \"buff.forClass\",",
       "\"buff.keptBack\", \"buff.forClass\",",
       "breath-swimonly: the page's reset leaves the choice",
       expect="Who to buff's reset left the swim choice on", script=S)

mutate("Commands.lua",
       "\t\t\t\t\t\t\tor name == \"buff.swimOnly\"\n",
       "",
       "breath-swimonly: the choice does not travel with a profile",
       expect="the export does not carry the choice", script=S)

mutate("Buffs.lua",
       "alone = true, switchable = true, swimGate = true },",
       "alone = true, switchable = true },",
       "breath-swimonly: no swim switch on Mists",
       expect="a warlock with Unending Breath has no swim switch", script=S)

mutate("Options/Who.lua",
       "\t\t\t\tget = function() return B().swimOnly[buff.key] == true end,\n",
       "\t\t\t\tget = function() return false end,\n",
       "breath-swimonly: the switch always reads off",
       expect="a moment after: ticking it wrote", script=S)
