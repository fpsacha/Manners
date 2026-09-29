# A passer-by stays on the prompt long enough to be clicked: the passers-by
# Queue.lua remembers for a few seconds after the last token reached them, and
# the prompt holding still under the cursor (Prompt.lua). Each fault put back
# is caught by the scenario in tests/scenarios/linger.lua that names it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# ------------------------------------------------ remembered at all
# The report itself: nothing remembered, so the cursor leaving the stranger
# for the prompt empties the queue and the fuse takes the prompt down.
mutate("Queue.lua",
       "\t\tif reason == \"nearby\" and not pointed then RememberPasserBy(queue[#queue], now, f.proximity) end\n",
       "",
       "linger: nobody remembered",
       expect="the prompt came down seconds after the cursor left the stranger it offered", script=S)

# A target or focus remembered as well, so clearing one keeps them on offer.
mutate("Queue.lua",
       "\t\tif reason == \"nearby\" and not pointed then RememberPasserBy(",
       "\t\tif reason == \"nearby\" then RememberPasserBy(",
       "linger: somebody pointed at remembered too",
       expect="your focus, cleared, was kept on offer like a passer-by", script=S)

# Offered as if the scan had measured them: they sort with the people a token
# reaches, and a shout would count as reaching them.
mutate("Queue.lua",
       "\t\t\t\tpriority = PRIORITY.nearby,\n\t\t\t\t-- ranged is left unwritten",
       "\t\t\t\tpriority = PRIORITY.nearby,\n\t\t\t\tranged = true,\n\t\t\t\t-- ranged is left unwritten",
       "linger: a remembered stranger claims a range reading",
       expect="a remembered stranger was offered as if a token still reached her", script=S)

# ------------------------------------------------ what is kept
mutate("Queue.lua",
       "\tmemo.known, memo.checked, memo.close = entry.known, entry.checked, entry.close\n",
       "\tmemo.checked, memo.close = entry.checked, entry.close\n",
       "linger: the reading is not kept",
       expect="linger: the panel says the same about her once the cursor leaves (missing it)", script=S)

mutate("Queue.lua",
       "\tmemo.expires = entry.remaining and (now + entry.remaining) or nil\n",
       "\tmemo.expires = nil\n",
       "linger: the top-up's clock is not kept",
       expect="linger: the panel says the same about her once the cursor leaves (a top-up)", script=S)

mutate("Queue.lua",
       "\t\t\t\tremaining = memo.expires and (memo.expires - now) or nil,\n",
       "\t\t\t\tremaining = memo.expires and (memo.expires - memo.seen) or nil,\n",
       "linger: the top-up's clock stops",
       expect="the top-up's time left did not count down while she was out of sight", script=S)

# Off Camelot a cross-realm player is filed "Anna-Aim" and targeted "Anna".
mutate("Queue.lua",
       "\t\t\t\ttargetName = memo.targetName,\n",
       "\t\t\t\ttargetName = name,\n",
       "linger: the /target spelling is the filed name",
       expect="targets them by name (another realm on retail)", script=S)

# ------------------------------------------------ let go
mutate("Queue.lua",
       "\t\tif now - memo.seen >= LINGER_SECONDS\n",
       "\t\tif false\n",
       "linger: never let go",
       expect="a stranger no token had reached for ten seconds was still offered", script=S)

mutate("Queue.lua",
       "\t\t\tor memo.within ~= db.filters.proximity\n",
       "",
       "linger: a narrowed setting does not apply",
       expect="narrowing Passers-by within left a remembered passer-by on offer", script=S)

mutate("Queue.lua",
       "\t\t\tor (ns.zonedAt and memo.seen < ns.zonedAt)\n",
       "",
       "linger: a loading screen forgets nobody",
       expect="a passer-by from before a loading screen was offered after it", script=S)

mutate("Queue.lua",
       "\t\t\tor rejected[name] == true\n",
       "",
       "linger: a token's verdict is ignored",
       expect="a remembered stranger was offered by name while a token turned her down", script=S)

