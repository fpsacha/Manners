# Mutations for a hunter's pet, further (HunterPet.lua, HunterPetHints.lua,
# Prompt/MendPet.lua and their hooks in Core.lua, Prompt/Press.lua and
# Options/): the master and every piece's own switch, the pace, the new
# moments, the meal hold, the Mend Pet button in a fight and the three hints.
# Each is caught by the scenario in tests/scenarios/hunterpet2.lua that names it.

S = "runscenarios.py"
H2 = "hunterpet2: "

# ------------------------------------------------ the settings and the pace
mutate("Core.lua",
       "\t\t\tall = true, leaveFood = true, growl = false,",
       "\t\t\tall = false, leaveFood = true, growl = false,",
       "hunterpet2: the master off in a new profile",
       expect=H2 + "defaults, and a damaged pace put back", script=S)

mutate("Core.lua",
       "growl = false, training = true,",
       "growl = true, training = true,",
       "hunterpet2: Growl's reminder on in a new profile",
       expect=H2 + "defaults, and a damaged pace put back", script=S)

mutate("Core.lua",
       "pace = \"sometimes\", answer = true,",
       "pace = \"often\", answer = true,",
       "hunterpet2: a new profile paced often",
       expect=H2 + "defaults, and a damaged pace put back", script=S)

mutate("HunterPet.lua",
       "then beast.pace = \"sometimes\" end\n",
       "then beast.pace = beast.pace end\n",
       "hunterpet2: a damaged pace left as it is",
       expect=H2 + "defaults, and a damaged pace put back", script=S)

mutate("HunterPet.lua",
       "\tif beast.all == false then moment = nil return queue, verdicts end\n",
       "",
       "hunterpet2: everything off, the queue still gets the pet",
       expect=H2 + "everything off leaves the pet alone", script=S)

mutate("HunterPet.lua",
       "beast.all ~= false and beast.bond == true and beast[kind] ~= false",
       "beast.bond == true and beast[kind] ~= false",
       "hunterpet2: a moment kept with everything off",
       expect=H2 + "everything off leaves the pet alone", script=S)

mutate("HunterPet.lua",
       " and beast[kind] ~= false and db.enabled",
       " and db.enabled",
       "hunterpet2: a moment kept with its own switch off",
       expect=H2 + "a moment's own switch drops only that moment", script=S)

mutate("HunterPet.lua",
       "math.max(0, Pace().gap - since)",
       "math.max(0, 1200 - since)",
       "hunterpet2: the gap ignores the pace",
       expect=H2 + "pace", script=S)

mutate("HunterPet.lua",
       "On(Switches(Profile()), \"answer\") and (\" \"",
       "true and (\" \"",
       "hunterpet2: the pet answers with its switch off",
       expect=H2 + "answer off", script=S)

mutate("HunterPet.lua",
       "\tif not On(Switches(db), \"words\") then return false end\n",
       "",
       "hunterpet2: a line said with its switch off",
       expect=H2 + "words off says nothing", script=S)

mutate("HunterPet.lua",
       " and not entry.item and Remembers() and Record",
       " and not entry.item and Record",
       "hunterpet2: a pat counted with the memory off",
       expect=H2 + "memory off counts nothing", script=S)

mutate("HunterPet.lua",
       "local function Milestones(name)\n\tif not Remembers() then return end\n",
       "local function Milestones(name)\n",
       "hunterpet2: a milestone said with the memory off",
       expect=H2 + "memory off counts nothing", script=S)

mutate("HunterPet.lua",
       "local rec = char and Remembers() and Record(char, pet, st.family)",
       "local rec = char and Record(char, pet, st.family)",
       "hunterpet2: a fight counted with the memory off",
       expect=H2 + "memory off counts nothing", script=S)

mutate("HunterPet.lua",
       "local rec = Remembers() and Record(char, st.name, st.family)",
       "local rec = Record(char, st.name, st.family)",
       "hunterpet2: a meal counted with the memory off",
       expect=H2 + "memory off counts nothing", script=S)

# ------------------------------------------------ the meal hold and a share
mutate("HunterPet.lua",
       "\tif clock.mealUntil and now < clock.mealUntil then return \"eating\" end\n\treturn nil\n",
       "\treturn nil\n",
       "hunterpet2: care offered while you eat",
       expect=H2 + "care waits while you eat", script=S)

mutate("HunterPet.lua",
       "\tif clock.mealUntil and now < clock.mealUntil then return \"eating\" end -- moments\n",
       "",
       "hunterpet2: a moment offered while you eat",
       expect=H2 + "share waits for the meal", script=S)

mutate("HunterPet.lua",
       "not (moment and moment.kind == \"share\") and beast.feed",
       "beast.feed",
       "hunterpet2: Feed care beside a share",
       expect=H2 + "share waits for the meal", script=S)

