# Mutations for the groups pass's fixes (round 34): a cast event that names
# nobody (Clicks.lua). Each undoes a fix and is caught by the scenario in
# tests/scenarios/groups-fixes.lua it names.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# ------------------------------------------------- a cast event with no name
# Forever's Arcane Brilliance, Prayers and Gift of the Wild have no unit to aim
# at, so the client reports the cast with an empty target name. Read as a name,
# it is compared with the person the macro aimed at: the cast that landed is
# rewound as "it went to nobody".
mutate("Clicks.lua",
       "\tif landedOn == \"\" then landedOn = nil end\n",
       "",
       "groups-fix: an empty cast name read as somebody else",
       expect="groups-fix: mage: a cast event that names nobody counts the cast as repaid",
       script=S)

# The same for a priest's and a druid's group cast: the mage's is not the only
# one judged.
mutate("Clicks.lua",
       "\tif landedOn == \"\" then landedOn = nil end\n",
       "\tif landedOn == \"\" and spellId == 23028 then landedOn = nil end\n",
       "groups-fix: only the mage's empty cast name read as none",
       expect="groups-fix: priest: a cast event that names nobody counts the cast as repaid",
       script=S)

# The click log (/manners clicks) shows what the client sent: nothing after the
# arrow, which is how an empty name is told from a withheld one ("nil") in the
# game.
mutate("Clicks.lua",
       "\t\ttostring(plain(spellId)), tostring(plain(target))))\n",
       "\t\ttostring(plain(spellId)), tostring(plain(target) ~= \"\" and plain(target) or nil)))\n",
       "groups-fix: the click log hides an empty cast name",
       expect="groups-fix: mage: a cast event that names nobody counts the cast as repaid",
       script=S)
