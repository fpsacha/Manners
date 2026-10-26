-- The prompt on an action bar, and on a controller (Clicks.lua's macro section,
-- Options/Start.lua's button, Looks/Looks.lua's ShortKey).
--
--   * Put Manners on an action bar makes or refreshes the macro and puts it on
--     the cursor, so a drop on any slot of any bar finishes it; /manners macro
--     does the same; in a fight neither touches anything;
--   * the macro's slot on a bar shows what a press would cast, through
--     SetMacroSpell (a spell) and SetMacroItem (a scroll or an enhancement from
--     the bags), set when what the prompt's top entry casts changes and not
--     again, never in a fight, and cleared to the macro's own icon with nobody
--     to buff;
--   * a gamepad button bound to the prompt's click presses it, and the key's
--     chip on every look that has one reads such a button, with or without a
--     modifier, short and inside the prompt.
--
-- Every name starts with "actionbar:" so a mutation in
-- tests/mutations/actionbar.py can name exactly one.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local COMMAND = "CLICK MannersPrompt:LeftButton"
local BODY = "/click MannersPrompt LeftButton 1"
local ANNA = { nameplate1 = { "Anna", "Aim" } }
local FLAVOURS = { "camelot", "vanilla", "tbc", "mists", "mainline" }

local function said() return table.concat(Mock.printed, "\n") end
local function macroIndex() return GetMacroIndexByName("Manners") end

-- The globals a scenario replaces, put back whatever happens.
local TOUCHED = { "SetMacroSpell", "SetMacroItem", "PickupMacro", "GetCursorInfo", "ClearCursor",
	"GetCVar", "GetBindingText", "GetMacroIndexByName", "ShowMacroFrame" }

local function with(scenario, body, flavour, tree)
	Mock.reset()
	if flavour then Mock.setFlavour(flavour) end
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	if tree then FT.install() end
	-- Anna alone on a nameplate; a copy, as the scenario may send her away.
	local restore = strangers({ nameplate1 = { ANNA.nameplate1[1], ANNA.nameplate1[2] } })
	local ns = load(scenario)
	local ok, err = true, nil
	if ns then ok, err = pcall(body, ns, scenario) end
	restore()
	if tree then FT.uninstall() end
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- The prompt armed at Anna, who is owed the mage's one buff.
local function armed(ns, scenario)
	freshPrompt(ns, scenario)
	owe(ns, "Anna Aim")
	ns.addon:Tick()
end

local function castLine(ns)
	local macro = ns.Prompt:GetButton():GetAttribute("macrotext1")
	return macro and macro:match("/cast ([^\n]+)")
end

-- A made-up top entry for the prompt: a spell is its buff's key (what the
-- addon names an unknown buff by), a scroll its item.
local function spellEntry(spell, who)
	return { name = who or "Anna Aim", unit = "nameplate1", reason = "owed", buff = { key = spell } }
end
local function scrollEntry(item)
	return { name = "Mort Stonewell", unit = "player", reason = "self", buff = { key = "scroll" .. item, item = item } }
end

-- Everybody paid and gone, and the prompt run empty: the panel's hold lets go
-- after a few seconds.
local function empty(ns)
	wipe(ns.owed)
	Mock.unitNames.nameplate1 = nil
	ns.nameplateUnits.nameplate1 = nil
	for _ = 1, 20 do
		Mock.advance(3)
		ns.addon:Tick()
		if not ns.Prompt:GetButton():GetAttribute("type1") then return true end
	end
	return false
end

local function makeButton(ns) return ns.optionsTable.args.general.args.makeMacro end
local function statusLine(ns) return H.optionText(ns.optionsTable.args.general.args.bindStatus.name) end

local function slotOf(index) return Mock.macroList[index] end

