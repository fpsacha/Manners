# What's new: the fold at the foot of Start here (tests/scenarios/whatsnew.lua).
S = "runscenarios.py"

mutate("Options/Start.lua",
       "\t\tlines[#lines + 1] = \"- \" .. tostring(entry)\n",
       "",
       "whatsnew: a note that is its title alone",
       expect="lines under its title for", script=S)

mutate("Options/Start.lua",
       "\t\t\t\thidden = function() return #News.Sections() == 0 end,\n",
       "\t\t\t\thidden = function() return false end,\n",
       "whatsnew: the fold's header shown with nothing under it",
       expect="with no notes the fold still shows", script=S)

mutate("Options/Start.lua",
       "\treturn L[\"What's new in %s\"]:format(tostring(ns.BUILD or \"\"))\n",
       "\treturn L[\"What's new in %s\"]:format(\"\")\n",
       "whatsnew: the fold's title without the version",
       expect="the fold's title does not name this build", script=S)

mutate("Options/Window/Layout.lua",
       "{ key = \"general.news\", header = \"general.newsHeader\", fold = true, plain = true, items = {\n",
       "{ key = \"general.news\", header = \"general.newsHeader\", plain = true, items = {\n",
       "whatsnew: the notes unfolded on Start here",
       expect="general.newsNote1 is not folded", script=S)

mutate("WhatsNew.lua",
       "\t{ title = \"Profiles\", entries = {\n",
       "\t{ title = \"Profile\", entries = {\n",
       "whatsnew: a section's title that is not the changelog's",
       expect="and the changelog says Profiles", script=S)
