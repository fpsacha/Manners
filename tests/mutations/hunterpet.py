# Mutations for a hunter's pet (HunterPet.lua: care, the moments of Bond with
# my pet and the memory, and its hooks in Core.lua, Prompt/Macro.lua,
# Prompt/Press.lua, Prompt/Paint.lua, Prompt/Button.lua, Prompt/Refresh.lua,
# Options/Launcher.lua, Options/Who.lua and Options/Diagnostics.lua). Each is
# caught by the scenario in tests/scenarios/hunterpet.lua that names it.

S = "runscenarios.py"

# ------------------------------------------------ the settings
mutate("Core.lua",
       "\t\tbeast = {\n\t\t\tcall = true,\n",
       "\t\tbeast = {\n\t\t\tcall = false,\n",
       "hunterpet: Call off in a new profile",
       expect="hunterpet: call when no pet is out, after one was seen", script=S)

mutate("Options/Who.lua",
       "\tlocal function SelfOff() return S().self ~= true end\n",
       "\tlocal function SelfOff() return false end\n",
       "hunterpet: the care switches live with Myself off",
       expect="hunterpet: the switches are under Myself, for a hunter alone", script=S)

mutate("Options/Who.lua",
       "\t\t15.983, function() return NotHunter() or not ns.Beast.Feeds() end, SelfOff)\n",
       "\t\t15.983, nil, SelfOff)\n",
       "hunterpet: Feed Pet's switch shown where pets do not eat",
       expect="hunterpet: the switches are under Myself, for a hunter alone", script=S)

mutate("Options/Who.lua",
       "\tlocal function NotHunter() return not (ns.Beast and ns.Beast.IsHunter()) end\n",
       "\tlocal function NotHunter() return false end\n",
       "hunterpet: the switches shown to every class",
       expect="hunterpet: the switches are under Myself, for a hunter alone", script=S)

# ------------------------------------------------ the hooks
mutate("Core.lua",
       "\tif ns.Beast and ns.Beast.Live() then return true end\n",
       "",
       "hunterpet: a hunter with no aspect learned has no prompt for his pet",
       expect="hunterpet: call when no pet is out, after one was seen", script=S)

mutate("Core.lua",
       "\tif buff.beastInfo then return buff.beastInfo end\n",
       "",
       "hunterpet: the pet's care has no spell name",
       expect="hunterpet: call when no pet is out, after one was seen", script=S)

mutate("Prompt/Macro.lua",
       "\tif entry.care or entry.bond then return ns.BeastArm(R, S, entry) end\n",
       "",
       "hunterpet: the pet's care armed as a buff",
       expect="hunterpet: call when no pet is out, after one was seen", script=S)

mutate("Prompt/Macro.lua",
       "\tif entry.care or entry.bond then return ns.Beast.Summary(entry) end\n",
       "",
       "hunterpet: the tooltip says a buff's summary for the pet",
       expect="hunterpet: call when no pet is out, after one was seen", script=S)

mutate("Prompt/Macro.lua",
       "\t-- Nor a hunter's pet cared for (HunterPet.lua): out of a fight only.\n\tif entry.care or entry.bond then return nil end\n",
       "",
       "hunterpet: the fight's rota carries the pet's care",
       expect="hunterpet: call when no pet is out, after one was seen", script=S)

mutate("Prompt/Paint.lua",
       "\tif entry.care or entry.bond then return ns.Beast.Reason(entry) end\n",
       "",
       "hunterpet: the second line a buff's",
       expect="hunterpet: a press on a moment does the emote and is remembered", script=S)

mutate("Prompt/Press.lua",
       "\tif S.current and (S.current.care or S.current.bond) then return ns.Beast.Pressed(S, armedText) end\n",
       "",
       "hunterpet: a press filed as a buff's",
       expect="hunterpet: a press on a moment does the emote and is remembered", script=S)