-- ------------------------------------------------------------------ 1
-- The button makes the macro, puts it on the cursor, and says where to drop it.
with("actionbar: the options button makes the macro and puts it on the cursor", function(ns, scenario)
	armed(ns, scenario)
	local spell = castLine(ns)
	if not spell then fail(scenario, "SKIPPED -- the prompt is not armed at Anna") return end
	local make = makeButton(ns)
	if H.optionText(make.name) ~= "Put Manners on an action bar" then
		fail(scenario, "the button reads " .. H.optionText(make.name))
	end
	if macroIndex() ~= 0 then fail(scenario, "SKIPPED -- a macro was there already") return end
	make.func({ "makeMacro" })
	local index = macroIndex()
	if index == 0 then fail(scenario, "the button made no macro") return end
	local name, icon, body = GetMacroInfo(index)
	if body ~= BODY then fail(scenario, "the macro's body is " .. tostring(body)) end
	if icon ~= "INV_MISC_NOTE_03" then fail(scenario, "the macro's own icon is " .. tostring(icon)) end
	local kind, id = GetCursorInfo()
	if kind ~= "macro" or id ~= index then
		fail(scenario, "the macro is not on the cursor after the button: " .. tostring(kind) .. " " .. tostring(id))
	end
	if not said():find("Drop it on any action bar slot", 1, true) then
		fail(scenario, "the chat line does not say where to drop it: " .. said())
	end
	if not statusLine(ns):find("Drop it on any action bar slot.", 1, true) then
		fail(scenario, "Start here does not say where to drop it: " .. statusLine(ns))
	end
	-- Dropped on a slot of a bar: the slot draws the spell a press would cast.
	if not Mock.dropOnBar(7) then fail(scenario, "SKIPPED -- the drop was refused") return end
	local shows, what = Mock.slotShows(7)
	if shows ~= "spell" or what ~= spell then
		fail(scenario, ("the slot shows %s %s, not the spell %s"):format(tostring(shows), tostring(what), spell))
	end
	if statusLine(ns):find("Drop it on any action bar slot.", 1, true) then
		fail(scenario, "Start here still says where to drop it once the macro is on a bar")
	end
	if ns.macroOnCursor then fail(scenario, "the macro is still said to be on the cursor once it is on a bar") end
	-- Pressed again: the one macro, its body put right, on the cursor again.
	EditMacro(index, nil, nil, "/mine")
	make.func({ "makeMacro" })
	local account, character = GetNumMacros()
	if account + character ~= 1 then fail(scenario, "a second press made a second macro") end
	if select(3, GetMacroInfo(index)) ~= BODY then fail(scenario, "a second press left the body as it was changed") end
	if GetCursorInfo() ~= "macro" then fail(scenario, "a second press did not put the macro on the cursor") end
	-- The slash command does the same.
	ClearCursor()
	ns.addon:HandleSlash("macro")
	if GetCursorInfo() ~= "macro" then fail(scenario, "/manners macro did not put the macro on the cursor") end
end)

-- ------------------------------------------------------------------ 2
-- In a fight nothing is touched.
with("actionbar: in combat the button refuses and changes nothing", function(ns, scenario)
	armed(ns, scenario)
	local button = ns.Prompt:GetButton()
	local armedWith = button:GetAttribute("macrotext1")
	local protectedBefore = #Mock.protectedCalls
	local make = makeButton(ns)
	Mock.inCombat = true
	Mock.printed = {}
	make.func({ "makeMacro" })
	ns.addon:HandleSlash("macro")
	if macroIndex() ~= 0 then fail(scenario, "a macro was made in a fight") end
	if GetCursorInfo() ~= nil then fail(scenario, "something is on the cursor after a fight's press") end
	if not said():find("cannot touch macros in combat", 1, true) then
		fail(scenario, "no refusal was said: " .. said())
	end
	if #Mock.blockedCalls ~= 0 then
		fail(scenario, "the client was asked for " .. table.concat(Mock.blockedCalls, ", ") .. " in a fight")
	end
	-- A macro already there is not edited or picked up either.
	Mock.inCombat = false
	ns.CreateClickMacro()
	ClearCursor()
	ns.macroOnCursor = nil
	local index = macroIndex()
	EditMacro(index, nil, nil, "/mine")
	Mock.inCombat = true
	Mock.printed = {}
	make.func({ "makeMacro" })
	if select(3, GetMacroInfo(index)) ~= "/mine" then fail(scenario, "the macro was edited in a fight") end
	if GetCursorInfo() ~= nil then fail(scenario, "the macro was picked up in a fight") end
	if #Mock.blockedCalls ~= 0 then
		fail(scenario, "the client was asked for " .. table.concat(Mock.blockedCalls, ", ") .. " in a fight")
	end
	if button:GetAttribute("macrotext1") ~= armedWith or #Mock.protectedCalls ~= protectedBefore then
		fail(scenario, "the secure button was touched")
	end
	Mock.inCombat = false
end)

