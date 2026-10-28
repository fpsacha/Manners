# Mutations for the prompt on an action bar and on a controller: the button that
# puts the macro on the cursor (Clicks.lua, Options/Start.lua), the slot that
# shows what a press would cast (Clicks.lua's SetMacroSpell and SetMacroItem,
# armed from Prompt/Macro.lua), and the key chip's words for a gamepad button
# (Looks/Looks.lua and the chip of each look). Each undoes one rule and is
# caught by the scenario in tests/scenarios/actionbar.lua (or hunt19-options.lua)
# it names.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"
BUTTON = "actionbar: the options button makes the macro and puts it on the cursor"
COMBAT = "actionbar: in combat the button refuses and changes nothing"
FOLLOWS = "actionbar: the macro's slot follows what the prompt's top entry casts"
NOBODY = "actionbar: with nobody to buff the slot shows the macro's own icon"
FIGHT = "actionbar: nothing is set in a fight, and the slot is caught up after"
MOVED = "actionbar: a macro moved in a fight has its spell set once the fight ends"
BYHAND = "actionbar: a macro made by hand gets the spell, and none is set where it is not"
ROWS = "actionbar: a list row's macro is not what the slot shows"
NOMACRO = "actionbar: with no macro a scan asks the client nothing either"
GLYPH = "actionbar: a gamepad button on the chip reads as its glyph, short"
FITS = "actionbar: the key chip with a controller's buttons fits in every look"

# ------------------------------------------------------------ the slot

# Set in a fight, where the client refuses the call.
mutate("Clicks.lua",
       "\t\tif slot.want == nil or slot.want == slot.shown or InCombatLockdown() then return end\n",
       "\t\tif slot.want == nil or slot.want == slot.shown then return end\n",
       "actionbar: the slot is set in a fight",
       expect=FIGHT, script=S)

# Set again for what it shows already, on every arming.
mutate("Clicks.lua",
       "\t\tif slot.want == nil or slot.want == slot.shown or InCombatLockdown() then return end\n",
       "\t\tif slot.want == nil or InCombatLockdown() then return end\n",
       "actionbar: the slot is set again for what it shows",
       expect=FOLLOWS, script=S)

# A macro that is not there asked for a spell.
mutate("Clicks.lua",
       "\t\tif slot.index == 0 then return end\n",
       "",
       "actionbar: the slot is set on a macro that is not there",
       expect=NOMACRO, script=S)

# The macro's place asked for again at every change, not once.
mutate("Clicks.lua",
       "\t\tif slot.index == nil then slot.index = safecall(_G.GetMacroIndexByName, MACRO_NAME) or 0 end\n",
       "\t\tslot.index = safecall(_G.GetMacroIndexByName, MACRO_NAME) or 0\n",
       "actionbar: the macro's place asked for at every change",
       expect=NOMACRO, script=S)

# A scroll or enhancement never put on the slot.
mutate("Clicks.lua",
       "\t\telseif kind == \"item\" and type(setItem) == \"function\" then\n",
       "\t\telseif false then\n",
       "actionbar: an item is never put on the slot",
       expect=FOLLOWS, script=S)

# The item handed over without its "item:" form.
mutate("Clicks.lua",
       "\t\t\tslot.item = pcall(setItem, slot.index, \"item:\" .. value)\n",
       "\t\t\tslot.item = pcall(setItem, slot.index, value)\n",
       "actionbar: the item is handed over bare",
       expect=FOLLOWS, script=S)

# A spell left on the slot under a scroll.
mutate("Clicks.lua",
       "\t\tif kind ~= \"spell\" and slot.spell and type(setSpell) == \"function\" then\n",
       "\t\tif false then\n",
       "actionbar: the spell stays under a scroll",
       expect=FOLLOWS, script=S)

# An item left on the slot under a spell.
mutate("Clicks.lua",
       "\t\tif kind ~= \"item\" and slot.item and type(setItem) == \"function\" then\n",
       "\t\tif false then\n",
       "actionbar: the item stays under a spell",
       expect=FOLLOWS, script=S)

# Nobody to buff leaves the last spell on the slot.
mutate("Clicks.lua",
       "\t\tif not (entry and entry.buff) then return \"\" end\n",
       "\t\tif not (entry and entry.buff) then return nil end\n",
       "actionbar: nobody to buff leaves the slot as it was",
       expect=NOBODY, script=S)

# A macro made by hand, deleted or moved: told again whatever its place.
mutate("Clicks.lua",
       "\t\tif index ~= slot.index then\n",
       "\t\tif true then\n",
       "actionbar: every UPDATE_MACROS sets the spell again",
       expect=BYHAND, script=S)

