# Mutations for the Slate look: tests/scenarios/look-slate.lua, and the
# per-look checks in hunt34-fixesA.lua, hunt35-effects.lua and
# hunt37-effects.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts back a mistake the
# look could plausibly make and names the check that has to object.

SLATE = "Looks/Slate.lua"
GEN = "tools/make_slate_textures.py"
RS = "runscenarios.py"


def slate(old, new, label, expect):
    mutate(SLATE, old, new, label, expect=expect, script=RS)


# --- registration ------------------------------------------------------------

slate("\torder = 6,\n", "",
      "the look has no place in the dropdown",
      "the look has no place in the dropdown")

mutate("Manners.toc",
       "Looks\\Slate.lua\n",
       "",
       "the look is not in the toc",
       expect="no look is registered under",
       script=RS)

mutate("Locales/frFR.lua",
       'L["Slate -- slanted plates, accent blade, segmented timer"] = "Ardoise -- plaques',
       'L["Slate -- slanted plates, accent blade, segmented timer"] = "Slate -- plaques',
       "the look's name left in English in French",
       expect="left the look's name in English",
       script=RS)

mutate("Locales/frFR.lua",
       'L["slanted plates, accent blade, segmented timer"] = "plaques',
       'L["slanted plates, accent blade, segmented timer"] = "slanted plates, accent blade, segmented timer" .. "plaques',
       "the look's line left in English in French",
       expect="left \"slanted plates, accent blade, segmented timer\" in English",
       script=RS)

mutate("Locales/deDE.lua",
       'L["Slate"] = "Schiefer"\n',
       'L["Slate"] = "Schiefer"\nL["modern card, soft shadow, thin progress line"] = "moderne Karte, weicher Schatten, soft shadow, thin progress line"\n',
       "a translation of the old description kept",
       expect="a translation of the old description is still kept",
       script=RS)

slate("\ttitle = L[\"Slate\"],\n", "",
      "the picker's card has no title of its own",
      "the picker's card has no title")

slate("\treturn math.ceil((fontSize + 2) + 2 + (SubSize(fontSize) + 6) + 6 + 4)\n",
      "\treturn math.ceil((fontSize + 2) + 2 + (SubSize(fontSize) + 6) + 6 + 40)\n",
      "two lines asked to be taller than the default prompt",
      "two lines at the default font need")

# --- painting ------------------------------------------------------------------

slate("\tif icon then self.fx:Land(o[1], o[2], o[3], 0.70) end\n",
      "\tif icon then self.fx:Landed(o[1], o[2], o[3], 0.70) end\n",
      "a landed buff throws on the rings",
      "look-slate: every state paints")

# --- the layout ----------------------------------------------------------------

slate("\tlocal iconX = ground + SLANT * yt + 4\n",
      "\tlocal iconX = 2\n",
      "the icon stands in the blade",
      "the icon runs into the blade")

slate("\t\ttextX = iconX + S + 7\n",
      "\t\ttextX = iconX + S - 4\n",
      "the name starts under the icon",
      "runs into the icon")

slate("\t\ttextX = math.ceil(ground + SLANT * (hp - m) + 6)\n",
      "\t\ttextX = 4\n",
      "with no icon the name starts in the blade",
      "the name starts at")

slate("\tself.baseInset = math.ceil(twoLine and (SLANT * tagTop + 8 + SLANT * tagH / 2)\n",
      "\tself.baseInset = math.ceil(twoLine and (6)\n",
      "the lines keep no room for the slant at the right",
      "the slant cuts the name's room")

slate("\t\tf:SetSize(math.ceil(w + 10 + lean), self.tagH)\n",
      "\t\tf:SetSize(math.ceil(w), self.tagH)\n",
      "the tag is narrower than its words",
      "the tag does not hold its words")

slate("\tself.tagLeft = textX - 5 - SLANT * tagH / 2\n",
      "\tself.tagLeft = textX - 40\n",
      "the tag starts under the icon",
      "the tag")

slate("\tlocal hp = H - ledge\n",
      "\tlocal hp = H - ledge - 3\n",
      "the plate and its ledge do not fill the height",
      "the plate and its ledge do not fill")

slate("\tself.nameY = H / 2 - nameC\n",
      "\tself.nameY = H / 2 - nameC + 30\n",
      "the name is placed off the prompt",
      "outside the prompt's box")

