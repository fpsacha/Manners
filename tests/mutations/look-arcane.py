# Mutations for the Arcane look: tests/scenarios/look-arcane.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts back a mistake
# Looks/Arcane.lua could plausibly make, and names the check that objects.

A = "Looks/Arcane.lua"
S = "runscenarios.py"

# --- the look itself ------------------------------------------------------

mutate(A, "\torder = 3,\n", "\torder = 3,\n\tfallback = \"luxe\",\n",
       "Arcane left drawing as Luxe",
       expect="Arcane still draws as another look", script=S)

# --- the reason -----------------------------------------------------------

mutate(A, "\tSliceColor(self.rim, r, g, b, rimA)\n", "\tSliceColor(self.rim, 0.72, 0.74, 0.82, rimA)\n",
       "Arcane's rim never coloured",
       expect="the rim is not in", script=S)

mutate(A, "\tself.ring:SetVertexColor(lr, lg, lb, 1)\n", "\tself.ring:SetVertexColor(r, g, b, 1)\n",
       "Arcane's ring coloured on the stripe setting",
       expect="the ring round the icon is still coloured", script=S)

mutate(A, "\tself.runes:SetVertexColor(lr, lg, lb, math.min(1, rest[2] / RUNE_ALPHA))\n",
       "\tself.runes:SetVertexColor(1, 1, 1, math.min(1, rest[2] / RUNE_ALPHA))\n",
       "Arcane's runes never coloured",
       expect="the runes are not in", script=S)

mutate(A, "\tif off then r, g, b = NEUTRAL[1], NEUTRAL[2], NEUTRAL[3] end\n", "",
       "Arcane ignores the marker switched off",
       expect="with the marker off", script=S)

mutate(A, "REST[reason] or REST.nearby, off)", "REST.owed, off)",
       "Arcane glows the same for every reason",
       expect="does not glow more than a passer-by", script=S)

# --- motion ---------------------------------------------------------------

mutate(A, "\tif self.kit.FullEffects() and not self.combat and self.showIcon then\n",
       "\tif not self.combat and self.showIcon then\n",
       "Arcane's runes turn on Calm",
       expect="the rune circle turns on Calm", script=S)

mutate(A, "\tif self.kit.FullEffects() and not self.combat and self.showIcon then\n",
       "\tif self.kit.FullEffects() and self.showIcon then\n",
       "Arcane's runes turn in a fight",
       expect="keeps turning in a fight", script=S)

mutate(A, "\tself.pulseAnim:Stop()\n\tif self.kit.FullEffects() then\n\t\tself.pulseAnim:Play()\n",
       "\tself.pulseAnim:Stop()\n\tif true then\n\t\tself.pulseAnim:Play()\n",
       "Arcane breathes on Calm",
       expect="loop on Calm", script=S)

mutate(A, "\t\tif self.breathe then self:Breathe() end\n", "",
       "Arcane's breath never follows the flare",
       expect="does not breathe after the flare", script=S)

mutate(A, "\tself.breathe = nil\n\tself.pulseAnim:Stop()\n\tif not self.flareAnim:IsPlaying() then "
       "self.liftFrame:SetAlpha(0) end\n\t-- In a fight",
       "\tself.breathe = nil\n\tif not self.flareAnim:IsPlaying() then "
       "self.liftFrame:SetAlpha(0) end\n\t-- In a fight",
       "Arcane's breath outlives the favour",
       expect="the owed breath kept going", script=S)

mutate(A, "\tanim.to = on and 1 or 0\n", "\tanim.to = 0\n",
       "Arcane's glass never lit under the cursor",
       expect="did not light the glass", script=S)

# --- the fight ------------------------------------------------------------

mutate(A, "\tcombatArtAlpha = 1,\n", "\tcombatArtAlpha = 0.55,\n",
       "Arcane dimmed whole in a fight",
       expect="art dimmed whole in a fight", script=S)

mutate(A, "\tself.kit.icon:SetDesaturated(on)\n\tself:Spin()\n", "\tself:Spin()\n",
       "Arcane's icon keeps its colour in a fight",
       expect="the icon keeps its colour", script=S)

mutate(A, "\tSliceAlpha(self.bloom, fight and 0 or 1)\n", "\tSliceAlpha(self.bloom, 1)\n",
       "Arcane's bloom glows in a fight",
       expect="the bloom still glows in a fight", script=S)

# --- the favour's clock -----------------------------------------------------

mutate("Prompt.lua",
       "\tif activeLook and activeLook.Painted then activeLook:Painted(entry) end\n", "",
       "the look never told a person was painted",
       expect="no clock along the bottom", script=S)

mutate(A, "\t\tself.drain:SetWidth(width)\n", "",
       "Arcane's clock never drains",
       expect="halfway through the favour", script=S)

mutate(A, "\tif self.combat then self:SetDrain(nil) end\n", "",
       "Arcane's clock outlives a favour in a fight",
       expect="ran out in a fight", script=S)

mutate(A, "\tself:ShowKey()\n\tself:SetDrain(self.drainLeft)\nend\n", "\tself:ShowKey()\nend\n",
       "Arcane's clock gone after an outcome",
       expect="the clock did not come back", script=S)

