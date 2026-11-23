# Mutations for Ice Block for the moment: tests/scenarios/moments-iceblock.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts one guard back to
# its absence and names the scenario that objects.

S = "runscenarios.py"
M = "Prompt/Moments.lua"
SENSE = "Prompt/MomentsSense.lua"

mutate(SENSE,
       '\t\tif cur / max * 100 < threshold then return "yes" end\n',
       '\t\tif cur / max * 100 <= threshold then return "yes" end\n',
       "moments-iceblock: the health compare takes the line itself",
       expect="moments-iceblock: lit under the line with plain health", script=S)

mutate(SENSE,
       '\t\tc:AddPoint(Sense.scale, 0)\n',
       '\t\tc:AddPoint(Sense.scale, 1)\n',
       "moments-iceblock: the curve's far end is reversed",
       expect="moments-iceblock: hidden health is handed to the game", script=S)

mutate(M,
       '\tif slot.state == "game" and slot.row.guard == "twice" then\n\t\t-- Open from a third',
       '\tif false then\n\t\t-- Open from a third',
       "moments-iceblock: the cover is dropped in game for a two-click row",
       expect="moments-iceblock: hidden health: one click casts nothing and opens it", script=S)

mutate(M,
       '\t\t\t\tif slot.openUntil and GetTime() >= slot.openUntil then\n',
       '\t\t\t\tif false then\n',
       "moments-iceblock: the open window is endless",
       expect="moments-iceblock: hidden health: two clicks three seconds apart", script=S)

mutate(M,
       '\t\tslot.state = "dark"\n\t\tslot.cover:SetShown(CoverWanted(slot, now))\n',
       '\t\tslot.state = "dark"\n\t\tslot.inner:SetAlpha(1)\n\t\tslot.cover:SetShown(CoverWanted(slot, now))\n',
       "moments-iceblock: the art is reset on the way to dark",
       expect="moments-iceblock: hidden health, then the cooldown starts", script=S)

mutate(M,
       '\t\tif was == "game" then\n',
       '\t\tif false then\n',
       "moments-iceblock: game to dark is not snapped",
       expect="moments-iceblock: hidden health, then the cooldown starts", script=S)

mutate(M,
       '\tlocal from = slot.face:GetAlpha()\n',
       '\tlocal from = slot.inner:GetAlpha()\n',
       "moments-iceblock: the fader reads the game's alpha",
       expect="moments-iceblock: no arithmetic on a secret alpha", script=S)

mutate(SENSE,
       '\t\t\treturn plain(rec.isActive), plain(rec.startTime), plain(rec.duration)\n',
       '\t\t\treturn nil, plain(rec.startTime), plain(rec.duration)\n',
       "moments-iceblock: isActive is ignored",
       expect="moments-iceblock:", script=S)

mutate(SENSE,
       '\t\tif slot.onGCD == false then return true end\n',
       '\t\tif slot.onGCD ~= true then return true end\n',
       "moments-iceblock: a missing isOnGCD is taken for not on the global cooldown",
       expect="moments-iceblock: isOnGCD missing during the global cooldown", script=S)

mutate(M,
       '\t\t\tSeed(slot, now)\n\t\t\tslot.cover:SetShown(slot.mouseOn == true)\n',
       '\t\t\tslot.cover:SetShown(slot.mouseOn == true)\n',
       "moments-iceblock: the pull's clock seed is removed",
       expect="moments-iceblock: a cooldown the pull read plainly is kept by the clock", script=S)

mutate(SENSE,
       '\tlocal threshold = moments and moments[which] or 20\n',
       '\tlocal threshold = 20\n',
       "moments-iceblock: the slider no longer moves the line",
       expect="moments-iceblock: the slider moves the line", script=S)

mutate(SENSE,
       '\t\tif type(plain(auras.GetPlayerAuraBySpellID(lock.aura))) == "table" then return "no", "Hypothermia" end\n',
       '',
       "moments-iceblock: a plain Hypothermia aura is not read",
       expect="moments-iceblock: Hypothermia by a plain aura", script=S)

mutate(SENSE,
       '\tif slot.castAt and now - slot.castAt < lock.seconds then return "no", "Hypothermia" end\n',
       '',
       "moments-iceblock: Hypothermia's own clock is not kept",
       expect="moments-iceblock: Hypothermia by its own clock", script=S)

mutate(SENSE,
       '\tif not curve then return "blind", "your " .. which end\n',
       '\tif not curve then return "yes" end\n',
       "moments-iceblock: no curve call lights it on a guess",
       expect="moments-iceblock: hidden health and no curve call", script=S)

mutate(SENSE,
       '\tif slot.readyAt and now < slot.readyAt then return "no", "cooling down" end\n',
       '',
       "moments-iceblock: Manners' own clock is not consulted",
       expect="moments-iceblock: a cooldown begun before the pull keeps it dark", script=S)

mutate(SENSE,
       '\t\tif slot.onGCD == false then return true end\n',
       '',
       "moments-iceblock: a cooldown flag off the global cooldown is not believed",
       expect="moments-iceblock: isActive true with the numbers hidden", script=S)

mutate(M,
       '\tif slot.state == "game" and slot.row.guard == "twice" then\n\t\t-- Inside the gap',
       '\tif false then\n\t\t-- Inside the gap',
       "moments-iceblock: the first click is not counted as opening it",
       expect="moments-iceblock: hidden health: one click casts nothing and opens it", script=S)
