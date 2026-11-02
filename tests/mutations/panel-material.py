# Mutations for the built-in looks' material: the glass pane and its light,
# the icon's bezel and the framed look's rim (tests/scenarios/panel-material.lua).
#
# Run by tests/selftest.py with mutate() in scope. Each puts back a mistake the
# panel could plausibly make -- the ink judged on the bare panel colour, a bezel
# taller than its panel, a bezel under the hairline, a hover that lingers, the
# framed look refusing its stripe, a caustic that reaches the stretched edge
# strips, a generator that draws different bytes each run -- and names the
# check that has to object.

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

# --- the stripe --------------------------------------------------------------

# The framed look refusing its stripe again.
mutate(PANEL,
       "\tlocal showAccent = (mode == \"stripe\" or mode == \"both\")\n",
       "\tlocal showAccent = not framed and (mode == \"stripe\" or mode == \"both\")\n",
       "panel-material: the framed look refuses the stripe",
       expect="panel-material: framed carries the stripe", script=S)

# --- the art -----------------------------------------------------------------

# The caustic's first band drawn with its centre at texel 20, in the top edge
# strip: the fade keeps it out of the middle cell, where nothing is left.
mutate(GEN,
       "CAUSTIC_BANDS = ((0.30, 0.10, 0.10), (0.55, 0.06, 0.06))\n",
       "CAUSTIC_BANDS = ((-0.1875, 0.10, 0.10), (0.55, 0.06, 0.06))\n",
       "panel-material: the caustic leaves the middle cell",
       expect="panel-material: the caustic stays in the middle cell", script=S)

# The pane's noise seeded from nowhere: a different file every run.
mutate(GEN,
       "PANE_SEED = 11\n",
       "PANE_SEED = int.from_bytes(os.urandom(4), \"little\")\n",
       "panel-material: the generator is seeded from the air",
       expect="panel-material: the generator draws the same bytes twice", script=S)