mutate(A, "\t\t\tleft = 0.62\n", "\t\t\tleft = nil\n",
       "Arcane's preview has no clock",
       expect="the preview has no part-run clock", script=S)

# --- the key --------------------------------------------------------------

mutate(A, "\t\tparts[i] = KEY_WORDS[part] or part:gsub(\"^NUMPAD\", \"N\")\n", "",
       "Arcane's keycap spells the key out",
       expect="does not say S-F", script=S)

mutate(A, "\tself:ReadKey()\n\tlocal left\n", "\tlocal left\n",
       "Arcane's keycap never sees a rebinding",
       expect="a rebinding is not on the keycap", script=S)

mutate(A, "\tif yield ~= (self.keyYield or false) then\n", "\tif false then\n",
       "Arcane's keycap cuts the name",
       expect="cut a name that could not shrink", script=S)

mutate(A, "\tlocal on = self:KeyShown() and not self.outcome\n", "\tlocal on = self:KeyShown()\n",
       "Arcane's keycap over an outcome",
       expect="the keycap stayed up over an outcome", script=S)

mutate(A, "\tlocal inset = right + (self:KeyShown() and self.keyRoom or 0)\n", "\tlocal inset = right\n",
       "Arcane's lines run under the keycap",
       expect="the name runs under the keycap", script=S)

# --- outcomes -------------------------------------------------------------

mutate(A, "\t\tword = Known(\"buffed\") and L[\"buffed\"]\n", "\t\tword = nil\n",
       "Arcane rewrites the name for a landed buff",
       expect="a landed buff moved the name", script=S)

mutate(A, "\treturn locale == \"enUS\" or locale == \"enGB\" or rawget(L, english) ~= nil\n",
       "\treturn true\n",
       "Arcane's verdict in English on a German client",
       expect="German client's line reads the English", script=S)

mutate(A, "\t\tself:Tint(o[1], o[2], o[3], o, REST.owed)\n", "",
       "Arcane's rim not red for a refusal",
       expect="did not turn the rim red", script=S)

mutate(A, "\tkit.icon:SetDesaturated(kind == \"failed\" or self.combat or false)\n",
       "\tkit.icon:SetDesaturated(self.combat or false)\n",
       "Arcane's icon not grey for a refusal",
       expect="a refusal did not grey the icon", script=S)

mutate(A, "\tself.check:SetShown(kind == \"cast\" and self.showIcon)\n",
       "\tself.check:SetShown(self.showIcon)\n",
       "Arcane ticks a refusal",
       expect="a refusal kept the landed buff's tick", script=S)

mutate(A, "\tif kind ~= \"cast\" then return end\n", "",
       "Arcane flourishes an unconfirmed cast",
       expect="got Arcane's flourish", script=S)

# --- settings -------------------------------------------------------------

mutate(A, "\t\t\tkit.count:SetText(\"+\" .. text)\n", "",
       "Arcane's count without its plus",
       expect="no \"+N\" on the lens", script=S)

mutate(A, "\t\tSliceShown(self.trayGlass, list)\n", "\t\tSliceShown(self.trayGlass, false)\n",
       "Arcane's list without its glass",
       expect="the list below the panel is not hung", script=S)

mutate(A, "\t\t\ty, edge = 5 + (shown - i) * pitch + pitch / 2, \"TOPLEFT\"\n",
       "\t\t\ty, edge = -(5 + (i - 1) * pitch + pitch / 2), \"BOTTOMLEFT\"\n",
       "Arcane's list never hangs above",
       expect="not hung over it", script=S)

mutate(A, "\tlocal maskFile = ART .. (round and \"CircleMask\" or \"SquircleMask\")\n",
       "\tlocal maskFile = ART .. \"SquircleMask\"\n",
       "Arcane's round icon kept square",
       expect="the round icon kept the square mask", script=S)

mutate(A, "\tfor _, t in ipairs({ self.well, self.runes, self.shade, self.gloss, self.ring }) do\n"
       "\t\tt:SetShown(showIcon)\n",
       "\tfor _, t in ipairs({ self.well, self.runes, self.shade, self.gloss, self.ring }) do\n"
       "\t\tt:SetShown(true)\n",
       "Arcane's lens up with the icon off",
       expect="lens and runes are still up", script=S)

# --- leaving --------------------------------------------------------------

mutate(A, "\t\ticon:RemoveMaskTexture(self.mask)\n", "",
       "Arcane's mask left on the icon",
       expect="Arcane's mask still shapes the icon", script=S)

mutate(A, "\t\tif cooldown.SetUseCircularEdge then cooldown:SetUseCircularEdge(false) end\n", "",
       "Arcane's round sweep left on the cooldown",
       expect="kept Arcane's round edge", script=S)

mutate(A, "\tfor _, anim in ipairs({ self.flareAnim, self.pulseAnim, self.spinAnim, self.runeFlareAnim,\n",
       "\tfor _, anim in ipairs({ self.flareAnim, self.pulseAnim, self.runeFlareAnim,\n",
       "Arcane's runes left turning",
       expect="still turns after switching", script=S)

mutate(A, "\tkit.textLayer:SetFrameLevel(kit.art:GetFrameLevel() + 1)\n", "",
       "textLayer left at Arcane's level",
       expect="textLayer kept Arcane's frame level", script=S)
