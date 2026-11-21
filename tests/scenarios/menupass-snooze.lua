-- Snooze has Until I log out, which keeps the prompt away past the four hours
-- the lengths stop at and ends on a logout, a reload or Stop snoozing. Every
-- line that says "until %s" reads "until you log out", and search finds the
-- buttons at the top of the window (Snooze among them), which no page holds.
--
-- Called by scenarios.lua with the addon directory and its helpers.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive
local strangers, freshPrompt = H.strangers, H.freshPrompt

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- A menu the way the client builds one, as snooze-long.lua has it.
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

-- ------------------------------------------------------------------ 1
do
	local scenario = "menupass-snooze: Until I log out keeps the prompt away past four hours"
	Mock.reset()
	local restore = strangers({ nameplate1 = { "Anna", "Aim" } })
	local ns = load(scenario)
	if ns then
		freshPrompt(ns, scenario)
		Mock.advance(60)
		ns.addon:Tick()
		local button = ns.Prompt:GetButton()
		if not button:IsShown() then
			fail(scenario, "SKIPPED -- the prompt was not up before the snooze")
		else
			ns.StartSnooze(ns.SNOOZE_SESSION)
			if not ns.SnoozeLeft() then fail(scenario, "no snooze is running") end
			Mock.advance(10 * 3600)
			ns.addon:Tick()
			if not ns.SnoozeLeft() then fail(scenario, "the snooze ended within ten hours") end
			if ns.SnoozeEndsAt() ~= ns.L["until you log out"] then
				fail(scenario, "the snooze ends at " .. tostring(ns.SnoozeEndsAt()))
			end
			if button:IsShown() then fail(scenario, "the prompt was up ten hours into the snooze") end
			ns.StopSnooze(true)
			ns.addon:Tick()
			if ns.SnoozeLeft() then fail(scenario, "Stop snoozing left it running") end
			if not button:IsShown() then fail(scenario, "the prompt did not come back after Stop snoozing") end
		end
		noErrors(scenario, ns)
	end
	restore()
	Mock.reset()
end

-- ------------------------------------------------------------------ 2
do
	local scenario = "menupass-snooze: the header menu and the launcher offer it, and the launcher can stop it"
	Mock.reset()
	local restore = strangers({ nameplate1 = { "Anna", "Aim" } })
	local ns = load(scenario)
	if ns then
		freshPrompt(ns, scenario)
		ns.Prompt:ExitTest()
		local layout = ns.WindowLayout
		local listed
		for _, path in ipairs(layout and layout.header and layout.header.snooze or {}) do
			if path == "general.snoozeSession" then listed = true end
		end
		if not listed then fail(scenario, "the header's Snooze menu lacks general.snoozeSession") end
		local control = ns.optionsTable and ns.optionsTable.args.general and ns.optionsTable.args.general.args.snoozeSession
		if not (control and control.func) then
			fail(scenario, "no snoozeSession control to run")
		else
			control.func({ "snoozeSession" })
			if not ns.SnoozeSession() then fail(scenario, "the control did not start a session snooze") end
			ns.StopSnooze(true)
		end
		local broker, real, opened = Mock.broker, MenuUtil, nil
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
			if not child(snooze, "^Until I log out$") then
				fail(scenario, "the launcher's Snooze submenu has no Until I log out")
			end
			if child(snooze, "^Stop snoozing") then
				fail(scenario, "Stop snoozing is offered with no snooze running")
			end
			ns.StartSnooze(ns.SNOOZE_SESSION)
			broker.OnClick({}, "RightButton")
			snooze = child(opened, "^Snoozed until you log out$")
			if not snooze then fail(scenario, "the launcher's Snooze entry does not read Snoozed until you log out") return end
			local stop = child(snooze, "^Stop snoozing")
			if not stop then
				fail(scenario, "no Stop snoozing while a session snooze runs")
			else
				stop.fn()
				if ns.SnoozeLeft() then fail(scenario, "Stop snoozing left the snooze running") end
			end
		end)
		MenuUtil = real
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
		ns.StopSnooze(true)
		noErrors(scenario, ns)
	end
	restore()
	Mock.reset()
end