mutate("Clicks.lua",
       "\t\t\tslot.index, slot.shown, slot.spell, slot.item = index, nil, true, true\n",
       "\t\t\tslot.index, slot.shown, slot.spell, slot.item = index, slot.shown, slot.spell, slot.item\n",
       "actionbar: a macro made again is thought to show its spell",
       expect=BYHAND, script=S)

# Not asked again once a fight ends.
mutate("Core.lua",
       "\tif ns.ResyncMacroSlot then ns.Guard(\"macro slot\", ns.ResyncMacroSlot) end\n",
       "",
       "actionbar: the slot is not caught up after a fight",
       expect=MOVED, script=S)

# The event never listened for.
mutate("Core.lua",
       "\t\t\"UPDATE_MACROS\",\n",
       "",
       "actionbar: UPDATE_MACROS is not listened for",
       expect=BYHAND, script=S)

# ------------------------------------------------------------ armed from the prompt

mutate("Prompt/Macro.lua",
       "\tif not S.isRow then ns.SyncMacroSlot(entry) end\n",
       "",
       "actionbar: arming the prompt never sets the slot",
       expect=FOLLOWS, script=S)

# A list row's macro taken for the prompt's.
mutate("Prompt/Macro.lua",
       "\tif not S.isRow then ns.SyncMacroSlot(entry) end\n",
       "\tns.SyncMacroSlot(entry)\n",
       "actionbar: a list row sets the slot",
       expect=ROWS, script=S)

mutate("Prompt/Macro.lua",
       "\t\tif not S.isRow then ns.SyncMacroSlot(nil) end\n\t\treturn\n",
       "\t\tns.SyncMacroSlot(nil)\n\t\treturn\n",
       "actionbar: a disarmed list row clears the slot",
       expect=ROWS, script=S)

mutate("Prompt/Macro.lua",
       "\t\tif not S.isRow then ns.SyncMacroSlot(nil) end\n\t\treturn\n",
       "\t\treturn\n",
       "actionbar: an emptied prompt never clears the slot",
       expect=NOBODY, script=S)

# ------------------------------------------------------------ the button

# Made in a fight.
mutate("Clicks.lua",
       "\tif InCombatLockdown() then\n\t\taddon:Print(\"|cffff8080\" .. L[\"cannot touch macros in combat.\"]",
       "\tif false then\n\t\taddon:Print(\"|cffff8080\" .. L[\"cannot touch macros in combat.\"]",
       "actionbar: the macro is made and picked up in a fight",
       expect=COMBAT, script=S)

# Made, but never asked to show its spell.
mutate("Clicks.lua",
       "\tns.ResyncMacroSlot(true)\n\tlocal pickup = _G.PickupMacro\n",
       "\tlocal pickup = _G.PickupMacro\n",
       "actionbar: a macro just made shows no spell",
       expect=BUTTON, script=S)

# Never put on the cursor.
mutate("Clicks.lua",
       "\t\tpcall(pickup, index)\n",
       "",
       "actionbar: the macro is never picked up",
       expect=BUTTON, script=S)

# The cursor trusted without a look at it.
mutate("Clicks.lua",
       "\t\tif type(_G.GetCursorInfo) ~= \"function\" or _G.GetCursorInfo() == \"macro\" then\n",
       "\t\tif true then\n",
       "actionbar: a refused pick-up is called a success",
       expect="a client that refuses the pick-up opens the macro window", script=S)

# Nothing said, nothing remembered.
mutate("Clicks.lua",
       "\t\t\tns.macroOnCursor = true\n",
       "",
       "actionbar: the pick-up is not remembered",
       expect=BUTTON, script=S)

mutate("Clicks.lua",
       "\t\t\taddon:Print(L[\"macro |cffffd100%s|r is on your cursor. Drop it on any action bar slot.\"]:format(MACRO_NAME))\n",
       "",
       "actionbar: the pick-up is not said",
       expect=BUTTON, script=S)

# Start here: the hint, and when it goes.
mutate("Options/Start.lua",
       "\t\t\t\t\tif Setup.Carrying() then\n",
       "\t\t\t\t\tif false then\n",
       "actionbar: Start here never says where to drop it",
       expect=BUTTON, script=S)

mutate("Options/Start.lua",
       "\tif not ns.macroOnCursor then return false end\n",
       "\tif not ns.macroOnCursor then return true end\n",
       "actionbar: Start here says where to drop it always",
       expect="start here: step 2 puts the prompt on a key", script=S)

mutate("Options/Start.lua",
       "\tns.macroOnCursor = false\n\treturn false\n",
       "\treturn false\n",
       "actionbar: the pick-up is remembered once dropped",
       expect=BUTTON, script=S)

