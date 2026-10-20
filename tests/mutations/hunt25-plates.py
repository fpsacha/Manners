# Mutations for the friendly nameplate hint beside the passers-by switch on Who
# to buff, and the empty keypress that names the nameplates. Each is caught by
# the scenario in tests/scenarios/hunt25-plates.lua that names it.

SHOWN = "hunt25-plates: Forever: the note and the button on Who to buff"
BUTTON = "hunt25-plates: Forever: Show friendly nameplates turns them on out of combat only"
NAMED = "hunt25-plates: Forever: an empty keypress names the nameplates when they are why"
NOT_NAMED = "hunt25-plates: Forever: an empty keypress does not name the nameplates"
OWN_REASON = "hunt25-plates: Forever: an empty keypress keeps its own reason"

# The line the keypress says, as Press.lua has it, for the mutations that
# put it somewhere else.
PLATES_LINE = (
    "\t\t\tns.addon:Print(L[\"nobody to buff right now -- friendly nameplates are off, and passers-by are seen through them. %s on the %s tab turns them on.\"]\n"
    "\t\t\t\t:format(\"|cffffd100\" .. L[\"Show friendly nameplates\"] .. \"|r\", L[\"Who to buff\"]))\n"
)

# ------------------------------------------------------------------ Who to buff

# The note and the button with passers-by switched off.
mutate("Options/Who.lua",
       "\treturn not S().strangers or OnlyReachesGroup() or not ns.FriendlyPlatesOff()\n",
       "\treturn OnlyReachesGroup() or not ns.FriendlyPlatesOff()\n",
       "plates note with passers-by off",
       expect=SHOWN + " (passers-by off)",
       script="runscenarios.py")

# ... to a class whose buffs reach only its group, which has no passers-by.
mutate("Options/Who.lua",
       "\treturn not S().strangers or OnlyReachesGroup() or not ns.FriendlyPlatesOff()\n",
       "\treturn not S().strangers or not ns.FriendlyPlatesOff()\n",
       "plates note to a class with no passers-by",
       expect=SHOWN + " (everything reaches only the group)",
       script="runscenarios.py")

# ... with the nameplates on already.
mutate("Options/Who.lua",
       "\treturn not S().strangers or OnlyReachesGroup() or not ns.FriendlyPlatesOff()\n",
       "\treturn not S().strangers or OnlyReachesGroup()\n",
       "plates note with the nameplates on",
       expect=SHOWN + " (the nameplates on)",
       script="runscenarios.py")

# ... when the client will not say (no answer read as off).
mutate("Options/Who.lua",
       "\treturn not S().strangers or OnlyReachesGroup() or not ns.FriendlyPlatesOff()\n",
       "\treturn not S().strangers or OnlyReachesGroup() or select(2, ns.FriendlyPlatesCVar()) == \"1\"\n",
       "plates note when the client will not say",
       expect=SHOWN + " (the client will not say)",
       script="runscenarios.py")

# Never shown at all.
mutate("Options/Who.lua",
       "\treturn not S().strangers or OnlyReachesGroup() or not ns.FriendlyPlatesOff()\n",
       "\treturn true\n",
       "plates note never shown",
       expect=SHOWN + " (passers-by on, nameplates off)",
       script="runscenarios.py")

# The button live in a fight.
mutate("Options/Who.lua",
       "\t\t\t\t-- The client refuses the setting in a fight.\n\t\t\t\tdisabled = function() return InCombatLockdown() end,\n",
       "",
       "plates button live in combat",
       expect=BUTTON,
       script="runscenarios.py")

# The button turning nothing on.
mutate("Options/Who.lua",
       "\t\t\t\t\tif ns.ShowFriendlyPlates() then ns.RefreshOptionsDisplay() end\n",
       "\t\t\t\t\tns.RefreshOptionsDisplay()\n",
       "plates button sets nothing",
       expect=BUTTON,
       script="runscenarios.py")

# The open page not redrawn after the button worked, so the note stays up.
mutate("Options/Who.lua",
       "\t\t\t\t\tif ns.ShowFriendlyPlates() then ns.RefreshOptionsDisplay() end\n",
       "\t\t\t\t\tns.ShowFriendlyPlates()\n",
       "plates note stays after the button",
       expect="hunt25-plates: Forever: the button has the open page redrawn once the nameplates are on",
       script="runscenarios.py")

