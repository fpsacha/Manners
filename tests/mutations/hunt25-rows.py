# The names in the list as buttons (Prompt/Rows.lua, tests/scenarios/
# hunt25-rows.lua): each fault put back has to be caught by the scenario that
# names it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"
P = "Prompt/Press.lua"
R = "Prompt/Rows.lua"

# ------------------------------------------------ who, and with what macro
# The click aimed at whoever the prompt is on.
mutate(P,
       "\tPrompt:ArmRow(row, fresh, HoldLine(fresh, verdicts))\n",
       "\tPrompt:ArmRow(row, S.current or fresh, HoldLine(fresh, verdicts))\n",
       "hunt25-rows: a click on a name casts at the prompt's person",
       expect="hunt25-rows: a click on the second name casts at that person",
       script=S)

# The hand-back left off the macro of a name.
mutate("Prompt/Macro.lua",
       "\tif restore then lines[#lines + 1] = \"/targetlasttarget\" end\n",
       "\tif restore and not S.isRow then lines[#lines + 1] = \"/targetlasttarget\" end\n",
       "hunt25-rows: a name's macro leaves out the hand-back",
       expect="hunt25-rows: a click on the second name casts at that person",
       script=S)

# ------------------------------------------------ filed as a press on the prompt is
# The press filed against the prompt's state rather than the row's.
mutate(P,
       "\tlocal S = self.mannersRow or S\n",
       "\tlocal S = S\n",
       "hunt25-rows: a press on a name filed for the prompt's person",
       expect="hunt25-rows: a click on a name files the press as a press on the prompt does",
       script=S)

# The press never filed: no favour is repaid by it.
mutate(P,
       "\tOnPostClick(self, mouseButton, down)\n"
       "\t-- A fight that began in the middle of a press is DisarmRows' (Core.lua).\n",
       "\t-- A fight that began in the middle of a press is DisarmRows' (Core.lua).\n",
       "hunt25-rows: a press on a name never filed",
       expect="hunt25-rows: a favour is repaid when a cast on a name lands",
       script=S)

# What the macro was aimed at not kept for the row: the settle path cannot
# judge the press.
mutate("Prompt/Macro.lua",
       "\tS.armed = record\n",
       "\tif not S.isRow then S.armed = record end\n",
       "hunt25-rows: a name's macro leaves no record of its aim",
       expect="hunt25-rows: a click on a name files the press as a press on the prompt does",
       script=S)

# The row let go before its press is filed: there is nothing to refuse.
mutate(P,
       "\trow.pressing = nil\n"
       "\tOnPostClick(self, mouseButton, down)\n",
       "\trow.pressing = nil\n"
       "\tPrompt:ArmRow(row, nil)\n"
       "\tOnPostClick(self, mouseButton, down)\n",
       "hunt25-rows: a name let go before its press is filed",
       expect="hunt25-rows: a refused cast on a name backs off that name and not the prompt's",
       script=S)

# The macro's own /target taken for the player choosing them.
mutate(P,
       "\tns.pressAt = now\n"
       "\tpressStale = nil\n"
       "\trow.pressing = true\n",
       "\tpressStale = nil\n"
       "\trow.pressing = true\n",
       "hunt25-rows: a name's own /target lifts the back-off",
       expect="hunt25-rows: a refused cast on a name backs off that name and not the prompt's",
       script=S)

# A press on a name stopping the prompt's own pulse.
mutate(P,
       "\tif not S.isRow then Prompt:StopAttention() end\n"
       "end\n",
       "\tPrompt:StopAttention()\n"
       "end\n",
       "hunt25-rows: a press on a name stops the prompt's pulse",
       expect="hunt25-rows: a click on a name files the press as a press on the prompt does",
       script=S)

