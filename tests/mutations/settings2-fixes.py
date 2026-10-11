# Round 34, the settings (Commands.lua, Options/Launcher.lua, Clicks.lua):
# the chat line of /manners off and of the launcher's middle click in a fight,
# and /manners macro with every macro slot used. Each fault is caught by the
# scenario in tests/scenarios/settings2-fixes.lua that names it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# ------------------------------------------------ /manners off in a fight

HELD = ("\t\t\tself:Print(L[\"Switched off -- the prompt this fight froze stays up until it ends,"
        " and a press still casts it.\"])\n")

# The old bare line: the macro the fight froze is never mentioned.
mutate("Commands.lua",
       "\t\tif type(armed) == \"string\" and armed ~= \"\" then\n" + HELD,
       "\t\tif false then\n" + HELD,
       "settings2-fix: off in a fight says only disabled",
       expect="settings2-fix: camelot: /manners off in a fight says a press still casts what the fight froze",
       script=S)

# Said whether or not anything is armed: out of a fight, or in one that began
# with nobody on the prompt, no press casts.
mutate("Commands.lua",
       "\t\tif type(armed) == \"string\" and armed ~= \"\" then\n" + HELD,
       "\t\tif true then\n" + HELD,
       "settings2-fix: off says a press still casts with nothing armed",
       expect="settings2-fix: camelot: /manners off out of a fight is the plain line",
       script=S)

# ------------------------------------------------ the launcher's middle click

# The click's own line is all there is, as before.
mutate("Options/Launcher.lua",
       "\tif not ns.db.profile.enabled and InCombatLockdown() and ArmedButtonLeft() then\n",
       "\tif false then\n",
       "settings2-fix: middle click in a fight says only the way back",
       expect="settings2-fix: camelot: the launcher's middle click in a fight says a press still casts what the fight froze",
       script=S)

# Said on the way back on too.
mutate("Options/Launcher.lua",
       "\tif not ns.db.profile.enabled and InCombatLockdown() and ArmedButtonLeft() then\n",
       "\tif InCombatLockdown() and ArmedButtonLeft() then\n",
       "settings2-fix: middle click switching on says it is off",
       expect="settings2-fix: camelot: the launcher's middle click switching it back on in a fight does not say it is off",
       script=S)

# ------------------------------------------------ macro slots

# The sentence written for a full list is never reached again.
mutate("Clicks.lua",
       "\telseif MacroListsFull() then\n",
       "\telseif false then\n",
       "settings2-fix: macro with both lists full says could not",
       expect="settings2-fix: camelot: /manners macro with every macro slot used says the slots are full",
       script=S)

# Only the account list counted: a character list with room is called full.
mutate("Clicks.lua",
       "\t\tand account >= accountCap and character >= characterCap\n",
       "\t\tand account >= accountCap\n",
       "settings2-fix: macro slots full by the account list alone",
       expect="settings2-fix: camelot: a refusal with 120 account and 29 character macros used is not blamed on the slots",
       script=S)

# Either list full is enough: one with room is called full.
mutate("Clicks.lua",
       "\t\tand account >= accountCap and character >= characterCap\n",
       "\t\tand (account >= accountCap or character >= characterCap)\n",
       "settings2-fix: macro slots full by either list",
       expect="settings2-fix: camelot: a refusal with 40 account and 30 character macros used is not blamed on the slots",
       script=S)

# The classic family's 18 taken for every client's: Forever and retail keep 30.
mutate("Clicks.lua",
       "\tlocal characterCap = consts.MAX_CHARACTER_MACROS or _G.MAX_CHARACTER_MACROS\n",
       "\tlocal characterCap = 18\n",
       "settings2-fix: macro character cap hard-coded at 18",
       expect="settings2-fix: camelot: a refusal with 120 account and 29 character macros used is not blamed on the slots",
       script=S)

# Only the globals read: Forever and retail keep the caps in Constants.MacroConsts.
mutate("Clicks.lua",
       "\tlocal characterCap = consts.MAX_CHARACTER_MACROS or _G.MAX_CHARACTER_MACROS\n",
       "\tlocal characterCap = _G.MAX_CHARACTER_MACROS\n",
       "settings2-fix: macro caps read from the globals only",
       expect="settings2-fix: camelot: /manners macro with every macro slot used says the slots are full",
       script=S)

# Only Constants read: the classic family keeps them in globals.
mutate("Clicks.lua",
       "\tlocal characterCap = consts.MAX_CHARACTER_MACROS or _G.MAX_CHARACTER_MACROS\n",
       "\tlocal characterCap = consts.MAX_CHARACTER_MACROS\n",
       "settings2-fix: macro caps read from Constants only",
       expect="settings2-fix: vanilla: /manners macro with every macro slot used says the slots are full",
       script=S)

# A cap the client does not tell, guessed at.
mutate("Clicks.lua",
       "\tlocal accountCap = consts.MAX_ACCOUNT_MACROS or _G.MAX_ACCOUNT_MACROS\n"
       "\tlocal characterCap = consts.MAX_CHARACTER_MACROS or _G.MAX_CHARACTER_MACROS\n",
       "\tlocal accountCap = consts.MAX_ACCOUNT_MACROS or _G.MAX_ACCOUNT_MACROS or 120\n"
       "\tlocal characterCap = consts.MAX_CHARACTER_MACROS or _G.MAX_CHARACTER_MACROS or 18\n",
       "settings2-fix: macro caps guessed when unreadable",
       expect="settings2-fix: camelot: a macro list cap the client does not tell is not guessed",
       script=S)
