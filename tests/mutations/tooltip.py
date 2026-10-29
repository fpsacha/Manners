# The tooltip over the prompt and the names in its list (Prompt/Button.lua,
# tests/scenarios/tooltip.lua): how much it says, Shift, where it goes, and what
# is kept of it. Each fault put back has to be caught by the scenario that names
# it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"
B = "Prompt/Button.lua"
C = "Core.lua"

# ------------------------------------------------ the defaults and the repair
mutate(C,
       '\t\t\ttooltip = "short",\n',
       '\t\t\ttooltip = "full",\n',
       "tooltip: the default is the full tooltip",
       expect="tooltip: a new profile gets the short tooltip",
       script=S)

mutate(C,
       '\t\t\ttooltipPosition = "beside",\n',
       '\t\t\ttooltipPosition = "game",\n',
       "tooltip: the default position is the game's corner",
       expect="tooltip: a new profile gets the short tooltip",
       script=S)

mutate(C,
       '\toneOf(p, "tooltip", { full = true, short = true, shift = true, off = true }, "short")\n',
       '',
       "tooltip: a damaged setting is kept",
       expect="tooltip: a damaged setting is put back by ClampSettings",
       script=S)

mutate(C,
       '\toneOf(p, "tooltip", { full = true, short = true, shift = true, off = true }, "short")\n',
       '\toneOf(p, "tooltip", { full = true, short = true, shift = true, off = true }, "full")\n',
       "tooltip: a damaged setting is repaired to the full tooltip",
       expect="tooltip: a damaged setting is put back by ClampSettings",
       script=S)

mutate(C,
       '\toneOf(p, "tooltipPosition", { beside = true, game = true }, "beside")\n',
       '',
       "tooltip: a damaged position is kept",
       expect="tooltip: a damaged setting is put back by ClampSettings",
       script=S)

mutate(C,
       '\toneOf(p, "tooltip", { full = true, short = true, shift = true, off = true }, "short")\n',
       '\toneOf(p, "tooltip", { full = true, short = true, shift = true }, "short")\n',
       "tooltip: off is not a setting the repair knows",
       expect="tooltip: a damaged setting is put back by ClampSettings",
       script=S)

# ------------------------------------------------ how much each setting says
mutate(B,
       '\tif mode == "off" then return nil end\n',
       '',
       "tooltip: off still shows the tooltip",
       expect="tooltip: off shows nothing over the prompt",
       script=S)

mutate(B,
       '\tif mode == "full" or ShiftHeld() then return "full" end\n',
       '\tif mode == "full" then return "full" end\n',
       "tooltip: Shift never opens the full tooltip",
       expect="tooltip: Shift switches the short tooltip to the full one and back, live",
       script=S)

mutate(B,
       '\tif mode == "shift" then return nil end\n',
       '',
       "tooltip: only-with-Shift shows the short one without Shift",
       expect="tooltip: only while holding Shift shows nothing until Shift is held",
       script=S)

mutate(B,
       '\tif brief then return end\n\t-- Why they are ahead of the others like them',
       '\t-- Why they are ahead of the others like them',
       "tooltip: the short tooltip keeps every reason line",
       expect="tooltip: short on the prompt says what that setting says",
       script=S)

mutate(B,
       '\tGameTooltip:AddLine(count, 0.7, 0.7, 0.7, true)\n\tif brief then return end\n',
       '\tGameTooltip:AddLine(count, 0.7, 0.7, 0.7, true)\n',
       "tooltip: the short tooltip of a group cast keeps the rest",
       expect="tooltip: the short tooltip is for a group cast too",
       script=S)

mutate(B,
       '\t\tif not brief then GameTooltip:AddLine("Manners") end\n',
       '\t\tGameTooltip:AddLine("Manners")\n',
       "tooltip: the short tooltip carries the title",
       expect="tooltip: short on the prompt says what that setting says",
       script=S)

mutate(B,
       '\t\t\tGameTooltip:AddLine(L["Hold Shift for more"], 0.5, 0.5, 0.5)\n',
       '',
       "tooltip: the short tooltip does not say Shift gives more",
       expect="tooltip: short on the prompt says what that setting says",
       script=S)

