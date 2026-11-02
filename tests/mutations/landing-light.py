# Mutations for the landing's edge light, wave and fading wash and the
# refusal's crack, sputter, grey icon and struck shake:
# tests/scenarios/landing-light.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts back a mistake the
# strike or the break could plausibly make -- an edge lit like a border, a wave
# at full strength under the words, a wash restarted by every repaint or made
# after the light it should lie under, a crack grown into the reason line, an
# icon left grey or asked about on every scan, a shake that ends displaced, a
# crack left playing by a repaint, an edge lit with the other look's material
# or under the words -- and names the check that has to object.

EFFECTS = "Prompt/Effects.lua"
PANEL = "Prompt/Panel.lua"
PAINT = "Prompt/Paint.lua"
S = "runscenarios.py"

# --- the strike ---------------------------------------------------------------

# The edge lit to 0.90: a border drawn on, not a flash.
mutate(EFFECTS,
       "local EDGE_PEAK = 0.40\n",
       "local EDGE_PEAK = 0.90\n",
       "landing-light: the edge lit like a border",
       expect="landing-light: the edge light stays under 0.40", script=S)

# The wave at full strength under the words.
mutate(EFFECTS,
       "\t\tself:PlayShine(sr, sg, sb, 0.30)\n",
       "\t\tself:PlayShine(sr, sg, sb, 1.0)\n",
       "landing-light: the wave at full strength",
       expect="landing-light: the shockwave keeps the shine's strength", script=S)

# The wave anchored to the panel's left edge, over the icon.
mutate(PANEL,
       "\t\tR.shineFrame:SetPoint(\"LEFT\", R.icon, \"RIGHT\", SHINE_GAP, 0)\n",
       "\t\tR.shineFrame:SetPoint(\"LEFT\", R.art, \"LEFT\", 0, 0)\n",
       "landing-light: the wave starts under the icon",
       expect="landing-light: the shockwave keeps the shine's strength", script=S)

# The wash restarted by every repaint of the same outcome.
mutate(PAINT,
       "\t\tif S.washStamp ~= S.outcomeAt then\n",
       "\t\tif true then\n",
       "landing-light: the wash played on every repaint",
       expect="landing-light: the wash fades once", script=S)

# The wash left at whatever its last frame was: no rest to settle on.
mutate(EFFECTS,
       "\tfade:SetScript(\"OnFinished\", restWash)\n",
       "",
       "landing-light: the wash never settles at its rest",
       expect="landing-light: the wash fades once", script=S)

# The same instant's second outcome keeps the first's wash.
mutate(PAINT,
       "\t-- A new outcome gets its own wash, even one in the same instant as the last.\n\tS.washStamp = nil\n",
       "",
       "landing-light: an outcome in the same instant keeps the last wash",
       expect="landing-light: the wash fades once", script=S)

# The wash's frame made after the first frame of light: drawn over it.
mutate(PANEL,
       "\tR.washFrame = CreateFrame(\"Frame\", nil, R.art)\n\tR.washFrame:SetAllPoints()\n"
       "\tR.resultFill = Solid(R.washFrame, \"ARTWORK\", 2)\n\tR.resultFill:SetAllPoints(R.art)\n\tR.resultFill:Hide()\n\n"
       "\tR.sweepFrame = CreateFrame(\"Frame\", nil, R.art)\n",
       "\tR.sweepFrame = CreateFrame(\"Frame\", nil, R.art)\n"
       "\tR.washFrame = CreateFrame(\"Frame\", nil, R.art)\n\tR.washFrame:SetAllPoints()\n"
       "\tR.resultFill = Solid(R.washFrame, \"ARTWORK\", 2)\n\tR.resultFill:SetAllPoints(R.art)\n\tR.resultFill:Hide()\n",
       "landing-light: the wash made after the light",
       expect="landing-light: the wash lies under the light", script=S)

# The edge lit on Minimal, which has no edge.
mutate(EFFECTS,
       "\t\tif p.style == \"minimal\" then\n\t\t\tfor _, rule in ipairs({ R.ruleTop, R.ruleBottom }) do\n",
       "\t\tif false then\n\t\t\tfor _, rule in ipairs({ R.ruleTop, R.ruleBottom }) do\n",
       "landing-light: minimal lights an edge it does not have",
       expect="landing-light: the edge carrier follows the look", script=S)

# Calm fades the wash.
mutate(PAINT,
       "\tif FullEffects() then\n\t\tif S.washStamp ~= S.outcomeAt then\n",
       "\tif true then\n\t\tif S.washStamp ~= S.outcomeAt then\n",
       "landing-light: Calm fades the wash",
       expect="landing-light: Calm keeps the static wash", script=S)

# --- the break ---------------------------------------------------------------

# The crack never shorter than six units: into the name at the smallest panel.
mutate(PANEL,
       "local CRACK_INSET, CRACK_END, CRACK_MIN, CRACK_MAX = 1.0, 0.3, 2, 7\n",
       "local CRACK_INSET, CRACK_END, CRACK_MIN, CRACK_MAX = 1.0, 0.3, 6, 7\n",
       "landing-light: the crack grows into the words",
       expect="landing-light: the crack stays under the words", script=S)

