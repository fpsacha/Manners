# Mutations for the Core.lua fixes from the fifth bug hunt (second half of the
# file). Each one undoes a fix and is caught by the scenario in
# tests/scenarios/hunt5-core2.lua it names.
#
# Run by selftest.py with mutate() in scope.

# A late refusal putting back the debt of somebody just never-offered.
mutate("Core.lua",
       "\tlocal listed = settled.owed and not settled.listedAtSettle and ListedAs(settled.name)\n",
       "\tlocal listed = false\n",
       "late refusal ignores the never-offer list",
       expect="core2: a late refusal does not bring back somebody just never-offered (listed after the settle)",
       script="runscenarios.py")

# A late refusal letting go the debt of somebody listed before the favour,
# which the list never applied to.
mutate("Core.lua",
       "settled.owed and not settled.listedAtSettle and ListedAs(settled.name)",
       "settled.owed and ListedAs(settled.name)",
       "late refusal lets go somebody listed before",
       expect="core2: a late refusal does not bring back somebody just never-offered (listed before the favour)",
       script="runscenarios.py")

# The previous reading trusted after a doubted reading of nothing.
mutate("Core.lua",
       "\t\tif not sinceEmpty and lastPresent[instanceId] == key then return false end\n",
       "\t\tif lastPresent[instanceId] == key then return false end\n",
       "rebuff after an empty reading swallowed",
       expect="core2: a rebuff after the last buff ran out is a favour (a later end)",
       script="runscenarios.py")

# The previous reading never trusted again once a reading of nothing was
# doubted, so a refresh counts as a favour.
mutate("Core.lua",
       "\t\thaveLastScan = true\n\t\tsinceEmpty = false\n",
       "\t\thaveLastScan = true\n",
       "empty reading doubted for good",
       expect="core2: a rebuff after the last buff ran out is a favour (a later end)",
       script="runscenarios.py")

# The tokenless fallback blind to the loading screen.
mutate("Core.lua",
       "\t\t\t\tor ((not ns.zonedAt or entry.at >= ns.zonedAt) and (now - entry.at) <= grace)\n",
       "\t\t\t\tor (now - entry.at) <= grace\n",
       "tokenless favour offered across a loading screen",
       expect="core2: a stranger left behind by a loading screen is not offered (a loading screen)",
       script="runscenarios.py")

# The loading screen dropping favours with "Drop people who are probably gone" off.
mutate("Core.lua",
       "\t\t\tlocal fresh = not db.filters.reachableOnly\n"
       "\t\t\t\tor ((not ns.zonedAt or entry.at >= ns.zonedAt) and (now - entry.at) <= grace)\n",
       "\t\t\tlocal fresh = (not ns.zonedAt or entry.at >= ns.zonedAt)\n"
       "\t\t\t\tand (not db.filters.reachableOnly or (now - entry.at) <= grace)\n",
       "loading screen drops people with the option off",
       expect="core2: a stranger left behind by a loading screen is not offered (a loading screen, keeping people who are probably gone)",
       script="runscenarios.py")

# A /reload taken for a loading screen.
mutate("Core.lua",
       "\tif plain(isInitialLogin) == false and plain(isReloadingUi) == false then\n",
       "\tif plain(isInitialLogin) == false then\n",
       "a reload taken for a loading screen",
       expect="core2: a stranger left behind by a loading screen is not offered (a reload)",
       script="runscenarios.py")

# A profile section that is not a table left for the clamp to throw on.
mutate("Core.lua",
       "\t\tif type(default) == \"table\" and type(profile[key]) ~= \"table\" then\n",
       "\t\tif false then\n",
       "damaged profile section not repaired",
       expect="core2: a damaged profile section does not stop the addon (speech)",
       script="runscenarios.py")

# A favour in a fight said to be on the prompt.
mutate("Core.lua",
       "\t\t\telseif reachable and InCombatLockdown() and not FrozenOn(seen.name) then\n",
       "\t\t\telseif false then\n",
       "favour in a fight said to be on the prompt",
       expect="core2: a favour in a fight is offered once it ends (in a fight)",
       script="runscenarios.py")

# A favour in a fight said to wait for its end while the frozen prompt is on them.
mutate("Core.lua",
       "\t\t\telseif reachable and InCombatLockdown() and not FrozenOn(seen.name) then\n",
       "\t\t\telseif reachable and InCombatLockdown() then\n",
       "favour in a fight ignores the frozen prompt",
       expect="core2: a favour in a fight is offered once it ends (in a fight, the prompt already on her)",
       script="runscenarios.py")

# /manners unlock in a fight claiming a frozen cast with nothing armed.
mutate("Core.lua",
       "\t\t\tif type(armed) == \"string\" and armed ~= \"\" then\n",
       "\t\t\tif true then\n",
       "unlock in a fight claims a frozen cast",
       expect="core2: unlocking in a fight says whether anything is armed (nothing armed)",
       script="runscenarios.py")

# The snooze's end in the PC's time beside a minimap clock on realm time.
mutate("Core.lua",
       "\tif ok and plain(useLocal) == \"0\" and type(realm) == \"function\" then\n",
       "\tif false then\n",
       "snooze end ignores the realm clock",
       expect="core2: the snooze ends on the minimap clock (realm time, 24-hour)",
       script="runscenarios.py")

# The whole request closed by the first buff to land.
mutate("Core.lua",
       "\t\t\t\tif not buffKey or next(request.keys) == nil then table.remove(requests, i) end\n",
       "\t\t\t\ttable.remove(requests, i)\n",
       "request closed by its first buff",
       expect="core2: a request is answered buff by buff (owed asker)",
       script="runscenarios.py")

