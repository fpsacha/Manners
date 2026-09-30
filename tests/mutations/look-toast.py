# Mutations for the Toast look: tests/scenarios/look-toast.lua, and the
# switching checks in tests/scenarios/looks.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts back a mistake the
# toast could plausibly make -- most of them the ones the judges warned about
# -- and names the check that has to object.

TOAST = "Looks/Toast.lua"

# --- the reason ------------------------------------------------------------

mutate(TOAST,
       "\tself.band:SetVertexColor(er, eg, eb, 1)\n",
       "\tself.band:SetVertexColor(1, 1, 1, 1)\n",
       "the enamel left uncoloured",
       expect="the enamel is not in",
       script="runscenarios.py")

# Gold on gold: the palette's owed colour as it is, inside the gold ring.
mutate(TOAST,
       "\tlocal k = 1.35\n",
       "\tlocal k = 1.0\n",
       "the enamel no more saturated than the gold",
       expect="the owed enamel is no more saturated",
       script="runscenarios.py")

mutate(TOAST,
       "\tif mode == \"off\" then\n\t\t-- Neutral enamel",
       "\tif false then\n\t\t-- Neutral enamel",
       "the marker switched off and the enamel still coloured",
       expect="with the marker off the enamel",
       script="runscenarios.py")

mutate(TOAST,
       "\t\tsr = WARM_GREY[1] + (r - WARM_GREY[1]) * 0.6\n"
       "\t\tsg = WARM_GREY[2] + (g - WARM_GREY[2]) * 0.6\n"
       "\t\tsb = WARM_GREY[3] + (b - WARM_GREY[3]) * 0.6\n",
       "\t\tsr, sg, sb = WARM_GREY[1], WARM_GREY[2], WARM_GREY[3]\n",
       "the subtitle never warmed towards the reason",
       expect="the subtitle is the same colour whatever the reason",
       script="runscenarios.py")

# --- motion ----------------------------------------------------------------

# The design's own rule: the sparks on every new face on the panel.
mutate(TOAST,
       "\t-- A refusal greyed the icon; a fight keeps it grey.\n\tself.refused = nil\n",
       "\tif self.kit.FullEffects() then self:Sweep() end\n\tself.refused = nil\n",
       "the rails sparkle for every new face",
       expect="the rails sparkled for a new face",
       script="runscenarios.py")

mutate(TOAST,
       "\t\tif full then self:Sweep() end\n\tend\n",
       "\tend\n\tif full then self:Sweep() end\n",
       "the rails sparkle on every repaint of a favour",
       expect="the rails sparkled again for the same favour",
       script="runscenarios.py")

mutate(TOAST,
       "\t\tif full then self:Sweep() end\n",
       "\t\tself:Sweep()\n",
       "the rails sparkle on Calm",
       expect="the rails sparkled on Calm",
       script="runscenarios.py")

mutate(TOAST,
       "\tfor _, g in ipairs(self.pulse) do g:Play() end\n",
       "",
       "the owed pulse never breathes",
       expect="the toast does not breathe",
       script="runscenarios.py")

# The loop that runs for as long as somebody waits.
mutate(TOAST,
       "\t\t\tif Toast.pulse[1]:IsPlaying() then Toast:HoldPulse() end\n",
       "",
       "the owed pulse never stops",
       expect="still loops after its three breaths",
       script="runscenarios.py")

mutate(TOAST,
       "\t\t\tToast.pulseSpent = true\n",
       "",
       "the spent pulse started again by the scan",
       expect="the scan started the spent pulse again",
       script="runscenarios.py")

mutate(TOAST,
       "\tif not full or self.pulseSpent then\n",
       "\tif self.pulseSpent then\n",
       "the owed pulse loops on Calm",
       expect="loop on Calm",
       script="runscenarios.py")

mutate(TOAST,
       "\tfor _, g in ipairs(self.pulse) do g:Stop() end\n\tself.bloomPulse:SetAlpha(0)\n",
       "\tfor _, g in ipairs(self.pulse) do g:Stop() end\n",
       "the owed glow left up with nobody owed",
       expect="the owed glow stayed with nobody owed",
       script="runscenarios.py")

# A flourish is a claim.
mutate(TOAST,
       "\tif kind ~= \"cast\" then return end\n",
       "",
       "a cast nobody confirmed flares the gilding",
       expect="a cast nobody confirmed got the toast's flourish",
       script="runscenarios.py")

