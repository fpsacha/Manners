# Mutations for the what-if run (1.6.5): tests/scenarios/whatif.lua, and the
# what-ifs kept with their own kind in mage-scrolls.lua (scenarios 22-24),
# ownbuffs.lua (own 30, 31) and groupbuffs.lua. Each puts one edge case back
# and is caught by the scenario that names it.

S = "runscenarios.py"

# --- an oil seen beside a scroll's imbue (Core.lua, ReadImbue) ---

mutate("Core.lua",
       "\t\t\tif not has or (imbueStacks and not named) then\n",
       "\t\t\tif not has then\n",
       "whatif: an oil alone always counts",
       expect="the imbue ran out under an oil seen beside it", script=S)

mutate("Core.lua",
       "\t\t\tif named and other then imbueStacks = true end\n",
       "",
       "whatif: an oil beside an imbue never noted",
       expect="the imbue ran out under an oil seen beside it", script=S)

mutate("Core.lua",
       "\t\t\t\t\tif not made then other = true end\n",
       "",
       "whatif: the oil beside the imbue not seen",
       expect="the imbue ran out under an oil seen beside it", script=S)

# --- a scroll picked above your level (Core.lua, OwnVerdict) ---

mutate("Core.lua",
       "\t\t\tif type(level) == \"number\" and level < spell.level and ns.OwnAutoPick(family) then spell = nil end\n",
       "",
       "whatif: a pick above your level silences the family",
       expect="Cat Familiar picked at level 14 with four Rats", script=S)

mutate("Core.lua",
       "\t\t\tif type(level) == \"number\" and level < spell.level and ns.OwnAutoPick(family) then spell = nil end\n",
       "\t\t\tif type(level) == \"number\" and level < spell.level then spell = nil end\n",
       "whatif: a pick above your level dropped with nothing to use",
       expect="Cat picked at level 14 with only a Frog scroll", script=S)

# --- Spellbreak's rank (Buffs.lua) ---

# Ahead of the level-25 scrolls again, as it sat.
mutate("Buffs.lua",
       "\t\t\t{ key = \"imbueaccuracy\", item = 277494,",
       "\t\t\t{ key = \"imbuespellbreak\", item = 277503, level = 46, ranks = { 1295720 }, enchant = 8700, weapon = STAFF },\n"
       "\t\t\t{ key = \"imbueaccuracy\", item = 277494,",
       "whatif: Spellbreak ranked over Flame and Frost",
       expect="Spellbreak, Flame and Accuracy at level 50", script=S)

# --- a shared party aura (Buffs.lua, Core.lua OwnAutoPick and ByName) ---

mutate("Core.lua",
       "\t\tif spell and family.shared and OthersOnYou(spell) then\n",
       "\t\tif false then\n",
       "whatif: another's party aura never passed over",
       expect="yours gone and another paladin's Devotion Aura on you", script=S)

mutate("Buffs.lua",
       "\t\t\t-- of the same from two paladins do not stack.\n\t\t\tshared = true,\n",
       "\t\t\t-- of the same from two paladins do not stack.\n",
       "whatif: a paladin's auras not shared",
       expect="yours gone and another paladin's Devotion Aura on you", script=S)

mutate("Buffs.lua",
       "\t\t\t-- party.\n\t\t\tspells = { { key = \"trueshot\", ranks = { 20906, 20905, 19506, 1299348, 1299346 }, talent = true } },\n"
       "\t\t\tshared = true,\n",
       "\t\t\t-- party.\n\t\t\tspells = { { key = \"trueshot\", ranks = { 20906, 20905, 19506, 1299348, 1299346 }, talent = true } },\n",
       "whatif: Trueshot Aura not shared",
       expect="another hunter's Trueshot Aura on you: offered", script=S)

mutate("Core.lua",
       "\t\t\t\tif other ~= spell and Known(other) and not other.neverAuto and not OthersOnYou(other) then\n",
       "\t\t\t\tif other ~= spell and Known(other) and not other.neverAuto then\n",
       "whatif: passed over onto another's aura",
       expect="both your auras on you from other paladins", script=S)

mutate("Core.lua",
       "\t\t\tif not Withheld(aura) and type(aura) == \"table\" and FromYou(aura) == false then return true end\n",
       "",
       "whatif: another's copy never read",
       expect="yours gone and another paladin's Devotion Aura on you", script=S)

mutate("Core.lua",
       "\t\t\t\t\tlocal ok, aura = pcall(lookup, \"player\", name, \"HELPFUL|PLAYER\")\n",
       "\t\t\t\t\tlocal ok, aura = pcall(lookup, \"player\", name, \"HELPFUL\")\n",
       "whatif: by name, another's copy read first",
       expect="your own Devotion Aura, read after another paladin's", script=S)

