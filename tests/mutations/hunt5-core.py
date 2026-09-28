# Mutations for the Core.lua fixes from the fifth bug hunt. Each one undoes a
# fix and is caught by the scenario in tests/scenarios/hunt5-core.lua it names.
#
# Run by selftest.py with mutate() in scope.

# core-1: the old cap, which a Cyrillic name and surname outgrows.
mutate("Core.lua",
       "\tif #name > 97 then return false end\n",
       "\tif #name > 48 then return false end\n",
       "names capped at 48 bytes again",
       expect="core: a long Cyrillic name and surname is a person",
       script="runscenarios.py")

# core-2: a stamp from the future used as it stands, which adds the skew to
# the window.
mutate("Queue.lua",
       "\t\t\tlocal at = math.min(entry.at, wall)\n",
       "\t\t\tlocal at = entry.at\n",
       "a future-dated favour restored past the window",
       expect="core: a favour stamped by a clock set back lasts no longer than the window",
       script="runscenarios.py")

# core-3: the list sorted by string.lower, which folds A-Z only.
mutate("Queue.lua",
       "\ttable.sort(names, NameBefore)\n",
       "\ttable.sort(names, function(a, b) return a:lower() < b:lower() end)\n",
       "never-offer list sorted by ASCII lower",
       expect="core: the never-offer list is in alphabetical order (Russian)",
       script="runscenarios.py")

# core-4: every favour checked against the whole list again.
mutate("Queue.lua",
       "\t\tif SameName(listed, key) or SameName(listed, ShortName(key)) then\n",
       "\t\tif ListedAs(key) == listed then\n",
       "never-offer walks the list once per favour",
       expect="core: one name put on a long list costs one compare per favour",
       script="runscenarios.py")

# core-4: the realm left on the favour's key, so a name listed as the prompt
# shows it misses a cross-realm debt.
mutate("Queue.lua",
       "\t\tif SameName(listed, key) or SameName(listed, ShortName(key)) then\n",
       "\t\tif SameName(listed, key) then\n",
       "never-offer misses a cross-realm favour",
       expect="core: one name put on a long list costs one compare per favour",
       script="runscenarios.py")
