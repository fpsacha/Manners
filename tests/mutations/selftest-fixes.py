# Mutations for round 30's fixes around /manners selftest: the window built
# outside the fallback's guard (Selftest.lua, Options/Register.lua), the
# proximity line graded by its English words (Selftest.lua, Range.lua), a
# Forever mage with no scrolls reading "said nothing" (Selftest.lua), and the
# nameplate line and note in /party or /raid (Speech.lua, Options/Say.lua).
# Each undoes a fix and is caught by the scenario in
# tests/scenarios/selftest-fixes.lua it names.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# ------------------------------------------------------------ window.build
# The bare pcall again: a build that throws keeps its half-built frame, which
# the next opening shows, and nothing falls back.
mutate("Selftest.lua",
       "\tif ns.BuildOptionsWindow() then\n",
       "\tif pcall(UI.Build) and UI.built then\n",
       "selftest-fixes: window.build outside the guard",
       expect="selftest-fix: after the self-test a window that will not build still falls back", script=S)

# Built through the guard, but the failure not taken as the window's: no
# fallback, the half-built frame kept.
mutate("Options/Register.lua",
       "\tif ns.Guard(\"options window\", UI.Build) then return UI.built == true end\n"
       "\tbroken = true\n\tpcall(Discard)\n",
       "\tif ns.Guard(\"options window\", UI.Build) then return UI.built == true end\n",
       "selftest-fixes: a failed build leaves no fallback",
       expect="selftest-fix: after the self-test a window that will not build still falls back", script=S)

# Built again over a window that failed: a second frame takes the global.
mutate("Options/Register.lua",
       "\tif broken then return false end\n\tif ns.Guard(\"options window\", UI.Build)",
       "\tif ns.Guard(\"options window\", UI.Build)",
       "selftest-fixes: a second build over the first",
       expect="selftest-fix: a second self-test builds no second window", script=S)

# ------------------------------------------------------------ range.proximity
# The English words again: every translated client reads PASS with nothing to
# measure by.
mutate("Selftest.lua",
       "\tadd(unmeasured == true and WARN or PASS, Strip(summary))\n",
       "\tadd(Strip(summary):find(\"no signal\", 1, true) and WARN or PASS, Strip(summary))\n",
       "selftest-fixes: proximity graded by its words",
       expect="selftest-fix: range.proximity reads WARN with no distance signal (deDE)", script=S)

# The summary no longer says it measures nothing.
mutate("Range.lua",
       "\t\treturn out, prox.source == nil\n",
       "\t\treturn out\n",
       "selftest-fixes: the summary keeps its state",
       expect="selftest-fix: range.proximity reads WARN with no distance signal (enUS)", script=S)

# ------------------------------------------------------------ beliefs.scrolls
# No line for a mage with none in the bags: WARN "said nothing".
mutate("Selftest.lua",
       "\telseif not held then\n",
       "\telseif false then\n",
       "selftest-fixes: no scrolls said nothing",
       expect="selftest-fix: a Forever mage's scrolls get a line of their own (none in the bags)", script=S)

# "none in the bags" beside a count.
mutate("Selftest.lua",
       "\t\t\t\theld = true\n",
       "",
       "selftest-fixes: none in the bags beside a count",
       expect="selftest-fix: a Forever mage's scrolls get a line of their own (two of one scroll)", script=S)

# ------------------------------------------------------------ the nameplate line
# The chat line in /party: a stranger gets no line whatever the nameplates say.
mutate("Speech.lua",
       "\t\tif not ns.ChannelOpen(entry) then return end\n",
       "",
       "selftest-fixes: nameplate line in /party",
       expect="selftest-fix: the nameplate line is said only where a line could go (PARTY)", script=S)

# What I say's note and its button in /party.
mutate("Options/Say.lua",
       "\t\t\t\torder = 14.5,\n"
       "\t\t\t\thidden = function() return speechOff() or not ns.FriendlyPlatesOff() or not ns.ChannelOpen({}) end,\n",
       "\t\t\t\torder = 14.5,\n"
       "\t\t\t\thidden = function() return speechOff() or not ns.FriendlyPlatesOff() end,\n",
       "selftest-fixes: nameplate note in /party",
       expect="selftest-fix: What I say's nameplate note shows only where a line could go (PARTY)", script=S)

mutate("Options/Say.lua",
       "\t\t\t\torder = 14.6,\n"
       "\t\t\t\thidden = function() return speechOff() or not ns.FriendlyPlatesOff() or not ns.ChannelOpen({}) end,\n",
       "\t\t\t\torder = 14.6,\n"
       "\t\t\t\thidden = function() return speechOff() or not ns.FriendlyPlatesOff() end,\n",
       "selftest-fixes: nameplate button in /party",
       expect="selftest-fix: What I say's nameplate note shows only where a line could go (RAID)", script=S)
