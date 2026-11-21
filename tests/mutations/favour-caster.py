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
       expect=N + "a cast aimed at you names them as the buff lands", script=S)

mutate("Favours.lua",
       "\t\tif not source and ns.ALL_BUFF_IDS[key] and ns.castWatch.armed\n",
       "\t\tif type(aura.sourceUnit) == \"nil\" and ns.ALL_BUFF_IDS[key] and ns.castWatch.armed\n",
       "favour-caster: a withheld source is not asked about",
       expect=N + "a withheld caster is named from their cast", script=S)

mutate("Favours.lua",
       "if type(hit) == \"table\" and hit.aim == \"you\" then\n\t\t\t\tCopyCaster(hit.seen, seen)",
       "if false then\n\t\t\t\tCopyCaster(hit.seen, seen)",
       "favour-caster: a cast aimed at you waits for the window",
       expect=N + "a cast aimed at you names them as the buff lands", script=S)

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
       "e.ignored = ns.Ignored(unit, guid) or nil",
       "e.ignored = nil",
       "favour-caster: an ignored caster is not noted as ignored",
       expect=N + "a cast from somebody on your ignore list names nobody", script=S)

mutate("Favours.lua",
       "return a == b or (ns.BUFF_BY_ID[a] ~= nil and ns.BUFF_BY_ID[a] == ns.BUFF_BY_ID[b])",
       "return true",
       "favour-caster: any buff is the same buff",
       expect=N + "a cast of another buff names nobody", script=S)

mutate("Favours.lua",
       "e.aim = me == true and \"you\" or me == false and \"else\" or \"unknown\"",
       "e.aim = me ~= nil and \"you\"",
       "favour-caster: a cast at somebody else counts as at you",
       expect=N + "a cast at somebody else names nobody", script=S)

mutate("Favours.lua",
       "if cast ~= nil and e.cast == cast then return end\n",
       "",
       "favour-caster: one cast under two tokens is two casters",
       expect=N + "one cast seen under two tokens is one caster", script=S)

mutate("Favours.lua",
       "return math.abs((GetTime() - (seconds - remaining)) - e.at) <= 0.75",
       "return false",
       "favour-caster: a self-cast is never recognised",
       expect=N + "a cast by somebody who now wears a fresh one of it names nobody", script=S)

mutate("Favours.lua",
       "if plain(UnitIsPlayer(unit)) ~= true then e.block = e.block or \"npc\" end\n",
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
