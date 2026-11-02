# Mutations for the entrance's rules of light, the words' reveal and the glint
# a favour runs along the rules: tests/scenarios/entrance-light.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts back a mistake the
# entrance could plausibly make -- a sweep that slides on Calm, a rule that
# draws past the words, a reveal left running by a repaint, a glint hung from
# the rule it runs (and so never seen), a flourish that snaps a look's fight
# dim back, a reading of a Scale that forgets its origin -- and names the check
# that has to object.

EFFECTS = "Prompt/Effects.lua"
PANEL = "Prompt/Panel.lua"
PAINT = "Prompt/Paint.lua"
GEOMETRY = "tests/fxgeometry.lua"
S = "runscenarios.py"

# --- the entrance -----------------------------------------------------------

# A rule that takes 0.60 s to draw: past the words, past the arrival's ceiling.
mutate(EFFECTS,
       "\t\tGrow(draw, 0.04, 1, 0.26, 2, 0, \"OUT\", 1, 1, \"LEFT\")\n\t\tAlpha(draw, 0.95, 0.95, 0.26, 2)\n",
       "\t\tGrow(draw, 0.04, 1, 0.60, 2, 0, \"OUT\", 1, 1, \"LEFT\")\n\t\tAlpha(draw, 0.95, 0.95, 0.60, 2)\n",
       "entrance-light: a rule draws for 0.60 s",
       expect="entrance-light: the words arrive with the panel", script=S)

# The words take half a second to arrive.
mutate(EFFECTS,
       "\tAlpha(reveal, 0, 1, 0.16, 2, 0, \"OUT\")\n",
       "\tAlpha(reveal, 0, 1, 0.50, 2, 0, \"OUT\")\n",
       "entrance-light: the words arrive late",
       expect="entrance-light: the words arrive with the panel", script=S)

# The rules on the panel's very edge.
mutate(PANEL,
       "local RULE_INSET, RULE_END, RULE_X0, GLINT_LENGTH = 1.5, 2, 6, 14\n",
       "local RULE_INSET, RULE_END, RULE_X0, GLINT_LENGTH = 0, 2, 6, 14\n",
       "entrance-light: the rules lie on the panel's edge",
       expect="entrance-light: the rules stay off the words", script=S)

# Calm's panel holds the words back too.
mutate(EFFECTS,
       "\t\tR.art.intro:Stop()\n\t\tR.art.introCalm:Play()\n",
       "\t\tR.art.intro:Stop()\n\t\tR.art.introCalm:Play()\n\t\tif R.textLayer.reveal then R.textLayer.reveal:Play() end\n",
       "entrance-light: Calm holds the words back",
       expect="entrance-light: Calm keeps the words", script=S)

# A look from Looks/ gets the rules drawn over it.
mutate(EFFECTS,
       "\t\tif not S.activeLook and R.ruleTop and R.ruleTop.draw then\n",
       "\t\tif R.ruleTop and R.ruleTop.draw then\n",
       "entrance-light: the rules draw under a look of its own",
       expect="entrance-light: a look from Looks/ sees none of it", script=S)

# Minimal draws the rules at full strength over the world.
mutate(PANEL,
       "\tS.ruleStrength = style == \"minimal\" and 0.6 or 1.0\n",
       "\tS.ruleStrength = 1.0\n",
       "entrance-light: minimal's rules at full strength",
       expect="entrance-light: minimal draws the rules at half strength", script=S)

# --- the words' reveal and its stops ----------------------------------------

# A repaint mid-entrance leaves the reveal running.
mutate(EFFECTS,
       "\t\tif R.textLayer.reveal and R.textLayer.reveal:IsPlaying() then R.textLayer.reveal:Stop() end\n\t\tR.textLayer:SetAlpha(1)\n",
       "\t\tR.textLayer:SetAlpha(1)\n",
       "entrance-light: a repaint leaves the reveal running",
       expect="entrance-light: a style change mid-entrance leaves the words lit", script=S)

# A repaint mid-entrance leaves the rules drawing.
mutate(EFFECTS,
       "\t\tR.textLayer.shake, R.art.settle, R.ruleTop.draw, R.ruleBottom.draw, R.ruleTop.flare, R.ruleBottom.flare,\n",
       "\t\tR.textLayer.shake, R.art.settle, R.ruleTop.flare, R.ruleBottom.flare,\n",
       "entrance-light: a repaint leaves the rules drawing",
       expect="entrance-light: a style change mid-entrance leaves the words lit", script=S)

