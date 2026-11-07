# Mutations for "Never remind me about" (ownBuffs.leave): the rule in Core.lua
# (LeftOut, FirstKnown, Remembered, AutoAnswer, OwnAutoPick, OwnVerdict,
# OwnReminds), the defaults and the repair, the control on Who to buff, its
# place in the layout, the page's reset and marker, the settings string, and
# what /manners debug and Diagnostics say. Each is caught by the scenario in
# tests/scenarios/ownleave.lua (or the two at the end of ownbuffs.lua) that
# names it.

S = "runscenarios.py"

# --- Automatic skips what is ticked ---

mutate("Core.lua",
       "\t\t\tif Known(spell) and not (auto and (spell.neverAuto or LeftOut(spell))) then return spell end\n",
       "\t\t\tif Known(spell) and not (auto and spell.neverAuto) then return spell end\n",
       "ownleave: Automatic's first pick ignores the tick",
       expect="ownleave: a spell ticked is skipped", script=S)

mutate("Core.lua",
       "\t\tif spell and spell.family == family and not spell.neverAuto and Known(spell) and not LeftOut(spell)\n",
       "\t\tif spell and spell.family == family and not spell.neverAuto and Known(spell)\n",
       "ownleave: the one you had up last is offered though ticked",
       expect="ownleave: a spell ticked is skipped", script=S)

mutate("Core.lua",
       "\t\tif preferred and LeftOut(preferred) then preferred = nil end\n",
       "",
       "ownleave: a dungeon's armor offered though ticked",
       expect="own: an armor ticked under Never remind me about", script=S)

mutate("Core.lua",
       "\t\t\t\tif spell ~= preferred and Known(spell) and not spell.neverAuto and not LeftOut(spell) then\n",
       "\t\t\t\tif spell ~= preferred and Known(spell) and not spell.neverAuto then\n",
       "ownleave: the world's armor offered though ticked",
       expect="own: an armor ticked under Never remind me about", script=S)

mutate("Core.lua",
       "\t\t\t\tif other ~= spell and Known(other) and not other.neverAuto and not LeftOut(other)\n"
       "\t\t\t\t\tand not OthersOnYou(other) then\n",
       "\t\t\t\tif other ~= spell and Known(other) and not other.neverAuto\n"
       "\t\t\t\t\tand not OthersOnYou(other) then\n",
       "ownleave: a ticked aura offered in place of one covered",
       expect="own: a shared aura ticked under Never remind me about", script=S)

# --- never offered, whatever the pick ---

mutate("Core.lua",
       "\t\tif spell and LeftOut(spell) then return nil, up, nil, \"leftout\", spell end\n",
       "",
       "ownleave: a pinned spell offered though ticked",
       expect="ownleave: a spell pinned and ticked", script=S)

mutate("Core.lua",
       "\t\treturn type(leave) == \"table\" and leave[spell.key] == true\n",
       "\t\treturn false\n",
       "ownleave: the tick is never read",
       expect="ownleave: a spell ticked is skipped", script=S)

# --- whether a family still counts as a reminder ---

mutate("Core.lua",
       "\t\tif spell then return not LeftOut(spell) end\n",
       "\t\tif spell then return true end\n",
       "ownleave: a pinned and ticked family still counts",
       expect="ownleave: a spell pinned and ticked", script=S)

mutate("Core.lua",
       "\t\t\tif Known(each) and not LeftOut(each) then return true end\n",
       "\t\t\tif Known(each) then return true end\n",
       "ownleave: a family with everything ticked still counts",
       expect="ownleave: every spell of a kind ticked", script=S)

mutate("Core.lua",
       "\t\t\tif ns.OwnReminds(family) then count = count + 1 end\n",
       "\t\t\tif ns.OwnPick(family) ~= \"off\" then count = count + 1 end\n",
       "ownleave: Myself counts a family with everything ticked",
       expect="ownleave: Sense Undead alone", script=S)

mutate("Options/Start.lua",
       "\t\tif ns.OwnReminds(family) then\n",
       "\t\tif ns.OwnPick(family) ~= \"off\" then\n",
       "ownleave: Start here names a family with everything ticked",
       expect="ownleave: Start here names only the families", script=S)

# --- the defaults and the repair ---

mutate("Core.lua",
       "\t\t\tfor _, spell in ipairs(family.spells) do defaults.profile.ownBuffs.leave[spell.key] = false end\n",
       "",
       "ownleave: no defaults for the ticks",
       expect="ownleave: every spell of a family of several has a false", script=S)

mutate("Core.lua",
       "\t\tif ns.OwnLeaveable(family) then\n\t\t\tfor _, spell in ipairs(family.spells) do defaults",
       "\t\tif true then\n\t\t\tfor _, spell in ipairs(family.spells) do defaults",
       "ownleave: a scroll or an enhancement can be ticked",
       expect="ownleave: every spell of a family of several has a false", script=S)

