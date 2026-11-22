# Mutations for tests/scenarios/options-fixes.lua: each puts back the fault the
# fix removed. Every one is judged by runscenarios.py.

S = "runscenarios.py"

# The bag counts are not read again when a profile change, a copy or an import
# turns Well-Rested on.
mutate("Core.lua",
       "\tns.ForgetScrolls()\n\t-- A profile switched to may just have been carried over",
       "\t-- A profile switched to may just have been carried over",
       "options-fixes: a settings change leaves the bag counts stale",
       expect="options-fix: an import that switches Well-Rested on offers the bag",
       script=S)

# Emote to use hidden with the lines said with a cast, for a class with nothing
# to give.
mutate("Options/Say.lua",
       "local THANKS_ONLY = { speechHeader = true, thankEmote = true, thankEmoteToken = true, thankWhisper = true }\n",
       "local THANKS_ONLY = { speechHeader = true, thankEmote = true, thankWhisper = true }\n",
       "options-fixes: Emote to use hidden with nothing to give",
       expect="options-fix: Emote to use is shown beside the /thank switch",
       script=S)

# Well-Rested and Well Fed up named "?" is prompt-fixes.py's (FamilyLine's one
# fix); this file's scenario for it still has to pass.

# The two-hour aura is said to have no timer.
mutate("Commands.lua",
       "\t\t\tif not family.bagged and not family.timed then\n",
       "\t\t\tif not family.timed then\n",
       "options-fixes: Well-Rested said to have no timer",
       expect="options-fix: Well-Rested is not said to have no timer",
       script=S)

# Myself works to the setting for other people, not the queue's.
mutate("Commands.lua",
       "\t\t\twhenBuffed = ns.SelfWhenBuffed(db.filters), refreshUnder = db.filters.refreshUnder }\n",
       "\t\t\twhenBuffed = db.filters.whenBuffed, refreshUnder = db.filters.refreshUnder }\n",
       "options-fixes: Myself ignores the own top-up switch",
       expect="options-fix: Myself says your armor's top-up is due",
       script=S)

# The moment printed leaves out the player's earlier one.
mutate("Commands.lua",
       "\t\t\t\t\t\t\t:format(name, Text(seconds), Text(Earlier(Lead(seconds, KIND.own, ceiling), seconds)),\n",
       "\t\t\t\t\t\t\t:format(name, Text(seconds), Text(Lead(seconds, KIND.own, ceiling)),\n",
       "options-fixes: the top-up moment leaves out the earlier one",
       expect="options-fix: When a top-up is due gives your armor the selfLead moment",
       script=S)

# The heading says top-ups are off above own buffs that are topped up.
mutate("Commands.lua",
       "\t\tif ns.SelfWhenBuffed(db.filters) == \"refresh\" then\n",
       "\t\tif false then\n",
       "options-fixes: the heading says top-ups are off over own buffs",
       expect="options-fix: the top-up heading does not say off",
       script=S)

# The check-up leaves the PvP list's names in clear.
mutate("Options/Diagnostics.lua",
       "\tpcall(function() Heard(ns.PvPLines()) end)\n",
       "",
       "options-fixes: a player held back for PvP named in the check-up",
       expect="options-fix: the full check-up does not name a player held back for PvP",
       script=S)

# ... and the chat requests'.
mutate("Options/Diagnostics.lua",
       "\tpcall(function() Heard(ns.RequestLines()) end)\n",
       "",
       "options-fixes: somebody who asked named in the check-up",
       expect="options-fix: the full check-up does not name somebody who asked",
       script=S)

# The report's own headings are aliased too.
mutate("Options/Diagnostics.lua",
       "\t\tfixed[#lines] = true\n\t\tlocal ok, err = pcall(fn)\n",
       "\t\tlocal ok, err = pcall(fn)\n",
       "options-fixes: a name overwrites the report's headings",
       expect="options-fix: a player named Bug leaves the check-up's own words alone",
       script=S)

# A name inside a longer word is aliased too.
mutate("Options/Diagnostics.lua",
       "local function Part(c) return c ~= \"\" and c:find(\"[%w_\\128-\\255]\") ~= nil end\n",
       "local function Part(c) return false end\n",
       "options-fixes: a name inside a longer word is aliased",
       expect="options-fix: a player named Intel leaves the word Intellect alone",
       script=S)

# A slider box reads only the English unit letters back.
mutate("Options/Window/WidgetsEntry.lua",
       "\tLearnLocaleLetters()\n\tlocal clean = ",
       "\tlocal clean = ",
       "options-fixes: a slider box misreads its own unit words",
       expect="options-fix: a slider box left untouched keeps its value in the client's language",
       script=S)

# Food still offered outside has no default to be marked against.
mutate("Options/Window/WindowPage.lua",
       "\t[\"who.ownFoodOutside\"] = { { \"ownBuffs\", \"foodOutside\" } },\n",
       "",
       "options-fixes: Food still offered outside never marked as changed",
       expect="options-fix: Food still offered outside dungeons and raids, changed, is marked and listed",
       script=S)

# The consumables button, its key, Which food and own items last hidden from
# a class with nothing for others.
mutate("Options/Who.lua",
       "\t\t\tor key == \"ownApart\" or key == \"ownApartKey\" or key == \"ownFoodChoice\" or key == \"ownItemsLast\"\n",
       "",
       "options-fixes: own consumable controls hidden with nothing for others",
       expect="options-fix: a class with nothing for others still sees the consumables button",
       script=S)

# Who to buff leaves the sidebar once a res-only class turns its res off.
mutate("Options/Who.lua",
       " and not Page.OwnSwitchWaiting() and not ResLearned() end,\n",
       " and not Page.OwnSwitchWaiting() end,\n",
       "options-fixes: Who to buff hidden with the res switch off",
       expect="options-fix: a class with only its resurrection keeps Who to buff",
       script=S)

# My own buffs' reset leaves Which pet alone.
mutate("Options/Advanced.lua",
       "\t\"ownBuffs.petChoice\",\n",
       "",
       "options-fixes: the self reset leaves Which pet",
       expect="options-fix: My own buffs' reset puts Which pet back",
       script=S)

# The food and elixir lists never count as changed.
mutate("Options/Window/WindowPage.lua",
       "\t[\"who.own_leave_food\"] = function() return AnyTicked(Profile().ownBuffs.leave, FoodKeys()) end,\n"
       "\t[\"who.own_elixirkeep\"] = function() return AnyTicked(Profile().ownBuffs.elixirKeep) end,\n",
       "",
       "options-fixes: the food and elixir lists never marked",
       expect="options-fix: What I changed names the food and elixir lists a tick is in",
       script=S)

# A food tick counts the other Never remind me about as changed.
mutate("Options/Window/WindowPage.lua",
       "\t\t\tif foods[key] then on = false end\n",
       "",
       "options-fixes: a food tick marks the other list",
       expect="options-fix: What I changed names the food and elixir lists a tick is in",
       script=S)
