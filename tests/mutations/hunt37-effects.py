# Mutations for hunt 37: the rings stay in their room, under the text
# (tests/scenarios/hunt37-effects.lua).
#
# Run by tests/selftest.py with mutate() in scope. Each undoes one half of the
# fix -- a cap that lets a ring spread as far as it was drawn to, a look that
# never asks for one, a text layer no higher than the light -- and names the
# check that has to object.

EFFECTS = "Prompt/Effects.lua"
PANEL = "Prompt/Panel.lua"
PROMPT = "Prompt/Prompt.lua"
S = "runscenarios.py"
ROOM = "hunt37-effects: the rings, the echo and the halo stay in their room, in "
BENEATH = "hunt37-effects: the light is drawn beneath the text, in "

# --- the built-in looks -----------------------------------------------------

# A landing's rings spread as far as they were drawn to, whatever the room.
mutate(EFFECTS,
       "\t\tlocal to = from + (math.min(RING_REACH[i], limit / full) - from) * RING_SHARE[i]\n",
       "\t\tlocal to = from + (RING_REACH[i] - from) * RING_SHARE[i]\n",
       "hunt37: a landing's rings spread past their room",
       expect=ROOM + "glass", script=S)

# The refusal's ring contracts from where it was drawn to, not from the room.
mutate(EFFECTS,
       "\t\t\tlocal out = math.max(from, math.min(RING_REACH[1], refuseLimit / full))\n",
       "\t\t\tlocal out = RING_REACH[1]\n",
       "hunt37: a refusal's ring contracts from past its room",
       expect=ROOM + "glass", script=S)

# The arrival's echo drops from 1.45 times, whatever the room.
mutate(EFFECTS,
       "\tRescale(echo.dropIn, math.min(ECHO_FROM, room))\n",
       "\tRescale(echo.dropIn, ECHO_FROM)\n",
       "hunt37: the arrival's echo drops from past its room",
       expect=ROOM + "glass", script=S)

# ...and settles out to 1.10 times.
mutate(EFFECTS,
       "\tRescale(echo.dropOut, nil, math.min(ECHO_SETTLE, room))\n",
       "\tRescale(echo.dropOut, nil, ECHO_SETTLE)\n",
       "hunt37: the arrival's echo settles out past its room",
       expect=ROOM + "glass", script=S)

# The halo that flares grows by a tenth, whatever the room.
mutate(EFFECTS,
       "\tif flare and flare.grow then lib.Rescale(flare.grow, math.min(1, cap), math.min(1.10, cap)) end\n",
       "\tif flare and flare.grow then lib.Rescale(flare.grow, 1, 1.10) end\n",
       "hunt37: the halo flares past its room",
       expect=ROOM + "glass", script=S)

# The arrival's bloom grows by a tenth, whatever the room.
mutate(EFFECTS,
       "\tif arrive and arrive.grow then lib.Rescale(arrive.grow, math.min(0.94, cap), math.min(1.10, cap)) end\n",
       "\tif arrive and arrive.grow then lib.Rescale(arrive.grow, 0.94, 1.10) end\n",
       "hunt37: the arrival's bloom grows past its room",
       expect=ROOM + "glass", script=S)

# The halo drawn four units deep, however little room there is.
mutate(PANEL,
       "\t\tPlaceHalo(R.burstHalo, R.burstFrame, deep, deep, outer, roundSize)\n",
       "\t\tPlaceHalo(R.burstHalo, R.burstFrame, 4, 4, outer, roundSize)\n",
       "hunt37: the halo is drawn deeper than the room",
       expect=ROOM + "glass", script=S)

# The rings' size taken from the icon alone, so the pad they sit at is not
# counted and every cap is too generous.
mutate(EFFECTS,
       "\t\tring.half = size / 2 + pad\n",
       "\t\tring.half = size / 2\n",
       "hunt37: the rings' size forgets their pad",
       expect=ROOM + "glass", script=S)

# A ring that begins where it was drawn to begin, past a small room.
mutate(EFFECTS,
       "\t\tlocal from = math.min(1, math.max(half * 0.6, half - RING_START_IN) / (art.peak * ring.half), limit / full)\n",
       "\t\tlocal from = 1\n",
       "hunt37: the rings begin past their room",
       expect=ROOM + "glass", script=S)

# The panel never asks for the cap.
mutate(PANEL,
       "\t\tR.fx:Fit(limitH, limitV, lib.SHAKE_LEFT)\n",
       "",
       "hunt37: the glass never holds its rings to the room",
       expect=ROOM + "glass", script=S)

# The room to the text counted from the icon's middle rather than its edge.
mutate(PANEL,
       "\t\tlocal limitH = half + math.min(ICON_GAP - lib.TEXT_MARGIN, ICON_X - lib.EDGE_MARGIN)\n",
       "\t\tlocal limitH = half + ICON_GAP + half\n",
       "hunt37: the glass counts its room to the text from the wrong place",
       expect=ROOM + "glass", script=S)

