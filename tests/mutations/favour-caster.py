# Mutations for naming a favour's caster from the casts seen at that moment
# (GitHub issue 26: Favours.lua's cast watch, Hints.lua's UnmatchedBuffHint,
# Commands.lua's last-favour line, Queue.lua's TellLedger hook, Core.lua's
# arming). Each is caught by the scenario in tests/scenarios/favour-caster.lua
# that names it.

S = "runscenarios.py"
N = "favour-caster: "

mutate("Favours.lua",
       "\t\tif not source and ns.ALL_BUFF_IDS[key] and ns.castWatch.armed\n",
       "\t\tif not source and ns.ALL_BUFF_IDS[key] and false\n",
       "favour-caster: the cast watch never asked",
       expect=N + "a cast aimed at you names them once the moment has passed", script=S)

mutate("Favours.lua",
       "\t\tif not source and ns.ALL_BUFF_IDS[key] and ns.castWatch.armed\n",
       "\t\tif type(aura.sourceUnit) == \"nil\" and ns.ALL_BUFF_IDS[key] and ns.castWatch.armed\n",
       "favour-caster: a withheld source is not asked about",
       expect=N + "a withheld caster is named from their cast", script=S)

# Fix 2: a landing is named at the moment it lands, on the casts the ring holds then.
mutate("Favours.lua",
       "\t\t\tseen.awaitCast = true\n\t\t\treturn true\n",
       "\t\t\tseen.awaitCast = true\n\t\t\tlocal hit = Judge(seen.key, seen.low, GetTime())\n"
       "\t\t\tif type(hit) == \"table\" and hit.aim == \"you\" then\n"
       "\t\t\t\tCopyCaster(hit.seen, seen) hit.used = true seen.fromCast = true seen.awaitCast = nil\n"
       "\t\t\t\treturn true\n\t\t\tend\n\t\t\treturn true\n",
       "favour-caster: a landing is named at once from the casts seen so far",
       expect=N + "a second cast aimed at you after the landing names nobody", script=S)

# Fix 3: the nameplates rule for a cast with no target.
mutate("Favours.lua",
       "\t\t\t\tif ns.FriendlyPlatesOff() then\n\t\t\t\t\thit, why = nil, \"unseen\"\n",
       "\t\t\t\tif false then\n\t\t\t\t\thit, why = nil, \"unseen\"\n",
       "favour-caster: a cast with no target names them with the nameplates off",
       expect=N + "plates off: a cast with no target names nobody", script=S)

mutate("Favours.lua",
       "\t\t\tif type(hit) == \"table\" and hit.aim ~= \"you\" then\n\t\t\t\tif ns.FriendlyPlatesOff() then",
       "\t\t\tif type(hit) == \"table\" then\n\t\t\t\tif ns.FriendlyPlatesOff() then",
       "favour-caster: the nameplates rule holds a cast aimed at you too",
       expect=N + "plates off: a cast aimed at you still names them", script=S)

# Fix 1: a withheld target blocks.
mutate("Favours.lua",
       "\t\t\t\tif ex == nil then\n\t\t\t\t\te.block = \"unreadable\"\n",
       "\t\t\t\tif false then\n\t\t\t\t\te.block = \"unreadable\"\n",
       "favour-caster: a withheld target is no target",
       expect=N + "a cast whose target is withheld names nobody", script=S)

mutate("Favours.lua",
       "\t\t\t\t\tif me == nil then\n\t\t\t\t\t\te.block = \"unreadable\"\n",
       "\t\t\t\t\tif me == nil then\n\t\t\t\t\t\te.aim = \"unknown\"\n",
       "favour-caster: a withheld answer to whether the target is you is no target",
       expect=N + "a cast at a target who may be you names nobody", script=S)

# Fix 4: a list the client hides says nothing about not wearing the buff.
mutate("Favours.lua",
       "if not ok or type(first) ~= \"table\" or (issecretvalue and issecretvalue(first)) then return nil end\n",
       "if false then return nil end\n",
       "favour-caster: a hidden aura list is taken for not wearing the buff",
       expect=N + "a caster whose auras are not shown names nobody", script=S)