# The page redrawn before the setting changed: the note drawn once more.
mutate("Options/Who.lua",
       "\t\t\t\t\tif ns.ShowFriendlyPlates() then ns.RefreshOptionsDisplay() end\n",
       "\t\t\t\t\tns.RefreshOptionsDisplay()\n\t\t\t\t\tns.ShowFriendlyPlates()\n",
       "plates page redrawn before the setting changes",
       expect="hunt25-plates: Forever: the button has the open page redrawn once the nameplates are on",
       script="runscenarios.py")

# ------------------------------------------------------------------ the layout

# The two controls drawn at the end of the section instead of under the switch.
mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t{ \"who.strangersPlatesNote\", indent = true },\n"
       "\t\t\t\t\t{ \"who.strangersShowPlates\", indent = true },\n"
       "\t\t\t\t\t{ \"who.strangersNote\", standIn = true },\n"
       "\t\t\t\t\t{ \"who.proximity\", indent = true },\n"
       "\t\t\t\t\t{ \"who.restingOnly\", indent = true },\n"
       "\t\t\t\t\t\"who.asked\",\n",
       "\t\t\t\t\t{ \"who.strangersNote\", standIn = true },\n"
       "\t\t\t\t\t{ \"who.proximity\", indent = true },\n"
       "\t\t\t\t\t{ \"who.restingOnly\", indent = true },\n"
       "\t\t\t\t\t\"who.asked\",\n"
       "\t\t\t\t\t{ \"who.strangersPlatesNote\", indent = true },\n"
       "\t\t\t\t\t{ \"who.strangersShowPlates\", indent = true },\n",
       "plates note and button placed away from the switch",
       expect="hunt25-plates: the note and the button sit right under the passers-by switch",
       script="runscenarios.py")

# The two controls placed nowhere: a setting nobody can reach.
mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t{ \"who.strangersPlatesNote\", indent = true },\n"
       "\t\t\t\t\t{ \"who.strangersShowPlates\", indent = true },\n",
       "",
       "plates note and button placed on no page",
       expect="who.strangersPlatesNote",
       script="runscenarios.py")

# ------------------------------------------------------------------ the keypress

# The line said whatever the nameplates are.
mutate("Prompt/Press.lua",
       "\t\t\tand ns.FriendlyPlatesOff() then\n",
       "\t\t\tthen\n",
       "plates line with the nameplates on",
       expect=NOT_NAMED + " (the nameplates on)",
       script="runscenarios.py")

# ... or when the client will not say.
mutate("Prompt/Press.lua",
       "\t\t\tand ns.FriendlyPlatesOff() then\n",
       "\t\t\tand select(2, ns.FriendlyPlatesCVar()) ~= \"1\" then\n",
       "plates line when the client will not say",
       expect=NOT_NAMED + " (the client will not say)",
       script="runscenarios.py")

# ... with passers-by switched off.
mutate("Prompt/Press.lua",
       "\t\telseif db and db.sources and db.sources.strangers == true and ns.caps.hasClassBuffs == true\n",
       "\t\telseif db and db.sources and ns.caps.hasClassBuffs == true\n",
       "plates line with passers-by off",
       expect=NOT_NAMED + " (passers-by off)",
       script="runscenarios.py")

# ... to a class with nothing for anybody else.
mutate("Prompt/Press.lua",
       "\t\telseif db and db.sources and db.sources.strangers == true and ns.caps.hasClassBuffs == true\n",
       "\t\telseif db and db.sources and db.sources.strangers == true\n",
       "plates line to a class with nothing for others",
       expect=NOT_NAMED + " (a class with nothing for anybody else)",
       script="runscenarios.py")

# ... to a class whose buffs reach only its group.
mutate("Prompt/Press.lua",
       "\t\t\tand not ns.OnlyReachesGroup() and not (db.filters.restingOnly == true and ns.Resting() == false)\n",
       "\t\t\tand not (db.filters.restingOnly == true and ns.Resting() == false)\n",
       "plates line to a class with no passers-by",
       expect=NOT_NAMED + " (everything reaches only the group)",
       script="runscenarios.py")

