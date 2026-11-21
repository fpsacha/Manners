-- How long a right-click skips is on Who to skip, under After a right-click,
-- and its two boxes read seconds and minutes ("12 s", "5 min", "1 h 30 min")
-- and take a typed unit ("5m", "1h"). Who to skip's reset puts them back
-- and rescans; When to offer's leaves them.
--
-- Called by scenarios.lua with the addon directory and its helpers.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- One session on `page` as `class`, everything put back.
local function with(scenario, class, page, body)
	Mock.reset()
	Mock.class = class or "MAGE"
	Mock.knownSpells = setmetatable({}, { __index = function() return true end })
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		drive(scenario, ns)
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.Prompt:ExitTest()
		ns.OpenOptions(page)
		ns.Prompt:ExitTest()
		body(ns, ns.WindowUI)
		ns.Prompt:ExitTest()
		noErrors(scenario, ns)
		ns.CloseOptions()
		ns.Prompt:ExitTest()
	end)
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- A value typed into a slider's box and left.
local function type_(row, text)
	row.box:SetFocus()
	row.box:SetText(text)
	row.box:ClearFocus()
end

-- ------------------------------------------------------------------ 1
local scenario = "menupass-skip: the right-click lengths lead Who to skip, open"
for _, class in ipairs({ "MAGE", "HUNTER" }) do
	with(scenario, class, "skip", function(ns, UI)
		local layout = ns.WindowLayout
		local spot = {}
		for i, sec in ipairs(layout.pages.skip.sections) do
			for _, item in ipairs(sec.items or {}) do
				local path = type(item) == "table" and item[1] or item
				spot[path] = { index = i, sec = sec }
			end
			spot[sec.key] = { index = i, sec = sec }
		end
		for _, path in ipairs({ "advanced.skipSeconds", "advanced.ownSkipMinutes" }) do
			local at = spot[path]
			if not at then
				fail(scenario, class .. ": " .. path .. " is not on Who to skip")
			else
				if at.sec.key ~= "skip.rightClick" then fail(scenario, class .. ": " .. path .. " is in " .. tostring(at.sec.key)) end
				if at.sec.fold then fail(scenario, class .. ": " .. path .. " is in a fold") end
				if not (spot["skip.lead"] and at.index < spot["skip.lead"].index) then
					fail(scenario, class .. ": After a right-click does not come before Players to skip")
				end
			end
			if not layout.simple.items[path] then fail(scenario, path .. " is not on the simple list") end
			if UI.PageOf(path) ~= "skip" then fail(scenario, class .. ": " .. path .. " is on the page " .. tostring(UI.PageOf(path))) end
			if not UI.RowShown(path) then fail(scenario, class .. ": " .. path .. " is not drawn on Who to skip") end
		end
	end)
end

-- ------------------------------------------------------------------ 2
scenario = "menupass-skip: the box reads seconds and minutes"
with(scenario, "MAGE", "skip", function(ns, UI)
	local secs, mins = UI.RowFor("advanced.skipSeconds"), UI.RowFor("advanced.ownSkipMinutes")
	if not (secs and secs.box and mins and mins.box) then
		fail(scenario, "no slider rows for the two lengths")
		return
	end
	local timing = ns.db.profile.timing
	local function reads(row, field, value, want)
		timing[field] = value
		UI.Refresh()
		if row.box:GetText() ~= want then
			fail(scenario, ("%s at %s reads %q, not %q"):format(field, tostring(value), tostring(row.box:GetText()), want))
		end
	end
	reads(secs, "skipSeconds", 12, "12 s")
	reads(secs, "skipSeconds", 90, "1 min 30 s")
	reads(secs, "skipSeconds", 300, "5 min")
	reads(secs, "skipSeconds", 1800, "30 min")
	if secs.low:GetText() ~= "3 s" or secs.high:GetText() ~= "30 min" then
		fail(scenario, ("the ends read %q and %q"):format(tostring(secs.low:GetText()), tostring(secs.high:GetText())))
	end
	reads(mins, "ownSkipMinutes", 0, "Same as above")
	reads(mins, "ownSkipMinutes", 90, "1 h 30 min")
	reads(mins, "ownSkipMinutes", 15, "15 min")
	reads(mins, "ownSkipMinutes", 120, "2 h")
end)

