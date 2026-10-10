# What the UI hunt fixed (tests/scenarios/hunt-ui-fixes.lua): the opacity
# slider of the Classic clients' colour picker, which means transparency; a
# swatch clicked while another's picker is up; and the prompt's sound for a
# passer-by on the panel who then buffs you. Each fault put back has to be
# caught by the check it names.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

PICKER = ("hunt-ui-fix: colour picker: the opacity slider of the Panel colour swatch "
          "means what the client's picker means by it (vanilla)")

# ------------------------------------------------ the opacity slider
# The picker handed the alpha as it stands: an 88% opaque panel opens with the
# slider at the transparent end's 0.88.
mutate("Options/Window/WidgetsChoice.lua",
       "opacity = SliderAlpha(a), hasOpacity",
       "opacity = a, hasOpacity",
       "hunt-ui-fix: the picker opened on the alpha, not the slider's transparency",
       expect=PICKER,
       script=S)

# The slider's value stored as the alpha: dragging to "+", the opaque end,
# writes an alpha of 0 and the panel is gone.
mutate("Options/Window/WidgetsChoice.lua",
       "a = SliderAlpha(ColorPickerFrame:GetColorAlpha())",
       "a = ColorPickerFrame:GetColorAlpha()",
       "hunt-ui-fix: the slider's transparency stored as the alpha",
       expect=PICKER,
       script=S)

# The flip applied on Forever and retail as well, whose picker answers the
# alpha itself.
mutate("Options/Window/WidgetsChoice.lua",
       "or not (ns.Flavour and ns.Flavour.family == \"classic\") then return v end",
       "or false then return v end",
       "hunt-ui-fix: the flip applied on Forever and retail",
       expect=("hunt-ui-fix: colour picker: the opacity slider of the Panel colour swatch "
               "means what the client's picker means by it (camelot)"),
       script=S)

# The flip left unrounded: 1 - (1 - 0.3) is 0.30000000000000004, and a swatch
# opened and accepted moves the stored opacity by a float's last digit.
mutate("Options/Window/WidgetsChoice.lua",
       "return math.floor((1 - v) * 10000 + 0.5) / 10000",
       "return 1 - v",
       "hunt-ui-fix: the flip left to drift a stored opacity",
       expect=("hunt-ui-fix: colour picker: opening and accepting a swatch leaves its "
               "opacity as it was (vanilla)"),
       script=S)

# ------------------------------------------------ a second swatch
# The picker not closed first: a shown frame is not shown again, the classic
# one's OnShow never runs, and the first swatch's slider is read as the second
# swatch's opacity.
mutate("Options/Window/WidgetsChoice.lua",
       "\tif picker.IsShown and picker:IsShown() and picker.Hide then picker:Hide() end\n",
       "",
       "hunt-ui-fix: a second swatch opened over the first's picker",
       expect=("hunt-ui-fix: colour picker: a swatch clicked while another's picker is up "
               "gets its own opacity (vanilla)"),
       script=S)

# ------------------------------------------------ the sound
# The sound tied to the name changing alone: a passer-by already on the prompt
# who then buffs you flashes the panel and stays silent.
mutate("Prompt/Refresh.lua",
       "\tif (isNew or (becameOwed and db.sound.owedOnly)) and db.sound.enabled\n",
       "\tif isNew and db.sound.enabled\n",
       "hunt-ui-fix: the sound missing the passer-by turning owed",
       expect="hunt-ui-fix: sound: a passer-by on the prompt who then buffs you sounds once",
       script=S)

# The turn to owed sounding with the filter off as well: "Off, every new
# person makes a sound" becomes a second sound for the same person.
mutate("Prompt/Refresh.lua",
       "\tif (isNew or (becameOwed and db.sound.owedOnly)) and db.sound.enabled\n",
       "\tif (isNew or becameOwed) and db.sound.enabled\n",
       "hunt-ui-fix: a second sound for somebody already announced",
       expect=("hunt-ui-fix: sound: with Only for people who buff me off, the passer-by "
               "turning owed is not a second new person"),
       script=S)
