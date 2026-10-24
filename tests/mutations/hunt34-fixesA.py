# Hunt 34, fixes A (tests/scenarios/hunt33-clickui.lua, hunt33-decision.lua,
# hunt33-rows.lua, hunt33-weapons.lua and hunt34-fixesA.lua): the release of a
# held key (Prompt/Press.lua), a reload in a fight (Favours.lua), a /manners try
# macro from a name (Prompt/Macro.lua, Commands.lua), a hand let go when the cast
# succeeds (Core.lua, Clicks.lua), the singular group tooltip
# (Prompt/Button.lua), the name's room (Prompt/Text.lua and the looks) and the
# lines a language gives a man's voice (Phrases.lua). Each fault put back has to be
# caught by the scenario that names it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# ------------------------------------------------ the release of a held key
mutate("Prompt/Press.lua",
       "\tif down == false then return end\n\tif mouseButton and mouseButton ~= \"LeftButton\" then return end\n\tlocal now = GetTime()\n",
       "\tif mouseButton and mouseButton ~= \"LeftButton\" then return end\n\tlocal now = GetTime()\n",
       "hunt34-press: PreClick takes the release of a key for a press",
       expect="hunt33-press: the release of a", script=S)

mutate("Prompt/Press.lua",
       "\tif down == false then return end\n\t-- Whose press this is",
       "\t-- Whose press this is",
       "hunt34-press: PostClick files the release of a key as a press",
       expect="hunt33-press: the release of a", script=S)

# A click with no phase at all (a script's) is a press: only a false is an up.
mutate("Prompt/Press.lua",
       "\tif down == false then return end\n\tif mouseButton and mouseButton ~= \"LeftButton\" then return end\n\tlocal now = GetTime()\n",
       "\tif not down then return end\n\tif mouseButton and mouseButton ~= \"LeftButton\" then return end\n\tlocal now = GetTime()\n",
       "hunt34-press: a click with no phase taken for a release (PreClick)",
       expect="hunt34-press: a click with no down or up is a press", script=S)

mutate("Prompt/Press.lua",
       "\tif down == false then return end\n\t-- Whose press this is",
       "\tif not down then return end\n\t-- Whose press this is",
       "hunt34-press: a click with no phase taken for a release (PostClick)",
       expect="hunt34-press: a click with no down or up is a press", script=S)

# ------------------------------------------------ a reload in a fight
mutate("Favours.lua",
       "\t\t\t\t\tprimedBlind[instanceId] = key == true or nil\n",
       "",
       "hunt34-favours: a baseline primed withheld never adopts the spell",
       expect="hunt33-favours: a reload in a fight does not turn what you already wear into favours", script=S)

# An adopted aura that took the new end as the filed one: a recast looks like a refresh.
mutate("Favours.lua",
       "\t\t\t\t\t\tknownAuras[instanceId] = spellId\n",
       "\t\t\t\t\t\tknownAuras[instanceId] = spellId\n\t\t\t\t\t\tknownUntil[instanceId] = expires\n",
       "hunt34-favours: a recast that moved the end taken for the same aura",
       expect="hunt34-favours: a buff recast during the fight a reload happened in is still a favour", script=S)

# ------------------------------------------------ a try macro from a name
mutate("Prompt/Macro.lua",
       "\t\tlocal text, unfilled = ns.ExpandTokens(ns.tryMacro, entry)\n\t\tif not text then\n\t\t\t-- A template",
       "\t\tlocal text, unfilled = ns.ExpandTokens(ns.tryMacro)\n\t\tif not text then\n\t\t\t-- A template",
       "hunt34-rows: a try macro from a name filled from the prompt's person",
       expect="hunt33-rows: a /manners try macro pressed from a name", script=S)

mutate("Commands.lua",
       "\tentry = entry or ns.lastTopEntry\n",
       "\tentry = ns.lastTopEntry\n",
       "hunt34-rows: ExpandTokens ignoring the entry it is given",
       expect="hunt33-rows: a /manners try macro pressed from a name", script=S)

