# Mutations for round 19's options fixes: a page changed while a box has the
# keyboard (Window.lua), a slider or nudge arrow beside a box that had it and
# a slider whose release went missing (WidgetsEntry.lua), the key button and a
# long dropdown (WidgetsChoice.lua), a rogue's reset (WindowChrome.lua, Bind),
# the Profiles tab and AceDBOptions' shared table (Profiles.lua), a pasted
# /thank and /manners macro (Commands.lua). Each undoes a fix and is caught by
# the scenario in tests/scenarios/hunt19-options.lua it names.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# The old page hidden while it is still the page in view: the box it held
# commits as it goes, and that commit's repaint draws the old page back.
mutate("Options/Window/Window.lua",
       "\tUI.page = id\n\tUI.State().page = id\n\tif was ~= id then UI.view.scrollY = 0 end\n"
       "\tif was and was ~= id then UI.HidePage(was) end\n",
       "\tif was and was ~= id then UI.HidePage(was) end\n"
       "\tUI.page = id\n\tUI.State().page = id\n\tif was ~= id then UI.view.scrollY = 0 end\n",
       "hunt19-options: the old page hidden before the new one is in view",
       expect="of Look's rows are still drawn over Who to buff after leaving Scale's box", script=S)

# A change on Look committed as the player leaves it fades the window over
# the page they went to.
mutate("Options/Window/Window.lua",
       "\tif OnLook(item) and UI.page == \"appearance\" and not InCombatLockdown() then\n",
       "\tif OnLook(item) and not InCombatLockdown() then\n",
       "hunt19-options: a Look box left for another page fades the window",
       expect="the window faded over Who to buff, to", script=S)

# The box beside a slider or nudge arrow keeps the keyboard, and its old
# number, through the drag.
mutate("Options/Window/WidgetsEntry.lua",
       "\tif on and row.box:HasFocus() then Leave(row) end\n",
       "",
       "hunt19-options: a drag beside a focused box is put back",
       expect="dragged to 2, the Scale box beside the slider reads", script=S)

# A press while a hold stands is ignored again: the release went missing, so
# the next press never fades the window.
mutate("Options/Window/WidgetsEntry.lua",
       "\tif not on and not row.held then return false end\n",
       "\tif (row.held == true) == on then return false end\n",
       "hunt19-options: a press after a lost release does not hold",
       expect="pressing Scale again after a lost release left the window at", script=S)

# A repaint keeps the hold whose release went missing: the slider and its box
# show where the drag ended.
mutate("Options/Window/WidgetsEntry.lua",
       "\t\tHoldLost(row)\n\t\trow.refreshing = true\n",
       "\t\trow.refreshing = true\n",
       "hunt19-options: a lost release keeps the slider off the setting",
       expect="typed 2 after a lost release: the slider is at", script=S)

# The key button waits while the search box keeps the keyboard.
mutate("Options/Window/WidgetsChoice.lua",
       "\tif focused and focused.ClearFocus then focused:ClearFocus() end\n",
       "",
       "hunt19-options: the key capture leaves the keyboard with a box",
       expect="waiting for a key, the search box kept the keyboard", script=S)

# A dropdown that never scrolls.
mutate("Options/Window/WidgetsChoice.lua",
       "\tif root.SetScrollMode then root:SetScrollMode(MENU_HEIGHT) end\n",
       "",
       "hunt19-options: a long dropdown runs off the screen",
       expect="entries never scrolls: past the screen's edge they cannot be picked", script=S)

# The footer's reset judged by its tab as well, which a rogue does not have.
mutate("Options/Window/WindowChrome.lua",
       "\tfooter.reset:SetShown(item ~= nil and not UI.OwnHidden(item))\n",
       "\tfooter.reset:SetShown(item ~= nil and not UI.Hidden(item))\n",
       "hunt19-options: a rogue's What I say loses its reset",
       expect="with a list to put back, has no Put these back to default", script=S)

# The Profiles tab is the library's own group again: a newer copy of the
# library loading later puts a fresh table of controls in it.
mutate("Options/Profiles.lua",
       "\tlocal t = Copy(lib)\n\tt.order = 90\n\tt.args = {}\n",
       "\tlocal t = lib\n\tt.order = 90\n\tt.args = {}\n",
       "hunt19-options: the Profiles tab is the library's own group",
       expect="/manners export sent the player to a box the Profiles tab no longer has", script=S)

# The library's controls put in our group as its own table, not copies: the
# hidden paragraph is hidden on every addon's tab.
mutate("Options/Profiles.lua",
       "\t\tt.args[key] = type(option) == \"table\" and Copy(option) or option\n",
       "\t\tt.args[key] = option\n",
       "hunt19-options: the library's paragraph hidden on every addon's tab",
       expect="another addon's Profiles tab lost the library's own paragraph", script=S)

# A pasted string switches the /thank on again.
mutate("Commands.lua",
       "[\"speech.enabled\"] = \"switch\", [\"prompt.thankEmote\"] = \"thank\" }",
       "[\"speech.enabled\"] = \"switch\" }",
       "hunt19-options: a paste switches the /thank on",
       expect="an imported string switched on /thank people who buff me", script=S)

# /manners macro leaves Start here as it was.
mutate("Commands.lua",
       "\tmacro = true,\n",
       "",
       "hunt19-options: /manners macro does not repaint Start here",
       expect="/manners macro made the macro and Start here still says", script=S)
