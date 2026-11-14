# Mutations for the line said once when resting holds your own buffs back
# (Hints.lua). Caught by tests/scenarios/resting-hint.lua.

S = "runscenarios.py"

mutate("Hints.lua",
       "\tif ns.MyselfHeldBack(db.profile, now) ~= \"resting\" then return false end\n",
       "",
       "resting-hint: said wherever you are",
       expect="said out in the world, where nothing is held back", script=S)

mutate("Hints.lua",
       "\tif ns.MyselfHeldBack(db.profile, now) ~= \"resting\" then return false end\n",
       "\tif ns.MyselfHeldBack(db.profile, now) == nil then return false end\n",
       "resting-hint: said for any hold, Myself off included",
       expect="said with Myself switched off", script=S)

mutate("Hints.lua",
       "\tif not SomethingOfYours(db.profile, now) then return false end\n",
       "",
       "resting-hint: said with nothing of yours missing",
       expect="said with nothing of yours missing", script=S)

mutate("Hints.lua",
       "\tif type(hints) == \"table\" and hints.resting then return false end\n",
       "",
       "resting-hint: said at every login",
       expect="said a second time to the same character", script=S)

mutate("Hints.lua",
       "\thints.resting = true\n\tns.addon:Print",
       "\tns.addon:Print",
       "resting-hint: the once never written down",
       expect="said a second time to the same character", script=S)

mutate("Hints.lua",
       "\t\t\"|cffffd100\" .. L[\"Also in cities and inns\"] .. \"|r\", \"|cffffd100\" .. L[\"Who to buff\"] .. \"|r\"))\n",
       "\t\t\"|cffffd100\" .. L[\"Also in cities and inns\"] .. \"|r\", \"\"))\n",
       "resting-hint: the page not named",
       expect="the line does not say which page the switch is on", script=S)

mutate("Hints.lua",
       "\t\tif ns.OwnVerdict(family, ctx) then return true end\n",
       "\t\tif ns.OwnVerdict(family, ctx) == nil then return true end\n",
       "resting-hint: missing read the wrong way round",
       expect="resting with tracking off, the line was not said", script=S)
