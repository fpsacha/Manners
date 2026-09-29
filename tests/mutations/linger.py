# A passer-by stays on the prompt long enough to be clicked: the passers-by
# and askers Queue.lua remembers for a few seconds after the last token reached
# them, an older favour a token found a moment ago, and the prompt holding
# still under the cursor (Prompt.lua) against a token lost and nothing else.
# Each fault put back is caught by the scenario in tests/scenarios/linger.lua
# that names it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# ------------------------------------------------ remembered at all
# The report itself: nothing remembered, so the cursor leaving the stranger
# for the prompt empties the queue and the fuse takes the prompt down.
mutate("Queue.lua",
       "\t\t\t\tRememberPasserBy(queue[#queue], now, f.proximity, hasMana)\n",
       "",
       "linger: nobody remembered",
       expect="the prompt came down seconds after the cursor left the stranger it offered", script=S)

# A target or focus remembered as well, so clearing one keeps them on offer.
mutate("Queue.lua",
       "\t\tif not pointed then\n\t\t\tif reason == \"nearby\" or reason == \"asked\" then\n",
       "\t\tif true then\n\t\t\tif reason == \"nearby\" or reason == \"asked\" then\n",
       "linger: somebody pointed at remembered too",
       expect="your focus, cleared, was kept on offer like a passer-by", script=S)

# Offered as if the scan had measured them: they sort with the people a token
# reaches, and a shout would count as reaching them.
mutate("Queue.lua",
       "\t\t\t\tpriority = PRIORITY[memo.reason],\n\t\t\t\t-- ranged is left unwritten",
       "\t\t\t\tpriority = PRIORITY[memo.reason],\n\t\t\t\tranged = true,\n\t\t\t\t-- ranged is left unwritten",
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
       "\t\telseif now - memo.seen >= LINGER_SECONDS then\n",
       "\t\telseif false then\n",
       "linger: never let go",
       expect="a stranger no token had reached for ten seconds was still offered", script=S)

mutate("Queue.lua",
       "(nearby and (drop or memo.within ~= db.filters.proximity))",
       "(nearby and drop)",
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
       "\t\t\tif person and (watch or next(owed) or next(passing)) then\n",
       "\t\t\tif person and (watch or next(owed)) then\n",
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
       "\t\tif (nearby and (drop or memo.within ~= db.filters.proximity))\n",
       "\t\tif nearby and drop then\n\t\t\t-- held back, and kept\n"
       "\t\telseif (nearby and memo.within ~= db.filters.proximity)\n",
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
       "\tif now - heldAt >= HOLD_SECONDS and not CursorHolds(heldEntry, now) then return false end\n",
       "\tif now - heldAt >= HOLD_SECONDS then return false end\n",
       "linger: the hold runs out under the cursor",
       expect="a passer-by no better took the panel from under the cursor", script=S)

