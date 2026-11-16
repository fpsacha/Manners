# Mutations for "Thank them even when I can't see who it was"
# (prompt.thankUnseen: Favours.lua, Sight, ThankNobody, ThankUnseen and
# ThankByName; Speech.lua, ns.ThankWhisper; Hints.lua; Commands.lua;
# Options). Each is caught by the scenario in tests/scenarios/thank-unseen.lua
# that names it.

S = "runscenarios.py"

# ------------------------------------------------ the switch
mutate("Core.lua",
       "\t\t\tthankUnseen = false,\n",
       "\t\t\tthankUnseen = true,\n",
       "thank-unseen: on by default",
       expect="thank-unseen: off by default, a buff from nobody named is not thanked", script=S)

mutate("Favours.lua",
       "\t\t\t\t\t\t\tThankNobody(seen)\n",
       "",
       "thank-unseen: a landing with nobody behind it is never thanked",
       expect="thank-unseen: on, the emote goes out with nobody targeted", script=S)

mutate("Favours.lua",
       "\t\tlocal ok, answer = pcall(EmoteCall(), ns.ThankEmoteToken(prompt))\n",
       "\t\tlocal ok, answer = pcall(EmoteCall(), ns.ThankEmoteToken(prompt), \"target\")\n",
       "thank-unseen: the emote goes at a target",
       expect="thank-unseen: on, the emote goes out with nobody targeted", script=S)

mutate("Favours.lua",
       "\t\tns.thankLog.unseen = { key = seen.key, at = now, answer = tostring(answer) }\n",
       "",
       "thank-unseen: the thank is not written down",
       expect="thank-unseen: on, the emote goes out with nobody targeted", script=S)

mutate("Favours.lua",
       "\t\treturn db and db.enabled and db.prompt.thankUnseen == true and db.prompt.thankEmote == true or false\n",
       "\t\treturn db and db.enabled and db.prompt.thankUnseen == true or false\n",
       "thank-unseen: live with the /thank off",
       expect="thank-unseen: live only while the /thank is on", script=S)

# ------------------------------------------------ is it a landing
mutate("Favours.lua",
       "\t\t\t\t\tknownAuras[instanceId] = key\n"
       "\t\t\t\t\tknownUntil[instanceId] = presentUntil[instanceId]\n"
       "\t\t\t\t\tprimedBlind[instanceId] = key == true or nil\n",
       "\t\t\t\t\tprimedBlind[instanceId] = key == true or nil\n",
       "thank-unseen: the baseline read as landings",
       expect="thank-unseen: the buffs worn at login are not thanked", script=S)

mutate("Favours.lua",
       "\tlocal RECAST_GAIN = 3\n",
       "\tlocal RECAST_GAIN = 0\n",
       "thank-unseen: a restated end read as a recast",
       expect="thank-unseen: a refresh of a buff already worn is not thanked again", script=S)

mutate("Favours.lua",
       "\t\tif Shout(seen.key) or MaybeMember(seen.key) then return end\n",
       "\t\tif MaybeMember(seen.key) then return end\n",
       "thank-unseen: a shout thanked",
       expect="thank-unseen: a shout is never thanked", script=S)

# ------------------------------------------------ where and when
mutate("Favours.lua",
       "\t\tlocal why = Held(seen)\n"
       "\t\tif why then return why end\n"
       "\t\tif Answer(UnitExists, \"target\")",
       "\t\tif Answer(UnitExists, \"target\")",
       "thank-unseen: held by nothing",
       expect="thank-unseen: never in a fight", script=S)

mutate("Favours.lua",
       "\t\tlocal why = Held(seen)\n"
       "\t\tif why then return why end\n"
       "\t\tif Answer(UnitExists, \"target\")",
       "\t\tlocal why = InCombatLockdown() and Held(seen) or nil\n"
       "\t\tif why then return why end\n"
       "\t\tif Answer(UnitExists, \"target\")",
       "thank-unseen: held only in a fight",
       expect="thank-unseen: never in a dungeon", script=S)

mutate("Battle.lua",
       "\tif not (type(seen) == \"table\" and seen.inGroup == true) then\n",
       "\tif not (type(seen) == \"table\" and (seen.inGroup == true or seen.name == nil)) then\n",
       "thank-unseen: nobody unseen taken for the team",
       expect="thank-unseen: never in a battleground", script=S)
mutate("Battle.lua",
       "\tif not (type(seen) == \"table\" and seen.inGroup == true) then\n",
       "\tif not (type(seen) == \"table\" and seen.inGroup ~= false) then\n",
       "thank-unseen: an unknown team read as yours",
       expect="thank-unseen: never in a battleground", script=S)

mutate("Favours.lua",
       "\t\tif Answer(UnitExists, \"target\") ~= false then return L[\"you have somebody targeted\"] end\n",
       "",
       "thank-unseen: the emote goes at whoever is targeted",
       expect="thank-unseen: never with somebody targeted", script=S)

