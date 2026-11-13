# Mutations for the built-in looks' material: the glass pane and its light,
# the icon's bezel and the framed look's rim (tests/scenarios/panel-material.lua).
#
# Run by tests/selftest.py with mutate() in scope. Each puts back a mistake the
# panel could plausibly make -- the ink judged on the bare panel colour, a bezel
# taller than its panel, a bezel under the hairline, a hover that lingers, the
# framed look refusing its stripe, light drawn in the middle cell under the
# words, the corner's pooled light shrunk back to a speck, the slab's
# refraction line lost, moved, widened, glaring, lit from the wrong side,
# stripped of its tint or turned mint, its gap closed, its fill light dimmed
# or outshining the lit side, its shade side or its glow undone, the light
# tinted by the panel or off the player's opacity or corners, the pane's top
# off the player's colour, a generator that draws different bytes each run --
# and names the check that has to object.

PANEL = "Prompt/Panel.lua"
TEXT = "Prompt/Text.lua"
EFFECTS = "Prompt/Effects.lua"
GEN = "tools/make_panel_textures.py"
S = "runscenarios.py"

# --- the ink -----------------------------------------------------------------

# The ink judged on the bare panel colour, as if the pane were clear glass.
mutate(TEXT,
       "\t\tif style == \"glass\" then pane = PANE_MID end\n",
       "\t\tif style == \"glass\" then pane = 1 end\n",
       "panel-material: the ink forgets the pane",
       expect="panel-material: ink is judged on the pane", script=S)

# --- the bezel ---------------------------------------------------------------

# A bezel as large as the icon asks, taller than the panel at the biggest icon.
mutate(PANEL,
       "\t\tlocal bezelSize = math.min(p.iconSize / BEZEL_FRAME, p.height - 1)\n",
       "\t\tlocal bezelSize = p.iconSize / BEZEL_FRAME\n",
       "panel-material: the bezel outgrows the panel",
       expect="panel-material: the bezel fits the panel", script=S)

# The bezel under the pane's hairline and the framed look's rim.
mutate(PANEL,
       "\tR.bezel = R.art:CreateTexture(nil, \"BORDER\", nil, 4)\n",
       "\tR.bezel = R.art:CreateTexture(nil, \"BORDER\", nil, -2)\n",
       "panel-material: the bezel sinks under the hairline",
       expect="panel-material: the bezel sits over the hairline and the rim", script=S)

# --- the cursor --------------------------------------------------------------

# The gold lingers after the cursor has gone.
mutate(EFFECTS,
       "\tbezelLeave.fade = Alpha(bezelLeave, 1, 0, 0.18, 1, 0, \"IN\")\n",
       "\tbezelLeave.fade = Alpha(bezelLeave, 1, 0, 0.6, 1, 0, \"IN\")\n",
       "panel-material: the gold lingers under a cursor that left",
       expect="panel-material: hover leaves in 0.18 s", script=S)

# The enter's end not put on the texture: the gold fades up for 0.12 s and
# falls back to its base of nothing while the cursor stays.
mutate(EFFECTS,
       "\t\tR.bezelHover:SetAlpha(1)\n",
       "",
       "panel-material: the gold falls back at the end of its fade up",
       expect="panel-material: hover leaves in 0.18 s", script=S)

# The tooltip or Shift asking again with the cursor still there restarts the
# fade, from wherever the client left the texture.
mutate(EFFECTS,
       "\tif t.goal == goal or (goal == 0 and not t.goal) then return end\n",
       "",
       "panel-material: a repeated arrival restarts the gold",
       expect="panel-material: hover leaves in 0.18 s", script=S)

# A cursor that leaves part way up lets go from nothing, not from where it was.
mutate(EFFECTS,
       "\tlocal from = BezelLevel(t)\n",
       "\tlocal from = 0\n",
       "panel-material: the gold lets go from nothing",
       expect="panel-material: hover leaves mid-enter from where it got", script=S)

