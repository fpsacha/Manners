# Mutations for the effects and art of hunt 35: tests/scenarios/hunt35-effects.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts back a mistake an
# effect could plausibly make -- an arrival that plays on every repaint, a
# landing that does not radiate, a Calm that still scales, a ring left playing
# when the look changes, a secure frame animated in a fight, a texture
# generator that is not deterministic -- and names the check that has to
# object.

EFFECTS = "Prompt/Effects.lua"
PANEL = "Prompt/Panel.lua"
S = "runscenarios.py"

# --- the arrival -----------------------------------------------------------

# The icon's echo never dropped.
mutate(EFFECTS,
       "\t\tR.fx:Arrive(file, Tint(r, g, b, 0.55))\n",
       "",
       "hunt35: the icon's echo never drops on a favour",
       expect="the icon's echo played", script=S)

# The arrival played on every repaint of somebody owed.
mutate(EFFECTS,
       "\tif isNew and FullEffects() and not self:OutcomeLive() and R.burstFrame.arrive then\n",
       "\tif FullEffects() and not self:OutcomeLive() and R.burstFrame.arrive then\n",
       "hunt35: the arrival plays on every repaint",
       expect="the arrival played again on a repaint of the same favour", script=S)

# The arrival played on Calm.
mutate(EFFECTS,
       "\tif isNew and FullEffects() and not self:OutcomeLive() and R.burstFrame.arrive then\n",
       "\tif isNew and not self:OutcomeLive() and R.burstFrame.arrive then\n",
       "hunt35: the arrival plays on Calm",
       expect="in glass: with Effects on Calm the arrive still played", script=S)

# The arrival played over an outcome still up.
mutate(EFFECTS,
       "\tif isNew and FullEffects() and not self:OutcomeLive() and R.burstFrame.arrive then\n",
       "\tif isNew and FullEffects() and R.burstFrame.arrive then\n",
       "hunt35: the arrival plays over an outcome",
       expect="the arrival of the next favour played over the confirmation of the last", script=S)

# A passer-by got the arrival a favour gets.
mutate("Prompt/Refresh.lua",
       "\tif top.reason == \"owed\" then\n\t\tself:StartAttention(becameOwed, arrived)\n",
       "\tif true then\n\t\tself:StartAttention(becameOwed or isNew, arrived)\n",
       "hunt35: a passer-by arrives like a favour",
       expect="a passer-by on the panel played the favour's arrival", script=S)

# --- the landing and the refusal --------------------------------------------

# A confirmed buff with no rings.
mutate(EFFECTS,
       "\t\t\tR.fx:Land(Tint(r, g, b, 0.20))\n",
       "",
       "hunt35: a landed buff spreads no rings",
       expect="in glass: a buff the game confirmed did not spread both rings", script=S)

# The panel does not settle as the buff lands.
mutate(EFFECTS,
       "\t\tself:PlayShine(sr, sg, sb, 0.30)\n\t\tR.art.settle:Play()\n",
       "\t\tself:PlayShine(sr, sg, sb, 0.30)\n",
       "hunt35: a landed buff does not settle the panel",
       expect="in glass: a landed buff did not settle the panel", script=S)

# The same on a look of its own.
mutate(EFFECTS,
       "\t\tif kind == \"cast\" then R.art.settle:Play() end\n",
       "",
       "hunt35: a landed buff does not settle a look's panel",
       expect="in luxe: a landed buff did not settle the panel", script=S)

# A refusal with no contracting ring.
mutate(EFFECTS,
       "\t\t\tR.fx:Refuse(1.00, 0.38, 0.22)\n",
       "",
       "hunt35: a refusal contracts no ring",
       expect="in glass: a refusal did not contract a ring onto the icon", script=S)

# A refusal that radiates as a landing does.
mutate(EFFECTS,
       "\t\t\tR.fx:Refuse(1.00, 0.38, 0.22)\n",
       "\t\t\tR.fx:Refuse(1.00, 0.38, 0.22)\n\t\t\tR.fx:Land(1, 1, 1)\n",
       "hunt35: a refusal radiates like a landing",
       expect="in glass: a refusal spread the landing's rings", script=S)

