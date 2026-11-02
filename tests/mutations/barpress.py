# Mutations for the review of the Manners macro on an action bar (Clicks.lua's
# body block, Prompt/Press.lua's OnBarClick and BarWaiting, the launch
# self-test): whose body it is, whose press it is, a body a session before
# left, the cooldown, a press with nothing to cast. Each undoes one fix and is
# caught by the scenario in tests/scenarios/barpress.lua (or barclick.lua) it
# names.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"
C = "Clicks.lua"
P = "Prompt/Press.lua"

SHAPES = "barpress: only a shape Manners writes is Manners'"
BYHAND = "barpress: a /use added by hand under the cast is the player's"
OTHER = "barpress: the player's own macro with the bar line is not filed"
LOGIN = "barpress: a login in a fight finds the last session's body"
LEFT = "barpress: a loading screen in a fight leaves the cast, and the next login says so"
SAME = "barpress: lines typed by hand that the prompt would write are the prompt's"
QUIET = "barpress: a press early in the cooldown after a press that landed is quiet"
WHY = "barpress: a press with nothing to cast says why: "
AGAIN = "barpress: press again after the prompt has moved on"
GUARD = "barpress: an error in the look at UPDATE_MACROS is caught"
LAUNCH = "barpress: the launch check writes its macro by name"
BUTTON = "barpress: the self-test's button line names the key binding only"
OWN = "barclick: the spell's own cooldown holds the macro back at its end too"

# ------------------------------------------------------------ whose body it is

# Any line under the bar line taken for Manners': a trinket's /use 13 added by
# hand is written over.
mutate(C,
       "\t\tif not Shaped(rest) then return \"foreign\", prefix, rest end\n",
       "",
       "barpress: any line under the bar line taken for Manners'",
       expect=SHAPES, script=S)

# The same, met in a session: the /use added under the cast is written over.
mutate(C,
       "\t\tif not Shaped(rest) then return \"foreign\", prefix, rest end\n",
       "\t\tif not Shaped(rest) and not rest[#rest]:find(\"^/use %d\") then return \"foreign\", prefix, rest end\n",
       "barpress: a /use of a slot added by hand taken for Manners'",
       expect=BYHAND, script=S)

# A hand-back with no /target before it taken for Manners'.
mutate(C,
       "\t\tif targeted then\n\t\t\tcommand, arg = Command(rest[i])\n",
       "\t\tdo\n\t\t\tcommand, arg = Command(rest[i])\n",
       "barpress: a hand-back with nothing targeted taken for Manners'",
       expect=SHAPES, script=S)

# Any slot used after a scroll taken for the weapon's.
mutate(C,
       "\t\t\tif command == \"use\" and (arg == \"16\" or arg == \"17\") then i = i + 1 end\n",
       "\t\t\tif command == \"use\" and arg ~= \"\" then i = i + 1 end\n",
       "barpress: a /use 13 after a scroll taken for Manners'",
       expect=SHAPES, script=S)

# A conditional in the cast taken for Manners'.
mutate(C,
       "\t\tif command == \"cast\" then\n\t\t\tif arg == \"\" or arg:find(\"[\", 1, true) then return false end\n",
       "\t\tif command == \"cast\" then\n",
       "barpress: a /cast with a conditional taken for Manners'",
       expect=SHAPES, script=S)

# A body of the player's that targets nobody, never said.
mutate(C,
       "\t\tlocal key = who or text\n",
       "\t\tif not who then return end\n\t\tlocal key = who\n",
       "barpress: a body of the player's that targets nobody is not said",
       expect=SHAPES, script=S)

# ------------------------------------------------------------ whose press it is

# Another macro with the bar line filed as a press of the Manners macro.
mutate(P,
       "\tif type(running) == \"number\" and running ~= ns.BarMacroIndex() then\n",
       "\tif false then\n",
       "barpress: a press of another macro with the bar line is filed",
       expect=OTHER, script=S)

# ------------------------------------------------------------ a body a session left

# A login in a fight does not look at the macro: its press reads as edited.
mutate(C,
       "\t\t\tif state == nil then Look() end\n\t\t\treturn\n",
       "\t\t\treturn\n",
       "barpress: a login in a fight does not look at the macro",
       expect=LOGIN, script=S)

# The last session's lines run and nothing says so.
mutate(C,
       "\t\tif InCombatLockdown() and not body.staleSaid then\n",
       "\t\tif false then\n",
       "barpress: a press of the last session's lines is not said",
       expect=LOGIN, script=S)