# A look from Looks/ taking the panel leaves the cursor's state behind, so the
# first arrival after it is taken for a cursor already there.
mutate(PANEL,
       "\tR.bezelHover.level, R.bezelHover.goal, R.bezelHover.start = 0, nil, nil\n",
       "",
       "panel-material: the gold remembers the cursor through a look",
       expect="panel-material: hover lifts again after a look from Looks/", script=S)

# The lift as no lift: the bezel's own colour again under the cursor.
mutate(PANEL,
       "\tlocal hr, hg, hb = Tint(mr, mg, mb, HOVER_LIFT)\n",
       "\tlocal hr, hg, hb = Tint(mr, mg, mb, 0)\n",
       "panel-material: the bezel's lift shows nothing",
       expect="panel-material: the bezel wears the reason colour and the icon's shape", script=S)

# The cursor's hooks on the prompt: arriving and leaving ask the built-in
# looks' bezel for its lift, and a look from Looks/ is never asked.
BUTTON = "Prompt/Button.lua"
mutate(BUTTON,
       "\t\tif not S.activeLook then Prompt:HoverBezel(true) end\n",
       "\t\tif not S.activeLook then end\n",
       "panel-material: the cursor arriving does not lift the bezel",
       expect="panel-material: hover leaves in 0.18 s", script=S)
mutate(BUTTON,
       "\t\tif not S.activeLook then Prompt:HoverBezel(false) end\n",
       "\t\tif not S.activeLook then end\n",
       "panel-material: the cursor leaving does not let the bezel go",
       expect="panel-material: hover leaves in 0.18 s", script=S)
mutate(BUTTON,
       "\t\tif not S.activeLook then Prompt:HoverBezel(true) end\n",
       "\t\tPrompt:HoverBezel(true)\n",
       "panel-material: a look from Looks/ lifts the bezel under it",
       expect="the bezel's gold played under a look from Looks/", script=S)

# --- the stripe --------------------------------------------------------------

# The framed look refusing its stripe again.
mutate(PANEL,
       "\tlocal showAccent = (mode == \"stripe\" or mode == \"both\")\n",
       "\tlocal showAccent = not framed and (mode == \"stripe\" or mode == \"both\")\n",
       "panel-material: the framed look refuses the stripe",
       expect="panel-material: framed carries the stripe", script=S)

# --- the art -----------------------------------------------------------------

# The caustic drawn back into the middle cell, a soft band across the name's
# line that the 9-slice stretches into a smear beside the words.
mutate(GEN,
       "    alpha = np.maximum(light, dark) * shape\n",
       "    alpha = np.maximum(np.maximum(light, dark), 0.10 * np.exp(-0.5 * ((y - 51.2) / 6.4) ** 2)) * shape\n",
       "panel-material: a caustic band drawn in the middle cell",
       expect="panel-material: the middle cell carries no light", script=S)

# The corner's light brightened in the generator and the file not redrawn:
# the file that ships no longer matches what the generator draws.
mutate(GEN,
       "BEAD_PEAK = 0.65 ",
       "BEAD_PEAK = 0.70 ",
       "panel-material: the corner's light changes and the file is not redrawn",
       expect="panel-material: the generator draws the same bytes twice and what ships", script=S)

# The pool's reach cut to a texel or so: the corner's light shrinks back to
# the speck that read as a stuck pixel.
mutate(GEN,
       "BEAD_REACH = 20.0 ",
       "BEAD_REACH = 4.0 ",
       "panel-material: the corner's light shrinks to a speck",
       expect="panel-material: the light pools along the cut corner", script=S)

# The corner as bright as the old bead: a white point, not light on the cut.
mutate(GEN,
       "BEAD_PEAK = 0.65 ",
       "BEAD_PEAK = 0.90 ",
       "panel-material: the corner's light flares white",
       expect="panel-material: the light pools along the cut corner", script=S)

