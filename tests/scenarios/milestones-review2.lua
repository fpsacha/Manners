-- The second review of milestones (Milestones.lua, with its hooks in
-- Ledger.lua, Resurrect.lua and Core.lua): what a milestone counts and when.
--
-- A resurrection is nobody buffed; a raid is "everybody" by who was reached,
-- each person once and never yourself; a stranger who asked is not one buffed
-- unprompted; a settle cut off by a reload is counted at the next login; a
-- profile changed is the switch turned; a favour returned counts once its
-- refusal can no longer come; and an earned row keeps the room for its line.
--
-- Every name below starts "milestones-review2:".

local dir, H = ...
local fail, load = H.fail, H.load

local PETRA = "Petra Stonewell"

-- A clean ledger and no milestones yet, and nothing said so far.
local function begin(ns, scenario)
	H.freshPrompt(ns, scenario)
	ns.db.char.ledger = nil
	ns.db.char.milestones = nil
	ns.Ledger.Load()
	Mock.printed = {}
	return ns.Milestones
end

local function earned(ns, id)
	local st = ns.db.char.milestones
	return st and st.earned and st.earned[id]
end

local function count(ns, key)
	local st = ns.db.char.milestones
	return st and st.n and st.n[key] or 0
end

-- The lines in chat that say a milestone was earned.
local function said(ns)
	local out = {}
	local prefix = ns.Milestones.TEXT.EARNED:match("^([^|%%]*)")
	for _, line in ipairs(Mock.printed or {}) do
		if tostring(line):find(prefix, 1, true) then out[#out + 1] = tostring(line) end
	end
	return out
end

-- Something given, as Core and Resurrect.lua file it.
local function give(ns, name, inGroup, spell, extra)
	local pending = { inGroup = inGroup == true, class = "WARRIOR" }
	for k, v in pairs(extra or {}) do pending[k] = v end
	ns.Ledger.Settled(name, nil, pending, spell or 1459)
end

-- One favour from `name` and one returned `wait` seconds later; the settle's
-- clock is handed back, which is what a refusal names it by.
local function returnOne(ns, name, wait)
	ns.Ledger.Received({ name = name, class = "PRIEST", key = 1459 })
	Mock.advance(wait)
	local clock = GetTime()
	ns.Ledger.Settled(name, { at = clock - wait }, { buffKey = "intellect" }, 1459)
	return clock
end

local function settle(ns)
	Mock.runTimers(ns.Ledger.PROMOTE_SECONDS + 1)
end

local function guarded(ns, scenario)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

local function raider(i) return "Raider " .. string.char(64 + i) .. "a" end

-- ------------------------------------------------------------- review2 1
-- A resurrection goes in the ledger as something given, and a mass one says
-- how many it reached. It is nobody buffed: a raid brought back after a wipe
-- is not a raid given one of your buffs.
Mock.reset()
do
	local scenario = "milestones-review2: a raid brought back to life was not given a buff"
	local ns = load(scenario)
	if ns then
		begin(ns, scenario)
		Mock.raid = { size = 10 }
		local R = ns.Resurrect
		if not (R and R.KEY and R.MASS_KEY and R.IsSpell and R.IsSpell(83968) and R.IsSpell(2006) and not R.IsSpell(1459)) then
			fail(scenario, "SKIPPED -- Resurrect.lua does not tell a resurrection from a buff")
		else
			-- One cast for everybody dead: the other nine of a raid of ten.
			local others = {}
			for i = 2, 9 do others[#others + 1] = raider(i) end
			give(ns, raider(1), true, 83968, { buffKey = R.MASS_KEY, group = { spell = 83968, members = others } })
			settle(ns)
			local row = ns.Ledger.Entries("given")[1]
			if not (row and row.spell == 83968 and row.to == "group") then
				fail(scenario, "SKIPPED -- the mass resurrection is not in the ledger as given to the group")
			end
			if count(ns, "raid") ~= 0 or earned(ns, "raid") then
				fail(scenario, "a mass resurrection of the raid earned \"everybody in your raid\"")
			end
			-- And nine of them brought back one by one.
			Mock.advance(1200)
			for i = 1, 9 do give(ns, raider(i), true, 2006, { buffKey = R.KEY }) end
			settle(ns)
			if count(ns, "raid") ~= 0 or earned(ns, "raid") then
				fail(scenario, "nine resurrections in a raid of ten earned \"everybody in your raid\"")
			end
			-- Nine buffs do.
			Mock.advance(1200)
			for i = 1, 9 do give(ns, raider(i), true) end
			settle(ns)
			if not earned(ns, "raid") then fail(scenario, "SKIPPED -- nine raid members buffed earned nothing") end
		end
		Mock.raid = nil
		guarded(ns, scenario)
	end
end

-- ------------------------------------------------------------- review2 2
-- "Everybody" is who was reached. The same party buffed again under another
-- anchor is the same five people, and you are not somebody you gave it to.
Mock.reset()
do
	local scenario = "milestones-review2: a raid is everybody by name, each once and never yourself"
	local ns = load(scenario)
	if ns then
		begin(ns, scenario)
		local me = ns.UnitFullName("player")
		if type(me) ~= "string" or not ns.IsPlayerName(me) then
			fail(scenario, "SKIPPED -- the player has no name")
		else
			-- One party of a raid of ten, three times over: anchored on each of
			-- three of its members in turn, yourself among the rest.
			Mock.raid = { size = 10 }
			local party = { raider(1), raider(2), raider(3), raider(4) }
			for anchor = 1, 3 do
				local members = { me }
				for i, name in ipairs(party) do
					if i ~= anchor then members[#members + 1] = name end
				end
				give(ns, party[anchor], true, 21562, { group = { spell = 21562, members = members } })
				settle(ns)
				Mock.advance(60)
			end
			if count(ns, "raid") ~= 0 or earned(ns, "raid") then
				fail(scenario, "one party buffed three times was the whole raid of ten")
			end
			-- A raid of eleven: your own party and another, the eleventh left out.
			ns.db.char.milestones.n.raid = 0
			ns.db.char.milestones.earned.raid = nil
			Mock.advance(1200)
			Mock.raid = { size = 11 }
			give(ns, raider(1), true, 21562, { group = { spell = 21562, members = { raider(2), raider(3), raider(4), me } } })
			give(ns, raider(5), true, 21562, { group = { spell = 21562,
				members = { raider(6), raider(7), raider(8), raider(9) } } })
			settle(ns)
			if count(ns, "raid") ~= 0 or earned(ns, "raid") then
				fail(scenario, "nine of the ten others in a raid of eleven were everybody, yourself counted")
			end
			-- The eleventh, and it is.
			give(ns, raider(10), true, 21562)
			settle(ns)
			if not earned(ns, "raid") then fail(scenario, "all ten others of a raid of eleven buffed earned nothing") end
		end
		Mock.raid = nil
		guarded(ns, scenario)
	end
end

-- ------------------------------------------------------------- review2 3
-- "Buff a hundred strangers unprompted": one who asked in chat was prompted,
-- and one brought back to life was not buffed. Neither is counted when it
-- happens, and neither is read out of the ledger's past.
Mock.reset()
do
	local scenario = "milestones-review2: a stranger who asked or was brought back is not one buffed unprompted"
	local ns = load(scenario)
	if ns then
		begin(ns, scenario)
		local R = ns.Resurrect
		for i = 1, 3 do give(ns, "Asker " .. string.char(64 + i) .. "x", false, 1459, { reason = "asked" }) end
		settle(ns)
		if count(ns, "strangers") ~= 0 then
			fail(scenario, ("three strangers who asked count %d towards the hundred"):format(count(ns, "strangers")))
		end
		if count(ns, "asked") ~= 3 then fail(scenario, "SKIPPED -- the requests were not counted as answered") end
		for i = 1, 2 do give(ns, "Fallen " .. string.char(64 + i) .. "x", false, 2006, { buffKey = R and R.KEY }) end
		settle(ns)
		if count(ns, "strangers") ~= 0 then
			fail(scenario, ("two strangers brought back count %d towards the hundred"):format(count(ns, "strangers")))
		end
		for i = 1, 4 do give(ns, "Passer " .. string.char(64 + i) .. "x", false) end
		settle(ns)
		if count(ns, "strangers") ~= 4 then
			fail(scenario, ("four strangers buffed unprompted count %d"):format(count(ns, "strangers")))
		end
		-- The same ledger met for the first time: its count of strangers holds
		-- all nine, and four of them were buffed unprompted.
		if ns.Ledger.Summary().totals.strangers ~= 9 then
			fail(scenario, "SKIPPED -- the ledger does not count nine strangers")
		end
		ns.db.char.milestones = nil
		ns.Ledger.Load()
		if count(ns, "strangers") ~= 4 then
			fail(scenario, ("read from the ledger's past, they count %d and not 4"):format(count(ns, "strangers")))
		end
		guarded(ns, scenario)
	end
end

-- ------------------------------------------------------------- review2 4
-- The ledger writes a settle down at the press; milestones count it three
-- seconds later. A reload inside those seconds must not lose it: the next
-- login counts it from the ledger's row, once.
Mock.reset()
do
	local scenario = "milestones-review2: a settle cut off by a reload is counted at the next login"
	local ns = load(scenario)
	if ns then
		begin(ns, scenario)
		ns.db.char.ledger.totals.returned = 99
		ns.db.char.ledger.totals.received = 99
		returnOne(ns, PETRA, 5)
		give(ns, "Corwin Ash", false)
		local refusedAt = GetTime()
		give(ns, "Refused Rolf", false)
		ns.Ledger.Refused("Refused Rolf", refusedAt)
		Mock.advance(1)
		if count(ns, "strangers") ~= 0 or earned(ns, "hundred") then
			fail(scenario, "SKIPPED -- counted before the refusal's wait was over")
		end
		-- /reload: the same saved file, a fresh namespace, and no timer left.
		Mock.timers = {}
		local again = load(scenario)
		if not again then
			fail(scenario, "the second session would not load")
		else
			Mock.printed = {}
			H.drive(scenario, again)
			local st = again.db.char.milestones
			if not st then
				fail(scenario, "the second session has no milestones")
			else
				if st.n.strangers ~= 1 then
					fail(scenario, ("the stranger buffed before the reload counts %d after it"):format(st.n.strangers))
				end
				if not st.classes.PRIEST or st.n.swift ~= 1 or not st.people[PETRA] then
					fail(scenario, "the favour returned before the reload was not counted after it")
				end
				local at = st.earned.hundred
				if not (type(at) == "number" and at > 0) then
					fail(scenario, "the hundredth favour, returned before the reload, is not marked at login: " .. tostring(at))
				end
				local lines = said(again)
				local named = false
				for _, line in ipairs(lines) do
					if line:find(again.Milestones.LIST[7].name, 1, true) then named = true end
				end
				if at and not named then fail(scenario, "the hundredth favour got no line at login") end
				if #st.due ~= 0 then fail(scenario, "what was counted at login is still remembered as waiting") end
				-- And once: another login adds nothing.
				again.Ledger.Load()
				local third = load(scenario)
				if third then
					H.drive(scenario, third)
					local st3 = third.db.char.milestones
					if st3.n.strangers ~= 1 or st3.n.swift ~= 1 then
						fail(scenario, "a second login counted the same settle again")
					end
					guarded(third, scenario)
				end
			end
			guarded(again, scenario)
		end
	end
end

-- ------------------------------------------------------------- review2 5
-- The switch is the profile's, the milestones the character's. What was
-- passed on a profile that had it off is marked quietly when the profile
-- changes to one that has it on, as the switch itself would mark it.
Mock.reset()
do
	local scenario = "milestones-review2: a profile changed to one with milestones on toasts nothing passed while off"
	local ns = load(scenario)
	if ns then
		local M = begin(ns, scenario)
		ns.db.profile.milestones.enabled = false
		M.Switched()
		for i = 1, 3 do
			returnOne(ns, "Guest " .. string.char(64 + i) .. "x", 30)
			settle(ns)
		end
		ns.db.char.ledger.totals.returned = 100
		-- The title a hundred favours hold has been said: this is not about it.
		ns.db.char.ledger.title = ns.Ledger.Rank({ totals = { returned = 101 } }).level
		if earned(ns, "first") or earned(ns, "hundred") then fail(scenario, "SKIPPED -- earned while off") end
		-- The profile is reset, or another chosen: the switch is on again.
		ns.db.profile.milestones.enabled = true
		Mock.printed = {}
		ns.addon:RefreshConfig("OnProfileReset")
		returnOne(ns, PETRA, 30)
		settle(ns)
		for _, id in ipairs({ "first", "hundred" }) do
			local at = earned(ns, id)
			if not (type(at) == "number" and at < 0) then
				fail(scenario, id .. " was passed while off and is not marked as earned before: " .. tostring(at))
			end
		end
		if #said(ns) ~= 0 then
			fail(scenario, ("%d line(s) in chat for what was passed while off: %s"):format(#said(ns), said(ns)[1]))
		end
		local toast = M.ToastFrame()
		if (toast and toast:IsShown()) or M.Waiting() ~= 0 then
			fail(scenario, "a toast for what was passed while off")
		end
		guarded(ns, scenario)
	end
end

-- ------------------------------------------------------------- review2 6
-- The ledger counts a favour returned at the press and takes it back on a
-- refusal. A milestone read from that count waits for the refusal's window of
-- the return itself, not of whatever else happened to come due meanwhile.
Mock.reset()
do
	local scenario = "milestones-review2: a favour returned counts once its own refusal can no longer come"
	local ns = load(scenario)
	if ns then
		local M = begin(ns, scenario)
		local wait = ns.Ledger.PROMOTE_SECONDS
		ns.Ledger.Received({ name = PETRA, class = "PRIEST", key = 1459 })
		-- A stranger buffed; the favour returned just before the stranger's
		-- wait is over; the server refuses the return just after.
		give(ns, "Corwin Ash", false)
		Mock.runTimers(wait - 0.2)
		local clock = GetTime()
		ns.Ledger.Settled(PETRA, { at = clock - 20 }, { buffKey = "intellect" }, 1459)
		Mock.runTimers(0.4)
		if count(ns, "strangers") ~= 1 then fail(scenario, "SKIPPED -- the stranger's wait did not end") end
		if earned(ns, "first") then
			fail(scenario, "the first favour was earned inside its own refusal wait, by another settle coming due")
		end
		-- The tab's count of favours returned waits with it.
		for _, row in ipairs(M.Rows()) do
			if row.id == "hundred" and row.value ~= 0 then
				fail(scenario, ("a favour inside its refusal wait reads %d of 100 on the tab"):format(row.value))
			end
		end
		ns.Ledger.Refused(PETRA, clock)
		settle(ns)
		if earned(ns, "first") or ns.Ledger.Summary().totals.returned ~= 0 then
			fail(scenario, "a refused return earned the first favour")
		end
		-- Another feature's good turn in the same moment: the same.
		Mock.advance(30)
		clock = GetTime()
		ns.Ledger.Settled(PETRA, { at = clock - 50 }, { buffKey = "intellect" }, 1459)
		M.Note("cure")
		if earned(ns, "first") then
			fail(scenario, "the first favour was earned inside its refusal wait, by a cure noted")
		end
		if #said(ns) ~= 0 and said(ns)[1]:find(M.LIST[1].name, 1, true) then
			fail(scenario, "the first favour was said inside its refusal wait")
		end
		-- Left alone, it is earned when the wait is over.
		settle(ns)
		local at = earned(ns, "first")
		if not (type(at) == "number" and at > 0) then
			fail(scenario, "a favour returned and never refused earned nothing: " .. tostring(at))
		end
		guarded(ns, scenario)
	end
end

-- ------------------------------------------------------------- review2 6b
-- The week without a debt is read from the ledger's rows, and a row returned
-- a moment ago may yet go back to owed: the week waits for it too.
Mock.reset()
do
	local scenario = "milestones-review2: a week is not kept by a favour still inside its refusal wait"
	local ns = load(scenario)
	if ns then
		local M = begin(ns, scenario)
		-- The calendar by the mock's clock: a day is 86400 seconds of it.
		local real = date
		date = function(fmt, t)
			if fmt == "%Y%m%d" then return tostring(math.floor((t or time()) / 86400)) end
			if fmt == "%Y-%m-%d" then return "day " .. tostring(math.floor((t or time()) / 86400)) end
			return real(fmt, t)
		end
		local n = 0
		for _ = 1, 4 do
			for _ = 1, 2 do
				n = n + 1
				returnOne(ns, "Weekly " .. string.char(64 + n) .. "z", 30)
				settle(ns)
			end
			Mock.advance(86400)
		end
		returnOne(ns, "Weekly Iz", 30)
		settle(ns)
		if earned(ns, "week") then fail(scenario, "SKIPPED -- nine favours made the week") end
		-- The tenth, and something else evaluated inside its wait.
		local clock = returnOne(ns, "Weekly Jz", 30)
		M.Note("cure")
		if earned(ns, "week") then
			fail(scenario, "the week was kept by a favour the server could still refuse")
		end
		ns.Ledger.Refused("Weekly Jz", clock)
		settle(ns)
		if earned(ns, "week") then fail(scenario, "the week was kept by a refused return") end
		Mock.advance(5)
		ns.Ledger.Settled("Weekly Jz", { at = GetTime() - 40 }, { buffKey = "intellect" }, 1459)
		settle(ns)
		if not earned(ns, "week") then fail(scenario, "ten favours on five days, all returned, earned nothing") end
		date = real
		guarded(ns, scenario)
	end
end

-- ------------------------------------------------------------- review2 7
-- An earned row has a link button beside its one line. The button is small,
-- the same in every language, so the line keeps nearly the room an unearned
-- row gives it; the button's words are in its tooltip.
Mock.reset()
do
	local scenario = "milestones-review2: an earned row keeps the room for its line"
	local ns = load(scenario)
	if ns then
		local M = begin(ns, scenario)
		returnOne(ns, PETRA, 30)
		settle(ns)
		ns.Ledger.Show()
		local window = ns.Ledger.Window()
		for _, t in ipairs(window.tabs) do
			if t.key == "milestones" then t.scripts.OnClick(t) end
		end
		local top, other
		for _, row in ipairs(window.rows) do
			local m = row:IsShown() and row.entry
			if m and m.milestone and m.earnedAt and not top then top = row end
			if m and m.milestone and not m.earnedAt and not m.concealed and not other then other = row end
		end
		if not (top and other and top.link and top.link:IsShown()) then
			fail(scenario, "SKIPPED -- no earned row with a link button and no row under way")
		else
			local width = top.link:GetWidth()
			if not (type(width) == "number" and width <= 24) then
				fail(scenario, ("the link button is %s wide beside the row's line"):format(tostring(width)))
			end
			-- The line's room in a row 328 wide, from where it is anchored: it
			-- starts after the badge (at 40, and 6 on) and ends where its last
			-- BOTTOMRIGHT says. Near a row's with no button at all, the badges
			-- being a few apart.
			local function room(row)
				local right
				for _, point in ipairs(row.detail.points or {}) do
					if point[1] == "BOTTOMRIGHT" then right = point[4] end
				end
				local plate = row.badgePlate:GetWidth()
				if type(right) ~= "number" or type(plate) ~= "number" or plate <= 0 then return nil end
				return 328 + right - (40 + plate + 6)
			end
			local a, b = room(top), room(other)
			if not (a and b) then
				fail(scenario, "SKIPPED -- the line's width cannot be measured")
			elseif a < b - 50 or a < 180 then
				fail(scenario, ("an earned row's line has %d to an unearned row's %d"):format(a, b))
			end
			-- Its words are in its tooltip, since the button no longer has them.
			local tip = tostring(top.link.tip or "")
			if not tip:find(M.TEXT.LINK, 1, true) or not tip:find(M.TEXT.LINK_TIP, 1, true) then
				fail(scenario, "the link button's tooltip does not say what it is: " .. tip)
			end
		end
		guarded(ns, scenario)
	end
end
Mock.reset()
