# Moving the prompt (tests/scenarios/hunt30-move.lua): each fault put back has
# to be caught by the scenario that names it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

HEADER = "hunt30-move: the header's Move the prompt button unlocks, and reads Lock it while unlocked"
SCREEN = "hunt30-move: unlocking leaves the prompt on screen to drag, a preview out of its way"
FIGHT = "hunt30-move: Move the prompt is refused in a fight, and says why"
WORDS = "hunt30-move: Move the prompt says what /manners unlock says"
LOOK = "hunt30-move: Look leads with a big Move the prompt button, the places beside it"
MODEL = "hunt30-move: the model has the control as an ordinary button, for a class with a prompt"
NOPROMPT = "hunt30-move: a class with no prompt has no Move the prompt button"
SLASH = "hunt30-move: /manners move unlocks the prompt as /manners unlock does"
LINES = "hunt30-move: the unlocked prompt says what happens next"
TIP = "hunt30-move: the unlocked prompt's tooltip keeps the warning while there is something to drag"
ROW = "hunt30-move: the header's buttons sit in a row, Move the prompt between Show me the prompt and Snooze"

# ------------------------------------------------ the control
# The label stuck on its first word, so Lock it never shows.
mutate("Options/Shared.lua",
       "\t\tname = function() return P().locked and L[\"Move the prompt\"] or L[\"Lock it\"] end,\n",
       "\t\tname = function() return L[\"Move the prompt\"] end,\n",
       "hunt30-move: the label does not follow the lock",
       expect=MODEL,
       script=S)

# Unlocking by writing the setting, which says nothing in chat: not what
# /manners unlock says, and nothing to tell a switched-off addon's owner why
# there is no prompt.
mutate("Options/Shared.lua",
       "\t\t\tns.addon:HandleSlash(\"unlock\")\n",
       "\t\t\tprofile.prompt.locked = false\n\t\t\tns.Prompt:ApplyStyle()\n",
       "hunt30-move: the button unlocks without saying what /manners unlock says",
       expect=WORDS + " (on)",
       script=S)

# And locking the same way.
mutate("Options/Shared.lua",
       "\t\t\t\tns.addon:HandleSlash(\"lock\")\n",
       "\t\t\t\tprofile.prompt.locked = true\n\t\t\t\tns.Prompt:ApplyStyle()\n",
       "hunt30-move: the button locks without saying so",
       expect=HEADER,
       script=S)

# The window left over a prompt that is behind it.
mutate("Options/Shared.lua",
       "\t\t\tif profile.enabled and not profile.prompt.locked then ns.CloseOptions() end\n",
       "",
       "hunt30-move: the window stays over the prompt it was asked to move",
       expect=HEADER,
       script=S)

# The window shut with the addon off, taking the switch with it.
mutate("Options/Shared.lua",
       "\t\t\tif profile.enabled and not profile.prompt.locked then ns.CloseOptions() end\n",
       "\t\t\tif not profile.prompt.locked then ns.CloseOptions() end\n",
       "hunt30-move: the window shuts over a switched-off addon",
       expect=WORDS + " (off)",
       script=S)

# Live in a fight.
mutate("Options/Shared.lua",
       "\t\tdisabled = function() return P().locked and InCombatLockdown() end,\n",
       "\t\tdisabled = function() return false end,\n",
       "hunt30-move: Move the prompt live in a fight",
       expect=FIGHT,
       script=S)

# Greyed out in a fight while unlocked too, where locking is the way to get a
# prompt that casts.
mutate("Options/Shared.lua",
       "\t\tdisabled = function() return P().locked and InCombatLockdown() end,\n",
       "\t\tdisabled = function() return InCombatLockdown() end,\n",
       "hunt30-move: Lock it greyed out in a fight",
       expect=FIGHT,
       script=S)

# A press that gets through in a fight (the menu was open before the pull).
mutate("Options/Shared.lua",
       "\t\t\tif InCombatLockdown() then return end\n",
       "",
       "hunt30-move: a press in a fight unlocks",
       expect=FIGHT,
       script=S)

