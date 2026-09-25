# Mutations for the Core.lua fixes from the third bug hunt. Each one undoes a
# fix and is caught by the scenario in tests/scenarios/hunt3-core.lua it names.
#
# Run by selftest.py with mutate() in scope.

# core-1: a favour let go through the never-offer list, never told to the
# ledger -- the row stays owed and swallows the next favour.
mutate("Core.lua",
       "\t\t\tTellLedger(\"LetGo\", key, \"never\")\n",
       "",
       "never-offer list leaves the ledger row owed",
       expect="core: the never-offer list lets the favour go in the ledger",
       script="runscenarios.py")

# core-2: the never-offer line never noticing the fight -- it promises the
# person the frozen prompt still casts at will not be offered anything.
mutate("Core.lua",
       "\tif InCombatLockdown() and ns.Prompt and ns.Prompt.Showing then\n\t\tns.Guard(\"never-offer prompt check\"",
       "\tif false then\n\t\tns.Guard(\"never-offer prompt check\"",
       "never-offer line silent about the fight",
       expect="core: never-offering the person on the prompt in a fight says a press still casts",
       script="runscenarios.py")

# core-3: a late refusal writing the older debt over a newer favour's.
mutate("Core.lua",
       "\t\tif not standing or LiveExpiry(standing) < LiveExpiry(settled.owed) then\n",
       "\t\tif true then\n",
       "late refusal overwrites the newer debt",
       expect="core: a late refusal keeps the newer favour's debt",
       script="runscenarios.py")

# core-4: UnitIsInMyGuild's plain no overruled by the guild names.
mutate("Core.lua",
       "\t\telseif inMine == nil then\n",
       "\t\telse\n",
       "guild names overrule a definite no",
       expect="core: a guild of the same name is not your guild (camelot, a definite no over matching names)",
       script="runscenarios.py")

# core-4: the guild names compared without the realms.
mutate("Core.lua",
       "\t\t\t\tand theirs == ours and theirRealm and theirRealm == ourRealm then\n",
       "\t\t\t\tand theirs == ours then\n",
       "guild names compared across realms",
       expect="core: a guild of the same name is not your guild (camelot, no UnitIsInMyGuild, another realm)",
       script="runscenarios.py")

# core-5: the old ceiling, which a 90-line phrase box outgrows.
mutate("Core.lua",
       "local SHARE_MAX = 64000\n",
       "local SHARE_MAX = 8000\n",
       "settings strings capped at 8000 again",
       expect="core: a long profile's export and its import undo read back (90 lines): your own export",
       script="runscenarios.py")

# core-5: the undo read back under the ceiling meant for strangers' strings.
mutate("Core.lua",
       "\tlocal parsed = Parse(lastImportUndo, math.huge)\n",
       "\tlocal parsed = Parse(lastImportUndo, SHARE_MAX)\n",
       "import undo read under the paste ceiling",
       expect="core: a long profile's export and its import undo read back (more than any string can hold): the phrase box did not come back",
       script="runscenarios.py")

# core-5: an export too long to import back handed over without a word.
mutate("Core.lua",
       "\t\tif type(export) == \"string\" and #export:gsub(\"%s+\", \"\") > SHARE_MAX then\n",
       "\t\tif false then\n",
       "overlong export said nothing",
       expect="core: a long profile's export and its import undo read back (more than any string can hold): an export too long",
       script="runscenarios.py")

# core-6: every profile switch throwing the undo away again.
mutate("Core.lua",
       "\tif event == nil then\n\t\tns.ForgetImportUndo()\n\telse\n",
       "\tif true then\n\t\tns.ForgetImportUndo()\n\telse\n",
       "import undo lost on a profile round trip",
       expect="core: an import's undo survives a profile round trip (round trip)",
       script="runscenarios.py")

# core-6: a reset or copy of the import's own profile leaving the undo alive.
mutate("Core.lua",
       "\telseif here == undoProfile then\n\t\tns.ForgetImportUndo()\n",
       "\telseif false then\n\t\tns.ForgetImportUndo()\n",
       "import undo outlives a reset of its profile",
       expect="core: an import's undo survives a profile round trip (reset)",
       script="runscenarios.py")

# core-6: deleting the import's profile leaving the undo alive.
mutate("Core.lua",
       "\t\tif name ~= nil and name == undoProfileName then ns.ForgetImportUndo() end\n",
       "",
       "import undo outlives its deleted profile",
       expect="core: an import's undo survives a profile round trip (delete it)",
       script="runscenarios.py")

# core-7: the snooze line saying "no prompt" over an unlocked prompt.
mutate("Core.lua",
       "\telseif not db.prompt.locked then\n\t\t-- An unlocked prompt stays up through a snooze",
       "\telseif false then\n\t\t-- An unlocked prompt stays up through a snooze",
       "snooze line ignores the unlocked prompt",
       expect="core: a snooze while unlocked does not say the prompt is gone (unlocked)",
       script="runscenarios.py")

# core-8: the greeting counting the queue through a snooze.
mutate("Core.lua",
       "\tif profile and profile.enabled and profile.prompt.locked and not ns.SnoozeLeft() then\n",
       "\tif profile and profile.enabled and profile.prompt.locked then\n",
       "greeting ignores the snooze",
       expect="core: the greeting does not point at a snoozed prompt",
       script="runscenarios.py")

