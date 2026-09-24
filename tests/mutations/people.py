# Mutations for "who gets offered": friends and guildmates first, the
# never-offer list and the shift-right-click that fills it, and passers-by only
# while resting. Each is caught by the scenario in tests/scenarios/people.lua
# that names it.

# The never-offer list not consulted at all.
mutate("Core.lua",
       "\t\tif not isOwed and ns.IsNeverOffered(full) then\n",
       "\t\tif false then\n",
       "never-offer list ignored by the queue",
       expect="shift-right-click never offers them again",
       script="runscenarios.py")

# The list applied to somebody who buffed you, against what the page says.
mutate("Core.lua",
       "\t\tif not isOwed and ns.IsNeverOffered(full) then\n",
       "\t\tif ns.IsNeverOffered(full) then\n",
       "never-offer list turns away a favour owed",
       expect="a never-listed person who buffs you is still offered",
       script="runscenarios.py")

# Shift ignored, so shift-right-click is only the skip.
mutate("Prompt.lua",
       "\t\t\tif IsShiftKeyDown and ns.plain(IsShiftKeyDown()) then\n",
       "\t\t\tif false then\n",
       "shift-right-click only skips",
       expect="shift-right-click never offers them again",
       script="runscenarios.py")

# Shift read as held on every right-click, so the skip fills the list.
mutate("Prompt.lua",
       "\t\t\tif IsShiftKeyDown and ns.plain(IsShiftKeyDown()) then\n",
       "\t\t\tif true then\n",
       "plain right-click puts them on the list",
       expect="shift-right-click never offers them again",
       script="runscenarios.py")

# The shifted press re-silencing the right button, which is a protected call
# and is refused in a fight.
mutate("Prompt.lua",
       "\t\t\t\tns.PutOnNeverList(victim)\n",
       "\t\t\t\tns.PutOnNeverList(victim)\n\t\t\t\tself:SetAttribute(\"type2\", \"none\")\n",
       "shift-right-click touches the button in a fight",
       expect="the never list is safe in combat",
       script="runscenarios.py")

# The favour kept when an owed person is shift-right-clicked, so they come
# straight back.
mutate("Core.lua",
       "\t\tif ListedAs(key) == listed then\n\t\t\towed[key] = nil\n",
       "\t\tif ListedAs(key) == listed then\n",
       "owed person shift-right-clicked keeps the debt",
       expect="a never-listed person who buffs you is still offered",
       script="runscenarios.py")

# A name typed in another case not matched.
mutate("Core.lua",
       "\t\t\tif k == lower or k == short then return key end\n",
       "\t\t\tif false then return key end\n",
       "never-offer list matches exact case only",
       expect="the never list persists and can be emptied",
       script="runscenarios.py")

# Taking somebody off the list leaving them on it.
mutate("Core.lua",
       "\tNeverSet()[listed] = nil\n",
       "\tlocal _ = NeverSet()[listed]\n",
       "taking somebody off the list does nothing",
       expect="the never list persists and can be emptied",
       script="runscenarios.py")

# A saved list that is not a table left as it is.
mutate("Core.lua",
       "\tif type(profile.never) ~= \"table\" then profile.never = {} end\n",
       "",
       "broken never-offer list not repaired",
       expect="a broken never list in a saved profile is repaired",
       script="runscenarios.py")

# The sort no longer puts friends and guildmates first.
mutate("Core.lua",
       "\t\tif (a.close ~= nil) ~= (b.close ~= nil) then return a.close ~= nil end\n",
       "",
       "friends and guildmates not put first",
       expect="friends and guildmates come first",
       script="runscenarios.py")

# The switch not honoured, so friends are looked up and put first regardless.
mutate("Core.lua",
       "\tlocal friendsFirst = db.priority.friends == true\n",
       "\tlocal friendsFirst = true\n",
       "friends first ignores its switch",
       expect="friends and guildmates come first",
       script="runscenarios.py")

# Friends put ahead across kinds of offer: a friend passing by above your group.
mutate("Core.lua",
       "\t\tif a.priority ~= b.priority then return a.priority < b.priority end\n"
       "\t\t-- Inside a kind of offer",
       "\t\tif (a.close ~= nil) ~= (b.close ~= nil) then return a.close ~= nil end\n"
       "\t\tif a.priority ~= b.priority then return a.priority < b.priority end\n"
       "\t\t-- Inside a kind of offer",
       "a friend passing by jumps your group",
       expect="within their kind",
       script="runscenarios.py")

# The friends API called bare, so a refusal throws into the scan.
mutate("Core.lua",
       "safecall(list.IsFriend, rawGuid) == true",
       "list.IsFriend(rawGuid) == true",
       "friends API called without a net",
       expect="unknown friend answers are not friends",
       script="runscenarios.py")

# A withheld Battle.net answer read as a friend.
mutate("Core.lua",
       "and type(safecall(bnet.GetGameAccountInfoByGUID, rawGuid)) == \"table\" then",
       "and bnet.GetGameAccountInfoByGUID and pcall(bnet.GetGameAccountInfoByGUID, rawGuid) then",
       "a refused Battle.net answer read as a friend",
       expect="unknown friend answers are not friends",
       script="runscenarios.py")

# The friends list read by index dropped, so the fallback finds nobody.
mutate("Core.lua",
       "\t\t\tif type(name) == \"string\" then friendNames[name:lower()] = true end\n",
       "",
       "friends list fallback finds nobody",
       expect="unknown friend answers are not friends",
       script="runscenarios.py")

# Passers-by offered out in the world with the setting on.
mutate("Core.lua",
       "\t\tif reason == \"nearby\" and not pointed and notResting then\n",
       "\t\tif false then\n",
       "resting-only setting ignored",
       expect="passers-by only while resting",
       script="runscenarios.py")

# The target not exempt, against what the option text says.
mutate("Core.lua",
       "\t\tif reason == \"nearby\" and not pointed and notResting then\n",
       "\t\tif reason == \"nearby\" and notResting then\n",
       "resting-only drops your target",
       expect="passers-by only while resting",
       script="runscenarios.py")

# A resting answer withheld as a secret read as "not resting".
mutate("Core.lua",
       "\tif issecretvalue and issecretvalue(value) then return nil end\n"
       "\treturn value == true or value == 1\n",
       "\treturn value == true or value == 1\n",
       "withheld resting answer drops passers-by",
       expect="passers-by only while resting",
       script="runscenarios.py")
