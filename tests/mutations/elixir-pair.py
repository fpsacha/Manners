# Mutations for keeping two elixirs up (tests/scenarios/elixir-pair.lua):
# Burning Crusade's and Mists' elixirs a family a slot, read from each row's
# fourth value (Buffs.lua CONSUME), Mists' scrolls in their own slot alone, the
# one switch carried into the two (Core.lua ns.SplitElixirs, the stamp in a
# settings string), and Classic Era's and Forever's elixirs to keep up
# (ns.KeepTicks, ReadConsumable, KeepAnswer, the clash memory, the box on Who
# to buff and its ticks in a settings string). Each is caught by the scenario
# of the name it expects.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"
P = "elixir-pair: "

# --- two slots ---

mutate("Buffs.lua",
       "\t\t\tif row[4] == \"guardian\" then guard[#guard + 1] = row else battle[#battle + 1] = row end\n",
       "\t\t\tbattle[#battle + 1] = row\n",
       "elixir-pair: the slot column ignored",
       expect=P + "tbc: a battle and a guardian elixir are each reminded of", script=S)

mutate("Buffs.lua",
       "\t\t\t\t\tlocal mate = bySlot[slot]\n",
       "\t\t\t\t\tlocal mate = elixir\n",
       "elixir-pair: every Mists scroll in the battle slot",
       expect=P + "mists: a scroll takes its own slot alone", script=S)

mutate("Options/Who.lua",
       "\telseif family.slot then\n",
       "\telseif false then\n",
       "elixir-pair: the switch does not say its slot",
       expect=P + "tbc: a battle and a guardian elixir are each reminded of", script=S)

mutate("Options/Who.lua",
       "\t\tif family.slotScrolls then\n",
       "\t\tif false then\n",
       "elixir-pair: Mists' switch silent about scrolls",
       expect=P + "mists: a scroll takes its own slot alone", script=S)

# --- carried over ---

mutate("Core.lua",
       "\tif own.elixirsSplit ~= true then\n",
       "\tif false then\n",
       "elixir-pair: the elixir switch not carried into the two",
       expect=P + "tbc: the one switch carries over into the two", script=S)

mutate("Core.lua",
       "\tif last and last.family == guardian then\n",
       "\tif false then\n",
       "elixir-pair: the memory of a guardian elixir left on Battle Elixir",
       expect=P + "mists: the one switch carries over into the two", script=S)

mutate("Commands.lua",
       "\t\tfields[#fields + 1] = { name = \"ownBuffs.elixirsSplit\", kind = \"boolean\",\n",
       "\t\tlocal _ = { name = \"ownBuffs.elixirsSplit\", kind = \"boolean\",\n",
       "elixir-pair: a settings string without the stamp",
       expect="a string made before the split left Guardian Elixir", script=S)

# --- keep up (Classic Era, Forever) ---

mutate("Core.lua",
       "\t\tif ticks then return KeepAnswer(ticks) end\n",
       "",
       "elixir-pair: the ticks ignored in Automatic",
       expect=P + "camelot: the elixirs ticked are each kept up", script=S)

mutate("Core.lua",
       "\t\tif ticks then\n\t\t\tlocal ok, up, left, a, b = pcall(ScanKept, byId, ticks, now)\n",
       "\t\tif false then\n\t\t\tlocal ok, up, left, a, b = pcall(ScanKept, byId, ticks, now)\n",
       "elixir-pair: any elixir on reads as every ticked one up",
       expect=P + "vanilla: the elixirs ticked are each kept up", script=S)

mutate("Core.lua",
       "\t\t\t\t\tif Known(spell) then\n\t\t\t\t\t\tcounted = true\n\t\t\t\t\t\tall = false\n",
       "\t\t\t\t\tdo\n\t\t\t\t\t\tcounted = true\n\t\t\t\t\t\tall = false\n",
       "elixir-pair: a ticked elixir not in the bags holds the family down",
       expect=P + "camelot: the elixirs ticked are each kept up", script=S)

mutate("Core.lua",
       "\t\t\tif a and b then ns.Guard(\"elixir clash\", ns.NoteElixirClash, a, b) end\n",
       "",
       "elixir-pair: two that do not stack never noted",
       expect=P + "camelot: two that do not stack are kept as one", script=S)

mutate("Core.lua",
       "\t\t\t\t\tif was and (type(was) ~= \"number\" or was - now > CLASH_SPARE) then\n",
       "\t\t\t\t\tif was then\n",
       "elixir-pair: an elixir that ran out taken for a clash",
       expect=P + "vanilla: two that do not stack are kept as one", script=S)

mutate("Core.lua",
       "\t\t\tif not LeftOut(spell) and not (type(lifts) == \"number\" and lifts > now) then\n",
       "\t\t\tif not LeftOut(spell) then\n",
       "elixir-pair: one the game turned away asked for again",
       expect=P + "camelot: one the game turns away is passed over", script=S)

mutate("Core.lua",
       "\t\tif value ~= true or not (spell and spell.family and spell.family.keep) then own.elixirKeep[key] = nil end\n",
       "\t\tif value ~= true then own.elixirKeep[key] = nil end\n",
       "elixir-pair: a tick of something else kept",
       expect=P + "vanilla: one family, nothing carried, the ticks repaired and shared", script=S)

mutate("Commands.lua",
       "\t\t\t\t\t\t\tor name == \"ownBuffs.elixirKeep\"\n",
       "",
       "elixir-pair: the ticks do not travel",
       expect=P + "vanilla: one family, nothing carried, the ticks repaired and shared", script=S)

mutate("Options/Who.lua",
       "\t\t\treturn not family or ns.OwnPick(family) ~= \"auto\" or next(KeepChoices()) == nil\n",
       "\t\t\treturn not family or next(KeepChoices()) == nil\n",
       "elixir-pair: the box shown with the elixir switch off",
       expect=P + "camelot: the elixirs ticked are each kept up", script=S)

# --- the clash memory kept honest (review after the first build) ---

mutate("Core.lua",
       "\t\tif not keptRead.walked then\n",
       "\t\tif false then\n",
       "elixir-pair: a gap in the readings taken for a clash",
       expect=P + "vanilla: a gap in the readings is no clash", script=S)

mutate("Options/Who.lua",
       "\t\t\tns.ForgetElixirClash(key)\n",
       "",
       "elixir-pair: a pair kept as one never parted",
       expect=P + "camelot: a tick parts a pair kept as one", script=S)

mutate("Core.lua",
       "\t\t\t\tkeptLeft[spell.key] = nil\n\t\t\telse\n",
       "\t\t\telse\n",
       "elixir-pair: a refused reading taken for a clash",
       expect=P + "camelot: a refused reading is no clash", script=S)

mutate("Core.lua",
       "\t\t\t\tfor key in pairs(keptLeft) do keptLeft[key] = nil end\n\t\t\t\treturn nil\n",
       "\t\t\t\treturn nil\n",
       "elixir-pair: a read that threw taken for a clash",
       expect=P + "camelot: a refused reading is no clash", script=S)
