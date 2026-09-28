# "Thank them with an emote": each load-bearing part put back wrong and
# required to be caught by its scenario in tests/scenarios/thank.lua.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# ------------------------------------------------ the setting
mutate("Favours.lua",
       "\t\tif not (db and db.prompt.thankEmote) then return end\n",
       "\t\tif not db then return end\n",
       "thank: the setting is not read",
       expect="an emote was made with the setting off", script=S)
mutate("Core.lua",
       "\t\t\tthankEmote = false,\n",
       "\t\t\tthankEmote = true,\n",
       "thank: on by default",
       expect="the emote is not off in a new profile", script=S)
mutate("Core.lua",
       "\tboolean(p, \"thankEmote\", false)\n",
       "",
       "thank: a garbage setting is not repaired",
       expect="a setting that is not a yes or no was kept", script=S)
mutate("Options.lua",
       "\t\t\t\t\t\tset = function(_, v) P().thankEmote = v end,\n",
       "\t\t\t\t\t\tset = function(_, v) end,\n",
       "thank: the toggle writes nothing",
       expect="the toggle does not switch the setting on", script=S)
mutate("Options.lua",
       "\t\t\t\t\t\tdisabled = function() return not S().owed end,\n"
       "\t\t\t\t\t\tget = function() return P().thankEmote end,\n",
       "\t\t\t\t\t\tget = function() return P().thankEmote end,\n",
       "thank: the toggle is live with nobody noticed",
       expect="the toggle is live with People who buffed me off", script=S)

# ------------------------------------------------ which favours
mutate("Favours.lua",
       "\t\tif reachable then ns.Guard(\"thank emote\", ThankFavour, seen) end\n",
       "\t\tns.Guard(\"thank emote\", ThankFavour, seen)\n",
       "thank: a favour the prompt cannot return is thanked",
       expect="a favour the shout cannot return was thanked", script=S)
mutate("Favours.lua",
       "\t\t\tTellLedger(\"Received\", seen, true)\n",
       "\t\t\tTellLedger(\"Received\", seen, true)\n\t\t\tThankFavour(seen)\n",
       "thank: a useless favour is thanked",
       expect="a favour nothing you cast could return was thanked", script=S)

# ------------------------------------------------ the emote and its target
mutate("Favours.lua",
       "\t\tseen.unit = source\n",
       "\t\tseen.unit = \"target\"\n",
       "thank: the token is not the one the buff came from",
       expect="thank: a favour is thanked at the token it came from", script=S)
mutate("Favours.lua",
       "\t\tlocal ok, answer = pcall(EmoteCall(), \"THANK\", unit)\n",
       "\t\tlocal ok, answer = pcall(EmoteCall(), \"THANK\", name)\n",
       "thank: the emote goes to a name",
       expect="the token the buff came from", script=S)
mutate("Favours.lua",
       "\t\tlocal ok, answer = pcall(EmoteCall(), \"THANK\", unit)\n",
       "\t\tlocal ok, answer = pcall(EmoteCall(), \"CHEER\", unit)\n",
       "thank: the wrong emote",
       expect="the emote made was", script=S)
mutate("Favours.lua",
       "\t\tlocal ok, answer = pcall(EmoteCall(), \"THANK\", unit)\n",
       "\t\tlocal ok, answer = true, EmoteCall()(\"THANK\", unit)\n",
       "thank: an emote call that throws is not caught",
       expect="thank: DoEmote throws is skipped silently", script=S)
mutate("Favours.lua",
       "\t\tns.thankLog.thanked = { name = name, at = now, answer = tostring(answer) }\n",
       "",
       "thank: the thank is not written down",
       expect="the thank was not written down for /manners debug", script=S)

# ------------------------------------------------ which call, and its answer
mutate("Favours.lua",
       "\t\tif chat and type(chat.PerformEmote) == \"function\" then return chat.PerformEmote end\n",
       "",
       "thank: PerformEmote is never called",
       expect="thank: PerformEmote is the call made (without DoEmote)", script=S)
mutate("Favours.lua",
       "\t\tif chat and type(chat.PerformEmote) == \"function\" then return chat.PerformEmote end\n",
       "\t\tif chat and type(chat.PerformEmote) == \"function\" and not _G.DoEmote then return chat.PerformEmote end\n",
       "thank: the DoEmote shim is taken over PerformEmote",
       expect="DoEmote was called with PerformEmote there", script=S)
mutate("Favours.lua",
       "\t\treturn _G.DoEmote\n",
       "\t\treturn nil\n",
       "thank: no DoEmote on a client without PerformEmote",
       expect="thank: a favour is thanked at the token it came from", script=S)
