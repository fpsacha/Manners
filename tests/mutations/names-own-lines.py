# Mutations for First name only (speech.firstNameOnly; Speech.lua, ns.SaidName),
# How often my own lines are said (speech.mixedShare; Speech.lua, OwnTurn) and
# the In character lines left out (speech.leftOut; Phrases.lua, RP.Pick and
# RP.Last; Options/Say.lua; Core.lua's defaults and repair; Commands.lua's
# /manners debug; Selftest.lua). Caught by tests/scenarios/names-own-lines.lua.

S = "runscenarios.py"

# ------------------------------------------------ first name only
mutate("Speech.lua",
       "\treturn ns.FirstName(name) or name\nend\n",
       "\treturn name\nend\n",
       "names-own-lines: first name only says the whole name",
       expect="names-own-lines: first name only says the first word, the whisper keeps the whole name", script=S)

mutate("Speech.lua",
       "\t\t\twhisperTo = WhisperName(entry)\n",
       "\t\t\twhisperTo = ns.SaidName(WhisperName(entry))\n",
       "names-own-lines: the whisper goes to the first name",
       expect="names-own-lines: first name only says the first word, the whisper keeps the whole name", script=S)

mutate("Speech.lua",
       "\t\tif line and whisperTo and entry.targetName ~= nil\n",
       "\t\tif line and whisperTo and entry.targetName ~= nil and false\n",
       "names-own-lines: the whisper guard skipped",
       expect="names-own-lines: a one-word name is said whole, and the whisper guard still refuses a misread", script=S)

mutate("Speech.lua",
       "\t\t\t\tlocal phrase = ns.Swap(clean, \"{name}\", ns.SaidName(entry.short or entry.name))\n",
       "\t\t\t\tlocal phrase = ns.Swap(clean, \"{name}\", entry.short or entry.name)\n",
       "names-own-lines: a line mixed in says the whole name",
       expect="names-own-lines: first name only reaches In character, the lines mixed in and the whispered thank-you", script=S)

mutate("Speech.lua",
       "\t\t\tlocal phrase = ns.Swap(raw, \"{name}\", ns.SaidName(entry.short or entry.name))\n",
       "\t\t\tlocal phrase = ns.Swap(raw, \"{name}\", entry.short or entry.name)\n",
       "names-own-lines: a fixed set says the whole name",
       expect="names-own-lines: first name only reaches In character, the lines mixed in and the whispered thank-you", script=S)

mutate("Phrases.lua",
       "\t\tif ns.SaidName then name = ns.SaidName(name) end\n",
       "",
       "names-own-lines: In character says the whole name",
       expect="names-own-lines: first name only reaches In character, the lines mixed in and the whispered thank-you", script=S)

mutate("Core.lua",
       "\t\t\tfirstNameOnly = false,\n",
       "\t\t\tfirstNameOnly = true,\n",
       "names-own-lines: first name only on by default",
       expect="names-own-lines: First name only is a switch on What I say, off by default", script=S)

mutate("Options/Say.lua",
       "\t\t\t\tdisabled = function() return speechOff() and not P().thankWhisper end,\n",
       "\t\t\t\tdisabled = speechOff,\n",
       "names-own-lines: first name only greyed for the whispered thank-you",
       expect="names-own-lines: First name only is a switch on What I say, off by default", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t\"click.firstNameOnly\",\n",
       "",
       "names-own-lines: first name only not placed",
       expect="names-own-lines: First name only is a switch on What I say, off by default", script=S)

mutate("Commands.lua",
       "\t\tif db.speech.firstNameOnly == true then\n",
       "\t\tif false then\n",
       "names-own-lines: debug says nothing of first name only",
       expect="names-own-lines: First name only is a switch on What I say, off by default", script=S)

mutate("Selftest.lua",
       "\t\tspeech.firstNameOnly == true and \"on\" or \"off\", tostring(speech.mixedShare),\n",
       "\t\t\"off\", tostring(speech.mixedShare),\n",
       "names-own-lines: the check-up says nothing of first name only",
       expect="names-own-lines: First name only is a switch on What I say, off by default", script=S)

# ------------------------------------------------ how often my own lines are said
mutate("Speech.lua",
       "\t\tif share == \"always\" then return true end\n",
       "",
       "names-own-lines: every press rolls like one in three",
       expect="names-own-lines: how often my own lines are said", script=S)

mutate("Speech.lua",
       "\t\tif share == \"half\" then return math.random(2) == 1 end\n",
       "",
       "names-own-lines: half rolls like one in three",
       expect="names-own-lines: how often my own lines are said", script=S)

mutate("Speech.lua",
       "\t\tif share == \"twothirds\" then return math.random(3) ~= 1 end\n",
       "\t\tif share == \"twothirds\" then return math.random(3) == 1 end\n",
       "names-own-lines: two in three rolls like one in three",
       expect="names-own-lines: how often my own lines are said", script=S)

