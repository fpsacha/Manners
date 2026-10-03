# Mutations for the pcall budget per scan and for the player's own casts
# (tests/scenarios/perf-budget.lua): a protected call put back on a busy path,
# and the cast events handed back to AceEvent's dispatch of everybody's.
# Each is caught by the scenario that names it.
#
# Run by selftest.py with mutate() in scope. Its sibling in perf.py puts the
# PvP flags back on safecall, which the raid's budget catches.

S = "runscenarios.py"

# The proximity ladder's rungs asked through safecall again, for every
# passer-by on every scan: a pcall each, eighteen more per city scan than the
# rungs that protect their own library call need.
mutate("Range.lua",
       "\t\t\tlocal near, answered = rung.ask(unit)\n",
       "\t\t\tlocal near, answered = safecall(rung.ask, unit)\n",
       "perf-budget: the ladder's rungs back on safecall",
       expect="perf-budget: a city scan makes at most 12 pcalls", script=S)

# The player's casts registered through AceEvent again, which hands every cast
# in sight to a handler that throws it away.
mutate("Core.lua",
       "\t\t\tif type(casts.RegisterUnitEvent) == \"function\" then\n",
       "\t\t\tif false then\n",
       "perf-budget: cast events for everybody",
       expect="is not registered for the player alone", script=S)

mutate("Core.lua",
       "\t\t\t\tcasts:RegisterUnitEvent(event, \"player\")\n",
       "\t\t\t\tself:RegisterEvent(event)\n",
       "perf-budget: cast events back on AceEvent",
       expect="goes through AceEvent, which hands every cast in sight to the handler", script=S)

# The frame's script handing the payload over without the event's name, which
# every handler takes first (AceEvent's order).
mutate("Core.lua",
       "function(_, event, ...) addon[event](addon, event, ...) end",
       "function(_, event, ...) addon[event](addon, ...) end",
       "perf-budget: the cast frame drops the event name",
       expect="the cast frame handed the event over as", script=S)

# A mage's familiar read best first again (Core.lua, ReadFamiliar): the Cat's
# and the Frog's aura asked on every scan before the Rat's he has up, whatever
# his level and whichever he had up last -- four pcalls a scan where two do.
mutate("Core.lua",
       "\t\t\tif i == 0 then\n\t\t\t\tspell = last\n\t\t\telseif spell == last or spell.level > level then\n",
       "\t\t\tif i == 0 then\n\t\t\t\tspell = nil\n\t\t\telseif false then\n",
       "perf-budget: three familiars read on every scan",
       expect="perf-budget: a mage's scrolls cost a raid scan with group casts at most 2 pcalls", script=S)

# The looks measuring again what FitLine has just measured, or the same count
# on every repaint: a pcall a scan each, over the city's ceiling.
mutate("Looks/Toast.lua",
       "\tself.nameWidth = kit.fit.drawn[kit.name] or kit.TextWidth(kit.name)\n",
       "\tself.nameWidth = kit.TextWidth(kit.name)\n",
       "perf-budget: Toast measures the name every repaint",
       expect="perf-budget: a city scan in any look makes at most 12 pcalls", script=S)

mutate("Looks/Arcane.lua",
       "\t\tif text ~= self.countText or not self.countW then\n",
       "\t\tif true then\n",
       "perf-budget: Arcane measures the count every repaint",
       expect="perf-budget: a city scan in any look makes at most 12 pcalls", script=S)

mutate("Looks/Arcane.lua",
       "\tlocal width, size, base = fit.drawn[name] or kit.TextWidth(name), fit.size[name], fit.base[name]\n",
       "\tlocal width, size, base = kit.TextWidth(name), fit.size[name], fit.base[name]\n",
       "perf-budget: Arcane measures the name on every fit",
       expect="perf-budget: a city scan in any look makes at most 12 pcalls", script=S)
