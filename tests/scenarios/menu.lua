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

-- The buffs a class has learned, by key (every rank), for the scenarios that
-- need its switches on the page.
local KNOWS = {
	PRIEST = { "fortitude", "spirit", "shadow" },
	PALADIN = { "wisdom", "might", "kings" },
}

-- opts: class, page, screen (the screen's width in UI units), before(ns),
-- newProfile (the profile left to start as a new one does).
local function with(scenario, opts, body)
	Mock.reset()
	FT.install()
	local known, playerSpell = rawget(_G, "IsSpellKnown"), rawget(_G, "IsPlayerSpell")
	local ok, err = pcall(function()
		if opts.class then Mock.class = opts.class end
		if opts.screen then Mock.screenWidth = opts.screen end
		if opts.newProfile then Mock.newMenu = true end
		local ns = load(scenario)
		if not ns then return end
		if KNOWS[opts.class or ""] then
			local set = {}
			for _, key in ipairs(KNOWS[opts.class]) do
				local buff = ns.FindBuff(opts.class, key)
				for _, id in ipairs(buff and buff.ranks or {}) do set[id] = true end
			end
			IsSpellKnown = function(id) return set[id] == true end
			IsPlayerSpell = IsSpellKnown
		end
		drive(scenario, ns)
		if KNOWS[opts.class or ""] then ns.Guard("probe", ns.ProbeCapabilities) end
		ns.Prompt:ExitTest()
		if opts.before then opts.before(ns) end
		ns.OpenOptions(opts.page or "when")
		ns.Prompt:ExitTest()
		body(ns, ns.WindowUI)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	rawset(_G, "IsSpellKnown", known)
	rawset(_G, "IsPlayerSpell", playerSpell)
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
	with(scenario, { page = "who", class = "PRIEST" }, function(ns, UI)
		UI.SetWindowSize(1320, 620)
		-- Where each column of the sections before the folds ends, where the
		-- folds under them begin, and the last thing on the page.
		for _, id in ipairs({ "who", "when" }) do
			ns.OpenOptions(id)
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
			if not (bottoms[1] and bottoms[2]) then
				fail(scenario, id .. " is not in two columns")
			elseif not foldTop then
				fail(scenario, "no fold under the columns of " .. id)
			else
				-- The folds' caption stands between the columns and the folds: a
				-- line of small text and its room, 24 at the least.
				local tallest = math.max(bottoms[1], bottoms[2])
				if foldTop < tallest + 24 then
					fail(scenario, ("%s: the folds start at %s, over a column or its caption (the columns end at %s and %s)"):format(id,
						tostring(foldTop), tostring(bottoms[1]), tostring(bottoms[2])))
				end
			end
			local total = UI.view.range + UI.view.height
			-- The last thing drawn, the gap under it, the padding under the page.
			if total < last + PAD_BOTTOM or total > last + PAD_BOTTOM + 40 then
				fail(scenario, ("%s is %s tall and the last thing on it ends at %s"):format(id, tostring(total), tostring(last)))
			end
		end
		-- The folds are flowed the same way, and the page ends under the taller
		-- of them: Timing open in the first column, Targeting shut in the second.
		UI.State().open = { ["when.timing"] = true }
		ns.RefreshOptionsDisplay()
		local timing, targeting = UI.Where("advanced.retryCooldown"), UI.Where("advanced.restoreTarget")
		if not (timing and targeting and timing.sec.column == 1 and targeting.sec.column == 2) then
			fail(scenario, "When to offer's two folds are not side by side in a window 1320 wide")
			return
		end
		local last = 0
		for _, e in ipairs(rows(UI, timing.sec)) do last = math.max(last, e.y + e.h) end
		if not (last > targeting.sec.y + 26 + 30) then
			fail(scenario, "Timing, open, is no taller than Targeting, shut: the scenario proves nothing")
		end
		local total = UI.view.range + UI.view.height
		if total < last + PAD_BOTTOM then
			fail(scenario, ("the page is %s tall and its open fold, in the first column, ends at %s"):format(tostring(total), tostring(last)))
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
		-- Less the sub-divisions bar over the page, as tall as its chips' rows.
		if not near(UI.view.height, 720 - (600 - 522) - (UI.subbar.height or 0), 1) then
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

---------------------------------------------------------------------------
-- the pages, arranged by what the player came to do
---------------------------------------------------------------------------

local INDENT = 16

do
	local scenario = "menu: each buff has a row of its own, with that buff's own switch under it"
	with(scenario, { page = "who", class = "PRIEST" }, function(ns, UI)
		local fort, spirit, shadow = UI.Where("who.offer_fortitude"), UI.Where("who.offer_spirit"), UI.Where("who.offer_shadow")
		local mana = UI.Where("who.relevantOnly")
		if not (fort and spirit and shadow and mana) then fail(scenario, "SKIPPED -- a priest's switches are not placed") return end
		for _, path in ipairs({ "who.offer_fortitude", "who.offer_spirit", "who.offer_shadow", "who.relevantOnly" }) do
			if not UI.RowShown(path) then fail(scenario, path .. " is not drawn on a priest's Who to buff") return end
		end
		if not (fort.e.y < spirit.e.y and spirit.e.y < shadow.e.y) then
			fail(scenario, ("the three buffs are not one under the other: %s, %s, %s"):format(tostring(fort.e.y), tostring(spirit.e.y), tostring(shadow.e.y)))
		end
		if fort.e.x ~= spirit.e.x or spirit.e.x ~= shadow.e.x then fail(scenario, "the three buffs do not start at one edge") end
		-- Only to players with mana: Divine Spirit's, so right under it and a step in.
		if not (mana.e.y > spirit.e.y and mana.e.y < shadow.e.y) then
			fail(scenario, ("Only to players with mana is at %s, not between Divine Spirit (%s) and the buff after it (%s)"):format(
				tostring(mana.e.y), tostring(spirit.e.y), tostring(shadow.e.y)))
		end
		if mana.e.x ~= spirit.e.x + INDENT then
			fail(scenario, ("Only to players with mana starts at %s, not a step in from Divine Spirit (%s)"):format(tostring(mana.e.x), tostring(spirit.e.x)))
		end
	end)
	with(scenario, { page = "who", class = "PALADIN" }, function(ns, UI)
		local wisdom, might, casters, mana = UI.Where("who.offer_wisdom"), UI.Where("who.offer_might"),
			UI.Where("who.skipCasters"), UI.Where("who.relevantOnly")
		if not (wisdom and might and casters and mana) then fail(scenario, "SKIPPED -- a paladin's switches are not placed") return end
		if not (UI.RowShown("who.skipCasters") and UI.RowShown("who.relevantOnly")) then
			fail(scenario, "a paladin's two switches about who a blessing is any use to are not drawn")
			return
		end
		if not (mana.e.y > wisdom.e.y and mana.e.y < might.e.y and mana.e.x == wisdom.e.x + INDENT) then
			fail(scenario, "Only to players with mana is not under a paladin's Blessing of Wisdom")
		end
		if not (casters.e.y > might.e.y and casters.e.x == might.e.x + INDENT) then
			fail(scenario, "Not to mages, warlocks and priests is not under a paladin's Blessing of Might")
		end
	end)
end

do
	local scenario = "menu: a sub-option is not drawn under a switch that is off, and is back with the switch"
	with(scenario, { page = "appearance" }, function(ns, UI)
		local db = ns.db.profile
		db.sound.enabled = false
		ns.RefreshOptionsDisplay()
		if not UI.RowShown("appearance.soundEnabled") then fail(scenario, "SKIPPED -- no Play a sound on Look") return end
		if UI.RowShown("appearance.soundFile") or UI.RowShown("appearance.soundOwedOnly") then
			fail(scenario, "the sound's own choices are drawn under Play a sound while it is off")
		end
		db.sound.enabled = true
		ns.RefreshOptionsDisplay()
		if not (UI.RowShown("appearance.soundFile") and UI.RowShown("appearance.soundOwedOnly")) then
			fail(scenario, "the sound's own choices are not back with Play a sound on")
		else
			local switch, file = UI.Where("appearance.soundEnabled").e, UI.Where("appearance.soundFile").e
			if file.x ~= switch.x + INDENT or not (file.y > switch.y) then fail(scenario, "Sound is not a step in under Play a sound") end
		end
		-- The model decides what a switch governs: the pause before a /thank is
		-- the whisper's too, and stays while the whisper is on.
		ns.OpenOptions("click")
		db.prompt.thankEmote, db.prompt.thankWhisper = false, true
		ns.RefreshOptionsDisplay()
		if UI.RowShown("click.thankEmoteToken") then fail(scenario, "Emote to use is drawn under a /thank that is off") end
		if not UI.RowShown("click.thankDelay") then
			fail(scenario, "the pause is gone with the /thank off, though the whispered thank-you still waits it out")
		end
		db.prompt.thankWhisper = false
		ns.RefreshOptionsDisplay()
		if UI.RowShown("click.thankDelay") then fail(scenario, "the pause is drawn with neither the /thank nor the whisper on") end
		-- A choice under a dropdown under a switch goes with the switch too.
		local magic = UI.Where("who.ownDampenAlone")
		if magic and magic.e.parent and magic.e.parent.parent then
			if magic.e.parent.parent.path ~= "who.self" then
				fail(scenario, "a mage's Dampen Magic choice is under " .. tostring(magic.e.parent.parent.path) .. ", not Myself")
			end
		else
			fail(scenario, "a row two steps in is not under the row one step in above it")
		end
	end)
end

do
	local scenario = "menu: search finds a sub-option under a switch that is off, and opens the switch"
	with(scenario, { page = "appearance" }, function(ns, UI)
		ns.db.profile.sound.enabled = false
		ns.RefreshOptionsDisplay()
		local found
		for _, entry in ipairs(UI.SearchEntries()) do
			if (entry.ref.via or entry.ref.path) == "appearance.soundFile" then found = entry end
		end
		if not found then fail(scenario, "Sound is not searched while Play a sound is off") return end
		if found.ref.path ~= "appearance.soundEnabled" or found.ref.via ~= "appearance.soundFile" then
			fail(scenario, "the result for Sound leads to " .. tostring(found.ref.path) .. ", not to Play a sound")
		end
		local name = ns.WindowBind.Text(UI.Item("appearance.soundEnabled"), "name")
		if found.first ~= name then
			fail(scenario, ("the result does not say to turn %s on first: %s"):format(tostring(name), tostring(found.first)))
		end
		ns.OpenOptions("when")
		local e = UI.Reveal("appearance.soundFile")
		if not (e and e.path == "appearance.soundEnabled") then
			fail(scenario, "asked for Sound, the window showed " .. tostring(e and e.path) .. ", not Play a sound")
		end
		if UI.page ~= "appearance" then fail(scenario, "asked for Sound, the window is on " .. tostring(UI.page)) end
	end)
end

do
	local scenario = "menu: Who to buff asks who before what, and every section has a heading"
	with(scenario, { page = "who", class = "PRIEST" }, function(ns, UI)
		local at = {}
		for i, sec in ipairs(UI.Model("who").sections) do at[sec.key] = i end
		local order = { "who.now", "who.sources", "who.cast", "who.order", "who.group", "who.myself", "who.first" }
		for i = 2, #order do
			local a, b = at[order[i - 1]], at[order[i]]
			if not (a and b) then
				fail(scenario, "Who to buff has no section " .. (a and order[i] or order[i - 1]))
			elseif a > b then
				fail(scenario, order[i] .. " comes before " .. order[i - 1] .. " on Who to buff")
			end
		end
		-- A heading on every section; the one a page opens with may go without.
		for id, page in pairs(ns.WindowLayout.pages) do
			for i, section in ipairs(page.sections) do
				if i > 1 and section.title == nil and section.header == nil then
					fail(scenario, ("%s, section %d (%s) has no heading"):format(id, i, tostring(section.key)))
				end
			end
		end
	end)
end

do
	local scenario = "menu: Look's fine print is folded, its dot lit by a change, and no page is much over three screens"
	with(scenario, { page = "appearance" }, function(ns, UI)
		local byKey = {}
		for _, sec in ipairs(UI.Model("appearance").sections) do byKey[sec.key] = sec end
		for _, key in ipairs({ "appearance.hover", "appearance.window" }) do
			if not (byKey[key] and byKey[key].fold) then fail(scenario, key .. " is not a fold on Look") end
		end
		-- The colours, folded while the picker was one long shelf of cards,
		-- stand open with the chosen look's own settings under the gallery
		-- since the picker has tabs (tests/scenarios/lookpage.lua): the page
		-- is still held to its three screens below.
		if not byKey["appearance.lookOwn"] or byKey["appearance.lookOwn"].fold then
			fail(scenario, "the chosen look's own settings are folded away")
		end
		if not byKey["appearance.queue"] or byKey["appearance.queue"].fold then fail(scenario, "the waiting list is folded away") end
		local hover = byKey["appearance.hover"]
		if hover then
			if UI.FoldChanged(hover) then fail(scenario, "Tooltip's dot is lit on a profile nobody changed") end
			ns.db.profile.prompt.tooltip = "off"
			ns.RefreshOptionsDisplay()
			if not UI.FoldChanged(hover) then fail(scenario, "Tooltip's dot stays dark with the tooltip switched off") end
			ns.db.profile.prompt.tooltip = ns.defaults.profile.prompt.tooltip
		end
		-- The pane's width and height, in Exact position's fold since the
		-- cards' descriptions took the lines they need: fine print beside
		-- Size's scale, the fold's dot lit by a width that was changed.
		local exact = byKey["appearance.exactPos"]
		local where = { UI.Where("appearance.width"), UI.Where("appearance.height") }
		if not (exact and exact.fold and #where == 2 and where[1].sec.key == "appearance.exactPos"
			and where[2].sec.key == "appearance.exactPos") then
			fail(scenario, "Width and Height are not in Exact position's fold")
		else
			ns.RefreshOptionsDisplay()
			if UI.FoldChanged(exact) then fail(scenario, "Exact position's dot is lit on a profile nobody changed") end
			local was = ns.db.profile.prompt.width
			ns.db.profile.prompt.width = was + 40
			ns.RefreshOptionsDisplay()
			if not UI.FoldChanged(exact) then fail(scenario, "Exact position's dot stays dark with the width changed") end
			ns.db.profile.prompt.width = was
			ns.RefreshOptionsDisplay()
		end
		-- The folds as a new profile has them, shut; the usual window.
		UI.State().open = {}
		for _, group in ipairs(ns.WindowLayout.groups) do
			for _, id in ipairs(group) do
				ns.OpenOptions(id)
				if UI.page == id then
					-- The usual window's room for a page, the sub-divisions bar's
					-- share of it included: the page is as long as ever.
					local room = UI.view.height + (UI.subbar.height or 0)
					local screens = (UI.view.range + UI.view.height) / room
					if screens > 3.1 then
						fail(scenario, ("%s is %.1f screens of the usual window with its folds shut"):format(id, screens))
					end
				end
			end
		end
	end)
end

do
	local scenario = "menu: the homes for what is coming are in the layout, titled, and not drawn while empty"
	with(scenario, { page = "who", class = "PRIEST" }, function(ns, UI)
		local homes = { ["who.beyond"] = "who", ["who.asking"] = "who", ["when.battle"] = "when" }
		for key, pageId in pairs(homes) do
			local def
			for _, section in ipairs(ns.WindowLayout.pages[pageId].sections) do
				if section.key == key then def = section end
			end
			if not def then
				fail(scenario, "no section " .. key)
			else
				if def.home ~= true then fail(scenario, key .. " is not marked as a home") end
				if type(def.title) ~= "string" or def.title == "" then fail(scenario, key .. " has no title") end
				if #def.items == 0 then
					ns.OpenOptions(pageId)
					for _, sec in ipairs(UI.Model(pageId).sections) do
						if sec.key == key and (sec.visible or (sec.title and sec.title:IsShown())) then
							fail(scenario, key .. " is drawn with nothing in it")
						end
					end
				end
			end
		end
		-- The others are a comment where the setting belongs.
		local file = io.open(dir .. "/Options/Window/Layout.lua", "r")
		local text = file and file:read("*a") or ""
		if file then file:close() end
		local named = 0
		for line in text:gmatch("[^\n]+") do
			if line:find("-- HOME:", 1, true) then named = named + 1 end
		end
		if named < 6 then fail(scenario, "the layout names " .. named .. " homes in its comments, not the six it has") end
		text = text:lower():gsub("%s*\n%s*%-%-%s*", " ")
		for _, what in ipairs({ "resurrection", "courtesies", "cures", "other manners users", "asking for a buff",
			"battlegrounds and arenas", "companion pets", "group's pets" }) do
			if not text:find(what, 1, true) then fail(scenario, "no home says it is for " .. what) end
		end
	end)
end

---------------------------------------------------------------------------
-- the simple view
---------------------------------------------------------------------------

-- How many controls of the open page are drawn.
local function controlsDrawn(UI)
	local n = 0
	for _, sec in ipairs(drawn(UI)) do
		for _, e in ipairs(rows(UI, sec)) do
			if e.isControl then n = n + 1 end
		end
	end
	return n
end

local function shownRow(row) return row ~= nil and row.frame:IsShown() == true end

do
	local scenario = "menu: a new profile starts on the short list, one from before keeps everything and is offered it once"
	with(scenario, { page = "when", newProfile = true }, function(ns, UI)
		if Mock.sv.profile.menuView ~= "simple" or ns.MenuView() ~= "simple" then
			fail(scenario, "a new profile's view is " .. tostring(Mock.sv.profile.menuView) .. ", not the short list")
		end
		if shownRow(UI.MenuRow("offer")) then fail(scenario, "a new profile is offered the view it is already in") end
		-- The same profile at a later login, from before the view existed: it
		-- has been through the repair, and has no view yet.
		Mock.sv.profile.menuView = nil
		local later = load(scenario)
		if not later then return end
		drive(scenario, later)
		later.Prompt:ExitTest()
		local LUI = later.WindowUI
		if Mock.sv.profile.menuView ~= "offer" then
			fail(scenario, "a profile from before is stamped " .. tostring(Mock.sv.profile.menuView) .. ", not offered the view")
			return
		end
		later.OpenOptions("when")
		if later.MenuView() ~= "offer" then fail(scenario, "the offer reads as " .. tostring(later.MenuView())) end
		-- Everything on screen, and the offer over it with its two buttons.
		if not LUI.RowShown("who.quietTargets") then fail(scenario, "a profile from before lost a row to the short list unasked") end
		for _, slot in ipairs({ "offer", "try", "dismiss" }) do
			if not shownRow(LUI.MenuRow(slot)) then fail(scenario, "the offer's " .. slot .. " is not drawn") end
		end
		local _, note = LUI.MenuRow("offer")
		local first = LUI.Where("when.rightNow")
		if note and first and not (note.y < first.e.y) then fail(scenario, "the offer is not over the page") end
		-- Not now: gone, everything stays, and it does not come back.
		local dismiss = LUI.MenuRow("dismiss")
		if dismiss then dismiss.button:GetScript("OnClick")(dismiss.button, "LeftButton") end
		if Mock.sv.profile.menuView ~= "full" then
			fail(scenario, "Not now left the view at " .. tostring(Mock.sv.profile.menuView))
		end
		if shownRow(LUI.MenuRow("offer")) or shownRow(LUI.MenuRow("try")) then fail(scenario, "the offer is still drawn after Not now") end
		if not LUI.RowShown("who.quietTargets") then fail(scenario, "Not now took a row off the page") end
		later.ClampSettings()
		if Mock.sv.profile.menuView ~= "full" then fail(scenario, "the repair offered the view again") end
		-- Try the simple view: the short list.
		Mock.sv.profile.menuView = "offer"
		later.RefreshOptionsDisplay()
		local try = LUI.MenuRow("try")
		if try then try.button:GetScript("OnClick")(try.button, "LeftButton") end
		if Mock.sv.profile.menuView ~= "simple" then
			fail(scenario, "Try the simple view left the view at " .. tostring(Mock.sv.profile.menuView))
		end
		-- A value no version wrote is everything, with no offer.
		Mock.sv.profile.menuView = "tiny"
		later.ClampSettings()
		if Mock.sv.profile.menuView ~= "full" then
			fail(scenario, "a damaged view was left as " .. tostring(Mock.sv.profile.menuView))
		end
	end)
end

do
	local scenario = "menu: the simple view draws each page's short list, says what it leaves out, and Show everything brings it back"
	for _, class in ipairs({ "PRIEST", "WARRIOR" }) do
		with(scenario, { page = "when", class = class }, function(ns, UI)
			if not (UI.side and UI.side.view) then fail(scenario, "no Simple view switch under the search box") return end
			-- Under the search box, with the pages under it (y runs up the screen).
			local _, boxBottom = nil, FT.span(UI.search.box, "y")
			local low, high = FT.span(UI.side.view.frame, "y")
			local _, firstTop = FT.span(UI.side.buttons.general, "y")
			if not shownRow(UI.side.view) or not (low and high and boxBottom and high <= boxBottom) then
				fail(scenario, "the Simple view switch is not drawn under the search box")
			elseif not (firstTop and firstTop <= low) then
				fail(scenario, ("the first page starts at %s, over the Simple view switch, which ends at %s"):format(tostring(firstTop), tostring(low)))
			end
			local full = {}
			for _, group in ipairs(ns.WindowLayout.groups) do
				for _, id in ipairs(group) do
					ns.OpenOptions(id)
					if UI.page == id then full[id] = controlsDrawn(UI) end
				end
			end
			-- The switch, pressed as a player presses it.
			local hit = UI.side.view.hit
			hit:GetScript("OnClick")(hit, "LeftButton")
			if ns.MenuView() ~= "simple" then fail(scenario, "the switch left the view at " .. ns.MenuView()) return end
			local whole = { general = true, profiles = true, diagnostics = true }
			for id, was in pairs(full) do
				ns.OpenOptions(id)
				local now = controlsDrawn(UI)
				local more = shownRow(UI.MenuRow("more"))
				if whole[id] then
					if now ~= was then fail(scenario, ("%s: %s draws %d controls in the simple view and %d in the full"):format(class, id, now, was)) end
					if more then fail(scenario, class .. ": " .. id .. " says it leaves settings out") end
				else
					if now > 15 then fail(scenario, ("%s: the short list of %s is %d controls"):format(class, id, now)) end
					if was > now and now == 0 and not more then
						fail(scenario, class .. ": " .. id .. " is empty in the simple view and does not say why")
					end
					if was > now then
						if not more then
							fail(scenario, class .. ": " .. id .. " does not say what its short list leaves out")
						elseif not (UI.simpleHidden and UI.simpleHidden >= was - now) then
							fail(scenario, ("%s: %s counts %s left out, %d fewer are drawn"):format(class, id, tostring(UI.simpleHidden), was - now))
						end
						if not shownRow(UI.MenuRow("everything")) then fail(scenario, class .. ": no Show everything under " .. id) end
					end
				end
			end
			-- What a short list holds, and what it leaves to the full view.
			ns.OpenOptions("when")
			if not UI.RowShown("when.hideMounted") then fail(scenario, class .. ": Hide the prompt while mounted is off the short list") end
			if UI.RowShown("who.quietTargets") or UI.RowShown("advanced.reciprocateWindow") then
				fail(scenario, class .. ": the fine print of When to offer is on its short list")
			end
			local _, note = UI.MenuRow("more")
			local last = UI.Where("when.hideMounted")
			if note and last and not (note.y > last.e.y) then fail(scenario, class .. ": what is left out is not said under the page") end
			local row = UI.MenuRow("more")
			local said = row and row.text and row.text:GetText() or ""
			if not said:find(tostring(UI.simpleHidden), 1, true) then
				fail(scenario, ("%s: the line under the page does not say %s are left out: %s"):format(class, tostring(UI.simpleHidden), said))
			end
			ns.OpenOptions("general")
			if not UI.RowShown("general.verbose") then fail(scenario, class .. ": Start here lost a row to the simple view") end
			-- Each buff's own switch and each of the player's own buffs.
			if class == "PRIEST" then
				ns.OpenOptions("who")
				if not UI.RowShown("who.offer_spirit") then fail(scenario, "a priest's Divine Spirit is off the short list") end
				if not UI.RowShown("who.own_food") then fail(scenario, "Well Fed is off the short list") end
				if UI.RowShown("who.relevantOnly") then fail(scenario, "Only to players with mana is on the short list") end
			end
			-- Show everything.
			ns.OpenOptions("when")
			local everything = UI.MenuRow("everything")
			if everything then everything.button:GetScript("OnClick")(everything.button, "LeftButton") end
			if ns.MenuView() ~= "full" then fail(scenario, class .. ": Show everything left the view at " .. ns.MenuView()) end
			if controlsDrawn(UI) ~= full.when then fail(scenario, class .. ": Show everything did not bring When to offer back") end
			if shownRow(UI.MenuRow("more")) or shownRow(UI.MenuRow("everything")) then
				fail(scenario, class .. ": the full view still says it leaves settings out")
			end
		end)
	end
end

do
	local scenario = "menu: search finds a setting the simple view leaves out, and opens the full view on it"
	with(scenario, { page = "who", class = "PRIEST" }, function(ns, UI)
		ns.SetMenuView("simple")
		local found = {}
		-- The header's buttons (ref.header) are no control of a page.
		for _, entry in ipairs(UI.SearchEntries()) do
			if not entry.ref.header then found[entry.ref.via or entry.ref.path] = true end
		end
		for _, path in ipairs({ "advanced.retryCooldown", "who.quietTargets", "appearance.fontSize", "who.target" }) do
			if not found[path] then fail(scenario, path .. " is not searched in the simple view") end
		end
		-- One on the short list: shown where it is, the view left alone.
		local e = UI.Reveal("who.owed")
		if not e or ns.MenuView() ~= "simple" then
			fail(scenario, "landing on People who buff me, on the short list, left the view at " .. ns.MenuView())
		end
		-- One the short list leaves out, in a fold of another page.
		if UI.RowShown("advanced.retryCooldown") then fail(scenario, "Timing's slider is on a short list") end
		e = UI.Choose({ path = "advanced.retryCooldown", page = "when" })
		if not (e and e.path == "advanced.retryCooldown") then
			fail(scenario, "the search did not land on the setting it found: " .. tostring(e and e.path))
		end
		if ns.MenuView() ~= "full" then fail(scenario, "the view stayed " .. ns.MenuView() .. " on a setting the short list leaves out") end
		if not UI.RowShown("advanced.retryCooldown") or UI.page ~= "when" then
			fail(scenario, "the setting found is not on screen")
		end
	end)
end

do
	local scenario = "menu: the view is the profile's own, kept through a reload and out of a string of settings"
	with(scenario, { page = "when" }, function(ns, UI)
		ns.SetMenuView("simple")
		if Mock.sv.profile.menuView ~= "simple" then fail(scenario, "the view is not kept in the profile") end
		if (Mock.sv.global or {}).menuView ~= nil then fail(scenario, "the view went into the account's state") end
		local text = ns.ExportSettings and ns.ExportSettings() or ""
		if text == "" then fail(scenario, "SKIPPED -- no string of settings") end
		if text:find("menuView", 1, true) then fail(scenario, "the view travels in a string of settings") end
		local later = load(scenario)
		if not later then return end
		drive(scenario, later)
		if later.MenuView() ~= "simple" then fail(scenario, "a reload read the view as " .. later.MenuView()) end
		-- The old dialog draws everything: the view's own controls are the window's.
		local args = later.optionsTable.args.general.args
		for _, key in ipairs({ "simpleView", "simpleMore", "showEverything", "simpleOffer", "simpleTry", "simpleDismiss" }) do
			if not args[key] then fail(scenario, "the model has no general." .. key) end
		end
		if args.simpleOffer and args.simpleOffer.hidden() ~= true then fail(scenario, "the offer is made to a profile on the short list") end
	end)
end

---------------------------------------------------------------------------
-- the nudge to put Manners on a key
---------------------------------------------------------------------------

local NO_KEY = "Manners has no key yet"

local function saidOf(needle)
	local n = 0
	for _, line in ipairs(Mock.printed or {}) do
		if tostring(line):find(needle, 1, true) then n = n + 1 end
	end
	return n
end

-- A login on the saved file as it stands (no reset in between is a later
-- login of the same character): the addon loaded and enabled, the clock run
-- past the login's own lines and then past the reminder's wait. `before` runs
-- between the two. Answers the addon and how often the reminder was said.
local function login(scenario, before)
	local ns = load(scenario)
	if not ns then return nil end
	ns.addon:OnInitialize()
	ns.addon:OnEnable()
	Mock.printed = {}
	Mock.runTimers(2)
	if before then before(ns) end
	Mock.runTimers(ns.KEY_NUDGE_AFTER + 1)
	return ns, saidOf(NO_KEY)
end

local function sessions(scenario, body)
	Mock.reset()
	FT.install()
	local ok, err = pcall(body)
	FT.uninstall()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

do
	local scenario = "menu: the reminder to set a key is said once a login, on three at most, and never on the first"
	sessions(scenario, function()
		local ns, said = login(scenario)
		if not ns then return end
		if said ~= 0 then fail(scenario, "the first login Manners sees a character, it was told " .. said .. " time(s)") end
		if Mock.sv.char.keyReminders ~= 0 then
			fail(scenario, "the first login was not noted: " .. tostring(Mock.sv.char.keyReminders))
		end
		for n = 1, 3 do
			ns, said = login(scenario)
			if said ~= 1 then fail(scenario, ("login %d after the first: said %d time(s), not once"):format(n, said)) end
			-- Once a session: a fight ending later in it says nothing more.
			ns.addon:PLAYER_REGEN_ENABLED()
			ns.KeyNudge()
			if saidOf(NO_KEY) ~= 1 then fail(scenario, "said again in the same session") end
			local line
			for _, text in ipairs(Mock.printed) do
				if tostring(text):find(NO_KEY, 1, true) then line = tostring(text) end
			end
			if line and not (line:find("/manners", 1, true) and line:find("Start here", 1, true)
				and line:find(("%d of 3"):format(n), 1, true)) then
				fail(scenario, "the line does not say where the key is set, or which of the three it is: " .. line)
			end
		end
		ns, said = login(scenario)
		if said ~= 0 then fail(scenario, "said on a fourth login") end
		if Mock.sv.char.keyReminders ~= 3 then fail(scenario, "the count reads " .. tostring(Mock.sv.char.keyReminders)) end
		local held = ns.Setup.ReminderHeld()
		if held ~= "said three times" then fail(scenario, "after three, the reminder is held by: " .. tostring(held)) end
		-- /manners debug says where it stands.
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		if saidOf("key: none | reminder: said three times (said 3 of 3)") ~= 1 then
			fail(scenario, "/manners debug does not say why the reminder keeps quiet")
		end
	end)
end

do
	local scenario = "menu: the reminder keeps quiet with a key set, a macro made, its switch off, and through a fight"
	local function second(why, before, want)
		sessions(scenario, function()
			if not login(scenario) then return end
			local ns, said = login(scenario, before)
			if said ~= want then fail(scenario, ("%s: said %d time(s), not %d"):format(why, said, want)) end
			return ns
		end)
	end
	second("a key set", function() SetBinding("F9", "CLICK MannersPrompt:LeftButton") end, 0)
	second("its switch off", function(ns) ns.db.profile.keyReminder = false end, 0)
	second("Manners off", function(ns) ns.db.profile.enabled = false end, 0)
	second("nothing in the way", nil, 1)
	-- A fight at the moment it is due: said when the fight ends, once.
	sessions(scenario, function()
		if not login(scenario) then return end
		local ns, said = login(scenario, function() Mock.inCombat = true end)
		if said ~= 0 then fail(scenario, "said in a fight") end
		if Mock.sv.char.keyReminders ~= 0 then fail(scenario, "a login in a fight was counted as told") end
		Mock.inCombat = false
		ns.addon:PLAYER_REGEN_ENABLED()
		if saidOf(NO_KEY) ~= 1 then fail(scenario, "not said when the fight ended: " .. saidOf(NO_KEY)) end
	end)
	-- The macro made for an action bar is a key of a kind.
	sessions(scenario, function()
		if not login(scenario) then return end
		local real = rawget(_G, "GetMacroIndexByName")
		GetMacroIndexByName = function() return 3 end
		local ns, said = login(scenario)
		rawset(_G, "GetMacroIndexByName", real)
		if not ns then return end
		if said ~= 0 then fail(scenario, "said with the Manners macro made") end
	end)
end

do
	local scenario = "menu: Start here's second step says No key yet first, then the key, and has the reminder's switch"
	with(scenario, { page = "general" }, function(ns, UI)
		local status, key, switch = UI.Where("general.bindStatus"), UI.Where("general.bindKey"), UI.Where("general.keyReminder")
		if not (status and key and switch) then fail(scenario, "SKIPPED -- the key step is not placed") return end
		for _, path in ipairs({ "general.bindStatus", "general.bindKey", "general.keyReminder" }) do
			if not UI.RowShown(path) then fail(scenario, path .. " is not drawn on Start here") end
		end
		if not (status.e.y < key.e.y) then fail(scenario, "where the key stands is not said before the box that sets it") end
		if status.sec.key ~= "general.key" or switch.sec.key ~= "general.key" then fail(scenario, "the state or the switch is outside step 2") end
		local text = status.e.row.text:GetText() or ""
		if not text:find("No key yet.", 1, true) then fail(scenario, "with no key, step 2 says: " .. text) end
		if not status.e.row.well then fail(scenario, "the state is not in a block of its own") end
		SetBinding("F9", "CLICK MannersPrompt:LeftButton")
		ns.RefreshOptionsDisplay()
		text = status.e.row.text:GetText() or ""
		if text:find("No key yet.", 1, true) or not text:find("Ready:", 1, true) then
			fail(scenario, "with a key set, step 2 says: " .. text)
		end
		-- The switch is the setting, on until it is turned off, and a taste of
		-- the player's own: not in a string of settings handed to somebody.
		local option = ns.optionsTable.args.general.args.keyReminder
		if ns.defaults.profile.keyReminder ~= true or option.get() ~= true then fail(scenario, "the reminder is not on by default") end
		option.set(nil, false)
		if ns.db.profile.keyReminder ~= false then fail(scenario, "the switch does not turn the reminder off") end
		local shared = ns.ExportSettings and ns.ExportSettings() or ""
		if shared:find("keyReminder", 1, true) then fail(scenario, "the reminder's switch travels in a string of settings") end
	end)
end

do
	local scenario = "menu: Add a spell of my own is on the short list a new profile starts in"
	with(scenario, { page = "who", newProfile = true }, function(ns, UI)
		if ns.MenuView() ~= "simple" then fail(scenario, "the view is " .. tostring(ns.MenuView())) return end
		local paths = { "who.ownSpellNote", "who.ownSpellAdd", "who.ownSpellSaid", "who.ownBriefNote" }
		for i = 1, 10 do paths[#paths + 1] = "who.ownSpell" .. i end
		for _, path in ipairs(paths) do
			if UI.OffShortList(path) then fail(scenario, path .. " is left out of the short list") end
		end
	end)
end