slate("\tinset = math.min(inset, math.max(0, self.W - self.textX - 20))\n", "",
      "the lines' room runs out and the points cross",
      "hunt34-layout: slate keeps the name 20 units")

slate("\t\tlocal limitH = math.min(textX - cx - kit.TEXT_MARGIN, cx - kit.EDGE_MARGIN)\n",
      "\t\tlocal limitH = 60\n",
      "the rings spread over the text",
      "hunt37-effects")

slate("\tself.edgeRoom = math.ceil(SLANT * (self.chipTop + chipH) + 4)\n",
      "\tself.edgeRoom = 4\n",
      "the chip's right end is past the slant",
      "the count chip is past the plate's slanted edge")

slate("\tfor _, t in ipairs({ self.iconPlate, self.iconEdge, self.iconFlash }) do t:SetShown(showIcon) end\n", "",
      "the icon's frame stays with the icon off",
      "the icon's frame stayed with the icon off")

# --- the chips -----------------------------------------------------------------

slate("\t\tkeyUp = self:NameFits(self.keyRoom)\n",
      "\t\tkeyUp = true\n",
      "the key's chip cuts a name that cannot shrink",
      "the key's chip stayed up")

slate("\t\t\tif self:NameFits(self:PairRoom()) then mode = \"pair\" end\n",
      "\t\t\tmode = \"pair\"\n",
      "both chips cut the name",
      "both chips are up and cut the name")

slate("\t\tif type(text) == \"string\" and text:match(\"^%d+$\") then count:SetText(\"+\" .. text) end\n",
      "",
      "the count chip says a bare number",
      "the count chip does not say how many more")

slate("\tif self.outcomeOn or type(GetBindingKey) ~= \"function\" then return nil end\n",
      "\tif type(GetBindingKey) ~= \"function\" then return nil end\n",
      "the key's chip over an outcome",
      "the key's chip is up over an outcome")

# --- the list --------------------------------------------------------------------

slate("\t\ty0 = self.H + 3\n",
      "\t\ty0 = self.H - 3\n",
      "the strips below touch the plate",
      "the strips below touch the plate")

slate("\t\ty0 = -3 - depth + 1\n",
      "\t\ty0 = -depth + 8\n",
      "the strips above touch the plate",
      "the strips above touch the plate")

slate("\t\tself.strips[i].notch:SetVertexColor(c[1], c[2], c[3], 1)\n",
      "\t\tself.strips[i].notch:SetVertexColor(1, 1, 1, 1)\n",
      "a notch not in the row's colour",
      "has no notch in a reason's colour")

slate("\t\tfs:SetPoint(\"LEFT\", art, \"TOPLEFT\", x0 + self.rowOffset, -(top + h / 2))\n",
      "\t\tfs:SetPoint(\"LEFT\", self.hatch, \"TOPLEFT\", x0 + self.rowOffset, -(top + h / 2))\n",
      "the list's names anchored to a texture",
      "names are buttons")

slate("\t\tlocal x0 = self.rowBase + (i - 1) * self.stagger\n",
      "\t\tlocal x0 = self.rowBase\n",
      "the strips do not step in",
      "the strips do not step in")

slate("\tself.rowReach = self.rowOffset\n",
      "\tself.rowReach = 2\n",
      "a click area that misses the notch",
      "click area misses its notch")

slate("\t\tif not (list and i <= shown) then\n",
      "\t\tif false then\n",
      "a strip stays with no row",
      "a strip with no row")

# --- frames, rings and the light -------------------------------------------------

slate("\tself.chipFrame = frame(3)\n",
      "\tself.chipFrame = frame(9)\n",
      "a frame of Slate's over the text",
      "every frame of Slate's is under the text")

slate("\t\tf:SetFrameLevel(base + 2)\n\tend\n\tkit.RingArt",
      "\t\tf:SetFrameLevel(base + 9)\n\tend\n\tkit.RingArt",
      "the rings drawn over the text",
      "hunt37-effects: the light is drawn beneath the text, in slate")

slate("local FX_PEAK, FX_EDGE = 0.70, 0.875\n",
      "local FX_PEAK, FX_EDGE = 0.70, 0.5\n",
      "the rings declared to reach less than they do",
      "is seen out to")

slate("\tPark(g, region, 0)\n\treturn g\nend\n\n-- Held out of sight",
      "\tPark(g, region, 0)\n\tg:CreateAnimation(\"Scale\")\n\treturn g\nend\n\n-- Held out of sight",
      "a flash that scales over the text",
      "scales: it would cross the text")

