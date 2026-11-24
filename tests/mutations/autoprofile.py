# Profiles from the page and switching by where you are (AutoProfile.lua, its
# call in Options/Profiles.lua and its rows in Options/Window/Layout.lua). Each
# fault is caught by the scenario in tests/scenarios/autoprofile.lua that names
# it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"
A = "AutoProfile.lua"

OFF = "autoprofile: off by default, and then an arrival switches nothing"
EACH = "autoprofile: each situation switches to the profile picked for it"
UNNAMED = "autoprofile: a place the game will not name switches nothing"
SETTLE = "autoprofile: a loading screen's events are one arrival, read once they have settled"
FIGHT = "autoprofile: a switch waits out a fight"
HELD = "autoprofile: a press waiting to be settled or a box being typed in holds the switch back"
LEAVE = "autoprofile: Do not switch leaves the profile as it is, and nothing is put back"
DELETED = "autoprofile: a deleted profile's rule goes back to Do not switch"
HAND = "autoprofile: a profile picked by hand holds until the next arrival"
QUIET = "autoprofile: an automatic switch says one line and turns nothing on or off"
LINE = "autoprofile: the chat line has its own tick, and keeps to Say nothing at all in chat"
MAKE = "autoprofile: the page makes a profile from the defaults or from the settings in use"
ASKS = "autoprofile: the page never deletes the profile in use, and asks before deleting"
RENAME = "autoprofile: renaming a profile keeps its settings, its characters and the rules that name it"
REPAIR = "autoprofile: the rules are the character's own, repaired as they are read"
WINDOW = "autoprofile: the window draws the section, the rows gone while the switch is off"

# --- the master switch ---

# The switch never asked: rules are followed with it off.
mutate(A,
       "\tif not (st and st.enabled) then\n\t\tauto.look, auto.pending = false, nil\n",
       "\tif not st then\n\t\tauto.look, auto.pending = false, nil\n",
       "autoprofile: the rules are followed with the switch off",
       expect=OFF, script=S)

# On unless it was turned off.
mutate(A,
       "\tst.enabled = st.enabled == true\n",
       "\tst.enabled = st.enabled ~= false\n",
       "autoprofile: on by default",
       expect=OFF, script=S)

# Say so in chat left as the damaged file had it.
mutate(A,
       "\tst.say = st.say ~= false\n",
       "\tst.say = st.say\n",
       "autoprofile: a damaged chat tick is left as it is",
       expect=REPAIR, script=S)

# Turning the switch on is an arrival where you stand.
mutate(A,
       "\tif st.enabled then st.at = Situation() or st.at end\n",
       "",
       "autoprofile: turning the switch on switches at once",
       expect=EACH, script=S)

# --- where you are ---

mutate(A,
       "\t\tif kind == \"raid\" then return \"raid\" end\n",
       "\t\tif kind == \"raid\" then return \"dungeon\" end\n",
       "autoprofile: a raid is a dungeon",
       expect=EACH, script=S)

mutate(A,
       "\t\tif kind == \"pvp\" or kind == \"arena\" then return \"battle\" end\n",
       "\t\tif kind == \"pvp\" then return \"battle\" end\n",
       "autoprofile: an arena is the open world",
       expect=EACH, script=S)

mutate(A,
       "\t\tif kind == \"party\" or kind == \"scenario\" then return \"dungeon\" end\n",
       "\t\tif kind == \"party\" then return \"dungeon\" end\n",
       "autoprofile: a scenario is the open world",
       expect=EACH, script=S)

# The game's 1 for "inside" not taken.
mutate(A,
       "\tif inside == true or inside == 1 then\n\t\tif kind == \"raid\"",
       "\tif inside == true then\n\t\tif kind == \"raid\"",
       "autoprofile: inside as a number is outside",
       expect=EACH, script=S)

# A place the game will not name read as the open world.
mutate(A,
       "\tif inside == nil and kind == nil then return nil end\n",
       "",
       "autoprofile: no answer is the open world",
       expect=UNNAMED, script=S)

