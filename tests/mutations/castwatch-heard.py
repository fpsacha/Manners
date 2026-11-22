# Mutations for what the cast watch hears (Favours.lua OnCast and SpellOfCast,
# Commands.lua's debug lines, Options/Diagnostics.lua's check-up line). Each is
# caught by the scenario in tests/scenarios/castwatch-heard.lua (or the budget in
# perf-budget.lua) that names it.

S = "runscenarios.py"
N = "castwatch-heard: "
HEAD = "if who == nil or type(UnitCanAttack) ~= \"function\" or plain(UnitCanAttack(\"player\", who)) ~= true then"

mutate("Favours.lua",
       "stat.heard = stat.heard + 1",
       "stat.heard = stat.heard + 0",
       "castwatch-heard: a stranger's cast is never counted heard",
       expect=N + "a stranger's withheld cast is counted heard", script=S)

mutate("Favours.lua",
       "if who == nil then stat.noUnit",
       "if false then stat.noUnit",
       "castwatch-heard: a withheld caster is never counted",
       expect=N + "a cast with its caster withheld is counted", script=S)

mutate("Favours.lua",
       "id = SpellOfCast(castGUID)",
       "id = nil",
       "castwatch-heard: no spell is read from the cast id",
       expect=N + "a withheld spell is read from a plain cast id and names the caster", script=S)

mutate("Favours.lua",
       HEAD,
       "if false then",
       "castwatch-heard: a cast nobody can read does not block the moment",
       expect=N + "a withheld cast in the window names nobody", script=S)

mutate("Favours.lua",
       "\"^Cast%-%d+%-%d+%-%d+%-%d+%-(%d+)%-%x+$\"",
       "\"%-(%d+)%-%x+$\"",
       "castwatch-heard: a cast id of any shape gives a spell",
       expect=N + "a cast id of another shape reads no spell", script=S)

mutate("Favours.lua",
       "seen.readLate and \"old\" or \"none\"",
       "\"none\"",
       "castwatch-heard: a late read is filed as no cast seen",
       expect=N + "a buff read long after it landed says so", script=S)

mutate("Commands.lua",
       "last.why == \"old\"",
       "false",
       "castwatch-heard: the debug line never says a buff was read late",
       expect=N + "a buff read long after it landed says so", script=S)

mutate("Commands.lua",
       "cast.heard, cast.noSpell",
       "0, cast.noSpell",
       "castwatch-heard: /manners debug counts nothing heard",
       expect=N + "/manners debug and the bug report carry what was heard", script=S)

mutate("Options/Diagnostics.lua",
       "tostring(cast.heard)",
       "\"0\"",
       "castwatch-heard: the check-up counts nothing heard",
       expect=N + "/manners debug and the bug report carry what was heard", script=S)

mutate("Favours.lua",
       "id = SpellOfCast(castGUID)",
       "id = ns.safecall(SpellOfCast, castGUID)",
       "castwatch-heard: the cast id is read through a protected call",
       expect="perf-budget: a stranger's cast with its spell withheld costs the cast watch no protected call", script=S)

mutate("Favours.lua",
       "or plain(UnitCanAttack(\"player\", who)) ~= true then",
       "or true then",
       "castwatch-heard: a mob's hidden cast blocks the moment",
       expect=N + "a withheld cast from a mob does not stop a stranger being named", script=S)