# The crack lifted eight units off the bottom: into the reason line.
mutate(PANEL,
       "local CRACK_INSET, CRACK_END, CRACK_MIN, CRACK_MAX = 1.0, 0.3, 2, 7\n",
       "local CRACK_INSET, CRACK_END, CRACK_MIN, CRACK_MAX = 8.0, 0.3, 2, 7\n",
       "landing-light: the crack lifted into the reason line",
       expect="landing-light: the crack stays under the words", script=S)

# The icon never given its colour back when the outcome runs out.
mutate(PAINT,
       "\tif R.resultFill then R.resultFill:Hide() end\n\tself:UngreyIcon()\n\tif S.activeLook then S.activeLook:ClearOutcome() end\n\treturn false\n",
       "\tif R.resultFill then R.resultFill:Hide() end\n\tif S.activeLook then S.activeLook:ClearOutcome() end\n\treturn false\n",
       "landing-light: the icon kept grey after the outcome",
       expect="landing-light: a refusal greys the icon and gives it back", script=S)

# The icon asked for its colour on every scan.
mutate(EFFECTS,
       "\tif S.iconGreyed then\n\t\tS.iconGreyed = nil\n\t\tR.icon:SetDesaturated(false)\n\tend\n",
       "\tS.iconGreyed = nil\n\tR.icon:SetDesaturated(false)\n",
       "landing-light: the icon ungreyed on every scan",
       expect="landing-light: an ungreyed icon costs nothing", script=S)

# The shake's last step +1: the words end displaced.
mutate(EFFECTS,
       "{ -3, 5, -4, 3, -2, 1.5, -0.5 }",
       "{ -3, 5, -4, 3, -2, 1.5, 1 }",
       "landing-light: the struck shake ends displaced",
       expect="the shake's steps add up to", script=S)

# The crack left playing by a repaint about somebody else.
mutate(EFFECTS,
       "\t\tR.ruleTop.flicker, R.edgeLightFrame.land, R.edgeLightFrame.reject, R.crackFrame.split, R.washFrame.fade }) do\n",
       "\t\tR.ruleTop.flicker, R.edgeLightFrame.land, R.edgeLightFrame.reject, R.washFrame.fade }) do\n",
       "landing-light: a repaint leaves the crack playing",
       expect="landing-light: a restyle leaves nothing lit", script=S)

# The top rule's sputter left playing by a look applied over it.
mutate(PANEL,
       "\t\tR.textLayer.reveal, R.ruleTop.flare, R.ruleBottom.flare, R.ruleTop.flicker, R.edgeLightFrame.land,\n",
       "\t\tR.textLayer.reveal, R.ruleTop.flare, R.ruleBottom.flare, R.edgeLightFrame.land,\n",
       "landing-light: a look applied leaves the sputter playing",
       expect="landing-light: a restyle leaves nothing lit", script=S)

# --- the retired file -----------------------------------------------------------

# The wave drawn from the old band's file.
mutate("Prompt/Prompt.lua",
       "local SHOCK = \"Interface\\\\AddOns\\\\Manners\\\\Textures\\\\Shock\"\n",
       "local SHOCK = \"Interface\\\\AddOns\\\\Manners\\\\Textures\\\\Sweep\"\n",
       "landing-light: the wave drawn from the retired band",
       expect="landing-light: the old sweep is retired", script=S)

# --- the material lit -----------------------------------------------------------

# The glass's edge drawn from the rim's file: a rail flashing on a pane.
mutate(PANEL,
       "\tR.edgeLightFrame.glass = Slice(R.edgeLightFrame, \"OVERLAY\", 1, GLASS_LIGHT)\n",
       "\tR.edgeLightFrame.glass = Slice(R.edgeLightFrame, \"OVERLAY\", 1, TOOLTIP_RIM)\n",
       "landing-light: the glass's edge lit with the rim",
       expect="landing-light: the edge light is the material", script=S)

# The edge's pieces drawn opaque, not as light.
mutate(PANEL,
       "\t\tfor _, t in ipairs(pieces) do\n\t\t\tt:SetBlendMode(\"ADD\")\n\t\t\tt:Hide()\n\t\tend\n",
       "\t\tfor _, t in ipairs(pieces) do\n\t\t\tt:Hide()\n\t\tend\n",
       "landing-light: the edge's light drawn opaque",
       expect="landing-light: the edge light stays under 0.40", script=S)

# The middle piece lit too: the glass's caustic flashing under the words.
mutate(PANEL,
       "\tfor i, t in ipairs(lit.glass) do t:SetShown(glass and i ~= 5) end\n",
       "\tfor i, t in ipairs(lit.glass) do t:SetShown(glass) end\n",
       "landing-light: the edge lit under the words",
       expect="landing-light: the edge light is the material", script=S)

# The framed look's edge lit with the glass's pieces, which it hides.
mutate(PANEL,
       "\tlit.pieces = framed and lit.rim or lit.glass\n",
       "\tlit.pieces = lit.glass\n",
       "landing-light: framed lights the glass's edge",
       expect="landing-light: the edge light is the material", script=S)
