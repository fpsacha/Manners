# Mutations for the key boxes' wording: tests/scenarios/keybox-words.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts one box's tooltip
# back to what it said before and names the scenario that objects.

S = "runscenarios.py"
NEW = 'L["Click, then press a key or a controller button. Esc cancels, a right-click clears it. Saved with your game key bindings, so it works on every profile."]'
OLD = 'L["Saved with your game key bindings, so it works on every profile."]'

mutate("Options/Start.lua",
       NEW,
       OLD,
       "keybox-words: the Start page's key box says only that it is saved",
       expect="keybox-words: every key box's tooltip", script=S)

mutate("Options/Who.lua",
       NEW,
       OLD,
       "keybox-words: the Who page's key box says only that it is saved",
       expect="keybox-words: every key box's tooltip", script=S)

mutate("Options/Diagnostics.lua",
       '.. " " .. ' + NEW,
       '',
       "keybox-words: the Mark this moment key says nothing of how a key is set",
       expect="keybox-words: every key box's tooltip", script=S)

mutate("Options/Look.lua",
       NEW,
       OLD,
       "keybox-words: a key box on the Look page says only that it is saved",
       expect="keybox-words: every key box's tooltip", script=S)
