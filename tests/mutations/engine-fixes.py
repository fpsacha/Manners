# Mutations for tests/scenarios/engine-fixes.lua (bug hunt 37, engine): each puts
# back one fault the round fixed, and the scenario of that name has to catch it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"
P = "engine-fix: "

# The fuzzer's /ignore list asks only tokens, as it did, and so answers "not
# ignored" for a debt whose person has no token.
mutate("tests/fuzz_world.lua",
       "\t\t\tif not p and type(unit) == \"string\" then\n",
       "\t\t\tif false then\n",
       "engine-fix: the fuzzer's ignore list reads tokens only",
       expect=P + "the fuzzer's ignore list answers a name as the game does", script=S)

# One record per person again: a blessing pressed on whoever wears your Oath of
# Light wipes the Oath's.
mutate("Queue.lua",
       "\t\tentry[buffKey] = now\n",
       "\t\twipe(entry)\n\t\tentry[buffKey] = now\n",
       "engine-fix: one noted cast per person",
       expect=P + "a blessing on whoever wears your Oath of Light does not move the Oath", script=S)

# The favour asked as if nobody tanked.
mutate("Favours.lua",
       "\t\tif not ns.CouldOffer(hasMana, true, nil, seen.tank, seen.class) then\n",
       "\t\tif not ns.CouldOffer(hasMana, true) then\n",
       "engine-fix: a favour judged with no tank",
       expect=P + "a favour to one whose only buff is for one target is not let go", script=S)

# "Buff pls" served once names every buff, one for one target included.
mutate("Requests.lua",
       "\t\t\t\t\t\tif not buff.oneTarget then request.keys[buff.key] = true end\n",
       "\t\t\t\t\t\trequest.keys[buff.key] = true\n",
       "engine-fix: buff pls names Beacon of Light",
       expect=P + "buff pls served once is no request for Beacon of Light", script=S)

# Symbiosis's partner aura not known.
mutate("Buffs.lua",
       "\t\tnotSelf = true, alone = true,\n\t\tgroup = { 110478, 110479, 110482, 110483, 110484, 110485, 110486, 110488, 110490, 110491 } }\n",
       "\t\tnotSelf = true, alone = true }\n",
       "engine-fix: Symbiosis partner's aura unknown",
       expect=P + "Symbiosis read where the game puts it", script=S)

# The druid's own aura read as the partner's.
mutate("Queue.lua",
       "\t\t\tif guid and not (buff.notSelf and (i == 0 or guid == myGuid)) then\n",
       "\t\t\tif guid then\n",
       "engine-fix: Symbiosis read on the druid",
       expect=P + "Symbiosis read where the game puts it", script=S)

# The greeting for one-target buffs only is the group's.
mutate("Commands.lua",
       "\telseif ns.OnlyOneTarget() then\n",
       "\telseif false then\n",
       "engine-fix: the greeting promises it to the group",
       expect=P + "the greeting does not promise Earth Shield to anybody in the group", script=S)

# A woman's thanks for a gift left in the pools' floor of three.
mutate("Phrases.lua",
       "LeaveOut(pool, leaving, GIFT_POOL[pool] and 0 or nil)",
       "LeaveOut(pool, leaving)",
       "engine-fix: a gift's thanks kept at the floor",
       expect=P + "a woman thanks for a one-target buff in her own voice", script=S)

mutate("Phrases.lua",
       "\t\t-- RP.GIFT's Oath of Light: \"degno\".\n\t\t[\"An oath, sworn to me? Thank you, {name}. I'll try to be worth keeping.\"] = true,\n",
       "",
       "engine-fix: Italian Oath of Light not listed",
       expect=P + "a woman thanks for a one-target buff in her own voice", script=S)

mutate("Phrases.lua",
       "\t\t[\"Thank you, {name}. With the earth at my back, I'll stand anything.\"] = true,\n",
       "",
       "engine-fix: Portuguese Earth Shield line not listed",
       expect=P + "a woman thanks for a one-target buff in her own voice", script=S)