# The tooltip silent about the fight.
mutate("Options/Shared.lua",
       "\t\t\tif InCombatLockdown() then\n\t\t\t\ttext = text .. \"\\n\\n\"",
       "\t\t\tif false then\n\t\t\t\ttext = text .. \"\\n\\n\"",
       "hunt30-move: the tooltip does not say why in a fight",
       expect=FIGHT,
       script=S)

# Offered to a class with nothing for the prompt to show.
mutate("Options/Shared.lua",
       "\t\thidden = function() return not HasPrompt() end,\n\t\tdisabled = function() return P().locked",
       "\t\thidden = function() return false end,\n\t\tdisabled = function() return P().locked",
       "hunt30-move: Move the prompt offered to a class with no prompt",
       expect=NOPROMPT,
       script=S)

# ------------------------------------------------ the model
mutate("Options/Start.lua",
       "\t\t\tmoveToggle = Page.MoveControl(32),\n",
       "",
       "hunt30-move: no general.moveToggle in the model",
       expect=HEADER,
       script=S)

mutate("Options/Look.lua",
       "\t\t\tmove = Page.MoveControl(1),\n",
       "",
       "hunt30-move: no appearance.move in the model",
       expect=LOOK,
       script=S)

# ------------------------------------------------ the window's header
mutate("Options/Window/Layout.lua",
       "\t\tmove = \"general.moveToggle\",\n",
       "",
       "hunt30-move: the header does not place the button",
       expect=HEADER,
       script=S)

# The button left at the first word whatever the state.
mutate("Options/Window/WindowChrome.lua",
       "\t\tUI.SetButtonText(move, B.Text(moveItem, \"name\") or L[\"Move the prompt\"])\n",
       "\t\tUI.SetButtonText(move, L[\"Move the prompt\"])\n",
       "hunt30-move: the header's label does not follow the lock",
       expect=HEADER,
       script=S)

# Pressable in a fight as far as the header knows.
mutate("Options/Window/WindowChrome.lua",
       "\t\tmove:SetEnabled(not UI.Disabled(moveItem))\n",
       "\t\tmove:SetEnabled(true)\n",
       "hunt30-move: the header's button never greys out",
       expect=FIGHT,
       script=S)

# Shown for a class with no prompt.
mutate("Options/Window/WindowChrome.lua",
       "\tlocal moveShown = moveItem ~= nil and not UI.Hidden(moveItem)\n",
       "\tlocal moveShown = moveItem ~= nil\n",
       "hunt30-move: the header's button shown to a class with no prompt",
       expect=NOPROMPT,
       script=S)

# Placed over the preview button.
mutate("Options/Window/WindowChrome.lua",
       "\t\tright = right - header.moveWidth - 10\n",
       "\t\tright = right - 10\n",
       "hunt30-move: the header's buttons overlap",
       expect=ROW,
       script=S)

# The tooltip left out of the header.
mutate("Options/Window/WindowChrome.lua",
       "\theader.move:HookScript(\"OnEnter\", UI.Guarded(MoveTip))\n",
       "",
       "hunt30-move: the header's button has no tooltip",
       expect=FIGHT,
       script=S)

# ------------------------------------------------ Look
# Lock position back on the page, ahead of the button.
mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t{ \"appearance.move\", pair = true, big = true },\n\t\t\t\t\t\"appearance.posPreset\",\n",
       "\t\t\t\t\t{ \"appearance.posPreset\", pair = true },\n\t\t\t\t\t\"appearance.move\",\n",
       "hunt30-move: Look does not lead with the button",
       expect=LOOK,
       script=S)

# A button as small as any other.
mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t{ \"appearance.move\", pair = true, big = true },\n",
       "\t\t\t\t\t{ \"appearance.move\", pair = true },\n",
       "hunt30-move: the button on Look is not big",
       expect=LOOK,
       script=S)

# Lock position drawn nowhere and not said to be.
mutate("Options/Window/Layout.lua",
       "\t\t[\"appearance.locked\"] = true,\n",
       "",
       "hunt30-move: Lock position placed nowhere",
       expect=LOOK,
       script=S)

# A big button no bigger than the others.
mutate("Options/Window/Widgets.lua",
       "\t\tlocal big = (row.item.layout or {}).big\n",
       "\t\tlocal big = false\n",
       "hunt30-move: the widget ignores big",
       expect=LOOK,
       script=S)

