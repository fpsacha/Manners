# The hand-back when the player had no target (Prompt/Macro.lua, tests/
# scenarios/hunt39-press.lua): each fault put back has to be caught by the
# scenario that names it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"
M = "Prompt/Macro.lua"

# With nothing targeted the macro hands a stale target back instead of
# clearing.
mutate(M,
       "\tif Prompt.armedForFight ~= true and NoTarget() then return \"/cleartarget\" end\n",
       "\tif false then return \"/cleartarget\" end\n",
       "hunt39-press: no target and the macro still hands back the last one",
       expect="hunt39-press: no target when armed, the hand-back clears the target",
       script=S)

# The macro armed at the pull clears the target in a fight, taking whatever
# the player has picked by then.
mutate(M,
       "\tif Prompt.armedForFight ~= true and NoTarget() then return \"/cleartarget\" end\n",
       "\tif NoTarget() then return \"/cleartarget\" end\n",
       "hunt39-press: the macro armed for a fight clears the target",
       expect="hunt39-press: the macro armed for a fight keeps handing back",
       script=S)

# The macro's key blind to whether anything is targeted: a target that comes or
# goes never re-arms it.
mutate(M,
       "tostring(Prompt.armedForFight), tostring(NoTarget()),\n",
       "tostring(Prompt.armedForFight),\n",
       "hunt39-press: the macro key is blind to the target coming and going",
       expect="hunt39-press: the macro follows the target coming and going",
       script=S)

# The room for the spoken line worked out for the longer hand-back always.
mutate(M,
       "\tif restore then used = used + #HandBack() + 1 end\n",
       "\tif restore then used = used + #\"/targetlasttarget\" + 1 end\n",
       "hunt39-press: the room for the line ignores the shorter hand-back",
       expect="hunt39-press: the spoken line gets the room the shorter hand-back leaves",
       script=S)

# A clear with the switch off: the line goes on whatever "Hand my target back"
# says.
mutate(M,
       "\tif restore then lines[#lines + 1] = HandBack() end\n",
       "\tlines[#lines + 1] = HandBack()\n",
       "hunt39-press: the macro hands back with the switch off",
       expect="hunt39-press: with the switch off nothing is handed back or cleared",
       script=S)
