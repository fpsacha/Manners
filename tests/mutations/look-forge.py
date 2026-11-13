# Mutations for the Forge look: tests/scenarios/look-forge.lua, with the
# shared checks in hunt35-effects.lua and hunt37-effects.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts back a mistake the
# forge could plausibly make -- the ones the judges warned about first -- and
# names the check that has to object.

FORGE = "Looks/Forge.lua"
GEN = "tools/make_forge_textures.py"
S = "runscenarios.py"


def _m(file, old, new, label, **kw):
    """Every label starts with the topic, so --only look-forge finds them all."""
    kw.setdefault("script", S)
    mutate(file, old, new, "look-forge: " + label, **kw)


# --- the reason ------------------------------------------------------------

# The slot quenched by a refusal and never given its colour back.
_m(FORGE,
   "\tself.refused = nil\n\tif mode == \"off\" then\n",
   "\tif mode == \"off\" then\n",
   "the refusal's steel never cleared by PaintReason",
   expect="the slot stayed steel after the refusal ran out")

_m(FORGE,
   "\t\tself.slot:SetVertexColor(hr, hg, hb, SLOT_ALPHA)\n",
   "\t\tself.slot:SetVertexColor(1, 1, 1, SLOT_ALPHA)\n",
   "the slot left uncoloured",
   expect="the slot is not in the reason's heated colour")

_m(FORGE,
   "\tif mode == \"off\" then\n\t\tself:Tint(NEUTRAL[1], NEUTRAL[2], NEUTRAL[3])\n",
   "\tif false then\n\t\tself:Tint(NEUTRAL[1], NEUTRAL[2], NEUTRAL[3])\n",
   "the marker switched off and the slot still coloured",
   expect="with the marker off the slot is not neutral")

# The look's own figures and the generator's parting company.
_m(FORGE,
   "local ICON_FRAME = 0.75\n",
   "local ICON_FRAME = 0.70\n",
   "ICON_FRAME changed in the Lua only",
   expect="ICON_FRAME is 0.70 in the Lua")

# A round icon whose sweep keeps the square texture.
_m(FORGE,
   "cooldown:SetSwipeTexture(round and maskFile or WHITE)",
   "cooldown:SetSwipeTexture(WHITE)",
   "the round icon's sweep keeps a square swipe",
   expect="the round icon's sweep is")

# --- motion ----------------------------------------------------------------

# The sparks let fly whatever the lines leave them: the gate replaced by true.
_m(FORGE,
   "\tlocal sparksOK = H >= 32 and (lowest - 2) >= strapTop + SPARK_CEIL\n",
   "\tlocal sparksOK = true\n",
   "the sparks' computed gate replaced by true",
   expect="look-forge: sparks stay on the strap")

# A spark that climbs past the strap's lane.
_m(FORGE,
   "\tlocal dys = { -1, 0, 1, 0, 1, -1 }\n",
   "\tlocal dys = { -1, 0, 3, 0, 1, -1 }\n",
   "a spark climbing past the strap",
   expect="look-forge: sparks stay on the strap")

# A slower breath: 4 s round, past the 2-3 s every look keeps.
_m(FORGE,
   "local BREATHS, BREATH = 3, 1.25\n",
   "local BREATHS, BREATH = 3, 2.0\n",
   "the breath slowed to 4 s round",
   expect="s round, not 2 to 3")

# The loop that runs for as long as somebody waits.
_m(FORGE,
   "\t\t\tif Forge.pulse[1]:IsPlaying() then Forge:HoldPulse(true) end\n",
   "",
   "the owed breath never stops",
   expect="still loops after its three breaths")

_m(FORGE,
   "\t\t\tForge.pulseSpent = true\n",
   "",
   "the spent breath started again by the scan",
   expect="the scan started the spent breath again")

_m(FORGE,
   "\tif not full then\n\t\t-- Calm: one fade up to the held glow, and nothing loops.\n",
   "\tif false then\n\t\t-- Calm: one fade up to the held glow, and nothing loops.\n",
   "the owed breath loops on Calm",
   expect="loop on Calm")

# The heat shimmer parked lit: additive light at rest, as 1.5.1's glow was.
_m(FORGE,
   "\tself.heatAnim = anim(Flash(self.heat, 0.6, 0.08, 0.40))\n",
   "\tself.heatAnim = anim(Flash(self.heat, 0.6, 0.08, 0.40, 0.3))\n",
   "the heat shimmer left additive at 0.3 at rest",
   expect="additive light at rest")

# The slot's floor drawn in additive light.
_m(FORGE,
   "\tself.slot = tex(art, \"BORDER\", 3, \"Slot\")\n",
   "\tself.slot = tex(art, \"BORDER\", 3, \"Slot\", \"ADD\")\n",
   "the slot floor additive",
   expect="additive light at rest")