mutate(B,
       '\t\tif brief then\n\t\t\tGameTooltip:AddLine(L["Hold Shift for more"], 0.5, 0.5, 0.5)\n\t\t\tGameTooltip:Show()\n\t\t\treturn\n\t\tend\n',
       '\t\tif brief then\n\t\t\tGameTooltip:AddLine(L["Hold Shift for more"], 0.5, 0.5, 0.5)\n\t\tend\n',
       "tooltip: the short tooltip goes on into the long one",
       expect="tooltip: short on the prompt says what that setting says",
       script=S)

# ------------------------------------------------ Shift, only while hovering
mutate(B,
       '\tif mode == "full" or mode == "off" then\n\t\t-- Nothing Shift could change. Whatever was watched stays until leave.\n\t\treturn\n\tend\n',
       '',
       "tooltip: Shift watched under full and off too",
       expect="tooltip: full has nothing to watch Shift for",
       script=S)

mutate(B,
       '\twatched, watchedHeld = nil, nil\n\twatcher:UnregisterEvent("MODIFIER_STATE_CHANGED")\n',
       '\twatched, watchedHeld = nil, nil\n',
       "tooltip: Shift still watched after the cursor leaves",
       expect="tooltip: Shift is watched only while the cursor is on the prompt",
       script=S)

mutate(B,
       '\tlocal function OnLeave(self)\n\t\tUnwatchShift(self)\n',
       '\tlocal function OnLeave(self)\n',
       "tooltip: the prompt's leave does not stop watching Shift",
       expect="tooltip: Shift is watched only while the cursor is on the prompt",
       script=S)

mutate(B,
       '\t\trow.hovered = nil\n\t\tUnwatchShift(self)\n',
       '\t\trow.hovered = nil\n',
       "tooltip: a name's leave does not stop watching Shift",
       expect="tooltip: Shift over a name in the list works live and stops on leave",
       script=S)

mutate(B,
       '\t\tS.hovering = true\n\t\tif S.activeLook then S.activeLook:Hover(true) end\n\t\tWatchShift(self)\n',
       '\t\tS.hovering = true\n\t\tif S.activeLook then S.activeLook:Hover(true) end\n',
       "tooltip: the prompt does not watch Shift",
       expect="tooltip: Shift switches the short tooltip to the full one and back, live",
       script=S)

mutate(B,
       '\t\trow.hovered = true\n\t\tWatchShift(self)\n\t\tif InCombatLockdown() then return end\n\t\tif row.wash',
       '\t\trow.hovered = true\n\t\tif InCombatLockdown() then return end\n\t\tif row.wash',
       "tooltip: a name does not watch Shift",
       expect="tooltip: Shift over a name in the list works live and stops on leave",
       script=S)

mutate(B,
       '\tif held == watchedHeld then return end\n',
       '',
       "tooltip: any modifier key rebuilds the tooltip",
       expect="tooltip: Shift switches the short tooltip to the full one and back, live",
       script=S)

mutate(B,
       '\tif watched ~= owner then watchedHeld = ShiftHeld() end\n',
       '',
       "tooltip: the watch does not read Shift as the cursor arrives",
       expect="tooltip: only while holding Shift shows nothing until Shift is held",
       script=S)

# ------------------------------------------------ the drag and the fight
mutate(B,
       '\t\tif DragPanelUp() then\n\t\t\tDragTooltip(self)\n\t\t\treturn\n\t\tend\n',
       '\t\tif DragPanelUp() and ns.db.profile.prompt.tooltip ~= "off" then\n\t\t\tDragTooltip(self)\n\t\t\treturn\n\t\tend\n',
       "tooltip: off takes the drag tooltip away too",
       expect="tooltip: the drag tooltip stays under off",
       script=S)

mutate(B,
       '\t\tif InCombatLockdown() then return end\n\t\tShowTip(self, "ANCHOR_TOP", S, S)\n',
       '\t\tShowTip(self, "ANCHOR_TOP", S, S)\n',
       "tooltip: the prompt's tooltip in a fight",
       expect="tooltip: nothing shows in a fight under",
       script=S)

# ------------------------------------------------ where
mutate(B,
       '\tif ns.db.profile.prompt.tooltipPosition == "game" and',
       '\tif ns.db.profile.prompt.tooltipPosition ~= "game" and',
       "tooltip: the position choices swapped",
       expect="tooltip: where the game shows tooltips hands the placing to the client",
       script=S)