-- ------------------------------------------------------------------ 3
scenario = "menupass-skip: a length typed with a unit is kept in the setting's own"
with(scenario, "MAGE", "skip", function(ns, UI)
	local secs, mins = UI.RowFor("advanced.skipSeconds"), UI.RowFor("advanced.ownSkipMinutes")
	if not (secs and secs.box and mins and mins.box) then
		fail(scenario, "no slider rows for the two lengths")
		return
	end
	local timing = ns.db.profile.timing
	local function typed(row, field, text, want)
		timing[field] = (field == "skipSeconds") and 12 or 7
		UI.Refresh()
		type_(row, text)
		if timing[field] ~= want then
			fail(scenario, ("%q typed into %s gave %s, not %s"):format(text, field, tostring(timing[field]), tostring(want)))
		end
	end
	typed(secs, "skipSeconds", "5m", 300)
	typed(secs, "skipSeconds", "45", 45)
	typed(secs, "skipSeconds", "1h", 1800)
	typed(secs, "skipSeconds", "2 Min.", 120)
	typed(secs, "skipSeconds", "1m30", 90)
	typed(mins, "ownSkipMinutes", "2h", 120)
	typed(mins, "ownSkipMinutes", "1h30", 90)
	typed(mins, "ownSkipMinutes", "20", 20)
end)

-- ------------------------------------------------------------------ 4
scenario = "menupass-skip: search finds the right-click length"
with(scenario, "MAGE", "who", function(ns, UI)
	local function rank(query, n)
		local found = ns.WindowSearch.Find(query, UI.SearchEntries(), 8)
		for i = 1, math.min(n, #found) do
			local ref = found[i].ref or {}
			local path = ref.via or ref.path
			if path == "advanced.skipSeconds" or path == "advanced.ownSkipMinutes" then return end
		end
		local seen = {}
		for i, e in ipairs(found) do seen[i] = tostring((e.ref or {}).via or (e.ref or {}).path) end
		fail(scenario, ("%q: neither length is in the top %d (found %s)"):format(query, n, table.concat(seen, ", ")))
	end
	rank("longer", 3)
	rank("right click", 3)
	rank("skip", 8)
end)

-- ------------------------------------------------------------------ 5
scenario = "menupass-skip: Who to skip's reset puts the lengths back and rescans, When to offer's leaves them"
with(scenario, "MAGE", "skip", function(ns, UI)
	local Page = ns.OptionsPage
	local timing, defaults = ns.db.profile.timing, ns.defaults.profile.timing
	local scans = 0
	local real = ns.addon.StartScanner
	ns.addon.StartScanner = function(...) scans = scans + 1 return real(...) end
	local function press(pageId)
		local ok, answer = pcall(Page.ResetPage, pageId)
		if not ok or answer ~= true then fail(scenario, pageId .. " reset did not run: " .. tostring(answer)) end
	end
	timing.skipSeconds, timing.ownSkipMinutes = 600, 45
	press("when")
	if timing.skipSeconds ~= 600 or timing.ownSkipMinutes ~= 45 then
		fail(scenario, "When to offer's reset put the right-click lengths back")
	end
	press("skip")
	ns.addon.StartScanner = real
	if timing.skipSeconds ~= defaults.skipSeconds then fail(scenario, "Who to skip's reset left skipSeconds at " .. tostring(timing.skipSeconds)) end
	if timing.ownSkipMinutes ~= defaults.ownSkipMinutes then fail(scenario, "Who to skip's reset left ownSkipMinutes at " .. tostring(timing.ownSkipMinutes)) end
	if scans == 0 then fail(scenario, "Who to skip's reset did not rescan") end
end)
