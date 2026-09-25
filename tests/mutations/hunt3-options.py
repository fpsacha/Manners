# The third bug hunt's launcher and options-page fixes, each put back and
# required to be caught by its scenario in tests/scenarios/hunt3-options.lua.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# ------------------------------------------------------------------ options-1
# Never offer from the menu without the block: the person just listed stays
# armed through the hold and the fuse, and a keypress casts at them.
mutate("Options.lua",
       "local function NeverFromMenu(entry)\n\tns.BlockPerson(entry.name)\n",
       "local function NeverFromMenu(entry)\n",
       "hunt3-options: never offer from the menu leaves them armed",
       expect="hunt3-options: never offer from the menu takes them off the prompt", script=S)

# ------------------------------------------------------------------ options-2
mutate("Options.lua",
       "\telseif snoozeLeft and held then\n",
       "\telseif snoozeLeft and false then\n",
       "hunt3-options: a snooze in a fight denies the held prompt",
       expect="snoozed in a fight, the tooltip denies the prompt it holds", script=S)

mutate("Options.lua",
       "\t\tif heldOnly then list = showing and { showing } or {} end\n",
       "",
       "hunt3-options: a snooze in a fight lists the whole queue",
       expect="snoozed in a fight, the tooltip lists people the snooze will not offer", script=S)

mutate("Options.lua",
       "\t\tif InCombatLockdown() and ArmedButtonLeft() then\n",
       "\t\tif false then\n",
       "hunt3-options: off in a fight denies the armed panel",
       expect="switched off in a fight, the tooltip denies the prompt still armed", script=S)

# ------------------------------------------------------------------ options-3
mutate("Options.lua",
       "\telseif not held and ns.HiddenWhileMounted and ns.HiddenWhileMounted() then\n",
       "\telseif false then\n",
       "hunt3-options: the launcher ignores the mount",
       expect="hunt3-options: the launcher names the mount", script=S)

mutate("Options.lua",
       "\telseif DragPanelUp() then\n\t\t-- Ahead of the snooze",
       "\telseif false then\n\t\t-- Ahead of the snooze",
       "hunt3-options: the launcher ignores the lock",
       expect="unlocked, the tooltip says it is watching and names people", script=S)

mutate("Options.lua",
       "\tif DragPanelUp() and not heldOnly then\n\t\tNobody(parent, line)\n",
       "\tif false then\n\t\tNobody(parent, line)\n",
       "hunt3-options: who's next puts the snooze before the lock",
       expect="snoozed while unlocked, who's next does not say the prompt is unlocked", script=S)

mutate("Options.lua",
       "\t\tlocal waiting = WaitingCount()\n\t\tif waiting == 1 then\n\t\t\tNobody(",
       "\t\tlocal waiting = 0\n\t\tif waiting == 1 then\n\t\t\tNobody(",
       "hunt3-options: who's next denies the favours waiting",
       expect="hunt3-options: who's next does not deny favours it cannot offer", script=S)

# ------------------------------------------------------------------ options-4
mutate("Options.lua",
       "elseif ends and DragPanelUp() then\n",
       "elseif false then\n",
       "hunt3-options: the snooze note ignores the lock",
       expect="hunt3-options: the snooze note knows the prompt is unlocked", script=S)

# ------------------------------------------------------------------ options-5
mutate("Options.lua",
       "\t\t\tif ns.Prompt:InTest() then\n\t\t\t\tns.addon:HandleSlash(\"test\")\n",
       "\t\t\tif true then\n\t\t\t\tns.addon:HandleSlash(\"test\")\n",
       "hunt3-options: End the preview toggles",
       expect="End the preview, clicked after it had ended, started a new one", script=S)

mutate("Options.lua",
       "if not ns.Prompt:InTest() then ns.addon:HandleSlash(\"test\") end",
       "ns.addon:HandleSlash(\"test\")",
       "hunt3-options: Preview the prompt toggles",
       expect="Preview the prompt, clicked over a running preview, ended it", script=S)

# ------------------------------------------------------------------ options-6
mutate("Options.lua",
       "\t\tif listed and not owedNow then\n",
       "\t\tif false then\n",
       "hunt3-options: a favour to let go for nobody owed",
       expect="who's next offers to let go a favour Anna never did", script=S)

# ------------------------------------------------------------------ review-1
# Unlocked in a fight: the tooltip and Who's next said "casts nothing" over a
# macro the fight keeps armed, and dropped the held person's Skip.
mutate("Options.lua",
       "\t\tif held then\n\t\t\treturn true, L[\"Unlocked, but",
       "\t\tif false then\n\t\t\treturn true, L[\"Unlocked, but",
       "hunt3-options: unlocked in a fight drops the held one",
       expect="unlocked in a fight, who's next drops the person a press still casts at", script=S)

mutate("Options.lua",
       "\t\telseif InCombatLockdown() and ArmedButtonLeft() then\n\t\t\treturn false, L[\"Unlocked --",
       "\t\telseif false then\n\t\t\treturn false, L[\"Unlocked --",
       "hunt3-options: unlocked in a fight denies the macro",
       expect="after a pass the tooltip does not say a press still casts", script=S)

mutate("Options.lua",
       "\tif heldOnly and DragPanelUp() then\n\t\tNobody(parent, L[\"Nobody else -- the prompt is unlocked\"])\n\telseif",
       "\tif false then\n\t\tNobody(parent, L[\"Nobody else -- the prompt is unlocked\"])\n\telseif",
       "hunt3-options: unlocked in a fight, nobody after unsaid",
       expect="who's next does not say why nobody comes after Anna", script=S)

# ------------------------------------------------------------------ review-2
# The lock alone, where nothing castable or /manners off keeps the panel down.
mutate("Options.lua",
       "\t\tand ns.caps ~= nil and ns.caps.anyKnown == true\n",
       "\t\tand true\n",
       "hunt3-options: drag panel with nothing to cast",
       expect="a rogue, unlocked, is told there is a prompt to drag", script=S)

mutate("Options.lua",
       "\treturn Enabled() and ns.db.profile.prompt.locked == false\n",
       "\treturn ns.db.profile.prompt.locked == false\n",
       "hunt3-options: drag panel while switched off",
       expect="switched off, unlocked and snoozed, the snooze note offers a prompt to drag", script=S)

# ------------------------------------------------------------------ review-3
mutate("Options.lua",
       "\tif listed and onPrompt and InCombatLockdown() then\n",
       "\tif false then\n",
       "hunt3-options: never offer in a fight, silent",
       expect="Never offer in a fight does not say a press still casts at Anna", script=S)

# ------------------------------------------------------------------ review-4
mutate("Options.lua",
       "L[\"Kept away while you are mounted -- %s, on the %s tab.\"]\n\t\t\t:format(L[\"Not while mounted\"], L[\"When\"])",
       "L[\"Kept away while you are mounted -- Not while mounted, on the When tab.\"]",
       "hunt3-options: the mount line hard-codes labels",
       expect="the mount line does not take the option and tab names from their own keys", script=S)
