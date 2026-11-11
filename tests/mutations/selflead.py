# Mutations for "Remind me this many minutes early" (filters.selfLead), exact
# from 1.11.15 (Core.lua, SelfEarlier). Each is caught by the scenario in
# tests/scenarios/selflead.lua that names it.

S = "runscenarios.py"

mutate("Core.lua",
       "\t\tif seconds and seconds >= 1 and want > seconds / 2 then want = seconds / 2 end\n\t\treturn want\n",
       "\t\tif seconds and seconds >= 1 and want > seconds / 2 then want = seconds / 2 end\n\t\tif want > lead then return want end\n\t\treturn lead\n",
       "selflead: only ever earlier, as before 1.11.15",
       expect="selflead: half a minute is half a minute, later than the worked-out moment", script=S)

mutate("Core.lua",
       "\t\tif type(minutes) ~= \"number\" or not (minutes > 0) then return lead end\n",
       "\t\tif type(minutes) ~= \"number\" or not (minutes >= 1) then return lead end\n",
       "selflead: half a minute read as none",
       expect="selflead: half a minute is half a minute, later than the worked-out moment", script=S)

mutate("Core.lua",
       "\t\tif type(minutes) ~= \"number\" or not (minutes > 0) then return lead end\n",
       "\t\tif type(minutes) ~= \"number\" then return lead end\n",
       "selflead: 0 read as a moment of its own",
       expect="selflead: 0 is the worked-out moment, as before", script=S)

mutate("Core.lua",
       "\tprofile.filters.selfLead = math.floor(profile.filters.selfLead * 2) / 2\n",
       "\tprofile.filters.selfLead = math.floor(profile.filters.selfLead)\n",
       "selflead: a half minute rounded away",
       expect="selflead: the slider goes in half minutes and a hand-edited value is kept to them", script=S)

mutate("Core.lua",
       "\tprofile.filters.selfLead = math.floor(profile.filters.selfLead * 2) / 2\n",
       "",
       "selflead: a hand-edited value kept as it is",
       expect="selflead: the slider goes in half minutes and a hand-edited value is kept to them", script=S)

mutate("Options/When.lua",
       "\t\t\t\tmax = 10,\n\t\t\t\tstep = 0.5,\n",
       "\t\t\t\tmax = 10,\n\t\t\t\tstep = 1,\n",
       "selflead: the slider in whole minutes",
       expect="selflead: the slider goes in half minutes and a hand-edited value is kept to them", script=S)
