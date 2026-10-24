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

# ------------------------------------------------------------------ 2
# WoW Forever's Battle Shout reaches the caster's whole raid (build 70450 on),
# so its set does not hold a shout to the caster's own subgroup.
mutate("Buffs.lua",
       "groupIsRaid = true,\n\tpartyIsSubgroup = false }, { __index = VANILLA_SET })",
       "groupIsRaid = true }, { __index = VANILLA_SET })",
       "forever: Battle Shout held to the warrior's own subgroup",
       expect="hunt33-data: camelot: a raid member in another subgroup is reached by Battle Shout",
       script="runscenarios.py")

# ------------------------------------------------------------------ 5
# A box filled by a client in another language follows the client: each of its
# lines is read as this client reads it (Phrases.lua, RP.OTHER_HASH), and the
# box counts as untouched when that is a set or the examples.
mutate("Speech.lua",
       "\t\tif now and now ~= text then\n",
       "\t\tif false then\n",
       "phrase set: another language's set never recognised",
       expect="hunt34-phrases: an unedited set from another language follows a enUS client",
       script="runscenarios.py")
mutate("Speech.lua",
       "\t\t\t\tif set and set.lines and Holds(now, set.lines) then return key end\n",
       "\t\t\t\tif set and set.lines then return key end\n",
       "phrase set: any box with a known line is a set",
       expect="hunt34-phrases: a player's own box in another language's words is left alone",
       script="runscenarios.py")
mutate("Phrases.lua",
       "\t\ttext = RP.InThisLanguage(text)\n",
       "",
       "In character: another language's examples never read",
       expect="hunt34-phrases: In character keeps speaking after the client's language changes",
       script="runscenarios.py")
mutate("Phrases.lua",
       "\t\t\tif n then return translated[keys[n]] end\n",
       "\t\t\tif n then return keys[n] end\n",
       "phrase set: another language's line read as English",
       expect="hunt34-phrases: an unedited set from another language follows a zhCN client",
       script="runscenarios.py")
mutate("Phrases.lua",
       "h = (h * 33 + line:byte(i)) % 4294967291 end\n",
       "h = (h * 33 + line:byte(i)) % 4294967279 end\n",
       "phrase set: the line hash is not the one the table was written with",
       expect="hunt34-phrases: an unedited set from another language follows a enUS client",
       script="runscenarios.py")

# ------------------------------------------------------------------ 4
# The prompt's font default is the library's own for the client's language.
mutate("Core.lua",
       "\t\t\t\treturn type(media) == \"string\" and media ~= \"\" and media or \"Friz Quadrata TT\"\n",
       "\t\t\t\treturn \"Friz Quadrata TT\"\n",
       "font default: Friz Quadrata TT on every client",
       expect="hunt33-settings: koKR: a fresh profile's font is not 'not loaded'",
       script="runscenarios.py")
mutate("Core.lua",
       "\t\t\t\treturn type(media) == \"string\" and media ~= \"\" and media or \"Friz Quadrata TT\"\n",
       "\t\t\t\treturn type(media) == \"string\" and media ~= \"\" and media or \"\"\n",
       "font default: no fallback when the library names none",
       expect="hunt34-font: a library with no default of its own leaves Friz Quadrata TT",
       script="runscenarios.py")
mutate("Core.lua",
       "\t\t\t\tlocal media = lsm and type(lsm.DefaultMedia) == \"table\" and lsm.DefaultMedia.font\n",
       "\t\t\t\tlocal media = lsm and type(lsm.DefaultMedia) == \"table\" and \"Arial Narrow\"\n",
       "font default: a Latin client given another font",
       expect="hunt34-font: a Latin client keeps Friz Quadrata TT as the default",
       script="runscenarios.py")

# ------------------------------------------------------------------ 3
# The buff order a player set travels in a settings string: CLASS=key:key,
# per class, validated like a saved order, reset by an import that has none.
mutate("Commands.lua",
       "\t\t\t\t\t\telseif name == \"buff.order\" then\n",
       "\t\t\t\t\t\telseif name == \"buff.orderx\" then\n",
       "settings string: the buff order has no kind of its own",
       expect="hunt34-order: the order of every class travels in a settings string",
       script="runscenarios.py")
mutate("Commands.lua",
       "\t\t\t\t\tif #list > 0 then classes[#classes + 1] = class .. \"=\" .. table.concat(list, \":\") end\n",
       "\t\t\t\t\tif false then classes[#classes + 1] = class .. \"=\" .. table.concat(list, \":\") end\n",
       "settings string: the buff order is not written",
       expect="hunt34-order: the order of every class travels in a settings string",
       script="runscenarios.py")
mutate("Commands.lua",
       "\t\t\t\tout[class] = ns.RepairedBuffOrder(class, keys, false) or false\n",
       "\t\t\t\tout[class] = keys\n",
       "settings string: a buff order read as it stands",
       expect="hunt34-order: a damaged order is refused whole and an unknown buff is dropped",
       script="runscenarios.py")
mutate("Commands.lua",
       "\t\t\t\tif not class or out[class] ~= nil then return nil end\n",
       "\t\t\t\tif not class then return nil end\n",
       "settings string: a class twice in a buff order",
       expect="hunt34-order: a damaged order is refused whole and an unknown buff is dropped",
       script="runscenarios.py")
mutate("Commands.lua",
       "\t\t\t\t\tif not key:match(\"^[%w_]+$\") or #keys >= 64 then return nil end\n",
       "\t\t\t\t\tif #keys >= 64 then return nil end\n",
       "settings string: an empty key in a buff order",
       expect="hunt34-order: a damaged order is refused whole and an unknown buff is dropped",
       script="runscenarios.py")
mutate("Commands.lua",
       "\t\t\tif value == nil then value = CopyValue(field.default) end\n",
       "\t\t\tif value == nil then value = field.kind == \"order\" and holder[field.key] or CopyValue(field.default) end\n",
       "settings string: an import with no buff order keeps the player's",
       expect="hunt34-order: an import with no order puts Automatic back",
       script="runscenarios.py")
mutate("Commands.lua",
       "\t\t\t\tif type(class) == \"string\" and class:match(\"^%u+$\") and type(keys) == \"table\" then\n",
       "\t\t\t\tif type(class) == \"string\" and class:match(\"^%l+$\") and type(keys) == \"table\" then\n",
       "settings string: no class is a buff order's",
       expect="hunt34-order: the order of every class travels in a settings string",
       script="runscenarios.py")