# The cut's light left to run the whole depth of its face, past its crest:
# the corner's catch draws its spoke of light in from the corner again, the
# old tick, and fills the gap before the refraction line.
mutate(GEN,
       "    across = sstep(0, 1.5, inward) * (1 - sstep(CHAMFER_W - 3, CHAMFER_W, inward))\n",
       "    across = sstep(0, 1.5, inward)\n",
       "panel-material: a spoke of light runs in from the corner",
       expect="panel-material: the light pools along the cut corner", script=S)

# The catch widened to reach further round the corner: along a straight edge
# the angle to the light never changes, so it lifts the whole edge instead.
mutate(GEN,
       "BEAD_SIGMA = 15.0 ",
       "BEAD_SIGMA = 40.0 ",
       "panel-material: the corner's catch widened lifts the whole edge",
       expect="panel-material: the light pools along the cut corner", script=S)

# --- the slab ------------------------------------------------------------------

# The refraction line drawn at nothing: the dark lacquer again, a cut edge and
# no thickness behind it.
mutate(GEN,
       "REFRACT_LIT = 0.70 ",
       "REFRACT_LIT = 0.0 ",
       "panel-material: the slab loses its refraction line",
       expect="panel-material: the slab's edge reads as thick glass", script=S)

# The line lit from the lower right: light along the bottom and right, shade
# along the top and left, against the one key light.
mutate(GEN,
       "    line = REFRACT_LIT * sstep(0, 1, facing_key) * band\n",
       "    line = REFRACT_LIT * sstep(0, 1, -facing_key) * band\n",
       "panel-material: the refraction line is lit from the lower right",
       expect="panel-material: the slab's edge reads as thick glass", script=S)

# No darker line along the bottom and right: the slab has no side in shade.
mutate(GEN,
       "REFRACT_SHADE = 0.45 ",
       "REFRACT_SHADE = 0.0 ",
       "panel-material: the slab has no darker line in shade",
       expect="panel-material: the slab's edge reads as thick glass", script=S)

# The edge's cool tint taken out: a white line, which reads as lacquer's
# highlight rather than the edge of glass.
mutate(GEN,
       "EDGE_TINT = (0.86, 1.00, 0.96)",
       "EDGE_TINT = (1.00, 1.00, 1.00)",
       "panel-material: the refraction line loses the glass's tint",
       expect="panel-material: the slab's edge reads as thick glass", script=S)

# The tint pushed back to the first slab's: at 6x it read mint beside the
# gold bezel, not cool white glass.
mutate(GEN,
       "EDGE_TINT = (0.86, 1.00, 0.96)",
       "EDGE_TINT = (0.80, 1.00, 0.94)",
       "panel-material: the refraction line turns mint",
       expect="panel-material: the slab's edge reads as thick glass", script=S)

# The glow under the top line let run two texels further down, toward the
# words: past 6 units in.
mutate(GEN,
       "GLOW_TO = 24.0 ",
       "GLOW_TO = 26.0 ",
       "panel-material: the glow under the top line reaches toward the words",
       expect="panel-material: the slab's edge reads as thick glass", script=S)

# The glow made stronger to show more: it reads as a second band under the
# line, and runs toward the name.
mutate(GEN,
       "GLOW_PEAK = 0.16\n",
       "GLOW_PEAK = 0.24\n",
       "panel-material: the glow under the top line brightens to a band",
       expect="panel-material: the slab's edge reads as thick glass", script=S)

# The line moved back a quarter unit toward the cut: the gap closes to three
# quarters of a unit, under a pixel at small scales, and the two merge.
mutate(GEN,
       "REFRACT_AT = 12.0 ",
       "REFRACT_AT = 11.0 ",
       "panel-material: the gap between the cut and the line closes",
       expect="panel-material: the slab's edge reads as thick glass", script=S)

