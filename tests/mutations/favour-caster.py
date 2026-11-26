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
       "\t\t\tseen.awaitCast = true\n\t\t\tOnlyPossibleCaster(seen)\n\t\t\treturn true\n",
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
       "\t\tif not source and ns.ALL_BUFF_IDS[key] and ns.castWatch.armed\n"
       "\t\t\tand not seen.claimIgnored and not seen.awaitCast\n",
       "\t\tif not source and ns.ALL_BUFF_IDS[key]\n"
       "\t\t\tand not seen.claimIgnored and not seen.awaitCast\n",
       "favour-caster: the cast watch files unnamed landings where the combat log does",
       expect=N + "classic: a landing is not called unnamed where the combat log names the caster", script=S)

mutate("Favours.lua",
       "\t\tif not source and ns.ALL_BUFF_IDS[key] and ns.castWatch.armed\n"
       "\t\t\tand not seen.claimIgnored and not seen.awaitCast\n",
       "\t\tif not source and ns.ALL_BUFF_IDS[key] and ns.castWatch.armed\n"
       "\t\t\tand not seen.claimIgnored\n",
       "favour-caster: a landing waiting for its window is called unnamed",
       expect=N + "a landing waiting for its window is not yet called unnamed", script=S)

mutate("Favours.lua",
       "\t\t\tand plain(aura.isFromPlayerOrPlayerPet) ~= false then\n\t\t\tRemember(seen, \"unnamed\", \"none\")\n",
       "\t\t\tthen\n\t\t\tRemember(seen, \"unnamed\", \"none\")\n",
       "favour-caster: an NPC's aura is called unnamed",
       expect=N + "a landing that is plainly an NPC's is not called unnamed", script=S)

mutate("Favours.lua",
       "\t\tif not source and ns.ALL_BUFF_IDS[key] and not seen.claimIgnored and not seen.awaitCast then\n"
       "\t\t\tUnnamed(key, seen.unseen)\n\t\tend\n",
       "\t\tif not source and ns.ALL_BUFF_IDS[key] and not seen.claimIgnored then\n"
       "\t\t\tUnnamed(key, seen.unseen)\n\t\tend\n",
       "favour-caster: the nameplates line is said while the landing waits",
       expect=N + "plates off: the nameplates line waits for the decision and is not said for a named caster", script=S)

mutate("Favours.lua",
       "\t\t\tUnnamed(seen.key, seen.unseen)\n\t\t\tif ns.UnmatchedBuffHint then",
       "\t\t\tif ns.UnmatchedBuffHint then",
       "favour-caster: a landing nobody named never says the nameplates line",
       expect=N + "plates off: a landing nobody names says the nameplates line once its window closes", script=S)

# Fix 9, and the third review: a full queue judges the oldest landing once its
# window has closed, and gives it up (naming nobody) while it is still open.
mutate("Favours.lua",
       "\t\t\t\tif GetTime() > old.high then Decide(old) else GiveUp(old) end\n",
       "\t\t\t\tGiveUp(old)\n",
       "favour-caster: a full queue gives up on the oldest landing",
       expect=N + "a full queue judges the oldest landing once its window has closed", script=S)

mutate("Favours.lua",
       "\t\t\t\tif GetTime() > old.high then Decide(old) else GiveUp(old) end\n",
       "\t\t\t\tDecide(old)\n",
       "favour-caster: a full queue judges the oldest before its window closes",
       expect=N + "a full queue gives up on the oldest landing while its window is open", script=S)

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
       "if ns.UnmatchedBuffHint then ns.UnmatchedBuffHint(why, seen) end",
       "",
       "favour-caster: the hint is never said",
       expect=N + "plates on: a buff with nobody to name says so once", script=S)

mutate("Hints.lua",
       "if InCombatLockdown() or db.profile.silentChat == true or db.profile.verbose ~= true then return false end\n",
       "if InCombatLockdown() or db.profile.silentChat == true then return false end\n",
       "favour-caster: the nameplates hint ignores chat commentary",
       expect=N + "the nameplates line is quiet when chat commentary is off",
       script=S)