# Fix 5: one cast guid is one cast only for the same caster.
mutate("Favours.lua",
       "\t\t\t\tif guid ~= nil and e.guid == guid then\n\t\t\t\t\tif cast ~= nil and e.cast == cast then return end\n",
       "\t\t\t\tif cast ~= nil and e.cast == cast then return end\n\t\t\t\tif guid ~= nil and e.guid == guid then\n",
       "favour-caster: one cast guid is one cast whoever cast it",
       expect=N + "two players under one cast guid name nobody", script=S)

# Fix 6: your own casts block.
mutate("Favours.lua",
       "\t\t\tif unit == \"player\" or unit == \"pet\" then return OwnCast(now, unit, cast, id) end\n",
       "\t\t\tif unit == \"player\" or unit == \"pet\" then return end\n",
       "favour-caster: your own cast is not kept",
       expect=N + "your own recast beside a stranger's cast names nobody", script=S)

# Fixes 7 and 8: what the check-up and the hint say, and when.
mutate("Favours.lua",
       "\t\tif not source and ns.ALL_BUFF_IDS[key] and ns.castWatch.armed and not seen.awaitCast\n",
       "\t\tif not source and ns.ALL_BUFF_IDS[key] and not seen.awaitCast\n",
       "favour-caster: the cast watch files unnamed landings where the combat log does",
       expect=N + "classic: a landing is not called unnamed where the combat log names the caster", script=S)

mutate("Favours.lua",
       "\t\tif not source and ns.ALL_BUFF_IDS[key] and ns.castWatch.armed and not seen.awaitCast\n",
       "\t\tif not source and ns.ALL_BUFF_IDS[key] and ns.castWatch.armed\n",
       "favour-caster: a landing waiting for its window is called unnamed",
       expect=N + "a landing waiting for its window is not yet called unnamed", script=S)

mutate("Favours.lua",
       "\t\t\tand plain(aura.isFromPlayerOrPlayerPet) ~= false then\n\t\t\tRemember(seen, \"unnamed\", \"none\")\n",
       "\t\t\tthen\n\t\t\tRemember(seen, \"unnamed\", \"none\")\n",
       "favour-caster: an NPC's aura is called unnamed",
       expect=N + "a landing that is plainly an NPC's is not called unnamed", script=S)

mutate("Favours.lua",
       "\t\tif not source and ns.ALL_BUFF_IDS[key] and not seen.awaitCast then Unnamed(key, seen.unseen) end\n",
       "\t\tif not source and ns.ALL_BUFF_IDS[key] then Unnamed(key, seen.unseen) end\n",
       "favour-caster: the nameplates line is said while the landing waits",
       expect=N + "plates off: the nameplates line waits for the decision and is not said for a named caster", script=S)

mutate("Favours.lua",
       "\t\t\tUnnamed(seen.key, seen.unseen)\n\t\t\tif ns.UnmatchedBuffHint then",
       "\t\t\tif ns.UnmatchedBuffHint then",
       "favour-caster: a landing nobody named never says the nameplates line",
       expect=N + "plates off: a landing nobody names says the nameplates line once its window closes", script=S)

# Fix 9: a full queue judges the oldest landing.
mutate("Favours.lua",
       "\t\t\t\tDecide(table.remove(waiting, 1))\n",
       "\t\t\t\tlocal old = table.remove(waiting, 1)\n\t\t\t\told.decided = true\n\t\t\t\tUnmatched(old, \"busy\")\n",
       "favour-caster: a full queue gives up on the oldest landing",
       expect=N + "a fifth landing judges the oldest waiting one on the casts seen", script=S)

# Fixes 10 to 12: what a cast costs, and where a decision runs.
mutate("Favours.lua",
       "\t\t\tif not auraScanPrimed\n\t\t\t\tor not (db.sources.owed or ((db.prompt.thankEmote or db.prompt.thankWhisper)\n\t\t\t\t\tand not InCombatLockdown())) then\n\t\t\t\tcw.floor = GetTime()\n\t\t\t\treturn\n\t\t\tend\n",
       "",
       "favour-caster: a cast nothing could use is looked at",
       expect=N + "a cast nothing could use costs the client nothing", script=S)

