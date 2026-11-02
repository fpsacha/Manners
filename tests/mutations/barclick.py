# Mutations for the Manners macro on an action bar (Clicks.lua's click macro
# section and its body block, Prompt/Press.lua's OnBarClick, Prompt/Macro.lua's
# barText, the wiring in Core.lua, Favours.lua and Prompt/Refresh.lua): the
# macro carries the cast under /click MannersBar, since the game will not run
# a macro from inside another one. Each undoes one rule and is caught by the
# scenario in tests/scenarios/barclick.lua (or selftest-launch.lua) it names;
# the last three by validate.py.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"
V = "validate.py"
C = "Clicks.lua"
P = "Prompt/Press.lua"

ONCE = "barclick: the old body casts nothing from a bar, the new one casts once"
FILED = "barclick: a press of the slot is filed before its cast and settled by it"
SILENT = "barclick: the bar macro never speaks, whatever the press meets"
FOLLOWS = "barclick: the macro follows the prompt"
GCD = "barclick: during the global cooldown the macro holds back at the end"
OWN = "barclick: the spell's own cooldown holds the macro back at its end too"
FIGHT = "barclick: in a fight the macro keeps what it held at the pull"
PULLFLASH = "barclick: a flash at the pull does not leave the fight's macro empty"
FIGHTEMPTY = "barclick: a press of the empty bar macro in a fight says why"
RUNNING = "barclick: nothing is written while the bar macro runs"
EDITED = "barclick: a Manners macro edited by hand"
LOGIN = "barclick: an old Manners macro is rewritten at login, nothing else is"
FLASH = "barclick: a flash about somebody else holds the macro back"
LOADING = "barclick: a loading screen puts the macro back to its first line"
TARGET = "barclick: a change of target hands back the right way at once"
WINDOW = "barclick: nothing is written while the macro window is open"
REPORT = "barclick: the self-test says whose the macro is"

# ------------------------------------------------------------ the body

# The old body back as the first line: a press runs the prompt's macro and the
# lines under it both, where the client allows the first.
mutate(C,
       "local BAR_LINE = \"/click MannersBar\"\n",
       "local BAR_LINE = \"/click MannersPrompt LeftButton 1\"\n",
       "barclick: the first line clicks the prompt again",
       expect=ONCE, script=S)

# 1.10.4's body no longer recognised: left on the bar, casting nothing.
mutate(C,
       "\t[\"/click MannersPrompt LeftButton 1\"] = true, -- 1.0 to 1.10.4: a macro the client will not run from a macro\n",
       "",
       "barclick: the 1.10.4 body is not rewritten",
       expect=LOGIN, script=S)

# Only the bare bar line is Manners': a body a session left keeps its cast.
mutate(C,
       "\t\tif rest[1] ~= BAR_LINE then return \"foreign\", prefix, rest end\n",
       "\t\tif rest[1] ~= BAR_LINE or #rest > 1 then return \"foreign\", prefix, rest end\n",
       "barclick: a body a session left is not reset",
       expect=LOGIN, script=S)

# Everything taken for Manners': a macro somebody wrote is rewritten.
mutate(C,
       "\t\tlocal meta, rest = {}, {}\n",
       "\t\tdo return \"ours\", \"\" end\n\t\tlocal meta, rest = {}, {}\n",
       "barclick: every body taken for Manners'",
       expect=LOGIN, script=S)

# "#" lines counted as lines of the player's: a #showtooltip makes it theirs.
mutate(C,
       "\t\t\tif line:sub(1, 1) == \"#\" then\n",
       "\t\t\tif false then\n",
       "barclick: a #showtooltip line makes the macro the player's",
       expect=EDITED, script=S)

# A macro changed by hand still targeting somebody, never said.
mutate(C,
       "\t\t\tif rest[1] == BAR_LINE then Warn(rest) end\n",
       "",
       "barclick: a macro changed by hand is not said",
       expect=EDITED, script=S)

# ...said at every look.
mutate(C,
       "\t\tif not who or body.warned == who then return end\n",
       "\t\tif not who then return end\n",
       "barclick: a macro changed by hand is said at every look",
       expect=EDITED, script=S)

# An edit announced by UPDATE_MACROS not looked at.
mutate(C,
       "\t\tif ns.ForgetMacroBody then ns.ForgetMacroBody() end\n",
       "",
       "barclick: UPDATE_MACROS does not look at the body again",
       expect=EDITED, script=S)