# --- the cooldown bar --------------------------------------------------------------

slate("\t\t\tseg.drop:SetStartDelay(math.max(0, left - at * duration))\n",
      "\t\t\tseg.drop:SetStartDelay(math.max(0, at * duration))\n",
      "the segments drop out in the wrong order and time",
      "look-slate: the cooldown bar drops")

slate("\t\tif i <= n and at < frac then\n",
      "\t\tif i <= n then\n",
      "a segment lit that the cooldown has run past",
      "is lit though the cooldown has run past it")

slate("\tself.coolHold:SetDuration(left)\n",
      "\tself.coolHold:SetDuration(1)\n",
      "the bar stays up for a second whatever is left",
      "the bar stays up")

slate("\tself.coolOn = nil\n\tself.coolRun:Stop()\n\tfor _, seg in ipairs(self.segs) do seg.group:Stop() end\n",
      "\tself.coolOn = nil\n\tfor _, seg in ipairs(self.segs) do seg.group:Stop() end\n",
      "a cleared cooldown leaves the bar up",
      "a cleared cooldown left the bar up")

slate("\t\tif Slate.active then Slate:Cool(start, duration) end\n",
      "\t\tSlate:Cool(start, duration)\n",
      "the bar counts on another look",
      "Slate's bar counted on another look")

slate("\tif not self.p.showIcon then return end\n\tself.coolOn = true\n",
      "\tself.coolOn = true\n",
      "a bar with no icon to cool",
      "a cooldown bar with no icon")

slate("\tself.coolRun:Play()\nend\n",
      "\tself.coolRun:Play()\n\tself.coolBox:SetScript(\"OnUpdate\", function() end)\nend\n",
      "the bar polls on a frame script",
      "has an OnUpdate while the bar runs")

slate("\t\t\tcooldown:SetAlpha(0)\n",
      "\t\t\tcooldown:SetAlpha(1)\n",
      "the sweep drawn as well as the bar",
      "the sweep is drawn")

slate("\tif kit.cooldown then\n\t\tkit.cooldown:SetAlpha(1)\n",
      "\tif kit.cooldown then\n\t\tkit.cooldown:SetAlpha(0)\n",
      "the sweep left at no strength on another look",
      "the sweep was not given back its strength")

# --- the accent ----------------------------------------------------------------------

slate("\tself.blade:SetVertexColor(r, g, b, 1)\n",
      "\tself.blade:SetVertexColor(0.62, 0.67, 0.76, 1)\n",
      "the blade not in the reason's colour",
      "the blade is not in the reason's colour")

slate("\tColour(self.tag, r, g, b, 1)\n",
      "\tColour(self.tag, 0.5, 0.5, 0.5, 1)\n",
      "the tag not in the reason's colour",
      "the tag is not in the reason's colour")

slate("\tColour(self.ledge, lr, lg, lb, 1)\n",
      "\tColour(self.ledge, 0.1, 0.1, 0.1, 1)\n",
      "the ledge not a shade of the reason's colour",
      "the ledge is not a shade of the reason's colour")

slate("\tif mode == \"icon\" or mode == \"both\" or a.outcome then\n",
      "\tif true then\n",
      "the icon's line wears the colour whatever the mode",
      "the icon's line wears the reason's colour though the mode says it does not")

slate("\tlocal ink = InkOn(r, g, b)\n",
      "\tlocal ink = INK_LIGHT\n",
      "the tag's ink does not follow its colour",
      "the tag's text is")

slate("\treturn (mode == \"icon\" or mode == \"both\") and p.showIcon and true or false, mode ~= \"off\"\n",
      "\treturn (mode == \"icon\" or mode == \"both\") and p.showIcon and true or false, true\n",
      "AccentCarriers says the blade carries with the marker off",
      "AccentCarriers says")

slate("\t\telseif mode == \"off\" then\n\t\t\tr, g, b = NEUTRAL[1], NEUTRAL[2], NEUTRAL[3]\n",
      "\t\telseif false then\n\t\t\tr, g, b = NEUTRAL[1], NEUTRAL[2], NEUTRAL[3]\n",
      "the marker off and the accent still the reason's",
      "with the marker off the blade or the tag")

