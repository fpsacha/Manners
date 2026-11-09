# Mutations for Hide the prompt in combat (Prompt/Fight.lua, the pull's bar
# macro in Clicks.lua, the presses in Prompt/Press.lua, the switch in
# Options/Look.lua). Each is caught by the scenario in
# tests/scenarios/hide-in-combat.lua that names it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# --- the snippet ---

# Hidden, but the macro left on the prompt and its rows: its key casts the
# frozen macro out of sight.
mutate("Prompt/Fight.lua",
       "\t\t\tbutton:SetAttribute(\"type1\", nil)\n"
       "\t\t\tbutton:SetAttribute(\"macrotext1\", nil)\n"
       "\t\t\tbutton:SetAttribute(\"type\", nil)\n"
       "\t\t\tbutton:SetAttribute(\"macrotext\", nil)\n",
       "",
       "hide-in-combat: hidden but still armed",
       expect="hide-in-combat: its key, the bar macro and a name in the list cast nothing while it is off (camelot)",
       script=S)

# The list's rows never handed to the snippet: a row a press left armed at the
# pull keeps its macro for the fight.
mutate("Prompt/Fight.lua",
       "\tfor _, button in ipairs(R.rowButtons or {}) do buttons[#buttons + 1] = button end\n",
       "",
       "hide-in-combat: the rows are not disarmed",
       expect="a name in the hidden list cast out of sight",
       script=S)

# Disarmed, never hidden.
mutate("Prompt/Fight.lua",
       "\t\tprompt:Hide(true)\n",
       "",
       "hide-in-combat: the snippet never hides it",
       expect="hide-in-combat: the prompt and its list are off the screen in a fight (camelot)",
       script=S)

# --- the pull and the bar macro ---

# The pull asks nothing of the header: no fight ever hides it.
mutate("Core.lua",
       "\tif ns.Prompt then ns.Guard(\"hide for the fight\", ns.Prompt.ArmFightHide, ns.Prompt) end\n",
       "",
       "hide-in-combat: the pull never arms the hide",
       expect="hide-in-combat: the prompt and its list are off the screen in a fight (camelot)",
       script=S)

# The bar macro keeps its cast at the pull: the prompt cannot be hidden safely,
# so it is not.
mutate("Clicks.lua",
       "\t\tif P.armedForFight == true and P:HidesForFight() then return body.waitBody end\n",
       "",
       "hide-in-combat: the pull leaves the bar macro its cast",
       expect="hide-in-combat: the prompt and its list are off the screen in a fight (camelot)",
       script=S)

# The bar macro emptied outside a fight too, while the switch is on.
mutate("Clicks.lua",
       "\t\tif P.armedForFight == true and P:HidesForFight() then return body.waitBody end\n",
       "\t\tif P:HidesForFight() then return body.waitBody end\n",
       "hide-in-combat: the bar macro empty outside a fight",
       expect="after the fight the bar macro holds",
       script=S)

# The prompt hidden over a bar macro that still casts.
mutate("Clicks.lua",
       "\t\treturn rest ~= nil and #rest == 1 and rest[1] == BAR_LINE\n",
       "\t\treturn true\n",
       "hide-in-combat: hidden over a bar macro that casts",
       expect="hide-in-combat: a bar macro still holding a cast at the pull keeps the prompt up",
       script=S)

# A macro changed by hand taken for one that casts nothing: its lines run at
# every press, and the prompt would be off the screen over them.
mutate("Clicks.lua",
       "\t\treturn rest ~= nil and #rest == 1 and rest[1] == BAR_LINE\n",
       "\t\treturn rest ~= nil and (#rest == 1 or not Shaped(rest))\n",
       "hide-in-combat: hidden over a macro changed by hand",
       expect="hide-in-combat: a Manners macro changed by hand keeps the prompt up",
       script=S)

# ...and nothing said about why it stays up.
mutate("Prompt/Fight.lua",
       "\t\tif ns.db.profile.verbose and not (stayedSaidAt and now - stayedSaidAt < STAYED_REST) then\n",
       "\t\tif false then\n",
       "hide-in-combat: staying up says nothing",
       expect="nothing said why it stays up",
       script=S)