# One stamp for every button: a press just after another is swallowed.
mutate(P,
       "\tif S.clickAt and (now - S.clickAt) < 0.25 then return end\n"
       "\tS.clickAt = now\n",
       "\tif Prompt.state.clickAt and (now - Prompt.state.clickAt) < 0.25 then return end\n"
       "\tPrompt.state.clickAt = now\n",
       "hunt25-rows: a press on a name just after the prompt's swallowed",
       expect="hunt25-rows: a press on a name just after one on the prompt is its own press",
       script=S)

# ------------------------------------------------ the cooldown guard, and a name that has gone
mutate(P,
       "\tif not ready then\n"
       "\t\tguardedEntry = nil\n"
       "\t\trow.pressing = true\n"
       "\t\tPrompt:SayWaiting(left)\n"
       "\t\treturn\n"
       "\tend\n",
       "",
       "hunt25-rows: a name cast on in the global cooldown",
       expect="hunt25-rows: a click on a name during the global cooldown casts nothing",
       script=S)

# The painted entry cast whether the scan still offers them or not.
mutate(P,
       "\tif not fresh then\n"
       "\t\tns.Guard(\"row moved on\", Prompt.Refresh, Prompt)\n"
       "\t\treturn\n"
       "\tend\n",
       "\tfresh = fresh or entry\n",
       "hunt25-rows: a name who is gone cast on from the painted list",
       expect="hunt25-rows: a name the scan no longer offers is not cast on",
       script=S)

# Whatever buff the scan offers now cast, not the one the row said.
mutate(P,
       "if candidate.name == entry.name and candidate.buff and candidate.buff.key == entry.buff.key then\n",
       "if candidate.name == entry.name and candidate.buff then\n",
       "hunt25-rows: a name cast on with another buff than the row said",
       expect="hunt25-rows: a name the scan no longer offers is not cast on",
       script=S)

# ------------------------------------------------ nothing stays armed
mutate(P,
       "\t-- A fight that began in the middle of a press is DisarmRows' (Core.lua).\n"
       "\tif not InCombatLockdown() then Prompt:ArmRow(row, nil) end\n",
       "\t-- A fight that began in the middle of a press is DisarmRows' (Core.lua).\n",
       "hunt25-rows: a row kept armed after its press",
       expect="hunt25-rows: a row holds no macro at rest and lets go after the press",
       script=S)

mutate(R,
       "\t\tif row.appliedKey and not combat and now - (row.armedAt or 0) > ARMED_SECONDS then\n",
       "\t\tif false then\n",
       "hunt25-rows: a row armed and never pressed stays armed",
       expect="hunt25-rows: a row holds no macro at rest and lets go after the press",
       script=S)

mutate(P,
       "\trow.armedAt = now\n",
       "",
       "hunt25-rows: a row's arming is never dated",
       expect="hunt25-rows: a row holds no macro at rest and lets go after the press",
       script=S)

mutate("Core.lua",
       "\tif ns.Prompt then ns.Guard(\"rows at fight start\", ns.Prompt.DisarmRows, ns.Prompt) end\n",
       "",
       "hunt25-rows: a row left armed into a fight",
       expect="hunt25-rows: a row holds no macro at rest and lets go after the press",
       script=S)

# The repaint arming every row, as a design that writes at paint would.
mutate(R,
       "\t\t\trow.entry, row.name, row.buffKey = entry, entry.name, key\n",
       "\t\t\trow.entry, row.name, row.buffKey = entry, entry.name, key\n"
       "\t\t\tself:ArmRow(row, entry)\n",
       "hunt25-rows: a repaint writes attributes on a row",
       expect="hunt25-rows: repainting the list writes no attribute on a row",
       script=S)

# ------------------------------------------------ inert in a fight
mutate(P,
       "\trow.pressing = nil\n"
       "\tif InCombatLockdown() then return end\n"
       "\tlocal now = GetTime()\n",
       "\trow.pressing = nil\n"
       "\tlocal now = GetTime()\n",
       "hunt25-rows: a click on a name arms it in a fight",
       expect="hunt25-rows: a click on a name in a fight does nothing at all",
       script=S)

