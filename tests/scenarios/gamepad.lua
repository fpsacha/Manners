-- A gamepad switched on and the client's own menus (issue #6). A player using a
-- gamepad and the mouse by turns got "ADDON FORBIDDEN:
-- SetPreferredGamepadInteractTarget()" when a menu closed: the client's gamepad
-- code treats the frames of a menu an addon filled as tainted and its protected
-- call is refused. With only Manners loaded it still happened, and Manners
-- opens such menus in three places: the launcher's right click, the options
-- window's drop-downs and its Snooze button. With a gamepad on (ns.GamepadActive,
-- C_GamePad.IsEnabled) none is opened: the right click is the switch alone, a
-- drop-down opens a list Manners draws itself, Snooze starts or stops the
-- fifteen minutes.
--
-- Every scenario name starts with "gamepad:" so the mutations in
-- tests/mutations/gamepad.py can name the one that has to catch them.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

local TOUCHED = { "MenuUtil", "C_GamePad", "IsSpellKnown", "IsPlayerSpell" }

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- One session with a menu the client could open (counted) and a gamepad that is
-- on, off or has no API at all (`pad`: true, false or nil).
local function with(scenario, pad, body)
	Mock.reset()
	Mock.class = "MAGE"
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local opened = 0
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		rawset(_G, "MenuUtil", {
			CreateContextMenu = function(owner, generator)
				opened = opened + 1
				local root = {}
				root.CreateButton = function() return root end
				root.CreateRadio = function() return root end
				root.CreateCheckbox = function() return root end
				root.CreateDivider = function() end
				root.CreateTitle = function() end
				generator(owner, root)
			end,
		})
		if pad == nil then
			rawset(_G, "C_GamePad", nil)
		else
			rawset(_G, "C_GamePad", { IsEnabled = function() return pad end })
		end
		drive(scenario, ns)
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.Prompt:ExitTest()
		Mock.printed = {}
		body(ns, function() return opened end)
		noErrors(scenario, ns)
	end)
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function press(button)
	local onClick = button and button:GetScript("OnClick")
	if onClick then onClick(button, "LeftButton", false) end
end

do
	local scenario = "gamepad: ns.GamepadActive follows the client, and no API is no gamepad"
	for _, case in ipairs({ { true, true }, { false, false }, { nil, false } }) do
		with(scenario, case[1], function(ns)
			if ns.GamepadActive() ~= case[2] then
				fail(scenario, "C_GamePad.IsEnabled " .. tostring(case[1]) .. " read as " .. tostring(ns.GamepadActive()))
			end
		end)
	end
end

do
	local scenario = "gamepad: the launcher's right click opens the menu, and not with a gamepad on"
	with(scenario, false, function(ns, count)
		if not Mock.broker then
			fail(scenario, "SKIPPED -- no launcher was made")
			return
		end
		pcall(Mock.broker.OnClick, {}, "RightButton")
		if count() ~= 1 then fail(scenario, "with no gamepad the right click opened " .. count() .. " menus, not one") end
		if not ns.db.profile.enabled then fail(scenario, "the right click threw the switch as well") end
	end)
	with(scenario, true, function(ns, count)
		if not Mock.broker then return end
		pcall(Mock.broker.OnClick, {}, "RightButton")
		if count() ~= 0 then fail(scenario, "with a gamepad on the right click opened the client's menu") end
		if ns.db.profile.enabled then fail(scenario, "with no menu to open, the right click did not throw the switch") end
	end)
end

do
	local scenario = "gamepad: the options window's Snooze button needs no menu with a gamepad on"
	with(scenario, true, function(ns, count)
		ns.OpenOptions()
		ns.Prompt:ExitTest()
		local UI = ns.WindowUI
		if not (UI and UI.header and UI.header.snooze) then
			fail(scenario, "SKIPPED -- the window has no Snooze button")
			return
		end
		press(UI.header.snooze)
		if count() ~= 0 then fail(scenario, "Snooze opened the client's menu with a gamepad on") end
		if not ns.SnoozeLeft() then fail(scenario, "Snooze did nothing with a gamepad on") end
		press(UI.header.snooze)
		if ns.SnoozeLeft() then fail(scenario, "Snooze, pressed again with one running, did not stop it") end
	end)
	with(scenario, false, function(ns, count)
		ns.OpenOptions()
		ns.Prompt:ExitTest()
		local UI = ns.WindowUI
		if not (UI and UI.header and UI.header.snooze) then return end
		press(UI.header.snooze)
		if count() ~= 1 then fail(scenario, "with no gamepad Snooze opened " .. count() .. " menus, not its menu") end
		if ns.SnoozeLeft() then fail(scenario, "with no gamepad Snooze started one without a choice") end
	end)
end

