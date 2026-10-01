# Mutations for tests/scenarios/hotfix151.lua.

S = "runscenarios.py"

# The count walks one pool only: the note would claim a handful.
mutate("Phrases.lua",
       "\tfor _, name in ipairs({ \"RACE\", \"KIN\", \"FACTION\", \"GENERAL\", \"CLASS\", \"SPELL\", \"TRADE\", \"GIFT\",\n"
       "\t\t\"HISTORY\", \"PLACE\", \"TIME\", \"TARGET\", \"SAME\", \"ONTO\", \"HOME\" }) do\n",
       "\tfor _, name in ipairs({ \"KIN\" }) do\n",
       "hotfix151: the line count reads one pool",
       expect="far fewer than the set has",
       script=S)

# The note without the number.
mutate("Options/Say.lua",
       "\t\t\t\t\t\t:format(ns.InCharacter.Count()) .. \"|r\\n\"\n",
       "\t\t\t\t\t\t:format(8) .. \"|r\\n\"\n",
       "hotfix151: the note does not name the count",
       expect="does not say how many lines there are",
       script=S)

# Back to speaking only when returning a favour, by default.
mutate("Core.lua",
       "\t\t\tonlyWhenReturning = false,\n",
       "\t\t\tonlyWhenReturning = true,\n",
       "hotfix151: speech only when returning, by default",
       expect="hotfix151: ticking Say a line speaks to a passer-by",
       script=S)

# No place of its own: LibDBIcon's shared 225, on top of other addons' buttons.
mutate("Core.lua",
       "\t\tminimap = { hide = false, minimapPos = 195 },\n",
       "\t\tminimap = { hide = false },\n",
       "hotfix151: the minimap button at the shared spot",
       expect="the minimap button has no place of its own",
       script=S)
