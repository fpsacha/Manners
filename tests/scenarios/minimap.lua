-- The launcher: the minimap button, a broker display and the addon
-- compartment. What each click does, what the right-click menu offers and what
-- it holds back in a fight, what the tooltip says in each state, and how the
-- icon and the text read at a glance.
--
-- Every scenario name starts with "minimap:" so the mutations in
-- tests/mutations/minimap.py can name the one that has to catch them.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

local function said()
	return table.concat(Mock.printed, "\n")
end

-- A context menu in the shape the client's MenuUtil hands the generator, with
-- the parts of an element description the launcher uses: checkboxes and radios
-- that ask their own state, and entries that can be greyed out and given a
-- tooltip. The one in ease.lua has none of those, which is the other shape a
-- client can have, and stays that way on purpose.
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
	function d:SetEnabled(on) self.enabled = on and true or false end
	function d:SetTooltip(fn) self.tooltip = fn end
	return d
end

local function find(root, pattern)
	for _, item in ipairs(root and root.items or {}) do
		if item.text and tostring(item.text):find(pattern) then return item end
		local inner = find(item, pattern)
		if inner then return inner end
	end
end

-- Direct children only, for "is this in that submenu".
local function child(root, pattern)
	for _, item in ipairs(root and root.items or {}) do
		if item.text and tostring(item.text):find(pattern) then return item end
	end
end

-- Stands in for the client's MenuUtil for the length of `body`, and hands it
-- a function that right-clicks the launcher and returns the menu it opened.
local function withMenu(body)
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
	local function rightClick()
		opened = nil
		local ok, err = pcall(Mock.broker.OnClick, {}, "RightButton")
		if not ok then error("right-clicking threw -> " .. tostring(err)) end
		return opened
	end
	local ok, err = pcall(body, rightClick, function() return opened end)
	MenuUtil = real
	if not ok then error(err, 0) end
end

