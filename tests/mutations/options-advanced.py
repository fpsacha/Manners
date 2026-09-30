# The Advanced tab (Options.lua, BuildAdvancedTab). Each fault is caught by the
# scenario in tests/scenarios/options-advanced.lua that names it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# --- put these back to default ---

# The loop that copies the defaults skipped.
mutate("Options.lua",
       "\t\t\t\tprofile[field[1]][field[2]] = defaults[field[1]][field[2]]\n",
       "",
       "advanced: the reset puts nothing back",
       expect="advanced reset: sources.owedClassBuffsOnly was not put back", script=S)

# One field left off the list.
mutate("Options.lua",
       "\t\t{ \"prompt\", \"reasonUnknown\" },\n\t}\n",
       "\t}\n",
       "advanced: the reset forgets a wording",
       expect="advanced reset: prompt.reasonUnknown was not put back", script=S)

# Re-anchored: the reset used to put the anchor back, and now keeps where the
# prompt sits. The fault is the anchor swept up with the rest again.
mutate("Options.lua",
       "\t\t{ \"prompt\", \"format\" },\n",
       "\t\t{ \"prompt\", \"point\" },\n\t\t{ \"prompt\", \"format\" },\n",
       "advanced: the reset leaves the anchor",
       expect="advanced reset: moved the prompt", script=S)

# A setting from another tab swept up with this one.
mutate("Options.lua",
       "\t\t{ \"prompt\", \"reasonUnknown\" },\n\t}\n",
       "\t\t{ \"prompt\", \"reasonUnknown\" },\n\t\t{ \"prompt\", \"scale\" },\n\t}\n",
       "advanced: the reset reaches another tab",
       expect="advanced reset: put back a setting from another tab", script=S)

# Keeping favours switched on without the save its own setter runs.
mutate("Options.lua",
       "\t\t\t-- ways of switching it on leave the file the same.\n\t\t\tns.addon:SaveDebts()\n",
       "\t\t\t-- ways of switching it on leave the file the same.\n",
       "advanced: the reset skips the favour save",
       expect="advanced reset: switched keeping favours back on without saving them", script=S)

# The scanner left on the old timings.
mutate("Options.lua",
       "\t\t\tns.addon:SaveDebts()\n\t\t\trescan()\n",
       "\t\t\tns.addon:SaveDebts()\n",
       "advanced: the reset does not rescan",
       expect="advanced reset: the new timings were not handed to the scanner", script=S)

# The prompt left in the old wording and place.
mutate("Options.lua",
       "\t\t\t-- this never touches the secure button mid-fight.\n\t\t\trestyleAndMacro()\n",
       "\t\t\t-- this never touches the secure button mid-fight.\n",
       "advanced: the reset does not restyle",
       expect="advanced reset: the prompt was not restyled and its macro rebuilt", script=S)

# ...or placed by hand, which moves the secure button in a fight.
mutate("Options.lua",
       "\t\t\t-- this never touches the secure button mid-fight.\n\t\t\trestyleAndMacro()\n",
       "\t\t\t-- this never touches the secure button mid-fight.\n\t\t\trestyleAndMacro()\n"
       "\t\t\tns.Prompt:GetButton():ClearAllPoints()\n",
       "advanced: the reset moves the button in a fight",
       expect="advanced reset in a fight called", script=S)

# The page left showing the old values.
mutate("Options.lua",
       "\t\t\trestyleAndMacro()\n\t\t\tns.RefreshOptionsDisplay()\n\t\tend)\n",
       "\t\t\trestyleAndMacro()\n\t\tend)\n",
       "advanced: the reset does not redraw",
       expect="advanced reset: the page still shows the old values", script=S)

# No question before resetting.
mutate("Options.lua",
       "\t\t\t\tconfirm = true,\n\t\t\t\tconfirmText = L[\"Put every setting on this tab back to its default? This also restores what the prompt says; where it sits is kept.\"],\n",
       "",
       "advanced: the reset does not ask",
       expect="Put these back to default does not ask before it resets", script=S)

# The question not saying the wording goes back too.
mutate("Options.lua",
       "L[\"Put every setting on this tab back to its default? This also restores what the prompt says; where it sits is kept.\"]",
       "L[\"Put every setting on this tab back to its default?\"]",
       "advanced: the reset hides what it restores",
       expect="the reset does not say it restores the wording and keeps the position", script=S)

# --- what greys out and hides ---

mutate("Options.lua",
       "\t\t\t\tdisabled = function() return not S().owed end,\n\t\t\t\tget = sGet,\n",
       "\t\t\t\tget = sGet,\n",
       "advanced: class buffs only live with favours off",
       expect="Ignore shields, heals and trinket procs is live with People who buffed me off", script=S)

mutate("Options.lua",
       "\t\t\t\tdisabled = function() return not F().reachableOnly end,\n",
       "",
       "advanced: grace live with stop sooner off",
       expect="Let them go after is live with Stop sooner off", script=S)

mutate("Options.lua",
       "\t\t\t\thidden = function() return not InCombatLockdown() end,\n"
       "\t\t\t\tname = \"|cffffd100\" .. L[\"In combat: targeting changes apply once the fight ends.\"]",
       "\t\t\t\tname = \"|cffffd100\" .. L[\"In combat: targeting changes apply once the fight ends.\"]",
       "advanced: combat notice out of combat",
       expect="the combat notice shows out of combat", script=S)

# The grey note shown to a class that does target.
mutate("Options.lua",
       "\t\t\t\thidden = function() return not NeverTargets() end,\n"
       "\t\t\t\tname = \"|cff888888\" .. L[\"Everything you can offer is cast on yourself",
       "\t\t\t\tname = \"|cff888888\" .. L[\"Everything you can offer is cast on yourself",
       "advanced: no-target note shown to a mage",
       expect="advanced: the switch and the grey note are both shown", script=S)

# --- the layout ---

# The help moved back under the box it explains.
mutate("Options.lua",
       "\t\t\tformatHelp = {\n\t\t\t\ttype = \"description\",\n\t\t\t\torder = 51,\n",
       "\t\t\tformatHelp = {\n\t\t\t\ttype = \"description\",\n\t\t\t\torder = 52.5,\n",
       "advanced: placeholder help below the box",
       expect="the placeholder help sits below the box it explains", script=S)

# A moved control writing somewhere new.
mutate("Options.lua",
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
