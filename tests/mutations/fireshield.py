# Mutations for Fire Shield from a warlock's imp on the tank (GitHub issue 22:
# Buffs.lua's fireshield, `pet` and `forTank`, its levels and its length;
# Core.lua's ProbeBuff, ns.PetCasts, CastableBuffs, Castable, UnitHasBuff,
# OnEnable and UNIT_PET; Queue.lua's tank read; Clicks.lua's pet cast;
# Options/Who.lua's label). Each is caught by the scenario
# in tests/scenarios/fireshield.lua that names it.

S = "runscenarios.py"

# ------------------------------------------------ the data
mutate("Buffs.lua",
       "\tVANILLA.WARLOCK[#VANILLA.WARLOCK + 1] = { key = \"fireshield\", ranks = { 11771, 11770, 8317, 8316, 2947 },\n",
       "\tVANILLA.WARLOCK[#VANILLA.WARLOCK + 1] = { key = \"fireshieldX\", ranks = { 11771, 11770, 8317, 8316, 2947 },\n",
       "fireshield: none on Classic Era and Forever",
       expect="fireshield: the imp's buff on Forever, Classic Era and Burning Crusade", script=S)

mutate("Buffs.lua",
       "\t\t\tkey = \"fireshield\",\n\t\t\tranks = { 27269, 11771, 11770, 8317, 8316, 2947 },\n",
       "\t\t\tkey = \"fireshieldX\",\n\t\t\tranks = { 27269, 11771, 11770, 8317, 8316, 2947 },\n",
       "fireshield: none on Burning Crusade",
       expect="fireshield: tbc: the tank is offered it", script=S)

mutate("Buffs.lua",
       "\t[2947] = 14, [8316] = 24, [8317] = 34, [11770] = 44, [11771] = 54,\n",
       "",
       "fireshield: no rank levels",
       expect="fireshield: the imp's buff on Forever, Classic Era and Burning Crusade", script=S)

mutate("Buffs.lua",
       "\tAdd(CAMELOT_SET, { { 180, 11771, 11770, 8317, 8316, 2947 } }) -- Fire Shield (3 min)\n",
       "\tAdd(CAMELOT_SET, { { 1800, 11771, 11770, 8317, 8316, 2947 } }) -- Fire Shield (3 min)\n",
       "fireshield: thirty minutes on Forever",
       expect="fireshield: the imp's buff on Forever, Classic Era and Burning Crusade", script=S)

mutate("Buffs.lua",
       "\t\tpet = 688, forTank = true, partyOnly = true, optIn = true, neverSelf = true }\n",
       "\t\tforTank = true, partyOnly = true, optIn = true, neverSelf = true }\n",
       "fireshield: not the pet's",
       expect="fireshield: off by default; ticked, the party's tank is offered it", script=S)

mutate("Buffs.lua",
       "\t\tpet = 688, forTank = true, partyOnly = true, optIn = true, neverSelf = true }\n",
       "\t\tpet = 688, forTank = true, partyOnly = true, neverSelf = true }\n",
       "fireshield: on by default",
       expect="fireshield: off by default; ticked, the party's tank is offered it", script=S)

mutate("Buffs.lua",
       "\t\tpet = 688, forTank = true, partyOnly = true, optIn = true, neverSelf = true }\n",
       "\t\tpet = 688, partyOnly = true, optIn = true, neverSelf = true }\n",
       "fireshield: for anybody in the party",
       expect="fireshield: off by default; ticked, the party's tank is offered it", script=S)

mutate("Buffs.lua",
       "\t\tpet = 688, forTank = true, partyOnly = true, optIn = true, neverSelf = true }\n",
       "\t\tpet = 688, forTank = true, optIn = true, neverSelf = true }\n",
       "fireshield: not held to the party",
       expect="fireshield: the imp's buff on Forever, Classic Era and Burning Crusade", script=S)

# ------------------------------------------------ the pet
mutate("Core.lua",
       "\t\t\tinfo.known = SpellKnown(buff.pet) or nil\n",
       "\t\t\tinfo.known = nil\n",
       "fireshield: never yours to switch on",
       expect="fireshield: the switch names the imp and the tank, and is there with no imp out", script=S)

mutate("Core.lua",
       "\twalk = ns.PetReady(walk)\n",
       "",
       "fireshield: offered with no imp out",
       expect="fireshield: only while an imp out knows it, asked again when the pet changes", script=S)

mutate("Core.lua",
       "\t\t\tpetKnows[key] = answer\n",
       "",
       "fireshield: the pet's spellbook asked every scan",
       expect="fireshield: the pet's answer is kept until the pet changes", script=S)

