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
