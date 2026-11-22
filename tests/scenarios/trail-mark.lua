-- Mark this moment and a fuller trail (Options/BugReport.lua, Core.lua's trail).
-- A key, the minimap menu and /manners mark write what Manners sees at that
-- instant onto the trail: the prompt (or why there is none), the first of the
-- queue, the fight buttons. It reads Lua state only, so it works in a fight and
-- writes nothing on a secure frame. A fight's end writes one summary line; a
-- change of the reason the prompt is held back is written once; the trail keeps
-- 300 lines.
--
-- Every name starts with "trail-mark:" so the mutations in
-- tests/mutations/trail-mark.py can name exactly one.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

local PROMPT_KEY = "CLICK MannersPrompt:LeftButton"
local MARK = "CLICK MannersMark:LeftButton"
local PEOPLE = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bob", "Bright" } }

-- One camelot priest with two people owed a buff, the prompt's key on F.
local function with(scenario, body, opts)
	opts = opts or {}
	Mock.reset()
	Mock.setFlavour("camelot")
	Mock.class = "PRIEST"
	-- A spellbook that holds every spell there is.
	Mock.knownSpells = setmetatable({}, { __index = function() return true end })
	local restore = strangers(PEOPLE)
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		Mock.timers = {}
		Mock.secureActions = true
		Mock.eventSink = ns.addon
		ns.KeyNudge = nil
		local p = ns.db.profile.prompt
		if opts.edit then opts.edit(p, ns) end
		ns.Prompt:ApplyStyle()
		Mock.bindings = Mock.bindings or {}
		Mock.bindings.F = PROMPT_KEY
		if opts.owed ~= false then
			owe(ns, "Anna Aim")
			owe(ns, "Bob Bright")
		end
		ns.addon:Tick()
		if opts.bar then
			ns.CreateClickMacro()
			Mock.dropOnBar(2)
			ns.addon:Tick()
		end
		Mock.runTimers(0)
		Mock.printed = {}
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	Mock.inCombat = false
	Mock.modifiers = {}
	restore()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function pull(ns)
	Mock.inCombat = false
	ns.addon:PLAYER_REGEN_DISABLED()
	Mock.inCombat = true
	Mock.frameEvent("PLAYER_REGEN_DISABLED")
	Mock.runTimers(0)
end

local function release(ns)
	Mock.inCombat = false
	ns.addon:PLAYER_REGEN_ENABLED()
	Mock.frameEvent("PLAYER_REGEN_ENABLED")
	Mock.runTimers(0)
end

-- The trail's lines of one kind, oldest first.
local function lines(ns, kind)
	local out = {}
	for _, t in ipairs(ns.db.char.trail or {}) do
		if t.kind == kind then out[#out + 1] = t end
	end
	return out
end

local function joined(list)
	local parts = {}
	for _, t in ipairs(list) do parts[#parts + 1] = t.text end
	return table.concat(parts, "\n")
end

do
	local scenario = "trail-mark: a mark holds the prompt, the queue and the buttons"
	with(scenario, function(ns)
		if not ns.Prompt:Showing() then fail(scenario, "SKIPPED -- the prompt is not up") return end
		ns.MarkMoment()
		local marks = lines(ns, "MARK")
		local text = joined(marks)
		if not (marks[1] and marks[1].text:find("^marked: in a fight no; ")) then
			fail(scenario, "the first line is not the header: " .. tostring(marks[1] and marks[1].text))
		end
		if not text:find("prompt: buff ", 1, true) then fail(scenario, "no prompt line: " .. text) end
		if not text:find("queue 1: ", 1, true) then fail(scenario, "no queue line: " .. text) end
		if not text:find("queue 2: ", 1, true) then fail(scenario, "no second queue line: " .. text) end
		if not text:find("buttons: ", 1, true) then fail(scenario, "no buttons line: " .. text) end
		local who = false
		for _, t in ipairs(marks) do if t.who == "Anna Aim" or t.who == "Bob Bright" then who = true end end
		if not who then fail(scenario, "no mark line names who it was about") end
		if not table.concat(Mock.printed, "\n"):find("Marked this moment", 1, true) then
			fail(scenario, "the mark said nothing to the player")
		end
		-- No more than three queue lines.
		local _, n = text:gsub("queue %d: ", "")
		if n > 3 then fail(scenario, "more than three queue lines") end
	end, { bar = true })

	-- Nothing on the prompt: what holds it back, or that nothing does.
	with(scenario, function(ns)
		ns.db.profile.enabled = false
		ns.addon:Tick()
		ns.MarkMoment()
		local text = joined(lines(ns, "MARK"))
		if not (text:find("held back: ", 1, true) or text:find("prompt: empty, nothing holding it back", 1, true)) then
			fail(scenario, "an empty prompt says neither why nor that nothing holds it: " .. text)
		end
	end, { owed = false })
end

do
	local scenario = "trail-mark: a mark in a fight writes nothing on a secure frame"
	with(scenario, function(ns)
		local writes = 0
		local function spy(frame)
			if not frame or not frame.SetAttribute then return end
			local real = frame.SetAttribute
			frame.SetAttribute = function(self, ...) writes = writes + 1 return real(self, ...) end
		end
		spy(ns.Prompt:GetButton())
		spy(ns.Prompt:FightHeader())
		for _, frame in pairs(Mock.namedFrames or {}) do spy(frame) end
		pull(ns)
		writes = 0
		local before = #lines(ns, "MARK")
		ns.MarkMoment()
		if writes ~= 0 then fail(scenario, "a mark in a fight set " .. writes .. " attributes") end
		local marks = lines(ns, "MARK")
		if #marks <= before then fail(scenario, "a mark in a fight wrote nothing") end
		if not marks[before + 1].text:find("in a fight yes", 1, true) then
			fail(scenario, "the mark does not say it was in a fight: " .. marks[before + 1].text)
		end
		release(ns)
	end, { bar = true })
end

do
	local scenario = "trail-mark: the people in a mark are aliased in the report"
	with(scenario, function(ns)
		if not ns.Prompt:Showing() then fail(scenario, "SKIPPED -- the prompt is not up") return end
		ns.MarkMoment()
		local text = ns.FullReport()
		local found = false
		for line in (text .. "\n"):gmatch("([^\n]*)\n") do
			if line:find(" MARK ", 1, true) then
				found = true
				if line:find("Anna", 1, true) or line:find("Bob", 1, true) then
					fail(scenario, "a mark line names somebody: " .. line)
				end
			end
		end
		if not found then fail(scenario, "no mark line is in the report") end
		if not text:find("MARK [Person ", 1, true) then fail(scenario, "no mark line is under a person's alias") end
		-- The prompt's line and the queue's each name who they were about, by alias.
		if not text:find("MARK %[Person %d+%] prompt: ") then fail(scenario, "the prompt's mark line is under nobody") end
		if not text:find("MARK %[Person %d+%] queue 1: ") then fail(scenario, "the queue's mark line is under nobody") end
		if not text:find("Marks in the trail: ", 1, true) and not text:find("== What happened lately ==", 1, true) then
			fail(scenario, "the trail is not in the report")
		end
		local composed = ns.BugReport.Compose("other", "")
		if not composed:find("Marks in the trail: 1", 1, true) then fail(scenario, "the report does not count the mark") end
	end, { bar = true })
end

do
	local scenario = "trail-mark: the key, the menu and /manners mark all mark"
	local function count(ns) return #lines(ns, "MARK") end
	local function fakeDescription(text, fn)
		local d = { text = text, fn = fn, items = {} }
		function d:CreateTitle() end
		function d:CreateDivider() end
		function d:CreateButton(t, f)
			local child = fakeDescription(t, f)
			self.items[#self.items + 1] = child
			return child
		end
		return d
	end
	local function find(root, pattern)
		for _, item in ipairs(root.items) do
			if item.text and item.text:find(pattern) then return item end
			local inner = find(item, pattern)
			if inner then return inner end
		end
	end
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
	with(scenario, function(ns)
		-- Bindings.xml declares the command, and the game lists it by name.
		local f = io.open(dir .. "/Bindings.xml", "r")
		local xml = f and f:read("*a") or ""
		if f then f:close() end
		if not xml:find('name="' .. MARK .. '"', 1, true) then fail(scenario, "Bindings.xml has no " .. MARK) end
		if _G["BINDING_NAME_" .. MARK] ~= "Mark this moment" then
			fail(scenario, "the binding's name is " .. tostring(_G["BINDING_NAME_" .. MARK]))
		end
		if ns.BugReport.MARK_COMMAND ~= MARK then fail(scenario, "MARK_COMMAND is " .. tostring(ns.BugReport.MARK_COMMAND)) end
		-- The key: a press of the button the binding clicks.
		local before = count(ns)
		local button = Mock.namedFrames and Mock.namedFrames.MannersMark
		if not button then
			fail(scenario, "no MannersMark button was made")
		else
			button:Click()
			if count(ns) <= before then fail(scenario, "the key's button marked nothing") end
		end
		-- The key can be set on Diagnostics, as a game key binding.
		local item = H.findOption(ns.optionsTable, "markKey")
		if not item then
			fail(scenario, "Diagnostics has no key for Mark this moment")
		else
			item.set(nil, "F9")
			if ns.Setup.Key(MARK) ~= "F9" then fail(scenario, "the key control did not bind the command") end
			if item.get() ~= "F9" then fail(scenario, "the key control does not read the binding back") end
		end
		-- The minimap menu.
		before = count(ns)
		local broker = Mock.broker
		if broker and broker.OnClick then
			opened = nil
			broker.OnClick({}, "RightButton")
			local entry = opened and find(opened, "^Mark this moment$")
			if not entry then
				fail(scenario, "the menu has no Mark this moment")
			else
				entry.fn()
				if count(ns) <= before then fail(scenario, "the menu's entry marked nothing") end
			end
		end
		-- The slash command.
		before = count(ns)
		ns.addon:HandleSlash("mark")
		if count(ns) <= before then fail(scenario, "/manners mark marked nothing") end
	end)
	MenuUtil = realMenu
end

do
	local scenario = "trail-mark: a fight's end writes one summary line"
	with(scenario, function(ns)
		local before = #lines(ns, "fight")
		pull(ns)
		local cure = ns.CureFight.LastFight()
		cure.shows, cure.reads, cure.secret = 2, 5, 3
		Mock.advance(7)
		release(ns)
		local fights = lines(ns, "fight")
		local summaries = {}
		for _, t in ipairs(fights) do if t.text:find("^fight summary:") then summaries[#summaries + 1] = t.text end end
		if #summaries ~= 1 then
			fail(scenario, #summaries .. " summary lines after one fight")
			return
		end
		local line = summaries[1]
		if not line:find("fight summary: 7s;", 1, true) then fail(scenario, "no length of 7 seconds: " .. line) end
		if not line:find("prompt hidden;", 1, true) then fail(scenario, "the hidden prompt is not in it: " .. line) end
		if not line:find("rota ", 1, true) then fail(scenario, "no rota in it: " .. line) end
		if not line:find("cure shown 2 times, 5 reads, 3 withheld", 1, true) then fail(scenario, "the cure's counts are not in it: " .. line) end
		if not line:find("break free lit 0 times", 1, true) then fail(scenario, "break free is not in it: " .. line) end
		if #fights <= before then fail(scenario, "the fight's lines are missing") end
		-- A release with no pull (a login in a fight) writes nothing more.
		release(ns)
		local again = 0
		for _, t in ipairs(lines(ns, "fight")) do if t.text:find("^fight summary:") then again = again + 1 end end
		if again ~= 1 then fail(scenario, "a second release wrote another summary") end
	end, { bar = true, edit = function(p) p.hideInFight = true end })

	-- The fight key's presses, and the prompt left up.
	with(scenario, function(ns)
		pull(ns)
		for _ = 1, 3 do
			Mock.advance(2)
			Mock.pressKey("F")
		end
		release(ns)
		local text = joined(lines(ns, "fight"))
		if not text:find("prompt up;", 1, true) then fail(scenario, "the prompt left up is not said: " .. text) end
		if not text:find("fight key 3 presses;", 1, true) then fail(scenario, "the fight key's presses are not counted: " .. text) end
	end, { bar = true, edit = function(p, ns)
		p.hideInFight = false
		p.fightKeySpells = { PRIEST = "shield" }
	end })
end

do
	local scenario = "trail-mark: a change of hold-back reason is written once"
	with(scenario, function(ns)
		local function holds() return lines(ns, "hold") end
		ns.NoteHold()
		ns.NoteHold()
		ns.NoteHold()
		if #holds() ~= 1 then fail(scenario, #holds() .. " lines after three calls with no change") end
		ns.addon:HandleSlash("snooze 5")
		ns.NoteHold()
		ns.NoteHold()
		if #holds() ~= 2 then fail(scenario, #holds() .. " lines after a snooze") end
		if not (holds()[2] and holds()[2].text:find("snoozed", 1, true)) then
			fail(scenario, "the snooze is not the second line: " .. tostring(holds()[2] and holds()[2].text))
		end
		-- Wake it again: a third.
		ns.addon:HandleSlash("snooze off")
		ns.NoteHold()
		if #holds() ~= 3 then fail(scenario, #holds() .. " lines after the snooze ended") end
		if holds()[1].text:find("|c", 1, true) then fail(scenario, "colour codes on the trail") end
	end)
end

do
	local scenario = "trail-mark: the trail keeps 300"
	with(scenario, function(ns)
		for i = 1, 350 do ns.Trail("test", "line " .. i) end
		local trail = ns.db.char.trail
		if #trail ~= 300 then fail(scenario, "the trail holds " .. #trail) end
		if trail[#trail].text ~= "line 350" then fail(scenario, "the newest line is not last") end
		if trail[1].text ~= "line 51" then fail(scenario, "the oldest kept is " .. trail[1].text) end
	end, { owed = false })
end