# ... out in the world under the city rule, which turns passers-by down anyway.
mutate("Prompt/Press.lua",
       "\t\t\tand not ns.OnlyReachesGroup() and not (db.filters.restingOnly == true and ns.Resting() == false)\n",
       "\t\t\tand not ns.OnlyReachesGroup()\n",
       "plates line under the city rule",
       expect=NOT_NAMED + " (passers-by only in cities, out in the world)",
       script="runscenarios.py")

# The city rule applied in a city, where passers-by are offered.
mutate("Prompt/Press.lua",
       "not (db.filters.restingOnly == true and ns.Resting() == false)\n",
       "not (db.filters.restingOnly == true and ns.Resting() ~= nil)\n",
       "city rule held against a city",
       expect="hunt25-plates: Forever: passers-by only in cities, in a city, an empty keypress names the nameplates",
       script="runscenarios.py")

# The line naming another tab for the button.
mutate("Prompt/Press.lua",
       "\"|r\", L[\"Who to buff\"]))\n\t\telse\n",
       "\"|r\", L[\"What I say\"]))\n\t\telse\n",
       "plates line names the wrong tab",
       expect=NAMED,
       script="runscenarios.py")

# The line not naming the button.
mutate("Prompt/Press.lua",
       "\t\t\t\t:format(\"|cffffd100\" .. L[\"Show friendly nameplates\"] .. \"|r\", L[\"Who to buff\"]))\n",
       "\t\t\t\t:format(\"|cffffd100\" .. L[\"Who to buff\"] .. \"|r\", L[\"Who to buff\"]))\n",
       "plates line does not name the button",
       expect=NAMED,
       script="runscenarios.py")

# The plain line when the nameplates are why.
mutate("Prompt/Press.lua",
       "\t\t\tand ns.FriendlyPlatesOff() then\n",
       "\t\t\tand false then\n",
       "plates line never said",
       expect=NAMED,
       script="runscenarios.py")

# The line ahead of every other reason: a switched-off Manners, snoozed,
# mounted or with nothing learned is told about the nameplates instead.
mutate("Prompt/Press.lua",
       "\t\tif db and not db.enabled then\n",
       "\t\tif db and db.sources and db.sources.strangers == true and ns.FriendlyPlatesOff() then\n"
       + PLATES_LINE
       + "\t\telseif db and not db.enabled then\n",
       "plates line ahead of every other reason",
       expect=OWN_REASON + " (switched off)",
       script="runscenarios.py")

# ... or ahead of only the mana floor.
mutate("Prompt/Press.lua",
       "\t\telseif ns.SavingMana() then\n",
       "\t\telseif db and db.sources and db.sources.strangers == true and ns.FriendlyPlatesOff() then\n"
       + PLATES_LINE
       + "\t\telseif ns.SavingMana() then\n",
       "plates line ahead of the mana floor",
       expect=OWN_REASON + " (saving mana)",
       script="runscenarios.py")

# ------------------------------------------------------------------ translations

# The Who to buff note without its German, the keypress line without its French:
# a string with no translation in a language fails validate.
mutate("Locales/deDE.lua",
       "L[\"Turn on friendly nameplates so Manners can see passers-by: without them it sees almost nobody outside your group.\"] = \"Schaltet die Namensplaketten von verbündeten Spielern ein, damit Manners Passanten erkennen kann: Ohne sie erkennt es fast niemanden außerhalb Eurer Gruppe.\"\n",
       "",
       "plates note without its German",
       expect="deDE",
       script="validate.py")

mutate("Locales/frFR.lua",
       "L[\"nobody to buff right now -- friendly nameplates are off, and passers-by are seen through them. %s on the %s tab turns them on.\"] = \"personne à buffer pour l'instant -- les barres d'info des personnages amicaux sont désactivées, et les passants sont repérés grâce à elles. %s dans l'onglet « %s » les active.\"\n",
       "",
       "plates keypress line without its French",
       expect="frFR",
       script="validate.py")
