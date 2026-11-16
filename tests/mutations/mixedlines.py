# Mutations for the player's own lines said among the In character ones
# (speech.mixedLines; Speech.lua, MixedIn and Roll; Options/Say.lua;
# Layout.lua; Core.lua's default and repair). Caught by
# tests/scenarios/mixedlines.lua.

S = "runscenarios.py"

mutate("Speech.lua",
       "\t\t\tlocal own = MixedIn(db, entry, command, budget)\n\t\t\tif own then return own end\n",
       "",
       "mixedlines: the own lines never said",
       expect="the roll came up, and the line was", script=S)

mutate("Speech.lua",
       "\t\treturn math.random(MIXED_ONE_IN) == 1\n",
       "\t\treturn true\n",
       "mixedlines: every press says an own line",
       expect="in three said an own line", script=S)

mutate("Speech.lua",
       "\t\tif #fits == 0 or not OwnTurn(db.speech.mixedShare) then return nil end\n",
       "\t\tif not OwnTurn(db.speech.mixedShare) then return nil end\n",
       "mixedlines: nothing said when no own line fits",
       expect="with only a line too long, the line was", script=S)

mutate("Speech.lua",
       "\t\t\t\t\tif #line <= budget then fits[#fits + 1] = line end\n\t\t\t\tend\n\t\t\tend\n\t\tend\n\t\tif #fits == 0 or not OwnTurn(",
       "\t\t\t\t\tfits[#fits + 1] = line\n\t\t\t\tend\n\t\t\tend\n\t\tend\n\t\tif #fits == 0 or not OwnTurn(",
       "mixedlines: an own line too long for the macro is said",
       expect="with one line too long, the line was", script=S)

mutate("Speech.lua",
       "\t\t\t\tphrase = SanitizePhrase(ns.Swap(phrase, \"{buff}\", spell))\n",
       "\t\t\t\tphrase = SanitizePhrase(phrase)\n",
       "mixedlines: the spell's name not written into an own line",
       expect="the second own line was said as", script=S)

mutate("Core.lua",
       "\t\t\tmixedLines = \"\",\n",
       "\t\t\tmixedLines = \"Well met, {name}!\",\n",
       "mixedlines: a line in the box on a new profile",
       expect="a new profile's own lines are", script=S)

mutate("Core.lua",
       "\tif type(speech.mixedLines) ~= \"string\" then speech.mixedLines = \"\" end\n",
       "",
       "mixedlines: a damaged box kept",
       expect="a damaged box was left as", script=S)

mutate("Options/Say.lua",
       "\t\t\t\t\tSP().mixedLines = type(value) == \"string\" and value or \"\"\n",
       "",
       "mixedlines: typing in the box writes nothing",
       expect="typing in it wrote", script=S)

mutate("Options/Say.lua",
       "\t\t\t\t\treturn speechOff() or not (ns.InCharacter and ns.InCharacter.Active(SP()))\n",
       "\t\t\t\t\treturn speechOff()\n",
       "mixedlines: the box shown with another set loaded",
       expect="shown with another set loaded", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t\"click.mixedLines\",\n",
       "",
       "mixedlines: the box not placed on the page",
       expect="mixedLines", script=S)
