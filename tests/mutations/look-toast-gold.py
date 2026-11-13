# Mutations for Toast's regild (tests/scenarios/look-toast-gold.lua,
# tools/make_toast_textures.py drawing through tools/materials.py, and the
# one line of Looks/Toast.lua that hangs the rope on the ring).
#
# Run by tests/selftest.py with mutate() in scope. Each puts back a mistake
# the regild could plausibly make -- the gold over its cap, the enamel's
# colour moved, a ring with no twist, hammer cells under the feature floor,
# the ring back in plain gold -- and names the check that has to object.
# The scenarios draw the files afresh, so the shipped bytes need not change
# for these to be caught.

GEN = "tools/make_toast_textures.py"
TOAST = "Looks/Toast.lua"
S = "runscenarios.py"

# The rails hammered at one unit: materials.planish raises under the
# two-unit feature floor, the generator dies, and hunt35's generator check
# finds nothing drawn.
mutate(GEN,
       'PLANISH_CELL = {"double": 3.0, "slim": 2.5}\n',
       'PLANISH_CELL = {"double": 1.0, "slim": 2.5}\n',
       "look-toast-gold: the rails hammered at one unit",
       expect="make_toast_textures.py is deterministic", script=S)

# The rope's gold let run over the cap, to 0.9: what 1.5.1's gold did.
mutate(GEN,
       "    rope = capped(gold + (rgb - gold) * inband[..., None])\n",
       "    rope = gold + (rgb - gold) * inband[..., None]\n"
       "    rope = rope * (0.9 / float(luma(rope).max()))\n",
       "look-toast-gold: the rope's gold over the cap",
       expect="look-toast-gold: gold stays under luma 0.60", script=S)

# The enamel's base moved: the reason colour on it is no longer what
# readable-toast.lua judged.
mutate(GEN,
       "    val = 0.84 + ENAMEL_LIT * lit + 0.02 * brush\n",
       "    val = 0.72 + ENAMEL_LIT * lit + 0.02 * brush\n",
       "look-toast-gold: the enamel's base moved",
       expect="look-toast-gold: the enamel keeps its colour", script=S)

# A ring with no strands: plain gold under a new name.
mutate(GEN,
       "ROPE_STRANDS, ROPE_HELIX, ROPE_RISE, ROPE_TPU = 24, 45.0, 0.6, 3.6\n",
       "ROPE_STRANDS, ROPE_HELIX, ROPE_RISE, ROPE_TPU = 0, 45.0, 0.6, 3.6\n",
       "look-toast-gold: the ring with no strands",
       expect="look-toast-gold: the ring is twisted", script=S)

# The ring hung back on the plain gold: the rope ships and nothing draws it.
mutate(TOAST,
       "\tself.ring = tex(art, \"ARTWORK\", -3, \"Rope\")\n",
       "\tself.ring = tex(art, \"ARTWORK\", -3, \"Gold\")\n",
       "look-toast-gold: the ring back in plain gold",
       expect="look-toast-gold: the ring wears the rope", script=S)