# The names hidden in a fight, which the client refuses on a secure frame.
mutate(R,
       "\t\t\tif not combat and row.shown then\n"
       "\t\t\t\trow.button:Hide()\n",
       "\t\t\tif row.shown then\n"
       "\t\t\t\trow.button:Hide()\n",
       "hunt25-rows: the names hidden in a fight",
       expect="hunt25-rows: a click on a name in a fight does nothing at all",
       script=S)

mutate("Prompt/Button.lua",
       "\t\trow.hovered = true\n"
       "\t\tif InCombatLockdown() then return end\n",
       "\t\trow.hovered = true\n",
       "hunt25-rows: a name's tooltip in a fight",
       expect="hunt25-rows: a click on a name in a fight does nothing at all",
       script=S)

# The preview painting the list's lines in a fight.
mutate("Prompt/Refresh.lua",
       "\t\tif not InCombatLockdown() then self:PaintQueue(mock) end\n",
       "\t\tself:PaintQueue(mock)\n",
       "hunt25-rows: the preview places the list in a fight",
       expect="hunt25-rows: the list's lines stay where they are in a fight",
       script=S)

# ------------------------------------------------ only the left button, and skip and never
mutate("Prompt/Macro.lua",
       "\tfor index = 2, 31 do\n"
       "\t\tif index <= 5 then R.button:SetAttribute(\"type\" .. index, \"none\") end\n"
       "\t\tR.button:SetAttribute(\"*type\" .. index, \"none\")\n"
       "\tend\n",
       "\tfor index = 2, 5 do\n"
       "\t\tR.button:SetAttribute(\"type\" .. index, \"none\")\n"
       "\tend\n",
       "hunt25-rows: a name run by a modified or extra mouse button",
       expect="hunt25-rows: only the left button casts from a name",
       script=S)

mutate(R,
       "\tSilenceOtherButtons(row)\n",
       "",
       "hunt25-rows: a row not silenced until it is armed",
       expect="hunt25-rows: only the left button casts from a name",
       script=S)

# Every button arms the row, and the right one leaves it armed.
mutate(P,
       "local function OnRowPreClick(self, mouseButton, down)\n"
       "\tif mouseButton and mouseButton ~= \"LeftButton\" then return end\n",
       "local function OnRowPreClick(self, mouseButton, down)\n",
       "hunt25-rows: any button arms a name",
       expect="hunt25-rows: only the left button casts from a name",
       script=S)

# The up of a long press armed as a press of its own.
mutate(P,
       "\tif down == false then return end\n"
       "\tlocal row = self.mannersRow\n"
       "\trow.pressing = nil\n",
       "\tlocal row = self.mannersRow\n"
       "\trow.pressing = nil\n",
       "hunt25-rows: the up of a press arms a name",
       expect="hunt25-rows: only the left button casts from a name",
       script=S)

# Shift-right-click listing whoever the prompt is on.
mutate(P,
       "\t\tif S.isRow then victim = S.name end\n",
       "",
       "hunt25-rows: right-click on a name skips the prompt's person",
       expect="hunt25-rows: right-click skips a name and shift-right-click lists them",
       script=S)

# ------------------------------------------------ hidden names, and the option
mutate(R,
       "\t\t\tif not combat and row.shown then\n"
       "\t\t\t\trow.button:Hide()\n"
       "\t\t\t\trow.shown = false\n"
       "\t\t\tend\n",
       "",
       "hunt25-rows: a name nobody is on stays clickable",
       expect="hunt25-rows: hidden names are not clickable",
       script=S)

mutate("Prompt/List.lua",
       "\t-- Nobody listed, so nobody to press.\n"
       "\tPrompt:PaintRows(nil)\n",
       "",
       "hunt25-rows: names stay clickable when the prompt comes down",
       expect="hunt25-rows: hidden names are not clickable",
       script=S)

mutate(R,
       "\tlocal clickable = p and p.clickRows ~= false and not S.testMode\n",
       "\tlocal clickable = p and not S.testMode\n",
       "hunt25-rows: the option off still shows the names as buttons",
       expect="hunt25-rows: the click option off leaves the list display-only",
       script=S)

