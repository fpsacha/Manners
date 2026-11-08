# The call to turn on friendly nameplates: Who to buff's red dot and red note,
# and Start here's note and button under step 1 (tests/scenarios/plates-cta.lua).
# Each fault is caught by the scenario that names it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# Who to buff's dot blind to the nameplates.
mutate("Options/Shared.lua",
       "\t\t\tor (Page.PlatesWanted ~= nil and Page.PlatesWanted())\n",
       "\t\t\tor false\n",
       "plates-cta: no red dot for the nameplates",
       expect="Who to buff has no red dot", script=S)

# ...and lit with passers-by off.
mutate("Options/Who.lua",
       "function Page.PlatesWanted()\n\treturn not PlatesHidden()\n",
       "function Page.PlatesWanted()\n\treturn ns.FriendlyPlatesOff()\n",
       "plates-cta: the call made with passers-by off",
       expect="passers-by are off and Who to buff has a red dot", script=S)

# The note under the red dot back to grey.
mutate("Options/Who.lua",
       "\t\t\t\tname = \"|cffff8080\"\n"
       "\t\t\t\t\t.. L[\"Turn on friendly nameplates so Manners can see passers-by",
       "\t\t\t\tname = \"|cff888888\"\n"
       "\t\t\t\t\t.. L[\"Turn on friendly nameplates so Manners can see passers-by",
       "plates-cta: the note under the dot is grey",
       expect="the note under the red dot is not red", script=S)

# Start here never asks.
mutate("Options/Start.lua",
       "\t\t\t\t\treturn noPrompt() or Quick.Asking() or not (Page.PlatesWanted and Page.PlatesWanted())\n"
       "\t\t\t\tend,\n"
       "\t\t\t\tname = \"|cffff8080\"",
       "\t\t\t\t\treturn true\n"
       "\t\t\t\tend,\n"
       "\t\t\t\tname = \"|cffff8080\"",
       "plates-cta: Start here's note never shown",
       expect="Start here asks for the nameplates under step 1", script=S)

# ...or asks while Quick setup stands in for step 1.
mutate("Options/Start.lua",
       "\t\t\t\t\treturn noPrompt() or Quick.Asking() or not (Page.PlatesWanted and Page.PlatesWanted())\n"
       "\t\t\t\tend,\n"
       "\t\t\t\tname = \"|cffff8080\"",
       "\t\t\t\t\treturn noPrompt() or not (Page.PlatesWanted and Page.PlatesWanted())\n"
       "\t\t\t\tend,\n"
       "\t\t\t\tname = \"|cffff8080\"",
       "plates-cta: Start here asks over Quick setup",
       expect="shown while Quick setup asks", script=S)

# Start here's button does nothing.
mutate("Options/Start.lua",
       "\t\t\t\tfunc = function()\n"
       "\t\t\t\t\tif ns.ShowFriendlyPlates() then ns.RefreshOptionsDisplay() end\n"
       "\t\t\t\tend,\n"
       "\t\t\t},\n"
       "\n"
       "\t\t\t-- Step 2.",
       "\t\t\t\tfunc = function() end,\n"
       "\t\t\t},\n"
       "\n"
       "\t\t\t-- Step 2.",
       "plates-cta: Start here's button sets nothing",
       expect="the click made 0 changes", script=S)
