-- The third bug hunt, on the launcher and the options page: Never offer from
-- the menu taking the person off the prompt, the tooltip and Who's next owning
-- up to a prompt a fight is holding, the lock and the mount named where they
-- keep the prompt away, the snooze note while unlocked, End the preview that
-- never starts one, and Let this favour go only where there is a favour.
--
-- Every scenario name starts with "hunt3-options:" so the mutations in
-- tests/mutations/hunt3-options.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

local function said()
	return table.concat(Mock.printed, "\n")
end

-- The same menu shape minimap.lua hands the generator: checkboxes, radios,
-- and entries that can be greyed out.
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

local function child(root, pattern)
	for _, item in ipairs(root and root.items or {}) do
		if item.text and tostring(item.text):find(pattern) then return item end
	end
end

local function texts(root)
	local out = {}
	for _, item in ipairs(root and root.items or {}) do out[#out + 1] = tostring(item.text) end
	return table.concat(out, " / ")
end

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
	local ok, err = pcall(body, rightClick)
	MenuUtil = real
	if not ok then error(err, 0) end
end

local function tooltipLines()
	local broker = Mock.broker
	if not (broker and broker.OnTooltipShow) then return "" end
	local lines = {}
	local tt = { AddLine = function(_, text) lines[#lines + 1] = tostring(text) end }
	local ok, err = pcall(broker.OnTooltipShow, tt)
	if not ok then return "THREW: " .. tostring(err) end
	return table.concat(lines, "\n")
end

local function whoIsNext(rightClick)
	return child(rightClick(), "^Who's next$")
end

local function guarded(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- Two people who buffed you, with Anna on the prompt and Bo behind her.
local function annaAndBo(ns, scenario)
	freshPrompt(ns, scenario)
	owe(ns, "Anna Aim")
	Mock.advance(1)
	owe(ns, "Bo Bell")
	ns.addon:Tick()
	local button = ns.Prompt:GetButton()
	local showing = ns.Prompt:Showing()
	if not button:IsShown() or not showing or showing.name ~= "Anna Aim" then
		fail(scenario, "SKIPPED -- Anna never came up on the prompt: "
			.. tostring(showing and showing.name))
		return nil
	end
	return button
end

-- ------------------------------------------------------------------ options-1
-- Never offer from the menu takes the person off the prompt at once, as the
-- shift-right-press does: the list alone reaches the queue only after the hold
-- and the fuse, and a keypress in between cast at the person just listed.
Mock.reset()
do
	local scenario = "hunt3-options: never offer from the menu takes them off the prompt"
	local restore = strangers({ nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bo", "Bell" } })
	local ns = load(scenario)
	if ns and annaAndBo(ns, scenario) then
		local ok, err = pcall(withMenu, function(rightClick)
			local anna = child(whoIsNext(rightClick), "^Anna Aim %-%- ")
			local never = anna and child(anna, "^Never offer$")
			if not never then
				fail(scenario, "SKIPPED -- who's next has no Never offer for Anna")
				return
			end
			never.fn()
			local showing = ns.Prompt:Showing()
			if showing and showing.name == "Anna Aim" then
				fail(scenario, "Never offer from the menu left Anna on the prompt")
			end
			Mock.advance(0.3)
			local ran = H.pressButton(ns)
			if ran and tostring(ran):find("Anna Aim", 1, true) then
				fail(scenario, "a press just after Never offer from the menu cast at Anna: " .. tostring(ran))
			end
		end)
		if not ok then fail(scenario, tostring(err)) end
		guarded(scenario, ns)
	end
	restore()
	Mock.reset()
end

Mock.reset()
do
	local scenario = "hunt3-options: never offer from the menu on the only one leaves nothing armed"
	local restore = strangers({ nameplate1 = { "Anna", "Aim" } })
	local ns = load(scenario)
	if ns then
		freshPrompt(ns, scenario)
		owe(ns, "Anna Aim")
		ns.addon:Tick()
		local showing = ns.Prompt:Showing()
		if not (showing and showing.name == "Anna Aim") then
			fail(scenario, "SKIPPED -- Anna never came up on the prompt")
		else
			local ok, err = pcall(withMenu, function(rightClick)
				local anna = child(whoIsNext(rightClick), "^Anna Aim %-%- ")
				local never = anna and child(anna, "^Never offer$")
				if not never then
					fail(scenario, "SKIPPED -- who's next has no Never offer for Anna")
					return
				end
				never.fn()
				Mock.advance(0.3)
				local ran = H.pressButton(ns)
				if ran and tostring(ran):find("Anna Aim", 1, true) then
					fail(scenario, "a press just after Never offer from the menu cast at Anna: " .. tostring(ran))
				end
			end)
			if not ok then fail(scenario, tostring(err)) end
		end
		guarded(scenario, ns)
	end
	restore()
	Mock.reset()
end

-- ------------------------------------------------------------------ options-2
-- A snooze started in a fight leaves the panel up and armed until the fight
-- ends. The tooltip and Who's next said "no prompt until then" and dropped the
-- Skip for the person a press still casts at.
Mock.reset()
do
	local scenario = "hunt3-options: a snooze in a fight owns up to the prompt it holds"
	local restore = strangers({ nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bo", "Bell" } })
	local ns = load(scenario)
	if ns then
		local button = annaAndBo(ns, scenario)
		if button then
			Mock.protect(button)
			Mock.inCombat = true
			ns.addon:PLAYER_REGEN_DISABLED()
			Mock.runTimers(0)
			local ok, err = pcall(withMenu, function(rightClick)
				local fifteen = child(child(rightClick(), "^Snooze$"), "^For 15 minutes$")
				if not fifteen then
					fail(scenario, "SKIPPED -- no For 15 minutes on the Snooze menu")
					return
				end
				fifteen.fn()
				if not (ns.SnoozeLeft() and button:IsShown()) then
					fail(scenario, "SKIPPED -- the snooze did not start, or the panel went in the fight")
					return
				end
				local tip = tooltipLines()
				if tip:find("no prompt until then", 1, true) then
					fail(scenario, "snoozed in a fight, the tooltip denies the prompt it holds: " .. tip)
				end
				if not tip:find("Held in combat", 1, true) or not tip:find("On the prompt", 1, true) then
					fail(scenario, "snoozed in a fight, the tooltip does not name the held prompt: " .. tip)
				end
				if tip:find("Next:", 1, true) then
					fail(scenario, "snoozed in a fight, the tooltip lists people the snooze will not offer: " .. tip)
				end
				local next = whoIsNext(rightClick)
				local first = next and next.items[1]
				if not (first and tostring(first.text):find("^Anna Aim %-%- ") and child(first, "^Skip for now$")) then
					fail(scenario, "snoozed in a fight, who's next drops the person a press still casts at: "
						.. texts(next))
				end
				if child(next, "^Bo Bell") then
					fail(scenario, "snoozed in a fight, who's next lists Bo, whom the snooze will not offer: "
						.. texts(next))
				end
			end)
			if not ok then fail(scenario, tostring(err)) end
			Mock.inCombat = false
			ns.StopSnooze(true)
			guarded(scenario, ns)
		end
	end
	restore()
	Mock.reset()
end

Mock.reset()
do
	local scenario = "hunt3-options: switched off in a fight owns up to the prompt it holds"
	local restore = strangers({ nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bo", "Bell" } })
	local ns = load(scenario)
	if ns then
		local button = annaAndBo(ns, scenario)
		if button then
			Mock.protect(button)
			Mock.inCombat = true
			ns.addon:PLAYER_REGEN_DISABLED()
			Mock.runTimers(0)
			Mock.broker.OnClick({}, "MiddleButton")
			local macro = tostring(button:GetAttribute("macrotext1") or "")
			if ns.db.profile.enabled or not button:IsShown() or not macro:find("Anna Aim", 1, true) then
				fail(scenario, "SKIPPED -- the switch did not go off over a frozen, armed panel")
			else
				local tip = tooltipLines()
				if tip:find("no prompt will appear", 1, true) then
					fail(scenario, "switched off in a fight, the tooltip denies the prompt still armed: " .. tip)
				end
				if not tip:find("Switched off", 1, true) then
					fail(scenario, "switched off in a fight, the tooltip does not say it is off: " .. tip)
				end
			end
			Mock.inCombat = false
			ns.db.profile.enabled = true
			guarded(scenario, ns)
		end
	end
	restore()
	Mock.reset()
end

-- ------------------------------------------------------------------ options-3
-- Not while mounted keeps the prompt away, and the launcher said "Watching"
-- with a count of people waiting while Who's next said nobody was.
Mock.reset()
do
	local scenario = "hunt3-options: the launcher names the mount"
	local restore = strangers({ nameplate1 = { "Anna", "Aim" } })
	local realMounted = IsMounted
	IsMounted = function() return true end
	local ns = load(scenario)
	if ns then
		freshPrompt(ns, scenario)
		ns.db.profile.filters.hideMounted = true
		owe(ns, "Anna Aim")
		ns.addon:Tick()
		ns.addon:Tick()
		local tip = tooltipLines()
		if tip:find("Watching for people to buff.", 1, true) or not tip:lower():find("mounted", 1, true) then
			fail(scenario, "mounted with Not while mounted on, the tooltip does not say why no prompt is up: " .. tip)
		end
		local ok, err = pcall(withMenu, function(rightClick)
			local next = whoIsNext(rightClick)
			if tostring(next and next.items[1] and next.items[1].text):find("Nobody is waiting", 1, true) then
				fail(scenario, "mounted, who's next says nobody is waiting under a bar that counts Anna")
			end
		end)
		if not ok then fail(scenario, tostring(err)) end
		guarded(scenario, ns)
	end
	IsMounted = realMounted
	restore()
	Mock.reset()
end

Mock.reset()
do
	local scenario = "hunt3-options: the launcher names the lock"
	local restore = strangers({ nameplate1 = { "Anna", "Aim" } })
	local ns = load(scenario)
	if ns then
		freshPrompt(ns, scenario)
		owe(ns, "Anna Aim")
		ns.addon:HandleSlash("unlock")
		ns.addon:Tick()
		local tip = tooltipLines()
		if tip:find("Watching", 1, true) or tip:find("Anna Aim", 1, true) then
			fail(scenario, "unlocked, the tooltip says it is watching and names people: " .. tip)
		end
		if not tip:find("Unlocked", 1, true) then
			fail(scenario, "unlocked, the tooltip does not say so: " .. tip)
		end
		local ok, err = pcall(withMenu, function(rightClick)
			local next = whoIsNext(rightClick)
			local anna = child(next, "^Anna Aim")
			if anna and child(anna, "^Skip for now$") then
				fail(scenario, "unlocked, who's next offers a Skip for Anna: " .. texts(next))
			end
		end)
		if not ok then fail(scenario, tostring(err)) end
		ns.addon:HandleSlash("snooze 5")
		tip = tooltipLines()
		if tip:find("no prompt until then", 1, true) then
			fail(scenario, "snoozed while unlocked, the tooltip says no prompt over the drag panel: " .. tip)
		end
		local ok2, err2 = pcall(withMenu, function(rightClick)
			local next = whoIsNext(rightClick)
			local first = tostring(next and next.items[1] and next.items[1].text)
			if not first:find("Unlocked", 1, true) then
				fail(scenario, "snoozed while unlocked, who's next does not say the prompt is unlocked: " .. first)
			end
		end)
		if not ok2 then fail(scenario, tostring(err2)) end
		ns.StopSnooze(true)
		ns.addon:HandleSlash("lock")
		guarded(scenario, ns)
	end
	restore()
	Mock.reset()
end

Mock.reset()
do
	local scenario = "hunt3-options: who's next does not deny favours it cannot offer"
	local restore = strangers({ nameplate1 = { "Anna", "Aim" } })
	local ns = load(scenario)
	if ns then
		freshPrompt(ns, scenario)
		owe(ns, "Anna Aim")
		ns.BlockPerson("Anna Aim")
		local ok, err = pcall(withMenu, function(rightClick)
			local next = whoIsNext(rightClick)
			local first = next and next.items[1]
			local text = tostring(first and first.text)
			if text ~= "Nobody can be offered right now -- 1 favour is waiting"
				or first.enabled ~= false then
				fail(scenario, "with Anna skipped, who's next does not say her favour is waiting: " .. text)
			end
			owe(ns, "Bo Bell")
			ns.BlockPerson("Bo Bell")
			first = whoIsNext(rightClick).items[1]
			text = tostring(first and first.text)
			if text ~= "Nobody can be offered right now -- 2 favours are waiting" then
				fail(scenario, "with both skipped, who's next does not count the favours waiting: " .. text)
			end
		end)
		if not ok then fail(scenario, tostring(err)) end
		guarded(scenario, ns)
	end
	restore()
	Mock.reset()
end

-- ------------------------------------------------------------------ options-4
-- The options page's snooze note said "No prompt until then" over a prompt
-- the lock keeps on screen for the whole snooze.
Mock.reset()
do
	local scenario = "hunt3-options: the snooze note knows the prompt is unlocked"
	local restore = strangers({ nameplate1 = { "Anna", "Aim" } })
	local ns = load(scenario)
	if ns then
		freshPrompt(ns, scenario)
		owe(ns, "Anna Aim")
		local note = H.findOption(ns.optionsTable, "snoozeNote")
		local five = H.findOption(ns.optionsTable, "snooze5")
		if not (note and five and type(note.name) == "function") then
			fail(scenario, "SKIPPED -- no snooze note or 5-minute button on the page")
		else
			five.func()
			local locked = note.name()
			if not locked:find("No prompt until then", 1, true) then
				fail(scenario, "locked, the snooze note lost its old wording: " .. locked)
			end
			ns.StopSnooze(true)
			ns.addon:HandleSlash("unlock")
			five.func()
			local text = note.name()
			if text:find("No prompt until then", 1, true) or not text:find("unlocked", 1, true) then
				fail(scenario, "unlocked, the snooze note says no prompt over the drag panel: " .. text)
			end
			ns.StopSnooze(true)
			ns.addon:HandleSlash("lock")
		end
		guarded(scenario, ns)
	end
	restore()
	Mock.reset()
end

-- ------------------------------------------------------------------ options-5
-- The menu is built once when it opens. A preview that timed out under it left
-- "End the preview" on screen, and clicking it started a new one.
Mock.reset()
do
	local scenario = "hunt3-options: end the preview never starts one"
	local restore = strangers({})
	local ns = load(scenario)
	if ns then
		freshPrompt(ns, scenario)
		Mock.optionsOpen = false
		ns.addon:HandleSlash("test")
		if not ns.Prompt:InTest() then
			fail(scenario, "SKIPPED -- the preview did not start")
		else
			local ok, err = pcall(withMenu, function(rightClick)
				local menu = rightClick()
				local stop = child(menu, "^End the preview$")
				if not stop then
					fail(scenario, "SKIPPED -- the menu has no End the preview: " .. texts(menu))
					return
				end
				Mock.advance(30)
				ns.addon:Tick()
				if ns.Prompt:InTest() then
					fail(scenario, "SKIPPED -- the preview did not time out")
					return
				end
				Mock.printed = {}
				stop.fn()
				if ns.Prompt:InTest() then
					fail(scenario, "End the preview, clicked after it had ended, started a new one: " .. said())
					ns.Prompt:ExitTest()
				end
				-- And the other way round: Preview the prompt clicked over a
				-- preview started since the menu opened does not end it.
				local start = child(rightClick(), "^Preview the prompt")
				ns.addon:HandleSlash("test")
				if start and ns.Prompt:InTest() then
					start.fn()
					if not ns.Prompt:InTest() then
						fail(scenario, "Preview the prompt, clicked over a running preview, ended it")
					end
				end
				ns.Prompt:ExitTest()
			end)
			if not ok then fail(scenario, tostring(err)) end
		end
		guarded(scenario, ns)
	end
	restore()
	Mock.reset()
end

-- ------------------------------------------------------------------ options-6
-- Somebody on the never-offer list who owes nothing can still be named on the
-- prompt a fight holds. "Let this favour go" there lets nothing go.
Mock.reset()
do
	local scenario = "hunt3-options: no favour to let go for somebody who owes nothing"
	local restore = strangers({ nameplate1 = { "Anna", "Aim" } })
	local ns = load(scenario)
	if ns then
		freshPrompt(ns, scenario)
		ns.addon:Tick()
		local button = ns.Prompt:GetButton()
		local showing = ns.Prompt:Showing()
		if not (showing and showing.name == "Anna Aim" and not ns.owed["Anna Aim"]) then
			fail(scenario, "SKIPPED -- Anna is not on the prompt as a passer-by: "
				.. tostring(showing and showing.name))
		else
			Mock.protect(button)
			Mock.inCombat = true
			ns.addon:PLAYER_REGEN_DISABLED()
			Mock.runTimers(0)
			local ok, err = pcall(withMenu, function(rightClick)
				local anna = child(whoIsNext(rightClick), "^Anna Aim %-%- ")
				local never = anna and child(anna, "^Never offer$")
				if not never then
					fail(scenario, "SKIPPED -- who's next has no Never offer for Anna")
					return
				end
				never.fn()
				local again = child(whoIsNext(rightClick), "^Anna Aim %-%- ")
				if not again then
					fail(scenario, "SKIPPED -- Anna is no longer on who's next in the fight")
					return
				end
				if child(again, "^Let this favour go$") then
					fail(scenario, "who's next offers to let go a favour Anna never did")
				end
				local listed = child(again, "^On your never%-offer list$")
				if not listed or listed.enabled ~= false or listed.fn then
					fail(scenario, "who's next does not say Anna is on the list, greyed out: " .. texts(again))
				end
			end)
			if not ok then fail(scenario, tostring(err)) end
			Mock.inCombat = false
		end
		guarded(scenario, ns)
	end
	restore()
	Mock.reset()
end