mutate("Favours.lua",
       "\t\tif Shout(seen.key) or MaybeMember(seen.key) then return end\n",
       "\t\tif Shout(seen.key) then return end\n",
       "thank-unseen: a group member's buff thanked as nobody's",
       expect="thank-unseen: a buff that may be a group member's is not thanked", script=S)
mutate("Favours.lua",
       "\t\t\t\tif theirs == nil or theirs == class then return true end\n",
       "\t\t\t\tif theirs == nil then return true end\n",
       "thank-unseen: the group's classes not read",
       expect="thank-unseen: a buff that may be a group member's is not thanked", script=S)

# ------------------------------------------------ nobody, or cannot tell
mutate("Favours.lua",
       "\t\tif type(aura.sourceUnit) == \"nil\" and ns.ALL_BUFF_IDS[key]\n",
       "\t\tif not source and ns.ALL_BUFF_IDS[key]\n",
       "thank-unseen: a withheld caster read as nobody",
       expect="thank-unseen: a withheld caster is not nobody", script=S)

mutate("Favours.lua",
       "\t\t\t\t\tlocal spellId = plain(aura.spellId)\n",
       "\t\t\t\t\tlocal spellId = plain(aura.spellId) or (issecretvalue and issecretvalue(aura.spellId) and 10938 or nil)\n",
       "thank-unseen: a withheld spell guessed",
       expect="thank-unseen: a withheld spell is not thanked", script=S)

mutate("Favours.lua",
       "\t\tif type(aura.sourceUnit) == \"nil\" and ns.ALL_BUFF_IDS[key]\n",
       "\t\tif (type(aura.sourceUnit) == \"nil\" or plain(UnitIsPlayer(source)) ~= true) and ns.ALL_BUFF_IDS[key]\n",
       "thank-unseen: an NPC read as nobody",
       expect="thank-unseen: an NPC's buff is not thanked", script=S)

mutate("Favours.lua",
       "\t\tif type(aura.sourceUnit) == \"nil\" and ns.ALL_BUFF_IDS[key]\n"
       "\t\t\tand plain(aura.isFromPlayerOrPlayerPet) ~= true then\n",
       "\t\tif type(aura.sourceUnit) == \"nil\" and ns.ALL_BUFF_IDS[key] then\n",
       "thank-unseen: your own buff read as nobody's",
       expect="thank-unseen: a buff the client calls your own is not thanked", script=S)

mutate("Favours.lua",
       "\t\treturn db and db.enabled and db.prompt.thankUnseen == true and db.prompt.thankEmote == true or false\n",
       "\t\treturn db and db.prompt.thankUnseen == true and db.prompt.thankEmote == true or false\n",
       "thank-unseen: thanked with Manners off",
       expect="thank-unseen: Manners off, nothing is thanked", script=S)

# ------------------------------------------------ the limits
mutate("Favours.lua",
       "\t\tif lastAt and now - lastAt < GAP then return L[\"thanked somebody a moment ago\"] end\n",
       "",
       "thank-unseen: no gap before it",
       expect="thank-unseen: the gap after a named thank holds it back", script=S)

mutate("Favours.lua",
       "\t\tlastAt = now\n"
       "\t\tfor key, at in pairs(unseenAt) do\n",
       "\t\tfor key, at in pairs(unseenAt) do\n",
       "thank-unseen: an unseen thank arms no gap",
       expect="thank-unseen: one landing read again with a token is one thank", script=S)

mutate("Favours.lua",
       "\t\tif last and now - last < PER_PERSON then return L[\"thanked for that buff a moment ago\"] end\n",
       "",
       "thank-unseen: no pause per buff",
       expect="thank-unseen: three buffs from one unseen druid are one thank", script=S)

mutate("Favours.lua",
       "\t\tif not (db.prompt.thankDelay == true and type(timer) == \"table\" and type(timer.After) == \"function\") then\n",
       "\t\tif not (false and type(timer) == \"table\" and type(timer.After) == \"function\") then\n",
       "thank-unseen: the pause ignored",
       expect="thank-unseen: with the pause on, the emote waits for it", script=S)

mutate("Favours.lua",
       "\t\tif not UnseenLive(db) then return end\n"
       "\t\tlocal now = GetTime()\n"
       "\t\tlocal why = UnseenBlocked(seen, now)\n",
       "\t\tlocal now = GetTime()\n"
       "\t\tlocal why = UnseenBlocked(seen, now)\n",
       "thank-unseen: the switches not asked again after the pause",
       expect="thank-unseen: switched off during the pause, nothing goes", script=S)

# ------------------------------------------------ what it says
mutate("Favours.lua",
       "then Unnamed(key, seen.unseen) end\n",
       "then Unnamed(key) end\n",
       "thank-unseen: the nameplates line not told of the thank",
       expect="thank-unseen: the nameplates line says the emote thanks them", script=S)

mutate("Hints.lua",
       "\telseif prompt.thankEmote == true and prompt.thankUnseen ~= true then\n",
       "\telseif false then\n",
       "thank-unseen: the nameplates line names no switch",
       expect="thank-unseen: the nameplates line names the switch to a player who thanks", script=S)

