# Mutations for the refusals the owner met on WoW Forever 1.60.1.70938: the
# game's reason arriving after the refusal (Queue.lua NoteGameError, LateReason;
# Clicks.lua UI_ERROR_MESSAGE and its message type), the same buff refused on the
# same person twice running (Queue.lua RefusedAgain, AuraChangedOn, OfferHeldAgain;
# Favours.lua UNIT_AURA; Options/Who.lua heldRetry) and Forever's other Arcane
# Intellects (Buffs.lua ALIKE_BLOCKERS). Each is caught by the scenario in
# tests/scenarios/refused.lua that names it.

S = "runscenarios.py"

# 1. The reason that comes after the refusal.
mutate("Queue.lua",
       "\t\tif late and now - late.at <= ERROR_SECONDS then\n",
       "\t\tif false then\n",
       "refused: a reason after the refusal is not acted on",
       expect="refused: the game's more powerful reason holds it at once (after)", script=S)

mutate("Queue.lua",
       "\t\tif late.key and OneOf(message, THIS_BUFF) then\n",
       "\t\tif false then\n",
       "refused: a late stronger-spell reason holds nothing",
       expect="refused: the game's more powerful reason holds it at once (after)", script=S)

mutate("Clicks.lua",
       "\tif message == nil and id and type(plain(_G[id])) == \"string\" then message = plain(_G[id]) end\n",
       "",
       "refused: withheld words not read from the message type",
       expect="refused: the game's more powerful reason holds it at once (type only)", script=S)

mutate("Clicks.lua",
       "\tlocal id = type(errorType) == \"number\" and type(GetGameMessageInfo) == \"function\"\n",
       "\tlocal id = false and type(GetGameMessageInfo) == \"function\"\n",
       "refused: the message type never asked",
       expect="refused: the game's more powerful reason holds it at once (type only)", script=S)

# 2. Twice running, with nothing changed.
mutate("Queue.lua",
       "\t\tif buffKey and not members and RefusedAgain(name, buffKey, why, now) and r.late then r.late.again = true end\n",
       "",
       "refused: a second refusal on the target holds nothing",
       expect="refused: a target refused twice with no reason has that buff held off, said once", script=S)

mutate("Queue.lua",
       "\t\tif not (first and first.key == buffKey) then\n",
       "\t\tif false then\n",
       "refused: the first refusal holds already",
       expect="refused: a target refused twice with no reason has that buff held off, said once", script=S)

mutate("Queue.lua",
       "\t\tTellAgain(name, buffKey)\n\t\treturn true\n",
       "\t\treturn true\n",
       "refused: the hold is not said",
       expect="refused: a target refused twice with no reason has that buff held off, said once", script=S)

mutate("Queue.lua",
       "\t\tfirstRefusal[name] = nil\n\t\tns.MarkAttempted(name, buffKey, THIS_BUFF_SECONDS, true)\n",
       "\t\tns.MarkAttempted(name, buffKey, THIS_BUFF_SECONDS, true)\n",
       "refused: the hold is said at every refusal after it",
       expect="refused: a target refused twice with no reason has that buff held off, said once", script=S)

mutate("Queue.lua",
       "\t\tif why ~= nil and not OneOf(why, AGAIN) then\n",
       "\t\tif false then\n",
       "refused: a refusal out of range or sight counts towards the hold",
       expect="refused: out of range holds nothing (before)", script=S)

mutate("Queue.lua",
       "\t\tif not OneOf(message, AGAIN) then\n\t\t\tfirstRefusal[name] = nil\n",
       "\t\tif false then\n\t\t\tfirstRefusal[name] = nil\n",
       "refused: a late range or sight reason leaves the refusal counted",
       expect="refused: out of sight holds nothing (after)", script=S)

mutate("Queue.lua",
       "\t\tif firstRefusal[name] then firstRefusal[name] = nil end\n",
       "",
       "refused: an aura between the refusals is not something changed",
       expect="refused: an aura changed between the two refusals holds nothing", script=S)

mutate("Queue.lua",
       "\t\t\tfor key in pairs(mine) do LiftAgain(name, key) end\n",
       "",
       "refused: a new aura on them does not lift the hold",
       expect="refused: a new aura on them lifts the hold", script=S)

mutate("Queue.lua",
       "\t\t\tif plain(info.isFullUpdate) ~= true and plain(info.addedAuras) == nil\n\t\t\t\tand plain(info.removedAuraInstanceIDs) == nil then return end\n",
       "",
       "refused: an aura's timer updating lifts the hold",
       expect="refused: a new aura on them lifts the hold", script=S)

mutate("Favours.lua",
       "\tif ns.refusalWatch then ns.AuraChangedOn(unit, info) end\n",
       "",
       "refused: UNIT_AURA never tells the refusals",
       expect="refused: a new aura on them lifts the hold", script=S)

mutate("Queue.lua",
       "\t\twipe(heldOff)\n\t\twipe(heldAgain)\n",
       "\t\twipe(heldAgain)\n",
       "refused: the button leaves the buffs held",
       expect="refused: Offer held-back buffs again brings the buff back", script=S)

mutate("Queue.lua",
       "\t\t\t\tns.MarkAttempted(name, key, 0)\n\t\t\t\tif ns.GROUP_HOLD",
       "\t\t\t\tif ns.GROUP_HOLD",
       "refused: the button leaves the retry cooldown standing",
       expect="refused: Offer held-back buffs again brings the buff back", script=S)

# 3. Forever's other Arcane Intellects.
mutate("Buffs.lua",
       "\t\t\t\t\tfor _, id in ipairs(ALIKE_BLOCKERS[entry.key] or {}) do blockers[#blockers + 1] = id end\n",
       "",
       "refused: Forever's other Arcane Intellects hold nothing off",
       expect="refused: each other Arcane Intellect keeps the offer from being made", script=S)

mutate("Buffs.lua",
       "local ALIKE_BLOCKERS = { intellect = { 364161, 13326, 16876 } }\n",
       "local ALIKE_BLOCKERS = { intellect = { 13326, 16876 } }\n",
       "refused: the hour-long Arcane Intellect (364161) not known",
       expect="refused: each other Arcane Intellect keeps the offer from being made", script=S)

mutate("Buffs.lua",
       "for id, value in pairs({ [364161] = 7, [13326] = 10, [16876] = 31 }) do\n",
       "for id, value in pairs({ [364161] = 6, [13326] = 10, [16876] = 31 }) do\n",
       "refused: 364161 weighed below what it gives",
       expect="refused: each other Arcane Intellect keeps the offer from being made", script=S)
