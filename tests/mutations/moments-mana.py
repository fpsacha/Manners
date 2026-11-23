# Mutations for Evocation and the mana gem for the moment:
# tests/scenarios/moments-mana.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts one guard back to
# its absence and names the scenario that objects.

S = "runscenarios.py"
M = "Prompt/Moments.lua"
SENSE = "Prompt/MomentsSense.lua"

mutate(SENSE,
       '\tif not anyCount then return "no", "no gem in your bags" end\n',
       '\tif false then return "no", "no gem in your bags" end\n',
       "moments-mana: the gem lit with none in the bags",
       expect="moments-mana: the gem is lit with one in the bags", script=S)

mutate(SENSE,
       '\t\t\tlocal cooling = ItemCooling(id, now)\n',
       '\t\t\tlocal cooling = false\n',
       "moments-mana: the gem's cooldown is ignored",
       expect="moments-mana: the gem cooling down keeps it dark", script=S)

mutate(SENSE,
       'function Sense.itemready(slot, now)\n\tlocal counts = slot.count\n',
       'function Sense.itemready(slot, now)\n\tlocal counts = Sense.CountItems(slot)\n',
       "moments-mana: the gem counted per flush",
       expect="moments-mana: a flush counts no gems", script=S)

mutate(SENSE,
       '\t\tif slot.readyAt and now < slot.readyAt then return "no", "the gem is cooling down" end\n',
       '',
       "moments-mana: the gem's own clock is not consulted",
       expect="moments-mana: the gem: hidden cooldown figures count as ready until it is used", script=S)

mutate(SENSE,
       '\t\trawPct = _G.UnitPowerPercent("player", MANA, false, curve)\n',
       '\t\trawPct = _G.UnitHealthPercent("player", false, curve)\n',
       "moments-mana: hidden mana is read from the health call",
       expect="moments-mana: Evocation hidden mana is handed to the game", script=S)

mutate(M,
       '\t\tif #lines == 0 then\n\t\t\tfor i, id in ipairs(row.items) do\n',
       '\t\tif false then\n\t\t\tfor i, id in ipairs(row.items) do\n',
       "moments-mana: no line for the gems the mage can conjure",
       expect="moments-mana: the macro lists every gem the mage can conjure", script=S)

mutate(M,
       '\t\t\tif slot.row.items then\n\t\t\t\tSense.CountItems(slot)\n\t\t\t\tArm(slot)\n\t\t\tend\n',
       '',
       "moments-mana: the pull neither counts the gems nor arms the gem button",
       expect="moments-mana: the macro lists the gems in the bags best first", script=S)

mutate("Core.lua",
       '\tif ns.Moments then ns.Guard("moments at fight start", ns.Moments.Take, ns.Moments) end\n',
       '',
       "moments-mana: the addon's pull never calls Take",
       expect="moments-mana: the macro lists the gems in the bags best first", script=S)

mutate(M,
       '\t\tif slot and slot.armed and slot.row.items then Sense.CountItems(slot) end\n',
       '',
       "moments-mana: a bag event does not count the gems",
       expect="moments-mana: the gem is lit with one in the bags", script=S)

mutate(M,
       '\t\t\tif needs.itemready then Register("BAG_UPDATE_DELAYED") end\n',
       '',
       "moments-mana: the bag event is not registered at the pull",
       expect="moments-mana: the gem is lit with one in the bags", script=S)

mutate(M,
       '\t\t\twantOwn = true\n\t\t\tif slot.needs.stuck then wantControl = true end\n',
       '\t\t\tif slot.needs.stuck then wantControl = true end\n',
       "moments-mana: your own casts are not heard out of a fight",
       expect="moments-mana: Evocation used between pulls stays dark next fight", script=S)

mutate(M,
       '\t\t\t\tArm(slot)\n\t\t\t\tSeed(slot, now)\n',
       '\t\t\t\tArm(slot)\n',
       "moments-mana: the refresh does not seed the clocks",
       expect="moments-mana: Evocation: a cooldown seen plainly at the refresh", script=S)

mutate(M,
       '\t\tif gem and gem.armed and gem.row.items and gem ~= slot and Went(gem) then\n',
       '\t\tif false then\n',
       "moments-mana: a gem's own spell is not taken for its use",
       expect="moments-mana: the gem: hidden cooldown figures count as ready until it is used", script=S)
