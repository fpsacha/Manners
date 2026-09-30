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
       expect="the owed enamel is not parted",
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
       "\tself.gold = { self.ring, self.jewelSet }\n",
       "\tself.gold = { self.ring, self.jewelSet, self.band }\n",
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
       "\tif who and kit.sub:IsShown() then\n\t\tkit.SetLine(kit.name, who)\n",
       "\tif who and kit.sub:IsShown() then\n\t\tkit.SetLine(kit.name, lead)\n",
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
       "\t\t\tself.clockW = nil\n\t\t\tself.ash:Hide()\n\t\t\tself.ember:Hide()\n",
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
       "\tlocal M = showIcon and H or 0\n",
       "\tlocal M = showIcon and H + 8 or 0\n",
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

# --- round 15: the reviewers' findings --------------------------------------

# A fight made the icon see-through, and the banner starts at its centre.
mutate(TOAST,
       "\tkit.icon:SetVertexColor(v, v, v)\n",
       "\tkit.icon:SetAlpha(v)\n",
       "the icon see-through in a fight",
       expect="the icon turned see-through in a fight",
       script="runscenarios.py")

mutate(TOAST,
       "\tself.well:SetShown(showIcon)\n",
       "\tself.well:Hide()\n",
       "nothing opaque under the icon",
       expect="nothing opaque under the icon",
       script="runscenarios.py")

mutate(TOAST,
       "\ticon:SetVertexColor(1, 1, 1)\n",
       "",
       "the fight's dim left on the icon for the next look",
       expect="left the icon dimmed on glass",
       script="runscenarios.py")

# A medallion shorter than the banner shows the rails' ends above and below.
mutate(TOAST,
       "\tlocal M = showIcon and H or 0\n",
       "\tlocal M = showIcon and Clamp(p.iconSize / ICON_OF, H * 0.8, H) or 0\n",
       "the medallion shorter than the banner",
       expect="is shorter than the banner",
       script="runscenarios.py")

# The owed gold as bright as the gold round it.
mutate(TOAST,
       "\tif er > 0.9 and eb < 0.3 and eg > 0.6 * er and eg < 0.9 * er then\n",
       "\tif false then\n",
       "the owed gold not fired deeper",
       expect="the owed enamel is not parted",
       script="runscenarios.py")

mutate(TOAST,
       "\tif er > 0.9 and eb < 0.3 and eg > 0.6 * er and eg < 0.9 * er then\n",
       "\tif er > 0.9 then\n",
       "every warm colour fired dark",
       expect="fired dark like the owed gold",
       script="runscenarios.py")

# The light cut at its brightest column, a seam under the medallion.
mutate(TOAST,
       "\t\tt:SetTexCoord(0, 1, 0, 1)\n",
       "\t\tt:SetTexCoord(0.30, 1, 0, 1)\n",
       "the light cut under the medallion",
       expect="a hard edge under the medallion",
       script="runscenarios.py")

# With the icon off, nothing carries the reason.
mutate(TOAST,
       "\tself.jewel:SetVertexColor(er, eg, eb, 1)\n",
       "",
       "the jewel in no colour",
       expect="Toast carries the reason on a jewel",
       script="runscenarios.py")

mutate(TOAST,
       "\tself.jewel:SetShown(not showIcon)\n",
       "\tself.jewel:Show()\n",
       "the jewel beside the medallion",
       expect="the jewel shows beside the medallion",
       script="runscenarios.py")

mutate(TOAST,
       "math.floor(jewelX + jewel / 2 + 7 + 0.5)",
       "(C + 4)",
       "the name written over the jewel",
       expect="the name starts on the jewel",
       script="runscenarios.py")

# The verdict written nowhere when the second line is down.
mutate(TOAST,
       "\tif who and kit.sub:IsShown() then\n",
       "\tif who then\n",
       "the outcome lost with the second line down",
       expect="not what happened",
       script="runscenarios.py")

# A German client's name line rewritten by the built-in headline.
mutate(TOAST,
       "\tif who and kit.sub:IsShown() then\n",
       "\tif who and word and kit.sub:IsShown() then\n",
       "a German client's name line rewritten",
       expect="German client",
       script="runscenarios.py")

# The coin hung off the banner's end with no medallion to sit on.
mutate(TOAST,
       "\t\tif keyUp and self.M > 0 then\n",
       "\t\tif keyUp then\n",
       "the count's coin with no medallion",
       expect="not beside the key's chip",
       script="runscenarios.py")

mutate(TOAST,
       "\tif self.countMode == \"pair\" then inset = math.max(inset, self:PairRoom()) end\n",
       "",
       "the name under the count beside the key",
       expect="the name runs under the count's chip beside the key's",
       script="runscenarios.py")

# A key bound anew, and the lines kept the old key's room.
mutate(TOAST,
       "\t\t\t-- lines again, beside it.\n\t\t\tkit.fit.right = nil\n",
       "",
       "the old key's room kept after a rebind",
       expect="keeps the old key's room",
       script="runscenarios.py")

# The clock as one more gold rail.
mutate(TOAST,
       "\tself.ash:Show()\n",
       "",
       "the clock with no ash",
       expect="no ash under the clock",
       script="runscenarios.py")

mutate(TOAST,
       "\t\tself.ember:SetVertexColor(Mix(er, eg, eb, 0.35))\n",
       "\t\tself.ember:SetVertexColor(er, eg, eb)\n",
       "the clock in the enamel's colour",
       expect="one more gold rail",
       script="runscenarios.py")

mutate(TOAST,
       "\tself.bead:SetSize(self.clockH * 4.5, self.clockH * 2)\n",
       "\tself.bead:SetSize(self.clockH * 3.2, self.clockH * 1.3)\n",
       "the clock's spark too small",
       expect="too small to see",
       script="runscenarios.py")

mutate(TOAST,
       "\t\t\tself.ash:Hide()\n",
       "",
       "the clock's ash outlives the debt",
       expect="the clock's ash stayed",
       script="runscenarios.py")

# The options page and the icon size the look ignores.
mutate("Options.lua",
       "disabled = function() return not P().showIcon or LookIconSize() ~= nil end,",
       "disabled = function() return not P().showIcon end,",
       "the icon slider live on Toast",
       expect="the icon size slider is live",
       script="runscenarios.py")

mutate("Options.lua",
       "\t\t\t\t\tif LookIconSize() then return not p.showIcon end\n",
       "",
       "nothing says how Toast sizes its icon",
       expect="nothing on the options page says",
       script="runscenarios.py")

mutate(TOAST,
       "\treturn math.floor(ICON_OF * (p.height or 44) + 0.5)\n",
       "\treturn p.iconSize\n",
       "the notice gives the slider's size, not the drawn one",
       expect="the notice does not give the icon's size",
       script="runscenarios.py")

# A misnamed file: a solid box in the game, and nothing throws.
mutate(TOAST,
       "ART .. \"Shadow\", nil, true, keep)",
       "ART .. \"Shadw\", nil, true, keep)",
       "a misnamed Toast texture",
       expect="which the package does not ship",
       script="runscenarios.py")