# The line drawn a unit and a half wide: a band, not the slab's edge.
mutate(GEN,
       "REFRACT_W = 4.0 ",
       "REFRACT_W = 6.0 ",
       "panel-material: the refraction line widens to a band",
       expect="panel-material: the slab's edge reads as thick glass", script=S)

# The line drawn brighter: it glares next to the bezel.
mutate(GEN,
       "REFRACT_LIT = 0.70 ",
       "REFRACT_LIT = 0.90 ",
       "panel-material: the refraction line glares",
       expect="panel-material: the slab's edge reads as thick glass", script=S)

# The fill light back at the first slab's: the bottom and right nearly vanish
# at scale 0.7 and in a landing.
mutate(GEN,
       "EDGE_FILL = 0.24 ",
       "EDGE_FILL = 0.18 ",
       "panel-material: the fill light along the bottom and right dims",
       expect="panel-material: the slab's edge reads as thick glass", script=S)

# The fill light pushed past the lit side's: the shade side outshines the
# side that faces the key light.
mutate(GEN,
       "EDGE_FILL = 0.24 ",
       "EDGE_FILL = 0.32 ",
       "panel-material: the fill light outshines the lit side",
       expect="panel-material: the slab's edge reads as thick glass", script=S)

# The cut widened back to the old four units: it runs over the gap and the
# line, one grey band again.
mutate(GEN,
       "CHAMFER_W = 6.0 ",
       "CHAMFER_W = 16.0 ",
       "panel-material: the cut widens over the slab's gap",
       expect="panel-material: the slab's edge reads as thick glass", script=S)

# --- the slab on the player's panel --------------------------------------------

# The light's opacity eased toward full under a see-through panel: still
# fainter as the panel fades, but not the player's opacity.
mutate(PANEL,
       "\t\t\tt:SetVertexColor(1, 1, 1, LIGHT_ALPHA * ba)\n",
       "\t\t\tt:SetVertexColor(1, 1, 1, LIGHT_ALPHA * math.sqrt(ba))\n",
       "panel-material: the slab's light eases off the player's opacity",
       expect="panel-material: the slab's light keeps the player's colour and opacity", script=S)

# The light tinted with the panel colour: gone on the near-black panel, a
# coloured edge on the others, and the file's own tint and shade lost.
mutate(PANEL,
       "\t\t\tt:SetVertexColor(1, 1, 1, LIGHT_ALPHA * ba)\n",
       "\t\t\tt:SetVertexColor(br, bg, bb, LIGHT_ALPHA * ba)\n",
       "panel-material: the slab's light takes the panel's colour",
       expect="panel-material: the slab's light keeps the player's colour and opacity", script=S)

# The light laid on the rim's corners: its margins drawn 4 units, so the
# line sits a unit and a half in, off the pane's edge.
mutate(PANEL,
       "\t\tPlaceSlice(R.glassLight, R.art, corner)\n",
       "\t\tPlaceSlice(R.glassLight, R.art, rimCorner)\n",
       "panel-material: the slab's light is laid on the rim's corners",
       expect="panel-material: the slab's light keeps the player's colour and opacity", script=S)

# The pane's top lifted past the player's colour, to make the glass glow.
mutate(PANEL,
       "\t\t\tlocal k0, k1 = 0.62 + 0.38 * f0, 0.62 + 0.38 * f1\n",
       "\t\t\tlocal k0, k1 = 0.62 + 0.38 * f0, 0.62 + 0.48 * f1\n",
       "panel-material: the pane's top lifts past the player's colour",
       expect="panel-material: the slab's light keeps the player's colour and opacity", script=S)

# The pane's noise seeded from nowhere: a different file every run.
mutate(GEN,
       "PANE_SEED = 11\n",
       "PANE_SEED = int.from_bytes(os.urandom(4), \"little\")\n",
       "panel-material: the generator is seeded from the air",
       expect="panel-material: the generator draws the same bytes twice", script=S)
