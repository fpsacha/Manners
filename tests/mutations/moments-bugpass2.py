# Mutations for the second bug pass over the buttons for the moment:
# tests/scenarios/moments-bugpass2.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts one fix back to its
# absence and names the scenario that objects.

S = "runscenarios.py"

mutate("Prompt/MomentsData.lua",
       "guard = \"twice\", blind = \"weak\", cooldown = 30,",
       "blind = \"weak\", cooldown = 30,",
       "moments-bugpass2: Counterspell loses its two clicks where the game paints it",
       expect="moments-bugpass2: Counterspell painted by the game", script=S)

mutate("Prompt/MomentsData.lua",
       "key = \"spellsteal\", slot = 8, ranks = { 30449 }, stop = true, guard = \"twice\",\n",
       "key = \"spellsteal\", slot = 8, ranks = { 30449 }, stop = true,\n",
       "moments-bugpass2: Spellsteal loses its two clicks where the game paints it",
       expect="moments-bugpass2: Spellsteal painted by the game", script=S)

mutate("Prompt/MomentsCard.lua",
       "\tlocal ring = mark:CreateTexture(nil, \"OVERLAY\")\n",
       "\tlocal ring = inner:CreateTexture(nil, \"OVERLAY\")\n",
       "moments-bugpass2: the ring goes back on the layer the game paints",
       expect="moments-bugpass2: the first of two clicks shows the ring", script=S)

mutate("Prompt/Moments.lua",
       "if slot.openUntil and now < slot.openUntil then return now < slot.openFrom end",
       "if slot.openUntil and now < slot.openUntil then return false end",
       "moments-bugpass2: the cover comes down at once after the first click",
       expect="moments-bugpass2: a second click inside a third of a second", script=S)

mutate("Prompt/Moments.lua",
       "\tCard.Hint(slot, mode)\n",
       "\tCard.Hint(slot, nil)\n",
       "moments-bugpass2: the dim icon is never shown",
       expect="moments-bugpass2: a drink the game paints shows a dim icon", script=S)

mutate("Prompt/Moments.lua",
       "\t\tJudgeAll(\"casting\")\n\t\treturn Schedule()\n",
       "\t\treturn JudgeAll(\"casting\")\n",
       "moments-bugpass2: a cast start schedules no recheck",
       expect="moments-bugpass2: a cast start with the target out of range", script=S)

mutate("Prompt/Moments.lua",
       "\t\tJudgeAll()\n\t\t-- A caster out of range or a spell cooling down is waited on by the flush.\n\t\treturn Schedule()\n",
       "\t\treturn JudgeAll()\n",
       "moments-bugpass2: a target change schedules no recheck",
       expect="moments-bugpass2: a target change onto a caster out of range", script=S)

mutate("Prompt/Moments.lua",
       "\tif out.n > 0 and before and SameList(before, out) then\n",
       "\tif false then\n",
       "moments-bugpass2: a probe that learned nothing new still refreshes",
       expect="moments-bugpass2: a probe between the two clicks of a drink", script=S)

mutate("Prompt/MomentsData.lua",
       "ranks = { 12051 }, stop = true, guard = \"twice\", cooldown = 480,",
       "ranks = { 12051 }, guard = \"twice\", cooldown = 480,",
       "moments-bugpass2: Evocation does not stop the cast first",
       expect="moments-bugpass2: Evocation and the mana gem stop the cast first", script=S)

mutate("Prompt/MomentsData.lua",
       "ranks = { 12051 }, stop = true, guard = \"twice\", cooldown = 120,",
       "ranks = { 12051 }, guard = \"twice\", cooldown = 120,",
       "moments-bugpass2: Evocation does not stop the cast first on Mists",
       expect="moments-bugpass2: Evocation and the mana gem stop the cast first", script=S)

mutate("Prompt/Moments.lua",
       "\t\treturn (row.stop and \"/stopcasting\\n\" or \"\") .. table.concat(lines, \"\\n\")\n",
       "\t\treturn table.concat(lines, \"\\n\")\n",
       "moments-bugpass2: the mana gem does not stop the cast first",
       expect="moments-bugpass2: Evocation and the mana gem stop the cast first", script=S)

mutate("Prompt/Moments.lua",
       "\t\t\tif armed then armed = tostring(armed):gsub(\"^/target [^\\n]*\", \"/target <you>\") end\n",
       "",
       "moments-bugpass2: the debug line prints the macro with the character's name",
       expect="moments-bugpass2: no debug line holds the character's own name", script=S)

mutate("Prompt/Moments.lua",
       "\t\t\tlocal leaks = slot.leakTotal or 0\n",
       "\t\t\tlocal leaks = ns.db and ns.db.global and ns.db.global.momentCoverLeaks or 0\n",
       "moments-bugpass2: the self-test warns for a count kept from earlier sessions",
       expect="moments-bugpass2: a leak from an earlier session warns nothing", script=S)

mutate("Selftest.lua",
       "\t\t\tif r.id then\n\t\t\t\tfirst = r\n",
       "\t\t\tif true then\n\t\t\t\tfirst = r\n",
       "moments-bugpass2: the check-up reads the cooldown of a row with no spell id",
       expect="moments-bugpass2: the check-up of a priest", script=S)

mutate("tests/momentskit.lua",
       "\tif Mock.flavour == \"camelot\" and not plain then\n",
       "\tif false then\n",
       "moments-bugpass2: the kit gives Forever plain values by default",
       expect="moments-bugpass2: the kit on Forever hides health", script=S)

mutate("tests/momentskit.lua",
       "\t\tlocal hidden = c.secret\n\t\tif hidden == nil then hidden = Mock.hiddenValues == true end\n",
       "\t\tlocal hidden = c.secret\n",
       "moments-bugpass2: the kit gives the target's cast flag plain on Forever by default",
       expect="moments-bugpass2: the kit on Forever hides health", script=S)

mutate("tests/momentskit.lua",
       "\t\t\tif id == nil then error(\"bad argument #1 to 'GetSpellCooldown' (a spell is needed)\", 2) end\n",
       "",
       "moments-bugpass2: the kit answers a nil spell id",
       expect="moments-bugpass2: the kit's GetSpellCooldown throws", script=S)

mutate("Locales/frFR.lua",
       "L[\"It needs a %s in your bags.\"] = \"Composant requis dans vos sacs : %s.\"",
       "L[\"It needs a %s in your bags.\"] = \"Il faut un %s dans vos sacs.\"",
       "moments-bugpass2: the French Light Feather line gets a masculine article back",
       expect="moments-bugpass2: the Light Feather line has no article", script=S)

mutate("Locales/deDE.lua",
       "L[\"It needs a %s in your bags.\"] = \"Benötigt %s in deinen Taschen.\"",
       "L[\"It needs a %s in your bags.\"] = \"Er braucht ein %s in deinen Taschen.\"",
       "moments-bugpass2: the German Light Feather line gets an article back",
       expect="moments-bugpass2: the Light Feather line has no article", script=S)
