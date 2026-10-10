-- The options window's smaller behaviours, each driven as a player drives it:
-- a key captured from a side mouse button or the wheel, one commit for each
-- move of the colour picker, the search results giving way to a page chosen
-- from the sidebar, the peek letting go when its reason has gone, a control
-- rule that throws once, a box of many lines keeping the new line in view,
-- When to offer's combat line and the Targeting fold, and where the strip, a
-- section title and Snooze put their parts.
--
-- Every scenario name starts with "window:".

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

-- Globals a scenario may replace, put back after each: Mock.reset owns none.
local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "MenuUtil" }

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- One session as a mage, with body(ns, UI) run and every global put back
-- however it ends.
local function with(scenario, opts, body)
	Mock.reset()
	Mock.class = "MAGE"
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		drive(scenario, ns)
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.Prompt:ExitTest()
		Mock.printed = {}
		body(ns, ns.WindowUI)
		ns.Prompt:ExitTest()
		if not opts.allowErrors then noErrors(scenario, ns) end
	end)
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function press(button, which)
	local onClick = button and button:GetScript("OnClick")
	if onClick then onClick(button, which or "LeftButton", false) end
end

local function shown(frame) return frame ~= nil and frame:IsShown() == true end

-- A click as the client delivers it: only for a mouse button the button
-- registered for. Answers whether it got through.
local function clientClick(button, which)
	for _, c in ipairs(button._clicks or {}) do
		if c == "AnyUp" or c == which .. "Up" then
			button:Click(which)
			return true
		end
	end
	return false
end

-- The wheel reaches a frame only while it takes the wheel.
local function wheel(frame, delta)
	if frame._wheel ~= true then return false end
	Mock.fire(frame, "OnMouseWheel", delta)
	return true
end