local function tooltipLines()
	local broker = Mock.broker
	if not (broker and broker.OnTooltipShow) then return nil end
	local lines = {}
	local tt = { AddLine = function(_, text) lines[#lines + 1] = tostring(text) end }
	local ok, err = pcall(broker.OnTooltipShow, tt)
	if not ok then return "THREW: " .. tostring(err) end
	return table.concat(lines, "\n")
end

-- Two people who buffed you, with Anna on the prompt and Bo behind her.
local function annaAndBo(ns, scenario)
	freshPrompt(ns, scenario)
	owe(ns, "Anna Aim")
	Mock.advance(1)
	owe(ns, "Bo Bell")
	ns.addon:Tick()
	local button = ns.Prompt:GetButton()
	local macro = tostring(button:GetAttribute("macrotext1") or "")
	local showing = ns.Prompt:Showing()
	if not button:IsShown() or not showing or not macro:find(showing.name, 1, true) then
		fail(scenario, "SKIPPED -- the prompt never came up for either of them: " .. macro)
		return nil
	end
	local queue = H.inQueue(ns)
	if not (queue["Anna Aim"] and queue["Bo Bell"]) then
		fail(scenario, "SKIPPED -- the queue does not hold both of them")
		return nil
	end
	return button, showing
end

-- A press counter on the button's own click scripts, so a menu entry that
-- went anywhere near a cast is caught at the door.
local function watchPresses(button)
	local presses = 0
	for _, which in ipairs({ "PreClick", "OnClick", "PostClick" }) do
		local real = button.scripts[which]
		if real then
			button.scripts[which] = function(...)
				presses = presses + 1
				return real(...)
			end
		end
	end
	return function() return presses end
end

-- ------------------------------------------------------------------ clicks
-- Left opens the options, shift-left the ledger, middle throws the switch
-- both ways and says so, and right opens the menu -- or, on a client with no
-- menu, throws the switch as it always did.
Mock.reset()
do
	local scenario = "minimap: every click does its job"
	local restore = strangers({ nameplate1 = { "Anna", "Aim" } })
	local ns = load(scenario)
	if ns then
		freshPrompt(ns, scenario)
		local broker = Mock.broker
		if not (broker and broker.OnClick) then
			fail(scenario, "SKIPPED -- no launcher was registered")
		else
			local optionsOpened = 0
			local realOpen = ns.OpenOptions
			ns.OpenOptions = function() optionsOpened = optionsOpened + 1 end

			broker.OnClick({}, "LeftButton")
			if optionsOpened ~= 1 then fail(scenario, "a left click did not open the options") end

			local realShift = IsShiftKeyDown
			IsShiftKeyDown = function() return true end
			broker.OnClick({}, "LeftButton")
			IsShiftKeyDown = realShift
			local window = ns.Ledger.Window()
			if not (window and window:IsShown()) then
				fail(scenario, "a shift-left click did not open the ledger")
			end
			if optionsOpened ~= 1 then fail(scenario, "a shift-left click opened the options too") end

			Mock.printed = {}
			Mock.optionsRepaints = 0
			broker.OnClick({}, "MiddleButton")
			if ns.db.profile.enabled then
				fail(scenario, "a middle click did not switch Manners off")
			else
				-- Off is saved, and a wheel pressed on the minimap's edge throws
				-- it too, so the line has to carry the way back.
				if not said():find("middle-click it again", 1, true)
					or not said():find("/manners on", 1, true) then
					fail(scenario, "a middle click switched it off without saying how to switch it back: "
						.. said())
				end
				if not tostring(broker.text):find("off", 1, true) then
					fail(scenario, "a middle click switched it off and the launcher still reads "
						.. tostring(broker.text))
				end
				if Mock.optionsRepaints == 0 then
					fail(scenario, "a middle click left an open options page drawing the old value")
				end
				broker.OnClick({}, "MiddleButton")
				if not ns.db.profile.enabled then
					fail(scenario, "a second middle click did not switch it back on")
				end
			end
			if optionsOpened ~= 1 then fail(scenario, "a middle click opened the options") end

			local ok, err = pcall(withMenu, function(rightClick)
				local menu = rightClick()
				if not menu then fail(scenario, "a right click opened no menu") end
				if not ns.db.profile.enabled then
					fail(scenario, "a right click threw the switch instead of opening the menu")
				end
			end)
			if not ok then fail(scenario, tostring(err)) end

			local realMenu = MenuUtil
			MenuUtil = nil
			Mock.printed = {}
			broker.OnClick({}, "RightButton")
			if ns.db.profile.enabled then
				fail(scenario, "with no menu to open, a right click no longer throws the switch")
			elseif not said():find("right-click it again", 1, true) then
				fail(scenario, "a right click that switched it off names another way back: " .. said())
			end
			MenuUtil = realMenu
			ns.db.profile.enabled = true
			ns.OpenOptions = realOpen
		end
	end
	restore()
	Mock.reset()
end

-- ------------------------------------------------------------------ menu
-- Every entry is there, in its submenu, reads the state it is in, and does
-- what it says.
Mock.reset()
do
	local scenario = "minimap: the menu has every entry and each one works"
	local restore = strangers({ nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bo", "Bell" } })
	local ns = load(scenario)
	if ns then
		local button = annaAndBo(ns, scenario)
		if button then
			-- The profile list, which the mock's database does not keep.
			ns.db.GetProfiles = function(_, t)
				t = t or {}
				t[1], t[2] = "Default", "Healer"
				return t, 2
			end
			ns.db.GetCurrentProfile = function() return Mock.sv.profileName or "Default" end

			local ok, err = pcall(withMenu, function(rightClick)
				local menu = rightClick()
				if not menu then
					fail(scenario, "SKIPPED -- no menu opened")
					return
				end
				local enable = child(menu, "^Enable$")
				local snooze = child(menu, "^Snooze$")
				local preview = child(menu, "^Preview the prompt")
				local ledger = child(menu, "^Open the ledger$")
				local next = child(menu, "^Who's next$")
				local prompt = child(menu, "^Prompt$")
				local chat = child(menu, "^Tell me in chat what the addon is doing$")
				local profiles = child(menu, "^Profiles$")
				local options = child(menu, "^Options$")
				local missing = {}
				for name, entry in pairs({ enable = enable, snooze = snooze, preview = preview,
					ledger = ledger, ["who's next"] = next, prompt = prompt, chat = chat,
					profiles = profiles, options = options }) do
					if not entry then missing[#missing + 1] = name end
				end
				if #missing > 0 then
					table.sort(missing)
					fail(scenario, "the menu is missing " .. table.concat(missing, ", "))
					return
				end

				-- In groups: the state, the people, the prompt, the options.
				local shape = {}
				for _, item in ipairs(menu.items) do
					shape[#shape + 1] = item.divider and "|" or tostring(item.text)
				end
				shape = table.concat(shape, " / ")
				local want = "Manners / Enable / Snooze / | / Who's next / Open the ledger / | / "
					.. "Preview the prompt / Prompt / Tell me in chat what the addon is doing / Profiles / | / Options"
				if shape ~= want then
					fail(scenario, "the menu is not grouped as it should be: " .. shape)
				end

				-- The switch, as a checkbox reading the switch.
				if enable.kind ~= "checkbox" or enable.get() ~= true then
					fail(scenario, "the Enable checkbox does not read the switch as on")
				end
				enable.fn()
				if ns.db.profile.enabled then fail(scenario, "Enable did not switch Manners off") end
				local again = child(rightClick(), "^Enable$")
				if not again or again.get() ~= false then
					fail(scenario, "the Enable checkbox does not read the switch as off")
				end
				if again then again.fn() end
				if not ns.db.profile.enabled then fail(scenario, "Enable did not switch it back on") end

				-- The snooze lengths, an hour among them, and the way out of one.
				for _, length in ipairs({ "5 minutes", "15 minutes", "30 minutes", "60 minutes" }) do
					if not child(snooze, "^For " .. length .. "$") then
						fail(scenario, "the Snooze submenu has no " .. length
							.. (length == "60 minutes" and " -- no hour-long snooze" or ""))
					end
				end
				if child(snooze, "^Stop snoozing") then
					fail(scenario, "Stop snoozing is offered with no snooze running")
				end
				local hour = child(snooze, "^For 60 minutes$")
				if hour then
					hour.fn()
					if math.abs((ns.SnoozeLeft() or 0) - 3600) > 1 then
						fail(scenario, "For 60 minutes did not snooze for an hour")
					end
					local whileSnoozed = rightClick()
					-- Nobody is offered while snoozed, so Who's next says that
					-- rather than listing people no prompt is going to show.
					local nobody = child(child(whileSnoozed, "^Who's next$"), "")
					if not nobody or not tostring(nobody.text):find("^Nobody %-%- snoozed until ")
						or nobody.enabled ~= false or #nobody.items > 0 then
						fail(scenario, "while snoozed, who's next lists people no prompt will offer: "
							.. tostring(nobody and nobody.text))
					end
					local snoozed = child(whileSnoozed, "^Snoozed until ")
					local stop = snoozed and child(snoozed, "^Stop snoozing$")
					if not stop then
						fail(scenario, "a snooze running is not named on the menu with a way to stop it")
					else
						stop.fn()
						if ns.SnoozeLeft() then fail(scenario, "Stop snoozing left it running") end
					end
				end

				-- Who's next: Anna on the prompt, Bo behind her, each with both acts.
				local anna = child(next, "^Anna Aim %-%- .+, on the prompt$")
				local bo = child(next, "^Bo Bell %-%- ")
				if not (anna and bo) then
					fail(scenario, "who's next does not list the prompt and the queue: "
						.. tostring(next.items[1] and next.items[1].text) .. " / "
						.. tostring(next.items[2] and next.items[2].text))
				else
					if not tostring(anna.text):find("buffed you", 1, true) then
						fail(scenario, "who's next does not say why Anna is there: " .. anna.text)
					end
					if not (child(anna, "^Skip for now$") and child(anna, "^Never offer$")) then
						fail(scenario, "a person on who's next has no Skip for now and Never offer")
					end
				end

				-- With nothing to cast, the same reason the tooltip gives, and
				-- nobody listed.
				local realResolve = ns.ResolveBuff
				ns.ResolveBuff = function() return nil end
				local stuck = child(child(rightClick(), "^Who's next$"), "")
				ns.ResolveBuff = realResolve
				if not stuck or stuck.enabled ~= false or tostring(stuck.text):find("Anna Aim", 1, true)
					or tostring(stuck.text):find("Bo Bell", 1, true) then
					fail(scenario, "with nothing to cast, who's next still lists people: "
						.. tostring(stuck and stuck.text))
				end

				-- The prompt's own settings.
				local locked = child(prompt, "^Locked$")
				local reset = child(prompt, "^Reset position$")
				local quiet = child(prompt, "^Stay quiet in combat$")
				local sound = child(prompt, "^Play a sound$")
				local effects = child(prompt, "^Effects$")
				local full = effects and child(effects, "^Full$")
				local calm = effects and child(effects, "^Calm")
				if not (locked and reset and quiet and sound and full and calm) then
					fail(scenario, "the Prompt submenu is missing entries")
				else
					if locked.get() ~= true then fail(scenario, "Locked does not read the lock") end
					locked.fn()
					if ns.db.profile.prompt.locked then fail(scenario, "Locked did not unlock the prompt") end
					child(child(rightClick(), "^Prompt$"), "^Locked$").fn()
					if not ns.db.profile.prompt.locked then fail(scenario, "Locked did not lock it again") end

					local p = ns.db.profile.prompt
					p.x, p.y = 123, 456
					reset.fn()
					local d = ns.defaults.profile.prompt
					if p.x ~= d.x or p.y ~= d.y or p.point ~= d.point then
						fail(scenario, "Reset position did not put the prompt back")
					end

					local wasQuiet = p.hideInCombat == true
					quiet.fn()
					if (p.hideInCombat == true) == wasQuiet then
						fail(scenario, "Stay quiet in combat did not change the setting")
					end
					local wasSound = ns.db.profile.sound.enabled == true
					sound.fn()
					if (ns.db.profile.sound.enabled == true) == wasSound then
						fail(scenario, "Play a sound did not change the setting")
					end
					if full.kind ~= "radio" or full.get() ~= true or calm.get() ~= false then
						fail(scenario, "the Effects radios do not read the setting")
					end
					calm.fn()
					if p.effects ~= "calm" then fail(scenario, "Effects Calm did not set calm") end
					local reopened = child(child(child(rightClick(), "^Prompt$"), "^Effects$"), "^Calm")
					if not reopened or reopened.get() ~= true then
						fail(scenario, "the Effects radios do not read the setting once it is Calm")
					end
					full.fn()
					if p.effects ~= "full" then fail(scenario, "Effects Full did not set full") end
				end

				-- Told in chat, and the profiles.
				local verbose = ns.db.profile.verbose == true
				chat.fn()
				if (ns.db.profile.verbose == true) == verbose then
					fail(scenario, "Tell me in chat did not change the setting")
				end
				local healer = child(profiles, "^Healer$")
				local default = child(profiles, "^Default$")
				if not (healer and default) or default.get() ~= true then
					fail(scenario, "the Profiles submenu does not list the profiles and the current one")
				else
					healer.fn()
					if ns.db:GetCurrentProfile() ~= "Healer" then
						fail(scenario, "picking a profile on the menu did not switch to it")
					end
					ns.db:SetProfile("Default")
				end
				-- One profile is nothing to switch to, and no entry at all.
				local realProfiles = ns.db.GetProfiles
				ns.db.GetProfiles = function(_, t)
					t = t or {}
					t[1] = "Default"
					return t, 1
				end
				if child(rightClick(), "^Profiles$") then
					fail(scenario, "the menu offers a Profiles submenu with one profile in it")
				end
				ns.db.GetProfiles = realProfiles

				-- The ledger, and the options.
				ledger.fn()
				local window = ns.Ledger.Window()
				if not (window and window:IsShown()) then
					fail(scenario, "Open the ledger did not open it")
				end
				local optionsOpened = 0
				local realOpen = ns.OpenOptions
				ns.OpenOptions = function() optionsOpened = optionsOpened + 1 end
				options.fn()
				ns.OpenOptions = realOpen
				if optionsOpened ~= 1 then fail(scenario, "Options did not open the options") end
			end)
			if not ok then fail(scenario, tostring(err)) end
			for _, e in ipairs(ns.errors or {}) do
				fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
			end
		end
	end
	restore()
	Mock.reset()
end

-- ------------------------------------------------------------------ combat
-- In a fight the entries that move the prompt or change what it is armed with
-- are greyed out with the reason on them, and refuse even when clicked --
-- a menu opened before the pull is still open after it. Nothing on the menu
-- touches the secure button while the lockdown is on.
Mock.reset()
do
	local scenario = "minimap: in a fight the menu holds back what moves the prompt"
	local restore = strangers({ nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bo", "Bell" } })
	local ns = load(scenario)
	if ns then
		local button = annaAndBo(ns, scenario)
		if button then
			ns.db.GetProfiles = function(_, t)
				t = t or {}
				t[1], t[2] = "Default", "Healer"
				return t, 2
			end
			ns.db.GetCurrentProfile = function() return Mock.sv.profileName or "Default" end
			Mock.protect(button)
			Mock.inCombat = true
			Mock.protectedCalls = {}
			local p = ns.db.profile.prompt
			local where = { p.point, p.x, p.y }
			p.x, p.y = 77, 88

			local ok, err = pcall(withMenu, function(rightClick)
				local menu = rightClick()
				if not menu then
					fail(scenario, "SKIPPED -- no menu opened")
					return
				end
				local prompt = child(menu, "^Prompt$")
				local held = {
					["Locked"] = prompt and child(prompt, "^Locked"),
					["Reset position"] = prompt and child(prompt, "^Reset position"),
					["Preview the prompt"] = child(menu, "^Preview the prompt"),
					["the Healer profile"] = child(child(menu, "^Profiles$"), "^Healer"),
				}
				for name, entry in pairs(held) do
					if not entry then
						fail(scenario, name .. " is not on the menu in a fight")
					else
						if entry.enabled ~= false then
							fail(scenario, name .. " is not greyed out in a fight")
						end
						if not tostring(entry.text):find("after the fight", 1, true) then
							fail(scenario, name .. " does not say it waits for after the fight: "
								.. tostring(entry.text))
						end
						if type(entry.tooltip) ~= "function" then
							fail(scenario, name .. " has no tooltip saying why it is greyed out")
						end
					end
				end

				-- Clicked anyway, as a menu opened before the pull can be.
				Mock.printed = {}
				if held["Locked"] then held["Locked"].fn() end
				if held["Reset position"] then held["Reset position"].fn() end
				if held["the Healer profile"] then held["the Healer profile"].fn() end
				if not p.locked then fail(scenario, "Locked unlocked the prompt in a fight") end
				if p.x ~= 77 or p.y ~= 88 then fail(scenario, "Reset position ran in a fight") end
				if ns.db:GetCurrentProfile() ~= "Default" then
					fail(scenario, "a profile was switched in a fight")
					ns.db:SetProfile("Default")
				end
				if not said():find("after the fight", 1, true) then
					fail(scenario, "a held entry clicked in a fight said nothing: " .. said())
				end

				-- And the ones a fight does not stop stay open.
				for _, pattern in ipairs({ "^Enable$", "^Snooze$", "^Who's next$" }) do
					local entry = child(menu, pattern)
					if not entry or entry.enabled == false then
						fail(scenario, pattern .. " is greyed out in a fight, where it is safe")
					end
				end
				local quiet = prompt and child(prompt, "^Stay quiet in combat$")
				if not quiet or quiet.enabled == false then
					fail(scenario, "Stay quiet in combat is held back in a fight, where it is only drawing")
				end
				-- The switch and a snooze, thrown in the fight.
				child(menu, "^Enable$").fn()
				child(menu, "^Enable$").fn()
				child(child(menu, "^Snooze$"), "^For 5 minutes$").fn()
				ns.StopSnooze(true)
			end)
			if not ok then fail(scenario, tostring(err)) end
			if #Mock.protectedCalls > 0 then
				fail(scenario, "the menu touched the secure button in a fight: "
					.. table.concat(Mock.protectedCalls, ", "))
			end
			Mock.inCombat = false
			p.point, p.x, p.y = where[1], where[2], where[3]
		end
	end
	restore()
	Mock.reset()
end

-- ------------------------------------------------------------------ who's next
-- Skip and Never offer from the menu write what the prompt's own right-press
-- writes, and nothing else: no press reaches the button, nothing is cast or
-- parked as a click, and in a fight the secure button is not touched at all.
Mock.reset()
do
	local scenario = "minimap: who's next skips and never-offers without casting"
	local restore = strangers({ nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bo", "Bell" } })
	local ns = load(scenario)
	if ns then
		local button, showing = annaAndBo(ns, scenario)
		if button then
			local presses = watchPresses(button)
			local first, second = showing.name, showing.name == "Anna Aim" and "Bo Bell" or "Anna Aim"
			local ok, err = pcall(withMenu, function(rightClick)
				-- In a fight first: the button is frozen, and must stay exactly
				-- as the fight found it.
				Mock.protect(button)
				Mock.inCombat = true
				Mock.protectedCalls = {}
				local frozen = button:GetAttribute("macrotext1")
				local next = child(rightClick(), "^Who's next$")
				local person = next and child(next, "^" .. first:gsub("%-", "%%-") .. " %-%- ")
				local skip = person and child(person, "^Skip for now$")
				if not skip then
					fail(scenario, "SKIPPED -- who's next does not list " .. first)
					return
				end
				Mock.printed = {}
				skip.fn()
				if not ns.IsBlocked(first) then
					fail(scenario, "Skip for now did not skip " .. first)
				end
				if not said():find("skipping", 1, true) then
					fail(scenario, "Skip for now said nothing in chat: " .. said())
				end
				-- The prompt cannot follow the skip in a fight, and a press still
				-- casts at them, so the line has to say so.
				if not said():find("cannot move off them in a fight", 1, true) then
					fail(scenario, "Skip for now on the prompt in a fight claimed the skip without saying"
						.. " a press still casts at them: " .. said())
				end
				if #Mock.protectedCalls > 0 then
					fail(scenario, "Skip for now touched the secure button in a fight: "
						.. table.concat(Mock.protectedCalls, ", "))
				end
				if button:GetAttribute("macrotext1") ~= frozen then
					fail(scenario, "Skip for now re-armed the button in a fight")
				end

				local other = child(child(rightClick(), "^Who's next$"),
					"^" .. second:gsub("%-", "%%-") .. " %-%- ")
				local never = other and child(other, "^Never offer$")
				if not never then
					fail(scenario, "who's next does not offer Never offer for " .. second)
				else
					Mock.printed = {}
					never.fn()
					if not (ns.IsNeverOffered and ns.IsNeverOffered(second)) then
						fail(scenario, "Never offer did not put " .. second .. " on the never-offer list")
					end
					if not said():find("will not be offered anything again", 1, true) then
						fail(scenario, "Never offer said nothing about the list: " .. said())
					end
				end
				if #Mock.protectedCalls > 0 then
					fail(scenario, "Never offer touched the secure button in a fight: "
						.. table.concat(Mock.protectedCalls, ", "))
				end
				Mock.inCombat = false
				Mock.protectedCalls = {}
			end)
			Mock.inCombat = false
			if not ok then fail(scenario, tostring(err)) end
			if presses() > 0 then
				fail(scenario, "a who's next action pressed the prompt's button")
			end
			if ns.pendingClick then
				fail(scenario, "a who's next action parked a click as though something was cast")
			end
			for _, e in ipairs(ns.errors or {}) do
				fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
			end
		end
	end
	restore()
	Mock.reset()
end

-- Somebody already on the never-offer list is only on the prompt because they
-- buffed you, and for them Never offer reads Let this favour go. Letting it go
-- takes the favour off the launcher's count at once -- the bar used to go on
-- reading "1 waiting" for a favour that no longer existed.
Mock.reset()
do
	local scenario = "minimap: letting a favour go takes it off the count"
	local restore = strangers({ nameplate1 = { "Anna", "Aim" } })
	local ns = load(scenario)
	if ns then
		freshPrompt(ns, scenario)
		ns.PutOnNeverList("Anna Aim")
		owe(ns, "Anna Aim")
		ns.addon:Tick()
		ns.RefreshBrokerText()
		local broker = Mock.broker
		if not (broker and tostring(broker.text):find("1 waiting", 1, true)) then
			fail(scenario, "SKIPPED -- the launcher never counted Anna's favour: "
				.. tostring(broker and broker.text))
		else
			local ok, err = pcall(withMenu, function(rightClick)
				local anna = child(child(rightClick(), "^Who's next$"), "^Anna Aim %-%- ")
				local letGo = anna and child(anna, "^Let this favour go$")
				if not letGo then
					fail(scenario, "SKIPPED -- who's next has no Let this favour go for Anna")
					return
				end
				letGo.fn()
				if next(ns.owed) then
					fail(scenario, "Let this favour go left the favour standing")
				end
				if broker.text ~= "Manners" then
					fail(scenario, "a favour let go left the launcher reading " .. tostring(broker.text))
				end
			end)
			if not ok then fail(scenario, tostring(err)) end
		end
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end
	restore()
	Mock.reset()
end

-- ------------------------------------------------------------------ tooltip
-- What the hover says in each state: who is on the prompt and why, who comes
-- next, how many favours are waiting, held in a fight, off, snoozed -- and a
-- line for every click.
Mock.reset()
do
	local scenario = "minimap: the tooltip says what state it is in"
	local restore = strangers({ nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bo", "Bell" } })
	local ns = load(scenario)
	if ns then
		local button, showing = annaAndBo(ns, scenario)
		if button then
			local other = showing.name == "Anna Aim" and "Bo Bell" or "Anna Aim"
			local real = MenuUtil
			MenuUtil = { CreateContextMenu = function() end }

			local tip = tooltipLines() or ""
			if not tip:find("On the prompt: |cffffffff" .. showing.name .. "|r", 1, true)
				or not tip:find("buffed you", 1, true) then
				fail(scenario, "the tooltip does not say who is on the prompt, and why: " .. tip)
			end
			if not tip:find("Next: |cffffffff" .. other .. "|r", 1, true) then
				fail(scenario, "the tooltip does not say who comes next: " .. tip)
			end
			if not tip:find("2 people who buffed you are waiting", 1, true) then
				fail(scenario, "the tooltip does not count the favours waiting: " .. tip)
			end
			for _, hint in ipairs({ "Left click: options", "Shift-click: favour ledger",
				"Middle click: switch it off", "Right click: snooze, preview, who's next and more" }) do
				if not tip:find(hint, 1, true) then
					fail(scenario, "the tooltip has no click hint \"" .. hint .. "\": " .. tip)
				end
			end
			if tip:find("Held in combat", 1, true) then
				fail(scenario, "the tooltip says the prompt is held out of a fight")
			end

			Mock.inCombat = true
			tip = tooltipLines() or ""
			Mock.inCombat = false
			if not tip:find("Held in combat", 1, true) then
				fail(scenario, "the tooltip does not say the prompt is held in a fight: " .. tip)
			end
			-- And not with no prompt up, where it describes one nobody can see.
			local realShowing = ns.Prompt.Showing
			ns.Prompt.Showing = function() return nil end
			Mock.inCombat = true
			tip = tooltipLines() or ""
			Mock.inCombat = false
			ns.Prompt.Showing = realShowing
			if tip:find("Held in combat", 1, true) then
				fail(scenario, "the tooltip says a prompt is held in a fight with no prompt up: " .. tip)
			end

			ns.addon:HandleSlash("snooze 15")
			tip = tooltipLines() or ""
			if not tip:find("Snoozed until", 1, true) then
				fail(scenario, "the tooltip does not say it is snoozed: " .. tip)
			end
			if tip:find("On the prompt", 1, true) then
				fail(scenario, "a snoozed tooltip names somebody on a prompt that is down: " .. tip)
			end
			ns.StopSnooze(true)

			ns.addon:HandleSlash("off")
			tip = tooltipLines() or ""
			if not tip:find("Switched off", 1, true) or not tip:find("Middle click: switch it on", 1, true) then
				fail(scenario, "the tooltip of an addon that is off does not say so, or how to"
					.. " switch it on: " .. tip)
			end
			if tip:find("On the prompt", 1, true) or tip:find("Next:", 1, true) then
				fail(scenario, "an addon that is off names people on its tooltip: " .. tip)
			end
			ns.addon:HandleSlash("on")

			MenuUtil = nil
			tip = tooltipLines() or ""
			if not tip:find("Middle or right click: switch it off", 1, true) then
				fail(scenario, "with no menu, the tooltip does not say what a right click does: " .. tip)
			end
			if tip:find("Middle click:", 1, true) then
				fail(scenario, "with no menu, the tooltip says the same thing twice: " .. tip)
			end
			MenuUtil = real
		end
	end
	restore()
	Mock.reset()
end

-- ------------------------------------------------------------------ at a glance
-- The icon dims while off and warms while snoozed; the text counts the favours
-- waiting, and a favour filed the real way moves it without anything else
-- being asked to repaint.
Mock.reset()
do
	local scenario = "minimap: the icon and the text follow the state"
	local ns = load(scenario)
	if ns then
		freshPrompt(ns, scenario)
		local broker = Mock.broker
		if not broker then
			fail(scenario, "SKIPPED -- no launcher was registered")
		else
			local function tint() return broker.iconR, broker.iconG, broker.iconB end
			ns.RepaintOptions()
			local r, g, b = tint()
			if r ~= 1 or g ~= 1 or b ~= 1 then
				fail(scenario, ("the icon is tinted while on: %s %s %s"):format(tostring(r), tostring(g), tostring(b)))
			end
			if broker.text ~= "Manners" then
				fail(scenario, "with nobody waiting the launcher reads " .. tostring(broker.text))
			end

			ns.addon:HandleSlash("off")
			r, g, b = tint()
			if not (r and r < 0.6 and g < 0.6 and b < 0.6) then
				fail(scenario, "the icon is not dimmed while off: " .. tostring(r))
			end
			local offR = r
			ns.addon:HandleSlash("on")
			r = tint()
			if r ~= 1 then fail(scenario, "the icon stayed dimmed after switching on") end

			-- Dimmed evenly, and less than off: a hue turned the icon's blue
			-- arrow olive and read as a different icon.
			ns.addon:HandleSlash("snooze 15")
			r, g, b = tint()
			if not (r and r < 1 and r == g and g == b and r > (offR or 1)) then
				fail(scenario, ("the icon is not tinted while snoozed, or not as a dimmer icon between"
					.. " on and off: %s %s %s"):format(tostring(r), tostring(g), tostring(b)))
			end
			if not tostring(broker.text):find("snoozed until", 1, true) then
				fail(scenario, "the launcher does not say it is snoozed: " .. tostring(broker.text))
			end
			ns.StopSnooze(true)
			r, g, b = tint()
			if r ~= 1 or g ~= 1 or b ~= 1 then fail(scenario, "the snooze tint outlived the snooze") end

			owe(ns, "Anna Aim")
			owe(ns, "Bo Bell")
			ns.RefreshBrokerText()
			if not tostring(broker.text):find("2 waiting", 1, true) then
				fail(scenario, "the launcher does not count the favours waiting: " .. tostring(broker.text))
			end

			-- With "People who buffed me" off the queue offers none of them, so
			-- nobody is waiting -- and the switch on the page repaints the bar.
			local function findOption(group, key)
				for k, option in pairs(group and group.args or {}) do
					if k == key and option.type == "toggle" then return option end
					local inner = findOption(option, key)
					if inner then return inner end
				end
			end
			local owedToggle = findOption(ns.optionsTable, "owed")
			if not owedToggle then
				fail(scenario, "SKIPPED -- no People who buffed me toggle on the page")
			else
				owedToggle.set({ "owed" }, false)
				if broker.text ~= "Manners" then
					fail(scenario, "with People who buffed me off, the launcher still counts favours"
						.. " nobody will be offered: " .. tostring(broker.text))
				end
				owedToggle.set({ "owed" }, true)
				if not tostring(broker.text):find("2 waiting", 1, true) then
					fail(scenario, "switching People who buffed me back on left the launcher reading "
						.. tostring(broker.text))
				end
			end
			wipe(ns.owed)
			ns.RefreshBrokerText()

			-- The real path: a buff lands, a favour is filed, and the text
			-- follows with nobody asking.
			H.primeAuras(ns)
			H.favourFrom(ns, "nameplate1", 1459, 4101)
			if not next(ns.owed) then
				fail(scenario, "SKIPPED -- no favour was filed")
			elseif not tostring(broker.text):find("1 waiting", 1, true) then
				fail(scenario, "a favour filed left the launcher reading " .. tostring(broker.text))
			end
		end
	end
	Mock.reset()
end

-- ------------------------------------------------------------------ compartment
-- The addon compartment: registered once, with the options on a left click,
-- the menu on a right one -- on the next frame, after the compartment's own
-- menu has shut -- the switch on the middle one and the tooltip on a hover.
-- Reachable with no minimap button at all.
local function fakeCompartment()
	local frame = { registered = {} }
	function frame:RegisterAddon(data) self.registered[#self.registered + 1] = data end
	return frame
end

Mock.reset()
do
	local scenario = "minimap: the addon compartment reaches the launcher"
	AddonCompartmentFrame = fakeCompartment()
	-- No minimap button at all: the compartment is what is left.
	Mock.missingLibs = { ["LibDBIcon-1.0"] = true, ["LibDataBroker-1.1"] = true }
	local ns = load(scenario)
	if ns then
		freshPrompt(ns, scenario)
		local list = AddonCompartmentFrame.registered
		local entry = list[1]
		if #list ~= 1 or not entry then
			fail(scenario, ("never registered in the addon compartment (%d entries)"):format(#list))
		else
			if entry.text ~= "Manners" or not entry.icon then
				fail(scenario, "the compartment entry has no name or icon")
			end
			local optionsOpened = 0
			local realOpen = ns.OpenOptions
			ns.OpenOptions = function() optionsOpened = optionsOpened + 1 end
			entry.func(nil, { buttonName = "LeftButton" })
			if optionsOpened ~= 1 then fail(scenario, "a left click in the compartment did not open the options") end
			entry.func(nil, { buttonName = "MiddleButton" })
			if ns.db.profile.enabled then
				fail(scenario, "a middle click in the compartment did not throw the switch")
			end
			-- The line reads the state as the button's text does, since it is
			-- what is left with the button hidden.
			if not tostring(entry.text):find("off", 1, true) then
				fail(scenario, "the compartment line does not say Manners is off: " .. tostring(entry.text))
			end
			entry.func(nil, { buttonName = "MiddleButton" })
			if entry.text ~= "Manners" then
				fail(scenario, "the compartment line still reads " .. tostring(entry.text) .. " once back on")
			end
			ns.OpenOptions = realOpen

			-- And the page says so where the button is hidden.
			local function findOption(group, key)
				for k, option in pairs(group and group.args or {}) do
					if k == key and option.type == "toggle" then return option end
					local inner = findOption(option, key)
					if inner then return inner end
				end
			end
			local toggle = findOption(ns.optionsTable, "minimap")
			local desc = toggle and type(toggle.desc) == "function" and toggle.desc() or nil
			if not (desc and desc:find("addon compartment", 1, true)) then
				fail(scenario, "Show minimap button does not say Manners stays in the compartment: "
					.. tostring(desc))
			end

			local real = MenuUtil
			local opened, shown
			MenuUtil = {
				CreateContextMenu = function(owner, generator)
					local root = newMenu()
					generator(owner, root)
					opened = root
				end,
				ShowTooltip = function(_, fill)
					local lines = {}
					fill({ AddLine = function(_, text) lines[#lines + 1] = tostring(text) end })
					shown = table.concat(lines, "\n")
				end,
				HideTooltip = function() end,
			}
			entry.func(nil, { buttonName = "RightButton" })
			if opened then
				fail(scenario, "the menu opened inside the compartment's own click, which shuts it again")
			end
			Mock.runTimers(0)
			if not opened or not child(opened, "^Who's next$") then
				fail(scenario, "a right click in the compartment never opened the menu")
			end
			entry.funcOnEnter({})
			if not shown or not shown:find("Left click: options", 1, true) then
				fail(scenario, "hovering the compartment entry shows no tooltip: " .. tostring(shown))
			end
			entry.funcOnLeave({})

			-- And where the client's menu has no tooltip of its own, GameTooltip.
			MenuUtil = { CreateContextMenu = MenuUtil.CreateContextMenu }
			Mock.tooltip = {}
			entry.funcOnEnter({})
			if not table.concat(Mock.tooltip, "\n"):find("Manners", 1, true) then
				fail(scenario, "hovering the compartment entry without MenuUtil's tooltip shows nothing")
			end
			entry.funcOnLeave({})
			MenuUtil = real
		end
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end
	Mock.missingLibs = nil
	AddonCompartmentFrame = nil
	Mock.reset()
end

-- A client without the compartment, or with a frame that cannot take an
-- entry, loads and runs exactly as before.
for _, case in ipairs({
	{ label = "none at all", frame = function() return nil end },
	{ label = "a frame with no RegisterAddon", frame = function() return {} end },
}) do
	Mock.reset()
	local scenario = "minimap: a client without the addon compartment loads clean (" .. case.label .. ")"
	AddonCompartmentFrame = case.frame()
	local ns = load(scenario)
	if ns then drive(scenario, ns) end
	AddonCompartmentFrame = nil
	Mock.reset()
end
