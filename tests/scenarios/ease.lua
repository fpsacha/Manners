-- Convenience: the snooze, "Not while mounted", the minimap button's menu,
-- the help and its did-you-mean, and sharing settings as text.
--
-- Every scenario name starts with "ease:" so the mutations in
-- tests/mutations/ease.py can name the one that has to catch them.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe
local findOption, optionText, pressButton = H.findOption, H.optionText, H.pressButton

local function said()
	return table.concat(Mock.printed, "\n")
end

-- The prompt put on screen with one person on it, which every scenario about
-- taking it away has to start from -- otherwise "hidden" proves nothing.
local function promptWithAnna(ns, scenario)
	freshPrompt(ns, scenario)
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	local button = ns.Prompt:GetButton()
	local macro = tostring(button:GetAttribute("macrotext1") or "")
	if not button:IsShown() or not macro:find("Anna Aim", 1, true) then
		fail(scenario, "SKIPPED -- the prompt never showed Anna, so there is nothing to hide: "
			.. macro)
		return nil
	end
	return button
end

-- What the launcher's tooltip says, one line per entry.
local function tooltipLines(ns)
	local broker = Mock.broker
	if not (broker and broker.OnTooltipShow) then return nil end
	local lines = {}
	local tt = { AddLine = function(_, text) lines[#lines + 1] = tostring(text) end }
	local ok = pcall(broker.OnTooltipShow, tt)
	if not ok then return nil end
	return table.concat(lines, "\n")
end

-- ------------------------------------------------------------------ snooze
-- A snooze takes the prompt away, keeps it away for as long as it was asked
-- to, and brings it back on the first scan after -- saying so in chat only for
-- somebody who has asked to be told what the addon is doing.
do
	local scenario = "ease: snooze hides the prompt and brings it back on time"
	Mock.reset()
	local restore = strangers({ nameplate1 = { "Anna", "Aim" } })
	local ns = load(scenario)
	if ns then
		local button = promptWithAnna(ns, scenario)
		if button then
			Mock.printed = {}
			ns.addon:HandleSlash("snooze 5")
			if button:IsShown() then
				fail(scenario, "/manners snooze 5 left the prompt on screen")
			end
			if button:GetAttribute("macrotext1") then
				fail(scenario, "the snoozed prompt is hidden but still armed, so its key binding"
					.. " casts at somebody nobody can see")
			end
			if not said():find("5 minutes", 1, true) then
				fail(scenario, "the snooze never said how long it lasts: " .. said())
			end
			-- The key binding still reaches the hidden button, and has to say
			-- why nothing happened rather than "nobody to buff".
			Mock.printed = {}
			local ran = pressButton(ns)
			if ran then fail(scenario, "a keypress on the snoozed prompt cast: " .. ran) end
			if not said():find("snoozed until", 1, true) then
				fail(scenario, "a keypress on the snoozed prompt did not say it is snoozed: "
					.. said())
			end

			-- Still away just before the end, however many scans run.
			Mock.advance(4 * 60 + 50)
			owe(ns, "Anna Aim")
			ns.addon:Tick()
			ns.addon:Tick()
			if button:IsShown() then
				fail(scenario, "the prompt came back before the five minutes were up")
			end

			-- And back on the first scan after.
			ns.db.profile.verbose = true
			Mock.printed = {}
			Mock.advance(15)
			owe(ns, "Anna Aim")
			ns.addon:Tick()
			if not button:IsShown() then
				fail(scenario, "the snooze ran out and the prompt stayed away")
			end
			if not said():find("snooze is over", 1, true) then
				fail(scenario, "the snooze ended without a word, with chat output on: " .. said())
			end
			if ns.SnoozeLeft() then
				fail(scenario, "the snooze is over and still reports time left")
			end

			-- Chat output off: the same ending, in silence.
			ns.addon:HandleSlash("snooze 1")
			ns.db.profile.verbose = false
			Mock.printed = {}
			Mock.advance(61)
			ns.addon:Tick()
			if said():find("snooze is over", 1, true) then
				fail(scenario, "the end of a snooze was announced with chat output switched off")
			end
		end
	end
	restore()
	Mock.reset()
end

-- /manners snooze off ends it at once, a bare /manners snooze takes the
-- default, and nonsense is answered rather than taken as a length.
do
	local scenario = "ease: snooze off ends it early"
	Mock.reset()
	local restore = strangers({ nameplate1 = { "Anna", "Aim" } })
	local ns = load(scenario)
	if ns then
		local button = promptWithAnna(ns, scenario)
		if button then
			ns.addon:HandleSlash("snooze")
			local left = ns.SnoozeLeft() or 0
			if math.abs(left - ns.SNOOZE_DEFAULT * 60) > 1 then
				fail(scenario, ("a bare /manners snooze lasts %ds, not the %d minutes the help"
					.. " says"):format(left, ns.SNOOZE_DEFAULT))
			end
			Mock.printed = {}
			ns.addon:HandleSlash("snooze off")
			ns.addon:Tick()
			if ns.SnoozeLeft() then fail(scenario, "/manners snooze off left the snooze running") end
			if not button:IsShown() then
				fail(scenario, "/manners snooze off ended the snooze and the prompt stayed away")
			end
			if not said():find("snooze is over", 1, true) then
				fail(scenario, "/manners snooze off said nothing: " .. said())
			end

			for _, bad in ipairs({ "banana", "0", "-5", "100000", "5 parsecs", "5h", "1h30" }) do
				Mock.printed = {}
				ns.addon:HandleSlash("snooze " .. bad)
				if ns.SnoozeLeft() then
					fail(scenario, "/manners snooze " .. bad .. " started a snooze")
					ns.StopSnooze(true)
				end
				if not said():find("from 1 to", 1, true) then
					fail(scenario, "/manners snooze " .. bad .. " was not answered: " .. said())
				end
			end

			-- A length written the way people say it, in the unit the help and
			-- every chat line use, or in hours.
			for typed, minutes in pairs({ ["15m"] = 15, ["15 min"] = 15, ["15 minutes"] = 15,
				["1 minute"] = 1, ["90 Mins"] = 90, ["1h"] = 60, ["2 hours"] = 120,
				["1.5h"] = 90, ["4 hr"] = 240 }) do
				Mock.printed = {}
				ns.addon:HandleSlash("snooze " .. typed)
				local left = ns.SnoozeLeft() or 0
				if math.abs(left - minutes * 60) > 1 then
					fail(scenario, ("/manners snooze %s snoozed for %ds, not %d minutes: %s")
						:format(typed, left, minutes, said()))
				end
				ns.StopSnooze(true)
			end
		end
	end
	restore()
	Mock.reset()
end

-- The prompt is a secure frame. A snooze started in a fight leaves it exactly
-- as the fight found it -- up, armed, still casting on a press -- and takes it
-- down when the fight ends, without one protected call in between.
do
	local scenario = "ease: a snooze started in a fight waits for the fight to end"
	Mock.reset()
	local restore = strangers({ nameplate1 = { "Anna", "Aim" } })
	local ns = load(scenario)
	if ns then
		local button = promptWithAnna(ns, scenario)
		if button then
			Mock.protect(button)
			Mock.inCombat = true
			ns.addon:PLAYER_REGEN_DISABLED()
			Mock.runTimers(0)
			Mock.protectedCalls = {}
			Mock.printed = {}
			ns.addon:HandleSlash("snooze 15")
			ns.addon:Tick()
			ns.addon:Tick()
			if #Mock.protectedCalls > 0 then
				fail(scenario, "snoozing in a fight called " .. table.concat(Mock.protectedCalls, ", ")
					.. " on the secure button, which the client refuses there")
			end
			if not button:IsShown() then
				fail(scenario, "the prompt vanished in the fight")
			end
			if not said():find("In a fight the prompt stays", 1, true) then
				fail(scenario, "a snooze started in a fight did not say it waits for the fight"
					.. " to end: " .. said())
			end

			Mock.inCombat = false
			ns.addon:PLAYER_REGEN_ENABLED()
			ns.addon:Tick()
			if button:IsShown() then
				fail(scenario, "the fight ended and the snoozed prompt stayed on screen")
			end
			if button:GetAttribute("macrotext1") then
				fail(scenario, "the fight ended and the snoozed prompt kept its macro")
			end
		end
	end
	restore()
	Mock.reset()
end

-- The launcher is where a snooze is seen from: its text says until when, its
-- tooltip says until when and how long that is, and both go back afterwards.
do
	local scenario = "ease: the launcher says a snooze is running and when it ends"
	Mock.reset()
	local ns = load(scenario)
	if ns then
		drive(scenario, ns)
		ns.Prompt:ExitTest()
		ns.addon:HandleSlash("snooze 30")
		local text = tostring(Mock.broker and Mock.broker.text)
		local tip = tooltipLines(ns) or ""
		if not text:find("snoozed until", 1, true) then
			fail(scenario, "the launcher's text does not say a snooze is running: " .. text)
		end
		if not tip:find("Snoozed until", 1, true) or not tip:find("30 minutes", 1, true) then
			fail(scenario, "the tooltip does not say when the snooze ends: " .. tip)
		end
		ns.addon:HandleSlash("snooze off")
		text = tostring(Mock.broker and Mock.broker.text)
		if text ~= "Manners" then
			fail(scenario, "the snooze ended and the launcher still says: " .. text)
		end
		tip = tooltipLines(ns) or ""
		if tip:find("Snoozed", 1, true) then
			fail(scenario, "the snooze ended and the tooltip still says: " .. tip)
		end

		-- The General tab's buttons go through the same path.
		local button = findOption(ns.optionsTable, "snooze5")
		local stop = findOption(ns.optionsTable, "snoozeStop")
		if not (button and button.func and stop and stop.func) then
			fail(scenario, "the General tab has no snooze buttons")
		else
			button.func()
			if math.abs((ns.SnoozeLeft() or 0) - 300) > 1 then
				fail(scenario, "the 5 minutes button did not snooze for five minutes")
			end
			if stop.hidden() then fail(scenario, "Stop snoozing is hidden while snoozed") end
			stop.func()
			if ns.SnoozeLeft() then fail(scenario, "Stop snoozing left the snooze running") end
			if not stop.hidden() then fail(scenario, "Stop snoozing shows with no snooze running") end
		end
	end
	Mock.reset()
end

-- The end of a snooze is read off the clock on the player's screen, so it is
-- written the way that clock writes it: 9:45 PM for a 12-hour clock, 21:45
-- for a 24-hour one or a client that will not say.
do
	local scenario = "ease: the snooze ends on the player's own clock"
	Mock.reset()
	local realGetCVar, realDate = _G.GetCVar, _G.date
	local military
	local ns = load(scenario)
	if ns then
		drive(scenario, ns)
		ns.Prompt:ExitTest()
		-- The mock's date answers one fixed string whatever it is asked; the
		-- format is the whole question here, so the real one answers it.
		_G.date = os.date
		_G.GetCVar = function(name)
			if name == "timeMgrUseMilitaryTime" then return military end
		end
		ns.StartSnooze(15)

		military = "0"
		local twelve = tostring(ns.SnoozeEndsAt())
		if not twelve:match("^[1-9]%d?:%d%d [AP]M$") then
			fail(scenario, "a 12-hour clock was told the snooze ends at " .. twelve)
		end
		military = "1"
		local full = tostring(ns.SnoozeEndsAt())
		if not full:match("^%d%d:%d%d$") then
			fail(scenario, "a 24-hour clock was told the snooze ends at " .. full)
		end
		_G.GetCVar = function() error("no", 0) end
		local unknown = tostring(ns.SnoozeEndsAt())
		if not unknown:match("^%d%d:%d%d$") then
			fail(scenario, "a client with no clock setting was told " .. unknown)
		end
		ns.StopSnooze(true)
	end
	_G.GetCVar, _G.date = realGetCVar, realDate
	Mock.reset()
end

-- ------------------------------------------------------------------ mounted
-- "Not while mounted" is off unless asked for, keeps the prompt away while
-- mounted when it is on, lets it back when the player gets off, and does
-- nothing at all to the secure button in a fight.
do
	local scenario = "ease: not while mounted"
	Mock.reset()
	local restore = strangers({ nameplate1 = { "Anna", "Aim" } })
	local realMounted = IsMounted
	local mounted = false
	IsMounted = function() return mounted end
	local ns = load(scenario)
	if ns then
		local button = promptWithAnna(ns, scenario)
		if button then
			local f = ns.db.profile.filters
			if f.hideMounted ~= false then
				fail(scenario, "Not while mounted is on by default, which hides the prompt from"
					.. " everybody who has always buffed from the saddle")
			end
			mounted = true
			owe(ns, "Anna Aim")
			ns.addon:Tick()
			if not button:IsShown() then
				fail(scenario, "the prompt went away on a mount with the switch off")
			end

			f.hideMounted = true
			if #ns.BuildQueue() > 0 then
				fail(scenario, "somebody is offered while mounted with Not while mounted on")
			end
			ns.addon:Tick()
			Mock.advance(1)
			ns.addon:Tick()
			if button:IsShown() then
				fail(scenario, "the prompt stayed on screen while mounted with Not while mounted on")
			end
			Mock.printed = {}
			pressButton(ns)
			if not said():find("mounted", 1, true) then
				fail(scenario, "a keypress on the prompt hidden for the mount did not say why: "
					.. said())
			end

			mounted = false
			owe(ns, "Anna Aim")
			ns.addon:Tick()
			if not button:IsShown() then
				fail(scenario, "the player got off the mount and the prompt stayed away")
			end

			-- In a fight nothing moves, mounted or not.
			Mock.protect(button)
			Mock.inCombat = true
			ns.addon:PLAYER_REGEN_DISABLED()
			Mock.runTimers(0)
			Mock.protectedCalls = {}
			mounted = true
			ns.addon:Tick()
			Mock.advance(1)
			ns.addon:Tick()
			if #Mock.protectedCalls > 0 then
				fail(scenario, "mounting in a fight called " .. table.concat(Mock.protectedCalls, ", ")
					.. " on the secure button")
			end
			Mock.inCombat = false
			ns.addon:PLAYER_REGEN_ENABLED()
			-- The first-login greeting waits for the end of a fight and plays
			-- a preview; that is its business, not this switch's.
			ns.Prompt:ExitTest()
			Mock.advance(1)
			ns.addon:Tick()
			if button:IsShown() then
				fail(scenario, "the fight ended on a mount and the prompt stayed on screen")
			end

			-- A value no checkbox can write is repaired to the default.
			f.hideMounted = "yes"
			ns.ClampSettings()
			if f.hideMounted ~= false then
				fail(scenario, "a nonsense value for Not while mounted survived the repair: "
					.. tostring(f.hideMounted))
			end
			if not findOption(ns.optionsTable, "hideMounted") then
				fail(scenario, "Not while mounted has no control on the options page")
			end
		end
	end
	IsMounted = realMounted
	restore()
	Mock.reset()
end

-- The one withheld answer: a client whose IsMounted throws or is missing
-- counts as on foot, so the switch can hide the prompt but never lose it.
do
	local scenario = "ease: not while mounted with no answer from the client"
	Mock.reset()
	local realMounted = IsMounted
	local ns = load(scenario)
	if ns then
		drive(scenario, ns)
		ns.db.profile.filters.hideMounted = true
		-- Asked through pcall so a throw lands here, named, rather than as the
		-- whole file falling over.
		IsMounted = function() error("no", 0) end
		local ok, hidden = pcall(ns.HiddenWhileMounted)
		if not ok then
			fail(scenario, "a throwing IsMounted took the queue down with it -> " .. tostring(hidden))
		elseif hidden then
			fail(scenario, "a throwing IsMounted read as mounted")
		end
		IsMounted = nil
		ok, hidden = pcall(ns.HiddenWhileMounted)
		if not ok or hidden then fail(scenario, "a missing IsMounted read as mounted, or threw") end
	end
	IsMounted = realMounted
	Mock.reset()
end

-- ------------------------------------------------------------------ minimap
-- A context menu in the shape the client's MenuUtil hands the generator:
-- every entry is a description that can hold entries of its own.
local function fakeDescription(text, fn)
	local d = { text = text, fn = fn, items = {} }
	function d:CreateTitle(t) self.items[#self.items + 1] = { text = t, title = true, items = {} } end
	function d:CreateDivider() end
	function d:CreateButton(t, f)
		local child = fakeDescription(t, f)
		self.items[#self.items + 1] = child
		return child
	end
	return d
end

local function findEntry(root, pattern)
	for _, item in ipairs(root and root.items or {}) do
		if item.text and item.text:find(pattern) then return item end
		local inner = findEntry(item, pattern)
		if inner then return inner end
	end
end

-- Right-click opens a menu with the switch, the snooze and the preview, and
-- does not throw the switch itself; the tooltip lists what the clicks do.
do
	local scenario = "ease: the minimap right-click opens a menu"
	Mock.reset()
	local realMenu = MenuUtil
	local opened
	MenuUtil = {
		CreateContextMenu = function(owner, generator)
			local root = fakeDescription()
			generator(owner, root)
			opened = root
			return root
		end,
	}
	local ns = load(scenario)
	if ns then
		drive(scenario, ns)
		ns.Prompt:ExitTest()
		local broker = Mock.broker
		if not (broker and broker.OnClick) then
			fail(scenario, "SKIPPED -- no launcher was registered")
		else
			local function rightClick()
				opened = nil
				local ok, err = pcall(broker.OnClick, {}, "RightButton")
				if not ok then fail(scenario, "right-clicking threw -> " .. tostring(err)) end
				return opened
			end

			local menu = rightClick()
			if not menu then
				fail(scenario, "right-clicking the minimap button opened no menu")
			else
				if not ns.db.profile.enabled then
					fail(scenario, "right-clicking switched the addon off instead of opening the menu")
					ns.db.profile.enabled = true
				end
				local switch = findEntry(menu, "^Enable$")
				local snooze15 = findEntry(menu, "15 minutes")
				local preview = findEntry(menu, "^Preview the prompt")
				local options = findEntry(menu, "^Options$")
				if not (switch and snooze15 and preview and options) then
					fail(scenario, ("the menu is missing entries -- switch %s, snooze %s,"
						.. " preview %s, options %s"):format(tostring(switch ~= nil),
						tostring(snooze15 ~= nil), tostring(preview ~= nil),
						tostring(options ~= nil)))
				else
					snooze15.fn()
					if math.abs((ns.SnoozeLeft() or 0) - 900) > 1 then
						fail(scenario, "the menu's 15 minutes did not snooze for fifteen minutes")
					end
					local stop = findEntry(rightClick(), "^Stop snoozing")
					if not stop then
						fail(scenario, "a snoozed launcher's menu has no way to stop the snooze")
					else
						stop.fn()
						if ns.SnoozeLeft() then fail(scenario, "Stop snoozing left it running") end
					end

					preview.fn()
					if not ns.Prompt:InTest() then
						fail(scenario, "the menu's Preview the prompt started no preview")
					end
					local stopPreview = findEntry(rightClick(), "^End the preview")
					if not stopPreview then
						fail(scenario, "a running preview is not offered as End the preview")
					end
					ns.Prompt:ExitTest()

					switch.fn()
					if ns.db.profile.enabled then
						fail(scenario, "the menu's Enable left it on")
					end
					local again = findEntry(rightClick(), "^Enable$")
					if again then again.fn() end
					if not ns.db.profile.enabled then
						fail(scenario, "the menu of an addon that is off does not switch it"
							.. " back on")
					end
					ns.db.profile.enabled = true
				end
			end

			local tip = tooltipLines(ns) or ""
			if not tip:find("Left click: options", 1, true)
				or not tip:find("Right click: snooze, preview, who's next and more", 1, true) then
				fail(scenario, "the tooltip does not list what the clicks do: " .. tip)
			end

			-- A client with no menu keeps the right-click it always had.
			MenuUtil = nil
			pcall(broker.OnClick, {}, "RightButton")
			if ns.db.profile.enabled then
				fail(scenario, "with no menu to open, right-click no longer switches the addon")
			end
			tip = tooltipLines(ns) or ""
			if not tip:find("Right click: switch it on", 1, true) or tip:find("snooze", 1, true) then
				fail(scenario, "with no menu, the tooltip promises one: " .. tip)
			end
			ns.db.profile.enabled = true
		end
	end
	MenuUtil = realMenu
	Mock.reset()
end

-- ------------------------------------------------------------------ help
-- Every word the dispatcher answers to is in the help, read out of the
-- dispatcher's own source so the two cannot drift: a branch added without a
-- line in COMMANDS fails here. Grouped under headings, one line each.
do
	local scenario = "ease: help lists every real command"
	Mock.reset()
	local ns = load(scenario)
	if ns then
		drive(scenario, ns)
		local source = assert(io.open(dir .. "/Core.lua", "r")):read("*a")
		local body = source:match("function addon:HandleSlash%(rawInput%)(.-)\nend\n")
		if not body then
			fail(scenario, "SKIPPED -- the dispatcher could not be found in Core.lua")
		else
			local words = {}
			for word in body:gmatch('input == "([^"]*)"') do words[word] = true end
			Mock.printed = {}
			ns.addon:HandleSlash("help")
			local help = said()
			if not help:find("Manners commands:", 1, true) then
				fail(scenario, "/manners help printed no list: " .. help)
			end
			local count = 0
			for word in pairs(words) do
				if word ~= "" and not ns.COMMAND_ALIASES[word] then
					count = count + 1
					if not help:find("/manners " .. word .. "|r", 1, true)
						and not help:find("/manners " .. word .. " ", 1, true) then
						fail(scenario, "/manners " .. word .. " is a real command the help never"
							.. " mentions")
					end
				end
			end
			if count < 15 then
				fail(scenario, ("SKIPPED -- only %d commands read out of the dispatcher"):format(count))
			end
			for _, group in ipairs(ns.COMMAND_GROUPS) do
				if not help:find(group.title, 1, true) then
					fail(scenario, "the help has no heading for " .. group.title)
				end
			end
			local known = {}
			for _, group in ipairs(ns.COMMAND_GROUPS) do known[group.key] = true end
			for _, command in ipairs(ns.COMMANDS) do
				if not known[command.group] then
					fail(scenario, "/manners " .. command.word .. " is in no group, so the help"
						.. " never prints it")
				end
				if command.help:find("\n", 1, true) then
					fail(scenario, "/manners " .. command.word .. " takes more than one line")
				end
			end
		end
	end
	Mock.reset()
end

-- A word that is nearly a command is answered with the command, and only that;
-- anything else still gets the whole list.
do
	local scenario = "ease: did you mean"
	Mock.reset()
	local ns = load(scenario)
	if ns then
		drive(scenario, ns)
		for typed, meant in pairs({ snoze = "snooze", exprot = "export", optoins = "options",
			imp = "import", verbos = "verbose", loc = "lock", tset = "test", snoozr = "snooze",
			weclome = "welcome" }) do
			Mock.printed = {}
			ns.addon:HandleSlash(typed)
			local out = said()
			if not out:find("did you mean", 1, true)
				or not out:find("/manners " .. meant .. "|r?", 1, true) then
				fail(scenario, ("/manners %s did not suggest /manners %s: %s"):format(typed, meant, out))
			end
			if out:find("Manners commands:", 1, true) then
				fail(scenario, "/manners " .. typed .. " printed the whole list under its suggestion")
			end
		end
		-- "reset" is two changes from "test", and a player typing it wants their
		-- settings back, not a preview: a guess that far out is worse than the list.
		for _, typed in ipairs({ "xyzzyplugh", "help", "?", "reset" }) do
			Mock.printed = {}
			ns.addon:HandleSlash(typed)
			local out = said()
			if not out:find("Manners commands:", 1, true) then
				fail(scenario, "/manners " .. typed .. " did not print the list: " .. out)
			end
			if out:find("did you mean", 1, true) then
				fail(scenario, "/manners " .. typed .. " was answered with a guess: " .. out)
			end
		end
		-- A command is never suggested to itself. That word reaching the guess
		-- means its branch is missing, and "did you mean /manners forms?" in
		-- answer to /manners forms hides that from the player and from the
		-- scenario that walks the list, which looks for the full help.
		for _, command in ipairs(ns.COMMANDS) do
			local guess = ns.ClosestCommand(command.word)
			if guess then
				fail(scenario, ("/manners %s, a real command, would be answered with a guess of"
					.. " /manners %s"):format(command.word, guess))
			end
		end

		-- Every suggestion is something that works.
		for _, command in ipairs(ns.COMMANDS) do
			local guess = ns.ClosestCommand(command.word .. "x")
			if guess and guess ~= command.word and not ns.COMMAND_ALIASES[guess] then
				local real = false
				for _, other in ipairs(ns.COMMANDS) do
					if other.word == guess then real = true end
				end
				if not real then fail(scenario, "suggested /manners " .. guess .. ", which is no command") end
			end
		end
		ns.Prompt:ExitTest()
		ns.StopSnooze(true)
	end
	Mock.reset()
end

-- ------------------------------------------------------------------ sharing
-- The checksum the format carries, worked out here the same way, so hostile
-- strings below can be written with a checksum that passes and reach the
-- checks behind it.
local function checksum(text)
	local h = 0
	for i = 1, #text do h = (h * 31 + text:byte(i)) % 16777213 end
	return ("%06x"):format(h)
end

local function signed(body, version)
	local head = "MNR" .. tostring(version or 1) .. ":" .. body
	return head .. ":" .. checksum(head)
end

-- What was changed below, read back the same way afterwards.
local function snapshot(ns)
	local p = ns.db.profile
	return {
		width = p.prompt.width,
		scale = p.prompt.scale,
		format = p.prompt.format,
		reasonOwed = p.prompt.reasonOwed,
		fontColor = table.concat({ p.prompt.fontColor[1], p.prompt.fontColor[2],
			p.prompt.fontColor[3], tostring(p.prompt.fontColor[4]) }, ","),
		showQueue = p.prompt.showQueue,
		proximity = p.filters.proximity,
		hideMounted = p.filters.hideMounted,
		verbose = p.verbose,
		sound = p.sound.enabled,
		reciprocate = p.timing.reciprocateWindow,
		phrases = p.speech.phrases,
		preset = tostring(p.speech.presetChoice),
		channel = p.speech.channel,
		skip = (function()
			local keys = {}
			for k in pairs(p.buff.skip) do keys[#keys + 1] = k end
			table.sort(keys)
			return table.concat(keys, ",")
		end)(),
	}
end

local function sameAs(a, b)
	for key, value in pairs(a) do
		if b[key] ~= value then
			return false, ("%s is %s, was %s"):format(key, tostring(b[key]), tostring(value))
		end
	end
	return true
end

-- What goes out comes back: a profile exported, trampled and imported again
-- is the profile that was exported, text with every separator in it included.
do
	local scenario = "ease: export and import round-trip"
	Mock.reset()
	local ns = load(scenario)
	if ns then
		drive(scenario, ns)
		ns.Prompt:ExitTest()
		local untouched = ns.ExportSettings()
		if not untouched or #untouched > 40 then
			fail(scenario, "an untouched profile exports as more than its defaults: "
				.. tostring(untouched))
		end

		local p = ns.db.profile
		p.prompt.width = 260
		p.prompt.scale = 1.25
		p.prompt.format = "{name}; = : % | + , 100% & \"quoted\""
		p.prompt.reasonOwed = "owes you -- tab\there"
		p.prompt.fontColor = { 1, 0.8, 0.123456789, 0.5 }
		p.prompt.showQueue = true
		p.filters.proximity = "cast"
		p.filters.hideMounted = true
		p.verbose = false
		p.sound.enabled = true
		p.timing.reciprocateWindow = 300
		p.speech.presetChoice = "cheeky"
		p.speech.phrases = "First line, {name}!\nSecond; line = here"
		p.speech.channel = "PARTY"
		p.buff.skip = { arcaneIntellect = true, zz_other = true }
		local wanted = snapshot(ns)
		local text = ns.ExportSettings()

		if type(text) ~= "string" or text:sub(1, 5) ~= "MNR1:" then
			fail(scenario, "the export does not start MNR1: -- " .. tostring(text))
		elseif text:find("%s") or text:find("|", 1, true) then
			fail(scenario, "the export holds whitespace or a |, which a chat line or a text box"
				.. " will not carry intact: " .. text)
		else
			-- Trample everything, then read it back.
			p.prompt.width, p.prompt.scale = 99, 2
			p.prompt.format, p.prompt.reasonOwed = "{name} x", "y"
			p.prompt.fontColor = { 0, 0, 0, 1 }
			p.prompt.showQueue, p.filters.proximity = false, "beside"
			p.filters.hideMounted, p.verbose, p.sound.enabled = false, true, false
			p.timing.reciprocateWindow = 60
			p.speech.presetChoice, p.speech.phrases, p.speech.channel = nil, "x", "SAY"
			p.buff.skip = { something = true }
			p.enabled, p.debugClicks = true, true
			local before = ns.ExportSettings()

			-- With a line break in it, the way a text box that wraps can hand it over.
			local wrapped = text:sub(1, 20) .. "\n  " .. text:sub(21)
			local ok, message = ns.ImportSettings(wrapped)
			if not ok then
				fail(scenario, "its own export was refused: " .. tostring(message))
			else
				local same, why = sameAs(wanted, snapshot(ns))
				if not same then fail(scenario, "the import did not give back what was exported: " .. why) end
				if not p.enabled or not p.debugClicks then
					fail(scenario, "the import touched the on switch or the click log, which are"
						.. " not shared")
				end
				if not tostring(message):find("undo", 1, true) then
					fail(scenario, "the import never said how to undo it: " .. tostring(message))
				end
				Mock.printed = {}
				ns.addon:HandleSlash("import undo")
				if ns.ExportSettings() ~= before then
					fail(scenario, "/manners import undo did not put the old settings back")
				end
				local first = said()
				if not first:find("from before the import are back", 1, true)
					or first:find("undo", 1, true) then
					fail(scenario, "/manners import undo described itself as an import, or told the"
						.. " player to undo it: " .. first)
				end
				-- Used up: a second undo is not the import all over again.
				Mock.printed = {}
				ns.addon:HandleSlash("import undo")
				if ns.ExportSettings() ~= before then
					fail(scenario, "a second /manners import undo put the imported settings back")
				end
				if not said():find("nothing to undo", 1, true) then
					fail(scenario, "a second /manners import undo said: " .. said())
				end
			end

			-- The same string through the options page's own boxes.
			local paste = findOption(ns.optionsTable, "sharePaste")
			local copy = findOption(ns.optionsTable, "shareText")
			if not (paste and paste.set and paste.validate and copy and copy.get) then
				fail(scenario, "the General tab has no boxes to copy and paste settings")
			else
				Mock.printed = {}
				if paste.validate({ "sharePaste" }, text) ~= true then
					fail(scenario, "the paste box refused a good string")
				end
				paste.set({ "sharePaste" }, text)
				if copy.get({ "shareText" }) ~= text then
					fail(scenario, "the copy box does not show what was just pasted")
				end
				if not said():find("imported", 1, true) then
					fail(scenario, "pasting into the box said nothing in chat: " .. said())
				end
			end
		end

		-- Speaking a line is never switched on by somebody else's string.
		p.speech.enabled = true
		local talking = ns.ExportSettings()
		p.speech.enabled = false
		local ok, message = ns.ImportSettings(talking)
		if not ok then
			fail(scenario, "a string with speech on was refused: " .. tostring(message))
		elseif p.speech.enabled then
			fail(scenario, "an imported string switched on speaking to other players")
		elseif not tostring(message):find("talks to other players", 1, true) then
			fail(scenario, "the import left speech off without saying so: " .. tostring(message))
		end

		-- In a fight: nothing protected, and the line says what waits.
		local button = ns.Prompt:GetButton()
		Mock.protect(button)
		Mock.inCombat = true
		Mock.protectedCalls = {}
		ok, message = ns.ImportSettings(text)
		if #Mock.protectedCalls > 0 then
			fail(scenario, "an import in a fight called " .. table.concat(Mock.protectedCalls, ", "))
		end
		if not tostring(message):find("when this fight ends", 1, true) then
			fail(scenario, "an import in a fight did not say the prompt waits: " .. tostring(message))
		end
		Mock.inCombat = false
		ns.addon:PLAYER_REGEN_ENABLED()
	end
	Mock.reset()
end

-- The lock and the prompt's place are never in a string. The obvious moment to
-- copy one is with the prompt unlocked to drag it, and an import that carried
-- that would unlock -- and so stop -- everybody who pasted it.
do
	local scenario = "ease: an import never unlocks or moves the prompt"
	Mock.reset()
	local ns = load(scenario)
	if ns then
		drive(scenario, ns)
		ns.Prompt:ExitTest()
		local p = ns.db.profile.prompt
		p.locked, p.point, p.relPoint, p.x, p.y = false, "TOPLEFT", "TOPLEFT", 900, 40
		p.width = 260
		local text = ns.ExportSettings()
		for _, name in ipairs({ "prompt.locked", "prompt.point", "prompt.relPoint",
			"prompt.x", "prompt.y" }) do
			if text:find(name .. "=", 1, true) then
				fail(scenario, name .. " is written into the settings string: " .. text)
			end
		end

		p.locked, p.point, p.relPoint, p.x, p.y = true, "BOTTOM", "BOTTOM", 0, 300
		p.width = 220
		local ok, message = ns.ImportSettings(text)
		if not ok then
			fail(scenario, "the string was refused: " .. tostring(message))
		else
			if p.locked ~= true then
				fail(scenario, "importing a string copied from an unlocked prompt unlocked this one,"
					.. " and an unlocked prompt never casts")
			end
			if p.point ~= "BOTTOM" or p.relPoint ~= "BOTTOM" or p.x ~= 0 or p.y ~= 300 then
				fail(scenario, ("the import moved the prompt to %s %s %s,%s"):format(tostring(p.point),
					tostring(p.relPoint), tostring(p.x), tostring(p.y)))
			end
			if p.width ~= 260 then
				fail(scenario, "the prompt's width, which is shared, did not arrive")
			end
		end
		-- Nor through a string written by hand to carry them.
		ns.ImportSettings(signed("prompt.locked=0;prompt.x=900;prompt.y=40"))
		if p.locked ~= true or p.x ~= 0 or p.y ~= 300 then
			fail(scenario, "a string written to carry the lock and the place still changed them")
		end

		-- And an offset no screen has, however it got into the file, is put back.
		p.x = 1e300
		ns.ClampSettings()
		if p.x ~= 0 or p.y ~= 300 or p.point ~= "BOTTOM" then
			fail(scenario, "an offset of 1e300 survived the repair: " .. tostring(p.x))
		end
		p.point, p.relPoint, p.x, p.y = "CENTER", "CENTER", -2500, 1200
		ns.ClampSettings()
		if p.x ~= -2500 or p.y ~= 1200 or p.point ~= "CENTER" then
			fail(scenario, "the repair moved a prompt sitting where a wide screen can put it")
		end
	end
	Mock.reset()
end

-- Speaking stays the player's while they have it on: the switch, and also
-- what is said and where. With it off those change nothing anybody hears, so
-- they arrive as the string has them.
do
	local scenario = "ease: an import keeps what you say while speaking is on"
	Mock.reset()
	local ns = load(scenario)
	if ns then
		drive(scenario, ns)
		ns.Prompt:ExitTest()
		local s = ns.db.profile.speech
		s.enabled, s.channel, s.onlyWhenReturning = false, "YELL", false
		s.phrases = "HELLO EVERYBODY"
		local loud = ns.ExportSettings()

		s.enabled, s.channel, s.onlyWhenReturning, s.phrases = true, "SAY", true, "thanks!"
		local ok, message = ns.ImportSettings(loud)
		if not ok then
			fail(scenario, "the string was refused: " .. tostring(message))
		else
			if s.channel ~= "SAY" or s.phrases ~= "thanks!" or s.onlyWhenReturning ~= true
				or s.enabled ~= true then
				fail(scenario, ("a pasted string changed what a player who speaks says: channel %s,"
					.. " phrases %q, only when returning %s"):format(tostring(s.channel),
					tostring(s.phrases), tostring(s.onlyWhenReturning)))
			end
			if not tostring(message):find("kept as you had it", 1, true) then
				fail(scenario, "the import kept the player's words without saying so: "
					.. tostring(message))
			end
		end

		-- Nothing about speech in the string: nothing kept, nothing said.
		ok, message = ns.ImportSettings(signed("prompt.width=240"))
		if tostring(message):find("kept as you had it", 1, true) then
			fail(scenario, "a string with no words in it was said to have had some kept: "
				.. tostring(message))
		end
		if s.phrases ~= "thanks!" or s.channel ~= "SAY" then
			fail(scenario, "a string with no words in it reset a speaking player's words")
		end

		s.enabled = false
		ns.ImportSettings(loud)
		if s.channel ~= "YELL" or s.phrases ~= "HELLO EVERYBODY" then
			fail(scenario, "with speaking off, the string's words did not arrive")
		end
		if s.enabled then fail(scenario, "the import switched speaking on") end
	end
	Mock.reset()
end

-- The undo an import keeps is for the profile it was made on. Switching
-- profile and undoing would lay one profile's old settings over another's.
do
	local scenario = "ease: an undo belongs to the profile it was made on"
	Mock.reset()
	local ns = load(scenario)
	if ns then
		drive(scenario, ns)
		ns.Prompt:ExitTest()
		if not ns.db.SetProfile then
			fail(scenario, "SKIPPED -- the mock has no profile switch")
		else
			ns.db.profile.prompt.width = 300
			ns.ImportSettings(signed("prompt.width=250"))
			ns.db:SetProfile("Alt")
			ns.db.profile.prompt.width = 180
			local before = ns.ExportSettings()
			Mock.printed = {}
			ns.addon:HandleSlash("import undo")
			if ns.ExportSettings() ~= before then
				fail(scenario, "an undo made on one profile rewrote another")
			end
			if not said():find("nothing to undo", 1, true) then
				fail(scenario, "an undo on a profile that imported nothing said: " .. said())
			end
			ns.db:SetProfile("Default")
		end
	end
	Mock.reset()
end

-- Nothing that is not a whole, untouched settings string changes anything,
-- each refusal says why in a sentence, and nothing handed in is ever run.
do
	local scenario = "ease: malformed and hostile import strings are rejected"
	Mock.reset()
	local ns = load(scenario)
	if ns then
		drive(scenario, ns)
		ns.Prompt:ExitTest()
		ns.db.profile.prompt.width = 260
		local good = ns.ExportSettings()
		local ran = {}
		local realLoadstring, realLoad, realDofile = _G.loadstring, _G.load, _G.dofile
		local function trap(name) return function() ran[#ran + 1] = name end end
		_G.loadstring, _G.load, _G.dofile = trap("loadstring"), trap("load"), trap("dofile")

		-- Nothing at all, straight in: through the slash command a bare
		-- /manners import is a question about where to paste, not a refusal.
		local emptyOk, emptyWhy = ns.ImportSettings("  \n ")
		if emptyOk or not tostring(emptyWhy):find("nothing to import", 1, true) then
			fail(scenario, "an empty paste was not refused as empty: " .. tostring(emptyWhy))
		end

		local cases = {
			{ "not ours", "hello there", "not a Manners settings string" },
			{ "code", "return os.exit()", "not a Manners settings string" },
			{ "cut short", good:sub(1, -3), "incomplete" },
			{ "cut in the middle", good:sub(1, 12), "incomplete" },
			{ "one letter changed", good:gsub("260", "261"), "incomplete" },
			{ "from a newer version", signed("prompt.width=100", 2), "newer version" },
			{ "a word for a number", signed("prompt.width=banana"), "prompt.width" },
			{ "an infinite number", signed("prompt.width=1e999"), "prompt.width" },
			{ "a hex number", signed("prompt.width=0x10"), "prompt.width" },
			{ "a word for a switch", signed("verbose=true"), "verbose" },
			{ "a broken escape", signed("prompt.format=%ZZ"), "prompt.format" },
			{ "a control character", signed("prompt.format=a%01b"), "prompt.format" },
			{ "a short colour", signed("prompt.fontColor=1,2"), "prompt.fontColor" },
			{ "a long colour", signed("prompt.fontColor=1,1,1,1,1"), "prompt.fontColor" },
			{ "a path in the skip list", signed("buff.skip=../../x"), "buff.skip" },
			{ "a pair with no value", signed("prompt.width"), "damaged" },
			{ "an empty pair", signed("prompt.width=100;;verbose=0"), "damaged" },
			{ "far too long", "MNR1:" .. string.rep("a=1;", 30000) .. ":000000", "longer" },
		}
		for _, case in ipairs(cases) do
			local label, text, reason = case[1], case[2], case[3]
			local before = ns.ExportSettings()
			Mock.printed = {}
			local ok, err = pcall(ns.addon.HandleSlash, ns.addon, "import " .. text)
			local out = said()
			if not ok then
				fail(scenario, label .. ": the import threw -> " .. tostring(err))
			elseif ns.ExportSettings() ~= before then
				fail(scenario, label .. ": a refused string changed the settings")
			elseif not out:find(reason, 1, true) then
				fail(scenario, ("%s: refused without saying why (%q): %s"):format(label, reason, out))
			end
		end

		-- A name the list does not know is skipped, never written -- the
		-- metatable key and a whole section's name included.
		local p = ns.db.profile
		local ok, message = ns.ImportSettings(signed("__index=1;prompt=1;prompt.width=300;"
			.. "prompt.__newindex=2"))
		if not ok then
			fail(scenario, "a string with unknown names beside a good one was refused: "
				.. tostring(message))
		else
			if rawget(p, "__index") ~= nil or type(p.prompt) ~= "table"
				or rawget(p.prompt, "__newindex") ~= nil then
				fail(scenario, "an unknown name was written into the profile")
			end
			if p.prompt.width ~= 300 then
				fail(scenario, "the known setting beside the unknown ones was not applied")
			end
			if not tostring(message):find("left out", 1, true) then
				fail(scenario, "unknown settings were skipped without a word: " .. tostring(message))
			end
		end

		-- And a value out of range is repaired the way a saved one is.
		ns.ImportSettings(signed("prompt.width=99999;filters.proximity=everywhere"))
		if p.prompt.width ~= 500 or p.filters.proximity ~= "near" then
			fail(scenario, ("an imported value outside what the page allows survived:"
				.. " width %s, proximity %s"):format(tostring(p.prompt.width),
				tostring(p.filters.proximity)))
		end

		-- The options box refuses the same way, before anything changes.
		local paste = findOption(ns.optionsTable, "sharePaste")
		if paste and paste.validate then
			local answer = paste.validate({ "sharePaste" }, "hello")
			if answer == true or not tostring(answer):find("not a Manners", 1, true) then
				fail(scenario, "the paste box let a string that is not ours through: "
					.. tostring(answer))
			end
		end

		_G.loadstring, _G.load, _G.dofile = realLoadstring, realLoad, realDofile
		if #ran > 0 then
			fail(scenario, "reading a settings string ran " .. table.concat(ran, ", ")
				.. " -- a pasted string must never be run as code")
		end
	end
	Mock.reset()
end

-- /manners export and a bare /manners import open the page on the boxes
-- rather than printing a string nobody can copy out of chat.
do
	local scenario = "ease: export opens the box to copy from"
	Mock.reset()
	local ns = load(scenario)
	if ns then
		drive(scenario, ns)
		ns.Prompt:ExitTest()
		local copy = findOption(ns.optionsTable, "shareText")
		Mock.printed = {}
		ns.addon:HandleSlash("export")
		if not copy or copy.hidden() then
			fail(scenario, "/manners export left the box with the settings in it shut")
		end
		if not said():find("Share settings", 1, true) then
			fail(scenario, "/manners export did not say where the settings are: " .. said())
		end
		-- The game cannot copy for the player, so nothing on the page may say
		-- it has, and the box itself says how.
		local button = findOption(ns.optionsTable, "shareCopy")
		if button then
			-- Both of its labels: shut, and open.
			for _ = 1, 2 do
				local name = optionText(button.name)
				if tostring(name):find("Copy", 1, true) then
					fail(scenario, "a button labelled " .. tostring(name) .. " copies nothing")
				end
				button.func()
			end
		end
		if copy and not tostring(optionText(copy.name)):find("Ctrl+C", 1, true) then
			fail(scenario, "the box to copy from does not say how to copy: "
				.. tostring(optionText(copy.name)))
		end
		Mock.printed = {}
		ns.addon:HandleSlash("import")
		if not said():find("paste", 1, true) then
			fail(scenario, "a bare /manners import did not say where to paste: " .. said())
		end
		Mock.printed = {}
		ns.addon:HandleSlash("import undo")
		if not said():find("nothing to undo", 1, true) then
			fail(scenario, "/manners import undo with nothing imported said: " .. said())
		end
	end
	Mock.reset()
end