# "buffs please" closed by the first buff to land.
mutate("Core.lua",
       "\t\t\t\tif buffKey and request.keys == ASK.ANY then\n",
       "\t\t\t\tif false then\n",
       "buffs please closed by its first buff",
       expect="core2: a request is answered buff by buff (buffs please)",
       script="runscenarios.py")

# The buff that landed left on the request, so an asker whose buffs cannot be
# read is offered it again until the request runs out.
mutate("Core.lua",
       "\t\t\t\tif buffKey then request.keys[buffKey] = nil end\n",
       "",
       "landed buff left on the request",
       expect="core2: a request is answered buff by buff (buffs please, unreadable)",
       script="runscenarios.py")

# German question openers forgotten.
mutate("Core.lua",
       "\t\t\t\"ist\", \"sind\", \"hat\", \"wer\", \"was\", \"wie\", \"warum\", \"welche\", \"lohnt\",\n",
       "",
       "german question openers ask for it",
       expect="core2: a question about the buff is not a request (deDE)",
       script="runscenarios.py")

# A Chinese question particle ignored.
mutate("Core.lua",
       "\t\t\tand not ASK.questionEnds[stem:sub(-3)] and not lowered:find(",
       "\t\t\tand not lowered:find(",
       "chinese question particle ignored",
       expect="core2: a question about the buff is not a request (zhCN)",
       script="runscenarios.py")

# A Korean question mark taken for asking.
mutate("Core.lua",
       "\t\t\tand not ASK.questionEnds[stem:sub(-3)] and not lowered:find(\"[\\234-\\237]\")\n",
       "\t\t\tand not ASK.questionEnds[stem:sub(-3)]\n",
       "korean question mark asks",
       expect="core2: a question about the buff is not a request (koKR)",
       script="runscenarios.py")

# A whole Chinese sentence taken as one short word.
mutate("Core.lua",
       "\t\t\tif word:find(\"[\\228-\\233]\") and select(2, word:gsub(\"[\\192-\\255]\", \"\")) > ASK.mostChars then\n",
       "\t\t\tif false then\n",
       "chinese sentences uncapped",
       expect="core2: a long Chinese sentence is not a request",
       script="runscenarios.py")

# The Chinese please matched inside 要求 and 需求 again, as a plain please.
mutate("Core.lua",
       "\t\tpleaseInside = { \"请\", \"請\", \"부탁\", \"주세요\" },\n",
       "\t\tpleaseInside = { \"请\", \"請\", \"求\", \"부탁\", \"주세요\" },\n",
       "chinese please found inside other words",
       expect="core2: the Chinese please inside another word is not a please",
       script="runscenarios.py")

# The Chinese please counted whatever stands before it.
mutate("Core.lua",
       "\t\t\tif not ASK.notBeforeQiu[lowered:sub(at - 3, at - 1)] then pleased = true break end\n",
       "\t\t\tif true then pleased = true break end\n",
       "chinese please counted inside a compound",
       expect="core2: the Chinese please inside another word is not a please",
       script="runscenarios.py")

# The Chinese please counted only opening the message, not after an address.
mutate("Core.lua",
       "\t\tlocal pleased, at = false, lowered:find(\"求\", 1, true)\n",
       "\t\tlocal pleased, at = false, lowered:find(\"^%s*求\")\n",
       "chinese please after an address ignored",
       expect="core2: the Chinese please inside another word is not a please",
       script="runscenarios.py")

# A Korean name found inside another word.
mutate("Core.lua",
       "\t\t\t\tand ownWords[1]:find(\"[\\228-\\233]\") and #ownWords[1] >= 6\n",
       "\t\t\t\tand #ownWords[1] >= 6\n",
       "korean name found inside a word",
       expect="core2: a Korean name is not found inside another word",
       script="runscenarios.py")

# A Chinese name with full-width punctuation no longer found inside a message.
mutate("Core.lua",
       "\t\t\t\tand ownWords[1]:find(\"[\\228-\\233]\") and #ownWords[1] >= 6\n",
       "\t\t\t\tand not ownWords[1]:find(\"[\\192-\\227\\234-\\255]\") and #ownWords[1] >= 6\n",
       "chinese name with punctuation not found",
       expect="core2: a Chinese name with punctuation is found inside the message",
       script="runscenarios.py")

# German and Italian negation forgotten.
mutate("Core.lua",
       "\t\t\t\"nicht\", \"kein\", \"keine\", \"keinen\", \"keiner\", \"nein\", \"pas\", \"non\",\n",
       "\t\t\t\"nicht\", \"kein\", \"pas\",\n",
       "german and italian no still asks",
       expect="core2: a request that says no is not a request (deDE)",
       script="runscenarios.py")

# Portuguese negation forgotten.
mutate("Core.lua",
       "\t\t\t\"não\", \"nao\", \"нет\", \"не\" }),\n",
       "\t\t\t\"нет\", \"не\" }),\n",
       "portuguese no still asks",
       expect="core2: a request that says no is not a request (ptBR)",
       script="runscenarios.py")

# Chinese and Korean negation inside a word ignored.
mutate("Core.lua",
       "\t\tfor _, inside in ipairs(ASK.neverInside) do\n",
       "\t\tfor _, inside in ipairs({}) do\n",
       "chinese and korean no inside a word",
       expect="core2: a request that says no is not a request (zhCN)",
       script="runscenarios.py")

# A bare 别 taken for "don't", which also sits inside 特别 and 别人.
mutate("Core.lua",
       "\"不需要\", \"别给\",",
       "\"不需要\", \"别\", \"别给\",",
       "chinese bare bie says no",
       expect="core2: a request that says no is not a request (zhCN)",
       script="runscenarios.py")
