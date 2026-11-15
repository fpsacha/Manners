# What's new: the fold at the foot of Start here (tests/scenarios/whatsnew.lua).
S = "runscenarios.py"

mutate("Options/Start.lua",
       "\t\tlines[#lines + 1] = \"- \" .. tostring(entry)\n",
       "",
       "whatsnew: a note that is its head alone",
       expect="lines under its head for", script=S)

mutate("Options/Start.lua",
       "\t\t\t\thidden = function() return #News.Blocks() == 0 end,\n",
       "\t\t\t\thidden = function() return false end,\n",
       "whatsnew: the fold's header shown with nothing under it",
       expect="with no notes the fold still shows", script=S)

mutate("Options/Start.lua",
       "\treturn L[\"What's new in %s\"]:format(tostring(ns.BUILD or \"\"))\n",
       "\treturn L[\"What's new in %s\"]:format(\"\")\n",
       "whatsnew: the fold's title without the version",
       expect="the fold's title does not name this build", script=S)

mutate("Options/Start.lua",
       "\tif version:lower() == \"unreleased\" then version = tostring(ns.BUILD or \"\") end\n",
       "",
       "whatsnew: a release called Unreleased in the fold",
       expect="a release the changelog calls Unreleased is not named by this build", script=S)

mutate("Options/Start.lua",
       "\t\tif release.date then head = head .. \"  |cff9d9d9d\" .. tostring(release.date) .. \"|r\" end\n",
       "",
       "whatsnew: a release with no date beside its version",
       expect="the first note does not say when the newest release is from", script=S)

mutate("Options/Start.lua",
       "\t\t\t\tif s == 1 then lines[1] = head end\n",
       "\t\t\t\tlines[1] = head\n",
       "whatsnew: the version over every section of the newest release",
       expect="the second note repeats the release's version", script=S)

mutate("Options/Start.lua",
       "\t\t\tfor _, section in ipairs(release.sections or {}) do Entries(lines, section) end\n",
       "",
       "whatsnew: an earlier release that is its version alone",
       expect="the release before the newest has 0 lines for", script=S)

mutate("Options/Window/Layout.lua",
       "{ key = \"general.news\", header = \"general.newsHeader\", fold = true, plain = true, items = {\n",
       "{ key = \"general.news\", header = \"general.newsHeader\", plain = true, items = {\n",
       "whatsnew: the notes unfolded on Start here",
       expect="general.newsNote1 is not folded", script=S)

mutate("WhatsNew.lua",
       "\t\t{ title = \"Profiles\", entries = {\n",
       "\t\t{ title = \"Profile\", entries = {\n",
       "whatsnew: a section's title that is not the changelog's",
       expect="and the changelog says Profiles", script=S)

mutate("CHANGELOG.md",
       "### Highlights\n",
       "### In short\n",
       "whatsnew: a newest release that does not lead with its highlights",
       expect="does not start with its Highlights", script=S)