# Dead is a verdict the walk only writes down while somebody could resurface.
mutate("Queue.lua",
       "\t\t\tif person and (next(owed) or next(passing)) then\n",
       "\t\t\tif person and next(owed) then\n",
       "linger: somebody dead is not written down",
       expect="linger: a remembered stranger a token finds dead is let go", script=S)

mutate("Queue.lua",
       "\t\t\tor ns.IsBlocked(name, memo.buff.key, now)\n",
       "",
       "linger: a block is ignored",
       expect="a remembered stranger was still offered after the press on them", script=S)

mutate("Queue.lua",
       "\t\t\tor ns.IsNeverOffered(name)\n\t\t\tor not SafeForMacro(name) then\n",
       "\t\t\tor not SafeForMacro(name) then\n",
       "linger: the never-offer list is ignored",
       expect="a remembered stranger on the never-offer list was offered", script=S)

mutate("Queue.lua",
       "\t\t\tor ns.IsNeverOffered(name)\n\t\t\tor not SafeForMacro(name) then\n",
       "\t\t\tor ns.IsNeverOffered(name) then\n",
       "linger: a name unsafe for the macro is offered",
       expect="a remembered name that could break out of the macro was offered", script=S)

# ------------------------------------------------ the edge of the setting
# Measured just past "Passers-by within" is not a verdict: taking it for one
# is the blinking the memory is there to stop.
mutate("Queue.lua",
       "\t\t\trejected[full] = \"far\"\n",
       "\t\t\trejected[full] = true\n",
       "linger: far taken for a verdict by the walk",
       expect="a passer-by just past the edge of Passers-by within blinked off the prompt", script=S)

mutate("Queue.lua",
       "\t\t\tor rejected[name] == true\n",
       "\t\t\tor rejected[name]\n",
       "linger: far taken for a verdict by the memory",
       expect="a passer-by just past the edge of Passers-by within blinked off the prompt", script=S)

# ------------------------------------------------ one entry per person
mutate("Queue.lua",
       "\t\telseif not seen[name] and not (debt and LiveExpiry(debt) > now) then\n",
       "\t\telseif not (debt and LiveExpiry(debt) > now) then\n",
       "linger: a token and the memory both offer",
       expect="a remembered stranger the cursor found again was offered", script=S)

mutate("Queue.lua",
       "\t\telseif not seen[name] and not (debt and LiveExpiry(debt) > now) then\n",
       "\t\telseif not seen[name] then\n",
       "linger: a favour and the memory both offer",
       expect="a remembered stranger who buffed you was offered", script=S)

# ------------------------------------------------ passers-by turned down as a kind
mutate("Queue.lua",
       "\t\tnot db.sources.strangers or groupOnly or savingMana or notResting)\n",
       "\t\tgroupOnly or savingMana or notResting)\n",
       "linger: passers-by off keeps the remembered",
       expect="a remembered passer-by was offered with passers-by switched off", script=S)

mutate("Queue.lua",
       "\t\tnot db.sources.strangers or groupOnly or savingMana or notResting)\n",
       "\t\tnot db.sources.strangers or groupOnly or notResting)\n",
       "linger: saving mana keeps the remembered",
       expect="a remembered passer-by was offered with saving mana", script=S)

mutate("Queue.lua",
       "\t\tnot db.sources.strangers or groupOnly or savingMana or notResting)\n",
       "\t\tnot db.sources.strangers or groupOnly or savingMana)\n",
       "linger: out of the city keeps the remembered",
       expect="a remembered passer-by was offered with out of the city", script=S)

mutate("Queue.lua",
       "\t\tnot db.sources.strangers or groupOnly or savingMana or notResting)\n",
       "\t\tnot db.sources.strangers or savingMana or notResting)\n",
       "linger: a shout offered to the remembered",
       expect="a warrior's shout was offered to a passer-by remembered", script=S)

# Held back only while it lasts, so they are back when it ends.
mutate("Queue.lua",
       "\tif drop then\n\t\tif next(passing) then wipe(passing) end\n\t\treturn\n\tend\n",
       "\tif drop then\n\t\treturn\n\tend\n",
       "linger: turned down only for the moment",
       expect="a remembered passer-by came back after", script=S)

