# The What I say tab (Options.lua, BuildSpeechTab). Each fault is caught by
# the scenario in tests/scenarios/options-click.lua that names it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# --- the tab and its order ---

mutate("Options/Say.lua",
       "\t\tname = TAB.click,\n\t\torder = 4,\n",
       "\t\tname = TAB.click,\n\t\torder = 5,\n",
       "click: the tab is not fourth",
       expect="the What I say tab is not fourth", script=S)

mutate("Options/Say.lua",
       "\t\t\t\torder = 11,\n\t\t\t\twidth = \"full\",\n\t\t\t\t-- Nobody is noticed buffing you with that source off.\n",
       "\t\t\t\torder = 21.2,\n\t\t\t\twidth = \"full\",\n\t\t\t\t-- Nobody is noticed buffing you with that source off.\n",
       "click: /thank back under the lines",
       expect="/thank people who buff me is not first under Thanks and speech", script=S)

# --- the combat notice ---

mutate("Options/Say.lua",
       "\t\t\t-- fight ends, and until then a press runs the old one.\n"
       "\t\t\tcombatNotice = {\n\t\t\t\ttype = \"description\",\n\t\t\t\torder = 0.5,\n"
       "\t\t\t\tfontSize = \"medium\",\n\t\t\t\thidden = function() return not InCombatLockdown() end,\n",
       "\t\t\t-- fight ends, and until then a press runs the old one.\n"
       "\t\t\tcombatNotice = {\n\t\t\t\ttype = \"description\",\n\t\t\t\torder = 0.5,\n"
       "\t\t\t\tfontSize = \"medium\",\n\t\t\t\thidden = function() return false end,\n",
       "click: combat notice out of combat",
       expect="the combat notice shows out of combat", script=S)

# --- speech on and off ---

mutate("Options/Say.lua",
       "\t\t\t\torder = 13,\n\t\t\t\tdisabled = speechOff,\n",
       "\t\t\t\torder = 13,\n",
       "click: channel live with speech off",
       expect="Where to say it is live with speech off", script=S)

mutate("Options/Say.lua",
       "\t\t\t\torder = 14,\n\t\t\t\twidth = \"full\",\n\t\t\t\tdisabled = speechOff,\n",
       "\t\t\t\torder = 14,\n\t\t\t\twidth = \"full\",\n",
       "click: only-when-returning live with speech off",
       expect="Only when I buff someone back is live with speech off", script=S)

# Re-anchored: the note under the switch is gone (it only repeated it, and
# said "hear" for "say"), so the fault now is the note coming back.
mutate("Options/Say.lua",
       "\t\t\t-- In place of the Lines section while nothing is said.\n",
       "\t\t\tonlyNote = {\n\t\t\t\ttype = \"description\",\n\t\t\t\torder = 14.5,\n"
       "\t\t\t\tname = L[\"You will only hear a line when you return a favour.\"],\n\t\t\t},\n"
       "\t\t\t-- In place of the Lines section while nothing is said.\n",
       "click: no note under only-when-returning",
       expect="the note repeating Only when I buff someone back is still on the tab", script=S)

# Re-anchored from the same note: the switch it sat under, relabelled. Pinned
# to What I say's switch by its order: Start here carries the same label
# under its "When I buff someone" choice, earlier in the file.
mutate("Options/Say.lua",
       "\t\t\t\tname = L[\"Only when I buff someone back\"],\n"
       "\t\t\t\tdesc = L[\"Off, you also speak when you buff someone first.\"],\n"
       "\t\t\t\torder = 14,\n",
       "\t\t\t\tname = L[\"Only when I return a favour\"],\n"
       "\t\t\t\tdesc = L[\"Off, you also speak when you buff someone first.\"],\n"
       "\t\t\t\torder = 14,\n",
       "click: only-when-returning note with speech off",
       expect="onlyWhenReturning is labelled", script=S)

mutate("Options/Say.lua",
       "\t\t\t\thidden = function() return not speechOff() end,\n",
       "\t\t\t\thidden = function() return true end,\n",
       "click: no hint with speech off",
       expect="nothing says how to get the lines back with speech off", script=S)

mutate("Options/Say.lua",
       "\t\t\t\thidden = function() return not speechOff() end,\n",
       "\t\t\t\thidden = function() return false end,\n",
       "click: hint with speech on",
       expect="the hint to tick Say a line stays up with speech on", script=S)

# --- the Lines section hidden, not greyed ---

mutate("Options/Say.lua",
       "\tlocal function speechOff() return not SP().enabled end\n",
       "\tlocal function speechOff() return false end\n",
       "click: lines section always shown",
       expect="the Lines header stays up with speech off", script=S)

mutate("Options/Say.lua",
       "name = L[\"Lines\"], order = 20, hidden = speechOff },\n",
       "name = L[\"Lines\"], order = 20 },\n",
       "click: lines header with speech off",
       expect="the Lines header stays up with speech off", script=S)

mutate("Options/Say.lua",
       "\t\t\t\torder = 21,\n\t\t\t\thidden = speechOff,\n",
       "\t\t\t\torder = 21,\n",
       "click: line set with speech off",
       expect="the Line set dropdown stays up with speech off", script=S)