slate("\t\tif self.combat then\n\t\t\tr, g, b = STEEL[1], STEEL[2], STEEL[3]\n",
      "\t\tif false then\n\t\t\tr, g, b = STEEL[1], STEEL[2], STEEL[3]\n",
      "the accent keeps its colour in a fight",
      "the accent is not steel in a fight")

slate("\t\tself:StopFlourishes()\n\tend\n\tself:Accent()\nend\n",
      "\t\tself:StopFlourishes()\n\tend\nend\n",
      "a fight starts and the accent is not repainted",
      "the accent is not steel in a fight")

slate("local STEEL = { 0.50, 0.56, 0.66 }\n",
      "local STEEL = { 0.20, 0.56, 0.96 }\n",
      "steel that is not muted",
      "steel is not muted")

# --- the outcomes ----------------------------------------------------------------------

slate("\tif kind ~= \"cast\" then return end\n", "",
      "a cast nobody confirmed lands",
      "a cast nobody confirmed got a flourish")

slate("\t\tkit.SetLine(kit.name, who)\n",
      "\t\tkit.SetLine(kit.name, lead)\n",
      "the verdict moves the name",
      "a landed buff moved the name")

slate("\t\tkit.SetLine(kit.sub, word)\n",
      "\t\tkit.SetLine(kit.sub, \"\")\n",
      "the tag says nothing of the outcome",
      "a landed buff's tag is not")

slate("\tself.accent = { o[1], o[2], o[3], mode = self.p.accentMode or \"icon\", outcome = true }\n",
      "\tself.accent = { 0.5, 0.5, 0.5, mode = self.p.accentMode or \"icon\", outcome = true }\n",
      "a landed buff leaves the accent grey",
      "did not turn the accent green")

slate("\tColour(self.wash, oc[1], oc[2], oc[3], 1)\n",
      "\tColour(self.wash, 1, 1, 1, 1)\n",
      "the wash is white",
      "the wash is not green")

slate("\tself.band:SetVertexColor(1, 1, 1, 1)\n",
      "\tself.band:SetVertexColor(0.2, 0.9, 0.4, 1)\n",
      "the landing's streak is green",
      "the landing's streak is not white")

slate("\tself.bandMove:SetOffset(travel, 0)\n",
      "\tself.bandMove:SetOffset(travel / 3, 0)\n",
      "the landing's streak stops short",
      "the landing's streak does not cross the whole plate")

slate("\tfor _, g in ipairs(self.landing) do g:Stop() end\n\tfor _, g in ipairs(self.refusal) do g:Stop() end\n",
      "\tfor _, g in ipairs(self.refusal) do g:Stop() end\n",
      "a repaint leaves the landing playing",
      "hunt35-effects: every effect stops cleanly on a repaint and a restyle, in slate")

slate("\tlocal plateSteps = { -3, 5, -4, 3, -2, 1 }\n",
      "\tlocal plateSteps = { -3, 5, -4, 3, -2, 2 }\n",
      "the plate's jerk ends displaced",
      "the plate's jerk does not end where it began")

slate("\tlocal ghostSteps = { { -5, 8, -6, 2, 1 }, { 6, -9, 5, -3, 1 } }\n",
      "\tlocal ghostSteps = { { -5, 8, -6, 2, 2 }, { 6, -9, 5, -3, 1 } }\n",
      "a copy of the plate ends displaced",
      "a ghost's slip")

slate("local GHOSTS = { { 1.00, 0.22, 0.18 }, { 1.00, 0.72, 0.20 } }\n",
      "local GHOSTS = { { 1.00, 0.22, 0.18 }, { 0.20, 0.30, 1.00 } }\n",
      "the glitch's copies are not red and amber",
      "the glitch's copies are not red and amber")

slate("\t\tPlayAll(self.refusal)\n",
      "",
      "a refusal does not glitch the plate",
      "a refusal did not glitch the plate")

slate("\tself.refused = kind == \"failed\"\n",
      "\tself.refused = false\n",
      "a refusal does not grey the icon",
      "a refusal did not grey the icon")

# --- Calm, the arrival and the breath ------------------------------------------------------

slate("\t\tif full and not self.outcomeOn then\n",
      "\t\tif not self.outcomeOn then\n",
      "Calm plays the arrival",
      "look-slate: Calm plays none")

slate("\tif not full or self.pulseSpent then\n",
      "\tif self.pulseSpent then\n",
      "Calm breathes",
      "look-slate: Calm plays none")

slate("\t\tif full and not self.outcomeOn then\n",
      "\t\tif full then\n",
      "the arrival plays over an outcome",
      "the arrival played over an outcome")

