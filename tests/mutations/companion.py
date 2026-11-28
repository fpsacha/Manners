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
    "if char then char.companionBondAt = time() end",
    "local _ = char",
    "companion: no gap between two moments",
    expect="a second moment came inside the gap",
    script="runscenarios.py",
)
