# Mutations for the spells that strip a buff, for the moment (Purge, Dispel Magic,
# Tranquilizing Shot, Shield Slam): tests/scenarios/moments-strip.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts one guard back to
# its absence and names the scenario that objects.

S = "runscenarios.py"
SENSE = "Prompt/MomentsSense.lua"
DATA = "Prompt/MomentsData.lua"

mutate(SENSE,
       '\tif type(kind) == "string" and kinds[kind] then return "fits" end\n',
       '\tif false then return "fits" end\n',
       "moments-strip: a buff of a kind the spell removes is not seen",
       expect="moments-strip: Purge: a magic buff lights it", script=S)

mutate(SENSE,
       '\tif type(_G.IsInGroup) == "function" and plain(_G.IsInGroup()) == false then return "yes" end\n',
       '',
       "moments-strip: the game's filter never lights it on your own",
       expect="moments-strip: withheld, on your own: the game's filter decides plainly", script=S)

mutate(SENSE,
       '\tif type(_G.IsInGroup) == "function" and plain(_G.IsInGroup()) == false then return "yes" end\n',
       '\tif true then return "yes" end\n',
       "moments-strip: the game's filter lights it in a group too",
       expect="moments-strip: only the kinds hidden: in a group Tranquilizing Shot stays dark", script=S)

mutate(SENSE,
       '\tif #ids == 0 then return "no" end\n\tif type(_G.IsInGroup)',
       '\tif type(_G.IsInGroup)',
       "moments-strip: an empty filter does not say no",
       expect="moments-strip: withheld, on your own: the game's filter decides plainly", script=S)

mutate(SENSE,
       '\tlocal ok, ids = pcall(listed, "target", DISPELLABLE)\n',
       '\tlocal ok, ids = true, listed("target", DISPELLABLE)\n',
       "moments-strip: a client that refuses the filter throws",
       expect="moments-strip: the filter refused", script=S)

mutate(DATA,
       'kinds = kinds, purge = kinds.Magic == true, stop = true,',
       'kinds = kinds, purge = true, stop = true,',
       "moments-strip: the stealable flag counts for a spell that takes no magic",
       expect="moments-strip: Tranquilizing Shot: an enrage lights it, a magic buff does not on Forever", script=S)

mutate(DATA,
       '\t\tguard = "twice", needs = STRIP }\n',
       '\t\tneeds = STRIP }\n',
       "moments-strip: a game-painted strip takes one click",
       expect="moments-strip: withheld, in a group", script=S)

mutate(DATA,
       'Strip("shieldslam", ranks, MAGIC, { stop = false, cooldown = 6 })',
       'Strip("shieldslam", ranks, MAGIC, { cooldown = 6 })',
       "moments-strip: Shield Slam stops a Slam under way",
       expect="moments-strip: Shield Slam ships off", script=S)

mutate(DATA,
       'purge = true, dispel = true, tranq = true, shieldslam = false }',
       'purge = true, dispel = true, tranq = true, shieldslam = true }',
       "moments-strip: Shield Slam ships on",
       expect="moments-strip: the rows per client", script=S)

mutate(DATA,
       'PRIEST = Strip("dispel", { 528 }, MAGIC),\n\tHUNTER = Strip("tranq", { 19801 }, ENRAGE_MAGIC), WARRIOR',
       'PRIEST = Strip("dispel", { 527 }, MAGIC),\n\tHUNTER = Strip("tranq", { 19801 }, ENRAGE_MAGIC), WARRIOR',
       "moments-strip: Mists' Dispel Magic is Purify's id",
       expect="moments-strip: Dispel Magic on Mists is 528", script=S)

mutate("Prompt/Moments.lua",
       '\t\t\tif needs.stealable or needs.removable then Register("UNIT_AURA", "target") end\n',
       '\t\t\tif needs.stealable then Register("UNIT_AURA", "target") end\n',
       "moments-strip: a strip does not hear its target's auras change",
       expect="moments-strip: Purge: a magic buff lights it", script=S)