mutate("Core.lua",
       "\t\t\tmixedShare = \"third\",\n",
       "\t\t\tmixedShare = \"half\",\n",
       "names-own-lines: half by default",
       expect="names-own-lines: how often my own lines are said", script=S)

mutate("Core.lua",
       "\toneOf(profile.speech, \"mixedShare\", { third = true, half = true, twothirds = true, always = true }, \"third\")\n",
       "",
       "names-own-lines: an unknown share kept",
       expect="names-own-lines: how often my own lines are said", script=S)

mutate("Options/Say.lua",
       "\t\t\t\thidden = function() return not inCharacter() or speechOff() end,\n",
       "\t\t\t\thidden = speechOff,\n",
       "names-own-lines: the share shown with another set loaded",
       expect="names-own-lines: the share is chosen under the box, and the box's note stays true", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t{ \"click.mixedShare\", indent = true },\n",
       "\t\t\t\t\t\"click.mixedShare\",\n",
       "names-own-lines: the share not indented under the box",
       expect="names-own-lines: the share is chosen under the box, and the box's note stays true", script=S)

# ------------------------------------------------ lines left out
mutate("Phrases.lua",
       "\t\t\t\t\tand not (out and out[text])\n",
       "",
       "names-own-lines: a left-out line said",
       expect="names-own-lines: a left-out line is never said", script=S)

mutate("Phrases.lua",
       "\t\tif list ~= outList or #list ~= outCount then\n",
       "\t\tif list ~= outList then\n",
       "names-own-lines: a line added to the list later said",
       expect="names-own-lines: a left-out line is never said", script=S)

mutate("Phrases.lua",
       "\t\tlastSaid = text\n",
       "",
       "names-own-lines: the last line said never remembered",
       expect="names-own-lines: Never say my last line again leaves out the last line said", script=S)

mutate("Options/Say.lua",
       "\t\t\t\t\tlocal last = inCharacter() and ns.InCharacter.Last()\n\t\t\t\t\tif not last then return true end\n",
       "\t\t\t\t\tlocal last = ns.InCharacter.Last()\n\t\t\t\t\tif not last then return true end\n",
       "names-own-lines: the button live with another set loaded",
       expect="names-own-lines: Never say my last line again leaves out the last line said", script=S)

mutate("Options/Say.lua",
       "\t\t\t\t\tlist[#list + 1] = last\n",
       "",
       "names-own-lines: the button leaves nothing out",
       expect="names-own-lines: Never say my last line again leaves out the last line said", script=S)

mutate("Options/Say.lua",
       "\t\t\t\t\t\tif text == last then return true end\n",
       "",
       "names-own-lines: the button live with the line already left out",
       expect="names-own-lines: Never say my last line again leaves out the last line said", script=S)

mutate("Options/Say.lua",
       "\t\t\t\t\t\tif text == last then return end\n",
       "",
       "names-own-lines: the button writes a line twice",
       expect="names-own-lines: Never say my last line again leaves out the last line said", script=S)

mutate("Options/Say.lua",
       "\t\t\t\t\t\tif row ~= \"\" and not seen[row] and #list < ns.LEFT_OUT_MAX then\n",
       "\t\t\t\t\t\tif row ~= \"\" and not seen[row] then\n",
       "names-own-lines: the box holds more than the cap",
       expect="names-own-lines: Never say my last line again leaves out the last line said", script=S)

mutate("Options/Say.lua",
       "\t\t\t\t\tSP().leftOut = list\n\t\t\t\t\tns.Prompt:InvalidateMacro()\n\t\t\t\tend,\n\t\t\t},\n",
       "\t\t\t\t\tns.Prompt:InvalidateMacro()\n\t\t\t\tend,\n\t\t\t},\n",
       "names-own-lines: the box writes nothing",
       expect="names-own-lines: Never say my last line again leaves out the last line said", script=S)

mutate("Core.lua",
       "\t\t\t\t\tif text ~= \"\" and #text <= 500 and not seen[text] and #clean < ns.LEFT_OUT_MAX then\n",
       "\t\t\t\t\tif text ~= \"\" and #text <= 500 and not seen[text] then\n",
       "names-own-lines: the load keeps more than the cap",
       expect="names-own-lines: the list is repaired at load and does not travel in a pasted string", script=S)

mutate("Core.lua",
       "\t\tspeech.leftOut = clean\n",
       "",
       "names-own-lines: a damaged list kept",
       expect="names-own-lines: the list is repaired at load and does not travel in a pasted string", script=S)

mutate("Commands.lua",
       "\t\tif leftOut > 0 then\n",
       "\t\tif false then\n",
       "names-own-lines: debug says nothing of the lines left out",
       expect="names-own-lines: the list is repaired at load and does not travel in a pasted string", script=S)
