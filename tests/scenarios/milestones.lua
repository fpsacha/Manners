-- Ledger milestones (Ledger.lua, TITLES): the little titles the favours you
-- return earn you. Where each one starts and what the way to the next says;
-- the one line in chat a new title gets, and never a second; the quiet welcome
-- an old ledger gets for the titles it earned before there were any; Clear
-- keeping them; and the window and the minimap tooltip showing them.
--
-- The announcement is checked through the real path once -- a buff landing,
-- the prompt pressed -- because what matters there is that Core's settle
-- reaches it with chat lines off. The rest is the ledger's own arithmetic and
-- is driven through Ledger's entry points.

local dir, H = ...
local fail, load = H.fail, H.load

local PETRA = "Petra Stonewell"

-- A clean ledger after the lifecycle has run, as tests/scenarios/ledger.lua
-- starts each of its own.
local function fresh(ns)
	ns.db.char.ledger = nil
	ns.Ledger.Load()
	return ns.db.char.ledger
end

-- Every line printed since the last look that announces a title.
local function announcements(ns)
	local out = {}
	local prefix = ns.Ledger.TEXT.EARNED:match("^(.-)|c") or ns.Ledger.TEXT.EARNED
	for _, line in ipairs(Mock.printed or {}) do
		if tostring(line):find(prefix, 1, true) then out[#out + 1] = tostring(line) end
	end
	return out
end

-- The announcement a title gets, as it should read.
local function said(ns, level)
	local t = ns.Ledger.TITLES[level]
	return ns.Ledger.TEXT.EARNED:format(t.name, t.flavour)
end

-- One favour from `name` and one returned, straight through the ledger: what
-- Core tells it when a buff lands and when the prompt repays it. Handed back
-- is the settle's clock, which is what a refusal names it by.
local function returnOne(ns, name)
	ns.Ledger.Received({ name = name, class = "PRIEST", key = 1459 })
	Mock.advance(5)
	local clock = GetTime()
	ns.Ledger.Settled(name, { at = clock - 5 }, { buffKey = "intellect" }, 1459)
	return clock
end

-- The broker tooltip's lines, joined.
local function brokerTooltip()
	if not (Mock.broker and Mock.broker.OnTooltipShow) then return nil end
	local lines = {}
	local tt = { AddLine = function(_, text) lines[#lines + 1] = tostring(text) end }
	local ok, err = pcall(Mock.broker.OnTooltipShow, tt)
	if not ok then return "THREW: " .. tostring(err) end
	return table.concat(lines, "\n")
end

-- ------------------------------------------------------------------ milestones 1
-- Seven titles, each further off than the last, starting at ten favours
-- returned; the way to the next reads "37 of 50 to Courteous", and past the
-- last there is no next to name.
Mock.reset()
do
	local scenario = "milestones: the titles and the way to the next"
	local ns = load(scenario)
	if ns then
		local L, T = ns.Ledger, ns.Ledger.TEXT
		local want = { 10, 25, 50, 100, 250, 500, 1000 }
		if #L.TITLES ~= #want then
			fail(scenario, ("there are %d titles, not %d"):format(#L.TITLES, #want))
		end
		for i, at in ipairs(want) do
			local t = L.TITLES[i]
			if not t or t.at ~= at then
				fail(scenario, ("title %d starts at %s, not %d"):format(i, tostring(t and t.at), at))
			elseif type(t.name) ~= "string" or t.name == "" or type(t.flavour) ~= "string" or t.flavour == "" then
				fail(scenario, ("title %d has no name or no line of flavour"):format(i))
			end
		end
		local function rank(n) return L.Rank({ totals = { returned = n } }) end
		for _, case in ipairs({ { 0, 0 }, { 9, 0 }, { 10, 1 }, { 24, 1 }, { 25, 2 }, { 49, 2 }, { 50, 3 },
			{ 99, 3 }, { 100, 4 }, { 249, 4 }, { 250, 5 }, { 499, 5 }, { 500, 6 }, { 999, 6 },
			{ 1000, 7 }, { 54321, 7 } }) do
			local r = rank(case[1])
			if r.level ~= case[2] then
				fail(scenario, ("%d favours returned hold title %d, not %d"):format(case[1], r.level, case[2]))
			end
		end

		local r = rank(37)
		if not (r.title and r.title.name == L.TITLES[2].name and r.next and r.next.name == L.TITLES[3].name) then
			fail(scenario, "37 favours returned are not between the second title and the third")
		end
		local line = L.RankText({ totals = { returned = 37 } })
		local wantLine = T.BROKER_TITLED:format(L.TITLES[2].name, 37, 50, L.TITLES[3].name)
		if line ~= wantLine then fail(scenario, "37 returned reads: " .. tostring(line)) end
		if not line:find("37 of 50 to " .. L.TITLES[3].name, 1, true) then
			fail(scenario, "the way to the next does not read \"37 of 50 to <title>\": " .. line)
		end

		line = L.RankText({ totals = { returned = 3 } })
		if line ~= T.BROKER_FIRST:format(3, 10, L.TITLES[1].name) then
			fail(scenario, "3 returned, before any title, reads: " .. tostring(line))
		end
		line = L.RankText({ totals = { returned = 1200 } })
		if line ~= T.BROKER_TOP:format(L.TITLES[7].name) then
			fail(scenario, "past the last title reads: " .. tostring(line))
		end
		r = rank(1200)
		if r.next ~= nil then fail(scenario, "past the last title there is still a next one") end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ milestones 2
-- The favour that reaches a title gets one line in chat, through the real
-- path, with chat lines switched off: a title comes a handful of times in a
-- character's life, and the switch is for the lines about every buff.
Mock.reset()
do
	local scenario = "milestones: a new title is said once in chat, chat lines or not"
	local ns = load(scenario)
	if ns then
		H.freshPrompt(ns, scenario)
		local s = fresh(ns)
		s.totals.returned = 9
		ns.db.profile.verbose = false
		H.primeAuras(ns)
		H.favourFrom(ns, "nameplate1", 1459, 4101)
		local entry = ns.owed[PETRA] and H.inQueue(ns)[PETRA]
		if not entry then
			fail(scenario, "SKIPPED -- Petra is not owed and offered, so nothing can be repaid")
		else
			Mock.printed = {}
			H.pressAndSend(ns, entry, 1459)
			if ns.owed[PETRA] or s.totals.returned ~= 10 then
				fail(scenario, "SKIPPED -- the press did not settle the favour (returned "
					.. tostring(s.totals.returned) .. ")")
			else
				local lines = announcements(ns)
				if #lines ~= 1 then
					fail(scenario, ("the tenth favour returned was announced %d times, with chat lines off"):format(#lines))
				elseif lines[1] ~= said(ns, 1) and not lines[1]:find(said(ns, 1), 1, true) then
					fail(scenario, "the announcement reads: " .. lines[1])
				end
				if s.title ~= 1 then
					fail(scenario, "the title announced was not remembered: " .. tostring(s.title))
				end
			end
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ milestones 3
-- A title is said once and never again: not when a late refusal takes back
-- the favour that earned it and the next one earns it again, and not for any
-- favour after. The next title is said when it comes.
Mock.reset()
do
	local scenario = "milestones: a title taken back and earned again is not said twice"
	local ns = load(scenario)
	if ns then
		H.freshPrompt(ns, scenario)
		local s = fresh(ns)
		local L = ns.Ledger
		s.totals.returned = 9
		Mock.printed = {}
		local clock = returnOne(ns, "Anna Aim")
		if #announcements(ns) ~= 1 then
			fail(scenario, "SKIPPED -- the tenth favour was announced " .. #announcements(ns) .. " times")
		else
			L.Refused("Anna Aim", clock)
			if s.totals.returned ~= 9 then
				fail(scenario, "SKIPPED -- the refusal did not take the favour back: " .. tostring(s.totals.returned))
			end
			Mock.printed = {}
			Mock.advance(60)
			returnOne(ns, "Anna Aim")
			returnOne(ns, "Bo Bell")
			if #announcements(ns) ~= 0 then
				fail(scenario, "a title already announced was announced again: " .. announcements(ns)[1])
			end
			-- Up to the edge of the next title and over it.
			s.totals.returned = 24
			Mock.printed = {}
			returnOne(ns, "Cy Cole")
			local lines = announcements(ns)
			if #lines ~= 1 or not lines[1]:find(said(ns, 2), 1, true) then
				fail(scenario, "the twenty-fifth favour did not announce the second title: "
					.. table.concat(lines, " / "))
			end
			Mock.printed = {}
			returnOne(ns, "Di Dale")
			if #announcements(ns) ~= 0 then fail(scenario, "a favour past a title announced it again") end
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ milestones 4
-- A ledger from before titles, with three hundred favours behind it, takes the
-- title it has earned on its first load without a word -- not five
-- announcements at once -- and hears of the next title when it comes.
Mock.reset()
do
	local scenario = "milestones: an old ledger takes its title quietly"
	local ns = load(scenario)
	if ns then
		H.freshPrompt(ns, scenario)
		local L = ns.Ledger
		Mock.printed = {}
		ns.db.char.ledger = { entries = {},
			totals = { received = 340, returned = 300, letGo = 40, group = 12, strangers = 90 } }
		L.Load()
		local s = ns.db.char.ledger
		if #announcements(ns) ~= 0 then
			fail(scenario, "an old ledger's back catalogue was announced: " .. announcements(ns)[1])
		end
		if s.title ~= 5 then
			fail(scenario, "an old ledger at 300 returned was marked " .. tostring(s.title) .. ", not 5")
		end
		if L.Rank().level ~= 5 then fail(scenario, "an old ledger at 300 returned does not hold the fifth title") end
		returnOne(ns, "Anna Aim")
		if #announcements(ns) ~= 0 then
			fail(scenario, "the first favour after the upgrade announced a title already held")
		end
		s.totals.returned = 499
		returnOne(ns, "Bo Bell")
		local lines = announcements(ns)
		if #lines ~= 1 or not lines[1]:find(said(ns, 6), 1, true) then
			fail(scenario, "the five-hundredth favour did not announce the sixth title: " .. table.concat(lines, " / "))
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ milestones 5
-- A mark on disk that is not a whole number is read as none announced beyond
-- what the count earns, quietly; one past the last title is the last title.
-- A mark above the count is kept, because it is what was said.
Mock.reset()
do
	local scenario = "milestones: a damaged mark is repaired quietly"
	local ns = load(scenario)
	if ns then
		H.freshPrompt(ns, scenario)
		local L = ns.Ledger
		for _, case in ipairs({ { "lots", 60, 3 }, { -2, 60, 3 }, { 2.5, 120, 4 }, { 42, 5, 7 },
			{ 6, 5, 6 }, { {}, 0, 0 } }) do
			Mock.printed = {}
			ns.db.char.ledger = { totals = { returned = case[2] }, title = case[1] }
			L.Load()
			local s = ns.db.char.ledger
			if s.title ~= case[3] then
				fail(scenario, ("a mark of %s at %d returned was repaired to %s, not %d"):format(
					tostring(case[1]), case[2], tostring(s.title), case[3]))
			end
			if #announcements(ns) ~= 0 then
				fail(scenario, "repairing a mark announced a title: " .. announcements(ns)[1])
			end
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ milestones 6
-- Clear empties the list and keeps the lifetime counts, and so the title and
-- the mark of what was announced.
Mock.reset()
do
	local scenario = "milestones: Clear keeps the title"
	local ns = load(scenario)
	if ns then
		H.freshPrompt(ns, scenario)
		local s = fresh(ns)
		local L = ns.Ledger
		s.totals.returned = 99
		returnOne(ns, "Anna Aim")
		if s.title ~= 4 then
			fail(scenario, "SKIPPED -- the hundredth favour did not earn the fourth title")
		else
			L.Clear()
			s = ns.db.char.ledger
			if #s.entries ~= 0 then fail(scenario, "SKIPPED -- Clear left rows") end
			if L.Rank().level ~= 4 or s.title ~= 4 then
				fail(scenario, ("after Clear the title is %d and the mark %s"):format(L.Rank().level, tostring(s.title)))
			end
			Mock.printed = {}
			returnOne(ns, "Bo Bell")
			if #announcements(ns) ~= 0 then fail(scenario, "after Clear a title held was announced again") end
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ milestones 7
-- The title is at the top of the window, with the way to the next and a bar
-- filled for it, and hovering it tells its line of flavour; the minimap
-- tooltip carries the same in a line. Before any title the window says there
-- is none yet, and past the last there is no next.
Mock.reset()
do
	local scenario = "milestones: the window and the minimap tooltip show the title"
	local ns = load(scenario)
	if ns then
		H.freshPrompt(ns, scenario)
		local s = fresh(ns)
		local L, T = ns.Ledger, ns.Ledger.TEXT
		s.totals.returned = 36
		returnOne(ns, "Anna Aim")
		ns.addon:HandleSlash("ledger")
		local window = L.Window()
		local rank = window and window.rank
		if not rank then
			fail(scenario, "the ledger window has no title at the top")
		else
			if rank.name:GetText() ~= L.TITLES[2].name then
				fail(scenario, "the window's title reads " .. tostring(rank.name:GetText()))
			end
			local progress = T.RANK_PROGRESS:format(37, 50, L.TITLES[3].name)
			if rank.progress:GetText() ~= progress then
				fail(scenario, "the way to the next reads " .. tostring(rank.progress:GetText()))
			end
			if not rank.fill:IsShown() then fail(scenario, "the bar is empty 12 favours into 25") end
			-- The mock keeps a set width and has no GetWidth; the bar's track is
			-- the window's width less its padding either side.
			local width = rank.fill._width or 0
			local share = width / (360 - 2 * 12)
			if math.abs(share - 12 / 25) > 0.02 then
				fail(scenario, ("the bar is %.2f full, not %.2f"):format(share, 12 / 25))
			end

			Mock.tooltip = {}
			rank.scripts.OnEnter(rank)
			local tip = table.concat(Mock.tooltip or {}, "\n")
			if not tip:find(L.TITLES[2].flavour, 1, true) then
				fail(scenario, "hovering the title does not tell its flavour: " .. tip)
			end
			if not tip:find(T.RANK_TIP_NEXT:format(L.TITLES[3].name, 50), 1, true) then
				fail(scenario, "hovering the title does not say where the next is: " .. tip)
			end

			-- The minimap tooltip, which the ledger fills for the launcher.
			local said = brokerTooltip()
			local line = T.BROKER_TITLED:format(L.TITLES[2].name, 37, 50, L.TITLES[3].name)
			if not said then
				fail(scenario, "SKIPPED -- no launcher to read")
			elseif not said:find(line, 1, true) then
				fail(scenario, "the minimap tooltip does not carry the title: " .. said)
			end

			-- A new favour repaints it: over the edge of the third title.
			s.totals.returned = 49
			returnOne(ns, "Bo Bell")
			if rank.name:GetText() ~= L.TITLES[3].name then
				fail(scenario, "the open window did not move on to the new title: " .. tostring(rank.name:GetText()))
			end

			-- Before any title, and past the last.
			ns.db.char.ledger = nil
			L.Load()
			L.Show()
			if rank.name:GetText() ~= T.UNTITLED then
				fail(scenario, "with nothing returned the title reads " .. tostring(rank.name:GetText()))
			end
			if rank.progress:GetText() ~= T.RANK_PROGRESS:format(0, 10, L.TITLES[1].name) then
				fail(scenario, "with nothing returned the way to the first reads " .. tostring(rank.progress:GetText()))
			end
			if rank.fill:IsShown() then fail(scenario, "the bar shows with nothing returned") end
			ns.db.char.ledger.totals.returned = 1500
			L.Show()
			if rank.name:GetText() ~= L.TITLES[7].name or rank.progress:GetText() ~= T.RANK_TOP then
				fail(scenario, ("past the last title the window reads %s / %s"):format(
					tostring(rank.name:GetText()), tostring(rank.progress:GetText())))
			end
			said = brokerTooltip()
			if said and not said:find(T.BROKER_TOP:format(L.TITLES[7].name), 1, true) then
				fail(scenario, "past the last title the minimap tooltip reads: " .. said)
			end
		end
	end
end
Mock.reset()