# --- an arrival ---

# Every zone event is an arrival, the same place included.
mutate(A,
       "\t\tif at and at ~= st.at then\n",
       "\t\tif at then\n",
       "autoprofile: the same place is an arrival",
       expect=HAND, script=S)

# Every timer runs, not only the last: the place is read before the settle.
mutate(A,
       "\t\tif mine == auto.serial then ns.Guard(\"automatic profile\", Step) end\n",
       "\t\tif true then ns.Guard(\"automatic profile\", Step) end\n",
       "autoprofile: every zone event reads the place",
       expect=SETTLE, script=S)

# --- what holds a switch back ---

mutate(A,
       "\tif InCombatLockdown() then return \"fight\" end\n",
       "",
       "autoprofile: a switch in a fight",
       expect=FIGHT, script=S)

# The end of the fight asks nothing.
mutate(A,
       "\t\tif auto.pending or auto.look then Later(0.3) end\n",
       "",
       "autoprofile: a switch a fight held back is never made",
       expect=FIGHT, script=S)

mutate(A,
       "\tif ns.pendingClick then return \"press\" end\n",
       "",
       "autoprofile: a switch over a press waiting to be settled",
       expect=HELD, script=S)

mutate(A,
       "\t\tif type(focus) == \"function\" and focus() then return \"window\" end\n",
       "",
       "autoprofile: a switch under a box being typed in",
       expect=HELD, script=S)

# Held back, and never asked again.
mutate(A,
       "\tif held then return Later(RETRY) end\n",
       "\tif held then return end\n",
       "autoprofile: a switch held back is never made",
       expect=HELD, script=S)

# --- Do not switch, and a profile that is gone ---

# "Do not switch" saved as a profile's name.
mutate(A,
       "\t\t\tst.rules[at] = (type(value) == \"string\" and value ~= NONE) and value or nil\n",
       "\t\t\tst.rules[at] = value\n",
       "autoprofile: Do not switch saved as a name",
       expect=LEAVE, script=S)

# Deleting a profile leaves the rules that name it.
mutate(A,
       "\t\tCarry(Store(), name, nil)\n",
       "",
       "autoprofile: a deleted profile keeps its rule",
       expect=DELETED, script=S)

# A rule naming a profile that is gone makes it again.
mutate(A,
       "\tif not P.Names()[name] then\n\t\tst.rules[at] = nil\n",
       "\tif false then\n\t\tst.rules[at] = nil\n",
       "autoprofile: a rule makes a deleted profile again",
       expect=DELETED, script=S)

# --- by hand, and why ---

# A profile the player picked still reads as the automatic choice.
mutate(A,
       "\t\t\tif st then st.chose = nil end\n",
       "",
       "autoprofile: a profile picked by hand reads as chosen automatically",
       expect=HAND, script=S)

# The switch does not remember what it chose.
mutate(A,
       "\tst.chose = { profile = name, at = at }\n",
       "",
       "autoprofile: the page never says why",
       expect=HAND, script=S)

# --- quiet ---

mutate(A,
       "\tif st.say then\n\t\taddon:Print(L[\"profile %s (%s)\"]",
       "\tif true then\n\t\taddon:Print(L[\"profile %s (%s)\"]",
       "autoprofile: the chat line whatever its tick",
       expect=LINE, script=S)

# Said through the route that Say nothing at all in chat does not stop.
mutate(A,
       "\t\taddon:Print(L[\"profile %s (%s)\"]",
       "\t\taddon:Reply(L[\"profile %s (%s)\"]",
       "autoprofile: the chat line with chat silent",
       expect=LINE, script=S)

# --- the page ---

mutate(A,
       "\tif P.Names()[name] then return L[\"There is already a profile called %s.\"]:format(name) end\n",
       "",
       "autoprofile: a name already taken is let through",
       expect=MAKE, script=S)

# Bytes, not letters.
mutate(A,
       "\tif letters > NAME_MAX then",
       "\tif #name > NAME_MAX then",
       "autoprofile: a name counted in bytes",
       expect=MAKE, script=S)

