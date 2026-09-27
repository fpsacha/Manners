# Mutations for the Prompt.lua fixes of the fifth bug hunt. Each is caught by
# the scenario in tests/scenarios/hunt5-prompt.lua that names it.

# A press on a held or fused entry trusts that entry's old range reading again,
# so a shout clears the debt of somebody the latest scan put out of earshot.
mutate("Prompt.lua",
       "\t\twithinShout = current.ranged == true and not stale,\n",
       "\t\twithinShout = current.ranged == true,\n",
       "stale range reading trusted on a press",
       expect="prompt5: a shout pressed after she walked out of earshot keeps the debt (held)",
       script="runscenarios.py")

# The empty-queue fuse no longer marks its press as stale.
mutate("Prompt.lua",
       "\t\tLightFuse(now)\n\t\tpressStale = true\n",
       "\t\tLightFuse(now)\n",
       "fused press not marked stale",
       expect="prompt5: a shout pressed after she walked out of earshot keeps the debt (fused)",
       script="runscenarios.py")

# A held entry picked against a queue that no longer holds it is not marked.
mutate("Prompt.lua",
       "\tif top then\n\t\tpressStale = true\n",
       "\tif false then\n\t\tpressStale = true\n",
       "held press not marked stale",
       expect="prompt5: a shout pressed after she walked out of earshot keeps the debt (held)",
       script="runscenarios.py")

# The hand-back decided from the token the scan recorded, not from who is
# targeted now.
mutate("Prompt.lua",
       "\treturn entry.unit == \"target\" and entry.name ~= nil and ns.UnitFullName ~= nil\n"
       "\t\tand ns.UnitFullName(\"target\") == entry.name\n",
       "\treturn entry.unit == \"target\"\n",
       "hand-back decided from the recorded token",
       expect="prompt5: a press after your target changed hands it back (held)",
       script="runscenarios.py")

# The macro's key no longer notices the target changing, so the fuse's press
# runs the macro armed while she was still the target.
mutate("Prompt.lua",
       "\t\ttostring(StillTargeted(entry)) }, \"\\1\")\n",
       "\t\t\"\" }, \"\\1\")\n",
       "macro key blind to a change of target",
       expect="prompt5: a press after your target changed hands it back (fused)",
       script="runscenarios.py")

# The fuse's press is no longer re-keyed before it goes out.
mutate("Prompt.lua",
       "\t\tPrompt:ApplyTarget(current)\n\t\tpressKey = appliedKey\n",
       "\t\tpressKey = appliedKey\n",
       "fused press not re-keyed",
       expect="prompt5: a press after your target changed hands it back (fused)",
       script="runscenarios.py")

# The pull's own pass holds the dropped person over whoever is in the queue.
mutate("Prompt.lua",
       "\tif ArmingForFight() then return top end\n",
       "",
       "the hold decides the fight's macro",
       expect="prompt5: a pull inside the hold arms whoever the queue holds",
       script="runscenarios.py")

# The pull's own pass lets the fuse keep the dropped person's macro.
mutate("Prompt.lua",
       "\t\tif button:IsShown() and current and not retired and not ArmingForFight() then\n",
       "\t\tif button:IsShown() and current and not retired then\n",
       "the fuse decides the fight's macro",
       expect="prompt5: a pull inside the fuse does not freeze the dropped person's macro",
       script="runscenarios.py")

# A combat disarm forgets who the frozen macro names.
mutate("Prompt.lua",
       "\t\t\tfrozenEntry = frozenEntry or current\n",
       "",
       "combat disarm forgets the frozen macro's person",
       expect="prompt5: /manners off then on in a fight keeps the press filed",
       script="runscenarios.py")

# A repaint in the fight never puts the frozen macro's person back.
mutate("Prompt.lua",
       "\t\tif not current and frozenEntry and button:GetAttribute(\"macrotext1\") then\n"
       "\t\t\tcurrent = frozenEntry\n",
       "\t\tif false then\n"
       "\t\t\tcurrent = frozenEntry\n",
       "frozen macro's person not put back in the fight",
       expect="prompt5: /manners unlock then lock in a fight keeps the press filed",
       script="runscenarios.py")

# A font the client cannot load is used as it is, with no fallback.
mutate("Prompt.lua",
       "\t\tfs:SetFont(STANDARD_TEXT_FONT, size, flags)\n",
       "",
       "no fallback for a font that fails to load",
       expect="prompt5: a font the client cannot load falls back rather than hiding the prompt",
       script="runscenarios.py")

# The colour-blind palette loses its colour for askers.
mutate("Prompt.lua",
       "\tasked = { 0.72, 0.20, 0.34 },\n",
       "",
       "colour-blind palette without an asked colour",
       expect="prompt5: the colour-blind palette has its own colour for askers",
       script="runscenarios.py")

# The press no longer says why the person was offered.
mutate("Prompt.lua",
       "\t\treason = current.reason,\n",
       "",
       "press filed without its reason",
       expect="prompt5: a press carries the reason it was offered (asked)",
       script="runscenarios.py")

# The rotation pointers are never emptied.
mutate("Prompt.lua",
       "\t\t\t\tif lastGaveCount >= LAST_GAVE_CAP then\n",
       "\t\t\t\tif false then\n",
       "rotation pointers unbounded",
       expect="prompt5: the rotation pointers stay bounded",
       script="runscenarios.py")
