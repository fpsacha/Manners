# Mutations for the When to offer tab (Options.lua, BuildWhenTab). Each is
# caught by the scenario in tests/scenarios/options-when.lua that names it, or,
# where its comment says so, in ownbuffs.lua (a hunter's page) or
# options-advanced.lua (the page's reset).
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# --- the layout ---

# The combat switch, now on Look next to Animations, drifted out of Getting my
# attention (re-anchored from its old place on this tab).
mutate("Options/Look.lua",
       "red if it failed.\"],\n"
       "\t\t\t\torder = 32.5,\n",
       "red if it failed.\"],\n"
       "\t\t\t\torder = 38,\n",
       "when tab: combat switch out of its section",
       expect="is out of order: it comes before hideInCombat", script=S)

# Retired: "when tab: favour time points nowhere" and "favour pointer with
# favours off". when.favoursHeader and when.favoursNote are gone: the window
# draws Offer a buff back for on this page, so there is no pointer left.

# The choices listed in the alphabet's order rather than least mana first.
mutate("Options/When.lua",
       "\t\t\t\tsorting = { \"skip\", \"refresh\", \"always\" },\n",
       "",
       "when tab: already-buffed choices unsorted",
       expect="the choices are not listed skip, refresh, always", script=S)

# --- what follows the choice ---

# The top-up slider shown whatever is chosen.
mutate("Options/When.lua",
       "\t\t\t\thidden = function() return F().whenBuffed ~= \"refresh\" end,\n",
       "\t\t\t\thidden = function() return false end,\n",
       "when tab: top-up slider always shown",
       expect="chosen, the top-up slider is shown", script=S)

# The Always note shown whatever is chosen.
mutate("Options/When.lua",
       "\t\t\t\thidden = function() return F().whenBuffed ~= \"always\" or not HasClassBuffs() end,\n",
       "\t\t\t\thidden = function() return not HasClassBuffs() end,\n",
       "when tab: Always note always shown",
       expect="chosen, the Always note is shown", script=S)

# The note naming the control but not the tab it is on.
mutate("Options/When.lua",
       ":format(Ref(L[\"My target first\"], TAB.who))\n",
       ":format(L[\"My target first\"])\n",
       "when tab: Always note without its tab",
       expect="the Always note does not name My target first and its tab", script=S)

# --- Only offer people whose buffs can be read ---

# The switch shown whatever is chosen: Always offer reads nobody's buffs, so
# nothing is refused there and the box would change nothing.
mutate("Options/When.lua",
       "\t\t\t\thidden = function() return F().whenBuffed == \"always\" or not HasClassBuffs() end,\n",
       "\t\t\t\thidden = function() return false end,\n",
       "when tab: verified-only switch always shown",
       expect="always chosen, Only offer people whose buffs can be read is shown", script=S)

# The same with only the hunter's half of the rule left.
mutate("Options/When.lua",
       "\t\t\t\thidden = function() return F().whenBuffed == \"always\" or not HasClassBuffs() end,\n",
       "\t\t\t\thidden = function() return not HasClassBuffs() end,\n",
       "when tab: verified-only switch with Always offer",
       expect="always chosen, Only offer people whose buffs can be read is shown", script=S)

# And with only Always offer's half: the switch on a hunter's page, whose own
# buffs are always read. Caught by own 24 in tests/scenarios/ownbuffs.lua.
mutate("Options/When.lua",
       "\t\t\t\thidden = function() return F().whenBuffed == \"always\" or not HasClassBuffs() end,\n",
       "\t\t\t\thidden = function() return F().whenBuffed == \"always\" end,\n",
       "when tab: verified-only switch on a hunter's page",
       expect="verifiedOnly is shown to a hunter (skip chosen)", script=S)

# The rule turned round: the switch only under Always offer, gone from the
# two choices where somebody can be refused.
mutate("Options/When.lua",
       "\t\t\t\thidden = function() return F().whenBuffed == \"always\" or not HasClassBuffs() end,\n",
       "\t\t\t\thidden = function() return F().whenBuffed ~= \"always\" or not HasClassBuffs() end,\n",
       "when tab: verified-only switch only with Always offer",
       expect="skip chosen, Only offer people whose buffs can be read is hidden", script=S)

# A string or a number in the saved file left as it is: true on every scan,
# and no unverified offer ever again, with the box unable to show why.
mutate("Core.lua",
       "\tboolean(profile.filters, \"verifiedOnly\", false)\n",
       "",
       "when tab: verified-only switch left out of the repair",
       expect="a nonsense value for Only offer people whose buffs can be read survived", script=S)

# Left out of the page's Put these back to default. Caught by the When to
# offer reset in tests/scenarios/options-advanced.lua.
mutate("Options/Advanced.lua",
       "\"filters.refreshUnder\", \"filters.verifiedOnly\", \"filters.hideMounted\",",
       "\"filters.refreshUnder\", \"filters.hideMounted\",",
       "when tab: verified-only switch not reset",
       expect="when reset: filters.verifiedOnly was not put back", script=S)

# --- the combat switch ---

# Moved here and bound to the filters table, so the saved setting is lost.
mutate("Options/Look.lua",
       "red if it failed.\"],\n"
       "\t\t\t\torder = 32.5,\n"
       "\t\t\t\twidth = \"full\",\n"
       "\t\t\t\tget = pGet,\n"
       "\t\t\t\tset = pSet,\n",
       "red if it failed.\"],\n"
       "\t\t\t\torder = 32.5,\n"
       "\t\t\t\twidth = \"full\",\n"
       "\t\t\t\tget = Page.fGet,\n"
       "\t\t\t\tset = Page.fSet,\n",
       "when tab: combat switch writes filters",
       expect="hideInCombat writes prompt.hideInCombat no longer", script=S)

# --- the mana note ---

# Zero read as a floor rather than as off.
mutate("Options/When.lua",
       "\t\t\t\t\tif floor <= 0 then\n",
       "\t\t\t\t\tif floor < 0 then\n",
       "when tab: mana note at zero",
       expect="the mana note at zero does not say the floor is off", script=S)

# The resume point given as the floor itself.
mutate("Options/When.lua",
       ":format(floor, floor + 5)\n",
       ":format(floor, floor)\n",
       "when tab: mana note resume point",
       expect="the rest comes back at 35%", script=S)

# The note left on a warrior's page after the floor has gone.
mutate("Options/When.lua",
       "\t\t\t\thidden = noManaBar,\n"
       "\t\t\t\tname = function()\n",
       "\t\t\t\thidden = function() return false end,\n"
       "\t\t\t\tname = function()\n",
       "when tab: mana note on a warrior's page",
       expect="the mana note is on a warrior's page", script=S)
