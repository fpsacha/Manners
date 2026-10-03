# Mutations for the spoken line and the range (beta.8: a thank-you said over a
# buff the game refused for range). Each is caught by the scenario in
# tests/scenarios/speech-range.lua that names it.

# The range reading ignored: the line goes in for somebody known out of reach.
mutate("Prompt/Macro.lua",
       "\tlocal speak = not silent and entry.ranged ~= false and not ns.SpeechHeld(entry.name)\n",
       "\tlocal speak = not silent and not ns.SpeechHeld(entry.name)\n",
       "speech armed out of range",
       expect="speech-range: the line follows what the scan knows of the range",
       script="runscenarios.py")

# Unknown range taken for out of range: silences everybody the client will
# not measure.
mutate("Prompt/Macro.lua",
       "\tlocal speak = not silent and entry.ranged ~= false and not ns.SpeechHeld(entry.name)\n",
       "\tlocal speak = not silent and entry.ranged == true and not ns.SpeechHeld(entry.name)\n",
       "speech silenced when range is unknown",
       expect="speech-range: the line follows what the scan knows of the range",
       script="runscenarios.py")

# The macro's key blind to whether the line is armed: a change of range
# never rebuilds the macro.
mutate("Prompt/Macro.lua",
       "\t\ttostring(StillTargeted(entry)), tostring(speak) }, \"\\1\")\n",
       "\t\ttostring(StillTargeted(entry)) }, \"\\1\")\n",
       "macro key ignores the spoken line",
       expect="speech-range: the line follows what the scan knows of the range",
       script="runscenarios.py")

# The tooltip quoting a line the macro left out.
mutate("Prompt/Macro.lua",
       "\tif S.phraseText and S.phraseArmed then\n",
       "\tif S.phraseText then\n",
       "tooltip quotes a held line",
       expect="speech-range: the line follows what the scan knows of the range",
       script="runscenarios.py")

# PreClick not asking the range again for the entry it re-keys.
mutate("Prompt/Press.lua",
       "\t\tPrompt:ApplyTarget(S.current, OutOfReachNow(S.current))\n",
       "\t\tPrompt:ApplyTarget(S.current)\n",
       "press keeps the line for somebody who walked off",
       expect="speech-range: the press drops the line for somebody who walked off",
       script="runscenarios.py")

# The last-moment range reading never saying no.
mutate("Prompt/Press.lua",
       "\treturn ns.ReachNow(entry.unit, entry.buff) == false\n",
       "\treturn false\n",
       "last-moment range never out",
       expect="speech-range: the press drops the line for somebody who walked off",
       script="runscenarios.py")

# A refusal holding nothing: the next press talks again.
mutate("Prompt/Macro.lua",
       "\tlocal speak = not silent and entry.ranged ~= false and not ns.SpeechHeld(entry.name)\n",
       "\tlocal speak = not silent and entry.ranged ~= false\n",
       "refusal does not hold the line",
       expect="speech-range: a refusal holds the line until neither",
       script="runscenarios.py")

# The error inside the press's window not noted as a refusal.
mutate("Clicks.lua",
       "\tRewindClick(pending)\n\tns.NoteRefusal(pending.name, message)\n",
       "\tRewindClick(pending)\n",
       "error refusal not noted",
       expect="speech-range: a refusal holds the line until neither",
       script="runscenarios.py")

# The hold never running out.
mutate("Queue.lua",
       "\tlocal QUIET_SECONDS = 30\n",
       "\tlocal QUIET_SECONDS = 3000\n",
       "line held for ever",
       expect="speech-range: a refusal holds the line until half a minute",
       script="runscenarios.py")

# A cast that lands forgetting nothing.
mutate("Clicks.lua",
       "\t\t\tif record.landed then ns.NoteLanded(record.name) end\n",
       "",
       "landed cast does not clear the hold",
       expect="speech-range: a refusal holds the line until a cast that lands",
       script="runscenarios.py")

# PreClick's main path trusting the held entry's old range reading.
mutate("Prompt/Press.lua",
       "\tPrompt:ApplyTarget(top, OutOfReachNow(top))\n",
       "\tPrompt:ApplyTarget(top)\n",
       "press keeps the line for a held entry that walked off",
       expect="speech-range: the press asks again for a held entry that walked off",
       script="runscenarios.py")

# A press the settle path calls a failure (the cast went to somebody else)
# holding nothing: the next press thanks them again.
mutate("Clicks.lua",
       "\t\t-- went, so it is held; no back-off, since the game refused nobody.\n\t\tns.NoteRefusal(pending.name, nil, true)\n",
       "\t\t-- went, so it is held; no back-off, since the game refused nobody.\n",
       "settle failure does not hold the line",
       expect="speech-range: a press that went to somebody else holds the line",
       script="runscenarios.py")

# The channel never asked: "/party Thanks" in the macro of a player in no
# party, on every press.
mutate("Prompt/Macro.lua",
       "\t\tand ns.ChannelOpen()\n",
       "\n",
       "speech: /party with nobody to hear it",
       expect="speech-range: /party is said only in a party",
       script="runscenarios.py")

# /raid taken for any group: a party that is no raid hears nothing of it.
mutate("Speech.lua",
       "\t\tmember = IsInRaid and IsInRaid()\n",
       "\t\tmember = IsInGroup and IsInGroup()\n",
       "speech: /raid said in a party",
       expect="speech-range: /raid is said only in a raid",
       script="runscenarios.py")