mutate("Prompt/Press.lua",
       "\tif not ready and not InCombatLockdown() and S.current and S.current.bond and not S.current.item then\n",
       "\tif false then\n",
       "hunterpet: a moment held back by the cooldown",
       expect="hunterpet: a press on a moment does the emote and is remembered", script=S)

mutate("Prompt/Press.lua",
       "\t\t-- A hunter's pet's care or moment (HunterPet.lua), with shift, ctrl or\n"
       "\t\t-- neither: not now, and nobody skipped, listed or switched off.\n"
       "\t\tif S.current and (S.current.care or S.current.bond) and (S.isRow or Prompt:PanelName() == S.current.name) then\n"
       "\t\t\treturn ns.Beast.Dismiss(S)\n"
       "\t\tend\n"
       "\t\t-- Whoever the panel names, as the left press follows: under a red flash\n"
       "\t\t-- that is the person the flash is about, not the next one armed\n"
       "\t\t-- underneath.\n"
       "\t\tlocal victim = Prompt:PanelName() or (S.current and S.current.name)\n"
       "\t\t-- A name in the list skips that name, whoever the prompt is on.\n"
       "\t\tif S.isRow then victim = S.name end\n"
       "\t\t-- The panel still on the pet once the entry moved on: that one let go.\n"
       "\t\tif type(victim) == \"string\" and victim:find(\"^%?pet:\") then return ns.Beast.DismissName(victim, S) end\n",
       "\t\tlocal victim = Prompt:PanelName() or (S.current and S.current.name)\n"
       "\t\tif S.isRow then victim = S.name end\n",
       "hunterpet: a right-click on the pet skips a person",
       expect="hunterpet: a right-click lets it go", script=S)

mutate("Prompt/Button.lua",
       "\t\tif S.current.care or S.current.bond then\n\t\t\tfor _, line in ipairs(ns.Beast.ClickLines(S.current)) do",
       "\t\tif false then\n\t\t\tfor _, line in ipairs(ns.Beast.ClickLines(S.current)) do",
       "hunterpet: the tooltip offers a skip",
       expect="hunterpet: the tooltip and the launcher say what a press does", script=S)

mutate("Options/Launcher.lua",
       "\t\telseif entry.care or entry.bond then\n\t\t\t-- A hunter's pet (HunterPet.lua): not now, and nobody skipped or listed.\n",
       "\t\telseif false then\n\t\t\t-- A hunter's pet (HunterPet.lua): not now, and nobody skipped or listed.\n",
       "hunterpet: the launcher offers to skip the pet",
       expect="hunterpet: the tooltip and the launcher say what a press does", script=S)

mutate("Options/Launcher.lua",
       "\tif (reason == \"care\" or reason == \"bond\") and pet then return pet end\n",
       "",
       "hunterpet: the launcher calls the pet a passer-by",
       expect="hunterpet: the tooltip and the launcher say what a press does", script=S)

mutate("Options/Launcher.lua",
       "\telseif not HasClassBuffs() and ns.Beast and ns.Beast.Live() then\n",
       "\telseif false then\n",
       "hunterpet: the launcher watches nothing for a hunter with no aspect",
       expect="hunterpet: the tooltip and the launcher say what a press does", script=S)

mutate("Prompt/Refresh.lua",
       "\tif top.bond then isNew, becameOwed = false, false end\n",
       "",
       "hunterpet: a moment makes a sound",
       expect="hunterpet: a press on a moment does the emote and is remembered", script=S)

mutate("Options/Diagnostics.lua",
       "\tpcall(function() Heard(ns.BeastLines(GetTime())) end)\n",
       "",
       "hunterpet: the full check-up names the pet",
       expect="hunterpet: the memory and its milestones", script=S)

# ------------------------------------------------ care
mutate("HunterPet.lua",
       "\t\tif Unable() then return queue, verdicts end\n",
       "",
       "hunterpet: care offered to a ghost",
       expect="hunterpet: revive when the pet is dead, never for a ghost", script=S)

