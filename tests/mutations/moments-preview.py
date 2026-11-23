# Mutations for "Show where the buttons for the moment sit":
# tests/scenarios/moments-preview.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts one guard back to
# its absence and names the scenario that objects.

S = "runscenarios.py"
M = "Prompt/Moments.lua"

mutate(M,
       '\t\t\tDisarm(slot)\n\t\t\tslot.cover:Show()\n',
       '\t\t\tslot.cover:Show()\n',
       "moments-preview: the preview leaves the macros on the buttons",
       expect="moments-preview: a click and a key press cast nothing from a preview", script=S)

mutate(M,
       '\t\t\tDisarm(slot)\n\t\t\tslot.cover:Show()\n',
       '\t\t\tDisarm(slot)\n',
       "moments-preview: the preview puts no cover over the cards",
       expect="moments-preview: with no key bound a click on a preview card is swallowed too", script=S)

mutate(M,
       '\tif InCombatLockdown() or Sense.fighting then\n\t\tSay(L["|cffff8080not during a fight|r -- the preview can be shown once it ends."])\n\t\treturn false\n\tend\n',
       '',
       "moments-preview: the preview starts in a fight",
       expect="moments-preview: refused in a fight", script=S)

mutate(M,
       '\tif previewing then Moments:Refresh() end\n',
       '',
       "moments-preview: a pull leaves the preview's disarmed buttons",
       expect="moments-preview: a pull in the middle of a preview", script=S)

mutate(M,
       '\t\tif serial ~= previewSerial or not previewing then return end\n',
       '',
       "moments-preview: a stale timer of a preview acts after it ended",
       expect="moments-preview: a pull in the middle of a preview", script=S)

mutate("Options/Launcher.lua",
       '\tif ns.Moments and ns.Moments.AnyArmed() then\n\t\tlocal where',
       '\tif false then\n\t\tlocal where',
       "moments-preview: the launcher has no entry for the preview",
       expect="moments-preview: the launcher's menu has the entry", script=S)

mutate("Options/Launcher.lua",
       '\t\tif fight then HeldForFight(where) end\n',
       '',
       "moments-preview: the launcher's entry is not held for the fight",
       expect="moments-preview: the launcher's menu has the entry", script=S)

mutate(M,
       '\tif #fightCards + #calmCards == 0 then\n',
       '\tif false then\n',
       "moments-preview: nothing armed starts a preview of nothing",
       expect="moments-preview: nothing armed says so in one line", script=S)
