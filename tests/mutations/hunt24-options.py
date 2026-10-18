# Mutations for round 24's fix in Options/Look.lua: "Only for people who buff
# me" (the sound's owedOnly) is greyed out while "People who buff me"
# (db.sources.owed) is off as well as while the sound is, because the sound
# ignores the setting then (Prompt/Refresh.lua) and the toggle did nothing.
# Each undoes a part of that and is caught by the scenario in
# tests/scenarios/hunt24-options.lua it names.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# ------------------------------------------------------------ the source
# The fix undone: only the sound switch greys it out, as in 1.7.8.
mutate("Options/Look.lua",
       "\t\t\t\tdisabled = function() return not SND().enabled or S().owed == false end,\n",
       "\t\t\t\tdisabled = function() return not SND().enabled end,\n",
       "hunt24-options: the owed-only sound toggle stays live with the source off",
       expect="hunt24-options: Only for people who buff me is greyed out while People who buff me is off", script=S)

# A profile with no value for the source, which the sound reads as on, greyed
# out as if it were off.
mutate("Options/Look.lua",
       "\t\t\t\tdisabled = function() return not SND().enabled or S().owed == false end,\n",
       "\t\t\t\tdisabled = function() return not SND().enabled or not S().owed end,\n",
       "hunt24-options: the owed-only sound toggle greyed out by an unset source",
       expect="hunt24-options: Only for people who buff me is live with People who buff me and the sound on", script=S)

# ------------------------------------------------------------ the sound
# The source alone decides: the toggle stays live with the sound off.
mutate("Options/Look.lua",
       "\t\t\t\tdisabled = function() return not SND().enabled or S().owed == false end,\n",
       "\t\t\t\tdisabled = function() return S().owed == false end,\n",
       "hunt24-options: the owed-only sound toggle live with the sound off",
       expect="hunt24-options: Only for people who buff me is greyed out with the sound off, whoever buffs me", script=S)

# ------------------------------------------------------------ the window
# The same undone, as the window's click finds it: a greyed-out toggle in the
# window refuses the click, and a live one does not.
mutate("Options/Look.lua",
       "\t\t\t\tdisabled = function() return not SND().enabled or S().owed == false end,\n",
       "\t\t\t\tdisabled = function() return false end,\n",
       "hunt24-options: the owed-only sound toggle never greyed out",
       expect="hunt24-options: the window's Only for people who buff me refuses a click while People who buff me is off", script=S)