# An edit nobody announced written over.
mutate(C,
       "\t\tif Trimmed(now) ~= body.written then\n",
       "\t\tif false then\n",
       "barclick: a body changed without a word is written over",
       expect=EDITED, script=S)

# ------------------------------------------------------------ when it is written

# Written in a fight (the client refuses, but it is asked).
mutate(C,
       "\t\tif InCombatLockdown() then return end\n\t\t-- Never into a macro that may be running",
       "\t\t-- Never into a macro that may be running",
       "barclick: the macro written in a fight",
       expect=FIGHT, script=S)

# Written while the bar macro runs.
mutate(C,
       "\t\tif body.pressingAt and body.pressingAt == GetTime() then\n",
       "\t\tif false then\n",
       "barclick: the macro written while it runs",
       expect=RUNNING, script=S)

# ...because the press never says it is running.
mutate(P,
       "\tns.HoldMacroWrites()\n\t-- The lines' own /target",
       "\t-- The lines' own /target",
       "barclick: a bar press does not hold the writes",
       expect=RUNNING, script=S)

# Written with the macro window open.
mutate(C,
       "\t\tif WindowOpen() then return end\n",
       "",
       "barclick: the macro written with the macro window open",
       expect=WINDOW, script=S)

# The window opened and the macro left carrying the cast it cannot follow.
mutate(C,
       "\t\tframe:HookScript(\"OnShow\", function() ns.Guard(\"macro window\", OnWindowShown) end)\n",
       "",
       "barclick: the macro window's opening not heard",
       expect=WINDOW, script=S)

# A flash about somebody else does not hold the macro back.
mutate(C,
       "\t\t\tif named and named ~= entry.name then return body.waitBody end\n",
       "",
       "barclick: the macro carries the cast under a flash about somebody else",
       expect=FLASH, script=S)

# The pull's macro held back by a flash, for the whole fight.
mutate(C,
       "\t\tif P.armedForFight ~= true then\n\t\t\t-- A press follows the words",
       "\t\tif true then\n\t\t\t-- A press follows the words",
       "barclick: a flash at the pull empties the fight's macro",
       expect=PULLFLASH, script=S)

# The end of a cooldown never held back.
mutate(C,
       "\t\tlocal hold = left <= window\n",
       "\t\tlocal hold = false\n",
       "barclick: the end of a cooldown is not held back",
       expect=GCD, script=S)

# Held for the global cooldown alone, not the spell's own.
mutate(C,
       "\t\tlocal ready, left = ns.CastReady(ns.PressSpell and ns.PressSpell(entry) or nil)\n",
       "\t\tlocal ready, left = ns.CastReady()\n",
       "barclick: the spell's own cooldown is not held back",
       expect=OWN, script=S)

# A loading screen does not park it.
mutate(C,
       "\t\tbody.parked = true\n",
       "",
       "barclick: a loading screen leaves the cast in the macro",
       expect=LOADING, script=S)

# ...and the world back does not let it go.
mutate("Favours.lua",
       "\tif ns.UnparkMacroBody then ns.Guard(\"bar macro\", ns.UnparkMacroBody) end\n",
       "",
       "barclick: the macro stays parked after the loading screen",
       expect=LOADING, script=S)

# A change of target re-arms nothing before the next scan.
mutate("Core.lua",
       "\t\tns.Guard(\"hand-back\", P.ApplyTarget, P, P.state.current, P.state.phraseArmed ~= true)\n",
       "",
       "barclick: a change of target waits for the scan",
       expect=TARGET, script=S)

# An arming of the button outside a repaint does not reach the macro.
mutate("Prompt/Macro.lua",
       "\tns.SyncMacroBody(true)\n",
       "",
       "barclick: arming the button does not write the macro",
       expect=TARGET, script=S)

# A repaint that brings the panel up (the button is armed before it is shown)
# does not reach the macro.
mutate("Prompt/Refresh.lua",
       "\t-- click macro). Nothing is asked of the client while nothing changed.\n\tns.SyncMacroBody()\n",
       "\t-- click macro). Nothing is asked of the client while nothing changed.\n",
       "barclick: a repaint does not write the macro",
       expect=FOLLOWS, script=S)

# ------------------------------------------------------------ what it carries

# The spoken line rides the bar macro, unjudged at the press.
mutate("Prompt/Macro.lua",
       "\t\tlocal barText = table.concat(quiet, \"\\n\")\n",
       "\t\tlocal barText = macro\n",
       "barclick: the bar macro says the line",
       expect=SILENT, script=S)

