-- The options window's scroll bars: the page's on the right and a box's own
-- (Options/Window/Widgets.lua, W.DragBar and W.PlaceThumb; Window.lua,
-- UI.ScrollTo and UI.SetContentHeight; WidgetsEntry.lua, ScrollBar). A bar is
-- a plain frame whose thumb Manners places and drags from the cursor, so a drag
-- down scrolls down on every page and never rests on how the client maps a
-- drag on a Slider. The mock has no cursor geometry: a scenario states where
-- the bar is (its top and height), puts the cursor where it wants it
-- (GetCursorPosition) and holds the button (Mock.buttonsDown).
--
-- Every scenario name starts with "scrollbar:" so the mutations in
-- tests/mutations/scrollbar.py can name the one that has to catch them.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local PAGES = { "skip", "click", "appearance", "diagnostics", "who" }

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- A loaded, driven addon with the cursor stubbed: `cur.y` is where it is, in
-- the units GetCursorPosition answers, and the left button is held.
local function with(scenario, body)
	Mock.reset()
	FT.install()
	local was = rawget(_G, "GetCursorPosition")
	local cur = { y = 0 }
	rawset(_G, "GetCursorPosition", function() return 100, cur.y end)
	Mock.buttonsDown.LeftButton = true
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		drive(scenario, ns)
		ns.Prompt:ExitTest()
		body(ns, cur)
		noErrors(scenario, ns)
	end)
	rawset(_G, "GetCursorPosition", was)
	FT.uninstall()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- The bar as the client would lay it out: `top` and `high`, then the thumb
-- placed again. Answers how far the thumb travels.
local function laid(bar, thumb, top, high, place)
	bar._top, bar._height = top, high
	place()
	return high - thumb:GetHeight()
end

-- How far below the bar's top the thumb sits.
local function offsetOf(thumb)
	local p = thumb.points and thumb.points[1]
	return p and -(p[5] or 0) or 0
end

-- The page in view, its bar laid out; nil when it has nothing to scroll.
local function pageView(ns, id)
	local UI = ns.WindowUI
	ns.OpenOptions()
	UI.ShowPage(id)
	local view = UI.view
	if not (view.range > 0) then return nil end
	local travel = laid(view.bar, view.thumb, 600, view.height - 8, function() UI.ScrollTo(view.scrollY) end)
	return UI, view, travel
end

-- A page long enough to scroll, for the scenarios that need only one.
local function anyPage(ns)
	for _, id in ipairs(PAGES) do
		local UI, view, travel = pageView(ns, id)
		if UI then return UI, view, travel, id end
	end
end

do
	local scenario = "scrollbar: dragging the page bar down scrolls the page down"
	local tested = 0
	for _, id in ipairs(PAGES) do
		with(scenario, function(ns, cur)
			local UI, view, travel = pageView(ns, id)
			if not UI then return end
			if travel <= 40 then fail(scenario, id .. ": the thumb has no room to travel") return end
			tested = tested + 1
			local bar = view.bar
			cur.y = 600 - view.thumb:GetHeight() / 2
			Mock.mouseDown(bar)
			cur.y = cur.y - 40
			if not bar.scripts.OnUpdate then fail(scenario, id .. ": nothing follows the cursor while the button is held") return end
			bar.scripts.OnUpdate(bar, 0.016)
			local want = math.min(view.range, 40 * view.range / travel)
			if not (view.scrollY > 0) or math.abs(view.scrollY - want) > 1 then
				fail(scenario, ("%s: the cursor 40 down took the page to %s, not about %s"):format(id, tostring(view.scrollY), tostring(want)))
			end
			cur.y = cur.y + 40
			bar.scripts.OnUpdate(bar, 0.016)
			if view.scrollY > 0.5 then
				fail(scenario, ("%s: the cursor back up left the page at %s"):format(id, tostring(view.scrollY)))
			end
			Mock.mouseUp(bar)
		end)
	end
	if tested == 0 then fail(scenario, "SKIPPED -- no page was long enough to scroll") end
end

do
	local scenario = "scrollbar: the thumb follows the page"
	with(scenario, function(ns)
		local UI, view, travel = anyPage(ns)
		if not UI then fail(scenario, "SKIPPED -- no page was long enough to scroll") return end
		UI.ScrollTo(view.range)
		if offsetOf(view.thumb) ~= travel then
			fail(scenario, ("at the end of the page the thumb is %s down, not %s"):format(tostring(offsetOf(view.thumb)), tostring(travel)))
		end
		UI.ScrollTo(0)
		if offsetOf(view.thumb) ~= 0 then
			fail(scenario, "at the top of the page the thumb is " .. tostring(offsetOf(view.thumb)) .. " down")
		end
	end)
end

