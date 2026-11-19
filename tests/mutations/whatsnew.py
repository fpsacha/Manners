# What's new: the fold at the foot of Start here (tests/scenarios/whatsnew.lua).
S = "runscenarios.py"

mutate("Options/Start.lua",
       "\t\tlines[#lines + 1] = mark .. tostring(entry)\n",
       "",
       "whatsnew: a note that is its head alone",
       expect="lines under its head for", script=S)

mutate("Options/Start.lua",
       "\tlocal mark = Accent(section) .. \"\\194\\187|r \"\n",
       "\tlocal mark = \"- \"\n",
       "whatsnew: an entry behind a plain dash",
       expect="an entry does not start with a marker in its section's accent", script=S)

mutate("Options/Start.lua",
       "\t\t\t\tlocal title = Accent(section) .. tostring(section.title):upper() .. \"|r\"\n",
       "\t\t\t\tlocal title = \"|cffffd100\" .. tostring(section.title):upper() .. \"|r\"\n",
       "whatsnew: every section's title in the one gold",
       expect="the second section's title is not in its own accent", script=S)

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
       "\t\t\t\tblocks[#blocks + 1] = { head = title, body = table.concat(lines, \"\\n\") }\n",
       "\t\t\t\tblocks[#blocks + 1] = { head = head .. \" \" .. title, body = table.concat(lines, \"\\n\") }\n",
       "whatsnew: the version over every section of the newest release",
       expect="a section's head repeats the release's version", script=S)

mutate("Options/Start.lua",
       "if s == 1 then blocks[#blocks + 1] = { head = head, body = \"\", title = true } end",
       "if s == 1 then blocks[#blocks + 1] = { head = head, body = title, title = true } end",
       "whatsnew: text under the release's title line",
       expect="the release's title line has text under it", script=S)

mutate("Options/Start.lua",
       "\t\t\tfor _, section in ipairs(release.sections or {}) do Entries(lines, section) end\n\t\t\tblocks[#blocks + 1] = { head = head,",
       "\t\t\tblocks[#blocks + 1] = { head = head,",
       "whatsnew: an earlier release that is its version alone",
       expect="the release before the newest has 0 lines for", script=S)

mutate("Options/Window/Layout.lua",
       "{ key = \"general.news\", header = \"general.newsHeader\", fold = true, plain = true, items = {\n",
       "{ key = \"general.news\", header = \"general.newsHeader\", plain = true, items = {\n",
       "whatsnew: the notes unfolded on Start here",
       expect="general.newsNote1 is not folded", script=S)

mutate("WhatsNew.lua",
       "\t\t{ title = \"In a fight\", accent",
       "\t\t{ title = \"In a figh\", accent",
       "whatsnew: a section's title that is not the changelog's",
       expect="and the changelog says In a fight", script=S)

mutate("CHANGELOG.md",
       "### Highlights\n",
       "### In short\n",
       "whatsnew: a newest release that does not lead with its highlights",
       expect="does not start with its Highlights", script=S)

mutate("Options/Window/Layout.lua",
       "{ \"general.newsHead3\", lead = 3 }, \"general.newsNote3\",",
       "\"general.newsHead3\", \"general.newsNote3\",",
       "whatsnew: a head the size of its note",
       expect="general.newsHead3 is not drawn a size up from its note", script=S)

mutate("Options/Window/Layout.lua",
       "{ \"general.newsHead1\", lead = 8 }, \"general.newsNote1\",",
       "{ \"general.newsHead1\", lead = 3 }, \"general.newsNote1\",",
       "whatsnew: a release's title the size of a section's",
       expect="the release's title is no larger than a section's", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t[\"general.newsNote2\"] = { block = true },\n",
       "",
       "whatsnew: the highlights with no well round them",
       expect="the highlights are not set apart in a well", script=S)

mutate("Options/Window/Widgets.lua",
       "\tlocal up = layout.lead == true and 2 or tonumber(layout.lead) or 0\n",
       "\tlocal up = layout.lead and 2 or 0\n",
       "whatsnew: a lead's own number of points ignored",
       expect="a title's lead is drawn no larger than a plain lead", script=S)
