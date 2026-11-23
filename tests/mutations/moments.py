# Mutations for the buttons for the moment, the framework:
# tests/scenarios/moments.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts one guard back to
# its absence and names the scenario that objects.

S = "runscenarios.py"
M = "Prompt/Moments.lua"
SENSE = "Prompt/MomentsSense.lua"

mutate(M,
       '\t\t\tslot.cover:SetShown(slot.mouseOn == true)\n',
       '\t\t\tslot.cover:Hide()\n',
       "moments: the cover is not put up at the pull",
       expect="moments: no key: the cover is up while dark", script=S)

mutate(M,
       '\t\treturn true\n\tend\n\treturn false\nend\n\n-- The icon of a button',
       '\t\treturn true\n\tend\n\treturn true\nend\n\n-- The icon of a button',
       "moments: the cover is left up while lit",
       expect="moments: no key: lit, the click reaches the button and casts", script=S)

mutate(M,
       '\t\t\t\tslot.face:SetAlpha(0)\n\t\t\t\tslot.fading, slot.fadeTo, slot.openUntil = false, 0, nil\n',
       '\t\t\t\tslot.face:SetAlpha(db.prompt.fightButtons == "always" and 1 or 0)\n\t\t\t\tslot.fading, slot.fadeTo, slot.openUntil = false, 0, nil\n',
       "moments: Show the fight buttons is read and a button sits there all fight",
       expect="moments: Show the fight buttons at All fight changes nothing", script=S)

mutate(M,
       'function Moments:Wanted()\n\tlocal mine = caps.moments\n',
       'function Moments:Wanted()\n\tif InCombatLockdown() then return false end\n\tlocal mine = caps.moments\n',
       "moments: a scan asks the lockdown first",
       expect="moments: not a mage: nothing made", script=S)

mutate(M,
       '\t\tif ev then ev:UnregisterEvent(name) end\n\t\tfightEvents[name] = nil\n',
       '\t\tfightEvents[name] = nil\n',
       "moments: the fight's events are not dropped at the release",
       expect="moments: events are registered at the pull and gone at the release", script=S)

mutate(M,
       '\tif not Sense.accepted[name] or fightEvents[name] then return end\n',
       '\tif fightEvents[name] then return end\n',
       "moments: an unprobed event name is registered directly",
       expect="moments: an event name the client lacks is skipped", script=S)

mutate(M,
       '\t\t\t\tfor _, name in ipairs(TARGET_CAST) do Register(name, "target") end\n',
       '\t\t\t\tfor _, name in ipairs(TARGET_CAST) do Register(name) end\n',
       "moments: the cast events are heard for every unit",
       expect="moments: a cast event for another unit does nothing", script=S)

mutate(M,
       '\tif slot.keyLabel == nil and slot.cover:IsShown() then\n',
       '\tif false then\n',
       "moments: the leak check is removed",
       expect="moments: a click that gets past the cover is counted", script=S)

mutate(M,
       '\t\tif slot and slot.armed and slot.tally.leak > 0 and not told then\n',
       '\t\tif slot and slot.armed and slot.tally.leak > 0 then\n',
       "moments: the leak is told after every fight",
       expect="moments: a click that gets past the cover is counted", script=S)

mutate("Core.lua",
       '\t\tmoments = { counterspell = true, spellsteal = true,',
       '\t\tmoments = { counterspell = false, spellsteal = true,',
       "moments: a default is flipped in Core.lua",
       expect="moments: the data's defaults are the profile's defaults", script=S)

mutate(M,
       '\t\tslot.inner:SetAlpha(1)\n\t\tslot.state = "lit"\n',
       '\t\tslot.button:SetAlpha(1)\n\t\tslot.inner:SetAlpha(1)\n\t\tslot.state = "lit"\n',
       "moments: the button's own alpha is written when it lights",
       expect="moments: the button's own alpha is never written", script=S)

mutate(M,
       '\t\tslot.inner:SetAlpha(1)\n\t\tslot.state = "lit"\n',
       '\t\tslot.button:Show()\n\t\tslot.inner:SetAlpha(1)\n\t\tslot.state = "lit"\n',
       "moments: the button is shown from Lua in a fight",
       expect="moments: nothing protected is called under the lockdown", script=S)

mutate(M,
       '\tbutton:EnableMouse(false)\n\tfor i = 2, 31 do\n',
       '\tbutton:EnableMouse(false)\n\tbutton:SetHighlightTexture(HOVER)\n\tfor i = 2, 31 do\n',
       "moments: a highlight texture is put back on the button",
       expect="moments: the button's own alpha is never written and it has no highlight texture", script=S)

mutate(M,
       '\tif slot.state ~= "lit" then return end\n\tlocal tip = _G.GameTooltip\n',
       '\tlocal tip = _G.GameTooltip\n',
       "moments: the tooltip shows in a game-painted state",
       expect="moments: hover while dark shows no highlight", script=S)

mutate(M,
       '\tif slot.state == "dark" then return end\n\tslot.hover:Show()\n',
       '\tslot.hover:Show()\n',
       "moments: the highlight shows while dark",
       expect="moments: hover while dark shows no highlight", script=S)

mutate(M,
       '\tif pending and ns.ExpirePendingClick then\n',
       '\tif false then\n',
       "moments: a press does not let the prompt's waiting press go",
       expect="moments: a press lets the prompt's waiting press go", script=S)

mutate(SENSE,
       '\tif refused[kind] then return false end\n\tif kind == "not" or kind == "is" then',
       '\tif kind == "not" or kind == "is" then',
       "moments: a refused paint is tried again",
       expect="moments: a paint call the game refuses is tried once", script=S)

mutate(M,
       'b:SetPoint("RIGHT", anchor, "LEFT", -(10 + col * step), rowN * step)',
       'b:SetPoint("LEFT", anchor, "RIGHT", 10 + col * step, rowN * step)',
       "moments: the row sits right of the prompt",
       expect="moments: the row sits left of the prompt", script=S)

mutate(M,
       '\t\tside = queueAbove and "below" or "above"\n',
       '\t\tside = queueAbove and "above" or "below"\n',
       "moments: the row goes over the list of names",
       expect="moments: no room on the left with the list above puts the row below the prompt", script=S)

mutate(M,
       '\tlocal on = slot.keyLabel == nil\n',
       '\tlocal on = true\n',
       "moments: the mouse stays on with a key bound",
       expect="moments: a key bound turns the mouse off", script=S)

mutate("Prompt/MomentsData.lua",
       'Row { key = "blink", slot = 3, ranks = { 1953 }, stop = true, blind = "weak", cooldown = 15,',
       'Row { key = "blink", slot = 2, ranks = { 1953 }, stop = true, blind = "weak", cooldown = 15,',
       "moments: two rows share a slot",
       expect="moments: every slot number is unique", script=S)

mutate(M,
       '\treturn (row.stop and "/stopcasting\\n" or "") .. "/cast " .. slot.name\n',
       '\treturn (row.stop and "/stopcasting\\n" or "") .. "/cast [harm,nodead] " .. slot.name\n',
       "moments: a conditional is put in the macro",
       expect="moments: the armed macros of the built buttons", script=S)

mutate(M,
       '\t\t\t\tif not slots[entry.row.slot] then Create(entry.row.slot) end\n',
       '\t\t\t\tCreate(entry.row.slot)\n\t\t\t\tfor n = 1, MAX do if not slots[n] then Create(n) end end\n',
       "moments: a button is made for every slot, learned or not",
       expect="moments: a row not learned has no button", script=S)