mutate("Hints.lua",
       "\tunmatchedSaid = true\n",
       "",
       "favour-caster: the hint is said every time",
       expect=N + "plates on: a buff with nobody to name says so once", script=S)

mutate("Hints.lua",
       "\t\tor db.profile.verbose ~= true or CandidateAlreadyOffered(seen) then return false end\n",
       "\t\tor false then return false end\n",
       "favour-caster: the hint ignores chat commentary and the offered caster",
       expect=N + "the unnamed line is quiet when chat commentary is off", script=S)

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
       "\t\t\treturn false\n\t\tend\n\n\t\tForget = function(seen)\n",
       "\t\t\treturn true\n\t\tend\n\n\t\tForget = function(seen)\n",
       "favour-caster: a caster wearing none of the buff is taken for a self-cast",
       expect=N + "another class's buff with no target names the stranger once the moment has passed", script=S)

mutate("Favours.lua",
       "\t\t\t\tseen.filed = true\n\t\t\t\t-- A thank to nobody still waiting is let go for the name (the pause ends,\n"
       "\t\t\t\t-- PausedUnseen drops it, and the named thank behind it goes).\n\t\t\t\tif seen.nobodyWaiting then\n",
       "\t\t\t\tseen.filed = true\n\t\t\t\t-- A thank to nobody still waiting is let go for the name (the pause ends,\n"
       "\t\t\t\t-- PausedUnseen drops it, and the named thank behind it goes).\n\t\t\t\tif false then\n",
       "favour-caster: a thank to nobody that was queued and then held keeps its mark",
       expect=N + "a queued thank to nobody that is held then does not stop the caster being thanked", script=S)

mutate("Favours.lua",
       "\t\tns.Guard(\"thank unseen\", ThankUnseen, seen)\n",
       "\t\tseen.thankedNobody = true\n\t\tns.Guard(\"thank unseen\", ThankUnseen, seen)\n",
       "favour-caster: a thank to nobody is counted as sent before it is",
       expect=N + "a thank to nobody that never went does not stop the caster being thanked", script=S)

mutate("Favours.lua",
       "\t\tif not source and ns.ALL_BUFF_IDS[key] and ns.castWatch.armed\n"
       "\t\t\tand not seen.claimIgnored and not seen.awaitCast\n",
       "\t\tif false\n",
       "favour-caster: a landing given up on at once is left out of the check-up",
       expect=N + "a buff that landed too long ago to match a cast is in /manners debug", script=S)

mutate("Hints.lua",
       "\tif unmatchedSaid then return false end\n",
       "\tif false then return false end\n",
       "favour-caster: the unnamed hint can be repeated in one session",
       expect=N + "plates on: a buff with nobody to name says so once", script=S)

mutate("Commands.lua",
       "\t\telseif last.why ~= nil and last.why ~= \"none\" and last.why ~= \"else\" then\n",
       "\t\telseif false then\n",
       "favour-caster: the check-up says no cast was seen when one was",
       expect=N + "a cast by somebody who now wears a fresh one of it names nobody", script=S)

mutate("Modules/MyBuffs/Companion.lua",
       "and pcall(frame.RegisterUnitEvent, frame, event, \"player\") then",
       "and false then",
       "favour-caster: the pet's frame hears every cast in sight",
       expect=N + "a cast by somebody else costs the pet's listener no protected call", script=S)

mutate("Modules/MyBuffs/Companion.lua",
       "if event == \"UNIT_SPELLCAST_SUCCEEDED\" and plain(unit) ~= \"player\" then return end\n",
       "",
       "favour-caster: the pet's listener guards a stranger's cast",
       expect=N + "a cast by somebody else costs the pet's listener no protected call", script=S)