# A cast nobody confirmed flourished like a refusal.
mutate(EFFECTS,
       "\telseif kind == \"failed\" then\n\t\tif p.showIcon and R.burstFrame.reject then\n",
       "\telseif kind ~= \"cast\" then\n\t\tif p.showIcon and R.burstFrame.reject then\n",
       "hunt35: an unconfirmed cast flourishes",
       expect="in glass: a cast nobody confirmed got a flourish", script=S)

# The refusal's shake does not sum to nothing: the text ends displaced.
mutate(EFFECTS,
       "{ -3, 5, -5, 4, -2, 1 }",
       "{ -3, 5, -5, 4, -2, 3 }",
       "hunt35: the shake ends displaced",
       expect="the shake's steps add up to", script=S)

# A shake that does not die away.
mutate(EFFECTS,
       "{ -3, 5, -5, 4, -2, 1 }",
       "{ 1, -2, 3, -4, 5, -3 }",
       "hunt35: the shake grows to the end",
       expect="the shake ends nearly as hard as it began", script=S)

# --- Calm and the fight ------------------------------------------------------

# Calm played the flourishes.
mutate(EFFECTS,
       "\tif not p or not FullEffects() then return end\n",
       "\tif not p then return end\n",
       "hunt35: Calm plays the outcome's flourishes",
       expect="in glass: with Effects on Calm the land still played", script=S)

# Calm's entrance grows.
mutate(EFFECTS,
       "\tAlpha(introCalm, 0, 1, 0.20, 1, 0, \"OUT\")\n",
       "\tAlpha(introCalm, 0, 1, 0.20, 1, 0, \"OUT\")\n\tGrow(introCalm, 0.9, 1, 0.20, 1)\n",
       "hunt35: Calm's entrance scales",
       expect="Calm's entrance has a Scale in it", script=S)

# The panel comes up with the full entrance on Calm.
mutate(EFFECTS,
       "\t\tR.art.introCalm:Play()\n",
       "\t\tR.art.intro:Play()\n",
       "hunt35: Calm gets the full entrance",
       expect="on calm the panel came up with the wrong entrance", script=S)

# "Keep the prompt dim and still" ignored.
mutate(EFFECTS,
       "\tif InCombatLockdown() and p.hideInCombat then return end\n",
       "",
       "hunt35: the effects ignore the quiet fight",
       expect="with the prompt kept dim and still in combat the", script=S)

# An effect that touches the secure button in a fight.
mutate(EFFECTS,
       "\t\tself:PlayShine(sr, sg, sb, 0.30)\n\t\tR.art.settle:Play()\n",
       "\t\tself:PlayShine(sr, sg, sb, 0.30)\n\t\tR.art.settle:Play()\n\t\tR.button:SetScale(1)\n",
       "hunt35: a landing scales the secure button",
       expect="an outcome's effects in a fight called", script=S)

# A group made on the secure button itself.
mutate(EFFECTS,
       "\tlocal settle = R.art:CreateAnimationGroup()\n",
       "\tlocal settle = R.button:CreateAnimationGroup()\n",
       "hunt35: the settle is animated on the secure button",
       expect="an animation group is on a protected frame", script=S)

# --- stopping ---------------------------------------------------------------

# The rings left going when a repaint is about somebody else.
mutate(EFFECTS,
       "\tif R.fx then R.fx:Stop() end\n",
       "",
       "hunt35: the rings outlive a repaint",
       expect="a landing's or a refusal's effect was still playing after a repaint stopped them", script=S)

# The rings left going when the look changes.
mutate(PANEL,
       "\tR.fx:Stop()\n",
       "",
       "hunt35: the rings outlive the look",
       expect="in glass: an effect of the old look was still playing after the look changed", script=S)