mutate("Favours.lua",
       "if ReadCaster(unit, rec, true, guid, full) then",
       "if ReadCaster(unit, rec, false) then",
       "favour-caster: the caster is asked about twice",
       expect=N + "a cast asks the client for the caster's guid and kind once", script=S)

mutate("Favours.lua",
       "\t\t\tlocal wait = math.max(seen.high + 0.1 - GetTime(), 0)\n\t\t\tif not (C_Timer and C_Timer.After) then\n",
       "\t\t\tlocal wait = seen.high + 0.1 - GetTime()\n\t\t\tif wait <= 0 or not (C_Timer and C_Timer.After) then\n",
       "favour-caster: a closed window is decided inside the scan",
       expect=N + "a window already closed is decided after the scan, not inside it", script=S)

mutate("Favours.lua",
       "\t\t\t\t\t\treturn nil, \"several\"\n",
       "\t\t\t\t\t\tfirst = first\n",
       "favour-caster: the first of two casters wins",
       expect=N + "two players casting it name nobody", script=S)

mutate("Favours.lua",
       "seen.low, seen.high = landed - CAST_WINDOW - lag, landed + CAST_WINDOW",
       "seen.low, seen.high = landed - CAST_WINDOW - lag, landed",
       "favour-caster: the window closes at the landing",
       expect=N + "a second caster just after the landing still names nobody", script=S)

mutate("Favours.lua",
       "if seen and seen.key == key and seen.awaitCast and not seen.name and not seen.parked then AwaitCaster(seen) end\n",
       "",
       "favour-caster: a landing is never parked for the window",
       expect=N + "a cast just after the buff lands names them", script=S)

mutate("Favours.lua",
       "if e.at >= low and e.at <= high and SameBuff(e.spell, key) then",
       "if true and SameBuff(e.spell, key) then",
       "favour-caster: a cast of any time counts",
       expect=N + "a cast outside the moment names nobody", script=S)

mutate("Favours.lua",
       "e.ignored = not NobodyIgnored() and ns.Ignored(unit, guid) or nil",
       "e.ignored = nil",
       "favour-caster: an ignored caster is not noted as ignored",
       expect=N + "a cast from somebody on your ignore list names nobody", script=S)

mutate("Favours.lua",
       "return a == b or (ns.BUFF_BY_ID[a] ~= nil and ns.BUFF_BY_ID[a] == ns.BUFF_BY_ID[b])",
       "return true",
       "favour-caster: any buff is the same buff",
       expect=N + "a cast of another buff names nobody", script=S)

mutate("Favours.lua",
       "e.aim = me == true and \"you\" or \"else\"",
       "e.aim = \"you\"",
       "favour-caster: a cast at somebody else counts as at you",
       expect=N + "a cast at somebody else names nobody", script=S)

mutate("Favours.lua",
       "if cast ~= nil and e.cast == cast then return end\n",
       "",
       "favour-caster: one cast under two tokens is two casters",
       expect=N + "one cast seen under two tokens is one caster", script=S)

mutate("Favours.lua",
       "\t\t\t\t\telseif math.abs((ends - length) - e.at) <= 0.75 then\n",
       "\t\t\t\t\telseif false then\n",
       "favour-caster: a self-cast is never recognised",
       expect=N + "a cast by somebody who now wears a fresh one of it names nobody", script=S)

mutate("Favours.lua",
       "if not isPlayer then e.block = e.block or \"npc\" end\n",
       "",
       "favour-caster: an NPC's cast is no block",
       expect=N + "an NPC casting it at that moment names nobody", script=S)

mutate("Favours.lua",
       "if buff and (buff.selfCast or InList(buff.group, id)) then e.block = \"group\" end\n",
       "",
       "favour-caster: a group form is a single cast",
       expect=N + "a group form of the buff names nobody", script=S)

mutate("Favours.lua",
       "\t\t\t\tcw.floor = math.max(cw.floor, removed.at)\n",
       "",
       "favour-caster: a dropped cast leaves no floor",
       expect=N + "a ring too full to vouch for the moment names nobody", script=S)

mutate("Favours.lua",
       "\t\tif seen.noThank then return end\n",
       "",
       "favour-caster: a late-named favour is thanked again",
       expect=N + "a late-named favour after the thank to nobody is not thanked again", script=S)