-- ------------------------------------------------------------------ 3
-- The slot follows the prompt's top entry, and only a change of what it casts.
with("actionbar: the macro's slot follows what the prompt's top entry casts", function(ns, scenario)
	armed(ns, scenario)
	local spell = castLine(ns)
	ns.CreateClickMacro()
	local index = macroIndex()
	if index == 0 or not spell then fail(scenario, "SKIPPED -- no macro or no spell") return end
	if slotOf(index).spell ~= spell then
		fail(scenario, ("the slot's spell is %s, the prompt casts %s"):format(tostring(slotOf(index).spell), spell))
	end
	if slotOf(index).body ~= nil and slotOf(index).body ~= BODY then fail(scenario, "the body changed") end
	-- The same spell at somebody else: no call at all.
	local calls = (Mock.macroSpellCalls or 0) + (Mock.macroItemCalls or 0)
	ns.Prompt:ApplyTarget(spellEntry(spell, "Bert Beside"))
	if (Mock.macroSpellCalls or 0) + (Mock.macroItemCalls or 0) ~= calls then
		fail(scenario, "the slot was set again for the same spell at somebody else")
	end
	-- Another spell.
	ns.Prompt:ApplyTarget(spellEntry("Power Word: Fortitude"))
	if slotOf(index).spell ~= "Power Word: Fortitude" then
		fail(scenario, "the slot's spell is " .. tostring(slotOf(index).spell) .. " under Fortitude")
	end
	-- A scroll: the item, and no spell.
	ns.Prompt:ApplyTarget(scrollEntry(275069))
	if slotOf(index).item ~= "item:275069" then
		fail(scenario, "the slot's item is " .. tostring(slotOf(index).item) .. " under a scroll")
	end
	if slotOf(index).spell ~= nil then
		fail(scenario, "the slot kept the spell " .. tostring(slotOf(index).spell) .. " under a scroll")
	end
	if select(1, Mock.slotShows(1) or "none") ~= "none" then fail(scenario, "SKIPPED -- the macro is on a bar already") end
	-- Back to a spell: the item goes.
	ns.Prompt:ApplyTarget(spellEntry("Arcane Intellect"))
	if slotOf(index).item ~= nil or slotOf(index).spell ~= "Arcane Intellect" then
		fail(scenario, ("the slot holds %s and %s after a spell again"):format(
			tostring(slotOf(index).spell), tostring(slotOf(index).item)))
	end
	-- A press settling nothing and a repaint: the same entry, no call.
	calls = (Mock.macroSpellCalls or 0) + (Mock.macroItemCalls or 0)
	for _ = 1, 5 do ns.Prompt:ApplyTarget(spellEntry("Arcane Intellect")) end
	if (Mock.macroSpellCalls or 0) + (Mock.macroItemCalls or 0) ~= calls then
		fail(scenario, "the slot was set again for an entry that had not changed")
	end
end)

-- ------------------------------------------------------------------ 4
-- With nobody to buff the slot goes back to the macro's own icon.
with("actionbar: with nobody to buff the slot shows the macro's own icon", function(ns, scenario)
	armed(ns, scenario)
	ns.CreateClickMacro()
	local index = macroIndex()
	if index == 0 then fail(scenario, "SKIPPED -- no macro") return end
	Mock.dropOnBar(3)
	if select(1, Mock.slotShows(3)) ~= "spell" then fail(scenario, "SKIPPED -- the slot shows no spell to begin with") return end
	if not empty(ns) then fail(scenario, "SKIPPED -- the prompt never emptied") return end
	local shows, what = Mock.slotShows(3)
	if shows ~= "icon" or what ~= "INV_MISC_NOTE_03" then
		fail(scenario, ("with nobody to buff the slot shows %s %s"):format(tostring(shows), tostring(what)))
	end
	-- A scroll, then nobody: the item goes too.
	ns.Prompt:ApplyTarget(scrollEntry(275069))
	if select(1, Mock.slotShows(3)) ~= "item" then fail(scenario, "SKIPPED -- the scroll is not on the slot") return end
	ns.Prompt:ApplyTarget(nil)
	if select(1, Mock.slotShows(3)) ~= "icon" then
		fail(scenario, "the slot still shows the scroll with nobody to buff")
	end
	-- A fresh login with nobody to buff clears what an earlier session left:
	-- the game says the macros are there, and the slot holds a spell still.
	local fresh = load(scenario)
	if fresh then
		freshPrompt(fresh, scenario)
		Mock.macroList[index] = { name = "Manners", icon = "INV_MISC_NOTE_03", body = BODY, spell = "Stale Spell" }
		fresh.addon:UPDATE_MACROS()
		fresh.addon:Tick()
		if slotOf(index).spell ~= nil then
			fail(scenario, "a login with nobody to buff left " .. tostring(slotOf(index).spell) .. " on the slot")
		end
	end
end)

