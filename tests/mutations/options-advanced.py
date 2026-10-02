# The Advanced group and the per-page reset (Options/Advanced.lua). Each fault
# is caught by the scenario in tests/scenarios/options-advanced.lua that names it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# --- put these back to default ---
#
# Re-anchored on the per-page reset (Page.RESET, Page.ResetPage): the old
# Advanced reset's seventeen fields are on When to offer's and Look's lists.

# The loop that copies the defaults skipped.
mutate("Options/Advanced.lua",
       "\t\tfor _, path in ipairs(list) do ResetField(path) end\n",
       "",
       "advanced: the reset puts nothing back",
       expect="when reset: filters.whenBuffed was not put back", script=S)

# One field left off the list.
mutate("Options/Advanced.lua",
       "\t\t\"prompt.reasonUnknown\", \"prompt.showIcon\",",
       "\t\t\"prompt.showIcon\",",
       "advanced: the reset forgets a wording",
       expect="look reset: prompt.reasonUnknown was not put back", script=S)

# The anchor swept up with the rest: where the prompt sits is kept.
mutate("Options/Advanced.lua",
       "\t\t\"sound.enabled\", \"sound.file\", \"sound.owedOnly\",\n",
       "\t\t\"sound.enabled\", \"sound.file\", \"sound.owedOnly\", \"prompt.point\",\n",
       "advanced: the reset leaves the anchor",
       expect="look reset: moved the prompt", script=S)

# A setting from another page swept up with this one.
mutate("Options/Advanced.lua",
       "\t\t\"filters.restoreTarget\",\n",
       "\t\t\"filters.restoreTarget\", \"prompt.scale\",\n",
       "advanced: the reset reaches another tab",
       expect="when reset: put back a setting from another page", script=S)

# A colour put back as the defaults' own table, which the picker then writes.
mutate("Options/Advanced.lua",
       "\t\tinto[name] = Copy(default)\n",
       "\t\tinto[name] = default\n",
       "advanced: the reset hands out the defaults' colour",
       expect="is the defaults' own table", script=S)

# Keeping favours switched on without the save its own setter runs.
mutate("Options/Advanced.lua",
       "\t\t\t-- ways of switching it on leave the file the same.\n\t\t\tns.addon:SaveDebts()\n",
       "\t\t\t-- ways of switching it on leave the file the same.\n",
       "advanced: the reset skips the favour save",
       expect="when reset: switched keeping favours back on without saving them", script=S)

# The scanner left on the old timings.
mutate("Options/Advanced.lua",
       "\t\t\tns.addon:SaveDebts()\n\t\t\trescan()\n",
       "\t\t\tns.addon:SaveDebts()\n",
       "advanced: the reset does not rescan",
       expect="when reset: the new timings were not handed to the scanner", script=S)

# The prompt left in the old wording and place.
mutate("Options/Advanced.lua",
       "\t\t\t-- this never touches the secure button mid-fight.\n\t\t\trestyleAndMacro()\n",
       "\t\t\t-- this never touches the secure button mid-fight.\n",
       "advanced: the reset does not restyle",
       expect="when reset: the prompt was not restyled and its macro rebuilt", script=S)

# ...or placed by hand, which moves the secure button in a fight.
mutate("Options/Advanced.lua",
       "\t\t\t-- this never touches the secure button mid-fight.\n\t\t\trestyleAndMacro()\n",
       "\t\t\t-- this never touches the secure button mid-fight.\n\t\t\trestyleAndMacro()\n"
       "\t\t\tns.Prompt:GetButton():ClearAllPoints()\n",
       "advanced: the reset moves the button in a fight",
       expect="reset in a fight called", script=S)

# Look's icon left past the prompt's size: the clamp its sliders run.
mutate("Options/Advanced.lua",
       "\t\t\tns.ClampSettings()\n\t\t\trestyleAndMacro()\n",
       "\t\t\trestyleAndMacro()\n",
       "advanced: the Look reset skips the clamp",
       expect="look reset: the icon was not held inside the prompt's size again", script=S)

# The page left showing the old values.
mutate("Options/Advanced.lua",
       "\t\tif list.after then list.after() end\n\t\tns.RefreshOptionsDisplay()\n",
       "\t\tif list.after then list.after() end\n",
       "advanced: the reset does not redraw",
       expect="when reset: the page still shows the old values", script=S)

# No question before resetting.
mutate("Options/Advanced.lua",
       "\t\t\t\tconfirm = function()\n\t\t\t\t\taskedFor = ns.OptionsTab()\n\t\t\t\t\treturn true\n\t\t\t\tend,\n\t\t\t\tconfirmText = L[\"Put every setting on this page back to its default? Where the prompt sits, the lines you wrote and the never-offer list are kept.\"],\n",
       "",
       "advanced: the reset does not ask",
       expect="Put these back to default does not ask before it resets", script=S)

