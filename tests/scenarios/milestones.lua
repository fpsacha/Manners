-- Ledger milestones (Ledger.lua, TITLES): the little titles the favours you
-- return earn you. Where each one starts and what the way to the next says;
-- the one line in chat a new title gets, and never a second; the quiet welcome
-- an old ledger gets for the titles it earned before there were any; Clear
-- keeping them; and the window and the minimap tooltip showing them.
--
-- The announcement is checked through the real path -- a buff landing, the
-- prompt pressed, the server refusing the cast -- because what matters there
-- is that Core's settle reaches it with chat lines off, and that it waits out
-- the refusal Core can still hear. The rest is the ledger's own arithmetic and
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
-- is the settle's clock, which is what a refusal names it by. `wait` is the
-- time between the two, five seconds unless said.
local function returnOne(ns, name, wait)
	wait = wait or 5
	ns.Ledger.Received({ name = name, class = "PRIEST", key = 1459 })
	Mock.advance(wait)
	local clock = GetTime()
	ns.Ledger.Settled(name, { at = clock - wait }, { buffKey = "intellect" }, 1459)
	return clock
end

-- One favour returned and the refusal window let pass, so a title it earns
-- is said.
local function returnKept(ns, name)
	local clock = returnOne(ns, name)
	Mock.runTimers(ns.Ledger.PROMOTE_SECONDS + 1)
	return clock
end

-- A press on `entry` whose cast is sent under `guid`, so a refusal can name it.
local function pressAs(ns, entry, spellId, guid)
	local button = ns.Prompt:GetButton()
	Mock.advance(1)
	ns.pendingClick = nil
	ns.Prompt:InvalidateMacro()
	ns.Prompt:ApplyTarget(entry)
	local post = button.scripts.PostClick
	if post then pcall(post, button, "LeftButton", true) end
	if not ns.pendingClick then return false end
	ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, guid, spellId)
	return true
end

