# Mutations for the look and the effects: tests/scenarios/look.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each one puts back a mistake
# the new effects could plausibly make, and names the line in look.lua that has
# to be the one to object.

# The halo drawn in over the icon it frames -- the wash-out it replaced -- by
# a gap with its sign turned round.
mutate("Prompt.lua",
       "\t\tPlaceHalo(glowHalo, glowFrame, sx, sy, outer, roundSize)\n",
       "\t\tPlaceHalo(glowHalo, glowFrame, sx, sy, -sy, roundSize)\n",
       "glow strip laid over the icon",
       expect="lies over the spell icon",
       script="runscenarios.py")

# The halo let out past the panel's edge, where it lit the framed border.
mutate("Prompt.lua",
       "\t\tlocal sy = math.max(2, math.min(8, math.floor((p.height - p.iconSize) / 2) - outer))\n",
       "\t\tlocal sy = math.max(2, math.min(8, math.floor((p.height - p.iconSize) / 2) - outer + 2))\n",
       "glow spills past the panel",
       expect="past the panel's edge",
       script="runscenarios.py")

# The arrival keyed on a new name again, so a passer-by who buffs you is missed.
mutate("Prompt.lua",
       '\tlocal becameOwed = top.reason == "owed" and (isNew or lastTopReason ~= "owed")\n',
       '\tlocal becameOwed = top.reason == "owed" and isNew\n',
       "arrival keyed on a new name only",
       expect="flash once did not flash",
       script="runscenarios.py")

# A cast nobody confirmed celebrated as if it had landed.
mutate("Prompt.lua",
       '\tif kind == "cast" then\n\t\t-- Coloured here rather than by PaintAccent',
       '\tif kind == "cast" or kind == "sent" then\n\t\t-- Coloured here rather than by PaintAccent',
       "unconfirmed cast gets the flourish",
       expect="cast nobody confirmed got a flourish",
       script="runscenarios.py")

# Calm ignored.
mutate("Prompt.lua",
       '\treturn p ~= nil and p.effects ~= "calm"\n',
       "\treturn p ~= nil\n",
       "Calm effects ignored",
       expect="with effects on calm",
       script="runscenarios.py")

# The fade out left running under the next person.
mutate("Prompt.lua",
       "\tif not self.outroWanted then self:ComeBack(fadedTo) end\n",
       "",
       "fade out never cancelled",
       expect="painted onto a panel left at alpha",
       script="runscenarios.py")

# Stay quiet in combat ignored by the new motion.
mutate("Prompt.lua",
       "\tif InCombatLockdown() and p.hideInCombat then return end\n",
       "",
       "flourish ignores Stay quiet in combat",
       expect="stay quiet in combat is on",
       script="runscenarios.py")

# A flourish that puts the panel up, which is a protected call in a fight.
mutate("Prompt.lua",
       "\tif not button:IsShown() then return end\n\tself:StopFlourishes()\n",
       "\tif not button:IsShown() then return end\n\tbutton:Show()\n\tself:StopFlourishes()\n",
       "flourish touches the secure button",
       expect="on the secure button in a fight",
       script="runscenarios.py")

# The band of light left looping: an animation running with nobody on the panel.
mutate("Prompt.lua",
       "\tshine.move = shMove\n",
       '\tshine.move = shMove\n\tshine:SetLooping("REPEAT")\n',
       "shine left looping",
       expect="still running on a prompt with nobody on it",
       script="runscenarios.py")

# The sweep never told a cast went out.
mutate("Core.lua",
       "\tNoteCastWentOut(plain(spellId))\n"
       "\t-- The sweep over the prompt's icon starts with the cooldown this cast\n"
       "\t-- began, whichever button sent it.\n"
       "\tif ns.Prompt and ns.Prompt.SyncCooldown then\n",
       "\tNoteCastWentOut(plain(spellId))\n"
       "\t-- The sweep over the prompt's icon starts with the cooldown this cast\n"
       "\t-- began, whichever button sent it.\n"
       "\tif false then\n",
       "cooldown sweep not started by a cast",
       expect="the icon shows no cooldown",
       script="runscenarios.py")

# No fallback where the client withholds the cooldown.
mutate("Core.lua",
       "\tif castBlockedUntil > now and castBlockedUntil > castBlockedFrom then\n",
       "\tif false then\n",
       "cooldown sweep has no tracked fallback",
       expect="with the client's figure withheld",
       script="runscenarios.py")

# The switch that hides the sweep ignored.
mutate("Prompt.lua",
       "\tif not (p and p.showCooldown and p.showIcon) or quiet then\n",
       "\tif not p or quiet then\n",
       "cooldown sweep ignores its switches",
       expect="off the icon still sweeps",
       script="runscenarios.py")