mutate("Options/Say.lua",
       "\t\t\t\torder = 22,\n\t\t\t\thidden = speechOff,\n",
       "\t\t\t\torder = 22,\n",
       "click: placeholder help with speech off",
       expect="the placeholder help stays up with speech off", script=S)

mutate("Options/Say.lua",
       "\t\t\t\twidth = \"full\",\n\t\t\t\thidden = speechOff,\n",
       "\t\t\t\twidth = \"full\",\n",
       "click: phrase box with speech off",
       expect="the phrase box stays up with speech off", script=S)

mutate("Options/Say.lua",
       "\t\t\t\torder = 24,\n\t\t\t\thidden = speechOff,\n",
       "\t\t\t\torder = 24,\n",
       "click: try a few with speech off",
       expect="Try a few lines stays up with speech off", script=S)

mutate("Options/Say.lua",
       "\t\t\t\torder = 25,\n\t\t\t\thidden = speechOff,\n",
       "\t\t\t\torder = 25,\n",
       "click: limits with speech off",
       expect="the limits line stays up with speech off", script=S)

mutate("Options/Say.lua",
       "\t\t\t\thidden = function() return speechOff() or not inCharacter() end,\n",
       "\t\t\t\thidden = function() return not inCharacter() end,\n",
       "click: in character note with speech off",
       expect="the In character note stays up with speech off", script=S)

# --- the Line set names ---

mutate("Options/Say.lua",
       "\t\troleplay = L[\"Fantasy (general)\"],\n",
       "",
       "click: roleplay keeps its bare name",
       expect="the general set is not named Fantasy (general)", script=S)

mutate("Options/Say.lua",
       "\t\tincharacter = L[\"In character (fits your race and class)\"],\n",
       "",
       "click: in character keeps its bare name",
       expect="the In character set is named", script=S)

# Start here's quick choice named apart from the Line set it loads.
mutate("Options/Start.lua",
       "\ttable.insert(Quick.VOICE, 4, { key = \"incharacter\", name = L[\"In character (fits your race and class)\"],\n",
       "\ttable.insert(Quick.VOICE, 4, { key = \"incharacter\", name = L[\"Roleplay, in character\"],\n",
       "click: in character named twice",
       expect="Start here names the In character set differently", script=S)

mutate("Options/Say.lua",
       "\t\t\t\t\t\tout[key] = SET_LABEL[key] or ns.PHRASE_SETS[key].label\n",
       "\t\t\t\t\t\tout[key] = SET_LABEL[key]\n",
       "click: other sets unnamed",
       expect="has no name in the Line set dropdown", script=S)

# --- editing In character, and the way back ---

mutate("Options/Say.lua",
       "\t\t\t\t\t\treturn L[\"Editing these turns In character off and uses only your lines. Continue?\"]\n",
       "\t\t\t\t\t\treturn false\n",
       "click: editing in character never asks",
       expect="editing In character's lines does not ask first", script=S)

mutate("Options/Say.lua",
       "\t\t\t\t\tif ns.InCharacter and ns.InCharacter.Active(SP()) then\n"
       "\t\t\t\t\t\treturn L[\"Editing these turns",
       "\t\t\t\t\tif true then\n"
       "\t\t\t\t\t\treturn L[\"Editing these turns",
       "click: editing own lines asks",
       expect="the box asks before editing lines that are already the player's own", script=S)

mutate("Options/Say.lua",
       "\t\t\t\t\treturn speechOff() or SP().presetChoice ~= \"incharacter\" or inCharacter()\n",
       "\t\t\t\t\treturn true\n",
       "click: no way back to in character",
       expect="no way back to In character once its lines are edited", script=S)

mutate("Options/Say.lua",
       "\t\t\t\t\treturn speechOff() or SP().presetChoice ~= \"incharacter\" or inCharacter()\n",
       "\t\t\t\t\treturn speechOff() or SP().presetChoice ~= \"incharacter\"\n",
       "click: way back offered while in character",
       expect="Go back to In character is offered while In character is already on", script=S)

mutate("Options/Say.lua",
       "\t\t\t\t\treturn speechOff() or SP().presetChoice ~= \"incharacter\" or inCharacter()\n",
       "\t\t\t\t\treturn speechOff() or inCharacter()\n",
       "click: way back offered over another set",
       expect="Go back to In character is offered over a different set", script=S)

mutate("Options/Say.lua",
       "\t\t\t\t\treturn speechOff() or SP().presetChoice ~= \"incharacter\" or inCharacter()\n",
       "\t\t\t\t\treturn SP().presetChoice ~= \"incharacter\" or inCharacter()\n",
       "click: way back offered with speech off",
       expect="Go back to In character stays up with speech off", script=S)

mutate("Options/Say.lua",
       "\t\t\t\tfunc = function() loadSet(\"incharacter\") end,\n",
       "\t\t\t\tfunc = function() end,\n",
       "click: way back does nothing",
       expect="Go back to In character did not bring it back", script=S)

# --- the order of the channels ---

mutate("Options/Say.lua",
       "\t\t\t\tsorting = { \"SAY\", \"WHISPER\", \"EMOTE\", \"PARTY\", \"RAID\", \"YELL\" },\n",
       "",
       "click: channels in alphabetical order",
       expect="the Where to say it dropdown is not in its order", script=S)
