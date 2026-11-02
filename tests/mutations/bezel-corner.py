# Mutations for the built-in bezel's lip in the owed light:
# tests/scenarios/bezel-corner.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each one puts back a way the
# owed bezel's corners could go dark again, or light where they should not.

S = "runscenarios.py"
PANEL = "Prompt/Panel.lua"
PROMPT = "Prompt/Prompt.lua"

# The light not carried round the corner: the dark notch at each corner of an
# owed bezel, the lip turning its corner out of the halos' square gap.
mutate(PANEL,
       "\t\t\tand math.max(0, half + outer - lipCorner) or 0\n",
       "\t\t\tand 0 or 0\n",
       "bezel-corner: the halos' light stops at the gap's corner",
       expect="bezel-corner: an owed bezel is lit all the way round its lip", script=S)

# Carried in whatever the lip does: where the lip lies in the gap all round
# (the biggest icon at the default height, a 160 x 32 prompt), four bright dots.
mutate(PANEL,
       "\t\tlocal fill = half + outer < bezelSize * lib.BEZEL_LIP_SIDE\n",
       "\t\tlocal fill = half + outer < bezelSize\n",
       "bezel-corner: light carried into the corners of a lip that is out of the light",
       expect="bezel-corner: no light is carried in where the lip is out of the light", script=S)

# The corner's light never painted: white where the sides are the reason's
# colour or the warm white rim.
mutate(PROMPT,
       "\tfor _, t in ipairs(halo.fills) do t:SetVertexColor(r, g, b, alpha) end\n",
       "",
       "bezel-corner: the corner's light is not painted with the halo",
       expect="bezel-corner: the corner's light is the halo's own", script=S)

# The top-left corner's light cut from the dim side of the glow's middle (the
# lower right, which the key light leaves a quarter darker): a seam against
# the corner piece it meets.
mutate(PROMPT,
       "\t{ 0.5 - 1 / 128, 0.5, 0.5 - 1 / 128, 0.5 }, -- top-left\n",
       "\t{ 0.5, 0.5 + 1 / 128, 0.5, 0.5 + 1 / 128 }, -- top-left\n",
       "bezel-corner: a corner's light cut from the wrong side of the glow",
       expect="bezel-corner: the corner's light is the halo's own", script=S)

# The corner's light laid on the corner piece instead of in the gap's corner.
mutate(PROMPT,
       "\t\t\tt:SetPoint(at[1], box, at[2], at[3] * inset, at[4] * inset)\n",
       "\t\t\tt:SetPoint(at[1], box, at[2], at[3] * gap, at[4] * gap)\n",
       "bezel-corner: the corner's light placed outside the gap",
       expect="bezel-corner: an owed bezel is lit all the way round its lip", script=S)

# The lip's corner taken along a side rather than on the diagonal, so
# Prompt.lua's figure is no longer the generator's (and the light falls short).
mutate(PROMPT,
       "local BEZEL_LIP_CORNER, BEZEL_LIP_SIDE = (47 + 12 / math.sqrt(2)) / 128, 60.5 / 128\n",
       "local BEZEL_LIP_CORNER, BEZEL_LIP_SIDE = (47 + 12) / 128, 60.5 / 128\n",
       "bezel-corner: the lip's corner figure is not the generator's",
       expect="bezel-corner: the lip's figures agree with the generator", script=S)

# The generator's rim drawn a texel wider, Prompt.lua's figures left behind.
mutate("tools/make_panel_textures.py",
       "SEAM, RIM, LIP = 3.0, 8.0, 3.0\n",
       "SEAM, RIM, LIP = 3.0, 9.0, 3.0\n",
       "bezel-corner: the generator's bezel moves under Prompt.lua's figures",
       expect="bezel-corner: the lip's figures agree with the generator", script=S)
