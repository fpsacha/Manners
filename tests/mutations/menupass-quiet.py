# Mutations for the Quiet times page: tests/scenarios/menupass-quiet.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts one rule back and
# names the scenario that objects.

S = "runscenarios.py"

mutate("Options/Window/Layout.lua",
       "\t\t[\"click.quietInParty\"] = function() return L[\"Needs %s ticked, on %s.\"]:format(NameOf(\"click.enabled\"), TabOf(\"click.enabled\")) end,\n",
       "",
       "menupass-quiet: Say nothing in a party greys with no word of what to tick",
       expect="menupass-quiet: greyed group switches", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t\"click.thankDelay\",\n",
       "\t\t\t\t\t{ \"click.thankDelay\", indent = true },\n",
       "menupass-quiet: the pause sits under one thank switch",
       expect="menupass-quiet: with only the whisper on", script=S)

mutate("Options/Advanced.lua",
       "\tkeep = function(path) return (path == \"speech.quietInParty\" or path == \"speech.quietInRaid\") and not HasClassBuffs() end,\n",
       "",
       "menupass-quiet: Quiet times' reset puts back a rogue's speech",
       expect="menupass-quiet: Quiet times' reset", script=S)
