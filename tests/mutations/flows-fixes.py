# Mutations for the flows bug hunt's fixes (round 30): a favour or a top-up
# offered over a stronger rank (Core.lua), a press in the air on a flying mount
# (Queue.lua, Prompt/Press.lua), a shout's reach on Mists and retail (Core.lua,
# Buffs.lua) and one cast settling only the party member it was aimed at
# (Prompt/Press.lua, Clicks.lua, Buffs.lua). Each undoes a fix and is caught
# by the scenario in tests/scenarios/flows-fixes.lua it names.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# ------------------------------------------------------------ a stronger rank
# A rank above the one your cast lands read as any other cover: a debt is
# repaid with a cast the game refuses, and the thank-you goes out over it.
mutate("Core.lua",
       "\t\t\t\t\tif isRank and landing and worn > landing and worn <= level + 10 then over = true end\n",
       "",
       "flows-fix: a stronger rank not read",
       expect="flows-fix: vanilla: a favour is not repaid with a rank weaker than the one they wear",
       script=S)

# The walk offering what they hold over a stronger rank, as a refresh or a top-up.
mutate("Core.lua",
       "\t\t\t\telseif not over then\n",
       "\t\t\t\telse\n",
       "flows-fix: the walk offering over a stronger rank",
       expect="flows-fix: vanilla: no top-up is offered over a rank stronger than yours",
       script=S)

# The aura cache forgetting the stronger rank: the press's own scan, a moment
# after the one that read it, offers her again and says the line.
mutate("Core.lua",
       "\t\t\tcached.over = over\n",
       "",
       "flows-fix: the cache forgetting a stronger rank",
       expect="the press thanks Petra over a cast the game refuses",
       script=S)

# A paladin's debt falling back on another paladin's stronger blessing.
mutate("Core.lua",
       "\t\t\t\t\t\t\telseif not theirs and not over then\n",
       "\t\t\t\t\t\t\telseif not theirs then\n",
       "flows-fix: a paladin's debt under another's stronger blessing",
       expect="flows-fix: vanilla: a paladin's debt is not repaid under another paladin's stronger blessing",
       script=S)

# ...and repaid under a stronger blessing nobody the client names cast.
mutate("Core.lua",
       "\t\t\t\t\t\tif over then return nil, true end\n",
       "",
       "flows-fix: a paladin's debt under a nameless stronger blessing",
       expect="flows-fix: vanilla: a paladin's debt is not repaid under nobody's stronger blessing",
       script=S)

# ------------------------------------------------------------ in the air
# The press never asking whether you are up in the air: its line goes out over
# "You are mounted".
mutate("Prompt/Press.lua",
       "\tif ns.FlyingCastFails() then return true end\n",
       "",
       "flows-fix: the line said in the air",
       expect="in the air on a flying mount the press says no line",
       script=S)

# Auto Dismount in Flight ignored: the cast lands, and the line is held anyway.
mutate("Queue.lua",
       "\treturn not (value == \"1\" or value == 1 or value == true)\n",
       "\treturn true\n",
       "flows-fix: Auto Dismount in Flight ignored",
       expect="in the air with Auto Dismount in Flight on, the press says its line",
       script=S)

# "You are mounted" charged to the person: backed off, and blamed in chat.
mutate("Queue.lua",
       "\t\t\"SPELL_FAILED_INTERRUPTED\", \"SPELL_FAILED_NOT_MOUNTED\" }\n",
       "\t\t\"SPELL_FAILED_INTERRUPTED\" }\n",
       "flows-fix: your mount blamed on them",
       expect="refused for being mounted, nobody is backed off",
       script=S)

# ------------------------------------------------------------ a shout's reach
# Mists' and retail's shouts measured by vanilla's reach again.
mutate("Buffs.lua",
       "\tns.SHOUT_YARDS = chosen.shoutYards\n",
       "",
       "flows-fix: a shout's 100 yards forgotten",
       expect="a shout repays a party member 40 yards off, inside its 100 yards",
       script=S)

# The client's sight not asked: Anna, 40 yards off, is offered on no reading,
# and the shout aimed at Bert does not repay her.
mutate("Core.lua",
       "\tif wide and type(_G.UnitIsVisible) == \"function\" then\n",
       "\tif false then\n",
       "flows-fix: a shout's reach not asked of the client's sight",
       expect="a shout repays a party member 40 yards off, inside its 100 yards",
       script=S)

# The follow prompt's 28 yards a no for a 100-yard shout.
mutate("Core.lua",
       "\t\tif follow ~= nil and not wide then return false end\n",
       "\t\tif follow ~= nil then return false end\n",
       "flows-fix: the follow prompt's no for a 100-yard shout",
       expect="a party member 40 yards off is offered a shout where only the follow prompt answers",
       script=S)

# Vanilla's shout given Mists' reach.
mutate("Core.lua",
       "\tlocal wide = ns.SHOUT_YARDS\n",
       "\tlocal wide = ns.SHOUT_YARDS or 100\n",
       "flows-fix: a 20-yard shout given 100 yards",
       expect="flows-fix: vanilla: a shout still reaches nobody 40 yards off",
       script=S)

# ------------------------------------------------------------ one cast, the whole party
# The press on one party member settling them alone.
mutate("Prompt/Press.lua",
       "\t\tns.pendingClick.wideMembers = names\n",
       "",
       "flows-fix: a party-wide cast settling one",
       expect="one cast on a party member returns every favour in the party",
       script=S)

# ...or every favour it read in the queue, a passer-by's included.
mutate("Prompt/Press.lua",
       "\t\t\tif entry.name ~= S.current.name and entry.inGroup and entry.ranged ~= false\n",
       "\t\t\tif entry.name ~= S.current.name and entry.ranged ~= false\n",
       "flows-fix: a party-wide cast settling a passer-by",
       expect="a cast on a party member does not return a passer-by's favour",
       script=S)

# A spell that lands on its target alone settling the party with it.
mutate("Prompt/Press.lua",
       "\tif ns.WIDE_CASTS and S.current.inGroup and not stale and cast and not cast.selfCast and not cast.alone\n",
       "\tif ns.WIDE_CASTS and S.current.inGroup and not stale and cast and not cast.selfCast\n",
       "flows-fix: a single-target spell settling the party",
       expect="flows-fix: mists: a warlock's Unending Breath on one party member returns nobody else's favour",
       script=S)