# --- a charge shield (Buffs.lua, Core.lua OwnVerdict, Prompt/Paint.lua) ---

mutate("Core.lua",
       "\t\t\tlocal spent = upSpell and upSpell.charges and type(charges) == \"number\" and charges >= 1\n",
       "\t\t\tlocal spent = false and upSpell and upSpell.charges and type(charges) == \"number\" and charges >= 1\n",
       "whatif: charges never read",
       expect="Lightning Shield with 1 of its 3 charges and ten minutes left", script=S)

mutate("Core.lua",
       "\t\t\t\tand charges <= math.max(1, math.floor(upSpell.charges / 4))\n",
       "\t\t\t\tand charges <= 1\n",
       "whatif: only the last charge of twenty",
       expect="Inner Fire with 5 of its 20 charges left", script=S)

mutate("Buffs.lua",
       "{ key = \"lightningshield\", ranks = { 10432, 10431, 8134, 945, 905, 325, 324 }, charges = 3 },",
       "{ key = \"lightningshield\", ranks = { 10432, 10431, 8134, 945, 905, 325, 324 } },",
       "whatif: Lightning Shield's charges unknown",
       expect="Lightning Shield with 1 of its 3 charges and ten minutes left", script=S)

mutate("Prompt/Paint.lua",
       "\telseif entry.charges then\n",
       "\telseif false then\n",
       "whatif: a charge top-up says its time",
       expect="the charge top-up reads", script=S)

# --- the "buffed you" line (Favours.lua, QuietHere) ---

mutate("Favours.lua",
       "\t\tif type(_G.IsInRaid) == \"function\" and plain(_G.IsInRaid()) == true then return true end\n",
       "",
       "whatif: the line said in a raid group outdoors",
       expect="a favour in a raid group outdoors was announced in chat", script=S)

mutate("Favours.lua",
       "\t\tif kind == \"raid\" or kind == \"pvp\" or kind == \"arena\" then return true end\n",
       "\t\tif kind == \"raid\" or kind == \"arena\" then return true end\n",
       "whatif: the line said in a battleground",
       expect="a favour in a battleground was announced in chat", script=S)

mutate("Favours.lua",
       "\t\tif kind == \"raid\" or kind == \"pvp\" or kind == \"arena\" then return true end\n",
       "\t\tif kind == \"raid\" or kind == \"pvp\" then return true end\n",
       "whatif: the line said in an arena",
       expect="a favour in an arena was announced in chat", script=S)

# --- a group member's lapsing shout (Queue.lua, Core.lua, Favours.lua) ---

mutate("Queue.lua",
       "\t\topts.paidUp = isOwed and inGroup and checked or nil\n",
       "\t\topts.paidUp = nil\n",
       "whatif: a fresh cast of yours repaid again",
       expect="wearing your Fortitude with forty minutes left, was offered", script=S)

mutate("Queue.lua",
       "\t\topts.paidUp = isOwed and inGroup and checked or nil\n",
       "\t\topts.paidUp = isOwed and checked or nil\n",
       "whatif: a stranger's favour taken as paid",
       expect="a stranger who buffed you, wearing your Fortitude, was not offered", script=S)

mutate("Core.lua",
       "\t\t\tand remaining > (opts.refreshUnder or 5) * 60\n",
       "\t\t\tand remaining > 0\n",
       "whatif: a cast running out taken as paid",
       expect="wearing your Fortitude with two minutes left, was not offered it", script=S)

mutate("Core.lua",
       "\t\t\t\t\t\tif not opts.offerAnyway or Fresh(opts, mine, remaining) then return nil, true end\n",
       "\t\t\t\t\t\tif not opts.offerAnyway then return nil, true end\n",
       "whatif: a fresh blessing of yours repaid again",
       expect="wearing your Might with forty minutes left, was offered", script=S)

mutate("Favours.lua",
       "\t\tif speak and seen.inGroup then\n",
       "\t\tif false then\n",
       "whatif: a line at every lapsed shout",
       expect="\"buffed you\" lines", script=S)

mutate("Favours.lua",
       "\t\tif speak and seen.inGroup then\n",
       "\t\tif speak then\n",
       "whatif: a stranger's line held for half an hour",
       expect="two favours from a stranger seven minutes apart", script=S)

mutate("Favours.lua",
       "\t\tif last and now - last < (seen.inGroup and PER_MEMBER or PER_PERSON) then\n",
       "\t\tif last and now - last < PER_PERSON then\n",
       "whatif: a /thank at every lapsed shout",
       expect="/thank emotes", script=S)

# --- a low rank (Core.lua, UnitHasBuff) ---