# The heat raised on every repaint of a favour.
_m(FORGE,
   "\t\tif full then PlayAll(self.arrive) end\n\tend\n",
   "\tend\n\tif full then PlayAll(self.arrive) end\n",
   "the heat rises on every repaint",
   expect="the heat rose again on a repaint of the same favour")

# A flourish is a claim.
_m(FORGE,
   "\tif kind ~= \"cast\" then return end\n",
   "",
   "a cast nobody confirmed flashes the bezel",
   expect="a cast nobody confirmed got the forge's flourish")

# The steam let swell past the panel's top at the shortest heights.
_m(FORGE,
   "\tlocal to = math.min(1.2, cap)\n",
   "\tlocal to = 1.2\n",
   "the steam's cap removed",
   expect="look-forge: steam stays inside the panel")

# A ring file described wrongly: the rings would spread past the room.
_m(FORGE,
   "\tkit.RingArt(ART .. \"Ring\", RING_PEAK, RING_EDGE)\n",
   "\tkit.RingArt(ART .. \"Ring\", RING_PEAK, RING_EDGE - 0.1)\n",
   "the ring's reach misdeclared by a tenth",
   expect="declared reach")

# --- the fight -------------------------------------------------------------

_m(FORGE,
   "\tif held then self:Combat(true) end\n",
   "",
   "a layout during the hold puts the shine back",
   expect="a restyle in a fight put the iron's shine back")

_m(FORGE,
   "\t\tt:SetDesaturated(on)\n",
   "\t\tt:SetDesaturated(false)\n",
   "the iron never dulls in a fight",
   expect="the straps did not dull in a fight")

_m(FORGE,
   "\tkit.textLayer:SetAlpha(on and TEXT_COMBAT or 1)\n",
   "\tkit.textLayer:SetAlpha(TEXT_COMBAT)\n",
   "the fight's dim left on after it",
   expect="the fight's dulling stayed on after it ended")

# --- the bezel -------------------------------------------------------------

# The bezel let grow past the plate at the biggest icons.
_m(FORGE,
   "\tlocal bz = math.min(iconSize / ICON_FRAME, H - 1)\n",
   "\tlocal bz = iconSize / ICON_FRAME\n",
   "the bezel's cap removed",
   expect="look-forge: the bezel fits and clears the slot")

# The bezel over the slot at a large icon.
_m(FORGE,
   "\tlocal iconX = math.max(ICON_X, SLOT_GAP + outset)\n",
   "\tlocal iconX = ICON_X\n",
   "the icon's x never pushed right of the slot",
   expect="over the slot")

# The bloom sized from the capped bezel and left uncapped itself: flush with
# the plate at icon 30, past its top and bottom at every icon over it.
_m(FORGE,
   "\tlocal bloom = math.min(bz * GLOW_SCALE, H - 2 * kit.EDGE_MARGIN)\n",
   "\tlocal bloom = bz * GLOW_SCALE\n",
   "the bezel's bloom left uncapped",
   expect="look-forge: the bezel's bloom is held inside the plate")

# The flash kept on the capped bloom at every size: at icon 36 in 44 and at
# the extreme size its bright band lies under the icon, and the white-hot
# landing fades to a fringe.
_m(FORGE,
   "\tlocal hotOnRim = 0.88 * bloom / 2 < iconSize / 2 + 2\n",
   "\tlocal hotOnRim = false\n",
   "the flash left on the bloom when its band sinks under the icon",
   expect="look-forge: the bezel's bloom is held inside the plate")

# The hot rim drawn as a solid tile three texels past the bezel's edge: the
# additive flash lights the plate round the bezel and the hole under the icon.
_m(GEN,
   "    alpha = cover(d_outer) * cover(-t) * heat\n",
   "    alpha = cover(d_outer - 3.0) * heat\n",
   "the hot rim spills off the iron",
   expect="look-forge: the hot rim lies on the iron")

# --- leaving ---------------------------------------------------------------

_m(FORGE,
   "\tfor _, x in ipairs(self.own) do x:Hide() end\n\tself.pulseGen = (self.pulseGen or 0) + 1\n",
   "\tself.pulseGen = (self.pulseGen or 0) + 1\n",
   "the forge left on screen under another look",
   expect="a forge region is still showing on glass")

_m(FORGE,
   "\tif self.masked then\n\t\ticon:RemoveMaskTexture(self.mask)\n\t\tself.masked = nil\n\tend\n\tself.mask:Hide()\n\ticon:SetAlpha(1)\n",
   "\tself.mask:Hide()\n\ticon:SetAlpha(1)\n",
   "the forge's mask left on the icon",
   expect="Forge's mask still shapes the icon")