-- A drop-down on Who to buff with more than one choice, its row and field.
-- Buff to offer is a select on every class with a choice; a mage has Show me
-- the prompt's neighbours, so the first select on the page does.
local function dropDown(scenario, ns)
	ns.OpenOptions("who")
	ns.Prompt:ExitTest()
	local UI = ns.WindowUI
	for _, path in ipairs({ "who.choice", "who.proximity", "who.orderPick" }) do
		if UI.Reveal(path) then
			local row = UI.RowFor(path)
			if row and row.field and row.values and #row.values > 1 then return row, row.field end
		end
	end
	fail(scenario, "SKIPPED -- no drop-down found on Who to buff")
	return nil
end

do
	local scenario = "gamepad: an options drop-down opens Manners' own list with a gamepad on"
	with(scenario, true, function(ns, count)
		local row, field = dropDown(scenario, ns)
		if not row then return end
		local before = row.value:GetText()
		press(field)
		if count() ~= 0 then fail(scenario, "a drop-down opened the client's menu with a gamepad on") end
		if row.value:GetText() ~= before then fail(scenario, "opening the list changed the choice") end
		local list = ns.WindowWidgets.choiceList
		if not (list and list.screen:IsShown()) then
			fail(scenario, "the drop-down opened no list")
			return
		end
		if list.screen._strata ~= "FULLSCREEN_DIALOG" then
			fail(scenario, "the list draws at " .. tostring(list.screen._strata) .. ", under the window")
		end
		local other
		for i, v in ipairs(row.values) do
			local button = list.buttons[i]
			if not (button and button:IsShown()) then
				fail(scenario, "choice " .. tostring(v[2]) .. " has no row in the list")
			elseif button.text:GetText() ~= v[2] then
				fail(scenario, "row " .. i .. " reads " .. tostring(button.text:GetText()))
			elseif v[2] ~= before then
				other = other or button
			end
		end
		if not other then
			fail(scenario, "SKIPPED -- no other choice to pick")
			return
		end
		local picked = other.text:GetText()
		press(other)
		if list.screen:IsShown() then fail(scenario, "picking left the list open") end
		if row.value:GetText() ~= picked then
			fail(scenario, "picked " .. tostring(picked) .. " and the field reads " .. tostring(row.value:GetText()))
		end
	end)
end

do
	local scenario = "gamepad: a click away from the list closes it and changes nothing"
	with(scenario, true, function(ns)
		local row, field = dropDown(scenario, ns)
		if not row then return end
		local before = row.value:GetText()
		press(field)
		local list = ns.WindowWidgets.choiceList
		press(list.screen)
		if list.screen:IsShown() then fail(scenario, "the list stayed open") end
		if row.value:GetText() ~= before then fail(scenario, "the choice changed to " .. tostring(row.value:GetText())) end
	end)
end

do
	local scenario = "gamepad: the list shuts with the window"
	with(scenario, true, function(ns)
		local row, field = dropDown(scenario, ns)
		if not row then return end
		press(field)
		local list = ns.WindowWidgets.choiceList
		local tick = list.screen:GetScript("OnUpdate")
		tick(list.screen, 0.1)
		if not list.screen:IsShown() then fail(scenario, "the list shut with the window still open") end
		field:Hide()
		tick(list.screen, 0.1)
		if list.screen:IsShown() then fail(scenario, "the list stayed up without its field") end
	end)
end

do
	local scenario = "gamepad: a long list opens at the choice and scrolls"
	with(scenario, true, function(ns)
		local row, field = dropDown(scenario, ns)
		if not row then return end
		local B = ns.WindowBind
		local values, value = B.Values, B.Value
		local many = {}
		for i = 1, 30 do many[i] = { "k" .. i, "Choice " .. i } end
		B.Values = function(item, ...) if item == row.item then return many end return values(item, ...) end
		B.Value = function(item, ...) if item == row.item then return "k25" end return value(item, ...) end
		local ok, err = pcall(function()
			press(field)
			local list = ns.WindowWidgets.choiceList
			local shown = {}
			for _, button in ipairs(list.buttons) do
				if button:IsShown() then shown[button.text:GetText()] = true end
			end
			if not shown["Choice 25"] then fail(scenario, "the current choice is out of view") end
			if not (list.up:IsShown() and list.down:IsShown()) then fail(scenario, "no arrows on a long list") end
			if list.buttons[1].text:GetText() ~= "Choice 11" then
				fail(scenario, "it opened with " .. tostring(list.buttons[1].text:GetText()) .. " first")
			end
			press(list.up)
			if list.buttons[1].text:GetText() ~= "Choice 1" then
				fail(scenario, "the up arrow left " .. tostring(list.buttons[1].text:GetText()) .. " first")
			end
			list.screen:GetScript("OnMouseWheel")(list.screen, -1)
			if list.buttons[1].text:GetText() ~= "Choice 4" then
				fail(scenario, "the wheel left " .. tostring(list.buttons[1].text:GetText()) .. " first")
			end
			press(list.screen)
		end)
		B.Values, B.Value = values, value
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
	end)
end
