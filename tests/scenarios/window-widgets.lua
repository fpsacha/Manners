-- The options window and its controls together: what the rows
-- (Options/Window/Widgets*.lua) and the window (Window*.lua, Bind.lua) promise
-- each other in Interfaces 6 and 7 of the build, driven the way a player
-- drives them -- a slider held, the colour picker opened, a name typed into
-- the never-offer list, the footer's reset answered in the window's own
-- confirm box. window.lua tests the window's half by calling its context
-- directly, widgets.lua the rows' half on a context of their own; these are
-- the two halves meeting.
--
-- Every scenario name starts with "window:".

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

local function press(button)
	local onClick = button and button:GetScript("OnClick")
	if onClick then onClick(button, "LeftButton", false) end
end

-- One mage's session with the window open on `page`, everything put back.
local function with(scenario, page, body)
	Mock.reset()
	local menu = rawget(_G, "MenuUtil")
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		drive(scenario, ns)
		ns.Prompt:ExitTest()
		ns.OpenOptions(page)
		ns.Prompt:ExitTest()
		body(ns, ns.WindowUI)
		noErrors(scenario, ns)
	end)
	rawset(_G, "MenuUtil", menu)
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- The window's alpha once its fade has had `seconds` to run.
local function settle(ns, seconds)
	local f = ns.OptionsWindow
	local update = f:GetScript("OnUpdate")
	for _ = 1, 10 do update(f, (seconds or 0.5) / 10) end
	return f:GetAlpha()
end

-- ------------------------------------------------------------------ the peek
-- Look's real slider held down, and its real colour swatch's picker open,
-- fade the window so the prompt behind shows (IA 1.7): the rows tell the
-- window through ctx.OnHold, which the window hands them with every item.
do
	local scenario = "window: Look's own slider and colour picker fade the window while held"
	with(scenario, "appearance", function(ns, UI)
		local slider = UI.RowFor("appearance.scale")
		if not (slider and slider.slider and UI.RowShown("appearance.scale")) then
			fail(scenario, "SKIPPED -- no Scale slider on Look")
			return
		end
		Mock.mouseDown(slider.slider)
		if math.abs(settle(ns, 0.3) - 0.25) > 0.001 then
			fail(scenario, "holding the Scale slider left the window at " .. ns.OptionsWindow:GetAlpha())
		end
		Mock.mouseUp(slider.slider)
		Mock.advance(2)
		if settle(ns, 0.3) ~= 1 then fail(scenario, "letting go of Scale left the window at " .. ns.OptionsWindow:GetAlpha()) end

		local colour = UI.RowFor("appearance.bgColor")
		if not (colour and colour.hit and UI.RowShown("appearance.bgColor")) then
			fail(scenario, "SKIPPED -- no Panel colour on Look")
			return
		end
		press(colour.hit)
		if not (ColorPickerFrame and ColorPickerFrame:IsShown()) then
			fail(scenario, "SKIPPED -- Panel colour did not open the colour picker")
			return
		end
		if math.abs(settle(ns, 0.3) - 0.25) > 0.001 then
			fail(scenario, "with the colour picker open for Panel colour the window is at " .. ns.OptionsWindow:GetAlpha())
		end
		-- A slider pressed and let go with the picker still up ends its own
		-- hold, not the picker's.
		Mock.mouseDown(slider.slider)
		Mock.mouseUp(slider.slider)
		if math.abs(settle(ns, 0.3) - 0.25) > 0.001 then
			fail(scenario, "Scale let go with the colour picker up left the window at " .. ns.OptionsWindow:GetAlpha())
		end
		Mock.closeColour(false)
		Mock.advance(2)
		if settle(ns, 0.3) ~= 1 then
			fail(scenario, "the colour picker shut and the window stayed at " .. ns.OptionsWindow:GetAlpha())
		end
	end)
end

-- ------------------------------------------------------------------ never offer
-- The never-offer list is one row built from five definitions: the window
-- hands the row its layout entry (item.layout.ids), the row finds the parts
-- in it. A name typed and entered joins the list and the page; its X takes
-- it off again.
do
	local scenario = "window: a name typed into the never-offer list joins it, and its X takes it off"
	with(scenario, "skip", function(ns, UI)
		local row = UI.RowFor("who.neverAdd")
		if not (row and row.add and row.add.box and UI.RowShown("who.neverAdd")) then
			fail(scenario, "SKIPPED -- no never-offer list on Who to skip")
			return
		end
		local before = UI.Where("who.neverAdd").e.h
		Mock.type(row.add.box, "Grumbleton")
		Mock.press(row.add.box, "ENTER")
		local list = ns.NeverList()
		if #list ~= 1 then
			fail(scenario, "entering a name put " .. #list .. " names on the list")
			return
		end
		if (row.count or 0) ~= 1 or not (row.lines[1] and row.lines[1]:IsShown()) then
			fail(scenario, "the name is on the list and the list on the page shows " .. tostring(row.count))
		end
		if not (UI.Where("who.neverAdd").e.h > before) then
			fail(scenario, "the list grew a line and the page did not give it room")
		end
		if (row.add.box:GetText() or "") ~= "" then
			fail(scenario, "the box still holds " .. tostring(row.add.box:GetText()) .. " after the name went in")
		end
		press(row.lines[1].x)
		if #ns.NeverList() ~= 0 then fail(scenario, "the X did not take the name off the list") end
		if (row.count or 0) ~= 0 then fail(scenario, "the name is off the list and the page still shows it") end
	end)
end

-- ------------------------------------------------------------------ the reset
-- The footer's reset asks in the window's own confirm box, over the window;
-- No changes nothing, Yes resets the page in view (IA 1.6).
do
	local scenario = "window: the footer's reset asks in the window's own box, and Yes resets the page"
	with(scenario, "skip", function(ns, UI)
		local W = ns.WindowWidgets
		local reset = UI.footer and UI.footer.reset
		local f = ns.db.profile.filters
		if not (reset and reset:IsShown()) then
			fail(scenario, "SKIPPED -- no reset in the footer on Who to skip")
			return
		end
		local default = ns.defaults.profile.filters.skipSameClass
		f.skipSameClass = not default
		press(reset)
		local m = W.Asking()
		if not (m and m:IsShown() and m.yes and m.no) then
			fail(scenario, "the reset did not ask first")
			return
		end
		if m:GetParent() ~= ns.OptionsWindow then fail(scenario, "the confirm box is not over the window") end
		press(m.no)
		if f.skipSameClass == default then fail(scenario, "No reset the page anyway") end
		press(reset)
		m = W.Asking()
		press(m and m.yes)
		if f.skipSameClass ~= default then fail(scenario, "Yes left Skip my own class as it was") end
		local row = UI.RowFor("who.skipSameClass")
		if row and row.box and (row.box.check:IsShown() == true) ~= (default == true) then
			fail(scenario, "the page still shows Skip my own class as it was before the reset")
		end
	end)
end
