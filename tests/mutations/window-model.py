# What the options window reads from the model: the sidebar's red dots
# (Page.Warn, Options/Shared.lua), the status strip's state (LauncherState's
# kind, Options/Launcher.lua), the per-page reset (Page.RESET and
# Page.ResetPage, Options/Advanced.lua) and the ledger raised over the window.
# Each fault is caught by the scenario in tests/scenarios/model-window.lua that
# names it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# --- the red dots ---

# Start here's dot blind to the macro.
mutate("Options/Shared.lua",
       "\t\treturn HasPrompt() and not ns.Setup.Key() and not ns.Setup.MacroMade()\n",
       "\t\treturn HasPrompt() and not ns.Setup.Key()\n",
       "model: Start here's dot ignores the macro",
       expect="the macro is made and Start here still has its red dot", script=S)

# Who to buff's dot blind to a pin nobody learned.
mutate("Options/Shared.lua",
       "(NoSources() or PinUnlearned() or NothingCastable())",
       "(NoSources() or NothingCastable())",
       "model: Who to buff's dot ignores the pin",
       expect="a pinned spell not learned offers nobody, and Who to buff has no red dot", script=S)

# ...and to Automatic with nothing it can cast.
mutate("Options/Shared.lua",
       "(NoSources() or PinUnlearned() or NothingCastable())",
       "(NoSources() or PinUnlearned())",
       "model: Who to buff's dot ignores nothing castable",
       expect="nothing can be cast and Who to buff has no red dot", script=S)

# When to offer's dot for a character with nobody to offer to.
mutate("Options/Shared.lua",
       "\t\treturn HasClassBuffs() and F().whenBuffed == \"always\"\n",
       "\t\treturn F().whenBuffed == \"always\"\n",
       "model: Always offer dot without class buffs",
       expect="a character with nothing for anybody gets the Always offer dot", script=S)

# Look's dot blind to a dead marker.
mutate("Options/Shared.lua",
       "\t\treturn (SND().enabled == true and SND().file == \"None\") or Page.AccentDead()\n",
       "\t\treturn (SND().enabled == true and SND().file == \"None\")\n",
       "model: Look's dot ignores the dead marker",
       expect="the marker has nothing left to colour, and Look has no red dot", script=S)

# A marker switched off on purpose counted as dead.
mutate("Options/Look.lua",
       "\tif (P().accentMode or \"icon\") == \"off\" then return false end\n",
       "",
       "model: no marker counted as a dead one",
       expect="no marker asked for, and Look still has a red dot", script=S)

# Diagnostics' dot blind to an error.
mutate("Options/Shared.lua",
       "\t\treturn #ns.errors > 0\n",
       "\t\treturn false\n",
       "model: Diagnostics' dot ignores errors",
       expect="an error was caught and Diagnostics has no red dot", script=S)

# --- the strip ---

mutate("Options/Launcher.lua",
       "L[\"Switched off -- no prompt will appear.\"], 1, 0.5, 0.5, nil, nil, \"off\"\n",
       "L[\"Switched off -- no prompt will appear.\"], 1, 0.5, 0.5, nil, nil, \"watching\"\n",
       "model: off read as watching",
       expect="switched off reads as", script=S)

mutate("Options/Launcher.lua",
       ":format(\"|cffffd100/manners lock|r\"), 1, 0.82, 0, true, nil, \"unlocked\"\n",
       ":format(\"|cffffd100/manners lock|r\"), 1, 0.82, 0, true, nil, \"snoozed\"\n",
       "model: unlocked read as snoozed",
       expect="unlocked reads as", script=S)

mutate("Options/Launcher.lua",
       "math.ceil(snoozeLeft / 60))), 1, 0.82, 0, true, nil, \"snoozed\"\n",
       "math.ceil(snoozeLeft / 60))), 1, 0.82, 0, true\n",
       "model: snoozed without its kind",
       expect="snoozed reads as", script=S)

