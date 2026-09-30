# Mutations for round 13's second batch of fixes: the prompt's hold, a fight's
# withheld auras, a shout's other listeners, the press on yourself, the sound
# for a class nobody owes, the skip in a fight, "moved on" to a group cast, the
# quiet useless favour and In character's targeted group member. Each is
# caught by the scenario in tests/scenarios/hunt13-fix2.lua that names it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# ------------------------------------------------ hold

# The hold judged by the copy painted again: somebody still in the queue keeps
# the priority they had then, over a new target.
mutate("Prompt/Hold.lua",
       "\tif top.priority < held.priority then return top end\n",
       "\tif top.priority < S.heldEntry.priority then return top end\n",
       "fix2: hold judged by the painted copy",
       expect="the prompt stayed on the old target after you targeted somebody else", script=S)

# ...and the copy painted kept: over a favour once the target is cleared.
mutate("Prompt/Hold.lua",
       "\tif top.priority < held.priority then return top end\n\treturn held\n",
       "\tif top.priority < S.heldEntry.priority then return top end\n\treturn S.heldEntry\n",
       "fix2: hold keeps the painted copy",
       expect="the favour did not get the panel once the target was cleared", script=S)

# ...over the group once a favour lapses.
mutate("Prompt/Hold.lua",
       "\t\tif candidate.name == S.heldEntry.name then held = candidate break end\n",
       "\t\tif false then held = candidate break end\n",
       "fix2: hold never finds them in the queue",
       expect="a lapsed favour kept the panel ahead of the group", script=S)

# ------------------------------------------------ fight

# A withheld spell filed as "no spell" again: every buff on you is new after
# the fight.
mutate("Favours.lua",
       "\t\t\t\t\tlocal key = spellId or knownAuras[instanceId] or true\n",
       "\t\t\t\t\tlocal key = spellId or true\n",
       "fix2: withheld spell loses the filed identity",
       expect="a buff already on you became a new favour when the fight ended", script=S)

# A readable aura with its number withheld skipped without doubt: two scans
# prune the baseline empty.
mutate("Favours.lua",
       "\t\t\t\tif instanceId == nil then refused = true end\n",
       "",
       "fix2: withheld aura number not doubted",
       expect="a buff already on you became a new favour when the fight ended", script=S)

# The over-fix: an aura first filed with its spell withheld taken as the same
# aura once the spell reads, so a favour that landed in the fight is lost.
mutate("Favours.lua",
       "\t\tif known == nil or known ~= key then return true end\n",
       "\t\tif known == nil or (known ~= key and known ~= true) then return true end\n",
       "fix2: withheld-then-read aura never new",
       expect="a buff that landed in the fight was never announced after it", script=S)

# ------------------------------------------------ shout

# Only the one it was aimed at is settled.
mutate("Clicks.lua",
       "\tif pending.selfCast and pending.shoutMembers then members = SettleShout(pending, spellId) end\n",
       "",
       "fix2: shout settles only its anchor",
       expect="a shout that reached two owed party members repaid only the one it was aimed at",
       script=S)

# Settled, but not kept for a late refusal to undo.
mutate("Clicks.lua",
       "then members = SettleShout(pending, spellId) end\n",
       "then SettleShout(pending, spellId) end\n",
       "fix2: shout members not kept for a refusal",
       expect="a late refusal of the shout left the other favour it returned repaid", script=S)

# Somebody nothing measured counted as in reach.
mutate("Prompt/Press.lua",
       "\t\t\tif entry.name ~= S.current.name and entry.ranged == true and entry.reason ~= \"self\"\n",
       "\t\t\tif entry.name ~= S.current.name and entry.ranged ~= false and entry.reason ~= \"self\"\n",
       "fix2: unmeasured member counted in reach",
       expect="a shout counted as repaying a party member nothing measured in its reach", script=S)

# ------------------------------------------------ own

# The press on yourself follows the switch for other people again.
mutate("Prompt/Macro.lua",
       "\tlocal lines = STRATEGIES.target(entry, spell)\n"
       "\tlocal restore = not StillTargeted(entry) or Prompt.armedForFight == true\n",
       "\tlocal lines, restore = STRATEGIES.target(entry, spell)\n",
       "fix2: own press follows restoreTarget",
       expect="the press on yourself drops your target", script=S)

# Your own target is not asked about: /targetlasttarget switches away from you.
mutate("Prompt/Macro.lua",
       "\treturn (entry.unit == \"target\" or entry.reason == \"self\") and entry.name ~= nil\n",
       "\treturn entry.unit == \"target\" and entry.name ~= nil\n",
       "fix2: self-targeted not seen",
       expect="the press on yourself switches away from you when you are your own target", script=S)

# ------------------------------------------------ sound

# "Only for people who buff me" applied to a class nobody can owe.
mutate("Prompt/Refresh.lua",
       "or not (ns.caps and ns.caps.hasClassBuffs == true and db.sources.owed ~= false))",
       "or not (ns.caps and true))",
       "fix2: owed-only sound silences a hunter",
       expect="the hunter's own prompt came up and the sound played", script=S)

# ...and ignored for a class that can be owed.
mutate("Prompt/Refresh.lua",
       "or not (ns.caps and ns.caps.hasClassBuffs == true and db.sources.owed ~= false))",
       "or not (ns.caps and false))",
       "fix2: owed-only sound ignored for a mage",
       expect="a group member made a sound with Only for people who buff me on", script=S)

mutate("Options.lua",
       "\t\t\t\torder = 35,\n\t\t\t\thidden = function() return not HasClassBuffs() end,\n",
       "\t\t\t\torder = 35,\n",
       "fix2: owed-only sound shown to a hunter",
       expect="soundOwedOnly is shown to a hunter", script=S)

mutate("Options.lua",
       "\t\t\t\torder = 31,\n\t\t\t\thidden = function() return not HasClassBuffs() end,\n",
       "\t\t\t\torder = 31,\n",
       "fix2: favour flash shown to a hunter",
       expect="flashStyle is shown to a hunter", script=S)

# ------------------------------------------------ skip

mutate("Prompt/Press.lua",
       "\t\tlocal frozenOnThem = not own and InCombatLockdown() and S.current and S.current.name == victim\n",
       "\t\tlocal frozenOnThem = false\n",
       "fix2: skip in a fight claims the skip",
       expect="a skip in a fight claimed the skip without saying a press still casts at them", script=S)

# ------------------------------------------------ moved

mutate("Prompt/Paint.lua",
       "\tif top.groupCast then\n\t\tns.addon:Print(L[\"the prompt has moved on to",
       "\tif false then\n\t\tns.addon:Print(L[\"the prompt has moved on to",
       "fix2: moved on names one member",
       expect="moving on to a group cast named one member", script=S)

# ------------------------------------------------ quiet

mutate("Favours.lua",
       "\t\t\tTellLedger(\"Received\", seen, true)\n\t\t\tif speak then\n",
       "\t\t\tTellLedger(\"Received\", seen, true)\n\t\t\tif db.verbose then\n",
       "fix2: useless favour said in a raid",
       expect="a favour nothing can return was announced where every other is quiet", script=S)

# ------------------------------------------------ rp

mutate("Phrases.lua",
       "\t\tlocal kind = KIND[entry.reason] or (entry.inGroup and \"group\") or \"offer\"\n",
       "\t\tlocal kind = KIND[entry.reason] or \"offer\"\n",
       "fix2: targeted group member gets offers",
       expect="a party member you target was told", script=S)