# The bezel's breath back in warm white: on the rounded square it lays a pale
# film over the bolts and the dark seam at every pulse, and Calm holds it.
_m(FORGE,
   "\t\tself.bezelWarm:SetVertexColor(hr, hg, hb, 1)\n",
   "\t\tself.bezelWarm:SetVertexColor(kit.WARM_WHITE[1], kit.WARM_WHITE[2], kit.WARM_WHITE[3], 1)\n",
   "the bezel's breath whitened",
   expect="look-forge: the bezel breathes in the slot's heat")

# The breath back to the disc's peak and held glow over the square's larger
# cover of iron.
_m(FORGE,
   "local WARM_REST, WARM_PEAK, WARM_HELD = 0.04, 0.12, 0.07\n",
   "local WARM_REST, WARM_PEAK, WARM_HELD = 0.04, 0.18, 0.07\n",
   "the bezel's breath peaks at 0.18",
   expect="look-forge: the bezel breathes in the slot's heat")

_m(FORGE,
   "local WARM_REST, WARM_PEAK, WARM_HELD = 0.04, 0.12, 0.07\n",
   "local WARM_REST, WARM_PEAK, WARM_HELD = 0.04, 0.12, 0.10\n",
   "the bezel held at 0.10 after its breaths",
   expect="look-forge: the bezel breathes in the slot's heat")

# --- the art ---------------------------------------------------------------

# The generator's rng unseeded: two runs draw different bytes.
_m(GEN,
   "    rng = np.random.default_rng(SEED_RING)\n",
   "    rng = np.random.default_rng()\n",
   "the ring's jitter unseeded",
   expect="differs between two runs")

# The plate hammered as hard under the words as by the straps: the ground
# fights the lines at the default size.
_m(GEN,
   "PLATE_CALM, CALM_FROM, CALM_TO = 0.7, 14.0, 38.0\n",
   "PLATE_CALM, CALM_FROM, CALM_TO = 0.0, 14.0, 38.0\n",
   "the plate left as busy under the words as on its rails",
   expect="look-forge: the plate is calm under the words")

# The sparks lit as bright as when they were sub-unit dots: six heads of 1.7
# units in one burst add up to one white bar.
_m(FORGE,
   "\t\tAlpha(g, 0.75, 0, seconds, 1, 0.035 * k, \"IN\")\n",
   "\t\tAlpha(g, 0.9, 0, seconds, 1, 0.035 * k, \"IN\")\n",
   "the sparks lit to 0.9 with their bigger heads",
   expect="glare as one bar")

# The sparks born two units apart again: six 1.7-unit heads touching, one
# white blob as the landing starts.
_m(FORGE,
   "\t\tlocal x = (showIcon and bezelRight or TEXT_X_BARE) - 2 + 3 * k\n",
   "\t\tlocal x = (showIcon and bezelRight or TEXT_X_BARE) - 2 + 2 * k\n",
   "the sparks born two units apart",
   expect="look-forge: the sparks set off one after another")

# The sparks leaving 0.02 s apart again: all six off in the first tenth of a
# second, born as one.
_m(FORGE,
   "\t\tif move.SetStartDelay then move:SetStartDelay(0.035 * k) end\n",
   "\t\tif move.SetStartDelay then move:SetStartDelay(0.02 * k) end\n",
   "the sparks leaving 0.02 s apart",
   expect="look-forge: the sparks set off one after another")

# Each spark lit from the landing's first frame while it waits its turn: six
# lit heads sit where they were born.
_m(FORGE,
   "\t\tAlpha(g, 0.75, 0, seconds, 1, 0.035 * k, \"IN\")\n",
   "\t\tAlpha(g, 0.75, 0, seconds, 1, 0, \"IN\")\n",
   "the sparks lit before they leave",
   expect="look-forge: the sparks set off one after another")

# Each spark thrown further than the last again: the late ones catch the
# early ones up and the six meet in one bright knot 0.15 to 0.25 s in.
_m(FORGE,
   "\t\tlocal run = math.min(46 - 5 * k, W - 2 - x - 1.5)\n",
   "\t\tlocal run = math.min(22 + 3 * k, W - 2 - x - 1.5)\n",
   "each spark thrown further than the last",
   expect="the burst knots up")

# Every spark landing on the same point: born three units apart, each flying
# three units shorter than the last, the six close on one place and the spray
# dies in a dim knot.
_m(FORGE,
   "\t\tlocal run = math.min(46 - 5 * k, W - 2 - x - 1.5)\n",
   "\t\tlocal run = math.min(38 - 3 * k, W - 2 - x - 1.5)\n",
   "the sparks all land on one point",
   expect="land on one place")

# The sparks' flights stretched so the last is still out past the landing's
# 0.7 s.
_m(FORGE,
   "\t\tlocal seconds = 0.30 + 0.016 * k\n",
   "\t\tlocal seconds = 0.30 + 0.09 * k\n",
   "the last spark out past the landing",
   expect="past the landing's 0.7")