mutate(P,
       "\tif not (entry and entry.buff and entry.name and db and db.prompt.clickRows ~= false) then return end\n",
       "\tif not (entry and entry.buff and entry.name and db) then return end\n",
       "hunt25-rows: the option off still arms a name",
       expect="hunt25-rows: the click option off leaves the list display-only",
       script=S)

mutate("Core.lua",
       "\tboolean(p, \"clickRows\", true)\n",
       "",
       "hunt25-rows: a click option that is not a yes or no kept",
       expect="hunt25-rows: the click option off leaves the list display-only",
       script=S)

mutate("Core.lua",
       "\t\t\tclickRows = true,\n",
       "\t\t\tclickRows = false,\n",
       "hunt25-rows: clicking a name off by default",
       expect="hunt25-rows: the click option off leaves the list display-only",
       script=S)

# ------------------------------------------------ the click areas
mutate(R,
       "\t\tbutton:SetPoint(\"RIGHT\", fs, \"RIGHT\", 4, 0)\n",
       "",
       "hunt25-rows: a name's click area has no width",
       expect="hunt25-rows: every visible name has a click area",
       script=S)

mutate(R,
       "\t\tbutton:SetHeight(pitch)\n",
       "\t\tbutton:SetHeight(1)\n",
       "hunt25-rows: a name's click area is a hairline",
       expect="hunt25-rows: every visible name has a click area",
       script=S)

mutate(R,
       "\t\tbutton:SetPoint(\"LEFT\", fs, \"LEFT\", -reach, 0)\n",
       "\t\tbutton:SetPoint(\"LEFT\", fs, \"LEFT\", reach, 0)\n",
       "hunt25-rows: a name's click area starts inside its text",
       expect="hunt25-rows: every visible name has a click area",
       script=S)

mutate("Prompt/Panel.lua",
       "\tself:PlaceRows(p, look)\n",
       "",
       "hunt25-rows: a look's names have no click area",
       expect="hunt25-rows: every visible name has a click area",
       script=S)

mutate("Prompt/Panel.lua",
       "\tself:PlaceRows(p, nil, 7 + (iconW > 0 and iconW + 3 or 0) + 1)\n",
       "\tself:PlaceRows(p, nil, 0)\n",
       "hunt25-rows: a name's click area leaves out its icon and bar",
       expect="hunt25-rows: every visible name has a click area",
       script=S)

# ------------------------------------------------ the icon and the tooltip
mutate("Prompt/Refresh.lua",
       "\t\t\t\t\ticon = p.showIcon and EntryIcon(entry) or nil,\n",
       "\t\t\t\t\ticon = p.showIcon and EntryIcon(top) or nil,\n",
       "hunt25-rows: every name wears the prompt's icon",
       expect="hunt25-rows: each name wears the icon of its own buff",
       script=S)

mutate("Prompt/Refresh.lua",
       "\t\t\t\t\ticon = p.showIcon and EntryIcon(entry) or nil,\n",
       "\t\t\t\t\ticon = EntryIcon(entry),\n",
       "hunt25-rows: the names keep their icons with the spell icon off",
       expect="hunt25-rows: each name wears the icon of its own buff",
       script=S)

mutate("Prompt/List.lua",
       "\t\tif row and row.icon and not S.activeLook then\n",
       "\t\tif row and row.icon then\n",
       "hunt25-rows: icons drawn under a look that lays the list out itself",
       expect="hunt25-rows: each name wears the icon of its own buff",
       script=S)

mutate("Prompt/Button.lua",
       "\t\tFillTooltip(self, \"ANCHOR_RIGHT\", { current = entry }, row)\n",
       "\t\tFillTooltip(self, \"ANCHOR_RIGHT\", S, row)\n",
       "hunt25-rows: the tooltip over a name describes the prompt's person",
       expect="hunt25-rows: the tooltip over a name is the prompt's for that person",
       script=S)
