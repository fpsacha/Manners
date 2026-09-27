# Mutations for backing off from somebody the game keeps refusing (beta.8:
# "keep getting this prompt even if i cant cast"). Each is caught by the
# scenario in tests/scenarios/refusal-backoff.lua that names it.

# No escalation: every refusal blocks for the old two seconds.
mutate("Core.lua",
       "\tlocal STEPS = { 2, 30, 300 }\n",
       "\tlocal STEPS = { 2, 2, 2 }\n",
       "refusals never escalate",
       expect="refusal-backoff: refusals in a row back off further each time",
       script="runscenarios.py")

# Somebody owed backed off as hard as a stranger.
mutate("Core.lua",
       "\t\tlocal steps = (debt and LiveExpiry(debt) > now) and OWED_STEPS or STEPS\n",
       "\t\tlocal steps = STEPS\n",
       "owed people back off like strangers",
       expect="refusal-backoff: somebody owed backs off gently and stays owed",
       script="runscenarios.py")

# The back-off written and never read.
mutate("Core.lua",
       "\t\tif refused and refused.blockUntil > now then return true end\n",
       "",
       "back-off never blocks",
       expect="refusal-backoff: refusals in a row back off further each time",
       script="runscenarios.py")

# The refusal that repeats (after the cast was sent) not counted.
mutate("Core.lua",
       "\tns.NoteRefusal(settled.name)\n",
       "",
       "late refusal not counted",
       expect="refusal-backoff: refusals in a row back off further each time",
       script="runscenarios.py")

# The chat line said on every refusal from the third on.
mutate("Core.lua",
       "\t\tif r.count >= TELL_AT and not r.said then\n",
       "\t\tif r.count >= TELL_AT then\n",
       "backed-off line said every time",
       expect="refusal-backoff: refusals in a row back off further each time",
       script="runscenarios.py")

# The chat line only with chat lines on.
mutate("Core.lua",
       "\tlocal function Tell(name, why)\n",
       "\tlocal function Tell(name, why)\n\t\tif not addon.db.profile.verbose then return end\n",
       "backed-off line only when verbose",
       expect="refusal-backoff: refusals in a row back off further each time",
       script="runscenarios.py")

# An error line just before the refusal not taken as its reason.
mutate("Core.lua",
       "\t\tif why == nil and lastError and now - lastErrorAt <= ERROR_SECONDS then why = lastError end\n",
       "",
       "earlier error not the reason",
       expect="refusal-backoff: the line gives the game's reason (before)",
       script="runscenarios.py")

# An error line just after the refusal not taken as its reason.
mutate("Core.lua",
       "\tns.NoteGameError(message)\n",
       "",
       "later error not the reason",
       expect="refusal-backoff: the line gives the game's reason (after)",
       script="runscenarios.py")

# A cast that lands forgetting nothing.
mutate("Core.lua",
       "\t\tif name then refusals[name] = nil end\n",
       "",
       "landing does not reset the count",
       expect="refusal-backoff: a cast that lands starts the count again",
       script="runscenarios.py")

# Nobody ever swept.
mutate("Core.lua",
       "\tns.SweepRefusals(now)\n\tfor name, entry in pairs(owed) do\n",
       "\tfor name, entry in pairs(owed) do\n",
       "refusals never swept",
       expect="refusal-backoff: the memory is swept and capped",
       script="runscenarios.py")

# No cap.
mutate("Core.lua",
       "\t\tif held >= CAP then refusals[oldest] = nil end\n",
       "",
       "refusals uncapped",
       expect="refusal-backoff: the memory is swept and capped",
       script="runscenarios.py")

# The press's own /target taken for the player choosing them.
mutate("Core.lua",
       "\tif at and GetTime() - at < 0.5 then return end\n",
       "",
       "press targeting lifts the back-off",
       expect="refusal-backoff: targeting them lifts it, the press's own targeting does not",
       script="runscenarios.py")

# Targeting them on purpose lifting nothing.
mutate("Core.lua",
       "\t\tif r then r.blockUntil = 0 end\n",
       "",
       "targeting does not lift the back-off",
       expect="refusal-backoff: targeting them lifts it, the press's own targeting does not",
       script="runscenarios.py")

# /manners debug silent about who is backed off.
mutate("Core.lua",
       "\t\tfor _, line in ipairs(ns.RefusalLines(now)) do self:Print(\"  \" .. line) end\n",
       "",
       "debug omits the back-off",
       expect="refusal-backoff: targeting them lifts it, the press's own targeting does not",
       script="runscenarios.py")

# Out of mana blamed on the person.
mutate("Core.lua",
       "\t\tif quietOnly or AboutTheCaster(why) then\n",
       "\t\tif quietOnly then\n",
       "caster errors back people off",
       expect="refusal-backoff: out of mana backs nobody off",
       script="runscenarios.py")