-- Anything the ledger threw inside Guard, which a title said from a timer runs
-- under.
local function guarded(ns, scenario)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
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
				-- Not yet: the server may still refuse the cast.
				if #announcements(ns) ~= 0 then
					fail(scenario, "the title was said when the cast was sent, before the server could refuse it")
				end
				Mock.runTimers(ns.Ledger.PROMOTE_SECONDS + 1)
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
-- Through the real path: Core settles a favour when the cast is sent, and
-- the server can refuse it a moment later and take the favour back. The
-- tenth favour on a press the server refuses is not said -- the window has
-- just taken the title away again -- and the press that really lands it is
-- said, once.
Mock.reset()
do
	local scenario = "milestones: a title waits out the refusal of the cast that earned it"
	local ns = load(scenario)
	if ns then
		H.freshPrompt(ns, scenario)
		local s = fresh(ns)
		s.totals.returned = 9
		ns.db.profile.verbose = false
		H.primeAuras(ns)
		H.favourFrom(ns, "nameplate1", 1459, 4101)
		local entry = ns.owed[PETRA] and H.inQueue(ns)[PETRA]
		if not entry or not pressAs(ns, entry, 1459, "Cast-7") then
			fail(scenario, "SKIPPED -- Petra is not owed and offered, or the press went nowhere")
		elseif s.totals.returned ~= 10 then
			fail(scenario, "SKIPPED -- the press did not settle the favour (returned "
				.. tostring(s.totals.returned) .. ")")
		else
			Mock.printed = {}
			ns.addon:UNIT_SPELLCAST_FAILED(nil, "player", "Cast-7", 1459)
			if s.totals.returned ~= 9 then
				fail(scenario, "SKIPPED -- the refusal did not take the favour back: " .. tostring(s.totals.returned))
			end
			Mock.runTimers(ns.Ledger.PROMOTE_SECONDS + 1)
			if #announcements(ns) ~= 0 then
				fail(scenario, "a title was said for a favour the server refused: " .. announcements(ns)[1])
			end
			if s.title ~= 0 then fail(scenario, "a refused favour left the title marked said: " .. tostring(s.title)) end

			ns.addon:TickBody()
			local again = H.inQueue(ns)[PETRA]
			if not again or not pressAs(ns, again, 1459, "Cast-9") then
				fail(scenario, "SKIPPED -- Petra was not offered again after the refusal")
			else
				Mock.runTimers(ns.Ledger.PROMOTE_SECONDS + 1)
				local lines = announcements(ns)
				if #lines ~= 1 or not lines[1]:find(said(ns, 1), 1, true) then
					fail(scenario, ("the favour that really earned the title was said %d times: %s"):format(
						#lines, table.concat(lines, " / ")))
				end
				if s.title ~= 1 then fail(scenario, "the title said was not remembered: " .. tostring(s.title)) end
			end
		end
		guarded(ns, scenario)
	end
end
Mock.reset()

-- ------------------------------------------------------------------ milestones 4
-- A title is said once and never again: not when a late refusal takes back
-- the favour that earned it after it was said and the next one earns it
-- again, and not for any favour after. The next title is said when it comes.
-- A favour that reaches a title while another's wait is running gets its own
-- full wait, so a refusal of it is still heard.
Mock.reset()
do
	local scenario = "milestones: a title taken back and earned again is not said twice"
	local ns = load(scenario)
	if ns then
		H.freshPrompt(ns, scenario)
		local s = fresh(ns)
		local L = ns.Ledger
		local WAIT = L.PROMOTE_SECONDS

		-- The tenth favour, refused inside the wait; then another tenth late in
		-- that same wait, refused too. Neither is said.
		s.totals.returned = 9
		Mock.printed = {}
		local clock = returnOne(ns, "Anna Aim", 0)
		Mock.runTimers(0.5)
		L.Refused("Anna Aim", clock)
		Mock.runTimers(WAIT - 1)
		clock = returnOne(ns, "Bo Bell", 0)
		Mock.runTimers(1.1)
		if #announcements(ns) ~= 0 then
			fail(scenario, "a favour's title was said before its own refusal could come: " .. announcements(ns)[1])
		end
		L.Refused("Bo Bell", clock)
		Mock.runTimers(WAIT + 1)
		if #announcements(ns) ~= 0 or s.title ~= 0 or s.totals.returned ~= 9 then
			fail(scenario, ("two refused tenth favours: said %d times, mark %s, %s returned"):format(
				#announcements(ns), tostring(s.title), tostring(s.totals.returned)))
		end

		-- Kept this time, and said once.
		clock = returnKept(ns, "Anna Aim")
		if #announcements(ns) ~= 1 then
			fail(scenario, "SKIPPED -- the tenth favour was announced " .. #announcements(ns) .. " times")
		else
			-- Taken back after it was said: the title stays said.
			L.Refused("Anna Aim", clock)
			if s.totals.returned ~= 9 then
				fail(scenario, "SKIPPED -- the refusal did not take the favour back: " .. tostring(s.totals.returned))
			end
			Mock.printed = {}
			Mock.advance(60)
			returnKept(ns, "Anna Aim")
			returnKept(ns, "Bo Bell")
			if #announcements(ns) ~= 0 then
				fail(scenario, "a title already announced was announced again: " .. announcements(ns)[1])
			end
			-- Up to the edge of the next title and over it.
			s.totals.returned = 24
			Mock.printed = {}
			returnKept(ns, "Cy Cole")
			local lines = announcements(ns)
			if #lines ~= 1 or not lines[1]:find(said(ns, 2), 1, true) then
				fail(scenario, "the twenty-fifth favour did not announce the second title: "
					.. table.concat(lines, " / "))
			end
			Mock.printed = {}
			returnKept(ns, "Di Dale")
			if #announcements(ns) ~= 0 then fail(scenario, "a favour past a title announced it again") end
		end
		guarded(ns, scenario)
	end
end
Mock.reset()

-- ------------------------------------------------------------------ milestones 5
-- A client with no timer to wait on says the title at once rather than never.
Mock.reset()
do
	local scenario = "milestones: without a timer a title is said at once"
	local ns = load(scenario)
	if ns then
		H.freshPrompt(ns, scenario)
		local s = fresh(ns)
		s.totals.returned = 9
		Mock.printed = {}
		local timer = C_Timer
		C_Timer = nil
		local ok, err = pcall(returnOne, ns, "Anna Aim")
		C_Timer = timer
		if not ok then
			fail(scenario, "a favour with no timer threw: " .. tostring(err))
		elseif #announcements(ns) ~= 1 or s.title ~= 1 then
			fail(scenario, ("with no timer the tenth favour was said %d times, mark %s"):format(
				#announcements(ns), tostring(s.title)))
		end
		guarded(ns, scenario)
	end
end
Mock.reset()

-- ------------------------------------------------------------------ milestones 6
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
		returnKept(ns, "Anna Aim")
		if #announcements(ns) ~= 0 then
			fail(scenario, "the first favour after the upgrade announced a title already held")
		end
		s.totals.returned = 499
		returnKept(ns, "Bo Bell")
		local lines = announcements(ns)
		if #lines ~= 1 or not lines[1]:find(said(ns, 6), 1, true) then
			fail(scenario, "the five-hundredth favour did not announce the sixth title: " .. table.concat(lines, " / "))
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ milestones 7
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

-- ------------------------------------------------------------------ milestones 8
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
		returnKept(ns, "Anna Aim")
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
			returnKept(ns, "Bo Bell")
			if #announcements(ns) ~= 0 then fail(scenario, "after Clear a title held was announced again") end
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ milestones 9
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

-- ===========================================================================
-- Milestones.lua: the marks of good manners over the ledger, their toast,
-- their tab and their switch. Every name below starts "milestones: earned:".
-- ===========================================================================

-- A clean ledger and no milestones yet, and nothing said so far.
local function begin(ns, scenario)
	if scenario then H.freshPrompt(ns, scenario) end
	ns.db.char.ledger = nil
	ns.db.char.milestones = nil
	ns.Ledger.Load()
	Mock.printed = {}
	return ns.Milestones
end

local function lines(text)
	local out = {}
	local prefix = text:match("^([^|%%]*)")
	for _, line in ipairs(Mock.printed or {}) do
		if tostring(line):find(prefix, 1, true) then out[#out + 1] = tostring(line) end
	end
	return out
end

local function earned(ns, id)
	local st = ns.db.char.milestones
	return st and st.earned and st.earned[id]
end

-- A buff given unprompted, as Core files it.
local function give(ns, name, inGroup, spell, extra)
	local pending = { inGroup = inGroup == true, class = "WARRIOR" }
	for k, v in pairs(extra or {}) do pending[k] = v end
	ns.Ledger.Settled(name, nil, pending, spell or 1459)
end

local function settle(ns)
	Mock.runTimers(ns.Ledger.PROMOTE_SECONDS + 1)
end

-- The toast as a player would see it: its frame while shown, a frame of its
-- OnUpdate run so it is past its fade-in.
local function toastUp(ns)
	local f = ns.Milestones.ToastFrame()
	if not (f and f:IsShown()) then return nil end
	return f
end

-- The calendar by the mock's clock, which the mock's own date() does not keep:
-- a day is 86400 seconds of it. Put back by the caller.
local function calendar()
	local real = date
	date = function(fmt, t)
		if fmt == "%Y%m%d" then return tostring(math.floor((t or time()) / 86400)) end
		if fmt == "%Y-%m-%d" then return "day " .. tostring(math.floor((t or time()) / 86400)) end
		return real(fmt, t)
	end
	return function() date = real end
end

-- ------------------------------------------------------------- earned 1
-- The first favour returned earns the first milestone: not at the press, since
-- the server can still refuse it, but once that wait is over; with one line in
-- chat, a toast naming it, and the fanfare.
Mock.reset()
do
	local scenario = "milestones: earned: the first favour returned earns one, with a line, a toast and the sound"
	local ns = load(scenario)
	if ns then
		local M = begin(ns, scenario)
		local played = {}
		local realSound = PlaySound
		PlaySound = function(kit) played[#played + 1] = kit return true end
		local def = M.LIST[1]
		if def.id ~= "first" then fail(scenario, "the first milestone listed is " .. tostring(def.id)) end
		returnOne(ns, PETRA, 30)
		if earned(ns, "first") then fail(scenario, "earned at the press, before the server could refuse the cast") end
		if toastUp(ns) then fail(scenario, "a toast at the press") end
		settle(ns)
		local at = earned(ns, "first")
		if not (type(at) == "number" and at > 0) then
			fail(scenario, "the first favour returned earned nothing: " .. tostring(at))
		end
		local said = lines(M.TEXT.EARNED)
		if #said ~= 1 or not said[1]:find(def.name, 1, true) then
			fail(scenario, ("the milestone got %d line(s) in chat"):format(#said))
		end
		local f = toastUp(ns)
		if not f then
			fail(scenario, "no toast for the milestone")
		else
			if f.name:GetText() ~= def.name then fail(scenario, "the toast names " .. tostring(f.name:GetText())) end
			if f.line:GetText() ~= def.desc then fail(scenario, "the toast's line is " .. tostring(f.line:GetText())) end
			if f.heading:GetText() ~= M.TEXT.HEAD_MILESTONE then fail(scenario, "the toast's heading is " .. tostring(f.heading:GetText())) end
			if not (f.item and f.item.icon == def.icon) then fail(scenario, "the toast's icon is " .. tostring(f.item and f.item.icon)) end
		end
		if #played ~= 1 then fail(scenario, ("the fanfare played %d times"):format(#played)) end
		-- A second favour returned earns nothing twice.
		Mock.printed = {}
		returnOne(ns, "Bo Bell", 30)
		settle(ns)
		if #lines(M.TEXT.EARNED) ~= 0 then fail(scenario, "a milestone held was said again") end
		PlaySound = realSound
		guarded(ns, scenario)
	end
end

-- ------------------------------------------------------------- earned 2
-- A cast the server refuses inside the wait counts for nothing.
Mock.reset()
do
	local scenario = "milestones: earned: a refused cast earns nothing"
	local ns = load(scenario)
	if ns then
		local M = begin(ns, scenario)
		local clock = returnOne(ns, PETRA, 5)
		Mock.advance(1)
		ns.Ledger.Refused(PETRA, clock)
		settle(ns)
		if earned(ns, "first") or earned(ns, "swift") then fail(scenario, "a refused favour earned a milestone") end
		local st = ns.db.char.milestones
		if st and st.people[PETRA] then fail(scenario, "a refused favour was counted towards its giver") end
		if toastUp(ns) then fail(scenario, "a toast for a refused cast") end
		-- A buff given and refused: its row is gone, and so is its count.
		local gaveAt = GetTime()
		give(ns, "Corwin Ash", false)
		Mock.advance(1)
		ns.Ledger.Refused("Corwin Ash", gaveAt)
		settle(ns)
		if st and st.n.strangers ~= 0 then fail(scenario, "a refused buff counted a stranger") end
		-- The fanfare sound setting: off, the toast is silent.
		local played = 0
		local realSound = PlaySound
		PlaySound = function() played = played + 1 return true end
		ns.db.profile.milestones.sound = false
		returnOne(ns, PETRA, 30)
		settle(ns)
		if not toastUp(ns) then fail(scenario, "no toast with the sound off") end
		if played ~= 0 then fail(scenario, "the fanfare played with \"Play the sound\" off") end
		PlaySound = realSound
		guarded(ns, scenario)
	end
end

-- ------------------------------------------------------------- earned 3
-- A ledger that was long before milestones came: what it had earned is marked
-- with no toast, and one quiet line says how many and where they are.
Mock.reset()
do
	local scenario = "milestones: earned: an old ledger is marked quietly, with one line"
	local ns = load(scenario)
	if ns then
		local M = begin(ns, scenario)
		ns.db.char.ledger.totals.returned = 150
		ns.db.char.ledger.totals.received = 160
		ns.db.char.ledger.totals.strangers = 120
		ns.db.char.milestones = nil
		Mock.printed = {}
		ns.Ledger.Load()
		for _, id in ipairs({ "first", "hundred", "strangers" }) do
			local at = earned(ns, id)
			if not (type(at) == "number" and at < 0) then
				fail(scenario, id .. " was not marked as earned before: " .. tostring(at))
			end
		end
		if toastUp(ns) or M.Waiting() ~= 0 then fail(scenario, "a toast at login for what an old ledger had earned") end
		if #lines(M.TEXT.EARNED) ~= 0 then fail(scenario, "a line each at login for what an old ledger had earned") end
		local said = lines(M.TEXT.SEEDED_MANY)
		if #said ~= 1 or not said[1]:find(M.TEXT.SEEDED_MANY:format(3), 1, true) then
			fail(scenario, "the one quiet line reads: " .. tostring(said[1]) .. " (" .. #said .. ")")
		end
		-- Once: the next login says nothing.
		Mock.printed = {}
		ns.Ledger.Load()
		if #Mock.printed ~= 0 then fail(scenario, "the next login spoke again: " .. tostring(Mock.printed[1])) end
		-- And a new character's empty ledger gets no line at all.
		begin(ns)
		ns.db.char.milestones = nil
		ns.Ledger.Load()
		if #Mock.printed ~= 0 then fail(scenario, "an empty ledger was greeted: " .. tostring(Mock.printed[1])) end
		guarded(ns, scenario)
	end
end

-- ------------------------------------------------------------- earned 4
-- The master switch. Off: nothing counted, no toast, no line, no tab; what was
-- earned is kept. Back on: what was passed meanwhile is marked without a toast,
-- so turning it earns nothing.
Mock.reset()
do
	local scenario = "milestones: earned: switched off, nothing is counted, shown or said, and what was earned is kept"
	local ns = load(scenario)
	if ns then
		local M = begin(ns, scenario)
		if ns.db.profile.milestones.enabled ~= true or ns.db.profile.milestones.toast ~= true
			or ns.db.profile.milestones.sound ~= true then
			fail(scenario, "milestones, their toast and their sound are not all on by default")
		end
		returnOne(ns, PETRA, 30)
		settle(ns)
		if not earned(ns, "first") then fail(scenario, "nothing earned to begin with") end
		local toast = M.ToastFrame()
		local switch = H.findOption(ns.optionsTable, "milestones")
		if not (switch and switch.set) then
			fail(scenario, "no Milestones switch on the options page")
		else
			switch.set(nil, false)
			if ns.db.profile.milestones.enabled ~= false then fail(scenario, "the switch did not switch it off") end
			if toast and toast:IsShown() then fail(scenario, "the toast stayed up when milestones were switched off") end
			Mock.printed = {}
			local before = ns.db.char.milestones.n.strangers
			give(ns, "Corwin Ash", false)
			give(ns, "Delphine Moor", false, 1459, { reason = "asked" })
			ns.Milestones.Note("res")
			ns.Milestones.Ranked(ns.Ledger.TITLES[1])
			settle(ns)
			local st = ns.db.char.milestones
			if st.n.strangers ~= before or st.n.asked ~= 0 or st.n.res ~= 0 then
				fail(scenario, "something was counted while milestones were off")
			end
			if earned(ns, "asked") then fail(scenario, "a milestone earned while they were off") end
			if #Mock.printed ~= 0 then fail(scenario, "a line while off: " .. tostring(Mock.printed[1])) end
			if (toast and toast:IsShown()) or M.Waiting() ~= 0 then fail(scenario, "a toast while off") end
			if not earned(ns, "first") then fail(scenario, "what was earned was lost when it was switched off") end
			ns.Ledger.Show()
			local window = ns.Ledger.Window()
			for _, tab in ipairs(window.tabs) do
				if tab.key == "milestones" and tab:IsShown() then fail(scenario, "the Milestones tab shows while off") end
			end
			if M.Page(window, "milestones") ~= nil then fail(scenario, "the tab's page answers while off") end
			if M.Lines()[1] ~= M.TEXT.LINE_OFF then fail(scenario, "the check-up does not say it is off") end

			-- Passed while off, and switched back on: marked, never toasted.
			ns.db.char.ledger.totals.returned = 100
			Mock.printed = {}
			switch.set(nil, true)
			local at = earned(ns, "hundred")
			if not (type(at) == "number" and at < 0) then
				fail(scenario, "what was passed while off was not marked quietly: " .. tostring(at))
			end
			if (toast and toast:IsShown()) or M.Waiting() ~= 0 or #lines(M.TEXT.EARNED) ~= 0 then
				fail(scenario, "switching milestones back on gave a toast or a line")
			end
			local shown = false
			for _, tab in ipairs(window.tabs) do
				if tab.key == "milestones" and tab:IsShown() then shown = true end
			end
			if not shown then fail(scenario, "the Milestones tab did not come back") end
		end
		for _, key in ipairs({ "milestoneToast", "milestoneSound" }) do
			if not H.findOption(ns.optionsTable, key) then fail(scenario, "no " .. key .. " on the options page") end
		end
		guarded(ns, scenario)
	end
end

-- ------------------------------------------------------------- earned 5
-- Don't be annoying: no toast in a fight, one at a time, at most one a minute,
-- gone after a few seconds, and a click sends it away.
Mock.reset()
do
	local scenario = "milestones: earned: a toast waits out a fight and the minute, and goes by itself or at a click"
	local ns = load(scenario)
	if ns then
		local M = begin(ns, scenario)
		Mock.inCombat = true
		returnOne(ns, PETRA, 30)
		settle(ns)
		if not earned(ns, "first") then fail(scenario, "nothing earned in the fight") end
		if toastUp(ns) then fail(scenario, "a toast in a fight") end
		if M.Waiting() ~= 1 then fail(scenario, ("%d toasts wait in the fight, not 1"):format(M.Waiting())) end
		local held = M.Lines()[2]
		if held ~= M.TEXT.LINE_HELD_FIGHT:format(1) then fail(scenario, "the check-up reads: " .. tostring(held)) end
		M.Pump()
		if toastUp(ns) then fail(scenario, "the toast came up while the fight went on") end
		Mock.inCombat = false
		M.Pump()
		local f = toastUp(ns)
		if not f then
			fail(scenario, "the toast did not come once the fight ended")
		else
			-- A second, while the first is up, and then inside the minute.
			M.Ranked(ns.Ledger.TITLES[1])
			if f.name:GetText() == ns.Ledger.TITLES[1].name then fail(scenario, "a second toast replaced the one showing") end
			if M.Waiting() ~= 1 then fail(scenario, "the second toast is not waiting") end
			f.scripts.OnClick(f)
			if f:IsShown() then fail(scenario, "a click did not send the toast away") end
			M.Pump()
			if f:IsShown() then fail(scenario, "two toasts inside a minute") end
			if M.Lines()[2] ~= M.TEXT.LINE_HELD_MINUTE:format(1) then
				fail(scenario, "the check-up does not say the minute holds it: " .. tostring(M.Lines()[2]))
			end
			Mock.advance(M.TOAST_GAP + 1)
			M.Pump()
			if not f:IsShown() or f.name:GetText() ~= ns.Ledger.TITLES[1].name then
				fail(scenario, "the second toast did not come after the minute")
			elseif f.heading:GetText() ~= M.TEXT.HEAD_TITLE then
				fail(scenario, "a new title's toast is headed " .. tostring(f.heading:GetText()))
			end
			-- Gone after a few seconds, by itself.
			f.scripts.OnUpdate(f, 1)
			if not f:IsShown() or f:GetAlpha() ~= 1 then fail(scenario, "a second in, the toast is not fully up") end
			f.scripts.OnUpdate(f, M.TOAST_SECONDS)
			if f:IsShown() then fail(scenario, "the toast is still up after its few seconds") end
			-- And a fight that starts under one takes it away.
			Mock.advance(M.TOAST_GAP + 1)
			M.Ranked(ns.Ledger.TITLES[2])
			if not f:IsShown() then fail(scenario, "no third toast") end
			Mock.inCombat = true
			f.scripts.OnUpdate(f, 0.1)
			if f:IsShown() then fail(scenario, "the toast stayed up when a fight began") end
			Mock.inCombat = false
		end
		-- "Show it on screen too" off: the line in chat, and no toast.
		ns.db.profile.milestones.toast = false
		Mock.advance(M.TOAST_GAP + 1)
		Mock.printed = {}
		give(ns, "Delphine Moor", false, 1459, { reason = "asked" })
		settle(ns)
		if not earned(ns, "asked") then fail(scenario, "answering a request earned nothing") end
		if #lines(M.TEXT.EARNED) ~= 1 then fail(scenario, "no line in chat with the toast off") end
		if (f and f:IsShown()) or M.Waiting() ~= 0 then fail(scenario, "a toast with \"Show it on screen too\" off") end
		guarded(ns, scenario)
	end
end

-- ------------------------------------------------------------- earned 6
-- Never over the prompt: with the prompt where the toast would go, the toast
-- goes somewhere else.
Mock.reset()
do
	local scenario = "milestones: earned: a toast is never over the prompt"
	local ns = load(scenario)
	if ns then
		local M = begin(ns, scenario)
		Mock.geometry = { width = 1600, height = 900 }
		local button = ns.Prompt:GetButton()
		button:ClearAllPoints()
		button:SetPoint("TOP", UIParent, "TOP", 0, -160)
		button:SetSize(200, 40)
		button:Show()
		M.Ranked(ns.Ledger.TITLES[1])
		local f = toastUp(ns)
		if not f then
			fail(scenario, "no toast")
		else
			local function over(a, b)
				return a:GetLeft() < b:GetRight() and b:GetLeft() < a:GetRight()
					and a:GetBottom() < b:GetTop() and b:GetBottom() < a:GetTop()
			end
			if f:GetRight() - f:GetLeft() < 100 then fail(scenario, "the mock gave the toast no rectangle") end
			if over(f, button) then fail(scenario, "the toast is over the prompt") end
			if f.spot == 1 then fail(scenario, "the toast kept its first spot, which the prompt is in") end
			-- With the prompt out of the way it takes its first spot.
			f:Hide()
			button:ClearAllPoints()
			button:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 120)
			Mock.advance(M.TOAST_GAP + 1)
			M.Ranked(ns.Ledger.TITLES[2])
			if f.spot ~= 1 then fail(scenario, "with the prompt elsewhere the toast is not at its first spot") end
		end
		Mock.geometry = nil
		guarded(ns, scenario)
	end
end

-- ------------------------------------------------------------- earned 7
-- Never a reward for spam: a stranger buffed again before the buff would have
-- run out is the same stranger, and a buff for the group is no stranger.
Mock.reset()
do
	local scenario = "milestones: earned: the same stranger counts once until the buff would have run out"
	local ns = load(scenario)
	if ns then
		begin(ns, scenario)
		local function strangers() return ns.db.char.milestones and ns.db.char.milestones.n.strangers or 0 end
		give(ns, "Corwin Ash", false)
		settle(ns)
		if strangers() ~= 1 then fail(scenario, ("one stranger buffed counts %d"):format(strangers())) end
		for _ = 1, 5 do
			Mock.advance(20)
			give(ns, "Corwin Ash", false)
			settle(ns)
		end
		if strangers() ~= 1 then fail(scenario, ("the same stranger six times in two minutes counts %d"):format(strangers())) end
		give(ns, "Delphine Moor", false)
		give(ns, "Gwen Hollow", true)
		settle(ns)
		if strangers() ~= 2 then fail(scenario, ("two strangers and a group member count %d"):format(strangers())) end
		local lasts = ns.SPELL_SECONDS and ns.SPELL_SECONDS[1459]
		if type(lasts) ~= "number" or lasts <= 0 then lasts = 1800 end
		Mock.advance(lasts + 1200)
		give(ns, "Corwin Ash", false)
		settle(ns)
		if strangers() ~= 3 then fail(scenario, ("the same stranger after the buff ran out counts %d"):format(strangers())) end
		-- Progress on the tab, and nothing earned at three.
		if earned(ns, "strangers") then fail(scenario, "three strangers earned the hundred") end
		ns.db.char.milestones.n.strangers = 99
		Mock.advance(lasts + 1200)
		give(ns, "Esk Tallow", false)
		settle(ns)
		if not earned(ns, "strangers") then fail(scenario, "the hundredth stranger earned nothing") end
		guarded(ns, scenario)
	end
end

-- ------------------------------------------------------------- earned 8
-- The same person counts once a day: ten favours returned to one friend in an
-- afternoon are one day, and ten days are the milestone. A favour returned
-- inside ten seconds is the hidden one; ten different people in a day another.
Mock.reset()
do
	local scenario = "milestones: earned: the same person counts once a day, and ten people in a day once each"
	local ns = load(scenario)
	if ns then
		begin(ns, scenario)
		local restore = calendar()
		for _ = 1, 12 do
			returnOne(ns, PETRA, 30)
			settle(ns)
			Mock.advance(60)
		end
		local st = ns.db.char.milestones
		if not (st.people[PETRA] and st.people[PETRA].n == 1) then
			fail(scenario, "twelve favours returned to one person in a day count " .. tostring(st.people[PETRA] and st.people[PETRA].n))
		end
		if earned(ns, "regular") then fail(scenario, "one busy afternoon earned the ten days") end
		if st.today.n ~= 1 or earned(ns, "day10") then fail(scenario, "one person twelve times counts as " .. tostring(st.today.n) .. " people today") end
		if earned(ns, "swift") then fail(scenario, "a favour returned in thirty seconds was quick") end
		for day = 2, 10 do
			Mock.advance(86400)
			returnOne(ns, PETRA, 30)
			settle(ns)
			if (earned(ns, "regular") ~= nil) ~= (day == 10) then
				fail(scenario, ("on day %d the ten days are %s"):format(day, tostring(earned(ns, "regular"))))
			end
		end
		-- Ten different people in one day.
		Mock.advance(86400)
		for i = 1, 10 do
			returnOne(ns, "Guest " .. string.char(64 + i) .. "x", 30)
			settle(ns)
			if (earned(ns, "day10") ~= nil) ~= (i == 10) then
				fail(scenario, ("after %d people today the day's ten is %s"):format(i, tostring(earned(ns, "day10"))))
			end
		end
		-- Inside ten seconds, and just outside.
		returnOne(ns, "Slow Sam", ns.Milestones.SWIFT_SECONDS + 1)
		settle(ns)
		if earned(ns, "swift") then fail(scenario, "eleven seconds was quick") end
		returnOne(ns, "Quick Quin", ns.Milestones.SWIFT_SECONDS)
		settle(ns)
		if not earned(ns, "swift") then fail(scenario, "ten seconds was not quick") end
		-- Five classes: every return above was to a priest.
		if earned(ns, "classes") then fail(scenario, "priests alone are five classes") end
		for i, class in ipairs({ "MAGE", "DRUID", "PALADIN", "WARRIOR" }) do
			local name = "Class " .. string.char(64 + i) .. "y"
			ns.Ledger.Received({ name = name, class = class, key = 1459 })
			Mock.advance(30)
			ns.Ledger.Settled(name, { at = GetTime() - 30 }, { buffKey = "intellect" }, 1459)
			settle(ns)
			if (earned(ns, "classes") ~= nil) ~= (i == 4) then
				fail(scenario, ("after %d classes the five are %s"):format(i + 1, tostring(earned(ns, "classes"))))
			end
		end
		restore()
		guarded(ns, scenario)
	end
end

-- ------------------------------------------------------------- earned 9
-- A week in which every favour was returned: ten or more, on five days or
-- more, and none left unreturned.
Mock.reset()
do
	local scenario = "milestones: earned: a week with every favour returned, and not one with a favour let go"
	local ns = load(scenario)
	if ns then
		begin(ns, scenario)
		local restore = calendar()
		local n = 0
		local function day(count)
			for _ = 1, count do
				n = n + 1
				returnOne(ns, "Weekly " .. string.char(64 + n) .. "z", 30)
				settle(ns)
			end
			Mock.advance(86400)
		end
		day(3) day(3) day(3) day(1)
		if earned(ns, "week") then fail(scenario, "ten favours on four days made a week") end
		-- One let go on the fifth day: not this week.
		ns.Ledger.Received({ name = "Forgotten Fay", class = "PRIEST", key = 1459 })
		Mock.advance(200)
		ns.Ledger.LetGo("Forgotten Fay")
		day(1)
		if earned(ns, "week") then fail(scenario, "a week with a favour let go was kept") end
		-- A week later the lapse is behind: five days, ten favours, all returned.
		Mock.advance(8 * 86400)
		n = 0
		day(2) day(2) day(2) day(2)
		if earned(ns, "week") then fail(scenario, "eight favours on four days made a week") end
		day(2)
		if not earned(ns, "week") then fail(scenario, "ten favours on five days, all returned, earned nothing") end
		restore()
		guarded(ns, scenario)
	end
end

-- ------------------------------------------------------------- earned 10
-- Everybody in your raid in one sitting: one of your buffs on each of them,
-- by single casts or by one cast for the group, inside a quarter of an hour.
Mock.reset()
do
	local scenario = "milestones: earned: a whole raid buffed in one sitting"
	local ns = load(scenario)
	if ns then
		begin(ns, scenario)
		Mock.raid = { size = 10 }
		for i = 1, 8 do give(ns, "Raider " .. string.char(64 + i) .. "a", true) end
		-- The same one again adds nobody.
		give(ns, "Raider Aa", true)
		settle(ns)
		if earned(ns, "raid") then fail(scenario, "eight of nine raid members were the whole raid") end
		-- The ninth, but long after: another sitting.
		Mock.advance(1200)
		give(ns, "Raider Ia", true)
		settle(ns)
		if earned(ns, "raid") then fail(scenario, "a raid buffed over twenty minutes was one sitting") end
		-- A stranger outside the raid is not one of it.
		Mock.advance(1200)
		for i = 1, 8 do give(ns, "Raider " .. string.char(64 + i) .. "a", true) end
		give(ns, "Passing Pat", false)
		returnOne(ns, "Outside Olaf", 30)
		settle(ns)
		if earned(ns, "raid") then fail(scenario, "somebody outside the raid stood in for a raid member") end
		give(ns, "Raider Ia", true)
		settle(ns)
		if not earned(ns, "raid") then fail(scenario, "nine raid members buffed in one sitting earned nothing") end
		-- One cast for the whole group does it too.
		ns.db.char.milestones.earned.raid = nil
		ns.db.char.milestones.n.raid = 0
		Mock.advance(1200)
		local members = {}
		for i = 1, 9 do members[i] = { name = "Raider " .. i } end
		give(ns, "Raider Aa", true, 23028, { group = { spell = 23028, members = members } })
		settle(ns)
		if not earned(ns, "raid") then fail(scenario, "one cast that covered the raid earned nothing") end
		-- And five people are a party, not a raid.
		ns.db.char.milestones.earned.raid = nil
		ns.db.char.milestones.n.raid = 0
		Mock.raid = nil
		Mock.advance(1200)
		for i = 1, 9 do give(ns, "Friend " .. string.char(64 + i) .. "a", true) end
		settle(ns)
		if earned(ns, "raid") then fail(scenario, "outside a raid, a raid was buffed") end
		guarded(ns, scenario)
	end
end

-- ------------------------------------------------------------- earned 11
-- The tab: every milestone this character can earn, the earned ones first with
-- their date and a link button, progress where there is a number, "?" for a
-- hidden one. The link only fills the chat box; nothing is ever sent.
Mock.reset()
do
	local scenario = "milestones: earned: the tab lists them, and the link only fills the chat box"
	local ns = load(scenario)
	if ns then
		local M = begin(ns, scenario)
		local opened, sent = {}, 0
		local realOpen, realUtil, realSend = ChatFrame_OpenChat, ChatFrameUtil, SendChatMessage
		ChatFrameUtil = nil
		ChatFrame_OpenChat = function(text) opened[#opened + 1] = text end
		SendChatMessage = function() sent = sent + 1 end
		returnOne(ns, PETRA, 30)
		give(ns, "Corwin Ash", false)
		settle(ns)
		ns.Ledger.Show()
		local window = ns.Ledger.Window()
		local tab
		for _, t in ipairs(window.tabs) do if t.key == "milestones" then tab = t end end
		if #window.tabs ~= 4 or not tab then
			fail(scenario, "the ledger has no fourth tab for milestones")
		else
			if tab.label:GetText() ~= ns.Ledger.TEXT.TAB_MILESTONES then fail(scenario, "the tab reads " .. tostring(tab.label:GetText())) end
			tab.scripts.OnClick(tab)
			local list = M.Rows()
			local _, of = M.Tally()
			if #list ~= of or of < 10 then fail(scenario, ("the tab lists %d of %d milestones"):format(#list, of)) end
			local top = window.rows[1]
			if not (top:IsShown() and top.entry and top.entry.id == "first") then
				fail(scenario, "the earned milestone is not on top: " .. tostring(top.entry and top.entry.id))
			else
				if top.name:GetText() ~= M.LIST[1].name then fail(scenario, "the earned row is named " .. tostring(top.name:GetText())) end
				if top.badge:GetText() ~= M.TEXT.BADGE_EARNED then fail(scenario, "the earned row's badge reads " .. tostring(top.badge:GetText())) end
				if tostring(top.when:GetText() or "") == "" then fail(scenario, "the earned row has no date") end
				if not (top.link and top.link:IsShown()) then
					fail(scenario, "the earned row has no link button")
				else
					top.link.scripts.OnClick(top.link)
					if #opened ~= 1 then
						fail(scenario, ("the link opened the chat box %d times"):format(#opened))
					else
						if not opened[1]:find(M.LIST[1].name, 1, true) or not opened[1]:find("Manners", 1, true) then
							fail(scenario, "the line does not name the milestone and Manners: " .. opened[1])
						end
						if opened[1]:find("|", 1, true) or #opened[1] > 255 then fail(scenario, "the line is not plain text that fits: " .. opened[1]) end
					end
					if sent ~= 0 then fail(scenario, "the link sent a line itself") end
				end
			end
			-- Further down: progress with its numbers, a hidden one as "?", and
			-- no link on either.
			local seen = {}
			for offset = 0, #list - 1, 7 do
				ns.Ledger.Scroll(offset == 0 and 0 or 7)
				for _, row in ipairs(window.rows) do
					local m = row:IsShown() and row.entry
					if m and m.milestone and not seen[m.id] then
						seen[m.id] = true
						if m.id == "strangers" and row.badge:GetText() ~= M.TEXT.BADGE_PROGRESS:format(1, 100) then
							fail(scenario, "a hundred strangers, one in, reads " .. tostring(row.badge:GetText()))
						end
						if m.def.hidden and not m.earnedAt and (row.name:GetText() ~= "?" or row.detail:GetText() == m.def.desc) then
							fail(scenario, "a hidden milestone gives itself away: " .. tostring(row.name:GetText()))
						end
						if not m.earnedAt and row.link:IsShown() then fail(scenario, m.id .. " is not earned and has a link button") end
					end
				end
			end
			local count = 0
			for _ in pairs(seen) do count = count + 1 end
			if count ~= #list then fail(scenario, ("scrolling showed %d of %d milestones"):format(count, #list)) end
			if not seen.week or not seen.strangers then fail(scenario, "the list lacks the week or the strangers") end
			-- Back on a favour tab the rows are favours again, with no link.
			ns.Ledger.Scroll(-100)
			if not window.rows[1].link:IsShown() then fail(scenario, "scrolled back up, the earned row has lost its link") end
			for _, t in ipairs(window.tabs) do if t.key == "all" then t.scripts.OnClick(t) end end
			for _, row in ipairs(window.rows) do
				if row:IsShown() and (row.entry.milestone or (row.link and row.link:IsShown())) then
					fail(scenario, "a favour row kept a milestone's dress")
				end
			end
			-- Clear keeps milestones, as it keeps the counts.
			ns.Ledger.Clear()
			if not earned(ns, "first") then fail(scenario, "Clear took a milestone") end
		end
		-- A reload: what was earned comes back, and a damaged store is repaired.
		local at = earned(ns, "first")
		ns.db.char.milestones.n = "junk"
		ns.db.char.milestones.people = 7
		ns.db.char.milestones.earned.nonsense = 5
		local copy = ns.db.char.milestones
		ns.db.char.milestones = { seeded = copy.seeded, earned = copy.earned, n = copy.n, people = copy.people }
		ns.Ledger.Load()
		if earned(ns, "first") ~= at then fail(scenario, "a milestone did not survive the store being read again") end
		M.Rows()
		local st = ns.db.char.milestones
		if type(st.n) ~= "table" or type(st.people) ~= "table" or st.earned.nonsense then
			fail(scenario, "a damaged store was not repaired")
		end
		-- /manners debug says where they stand.
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		local want = M.TEXT.LINE_COUNT:format(M.Tally())
		local found = false
		for _, line in ipairs(Mock.printed) do
			if tostring(line):find(want, 1, true) then found = true end
		end
		if not found then fail(scenario, "/manners debug has no line about milestones") end
		ChatFrame_OpenChat, ChatFrameUtil, SendChatMessage = realOpen, realUtil, realSend
		guarded(ns, scenario)
	end
end

-- ------------------------------------------------------------- earned 12
-- What the other features tell it, one call each; a kind nobody defined, and a
-- class that has no such thing, earn and show nothing.
Mock.reset()
do
	local scenario = "milestones: earned: a resurrection, a cure and a courtesy are told in one call each"
	local ns = load(scenario)
	if ns then
		local M = begin(ns, scenario)
		local realRes, realCures, realCourtesy, class = ns.Resurrect, ns.ClassHasCures, ns.Courtesy, ns.caps.class
		local function listed(id)
			for _, row in ipairs(M.Rows()) do
				if row.id == id then return true end
			end
			return false
		end
		ns.Resurrect = { Has = function() return false end }
		ns.ClassHasCures = function() return false end
		if listed("res") or listed("cure") then fail(scenario, "a class with no resurrection or cure is shown theirs") end
		M.Note("res")
		if earned(ns, "res") then fail(scenario, "a class with no resurrection earned one") end
		ns.db.char.milestones.n.res = 0
		ns.Resurrect = { Has = function() return true end }
		ns.ClassHasCures = function() return true end
		ns.Courtesy = {}
		ns.caps.class = "MAGE"
		for _, id in ipairs({ "res", "cure", "courtesy" }) do
			if not listed(id) then fail(scenario, id .. " is not listed for a class that can earn it") end
			if earned(ns, id) then fail(scenario, id .. " earned before anything happened") end
			M.Note(id)
			if not earned(ns, id) then fail(scenario, "Note(\"" .. id .. "\") earned nothing") end
		end
		M.Note("nonsense")
		M.Note(nil)
		if ns.db.char.milestones.n.nonsense then fail(scenario, "a kind nobody defined was counted") end
		-- With the feature gone again, what was earned stays listed.
		ns.Resurrect = nil
		if not listed("res") then fail(scenario, "an earned milestone dropped off the list with its feature") end
		ns.Resurrect, ns.ClassHasCures, ns.Courtesy, ns.caps.class = realRes, realCures, realCourtesy, class
		guarded(ns, scenario)
	end
end

-- ------------------------------------------------------------- earned 13
-- A new title, reached through the ledger's own announcement, gets a toast of
-- its own beside its line in chat.
Mock.reset()
do
	local scenario = "milestones: earned: a new title gets a toast"
	local ns = load(scenario)
	if ns then
		local M = begin(ns, scenario)
		ns.db.char.ledger.totals.returned = 9
		returnOne(ns, PETRA, 30)
		settle(ns)
		local title = ns.Ledger.TITLES[1]
		local f = toastUp(ns)
		local names = {}
		for _ = 1, 3 do
			if f and f:IsShown() then
				names[f.name:GetText()] = f.heading:GetText()
				f.scripts.OnClick(f)
			end
			Mock.advance(M.TOAST_GAP + 1)
			M.Pump()
		end
		if names[title.name] ~= M.TEXT.HEAD_TITLE then
			fail(scenario, "the new title had no toast of its own: " .. tostring(names[title.name]))
		end
		if f and f.line and not names[M.LIST[1].name] then fail(scenario, "the milestone earned beside it had none") end
		guarded(ns, scenario)
	end
end
Mock.reset()

-- ===========================================================================
-- The other features' milestones, through each feature's own path: a
-- resurrection (Resurrect.lua), a cure (Clicks.lua's settle) and a courtesy
-- (Courtesy.lua) tell the milestones once the thing is known to have happened,
-- and a cast that failed or was refused tells them nothing. Every name below
-- starts "milestones: hook:".
-- ===========================================================================

-- Globals stood in for a scenario, and the function that puts them back.
local function standIn(globals)
	local saved, names = {}, {}
	for name, value in pairs(globals) do
		names[#names + 1] = name
		saved[name] = rawget(_G, name)
		rawset(_G, name, value)
	end
	return function()
		for _, name in ipairs(names) do rawset(_G, name, saved[name]) end
	end
end

-- How many of a kind the milestones have counted.
local function counted(ns, kind)
	local st = ns.db.char.milestones
	return st and st.n and st.n[kind] or 0
end

-- ------------------------------------------------------------- hook 1
-- A resurrection: not at the press and not from a cast that was interrupted,
-- but once the cast has gone its length and the game has taken it.
Mock.reset()
do
	local scenario = "milestones: hook: a resurrection that was cast earns one, and an interrupted one nothing"
	Mock.class = "PRIEST"
	Mock.groupSize = 4
	local restoreUnits = H.strangers({ party1 = { "Anna", "Aim" }, party2 = { "Bert", "Beside" } })
	local dead = {}
	local realDead, realSpell = UnitIsDeadOrGhost, C_Spell
	local known = { [2006] = true, [2010] = true }
	local restore = standIn({
		UnitIsDeadOrGhost = function(unit)
			if unit == "player" then return realDead(unit) end
			return dead[unit] == true
		end,
		UnitIsGhost = function() return false end,
		UnitHasIncomingResurrection = function() return false end,
		UnitIsFeignDeath = function() return false end,
		UnitAffectingCombat = function() return false end,
		UnitIsVisible = function() return true end,
		UnitInParty = function(unit) return type(unit) == "string" and unit:find("^party%d") ~= nil end,
		IsSpellKnown = function(id) return known[id] == true end,
		IsPlayerSpell = function(id) return known[id] == true end,
		C_Spell = setmetatable({
			GetSpellName = function(id) return known[id] and "Resurrection" or realSpell.GetSpellName(id) end,
			IsSpellUsable = function() return true, false end,
		}, { __index = realSpell }),
	})
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		begin(ns, scenario)
		local sources = ns.db.profile.sources
		sources.strangers, sources.self = false, false
		ns.Guard("probe", ns.ProbeCapabilities)
		local ANNA = "Anna Aim"
		dead.party1 = true
		local function press(guid)
			Mock.advance(4)
			ns.addon:Tick()
			if ns.Prompt:PanelName() ~= ANNA then return false end
			H.pressButton(ns)
			if not ns.Resurrect.pending then return false end
			Mock.advance(0.5)
			ns.Resurrect.OnEvent("UNIT_SPELLCAST_SENT", "player", ANNA, guid, 2010)
			ns.Resurrect.OnEvent("UNIT_SPELLCAST_START", "player", guid, 2010)
			return true
		end
		if not press("cast-1") then
			fail(scenario, "SKIPPED -- the press on the dead member was not filed")
			return
		end
		if counted(ns, "res") ~= 0 then fail(scenario, "a resurrection was counted at the press") end
		Mock.advance(4)
		ns.Resurrect.OnEvent("UNIT_SPELLCAST_INTERRUPTED", "player", "cast-1", 2010)
		settle(ns)
		if counted(ns, "res") ~= 0 or earned(ns, "res") then
			fail(scenario, "an interrupted resurrection earned the milestone")
		end
		if not press("cast-2") then
			fail(scenario, "SKIPPED -- the second press was not filed")
			return
		end
		Mock.advance(10)
		ns.Resurrect.OnEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-2", 2010)
		if counted(ns, "res") ~= 1 then
			fail(scenario, ("a resurrection that was cast counted %d, not one"):format(counted(ns, "res")))
		end
		if not earned(ns, "res") then fail(scenario, "a resurrection that was cast did not earn the milestone") end
		guarded(ns, scenario)
	end)
	restore()
	restoreUnits()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- ------------------------------------------------------------- hook 2
-- A cure: the press settles when the client sends the cast, which the server
-- can still refuse; a refused one earns nothing, and one nothing refused
-- earns the milestone once that wait is over, not before.
Mock.reset()
do
	local scenario = "milestones: hook: a cure nothing refused earns one, and a refused one nothing"
	local MOTW, CURE_POISON = 1126, 8946
	Mock.class = "DRUID"
	Mock.groupSize = 3
	Mock.held = { [MOTW] = true }
	local restoreUnits = H.strangers({ party1 = { "Gwen", "Hale" }, party2 = { "Hugo", "Holt" } })
	local debuffs = {}
	local known = { [MOTW] = true, [CURE_POISON] = true }
	local base = C_UnitAuras
	local restore = standIn({
		IsSpellKnown = function(id) return known[id] == true end,
		IsPlayerSpell = function(id) return known[id] == true end,
		UnitInParty = function(unit) return type(unit) == "string" and unit:find("^party%d+$") ~= nil end,
		C_UnitAuras = setmetatable({
			GetAuraDataByIndex = function(unit, index, filter)
				if filter ~= "HARMFUL" then return base.GetAuraDataByIndex(unit, index, filter) end
				if not (debuffs[unit] and index == 1) then return nil end
				return { name = "Poison thing", spellId = 90000, dispelName = "Poison",
					expirationTime = Mock.now + 60, duration = 60, isHarmful = true, auraInstanceID = 9001 }
			end,
		}, { __index = base }),
	})
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		begin(ns, scenario)
		local sources = ns.db.profile.sources
		sources.group, sources.strangers, sources.self, sources.cures = true, false, false, true
		ns.Guard("probe", ns.ProbeCapabilities)
		-- The cure offered to `name`, pressed, and its cast sent under `guid`.
		local function press(name, guid)
			Mock.advance(4)
			local entry
			for _, e in ipairs(ns.BuildQueue()) do
				if e.name == name and e.cure then entry = e end
			end
			if not entry then return false end
			local button = ns.Prompt:GetButton()
			Mock.advance(1)
			ns.pendingClick = nil
			ns.Prompt:InvalidateMacro()
			ns.Prompt:ApplyTarget(entry)
			button.scripts.PostClick(button, "LeftButton", true)
			if not (ns.pendingClick and ns.pendingClick.cure) then return false end
			ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, guid, CURE_POISON)
			return ns.pendingClick == nil
		end
		debuffs.party1 = true
		if not press("Gwen Hale", "cure-1") then
			fail(scenario, "SKIPPED -- the press on the poisoned member did not settle as a cure")
			return
		end
		-- The server refuses it a moment later.
		Mock.advance(0.5)
		ns.addon:UNIT_SPELLCAST_FAILED(nil, "player", "cure-1", CURE_POISON)
		Mock.advance(3)
		ns.addon:Tick()
		settle(ns)
		if counted(ns, "cure") ~= 0 or earned(ns, "cure") then
			fail(scenario, "a cure the game refused earned the milestone")
		end
		debuffs.party1, debuffs.party2 = nil, true
		if not press("Hugo Holt", "cure-2") then
			fail(scenario, "SKIPPED -- the second press did not settle as a cure")
			return
		end
		ns.addon:Tick()
		if counted(ns, "cure") ~= 0 then
			fail(scenario, "a cure was counted the moment it was sent, while the game could still refuse it")
		end
		Mock.advance(3)
		ns.addon:Tick()
		if counted(ns, "cure") ~= 1 then
			fail(scenario, ("a cure nothing refused counted %d, not one"):format(counted(ns, "cure")))
		end
		if not earned(ns, "cure") then fail(scenario, "a cure nothing refused did not earn the milestone") end
		guarded(ns, scenario)
	end)
	restore()
	restoreUnits()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- ------------------------------------------------------------- hook 3
-- A courtesy: the portal that went out, and the water put in the trade
-- window. Another spell going out is no portal, and a trade that opened with
-- nothing put in it (the cursor was busy) is no courtesy given.
Mock.reset()
do
	local scenario = "milestones: hook: a portal cast and water put in the trade earn one, and neither failing does"
	local NAMES = { [1459] = "Arcane Intellect", [10140] = "Conjure Water", [11417] = "Portal: Orgrimmar" }
	local WATER, RUNE = 8079, 17032
	Mock.class = "MAGE"
	Mock.groupSize = 2
	local names = { party1 = { "Anna", "Aim" } }
	local restoreUnits = H.strangers(names)
	local bags = { [RUNE] = 2 }
	local trade, cursor = {}, nil
	local function slotItems()
		local list = {}
		for item, count in pairs(bags) do
			if count > 0 then list[#list + 1] = item end
		end
		table.sort(list)
		return list
	end
	local knows = function(id) return NAMES[id] ~= nil end
	local restore = standIn({
		IsSpellKnown = knows, IsPlayerSpell = knows,
		C_Spell = setmetatable({
			GetSpellName = function(id) return NAMES[id] end,
			GetSpellSubtext = function(id) return id == 10140 and "Rank 7" or nil end,
			IsSpellUsable = function() return nil end,
		}, { __index = _G.C_Spell }),
		GetItemCount = function(item) return bags[item] or 0 end,
		C_Container = {
			GetContainerNumSlots = function(bag) return bag == 0 and 16 or 0 end,
			GetContainerItemID = function(bag, slot) return bag == 0 and slotItems()[slot] or nil end,
			GetContainerItemInfo = function() return { isLocked = false } end,
			PickupContainerItem = function(_, slot) cursor = slotItems()[slot] end,
		},
		GetCursorInfo = function() if cursor then return "item", cursor end end,
		CursorHasItem = function() return cursor ~= nil end,
		ClearCursor = function() cursor = nil end,
		ClickTradeButton = function(index) trade[index], cursor = cursor, nil end,
		GetTradePlayerItemLink = function(index) return trade[index] and "link" or nil end,
		UnitGUID = function(unit) return "Player-1-" .. (unit == "NPC" and "party1" or tostring(unit)) end,
		UnitLevel = function() return 60 end,
		UnitInParty = function() return true end,
		MAX_TRADABLE_ITEMS = 6,
	})
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		begin(ns, scenario)
		local db = ns.db.profile
		db.sources.asked, db.sources.strangers, db.sources.group, db.sources.self = true, false, false, false
		db.sources.courtesyPortals, db.sources.courtesyRefresh = true, true
		-- What Anna asks for in party chat, offered at `stage` and pressed.
		local function ask(text, stage)
			ns.addon.CHAT_MSG_PARTY(ns.addon, "CHAT_MSG_PARTY", text, "Anna Aim", "Common", "", "", "", 0, 0, "", 0, 1,
				"Player-1-party1")
			local entry
			for _, e in ipairs(ns.BuildQueue()) do
				if e.name == "Anna Aim" then entry = e end
			end
			if not (entry and entry.courtesy and entry.courtesy.stage == stage) then return false end
			ns.Prompt:Refresh()
			H.pressButton(ns)
			return true
		end

		-- The portal.
		if not ask("port to org pls", "cast") then
			fail(scenario, "SKIPPED -- the party member's portal is not offered")
			return
		end
		if counted(ns, "courtesy") ~= 0 then fail(scenario, "a courtesy was counted at the press") end
		ns.Courtesy.OnEvent(nil, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 1459)
		if counted(ns, "courtesy") ~= 0 or earned(ns, "courtesy") then
			fail(scenario, "another spell going out earned the milestone for the portal asked for")
		end
		ns.Courtesy.OnEvent(nil, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-2", 11417)
		if counted(ns, "courtesy") ~= 1 then
			fail(scenario, ("the portal going out counted %d, not one"):format(counted(ns, "courtesy")))
		end
		if not earned(ns, "courtesy") then fail(scenario, "the portal going out did not earn the milestone") end

		-- The water, with some in the bags: the trade opens while the cursor
		-- holds something else, so nothing goes in.
		Mock.advance(61)
		bags[WATER] = 20
		if not ask("water pls", "trade") then
			fail(scenario, "SKIPPED -- the water in the bags is not offered as a trade")
			return
		end
		names.NPC = { "Anna", "Aim" }
		cursor = RUNE
		ns.Courtesy.OnEvent(nil, "TRADE_SHOW")
		cursor = nil
		if trade[1] then
			fail(scenario, "SKIPPED -- the water went into the trade with the cursor busy")
			return
		end
		if counted(ns, "courtesy") ~= 1 then fail(scenario, "a trade that nothing was put in counted as a courtesy") end
		-- Asked again, and this time it goes in.
		Mock.advance(61)
		if not ask("water pls", "trade") then
			fail(scenario, "SKIPPED -- the water is not offered a second time")
			return
		end
		ns.Courtesy.OnEvent(nil, "TRADE_SHOW")
		if trade[1] ~= WATER then
			fail(scenario, "SKIPPED -- the water was not put in the trade window (" .. tostring(trade[1]) .. ")")
			return
		end
		if counted(ns, "courtesy") ~= 2 then
			fail(scenario, ("the water put in the trade left the count at %d, not two"):format(counted(ns, "courtesy")))
		end
		guarded(ns, scenario)
	end)
	restore()
	restoreUnits()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end
Mock.reset()