# ...or said at every pull.
mutate("Prompt/Fight.lua",
       "\t\tif ns.db.profile.verbose and not (stayedSaidAt and now - stayedSaidAt < STAYED_REST) then\n",
       "\t\tif ns.db.profile.verbose then\n",
       "hide-in-combat: staying up says so at every pull",
       expect="the next pull said the same line again",
       script=S)

# The switch ignored: every fight hides the prompt.
mutate("Prompt/Fight.lua",
       "\treturn R.fight ~= nil and db ~= nil and db.prompt.hideInFight == true\n",
       "\treturn R.fight ~= nil and db ~= nil\n",
       "hide-in-combat: hidden with the switch off",
       expect="hide-in-combat: off, the prompt stays up and armed in a fight (camelot)",
       script=S)

# --- the fight's end ---

# The verdict left standing after the fight: a combat flag that outlasts the
# lockdown hides and disarms the prompt outside a fight.
mutate("Prompt/Fight.lua",
       "\t-- nothing outside a fight.\n"
       "\theader:SetAttribute(\"manners-hide\", false)\n",
       "\t-- nothing outside a fight.\n",
       "hide-in-combat: the verdict outlives the fight",
       expect="hide-in-combat: a combat flag that outlasts the fight hides nothing after it",
       script=S)

# The driver left on "fight": a second fight a frame after the first is never
# seen.
mutate("Prompt/Fight.lua",
       "\theader:SetAttribute(\"state-\" .. STATE, \"peace\")\n",
       "",
       "hide-in-combat: the next pull goes unseen",
       expect="hide-in-combat: a second fight straight after the first hides it too",
       script=S)

# --- the presses ---

# Its key pressed while it is off is filed as a press, and says nothing.
mutate("Prompt/Press.lua",
       "\tif S == Prompt.state and Prompt:HiddenForFight() then\n",
       "\tif false then\n",
       "hide-in-combat: a press on the hidden prompt is filed",
       expect="a press of its key in the fight was filed",
       script=S)

# The bar macro's press in the fight says only that macros cannot change.
mutate("Prompt/Press.lua",
       "\tif InCombatLockdown() and Prompt:HiddenForFight() then\n",
       "\tif false then\n",
       "hide-in-combat: the bar press does not say it is hidden",
       expect="a press of the bar macro said",
       script=S)

# --- the launch check ---

# A client whose snippet leaves the macro on the button still reads PASS.
mutate("SelftestLaunch.lua",
       "\t\tif type1 ~= nil or text1 ~= nil then worse(FAIL, \"the snippet could not take a secure button's macro off\") end\n",
       "",
       "hide-in-combat: the launch check takes a macro left on for a pass",
       expect="selftest-launch: hide in combat: a snippet that leaves the macro reads FAIL",
       script=S)

# A driver that reads nothing useful out of a fight still reads PASS.
mutate("SelftestLaunch.lua",
       "\tif okS ~= true or state ~= \"peace\" then worse(FAIL, \"the state driver does not answer peace out of a fight\") end\n",
       "",
       "hide-in-combat: the launch check ignores the driver",
       expect="selftest-launch: hide in combat: a driver that does not read peace reads FAIL",
       script=S)

# --- the switch ---

# On out of the box.
mutate("Core.lua",
       "\t\t\thideInFight = false,\n",
       "\t\t\thideInFight = true,\n",
       "hide-in-combat: on by default",
       expect="hide-in-combat: the switch is on Look and off out of the box",
       script=S)

# No flashes in combat no longer names the switch that hides the prompt.
mutate("Options/Look.lua",
       "\t\t\t\t\t\t:format(L[\"Hide the prompt in combat\"])\n",
       "\t\t\t\t\t\t:format(\"\")\n",
       "hide-in-combat: the flashes switch does not point to it",
       expect="does not point to the switch that hides the prompt",
       script=S)

# Left out of Look's reset.
mutate("Options/Advanced.lua",
       "\t\t\"prompt.hideInFight\", \"prompt.font\",",
       "\t\t\"prompt.font\",",
       "hide-in-combat: Look's reset leaves it",
       expect="look reset: prompt.hideInFight was not put back",
       script=S)
