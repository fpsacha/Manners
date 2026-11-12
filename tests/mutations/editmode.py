# Moving the prompt in Edit Mode (tests/scenarios/editmode.lua): each fault put
# back has to be caught by the scenario that names it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

INOUT = "editmode: Edit Mode opening unlocks the prompt, and closing locks it"
DRAG = "editmode: a drag in Edit Mode saves the place and leaves the prompt unlocked until Edit Mode closes"
ALONE = "editmode: with the switch off, the addon off or a fight on, Edit Mode leaves the prompt alone"
THEIRS = "editmode: a prompt the player unlocked is not locked by Edit Mode closing"
RELOAD = "editmode: a reload inside Edit Mode does not leave the prompt unlocked"
SWITCH = "editmode: the switch is on Look where the client has an Edit Mode, and hidden where it has none"

# Nobody listening: Edit Mode opens and the prompt stays where it is, locked.
mutate("Core.lua",
       "\tns.Guard(\"Edit Mode\", function() ns.WatchEditMode() end)\n",
       "",
       "editmode: Edit Mode is never listened for",
       expect=INOUT,
       script=S)

# Closing forgets to lock: an unlocked prompt casts nothing from then on.
mutate("Prompt/Button.lua",
       "\t\tif p.locked then return end\n\t\tp.locked = true\n",
       "\t\tif p.locked then return end\n",
       "editmode: Edit Mode closing leaves the prompt unlocked",
       expect=INOUT,
       script=S)

# The switch not asked.
mutate("Prompt/Button.lua",
       "\t\tif not db or not db.enabled or not db.prompt.moveInEditMode then return end\n",
       "\t\tif not db or not db.enabled then return end\n",
       "editmode: Edit Mode unlocks with the switch off",
       expect=ALONE,
       script=S)

# Unlocked in a fight, where the secure prompt cannot be moved.
mutate("Prompt/Button.lua",
       "\t\tif not db.prompt.locked or InCombatLockdown() then return end\n\t\tif not (ns.caps",
       "\t\tif not db.prompt.locked then return end\n\t\tif not (ns.caps",
       "editmode: Edit Mode unlocks the prompt in a fight",
       expect=ALONE,
       script=S)

# Closing locks whatever is unlocked, the player's own unlock included.
mutate("Prompt/Button.lua",
       "\t\tif not editUnlocked then return end\n",
       "",
       "editmode: Edit Mode closing locks a prompt the player unlocked",
       expect=THEIRS,
       script=S)

# The drag locks at once, as outside Edit Mode: no second nudge.
mutate("Prompt/Button.lua",
       "\tif editUnlocked then\n\t\tPrompt:ApplyStyle()\n",
       "\tif false then\n\t\tPrompt:ApplyStyle()\n",
       "editmode: a drag in Edit Mode locks the prompt",
       expect=DRAG,
       script=S)

# The mark of a reload read and nothing done about it.
mutate("Prompt/Button.lua",
       "\t\t\tchar.editUnlocked = nil\n\t\t\tns.db.profile.prompt.locked = true\n",
       "\t\t\tchar.editUnlocked = nil\n",
       "editmode: a reload inside Edit Mode leaves the prompt unlocked",
       expect=RELOAD,
       script=S)

# The switch shown on a client with no Edit Mode to move anything in.
mutate("Options/Look.lua",
       "\t\t\t\thidden = function() return not ns.HasEditMode() end,\n",
       "\t\t\t\thidden = function() return false end,\n",
       "editmode: the switch shows on a client with no Edit Mode",
       expect=SWITCH,
       script=S)