# The text no higher than the light: left to the order the frames were made in.
mutate(PANEL,
       "\tR.textLayer:SetFrameLevel(R.art:GetFrameLevel() + lib.TEXT_LEVEL)\n",
       "",
       "hunt37: the text is drawn at the light's level",
       expect=BENEATH + "glass", script=S)

# The level the text sits at shrunk to the light's.
mutate(PROMPT,
       "lib.TEXT_LEVEL = 6\n",
       "lib.TEXT_LEVEL = 1\n",
       "hunt37: the text level is the light's level",
       expect=BENEATH + "framed", script=S)

# The band across the panel raised over the text.
mutate(PANEL,
       "\tR.shineFrame = CreateFrame(\"Frame\", nil, R.art)\n",
       "\tR.shineFrame = CreateFrame(\"Frame\", nil, R.art)\n\tR.shineFrame:SetFrameLevel(R.art:GetFrameLevel() + lib.TEXT_LEVEL + 1)\n",
       "hunt37: the band across the panel is drawn over the text",
       expect=BENEATH + "minimal", script=S)

# --- the art ----------------------------------------------------------------

# The thin ring said to be seen less far out than its file shows it.
mutate(EFFECTS,
       "RingArt(RING, 0.773, 0.93)\n",
       "RingArt(RING, 0.773, 0.80)\n",
       "hunt37: the ring is said to reach less far than its art does",
       expect="hunt37-effects: each ring's declared reach is the reach of its art", script=S)

# --- the looks of their own --------------------------------------------------

mutate("Looks/Luxe.lua",
       "\t\tself.fx:Fit(limitH, limitV, kit.SHAKE_LEFT)\n",
       "",
       "hunt37: Luxe never holds its rings to the room",
       expect=ROOM + "luxe", script=S)

mutate("Looks/Luxe.lua",
       "\t\t\tkit.CapScale(math.min(limitH, limitV), half + ringPad, 0.96))\n",
       "\t\t\t9)\n",
       "hunt37: Luxe's lock-on ring closes from past the room",
       expect=ROOM + "luxe", script=S)

mutate("Looks/Luxe.lua",
       "\tself.pillFrame:SetFrameLevel(base + 5)\n",
       "\tself.pillFrame:SetFrameLevel(base + 5)\n\tself.sheenFrame:SetFrameLevel(base + 6)\n",
       "hunt37: Luxe's crossing light is drawn over the text",
       expect=BENEATH + "luxe", script=S)

mutate("Looks/Toast.lua",
       "\t\tself.fx:Fit(limitH, limitV, kit.SHAKE_LEFT)\n",
       "",
       "hunt37: Toast never holds its rings to the room",
       expect=ROOM + "toast", script=S)

mutate("Looks/Toast.lua",
       "\t\tkit.CapLock(self.gather, nil, 1.30, 1, kit.CapScale(math.min(limitH, limitV), 0.725 * M, 0.78))\n",
       "",
       "hunt37: Toast's arrival ring gathers from past the room",
       expect=ROOM + "toast", script=S)

mutate("Looks/Toast.lua",
       "\tfor _, f in ipairs(self.fx.frames) do f:SetFrameLevel(base + 2) end\n",
       "\tfor _, f in ipairs(self.fx.frames) do f:SetFrameLevel(base + 4) end\n",
       "hunt37: Toast's rings are drawn at the text's level",
       expect=BENEATH + "toast", script=S)

mutate("Looks/Arcane.lua",
       "\tself.fx:Fit(limitH, limitV, kit.SHAKE_LEFT)\n",
       "",
       "hunt37: Arcane never holds its rings to the room",
       expect=ROOM + "arcane", script=S)

mutate("Looks/Arcane.lua",
       "\t\tkit.CapScale(math.min(limitH, limitV), iconSize / ICON_FRAME / 2, 0.98))\n",
       "\t\t9)\n",
       "hunt37: Arcane's lock-on ring closes from past the room",
       expect=ROOM + "arcane", script=S)

mutate("Looks/Arcane.lua",
       "\truneRing.half = M / 2\n",
       "\truneRing.half = M / 4\n",
       "hunt37: Arcane's rune ring is sized as if it were a quarter as wide",
       expect=ROOM + "arcane", script=S)

mutate("Looks/Arcane.lua",
       "\tfor _, f in ipairs(self.fx.frames) do f:SetFrameLevel(base + 2) end\n",
       "\tfor _, f in ipairs(self.fx.frames) do f:SetFrameLevel(base + 4) end\n",
       "hunt37: Arcane's rings are drawn at the text's level",
       expect=BENEATH + "arcane", script=S)
