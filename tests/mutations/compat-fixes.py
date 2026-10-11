# What the compat hunt fixed (tests/scenarios/compat-fixes.lua): the prompt's
# macro run by mouse clicks it was meant to ignore. Each fault put back has to
# be caught by the check it names.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# ------------------------------------------------ the other buttons
# Buttons 2 to 5 silenced by the plain "type<N>" alone, as before: the
# unmodified right button does nothing, and shift-right-click (the never-offer
# gesture), ctrl-right, alt-right, any modified middle or side click and every
# button from 6 to 31 fall to the bare type and run the macro.
mutate("Prompt/Macro.lua",
       "\tfor index = 2, 31 do\n"
       "\t\tif index <= 5 then R.button:SetAttribute(\"type\" .. index, \"none\") end\n"
       "\t\tR.button:SetAttribute(\"*type\" .. index, \"none\")\n"
       "\tend\n",
       "\tfor index = 2, 5 do\n"
       "\t\tR.button:SetAttribute(\"type\" .. index, \"none\")\n"
       "\tend\n",
       "compat-fix: modified and extra mouse buttons run the macro",
       expect="compat-fix: only the left mouse button runs the prompt's macro",
       script=S)

# The wildcard forms stopping at Button5: every modifier is covered for the
# right, middle and two side buttons, and Button6 to Button31 still cast.
mutate("Prompt/Macro.lua",
       "\tfor index = 2, 31 do\n",
       "\tfor index = 2, 5 do\n",
       "compat-fix: mouse buttons 6 to 31 run the macro",
       expect="compat-fix: only the left mouse button runs the prompt's macro",
       script=S)

# The wildcard silencing "type1" too: the left button with shift, ctrl or alt
# held, and a key binding with a modifier in it, would no longer cast.
mutate("Prompt/Macro.lua",
       "\tfor index = 2, 31 do\n",
       "\tR.button:SetAttribute(\"*type1\", \"none\")\n"
       "\tfor index = 2, 31 do\n",
       "compat-fix: the left button silenced with a modifier held",
       expect="compat-fix: only the left mouse button runs the prompt's macro",
       script=S)

# /manners try arming the button without silencing the other buttons.
mutate("Prompt/Macro.lua",
       "\t\tSilenceOtherButtons()\n"
       "\t\tns.lastMacro = \"[try] \" .. text\n",
       "\t\tns.lastMacro = \"[try] \" .. text\n",
       "compat-fix: a /manners try macro armed for every button",
       expect="compat-fix: a /manners try macro is run by the left button only",
       script=S)