# ------------------------------------------------ a crowd
mutate("Queue.lua",
       "\t\tif held >= LINGER_CAP then passing[oldest] = nil end\n",
       "",
       "linger: the memory has no ceiling",
       expect="the passers-by remembered grew past forty", script=S)

mutate("Queue.lua",
       "\t\t\tif not at or other.seen < at then oldest, at = who, other.seen end\n",
       "\t\t\tif not at or other.seen > at then oldest, at = who, other.seen end\n",
       "linger: the newest makes room",
       expect="a full crowd made room by forgetting somebody seen more recently than the oldest", script=S)

# ------------------------------------------------ the prompt under the cursor
mutate("Prompt.lua",
       "\tif now - heldAt >= HOLD_SECONDS and not hovering then return false end\n",
       "\tif now - heldAt >= HOLD_SECONDS then return false end\n",
       "linger: the hold runs out under the cursor",
       expect="a passer-by no better took the panel from under the cursor", script=S)

mutate("Prompt.lua",
       "\t\t\tif hovering then return end\n",
       "",
       "linger: the fuse burns out under the cursor",
       expect="the prompt came down under the cursor as the queue emptied", script=S)

mutate("Prompt.lua",
       "\t\thovering = true\n",
       "",
       "linger: OnEnter does not say the cursor is there",
       expect="the prompt came down under the cursor as the queue emptied", script=S)

mutate("Prompt.lua",
       "\t\thovering = nil\n\t\tif C_Timer and C_Timer.After then\n",
       "\t\tif C_Timer and C_Timer.After then\n",
       "linger: OnLeave does not say the cursor went",
       expect="the prompt stayed up after the cursor left it, with nobody in the queue", script=S)

mutate("Prompt.lua",
       "\t\t\tC_Timer.After(0, function() ns.Guard(\"leave repaint\", Prompt.Refresh, Prompt) end)\n",
       "",
       "linger: leaving waits for the next scan",
       expect="the prompt stayed up after the cursor left it, with nobody in the queue", script=S)

mutate("Prompt.lua",
       "\theldEntry, heldAt, emptyAt = nil, nil, nil\n\thovering = nil\n",
       "\theldEntry, heldAt, emptyAt = nil, nil, nil\n",
       "linger: the cursor outlives the prompt",
       expect="a hover from before the prompt went down still held it up", script=S)

# The cursor must never hold a panel that has to move on.
mutate("Prompt.lua",
       "\tif top.name == heldEntry.name then return top end\n",
       "\tif hovering then return heldEntry end\n\tif top.name == heldEntry.name then return top end\n",
       "linger: the cursor holds off somebody better",
       expect="somebody who buffed you did not take the panel from under the cursor", script=S)

mutate("Prompt.lua",
       "\tif not (heldEntry and heldAt) then return false end\n",
       "\tif not (heldEntry and heldAt) then return false end\n\tif hovering then return true end\n",
       "linger: the cursor holds somebody skipped",
       expect="a right-click skip under the cursor left the panel on", script=S)

mutate("Prompt.lua",
       "\t\tif button:IsShown() and current and not retired and not ArmingForFight() then\n",
       "\t\tif hovering and current then return end\n\t\tif button:IsShown() and current and not retired and not ArmingForFight() then\n",
       "linger: the cursor holds the last person retired",
       expect="a right-click skip under the cursor on the last person left the prompt up", script=S)

# ...nor through the pull, whose macro serves the whole fight: the held person
# over somebody in the queue, and over an empty one.
mutate("Prompt.lua",
       "\tif ArmingForFight() then return top end\n",
       "\tif hovering then return heldEntry end\n\tif ArmingForFight() then return top end\n",
       "linger: the cursor holds through the pull",
       expect="linger: a pull under the cursor arms whoever the queue holds (with Bert waiting)", script=S)

mutate("Prompt.lua",
       "\t\tif button:IsShown() and current and not retired and not ArmingForFight() then\n",
       "\t\tif hovering and current and not retired then return end\n\t\tif button:IsShown() and current and not retired and not ArmingForFight() then\n",
       "linger: the cursor keeps the fuse through the pull",
       expect="linger: a pull under the cursor arms whoever the queue holds (with nobody)", script=S)