do
	local scenario = "scrollbar: a click on the track below the thumb scrolls down"
	with(scenario, function(ns, cur)
		local UI, view = anyPage(ns)
		if not UI then fail(scenario, "SKIPPED -- no page was long enough to scroll") return end
		UI.ScrollTo(0)
		cur.y = 600 - (view.height - 8) + 2
		Mock.mouseDown(view.bar)
		if not (view.scrollY > view.range / 2) then
			fail(scenario, ("a click near the bottom of the track left the page at %s of %s"):format(tostring(view.scrollY), tostring(view.range)))
		end
		Mock.mouseUp(view.bar)
	end)
end

do
	local scenario = "scrollbar: letting go ends the drag"
	with(scenario, function(ns, cur)
		local UI, view, travel = anyPage(ns)
		if not UI then fail(scenario, "SKIPPED -- no page was long enough to scroll") return end
		local bar = view.bar
		UI.ScrollTo(0)
		cur.y = 600 - view.thumb:GetHeight() / 2
		Mock.mouseDown(bar)
		cur.y = cur.y - 10
		bar.scripts.OnUpdate(bar, 0.016)
		local held = view.scrollY
		if not (held > 0) then fail(scenario, "the drag did not start") return end
		-- The client says the button is up, and the frame never hears of it.
		Mock.buttonsDown.LeftButton = false
		bar.scripts.OnUpdate(bar, 0.016)
		cur.y = cur.y - 40
		if bar.scripts.OnUpdate then
			bar.scripts.OnUpdate(bar, 0.016)
			fail(scenario, "the bar still follows the cursor after the button went up")
		end
		if view.scrollY ~= held then
			fail(scenario, ("the page moved from %s to %s after the button went up"):format(tostring(held), tostring(view.scrollY)))
		end
		-- Letting go on the bar, and hiding it, end a drag too.
		Mock.buttonsDown.LeftButton = true
		Mock.mouseDown(bar)
		Mock.mouseUp(bar)
		if bar.scripts.OnUpdate then fail(scenario, "letting go on the bar left its drag running") end
		Mock.mouseDown(bar)
		bar:Hide()
		if bar.scripts.OnUpdate then fail(scenario, "hiding the bar left its drag running") end
	end)
end

do
	local scenario = "scrollbar: a box's bar drags its text the same way"
	Mock.reset()
	FT.install()
	local was = rawget(_G, "GetCursorPosition")
	local cur = { y = 0 }
	rawset(_G, "GetCursorPosition", function() return 100, cur.y end)
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		drive(scenario, ns)
		ns.Prompt:ExitTest()
		Mock.buttonsDown.LeftButton = true
		local ctx = { changes = {}, holds = {}, pages = {}, relayouts = 0 }
		ctx.Window = CreateFrame("Frame", "MannersOptionsTest", UIParent)
		ctx.Window:SetSize(820, 600)
		ctx.OnChange = function(item) ctx.changes[#ctx.changes + 1] = item.path end
		ctx.OnHold = function() end
		ctx.ScrollPage = function(delta) ctx.pages[#ctx.pages + 1] = delta end
		ctx.Relayout = function(row) ctx.relayouts = ctx.relayouts + 1 row:Layout(row.width) end
		-- The Diagnostics report box, with text that runs past it.
		local item = ns.WindowBind.Item("diagnostics.report", {}, ctx)
		if not item then fail(scenario, "SKIPPED -- the model has no diagnostics.report") return end
		local row = ns.WindowWidgets.Build("multiline", ctx.Window, item)
		row:Layout(560)
		local lines = {}
		for i = 1, 80 do lines[i] = "Line " .. i .. ", thank you kindly" end
		row.box:SetText(table.concat(lines, "\n"))
		row.scroll:UpdateScrollChildRect()
		row.scroll.scripts.OnScrollRangeChanged(row.scroll)
		local range = row.scroll:GetVerticalScrollRange()
		if not (range > 0) or not row.bar:IsShown() then
			fail(scenario, "SKIPPED -- eighty lines do not run past the box")
			return
		end
		local high = row.scroll:GetHeight() - 6
		row.bar._top, row.bar._height = 300, high
		ns.WindowWidgets.PlaceThumb(row.bar)
		local travel = high - row.thumb:GetHeight()
		cur.y = 300 - row.thumb:GetHeight() / 2
		Mock.mouseDown(row.bar)
		cur.y = cur.y - 40
		if not row.bar.scripts.OnUpdate then fail(scenario, "nothing follows the cursor while the button is held") return end
		row.bar.scripts.OnUpdate(row.bar, 0.016)
		local at, want = row.scroll:GetVerticalScroll(), math.min(range, 40 * range / travel)
		if not (at > 0) or math.abs(at - want) > 1 then
			fail(scenario, ("the cursor 40 down took the box to %s, not about %s"):format(tostring(at), tostring(want)))
		end
		cur.y = cur.y + 40
		row.bar.scripts.OnUpdate(row.bar, 0.016)
		if row.scroll:GetVerticalScroll() > 0.5 then
			fail(scenario, "the cursor back up left the box at " .. tostring(row.scroll:GetVerticalScroll()))
		end
		Mock.mouseUp(row.bar)
		noErrors(scenario, ns)
	end)
	rawset(_G, "GetCursorPosition", was)
	FT.uninstall()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end
