# "/thank people who buff me" for everybody: each new gate put back wrong, or
# the old rule put back, and required to be caught by its scenario in
# tests/scenarios/thank-everyone.lua.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# ------------------------------------------------ the debt and the thank apart
mutate("Favours.lua",
       "\t\tif db.sources.owed then OweFavour(db, seen) end\n",
       "\t\tOweFavour(db, seen)\n",
       "thank-everyone: a debt filed with the source off",
       expect="a debt was recorded with People who buff me off", script=S)
mutate("Favours.lua",
       "\t\tif db.prompt.thankEmote then ns.Guard(\"thank emote\", ThankFavour, seen) end\n",
       "\t\tif db.prompt.thankEmote and db.sources.owed then ns.Guard(\"thank emote\", ThankFavour, seen) end\n",
       "thank-everyone: the thank waits on People who buff me",
       expect="with People who buff me off, the favour was not thanked", script=S)
mutate("Favours.lua",
       "\t\tif db.prompt.thankEmote then ns.Guard(\"thank emote\", ThankFavour, seen) end\n",
       "\t\tif db.prompt.thankEmote and #ns.CastableBuffs() > 0 then ns.Guard(\"thank emote\", ThankFavour, seen) end\n",
       "thank-everyone: nothing to give, nothing thanked",
       expect="a rogue's favour was not thanked", script=S)
mutate("Favours.lua",
       "\t\tif not db.enabled then return end\n",
       "",
       "thank-everyone: thanked with Manners switched off",
       expect="a favour sighted before Manners was switched off was thanked", script=S)

# ------------------------------------------------ who cast it, and when it is read
mutate("Favours.lua",
       "\t\t\tand (db.sources.owed or db.prompt.thankEmote) and true or false\n",
       "\t\t\tand db.sources.owed and true or false\n",
       "thank-everyone: casters read for the debt alone",
       expect="with People who buff me off, the favour was not thanked", script=S)
mutate("Favours.lua",
       "\t\t\tand (db.sources.owed or db.prompt.thankEmote) and true or false\n",
       "\t\t\tand true or false\n",
       "thank-everyone: casters read with both off",
       expect="a caster was read with both switches off", script=S)
mutate("Favours.lua",
       "\t\t\t\t\t\t\tand (not classOnly or ns.ALL_BUFF_IDS[spellId]) then\n",
       "\t\t\t\t\t\t\tthen\n",
       "thank-everyone: every buff counted as a class buff",
       expect="a rogue thanked a buff that is not a class buff", script=S)

# ------------------------------------------------ What I say
mutate("Options/Say.lua",
       "\t\tname = TAB.click,\n\t\torder = 4,\n",
       "\t\tname = TAB.click,\n\t\torder = 4,\n\t\thidden = function() return not HasClassBuffs() end,\n",
       "thank-everyone: What I say hidden with nothing to give",
       expect="What I say is missing from a hunter's sidebar", script=S)
mutate("Options/Say.lua",
       "local THANKS_ONLY = { speechHeader = true, thankEmote = true }\n",
       "local THANKS_ONLY = { speechHeader = true }\n",
       "thank-everyone: the /thank hidden with the lines",
       expect="What I say is missing from a rogue's sidebar", script=S)
mutate("Options/Say.lua",
       "\t\t\t\tif not HasClassBuffs() then return true end\n",
       "",
       "thank-everyone: the lines shown with nothing to give",
       expect="a control other than the /thank shows on What I say", script=S)
mutate("Options/Say.lua",
       "\t\t\t\tif not HasClassBuffs() then return true end\n",
       "\t\t\t\tif true then return true end\n",
       "thank-everyone: the lines hidden from a mage",
       expect="is missing from a mage's What I say", script=S)
mutate("Options/Say.lua",
       "\t\t\t\tif type(own) == \"function\" then return own(info) end\n",
       "",
       "thank-everyone: a control's own rule dropped",
       expect="a mage's Lines section does not follow Say a line", script=S)
mutate("Options/Start.lua",
       "\t\t\t\torder = 41,\n\t\t\t\twidth = \"full\",\n\t\t\t\thidden = noClassBuffs,\n",
       "\t\t\t\torder = 41,\n\t\t\t\twidth = \"full\",\n",
       "thank-everyone: the voice choice with nothing to give",
       expect="a control other than the /thank shows on What I say", script=S)
mutate("Options/Start.lua",
       "\t\t\t\t\t\t\t\t:format(Ref(L[\"/thank people who buff me\"], TAB.click))\n",
       "\t\t\t\t\t\t\t\t:format(Ref(L[\"/thank people who buff me\"], TAB.who))\n",
       "thank-everyone: Start here points at the wrong page",
       expect="a rogue's Start here does not point at the /thank", script=S)

# ------------------------------------------------ what says so
mutate("Commands.lua",
       "\t\t\tPrintFavourWatch(self, db, GetTime())\n",
       "",
       "thank-everyone: debug silent about a rogue's /thank",
       expect="/manners debug does not show a rogue's /thank", script=S)
mutate("Options/Diagnostics.lua",
       "\t\ttostring(db.timing.keepDebts), tostring(db.prompt.thankEmote))\n",
       "\t\ttostring(db.timing.keepDebts), tostring(true))\n",
       "thank-everyone: the bug report always says thank=true",
       expect="the bug report does not say whether the /thank is on", script=S)
