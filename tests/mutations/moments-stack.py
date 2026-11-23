# Mutations for where the cards of the buttons for the moment sit:
# tests/scenarios/moments-stack.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts one guard back to
# its absence and names the scenario that objects.

S = "runscenarios.py"
M = "Prompt/Moments.lua"

mutate(M,
       '\tlocal baseAbove = math.max(listAbove, (state.artAbove or 0) * scale, sideAbove) + margin\n',
       '\tlocal baseAbove = math.max((state.artAbove or 0) * scale, sideAbove) + margin\n',
       "moments-stack: the list over the prompt is not cleared",
       expect="moments-stack: clear of the list above", script=S)

mutate(M,
       '\tlocal baseAbove = math.max(listAbove, (state.artAbove or 0) * scale, sideAbove) + margin\n',
       '\tlocal baseAbove = math.max(listAbove, sideAbove) + margin\n',
       "moments-stack: the painted art over the bar is not cleared",
       expect="moments-stack: clear of the list above", script=S)

mutate(M,
       '\tif W > pw then sideAbove, sideBelow = SideReach(p, scale, ph) end\n',
       '',
       "moments-stack: the buttons beside the prompt are not cleared",
       expect="moments-stack: clear of the list above", script=S)

mutate(M,
       '\tlocal baseBelow = math.max(listBelow, (state.artBelow or 0) * scale, sideBelow) + margin\n',
       '\tlocal baseBelow = math.max((state.artBelow or 0) * scale, sideBelow) + margin\n',
       "moments-stack: the list under the prompt is not cleared",
       expect="moments-stack: no room above: below the prompt", script=S)

mutate(M,
       '\tlocal baseBelow = math.max(listBelow, (state.artBelow or 0) * scale, sideBelow) + margin\n',
       '\tlocal baseBelow = math.max(listBelow, (state.artBelow or 0) * scale) + margin\n',
       "moments-stack: the second cure under the prompt is not cleared",
       expect="moments-stack: no room above: below the prompt", script=S)

mutate(M,
       '\tif baseAbove + H > roomAbove and baseBelow + H <= roomBelow then above = false end\n',
       '',
       "moments-stack: a prompt at the top of the screen keeps its cards above it",
       expect="moments-stack: no room above: below the prompt", script=S)

mutate(M,
       '\tlocal perCol = math.max(1, math.min(MAX, math.floor((room - base + gap) / (H + gap))))\n',
       '\tlocal perCol = MAX\n',
       "moments-stack: a tall column never wraps",
       expect="moments-stack: a tall column wraps", script=S)

mutate(M,
       '\tlocal lefts = type(left) == "number" and left * ratio >= W + gap + 10\n',
       '\tlocal lefts = true\n',
       "moments-stack: the columns go left off the screen's edge",
       expect="moments-stack: a tall column wraps", script=S)

mutate(M,
       '\tfor _, slot in ipairs(calm) do slotsOf[slot] = 0 end\n',
       '\tfor _, slot in ipairs(calm) do slotsOf[slot] = #list end\n',
       "moments-stack: the drink has a place of its own",
       expect="moments-stack: the drink shares the first place", script=S)

mutate(M,
       '\t\tor (type(m) == "table" and m.cardSize or nil) ~= placedSize then\n',
       '\t\tthen\n',
       "moments-stack: a new card size is not noticed",
       expect="moments-stack: Wanted re-places", script=S)

mutate(M,
       '\tif (Prompt.state and Prompt.state.styleSerial) ~= placedSerial\n',
       '\tif false\n',
       "moments-stack: a drag of the prompt is not noticed",
       expect="moments-stack: Wanted re-places", script=S)

mutate(M,
       '\ttable.sort(fight, function(a, b)\n\t\treturn (ORDER[a.row.key] or 50) + a.n / 100 < (ORDER[b.row.key] or 50) + b.n / 100\n\tend)\n',
       '',
       "moments-stack: the cards sit in slot order, not nearest first",
       expect="moments-stack: nearest first", script=S)

mutate("Prompt/Panel.lua",
       '\tS.artAbove, S.artBelow = math.ceil(above), math.ceil(below)\n',
       '',
       "moments-stack: the painted bar tells the cards nothing of its art",
       expect="moments-stack: the painted bar tells the cards", script=S)

mutate("Prompt/Panel.lua",
       '\tS.artAbove, S.artBelow = nil, nil\n',
       '',
       "moments-stack: a look with no painting keeps the last one's art",
       expect="moments-stack: the painted bar tells the cards", script=S)

mutate("Prompt/Panel.lua",
       '\t\tS.styleSerial = (S.styleSerial or 0) + 1\n',
       '',
       "moments-stack: restyling the prompt does not move the serial",
       expect="moments-stack: the painted bar tells the cards", script=S)

mutate("Prompt/Rows.lua",
       '\tS.rowPitch = placedPitch\n',
       '',
       "moments-stack: the list's row pitch is not told",
       expect="moments-stack: the painted bar tells the cards", script=S)
