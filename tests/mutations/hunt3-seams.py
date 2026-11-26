# Mutations for the third hunt's seams, where two of the day's features meet.
# Each is caught by the scenario in tests/scenarios/hunt3-seams.lua that
# names it.

S = "runscenarios.py"

# The pet's step of the scan no longer asks whether Manners is on or snoozed.
mutate("Modules/MyBuffs/Companion.lua",
       "\tif not db.enabled or ns.SnoozeLeft(now) then return end\n\tlocal family = Family()\n",
       "\tlocal family = Family()\n",
       "hunt3-seams: a pet is brought out while Manners is off or snoozed",
       expect="hunt3-seams: no pet is brought out of the journal while Manners is switched off or snoozed",
       script=S)

# A trade the asker opens goes by the last scan's offer whatever Manners'
# state: off, snoozed and unlocked each on its own.
TRADE = "hunt3-seams: a trade the asker opens gets nothing while Manners is off, snoozed or unlocked"
GATE = "\tif not (db and db.enabled) or ns.SnoozeLeft(now) or (db.prompt and db.prompt.locked == false) then return end\n"
mutate("Modules/Services/Courtesy.lua",
       GATE,
       "\tif not db or ns.SnoozeLeft(now) or (db.prompt and db.prompt.locked == false) then return end\n",
       "hunt3-seams: the water goes into the asker's trade with Manners switched off",
       expect=TRADE, script=S)
mutate("Modules/Services/Courtesy.lua",
       GATE,
       "\tif not (db and db.enabled) or (db.prompt and db.prompt.locked == false) then return end\n",
       "hunt3-seams: the water goes into the asker's trade while snoozed",
       expect=TRADE, script=S)
mutate("Modules/Services/Courtesy.lua",
       GATE,
       "\tif not (db and db.enabled) or ns.SnoozeLeft(now) then return end\n",
       "hunt3-seams: the water goes into the asker's trade with the prompt unlocked",
       expect=TRADE, script=S)

# The short report of /manners debug stops before the scan's own lines again.
DEBUG = "hunt3-seams: /manners debug says the cure lines and the count to a class with no buff for others"
mutate("Commands.lua",
       "\t\t\tif ns.CanCastAnything() then\n\t\t\t\tfor _, line in ipairs(ns.Battle.Lines(GetTime())) do self:Print(line) end\n",
       "\t\t\tif false then\n\t\t\t\tfor _, line in ipairs(ns.Battle.Lines(GetTime())) do self:Print(line) end\n",
       "hunt3-seams: debug's short report ends before the scan's lines",
       expect=DEBUG, script=S)
mutate("Commands.lua",
       "\t\t\t\tfor _, line in ipairs(ns.PvPLines()) do self:Print(\"  \" .. line) end\n"
       "\t\t\t\tfor _, line in ipairs(ns.CureLines and ns.CureLines() or {}) do self:Print(\"  \" .. line) end\n",
       "\t\t\t\tfor _, line in ipairs(ns.PvPLines()) do self:Print(\"  \" .. line) end\n",
       "hunt3-seams: debug's short report leaves the cures out",
       expect=DEBUG, script=S)

# The resting line is counted as said while every message is hidden.
mutate("Hints.lua",
       "\tif db.profile.silentChat == true then return false end\n",
       "",
       "hunt3-seams: the resting line is spent with every message hidden",
       expect="hunt3-seams: the resting line is not spent while Hide all Manners messages is on",
       script=S)

# A resurrection and a courtesy are told the nameplates cost them a line.
PLATES = "hunt3-seams: a resurrection or a courtesy is not said to have lost a line to the nameplates"
mutate("Speech.lua",
       "\t\tif entry.res or entry.courtesy then return end\n",
       "\t\tif entry.courtesy then return end\n",
       "hunt3-seams: a resurrection is told the nameplates cost it a line",
       expect=PLATES, script=S)
mutate("Speech.lua",
       "\t\tif entry.res or entry.courtesy then return end\n",
       "\t\tif entry.res then return end\n",
       "hunt3-seams: a courtesy is told the nameplates cost it a line",
       expect=PLATES, script=S)

# A resurrection's tooltip says its reading was set by the options.
mutate("Prompt/Button.lua",
       "\telseif not entry.checked and not entry.res then\n",
       "\telseif not entry.checked then\n",
       "hunt3-seams: a resurrection's tooltip says the options turned its reading off",
       expect="hunt3-seams: a resurrection's tooltip says nothing about a reading set by the options",
       script=S)

# A bar press on a courtesy's trade says nothing, and the slot shows the
# conjure spell.
BAR = "hunt3-seams: a bar press on a courtesy's trade says to press the prompt, and the slot shows no spell"
mutate("Prompt/Press.lua",
       "\tif S.current and S.current.courtesy and S.current.courtesy.stage == \"trade\" then\n\t\tif db and db.verbose then\n",
       "\tif S.current and S.current.courtesy and S.current.courtesy.stage == \"trade\" then\n\t\tif false then\n",
       "hunt3-seams: a bar press on a trade says nothing",
       expect=BAR, script=S)
mutate("Prompt/Macro.lua",
       "ns.SyncMacroSlot(not (entry.courtesy and entry.courtesy.stage == \"trade\") and entry or nil) end\n",
       "ns.SyncMacroSlot(entry) end\n",
       "hunt3-seams: the bar slot shows the conjure spell for a trade",
       expect=BAR, script=S)