# The red ring left standing in a fight.
mutate("Prompt.lua",
       "\t\t\t\tself:PaintAccent(current.reason)\n",
       "",
       "red ring kept for the fight",
       expect="the ring stayed red after the refusal was over, in a fight",
       script="runscenarios.py")

# The entrance's hop put back.
mutate("Prompt.lua",
       "\tdrop:SetOffset(0, -6)\n",
       "\tdrop:SetOffset(0, 0)\n",
       "entrance hops at the end",
       expect="the entrance's moves add up",
       script="runscenarios.py")

# The new settings left unrepaired.
mutate("Core.lua",
       '\toneOf(p, "effects", { full = true, calm = true }, "full")\n',
       "",
       "Effects not clamped",
       expect="an unknown effects value was kept",
       script="runscenarios.py")

mutate("Core.lua",
       '\tboolean(p, "showCooldown", true)\n',
       "",
       "cooldown switch not clamped",
       expect="a cooldown switch that is not a yes or a no",
       script="runscenarios.py")

# A rounded icon framed by the square halo again.
mutate("Prompt.lua",
       "\t\tlocal roundSize = round and p.iconSize or nil\n",
       "\t\tlocal roundSize = nil\n",
       "square halo round a rounded icon",
       expect="square glow piece 1 is shown round a rounded icon",
       script="runscenarios.py")

# One fade for every outcome, so the second is painted onto nothing.
mutate("Prompt.lua",
       "\t\t\t\tself:PlayOutro(outcomeAt)\n",
       "\t\t\t\tself:PlayOutro(true)\n",
       "second outcome gets no fade of its own",
       expect="a refusal after the fade was painted onto a panel",
       script="runscenarios.py")

# The light on arrival keyed on somebody owed reaching the top again.
mutate("Prompt.lua",
       "\tlocal arrived = debtAt ~= nil and debtAt > (seenDebtAt or -math.huge)\n"
       "\t\tand now - debtAt <= ARRIVAL_SECONDS\n",
       "\tlocal arrived = becameOwed\n",
       "arrival light keyed on reaching the top",
       expect="as if he had just buffed you",
       script="runscenarios.py")

# The light on arrival allowed over a success.
mutate("Prompt.lua",
       "\tif arrived and FullEffects() and not self:OutcomeLive()\n"
       "\t\tand not (shineFrame.anim and shineFrame.anim:IsPlaying()) then\n",
       "\tif arrived and FullEffects() then\n",
       "arrival light replaces the success",
       expect="for one buff landing",
       script="runscenarios.py")

# The sweep ignoring Stay quiet in combat.
mutate("Prompt.lua",
       "\tif not (p and p.showCooldown and p.showIcon) or quiet then\n",
       "\tif not (p and p.showCooldown and p.showIcon) then\n",
       "cooldown sweep ignores Stay quiet in combat",
       expect="the icon still sweeps with every cast of the fight",
       script="runscenarios.py")

# The sweep not brought back when the fight ends.
mutate("Prompt.lua",
       "\t-- The sweep answers to the fight as well: see SyncCooldown.\n\tself:SyncCooldown()\n",
       "",
       "cooldown sweep not resynced at the fight's edges",
       expect="the sweep did not come back",
       script="runscenarios.py")

# Light sent across a Minimal prompt, which has no panel.
mutate("Prompt.lua",
       "\tif ns.db and ns.db.profile.prompt.style == \"minimal\" then return end\n",
       "",
       "shine on the Minimal look",
       expect="crossed a minimal prompt",
       script="runscenarios.py")

# A fade cancelled by a fight snapping back.
mutate("Prompt.lua",
       "\tif not self.outroWanted then self:ComeBack(fadedTo) end\n",
       "\tif not self.outroWanted then self:ComeBack(nil) end\n",
       "cancelled fade snaps back",
       expect="snapped back instead of returning",
       script="runscenarios.py")

# The accent repainted on every scan whatever its colour.
mutate("Prompt.lua",
       "\tif key == accentPainted then return end\n",
       "",
       "accent repainted on every scan",
       expect="same passer-by made",
       script="runscenarios.py")

# The red ring not forgotten by the cache, so it is never put back.
mutate("Prompt.lua",
       "\t\tGradient(iconBack, \"VERTICAL\", 0.62, 0.16, 0.14, 0.95, 1.0, 0.36, 0.30, 0.95)\n"
       "\t\taccentPainted = nil\n",
       "\t\tGradient(iconBack, \"VERTICAL\", 0.62, 0.16, 0.14, 0.95, 1.0, 0.36, 0.30, 0.95)\n",
       "red ring outlives the colour cache",
       expect="the ring stayed red after the refusal was over",
       script="runscenarios.py")
