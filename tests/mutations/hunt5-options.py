# The fifth bug hunt's options-page and launcher-menu fixes, each put back and
# required to be caught by its scenario in tests/scenarios/hunt5-options.lua.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# ------------------------------------------------- compartment-claim-when-hidden
mutate("Options.lua",
       "\tlocal ok, shown = pcall(frame.IsShown, frame)\n\treturn ok and shown and true or false\n",
       "\treturn true\n",
       "hunt5-options: the minimap switch ignores a hidden compartment",
       expect="with the compartment hidden, the switch still says", script=S)

mutate("Options.lua",
       "\tif not compartment or type(frame) ~= \"table\" then return false end\n",
       "\tif type(frame) ~= \"table\" then return false end\n",
       "hunt5-options: the minimap switch ignores an unregistered compartment",
       expect="never registered, the switch still says", script=S)

# ------------------------------------------------- font-dropdown-blank-unregistered-key
mutate("Options.lua",
       "\t\t\t\t\t\t\tlocal chosen = P().font\n\t\t\t\t\t\t\tif type(chosen) == \"string\" and not list[chosen] then\n",
       "\t\t\t\t\t\t\tlocal chosen = P().font\n\t\t\t\t\t\t\tif false then\n",
       "hunt5-options: the Font dropdown drops an unregistered font",
       expect="the chosen font is missing from the Font dropdown", script=S)

# ------------------------------------------------- cvd-palette-desc-four-colours
mutate("Options.lua",
       "The colour-blind set keeps the reasons apart for red-green colour blindness, in colours that differ in lightness too.\"",
       "The colour-blind set keeps the four reasons apart for red-green colour blindness: pale yellow, orange, sky blue and violet, which differ in lightness too.\"",
       "hunt5-options: the colour-blind description counts four colours",
       expect="hunt5-options: the colour-blind description counts no colours", script=S)

# The description no longer says askers share the passers-by colour: the
# colour-blind set gives them a pink of their own (Prompt.lua REASON_COLOR_CVD).
# The scenario still holds the sentence to whichever is true; a mutation that
# claimed the opposite would now be claiming the truth, so there is none.

# ------------------------------------------------- profile-menu-sort-ascii-lower
mutate("Options.lua",
       "\ttable.sort(names, NameBefore)\n",
       "\ttable.sort(names, function(a, b) return a:lower() < b:lower() end)\n",
       "hunt5-options: the Profiles submenu sorts by raw bytes",
       expect="the profiles are listed as", script=S)
