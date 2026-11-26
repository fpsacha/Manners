# Mutations for the bug hunt of 1129: each undoes one fix and is caught by the
# scenario in tests/scenarios/hunt-1129.lua it names.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

mutate("Modules/MyBuffs/OwnSpells.lua",
       "\t\tif me == false and not (target == ns.plain(UnitName(\"pet\")) and CannotTargetMe(id)) then return end\n",
       "\t\tif me == false then return end\n",
       "hunt-1129: a cast at the pet is somebody else's",
       expect="hunt-1129: a spell that can only land on the pet", script=S)

mutate("Modules/MyBuffs/OwnSpells.lua",
       "\t\t\te.name, e.seen = name, seen or nil\n\t\t\tout[#out + 1] = e\n",
       "\t\t\tout[#out + 1] = { id = e.id, name = name, seen = seen or nil }\n",
       "hunt-1129: the repair makes new entry tables",
       expect="hunt-1129: a list the repair rebuilt", script=S)

mutate("Options/Window/WidgetsTheme.lua",
       "\tlocal p = t.p\n",
       "\tlocal p = PromptSettings()\n",
       "hunt-1129: a look tried goes back on whichever profile is in use",
       expect="hunt-1129: a look tried on hover goes back", script=S)

mutate("ThankPress.lua",
       "\t\tif item.shownAt and not OnPrompt(item) then item.shownAt = nil end\n",
       "",
       "hunt-1129: a thank off the panel keeps its clock",
       expect="hunt-1129: a thank the panel lost to a group entry", script=S)

mutate("Looks/Looks.lua",
       "\t\town = Looks.list[default] and default or nil\n",
       "\t\town = nil\n",
       "hunt-1129: an unknown own look falls back to the style",
       expect="hunt-1129: an unknown own look is the default", script=S)

mutate("Modules/Pets/HunterPet.lua",
       " and not MendOutOfRange() then\n",
       " then\n",
       "hunt-1129: Mend offered to a pet out of range",
       expect="hunt-1129: Mend is not offered to a pet out of its range", script=S)

mutate("Modules/Pets/HunterPet.lua",
       "Known(K.SPELL.revive) and not Known(K.LONE_WOLF) and open(\"revive\")",
       "Known(K.SPELL.revive) and open(\"revive\")",
       "hunt-1129: Revive for a Lone Wolf hunter",
       expect="hunt-1129: Revive is not offered to a Lone Wolf hunter", script=S)

mutate("Modules/Pets/HunterPet.lua",
       "\t\t\tif not wasOut and clock.tamedAt and now - clock.tamedAt <= K.TAME_WINDOW then char.beasts[name] = nil end\n",
       "",
       "hunt-1129: a new pet takes an old one's record",
       expect="hunt-1129: a pet tamed under an abandoned pet's name is new", script=S)

mutate("Modules/Pets/HunterPet.lua",
       "\t\tif type(count) == \"function\" and plain(count(moment.item)) == 0 then moment = nil end\n",
       "",
       "hunt-1129: a share with food that is gone",
       expect="hunt-1129: a share is not offered with food that is gone", script=S)

mutate("Modules/Pets/HunterPet.lua",
       "if clock.morning and Profile() and Profile().enabled == true and On(",
       "if clock.morning and On(",
       "hunt-1129: the inn line with Manners off",
       expect="hunt-1129: the inn line is not said while Manners is off", script=S)

mutate("Modules/Pets/HunterPet.lua",
       "\t\t\tclock.diedInFight = nil\n\t\t\tclock.tamedAt = nil\n",
       "\t\t\tclock.diedInFight = nil\n",
       "hunt-1129: a call keeps the tame of a channel that broke",
       expect="hunt-1129: a tame that failed does not wipe", script=S)

mutate("Modules/MyBuffs/OwnSpells.lua",
       " and not (target == ns.plain(UnitName(\"pet\")) and CannotTargetMe(id)) then return end",
       " and target ~= ns.plain(UnitName(\"pet\")) then return end",
       "hunt-1129: a cast at the pet judges a spell that can land on you",
       expect="hunt-1129: a spell that can land on you waits", script=S)