slate("local BREATHS, BREATH = 3, 1.25\n",
      "local BREATHS, BREATH = 3, 4\n",
      "a breath of eight seconds",
      "the breath is")

slate("local BREATHS, BREATH = 3, 1.25\n",
      "local BREATHS, BREATH = 30, 1.25\n",
      "the blade heats for ever",
      "the blade is still heating after its breaths")

slate("local WARM = { 1.00, 0.88, 0.66 }\n",
      "local WARM = { 0.60, 0.80, 1.00 }\n",
      "a cold second tone",
      "the blade's heat is not warm")

slate("\tself:HoldPulse()\n\tself.accent = { o[1]",
      "\tself.accent = { o[1]",
      "the breath goes on over an outcome",
      "the breath went on over an outcome")

slate("\tif flashStyle ~= \"pulse\" then\n\t\tself:StopAttention()\n",
      "\tif false then\n\t\tself:StopAttention()\n",
      "the breath plays with the flash set to once",
      "the breath played with the flash set to")

slate("\tAlpha(run, 0, 0, 2 * BREATH - 0.55, 2)\n",
      "\tAlpha(run, 0, 0, 0.2, 2)\n",
      "the streak runs out of step with the breath",
      "the streak's run is")

slate("\tself.streakMove:SetOffset(travel, 0)\n",
      "\tself.streakMove:SetOffset(travel / 2, 0)\n",
      "the streak stops half way",
      "the streak does not run the plate's width")

slate("\tSlide(g, dx, 0, duration, 2, \"OUT\")\n\tPark(g, region, rest or 1)\n",
      "\tSlide(g, dx / 2, 0, duration, 2, \"OUT\")\n\tPark(g, region, rest or 1)\n",
      "a slide ends displaced",
      "does not end at its plate's place")

slate("\tSlide(g, dx, 0, duration, 2, \"OUT\")\n\tPark(g, region, rest or 1)\n",
      "\tSlide(g, dx, 0, duration, 2)\n\tPark(g, region, rest or 1)\n",
      "a slide that does not ease out hard",
      "does not ease out hard")

slate("\tAlpha(g, 0, 0, delay + 0.01, 1)\n",
      "\tAlpha(g, 0, 0, 0.01, 1)\n",
      "the plates arrive together",
      "the plates do not arrive one after another")

slate("\tself.flash:SetVertexColor(1, 1, 1, 1)\n\n\t-- The light that crosses",
      "\tself.flash:SetVertexColor(1, 0.8, 0.2, 1)\n\n\t-- The light that crosses",
      "the blade's flash is not white",
      "the blade's flash is not white")

slate("\tinto(Flash(self.flash, 1, 0.05, 0.22))\n", "",
      "an arrival with no flash",
      "the arrival does not end in the blade's flash")

# --- the fight ----------------------------------------------------------------------------

slate("\tfor _, fs in ipairs({ kit.name, kit.count, self.keyText }) do fs:SetAlpha(on and TEXT_COMBAT or 1) end\n",
      "\tfor _, fs in ipairs({ kit.count, self.keyText }) do fs:SetAlpha(on and TEXT_COMBAT or 1) end\n",
      "the name does not dim in a fight",
      "the text does not dim in a fight")

slate("\tfor _, fs in ipairs({ kit.name, kit.count, self.keyText }) do fs:SetAlpha(on and TEXT_COMBAT or 1) end\n",
      "\tfor _, fs in ipairs({ kit.name, kit.sub, kit.count, self.keyText }) do fs:SetAlpha(on and TEXT_COMBAT or 1) end\n",
      "the tag dims in a fight",
      "the reason is dimmed in a fight")

slate("\tkit.icon:SetDesaturated(on or self.refused or false)\n",
      "\tkit.icon:SetDesaturated(false)\n",
      "the icon keeps its colour in a fight",
      "the icon keeps its colour in a fight")

slate("\tlocal v = on and ICON_COMBAT or 1\n",
      "\tlocal v = 1\n",
      "the icon is not dimmed in a fight",
      "the icon is not dimmed in a fight")

slate("\tif on then\n\t\tself:StopAttention()\n",
      "\tif false then\n\t\tself:StopAttention()\n",
      "the owed light is lit in a fight",
      "the owed light is lit in a fight")

