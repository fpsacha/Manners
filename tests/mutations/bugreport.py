# Report a bug (Options/BugReport.lua, tests/scenarios/bugreport.lua): each fault
# put back has to be caught by the scenario that names it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

NAMES = "bugreport: the link is percent-encoded and names nobody"
LIMIT = "bugreport: the link stays under 2000 characters"
STARTS = "bugreport: the report starts with the category and the words"
CAP = "bugreport: a report over the cap loses its oldest trail lines and says so"
FIGHT = "bugreport: in a fight the full report waits and the summary is offered"
SELECT = "bugreport: Select all highlights and focuses, Ctrl+C shows Copied"
ENTRY = "bugreport: every entry point opens the window"
OFFER = "bugreport: a new error offers Report it once a session, and the link opens the window"
FORM = "bugreport: the link's game and category match the issue form"

# The link is not percent-encoded: spaces and punctuation go in as they are.
mutate("Options/BugReport.lua",
       "\treturn (tostring(s):gsub(\"[^%w%-%._~]\", function(c) return (\"%%%02X\"):format(c:byte()) end))\n",
       "\treturn tostring(s)\n",
       "bugreport: the link is not encoded",
       expect=NAMES,
       script=S)

# Names stay in the link: nothing is scrubbed.
mutate("Options/BugReport.lua",
       "\tfor _, pair in ipairs(names) do text = ns.SwapName(text, pair[1], pair[2]) end\n",
       "",
       "bugreport: names are not scrubbed",
       expect=NAMES,
       script=S)

# The link is never shortened to fit.
mutate("Options/BugReport.lua",
       "\twhile #url > BR.URL_MAX and w ~= \"\" do\n",
       "\twhile false do\n",
       "bugreport: the link is never shortened",
       expect=LIMIT,
       script=S)

# A cut lands inside a letter.
mutate("Options/BugReport.lua",
       "\t\tif b and b >= 128 and b <= 191 then at = at - 1 else break end\n",
       "\t\tbreak\n",
       "bugreport: a cut lands inside a letter",
       expect=LIMIT,
       script=S)

# The report's opening lines are gone.
mutate("Options/BugReport.lua",
       "\t\t\"What went wrong: \" .. c.en,\n",
       "",
       "bugreport: the category is not in the report",
       expect=STARTS,
       script=S)

# The cap is never enforced by dropping the oldest of the trail.
mutate("Options/BugReport.lua",
       "\twhile #text > BR.CAP and skip < length do\n",
       "\twhile false do\n",
       "bugreport: the report is not cut by its oldest lines",
       expect=CAP,
       script=S)

# The full report is gathered in a fight.
mutate("Options/BugReport.lua",
       "\tif InCombatLockdown() then\n\t\t-- Nothing is gathered in a fight",
       "\tif false then\n\t\t-- Nothing is gathered in a fight",
       "bugreport: the full report is made in a fight",
       expect=FIGHT,
       script=S)

# Select all does not focus the box.
mutate("Options/BugReport.lua",
       "\tbox:SetFocus()\n\tbox:HighlightText()\n\thint:Show()\n",
       "\tbox:HighlightText()\n\thint:Show()\n",
       "bugreport: Select all does not focus",
       expect=SELECT,
       script=S)

# Copied shows on a plain C.
mutate("Options/BugReport.lua",
       "\tif key == \"C\" and (IsControlKeyDown()",
       "\tif key == \"C\" and (true or IsControlKeyDown()",
       "bugreport: Copied without Ctrl",
       expect=SELECT,
       script=S)

# The boxes can be typed in.
mutate("Options/BugReport.lua",
       "\t\tif userInput and self.fixed ~= nil then\n",
       "\t\tif false then\n",
       "bugreport: a box can be typed in",
       expect=SELECT,
       script=S)

# The footer button does nothing.
mutate("Options/Window/WindowChrome.lua",
       "\tfooter.bug = W.Button(foot, \"\", UI.Guarded(function() ns.BugReport.Show() end))\n",
       "\tfooter.bug = W.Button(foot, \"\", UI.Guarded(function() end))\n",
       "bugreport: the footer button opens nothing",
       expect=ENTRY,
       script=S)

# Diagnostics' button does nothing.
mutate("Options/Diagnostics.lua",
       "\t\t\t\tfunc = function() ns.BugReport.Show() end,\n",
       "\t\t\t\tfunc = function() end,\n",
       "bugreport: the Diagnostics button opens nothing",
       expect=ENTRY,
       script=S)

# The layout does not place the button.
mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t{ \"diagnostics.reportBug\", big = true },\n",
       "",
       "bugreport: the button is not placed",
       expect=ENTRY,
       script=S)

# ... nor the key for Mark this moment.
mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t\"diagnostics.markKey\",\n",
       "",
       "bugreport: the mark key is not placed",
       expect=ENTRY,
       script=S)

# The minimap menu has no entry.
mutate("Options/Launcher.lua",
       "\troot:CreateButton(L[\"Report a bug\"], Act(function() ns.BugReport.Show() end))\n",
       "",
       "bugreport: the minimap menu has no entry",
       expect=ENTRY,
       script=S)

# /manners report is not a word.
mutate("Commands.lua",
       "\telseif input == \"bug\" or input == \"report\" then\n",
       "\telseif input == \"bug\" then\n",
       "bugreport: /manners report is not a command",
       expect=ENTRY,
       script=S)

# An error offers the link every time.
mutate("Options/BugReport.lua",
       "\tif offered then return end\n\toffered = true\n",
       "\tif offered then return end\n",
       "bugreport: the link is offered every time",
       expect=OFFER,
       script=S)

# The link opens nothing.
mutate("Options/BugReport.lua",
       "\t\tif type(link) == \"string\" and link:find(\"^addon:Manners:report\") then\n",
       "\t\tif false then\n",
       "bugreport: the link does nothing",
       expect=OFFER,
       script=S)

# A fight's error offers the link at once.
mutate("Options/BugReport.lua",
       "\tif InCombatLockdown() then\n\t\tpending = true\n\t\treturn\n\tend\n",
       "",
       "bugreport: the link is offered in a fight",
       expect=OFFER,
       script=S)

# A game the form does not list.
mutate("Options/BugReport.lua",
       "\tmists = \"Mists of Pandaria Classic\",\n",
       "\tmists = \"Mists Classic\",\n",
       "bugreport: a game the form does not list",
       expect=FORM,
       script=S)

# In a fight the link and the summary are scrubbed of your name only, not the group's.
mutate("Options/BugReport.lua",
       "\tlocal aliases = FightAliases()\n",
       "\tlocal aliases = nil\n",
       "bugreport: a fight's link keeps a group member's name",
       expect="bugreport: in a fight a group member's name leaves the link and the summary",
       script=S)