# The question not saying what is kept.
mutate("Options/Advanced.lua",
       "L[\"Put every setting on this page back to its default? Where the prompt sits, the lines you wrote and the never-offer list are kept.\"]",
       "L[\"Put every setting on this page back to its default?\"]",
       "advanced: the reset hides what it restores",
       expect="the reset does not say what it keeps", script=S)

# The button offered on a page with nothing to put back.
mutate("Options/Advanced.lua",
       "\t\t\t\thidden = function() return Page.RESET[ns.OptionsTab()] == nil end,\n",
       "",
       "advanced: the reset on every page",
       expect="which has nothing to put back", script=S)

# The button putting back a page other than the one in view.
mutate("Options/Advanced.lua",
       "\t\t\t\t\tlocal pageId = askedFor or ns.OptionsTab()\n",
       "\t\t\t\t\tlocal pageId = \"when\"\n",
       "advanced: the reset ignores the page in view",
       expect="with Who to skip open, the reset did not put Skip players below level back", script=S)

# --- what greys out and hides ---

mutate("Options/Advanced.lua",
       "\t\t\t\tdisabled = function() return not S().owed end,\n\t\t\t\tget = sGet,\n",
       "\t\t\t\tget = sGet,\n",
       "advanced: class buffs only live with favours off",
       expect="Ignore shields, heals and trinket procs is live with People who buffed me off", script=S)

mutate("Options/Advanced.lua",
       "\t\t\t\tdisabled = function() return not F().reachableOnly end,\n",
       "",
       "advanced: grace live with stop sooner off",
       expect="Let them go after is live with Stop sooner off", script=S)

mutate("Options/Advanced.lua",
       "\t\t\t\thidden = function() return not InCombatLockdown() end,\n"
       "\t\t\t\tname = \"|cffffd100\" .. L[\"In combat: targeting changes apply once the fight ends.\"]",
       "\t\t\t\tname = \"|cffffd100\" .. L[\"In combat: targeting changes apply once the fight ends.\"]",
       "advanced: combat notice out of combat",
       expect="the combat notice shows out of combat", script=S)

# The grey note shown to a class that does target.
mutate("Options/Advanced.lua",
       "\t\t\t\thidden = function() return not NeverTargets() end,\n"
       "\t\t\t\tname = \"|cff888888\" .. L[\"Everything you can offer is cast on yourself",
       "\t\t\t\tname = \"|cff888888\" .. L[\"Everything you can offer is cast on yourself",
       "advanced: no-target note shown to a mage",
       expect="advanced: the switch and the grey note are both shown", script=S)

# --- the layout ---

# The help moved back under the box it explains.
mutate("Options/Advanced.lua",
       "\t\t\tformatHelp = {\n\t\t\t\ttype = \"description\",\n\t\t\t\torder = 51,\n",
       "\t\t\tformatHelp = {\n\t\t\t\ttype = \"description\",\n\t\t\t\torder = 52.5,\n",
       "advanced: placeholder help below the box",
       expect="the placeholder help sits below the box it explains", script=S)

# A moved control writing somewhere new.
mutate("Options/Advanced.lua",
       "\t\t\t\tname = L[\"Offer a buff back for (seconds)\"],\n"
       "\t\t\t\tdesc = L[\"How long someone who buffed you stays on offer.\"],\n"
       "\t\t\t\torder = 12,\n"
       "\t\t\t\twidth = \"double\",\n"
       "\t\t\t\thidden = NoOthers,\n"
       "\t\t\t\tmin = 15,\n"
       "\t\t\t\tmax = 600,\n"
       "\t\t\t\tstep = 5,\n"
       "\t\t\t\tget = tGet,\n"
       "\t\t\t\tset = tSet,\n",
       "\t\t\t\tname = L[\"Offer a buff back for (seconds)\"],\n"
       "\t\t\t\tdesc = L[\"How long someone who buffed you stays on offer.\"],\n"
       "\t\t\t\torder = 12,\n"
       "\t\t\t\twidth = \"double\",\n"
       "\t\t\t\thidden = NoOthers,\n"
       "\t\t\t\tmin = 15,\n"
       "\t\t\t\tmax = 600,\n"
       "\t\t\t\tstep = 5,\n"
       "\t\t\t\tget = fGet,\n"
       "\t\t\t\tset = fSet,\n",
       "advanced: a moved control writes a new field",
       expect="advanced: reciprocateWindow did not write timing.reciprocateWindow", script=S)