# Duplicate (since 1.12, in place of New profile from these settings) makes a
# profile at the defaults.
mutate(A,
       "\tsv.profiles[name] = Stripped(source, ns.defaults and ns.defaults.profile)\n",
       "\tsv.profiles[name] = {}\n",
       "autoprofile: the copy is not a copy",
       expect=MAKE, script=S)

# Profiles made and switched in a fight.
mutate(A,
       "\tif InCombatLockdown() or not P.Current() then return nil end\n",
       "\tif not P.Current() then return nil end\n",
       "autoprofile: the page acts in a fight",
       expect=MAKE, script=S)

# The profile in use handed to the library to delete.
mutate(A,
       "\tif type(name) ~= \"string\" or name == P.Current() or not P.Names()[name] then return false end\n"
       "\tdb:DeleteProfile(name, true)\n",
       "\tif type(name) ~= \"string\" or not P.Names()[name] then return false end\n"
       "\tdb:DeleteProfile(name, true)\n",
       "autoprofile: the profile in use can be deleted",
       expect=ASKS, script=S)

mutate(A,
       "\targs.delete.confirm = function() return P.DeleteQuestion(P.Picked()) end\n",
       "\targs.delete.confirm = false\n",
       "autoprofile: Delete does not ask",
       expect=ASKS, script=S)

mutate(A,
       "\t\tconfirm = true,\n\t\tconfirmText = L[\"Put every setting of this profile back to its default? Undo puts them back.\"],\n",
       "\t\tconfirm = false,\n\t\tconfirmText = L[\"Put every setting of this profile back to its default? Undo puts them back.\"],\n",
       "autoprofile: Reset does not ask",
       expect=ASKS, script=S)

# --- rename ---

mutate(A,
       "\tCarry(st, old, name)\n",
       "",
       "autoprofile: a rename leaves this character's rules on the old name",
       expect=RENAME, script=S)

mutate(A,
       "\t\t\t\tif profile == old then sv.profileKeys[char] = name end\n",
       "",
       "autoprofile: a rename leaves the alts on the old name",
       expect=RENAME, script=S)

mutate(A,
       "\t\t\t\tif type(char) == \"table\" then Carry(char.autoProfile, old, name) end\n",
       "",
       "autoprofile: a rename leaves the alts' rules on the old name",
       expect=RENAME, script=S)

mutate(A,
       "\tif st then st.chose = chose end\n",
       "",
       "autoprofile: a rename forgets why the profile is in use",
       expect=RENAME, script=S)

# The old name left behind as a second profile.
mutate(A,
       "\tdb:DeleteProfile(old, true)\n",
       "",
       "autoprofile: a rename keeps the old profile",
       expect=RENAME, script=S)

# --- its place on the page ---

# The page's own controls never added to the Profiles tab.
mutate("Options/Profiles.lua",
       "\tif ns.Profiles then ns.Profiles.AddOptions(t.args) end\n",
       "",
       "autoprofile: the Profiles tab has none of it",
       expect=OFF, script=S)

# A situation's row at the page's edge: drawn, greyed, with the switch off.
mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t{ \"profiles.auto_raid\", indent = true, match = \"auto\" },\n",
       "\t\t\t\t\t{ \"profiles.auto_raid\", match = \"auto\" },\n",
       "autoprofile: the raid's row is not under the switch",
       expect=WINDOW, script=S)

mutate("Options/Window/Layout.lua",
       "\t\t[\"profiles.auto_raid\"] = \"profiles.autoEnabled\",\n",
       "",
       "autoprofile: search is not told which switch shows the raid's row",
       expect=WINDOW, script=S)

mutate("Options/Window/Layout.lua",
       "\t\t[\"profiles.autoEnabled\"] = L[\"auto raid dungeon instance battleground arena world normal\"],\n",
       "",
       "autoprofile: search has no words for the switch",
       expect=WINDOW, script=S)