slate("\t\tself.iconPlateColor = { 0.025, 0.030, 0.042, 1 }\n",
      "\t\tself.iconPlateColor = { 0.025, 0.030, 0.042, 0.3 }\n",
      "a see-through plate under the icon",
      "nothing opaque under the icon in a fight")

slate("\tif held then self:Combat(true) end\n", "",
      "laying out again forgets the fight",
      "laying the plate out again during the hold")

# --- the cursor and leaving -------------------------------------------------------------------

slate("\tg.to = on and 1 or EDGE_REST\n",
      "\tg.to = on and 1 or 1\n",
      "the hairline never settles back after the cursor",
      "the hairline did not settle back")

slate("\tkit.fit.room[kit.name], kit.fit.room[kit.sub] = nil, nil\n", "",
      "the lines keep Slate's room on another look",
      "glass fits its lines to the room Slate kept")

slate("\t\ticon:RemoveMaskTexture(self.mask)\n", "",
      "the icon keeps the hexagon on another look",
      "Slate's mask still shapes the icon")

slate("\ticon:SetVertexColor(1, 1, 1)\n\ticon:SetDesaturated(false)\n", "",
      "the icon is left dimmed and grey",
      "left the icon dimmed on glass")

slate("\tfor _, fs in ipairs({ kit.name, kit.count, self.keyText }) do fs:SetAlpha(1) end\n", "",
      "the text left dimmed on another look",
      "left the text dimmed on glass")

slate("\tif fs == self.kit.sub then up = up:gsub(\"|[cC]%x%x%x%x%x%x%x%x\", \"\"):gsub(\"|[rR]\", \"\") end\n", "",
      "a colour code kept on the tag's words",
      "is set as")

slate("\tfor _, g in ipairs(self.anims) do g:Stop() end\n\tself.fx:Stop()\n",
      "\tself.fx:Stop()\n",
      "an effect left playing when the look changes",
      "hunt35-effects: every effect stops cleanly on a repaint and a restyle, in slate")

slate("\tfor _, x in ipairs(self.own) do x:Hide() end\n\tself.pulseGen",
      "\tself.pulseGen",
      "a piece of Slate's left shown on another look",
      "a piece of Slate's is still shown on glass")

# --- capitals ------------------------------------------------------------------------------------

slate("\t\tif Slate.active then text = Slate:Upper(line, text) end\n",
      "\t\ttext = Slate:Upper(line, text)\n",
      "capitals on another look",
      "Slate still sets capitals once it is not the look in use")

slate("\tlocal out = text:gsub(\"|[cC]%x%x%x%x%x%x%x%x\", hold):gsub(\"|[HT].-|[ht]\", hold):gsub(\"|%a\", hold)\n",
      "\tlocal out = text:gsub(\"|[HT].-|[ht]\", hold):gsub(\"|%a\", hold)\n",
      "a colour code set in capitals",
      "is set as")

slate("\tlocal out = text:gsub(\"|[cC]%x%x%x%x%x%x%x%x\", hold):gsub(\"|[HT].-|[ht]\", hold):gsub(\"|%a\", hold)\n",
      "\tlocal out = text:gsub(\"|[cC]%x%x%x%x%x%x%x%x\", hold):gsub(\"|[HT].-|[ht]\", hold)\n",
      "a line break and a colour's end set in capitals",
      "is set as")

slate("\tlocal out = text:gsub(\"|[cC]%x%x%x%x%x%x%x%x\", hold):gsub(\"|[HT].-|[ht]\", hold):gsub(\"|%a\", hold)\n",
      "\tlocal out = text:gsub(\"|[cC]%x%x%x%x%x%x%x%x\", hold):gsub(\"|%a\", hold)\n",
      "a link's payload set in capitals",
      "is set as")

slate("\tif seen and seen[1] == text then return seen[2] end\n",
      "\tif seen and seen[2] then return seen[2] end\n",
      "a repeated line answered with the last one's capitals",
      "a repeated line is not set the same way")

slate("\tif type(text) ~= \"string\" or (issecretvalue and issecretvalue(text)) then return text end\n",
      "\tif (issecretvalue and issecretvalue(text)) then return text end\n",
      "a line that is not text is worked on",
      "look-slate: capitals on ASCII only")

# --- the face ---------------------------------------------------------------------------------------

slate("\tif type(p.font) == \"string\" and p.font ~= d then return nil end\n", "",
      "the condensed face over the player's font",
      "the chosen font did not win")