mutate("HunterPet.lua",
       "\tif Ask(_G.IsMounted) == true then return \"mounted\" end\n",
       "",
       "hunterpet: care offered while mounted",
       expect="hunterpet: no care on a taxi, mounted, feigning or settling", script=S)

mutate("HunterPet.lua",
       "\tif Ask(_G.UnitIsFeignDeath, \"player\") == true then return \"feigning\" end\n\tif Ask(_G.UnitCastingInfo",
       "\tif Ask(_G.UnitCastingInfo",
       "hunterpet: care offered while feigning death",
       expect="hunterpet: no care on a taxi, mounted, feigning or settling", script=S)

mutate("HunterPet.lua",
       "\tif now < clock.settleUntil then return \"settling\" end\n",
       "",
       "hunterpet: care offered in the settle after a dismount",
       expect="hunterpet: no care on a taxi, mounted, feigning or settling", script=S)

mutate("HunterPet.lua",
       "\tif ns.Resting() == true and db.ownBuffs.inCities ~= true then return \"resting\" end\n",
       "",
       "hunterpet: care offered in a city",
       expect="hunterpet: no care on a taxi, mounted, feigning or settling", script=S)

mutate("HunterPet.lua",
       "\tif now < clock.afterFight then return \"fight\" end\n\tif ns.Resting()",
       "\tif ns.Resting()",
       "hunterpet: care offered the moment a fight ends",
       expect="hunterpet: no care on a taxi, mounted, feigning or settling", script=S)

mutate("HunterPet.lua",
       "\tif db.sources.self ~= true then return \"myself\" end\n",
       "",
       "hunterpet: care offered with Myself off",
       expect="hunterpet: no care on a taxi, mounted, feigning or settling", script=S)

mutate("HunterPet.lua",
       "\tif Ask(_G.UnitCastingInfo, \"player\") ~= nil or Ask(_G.UnitChannelInfo, \"player\") ~= nil then return \"casting\" end\n",
       "",
       "hunterpet: care offered while a cast is under way",
       expect="hunterpet: no feed in the cooldown or while casting", script=S)

mutate("HunterPet.lua",
       "\t\tif beast.call == true and char.beastAway == nil and char.beastLast ~= nil and not Known(K.LONE_WOLF)\n",
       "\t\tif beast.call == true and char.beastAway == nil and not Known(K.LONE_WOLF)\n",
       "hunterpet: Call for a hunter who never had a pet",
       expect="hunterpet: lone wolf and petless", script=S)

mutate("HunterPet.lua",
       "char.beastLast ~= nil and not Known(K.LONE_WOLF)\n",
       "char.beastLast ~= nil\n",
       "hunterpet: Call with Lone Wolf",
       expect="hunterpet: lone wolf and petless", script=S)

mutate("HunterPet.lua",
       "\t\telseif K.CALLS[spell] then\n\t\t\tchar.beastCall, char.beastAway = spell, nil\n",
       "\t\telseif K.CALLS[spell] then\n\t\t\tchar.beastAway = nil\n",
       "hunterpet: Call Pet 1 whatever was called last",
       expect="hunterpet: lone wolf and petless", script=S)

mutate("HunterPet.lua",
       "\t\telseif K.DISMISS[spell] then\n\t\t\tchar.beastAway = \"dismissed\"\n",
       "\t\telseif K.DISMISS[spell] then\n",
       "hunterpet: a dismissed pet called back",
       expect="hunterpet: a pet you dismissed is not called back, across a reload", script=S)

mutate("HunterPet.lua",
       "\t\tif not wasOut then char.beastAway = nil end\n",
       "\t\tchar.beastAway = nil\n",
       "hunterpet: the dismiss forgotten while the pet is still leaving",
       expect="hunterpet: a pet you dismissed is not called back, across a reload", script=S)

