# Mutations for tests/scenarios/aceconfig.lua: the options table as the real
# AceConfigRegistry-3.0 validator judges it.
#
# Run by tests/selftest.py with mutate() in scope.

S = "runscenarios.py"

# The 1.1.2 bug: a function in `width`, which AceConfigDialog reads but the
# registry refuses, so the page would not open at all.
mutate("Options.lua",
       "\t\tnode.width = FITTERS[kind](info)\n",
       "\t\tnode.width = FITTERS[kind]\n",
       "aceconfig: a function for a width",
       expect="expected a string or number, got 'function",
       script=S)

# A key the registry does not know, on a control every class sees.
mutate("Options.lua",
       "\t\t\t\tconfirm = function(_, v) return Quick.Confirm(Quick.VOICE, v) end,\n",
       "\t\t\t\tconfirm = function(_, v) return Quick.Confirm(Quick.VOICE, v) end,\n"
       "\t\t\t\ttooltip = \"not a key AceConfig knows\",\n",
       "aceconfig: an unknown key on an option",
       expect="unknown parameter",
       script=S)
