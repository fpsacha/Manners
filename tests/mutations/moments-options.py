# Mutations for the options of the buttons for the moment:
# tests/scenarios/moments-options.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts one guard back to
# its absence and names the scenario that objects.

S = "runscenarios.py"

mutate("Options/Window/WindowPage.lua",
       'FIELDS["appearance.momentMana"] = { { "moments", "mana" } }\n',
       '',
       "moments-options: the mana slider carries no changed mark",
       expect="moments-options: the changed marks follow each field", script=S)

mutate("Options/Advanced.lua",
       '\t"moments.health", "moments.mana",\n',
       '\t"moments.health",\n',
       "moments-options: the reset leaves the mana share out",
       expect="moments-options: the reset puts the twelve fields back", script=S)

mutate("Options/Window/Layout.lua",
       '"appearance.momentSlowfall", { "appearance.momentSlowfallKey", indent = true },\n',
       '"appearance.momentSlowfall", "appearance.momentSlowfallKey",\n',
       "moments-options: Slow Fall's key is not indented under its switch",
       expect="moments-options: every control is placed once with its key under it", script=S)

mutate("Options/Look.lua",
       '\t\t\thidden = function() return not Has(key) end,\n\t\t\tget = function() return On(key) end,\n',
       '\t\t\thidden = function() return not Has(key) or not HasPrompt() end,\n\t\t\tget = function() return On(key) end,\n',
       "moments-options: a switch is gone for a character with no prompt",
       expect="moments-options: a character with no prompt and a moment row still sees its switch", script=S)

mutate("Options/Look.lua",
       '\t\t\thidden = function() return not Has(key) or not On(key) or not ns.Setup.CanBind() end,\n',
       '\t\t\thidden = function() return not Has(key) or not ns.Setup.CanBind() end,\n',
       "moments-options: a key shows with its switch off",
       expect="moments-options: a switch arms and disarms the button", script=S)

mutate("Options/Look.lua",
       'L["Show %s when I need %s and it is cooling down"]:format(Spell("coldsnap"), Spell("iceblock"))',
       'L["Show %s when I need %s and it is cooling down"]:format(Spell("coldsnap"), Spell("coldsnap"))',
       "moments-options: Cold Snap's switch names itself twice",
       expect="moments-options: the names carry the client's spell names", script=S)

mutate("Options/Look.lua",
       '\t\t\t\tif reagent then text = text .. " " .. L["It needs a %s in your bags."]:format(reagent) end\n',
       '',
       "moments-options: Slow Fall's text leaves its reagent out",
       expect="moments-options: the names carry the client's spell names", script=S)
