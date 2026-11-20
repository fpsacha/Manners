-- The snooze offers more than half an hour without typing (asked for on
-- CurseForge: the window's Snooze stopped at 30 minutes and the minimap menu at
-- an hour, while /manners snooze takes up to four). Both menus now offer an
-- hour, two hours and four (ns.SNOOZE_CHOICES, MENU_SNOOZE_MINUTES in
-- Options/Launcher.lua, the header list in Options/Window/Layout.lua).
--
-- Every scenario name starts with "snooze-long:" so the mutations in
-- tests/mutations/snooze-long.py can name the one that has to catch them.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive
local strangers, freshPrompt = H.strangers, H.freshPrompt

-- The header's Snooze menu, as the window's layout lists it, and the control
-- each entry runs.
do
	local scenario = "snooze-long: the window's snooze offers an hour, two and four"
	Mock.reset()
	local ns = load(scenario)
	if ns then
		drive(scenario, ns)
		ns.Prompt:ExitTest()
		local general = ns.optionsTable and ns.optionsTable.args.general
		local layout = ns.WindowLayout
		if not (general and general.args and layout and layout.header) then
			fail(scenario, "SKIPPED -- no Start here tab or no window layout")
		else
			local listed = {}
			for _, path in ipairs(layout.header.snooze or {}) do listed[path] = true end
			for _, path in ipairs({ "general.snooze60", "general.snooze120", "general.snooze240" }) do
				if not listed[path] then fail(scenario, "the header's Snooze menu lacks " .. path) end
			end
			local control = general.args.snooze240
			if not (control and control.func) then
				fail(scenario, "no snooze240 control to run")
			else
				control.func({ "snooze240" })
				local left = ns.SnoozeLeft()
				if not left or math.abs(left - 14400) > 5 then
					fail(scenario, "Snooze 240 minutes left " .. tostring(left) .. " seconds, not 14400")
				end
				ns.StopSnooze(true)
			end
			local name = general.args.snooze120 and general.args.snooze120.name
			if type(name) == "function" then name = name() end
			if name ~= "Snooze 120 minutes" then
				fail(scenario, "the two-hour button reads " .. tostring(name))
			end
		end
	end
	Mock.reset()
end

-- The minimap menu's Snooze submenu: the four-hour entry snoozes for four hours.
local function newMenu(text, fn)
	local d = { text = text, fn = fn, items = {}, enabled = true }
	local function add(child)
		d.items[#d.items + 1] = child
		return child
	end
	function d:CreateTitle(t) return add({ text = t, title = true, items = {} }) end
	function d:CreateDivider() return add({ divider = true, items = {} }) end
	function d:CreateButton(t, f) return add(newMenu(t, f)) end
	function d:CreateCheckbox(t, get, set)
		local c = newMenu(t, set)
		c.kind, c.get = "checkbox", get
		return add(c)
	end
	function d:CreateRadio(t, get, set)
		local c = newMenu(t, set)
		c.kind, c.get = "radio", get
		return add(c)
	end
	return d
end

local function child(root, pattern)
	for _, item in ipairs(root and root.items or {}) do
		if item.text and tostring(item.text):find(pattern) then return item end
	end
end

do
	local scenario = "snooze-long: the minimap menu snoozes for four hours"
	Mock.reset()
	local restore = strangers({ nameplate1 = { "Anna", "Aim" } })
	local ns = load(scenario)
	if ns then
		freshPrompt(ns, scenario)
		ns.Prompt:ExitTest()
		local broker = Mock.broker
		local real = MenuUtil
		local opened
		MenuUtil = {
			CreateContextMenu = function(owner, generator)
				local root = newMenu()
				generator(owner, root)
				opened = root
				return root
			end,
		}
		local ok, err = pcall(function()
			if not (broker and broker.OnClick) then
				fail(scenario, "SKIPPED -- no launcher was registered")
				return
			end
			broker.OnClick({}, "RightButton")
			local snooze = child(opened, "^Snooze$")
			if not snooze then fail(scenario, "SKIPPED -- the menu has no Snooze") return end
			for _, length in ipairs({ "120 minutes", "240 minutes" }) do
				if not child(snooze, "^For " .. length .. "$") then
					fail(scenario, "the Snooze submenu has no " .. length)
				end
			end
			local four = child(snooze, "^For 240 minutes$")
			if four then
				four.fn()
				local left = ns.SnoozeLeft()
				if not left or math.abs(left - 14400) > 5 then
					fail(scenario, "For 240 minutes left " .. tostring(left) .. " seconds, not 14400")
				end
				ns.StopSnooze(true)
			end
		end)
		MenuUtil = real
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
	end
	restore()
	Mock.reset()
end