-- ------------------------------------------------------------------ 5
-- Nothing is asked of the client in a fight, and the slot is caught up after.
with("actionbar: nothing is set in a fight, and the slot is caught up after", function(ns, scenario)
	armed(ns, scenario)
	local spell = castLine(ns)
	ns.CreateClickMacro()
	local index = macroIndex()
	if index == 0 or not spell then fail(scenario, "SKIPPED -- no macro or no spell") return end
	Mock.dropOnBar(2)
	Mock.advance(0.1)
	-- A fight starts with Anna on the prompt; in it, the entry changes under
	-- the frozen button and the one thing a press casts stays what it was.
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	ns.SyncMacroSlot(spellEntry("Power Word: Fortitude"))
	wipe(ns.owed)
	ns.addon:Tick()
	if slotOf(index).spell ~= spell then
		fail(scenario, ("the slot changed to %s in a fight, where the button still casts %s"):format(
			tostring(slotOf(index).spell), spell))
	end
	if #Mock.blockedCalls ~= 0 then
		fail(scenario, "the client was asked for " .. table.concat(Mock.blockedCalls, ", ") .. " in a fight")
	end
	-- The fight ends, with nobody owed any more: the slot follows the prompt.
	Mock.inCombat = false
	ns.addon:PLAYER_REGEN_ENABLED()
	if not empty(ns) then fail(scenario, "SKIPPED -- the prompt never emptied") return end
	if slotOf(index).spell ~= nil then
		fail(scenario, "after the fight the slot still shows " .. tostring(slotOf(index).spell) .. " with nobody to buff")
	end
end)

with("actionbar: a macro moved in a fight has its spell set once the fight ends", function(ns, scenario)
	armed(ns, scenario)
	local spell = castLine(ns)
	ns.CreateClickMacro()
	local index = macroIndex()
	if index == 0 or not spell then fail(scenario, "SKIPPED -- no macro or no spell") return end
	-- In a fight that left the button as it was (no pull armed a macro of its
	-- own), so nothing re-arms it once the fight ends: only the catch-up does.
	Mock.inCombat = true
	-- Moved to another place by the macro window, event and all.
	Mock.macroList[5], Mock.macroList[index] = Mock.macroList[index], nil
	Mock.macroList[5].spell = nil
	ns.addon:UPDATE_MACROS()
	if Mock.macroList[5].spell ~= nil or #Mock.blockedCalls ~= 0 then
		fail(scenario, "the macro's slot was set in a fight")
	end
	Mock.inCombat = false
	-- The prompt's own repaint after a fight arms the button again whenever the
	-- fight changed anything about it, and sets the slot on its way; held off
	-- here, so that what is under test is the catch-up of the slot alone.
	local realRefresh = ns.Prompt.Refresh
	ns.Prompt.Refresh = function() end
	ns.addon:PLAYER_REGEN_ENABLED()
	ns.Prompt.Refresh = realRefresh
	if Mock.macroList[5].spell ~= spell then
		fail(scenario, "the moved macro shows " .. tostring(Mock.macroList[5].spell) .. " after the fight, not " .. spell)
	end
end)

-- ------------------------------------------------------------------ 6
-- A macro deleted and made again by hand is set again; one moved, too.
with("actionbar: a macro made by hand gets the spell, and none is set where it is not", function(ns, scenario)
	armed(ns, scenario)
	local spell = castLine(ns)
	if not spell then fail(scenario, "SKIPPED -- no spell") return end
	if not Mock.registeredEvents.UPDATE_MACROS then fail(scenario, "the addon does not listen for UPDATE_MACROS") end
	local calls = Mock.macroSpellCalls or 0
	ns.addon:Tick()
	ns.addon:UPDATE_MACROS()
	ns.addon:Tick()
	if (Mock.macroSpellCalls or 0) ~= calls then fail(scenario, "a spell was set with no macro to set it on") end
	-- Made in the macro window.
	local index = CreateMacro("Manners", "INV_MISC_NOTE_03", BODY, false)
	ns.addon:UPDATE_MACROS()
	if slotOf(index).spell ~= spell then
		fail(scenario, "a macro made by hand shows " .. tostring(slotOf(index).spell) .. ", not " .. spell)
	end
	-- An event that says nothing moved: nothing set.
	calls = Mock.macroSpellCalls
	ns.addon:UPDATE_MACROS()
	if Mock.macroSpellCalls ~= calls then fail(scenario, "an event with the macro in its place set the spell again") end
	-- Deleted and made again at another place.
	Mock.macroList[index] = nil
	ns.addon:UPDATE_MACROS()
	Mock.macroList[9] = { name = "Manners", icon = "INV_MISC_NOTE_03", body = BODY }
	ns.addon:UPDATE_MACROS()
	if Mock.macroList[9].spell ~= spell then
		fail(scenario, "a macro made again shows " .. tostring(Mock.macroList[9].spell) .. ", not " .. spell)
	end
end)

