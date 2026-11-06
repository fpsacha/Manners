-- A gamepad switched on and the client's own menus (issue #6). A player using a
-- gamepad and the mouse by turns got "ADDON FORBIDDEN:
-- SetPreferredGamepadInteractTarget()" when a menu closed: the client's gamepad
-- code treats the frames of a menu an addon filled as tainted and its protected
-- call is refused. With only Manners loaded it still happened, and Manners
-- opens such menus in three places: the launcher's right click, the options
-- window's drop-downs and its Snooze button. With a gamepad on (ns.GamepadActive,
-- C_GamePad.IsEnabled) none is opened: the right click is the switch alone, a
-- drop-down goes to the next choice, Snooze starts or stops the fifteen minutes.
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

do
	local scenario = "gamepad: an options drop-down goes to the next choice with a gamepad on"
	with(scenario, true, function(ns, count)
		ns.OpenOptions("who")
		ns.Prompt:ExitTest()
		local UI = ns.WindowUI
		-- Buff to offer is a select on every class with a choice; a mage has
		-- Show me the prompt's neighbours, so the first select on the page does.
		local row, field
		for _, path in ipairs({ "who.choice", "who.proximity", "who.orderPick" }) do
			if UI.Reveal(path) then
				row = UI.RowFor(path)
				field = row and row.field
				if field and row.values and #row.values > 1 then break end
				row, field = nil, nil
			end
		end
		if not field then
			fail(scenario, "SKIPPED -- no drop-down found on Who to buff")
			return
		end
		local before = row.value and row.value:GetText()
		press(field)
		if count() ~= 0 then fail(scenario, "a drop-down opened the client's menu with a gamepad on") end
		local after = row.value and row.value:GetText()
		if after == before then fail(scenario, "the drop-down stayed on " .. tostring(before)) end
	end)
end