# The square bezel's bloom back to a disc: its edge cuts across the corner
# bolts as the landing flashes, and they stay dark outside it.
_m(GEN,
   "        sd = rrect(x, y, c - outer, c - outer, c + outer, c + outer, GLOW_CORNER)\n",
   "        sd = disc(x, y, c, c, outer)\n",
   "the square bezel's bloom drawn as a disc",
   expect="look-forge: the bloom follows the bezel's shape")

# The round bezel given the square bezel's bloom: corners of light off a
# round bezel.
_m(FORGE,
   "\tlocal glowFile = round and \"BezelGlowRd\" or \"BezelGlow\"\n",
   "\tlocal glowFile = \"BezelGlow\"\n",
   "the round bezel wears the square bloom",
   expect="look-forge: the bezel's bloom is held inside the plate")

# The warm breath left on the file Build gave it, whatever the bezel's shape.
_m(FORGE,
   "\tself.bezelWarm:SetTexture(ART .. glowFile)\n",
   "",
   "the warm bloom never follows the bezel's shape",
   expect="look-forge: the bezel's bloom is held inside the plate")

# The spark back to a sub-unit dot with a hairline tail: under a pixel at the
# game's scale, and the landing's sparks go unseen.
_m(GEN,
   "SPARK_HEAD, SPARK_HEAD_X, SPARK_TAIL = 9.0, 10.5, 2.4\n",
   "SPARK_HEAD, SPARK_HEAD_X, SPARK_TAIL = 4.0, 11.0, 1.2\n",
   "the spark drawn as a sub-unit dot",
   expect="look-forge: a spark fills its frame")

# A misnamed file: a solid box in the game, and nothing throws.
_m(FORGE,
   "\tself.slot = tex(art, \"BORDER\", 3, \"Slot\")\n",
   "\tself.slot = tex(art, \"BORDER\", 3, \"Slott\")\n",
   "a misnamed Forge texture",
   expect="which the generator does not write")

# ...and the same slip seen from the package's side: a file the look asks for
# that nothing ships.
_m(FORGE,
   "\tself.core = tex(art, \"BORDER\", 4, \"SlotCore\")\n",
   "\tself.core = tex(art, \"BORDER\", 4, \"SlotCor\")\n",
   "a Forge texture the package does not ship",
   expect="which the package does not ship")

# --- the forge alive at rest, and the fountain ---

mutate("Looks/Forge.lua",
       "\tlocal on = self.active and not self.combat and self.kit.FullEffects()\n\tself.seamGlow:SetAlpha(on and SEAM_GLOW or 0)\n",
       "\tlocal on = self.active and not self.combat\n\tself.seamGlow:SetAlpha(on and SEAM_GLOW or 0)\n",
       "look-forge: the forge burns on Calm",
       expect="on Calm, light", script=S)

mutate("Looks/Forge.lua",
       "\tlocal on = self.active and not self.combat and self.kit.FullEffects()\n\tself.seamGlow:SetAlpha(on and SEAM_GLOW or 0)\n",
       "\tlocal on = self.active and self.kit.FullEffects()\n\tself.seamGlow:SetAlpha(on and SEAM_GLOW or 0)\n",
       "look-forge: the forge burns in a fight",
       expect="in a fight, light", script=S)

mutate("Looks/Forge.lua",
       "\t\tlocal t = tex(self.idleFrame, \"OVERLAY\", 2, \"Ember\")\n",
       "\t\tlocal t = tex(self.idleFrame, \"OVERLAY\", 2, \"Ember\", \"ADD\")\n",
       "look-forge: the embers additive at rest",
       expect="a light of the forge at rest is additive", script=S)

mutate("Looks/Forge.lua",
       "\t\t-- And the fountain, up off the bezel.\n\t\tPlayAll(self.fountAnims)\n",
       "\t\t-- And the fountain, up off the bezel.\n",
       "look-forge: a landing without its fountain",
       expect="a landing threw no fountain of sparks", script=S)

mutate("Looks/Forge.lua",
       "\tlocal fountRise = above and math.max(2, cy - bz / 2 - 1) or FOUNT_RISE\n",
       "\tlocal fountRise = FOUNT_RISE\n",
       "look-forge: the fountain over the list hung above",
       expect="with the list above, spark", script=S)

mutate("Looks/Forge.lua",
       "\tif name == self.greeted then return end\n\tself.greeted = name\n\tif name and not (entry.reason == \"owed\") then self:Greet() end\nend\n\n-- The shadow under the plate, and under the list's plate when it is out.",
       "\tself.greeted = name\n\tif name and not (entry.reason == \"owed\") then self:Greet() end\nend\n\n-- The shadow under the plate, and under the list's plate when it is out.",
       "look-forge: the same face greeted at every scan",
       expect="a repaint of the same face greeted again", script=S)