-- ------------------------------------------------------------------ 3
do
	local scenario = "menupass-snooze: every line says until you log out"
	Mock.reset()
	Mock.knownSpells = setmetatable({}, { __index = function() return true end })
	local restore = strangers({ nameplate1 = { "Anna", "Aim" } })
	local ns = load(scenario)
	if ns then
		freshPrompt(ns, scenario)
		ns.Prompt:ExitTest()
		local function clean(where, text)
			text = tostring(text)
			if not text:find("you log out", 1, true) then
				fail(scenario, where .. " does not say you log out: " .. text)
			end
			for _, bad in ipairs({ "nil", "inf", "%d+ minute", "%d+ min" }) do
				if text:find(bad) then fail(scenario, where .. " holds " .. bad .. ": " .. text) end
			end
		end
		local ok, err = pcall(function()
			Mock.printed = {}
			ns.StartSnooze(ns.SNOOZE_SESSION)
			clean("the chat line", table.concat(Mock.printed or {}, " / "))
			clean("the launcher line", select(2, ns.LauncherState()))
			if ns.RefreshBrokerText then ns.RefreshBrokerText() end
			if Mock.broker and Mock.broker.text then clean("the broker text", Mock.broker.text) end
			ns.OpenOptions("general")
			local header = ns.WindowUI and ns.WindowUI.header
			if header and header.snoozeLabel then
				clean("the header label", header.snoozeLabel)
			else
				fail(scenario, "the header has no Snooze label")
			end
			local general = ns.optionsTable.args.general.args
			local note = general.snoozeNote and general.snoozeNote.name
			if type(note) == "function" then note = note() end
			clean("the Start here note", note)
			ns.CloseOptions()
			-- Switched off, in a fight and unlocked have their own lines.
			ns.StopSnooze(true)
			ns.db.profile.enabled = false
			Mock.printed = {}
			ns.StartSnooze(ns.SNOOZE_SESSION)
			clean("the switched-off chat line", table.concat(Mock.printed or {}, " / "))
			ns.StopSnooze(true)
			ns.db.profile.enabled = true
			ns.db.profile.prompt.locked = false
			Mock.printed = {}
			ns.StartSnooze(ns.SNOOZE_SESSION)
			clean("the unlocked chat line", table.concat(Mock.printed or {}, " / "))
			clean("the unlocked launcher line", select(2, ns.LauncherState()))
			ns.StopSnooze(true)
			ns.db.profile.prompt.locked = true
			Mock.inCombat = true
			Mock.printed = {}
			ns.StartSnooze(ns.SNOOZE_SESSION)
			clean("the in-fight chat line", table.concat(Mock.printed or {}, " / "))
			Mock.inCombat = false
			ns.StopSnooze(true)
		end)
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
		ns.StopSnooze(true)
		noErrors(scenario, ns)
	end
	restore()
	Mock.reset()
end

-- ------------------------------------------------------------------ 4
do
	local scenario = "menupass-snooze: search finds Snooze and Manners is on at the top of the window"
	Mock.reset()
	Mock.class = "MAGE"
	Mock.knownSpells = setmetatable({}, { __index = function() return true end })
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		drive(scenario, ns)
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.Prompt:ExitTest()
		ns.OpenOptions("who")
		local UI = ns.WindowUI
		local function rank(query, header, within)
			local found = ns.WindowSearch.Find(query, UI.SearchEntries(), 8)
			for i = 1, math.min(within, #found) do
				if (found[i].ref or {}).header == header then return i end
			end
			local seen = {}
			for i, e in ipairs(found) do seen[i] = tostring((e.ref or {}).header or (e.ref or {}).path) end
			fail(scenario, ("%q: the header's %s is not in the top %d (found %s)")
				:format(query, header, within, table.concat(seen, ", ")))
		end
		rank("snooze", "snooze", 1)
		rank("pause", "snooze", 3)
		rank("turn off", "enabled", 3)
		-- Choosing it flashes the header button and opens its menu.
		local real, opened = MenuUtil, nil
		MenuUtil = { CreateContextMenu = function(owner, generator)
			local root = newMenu()
			generator(owner, root)
			opened = root
			return root
		end }
		local chose, cerr = pcall(function()
			local found = ns.WindowSearch.Find("snooze", UI.SearchEntries(), 8)
			local hit = found[1]
			if not (hit and (hit.ref or {}).header == "snooze") then return end
			local back = UI.Choose(hit.ref)
			if back ~= nil then fail(scenario, "choosing a header entry answered a row") end
			local frame = UI.header and UI.header.snooze
			if not (frame and frame.flashWash and frame.flashWash:IsShown()) then
				fail(scenario, "choosing Snooze did not flash its button")
			end
			if not child(opened, "^Until I log out$") then
				fail(scenario, "choosing Snooze did not open its menu")
			end
		end)
		MenuUtil = real
		if not chose then fail(scenario, "choosing threw: " .. tostring(cerr)) end
		noErrors(scenario, ns)
		ns.CloseOptions()
		ns.Prompt:ExitTest()
	end)
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- ------------------------------------------------------------------ 5
-- The end of a snooze is a whole phrase, so a language that says "until the
-- hour" with an article reads on for a logout too ("hasta las" a time, "hasta
-- que cierres sesion" an event): no line holds an "until" of its own.
do
	local WANT = {
		esES = { "En pausa hasta que cierres sesi\195\179n", "En pausa hasta las " },
		itIT = { "In pausa finch\195\169 non ti disconnetti", "In pausa fino alle " },
	}
	for code, want in pairs(WANT) do
		local scenario = "menupass-snooze: the snooze reads right in " .. code
		Mock.reset()
		Mock.locale = code
		local ns = load(scenario)
		if ns then
			freshPrompt(ns, scenario)
			ns.Prompt:ExitTest()
			ns.StartSnooze(ns.SNOOZE_SESSION)
			local line = ns.L["Snoozed %s"]:format(ns.SnoozeEndsAt())
			if line ~= want[1] then fail(scenario, "a session snooze reads " .. line) end
			ns.StopSnooze(true)
			ns.StartSnooze(15)
			line = ns.L["Snoozed %s"]:format(ns.SnoozeEndsAt())
			if line:sub(1, #want[2]) ~= want[2] or not line:find("%d:%d%d", #want[2]) then
				fail(scenario, "a timed snooze reads " .. line)
			end
			ns.StopSnooze(true)
			noErrors(scenario, ns)
		end
		Mock.reset()
	end
end