mutate("HunterPet.lua",
       "\t\t\t\tif char then char.beastDead = st.name or char.beastLast or true end\n",
       "",
       "hunterpet: a pet taken away dead is called",
       expect="hunterpet: a pet that died in a fight is revived, not called", script=S)

mutate("HunterPet.lua",
       "\t\t\tchar.beastDead = nil\n\t\t\tclock.tamedAt = nil\n\t\t\tTrigger(ReviveMoment(), now)\n",
       "\t\t\tchar.beastDead = nil\n\t\t\tclock.tamedAt = nil\n",
       "hunterpet: no welcome after a revive",
       expect="hunterpet: revive when the pet is dead, never for a ghost", script=S)

mutate("HunterPet.lua",
       "\t\tchar.beastDead = st.name or char.beastLast or true\n\t\tns.MarkAttempted(\"?pet:call\", \"beast:call\", 0)\n",
       "\t\tns.MarkAttempted(\"?pet:call\", \"beast:call\", 0)\n",
       "hunterpet: \"your pet is dead\" never heard",
       expect="hunterpet: the game's refusals are learned", script=S)

mutate("HunterPet.lua",
       "\telseif what == \"nopet\" and press.kind == \"call\" then\n\t\tchar.beastAway = \"nopet\"\n",
       "\telseif what == \"nopet\" and press.kind == \"call\" then\n",
       "hunterpet: \"you have no pet\" never heard",
       expect="hunterpet: the game's refusals are learned", script=S)

mutate("HunterPet.lua",
       "\t\t\tif message ~= nil and plain(_G[name]) == message then\n",
       "\t\t\tif false then\n",
       "hunterpet: a refusal known only by its words",
       expect="hunterpet: the game's refusals are learned", script=S)

mutate("HunterPet.lua",
       "\t\tLearn(press.item, false)\n",
       "",
       "hunterpet: a food refused offered again",
       expect="hunterpet: the game's refusals are learned", script=S)

mutate("HunterPet.lua",
       "\tif not st.out or st.fighting then return nil end\n",
       "\tif not st.out then return nil end\n",
       "hunterpet: Mend while the pet still fights",
       expect="hunterpet: mend waits for its own heal and for the pet's fight", script=S)

mutate("HunterPet.lua",
       "\t\tand open(\"mend\") and not Wears(\"mendOn\", MEND_SET) and not MendOutOfRange() then\n",
       "\t\tand open(\"mend\") and not MendOutOfRange() then\n",
       "hunterpet: Mend over its own heal",
       expect="hunterpet: mend waits for its own heal and for the pet's fight", script=S)

mutate("HunterPet.lua",
       "\tMEND_BELOW = 0.5,\n",
       "\tMEND_BELOW = 0.7,\n",
       "hunterpet: Mend after every scratch",
       expect="hunterpet: mend waits for its own heal and for the pet's fight", script=S)

mutate("HunterPet.lua",
       "\t\tmendHeld = true\n",
       "",
       "hunterpet: Mend's not now forgotten at once",
       expect="hunterpet: a right-click lets it go", script=S)

mutate("HunterPet.lua",
       "\t\tmendHeld = false\n",
       "",
       "hunterpet: Mend's not now kept past the next fight",
       expect="hunterpet: a right-click lets it go", script=S)

# ------------------------------------------------ feed
mutate("HunterPet.lua",
       "local FEEDS = { camelot = true, vanilla = true, tbc = true }\n",
       "local FEEDS = { camelot = true, vanilla = true, tbc = true, mists = true }\n",
       "hunterpet: Feed on Mists",
       expect="hunterpet: feed when not happy, with a food it eats", script=S)

mutate("HunterPet.lua",
       "st.happy and st.happy < 3 and",
       "st.happy and st.happy <= 3 and",
       "hunterpet: Feed for a happy pet",
       expect="hunterpet: feed when not happy, with a food it eats", script=S)