mutate(TOAST,
       "\tPlayAll(self.flareAnims)\n",
       "",
       "a landed buff without its flare",
       expect="did not flare the gilding",
       script="runscenarios.py")

# --- the fight -------------------------------------------------------------

mutate(TOAST,
       "\t\tt:SetDesaturated(on)\n",
       "\t\tt:SetDesaturated(false)\n",
       "the gold never turns to iron",
       expect="did not turn to iron",
       script="runscenarios.py")

mutate(TOAST,
       "\tkit.icon:SetDesaturated(on or self.refused or false)\n",
       "\tkit.icon:SetDesaturated(self.refused or false)\n",
       "the icon keeps its colour in a fight",
       expect="the icon keeps its colour in a fight",
       script="runscenarios.py")

mutate(TOAST,
       "local TEXT_COMBAT, ICON_COMBAT = 0.78, 0.70\n",
       "local TEXT_COMBAT, ICON_COMBAT = 1, 0.70\n",
       "the text undimmed in a fight",
       expect="the text does not dim in a fight",
       script="runscenarios.py")

mutate(TOAST,
       "\tcombatArtAlpha = 1,\n\tclassSoften = 0.35,\n",
       "\tclassSoften = 0.35,\n",
       "the toast dimmed whole in a fight",
       expect="art dimmed whole in a fight",
       script="runscenarios.py")

# The one bright thing left in a fight, turned to iron with the rest.
mutate(TOAST,
       "\tself.gold = { self.ring }\n",
       "\tself.gold = { self.ring, self.band }\n",
       "the enamel turned to iron in a fight",
       expect="the enamel lost the reason's colour in a fight",
       script="runscenarios.py")

mutate(TOAST,
       "\tif held then self:Combat(true) end\n",
       "",
       "a layout during the hold puts the gold back",
       expect="put the gold back",
       script="runscenarios.py")

mutate(TOAST,
       "\tkit.textLayer:SetAlpha(on and TEXT_COMBAT or 1)\n",
       "\tkit.textLayer:SetAlpha(TEXT_COMBAT)\n",
       "the fight's dim left on after it",
       expect="the fight's iron stayed on after it ended",
       script="runscenarios.py")

# --- the outcome -----------------------------------------------------------

# The design's own: "buffed Elowen" on the name line.
mutate(TOAST,
       "\tif word and who then\n\t\tkit.SetLine(kit.name, who)\n",
       "\tif word and who then\n\t\tkit.SetLine(kit.name, lead)\n",
       "the outcome rewrites the name line",
       expect="a landed buff moved the name on the toast",
       script="runscenarios.py")

mutate(TOAST,
       "\tself.glyphOn = kind ~= \"sent\"\n",
       "\tself.glyphOn = false\n",
       "the verdict without its tick",
       expect="is not a ticked",
       script="runscenarios.py")

mutate(TOAST,
       "\tself.refused = kind == \"failed\"\n",
       "\tself.refused = false\n",
       "a refusal leaves the icon in colour",
       expect="a refusal did not grey the toast's icon",
       script="runscenarios.py")

mutate(TOAST,
       "\tself.refused = nil\n\tself.kit.icon:SetDesaturated(self.combat and true or false)\n",
       "\tself.refused = nil\n",
       "the refusal's grey left on the icon",
       expect="the icon stayed grey after the refusal ran out",
       script="runscenarios.py")

mutate(TOAST,
       "\tself.glyph:SetShown((glyph and fs:IsShown()) and true or false)\n",
       "\tif glyph then self.glyph:Show() end\n",
       "the verdict's glyph left up",
       expect="the verdict stayed on the toast",
       script="runscenarios.py")

# --- the chips -------------------------------------------------------------

mutate(TOAST,
       "\t\tkeyUp = self:NameFits(self.keyRoom)\n",
       "\t\tkeyUp = false\n",
       "the bound key never shown",
       expect="no chip naming it",
       script="runscenarios.py")

mutate(TOAST,
       "\t\tkeyUp = self:NameFits(self.keyRoom)\n",
       "\t\tkeyUp = true\n",
       "the key's chip cuts the name",
       expect="cut a name that could not shrink",
       script="runscenarios.py")