# A look applied mid-entrance leaves the reveal running.
mutate(PANEL,
       "\tfor _, g in ipairs({ R.ruleTop.draw, R.ruleBottom.draw, R.glintTop.run, R.glintBottom.run,\n\t\tR.textLayer.reveal, R.ruleTop.flare,",
       "\tfor _, g in ipairs({ R.ruleTop.draw, R.ruleBottom.draw, R.glintTop.run, R.glintBottom.run,\n\t\tR.ruleTop.flare,",
       "entrance-light: a look applied leaves the reveal running",
       expect="entrance-light: a style change mid-entrance leaves the words lit", script=S)

# The words put at full by a flourish under any look: a look's fight dim
# snapped back.
mutate(EFFECTS,
       "\tif not S.activeLook then\n\t\tif R.textLayer.reveal and R.textLayer.reveal:IsPlaying() then R.textLayer.reveal:Stop() end\n",
       "\tif true then\n\t\tif R.textLayer.reveal and R.textLayer.reveal:IsPlaying() then R.textLayer.reveal:Stop() end\n",
       "entrance-light: a flourish snaps a look's fight dim back",
       expect="entrance-light: a look's fight dim survives a flourish", script=S)

# An outcome during the entrance dips words that are still arriving.
mutate(PAINT,
       "\tif not S.activeLook and R.textLayer.reveal and R.textLayer.reveal:IsPlaying() then\n"
       "\t\tR.textLayer.reveal:Stop()\n\t\tR.textLayer:SetAlpha(1)\n\tend\n",
       "",
       "entrance-light: an outcome dips words still arriving",
       expect="entrance-light: an outcome during the entrance keeps the words", script=S)

# --- the glint --------------------------------------------------------------

# The glint keyed on a name reaching the top rather than on the favour.
mutate(EFFECTS,
       "\tif arrived and FullEffects() and not self:OutcomeLive() and not S.glintPlaying and R.glintTop.run then\n",
       "\tif isNew and FullEffects() and not self:OutcomeLive() and not S.glintPlaying and R.glintTop.run then\n",
       "entrance-light: the glint runs for a name reaching the top",
       expect="as if he had just buffed you", script=S)

# The glints hung from the rules they run, which rest at nothing: never seen.
mutate(PANEL,
       "\t\tlocal glint = CreateFrame(\"Frame\", nil, R.art)\n\t\tglint:SetFrameLevel(R.art:GetFrameLevel() + 2)\n",
       "\t\tlocal glint = CreateFrame(\"Frame\", nil, R[which == \"glintTop\" and \"ruleTop\" or \"ruleBottom\"])\n"
       "\t\tglint:SetFrameLevel(R.art:GetFrameLevel() + 2)\n",
       "entrance-light: the glints hang from the parked rules",
       expect="entrance-light: the glint is seen", script=S)

# The glints left running when the favour leaves the panel.
mutate(EFFECTS,
       "\tif S.glintPlaying then\n\t\tR.glintTop.run:Stop()\n\t\tR.glintBottom.run:Stop()\n\t\tS.glintPlaying = nil\n\tend\n",
       "",
       "entrance-light: the glints outlive the favour",
       expect="entrance-light: a favour's glint runs the rules", script=S)

# The glint at full strength on minimal.
mutate(EFFECTS,
       "\t\tlocal k = 0.9 * (S.ruleStrength or 1)\n",
       "\t\tlocal k = 0.9\n",
       "entrance-light: minimal's glint at full strength",
       expect="entrance-light: minimal draws the rules at half strength", script=S)

# --- Calm ---------------------------------------------------------------------

# The stripe's sweep slides on Calm.
mutate(EFFECTS,
       "\tif isNew and FullEffects() and R.sweepFrame.anim and R.sweepFrame:IsShown() then\n",
       "\tif isNew and R.sweepFrame.anim and R.sweepFrame:IsShown() then\n",
       "entrance-light: the sweep slides on Calm",
       expect="entrance-light: Calm drops the light sweep", script=S)

# --- the geometry the tests read ---------------------------------------------

# A Scale read about the frame's middle whatever origin it names.
mutate(GEOMETRY,
       "\t\t\t\t\tlocal point = origin and origin[1] or \"CENTER\"\n",
       "\t\t\t\t\tlocal point = \"CENTER\"\n",
       "entrance-light: rectAt forgets the scale's origin",
       expect="entrance-light: hunt37 rectAt honours the origin", script=S)