mutate("Favours.lua",
       "\t\tif not source and ns.ALL_BUFF_IDS[key] and not seen.claimIgnored and not seen.awaitCast then\n"
       "\t\t\tUnnamed(key, seen.unseen)\n\t\tend\n",
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

# The third review: an aimed-at-you cast that was a self-cast, and one cast heard
# under two tokens with every id withheld.
mutate("Favours.lua",
       "\t\t\tif type(hit) == \"table\" and hit.aim == \"you\" and SelfCast(hit) == true then\n",
       "\t\t\tif false then\n",
       "favour-caster: a cast aimed at you is never asked whether it was their own",
       expect=N + "a cast aimed at you that was their own names nobody", script=S)

mutate("Favours.lua",
       "\t\t\t\t\t\tand math.abs(e.at - hit.at) <= CAST_SAME then\n\t\t\t\t\t\te.used = true\n",
       "\t\t\t\t\t\tand math.abs(e.at - hit.at) <= CAST_SAME then\n",
       "favour-caster: the other hearings of a cast are not spent with it",
       expect=N + "one cast under two tokens with every id withheld names one landing", script=S)

# Issue 44: the caster's Manners is the certain witness, before or after the aura.
mutate("Favours.lua",
       "\t\t\tNameFromMessage(seen, aura)\n",
       "",
       "favour-caster: the receiver never asks the caster's Manners",
       expect=N + "a Manners message names the caster before the aura", script=S)

mutate("Clicks.lua",
       "\t\tif buff then SendBuffClaim(to, id) end\n",
       "",
       "favour-caster: a successful caster never sends its certain message",
       expect=N + "a successful cast whispers one certain message", script=S)

mutate("Clicks.lua",
       "if not (db and db.enabled) or InCombatLockdown() then return end\n",
       "if not (db and db.enabled) then return end\n",
       "favour-caster: a successful cast sends an addon message in a fight",
       expect=N + "a successful cast stays quiet in a fight", script=S)

mutate("Clicks.lua",
       "if buffClaimCount >= BUFF_CLAIM_LIMIT then return end\n",
       "if false then return end\n",
       "favour-caster: a cast burst spends the client's whole addon-message allowance",
       expect=N + "successful casts share an eight-message-per-second cap", script=S)

mutate("Clicks.lua",
       "\t\tif ns.plain(prefix) == PREFIX and ns.BuffClaimHeard\n"
       "\t\t\tand ns.BuffClaimHeard(text, channel, sender) then return end\n",
       "\t\tif false then return end\n",
       "favour-caster: the addon-message handler drops caster claims",
       expect=N + "a Manners message names a waiting aura by the spell family", script=S)

mutate("Favours.lua",
       "if #text > 24 or channel ~= \"WHISPER\" or type(sender) ~= \"string\"\n",
       "if #text > 24 or false or type(sender) ~= \"string\"\n",
       "favour-caster: a group message can claim a caster",
       expect=N + "a Manners message is not taken from another channel", script=S)

mutate("Favours.lua",
       "\t\t\t\tseen.claimIgnored, seen.ignoredCaster = true, true\n"
       "\t\t\t\tseen.name = nil\n"
       "\t\t\t\tseen.decided, seen.filed = true, true\n"
       "\t\t\t\tForget(seen)\n"
       "\t\t\t\tRemember({ key = seen.key }, \"ignored\")\n"
       "\t\t\t\treturn true\n",
       "\t\t\t\tseen.ignoredCaster = true\n"
       "\t\t\t\tseen.name = nil\n"
       "\t\t\t\tRemember({ key = seen.key }, \"ignored\")\n"
       "\t\t\t\treturn true\n",
       "favour-caster: an ignored Manners claim stays active for an unseen thank",
       expect=N + "an ignored Manners claim cannot fall through to another caster",
       script=S)

mutate("Favours.lua",
       "\t\t\t\t\tif found and found.sender ~= claim.sender then return \"ambiguous\" end\n",
       "\t\t\t\t\tif found and found.sender ~= claim.sender then return nil end\n",
       "favour-caster: conflicting Manners claims fall through to the visible candidates",
       expect=N + "conflicting Manners claims cannot fall through to a visible caster",
       script=S)

mutate("Favours.lua",
       "\t\t\t\tif type(rankLevel) == \"number\" then\n"
       "\t\t\t\t\tif type(level) ~= \"number\" or level < 1 then\n"
       "\t\t\t\t\t\tambiguous = true\n\t\t\t\t\t\treturn\n"
       "\t\t\t\t\tend\n"
       "\t\t\t\t\tif level < rankLevel then return end\n"
       "\t\t\t\tend\n",
       "\t\t\t\tif type(level) == \"number\" and level >= 1 and type(rankLevel) == \"number\"\n"
       "\t\t\t\t\tand level < rankLevel then return end\n",
       "favour-caster: a withheld level is counted as castable",
       expect=N + "a withheld level of a possible caster is not guessed",
       script=S)

# The fallback at the landing: exactly one living, connected, capable player.
mutate("Favours.lua",
       "\t\t\t\telseif (seen.candidateCount or 0) > 1 then\n",
       "\t\t\t\telseif false then\n",
       "favour-caster: two possible casters are not recorded",
       expect=N + "two players in sight able to cast the rank name nobody", script=S)

mutate("Favours.lua",
       "\t\t\t\tif caster.ignored then\n",
       "\t\t\t\tif false then\n",
       "favour-caster: an ignored possible caster is still owed",
       expect=N + "the only possible caster on the ignore list is not named", script=S)

mutate("Favours.lua",
       "\t\t\t\tif type(class) ~= \"string\" then\n\t\t\t\t\tambiguous = true\n",
       "\t\t\t\tif false then\n\t\t\t\t\tambiguous = true\n",
       "favour-caster: a withheld class chooses a caster",
       expect=N + "a withheld class of a player in sight names nobody", script=S)

mutate("Favours.lua",
       "\t\t\t\tif not SpellHasClass(class, seen.key) then return end\n",
       "\t\t\t\tif false then return end\n",
       "favour-caster: a class can be the caster of another class's buff",
       expect=N + "a player of a class without the landed buff is no candidate", script=S)

mutate("Favours.lua",
       "\t\t\t\tif type(rankLevel) == \"number\" then\n"
       "\t\t\t\t\tif type(level) ~= \"number\" or level < 1 then\n"
       "\t\t\t\t\t\tambiguous = true\n\t\t\t\t\t\treturn\n"
       "\t\t\t\t\tend\n"
       "\t\t\t\t\tif level < rankLevel then return end\n"
       "\t\t\t\tend\n",
       "\t\t\t\tif type(rankLevel) == \"number\" and type(level) ~= \"number\" or level < 1 then\n"
       "\t\t\t\t\tambiguous = true\n\t\t\t\t\treturn\n"
       "\t\t\t\tend\n",
       "favour-caster: a low-level player can cast a rank they cannot know",
       expect=N + "a player below the landed rank's level is no candidate", script=S)

mutate("Favours.lua",
       "\t\t\t\tif dead == true or connected == false then return end\n",
       "\t\t\t\tif connected == false then return end\n",
       "favour-caster: a dead player can be the caster",
       expect=N + "a dead possible caster is not named", script=S)

mutate("Favours.lua",
       "\t\t\t\tif dead == true or connected == false then return end\n",
       "\t\t\t\tif dead == true then return end\n",
       "favour-caster: a disconnected player can be the caster",
       expect=N + "a disconnected possible caster is not named", script=S)

mutate("Hints.lua",
       "\t\tor db.profile.verbose ~= true or CandidateAlreadyOffered(seen) then return false end\n",
       "\t\tor CandidateAlreadyOffered(seen) then return false end\n",
       "favour-caster: the chat hint ignores Show what Manners is doing",
       expect=N + "the unnamed line is quiet when chat commentary is off", script=S)

mutate("Hints.lua",
       "\t\tor db.profile.verbose ~= true or CandidateAlreadyOffered(seen) then return false end\n",
       "\t\tor db.profile.verbose ~= true then return false end\n",
       "favour-caster: the chat hint names an already offered group member",
       expect=N + "the unnamed line stays quiet when a group member is already offered", script=S)
