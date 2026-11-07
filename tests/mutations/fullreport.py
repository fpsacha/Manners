# Mutations for the full check-up (Options/Diagnostics.lua, ns.FullReport and its
# button). Each is caught by the scenario in tests/scenarios/fullreport.lua that
# names it.

S = "runscenarios.py"

mutate("Options/Diagnostics.lua",
       "\t\taddon.Print = real\n\t\tif not ok then error(err, 0) end\n",
       "\t\tif not ok then error(err, 0) end\n",
       "fullreport: the chat stays caught",
       expect="fullreport: the check-up holds every part", script=S)

mutate("Options/Diagnostics.lua",
       "\tSection(\"/manners debug\", function() Caught(function() addon:HandleSlash(\"debug\") end) end)\n",
       "",
       "fullreport: no debug in it",
       expect="fullreport: the check-up holds every part", script=S)

mutate("Options/Diagnostics.lua",
       "\treturn (tostring(text):gsub(\"|c%x%x%x%x%x%x%x%x\", \"\"):gsub(\"|r\", \"\"):gsub(\"||\", \"|\"))\n",
       "\treturn tostring(text)\n",
       "fullreport: colour codes left in",
       expect="fullreport: the check-up holds every part", script=S)

mutate("Options/Diagnostics.lua",
       "\t\t\t\t\tlocal text = ns.FullReport()\n\t\t\t\t\tif not (ns.ShowSelftestBox and ns.ShowSelftestBox(text)) then\n",
       "\t\t\t\t\tlocal text = ns.FullReport()\n\t\t\t\t\tif true then\n",
       "fullreport: the box is never filled",
       expect="fullreport: Diagnostics has the button, and it fills the box", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t{ \"diagnostics.fullReport\", big = true },\n",
       "",
       "fullreport: the button is not placed",
       expect="fullReport", script=S)

mutate("Options/Diagnostics.lua",
       "\t\ttext = text:gsub(name:gsub(\"[%^%$%(%)%%%.%[%]%*%+%-%?]\", \"%%%0\"), (alias[name]:gsub(\"%%\", \"%%%%\")))\n",
       "",
       "fullreport: names left in the check-up",
       expect="fullreport: the trail says what happened", script=S)

mutate("Core.lua",
       "\twhile #trail > TRAIL_MAX do table.remove(trail, 1) end\n",
       "",
       "fullreport: the trail grows without end",
       expect="fullreport: the trail says what happened", script=S)

mutate("Favours.lua",
       "\t\tns.Trail(\"favour\", (\"buffed you (spell %s, %s, %s)\"):format(tostring(seen.key),\n",
       "\t\tlocal _ = ((\"buffed you (spell %s, %s, %s)\"):format(tostring(seen.key),\n",
       "fullreport: a favour is not on the trail",
       expect="fullreport: the trail says what happened", script=S)

mutate("Prompt/Refresh.lua",
       "\tif isNew then\n\t\tns.Trail(\"prompt\"",
       "\tif false then\n\t\tns.Trail(\"prompt\"",
       "fullreport: the prompt's people are not on the trail",
       expect="fullreport: the trail says what happened", script=S)
