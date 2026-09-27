-- The ledger window as it is drawn: where everything sits, whether it fits,
-- what an empty list shows, and what each tab lists.
--
-- The window was built without anybody seeing it, and its first layout hung
-- the headline and every row's name by an edge and a centre on the same axis
-- (TOPLEFT and RIGHT). The client sizes such a string from the distance
-- between the two, so the headline was drawn in the middle of the list and each
-- name on top of the line under it -- and against the mock, which draws
-- nothing, every scenario passed. These run on the recording CreateFrame in
-- tests/frametree.lua and work the layout out the way the client does, so a
-- string in the wrong place is a string in the wrong place here too.
-- tools/render_ledger.py draws the same thing as pictures.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

-- Text widths as the client would measure them, near enough: characters, not
-- bytes -- the mock's own estimate counts bytes, which makes a Cyrillic word
-- twice as wide as it is -- at a little over half an em each, which is Friz
-- Quadrata's average.
local function plain(text)
	return tostring(text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
end
local function chars(text)
	local n = 0
	for _ in plain(text):gmatch("[^\128-\191]") do n = n + 1 end
	return n
end
local function measure(fs)
	local size = fs._font and fs._font.size or 12
	return chars(fs._text) * size * 0.55
end

-- The recording CreateFrame, with that measure on every font string.
local function measured()
	local create = CreateFrame
	local function wrap(f)
		local make = f.CreateFontString
		f.CreateFontString = function(self, ...)
			local fs = make(self, ...)
			fs.GetStringWidth = measure
			fs.GetUnboundedStringWidth = measure
			-- The client's cap on wrapped lines, which the mock has no slot for.
			fs.SetMaxLines = function(self, n) self._maxLines = n return self end
			return fs
		end
		return f
	end
	CreateFrame = function(...) return wrap(create(...)) end
	wrap(UIParent)
	return function() CreateFrame = create end
end

-- Loaded in `locale` on the recording CreateFrame, driven, with an empty
-- ledger; everything put back afterwards whatever happens.
local function withWindow(scenario, locale, body)
	Mock.reset()
	Mock.locale = locale
	FT.install()
	local unmeasure = measured()
	local ns = load(scenario)
	local ok, err = true, nil
	if ns then
		ok, err = pcall(function()
			drive(scenario, ns)
			Mock.advance(60)
			wipe(ns.owed)
			ns.db.char.ledger = nil
			ns.Ledger.Load()
			body(ns)
			for _, e in ipairs(ns.errors or {}) do
				fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
			end
		end)
	end
	unmeasure()
	FT.uninstall()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- A day of play: every state a favour ends in, gifts to the group and to
-- strangers, a long name, a name with a realm, a favour of three buffs, and
-- more rows than the window shows.
local function busy(ns)
	local L = ns.Ledger
	L.Received({ name = "Oriel Dawnwhisper", class = "PRIEST", key = 21562 })
	Mock.advance(130)
	L.LetGo("Oriel Dawnwhisper")
	Mock.advance(3000)
	L.Received({ name = "Tamsin Reed", class = "PRIEST", key = 1126 })
	L.LetGo("Tamsin Reed", "notkept")
	for i = 1, 9 do
		L.Settled(("Walker Number%d"):format(i), nil, { inGroup = false, class = "MAGE" }, 1459)
		Mock.advance(300)
	end
	L.Received({ name = "Maximiliana Featherstonehaugh-Worthington", class = "PRIEST", key = 20217 })
	L.LetGo("Maximiliana Featherstonehaugh-Worthington", "never")
	Mock.advance(600)
	L.Received({ name = "Hild Ironbraid-Stormrage", class = "MAGE", key = 19740 })
	Mock.advance(30)
	L.Settled("Hild Ironbraid-Stormrage", { at = GetTime() - 30 }, { buffKey = "intellect" }, 1459)
	L.Settled("Gwen Hollow", nil, { inGroup = true, class = "PRIEST" }, 1459)
	L.Received({ name = "Brannoc Vale", class = "MAGE", key = 6673 }, true)
	Mock.advance(400)
	L.Received({ name = "Anna Aim", class = "PRIEST", key = 21562 })
	L.Received({ name = "Anna Aim", class = "PRIEST", key = 27841 })
	L.Received({ name = "Anna Aim", class = "PRIEST", key = 10958 })
	Mock.advance(60)
end

local function open(ns, tab)
	ns.addon:HandleSlash("ledger")
	local window = ns.Ledger.Window()
	if tab then
		for _, t in ipairs(window and window.tabs or {}) do
			if t.key == tab then t.scripts.OnClick(t) end
		end
	end
	return window
end

-- ---------------------------------------------------------------- layout
-- Where a region sits, worked out from its anchors the way the client does:
-- two edges on an axis give its extent, one edge and a size the rest, and one
-- edge and a centre make it twice as long as the distance between them. A font
-- string with nothing else to size it is as wide as its text and as tall as
-- its lines.

local function frac(point)
	local fx, fy = 0.5, 0.5
	if point:find("LEFT", 1, true) then fx = 0 elseif point:find("RIGHT", 1, true) then fx = 1 end
	if point:find("BOTTOM", 1, true) then fy = 0 elseif point:find("TOP", 1, true) then fy = 1 end
	return fx, fy
end

local function pointsOf(r)
	if r._allPointsTo then
		return { { "TOPLEFT", r._allPointsTo, "TOPLEFT", 0, 0 },
			{ "BOTTOMRIGHT", r._allPointsTo, "BOTTOMRIGHT", 0, 0 } }
	end
	local out = {}
	for i, p in ipairs(r.points or {}) do
		local point, a, b, c, d = p[1], p[2], p[3], p[4], p[5]
		if type(a) == "number" then
			out[i] = { point, r._parent, point, a, b or 0 }
		elseif a == nil then
			out[i] = { point, r._parent, point, 0, 0 }
		else
			out[i] = { point, a, b or point, c or 0, d or 0 }
		end
	end
	return out
end

-- Which axis, if any, a region is hung on by one edge and a centre.
local function mixedAxis(r)
	local xs, ys = {}, {}
	for _, p in ipairs(pointsOf(r)) do
		local fx, fy = frac(p[1])
		xs[fx] = true
		ys[fy] = true
	end
	if xs[0.5] and (xs[0] ~= nil) ~= (xs[1] ~= nil) then return "x" end
	if ys[0.5] and (ys[0] ~= nil) ~= (ys[1] ~= nil) then return "y" end
	return nil
end

local function newLayout()
	local rects, busyIds = {}, {}
	local rect
	local function axis(edges, size)
		local lo, hi, mid = edges[0], edges[1], edges[0.5]
		if lo and hi then return lo, hi end
		if mid and lo then return lo, lo + 2 * (mid - lo) end
		if mid and hi then return hi - 2 * (hi - mid), hi end
		if lo then return lo, lo + size end
		if hi then return hi - size, hi end
		if mid then return mid - size / 2, mid + size / 2 end
		return nil
	end
	rect = function(r)
		if r == nil then return nil end
		if r == UIParent then return { 0, 0, 1600, 1000 } end
		if rects[r] then return rects[r] end
		if busyIds[r] then return nil end
		busyIds[r] = true
		local ex, ey = {}, {}
		for _, p in ipairs(pointsOf(r)) do
			local rel = rect(p[2])
			if rel then
				local rfx, rfy = frac(p[3] or p[1])
				local fx, fy = frac(p[1])
				ex[fx] = rel[1] + (rel[3] - rel[1]) * rfx + (p[4] or 0)
				ey[fy] = rel[2] + (rel[4] - rel[2]) * rfy + (p[5] or 0)
			end
		end
		local text = r._kind == "FontString"
		local size = text and (r._font and r._font.size or 12) or 0
		local L, R = axis(ex, r._width or (text and measure(r)) or 0)
		local h = r._height
		if not h and text then
			local lines = 1
			if r._wordWrap and L then
				lines = math.max(1, math.ceil(measure(r) / math.max(1, R - L)))
				if r._maxLines and r._maxLines > 0 then lines = math.min(lines, r._maxLines) end
			end
			h = lines * size * (lines > 1 and 1.15 or 1)
		end
		local B, T = axis(ey, h or 0)
		busyIds[r] = nil
		if not (L and B) then return nil end
		rects[r] = { L, B, R, T }
		return rects[r]
	end
	return rect
end

local function overlaps(a, b)
	return a[1] < b[3] - 0.01 and b[1] < a[3] - 0.01 and a[2] < b[4] - 0.01 and b[2] < a[4] - 0.01
end

local function inside(a, b)
	return a[1] >= b[1] - 0.01 and a[3] <= b[3] + 0.01 and a[2] >= b[2] - 0.01 and a[4] <= b[4] + 0.01
end

local function shown(r)
	return FT.visible(r)
end

-- Every region under the window, in the order they were made.
local function regionsOf(window)
	local out = {}
	local function walk(r)
		for _, c in ipairs(r._children or {}) do
			out[#out + 1] = c
			walk(c)
		end
	end
	walk(window)
	return out
end

-- A string's text for a failure line, its letters past ASCII written as byte
-- codes: the report is printed on consoles that cannot show Cyrillic, and a
-- print that throws takes the whole report with it.
local function say(fs)
	local text = plain(fs and fs._text):gsub("[\128-\255]", function(c) return "\\" .. c:byte() end)
	return '"' .. text .. '"'
end

local LOCALES = { "enUS", "deDE", "ruRU" }

-- ------------------------------------------------------------------ ledgerui 1
-- Every string and plate on the window is hung by edges, never by an edge and
-- a centre on the same axis. The first window was, and in the client its
-- headline sat in the middle of the list and every name on the line under it.
for _, locale in ipairs(LOCALES) do
	local scenario = "ledgerui: the window is hung by edges, never an edge and a centre (" .. locale .. ")"
	withWindow(scenario, locale, function(ns)
		busy(ns)
		local window = open(ns, "all")
		if not (window and window:IsShown()) then
			fail(scenario, "SKIPPED -- /manners ledger did not open the window")
			return
		end
		for _, r in ipairs(regionsOf(window)) do
			local axis = mixedAxis(r)
			if axis then
				local what = r._kind == "FontString" and ("the string " .. say(r)) or ("a " .. tostring(r._kind))
				fail(scenario, ("%s is hung by an edge and a centre on the %s axis, which the client"
					.. " sizes from the distance between them"):format(what, axis))
			end
		end
	end)
end

-- ------------------------------------------------------------------ ledgerui 2
-- The rows are laid out without overlap: each row's icon, name, time, badge
-- and detail apart from one another, the badge's word on its plate, the rows
-- apart from each other and inside the list, and the header, tiles and tabs
-- above it, in every language.
for _, locale in ipairs(LOCALES) do
	local scenario = "ledgerui: rows and header are laid out without overlap (" .. locale .. ")"
	withWindow(scenario, locale, function(ns)
		busy(ns)
		local window = open(ns, "all")
		if not (window and window:IsShown()) then
			fail(scenario, "SKIPPED -- /manners ledger did not open the window")
			return
		end
		local rect = newLayout()
		local win = rect(window)
		local painted = 0
		local rowRects = {}
		for i, row in ipairs(window.rows) do
			if shown(row) then
				painted = painted + 1
				local rr = rect(row)
				rowRects[#rowRects + 1] = rr
				local parts = {
					{ "icon", rect(row.iconBack) }, { "name", rect(row.name) },
					{ "time", rect(row.when) }, { "badge", rect(row.badgePlate) },
					{ "detail", rect(row.detail) },
				}
				for a = 1, #parts do
					local pa = parts[a]
					if not pa[2] then
						fail(scenario, ("row %d's %s has no place on screen"):format(i, pa[1]))
					elseif not inside(pa[2], rr) then
						fail(scenario, ("row %d's %s reaches outside the row"):format(i, pa[1]))
					end
					for b = a + 1, #parts do
						local pb = parts[b]
						if pa[2] and pb[2] and overlaps(pa[2], pb[2]) then
							fail(scenario, ("row %d's %s and %s overlap (%s / %s)"):format(i, pa[1], pb[1],
								say(row.name), say(row.detail)))
						end
					end
				end
				local word, plate = rect(row.badge), rect(row.badgePlate)
				if word and plate and measure(row.badge) > (plate[3] - plate[1]) + 0.5 then
					fail(scenario, ("row %d's badge %s is wider than its plate"):format(i, say(row.badge)))
				end
			end
		end
		if painted ~= #window.rows then
			fail(scenario, ("SKIPPED -- a list longer than the window painted %d of %d rows"):format(
				painted, #window.rows))
		end
		for a = 1, #rowRects do
			for b = a + 1, #rowRects do
				if overlaps(rowRects[a], rowRects[b]) then
					fail(scenario, ("rows %d and %d overlap"):format(a, b))
				end
			end
		end
		-- Top to bottom: the summary, the tiles, the tabs, the list, the footer.
		local list = rect(window.rows[1])
		local last = rowRects[#rowRects]
		local above = { { "headline", window.headline }, { "summary line", window.subline } }
		for _, stat in ipairs(window.stats) do above[#above + 1] = { "tile", stat.plate } end
		for _, tab in ipairs(window.tabs) do above[#above + 1] = { "tab", tab } end
		for _, a in ipairs(above) do
			local r = rect(a[2])
			if not r then
				fail(scenario, "the " .. a[1] .. " has no place on screen")
			elseif list and r[2] < list[4] - 0.01 then
				fail(scenario, ("the %s reaches down into the list"):format(a[1]))
			elseif not inside(r, win) then
				fail(scenario, ("the %s reaches outside the window"):format(a[1]))
			end
		end
		local sub, tile = rect(window.subline), rect(window.stats[1].plate)
		if sub and tile and sub[2] < tile[4] + 10 - 0.01 then
			fail(scenario, ("the summary line (%s) runs into the all-time tiles"):format(say(window.subline)))
		end
		local head = rect(window.headline)
		if head and sub and overlaps(head, sub) then
			fail(scenario, "the headline and the summary line overlap")
		end
		for i = 1, #window.tabs - 1 do
			local a, b = rect(window.tabs[i]), rect(window.tabs[i + 1])
			if a and b and overlaps(a, b) then fail(scenario, ("tabs %d and %d overlap"):format(i, i + 1)) end
		end
		local clear, showing = rect(window.clear), rect(window.showing)
		if last and clear and last[2] < clear[4] - 0.01 then
			fail(scenario, "the last row reaches down into the footer")
		end
		if clear and showing and overlaps(clear, showing) then
			fail(scenario, "the position in the list runs into Clear")
		end
		if clear and not inside(clear, win) then fail(scenario, "Clear reaches outside the window") end
	end)
end

-- ------------------------------------------------------------------ ledgerui 3
-- Long text fits or is cut with an ellipsis, never spilling out of its box.
-- Every one-line string is bounded on both sides, so the client cuts it where
-- it has to; and the words a player needs whole -- the summary, the tabs, the
-- tile labels, Clear in both its states, the badges -- fit, in German and
-- Russian as well as English. Names and details may be cut: the tooltip tells
-- the whole of those.
for _, locale in ipairs(LOCALES) do
	local scenario = "ledgerui: long text fits or ellipsises (" .. locale .. ")"
	withWindow(scenario, locale, function(ns)
		busy(ns)
		local window = open(ns, "all")
		if not (window and window:IsShown()) then
			fail(scenario, "SKIPPED -- /manners ledger did not open the window")
			return
		end
		local rect = newLayout()
		local win = rect(window)
		for _, r in ipairs(regionsOf(window)) do
			if r._kind == "FontString" and shown(r) and plain(r._text) ~= "" then
				local box = rect(r)
				if not box then
					fail(scenario, "the string " .. say(r) .. " has no place on screen")
				elseif not inside(box, win) then
					fail(scenario, "the string " .. say(r) .. " reaches outside the window")
				elseif not r._wordWrap and measure(r) > (box[3] - box[1]) + 0.5 then
					-- Cut by the client, which is fine only where the string is
					-- bounded by its anchors or a width rather than sized by its
					-- text: a string sized by its text is never cut, it spills.
					local bounded = r._width ~= nil
					local xs = {}
					for _, p in ipairs(pointsOf(r)) do xs[(frac(p[1]))] = true end
					bounded = bounded or (xs[0] and xs[1])
					if not bounded then
						fail(scenario, "the string " .. say(r) .. " is wider than its box and nothing cuts it")
					end
				end
			end
		end

		local function fits(what, fs, text)
			local box = rect(fs)
			local was = fs._text
			if text then fs._text = text end
			local need, shownAs = measure(fs), say(fs)
			fs._text = was
			if box and need > (box[3] - box[1]) + 0.5 then
				fail(scenario, ("%s %s is cut: it needs %d and has %d"):format(what, shownAs,
					need, box[3] - box[1]))
			end
		end
		fits("the headline", window.headline)
		fits("the title", window.title)
		for _, tab in ipairs(window.tabs) do fits("the tab", tab.label) end
		for _, stat in ipairs(window.stats) do fits("the tile label", stat.label) end
		fits("Clear", window.clear.label, ns.Ledger.TEXT.CLEAR)
		fits("Clear, armed,", window.clear.label, ns.Ledger.TEXT.CLEAR_ARMED)
		for _, row in ipairs(window.rows) do
			if shown(row) then fits("the badge", row.badge) end
		end
		-- The summary line wraps rather than being cut: two sentences that do
		-- not share one line in German are given a second.
		local sub = rect(window.subline)
		local lines = sub and measure(window.subline) / math.max(1, sub[3] - sub[1]) or 0
		local cap = window.subline._maxLines
		if lines > 1 and not (window.subline._wordWrap and (cap == nil or cap == 0 or cap >= math.ceil(lines))) then
			fail(scenario, ("the summary line %s is %.1f lines long and is cut to one"):format(
				say(window.subline), lines))
		end
	end)
end

-- ------------------------------------------------------------------ ledgerui 4
-- The empty list: the faded mark and a line saying how a row comes to be
-- there, in the list and clear of the tabs, with no rows, no scroll bar and no
-- "1-0 of 0"; the line under the gifts tab is the gifts' own; and while
-- nothing can arrive, the line says why, in a warmer colour than the ordinary
-- one. With rows on screen, neither the mark nor the line shows.
do
	local scenario = "ledgerui: the empty list says how rows arrive"
	withWindow(scenario, "enUS", function(ns)
		local T = ns.Ledger.TEXT
		local window = open(ns, "all")
		if not (window and window:IsShown()) then
			fail(scenario, "SKIPPED -- /manners ledger did not open the window")
			return
		end
		local rect = newLayout()
		for i, row in ipairs(window.rows) do
			if shown(row) then fail(scenario, ("row %d shows on an empty ledger"):format(i)) end
		end
		if not (shown(window.empty) and shown(window.emptyIcon)) then
			fail(scenario, "an empty ledger shows no mark or no line in place of the list")
		elseif window.empty:GetText() ~= T.EMPTY_ALL then
			fail(scenario, "the empty list reads " .. say(window.empty))
		else
			local icon, line = rect(window.emptyIcon), rect(window.empty)
			local tab = rect(window.tabs[1])
			local rule = window.clear and rect(window.clear)
			if not (icon and line) then
				fail(scenario, "the empty list's mark or line has no place on screen")
			else
				if overlaps(icon, line) then fail(scenario, "the empty list's line runs over its mark") end
				if tab and icon[4] > tab[2] - 8 then fail(scenario, "the empty list's mark crowds the tabs") end
				if rule and line[2] < rule[4] then fail(scenario, "the empty list's line runs into the footer") end
			end
		end
		if shown(window.showing) then fail(scenario, "an empty list still says where in the list it is") end
		if shown(window.thumb) then fail(scenario, "an empty list has a scroll bar") end
		local ordinary = window.empty._textColor

		for _, t in ipairs(window.tabs) do if t.key == "given" then t.scripts.OnClick(t) end end
		if window.empty:GetText() ~= T.EMPTY_GIVEN then
			fail(scenario, "the empty gifts tab reads " .. say(window.empty))
		end

		ns.db.profile.enabled = false
		for _, t in ipairs(window.tabs) do if t.key == "all" then t.scripts.OnClick(t) end end
		local off = window.empty._textColor
		if window.empty:GetText() ~= T.EMPTY_OFF then
			fail(scenario, "switched off, the empty list reads " .. say(window.empty))
		elseif ordinary and off and ordinary[1] == off[1] and ordinary[2] == off[2] and ordinary[3] == off[3] then
			fail(scenario, "the line saying nothing can be recorded looks the same as the ordinary one")
		end
		ns.db.profile.enabled = true

		ns.Ledger.Received({ name = "Anna Aim", class = "PRIEST", key = 21562 })
		if shown(window.empty) or shown(window.emptyIcon) then
			fail(scenario, "with a row on screen, the empty list's mark or line still shows")
		end
		if not shown(window.rows[1]) then fail(scenario, "SKIPPED -- the new favour painted no row") end
	end)
end

-- ------------------------------------------------------------------ ledgerui 5
-- Each tab: the one chosen is the one marked, and it lists what it says, newest
-- first, each row's badge the word and the colour for its entry and its stripe
-- the same colour.
do
	local scenario = "ledgerui: each tab lists its own rows, badged"
	withWindow(scenario, "enUS", function(ns)
		busy(ns)
		local T = ns.Ledger.TEXT
		local window = open(ns, "all")
		if not (window and window:IsShown()) then
			fail(scenario, "SKIPPED -- /manners ledger did not open the window")
			return
		end
		local want = { owed = T.STATE_OWED, returned = T.STATE_RETURNED, letgo = T.STATE_LETGO }
		for _, tab in ipairs(window.tabs) do
			tab.scripts.OnClick(tab)
			for _, other in ipairs(window.tabs) do
				local marked = shown(other.underline)
				if marked ~= (other == tab) then
					fail(scenario, ("with %s chosen, the %s tab is %s"):format(tab.key, other.key,
						marked and "marked too" or "not marked"))
				end
			end
			local list = ns.Ledger.Entries(tab.key)
			if #list == 0 then fail(scenario, "SKIPPED -- the " .. tab.key .. " tab has nothing to list") end
			for i, row in ipairs(window.rows) do
				local e = list[i]
				if e and not shown(row) then
					fail(scenario, ("the %s tab shows no row %d with %d to list"):format(tab.key, i, #list))
				elseif e then
					if row.entry ~= e then
						fail(scenario, ("the %s tab's row %d is not its %dth entry, newest first"):format(tab.key, i, i))
					end
					if tab.key == "favours" and e.kind ~= "received" then
						fail(scenario, "the favours tab lists a buff you gave")
					elseif tab.key == "given" and e.kind ~= "given" then
						fail(scenario, "the buffs-you-gave tab lists a favour")
					end
					local word = e.kind == "given" and T.STATE_GAVE or want[e.state]
					if row.badge:GetText() ~= word then
						fail(scenario, ("row %d of %s is %s and its badge reads %s"):format(i, tab.key,
							tostring(e.kind == "given" and "a gift" or e.state), say(row.badge)))
					end
					local b, s = row.badge._textColor, row.stripe._color
					if not (b and s and b[1] == s[1] and b[2] == s[2] and b[3] == s[3]) then
						fail(scenario, ("row %d of %s: the badge and the stripe are not the same colour"):format(
							i, tab.key))
					end
					if not plain(row.name:GetText()):find(e.name, 1, true) then
						fail(scenario, ("row %d of %s names %s for %s"):format(i, tab.key, say(row.name), e.name))
					end
				elseif shown(row) then
					fail(scenario, ("the %s tab shows a row %d with %d to list"):format(tab.key, i, #list))
				end
			end
		end
		-- A gift to the group and one to a stranger do not share a colour.
		for _, t in ipairs(window.tabs) do if t.key == "given" then t.scripts.OnClick(t) end end
		local colours = {}
		for _, row in ipairs(window.rows) do
			if shown(row) and row.entry then
				local c = row.badge._textColor
				colours[row.entry.to] = c and table.concat({ c[1], c[2], c[3] }, ",")
			end
		end
		if not (colours.group and colours.stranger) then
			fail(scenario, "SKIPPED -- the gifts tab does not show a gift of each kind")
		elseif colours.group == colours.stranger then
			fail(scenario, "a gift to the group and one to a stranger are badged in the same colour")
		end
	end)
end