mutate("Prompt/Press.lua",
       "S.current and S.current.bond and not S.current.item then\n",
       "S.current and S.current.bond then\n",
       "hunterpet2: a share pressed in the global cooldown",
       expect=H2 + "share waits for the meal", script=S)

mutate("HunterPet.lua",
       "entry.care or (entry.item and \"feed\") or \"bond\", entry.item",
       "entry.care or \"bond\", entry.item",
       "hunterpet2: a share's food never learned",
       expect=H2 + "share waits for the meal", script=S)

# ------------------------------------------------ the new moments
mutate("HunterPet.lua",
       "now - clock.tamedAt <= K.TAME_WINDOW",
       "true",
       "hunterpet2: a pet tamed long ago welcomed",
       expect=H2 + "a newly tamed pet", script=S)

mutate("HunterPet.lua",
       "MISSED_AFTER = 3 * 86400",
       "MISSED_AFTER = 2 * 86400",
       "hunterpet2: missed after two days",
       expect=H2 + "missed after three days", script=S)

mutate("HunterPet.lua",
       "\tclock.sorryTurn = not clock.sorryTurn\n",
       "",
       "hunterpet2: sorry never takes a turn",
       expect=H2 + "sorry takes turns with welcome", script=S)

mutate("HunterPet.lua",
       "\t\tif clock.pullAt or InCombatLockdown() then clock.diedInFight = true end\n\telseif st.out then",
       "\telseif st.out then",
       "hunterpet2: a fall met at the read is no fall in a fight",
       expect=H2 + "sorry takes turns with welcome", script=S)

mutate("HunterPet.lua",
       "\t\t\t\tif clock.pullAt or InCombatLockdown() then clock.diedInFight = true end\n\t\t\t\tst.health = 0",
       "\t\t\t\tst.health = 0",
       "hunterpet2: a fall heard on the pet's health is no fall in a fight",
       expect=H2 + "sorry takes turns with welcome", script=S)

mutate("HunterPet.lua",
       "SAVED_BELOW = 0.2",
       "SAVED_BELOW = 0.5",
       "hunterpet2: thanks for saving you at half health",
       expect=H2 + "saved", script=S)

mutate("HunterPet.lua",
       "\tif not LOYAL[FLAVOUR] then return nil end\n",
       "",
       "hunterpet2: loyalty read where pets have none",
       expect=H2 + "grown", script=S)

mutate("HunterPet.lua",
       "\t\tif event == \"UNIT_LEVEL\" and unit ~= \"pet\" then return end\n",
       "",
       "hunterpet2: anybody's level moves the pet",
       expect=H2 + "grown", script=S)

mutate("HunterPet.lua",
       "if at <= m.days then rec.said[\"days\" .. at] = true end",
       "if false then end",
       "hunterpet2: an anniversary never marked",
       expect=H2 + "anniversary once, marked when shown", script=S)

mutate("HunterPet.lua",
       "\t\tif not (m[1] == \"days\" and byMoment) then\n",
       "\t\tif true then\n",
       "hunterpet2: the days said twice",
       expect=H2 + "anniversary once, marked when shown", script=S)

mutate("HunterPet.lua",
       "\tif pat and play then clock.playTurn = not clock.playTurn end\n",
       "",
       "hunterpet2: the pat never gives way to the game",
       expect=H2 + "pat and fetch take turns", script=S)

# ------------------------------------------------ the Mend Pet button
mutate("Prompt/MendPet.lua",
       "\tif health / most >= Beast.K.MEND_BELOW then return false, true end\n",
       "",
       "hunterpet2: the button lit at any health",
       expect=H2 + "the mend button in a fight", script=S)

mutate("Prompt/MendPet.lua",
       "function MendPet:Refresh()\n\tif InCombatLockdown() then return end\n",
       "function MendPet:Refresh()\n",
       "hunterpet2: the button refreshed in a fight",
       expect=H2 + "the mend button in a fight", script=S)

mutate("Prompt/MendPet.lua",
       "tbc = 15, mists = 10",
       "tbc = 0, mists = 10",
       "hunterpet2: lit again while Mend Pet's heal runs on",
       expect=H2 + "busy after a mend", script=S)

mutate("Prompt/MendPet.lua",
       "or most <= 0 then return false, false end",
       "or most <= 0 then return false, true end",
       "hunterpet2: a secret health read as nothing to say",
       expect=H2 + "mend button half lit with a secret health", script=S)

mutate("Prompt/MendPet.lua",
       "local beside = bf and bf.Applies() and bf:Button() or nil",
       "local beside = nil",
       "hunterpet2: the button placed over break free's",
       expect=H2 + "mend button beside break free", script=S)

