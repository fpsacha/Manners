# Blessing of Kings first (tests/scenarios/hunt27-kings.lua): each fault put
# back has to be caught by the scenario that names it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# ------------------------------------------------ which clients put Kings first
# Classic Era's Kings loses its flag, so the walk keeps Wisdom and Might ahead.
mutate("Buffs.lua",
       "\t\t\tgroup = { 25898 },\n\t\t\ttalent = true,\n\t\t\tgroupCast = Greater(25898),\n"
       "\t\t\tstrongest = true,\n",
       "\t\t\tgroup = { 25898 },\n\t\t\ttalent = true,\n\t\t\tgroupCast = Greater(25898),\n",
       "hunt27-kings: Classic Era's Kings not first",
       expect="hunt27-kings: vanilla: a warrior, a mage and a rogue are all offered Kings",
       script=S)

# Burning Crusade's own Kings, a table of its own.
mutate("Buffs.lua",
       "\t\t\ttalent = true,\n\t\t\tgroup = { 25898 },\n\t\t\tgroupCast = Greater(25898),\n"
       "\t\t\tstrongest = true,\n",
       "\t\t\ttalent = true,\n\t\t\tgroup = { 25898 },\n\t\t\tgroupCast = Greater(25898),\n",
       "hunt27-kings: Burning Crusade's Kings not first",
       expect="hunt27-kings: tbc: a warrior, a mage and a rogue are all offered Kings",
       script=S)

# Forever's list is a copy of Classic Era's, entry by entry: the copy drops it.
mutate("Buffs.lua",
       "\t\t\t\tif TRAINED[entry.key] then entry.talent = nil end\n",
       "\t\t\t\tif TRAINED[entry.key] then entry.talent = nil entry.strongest = nil end\n",
       "hunt27-kings: Forever's Kings not first",
       expect="hunt27-kings: camelot: a warrior, a mage and a rogue are all offered Kings",
       script=S)

# Mists' Kings is first in its list already: marked, the page shows a switch that
# changes nothing there.
mutate("Buffs.lua",
       "\t\t{ key = \"kings\", ranks = { 20217 }, alike = { 1126, 117666, 117667 } },\n",
       "\t\t{ key = \"kings\", ranks = { 20217 }, alike = { 1126, 117666, 117667 }, strongest = true },\n",
       "hunt27-kings: Mists' Kings marked strongest",
       expect="hunt27-kings: mists: Kings is first either way, and the switch is not shown",
       script=S)

# The Greater Blessing of Kings: no group version, so a class is buffed one by one.
mutate("Buffs.lua",
       "\t\t\tgroupCast = Greater(25898),\n\t\t\tstrongest = true,\n",
       "\t\t\tstrongest = true,\n",
       "hunt27-kings: Greater Blessing of Kings not a group version",
       expect="hunt27-kings: vanilla: Greater Blessing of Kings for a class group",
       script=S)

# ------------------------------------------------ the walk's order
# Never put first, whatever the switch says.
mutate("Core.lua",
       "\tlocal strongestFirst = db ~= nil and db.buff.kingsFirst == true\n",
       "\tlocal strongestFirst = false\n",
       "hunt27-kings: Kings never put first",
       expect="hunt27-kings: vanilla: a warrior, a mage and a rogue are all offered Kings",
       script=S)

# Always put first: the switch off changes nothing.
mutate("Core.lua",
       "\t\t\tif strongestFirst and buff.strongest then\n",
       "\t\t\tif buff.strongest then\n",
       "hunt27-kings: the switch off still puts Kings first",
       expect="hunt27-kings: vanilla: with the switch off the walk is as it was",
       script=S)

# Put last rather than first.
mutate("Core.lua",
       "\t\t\t\ttable.insert(out, 1, buff)\n",
       "\t\t\t\tout[#out + 1] = buff\n",
       "hunt27-kings: Kings put last instead of first",
       expect="hunt27-kings: tbc: a warrior, a mage and a rogue are all offered Kings",
       script=S)

# Put first and the rest dropped: nothing to fall back to.
mutate("Core.lua",
       "\t\t\t\ttable.insert(out, 1, buff)\n",
       "\t\t\t\tout = { buff }\n\t\t\t\tbreak\n",
       "hunt27-kings: Kings first with nothing to fall back to",
       expect="hunt27-kings: vanilla: Kings from another paladin is walked on to the class blessing",
       script=S)

# The class has no strongest buff for the walk and the page to find.
mutate("Core.lua",
       "\t\tif buff.strongest then return buff end\n",
       "\t\tif false then return buff end\n",
       "hunt27-kings: the class's strongest buff never found",
       expect="hunt27-kings: camelot: the spell named for the prompt is Kings",
       script=S)

# ------------------------------------------------ the spell that is named
# The login line, the preview and {spell} keep naming Wisdom.
mutate("Core.lua",
       "\tif db.buff.kingsFirst == true then\n\t\tlocal strongest = ns.StrongestBuff()\n",
       "\tif false then\n\t\tlocal strongest = ns.StrongestBuff()\n",
       "hunt27-kings: the spell named still Wisdom",
       expect="hunt27-kings: vanilla: the spell named for the prompt is Kings",
       script=S)

# Named although Kings is switched off.
mutate("Core.lua",
       "\t\tif strongest and ns.IsBuffKnown(strongest) and not strongest.neverAuto\n"
       "\t\t\tand not (db.buff.skip and db.buff.skip[strongest.key]) then\n",
       "\t\tif strongest and ns.IsBuffKnown(strongest) and not strongest.neverAuto then\n",
       "hunt27-kings: a switched-off Kings named",
       expect="hunt27-kings: vanilla: Kings switched off or another spell pinned",
       script=S)