mutate("Favours.lua",
       "\t\tif answer == true then\n",
       "\t\tif false then\n",
       "thank: the game's answer is not read",
       expect="an emote the game said was restricted was recorded as made", script=S)
mutate("Favours.lua",
       "\t\tanswer = plain(answer)\n",
       "",
       "thank: a secret answer is read unguarded",
       expect="thank: a secret answer is read safely", script=S)
mutate("Favours.lua",
       "\t\tif not ok then\n",
       "\t\tif not ok or plain(answer) == true then\n"
       "\t\t\tif ok then return Skip(name, now, L[\"the game said it was restricted\"]) end\n",
       "thank: a restricted answer does not hold the limits",
       expect="a restricted answer did not hold the gap", script=S)
mutate("Commands.lua",
       "\t\t\t\tthanks.thanked.name, math.floor(now - thanks.thanked.at), thanks.thanked.answer))\n",
       "\t\t\t\tthanks.thanked.name, math.floor(now - thanks.thanked.at), \"?\"))\n",
       "thank: debug does not show the game's answer",
       expect="/manners debug does not show what the game answered", script=S)
mutate("Favours.lua",
       "\t\tns.thankLog.skipped = { name = name, at = now, why = why }\n",
       "\t\tns.thankLog.skipped = { name = name, at = now }\n",
       "thank: a skip is written down without why",
       expect="the skip was not written down with its reason", script=S)

# ------------------------------------------------ when not
mutate("Favours.lua",
       "\t\tif InCombatLockdown() then return L[\"in a fight\"] end\n",
       "",
       "thank: thanked in a fight",
       expect="an emote was made in a fight", script=S)
mutate("Favours.lua",
       "\t\tif inside ~= false then return L[\"in an instance\"] end\n",
       "",
       "thank: thanked in an instance",
       expect="thank: not in an instance (a dungeon)", script=S)
mutate("Favours.lua",
       "\t\tif inside ~= false then return L[\"in an instance\"] end\n",
       "\t\tif inside == true then return L[\"in an instance\"] end\n",
       "thank: a client that will not say is taken for outdoors",
       expect="thank: not in an instance (no IsInInstance)", script=S)
mutate("Favours.lua",
       "\t\tif Answer(encounter and encounter.IsEncounterInProgress) == true\n\t\t\tor ",
       "\t\tif ",
       "thank: an encounter is not asked about",
       expect="thank: not while chat is held back (an encounter)", script=S)
mutate("Favours.lua",
       "\n\t\t\tor Answer(_G.IsEncounterInProgress) == true then\n",
       " then\n",
       "thank: the old encounter call is not asked",
       expect="thank: not while chat is held back (an encounter, old API)", script=S)
mutate("Favours.lua",
       "\t\t\tand Answer(chat.InChatMessagingLockdown) ~= false then\n",
       "\t\t\tand false then\n",
       "thank: the messaging lockdown is not asked",
       expect="thank: not while chat is held back (messaging lockdown)", script=S)
mutate("Favours.lua",
       "\t\t\tand Answer(chat.InChatMessagingLockdown) ~= false then\n",
       "\t\t\tand Answer(chat.InChatMessagingLockdown) == true then\n",
       "thank: an unreadable lockdown is taken for none",
       expect="thank: not while chat is held back (lockdown unreadable)", script=S)
mutate("Favours.lua",
       "\t\tif chat and chat.InChatMessagingLockdown\n\t\t\tand Answer",
       "\t\tif chat\n\t\t\tand Answer",
       "thank: a chat API without the lockdown holds every emote",
       expect="thank: not while chat is held back (a chat API without the lockdown)", script=S)
mutate("Favours.lua",
       "\t\t\tand Answer(actions.GetAddOnRestrictionState, kind) ~= idle then\n",
       "\t\t\tand false then\n",
       "thank: the chat restriction is not asked",
       expect="thank: not while chat is held back (chat restriction active)", script=S)
mutate("Favours.lua",
       "\t\t\tand Answer(actions.GetAddOnRestrictionState, kind) ~= idle then\n",
       "\t\t\tand Answer(actions.GetAddOnRestrictionState, kind) == 1 then\n",
       "thank: only Active counts as restricted",
       expect="thank: not while chat is held back (chat restriction activating)", script=S)
mutate("Favours.lua",
       "\t\tif kind ~= nil and idle ~= nil and actions and actions.GetAddOnRestrictionState\n",
       "\t\tif idle ~= nil and actions and actions.GetAddOnRestrictionState\n",
       "thank: another restriction is taken for chat's",
       expect="thank: not while chat is held back (no Chat restriction kind)", script=S)
