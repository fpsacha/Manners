# Mutations for tools/materials.py, the lit-material pipeline, and
# tests/materials_check.lua, the reader the looks hold their art with:
# tests/scenarios/materials.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts back a mistake
# the pipeline could plausibly make -- the ones that made 1.5.1's gold glare
# and the judges strike sub-unit detail -- and names the check that has to
# object.

MATERIALS = "tools/materials.py"
CHECK = "tests/materials_check.lua"

# The gold run up to near white, and the cap lifted to let it through: what
# 1.5.1 shipped. The swatch is then drawn over 0.60 and the scenario's own
# table of caps, not the generator's, says so.
mutate(MATERIALS,
       "(0.8, (0.60, 0.46, 0.23)), (1.0, (0.70, 0.56, 0.30))],\n"
       "        cap=0.60,",
       "(0.8, (0.86, 0.72, 0.42)), (1.0, (1.00, 0.90, 0.60))],\n"
       "        cap=0.95,",
       "the gold ramp run up to near white and its cap lifted",
       expect="every swatch is under its cap",
       script="runscenarios.py")

# The hammer marks from an unseeded generator: a different file every run.
mutate(MATERIALS,
       "    rng = np.random.default_rng(seed)\n"
       "    spacing = cell_units * tpu * SS",
       "    rng = np.random.default_rng()\n"
       "    spacing = cell_units * tpu * SS",
       "the planish drawn from an unseeded generator",
       expect="the same bytes twice",
       script="runscenarios.py")

# The dish's tilt read from the cell's unwrapped centre again: a texel whose
# nearest cell lies across the tile's edge takes a tilt of the tile's whole
# width, a cliff at every seam of a tiled plate and along a frame's file edge.
mutate(MATERIALS,
       "    along = ((xs - bcx) * np.cos(ca) + (ys - bcy) * np.sin(ca)) / radius\n",
       "    along = ((xs - cx[bj, bi]) * np.cos(ca) + (ys - cy[bj, bi]) * np.sin(ca)) / radius\n",
       "the planish's tilt read from the cell's unwrapped centre",
       expect="the hammer marks wrap round the tile",
       script="runscenarios.py")

# The feature floor lowered and the gold hammered at one unit: the detail the
# judges struck as a smudge at the game's scale.
mutate(MATERIALS,
       "MIN_FEATURE_UNITS = 2.0\n"
       "# The self-test's planished gold: its hammer cells, in units (--selftest).\n"
       "SWATCH_CELL = 3.0",
       "MIN_FEATURE_UNITS = 0.5\n"
       "# The self-test's planished gold: its hammer cells, in units (--selftest).\n"
       "SWATCH_CELL = 1.0",
       "the feature floor lowered and the gold hammered at one unit",
       expect="no feature under two units",
       script="runscenarios.py")

# The reader counting no texel as opaque: every cap passes with a max of 0.
mutate(CHECK,
       "MC.OPAQUE = 0.5\n",
       "MC.OPAQUE = 2.0\n",
       "the cap check counting no texel as opaque",
       expect="the check helper reads a cap",
       script="runscenarios.py")
