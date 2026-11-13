# Mutations for short buffs held back in a city or an inn
# (filters.quietShortInTowns and quietShortMinutes; Core.lua, Castable;
# Queue.lua; Options/Who.lua; Layout.lua). Caught by the scenario "audit-right-buff:
# short buffs are held back in a city or an inn, long ones still go".

S = "runscenarios.py"
ONE = "audit-right-buff: short buffs are held back in a city or an inn, long ones still go"

mutate("Core.lua",
       "\t\tif opts.shortHeld and not opts.asked then\n",
       "\t\tif false then\n",
       "cityshort: the held length never read",
       expect="in a city Thorns is still offered", script=S)

mutate("Core.lua",
       "\t\t\tif single and single > 0 and single <= opts.shortHeld then return false end\n",
       "\t\t\tif single and single > 0 then return false end\n",
       "cityshort: every buff with a length held",
       expect="Mark of the Wild is offered as", script=S)

mutate("Core.lua",
       "\t\t\tif single and single > 0 and single <= opts.shortHeld then return false end\n",
       "\t\t\tif single and single > 0 and single < opts.shortHeld then return false end\n",
       "cityshort: a buff of exactly the length not held",
       expect="short meaning an hour", script=S)

mutate("Queue.lua",
       "\tif f.quietShortInTowns == true and not inTown and Resting() == true then\n",
       "\tif f.quietShortInTowns == true and not inTown then\n",
       "cityshort: held out in the world too",
       expect="outside a city Thorns waits", script=S)

mutate("Queue.lua",
       "\tif f.quietShortInTowns == true and not inTown and Resting() == true then\n",
       "\tif false then\n",
       "cityshort: never held",
       expect="in a city Thorns is still offered", script=S)

mutate("Queue.lua",
       "\t\topts.shortHeld = (not pointed) and townShort or nil\n",
       "\t\topts.shortHeld = nil\n",
       "cityshort: the scan never hands the length on",
       expect="in a city Thorns is still offered", script=S)

mutate("Core.lua",
       "\t\t\tquietShortMinutes = 15,\n",
       "\t\t\tquietShortMinutes = 30,\n",
       "cityshort: the default length is half an hour",
       expect="the defaults are", script=S)

mutate("Core.lua",
       "\t{ \"filters\", \"quietShortMinutes\", 5, 60 },\n",
       "",
       "cityshort: the length not kept in range",
       expect="the length was left at", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t\"who.quietShortInTowns\",\n",
       "",
       "cityshort: the switch not placed on the page",
       expect="quietShortInTowns", script=S)
