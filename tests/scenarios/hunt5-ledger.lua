-- The favour ledger, fifth bug hunt: a Camelot name with a surname in Cyrillic,
-- "today" on the day the clocks change, a font the client cannot load, buffs
-- given because somebody asked, and today's favours on a day busier than the
-- list is long.
--
-- Every scenario name starts with "hunt5 ledger:" so the mutations in
-- tests/mutations/hunt5-ledger.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load

-- A clean ledger, after the lifecycle has run, as tests/scenarios/ledger.lua
-- starts each of its own.
local function fresh(ns)
	ns.db.char.ledger = nil
	ns.Ledger.Load()
	return ns.db.char.ledger
end

local function rowsFor(s, name, kind)
	local out = {}
	for _, e in ipairs(s and s.entries or {}) do
		if e.name == name and (kind == nil or e.kind == kind) then out[#out + 1] = e end
	end
	return out
end

local function guarded(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- The addon loaded again over the same saved variables, as a reload does.
local function reloaded(scenario)
	local again = load(scenario)
	if again and pcall(function() again.addon:OnInitialize() end) then return again end
	fail(scenario, "SKIPPED -- the addon did not load a second time")
	return nil
end

-- ------------------------------------------------------------------ surname
-- A Camelot name is a first name and a surname, up to twelve letters each, and
-- a Cyrillic letter is two bytes. The ledger refused anything over 48 bytes, so
-- this player's favours were never filed at all.
Mock.reset()
do
	local scenario = "hunt5 ledger: a long Cyrillic name and surname is filed"
	local ns = load(scenario)
	if ns then
		H.freshPrompt(ns, scenario)
		local s = fresh(ns)
		local L = ns.Ledger
		local long = "Александрина Великомучени"
		if #long ~= 49 then fail(scenario, "SKIPPED -- the name is " .. #long .. " bytes, not 49") end
		L.Received({ name = long, key = 1459, class = "MAGE" }, false, false)
		local rows = rowsFor(s, long, "received")
		if #rows ~= 1 then
			fail(scenario, ("a favour from a %d-byte name and surname filed %d rows"):format(#long, #rows))
		end
		-- The longest a name and surname can be: twelve four-byte characters
		-- each and the space between.
		local widest = string.rep("\240\159\152\128", 12) .. " " .. string.rep("\240\159\152\128", 12)
		L.Received({ name = widest, key = 1459 })
		if #rowsFor(s, widest, "received") ~= 1 then
			fail(scenario, ("a %d-byte name and surname was not filed"):format(#widest))
		end
		-- One byte more is not a name.
		local tooLong = widest .. "x"
		L.Received({ name = tooLong, key = 1459 })
		if #rowsFor(s, tooLong) ~= 0 then
			fail(scenario, ("a %d-byte name was filed"):format(#tooLong))
		end
		-- Still refused whatever its length: macro punctuation.
		L.Received({ name = "Bad;Name", key = 1459 })
		if #rowsFor(s, "Bad;Name") ~= 0 then fail(scenario, "a name carrying a ; was filed") end
		guarded(scenario, ns)
	end
end
Mock.reset()

-- ------------------------------------------------------------------ dst
-- Midnight was counted back from the hour on the clock, which is wrong on the
-- day the clocks change: at 04:30 on a spring-forward morning four and a half
-- hours back is 23:00 the night before. Last night's last gift was counted as
-- today's, and the day's key moved at the change, so today's count of gifts
-- started again mid-morning.
Mock.reset()
do
	local scenario = "hunt5 ledger: today starts at midnight on the day the clocks change"
	local realDate, realTime = date, time
	local ns = load(scenario)
	if ns then
		H.freshPrompt(ns, scenario)
		-- Seconds since the epoch of a date read as UTC.
		local function utc(y, m, d, hh, mm, ss)
			y = m <= 2 and y - 1 or y
			local era = math.floor(y / 400)
			local yoe = y - era * 400
			local doy = math.floor((153 * ((m + 9) % 12) + 2) / 5) + d - 1
			local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
			return (era * 146097 + doe - 719468) * 86400 + hh * 3600 + mm * 60 + ss
		end
		-- A zone five hours behind UTC until 02:00 on 8 March 2026, then four.
		local switch = utc(2026, 3, 8, 7, 0, 0)
		local function offset(t) return t >= switch and -4 or -5 end
		date = function(fmt, t)
			if fmt == "*t" then
				t = t or Mock.epoch
				local f = os.date("!*t", t + offset(t) * 3600)
				return { year = f.year, month = f.month, day = f.day, hour = f.hour,
					min = f.min, sec = f.sec, isdst = t >= switch }
			end
			return realDate(fmt, t)
		end
		time = function(tbl)
			if type(tbl) ~= "table" then return Mock.epoch end
			local wall = utc(tbl.year, tbl.month, tbl.day, tbl.hour or 12, tbl.min or 0, tbl.sec or 0)
			if wall + 4 * 3600 >= switch then return wall + 4 * 3600 end
			return wall + 5 * 3600
		end

		local s = fresh(ns)
		local L = ns.Ledger
		-- 23:30 on the 7th, 01:30 and 04:30 on the 8th, local time.
		Mock.epoch = utc(2026, 3, 8, 4, 30, 0)
		L.Settled("Late Walker", nil, { inGroup = false }, 1459)
		Mock.epoch = utc(2026, 3, 8, 6, 30, 0)
		L.Settled("Early Walker", nil, { inGroup = false }, 1459)
		local before = s.today and s.today.day
		Mock.epoch = utc(2026, 3, 8, 8, 30, 0)
		L.Settled("Morning Walker", nil, { inGroup = false }, 1459)
		local after = s.today and s.today.day
		local midnight = utc(2026, 3, 8, 5, 0, 0)
		if before ~= midnight or after ~= midnight then
			fail(scenario, ("today began at %s at 01:30 and at %s at 04:30; wanted %d, midnight EST")
				:format(tostring(before and before - midnight), tostring(after and after - midnight), 0))
		end
		local sum = L.Summary()
		if sum.given ~= 2 then
			fail(scenario, ("two gifts since midnight, one before it, read as %d today"):format(sum.given))
		end
		-- A refusal of the first gift of the day still finds it in today's count.
		local clock = GetTime()
		L.Settled("Refused Walker", nil, { inGroup = false }, 1459)
		L.Refused("Refused Walker", clock)
		if not (s.today and s.today.given == 2) then
			fail(scenario, "a refused gift left today's count at " .. tostring(s.today and s.today.given))
		end

		-- And the clocks going back: at 04:30 on 1 November, the day began at
		-- midnight EDT, five hours earlier.
		switch = utc(2026, 11, 1, 6, 0, 0)
		offset = function(t) return t >= switch and -5 or -4 end
		time = function(tbl)
			if type(tbl) ~= "table" then return Mock.epoch end
			local wall = utc(tbl.year, tbl.month, tbl.day, tbl.hour or 12, tbl.min or 0, tbl.sec or 0)
			if wall + 4 * 3600 < switch then return wall + 4 * 3600 end
			return wall + 5 * 3600
		end
		fresh(ns)
		s = ns.db.char.ledger
		Mock.epoch = utc(2026, 11, 1, 3, 30, 0)
		L.Settled("Night Walker", nil, { inGroup = false }, 1459)
		Mock.epoch = utc(2026, 11, 1, 9, 30, 0)
		L.Settled("Dawn Walker", nil, { inGroup = false }, 1459)
		if not (s.today and s.today.day == utc(2026, 11, 1, 4, 0, 0) and s.today.given == 1)
			or L.Summary().given ~= 1 then
			fail(scenario, ("on the day the clocks go back, today began %s after midnight and"
				.. " counts %s gifts"):format(tostring(s.today and s.today.day - utc(2026, 11, 1, 4, 0, 0)),
				tostring(s.today and s.today.given)))
		end
		guarded(scenario, ns)
	end
	date, time = realDate, realTime
end
Mock.reset()

-- ------------------------------------------------------------------ font
-- The prompt's font is the ledger's too. A font the client has a name for but
-- cannot load leaves a font string with no font, and the first SetText on it
-- throws: the window was left half built and every later open failed on it.
-- Twice: once with SetFont saying it failed, and once with it answering as if
-- it had worked, when only GetFont tells.
for _, claims in ipairs({ false, true }) do
	Mock.reset()
	local scenario = "hunt5 ledger: a font that will not load does not break the window"
	local realCreate = CreateFrame
	local ns = load(scenario)
	if ns then
		H.freshPrompt(ns, scenario)
		fresh(ns)
		local BROKEN = "Interface\\AddOns\\Gone\\gone.ttf"
		-- Font strings as the client has them: a file it cannot load is
		-- refused, and text on a string with no font throws.
		CreateFrame = function(...)
			local f = realCreate(...)
			local make = f.CreateFontString
			f.CreateFontString = function(self, ...)
				local fs = make(self, ...)
				fs.SetFont = function(me, path, size, flags)
					if path == BROKEN or type(path) ~= "string" then
						me._font = nil
						return claims
					end
					me._font = { path = path, size = size, flags = flags }
					return true
				end
				fs.GetFont = function(me)
					if not me._font then return nil end
					return me._font.path, me._font.size, me._font.flags
				end
				fs.SetText = function(me, text)
					if not me._font then error("Font not set") end
					me._text = text
					return me
				end
				return fs
			end
			return f
		end
		local LSM = LibStub("LibSharedMedia-3.0")
		LSM:Register("font", "Gone", BROKEN)
		ns.db.profile.prompt.font = "Gone"
		ns.Ledger.Received({ name = "Petra Stonewell", key = 1459 })
		local how = claims and "SetFont claiming success" or "SetFont refusing"

		for i = 1, 2 do
			local ok, err = pcall(ns.Ledger.Show)
			if not ok then
				fail(scenario, ("%s, opening the ledger (%d) threw: %s"):format(how, i, tostring(err)))
			end
			ns.Ledger.Hide()
		end
		local window = ns.Ledger.Window()
		if not (window and window.tabs and #window.tabs == 3) then
			fail(scenario, how .. ", the window has no tabs")
		elseif not (window.rows and window.rows[1] and window.rows[1].name:GetFont() == STANDARD_TEXT_FONT) then
			fail(scenario, how .. ", a row's name is not in the game's own font: "
				.. tostring(window.rows and window.rows[1] and window.rows[1].name:GetFont()))
		end
		if ns.db.profile.prompt.font ~= "Gone" then
			fail(scenario, "the saved font was changed to " .. tostring(ns.db.profile.prompt.font))
		end
		guarded(scenario, ns)
	end
	CreateFrame = realCreate
end
Mock.reset()

-- ------------------------------------------------------------------ asked
-- A buff somebody asked for in chat was filed as one given unprompted, so ten
-- answered requests read "You gave 10 buffs unprompted today". They stay in the
-- list, marked, and are left out of that count.
Mock.reset()
do
	local scenario = "hunt5 ledger: a buff somebody asked for is not unprompted"
	local ns = load(scenario)
	if ns then
		H.freshPrompt(ns, scenario)
		local s = fresh(ns)
		local L, T = ns.Ledger, ns.Ledger.TEXT
		for _ = 1, 3 do
			L.Settled("Anna Aim", nil, { inGroup = false, reason = "asked" }, 1459)
			Mock.advance(5)
		end
		L.Settled("Bert Beside", nil, { inGroup = false }, 1459)
		local sum = L.Summary()
		if sum.given ~= 1 then
			fail(scenario, ("three buffs asked for and one not read as %d unprompted"):format(sum.given))
		end
		if not (s.today and s.today.given == 1) then
			fail(scenario, "today's count of gifts reads " .. tostring(s.today and s.today.given))
		end
		if #L.Entries("given") ~= 4 then
			fail(scenario, ("the Given tab lists %d of four buffs given"):format(#L.Entries("given")))
		end
		ns.addon:HandleSlash("ledger")
		local window = L.Window()
		local sub = window and window.subline:GetText() or ""
		if not sub:find(T.GAVE_ONE, 1, true) then
			fail(scenario, "the line under the headline reads: " .. sub)
		end
		-- The row says why it was given.
		local row
		for _, r in ipairs(window and window.rows or {}) do
			if r.entry and r.entry.name == "Anna Aim" then row = r break end
		end
		if row then
			Mock.tooltip = {}
			row.scripts.OnEnter(row)
			local said = table.concat(Mock.tooltip, "\n")
			if not said:find("They asked for it in chat.", 1, true) then
				fail(scenario, "an asked-for buff's tooltip reads: " .. said)
			end
		else
			fail(scenario, "SKIPPED -- no row for Anna on screen")
		end
		-- The game refusing one of them takes nothing off today's count,
		-- which never had it.
		local clock = GetTime()
		L.Settled("Anna Aim", nil, { inGroup = false, reason = "asked" }, 1459)
		L.Refused("Anna Aim", clock)
		if not (s.today and s.today.given == 1) then
			fail(scenario, "a refused asked-for buff left today's count at "
				.. tostring(s.today and s.today.given))
		end

		-- Kept across a reload; a mark that is not true is dropped.
		rowsFor(s, "Bert Beside", "given")[1].asked = "yes"
		local again = reloaded(scenario)
		if again then
			local s2 = again.db.char.ledger
			local anna, bert = rowsFor(s2, "Anna Aim", "given"), rowsFor(s2, "Bert Beside", "given")
			local marked = 0
			for _, e in ipairs(anna) do if e.asked == true then marked = marked + 1 end end
			if #anna ~= 3 or marked ~= 3 then
				fail(scenario, ("after a reload %d of Anna's %d rows are marked asked"):format(marked, #anna))
			end
			if not bert[1] or bert[1].asked ~= nil then
				fail(scenario, "a damaged asked mark survived the reload: " .. tostring(bert[1] and bert[1].asked))
			end
			if again.Ledger.Summary().given ~= 1 then
				fail(scenario, "after a reload the unprompted count reads " .. again.Ledger.Summary().given)
			end
			guarded(scenario, again)
		end
		guarded(scenario, ns)
	end
end
Mock.reset()

-- ------------------------------------------------------------------ busy
-- The list keeps two hundred rows, and today's favours were counted off it: on
-- a busy day this morning's fell off the end and the headline read "Returned
-- 135 of 135" after 150. The day's counts are kept apart from the list, like
-- the count of gifts already was.
Mock.reset()
do
	local scenario = "hunt5 ledger: today's favours are counted past the list's end"
	local realDate, realTime = date, time
	local ns = load(scenario)
	if ns then
		H.freshPrompt(ns, scenario)
		-- This computer's own clock and zone, from nine in the morning.
		date = os.date
		time = function(tbl)
			if type(tbl) == "table" then return os.time(tbl) end
			return Mock.epoch
		end
		Mock.epoch = os.time({ year = 2026, month = 9, day = 24, hour = 9, min = 0, sec = 0 })
		local s = fresh(ns)
		local L, T = ns.Ledger, ns.Ledger.TEXT
		local gifts = 0
		for i = 1, 150 do
			local name = ("Friend %d"):format(i)
			L.Received({ name = name, key = 1459 })
			Mock.advance(40)
			L.Settled(name, { at = GetTime() }, {}, 1459)
			Mock.advance(40)
			if i % 2 == 0 or i > 140 then
				L.Settled(("Walker %d"):format(i), nil, { inGroup = false }, 1459)
				gifts = gifts + 1
				Mock.advance(40)
			end
		end
		local function check(summary, when)
			if summary.received ~= 150 or summary.returned ~= 150 or summary.given ~= gifts then
				fail(scenario, ("%s today reads received %d, returned %d, given %d; wanted 150, 150, %d")
					:format(when, summary.received, summary.returned, summary.given, gifts))
			end
		end
		check(L.Summary(), "after a busy day")
		local headline = T.TODAY_MANY:format(150, 150)
		if L.Headline() ~= headline then fail(scenario, "the headline reads " .. L.Headline()) end

		-- A favour nothing you cast returns, too.
		for i = 1, 3 do L.Received({ name = ("Warrior %d"):format(i), key = 6673 }, true) Mock.advance(20) end
		if L.Summary().useless ~= 3 then
			fail(scenario, "three favours nothing could return read as " .. L.Summary().useless)
		end

		-- A reload keeps the day's counts; a damaged one reads as nothing, not
		-- as whatever it says.
		local again = reloaded(scenario)
		if again then
			check(again.Ledger.Summary(), "after a reload")
			if again.Ledger.Summary().useless ~= 3 then
				fail(scenario, "after a reload the useless count reads " .. again.Ledger.Summary().useless)
			end
			guarded(scenario, again)
		end
		s = ns.db.char.ledger
		s.today.received, s.today.returned, s.today.useless = -4, 1.5, "lots"
		local third = reloaded(scenario)
		if third then
			local t = third.db.char.ledger.today
			if not t or t.received ~= 0 or t.returned ~= 0 or t.useless ~= 0 or t.given ~= gifts then
				fail(scenario, ("damaged counts came back as received %s, returned %s, useless %s, given %s")
					:format(tostring(t and t.received), tostring(t and t.returned),
					tostring(t and t.useless), tostring(t and t.given)))
			end
			guarded(scenario, third)
		end
	end
	date, time = realDate, realTime
end
Mock.reset()

-- ------------------------------------------------------------------ busy undo
-- The day's counts come back down for a return the game refused, as the list's
-- rows do: a favour returned and refused is still owed, one the ledger made up
-- for the return goes, and one folded into a second buff is counted once.
Mock.reset()
do
	local scenario = "hunt5 ledger: a refused return comes off today's counts"
	local realDate, realTime = date, time
	local ns = load(scenario)
	if ns then
		H.freshPrompt(ns, scenario)
		date = os.date
		time = function(tbl)
			if type(tbl) == "table" then return os.time(tbl) end
			return Mock.epoch
		end
		Mock.epoch = os.time({ year = 2026, month = 9, day = 24, hour = 9, min = 0, sec = 0 })
		local s = fresh(ns)
		local L = ns.Ledger
		local function counts() return s.today and s.today.received, s.today and s.today.returned end
		local function expect(what, r, t)
			local got, back = counts()
			if got ~= r or back ~= t then
				fail(scenario, ("%s: today counts received %s, returned %s; wanted %d, %d")
					:format(what, tostring(got), tostring(back), r, t))
			end
		end

		-- Returned, then refused: still received, no longer returned.
		L.Received({ name = "Ada Owed", key = 1459 })
		Mock.advance(5)
		local clock = GetTime()
		L.Settled("Ada Owed", { at = clock }, {}, 1459)
		expect("returned", 1, 1)
		L.Refused("Ada Owed", clock)
		expect("returned then refused", 1, 0)

		-- A return for a favour the ledger never saw, then refused.
		Mock.advance(5)
		clock = GetTime()
		L.Settled("Ghost Giver", { at = clock }, {}, 1459)
		expect("a return the ledger made a row for", 2, 1)
		L.Refused("Ghost Giver", clock)
		expect("that return refused", 1, 0)

		-- Returned, buffed again, then the return refused: one favour.
		Mock.advance(5)
		L.Received({ name = "Bea Twice", key = 1459 })
		Mock.advance(5)
		clock = GetTime()
		L.Settled("Bea Twice", { at = clock }, {}, 1459)
		Mock.advance(1)
		L.Received({ name = "Bea Twice", key = 1459 })
		expect("Bea returned and buffed again", 3, 1)
		L.Refused("Bea Twice", clock)
		expect("Bea's return refused", 2, 0)

		-- Clear takes the day's counts with the list, as its tooltip says.
		L.Clear()
		if s.today ~= nil then fail(scenario, "Clear kept today's counts") end
		guarded(scenario, ns)
	end
	date, time = realDate, realTime
end
Mock.reset()
