# Mutations for the drink for the moment: tests/scenarios/moments-drink.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts one guard back to
# its absence and names the scenario that objects.

S = "runscenarios.py"
M = "Prompt/Moments.lua"
SENSE = "Prompt/MomentsSense.lua"
DATA = "Prompt/MomentsData.lua"

mutate(SENSE,
       '\tif Sense.fighting or InCombatLockdown() then return "no", "in a fight" end\n',
       '\tif false then return "no", "in a fight" end\n',
       "moments-drink: the calm signal never says a fight",
       expect="moments-drink: dark in a fight", script=S)

mutate(M,
       '\t\t\t\tif on and not self:GetAttribute("manners-calm-" .. i) then b:Show(true) else b:Hide(true) end\n',
       '\t\t\t\tif on then b:Show(true) else b:Hide(true) end\n',
       "moments-drink: the driver shows the drink for a fight",
       expect="moments-drink: dark in a fight", script=S)

mutate(M,
       '\t\t\tif slot.row.calm then Disarm(slot) end\n',
       '',
       "moments-drink: the pull leaves the drink's macro",
       expect="moments-drink: dark in a fight", script=S)

mutate(M,
       '\t\t\tSchedulePeace()\n\t\t\tbreak\n',
       '\t\t\tbreak\n',
       "moments-drink: a refresh does not light the drink until a mana tick",
       expect="moments-drink: dark in a fight", script=S)

mutate(M,
       '\t\tif event == "UNIT_POWER_UPDATE" then\n\t\t\tlocal kind = plain(a)\n\t\t\tif type(kind) == "string" and kind ~= "MANA" then return end\n\t\t\treturn SchedulePeace()\n\t\tend\n',
       '',
       "moments-drink: a mana event out of a fight is not heard",
       expect="moments-drink: lit out of a fight", script=S)

mutate(SENSE,
       '\tif not slot.drinkPick then return "no", "no drink in your bags" end\n',
       '',
       "moments-drink: no drink in the bags is not a reason",
       expect="moments-drink: no drink in the bags, or only food", script=S)

mutate(M,
       '\tlocal mana = wantCalmMana and peace\n',
       '\tlocal mana = wantCalm and peace\n',
       "moments-drink: the mana events are registered with no drink in the bags",
       expect="moments-drink: no drink in the bags, or only food", script=S)

mutate(SENSE,
       '\tif Sense.moving then return "no", "you are moving" end\n',
       '',
       "moments-drink: moving is no reason",
       expect="moments-drink: dark while moving", script=S)

mutate(SENSE,
       '\tif type(_G.IsMounted) == "function" and plain(_G.IsMounted()) == true then return "no", "you are mounted" end\n',
       '',
       "moments-drink: mounted is no reason",
       expect="moments-drink: dark while mounted", script=S)

mutate(SENSE,
       '\t\tif type(form) == "number" and form > 0 then return "no", "you are shapeshifted" end\n',
       '',
       "moments-drink: a form is no reason",
       expect="moments-drink: dark while mounted", script=S)

mutate(SENSE,
       '\t\t\t\tif type(rawAura) == "table" then slot.auraSeen = true return "no", "you are drinking" end\n',
       '',
       "moments-drink: the Drink aura on you is no reason",
       expect="moments-drink: dark while drinking: the aura read plainly", script=S)

mutate(SENSE,
       '\tif slot.castAt and now - slot.castAt < (slot.row.seconds or 0) then return "no", "you are drinking" end\n',
       '',
       "moments-drink: the clock of your own drink is not kept",
       expect="moments-drink: dark while drinking with the aura hidden", script=S)

mutate(SENSE,
       '\t\tif not pick and (row.level == nil or level == nil or row.level <= level) then\n',
       '\t\tif false then\n',
       "moments-drink: the conjured water is never looked for",
       expect="moments-drink: the macro picks the best conjured water", script=S)

mutate(SENSE,
       '\t\tif not pick and (row.level == nil or level == nil or row.level <= level) then\n',
       '\t\tif not pick then\n',
       "moments-drink: the level a water asks is not held to",
       expect="moments-drink: the macro picks the best conjured water", script=S)

mutate(SENSE,
       '\treturn plain(call(id)) ~= false\n',
       '\treturn true\n',
       "moments-drink: an unusable drink is picked",
       expect="moments-drink: a drink the game calls unusable", script=S)

mutate(M,
       '\t\t\tif slot.bagsDirty then\n',
       '\t\t\tif false then\n',
       "moments-drink: the bags are not counted again after a bag event",
       expect="moments-drink: the bags changing re-arms", script=S)

mutate(M,
       '\t\tif slot and slot.armed and slot.needs.falling then Judge(slot, now) end\n',
       '\t\tif slot and slot.armed and slot.row.peace == true then Judge(slot, now) end\n',
       "moments-drink: the fall watch judges the drink five times a second",
       expect="moments-drink: moving with Slow Fall on", script=S)

mutate(DATA,
       'calm = true, forms = forms, guard = "twice",',
       'calm = true, forms = forms,',
       "moments-drink: the drink takes one click where only the game knows",
       expect="moments-drink: hidden mana is handed to the game", script=S)

mutate(SENSE,
       '\tif type(max) == "number" and max == 0 then return "no", "you have no mana" end\n',
       '',
       "moments-drink: a bar of zero is low",
       expect="moments-drink: a mana bar of zero", script=S)