mutate("Core.lua",
       "\t\treturn safecall(_G.IsSpellKnown, id, true) == true\n",
       "\t\treturn safecall(_G.IsSpellKnown, id) == true\n",
       "fireshield: your own spellbook asked for the pet's",
       expect="fireshield: off by default; ticked, the party's tank is offered it", script=S)

mutate("Core.lua",
       "function addon:UNIT_PET(_, unit)\n\tif unit ~= \"player\" then return end\n\tns.ForgetPetSpells()\n",
       "function addon:UNIT_PET(_, unit)\n\tif unit ~= \"player\" then return end\n",
       "fireshield: the pet's coming and going not heard",
       expect="fireshield: only while an imp out knows it, asked again when the pet changes", script=S)

mutate("Core.lua",
       "function addon:UNIT_PET(_, unit)\n\tif unit ~= \"player\" then return end\n",
       "function addon:UNIT_PET(_, unit)\n",
       "fireshield: every unit's pet heard as yours",
       expect="fireshield: the pet's answer is kept until the pet changes", script=S)

mutate("Core.lua",
       "\t\t\tns.Guard(\"RegisterEvent UNIT_PET\", function() self:RegisterEvent(\"UNIT_PET\") end)\n\t\t\tns.Guard(\"pet casts\", ns.HearPetCasts)\n",
       "\t\t\tns.Guard(\"RegisterEvent UNIT_PET\", function() self:RegisterEvent(\"UNIT_PET\") end)\n",
       "fireshield: the pet's casts never heard",
       expect="fireshield: the press targets the tank and casts it by name", script=S)

mutate("Core.lua",
       "\t\tif buff.pet then\n\t\t\tns.Guard(\"RegisterEvent UNIT_PET\"",
       "\t\tif true then\n\t\t\tns.Guard(\"RegisterEvent UNIT_PET\"",
       "fireshield: every class hears its pet",
       expect="fireshield: a class with no pet's buff hears no pet", script=S)

# ------------------------------------------------ who
mutate("Core.lua",
       "\t\tif buff.forTank and not (opts.isTank or opts.asked) then return false end\n",
       "",
       "fireshield: the tank rule never asked",
       expect="fireshield: off by default; ticked, the party's tank is offered it", script=S)

mutate("Core.lua",
       "\t\tif buff.forTank and not (opts.isTank or opts.asked) then return false end\n",
       "\t\tif buff.forTank and not opts.isTank then return false end\n",
       "fireshield: a request by name held to the tank",
       expect="fireshield: a party member who asks for fire shield by name is offered it", script=S)

mutate("Queue.lua",
       "\t\tif opts.isTank == nil and opts.forTank and inGroup and not owner then opts.isTank = ns.IsTankUnit(unit) end\n",
       "",
       "fireshield: nobody's role read",
       expect="fireshield: off by default; ticked, the party's tank is offered it", script=S)

mutate("Queue.lua",
       "\t\tif buff.forTank then opts.forTank = true end\n",
       "",
       "fireshield: the scan not told of the tank's buff",
       expect="fireshield: off by default; ticked, the party's tank is offered it", script=S)

# ------------------------------------------------ the press and the aura
mutate("Clicks.lua",
       "function ns.PetCastLanded(unit, castGUID, spellId)\n\tif unit ~= \"pet\" then return end\n",
       "function ns.PetCastLanded(unit, castGUID, spellId)\n",
       "fireshield: your own cast taken for the pet's",
       expect="fireshield: the press targets the tank and casts it by name", script=S)

mutate("Clicks.lua",
       "\tif not (buff and buff.pet) then return end\n\tSettlePendingClick(nil, id, plain(castGUID))\n",
       "\tSettlePendingClick(nil, id, plain(castGUID))\n",
       "fireshield: any pet cast answers the press",
       expect="fireshield: the press targets the tank and casts it by name", script=S)

mutate("Core.lua",
       "\t\t\t\t\tif same == false and buff.pet and plain(UnitIsUnit(source, \"pet\")) == true then mine = true end\n",
       "",
       "fireshield: your imp's aura read as somebody else's",
       expect="fireshield: the tank wearing it from your imp is covered", script=S)

mutate("Options/Who.lua",
       "\tif buff.pet and buff.forTank then return L[\"%s from my imp on the tank\"]:format(label) end\n",
       "",
       "fireshield: the switch does not name the imp",
       expect="fireshield: the switch names the imp and the tank", script=S)