# ------------------------------------------------ a hand let go when the cast succeeds
mutate("Clicks.lua",
       "\t\tns.EndScrollPress(done.spell)\n",
       "",
       "hunt34-weapons: a hand held busy after the cast succeeded",
       expect="hunt33-weapons: the hand is let go when the cast succeeds", script=S)

mutate("Core.lua",
       "\tfunction ns.EndScrollPress(spell)\n\t\tif spell.family.enhance then busyUntil[spell.family.slot] = nil end\n",
       "\tfunction ns.EndScrollPress(spell)\n",
       "hunt34-weapons: EndScrollPress letting nothing go",
       expect="hunt33-weapons: the hand is let go when the cast succeeds", script=S)

# ------------------------------------------------ one of a group
mutate("Prompt/Button.lua",
       "\t\tif missing == 1 then\n\t\t\tcount = L[\"1 in %s is missing %s.\"]:format(label, single)\n",
       "\t\tif false then\n\t\t\tcount = L[\"1 in %s is missing %s.\"]:format(label, single)\n",
       "hunt34-text: one person missing the buff read as are",
       expect="hunt33-text: a group tooltip does not say one person are", script=S)

mutate("Prompt/Button.lua",
       "\t\telseif low == 1 then\n\t\t\tcount = L[\"1 in %s is running out of %s.\"]:format(label, single)\n",
       "\t\telseif false then\n\t\t\tcount = L[\"1 in %s is running out of %s.\"]:format(label, single)\n",
       "hunt34-text: one person running out read as are",
       expect="hunt34-text: the tooltip for a party with 0 missing and 1 running out says is", script=S)

mutate("Prompt/Button.lua",
       "low == 1 and L[\"1 more is running out.\"] or L[\"%d more are running out.\"]:format(low)",
       "L[\"%d more are running out.\"]:format(low)",
       "hunt34-text: one more person running out read as are",
       expect="hunt33-text: a group tooltip does not say one person are", script=S)

# ------------------------------------------------ room for the name
mutate("Prompt/Text.lua",
       "\tlocal left = math.min(fit.textX, math.max(0, fit.width - MIN_ROOM - right))\n",
       "\tlocal left = fit.textX\n",
       "hunt34-layout: the name's left end never gives way to a big icon",
       expect="hunt34-layout: a big icon on a narrow panel leaves the name room in glass", script=S)

mutate("Prompt/Text.lua",
       "\tif on and fit.width - fit.textX - fit.chipRoom < MIN_ROOM then\n",
       "\tif false then\n",
       "hunt34-layout: a count chip drawn over a name with no room",
       expect="hunt34-layout: no count chip over a name with no room", script=S)

mutate("Looks/Arcane.lua",
       "\tlocal inset = math.min(right + (self:KeyShown() and self.keyRoom or 0), math.max(0, self.W - self.textX - 20))\n",
       "\tlocal inset = right + (self:KeyShown() and self.keyRoom or 0)\n",
       "hunt34-layout: Arcane's two points cross at 80 wide",
       expect="hunt34-layout: arcane keeps the name 20 units", script=S)

mutate("Looks/Toast.lua",
       "\tinset = math.min(inset, math.max(0, self.W - self.textX - 20))\n",
       "",
       "hunt34-layout: Toast's two points cross",
       expect="hunt34-layout: toast keeps the name 20 units", script=S)

mutate("Looks/Luxe.lua",
       "\tright = math.min(right, math.max(0, self.W - self.textX - 20))\n",
       "",
       "hunt34-layout: Luxe's two points cross",
       expect="hunt34-layout: luxe keeps the name 20 units", script=S)

mutate("Looks/Toast.lua",
       "\tlocal M = showIcon and math.min(H, math.max(24, math.floor(W * 0.5))) or 0\n",
       "\tlocal M = showIcon and H or 0\n",
       "hunt34-layout: Toast's medallion as tall as a narrow panel",
       expect="hunt33-layout: the name has room at 140x120, 13 pt, in toast", script=S)