mutate("Prompt.lua",
       "\t\t\tif CursorHolds(current, now) then return end\n",
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
       "\theldEntry, heldAt, emptyAt = nil, nil, nil\n\thovering, heldTurnedDown = nil, nil\n",
       "\theldEntry, heldAt, emptyAt = nil, nil, nil\n\theldTurnedDown = nil\n",
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

# ------------------------------------------------ the cursor forgives a token lost, not a verdict
# Review: under the cursor the hold kept a group member found dead, out of
# range or out of sight, with no end, and the press cast at them.
mutate("Prompt.lua",
       "\tif heldTurnedDown == entry.name then return false end\n",
       "",
       "linger: a verdict does not end the cursor's hold",
       expect="a group member turned down stayed on the panel under the cursor while", script=S)

mutate("Prompt.lua",
       "\treturn now - heldAt < HOVER_SECONDS\n",
       "\treturn true\n",
       "linger: the cursor's hold has no end",
       expect="the cursor held somebody gone for longer than ten seconds", script=S)

mutate("Prompt.lua",
       "\tNoteVerdicts(verdicts)\n\tlocal top = self:PickTop(",
       "\tlocal top = self:PickTop(",
       "linger: the repaint notes no verdicts",
       expect="a group member turned down stayed on the panel under the cursor while", script=S)

mutate("Prompt.lua",
       "\tNoteVerdicts(verdicts)\n\tlocal top = Prompt:PickTop(",
       "\tlocal top = Prompt:PickTop(",
       "linger: the press notes no verdicts",
       expect="a press under the cursor cast at a group member found dead", script=S)

mutate("Prompt.lua",
       "\tlocal queue, verdicts = ns.BuildQueue(hovering)\n\tNoteVerdicts(verdicts)\n\tlocal top = self:PickTop(",
       "\tlocal queue, verdicts = ns.BuildQueue()\n\tNoteVerdicts(verdicts)\n\tlocal top = self:PickTop(",
       "linger: the repaint does not watch",
       expect="linger: under the cursor a group member turned down yields the panel (dead)", script=S)

mutate("Prompt.lua",
       "\tlocal queue, verdicts = ns.BuildQueue(hovering)\n\tNoteVerdicts(verdicts)\n\tlocal top = Prompt:PickTop(",
       "\tlocal queue, verdicts = ns.BuildQueue()\n\tNoteVerdicts(verdicts)\n\tlocal top = Prompt:PickTop(",
       "linger: the press does not watch",
       expect="a press under the cursor cast at a group member found dead", script=S)

mutate("Queue.lua",
       "\t\t\tif person and (watch or next(owed) or next(passing)) then\n",
       "\t\t\tif person and (next(owed) or next(passing)) then\n",
       "linger: the walk writes nobody dead down for a watcher",
       expect="linger: under the cursor a group member turned down yields the panel (dead)", script=S)

mutate("Queue.lua",
       "\t\t\tand plain(UnitIsVisible and UnitIsVisible(unit)) == false then\n\t\t\trejected[full] = true\n",
       "\t\t\tand plain(UnitIsVisible and UnitIsVisible(unit)) == false then\n",
       "linger: out of sight is no verdict",
       expect="linger: under the cursor a group member turned down yields the panel (out of sight)", script=S)

mutate("Queue.lua",
       "\t\tif savingMana and (reason == \"group\" or reason == \"nearby\") then\n\t\t\trejected[full] = true\n",
       "\t\tif savingMana and (reason == \"group\" or reason == \"nearby\") then\n",
       "linger: saving mana is no verdict for the walk",
       expect="linger: under the cursor the prompt still comes down for a group member alone while you save mana", script=S)

mutate("Queue.lua",
       "\t\t\tif not seen[name] then rejected[name] = true end\n",
       "",
       "linger: letting the remembered go is no verdict",
       expect="linger: under the cursor the prompt still comes down for a remembered stranger while you save mana", script=S)

# A verdict written once, by the scan that let them go, and forgotten by the
# next, which has nothing to say about them.
mutate("Prompt.lua",
       "\tif not (name and verdicts) then return end\n",
       "\theldTurnedDown = nil\n\tif not (name and verdicts) then return end\n",
       "linger: a verdict lasts one scan",
       expect="linger: under the cursor the prompt still comes down for a remembered stranger while you save mana", script=S)

# ...and not for good either: back in the queue, they are held again.
mutate("Prompt.lua",
       "\tif inQueue or not heldEntry then heldAt, heldTurnedDown = now, nil end\n",
       "\tif inQueue or not heldEntry then heldAt = now end\n",
       "linger: a verdict outlives the person's return",
       expect="somebody back from a verdict was not held under the cursor again", script=S)

# ------------------------------------------------ your own state
mutate("Prompt.lua",
       "\tif verdicts == true or (type(verdicts) == \"table\" and verdicts[name] == true) then\n",
       "\tif type(verdicts) == \"table\" and verdicts[name] == true then\n",
       "linger: your own state is no verdict",
       expect="the prompt stayed up under the cursor with the queue refused for your own state", script=S)

mutate("Queue.lua",
       "\tif ns.HiddenWhileMounted() then return {}, true end\n",
       "\tif ns.HiddenWhileMounted() then return {} end\n",
       "linger: mounted is no verdict",
       expect="linger: under the cursor the prompt still goes for your own state (mounted with the switch on)", script=S)

mutate("Queue.lua",
       "\tif plain(UnitIsDeadOrGhost(\"player\")) == true then return {}, true end\n",
       "\tif plain(UnitIsDeadOrGhost(\"player\")) == true then return {} end\n",
       "linger: dead is no verdict",
       expect="linger: under the cursor the prompt still goes for your own state (dead)", script=S)

mutate("Queue.lua",
       "\tif UnitOnTaxi and plain(UnitOnTaxi(\"player\")) == true then return {}, true end\n",
       "\tif UnitOnTaxi and plain(UnitOnTaxi(\"player\")) == true then return {} end\n",
       "linger: a taxi is no verdict",
       expect="linger: under the cursor the prompt still goes for your own state (on a taxi)", script=S)

mutate("Queue.lua",
       "\tif UnitInVehicle and plain(UnitInVehicle(\"player\")) == true then return {}, true end\n",
       "\tif UnitInVehicle and plain(UnitInVehicle(\"player\")) == true then return {} end\n",
       "linger: a vehicle is no verdict",
       expect="linger: under the cursor the prompt still goes for your own state (in a vehicle)", script=S)

mutate("Queue.lua",
       "\tif plain(UnitIsCharmed and UnitIsCharmed(\"player\")) == true then return {}, true end\n",
       "\tif plain(UnitIsCharmed and UnitIsCharmed(\"player\")) == true then return {} end\n",
       "linger: charmed is no verdict",
       expect="linger: under the cursor the prompt still goes for your own state (charmed)", script=S)

mutate("Queue.lua",
       "\t\tif own then return { own }, {} end\n\t\treturn {}, true\n",
       "\t\tif own then return { own }, {} end\n\t\treturn {}\n",
       "linger: nothing to cast is no verdict",
       expect="linger: under the cursor the prompt still goes for your own state (with nothing left to cast)", script=S)

mutate("Queue.lua",
       "\t\tif myMana ~= nil and myMana <= 0 then return {}, true end\n",
       "\t\tif myMana ~= nil and myMana <= 0 then return {} end\n",
       "linger: no mana is no verdict",
       expect="linger: under the cursor the prompt still goes for your own state (out of mana)", script=S)

# ------------------------------------------------ somebody who asked
# Review: only passers-by were remembered, so somebody who asked in chat and
# was found under the cursor flashed up and went as it left them.
mutate("Queue.lua",
       "\t\t\tif reason == \"nearby\" or reason == \"asked\" then\n",
       "\t\t\tif reason == \"nearby\" then\n",
       "linger: an asker is not remembered",
       expect="somebody who asked was not offered once the cursor left her", script=S)

mutate("Queue.lua",
       "\t\t\t\treason = memo.reason,\n",
       "\t\t\t\treason = \"nearby\",\n",
       "linger: a remembered asker is offered as a passer-by",
       expect="a remembered asker was offered as", script=S)

mutate("Queue.lua",
       "\t\t\t\tpriority = PRIORITY[memo.reason],\n",
       "\t\t\t\tpriority = PRIORITY.nearby,\n",
       "linger: a remembered asker waits behind the group",
       expect="a remembered asker was offered at priority", script=S)

mutate("Queue.lua",
       "(nearby and (drop or memo.within ~= db.filters.proximity))",
       "(drop or (nearby and memo.within ~= db.filters.proximity))",
       "linger: passers-by off forgets askers",
       expect="somebody who asked was not offered once the cursor left her", script=S)

mutate("Queue.lua",
       "\t\t\tor (not nearby and not ns.StillAsked(name, memo.buff.key, now))\n",
       "",
       "linger: a request answered keeps the asker",
       expect="linger: a remembered asker after the request answered", script=S)

mutate("Requests.lua",
       "\t\tif not (db and db.sources.asked) or type(full) ~= \"string\" then return false end\n",
       "\t\tif not db or type(full) ~= \"string\" then return false end\n",
       "linger: requests switched off keep the asker",
       expect="linger: a remembered asker after requests switched off", script=S)

mutate("Requests.lua",
       "\t\t\t\tand (request.keys == ASK.ANY or request.keys[buffKey]) then\n",
       "\t\t\t\tthen\n",
       "linger: asking for something else keeps the old buff",
       expect="a remembered asker who asked for something else was still offered", script=S)

mutate("Requests.lua",
       "(request.full == full or SameName(request.short, short))",
       "request.full == full",
       "linger: asking again forgets the asker",
       expect="a remembered asker who asked again was let go", script=S)

mutate("Requests.lua",
       "\t\t\tif Live(request, now) and (request.full == full or SameName(request.short, short))\n",
       "\t\t\tif (request.full == full or SameName(request.short, short))\n",
       "linger: a request run out keeps the asker",
       expect="linger: a remembered asker after the request ran out", script=S)

mutate("Queue.lua",
       "\t\t\treturn not (f.relevantOnly and memo.reason ~= \"asked\"\n",
       "\t\t\treturn not (f.relevantOnly\n",
       "linger: relevance judged for a remembered asker",
       expect="somebody who asked was not offered once the cursor left her", script=S)

# ------------------------------------------------ an older favour
# Review: somebody who buffed you longer ago than "Let them go after" is
# offered only while a token reaches them, and flashed the same way.
mutate("Queue.lua",
       "\t\t\tlocal fresh = not db.filters.reachableOnly or near\n",
       "\t\t\tlocal fresh = not db.filters.reachableOnly\n",
       "linger: an older favour found is not fresh",
       expect="an older favour found under the cursor was not offered once it left her", script=S)

mutate("Queue.lua",
       "\t\t\t\towed[full].near = now\n",
       "",
       "linger: a favour found is not stamped",
       expect="an older favour found under the cursor was not offered once it left her", script=S)

mutate("Queue.lua",
       "\t\t\tlocal near = entry.near and now - entry.near < LINGER_SECONDS\n",
       "\t\t\tlocal near = entry.near\n",
       "linger: an older favour found stays for good",
       expect="an older favour no token had reached for ten seconds was still offered", script=S)

mutate("Queue.lua",
       "\t\t\tif rejected[full] == true then entry.near = nil end\n",
       "",
       "linger: a token's verdict on an older favour is forgotten",
       expect="linger: an older favour found under the cursor is let go after a token finds her dead", script=S)

mutate("Queue.lua",
       "\t\t\t\tand not (ns.zonedAt and entry.near < ns.zonedAt)\n",
       "",
       "linger: a loading screen keeps an older favour found",
       expect="linger: an older favour found under the cursor is let go after a loading screen", script=S)

# ------------------------------------------------ the buff remembered, against the settings
# Review: the buff chosen while they had a token was offered for the whole
# window, whatever the player switched off or pinned meanwhile.
mutate("Queue.lua",
       "\tif pinned and pinned.key ~= key then return false end\n",
       "",
       "linger: a pin to another spell is ignored",
       expect="linger: a remembered stranger is let go when another spell is pinned", script=S)

mutate("Queue.lua",
       "\t\tend\n\tend\n\treturn false\nend\n\n-- The walk's second half",
       "\t\tend\n\tend\n\treturn true\nend\n\n-- The walk's second half",
       "linger: a spell switched off is still offered",
       expect="linger: a remembered stranger is let go when the spell is switched off", script=S)

mutate("Queue.lua",
       "\t\t\treturn not (f.relevantOnly and memo.reason ~= \"asked\"\n\t\t\t\tand buff.manaOnly and memo.hasMana == false)\n",
       "\t\t\treturn true\n",
       "linger: Only buffs they can use is ignored",
       expect="linger: a remembered stranger is let go when only buffs they can use is switched on", script=S)

mutate("Queue.lua",
       "\tmemo.hasMana = hasMana\n",
       "",
       "linger: the no-mana reading is not kept",
       expect="linger: a remembered stranger is let go when only buffs they can use is switched on", script=S)
