# Mutations for the shared light lit from the upper left and the motion's
# shapes (tests/scenarios/glow-light.lua, tools/make-glow.py).
#
# Run by tests/selftest.py with mutate() in scope. Each puts the generator
# back a step -- no light, light from the wrong corner, the old formula that
# dimmed the lit half's own axis texels, a rule that ends hard -- and names
# the check that has to object. The scenarios draw the files afresh, so the
# shipped bytes need not change for these to be caught.

GLOW = "tools/make-glow.py"
S = "runscenarios.py"

# No light at all: the halo is the same in every direction again.
mutate(GLOW,
       "    \"light_bias\": 0.25, \"light_dir\": (-0.42, -0.70),\n",
       "    \"light_bias\": 0.0, \"light_dir\": (-0.42, -0.70),\n",
       "glow-light: the light's bias is nothing",
       expect="glow-light: the halo is lit from the upper left", script=S)

# The light comes from the lower right.
mutate(GLOW,
       "    \"light_bias\": 0.25, \"light_dir\": (-0.42, -0.70),\n",
       "    \"light_bias\": 0.25, \"light_dir\": (0.42, 0.70),\n",
       "glow-light: the light comes from the lower right",
       expect="glow-light: the halo is lit from the upper left", script=S)

# The unnormalised factor: 1 - bias * (1 - lit) scales the top and left axis
# texels too, so the shape's own reach could shift by a boundary texel.
mutate(GLOW,
       "    factor = 1.0 - bias * np.clip(0.5 - lit, 0.0, 1.0) * 2.0\n",
       "    factor = 1.0 - bias * (1.0 - lit)\n",
       "glow-light: the lit half is dimmed by the old formula",
       expect="glow-light: the lit half is untouched", script=S)

# A rule that ends hard.
mutate(GLOW,
       "    \"rule_core\": 1.1, \"rule_end_fade\": 6,\n",
       "    \"rule_core\": 1.1, \"rule_end_fade\": 0,\n",
       "glow-light: the rule ends hard",
       expect="glow-light: a rule ends soft", script=S)