mutate("Commands.lua",
       "\tif thanks.unseen then\n",
       "\tif false then\n",
       "thank-unseen: debug says nothing of the thank",
       expect="/manners debug does not say the unseen thank went", script=S)
mutate("Commands.lua",
       "\tif thanks.unseenSkipped then\n",
       "\tif false then\n",
       "thank-unseen: debug says nothing of the skip",
       expect="/manners debug does not say the unseen thank passed over", script=S)
mutate("Commands.lua",
       "\tif db.prompt.thankUnseen == true then\n",
       "\tif false then\n",
       "thank-unseen: debug says nothing of the switch",
       expect="/manners debug does not say the switch is on", script=S)
mutate("Options/Diagnostics.lua",
       "\tlines[#lines + 1] = (\"thankUnseen=%s\"):format(tostring(db.prompt.thankUnseen))\n",
       "",
       "thank-unseen: the check-up says nothing of the switch",
       expect="the full check-up does not say the switch is on", script=S)

# ------------------------------------------------ the options
mutate("Options/Say.lua",
       "\t\t\t\tdisabled = function() return not P().thankEmote and not P().thankWhisper end,\n",
       "\t\t\t\tdisabled = function() return not P().thankEmote end,\n",
       "thank-unseen: greyed with the whisper alone on",
       expect="greyed with the whispered thank-you on", script=S)

mutate("Commands.lua",
       "\tSHARE_KEEP_MINE[\"prompt.thankUnseen\"] = \"unseen\"\n",
       "",
       "thank-unseen: a paste switches it on",
       expect="thank-unseen: a pasted line does not switch it on", script=S)

# ------------------------------------------------ the combat log
mutate("Favours.lua",
       "\t\tif not seen.unit then ThankByName(db, seen) end\n",
       "",
       "thank-unseen: classic: the log never whispers by name",
       expect="thank-unseen: classic: a stranger the log names and no token holds is whispered by name", script=S)

mutate("Favours.lua",
       "\t\tif not unit and not seen.byName then return L[\"no unit for them\"] end\n",
       "\t\tif not unit then return L[\"no unit for them\"] end\n",
       "thank-unseen: classic: a whisper by name held for want of a token",
       expect="thank-unseen: classic: a stranger the log names and no token holds is whispered by name", script=S)

mutate("Favours.lua",
       "\t\tif not db.sources.owed and not (db.prompt.thankUnseen == true and db.prompt.thankWhisper == true) then\n",
       "\t\tif not db.sources.owed then\n",
       "thank-unseen: classic: the log read only for People who buff me",
       expect="thank-unseen: classic: a stranger the log names and no token holds is whispered by name", script=S)

mutate("Speech.lua",
       "\t\t\ttargetName = not unit and seen.name or nil, guid = not unit and seen.guid or nil })\n",
       "\t\t\ttargetName = not unit and seen.name or nil, guid = nil })\n",
       "thank-unseen: classic: the log's GUID not handed to the whisper",
       expect="thank-unseen: classic: a stranger the log names and no token holds is whispered by name", script=S)

mutate("Favours.lua",
       "\t\tif not (db.prompt.thankUnseen == true and db.prompt.thankWhisper == true) then return end\n",
       "\t\tif not (db.prompt.thankWhisper == true) then return end\n",
       "thank-unseen: classic: whispered by name with the switch off",
       expect="thank-unseen: classic: off, the log whispers nobody", script=S)

mutate("Favours.lua",
       "\t\tif Shout(seen.key) or GoesBack(seen) then return end\n",
       "\t\tif Shout(seen.key) then return end\n",
       "thank-unseen: classic: a favour you return whispered too",
       expect="thank-unseen: classic: somebody you will buff back is not whispered", script=S)

mutate("Speech.lua",
       "\t\t\ttargetName = not unit and seen.name or nil, guid = not unit and seen.guid or nil })\n",
       "\t\t\ttargetName = nil, guid = not unit and seen.guid or nil })\n",
       "thank-unseen: classic: a bare name whispered unasked",
       expect="thank-unseen: classic: a bare name the client will not place on your realm is not whispered", script=S)

mutate("Favours.lua",
       "\t\tif type(seen.name) ~= \"string\" or ns.UnitFor(seen.name) then return end\n",
       "\t\tif type(seen.name) ~= \"string\" then return end\n",
       "thank-unseen: classic: somebody a token holds whispered from the log",
       expect="thank-unseen: classic: somebody a token holds is left to the aura scan", script=S)

mutate("Favours.lua",
       "\t\tif whispered and seen.byName then unseenAt[seen.key] = now end\n",
       "",
       "thank-unseen: classic: the whisper by name leaves the emote free",
       expect="thank-unseen: classic: the log's whisper and the scan's late reading of one landing are one thank", script=S)

mutate("Favours.lua",
       "\t\t\tif at and now - at < SAME_LANDING then return L[\"thanked for that buff a moment ago\"] end\n",
       "",
       "thank-unseen: classic: the emote leaves the whisper by name free",
       expect="thank-unseen: classic: the scan's emote and the log's late line of one landing are one thank", script=S)
