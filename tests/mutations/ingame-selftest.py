# Mutations for tests/scenarios/ingame-selftest.lua: /manners selftest
# (Selftest.lua), the checks the author runs in the real client.
#
# Run by tests/selftest.py with mutate() in scope.

S = "runscenarios.py"

# One check that throws takes the rest with it: the pcall around each is the
# whole of "one failure never stops the rest".
mutate("Selftest.lua",
       "\t\tlocal ok, err = pcall(check.run, add)\n",
       "\t\tlocal ok, err = true, check.run(add)\n",
       "selftest: a throwing check stops the run",
       expect="selftest: a failure is that check's FAIL and the rest run",
       script=S)

# A client call that throws reported as a pass.
mutate("Selftest.lua",
       "\t\t\tadd(FAIL, \"threw: \" .. tostring(out[2]))\n",
       "\t\t\tadd(PASS, \"threw: \" .. tostring(out[2]))\n",
       "selftest: a throwing API reads as a pass",
       expect="selftest: a failure is that check's FAIL and the rest run",
       script=S)

# The 1.6.3 bug's own check: C_Item lists an imbue, Manners reads nothing on,
# and the report says nothing of it.
mutate("Selftest.lua",
       "\telseif listedOn and up == false then\n",
       "\telseif false then\n",
       "selftest: imbue listed, read as nothing, passes",
       expect="selftest: the main hand and the familiar are compared",
       script=S)

# The familiar on you by id, read by Manners as not up, passes.
mutate("Selftest.lua",
       "\tif direct and up == false then\n",
       "\tif false then\n",
       "selftest: familiar up, read as not up, passes",
       expect="selftest: the main hand and the familiar are compared",
       script=S)

# The memory of the buff last up, written by the readings, left behind.
mutate("Selftest.lua",
       "\t\telse\n\t\t\tchar.ownLast = had\n\t\tend\n",
       "\t\tend\n",
       "selftest: the readings' memory is kept",
       expect="selftest: the command touches nothing",
       script=S)

# Run in a fight.
mutate("Selftest.lua",
       "\tif InCombatLockdown() then\n\t\taddon:Print(L[\"the self-test runs out of combat",
       "\tif false then\n\t\taddon:Print(L[\"the self-test runs out of combat",
       "selftest: runs in a fight",
       expect="selftest: the command touches nothing",
       script=S)

# The report's window starts the prompt's preview on a first opening, which
# arms the button.
mutate("Options/Window/Window.lua",
       "\tif not quiet and not s.previewShown and",
       "\tif not s.previewShown and",
       "selftest: the report starts the preview",
       expect="selftest: the command touches nothing",
       script=S)

# The report never reaches its box.
mutate("Options/Register.lua",
       "\tns.OpenOptions(\"diagnostics\", true)\n\tPage.selftestText = text\n",
       "\tns.OpenOptions(\"diagnostics\", true)\n",
       "selftest: no report in the box",
       expect="selftest: the command touches nothing",
       script=S)

# /manners check, the alias, falls through to the help.
mutate("Commands.lua",
       "\telseif input == \"selftest\" or input == \"check\" then\n",
       "\telseif input == \"selftest\" then\n",
       "selftest: /manners check is not the self-test",
       expect="selftest: the command touches nothing",
       script=S)

# A macro the client would cut short reads as fine.
mutate("Selftest.lua",
       "\tif #text > (ns.MACRO_LIMIT or 255) then\n",
       "\tif false then\n",
       "selftest: an over-long macro passes",
       expect="selftest: the button, names, the line rule, repairs and errors",
       script=S)

# The line rule out of reach of the self-test.
mutate("Prompt/Press.lua",
       "ns.HoldLine = HoldLine\n",
       "ns.HoldLine = nil\n",
       "selftest: no line rule to ask",
       expect="selftest: the button, names, the line rule, repairs and errors",
       script=S)

# A repaired setting never written to the log.
mutate("Core.lua",
       "\t\tif not allowed[tbl[key]] then\n\t\t\tfixed(key, tbl[key])\n",
       "\t\tif not allowed[tbl[key]] then\n",
       "selftest: repairs go unlogged",
       expect="selftest: the button, names, the line rule, repairs and errors",
       script=S)
