# Mutations for the fight's three weak points of the 2026-11-15 review
# (Prompt/Fight.lua, Prompt/Macro.lua, Prompt/Refresh.lua, Clicks.lua's bar
# macro, Queue.lua's remembered passers-by). Caught by
# tests/scenarios/par-core2.lua.

S = "runscenarios.py"
FIGHT = "Prompt/Fight.lua"
REFRESH = "Prompt/Refresh.lua"
GONE = "par-core2: a pull three seconds after a crowd walked off arms none of them"

# 1. What the pull arms: nobody offered from memory alone.
mutate(FIGHT,
       "\t\tif outOnly or (entry.remembered and entry.reason == \"nearby\") then\n",
       "\t\tif outOnly or false then\n",
       "par-core2: the pull keeps passers-by remembered",
       expect=GONE, script=S)

mutate("Queue.lua",
       "\t\t\t\tremembered = true,\n",
       "",
       "par-core2: a remembered passer-by is not marked as one",
       expect=GONE, script=S)

mutate(REFRESH,
       "\tif ArmingForFight() then queue = ForFight(queue) end\n",
       "",
       "par-core2: the pull's repaint arms the queue as built",
       expect="par-core2: at a pull with one passer-by still beside you and two gone", script=S)

mutate(FIGHT,
       "\t\tif outOnly or (entry.remembered and entry.reason == \"nearby\") then\n",
       "\t\tif outOnly or entry.unit == nil then\n",
       "par-core2: the pull leaves out everybody with no token",
       expect="par-core2: a favour owed with no token is still armed at the pull", script=S)

mutate(REFRESH,
       "\tif ArmingForFight() then queue = ForFight(queue) end\n",
       "\tqueue = ForFight(queue)\n",
       "par-core2: the memory is left out of every repaint",
       expect="par-core2: out of a fight a passer-by who walked off is still offered", script=S)

# 2. The fight's hand-back runs only after a /target that found somebody
# friendly.
MACRO = "Prompt/Macro.lua"
MOB = "par-core2: a press in a fight whose /target finds nobody leaves your mob targeted"

mutate(MACRO,
       "\tif Prompt.armedForFight == true then return FIGHT_HANDBACK end\n",
       "",
       "par-core2: the fight's macro hands back whatever the /target found",
       expect=MOB, script=S)

mutate(MACRO,
       "local FIGHT_HANDBACK = \"/targetlasttarget [help]\"\n",
       "local FIGHT_HANDBACK = \"/targetlasttarget [exists]\"\n",
       "par-core2: the fight's hand-back asks only that something is targeted",
       expect=MOB, script=S)

mutate(MACRO,
       "local FIGHT_HANDBACK = \"/targetlasttarget [help]\"\n",
       "local FIGHT_HANDBACK = \"/targetlasttarget [@player,help]\"\n",
       "par-core2: the fight's hand-back names a unit",
       expect="the fight's macro names a unit in a conditional", script=S)

mutate("Clicks.lua",
       "\t\t\telseif command == \"targetlasttarget\" and arg == \"[help]\" then\n",
       "\t\t\telseif false then\n",
       "par-core2: the fight's bar macro is not Manners' own shape",
       expect="par-core2: the fight's bar macro left from a session before is Manners' own (1)", script=S)

mutate("Clicks.lua",
       "\t\t\telseif command == \"targetlasttarget\" and arg == \"[help]\" then\n",
       "\t\t\telseif command == \"targetlasttarget\" and arg:find(\"[\", 1, true) then\n",
       "par-core2: any conditional on the hand-back is Manners' own",
       expect="par-core2: the fight's bar macro left from a session before is Manners' own (2)", script=S)

mutate("SelftestLaunch.lua",
       "\t\tand (Plain(help) == \"yes\") ~= Plain(assist) then\n",
       "\t\tand false then\n",
       "par-core2: the launch check never says [help] reads the target wrong",
       expect="par-core2: the launch check says what [help] reads (3)", script=S)

mutate("SelftestLaunch.lua",
       "\tlocal okH, help = Ask(_G.SecureCmdOptionParse, \"[help] yes; no\")\n",
       "\tlocal okH, help = true, \"yes\"\n",
       "par-core2: the launch check asks the parser nothing",
       expect="par-core2: the launch check says what [help] reads (2)", script=S)

# 3. The fight's rota goes round once, and the bar macro says what it does in
# a fight.
ONCE = "par-core2: in a fight the rota presses for each person once, then casts nothing (camelot)"

mutate(FIGHT,
       "\tlocal i = (control:GetAttribute(\"manners-rota-i\") or 1) + 1\n",
       "\tlocal i = (control:GetAttribute(\"manners-rota-i\") or 1) % n + 1\n",
       "par-core2: the rota comes round again",
       expect=ONCE, script=S)

mutate(FIGHT,
       "\tif i > n then text = nil end\n",
       "",
       "par-core2: the rota casts from an earlier fight's longer rota",
       expect="par-core2: a longer rota of an earlier fight is never cast from", script=S)

mutate(FIGHT,
       "\tif i > #rota.entries then\n",
       "\tif false then\n",
       "par-core2: the panel stays on the rota's last person once it is done",
       expect="after the rota's last press the second line reads", script=S)

mutate(FIGHT,
       "\t\tS.current, S.frozenEntry, S.armed = nil, nil, nil\n\t\tns.lastMacro",
       "\t\tS.frozenEntry, S.armed = nil, nil\n\t\tns.lastMacro",
       "par-core2: the done rota leaves the last person as current",
       expect="after the rota's last press the second line reads", script=S)

mutate(REFRESH,
       "\t\t\t\t\tself:FightRotaDone() and L[\"in a fight -- everybody it began with has had a press\"]\n\t\t\t\t\tor L[",
       "\t\t\t\t\tL[",
       "par-core2: the done rota reads as an empty queue",
       expect="after the rota's last press the second line reads", script=S)

mutate("Options/Start.lua",
       "\t\t\t\t\treturn L[\"Makes the Manners macro and puts it on your cursor: drop it on any action bar slot. The slot then shows the spell a press would cast.\"]\n\t\t\t\t\t\t.. \" \" .. fight\n",
       "\t\t\t\t\treturn L[\"Makes the Manners macro and puts it on your cursor: drop it on any action bar slot. The slot then shows the spell a press would cast.\"]\n",
       "par-core2: the bar macro's button says nothing of a fight",
       expect="does not say what the macro does in a fight", script=S)

mutate("Options/Start.lua",
       "\t\t\t\t\tif p and p.fightRota ~= false then\n",
       "\t\t\t\t\tif p then\n",
       "par-core2: the bar macro's button promises the prompt moves on with the rota off",
       expect="with the rota off the line still says the prompt moves on", script=S)

mutate(REFRESH,
       "\t\t\tif S.fightLine then\n",
       "\t\t\tif false then\n",
       "par-core2: the fuse after a fight keeps the fight's line",
       expect="par-core2: the fight over with nobody left, the second line no longer speaks of the fight", script=S)