mutate(B,
       '\tif ns.db.profile.prompt.tooltipPosition == "game" and type(GameTooltip_SetDefaultAnchor) == "function" then\n',
       '\tif ns.db.profile.prompt.tooltipPosition == "game" then\n',
       "tooltip: no fallback without the client's default anchor",
       expect="tooltip: a client without a default anchor falls back to the old one",
       script=S)

mutate(B,
       '\tlocal above = roomAbove >= roomBelow\n',
       '\tlocal above = roomAbove < roomBelow\n',
       "tooltip: the tooltip takes the side with less room",
       expect="tooltip: beside the prompt takes the roomier side",
       script=S)

mutate(B,
       '\tlocal above = roomAbove >= roomBelow\n',
       '\tlocal above = true\n',
       "tooltip: the tooltip is always above",
       expect="tooltip: beside the prompt takes the roomier side, high on the screen",
       script=S)

mutate(B,
       '\tlocal reach = TIP_GAP + (above == listAbove and depth or 0)\n',
       '\tlocal reach = TIP_GAP\n',
       "tooltip: the tooltip covers the list",
       expect="tooltip: beside the prompt takes the roomier side, low on the screen",
       script=S)

mutate(B,
       '\tlocal reach = TIP_GAP + (above == listAbove and depth or 0)\n',
       '\tlocal reach = TIP_GAP + depth\n',
       "tooltip: the tooltip keeps clear of a list that is on the other side",
       expect="tooltip: beside the prompt takes the roomier side, just under the middle",
       script=S)

mutate(B,
       '\t\tGameTooltip:SetPoint("BOTTOM", button, "TOP", 0, reach * toTip)\n',
       '\t\tGameTooltip:SetPoint("BOTTOM", owner, "TOP", 0, reach * toTip)\n',
       "tooltip: a name's tooltip hung on the name",
       expect="tooltip: beside the prompt takes the roomier side",
       script=S)

mutate(B,
       '\tlocal roomBelow = bottom * ratio - (listAbove and 0 or depth * ratio)\n',
       '\tlocal roomBelow = bottom * ratio\n',
       "tooltip: the list's room is not counted",
       expect="tooltip: beside the prompt takes the roomier side",
       script=S)

mutate("Prompt/Rows.lua",
       '\treturn 4 + listed * placedPitch\n',
       '\treturn 0\n',
       "tooltip: the list has no reach",
       expect="tooltip: beside the prompt takes the roomier side, low on the screen",
       script=S)

mutate("Prompt/Rows.lua",
       '\tlisted = rows and #rows or 0\n',
       '',
       "tooltip: the list's length is never learned",
       expect="tooltip: beside the prompt takes the roomier side, low on the screen",
       script=S)

# ------------------------------------------------ the options, the reset, sharing
mutate("Options/Look.lua",
       '\t\t\t\tsorting = { "short", "full", "shift", "off" },\n',
       '\t\t\t\tsorting = { "full", "short", "shift", "off" },\n',
       "tooltip: the Look tab leads with the full tooltip",
       expect="tooltip: the Look tab offers the choices, short first",
       script=S)

mutate("Options/Look.lua",
       '\t\t\t\tdisabled = function() return P().tooltip == "off" end,\n',
       '',
       "tooltip: the position stays live with the tooltip off",
       expect="tooltip: the Look tab offers the choices, short first",
       script=S)

mutate("Options/Advanced.lua",
       '\t\t"prompt.tooltip", "prompt.tooltipPosition",\n',
       '',
       "tooltip: the Look reset leaves the tooltip alone",
       expect="tooltip: the Look page's reset puts the tooltip back",
       script=S)

mutate("Commands.lua",
       '\t\t["prompt.locked"] = true,\n',
       '\t\t["prompt.locked"] = true,\n\t\t["prompt.tooltip"] = true,\n',
       "tooltip: the setting is left out of an exported profile",
       expect="tooltip: the settings travel in an exported profile",
       script=S)

mutate("Locales/deDE.lua",
       'L["Hold Shift for more"] = "Umschalt für mehr"\n',
       '',
       "tooltip: a language without the hint",
       expect="tooltip: every language has the tooltip's words",
       script=S)

mutate("Locales/zhTW.lua",
       'L["Only while holding Shift"] = "僅在按住 Shift 時"\n',
       '',
       "tooltip: a language without a choice's name",
       expect="tooltip: every language has the tooltip's words",
       script=S)