# ------------------------------------------------ the hints
mutate("HunterPetHints.lua",
       "LOW_FOOD = 5",
       "LOW_FOOD = 0",
       "hunterpet2: no vendor line however little is left",
       expect=H2 + "vendor food line", script=S)

mutate("HunterPetHints.lua",
       "\tif told.vendors[who] then return end\n",
       "",
       "hunterpet2: a vendor told twice",
       expect=H2 + "vendor food line", script=S)

mutate("HunterPetHints.lua",
       "\t\tif told.zone == zone then return end\n",
       "",
       "hunterpet2: a zone told twice",
       expect=H2 + "growl reminders", script=S)

mutate("HunterPetHints.lua",
       "\t\tif told.alone then return end\n",
       "",
       "hunterpet2: alone told in every zone",
       expect=H2 + "growl reminders", script=S)

mutate("HunterPetHints.lua",
       "\tif Beast.Trains() then frame:RegisterEvent(\"UNIT_PET_TRAINING_POINTS\") end\n",
       "\tframe:RegisterEvent(\"UNIT_PET_TRAINING_POINTS\")\n",
       "hunterpet2: the training event asked for where it does not exist",
       expect=H2 + "training points", script=S)

mutate("HunterPetHints.lua",
       "\tif left <= 0 or (was and left <= was) then return end\n",
       "\tif left <= 0 then return end\n",
       "hunterpet2: the same training points told again",
       expect=H2 + "training points", script=S)

# ------------------------------------------------ the options
mutate("Options/Who.lua",
       "so a press never stands you up.\"], feeds },",
       "so a press never stands you up.\"], nil },",
       "hunterpet2: a share's switch shown where pets are not fed",
       expect=H2 + "the controls per client", script=S)

mutate("Options/Who.lua",
       "return NotHunter() or BondOff() or (extra",
       "return NotHunter() or (extra",
       "hunterpet2: the moments shown with Bond off",
       expect=H2 + "the controls per client", script=S)

mutate("Options/Look.lua",
       "hidden = function() return not (ns.Beast and ns.Beast.IsHunter() and ns.Beast.KnowsMend()) end,",
       "hidden = function() return false end,",
       "hunterpet2: Mend Pet's switch shown to a priest",
       expect=H2 + "mend on Look's In a fight", script=S)

mutate("Options/Advanced.lua",
       "\"beast.anniversary\",",
       "",
       "hunterpet2: the reset leaves the anniversary switch",
       expect="reset: the list leaves out", script=S)

mutate("Options/Advanced.lua",
       "\"prompt.breakFree\", \"beast.fightMend\",",
       "\"prompt.breakFree\",",
       "hunterpet2: Look's reset leaves Mend Pet's switch",
       expect="reset: the list leaves out", script=S)

# ------------------------------------------------ the inn line
mutate("HunterPet.lua",
       "if clock.morning and On(Switches(Profile()), \"morning\") and",
       "if clock.morning and",
       "hunterpet2: the inn line said with its switch off",
       expect=H2 + "the inn line keeps to its switch", script=S)

mutate("HunterPet.lua",
       "st.name and On(Switches(Profile()), \"morning\") and ns.Resting()",
       "st.name and ns.Resting()",
       "hunterpet2: a night kept with its switch off",
       expect=H2 + "the inn line keeps to its switch", script=S)

# ------------------------------------------------ review fixes
mutate("HunterPet.lua",
       "return db ~= nil and db.enabled == true and On(beast, \"memory\") and beast.bond == true",
       "return On(beast, \"memory\")",
       "hunterpet2: the memory outside Bond and Manners' own switch",
       expect=H2 + "the memory is held by Bond with my pet", script=S)

mutate("HunterPet.lua",
       "return db ~= nil and db.enabled == true and On(beast, \"memory\") and beast.bond == true",
       "return db ~= nil and On(beast, \"memory\") and beast.bond == true",
       "hunterpet2: a milestone said with Manners off",
       expect=H2 + "Manners off says no milestone", script=S)

mutate("HunterPet.lua",
       "	mealKind[spell] = kind\n",
       "",
       "hunterpet2: every cast asks the client its name",
       expect=H2 + "your casts cost no name lookup each", script=S)

mutate("HunterPet.lua",
       "if kind ~= \"food\" or not FEEDS[FLAVOUR] then return end",
       "if not FEEDS[FLAVOUR] then return end",
       "hunterpet2: a drink offered as a meal to share",
       expect=H2 + "a drink is no meal to share", script=S)

mutate("HunterPet.lua",
       "if moment and moment.kind == \"share\" then ns.MarkAttempted(\"?pet:feed\", \"beast:feed\", K.NOT_NOW.feed) end\n			moment = nil",
       "moment = nil",
       "hunterpet2: a not now to a share lets Feed ask at once",
       expect=H2 + "a not now to a share is one to Feed", script=S)