# Luxe's rings left going when it is left.
mutate("Looks/Luxe.lua",
       "\tself.fx:Stop()\n\t-- Stop parks nothing on a fade that has already finished, and the cursor\n",
       "\t-- Stop parks nothing on a fade that has already finished, and the cursor\n",
       "hunt35: Luxe's rings outlive Luxe",
       expect="in luxe: an effect of the old look was still playing after the look changed", script=S)

# --- the owed breath ---------------------------------------------------------

# A breath too fast to be a breath.
mutate(EFFECTS,
       "\tAlpha(pulse, 0.14, 0.62, 1.2, 1, 0, \"IN_OUT\")\n",
       "\tAlpha(pulse, 0.14, 0.62, 0.4, 1, 0, \"IN_OUT\")\n",
       "hunt35: the owed breath is a flicker",
       expect="the owed breath is", script=S)

# The warm rim never breathes.
mutate(EFFECTS,
       "\t\t\tR.rimFrame.pulse:Play()\n",
       "",
       "hunt35: the warm rim does not breathe",
       expect="the glow and the rim are not both breathing", script=S)

# --- each look in its own idiom ----------------------------------------------

mutate("Looks/Luxe.lua",
       "\t\tself.fx:Land(o[1], o[2], o[3])\n",
       "",
       "hunt35: Luxe's rings never spread",
       expect="in luxe: a buff the game confirmed did not spread both rings", script=S)

mutate("Looks/Toast.lua",
       "\t\tself.fx:Land(o[1], o[2], o[3], 0.70)\n",
       "",
       "hunt35: Toast's rings never spread",
       expect="in toast: a buff the game confirmed did not spread both rings", script=S)

mutate("Looks/Arcane.lua",
       "\t\tself.fx:Land(o[1], o[2], o[3], 0.85)\n",
       "",
       "hunt35: Arcane's rings never spread",
       expect="in arcane: a buff the game confirmed did not spread both rings", script=S)

mutate("Looks/Luxe.lua",
       "\t\tif self.kit.icon:IsShown() then self.fx:Refuse(o[1], 0.45, 0.28) end\n",
       "",
       "hunt35: Luxe's refusal contracts no ring",
       expect="in luxe: a refusal did not contract a ring onto the icon", script=S)

mutate("Looks/Toast.lua",
       "\t\tif self.kit.icon:IsShown() then self.fx:Refuse(1.00, 0.40, 0.22, 0.85) end\n",
       "",
       "hunt35: Toast's refusal contracts no ring",
       expect="in toast: a refusal did not contract a ring onto the icon", script=S)

mutate("Looks/Arcane.lua",
       "\t\t\tself.fx:Refuse(o[1], 0.45, 0.28)\n",
       "",
       "hunt35: Arcane's refusal contracts no ring",
       expect="in arcane: a refusal did not contract a ring onto the icon", script=S)

# The lens's ring locking on, on Calm.
mutate("Looks/Luxe.lua",
       "\t\tif full then\n\t\t\tself.popAnim:Stop()\n",
       "\t\tif true then\n\t\t\tself.popAnim:Stop()\n",
       "hunt35: Luxe's ring locks on on Calm",
       expect="in luxe: with Effects on Calm the arrive still played", script=S)

mutate("Looks/Arcane.lua",
       "\t\tif full and self.showIcon then\n\t\t\tself.runeFlareAnim:Stop()\n",
       "\t\tif self.showIcon then\n\t\t\tself.runeFlareAnim:Stop()\n",
       "hunt35: Arcane's lens locks on on Calm",
       expect="in arcane: with Effects on Calm the arrive still played", script=S)

# A ring that outstays the landing.
mutate(EFFECTS,
       "local RING_SECONDS = { 0.52, 0.46 }\n",
       "local RING_SECONDS = { 0.52, 1.2 }\n",
       "hunt35: the second ring outstays the landing",
       expect="a landing's effect lasts", script=S)

# --- the cooldown ------------------------------------------------------------

