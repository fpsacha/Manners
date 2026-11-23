# Mutations for the cure button's cover: tests/scenarios/curefight-cover.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts one guard back to
# its absence and names the scenario that objects.

S = "runscenarios.py"
CF = "Prompt/CureFight.lua"

mutate(CF,
       '\tif slot.cover then slot.cover:SetShown(fightOn and not on and slot.mouseOn == true and not Open(slot, GetTime())) end\n',
       '\tif slot.cover then slot.cover:SetShown(false) end\n',
       "curefight-cover: the cover is not shown when the cure is out of sight",
       expect="curefight-cover: no key: a click while nobody needs a cure casts nothing", script=S)

mutate(CF,
       '\tif slot.cover then slot.cover:SetShown(fightOn and not on and slot.mouseOn == true and not Open(slot, GetTime())) end\n',
       '\tif slot.cover then slot.cover:SetShown(fightOn and slot.mouseOn == true and not Open(slot, GetTime())) end\n',
       "curefight-cover: the cover is left up over a lit cure",
       expect="curefight-cover: no key: while somebody needs a cure the cover is down", script=S)

mutate(CF,
       '\tif slot.keyLabel == nil and slot.cover and slot.cover:IsShown() then\n',
       '\tif false then\n',
       "curefight-cover: the leak check is removed",
       expect="curefight-cover: a click that gets past the cover is counted and said", script=S)

mutate(CF,
       '\tslot.mouseOn = used ~= false and slot.keyLabel == nil\n',
       '\tslot.mouseOn = true\n',
       "curefight-cover: a cover is used with a key bound",
       expect="curefight-cover: with a key bound there is no cover and no mouse", script=S)

mutate(CF,
       'function CureFight:Release()\n\tfightOn = false\n',
       'function CureFight:Release()\n',
       "curefight-cover: the cover stands after the fight",
       expect="curefight-cover: nothing protected is called through a fight", script=S)

mutate(CF,
       '\tlast.covered = last.covered + 1\n',
       '',
       "curefight-cover: a swallowed click is not counted",
       expect="curefight-cover: no key: a click while nobody needs a cure casts nothing and is counted", script=S)

mutate(CF,
       '\tcover:EnableMouse(true)\n',
       '\tcover:EnableMouse(false)\n',
       "curefight-cover: the cover takes no mouse",
       expect="curefight-cover: no key: a click while nobody needs a cure casts nothing", script=S)