mutate("HunterPet.lua",
       "\t\tif level >= floor and (not best or level < (best.level or 0)) then best = c end\n",
       "",
       "hunterpet: always the highest food",
       expect="hunterpet: feed when not happy, with a food it eats", script=S)

mutate("HunterPet.lua",
       "\t\telseif row and eats and eats[row[1]] then\n",
       "\t\telseif row then\n",
       "hunterpet: a food the pet's diet leaves out",
       expect="hunterpet: feed when not happy, with a food it eats", script=S)

mutate("HunterPet.lua",
       "\t\t\tif wellFed[item] then tier = 4 end\n",
       "",
       "hunterpet: Well Fed food fed away",
       expect="hunterpet: feed waits for the effect and keeps Well Fed food", script=S)

mutate("HunterPet.lua",
       "\t\tand not Wears(\"fedOn\", FED_SET) then\n",
       "\t\tthen\n",
       "hunterpet: Feed while the pet is still eating",
       expect="hunterpet: feed waits for the effect and keeps Well Fed food", script=S)

mutate("HunterPet.lua",
       "\t\ttext = text .. \"\\n/use item:\" .. entry.item\n",
       "",
       "hunterpet: Feed Pet with no food",
       expect="hunterpet: feed when not happy, with a food it eats", script=S)

# ------------------------------------------------ bond
mutate("HunterPet.lua",
       "\t\t\t\tTrigger(\"praise\", now)\n",
       "",
       "hunterpet: no praise after a hard fight",
       expect="hunterpet: a press on a moment does the emote and is remembered", script=S)

mutate("HunterPet.lua",
       "\t\t\tif char then char.beastBondAt = time() end\n",
       "",
       "hunterpet: a moment shown spends no gap",
       expect="hunterpet: a press on a moment does the emote and is remembered", script=S)

mutate("HunterPet.lua",
       "\t\tif rec then rec.pats = rec.pats + 1 end\n",
       "",
       "hunterpet: a pat not remembered",
       expect="hunterpet: a press on a moment does the emote and is remembered", script=S)

mutate("HunterPet.lua",
       "\tlocal lines = { EmoteCommand(m.kind) .. \" \" .. at }\n",
       "\tlocal lines = { EmoteCommand(m.kind) .. \" pet\" }\n",
       "hunterpet: the emote aimed at the pet token, which the chat box reads as a name",
       expect="hunterpet: a press on a moment does the emote and is remembered", script=S)

mutate("HunterPet.lua",
       "\tlocal line = st.family and REACT[st.family]\n",
       "\tlocal line = nil\n",
       "hunterpet: every pet answers alike",
       expect="hunterpet: a press on a moment does the emote and is remembered", script=S)

mutate("HunterPet.lua",
       "\treturn now - moment.at >= (K.EXPIRE[moment.kind] or 60)\n",
       "\treturn false\n",
       "hunterpet: a moment waits for ever",
       expect="hunterpet: a moment expires unseen", script=S)

mutate("HunterPet.lua",
       "\t\t\tif st.health and st.health < K.COMFORT_BELOW then\n",
       "\t\t\tif false then\n",
       "hunterpet: no comfort after a near death",
       expect="hunterpet: comfort after a fight the pet barely lived through", script=S)

mutate("HunterPet.lua",
       "\tif type(speed) ~= \"number\" or speed <= 0 then return end\n",
       "",
       "hunterpet: a road moment for a player standing still",
       expect="hunterpet: road needs a moving player", script=S)

mutate("HunterPet.lua",
       "\tif Ask(_G.UnitIsAFK, \"player\") == true then return end\n",
       "",
       "hunterpet: a road moment for a player away",
       expect="hunterpet: road needs a moving player", script=S)