mutate(PANEL,
       "\t\tTry(R.cooldown, \"SetDrawEdge\", true)\n",
       "\t\tTry(R.cooldown, \"SetDrawEdge\", false)\n",
       "hunt35: the sweep has no leading edge",
       expect="the sweep has no leading edge", script=S)

mutate(PANEL,
       "\t\tif R.cooldown and R.cooldown.SetUseCircularEdge then R.cooldown:SetUseCircularEdge(round) end\n",
       "",
       "hunt35: a round icon's sweep keeps a square edge",
       expect="in glass: the sweep's edge is not round with a round icon", script=S)

# --- the glass ---------------------------------------------------------------

mutate(PANEL,
       "\tR.sheen:SetTexture(GLOSS)\n",
       "",
       "hunt35: the glass has no reflection",
       expect="the glass's sheen is not the reflection art", script=S)

mutate(PANEL,
       "\t\t\tt:SetShown(glass)\n\t\t\tt:SetVertexColor(1, 1, 1, ba)\n",
       "\t\t\tt:SetShown(true)\n\t\t\tt:SetVertexColor(1, 1, 1, ba)\n",
       "hunt35: the bevel on every built-in look",
       expect=": the bevel is shown when it should not be", script=S)

mutate(PANEL,
       "\t\t\tt:SetShown(glass)\n\t\t\tt:SetVertexColor(1, 1, 1, ba)\n",
       "\t\t\tt:SetShown(glass)\n\t\t\tt:SetVertexColor(1, 1, 1, 1)\n",
       "hunt35: the bevel ignores the panel's opacity",
       expect="the bevel does not follow the panel's opacity", script=S)

# --- the colours -------------------------------------------------------------

mutate("Prompt/Prompt.lua",
       "\tlocal k = 1 + t\n",
       "\tlocal k = 1 + 2 * t\n",
       "hunt35: a shade leaves the colour's range",
       expect="leaves the range", script=S)

mutate("Prompt/Prompt.lua",
       "\towed = { 1.00, 0.78, 0.30 },\n",
       "\towed = { 1.00, 0.80, 0.30 },\n",
       "hunt35: the owed colour moved",
       expect="the standard owed colour is not what it was", script=S)

# --- the art -----------------------------------------------------------------

# A generator that is not deterministic.
mutate("tools/make-glow.py",
       "    save(out, \"Glow\", 1.0, falloff(np.hypot(dx, dy)))\n",
       "    save(out, \"Glow\", 1.0, falloff(np.hypot(dx, dy)) * (1 - 0.01 * np.random.rand(N, N)))\n",
       "hunt35: Glow.tga differs between runs",
       expect="Glow.tga differs between two runs", script=S)

# A parameter changed and the art not redrawn.
mutate("tools/make_luxe_textures.py",
       "SPINE_SHADE, SPINE_LOWER = 0.76, 0.10\n",
       "SPINE_SHADE, SPINE_LOWER = 0.77, 0.10\n",
       "hunt35: the spine's parameters moved and the art did not",
       expect="Luxe_Spine.tga does not match the file that ships", script=S)

mutate("tools/make_toast_textures.py",
       "GOLD_LIT, ENAMEL_LIT = 0.17, 0.15\n",
       "GOLD_LIT, ENAMEL_LIT = 0.18, 0.15\n",
       "hunt35: the gold's parameters moved and the art did not",
       expect="Toast_Gold.tga does not match the file that ships", script=S)

mutate("tools/make_arcane_textures.py",
       "RUNE_LIT_MIN = 0.58\n",
       "RUNE_LIT_MIN = 0.59\n",
       "hunt35: the runes' parameters moved and the art did not",
       expect="Arcane_RuneRing.tga does not match the file that ships", script=S)

# A texture drawn past the size the clients are given.
mutate("tools/make-glow.py",
       "N = 128\n\n\ndef polar():",
       "N = 512\n\n\ndef polar():",
       "hunt35: a glow drawn at 512",
       expect="Glow.tga is 512x512", script=S)