mutate("Options/Launcher.lua",
       ":format(L[\"Myself\"]), 1, 0.82, 0, nil, nil, \"ownoff\"\n",
       ":format(L[\"Myself\"]), 1, 0.82, 0, nil, nil, \"ownwatch\"\n",
       "model: own buffs off read as watching them",
       expect="a hunter with Myself off reads as", script=S)

mutate("Options/Launcher.lua",
       "1, 0.5, 0.5, true,\n\t\t\t\tnil, \"blocked\"\n",
       "1, 0.5, 0.5, true,\n\t\t\t\tnil, \"unlearned\"\n",
       "model: blocked read as nothing learned",
       expect="every spell switched off reads as", script=S)

mutate("Options/Launcher.lua",
       "\treturn true, L[\"Watching for people to buff.\"], 0.4, 0.9, 0.4, nil, nil, \"watching\"\n",
       "\treturn true, L[\"Watching for people to buff.\"], 0.4, 0.9, 0.4\n",
       "model: watching without its kind",
       expect="a mage who can cast reads as", script=S)

# --- the reset ---

# A field dropped from a page's list.
mutate("Options/Advanced.lua",
       "\t\t\"filters.skipPvP\", \"filters.skipSameClass\", \"filters.requireInRange\", \"filters.minLevel\",\n",
       "\t\t\"filters.skipPvP\", \"filters.skipSameClass\", \"filters.requireInRange\",\n",
       "model: Who to skip's reset forgets the level",
       expect="skip reset: the list leaves out filters.minLevel", script=S)

# The never-offer list swept up with Who to skip.
mutate("Options/Advanced.lua",
       "\t\t\"filters.skipPvP\", \"filters.skipSameClass\", \"filters.requireInRange\", \"filters.minLevel\",\n",
       "\t\t\"filters.skipPvP\", \"filters.skipSameClass\", \"filters.requireInRange\", \"filters.minLevel\",\n"
       "\t\t\"never.list\",\n",
       "model: Who to skip's reset reaches the never list",
       expect="skip reset: the list reaches never.list", script=S)

# A set replaced by a new table rather than wiped in place.
mutate("Options/Advanced.lua",
       "\tif type(default) == \"table\" and type(current) == \"table\" and default[1] == nil then\n",
       "\tif false then\n",
       "model: the reset swaps a set for a new table",
       expect="is a new table, not the one wiped", script=S)

# Your own buffs' picks put back without the prompt following.
mutate("Options/Advanced.lua",
       "\t\t\tns.Prompt:Refresh()\n\t\t\t-- The favour count follows People who buff me.\n",
       "\t\t\t-- The favour count follows People who buff me.\n",
       "model: Who to buff's reset skips the refresh",
       expect="who reset: the refresh hook did not run", script=S)

# The launcher's favour count left on the old People who buff me.
mutate("Options/Advanced.lua",
       "\t\t\t-- The favour count follows People who buff me.\n\t\t\tRefreshBroker()\n",
       "\t\t\t-- The favour count follows People who buff me.\n",
       "model: Who to buff's reset skips the launcher",
       expect="who reset: the broker hook did not run", script=S)

# What I say's lines put back with the macro left on the old ones.
mutate("Options/Advanced.lua",
       "\t\tafter = function() ns.Prompt:InvalidateMacro() end,\n",
       "",
       "model: What I say's reset leaves the macro",
       expect="click reset: the macro hook did not run", script=S)

# A page with no list reset anyway.
mutate("Options/Advanced.lua",
       "\tif not list then return false end\n",
       "\tif not list then list = {} end\n",
       "model: a page with no list says it reset",
       expect="which has no list, said it ran", script=S)

# --- the ledger ---

# Shown under a window opened before it.
mutate("Ledger.lua",
       "\twindow:Show()\n\tif window.Raise then window:Raise() end\n",
       "\twindow:Show()\n",
       "model: the ledger not raised",
       expect="the ledger opened without raising its window", script=S)
