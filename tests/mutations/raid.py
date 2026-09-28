# Mutations for dungeons and raids: the ready check and coming back from the
# dead putting the group first, the raid groups you buff, group members out of
# sight, the quiet favour line in an instance fight, and the mana floor. Each is
# caught by the scenario in tests/scenarios/raid.lua or manafloor.lua that
# names it.

# --- ready check ---

# The ready check never read by the queue.
mutate("Queue.lua",
       "\tlocal readyCheck = db.priority.readyCheck == true and ns.ReadyCheckRunning(now)\n",
       "\tlocal readyCheck = false\n",
       "ready check ignored by the queue",
       expect="a ready check did not put the group ahead of a favour owed",
       script="runscenarios.py")

# The switch ignored.
mutate("Queue.lua",
       "\tlocal readyCheck = db.priority.readyCheck == true and ns.ReadyCheckRunning(now)\n",
       "\tlocal readyCheck = ns.ReadyCheckRunning(now)\n",
       "ready check switch ignored",
       expect="a ready check put the group first with the switch off",
       script="runscenarios.py")

# The end of the check never heard.
mutate("Queue.lua",
       "function addon:READY_CHECK_FINISHED()\n\tsweep.readyUntil = nil\n",
       "function addon:READY_CHECK_FINISHED()\n",
       "ready check never ends",
       expect="the group stayed first after the ready check ended",
       script="runscenarios.py")

# A check the client never ended runs forever.
mutate("Queue.lua",
       "\treturn untilAt ~= nil and untilAt > (now or GetTime())\n",
       "\treturn untilAt ~= nil\n",
       "ready check never runs out",
       expect="a ready check the client never ended kept the group first",
       script="runscenarios.py")

# Somebody promoted on a guess: no reading asked for.
mutate("Queue.lua",
       "\t\tif inGroup and checked and (has == false or remaining ~= nil) then\n",
       "\t\tif inGroup then\n",
       "ready check promotes a guess",
       expect="a ready check promoted somebody without a reading of their buffs",
       script="runscenarios.py")

# Marked, but left where they were in the order.
mutate("Queue.lua",
       "\t\t\tif swept and priority > PRIORITY.sweep then priority = PRIORITY.sweep end\n",
       "",
       "put first but not moved",
       expect="a ready check did not put the group ahead of a favour owed",
       script="runscenarios.py")

# The reason line keeps the group's words.
mutate("Prompt.lua",
       "\tif entry.sweep and entry.reason == \"group\" then\n",
       "\tif false then\n",
       "reason line does not say why they are first",
       expect="the reason line does not say ready check",
       script="runscenarios.py")

# The tooltip silent about the ready check.
mutate("Prompt.lua",
       "\t\tif current.sweep == \"readycheck\" then\n",
       "\t\tif false then\n",
       "tooltip silent about the ready check",
       expect="the tooltip does not say a ready check is running",
       script="runscenarios.py")

# --- back from the dead ---

# Only watched out of a fight.
mutate("Queue.lua",
       "\tlocal down, revived = sweep.down, sweep.revived\n",
       "\tif InCombatLockdown() then return end\n\tlocal down, revived = sweep.down, sweep.revived\n",
       "deaths not watched in a fight",
       expect="somebody who died and came back in a fight was not put first after it",
       script="runscenarios.py")

# Nobody recorded as coming back.
mutate("Queue.lua",
       "\t\t\tif was and ns.UnitFullName(unit) == was then revived[was] = now end\n",
       "",
       "revival never recorded",
       expect="somebody back from the dead was not put first",
       script="runscenarios.py")

# The two minutes never run out.
mutate("Queue.lua",
       "\tif at and now - at < REVIVED_SECONDS then return \"revived\" end\n",
       "\tif at then return \"revived\" end\n",
       "revival never runs out",
       expect="somebody back from the dead stayed first after two minutes",
       script="runscenarios.py")

# The switch ignored once a revival was seen.
mutate("Queue.lua",
       "\tlocal at = db.priority.revived == true and sweep.revived[name]\n",
       "\tlocal at = sweep.revived[name]\n",
       "revived switch ignored",
       expect="somebody back from the dead was put first with the switch off",
       script="runscenarios.py")

# The name read at the death trusted over the one standing there now.
mutate("Queue.lua",
       "\t\t\tif was and ns.UnitFullName(unit) == was then revived[was] = now end\n",
       "\t\t\tif was then revived[ns.UnitFullName(unit) or was] = now end\n",
       "revival credited to whoever holds the token",
       expect="somebody handed a dead member's token was taken for them coming back",
       script="runscenarios.py")

# --- raid groups ---

# The setting never read.
mutate("Queue.lua",
       "\t\t\tif group and skipGroups[group] then return end\n",
       "",
       "raid groups ignored",
       expect="a raid member outside your raid groups was offered",
       script="runscenarios.py")

# A favour held back by it.
mutate("Queue.lua",
       "\t\tif skipGroups and reason == \"group\" and not pointed then\n",
       "\t\tif skipGroups and (reason == \"group\" or reason == \"owed\") and not pointed then\n",
       "raid groups hold back a favour owed",
       expect="a favour owed by somebody outside your raid groups was not offered",
       script="runscenarios.py")

# Your own target held back by it.
mutate("Queue.lua",
       "\t\tif skipGroups and reason == \"group\" and not pointed then\n",
       "\t\tif skipGroups and reason == \"group\" then\n",
       "raid groups hold back your target",
       expect="your target in another raid group was not offered",
       script="runscenarios.py")