mutate("Favours.lua",
       "if id == nil or not ns.ALL_BUFF_IDS[id] then return end",
       "if id == nil then return end",
       "favour-caster: every cast is looked at",
       expect=N + "an unrelated cast costs the client nothing", script=S)

mutate("Favours.lua",
       "if not (db and db.enabled) then cw.floor = GetTime() return end",
       "if not (db and db.enabled) then cw.floor = GetTime() end",
       "favour-caster: a cast with Manners off is looked at",
       expect=N + "an unrelated cast costs the client nothing", script=S)

mutate("Core.lua",
       "if not ns.combatLogArmed and ns.ArmCastWatch then",
       "if ns.ArmCastWatch then",
       "favour-caster: the cast watch listens beside the combat log",
       expect=N + "classic: the cast watch waits on the combat log", script=S)

mutate("Queue.lua",
       "\tif ns.FavourFate then ns.FavourFate(event, ...) end\n",
       "",
       "favour-caster: the ledger's news never reaches the last favour",
       expect=N + "debug: a favour that ran out is not 'nobody has buffed you'", script=S)

mutate("Favours.lua",
       "\t\t\tRemember(seen, \"buffedFirst\")\n",
       "",
       "favour-caster: a buff back is not remembered as one",
       expect=N + "debug: a buff back says you buffed them first", script=S)

mutate("Commands.lua",
       "(LastFavourLine(now) or L[\"nobody has buffed you recently.\"])",
       "(L[\"nobody has buffed you recently.\"])",
       "favour-caster: debug ignores the last favour",
       expect=N + "debug: a favour that ran out is not 'nobody has buffed you'", script=S)

mutate("Favours.lua",
       "if ns.UnmatchedBuffHint then ns.UnmatchedBuffHint(why) end",
       "",
       "favour-caster: the hint is never said",
       expect=N + "plates on: a buff with nobody to name says so once", script=S)

mutate("Hints.lua",
       "\tunmatchedSaid = true\n",
       "",
       "favour-caster: the hint is said every time",
       expect=N + "plates on: a buff with nobody to name says so once", script=S)

mutate("Hints.lua",
       "if not (v == \"1\" or v == 1 or v == true) then return false end",
       "if false then return false end",
       "favour-caster: the hint is said with the nameplates off",
       expect=N + "plates off: the new line stays quiet", script=S)

mutate("Favours.lua",
       "elseif watching and spellId and classOnly then\n\t\t\t\t\t\t\tNotClassBuff(spellId, aura)",
       "elseif false then\n\t\t\t\t\t\t\tNotClassBuff(spellId, aura)",
       "favour-caster: a dropped buff leaves no line",
       expect=N + "a new buff that is no class buff is on the trail", script=S)

mutate("Favours.lua",
       "\t\tdroppedSaid[id] = true\n",
       "",
       "favour-caster: a dropped buff is written every time",
       expect=N + "a new buff that is no class buff is on the trail", script=S)

mutate("Options/Diagnostics.lua",
       "\tif ns.lastFavour then Alias(ns.lastFavour.name) end\n",
       "",
       "favour-caster: the check-up names the last favour",
       expect=N + "the full check-up names the last favour by an alias", script=S)

# Not mutated: OnCast's `local id = plain(spellID)` -> `local id = spellID`. The mock's
# secret is a table that does not throw when used as a key, so the mutant behaves the
# same here (proved MISSED); the real client's secret does throw. The scenario "a secret
# spell or token on a cast is no error" still pins the plain() path in the mock.

mutate("Favours.lua",
       "\t\t\treturn false\n\t\tend\n\n\t\tlocal function Forget(seen)\n",
       "\t\t\treturn true\n\t\tend\n\n\t\tlocal function Forget(seen)\n",
       "favour-caster: a caster wearing none of the buff is taken for a self-cast",
       expect=N + "another class's buff with no target names the stranger once the moment has passed", script=S)

mutate("Favours.lua",
       "\t\t\t\tif seen.nobodyWaiting then\n",
       "\t\t\t\tif false then\n",
       "favour-caster: a thank to nobody that was queued and then held keeps its mark",
       expect=N + "a queued thank to nobody that is held then does not stop the caster being thanked", script=S)

