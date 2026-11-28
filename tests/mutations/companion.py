mutate(
    "Modules/Pets/Companion.lua",
    "return ns.ModuleActive(\"pets\") and db ~= nil and db.enabled == true and beast ~= nil and beast.companion == true",
    "return ns.ModuleActive(\"pets\") and db ~= nil and db.enabled == true and beast ~= nil",
    "companion: the switch is ignored",
    expect="companion: off by default, a long fight offers nothing",
    script="runscenarios.py",
)

mutate(
    "Modules/Pets/Companion.lua",
    "if was and Out() == was and clock.pullAt and now - clock.pullAt >= C.HARD_FIGHT then Trigger(\"praise\", now) end",
    "if was and Out() == was then Trigger(\"praise\", now) end",
    "companion: any fight brings a moment",
    expect="a short fight offered a moment",
    script="runscenarios.py",
)

mutate(
    "Modules/Pets/Companion.lua",
    "local lines = { \"/targetexact \" .. name, EmoteCommand(m.kind) }",
    "local lines = { EmoteCommand(m.kind) }",
    "companion: the emote goes at whatever is targeted",
    expect="the macro is",
    script="runscenarios.py",
)

mutate(
    "Modules/Pets/Companion.lua",
    "if Out() ~= moment.name then moment = nil return queue, verdicts end",
    "local _ = Out()",
    "companion: a moment outlives the companion put away",
    expect="the moment stayed after the companion was put away",
    script="runscenarios.py",
)

mutate(
    "Modules/Pets/Companion.lua",
    "if char then char.companionBondAt = time() end\n\t\t\tAfter(C.SHOW",
    "local _ = char\n\t\t\tAfter(C.SHOW",
    "companion: no gap between two moments",
    expect="a second moment came inside the gap",
    script="runscenarios.py",
)

mutate(
    "Modules/Pets/Companion.lua",
    "if not Wanted() or not MomentOn(kind) or GapLeft() > 0 then return end",
    "if not Wanted() or GapLeft() > 0 then return end",
    "companion: a moment's own switch is ignored",
    expect="well done was offered with its switch off",
    script="runscenarios.py",
)

mutate(
    "Modules/Pets/Companion.lua",
    "local answer = (beast and beast.companionAnswer ~= false) and",
    "local answer = beast and",
    "companion: the answer's switch is ignored",
    expect="with the answer off the macro is",
    script="runscenarios.py",
)

mutate(
    "Modules/Pets/Companion.lua",
    "\t\tAfter(C.SETTLE, function() ns.Guard(\"companion level\", Trigger, \"levelup\", GetTime()) end)",
    "\t\tlocal _ = C.SETTLE",
    "companion: a level brings no moment",
    expect="companion: a level, a quest, an inn, a return, a pause and a summon each bring a moment",
    script="runscenarios.py",
)
mutate(
    "Modules/Pets/Companion.lua",
    "\t\tTrigger(\"quest\", now)",
    "\t\tlocal _ = now",
    "companion: a quest handed in brings no moment",
    expect="companion: a level, a quest, an inn, a return, a pause and a summon each bring a moment",
    script="runscenarios.py",
)
mutate(
    "Modules/Pets/Companion.lua",
    "\t\tif resting and clock.resting == false and clock.leftRest and now - clock.leftRest >= C.AWAY_FROM_REST then",
    "\t\tif false then",
    "companion: an inn brings no moment",
    expect="companion: a level, a quest, an inn, a return, a pause and a summon each bring a moment",
    script="runscenarios.py",
)
mutate(
    "Modules/Pets/Companion.lua",
    "\t\tif clock.died and Ask(\"UnitIsDeadOrGhost\", \"player\") ~= true then",
    "\t\tif false then",
    "companion: back from the dead brings no moment",
    expect="companion: a level, a quest, an inn, a return, a pause and a summon each bring a moment",
    script="runscenarios.py",
)
mutate(
    "Modules/Pets/Companion.lua",
    "\tif now - clock.stillSince >= C.PLAY_AFTER then",
    "\tif false then",
    "companion: standing still never plays",
    expect="companion: a level, a quest, an inn, a return, a pause and a summon each bring a moment",
    script="runscenarios.py",
)
mutate(
    "Modules/Pets/Companion.lua",
    "\tif guid and clock.seen and was == nil then Trigger(\"hello\", now) end",
    "\tlocal _ = was",
    "companion: calling it out says no hello",
    expect="companion: a level, a quest, an inn, a return, a pause and a summon each bring a moment",
    script="runscenarios.py",
)
mutate(
    "Modules/Pets/Companion.lua",
    "\tplay = \"companionPlay\", levelup = \"companionLevel\", home = \"companionHome\", back = \"companionBack\",\n\tquest = \"companionQuest\" }",
    "\tplay = \"companionPlay\", levelup = \"companionLevel\", home = \"companionHome\", back = \"companionBack\" }",
    "companion: the quest switch is ignored",
    expect="companion: a level, a quest, an inn, a return, a pause and a summon each bring a moment",
    script="runscenarios.py",
)
mutate(
    "Modules/Pets/Companion.lua",
    "\thome = \"anniversary\", back = \"missed\", quest = \"praise\" }",
    "\thome = \"road\", back = \"missed\", quest = \"praise\" }",
    "companion: the inn moment pets instead of cuddling",
    expect="companion: a level, a quest, an inn, a return, a pause and a summon each bring a moment",
    script="runscenarios.py",
)
mutate(
    "Modules/Pets/Companion.lua",
    "\tfor _, text in ipairs(WORDS[kind] or WORDS.road) do",
    "\tfor _, text in ipairs({}) do",
    "companion: its own words are never said",
    expect="companion: a level, a quest, an inn, a return, a pause and a summon each bring a moment",
    script="runscenarios.py",
)

mutate(
    "Modules/Pets/Companion.lua",
    "\tAWAY_FROM_REST = 600,",
    "\tAWAY_FROM_REST = 0,",
    "companion: walking in and out of town brings a cuddle each time",
    expect="a minute out of town and back brought a cuddle",
    script="runscenarios.py",
)

AUTO = "companion: by itself, a moment is an /emote with no press"
mutate("Modules/Pets/Companion.lua",
       "\tif Auto() then\n\t\tDoItself(now)\n\t\treturn queue, verdicts\n\tend\n",
       "",
       "companion: by itself still waits on the prompt",
       expect=AUTO, script="runscenarios.py")
mutate("Modules/Pets/Companion.lua",
       "\tif char then char.companionBondAt = time() end\n\tns.Trail(\"pet\", \"a moment with the companion, by itself\"",
       "\tns.Trail(\"pet\", \"a moment with the companion, by itself\"",
       "companion: by itself, the gap never starts",
       expect=AUTO, script="runscenarios.py")
mutate("Modules/Pets/Companion.lua",
       "\tif not pcall(send, gesture, \"EMOTE\") then return end\n",
       "\tif not pcall(send, gesture, \"SAY\") then return end\n",
       "companion: by itself, it speaks in /say",
       expect=AUTO, script="runscenarios.py")