mutate("Core.lua",
       "\t\t\t\t\tif isRank and landing and worn < landing then has, expires, mine = false, nil, nil end\n",
       "",
       "whatif: any rank covers",
       expect="a level-60 wearing Fortitude's second rank was not offered yours", script=S)

mutate("Core.lua",
       "\t\t\t\t\tlocal reach, landing = math.min(best, level + 10), nil\n",
       "\t\t\t\t\tlocal reach, landing = math.min(best, level), nil\n",
       "whatif: no downranking reach",
       expect="a level-20 wearing the level-12 rank was not offered the level-24 one", script=S)

mutate("Core.lua",
       "\t\t\t\t\tif isRank and landing and worn < landing then has, expires, mine = false, nil, nil end\n",
       "\t\t\t\t\tif isRank and worn < reach then has, expires, mine = false, nil, nil end\n",
       "whatif: the reach taken for the rank that lands",
       expect="a level-20 wearing the best rank a cast could land on him was offered it again", script=S)

# --- the ignore list (Favours.lua, Sight; Queue.lua) ---

mutate("Favours.lua",
       "\t\tif ns.Ignored(source, guid) then return end\n",
       "",
       "whatif: somebody ignored thanked",
       expect="somebody on your ignore list buffed you", script=S)

mutate("Queue.lua",
       "\t\tif ignoring and not inGroup and ns.Ignored(unit) then\n",
       "\t\tif false then\n",
       "whatif: an ignored passer-by offered",
       expect="a passer-by on your ignore list was offered", script=S)

mutate("Queue.lua",
       "\t\tif ignoring and not inGroup and ns.Ignored(unit) then\n",
       "\t\tif ignoring and ns.Ignored(unit) then\n",
       "whatif: an ignored group member left out",
       expect="a group member on your ignore list was not offered", script=S)

mutate("Queue.lua",
       "\tlocal ignoring = IgnoresAnybody()\n",
       "\tlocal ignoring = true\n",
       "whatif: an empty ignore list asked",
       expect="an empty ignore list was asked about", script=S)

# --- a party aura with heals counted (Favours.lua) ---

mutate("Favours.lua",
       "\t\t\t\t\t\tif watching and spellId and not ns.OWN_BY_ID[spellId]\n",
       "\t\t\t\t\t\tif watching and spellId\n",
       "whatif: a party aura taken for a favour",
       expect="a paladin's aura and a hunter's aspect and Trueshot with heals counted", script=S)

# --- a group cast's line (GroupBuffs.lua, Prompt/Macro.lua) ---

mutate("GroupBuffs.lua",
       "\tif (a.reason == \"owed\") ~= (b.reason == \"owed\") then return a.reason == \"owed\" end\n",
       "",
       "whatif: a tied group cast aimed by name",
       expect="a ready check tied the party, and the cast was aimed at", script=S)

mutate("Prompt/Macro.lua",
       "\tif not member then return entry end\n",
       "\tdo return entry end\n",
       "whatif: the line to the anchor, not the one repaid",
       expect="the group cast repays Gwen, and the line", script=S)

mutate("GroupBuffs.lua",
       "\t\tif entry ~= anchor and entry.reason == \"owed\" and entry.ranged ~= false then\n",
       "\t\tif false then\n",
       "whatif: nobody repaid named on the cast",
       expect="the group cast repays Gwen, and the line", script=S)

# --- one line per person a minute (Prompt/Macro.lua, Prompt/Press.lua) ---

mutate("Prompt/Macro.lua",
       "\tlocal at = spokeAt[entry.name]\n",
       "\tlocal at = nil\n",
       "whatif: a line at every buff",
       expect="a second buff on Munin two seconds after the first said a line again", script=S)

mutate("Prompt/Press.lua",
       "\tif S.phraseArmed then ns.NoteLineSaid(ns.LineSpeaker(S.current).name, now) end\n",
       "",
       "whatif: the line said never noted",
       expect="a second buff on Munin two seconds after the first said a line again", script=S)

mutate("Prompt/Macro.lua",
       "\t\tand ns.LineRested(speaker, GetTime())\n",
       "",
       "whatif: the armed macro keeps the line the press drops",
       expect="the macro armed for Munin's second buff carries a line", script=S)

mutate("Prompt/Macro.lua",
       "\tif entry.reason == \"owed\" then return true end\n\tlocal at = spokeAt[entry.name]\n",
       "\tlocal at = spokeAt[entry.name]\n",
       "whatif: a thank-you held by the minute",
       expect="a thank-you for a favour was held back by the minute", script=S)

mutate("Prompt/Macro.lua",
       "local LINE_REST = 60\n",
       "local LINE_REST = 600\n",
       "whatif: the line held for ten minutes",
       expect="a minute after the last line, Munin's buff still says nothing", script=S)
