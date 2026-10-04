# Mutations for first use: the two questions a new profile is asked on Start
# here, and the friendly nameplate hint on What I say. Each is caught by the
# scenario in tests/scenarios/quick-setup.lua that names it.

# A new profile taken for one set up long ago: nobody is ever asked.
mutate("Core.lua",
       "\t\tprofile.firstRun = p.anchorCarried == true and \"existing\" or \"pending\"\n",
       "\t\tprofile.firstRun = \"existing\"\n",
       "new profile never asked",
       expect="quick-setup: a new profile is asked two questions on Start here",
       script="runscenarios.py")

# Every profile taken for a new one: an upgrade asks everybody again.
mutate("Core.lua",
       "\t\tprofile.firstRun = p.anchorCarried == true and \"existing\" or \"pending\"\n",
       "\t\tprofile.firstRun = \"pending\"\n",
       "existing profile asked",
       expect="quick-setup: an existing profile is never asked (saved by 1.6.5)",
       script="runscenarios.py")

# A value no version writes kept as it is.
mutate("Core.lua",
       "\toneOf(profile, \"firstRun\", { pending = true, answered = true, skipped = true, existing = true }, \"existing\")\n",
       "",
       "damaged firstRun kept",
       expect="quick-setup: an existing profile is never asked (a damaged value)",
       script="runscenarios.py")

# The window opens on the last page, where the questions are not.
mutate("Options/Window/Window.lua",
       "\tif not pageId and ns.QuickSetup and ns.QuickSetup.Asking() then pageId = \"general\" end\n",
       "",
       "questions not opened on",
       expect="quick-setup: a new profile is asked two questions on Start here",
       script="runscenarios.py")

# Whispering offered as a first answer, and Custom with it.
mutate("Options/Start.lua",
       "\t\tif key ~= \"custom\" and (list ~= Quick.VOICE or Quick.FIRST_VOICE[key]) then out[key] = name end\n",
       "\t\tout[key] = name\n",
       "every voice choice offered",
       expect="quick-setup: a new profile is asked two questions on Start here",
       script="runscenarios.py")

# Done forgets who to buff.
mutate("Options/Start.lua",
       "\t\tif who then Quick.Apply(Quick.WHO, who) end\n",
       "",
       "Done skips the who answer",
       expect="quick-setup: Done sets what the presets set",
       script="runscenarios.py")

# Done applies the voice preset by its own route, without its lines.
mutate("Options/Start.lua",
       "\t\tif voice then Quick.Apply(Quick.VOICE, voice) end\n",
       "\t\tif voice then for path, value in pairs(Quick.Find(Quick.VOICE, voice).set) do Quick.Set(path, value) end end\n",
       "Done skips the voice preset's lines",
       expect="quick-setup: Done sets what the presets set",
       script="runscenarios.py")

# Done never ends the first run: asked on every open.
mutate("Options/Start.lua",
       "\tns.db.profile.firstRun = answered and \"answered\" or \"skipped\"\n",
       "",
       "first run never ends",
       expect="quick-setup: Skip changes nothing and is never asked again",
       script="runscenarios.py")

# Skip applies the picks as Done does.
mutate("Options/Start.lua",
       "\tif answered then\n\t\tif who then",
       "\tif true then\n\t\tif who then",
       "Skip applies the picks",
       expect="quick-setup: Skip changes nothing and is never asked again",
       script="runscenarios.py")

# Asked of a class with nothing to give.
mutate("Options/Start.lua",
       "\treturn Quick.Pending() and HasClassBuffs() == true\n",
       "\treturn Quick.Pending()\n",
       "rogue asked who to buff",
       expect="quick-setup: a class with nothing to give is not asked",
       script="runscenarios.py")

# The note shown to somebody who says nothing.
mutate("Options/Say.lua",
       "\t\t\t\thidden = function() return speechOff() or not ns.FriendlyPlatesOff() end,\n\t\t\t\tname = \"|cff888888\"",
       "\t\t\t\thidden = function() return not ns.FriendlyPlatesOff() end,\n\t\t\t\tname = \"|cff888888\"",
       "nameplate note while silent",
       expect="quick-setup: the nameplate note shows only while speaking with them off (silent, nameplates off)",
       script="runscenarios.py")

# A client that will not say read as nameplates off.
mutate("Speech.lua",
       "\t\treturn value == \"0\" or value == 0 or value == false\n",
       "\t\treturn value ~= \"1\"\n",
       "unknown nameplates read as off",
       expect="quick-setup: the nameplate note shows only while speaking with them off (speaking, the client will not say)",
       script="runscenarios.py")

# The button live in a fight.
mutate("Options/Say.lua",
       "\t\t\t\t-- The client refuses the setting in a fight.\n\t\t\t\tdisabled = function() return InCombatLockdown() end,\n",
       "",
       "nameplate button live in combat",
       expect="quick-setup: Show friendly nameplates sets the setting only out of combat",
       script="runscenarios.py")

# The setting written in a fight.
mutate("Speech.lua",
       "\t\tif InCombatLockdown() or not ns.FriendlyPlatesOff() then return false end\n",
       "\t\tif not ns.FriendlyPlatesOff() then return false end\n",
       "nameplates set in combat",
       expect="quick-setup: Show friendly nameplates sets the setting only out of combat",
       script="runscenarios.py")

# The chat line on every hold.
mutate("Speech.lua",
       "\t\tsaid = true\n",
       "",
       "nameplate line every press",
       expect="quick-setup: a line held back for want of nameplates is said once a session (nameplates off)",
       script="runscenarios.py")

# The hold says nothing.
mutate("Prompt/Press.lua",
       "\t\tns.NoteTokenlessHold(entry)\n",
       "",
       "nameplate line never said",
       expect="quick-setup: a line held back for want of nameplates is said once a session (nameplates off)",
       script="runscenarios.py")

# Said with the nameplates on, where they are not why.
mutate("Speech.lua",
       "\t\tif not ns.FriendlyPlatesOff() then return end\n\t\tsaid = true\n",
       "\t\tsaid = true\n",
       "nameplate line with them on",
       expect="quick-setup: a line held back for want of nameplates is said once a session (nameplates on)",
       script="runscenarios.py")