slate("\tif OWN_FACE[ns.LOCALE or \"enUS\"] then return nil end\n", "",
      "the condensed face on a Korean or Chinese client",
      "the client's own face is left for the Latin one")

slate("local CONDENSED = \"Fonts\\\\ARIALN.TTF\"\n",
      "local CONDENSED = \"Fonts\\\\ARIALNN.TTF\"\n",
      "a face file the client has not got",
      "the lines are not in the condensed face")

slate("\tif face and not tried then kit.name:SetFont(fit.path or STANDARD_TEXT_FONT, p.fontSize, fit.flags) end\n", "",
      "a refused face leaves the name with no font",
      "a line was left with no font")

slate("\tlocal nameSize = face and fs + 2 or fs\n",
      "\tlocal nameSize = fs\n",
      "the name no larger than the font's size",
      "the name is not a size above")

# --- the ground ---------------------------------------------------------------------------------------

slate("\treturn math.min(Ratio(1, lo), Ratio(1, hi)) >= math.min(Ratio(0, lo), Ratio(0, hi))\n",
      "\treturn math.min(Ratio(1, lo), Ratio(1, hi)) < math.min(Ratio(0, lo), Ratio(0, hi))\n",
      "the plate thinks a dark panel is light",
      "the hairline is not")

slate("local PLATE_TOP, PLATE_BOTTOM, PLATE_ALPHA = { 0.112, 0.124, 0.158 }, { 0.050, 0.056, 0.076 }, 0.95\n",
      "local PLATE_TOP, PLATE_BOTTOM, PLATE_ALPHA = { 0.55, 0.58, 0.62 }, { 0.50, 0.52, 0.56 }, 0.95\n",
      "a pale slate",
      "the plate's slate is not dark")

# --- the art -----------------------------------------------------------------------------------------

slate("local ART = \"Interface\\\\AddOns\\\\Manners\\\\Textures\\\\Slate\\\\Slate_\"\n",
      "local ART = \"Interface\\\\AddOns\\\\Manners\\\\Textures\\\\Slate\\\\Slat_\"\n",
      "the look draws files that do not exist",
      "a texture of Slate's is from")

slate("\tself.heat = tex(self.bladeFrame, \"ARTWORK\", 1, \"Blade\")\n",
      "\tself.heat = tex(self.bladeFrame, \"ARTWORK\", 1, \"Blade\")\n\tself.heat:SetBlendMode(\"ADD\")\n",
      "the blade's heat is additive",
      "a texture of Slate's is additive")

slate("\tself.hatch = tex(art, \"BACKGROUND\", -5, \"Hatch\")\n",
      "\tself.hatch = tex(art, \"BACKGROUND\", -5, \"Seg\")\n",
      "a file ships that nothing draws",
      "Slate_Hatch ships and the look never draws it")

slate("local SLANT, CAP = 0.28, 0.75\n",
      "local SLANT, CAP = 0.30, 0.75\n",
      "the slant in the code is not the art's",
      "the slant or the width of a plate's end differs")

mutate(GEN,
       "\nSLANT = 0.28\n",
       "\nSLANT = 0.30\n",
       "the art redrawn at another slant",
       expect="the slant or the width of a plate's end differs",
       script=RS)

mutate(GEN,
       "def plate_shape(x, y):\n    return poly_sdf(x, y, slab(256, 128, SLANT * 128))\n",
       "def plate_shape(x, y):\n    return poly_sdf(x, y, slab(256, 128, SLANT * 128)) + np.where((x < 14) & (y > 114), 5.0, 0.0)\n",
       "the plate drawn with a rounded corner",
       expect="does not match the file that ships",
       script=RS)

mutate(GEN,
       "        return np.clip(cover(d) - cover(d + 3.0), 0, 1)\n    make(\"Slate_Edge\"",
       "        return np.clip(cover(d) - cover(d + 4.0), 0, 1)\n    make(\"Slate_Edge\"",
       "the art redrawn without the generator",
       expect="does not match the file that ships",
       script=RS)

mutate(GEN,
       "    make(\"Slate_Seg\"",
       "    make(\"Slate_Segg\"",
       "a file the look draws is not drawn",
       expect="Slate_Seg is not drawn by the generator",
       script=RS)

mutate(GEN,
       "CUT = 15.0\n",
       "CUT = 3.0\n",
       "the icon's frame with its corners not cut",
       expect="does not match the file that ships",
       script=RS)
