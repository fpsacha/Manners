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
       "\telseif ns.db.profile.prompt.locked == false then\n\t\t-- Ahead of the snooze",
       "\telseif false then\n\t\t-- Ahead of the snooze",
       "hunt3-options: the launcher ignores the lock",
       expect="unlocked, the tooltip says it is watching and names people", script=S)

mutate("Options.lua",
       "\tif ns.db.profile.prompt.locked == false then\n\t\tNobody(parent, line)\n",
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
       "elseif ends and ns.db.profile.prompt.locked == false then\n",
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