mutate("Options/Window/Window.lua",
       "\tif ns.macroOnCursor and UI.Shown() and not ns.Setup.Carrying() then UI.Refresh() end\n",
       "\tif false then UI.Refresh() end\n",
       "actionbar: a drop on a bar does not repaint Start here",
       expect="hunt19-options: /manners macro repaints Start here", script=S)

mutate("Options/Window/Window.lua",
       "\tpcall(f.RegisterEvent, f, \"CURSOR_CHANGED\")\n",
       "",
       "actionbar: the window never hears the cursor change",
       expect="hunt19-options: /manners macro repaints Start here", script=S)

# ------------------------------------------------------------ the controller

mutate("Looks/Looks.lua",
       "\t\tif key:find(\"PAD\", 1, true) and key:find(\"-\", 1, true) then\n",
       "\t\tif false then\n",
       "actionbar: a pad button with a modifier reads s- and a glyph",
       expect=GLYPH, script=S)

mutate("Looks/Looks.lua",
       "\tlocal EMULATE = { SHIFT = \"GamePadEmulateShift\", CTRL = \"GamePadEmulateCtrl\", ALT = \"GamePadEmulateAlt\" }\n",
       "\tlocal EMULATE = { SHIFT = \"GamePadEmulateCtrl\", CTRL = \"GamePadEmulateShift\", ALT = \"GamePadEmulateAlt\" }\n",
       "actionbar: Shift and Ctrl swapped for a pad button",
       expect=GLYPH, script=S)

mutate("Looks/Looks.lua",
       "\t\t\tif type(button) ~= \"string\" or not button:match(\"^PAD\") then return nil end\n",
       "\t\t\tif type(button) ~= \"string\" then return nil end\n",
       "actionbar: a modifier on no pad button is read as one",
       expect=GLYPH, script=S)

mutate("Looks/Looks.lua",
       "\t\tlocal text = GetBindingText(key, true)\n",
       "\t\tlocal text = GetBindingText(key)\n",
       "actionbar: the chip takes the glyph drawn at 24 pixels",
       expect=GLYPH, script=S)

mutate("Looks/Looks.lua",
       "\t\tif type(GetBindingText) ~= \"function\" or type(key) ~= \"string\" then return nil end\n",
       "\t\tif type(key) ~= \"string\" then return nil end\n",
       "actionbar: a client with no key texts throws on the chip",
       expect=GLYPH, script=S)

mutate("Looks/Looks.lua",
       "\t\t\tif key ~= comboKey or made ~= comboMade then comboKey, comboMade, comboText = key, made, PadCombo(key) or false end\n",
       "\t\t\tif false then comboKey, comboMade, comboText = key, made, PadCombo(key) or false end\n",
       "actionbar: a pad combination is never worked out",
       expect=GLYPH, script=S)

# Each look's chip is as wide as its words.
mutate("Looks/Arcane.lua",
       "\t\tlocal w = math.max(self.keyH, math.floor(width + 9 + 0.5))\n",
       "\t\tlocal w = math.max(self.keyH, 9)\n",
       "actionbar: Arcane's chip is too narrow for its glyphs",
       expect=FITS + ": arcane", script=S)

mutate("Looks/Toast.lua",
       "\t\t\tlocal w = math.max(self.chipH * 1.75, (kit.TextWidth(self.keyText) or self.sub) + 10)\n",
       "\t\t\tlocal w = math.max(self.chipH * 1.75, 0)\n",
       "actionbar: Toast's chip is too narrow for its glyphs",
       expect=FITS + ": toast", script=S)

mutate("Looks/Ribbon.lua",
       "\t\t\tlocal w = math.max(self.chipH * 1.75, (kit.TextWidth(self.keyText) or self.sub) + 10)\n",
       "\t\t\tlocal w = math.max(self.chipH * 1.75, 0)\n",
       "actionbar: Ribbon's tag is too narrow for its glyphs",
       expect=FITS + ": ribbon", script=S)

mutate("Looks/Letter.lua",
       "\t\t\tself.keyW = math.ceil(math.max(h * 1.7, (kit.TextWidth(self.keyText) or self.sub) + 10))\n",
       "\t\t\tself.keyW = math.ceil(math.max(h * 1.7, 0))\n",
       "actionbar: Letter's slip is too narrow for its glyphs",
       expect=FITS + ": letter", script=S)

mutate("Looks/Leather.lua",
       "\t\t\tlocal w = math.max(self.chipW2, (kit.TextWidth(self.keyText) or self.sub) + 10)\n",
       "\t\t\tlocal w = math.max(self.chipW2, 0)\n",
       "actionbar: Leather's patch is too narrow for its glyphs",
       expect=FITS + ": leather", script=S)