# The page's checkbox writing the wrong way round.
mutate("Options.lua",
       "\t\t\t\t\tF().skipRaidGroups[group] = (not on) or nil\n",
       "\t\t\t\t\tF().skipRaidGroups[group] = on or nil\n",
       "raid group checkbox inverted",
       expect="unticking group 2 on the page did not switch it off",
       script="runscenarios.py")

# Nonsense in the saved set kept.
mutate("Core.lua",
       "\t\tif type(group) ~= \"number\" or group < 1 or group > 8 or group % 1 ~= 0 or flag ~= true then\n",
       "\t\tif type(group) ~= \"number\" then\n",
       "raid groups repair keeps nonsense",
       expect="a raid groups set with nonsense in it kept",
       script="runscenarios.py")

# --- out of sight ---

# Never asked.
mutate("Queue.lua",
       "\t\t\tand plain(UnitIsVisible and UnitIsVisible(unit)) == false then\n",
       "\t\t\tand false then\n",
       "out of sight not asked",
       expect="a group member out of sight was offered",
       script="runscenarios.py")

# Asked whatever the range switch says.
mutate("Queue.lua",
       "\t\tif reason == \"group\" and f.requireInRange\n",
       "\t\tif reason == \"group\"\n",
       "out of sight ignores the range switch",
       expect="a group member out of sight was left out with the range switch off",
       script="runscenarios.py")

# A withheld answer taken as out of sight.
mutate("Queue.lua",
       "\t\t\tand plain(UnitIsVisible and UnitIsVisible(unit)) == false then\n",
       "\t\t\tand plain(UnitIsVisible and UnitIsVisible(unit)) ~= true then\n",
       "withheld sight taken as out of sight",
       expect="a group member was left out when the game would not say whether they were in sight",
       script="runscenarios.py")

# --- the favour line in an instance fight ---

# Said anyway.
mutate("Favours.lua",
       "\t\tif db.verbose and not QuietInFight() then\n",
       "\t\tif db.verbose then\n",
       "favour line said in an instance fight",
       expect="a favour in a fight inside an instance was announced in chat",
       script="runscenarios.py")

# Held out of a fight too.
mutate("Favours.lua",
       "\t\tif not InCombatLockdown() then return false end\n\t\tlocal ok, inside, kind = pcall(_G.IsInInstance)\n",
       "\t\tlocal ok, inside, kind = pcall(_G.IsInInstance)\n",
       "favour line held out of a fight",
       expect="a favour outside an instance fight was not announced",
       script="runscenarios.py")

# --- mana floor ---

# Never read by the queue.
mutate("Queue.lua",
       "\t\tif savingMana and (reason == \"group\" or reason == \"nearby\") then return end\n",
       "",
       "mana floor ignored",
       expect="somebody was offered unasked while saving mana",
       script="runscenarios.py")

# Holding back favours and requests as well.
mutate("Queue.lua",
       "\t\tif savingMana and (reason == \"group\" or reason == \"nearby\") then return end\n",
       "\t\tif savingMana then return end\n",
       "mana floor holds back favours",
       expect="a favour owed was held back while saving mana",
       script="runscenarios.py")

# The comparison the wrong way round.
mutate("Queue.lua",
       "\tif mana * 100 < floor * most then return floor end\n",
       "\tif mana * 100 > floor * most then return floor end\n",
       "mana floor compared the wrong way",
       expect="somebody was offered unasked while saving mana",
       script="runscenarios.py")

# A withheld reading taken as empty.
mutate("Queue.lua",
       "\tlocal mana = plain(UnitPower(\"player\", MANA))\n\tif type(mana) ~= \"number\" then return nil end\n",
       "\tlocal mana = plain(UnitPower(\"player\", MANA)) or 0\n",
       "withheld mana taken as empty",
       expect="a withheld mana reading held the group back",
       script="runscenarios.py")

# A class with no mana bar read as out of mana.
mutate("Queue.lua",
       "\tif type(most) ~= \"number\" or most <= 0 then return nil end\n",
       "\tif type(most) ~= \"number\" then return nil end\n\tif most <= 0 then return floor end\n",
       "no mana bar read as saving mana",
       expect="a character with no mana bar was taken to be saving mana",
       script="runscenarios.py")

# The tooltip silent about it.
mutate("Prompt.lua",
       "\t\tlocal kept = ns.SavingMana and ns.SavingMana()\n",
       "\t\tlocal kept = nil\n",
       "tooltip silent about saving mana",
       expect="the tooltip does not say mana is being saved",
       script="runscenarios.py")

# An empty press says nothing about it.
mutate("Prompt.lua",
       "\t\telseif ns.SavingMana() then\n",
       "\t\telseif false then\n",
       "empty press silent about saving mana",
       expect="an empty press while saving mana does not say why",
       script="runscenarios.py")

# The page shows the slider to a warrior.
mutate("Options.lua",
       "\t\t\t\t\treturn class ~= nil and ns.MANA_CLASSES[class] ~= true\n",
       "\t\t\t\t\treturn false\n",
       "mana floor on a warrior's page",
       expect="the mana floor is on a warrior's page",
       script="runscenarios.py")

# No bounds.
mutate("Core.lua",
       "\t{ \"filters\", \"manaFloor\", 0, 90 },\n",
       "",
       "mana floor not repaired",
       expect="a mana floor of 150 was repaired",
       script="runscenarios.py")