mutate(TOAST,
       "\tif not (p and p.locked) then return nil end\n",
       "",
       "the key's chip on an unlocked prompt",
       expect="on an unlocked prompt",
       script="runscenarios.py")

mutate(TOAST,
       "\t\t\tmode = \"coin\"\n",
       "\t\t\tmode = \"chip\"\n",
       "two chips side by side at the right",
       expect="the count is not on the medallion",
       script="runscenarios.py")

mutate(TOAST,
       "\tif self.keyUp then inset = math.max(inset, self.keyRoom or 0) end\n",
       "",
       "the name runs under the key's chip",
       expect="the name runs under the key's chip",
       script="runscenarios.py")

# --- the favour clock ------------------------------------------------------

mutate(TOAST,
       "\t\t\t\tfrac = math.min(1, (ends - now) / (ends - debt.at))\n",
       "\t\t\t\tfrac = 1\n",
       "the favour clock never burns down",
       expect="half the time gone",
       script="runscenarios.py")

mutate(TOAST,
       "\t\t\tself.clockW = nil\n\t\t\tself.ember:Hide()\n",
       "\t\t\tself.clockW = nil\n",
       "the favour clock outlives the debt",
       expect="the favour clock stayed with nothing owed",
       script="runscenarios.py")

# It is information, not motion: it burns on in a fight and on Calm.
mutate(TOAST,
       "\tif not frac then\n\t\tif self.clockW then\n",
       "\tif not frac or self.combat then\n\t\tif self.clockW then\n",
       "the favour clock put out by a fight",
       expect="the favour clock went in a fight",
       script="runscenarios.py")

mutate(TOAST,
       "\tif not frac then\n\t\tif self.clockW then\n",
       "\tif not frac or not self.kit.FullEffects() then\n\t\tif self.clockW then\n",
       "the favour clock put out by Calm",
       expect="the favour clock went on Calm",
       script="runscenarios.py")

# --- fitting the panel -----------------------------------------------------

mutate(TOAST,
       "\tlocal slim = H < 40\n",
       "\tlocal slim = false\n",
       "the double rail at the smallest sizes",
       expect="the double rail at height 36",
       script="runscenarios.py")

# The design's own: the medallion up to 8 units taller than the button.
mutate(TOAST,
       "Clamp(p.iconSize / ICON_OF, BH * 0.9, H)",
       "Clamp(p.iconSize / ICON_OF, BH * 0.9, H + 8)",
       "the medallion overhangs the button",
       expect="overhangs the button",
       script="runscenarios.py")

mutate(TOAST,
       "\treturn math.ceil(1.1 * fontSize + Gap(fontSize) + 1.1 * SubSize(fontSize) + 10)\n",
       "\treturn math.ceil(1.1 * fontSize + Gap(fontSize) + 1.1 * SubSize(fontSize) + 6)\n",
       "two lines squeezed into too little height",
       expect="two lines need",
       script="runscenarios.py")

# --- the list --------------------------------------------------------------

mutate(TOAST,
       "\t\tself.drawer[i]:SetShown(not ((above and bottomRow) or (not above and topRow)))\n",
       "\t\tself.drawer[i]:SetShown(not topRow)\n",
       "the drawer's rail on the wrong side above the banner",
       expect="above the banner is not in a drawer",
       script="runscenarios.py")

mutate(TOAST,
       "\t\tself.gems[i]:SetVertexColor(c[1], c[2], c[3], 1)\n",
       "",
       "the list's gems in no colour",
       expect="has no reason colour",
       script="runscenarios.py")

# --- leaving ---------------------------------------------------------------

mutate(TOAST,
       "\tkit.fit.room[kit.name], kit.fit.room[kit.sub] = nil, nil\n",
       "",
       "the toast's line room kept after it goes",
       expect="glass fits its lines to the room Toast kept",
       script="runscenarios.py")

mutate(TOAST,
       "\t\ticon:RemoveMaskTexture(self.mask)\n",
       "",
       "the toast's mask left on the icon",
       expect="Toast's mask still shapes the icon",
       script="runscenarios.py")

mutate(TOAST,
       "\tfor _, x in ipairs(self.own) do x:Hide() end\n",
       "",
       "the toast left on screen under another look",
       expect="toast's region",
       script="runscenarios.py")
