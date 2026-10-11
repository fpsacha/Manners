# Mutations for the translated clients' fixes of round 34: the saved "In
# character" box read with the examples' earlier translations, a whisper to a
# surname that is not plain A to Z, and the end of a snooze written as the
# client's own 12-hour clock. Each is caught by the scenario in
# tests/scenarios/i18n-fixes.lua that names it.

# ------------------------------------------------------------------ old boxes

# An earlier translation of an example line never read: the box reads as the
# player's own again.
mutate("Phrases.lua",
       "\t\t\tanswer = now ~= text and IsExamples(now, false, true)\n",
       "\t\t\tanswer = false\n",
       "i18n-fix earlier translations never read",
       expect="i18n-fix: old box: the 1.6.5 box of a mage",
       script="runscenarios.py")

# ...and read too freely: one earlier line is enough for the box to count,
# whatever else it holds.
mutate("Phrases.lua",
       "\t\t\tanswer = now ~= text and IsExamples(now, false, true)\n",
       "\t\t\tanswer = now ~= text\n",
       "i18n-fix any earlier line makes the set",
       expect="i18n-fix: old box: an old box with a line of the player's own",
       script="runscenarios.py")

# Spanish: the file answers both clients, and the table is kept under esES.
mutate("Phrases.lua",
       "byLocale[ns.LOCALE == \"esMX\" and \"esES\" or ns.LOCALE]",
       "byLocale[ns.LOCALE]",
       "i18n-fix esMX reads no earlier translations",
       expect="i18n-fix: old box: a Spanish box is read on esMX",
       script="runscenarios.py")

# Only the first line of a box read as it reads now.
mutate("Phrases.lua",
       "\t\treturn (text:gsub(\"[^\\n]+\", earlier))\n",
       "\t\treturn (text:gsub(\"[^\\n]+\", earlier, 1))\n",
       "i18n-fix only the first line modernised",
       expect="i18n-fix: old box: the 1.6.5 box of a mage",
       script="runscenarios.py")

# An entry under a key the language no longer translates matches nothing.
mutate("Phrases.lua",
       "\t\t[\"Ishnu-alah, {name}. Elune keeps her children close.\"] = {",
       "\t\t[\"Ishnu-alah, {name}. Elune keeps her children closer.\"] = {",
       "i18n-fix an earlier translation under a mistyped key",
       expect="i18n-fix: old box: every earlier translation belongs to a line translated now",
       script="runscenarios.py")

# A translation of an example line edited without the old text going into the
# table (what 1.6.6 did to every box before it): the digest of the examples
# no longer matches the one the table was made for.
mutate("Locales/koKR.lua",
       "L[\"Ishnu-alah, {name}. Elune keeps her children close.\"] = \"이슈누 알라, {name}. 엘룬께선 자녀들을 늘 곁에 두시지요.\"",
       "L[\"Ishnu-alah, {name}. Elune keeps her children close.\"] = \"이슈누 알라, {name}. 엘룬께서는 자녀들을 늘 곁에 두십니다.\"",
       "i18n-fix an example translated again with no earlier text kept",
       expect="i18n-fix: old box: the examples read as the table of earlier translations was made for",
       script="runscenarios.py")

# ------------------------------------------------------------------ whisper

# The word of the client's walk read as letters and digits of the C locale.
mutate("Speech.lua",
       "\t\tlocal more = regional and \"[%s-](%S+)%s\" or \"%s\"\n",
       "\t\tlocal more = regional and \"[%s-](%w+)%s\" or \"%s\"\n",
       "i18n-fix whisper walk takes a word for letters and digits",
       expect="i18n-fix: whisper: an accented surname is whispered as the person it names",
       script="runscenarios.py")

# ------------------------------------------------------------------ clock

# The client's 12-hour strings never asked: AM and PM in every language.
mutate("Commands.lua",
       "\tlocal text = _G[late and \"TIME_TWELVEHOURPM\" or \"TIME_TWELVEHOURAM\"]\n",
       "\tlocal text = nil\n",
       "i18n-fix snooze end without the client's 12-hour strings",
       expect="i18n-fix: clock: a snooze ends on a koKR 12-hour clock as the client writes it",
       script="runscenarios.py")

# Noon is the afternoon.
mutate("Commands.lua",
       "\tlocal late = hour >= 12\n",
       "\tlocal late = hour > 12\n",
       "i18n-fix noon written as the morning",
       expect="i18n-fix: clock: a snooze ends on the realm clock at 12:00",
       script="runscenarios.py")

# The minimap's realm clock written with the English marker.
mutate("Commands.lua",
       "\t\t\tif TwelveHourClock() then return TwelveHourText(hour, minute) end\n",
       "\t\t\tif TwelveHourClock() then return (\"%d:%02d %s\"):format(hour % 12 == 0 and 12 or hour % 12, minute, hour < 12 and \"AM\" or \"PM\") end\n",
       "i18n-fix realm clock with the English marker",
       expect="i18n-fix: clock: a snooze ends on the realm clock at 13:20",
       script="runscenarios.py")

# The player's own clock written with the English marker.
mutate("Commands.lua",
       "\t\t\treturn TwelveHourText(when.hour, when.min)\n",
       "\t\t\treturn (date(\"%I:%M %p\", at):gsub(\"^0\", \"\"))\n",
       "i18n-fix local clock with the English marker",
       expect="i18n-fix: clock: a snooze ends on a koKR 12-hour clock as the client writes it",
       script="runscenarios.py")

# A client with none of the strings gets a time with no AM or PM.
mutate("Commands.lua",
       "\treturn (\"%d:%02d %s\"):format(twelve, minute, late and \"PM\" or \"AM\")\n",
       "\treturn (\"%d:%02d\"):format(twelve, minute)\n",
       "i18n-fix no English marker where the client has no strings",
       expect="i18n-fix: clock: a client without the 12-hour strings gets AM or PM",
       script="runscenarios.py")