# core-9: the favour line promising the prompt while snoozed.
mutate("Core.lua",
       "\tlocal snoozeEnds = reachable and ns.SnoozeLeft() and ns.SnoozeEndsAt()\n",
       "\tlocal snoozeEnds = nil\n",
       "favour line ignores the snooze",
       expect="core: the favour line does not promise a prompt that is kept away (snoozed)",
       script="runscenarios.py")

# core-9: the favour line promising the prompt while the mount keeps it away.
mutate("Core.lua",
       "\telseif reachable and ns.HiddenWhileMounted() then\n",
       "\telseif false then\n",
       "favour line ignores the mount",
       expect="core: the favour line does not promise a prompt that is kept away (mounted)",
       script="runscenarios.py")

# core-9: the favour line promising the prompt while it is unlocked.
mutate("Core.lua",
       "\telseif reachable and not db.prompt.locked then\n",
       "\telseif false then\n",
       "favour line ignores the unlocked prompt",
       expect="core: the favour line does not promise a prompt that is kept away (unlocked)",
       script="runscenarios.py")

# core-10: a refusal leaving the sweep running.
mutate("Core.lua",
       "\t-- went through on.\n\tSyncSweep()\n",
       "\t-- went through on.\n",
       "sweep not re-read on a refused cast",
       expect="core: the sweep stops when the global cooldown is given back (refused)",
       script="runscenarios.py")

# core-10: the client's own word that the cooldowns changed, ignored.
mutate("Core.lua",
       "function addon:SPELL_UPDATE_COOLDOWN()\n\tSyncSweep()\nend\n",
       "function addon:SPELL_UPDATE_COOLDOWN()\nend\n",
       "sweep not re-read on a cooldown update",
       expect="core: the sweep stops when the global cooldown is given back (cooldown update)",
       script="runscenarios.py")

# core-10: an interrupted cast leaving the sweep running.
mutate("Core.lua",
       "function addon:UNIT_SPELLCAST_INTERRUPTED(_, unit)\n\tif unit ~= \"player\" then return end\n\tSyncSweep()\n",
       "function addon:UNIT_SPELLCAST_INTERRUPTED(_, unit)\n\tif unit ~= \"player\" then return end\n",
       "sweep not re-read on an interrupted cast",
       expect="core: the sweep stops when the global cooldown is given back (interrupted)",
       script="runscenarios.py")

# core-11: the sweep reading the global cooldown alone, not the player's cast.
mutate("Core.lua",
       "\t\tif type(endMS) == \"number\" and endMS / 1000 > now\n\t\t\tand (not start",
       "\t\tif false\n\t\t\tand (not start",
       "sweep ignores the player's own cast",
       expect="core: the sweep lasts until the player's own cast ends",
       script="runscenarios.py")

# core-11: START not re-reading the sweep. UnitCastingInfo is empty at SENT,
# so this is the one moment a cast-time spell reaches it.
mutate("Core.lua",
       "function addon:UNIT_SPELLCAST_START(_, unit)\n\tif unit ~= \"player\" then return end\n\tSyncSweep()\n",
       "function addon:UNIT_SPELLCAST_START(_, unit)\n\tif unit ~= \"player\" then return end\n",
       "sweep not re-read when a cast starts",
       expect="core: the sweep lasts until the player's own cast ends (the client's figure)",
       script="runscenarios.py")

# core-11: pushback ignored -- the sweep stops at the cast's old end.
mutate("Core.lua",
       "function addon:UNIT_SPELLCAST_DELAYED(_, unit)\n\tif unit ~= \"player\" then return end\n\tSyncSweep()\n",
       "function addon:UNIT_SPELLCAST_DELAYED(_, unit)\n\tif unit ~= \"player\" then return end\n",
       "sweep not re-read on pushback",
       expect="core: the sweep lasts until the player's own cast ends (the client's figure, pushed back)",
       script="runscenarios.py")

# core-10 and core-11: each sweep event dropped from OnEnable's list, so the
# client never delivers it and the handler above never runs.
mutate("Core.lua",
       "\t\t\"UNIT_SPELLCAST_START\",\n",
       "",
       "cast start never registered",
       expect="core: the sweep lasts until the player's own cast ends (the tracked block)",
       script="runscenarios.py")

mutate("Core.lua",
       "\t\t\"UNIT_SPELLCAST_DELAYED\",\n",
       "",
       "pushback never registered",
       expect="core: the sweep lasts until the player's own cast ends (the client's figure, pushed back)",
       script="runscenarios.py")

mutate("Core.lua",
       "\t\t\"UNIT_SPELLCAST_INTERRUPTED\",\n",
       "",
       "interrupted cast never registered",
       expect="core: the sweep stops when the global cooldown is given back (interrupted)",
       script="runscenarios.py")

mutate("Core.lua",
       "\t\t\"SPELL_UPDATE_COOLDOWN\",\n",
       "",
       "cooldown update never registered",
       expect="core: the sweep stops when the global cooldown is given back (cooldown update)",
       script="runscenarios.py")

# core-12: the English an earlier build wrote left in the box.
mutate("Core.lua",
       "\tif translatedSet and translatedSet ~= speech.phrases then speech.phrases = translatedSet end\n",
       "",
       "English phrase box kept on a translated client",
       expect="core: an English phrase box written by an earlier build is translated (roleplay)",
       script="runscenarios.py")

# core-12: the English copy drifting from the set it stands for.
mutate("Core.lua",
       "\t\t\"Cheers, {name}!\",\n",
       "\t\t\"Cheers, {name}.\",\n",
       "English phrase copy drifts from its set",
       expect="core: an English phrase box written by an earlier build is translated (polite)",
       script="runscenarios.py")