# The control beside a dropdown, no longer levelled with its field.
mutate("Options/Window/WindowPage.lua",
       "\t\tif ma > mb then db = math.floor(ma - mb + 0.5) else da = math.floor(mb - ma + 0.5) end\n",
       "",
       "hunt30-move: a button beside a dropdown not levelled",
       expect="window: a switch or a swatch beside a dropdown sits level with the dropdown",
       script=S)

# ------------------------------------------------ /manners move
mutate("Commands.lua",
       "\telseif input == \"unlock\" or input == \"move\" then\n",
       "\telseif input == \"unlock\" then\n",
       "hunt30-move: /manners move is not a word",
       expect=SLASH,
       script=S)

mutate("Commands.lua",
       "\t{ word = \"move\", group = \"setup\",\n"
       "\t\thelp = L[\"move the prompt -- unlock it, drag it, and it locks itself when you let go\"] },\n",
       "",
       "hunt30-move: /manners move not in the help",
       expect=SLASH,
       script=S)

# An open window's button left saying Move the prompt.
mutate("Commands.lua",
       "\trestore = true, lock = true, unlock = true, move = true, snooze = true,\n",
       "\trestore = true, lock = true, unlock = true, snooze = true,\n",
       "hunt30-move: /manners move does not repaint the window",
       expect=SLASH,
       script=S)

# A preview left over the prompt, where "Drag to move" goes.
mutate("Commands.lua",
       "\t\tif ns.Prompt:InTest() then ns.Prompt:ExitTest(nil, true) end\n",
       "",
       "hunt30-move: a preview left over an unlocked prompt",
       expect=SCREEN,
       script=S)

# ...and ended with a line that says so as well.
mutate("Commands.lua",
       "\t\tif ns.Prompt:InTest() then ns.Prompt:ExitTest(nil, true) end\n",
       "\t\tif ns.Prompt:InTest() then ns.Prompt:ExitTest() end\n",
       "hunt30-move: ending the preview for a move announces it",
       expect=SCREEN,
       script=S)

mutate("Prompt/Refresh.lua",
       "\tif not quiet then ns.addon:Print(line or L[\"preview off.\"]) end\n",
       "\tns.addon:Print(line or L[\"preview off.\"])\n",
       "hunt30-move: a quiet ending of the preview is not quiet",
       expect=SCREEN,
       script=S)

# Opening Look starts a preview over the unlocked prompt.
mutate("Options/Window/Window.lua",
       "\tif not ns.db.profile.prompt.locked then return end\n",
       "",
       "hunt30-move: Look starts a preview over an unlocked prompt",
       expect=SCREEN,
       script=S)

# ------------------------------------------------ the prompt
# The second line the red warning it was.
mutate("Prompt/Refresh.lua",
       "\t\t\tif R.subText:IsShown() then SetLine(R.subText, L[\"Let go and it locks itself\"]) end\n",
       "\t\t\tif R.subText:IsShown() then SetLine(R.subText, \"|cffff8080\" .. L[\"not buffing while unlocked\"] .. \"|r\") end\n",
       "hunt30-move: the unlocked prompt's second line is the red warning",
       expect=LINES + " (luxe)",
       script=S)

# No tooltip over the unlocked prompt.
mutate("Prompt/Button.lua",
       "\t\tif DragPanelUp() then\n\t\t\tDragTooltip(self)\n\t\t\treturn\n\t\tend\n",
       "",
       "hunt30-move: no tooltip over the unlocked prompt",
       expect=TIP,
       script=S)

# ...taken down again at the next check, which finds nobody on the button.
mutate("Prompt/Button.lua",
       "\t\tif DragPanelUp() then return end\n",
       "",
       "hunt30-move: the drag tooltip goes at the next check",
       expect=TIP,
       script=S)

# ...up while the addon is off, with no prompt on screen to drag.
mutate("Prompt/Button.lua",
       "\t\treturn db.enabled and not db.prompt.locked and not S.testMode",
       "\t\treturn not db.prompt.locked and not S.testMode",
       "hunt30-move: the drag tooltip up while the addon is off",
       expect=TIP,
       script=S)