# ...said at every press.
mutate(C,
       "\t\t\tbody.staleSaid = true\n",
       "",
       "barpress: a press of the last session's lines is said every time",
       expect=LOGIN, script=S)

# The press not told apart from one of a macro changed by hand.
mutate(P,
       "\tif ns.StaleBarPress() then\n",
       "\tif false then\n",
       "barpress: a press of the last session's lines reads as edited",
       expect=LEFT, script=S)

# Lines found that are what the prompt casts now (typed by hand, or left by a
# session before): still taken for a session before's, their press not filed.
mutate(C,
       "\t\t\t-- it is filed, not taken for a session before's (ns.StaleBarPress).\n\t\t\tbody.mine, body.stale = want, false\n",
       "\t\t\t-- it is filed, not taken for a session before's (ns.StaleBarPress).\n",
       "barpress: lines found that the prompt casts kept as a session before's",
       expect=SAME, script=S)

# ------------------------------------------------------------ the cooldown

# A press the cooldown held back not stamped: the game's refusal of its /cast
# is reported about the press before it.
mutate(P,
       "\t\tns.barHeldAt = now\n",
       "",
       "barpress: a held bar press is not stamped",
       expect=QUIET, script=S)

# ...said as a cast that could not go.
mutate(C,
       "\t\tand ns.barHeldAt ~= GetTime() then\n",
       "\t\tthen\n",
       "barpress: a held bar press's refusal says could not cast",
       expect=QUIET, script=S)

# ...taken as an error after our cast, and as the next refusal's reason.
mutate(C,
       "\tif ns.barHeldAt == GetTime() then return end\n",
       "",
       "barpress: a held bar press's refusal is taken for the last press's",
       expect=QUIET, script=S)

# The hold for the spell's own cooldown pressed: nothing said.
mutate(P,
       "\tlocal ready, left = ns.CastReady(entry and entry.buff and PressSpell(entry) or nil)\n",
       "\tlocal ready, left = ns.CastReady()\n",
       "barpress: a press in the hold for the spell's own cooldown says nothing",
       expect=OWN, script=S)

# ------------------------------------------------------------ nothing to cast

mutate(P,
       "\t\tns.addon:Print(L[\"not buffing while unlocked\"])\n",
       "",
       "barpress: a bar press while unlocked says nothing",
       expect=WHY + "unlocked", script=S)

mutate(P,
       "\tif S.testMode then\n\t\tns.addon:Print(",
       "\tif false then\n\t\tns.addon:Print(",
       "barpress: a bar press under a preview says nothing",
       expect=WHY + "previewing", script=S)

mutate(P,
       "\tif ns.MacroWindowOpen and ns.MacroWindowOpen() then\n",
       "\tif false then\n",
       "barpress: a bar press with the macro window open says nothing",
       expect=WHY + "the macro window open", script=S)

mutate(P,
       "\tif ns.tryMacro then\n\t\tns.addon:Print(",
       "\tif false then\n\t\tns.addon:Print(",
       "barpress: a bar press under /manners try says nothing",
       expect=WHY + "running /manners try", script=S)

# "Press again" and the macro left with its first line alone until a scan.
mutate(P,
       "\t\tns.Guard(\"bar macro\", Prompt.Refresh, Prompt)\n\t\tB.waitAt = nil\n",
       "\t\tB.waitAt = nil\n",
       "barpress: press again leaves the bar macro empty",
       expect=AGAIN, script=S)

# ------------------------------------------------------------ guards and self-tests

mutate(C,
       "\t\tif ns.SyncMacroBody then ns.Guard(\"bar macro\", LookAgain) end\n",
       "\t\tif ns.SyncMacroBody then LookAgain() end\n",
       "barpress: the look at UPDATE_MACROS is not guarded",
       expect=GUARD, script=S)

mutate("SelftestLaunch.lua",
       "pcall(_G.EditMacro, macro.index, macro.name, nil, want)",
       "pcall(_G.EditMacro, macro.index, nil, nil, want)",
       "barpress: the launch check writes its macro with no name",
       expect=LAUNCH, script=S)

mutate("Selftest.lua",
       "\" -- the key binding names MannersPrompt\")",
       "\" -- the key binding and the /click macro name MannersPrompt\")",
       "barpress: the self-test's button line names a /click macro",
       expect=BUTTON, script=S)