# ------------------------------------------------------------ the press

# Filed against the prompt's state: a press from the bar reads as the prompt's.
mutate(P,
       "\tlocal S = self.mannersRow or self.mannersBar or S\n",
       "\tlocal S = self.mannersRow or S\n",
       "barclick: a bar press filed against the prompt's state",
       expect=FILED, script=S)

# A macro changed without a word filed as Manners'.
mutate(P,
       "\tif not B.body or ns.BarBodyNow() ~= B.body then\n",
       "\tif not B.body then\n",
       "barclick: a bar press of a changed macro is filed",
       expect=EDITED, script=S)

# A press refused by the cooldown filed anyway.
mutate(P,
       "\t\tif debug then ns.addon:Print(\"|cffffd100CLICK|r \" .. L[\"held back -- the cooldown was still running\"]) end\n"
       "\t\treturn\n\tend\n\t-- Whether the person",
       "\t\tif debug then ns.addon:Print(\"|cffffd100CLICK|r \" .. L[\"held back -- the cooldown was still running\"]) end\n"
       "\tend\n\t-- Whether the person",
       "barclick: a bar press in the cooldown is filed",
       expect=FIGHT, script=S)

# A press the client queues in a fight not filed.
mutate(P,
       "\tif InCombatLockdown() and not ready and left <= ns.SpellQueueWindow() then ready = true end\n",
       "",
       "barclick: a queued bar press in a fight is not filed",
       expect=FIGHT, script=S)

# An empty bar macro in a fight says nothing.
mutate(P,
       "\t\t\tns.addon:Print(\"|cffff8080\" .. L[\"cannot touch macros in combat.\"] .. \"|r\")\n",
       "",
       "barclick: an empty bar macro in a fight is silent",
       expect=FIGHTEMPTY, script=S)

# A press of the empty bar macro with nobody to buff says nothing.
mutate(P,
       "\tif ExplainEmpty(now) then return end\n\tif not PromptIsLive() then return end\n",
       "\tif not PromptIsLive() then return end\n",
       "barclick: an empty bar macro says nothing of why",
       expect=FOLLOWS, script=S)

# ------------------------------------------------------------ the self-tests

mutate("Selftest.lua",
       "\t\tmacro and \"made\" or \"none\", ns.BarMacroState and ns.BarMacroState() or \"?\")\n",
       "\t\tmacro and \"made\" or \"none\", \"?\")\n",
       "barclick: the self-test does not say whose the macro is",
       expect=REPORT, script=S)

mutate("SelftestLaunch.lua",
       "\telseif got == want then\n",
       "\telseif true then\n",
       "barclick: the launch check passes a body that lost a line",
       expect="selftest-launch: a client that loses a line of the macro written is a CHECK", script=S)

mutate("SelftestLaunch.lua",
       "\tif not macro.temp then\n\t\tlocal okB, text = Ask(readBody, macro.index)\n",
       "\tif false then\n\t\tlocal okB, text = Ask(readBody, macro.index)\n",
       "barclick: the launch check rewrites the player's own macro",
       expect="selftest-launch: the player's own macro is read, not rewritten, for its body", script=S)

# ------------------------------------------------------------ the structure (validate.py)

# The button the first line clicks made secure: a macro may not click it.
mutate("Prompt/Panel.lua",
       "\tR.bar = CreateFrame(\"Button\", \"MannersBar\", UIParent)\n",
       "\tR.bar = CreateFrame(\"Button\", \"MannersBar\", UIParent, \"SecureActionButtonTemplate\")\n",
       "barclick: MannersBar made a secure button",
       expect="MannersBar is not", script=V)

# A /click of the prompt put back where a macro could carry it.
mutate("Commands.lua",
       "local ns = select(2, ...)\n",
       "local ns = select(2, ...)\nlocal OLD_MACRO = \"/click MannersPrompt LeftButton 1\"\n",
       "barclick: a /click of the prompt in the code again",
       expect="must not /click the prompt", script=V)

# The README promising the old macro.
mutate("README.md",
       "   `/click MannersBar`, which tells Manners about the press, and under it\n",
       "   `/click MannersPrompt LeftButton 1`, which tells Manners about the press, and under it\n",
       "barclick: the README gives the old macro",
       expect="README.md still gives the macro", script=V)