mutate("Favours.lua",
       "\t\tif kind ~= nil and idle ~= nil and actions and actions.GetAddOnRestrictionState\n",
       "\t\tif kind ~= nil and idle ~= nil and actions\n",
       "thank: no way to ask the restriction holds every emote",
       expect="thank: not while chat is held back (no restriction state call)", script=S)

# ------------------------------------------------ the token
mutate("Favours.lua",
       "\t\tif Answer(UnitExists, unit) ~= true then return nil end\n",
       "",
       "thank: a token that may not exist",
       expect="thank: only at a token that still holds them (existence a secret)", script=S)
mutate("Favours.lua",
       "\t\tif Answer(ns.UnitFullName, unit) ~= seen.name then return nil end\n",
       "",
       "thank: a token handed to somebody else",
       expect="thank: only at a token that still holds them (handed to somebody else)", script=S)
mutate("Favours.lua",
       "\t\tif seen.guid ~= nil and Answer(UnitGUID, unit) ~= seen.guid then return nil end\n",
       "",
       "thank: a token holding somebody by the same name",
       expect="thank: only at a token that still holds them (somebody else by the same name)",
       script=S)

# ------------------------------------------------ throttles
mutate("Favours.lua",
       "\t\tif last and now - last < PER_PERSON then\n",
       "\t\tif false then\n",
       "thank: no per-person limit",
       expect="the same person was thanked twice in a minute", script=S)
mutate("Favours.lua",
       "\tlocal PER_PERSON = 300\n",
       "\tlocal PER_PERSON = 30\n",
       "thank: the per-person limit is thirty seconds",
       expect="the same person was thanked twice in a minute", script=S)
mutate("Favours.lua",
       "\tlocal PER_PERSON = 300\n",
       "\tlocal PER_PERSON = 3000\n",
       "thank: the per-person limit never ends",
       expect="the same person was not thanked again after five minutes", script=S)
mutate("Favours.lua",
       "\t\tthankedAt[name] = now\n",
       "",
       "thank: the person thanked is not remembered",
       expect="the same person was thanked twice in a minute", script=S)
mutate("Favours.lua",
       "\t\t\tif now - at >= PER_PERSON then thankedAt[who] = nil end\n",
       "\t\t\tif now - at >= 0 then thankedAt[who] = nil end\n",
       "thank: the sweep forgets everybody",
       expect="the same person was thanked twice in a minute", script=S)
mutate("Favours.lua",
       "\t\tif lastAt and now - lastAt < GAP then\n",
       "\t\tif false then\n",
       "thank: no gap between emotes",
       expect="two people were thanked three seconds apart", script=S)
mutate("Favours.lua",
       "\t\tlastAt = now\n",
       "",
       "thank: the last emote is not remembered",
       expect="two people were thanked three seconds apart", script=S)
mutate("Favours.lua",
       "\tlocal GAP = 10\n",
       "\tlocal GAP = 60\n",
       "thank: the gap is a minute",
       expect="a favour eleven seconds after the last thank was not thanked", script=S)
mutate("Favours.lua",
       "\t\tlocal ok, answer = pcall(EmoteCall(), \"THANK\", unit)\n",
       "\t\tlastAt = now\n"
       "\t\tthankedAt[name] = now\n"
       "\t\tlocal ok, answer = pcall(EmoteCall(), \"THANK\", unit)\n",
       "thank: an emote that never went holds the next back",
       expect="an emote that never went held the next one back", script=S)

# ------------------------------------------------ /manners debug
mutate("Commands.lua",
       "\t\tself:Print(\"  \" .. (db.prompt.thankEmote and L[\"thank with an emote: |cff00ff00on|r\"]\n",
       "\t\tself:Print(\"  \" .. (true and L[\"thank with an emote: |cff00ff00on|r\"]\n",
       "thank: debug always says on",
       expect="/manners debug does not say the emote is off", script=S)
mutate("Commands.lua",
       "\t\t\t\tthanks.thanked.name, math.floor(now - thanks.thanked.at), thanks.thanked.answer))\n",
       "\t\t\t\tthanks.thanked.name, math.floor(thanks.thanked.at), thanks.thanked.answer))\n",
       "thank: debug gives the wrong age",
       expect="/manners debug does not name the last thank", script=S)
mutate("Commands.lua",
       "\t\t\t\tthanks.skipped.name, math.floor(now - thanks.skipped.at), thanks.skipped.why))\n",
       "\t\t\t\tthanks.skipped.name, math.floor(now - thanks.skipped.at), \"?\"))\n",
       "thank: debug does not say why",
       expect="/manners debug does not name the last skip", script=S)