mutate("Favours.lua",
       "\t\tns.Guard(\"thank unseen\", ThankUnseen, seen)\n",
       "\t\tseen.thankedNobody = true\n\t\tns.Guard(\"thank unseen\", ThankUnseen, seen)\n",
       "favour-caster: a thank to nobody is counted as sent before it is",
       expect=N + "a thank to nobody that never went does not stop the caster being thanked", script=S)

mutate("Favours.lua",
       "\t\tif not source and ns.ALL_BUFF_IDS[key] and ns.castWatch.armed and not seen.awaitCast\n",
       "\t\tif false\n",
       "favour-caster: a landing given up on at once is left out of the check-up",
       expect=N + "a buff that landed too long ago to match a cast is in /manners debug", script=S)

mutate("Hints.lua",
       "\telseif why ~= nil and why ~= \"none\" and why ~= \"else\" then\n",
       "\telseif false then\n",
       "favour-caster: the hint says no cast was seen when one was",
       expect=N + "a cast by somebody who now wears a fresh one of it names nobody", script=S)

mutate("Commands.lua",
       "\t\telseif last.why ~= nil and last.why ~= \"none\" and last.why ~= \"else\" then\n",
       "\t\telseif false then\n",
       "favour-caster: the check-up says no cast was seen when one was",
       expect=N + "a cast by somebody who now wears a fresh one of it names nobody", script=S)

mutate("Companion.lua",
       "and pcall(frame.RegisterUnitEvent, frame, event, \"player\") then",
       "and false then",
       "favour-caster: the pet's frame hears every cast in sight",
       expect=N + "a cast by somebody else costs the pet's listener no protected call", script=S)

mutate("Companion.lua",
       "if event == \"UNIT_SPELLCAST_SUCCEEDED\" and plain(unit) ~= \"player\" then return end\n",
       "",
       "favour-caster: the pet's listener guards a stranger's cast",
       expect=N + "a cast by somebody else costs the pet's listener no protected call", script=S)

mutate("Favours.lua",
       "\t\tif not source and ns.ALL_BUFF_IDS[key] and not seen.awaitCast then Unnamed(key, seen.unseen) end\n",
       "",
       "favour-caster: a landing too old to match a cast never says the nameplates line",
       expect=N + "plates off: a landing too old to match a cast says the nameplates line at once", script=S)

# A cast whose caster guid is withheld, heard under two tokens, is one cast.
mutate("Favours.lua",
       "\t\t\tif guid == nil and cast ~= nil and e.seen then\n",
       "\t\t\tif false then\n",
       "favour-caster: a withheld guid keeps one cast twice",
       expect=N + "one cast under two tokens with a withheld guid is one caster", script=S)

# The ignore list holds back the thank to nobody.
mutate("Favours.lua",
       "\t\tif seen.awaitCast and HeardIgnored and HeardIgnored(seen) then\n",
       "\t\tif false then\n",
       "favour-caster: an ignored cast already heard does not stop the thank to nobody",
       expect=N + "an ignored caster's buff is not thanked to nobody: the cast came first, no pause", script=S)

mutate("Favours.lua",
       "\t\tif seen.ignoredCaster or seen.nobodyCancelled then\n\t\t\tseen.thankedNobody = nil\n",
       "\t\tif false then\n\t\t\tseen.thankedNobody = nil\n",
       "favour-caster: a thank to nobody waiting out its pause goes to an ignored caster",
       expect=N + "an ignored caster's buff is not thanked to nobody: the cast came after the landing, thanks paused", script=S)

mutate("Favours.lua",
       "\t\tif seen.awaitCast and seen.high then pause = math.max(pause, seen.high + 0.2 - now) end\n",
       "",
       "favour-caster: the thank to nobody can go before its window has closed",
       expect=N + "an ignored caster's buff is not thanked to nobody: the cast came after the landing, thanks paused", script=S)

mutate("ThankPress.lua",
       "\t\tif item.unseen and item.seen.ignoredCaster then\n",
       "\t\tif false then\n",
       "favour-caster: a thank to nobody parked for a press stays for an ignored caster",
       expect=N + "an ignored caster's buff is not thanked to nobody: the cast came after the landing, a press thanks", script=S)
