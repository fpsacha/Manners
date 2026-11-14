-- The options window's menu: columns when the window is dragged wide
-- (Options/Window/WindowPage.lua, UI.ColumnsFor, UI.ColumnBreaks, FlowRun;
-- Window.lua, UI.Resized and UI.Reflow; Widgets.lua, W.Grow; Layout.lua,
-- `spans`).
--
-- Every scenario name starts with "menu:" so the mutations in
-- tests/mutations/menu.py can name the one that has to catch them.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

-- The page's padding and the gap between two columns (WindowPage.lua).
local PAD_LEFT, PAD_BOTTOM, COLUMN_GAP = 18, 26, 28

local function near(a, b, eps) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < (eps or 0.5) end

-- opts: class, page, screen (the screen's width in UI units), before(ns).
local function with(scenario, opts, body)
	Mock.reset()
	FT.install()
	local ok, err = pcall(function()
		if opts.class then Mock.class = opts.class end
		if opts.screen then Mock.screenWidth = opts.screen end
		local ns = load(scenario)
		if not ns then return end
		drive(scenario, ns)
		ns.Prompt:ExitTest()
		if opts.before then opts.before(ns) end
		ns.OpenOptions(opts.page or "when")
		ns.Prompt:ExitTest()
		body(ns, ns.WindowUI)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	FT.uninstall()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- The sections of the open page that are drawn, in the layout's order.
local function drawn(UI)
	local out = {}
	for _, sec in ipairs(UI.Model(UI.page).sections) do
		if sec.visible then out[#out + 1] = sec end
	end
	return out
end

-- The rows of a section that are on screen now.
local function rows(UI, sec)
	local out = {}
	if sec.fold and not UI.State().open[sec.key] then return out end
	for _, e in ipairs(sec.entries) do
		if e.visible and e.row and e.row.frame:IsShown() then out[#out + 1] = e end
	end
	return out
end

-- Where every row of the page is, for comparing two layouts.
local function places(UI)
	local out = {}
	for _, sec in ipairs(drawn(UI)) do
		for _, e in ipairs(rows(UI, sec)) do
			out[#out + 1] = ("%s@%d,%d %dx%d"):format(e.path, e.x, e.y, e.row.frame:GetWidth(), e.h)
		end
	end
	return table.concat(out, "\n")
end

local function contentWidth(UI) return UI.WIDTH - UI.SIDEBAR - 13 - PAD_LEFT - 17 end

do
	local scenario = "menu: a window dragged wide flows a page's sections into two columns, and three when very wide"
	with(scenario, { screen = 1792, page = "when" }, function(ns, UI)
		if UI.Columns() ~= 1 then fail(scenario, "the usual window has " .. tostring(UI.Columns()) .. " columns") end
		for _, sec in ipairs(drawn(UI)) do
			if sec.column ~= 1 then fail(scenario, sec.key .. " is in column " .. tostring(sec.column) .. " of the usual window") end
		end
		for _, case in ipairs({ { 1320, 2 }, { 1740, 3 } }) do
			UI.SetWindowSize(case[1], 720)
			local width, want = contentWidth(UI), case[2]
			if UI.Columns() ~= want then
				fail(scenario, ("%d wide has room for %s columns, not %d"):format(case[1], tostring(UI.Columns()), want))
			end
			local colW = math.floor((width - (want - 1) * COLUMN_GAP) / want)
			local used, lastColumn, lastTop, folds = {}, 0, -1, false
			for _, sec in ipairs(drawn(UI)) do
				if not sec.span then
					local c = sec.column
					-- The folds are a run of their own, under their caption: the
					-- columns start again there.
					if sec.fold ~= folds then folds, lastColumn = sec.fold, 0 end
					used[c or 0] = true
					-- Reading order: down a column, then the next one to the right.
					if not c or c < lastColumn then
						fail(scenario, ("%d wide: %s is in column %s after one in column %d"):format(case[1], sec.key, tostring(c), lastColumn))
					elseif c == lastColumn and not (sec.top > lastTop) then
						fail(scenario, ("%d wide: %s is not under the section before it in its column"):format(case[1], sec.key))
					end
					lastColumn, lastTop = c or lastColumn, sec.top or lastTop
					-- Never split: every row of it inside its own column.
					local left = ((c or 1) - 1) * (colW + COLUMN_GAP) + PAD_LEFT
					for _, e in ipairs(rows(UI, sec)) do
						if e.x < left - 0.5 or e.x + e.row.frame:GetWidth() > left + colW + 0.5 then
							fail(scenario, ("%d wide: %s of %s runs from %s to %s, outside column %s (%s to %s)"):format(case[1],
								e.path, sec.key, tostring(e.x), tostring(e.x + e.row.frame:GetWidth()), tostring(c), tostring(left), tostring(left + colW)))
						end
						if e.y < sec.top - 0.5 then fail(scenario, ("%d wide: %s is above its own section"):format(case[1], e.path)) end
					end
				end
			end
			for c = 1, want do
				if not used[c] then fail(scenario, ("%d wide: nothing in column %d of %d"):format(case[1], c, want)) end
			end
		end
	end)
end

do
	local scenario = "menu: narrow again, the page is the one column it was"
	with(scenario, { page = "who", class = "PRIEST" }, function(ns, UI)
		local before, range = places(UI), UI.view.range
		if before == "" then fail(scenario, "no row on the page") return end
		UI.SetWindowSize(1320, 720)
		if places(UI) == before then fail(scenario, "nothing moved in a window 1320 wide") end
		UI.SetWindowSize(820, 600)
		local after = places(UI)
		if after ~= before then
			fail(scenario, "back at 820 x 600 the rows are not where they were")
		end
		if not near(UI.view.range, range) then
			fail(scenario, ("the page scrolled %s before and %s after"):format(tostring(range), tostring(UI.view.range)))
		end
		-- One column is the whole page's width, from its left edge.
		for _, sec in ipairs(drawn(UI)) do
			if sec.column ~= 1 or sec.left ~= 0 or sec.width ~= contentWidth(UI) then
				fail(scenario, ("%s: column %s at %s, %s wide"):format(sec.key, tostring(sec.column), tostring(sec.left), tostring(sec.width)))
			end
		end
	end)
end

do
	local scenario = "menu: the columns are cut where the tallest is shortest, the left one filled first"
	with(scenario, {}, function(ns, UI)
		local cut = UI.ColumnBreaks
		if type(cut) ~= "function" then fail(scenario, "no UI.ColumnBreaks") return end
		local cases = {
			{ { 100, 100, 100, 100 }, 2, "1 3" },
			{ { 300, 50, 50 }, 2, "1 2" },
			{ { 50, 50, 300 }, 2, "1 3" },
			{ { 100, 50, 50, 100 }, 2, "1 3" },
			-- As short either way: the left column takes the two.
			{ { 100, 100, 100 }, 2, "1 3" },
			{ { 100, 100, 100 }, 3, "1 2 3" },
			{ { 10, 10, 10, 200, 10 }, 3, "1 4 5" },
			{ { 120 }, 3, "1" },
			{ { 80, 90 }, 1, "1" },
		}
		for _, case in ipairs(cases) do
			local got = table.concat(cut(case[1], case[2]), " ")
			if got ~= case[3] then
				fail(scenario, ("heights %s in %d columns start at %s, not %s"):format(table.concat(case[1], ","), case[2], got, case[3]))
			end
		end
	end)
end

do
	local scenario = "menu: what comes under the columns starts under the tallest, and the page scrolls to its end"
	with(scenario, { page = "when" }, function(ns, UI)
		UI.SetWindowSize(1320, 620)
		-- Where each column of the sections before the folds ends, and where
		-- the folds under them begin and end.
		local bottoms, foldTop, last = {}, nil, 0
		for _, sec in ipairs(drawn(UI)) do
			if sec.fold then
				foldTop = math.min(foldTop or math.huge, sec.top)
				last = math.max(last, sec.y + 26)
			else
				for _, e in ipairs(rows(UI, sec)) do
					if not sec.span then bottoms[sec.column] = math.max(bottoms[sec.column] or 0, e.y + e.h) end
					last = math.max(last, e.y + e.h)
				end
			end
		end
		if not (bottoms[1] and bottoms[2]) then fail(scenario, "the page is not in two columns") return end
		if not foldTop then fail(scenario, "no fold under the columns of When to offer") return end
		if near(bottoms[1], bottoms[2], 30) then fail(scenario, "the two columns end level: the scenario proves nothing") end
		-- The folds' caption stands between the columns and the folds: a line
		-- of small text and its room, 24 at the least.
		if foldTop < math.max(bottoms[1], bottoms[2]) + 24 then
			fail(scenario, ("the folds start at %s, over a column or its caption (the columns end at %s and %s)"):format(tostring(foldTop),
				tostring(bottoms[1]), tostring(bottoms[2])))
		end
		local total = UI.view.range + UI.view.height
		-- The last thing drawn, the gap under it, the padding under the page.
		if total < last + PAD_BOTTOM or total > last + PAD_BOTTOM + 40 then
			fail(scenario, ("the page is %s tall and the last thing on it ends at %s"):format(tostring(total), tostring(last)))
		end
		-- No fold on Who to skip: the page ends under its taller column.
		ns.OpenOptions("skip")
		local ends = {}
		for _, sec in ipairs(drawn(UI)) do
			for _, e in ipairs(rows(UI, sec)) do
				if not sec.span then ends[sec.column] = math.max(ends[sec.column] or 0, e.y + e.h) end
			end
		end
		if not (ends[1] and ends[2]) then fail(scenario, "Who to skip is not in two columns") return end
		local tallest = math.max(ends[1], ends[2])
		total = UI.view.range + UI.view.height
		if total < tallest + PAD_BOTTOM then
			fail(scenario, ("Who to skip is %s tall, its columns end at %s and %s"):format(tostring(total), tostring(ends[1]), tostring(ends[2])))
		end
	end)
end

do
	local scenario = "menu: the line a page opens with runs across the columns"
	with(scenario, { page = "who", class = "PRIEST" }, function(ns, UI)
		UI.SetWindowSize(1320, 720)
		local w = UI.Where("who.rightNow")
		if not (w and w.e.row) then fail(scenario, "no Right now line on Who to buff") return end
		if not near(w.e.row.frame:GetWidth(), contentWidth(UI)) then
			fail(scenario, ("Right now is %s wide in a page of %s"):format(tostring(w.e.row.frame:GetWidth()), tostring(contentWidth(UI))))
		end
		local under = w.e.y + w.e.h
		for _, sec in ipairs(drawn(UI)) do
			if not sec.span and sec.top < under then
				fail(scenario, ("%s starts at %s, beside the Right now line (which ends at %s)"):format(sec.key, tostring(sec.top), tostring(under)))
			end
		end
	end)
end

do
	local scenario = "menu: a drag re-flows the page at every change of size, reading and building nothing"
	with(scenario, { page = "when" }, function(ns, UI)
		local W, B = ns.WindowWidgets, ns.WindowBind
		local f = UI.frame
		-- The grip held: the first change of size paints in full, the ones
		-- within a tenth of a second of it only place the rows.
		UI.sizing = true
		f:SetSize(900, 600)
		UI.Resized(false)
		local row = UI.RowFor("when.hideMounted")
		if not row then fail(scenario, "no Hide while mounted row") UI.sizing = false return end
		local built, read, asked = 0, 0, 0
		local build, hidden, refresh = W.Build, B.Hidden, row.Refresh
		W.Build = function(...) built = built + 1 return build(...) end
		B.Hidden = function(...) asked = asked + 1 return hidden(...) end
		row.Refresh = function(...) read = read + 1 return refresh(...) end
		local before = places(UI)
		f:SetSize(1320, 720)
		UI.Resized(false)
		W.Build, B.Hidden, row.Refresh = build, hidden, nil
		UI.sizing = false
		if UI.Model(UI.page).columns ~= 2 then
			fail(scenario, "dragged to 1320 wide the page is in " .. tostring(UI.Model(UI.page).columns) .. " column(s) until the grip is let go")
		end
		if places(UI) == before then fail(scenario, "no row moved while the grip was held") end
		if built > 0 then fail(scenario, built .. " row(s) built while the grip was held") end
		if read > 0 then fail(scenario, "a row was read again while the grip was held") end
		if asked > 0 then fail(scenario, asked .. " rule(s) of the model asked while the grip was held") end
		local total = UI.view.range + UI.view.height
		if not near(UI.view.height, 720 - (600 - 522), 1) then
			fail(scenario, "the page's room is " .. tostring(UI.view.height) .. " in a window 720 tall")
		end
		-- Let go: painted in full, and the rows are where the drag left them.
		local dragged = places(UI)
		UI.SetWindowSize(1320, 720)
		if places(UI) ~= dragged then fail(scenario, "letting go of the grip moved the rows") end
		if not near(UI.view.range + UI.view.height, total) then fail(scenario, "letting go changed how far the page scrolls") end
	end)
end

do
	local scenario = "menu: a field grows with a row wider than the usual page, and is as it was in a column"
	with(scenario, { page = "when" }, function(ns, UI)
		local W = ns.WindowWidgets
		if type(W.Grow) ~= "function" then fail(scenario, "no W.Grow") return end
		for _, case in ipairs({ { 300, 400, 300 }, { 300, 612, 300 }, { 300, 712, 350 }, { 300, 2000, 450 }, { 360, 772, 440 } }) do
			local got = W.Grow(case[1], case[2])
			if got ~= case[3] then
				fail(scenario, ("a field of %d in a row of %d is %s wide, not %d"):format(case[1], case[2], tostring(got), case[3]))
			end
		end
		local function field()
			local row = UI.RowFor("when.whenBuffed")
			return row and row.field and row.field:GetWidth()
		end
		local usual = field()
		if not usual then fail(scenario, "no dropdown to measure on When to offer") return end
		-- One column of 772.
		UI.SetWindowSize(980, 600)
		local grown = field()
		if not (grown and grown > usual + 40) then
			fail(scenario, ("the dropdown is %s wide in the usual window and %s in one 980 wide"):format(tostring(usual), tostring(grown)))
		end
		-- Two columns of 544: no wider than the usual page.
		UI.SetWindowSize(1320, 600)
		if not near(field(), usual) then
			fail(scenario, ("the dropdown is %s wide in the usual window and %s in a column of a wide one"):format(tostring(usual), tostring(field())))
		end
	end)
end
