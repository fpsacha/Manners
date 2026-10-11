# Mutations for tests/scenarios/fuzz-fixes.lua: the fuzzer's canaries. Each puts
# back one fault the fuzzer's oracles are there to notice, and is caught by the
# scenario that replays the few steps the fuzzer shrank it to.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# A conditional written into the macro's cast line.
mutate("Prompt/Macro.lua",
       "\t\t\"/cast \" .. spell,\n\t}, restore,\n\t\t{ targeted = true, selfCast = false, aimedAt = who }\n",
       "\t\t\"/cast [@mouseover] \" .. spell,\n\t}, restore,\n\t\t{ targeted = true, selfCast = false, aimedAt = who }\n",
       "fuzz-canary: a conditional in the macro",
       expect="fuzz-canary: a conditional in the macro",
       script=S)

# The button holding more than the client lets a macro be.
mutate("Speech.lua",
       "ns.MACRO_LIMIT = 255\n",
       "ns.MACRO_LIMIT = 400\n",
       "fuzz-canary: the macro past 255 characters",
       expect="fuzz-canary: the macro past 255 characters",
       script=S)

# A line spoken for somebody the scan never measured inside its reach.
mutate("Prompt/Macro.lua",
       "\tlocal speak = not silent and entry.ranged == true and not ns.SpeechHeld(entry.name)\n",
       "\tlocal speak = not silent and not ns.SpeechHeld(entry.name)\n",
       "fuzz-canary: a line spoken out of reach",
       expect="fuzz-canary: a line spoken out of reach",
       script=S)

# The prompt's panel shown or hidden while the fight locks the frame.
mutate("Prompt/Refresh.lua",
       "local function SetPanelShown(want)\n\tif InCombatLockdown() then return false end\n",
       "local function SetPanelShown(want)\n",
       "fuzz-canary: a protected call in a fight",
       expect="fuzz-canary: a protected call in a fight",
       script=S)

# Skip PvP never holding anybody back.
mutate("Queue.lua",
       "\t\tif not pvpScan.you then pvpHeld = pvpScan.names end\n",
       "\t\tif false then pvpHeld = pvpScan.names end\n",
       "fuzz-canary: a flagged player offered under Skip PvP",
       expect="fuzz-canary: a flagged player offered under Skip PvP",
       script=S)

# Group members never offered.
mutate("Queue.lua",
       "\t\tif reason == \"group\" and not db.sources.group then return end\n",
       "\t\tif reason == \"group\" then return end\n",
       "fuzz-canary: a group member left off the queue",
       expect="fuzz-canary: a group member left off the queue",
       script=S)

# A sweep reason (raised from the dead) that puts nobody first.
mutate("Queue.lua",
       "\t\t\tif swept and priority > PRIORITY.sweep then priority = PRIORITY.sweep end\n",
       "\t\t\tif swept == \"readycheck\" and priority > PRIORITY.sweep then priority = PRIORITY.sweep end\n",
       "fuzz-canary: the raised member behind a plain one",
       expect="fuzz-canary: the raised member behind a plain one",
       script=S)

# ----------------------------------------------------------- the other oracles
#
# Somebody on the player's /ignore list, outside the group, offered anyway.
mutate("Queue.lua",
       "\t\tif ignoring and not inGroup and ns.Ignored(unit) then\n",
       "\t\tif false then\n",
       "fuzz-canary: somebody on the ignore list offered",
       expect="fuzz-canary: somebody on the ignore list offered",
       script=S)

# Chat requests never put anybody on the queue.
mutate("Requests.lua",
       "\tfunction ns.AskedFor(unit, full, now, candidates, askOnly)\n\t\tif #requests == 0 then return nil end\n",
       "\tfunction ns.AskedFor(unit, full, now, candidates, askOnly)\n\t\tif #requests >= 0 then return nil end\n",
       "fuzz-canary: somebody who asked is not offered as asked for",
       expect="fuzz-canary: somebody who asked is not offered as asked for",
       script=S)

# ------------------------------------------------------------ the tool itself
#
# A step list that holds a step which is not one, played as a clean run.
mutate("tests/fuzz_world.lua",
       "\tlocal bad, why = badStep(list)\n\tif bad then\n",
       "\tlocal bad, why = badStep(list)\n\tif false then\n",
       "fuzz-canary: a step that is no step is no clean run",
       expect="fuzz-canary: a step that is no step is no clean run",
       script=S)

# A name replaced inside a longer word.
mutate("tests/fuzz_check.lua",
       "\t\tif before:find(\"^[A-Za-z0-9_]$\") or after:find(\"^[A-Za-z0-9_]$\") then\n",
       "\t\tif false then\n",
       "fuzz-canary: one fault met twice is one signature (a name inside a word)",
       expect="fuzz-canary: one fault met twice is one signature",
       script=S)

# The macro or the line in parentheses or quotes left in the signature.
mutate("tests/fuzz_check.lua",
       "\ttext = text:gsub(\"%b()\", \"()\"):gsub('\"[^\"]*\"', '\"Q\"')\n",
       "\ttext = text\n",
       "fuzz-canary: one fault met twice is one signature (a line in parentheses)",
       expect="fuzz-canary: one fault met twice is one signature",
       script=S)

# The stand-in for a message that ends in the macro ignored.
mutate("tests/fuzz_check.lua",
       "\t\tsig = signature(W, kind, sigText or message) }\n",
       "\t\tsig = signature(W, kind, message) }\n",
       "fuzz-canary: one fault met twice is one signature (the macro at the end)",
       expect="fuzz-canary: one fault met twice is one signature",
       script=S)

# ---------------------------------------------------------------- fuzz-fix
#
# ShoutSure over a library that reads a withheld prompt as "inside": the edge
# that said yes is not asked again.
mutate("Core.lua",
       "\t\tlocal direct = type(maxRange) == \"number\" and maxRange <= 20 and ns.DirectRangeCheck\n"
       "\t\t\tand ns.DirectRangeCheck(lib, maxRange)\n"
       "\t\tif direct and direct(unit) ~= true then maxRange = nil end\n",
       "",
       "fuzz-fix: a shout sure over a library that guesses",
       expect="fuzz-fix: a shout is not sure over a library that guesses",
       script=S)

# The world taking the library off the seeds whose client withholds the
# interact prompts, which is what hid the fault above from the first fuzzer.
mutate("tests/fuzz_world.lua",
       "\t\tMock.setInteract(mode)\n\tend\n\t-- A third of the seeds play in another language",
       "\t\tif mode == \"secret\" then Mock.rangeCheck = nil end\n\t\tMock.setInteract(mode)\n\tend\n\t-- A third of the seeds play in another language",
       "fuzz-canary: the library stays where the prompts are withheld",
       expect="fuzz-canary: the library stays where the prompts are withheld",
       script=S)
