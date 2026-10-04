# Mutations for the spoken line and the range (beta.8: a thank-you said over a
# buff the game refused for range), and for the line going only with a press
# known to land (speech-range-6: "The Light already likes you, Weirbeard
# Jenkins" over "Out of range."). Each is caught by the scenario in
# tests/scenarios/speech-range.lua that names it.

# The range reading ignored: the line goes in for somebody known out of reach.
mutate("Prompt/Macro.lua",
       "\tlocal speak = not silent and entry.ranged == true and not ns.SpeechHeld(entry.name)\n",
       "\tlocal speak = not silent and not ns.SpeechHeld(entry.name)\n",
       "speech armed out of range",
       expect="speech-range: the line follows what the scan knows of the range",
       script="runscenarios.py")

# Unknown range taken for in range, as it was before: the tooltip quotes a
# line for somebody nobody could measure, which the press then leaves out.
mutate("Prompt/Macro.lua",
       "\tlocal speak = not silent and entry.ranged == true and not ns.SpeechHeld(entry.name)\n",
       "\tlocal speak = not silent and entry.ranged ~= false and not ns.SpeechHeld(entry.name)\n",
       "speech armed when range is unknown",
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

# PreClick not judging the line again for the entry it re-keys.
mutate("Prompt/Press.lua",
       "\t\tPrompt:ApplyTarget(S.current, HoldLine(S.current, verdicts))\n",
       "\t\tPrompt:ApplyTarget(S.current)\n",
       "press keeps the line for somebody who walked off",
       expect="speech-range: the press drops the line for somebody who walked off",
       script="runscenarios.py")

# The last-moment range reading never asked. Somebody who walked off from the
# token the scan measured is turned down by the press's own scan; the reading
# alone matters on a token the scan only called far.
mutate("Prompt/Press.lua",
       "\tif ns.ReachNow(unit, entry.buff) ~= true then return true end\n",
       "",
       "last-moment range never out",
       expect="speech-range: the press follows him to another token (out of reach there)",
       script="runscenarios.py")

# A refusal holding nothing: the next press talks again.
mutate("Prompt/Macro.lua",
       "\tlocal speak = not silent and entry.ranged == true and not ns.SpeechHeld(entry.name)\n",
       "\tlocal speak = not silent and entry.ranged == true\n",
       "refusal does not hold the line",
       expect="speech-range: a refusal holds the line until neither",
       script="runscenarios.py")

# The error inside the press's window not noted as a refusal.
mutate("Clicks.lua",
       "\tRewindClick(pending)\n\tns.NoteRefusal(pending.name, message, nil, pending.spoke)\n",
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
       "\tPrompt:ApplyTarget(top, HoldLine(top, verdicts))\n",
       "\tPrompt:ApplyTarget(top)\n",
       "press keeps the line for a held entry that walked off",
       expect="speech-range: the press asks again for a held entry that walked off",
       script="runscenarios.py")

# A press the settle path calls a failure (the cast went to somebody else)
# holding nothing: the next press thanks them again.
mutate("Clicks.lua",
       "\t\t-- since the game refused nobody.\n\t\tns.NoteRefusal(pending.name, nil, true, pending.spoke)\n",
       "\t\t-- since the game refused nobody.\n",
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

# ------------------------------------------------- a press known to land
# The press without a token for them taking whatever token the scan had:
# a target since moved to somebody else is asked about, and answers for them.
mutate("Prompt/Press.lua",
       "\tlocal unit = ns.UnitFor(entry.name, entry.unit)\n",
       "\tlocal unit = entry.unit\n",
       "press asks the scan's token, whoever holds it",
       expect="speech-range: no line through your target, retargeted to somebody else",
       script="runscenarios.py")

# The scan's token taken without asking whose it is now.
mutate("Queue.lua",
       "\tif hint and plain(UnitExists(hint)) and ns.UnitFullName(hint) == name then return hint end\n",
       "\tif hint and plain(UnitExists(hint)) then return hint end\n",
       "token found by the scan's token alone",
       expect="speech-range: the press finds him by any token, by his whole name",
       script="runscenarios.py")

# The walk matching a first name: another Weirbeard targeted is taken for
# Weirbeard Jenkins.
mutate("Queue.lua",
       "\t\tif not found and unit ~= hint and plain(UnitExists(unit)) and ns.UnitFullName(unit) == name then\n",
       "\t\tif not found and unit ~= hint and plain(UnitExists(unit))\n"
       "\t\t\tand ns.FirstName(ns.UnitFullName(unit) or \"\") == ns.FirstName(name) then\n",
       "token found by the first name",
       expect="speech-range: the press knows him by his surname (Weirbeard Smith on a nameplate)",
       script="runscenarios.py")

# No walk at all: only the scan's own token is asked, and somebody still on a
# nameplate after your target moved is lost.
mutate("Queue.lua",
       "\tlocal found\n\tIterateUnits(function(unit)\n",
       "\tlocal found\n\tlocal _ = (function(unit)\n",
       "no walk for another token",
       expect="speech-range: the press follows him to another token (in reach)",
       script="runscenarios.py")

# Life the client will not read taken for alive.
mutate("Prompt/Press.lua",
       "\tif type(deadOrGhost) ~= \"function\" or ns.plain(deadOrGhost(unit)) ~= false then return true end\n",
       "\tif type(deadOrGhost) == \"function\" and ns.plain(deadOrGhost(unit)) == true then return true end\n",
       "life unread taken for alive",
       expect="speech-range: no line for somebody whose life the client will not read",
       script="runscenarios.py")

# A range the client will not read taken for in reach, as it used to be.
mutate("Prompt/Press.lua",
       "\tif ns.ReachNow(unit, entry.buff) ~= true then return true end\n",
       "\tif ns.ReachNow(unit, entry.buff) == false then return true end\n",
       "range unread taken for in reach",
       expect="speech-range: the press follows him to another token (range unread there)",
       script="runscenarios.py")

# The cooldowns never asked for the line.
mutate("Prompt/Press.lua",
       "\tif not ns.CastReady(spell) then return true end\n",
       "",
       "line said whatever the cooldowns",
       expect="speech-range: no line while the spell's own cooldown runs",
       script="runscenarios.py")

# Asked, but of no spell: only the global cooldown is read.
mutate("Prompt/Press.lua",
       "\tif not ns.CastReady(spell) then return true end\n",
       "\tif not ns.CastReady() then return true end\n",
       "line asks the global cooldown alone",
       expect="speech-range: no line while the spell's own cooldown runs",
       script="runscenarios.py")

# CastReady handed a spell and not reading its cooldown.
mutate("Clicks.lua",
       "\tif spell then\n\t\tlocal own = CooldownLeft(spell, now)\n",
       "\tif false then\n\t\tlocal own = CooldownLeft(spell, now)\n",
       "spell's own cooldown never read",
       expect="speech-range: no line while the spell's own cooldown runs",
       script="runscenarios.py")

# The client never asked whether the spell can be cast. Short of mana the
# press's own scan already turns everybody down (Affordable), so the case it
# alone catches is a plain no the scan lets through.
mutate("Prompt/Press.lua",
       "\tif spell and ns.safecall(usable, spell) == false then return true end\n",
       "",
       "line said without the mana",
       expect="speech-range: no line when the client says the spell cannot be cast",
       script="runscenarios.py")

# Leaving the line out takes the press with it: the buff never goes.
mutate("Prompt/Macro.lua",
       "\tif not entry or not entry.buff or S.testMode then\n",
       "\tif not entry or not entry.buff or S.testMode or silent then\n",
       "a press without its line not cast",
       expect="speech-range: out of reach at the press, the cast goes without the line",
       script="runscenarios.py")

# A press that leaves the line out rolls another: the line the tooltip
# quoted is spent, and "In character" remembers one never said.
mutate("Prompt/Macro.lua",
       "\tif speak and (S.phraseKey ~= phraseIdentity or (S.phraseText and #S.phraseText > budget)) then\n",
       "\tif silent or (speak and (S.phraseKey ~= phraseIdentity or (S.phraseText and #S.phraseText > budget))) then\n",
       "a line left out is rolled again",
       expect="speech-range: a line left out is kept for the press that lands",
       script="runscenarios.py")

# A line rolled whether or not it can be said, as it used to be: "In
# character" counts a line nobody heard as said lately.
mutate("Prompt/Macro.lua",
       "\tif speak and (S.phraseKey ~= phraseIdentity or (S.phraseText and #S.phraseText > budget)) then\n",
       "\tif S.phraseKey ~= phraseIdentity or (S.phraseText and #S.phraseText > budget) then\n",
       "a line rolled for an arming that cannot say it",
       expect="speech-range: no line is rolled for somebody the press cannot reach",
       script="runscenarios.py")

# ------------------------------------------------- the review's cases
# A silent press refused out of range holding the line like any other: the
# press that lands once he is back goes out silent too.
mutate("Queue.lua",
       "\t\tlocal hold = spoke ~= false or (not quietOnly and not OneOf(why, RECHECKED))\n",
       "\t\tlocal hold = true\n",
       "a silent press refused out of range holds the line",
       expect="speech-range: a silent press refused out of range leaves the next press its line",
       script="runscenarios.py")

# ...and refused for what no press can ask again (line of sight) holding
# nothing either.
mutate("Queue.lua",
       "\t\tlocal hold = spoke ~= false or (not quietOnly and not OneOf(why, RECHECKED))\n",
       "\t\tlocal hold = spoke ~= false\n",
       "a silent press refused out of sight holds nothing",
       expect="speech-range: a silent press refused out of sight still holds the line",
       script="runscenarios.py")

# The range left off the refusals every press asks again.
mutate("Queue.lua",
       "\tlocal RECHECKED = { \"ERR_OUT_OF_RANGE\", \"SPELL_FAILED_OUT_OF_RANGE\", \"ERR_OUT_OF_MANA\",\n",
       "\tlocal RECHECKED = { \"ERR_OUT_OF_MANA\",\n",
       "out of range not asked again",
       expect="speech-range: a silent press refused out of range leaves the next press its line",
       script="runscenarios.py")

# The error inside the press's window not saying whether the press spoke.
mutate("Clicks.lua",
       "\tns.NoteRefusal(pending.name, message, nil, pending.spoke)\n",
       "\tns.NoteRefusal(pending.name, message)\n",
       "refusal blind to a silent press",
       expect="speech-range: a silent press refused out of range leaves the next press its line",
       script="runscenarios.py")

# Every press recorded as one that spoke.
mutate("Prompt/Press.lua",
       "\t\tspoke = S.phraseArmed == true or ns.tryMacro ~= nil,\n",
       "\t\tspoke = true,\n",
       "every press recorded as spoken",
       expect="speech-range: a silent press refused out of range leaves the next press its line",
       script="runscenarios.py")

# The press blind to what its own scan turned down.
mutate("Prompt/Press.lua",
       "\tif verdicts == true or (type(verdicts) == \"table\" and verdicts[entry.name] == true) then return true end\n",
       "",
       "press blind to its own scan's verdicts",
       expect="speech-range: no line when the press's own scan turns him down (covered since the paint)",
       script="runscenarios.py")

# ...to the whole queue refused for your own state.
mutate("Prompt/Press.lua",
       "\tif verdicts == true or (type(verdicts) == \"table\" and verdicts[entry.name] == true) then return true end\n",
       "\tif type(verdicts) == \"table\" and verdicts[entry.name] == true then return true end\n",
       "press blind to a queue refused for your own state",
       expect="speech-range: no line when the press's own scan turns him down (you died since the paint)",
       script="runscenarios.py")

# The fuse's press not handed the verdicts.
mutate("Prompt/Press.lua",
       "\t\tPrompt:ApplyTarget(S.current, HoldLine(S.current, verdicts))\n",
       "\t\tPrompt:ApplyTarget(S.current, HoldLine(S.current))\n",
       "fused press judged without the verdicts",
       expect="speech-range: no line when the press's own scan turns him down (covered since the paint)",
       script="runscenarios.py")

# The hold's press not handed the verdicts.
mutate("Prompt/Press.lua",
       "\tPrompt:ApplyTarget(top, HoldLine(top, verdicts))\n",
       "\tPrompt:ApplyTarget(top, HoldLine(top))\n",
       "held press judged without the verdicts",
       expect="speech-range: no line when the press's own scan turns down the held entry",
       script="runscenarios.py")

# The fuse and the cursor's hold leaving the line armed for somebody the
# queue no longer holds: the tooltip quotes what the press leaves out.
mutate("Prompt/Refresh.lua",
       "\t\t\tself:ApplyTarget(S.current, true)\n",
       "",
       "fused entry keeps its line armed",
       expect="speech-range: the tooltip quotes no line while the cursor holds an empty queue",
       script="runscenarios.py")

# The hold's copy armed with the line of a scan the latest one overruled.
mutate("Prompt/Refresh.lua",
       "\tself:ApplyTarget(top, not inQueue)\n",
       "\tself:ApplyTarget(top)\n",
       "held copy armed with its line",
       expect="speech-range: the tooltip quotes no line for the held entry",
       script="runscenarios.py")

# "In character" counting a roll as said, as it used to.
mutate("Phrases.lua",
       "\t\treturn lines[chosen], texts[chosen]\n",
       "\t\tRP.Remember(texts[chosen])\n\t\treturn lines[chosen], texts[chosen]\n",
       "a roll counted as said",
       expect="speech-range: In character counts a line as said only when a press says it",
       script="runscenarios.py")

# ...and a line a press said never counted.
mutate("Prompt/Press.lua",
       "\t\tns.InCharacter.Remember(S.phraseSource)\n",
       "",
       "a line said not counted",
       expect="speech-range: In character counts a line as said only when a press says it",
       script="runscenarios.py")

mutate("Speech.lua",
       "\t\treturn line, source\n",
       "\t\treturn line\n",
       "the line as written lost on the way out",
       expect="speech-range: In character counts a line as said only when a press says it",
       script="runscenarios.py")

mutate("Prompt/Macro.lua",
       "\t\tS.phraseKey, S.phraseText, S.phraseSource = phraseIdentity, ns.PickPhrase(entry, budget)\n",
       "\t\tS.phraseKey, S.phraseText = phraseIdentity, ns.PickPhrase(entry, budget)\n",
       "the arming keeps no line as written",
       expect="speech-range: In character counts a line as said only when a press says it",
       script="runscenarios.py")
