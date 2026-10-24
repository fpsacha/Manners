# Mutations for the hunt 34 fixes (the faults hunt 33 proved), each undoing one
# fix and caught by the scenario it names. Run by selftest.py with mutate() in
# scope.

# ------------------------------------------------------------------ 1
# The never-offer list: an entry filed from a name the game gave means that
# one person; only a typed name also answers to the same person's other realm.

# A filed entry matched through the realm taken off again.
mutate("Queue.lua",
       "\t\t\tif flag == true and not typed and SameName(key, short) then typed = key end\n",
       "\t\t\tif not typed and SameName(key, short) then typed = key end\n",
       "never list: a filed Anna matches Anna-Aim",
       expect="hunt33-never: listing a same-realm Anna does not list a namesake",
       script="runscenarios.py")

# Everything filed as if typed.
mutate("Queue.lua",
       "\tnever[name] = typed and true or NEVER_FILED\n",
       "\tnever[name] = true\n",
       "never list: every name filed as typed",
       expect="hunt33-never: listing a same-realm Anna does not list a namesake",
       script="runscenarios.py")

# The debt walk matching through the realm whatever the entry is.
mutate("Queue.lua",
       "\tlocal byRealm = NeverSet()[listed] == true\n",
       "\tlocal byRealm = true\n",
       "never list: a filed Anna lets go Anna-Aim's favour",
       expect="hunt33-never: listing a same-realm Anna keeps the favour",
       script="runscenarios.py")

# A typed name no longer answers to the other realm.
mutate("Queue.lua",
       "\t\t\tif flag == true and not typed and SameName(key, short) then typed = key end\n",
       "\t\t\tif false and not typed and SameName(key, short) then typed = key end\n",
       "never list: a typed Anna no longer lists Anna-Aim",
       expect="hunt34-never: a typed Anna still answers to Anna-Aim",
       script="runscenarios.py")

# A favour filed under exactly the typed name does not take the realm rule
# off the table.
mutate("Queue.lua",
       "\t\t\tbyRealm = false\n\t\t\towed[key] = nil\n\t\t\tforgiven = true\n",
       "\t\t\towed[key] = nil\n\t\t\tforgiven = true\n",
       "never list: a typed Anna lets go both Annas' favours",
       expect="hunt34-never: a typed Anna still answers to Anna-Aim, an exact Anna first",
       script="runscenarios.py")

# An exact entry in other letters no longer found, so the realm-less one answers.
mutate("Queue.lua",
       "\t\t\tif SameName(key, name) then found = key break end\n",
       "\t\t\tif key == name then found = key break end\n",
       "never list: the realm-less entry wins over the exact one",
       expect="hunt34-never: the exact entry is the one named",
       script="runscenarios.py")

# The repair at login dropping a filed entry.
mutate("Core.lua",
       "or (flag ~= true and flag ~= \"filed\") then\n",
       "or flag ~= true then\n",
       "never list: the clamp drops filed entries",
       expect="hunt34-never: the clamp keeps typed and filed entries",
       script="runscenarios.py")

# The chat command and the options box handing over a typed name as a filed one.
mutate("Commands.lua",
       "\t\t\tns.PutOnNeverList(rest, true)\n",
       "\t\t\tns.PutOnNeverList(rest)\n",
       "never list: /manners never files a typed name as filed",
       expect="hunt34-never: a name typed in chat or the options box",
       script="runscenarios.py")
mutate("Options/Who.lua",
       "set = function(_, value) ns.PutOnNeverList(value, true) end,",
       "set = function(_, value) ns.PutOnNeverList(value) end,",
       "never list: the options box files a typed name as filed",
       expect="hunt34-never: a name typed in chat or the options box",
       script="runscenarios.py")

# The prompt's wrapper dropping the typed flag on its way through.
mutate("Prompt/Refresh.lua",
       "\t\t\tlocal listed = putOnNeverList(name, typed)\n",
       "\t\t\tlocal listed = putOnNeverList(name)\n",
       "never list: the repaint wrapper drops the typed flag",
       expect="hunt34-never: a name typed in chat or the options box",
       script="runscenarios.py")

# Filing a namesake refused as already listed.
mutate("Queue.lua",
       "\t\t\tif flag == true and not typed and SameName(key, short) then typed = key end\n",
       "\t\t\tif not typed and SameName(key, short) then typed = key end\n",
       "never list: Anna-Aim refused as already listed after Anna",
       expect="hunt34-never: a same-realm Anna on the list does not make Anna-Aim",
       script="runscenarios.py")