mutate("Buffs.lua",
       "\treturn family ~= nil and #family.spells > 1 and not (family.scroll or family.enhance or family.imbue\n"
       "\t\tor family.tank or family.bagged)\n",
       "\treturn family ~= nil and #family.spells > 1\n",
       "ownleave: a family of items is leaveable",
       expect="ownleave: every spell of a family of several has a false", script=S)

mutate("Core.lua",
       "\t\tif not ns.FindOwnSpell(key) then\n\t\t\town.leave[key] = nil\n",
       "\t\tif false then\n\t\t\town.leave[key] = nil\n",
       "ownleave: a spell nobody has kept",
       expect="ownleave: a hand-edited file", script=S)

mutate("Core.lua",
       "\t\telseif value ~= true and value ~= false then\n\t\t\town.leave[key] = false\n",
       "\t\telseif false then\n\t\t\town.leave[key] = false\n",
       "ownleave: nonsense tick kept",
       expect="ownleave: a hand-edited file", script=S)

mutate("Core.lua",
       "\t\tif own.leave[key] == nil then own.leave[key] = false end\n",
       "",
       "ownleave: a missing tick not given a false",
       expect="ownleave: a hand-edited file", script=S)

mutate("Core.lua",
       "\tif type(own.leave) ~= \"table\" then own.leave = {} end\n",
       "",
       "ownleave: a table that is not a table kept",
       expect="ownleave: a hand-edited file", script=S)

# --- sharing ---

mutate("Buffs.lua",
       "\t\t\tfor _, spell in ipairs(family.spells or {}) do ns.OWN_SPELL_ANY_CLIENT[spell.key] = true end\n",
       "",
       "ownleave: no spell known across clients",
       expect="ownleave: the ticks travel", script=S)

mutate("Commands.lua",
       "\t\t\t\t\tor (ns.OWN_SPELL_ANY_CLIENT or {})[name:match(\"^ownBuffs%.leave%.([%w_]+)$\") or \"\"] then\n",
       "\t\t\t\t\tor false then\n",
       "ownleave: another client's tick called newer",
       expect="ownleave: the ticks travel", script=S)

# --- the page ---

mutate("Options/Who.lua",
       "\t\t\tns.db.profile.ownBuffs.leave[key] = on and true or false\n",
       "\t\t\tns.db.profile.ownBuffs.leave[key] = false\n",
       "ownleave: a box ticked writes nothing",
       expect="ownleave: the page lists the spells you know", script=S)

mutate("Options/Who.lua",
       "\t\t\t\t\tif ns.OwnSpellKnown(spell) then values[spell.key] = ns.BuffName(spell) end\n",
       "\t\t\t\t\tvalues[spell.key] = ns.BuffName(spell)\n",
       "ownleave: spells you do not know on the list",
       expect="ownleave: the page lists the spells you know", script=S)

mutate("Options/Who.lua",
       "\t\thidden = function() return next(LeaveChoices()) == nil end,\n",
       "\t\thidden = function() return false end,\n",
       "ownleave: the control shown with nothing to tick",
       expect="ownleave: the control is hidden", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t{ \"who.own_leave\", indent = true },\n",
       "",
       "ownleave: the control not placed on the page",
       expect="own_leave", script=S)

mutate("Options/Advanced.lua",
       "\"ownBuffs.pick\", \"ownBuffs.leave\", \"ownBuffs.inCities\",",
       "\"ownBuffs.pick\", \"ownBuffs.inCities\",",
       "ownleave: the page's reset leaves the ticks",
       expect="ownleave: the page's reset", script=S)

mutate("Options/Window/WindowPage.lua",
       "\t\t\tif on == true then return true end\n",
       "\t\t\tif on == true then return false end\n",
       "ownleave: a tick does not mark the fold",
       expect="ownleave: the page's reset", script=S)

# --- what is said ---

mutate("Commands.lua",
       "\t\t\treturn L[\"%s: %s is ticked under Never remind me about.\"]:format(label, name or \"?\")\n",
       "\t\t\treturn L[\"%s: Automatic has nothing it would pick.\"]:format(label)\n",
       "ownleave: /manners debug quiet about a ticked spell",
       expect="ownleave: a spell pinned and ticked", script=S)

mutate("Options/Diagnostics.lua",
       "\t\tlines[#lines + 1] = \"own leftOut=\" .. table.concat(left, \",\")\n",
       "\t\tlines[#lines + 1] = \"own leftOut=\" .. table.concat(left, \";\")\n",
       "ownleave: Diagnostics joins the ticks wrongly",
       expect="ownleave: the Diagnostics report", script=S)