mutate("HunterPet.lua",
       "\tif not (type(speech) == \"table\" and speech.enabled == true and speech.channel == \"SAY\") then return false end\n",
       "\tif not (type(speech) == \"table\" and speech.enabled == true) then return false end\n",
       "hunterpet: the line in /say whatever the channel",
       expect="hunterpet: the line follows the player's channel", script=S)

mutate("HunterPet.lua",
       "\tif speech.onlyWhenReturning == true then return false end\n",
       "",
       "hunterpet: the line said with only favours returned",
       expect="hunterpet: the line follows the player's channel", script=S)

mutate("HunterPet.lua",
       "\tif not (RP and RP.Active and RP.Active(speech)) then return false end\n",
       "",
       "hunterpet: the line said with In character off",
       expect="hunterpet: the line follows the player's channel", script=S)

mutate("HunterPet.lua",
       "\t\t\tm.line, m.source = Beast.Words(K.WORDS[m.kind] or \"pet\", name, room)\n",
       "\t\t\tm.line, m.source = Beast.Words(\"pet\", name, room)\n",
       "hunterpet: the road's words for every moment",
       expect="hunterpet: the line follows the player's channel", script=S)

mutate("HunterPet.lua",
       "\t\t\t\t\tGreet(at)\n",
       "",
       "hunterpet: no hello with the pet out at login",
       expect="hunterpet: hello at login, good morning after a night at the inn", script=S)

mutate("HunterPet.lua",
       "\t\tif char and st.out and st.name and On(Switches(Profile()), \"morning\") and ns.Resting() == true and ns.InCity() == false then\n",
       "\t\tif char and st.out and st.name and On(Switches(Profile()), \"morning\") and ns.Resting() == true then\n",
       "hunterpet: a logout in a city kept as a night at the inn",
       expect="hunterpet: hello at login, good morning after a night at the inn", script=S)

mutate("HunterPet.lua",
       "\t\tif char then char.beastNight = nil end\n\t\tif a == true then\n",
       "\t\tif a == true then\n",
       "hunterpet: a reload keeps the night for the next login",
       expect="hunterpet: hello at login, good morning after a night at the inn", script=S)

mutate("HunterPet.lua",
       "\tTrigger(clock.morning and st.name == clock.morning and \"morning\" or \"hello\", now)\n",
       "\tTrigger(\"hello\", now)\n",
       "hunterpet: never good morning",
       expect="hunterpet: hello at login, good morning after a night at the inn", script=S)

# ------------------------------------------------ the memory
mutate("HunterPet.lua",
       "\tif type(name) ~= \"string\" or name == \"\" or name == _G.UNKNOWNOBJECT or name == _G.UNKNOWN then name = nil end\n",
       "\tif type(name) ~= \"string\" or name == \"\" then name = nil end\n",
       "hunterpet: a pet called Unknown remembered",
       expect="hunterpet: a pet the client calls Unknown is never remembered", script=S)

mutate("HunterPet.lua",
       "\t\t\tif rec then rec.fights = rec.fights + 1 end\n",
       "",
       "hunterpet: a fight not remembered",
       expect="hunterpet: a press on a moment does the emote and is remembered", script=S)

mutate("HunterPet.lua",
       "\t\t\taddon:Print(m[4] and m[3]:format(name, reached) or m[3]:format(reached, name))\n",
       "",
       "hunterpet: a milestone never said",
       expect="hunterpet: the memory and its milestones", script=S)

# ------------------------------------------------ review fixes
mutate("HunterPet.lua",
       "\t\tanswer = type(ns.SpellKnown) == \"function\" and ns.SpellKnown(id) == true\n",
       "\t\tanswer = Ask(_G.IsPlayerSpell, id) == true or Ask(_G.IsSpellKnown, id) == true\n",
       "hunterpet: spells read only through the deprecated calls",
       expect="hunterpet: care with the deprecation fallbacks off", script=S)