# Named although it is not learned.
mutate("Core.lua",
       "\t\tif strongest and ns.IsBuffKnown(strongest) and not strongest.neverAuto\n",
       "\t\tif strongest and not strongest.neverAuto\n",
       "hunt27-kings: an unlearned Kings named",
       expect="hunt27-kings: vanilla: a paladin who does not know Kings is unchanged",
       script=S)

# ------------------------------------------------ who it is offered to
# Kings on somebody already carrying another paladin's: read as theirs no more.
mutate("Core.lua",
       "\t\t\t\t\tif held == true and mine == false then\n",
       "\t\t\t\t\tif held == true and mine == false and not buff.strongest then\n",
       "hunt27-kings: another paladin's Kings read as ours",
       expect="hunt27-kings: vanilla: Kings from another paladin is walked on to the class blessing",
       script=S)

# Kings of ours read as another paladin's: Might goes on over it.
mutate("Core.lua",
       "\t\t\t\t\tif held == true and mine == false then\n",
       "\t\t\t\t\tif held == true and (mine == false or buff.strongest) then\n",
       "hunt27-kings: our own Kings read as another paladin's",
       expect="hunt27-kings: vanilla: Kings of yours is not flipped to the class blessing",
       script=S)

# Kings straight away, over whatever blessing of ours they carry.
mutate("Core.lua",
       "\t\t\tlocal pick, allRead, onCooldown = nil, true, false\n",
       "\t\t\tlocal pick, allRead, onCooldown = nil, true, false\n"
       "\t\t\tlocal lead = candidates[1]\n"
       "\t\t\tif lead and lead.strongest and Castable(opts, lead) and (has(lead, opts)) ~= true then\n"
       "\t\t\t\treturn lead, false\n"
       "\t\t\tend\n",
       "hunt27-kings: Kings over a blessing of ours already worn",
       expect="hunt27-kings: camelot: a blessing of yours already worn is not flipped to Kings",
       script=S)

# The Greater Blessing of Kings landing on a class with a Might of ours among it.
mutate("GroupBuffs.lua",
       "\t\t\tif not (name and offered[name]) and CarriesAnother(unit, key, mine) then return false end\n",
       "\t\t\tif false then return false end\n",
       "hunt27-kings: a Greater Blessing of Kings over a Might of ours",
       expect="hunt27-kings: vanilla: a Greater Blessing of Kings never replaces a Might of yours",
       script=S)

# ------------------------------------------------ the setting
# Off by default.
mutate("Core.lua",
       "\t\t\tkingsFirst = true,\n",
       "\t\t\tkingsFirst = false,\n",
       "hunt27-kings: Kings first off by default",
       expect="hunt27-kings: the switch is on by default and repaired to on",
       script=S)

# A damaged value left as it is.
mutate("Core.lua",
       "\tboolean(profile.buff, \"kingsFirst\", true)\n",
       "",
       "hunt27-kings: a damaged switch not repaired",
       expect="hunt27-kings: the switch is on by default and repaired to on",
       script=S)

# ------------------------------------------------ the control
# Shown to every class, not only a paladin whose list it changes.
mutate("Options/Who.lua",
       "\t\t\t\thidden = function() return ns.PinnedBuff() ~= nil or ns.StrongestBuff() == nil end,\n",
       "\t\t\t\thidden = function() return ns.PinnedBuff() ~= nil end,\n",
       "hunt27-kings: the switch shown to every class",
       expect="hunt27-kings: the switch is not shown to another class",
       script=S)

# Still shown while one spell is pinned, which is all that is considered then.
mutate("Options/Who.lua",
       "\t\t\t\thidden = function() return ns.PinnedBuff() ~= nil or ns.StrongestBuff() == nil end,\n",
       "\t\t\t\thidden = function() return ns.StrongestBuff() == nil end,\n",
       "hunt27-kings: the switch shown over a pin",
       expect="hunt27-kings: vanilla: the switch is on Who to buff for a paladin",
       script=S)

# Named by hand rather than as the client names the spell.
mutate("Options/Who.lua",
       "\t\t\t\t\treturn buff and L[\"%s first\"]:format(ns.BuffName(buff)) or \"\"\n",
       "\t\t\t\t\treturn buff and L[\"%s first\"]:format(\"Kings\") or \"\"\n",
       "hunt27-kings: the switch's label names the spell by hand",
       expect="hunt27-kings: tbc: the switch is on Who to buff for a paladin",
       script=S)

# Reads on whatever is stored.
mutate("Options/Who.lua",
       "\t\t\t\tget = function() return B().kingsFirst == true end,\n",
       "\t\t\t\tget = function() return true end,\n",
       "hunt27-kings: the switch always reads on",
       expect="hunt27-kings: camelot: the switch is on Who to buff for a paladin",
       script=S)

# Left out of the page's reset.
mutate("Options/Advanced.lua",
       "\t\t\"buff.choice\", \"buff.skip\", \"buff.kingsFirst\", \"filters.relevantOnly\",\n",
       "\t\t\"buff.choice\", \"buff.skip\", \"filters.relevantOnly\",\n",
       "hunt27-kings: the page's reset leaves the switch",
       expect="hunt27-kings: vanilla: the switch is on Who to buff for a paladin",
       script=S)

# Not placed in the window: a setting nobody can reach there.
mutate("Options/Window/Layout.lua",
       "\titems[#items + 1] = \"who.kingsFirst\"\n",
       "",
       "hunt27-kings: the switch not placed in the window",
       expect="every control has one place in the options window",
       script=S)