-- The last anchor a region was given: point, relative frame, relative
-- point, x, y.
local function anchor(region)
	local p = region.points and region.points[#region.points]
	if not p then return nil end
	return p[1], p[2], p[3], p[4] or 0, p[5] or 0
end

-- ------------------------------------------------------------------ key capture
do
	local scenario = "window: a key can be captured from a side mouse button or the wheel"
	with(scenario, {}, function(ns, UI)
		local W, Setup = ns.WindowWidgets, ns.Setup
		ns.OpenOptions("general")
		local row = UI.RowFor("general.bindKey")
		if not (row and UI.RowShown("general.bindKey")) then
			fail(scenario, "SKIPPED -- Start here shows no key control")
			return
		end
		local b = row.button
		-- Not waiting: a middle click neither starts listening nor binds.
		clientClick(b, "MiddleButton")
		if W.Capturing() or Setup.Key() ~= nil then fail(scenario, "a middle click on an idle button did something") end
		if b._wheel then fail(scenario, "the idle button takes the wheel from the page") end

		clientClick(b, "LeftButton")
		if W.Capturing() ~= row then fail(scenario, "a click did not start listening") end
		Mock.modifiers.shift = true
		if not clientClick(b, "Button4") then fail(scenario, "the button does not hear mouse button 4") end
		Mock.modifiers.shift = false
		if Setup.Key() ~= "SHIFT-BUTTON4" then fail(scenario, "Shift and mouse button 4 bound " .. tostring(Setup.Key())) end
		if W.Capturing() or b._wheel or b._keyboard then fail(scenario, "the button kept the wheel or the keyboard") end

		clientClick(b, "LeftButton")
		if not wheel(b, -1) then fail(scenario, "the button waiting for a key does not take the wheel") end
		if Setup.Key() ~= "MOUSEWHEELDOWN" then fail(scenario, "the wheel down bound " .. tostring(Setup.Key())) end
		clientClick(b, "LeftButton")
		wheel(b, 1)
		if Setup.Key() ~= "MOUSEWHEELUP" then fail(scenario, "the wheel up bound " .. tostring(Setup.Key())) end
		clientClick(b, "LeftButton")
		clientClick(b, "MiddleButton")
		if Setup.Key() ~= "BUTTON3" then fail(scenario, "the middle button bound " .. tostring(Setup.Key())) end
		clientClick(b, "LeftButton")
		clientClick(b, "Button5")
		if Setup.Key() ~= "BUTTON5" then fail(scenario, "mouse button 5 bound " .. tostring(Setup.Key())) end

		-- Escape still cancels and gives the wheel back; a right-click still clears.
		clientClick(b, "LeftButton")
		Mock.keyDown(b, "ESCAPE")
		if W.Capturing() or b._wheel or Setup.Key() ~= "BUTTON5" then fail(scenario, "Escape did not cancel cleanly") end
		clientClick(b, "RightButton")
		if Setup.Key() ~= nil then fail(scenario, "a right-click did not clear the key") end
	end)
end

-- ------------------------------------------------------------------ colour
do
	local scenario = "window: each move of the colour picker is committed once"
	with(scenario, {}, function(ns, UI)
		ns.OpenOptions("appearance")
		local row = UI.RowFor("appearance.bgColor")
		if not (row and row.hit) then
			fail(scenario, "SKIPPED -- Look shows no Panel colour")
			return
		end
		local commits, real = 0, UI.Changed
		UI.Changed = function(...)
			commits = commits + 1
			return real(...)
		end
		press(row.hit)
		-- The client calls swatchFunc and then opacityFunc for every move.
		Mock.pickColour(0.2, 0.3, 0.4, 0.5)
		local after = commits
		Mock.pickColour(0.2, 0.3, 0.4, 0.6)
		Mock.closeColour(true)
		UI.Changed = real
		local c = ns.db.profile.prompt.bgColor
		if math.abs(c[1] - 0.2) > 1e-6 or math.abs(c[4] - 0.6) > 1e-6 then
			fail(scenario, ("the colour came out %s %s %s %s"):format(tostring(c[1]), tostring(c[2]), tostring(c[3]), tostring(c[4])))
		end
		if after ~= 1 or commits ~= 2 then
			fail(scenario, ("two moves of the picker made %d and then %d commits"):format(after, commits))
		end
	end)
end

-- ------------------------------------------------------------------ search
do
	local scenario = "window: the search results give way to a page chosen from the sidebar"
	with(scenario, {}, function(ns, UI)
		ns.OpenOptions("general")
		local box, results = UI.search.box, UI.search.results
		Mock.type(box, "sound")
		Mock.runTimers(0.3)
		if not shown(results) then
			fail(scenario, "SKIPPED -- typing sound found nothing")
			return
		end
		press(UI.side.buttons.who)
		if UI.page ~= "who" then fail(scenario, "the sidebar did not open Who to buff") end
		if shown(results) then fail(scenario, "the results stayed over the page chosen from the sidebar") end
		if box:HasFocus() then fail(scenario, "the search box kept the keyboard") end
		if box:GetText() ~= "sound" then fail(scenario, "choosing a page threw away the words typed") end

		-- Typing not yet settled when the page is chosen: the search waiting on
		-- it does not open the results over the new page afterwards.
		Mock.type(box, "whisper")
		press(UI.side.buttons.when)
		Mock.runTimers(0.3)
		if shown(results) then fail(scenario, "a search still waiting opened over the page chosen") end
	end)
end

-- ------------------------------------------------------------------ peek
do
	local scenario = "window: the peek lets go when the page changes or the preview stops"
	with(scenario, {}, function(ns, UI)
		ns.OpenOptions("appearance")
		local row = UI.RowFor("appearance.bgColor")
		if not (row and row.hit) then
			fail(scenario, "SKIPPED -- Look shows no Panel colour")
			return
		end
		-- The picker open for a Look colour, then another page chosen with it up.
		press(row.hit)
		if UI.PeekTarget() ~= 0.25 then fail(scenario, "the colour picker on Look did not fade the window") end
		press(UI.side.buttons.who)
		if UI.PeekTarget() ~= 1 then fail(scenario, "with the picker left up behind Who to buff, the window stays faded") end
		press(UI.side.buttons.appearance)
		if UI.PeekTarget() ~= 0.25 then fail(scenario, "back on Look with the picker still up, the window did not fade") end
		Mock.closeColour(true)
		if UI.PeekTarget() ~= 1 then fail(scenario, "shutting the picker left the window faded") end

		-- Resting on Show me the prompt while a preview runs, and the preview
		-- ended by something else (/manners test, a fight): no peek without one.
		local preview = UI.header.preview
		if not ns.Prompt:InTest() then ns.Prompt:ToggleTest() end
		preview._mouseOver = true
		preview:GetScript("OnEnter")(preview)
		Mock.runTimers(0.5)
		if UI.PeekTarget() ~= 0.25 then fail(scenario, "resting on the button with a preview running did not fade") end
		ns.Prompt:ExitTest()
		if UI.PeekTarget() ~= 1 then fail(scenario, "the preview stopped and the window stays faded under the pointer") end

		-- Resting first, then clicking to start the preview: the peek follows
		-- once the pointer has rested on the running preview.
		preview:GetScript("OnLeave")(preview)
		preview:GetScript("OnEnter")(preview)
		Mock.runTimers(0.5)
		press(preview)
		if not ns.Prompt:InTest() then fail(scenario, "the button did not start the preview") end
		Mock.runTimers(0.5)
		if UI.PeekTarget() ~= 0.25 then fail(scenario, "resting on the button through the click gave no peek") end
		press(preview)
		if UI.PeekTarget() ~= 1 then fail(scenario, "stopping the preview from the button left the window faded") end
		preview._mouseOver = false
	end)
end

-- ------------------------------------------------------------------ a rule that throws
do
	local scenario = "window: a control rule that throws is named and left out, and the window stays"
	with(scenario, { allowErrors = true }, function(ns, UI)
		local dialog = LibStub("AceConfigDialog-3.0")
		local realOpen, opened = dialog.Open, 0
		dialog.Open = function(_, app) if app == "Manners" then opened = opened + 1 end end
		local def = ns.optionsTable.args.diagnostics.args.debugClicks
		local was, calls = def.hidden, 0
		def.hidden = function(...)
			calls = calls + 1
			if calls == 1 then error("only the first time", 0) end
			if type(was) == "function" then return was(...) end
			return was
		end
		local ok, err = pcall(function()
			ns.OpenOptions("general")
			if not shown(ns.OptionsWindow) then fail(scenario, "one throw sent the player to the old dialog") end
			ns.CloseOptions()
			ns.OpenOptions("diagnostics")
		end)
		dialog.Open, def.hidden = realOpen, was
		if not ok then fail(scenario, "opening the options threw: " .. tostring(err)) end
		if calls == 0 then fail(scenario, "SKIPPED -- nothing asked whether debugClicks is hidden") end
		if opened ~= 0 or not shown(ns.OptionsWindow) then fail(scenario, "the old dialog opened") end
		if UI.page ~= "diagnostics" or not UI.RowShown("diagnostics.debugClicks") then
			fail(scenario, "once the rule answered again, its control did not come back")
		end
		local named = 0
		for _, e in ipairs(ns.errors) do
			if e.where == "options row diagnostics.debugClicks" then named = named + 1 end
		end
		if named ~= 1 then fail(scenario, ("the throw was named %d times"):format(named)) end
	end)
end

-- ------------------------------------------------------------------ a box of many lines
do
	local scenario = "window: a new line typed at the bottom of a full box is scrolled into view"
	with(scenario, {}, function(ns, UI)
		-- The box is there while a line is said on a click.
		ns.db.profile.speech.enabled = true
		ns.OpenOptions("click")
		local row = UI.RowFor("click.phrases")
		if not (row and row.scroll and UI.RowShown("click.phrases")) then
			fail(scenario, "SKIPPED -- What I say shows no lines box")
			return
		end
		local box, scroll = row.box, row.scroll
		local lines = {}
		for i = 1, 40 do lines[i] = "line " .. i end
		Mock.type(box, table.concat(lines, "\n"))
		Mock.runTimers(0)
		-- Enter on the last line: the client tells the cursor's move before the
		-- box has grown to hold the new line, so the scroll range is still the
		-- old one (Blizzard's own ScrollingEdit puts its follow off to the next
		-- frame for this).
		local _, size = box:GetFont()
		local top = 6 + 40 * size
		Mock.fire(box, "OnCursorChanged", 0, -top, 2, size)
		lines[41] = ""
		Mock.type(box, table.concat(lines, "\n"))
		Mock.runTimers(0)
		local seen = scroll:GetVerticalScroll() + scroll:GetHeight()
		if seen < top + size then
			fail(scenario, ("the new line ends at %d and the box shows down to %d"):format(top + size, seen))
		end
		Mock.press(box, "ESCAPE")
	end)
end

-- ------------------------------------------------------------------ combat line
do
	local scenario = "window: When to offer's combat line waits for the Targeting fold to be open"
	with(scenario, {}, function(ns, UI)
		ns.OpenOptions("when")
		local w = UI.Where("advanced.restoreTarget")
		if not (w and w.sec.fold and w.sec.button) then
			fail(scenario, "SKIPPED -- Hand my target back is not in a fold")
			return
		end
		UI.State().open[w.sec.key] = nil
		Mock.inCombat = true
		ns.RefreshOptionsDisplay()
		if UI.strip.combat then fail(scenario, "the strip speaks of targeting with the Targeting fold shut") end
		press(w.sec.button)
		if not UI.strip.combat then fail(scenario, "the Targeting fold open in a fight, and no combat line") end
		press(w.sec.button)
		if UI.strip.combat then fail(scenario, "the fold shut again and the combat line stayed") end
		Mock.inCombat = false
		ns.RefreshOptionsDisplay()
	end)
end

-- ------------------------------------------------------------------ where the parts sit
do
	local scenario = "window: the strip, a section title and Snooze sit as the mock-up has them"
	with(scenario, {}, function(ns, UI)
		ns.db.profile.prompt.locked = false
		ns.OpenOptions("who")
		ns.Prompt:ExitTest()
		ns.RefreshOptionsDisplay()

		-- The unlocked line level with Lock it beside it.
		local strip = UI.strip
		if shown(strip.line1) and shown(strip.lock) then
			local _, _, _, _, y1 = anchor(strip.line1)
			local _, _, _, _, y2 = anchor(strip.lock)
			local middle1 = -y1 + UI.TextHeight(strip.line1) / 2
			local middle2 = -y2 + strip.lock:GetHeight() / 2
			if math.abs(middle1 - middle2) > 1 then
				fail(scenario, ("the strip's line sits at %.1f and Lock it at %.1f"):format(middle1, middle2))
			end
		else
			fail(scenario, "SKIPPED -- unlocked, the strip shows no line and Lock it")
		end

		-- A section title's rule runs on from the title, on its line.
		local w = UI.Where("who.owed")
		local sec = w and w.sec
		if sec and sec.title and sec.rule and shown(sec.rule) then
			local point, _, _, x, y = anchor(sec.rule)
			local _, _, _, tx, ty = anchor(sec.title)
			local middle = -ty + UI.TextHeight(sec.title) / 2
			if x < tx + UI.TextWidth(sec.title) or math.abs(-y - middle) > 1 then
				fail(scenario, ("the rule starts at %s %d,%d, not after the title on its line"):format(tostring(point), x, -y))
			end
		else
			fail(scenario, "SKIPPED -- Offer my buff to has no title")
		end

		-- Snooze says it opens a menu.
		local snooze = UI.header.snooze
		if shown(snooze) then
			if not (snooze.chevron and shown(snooze.chevron)) then fail(scenario, "Snooze has no chevron") end
			if snooze:GetWidth() < UI.Measure(UI.header.snoozeLabel) + 40 then
				fail(scenario, "Snooze has no room for its chevron: " .. snooze:GetWidth())
			end
		end

	end)
end

-- ------------------------------------------------------------------ the wheel over a box
-- The client gives the wheel to the first frame that takes it and does not pass
-- it up, so a box with nothing left to scroll hands it to the page itself.
do
	local scenario = "window: the wheel over a box with nothing to scroll moves the page"
	with(scenario, {}, function(ns, UI)
		ns.db.profile.speech.enabled = true
		ns.OpenOptions("click")
		local row = UI.RowFor("click.phrases")
		if not (row and row.scroll and UI.RowShown("click.phrases")) then
			fail(scenario, "SKIPPED -- What I say shows no lines box")
			return
		end
		if not (UI.view.range > 0) then
			fail(scenario, "SKIPPED -- What I say fits the window")
			return
		end
		Mock.type(row.box, "One line")
		row.scroll:SetVerticalScroll(0)
		UI.ScrollTo(0)
		if not wheel(row.scroll, -1) or UI.view.scrollY <= 0 then
			fail(scenario, "the wheel over a box that fits left the page at " .. tostring(UI.view.scrollY))
		end
		local at = UI.view.scrollY
		if not wheel(row.bar, 1) or UI.view.scrollY >= at then
			fail(scenario, "the wheel over the box's bar left the page at " .. tostring(UI.view.scrollY))
		end
	end)
end