-- A name in the prompt's list is armed as the prompt is, and is not what a
-- press on the bar casts.
with("actionbar: a list row's macro is not what the slot shows", function(ns, scenario)
	armed(ns, scenario)
	local spell = castLine(ns)
	ns.CreateClickMacro()
	local index = macroIndex()
	if index == 0 or not spell then fail(scenario, "SKIPPED -- no macro or no spell") return end
	local row = { isRow = true, button = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate") }
	ns.Prompt:ArmRow(row, spellEntry("Power Word: Fortitude", "Bert Beside"))
	if not row.button:GetAttribute("macrotext1") then fail(scenario, "SKIPPED -- the row was not armed") return end
	if slotOf(index).spell ~= spell then
		fail(scenario, "arming a list row put " .. tostring(slotOf(index).spell) .. " on the slot, not " .. spell)
	end
	ns.Prompt:ArmRow(row, nil)
	if slotOf(index).spell ~= spell then
		fail(scenario, "disarming a list row took the spell off the slot")
	end
end)

-- ------------------------------------------------------------------ 7
-- Nothing is asked of the client on a scan.
with("actionbar: a scan asks the client nothing about the macro", function(ns, scenario)
	armed(ns, scenario)
	if not castLine(ns) then fail(scenario, "SKIPPED -- no spell") return end
	ns.CreateClickMacro()
	local counts = { index = 0, spell = 0, item = 0, body = 0 }
	local realIndex, realSpell, realItem = GetMacroIndexByName, SetMacroSpell, SetMacroItem
	GetMacroIndexByName = function(...) counts.index = counts.index + 1 return realIndex(...) end
	SetMacroSpell = function(...) counts.spell = counts.spell + 1 return realSpell(...) end
	SetMacroItem = function(...) counts.item = counts.item + 1 return realItem(...) end
	for _ = 1, 30 do
		Mock.advance(0.5)
		ns.addon:Tick()
	end
	-- And with nobody to buff, after the one clearing.
	if not empty(ns) then fail(scenario, "SKIPPED -- the prompt never emptied") return end
	local settled = { counts.index, counts.spell, counts.item }
	for _ = 1, 30 do
		Mock.advance(0.5)
		ns.addon:Tick()
	end
	GetMacroIndexByName, SetMacroSpell, SetMacroItem = realIndex, realSpell, realItem
	if counts.index > settled[1] or counts.spell > settled[2] or counts.item > settled[3] then
		fail(scenario, ("scans asked the client for the macro's place %d, its spell %d, its item %d times with nobody to buff"):format(
			counts.index - settled[1], counts.spell - settled[2], counts.item - settled[3]))
	end
	if settled[1] ~= 0 and settled[2] > 1 then
		fail(scenario, ("30 scans on one entry set the slot %d times"):format(settled[2]))
	end
end)

with("actionbar: with no macro a scan asks the client nothing either", function(ns, scenario)
	armed(ns, scenario)
	if not castLine(ns) then fail(scenario, "SKIPPED -- no spell") return end
	-- The first look for the macro, which is not there.
	Mock.advance(3)
	ns.addon:Tick()
	local counts = { index = 0, spell = 0 }
	local realIndex, realSpell = GetMacroIndexByName, SetMacroSpell
	GetMacroIndexByName = function(...) counts.index = counts.index + 1 return realIndex(...) end
	SetMacroSpell = function(...) counts.spell = counts.spell + 1 return realSpell(...) end
	for _ = 1, 20 do
		Mock.advance(0.5)
		ns.addon:Tick()
	end
	ns.Prompt:ApplyTarget(spellEntry("Power Word: Fortitude"))
	GetMacroIndexByName, SetMacroSpell = realIndex, realSpell
	if counts.index > 0 or counts.spell > 0 then
		fail(scenario, ("with no macro the client was asked for its place %d and its spell %d times"):format(counts.index, counts.spell))
	end
end)

-- ------------------------------------------------------------------ 8
-- A controller button bound to the click presses the prompt.
with("actionbar: a gamepad button bound to the prompt presses it", function(ns, scenario)
	armed(ns, scenario)
	local clicks = ns.Prompt.regions.clicks
	if clicks ~= "AnyDown" then fail(scenario, "the secure button is registered for " .. tostring(clicks)) end
	local button = ns.Prompt:GetButton()
	if button:GetAttribute("pressAndHoldAction") ~= true then
		fail(scenario, "the secure button does not answer a held down press")
	end
	local keys = { "PAD1", "PAD2", "PAD3", "PAD4", "PAD5", "PAD6", "PADDUP", "PADDDOWN", "PADDLEFT", "PADDRIGHT",
		"PADLTRIGGER", "PADRTRIGGER", "PADLSHOULDER", "PADRSHOULDER", "PADLSTICK", "PADRSTICK",
		"SHIFT-PAD1", "CTRL-PADRTRIGGER", "CTRL-SHIFT-PAD4", "ALT-PADDUP" }
	for _, key in ipairs(keys) do
		Mock.bindings = {}
		ns.Setup.SetKey(key)
		if GetBindingAction(key) ~= COMMAND or ns.Setup.Key() ~= key then
			fail(scenario, key .. " did not bind to the prompt's click")
		else
			-- The client answers the binding with a down click on the button.
			Mock.printed = {}
			local ran = H.pressButton(ns)
			if not (ran and ran:find("/target Anna Aim", 1, true) and ran:find("/cast", 1, true)) then
				fail(scenario, key .. " pressed the prompt and ran " .. tostring(ran))
			end
			-- The next key meets a prompt that has not just been pressed.
			ns.pendingClick = nil
			wipe(ns.tried)
			wipe(ns.refusals)
			Mock.advance(60)
			owe(ns, "Anna Aim")
			ns.addon:Tick()
		end
	end
end)

-- ------------------------------------------------------------------ 9
-- The chip's words for a controller's buttons.
with("actionbar: a gamepad button on the chip reads as its glyph, short", function(ns, scenario)
	local restoreText = Mock.withBindingText()
	local short = ns.Looks.ShortKey
	local one = Mock.bindingText("PAD1", true)
	if short("PAD1") ~= one or not one:find("|A:Gamepad_Gen_1_32:14:14|a", 1, true) then
		fail(scenario, "PAD1 reads " .. tostring(short("PAD1")))
	end
	if #one > 40 then fail(scenario, "a button's glyph is " .. #one .. " characters long") end
	-- A modifier on a button: the left trigger and the face button, as pressed.
	rawset(_G, "GetCVar", function(name)
		return ({ GamePadEmulateShift = "PADLTRIGGER", GamePadEmulateCtrl = "PADLSHOULDER", GamePadEmulateAlt = "none" })[name]
	end)
	local trigger, shoulder = Mock.bindingText("PADLTRIGGER", true), Mock.bindingText("PADLSHOULDER", true)
	local want = trigger .. "+" .. one
	if short("SHIFT-PAD1") ~= want then
		fail(scenario, "SHIFT-PAD1 reads " .. tostring(short("SHIFT-PAD1")) .. ", not the trigger and the button")
	end
	if short("CTRL-SHIFT-PAD4") ~= shoulder .. "+" .. trigger .. "+" .. Mock.bindingText("PAD4", true) then
		fail(scenario, "CTRL-SHIFT-PAD4 reads " .. tostring(short("CTRL-SHIFT-PAD4")))
	end
	-- Alt is on no button: the client's own short form stays.
	if short("ALT-PADDUP") ~= Mock.bindingText("ALT-PADDUP", true) then
		fail(scenario, "ALT-PADDUP reads " .. tostring(short("ALT-PADDUP")))
	end
	-- A CVar the client does not answer: the client's own short form.
	rawset(_G, "GetCVar", nil)
	local ns2 = load(scenario)
	if ns2 and ns2.Looks.ShortKey("SHIFT-PAD1") ~= Mock.bindingText("SHIFT-PAD1", true) then
		fail(scenario, "with no CVar to read SHIFT-PAD1 reads " .. tostring(ns2.Looks.ShortKey("SHIFT-PAD1")))
	end
	-- A keyboard key is the client's own short form, as it always was.
	if short("SHIFT-F") ~= "s-F" or short("F") ~= "F" then
		fail(scenario, "a keyboard key reads " .. tostring(short("SHIFT-F")))
	end
	if short(nil) ~= nil then fail(scenario, "no key reads " .. tostring(short(nil))) end
	restoreText()
	if short("PAD1") ~= nil then fail(scenario, "a client with no key texts gave " .. tostring(short("PAD1"))) end
end)

-- ------------------------------------------------------------------ 10
-- The chip fits, on every look that has one.
do
	local STYLES = { "arcane", "toast", "ribbon", "letter", "leather" }
	local KEYS = { "PAD1", "PADRTRIGGER", "PADDUP", "SHIFT-PAD1", "CTRL-SHIFT-PAD4", "ALT-PADLSHOULDER", "SHIFT-CTRL-F" }

	local function rectOf(r)
		local L, R = FT.span(r, "x")
		local B, T = FT.span(r, "y")
		if L and B then return { L, B, R, T } end
	end
	local function across(a, b)
		return a[1] < b[3] - 0.01 and b[1] < a[3] - 0.01 and a[2] < b[4] - 0.01 and b[2] < a[4] - 0.01
	end

	with("actionbar: the key chip with a controller's buttons fits in every look", function(ns, scenario)
		local restoreText = Mock.withBindingText()
		rawset(_G, "GetCVar", function(name)
			return ({ GamePadEmulateShift = "PADLTRIGGER", GamePadEmulateCtrl = "PADLSHOULDER", GamePadEmulateAlt = "none" })[name]
		end)
		freshPrompt(ns, scenario)
		local shown = 0
		for _, style in ipairs(STYLES) do
			for _, key in ipairs(KEYS) do
				for _, width in ipairs({ 90, 140, 250 }) do
					Mock.bindings = {}
					SetBinding(key, COMMAND)
					local p = ns.db.profile.prompt
					p.style, p.width, p.locked, p.hideInCombat = style, width, true, false
					ns.Prompt:ApplyStyle()
					Mock.advance(60)
					owe(ns, "Anna Aim")
					ns.addon:Tick()
					FT.settle()
					local r = ns.Prompt:Regions()
					local look = r.look
					local tag = ("%s, %s, %d wide"):format(style, key, width)
					if not (look and look.keyBox and look.keyText) then
						fail(scenario, "SKIPPED -- " .. style .. " has no key chip")
					elseif look.keyText:IsShown() and look.keyBox:IsShown() then
						shown = shown + 1
						local panel, chip, name = rectOf(r.art), rectOf(look.keyBox), rectOf(r.name)
						local label = look.keyText:GetText() or ""
						if key:find("PAD", 1, true) and not label:find("|A:Gamepad_", 1, true) then
							fail(scenario, tag .. ": the chip reads " .. label .. ", no button glyph")
						end
						if not (panel and chip) then
							fail(scenario, tag .. ": the chip has no place")
						else
							if chip[1] < panel[1] - 0.01 or chip[3] > panel[3] + 0.01 then
								fail(scenario, ("%s: the chip (%.1f to %.1f) leaves the prompt (%.1f to %.1f)"):format(
									tag, chip[1], chip[3], panel[1], panel[3]))
							end
							if name and across(chip, name) then fail(scenario, tag .. ": the chip is over the name") end
							if r.sub:IsShown() then
								local sub = rectOf(r.sub)
								if sub and across(chip, sub) then fail(scenario, tag .. ": the chip is over the reason") end
							end
						end
						-- The label inside the chip it asked for.
						local room = look.keyText.GetUnboundedStringWidth and look.keyText:GetUnboundedStringWidth()
						if chip and type(room) == "number" and room > chip[3] - chip[1] + 0.5 then
							fail(scenario, ("%s: the chip is %.1f wide for a label %.1f wide"):format(tag, chip[3] - chip[1], room))
						end
					elseif width == 250 then
						fail(scenario, tag .. ": no chip on a prompt 250 wide")
					end
				end
			end
		end
		Mock.bindings = {}
		restoreText()
		if shown == 0 then fail(scenario, "SKIPPED -- no chip was ever up, so nothing was held") end
	end, nil, true)
end

-- ------------------------------------------------------------------ 11
-- Full macro lists, as /manners macro has always met them.
with("actionbar: with the macro lists full, an existing macro is still picked up", function(ns, scenario)
	rawset(_G, "MAX_ACCOUNT_MACROS", 120)
	rawset(_G, "MAX_CHARACTER_MACROS", 30)
	local function fill(first, last, except)
		for i = first, last do
			if i ~= except then Mock.macroList[i] = { name = "Filler" .. i, icon = "INV_MISC_NOTE_01", body = "" } end
		end
	end
	local ok, err = pcall(function()
		armed(ns, scenario)
		-- Both lists full, no Manners: refused with the words for it.
		fill(1, 150)
		Mock.printed = {}
		local made = ns.CreateClickMacro()
		if made or macroIndex() ~= 0 or GetCursorInfo() ~= nil then
			fail(scenario, "a macro was made or picked up with both lists full")
		end
		if not said():find("no free macro slots", 1, true) then
			fail(scenario, "full lists were met with: " .. said())
		end
		-- Both full, Manners one of them: it is edited and picked up.
		Mock.macroList[4] = { name = "Manners", icon = "INV_MISC_NOTE_03", body = "/old" }
		Mock.printed = {}
		if not ns.CreateClickMacro() then fail(scenario, "an existing macro in full lists was not picked up") end
		if select(3, GetMacroInfo(4)) ~= BODY then fail(scenario, "the existing macro's body was not put right") end
		local kind, id = GetCursorInfo()
		if kind ~= "macro" or id ~= 4 then fail(scenario, "the existing macro is not on the cursor") end
		-- Only the account list full: made among the character's, and carried.
		ClearCursor()
		Mock.macroList = {}
		fill(1, 120)
		if not ns.CreateClickMacro() then fail(scenario, "no macro was made among the character's with the account's full") end
		if macroIndex() <= 120 then fail(scenario, "the macro went to the account list, which is full") end
		if GetCursorInfo() ~= "macro" then fail(scenario, "the character's macro is not on the cursor") end
	end)
	rawset(_G, "MAX_ACCOUNT_MACROS", nil)
	rawset(_G, "MAX_CHARACTER_MACROS", nil)
	if not ok then error(err, 0) end
end)

-- ------------------------------------------------------------------ 12
-- All five clients, with the calls each has.
for _, flavour in ipairs(FLAVOURS) do
	with("actionbar: " .. flavour .. ": the macro is made, carried and its slot set", function(ns, scenario)
		freshPrompt(ns, scenario)
		ns.Prompt:ApplyTarget(spellEntry("Arcane Intellect"))
		makeButton(ns).func({ "makeMacro" })
		local index = macroIndex()
		if index == 0 then fail(scenario, "the button made no macro") return end
		if GetCursorInfo() ~= "macro" then fail(scenario, "the macro is not on the cursor") end
		if slotOf(index).spell ~= "Arcane Intellect" then
			fail(scenario, "the slot's spell is " .. tostring(slotOf(index).spell))
		end
		ns.Prompt:ApplyTarget(scrollEntry(275069))
		if slotOf(index).item ~= "item:275069" or slotOf(index).spell ~= nil then
			fail(scenario, "a scroll leaves the slot at " .. tostring(slotOf(index).spell) .. " and " .. tostring(slotOf(index).item))
		end
		-- Without the two calls the macro is still made and carried, quietly.
		Mock.macroList = {}
		ClearCursor()
		rawset(_G, "SetMacroSpell", nil)
		rawset(_G, "SetMacroItem", nil)
		ns.CreateClickMacro()
		ns.Prompt:ApplyTarget(spellEntry("Power Word: Fortitude"))
		ns.Prompt:ApplyTarget(scrollEntry(275069))
		if macroIndex() == 0 or GetCursorInfo() ~= "macro" then
			fail(scenario, "without SetMacroSpell and SetMacroItem the macro was not made and carried")
		end
	end, flavour)

	-- A client with no PickupMacro, and one that takes the call and puts nothing
	-- on the cursor: the macro window opens, and the chat says where it is.
	for _, how in ipairs({ "has no PickupMacro", "refuses the pick-up" }) do
		with("actionbar: " .. flavour .. ": a client that " .. how .. " opens the macro window", function(ns, scenario)
			freshPrompt(ns, scenario)
			local opened = 0
			rawset(_G, "ShowMacroFrame", function() opened = opened + 1 end)
			if how == "has no PickupMacro" then
				rawset(_G, "PickupMacro", nil)
			else
				rawset(_G, "PickupMacro", function() end)
			end
			Mock.printed = {}
			makeButton(ns).func({ "makeMacro" })
			if macroIndex() == 0 then fail(scenario, "the button made no macro") return end
			if opened ~= 1 then fail(scenario, "the macro window was opened " .. opened .. " times") end
			if not said():find("Drag it onto a bar", 1, true) then
				fail(scenario, "no word of where to find the macro: " .. said())
			end
			if said():find("on your cursor", 1, true) or ns.macroOnCursor then
				fail(scenario, "the macro is said to be on the cursor: " .. said())
			end
		end, flavour)
	end
end

-- ------------------------------------------------------------------ 13
-- Whatever the macro does, the secure button is not touched in a fight.
with("actionbar: the macro's slot never touches the secure button", function(ns, scenario)
	armed(ns, scenario)
	local button = ns.Prompt:GetButton()
	ns.CreateClickMacro()
	local before = { button:GetAttribute("type1"), button:GetAttribute("macrotext1") }
	local protectedBefore = #Mock.protectedCalls
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	ns.Prompt:ApplyTarget(spellEntry("Power Word: Fortitude"))
	ns.SyncMacroSlot(scrollEntry(275069))
	ns.ResyncMacroSlot(true)
	ns.addon:UPDATE_MACROS()
	makeButton(ns).func({ "makeMacro" })
	if button:GetAttribute("type1") ~= before[1] or button:GetAttribute("macrotext1") ~= before[2] then
		fail(scenario, "the button's attributes changed in a fight")
	end
	if #Mock.protectedCalls ~= protectedBefore then
		fail(scenario, "a protected call was made on the secure button in a fight: " .. table.concat(Mock.protectedCalls, ", ", protectedBefore + 1))
	end
	Mock.inCombat = false
end)