mutate("HunterPet.lua",
       "\tif event == \"SPELLS_CHANGED\" then\n\t\tst.dirty = true\n\t\tknown = {}\n",
       "\tif event == \"SPELLS_CHANGED\" then\n\t\tst.dirty = true\n",
       "hunterpet: the spells known kept past a change of the spellbook",
       expect="hunterpet: care with the deprecation fallbacks off", script=S)

mutate("HunterPet.lua",
       "\tif BondHeld(now) then return end\n",
       "",
       "hunterpet: a road moment every half minute with no pet out",
       expect="hunterpet: no road moment with no pet out", script=S)

mutate("HunterPet.lua",
       "\t\t\tif renamed.from then Rename(char, name, st.family, now) end\n",
       "",
       "hunterpet: a renamed pet starts a new memory",
       expect="hunterpet: a renamed pet keeps its memory", script=S)

mutate("HunterPet.lua",
       "\treturn plain(usable) == false and plain(noMana) == true\n",
       "\treturn false\n",
       "hunterpet: care offered with no mana for it",
       expect="hunterpet: no care the game says you cannot pay for", script=S)

mutate("HunterPet.lua",
       "SPELL_FAILED_FOOD_LOWLEVEL = \"lowlevel\",",
       "SPELL_FAILED_FOOD_LOWLEVEL = \"food\",",
       "hunterpet: a food too low for the pet learned as never eaten",
       expect="hunterpet: a food too low for the pet is not learned", script=S)

mutate("HunterPet.lua",
       "\tif not st.family then\n\t\tguessed[item] = eats == true\n\t\treturn\n\tend\n"
       "\tif type(db.beastFood) ~= \"table\" then db.beastFood = {} end\n\tlocal key = tostring(st.family)\n",
       "\tif type(db.beastFood) ~= \"table\" then db.beastFood = {} end\n\tlocal key = tostring(st.family or \"?\")\n",
       "hunterpet: every pet of no family shares one food record",
       expect="hunterpet: a food too low for the pet is not learned", script=S)

mutate("HunterPet.lua",
       "\t\tLearn(press.item, false)\n\t\tpress.item = nil\n",
       "\t\tLearn(press.item, false)\n",
       "hunterpet: a refused food learned as eaten by the next meal",
       expect="hunterpet: only the food of a press just made is learned as eaten", script=S)

mutate("HunterPet.lua",
       " and press.at and now - press.at < K.FED_WINDOW then\n",
       " then\n",
       "hunterpet: a stale press learned as eaten",
       expect="hunterpet: only the food of a press just made is learned as eaten", script=S)

mutate("HunterPet.lua",
       "\t\t\tif not (fedAt and now - fedAt < K.MEAL_GAP) then\n",
       "\t\t\tif true then\n",
       "hunterpet: one feed counted as two meals",
       expect="hunterpet: one meal counted once", script=S)

mutate("HunterPet.lua",
       "\t\t\tif char then char.beastAway = \"nopet\" end\n\t\t\tns.Trail(\"pet\", \"the pet was abandoned\", nil)\n",
       "\t\t\tns.Trail(\"pet\", \"the pet was abandoned\", nil)\n",
       "hunterpet: an abandoned pet called",
       expect="hunterpet: an abandoned pet is not called", script=S)

mutate("HunterPet.lua",
       "\tif not held then kind, item = CareWanted(beast, char, now) end\n",
       "\tkind, item = CareWanted(beast, char, now)\n\tif held then kind = nil end\n",
       "hunterpet: the pet's auras and the bags read with care held",
       expect="hunterpet: the pet's auras are read only when care could be offered", script=S)

mutate("HunterPet.lua",
       "\tif st.auraDirty or not st.auraAt or now - st.auraAt >= K.READ_EVERY then\n",
       "\tif true then\n",
       "hunterpet: the pet's auras walked at every health tick",
       expect="hunterpet: the pet's auras are read only when care could be offered", script=S)
