-- The favour ledger (Ledger.lua): what it writes down at each of the four
-- moments Core tells it about, what it keeps on disk and how much, what it does
-- with a file it did not write, and what the window and the summaries say.
--
-- Every favour here goes through the real path -- a buff landing on the player,
-- the prompt pressed, the game's cast events -- wherever the thing being
-- checked is that Core tells the ledger. The direct calls into Ledger are for
-- what is the ledger's alone: its bound, its repair, and its arithmetic.

local dir, H = ...
local fail, load = H.fail, H.load

local PETRA = "Petra Stonewell"

-- A clean ledger, after the lifecycle has run. Driving it can itself file a
-- favour from the mock's standing auras, so each scenario starts from nothing
-- rather than from whatever that left.
local function fresh(ns)
	ns.db.char.ledger = nil
	ns.Ledger.Load()
	return ns.db.char.ledger
end

-- The newest row, which is the one a scenario has just caused.
local function newest(s)
	return s and s.entries[#s.entries]
end

-- A favour from Petra, through the aura scan, onto a prompt ready to repay it.
local function owedByPetra(ns, scenario)
	H.freshPrompt(ns, scenario)
	local s = fresh(ns)
	H.primeAuras(ns)
	H.favourFrom(ns, "nameplate1", 1459, 4101)
	if not ns.owed[PETRA] then
		fail(scenario, "SKIPPED -- no favour was filed, so there is nothing to record")
		return nil
	end
	return s
end

-- The prompt armed at `entry` and pressed, and the game reporting the cast
-- going out with a cast guid on it -- which is what a late refusal is matched
-- by. H.pressAndSend sends none, and a refusal needs one to name.
local function pressWithGuid(ns, entry, spellId, guid)
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

-- ------------------------------------------------------------------ ledger 1
-- Somebody buffing you is written down, with who, their class and the spell.
-- A second buff from them while the first is still owed is the same favour --
-- the debt table keeps one debt per person, and one buff back repays it -- so it
-- is one row with both spells on it rather than two rows that a single return
-- could only ever close one of.
Mock.reset()
do
	local scenario = "a favour appears in the ledger"
	local ns = load(scenario)
	local s = ns and owedByPetra(ns, scenario)
	if s then
		local e = newest(s)
		if not e or e.kind ~= "received" then
			fail(scenario, "somebody buffed you and the ledger has no row for it")
		else
			if e.name ~= PETRA then fail(scenario, "filed under " .. tostring(e.name)) end
			if e.class ~= "PRIEST" then fail(scenario, "their class was not kept: " .. tostring(e.class)) end
			if e.spells[1] ~= 1459 then fail(scenario, "the spell was not kept: " .. tostring(e.spells[1])) end
			if e.state ~= "owed" then fail(scenario, "a favour just done reads " .. tostring(e.state)) end
			if s.totals.received ~= 1 then
				fail(scenario, "the lifetime count reads " .. tostring(s.totals.received) .. " after one favour")
			end
		end

		local rowsBefore = #s.entries
		Mock.advance(2)
		H.favourFrom(ns, "nameplate1", 10938, 4102)
		if #s.entries ~= rowsBefore then
			fail(scenario, "a second buff from somebody already owed became a row of its own,"
				.. " which one buff back can never close")
		elseif e and (e.times ~= 2 or e.spells[2] ~= 10938) then
			fail(scenario, ("the second buff was not folded into the favour (times=%s, second spell=%s)"):format(
				tostring(e.times), tostring(e.spells[2])))
		end
		if s.totals.received ~= 1 then
			fail(scenario, "one favour of two buffs was counted as " .. tostring(s.totals.received))
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ ledger 2
-- Pressing the prompt for somebody you owe marks their row returned, with the
-- spell that went out, and counts it.
Mock.reset()
do
	local scenario = "a favour repaid is marked returned"
	local ns = load(scenario)
	local s = ns and owedByPetra(ns, scenario)
	local entry = s and H.inQueue(ns)[PETRA]
	if s and not entry then
		fail(scenario, "SKIPPED -- Petra is owed and was not offered, so nothing can be pressed")
	elseif s then
		local row = newest(s)
		H.pressAndSend(ns, entry, 1459)
		if ns.owed[PETRA] then
			fail(scenario, "SKIPPED -- the press did not settle the debt, so the ledger has nothing to follow")
		elseif row.state ~= "returned" then
			fail(scenario, "the favour was repaid and the ledger still says " .. tostring(row.state))
		else
			if row.gave ~= 1459 then fail(scenario, "what you gave back was not kept: " .. tostring(row.gave)) end
			if type(row.doneAt) ~= "number" then fail(scenario, "when it was returned was not kept") end
			if s.totals.returned ~= 1 then
				fail(scenario, "the lifetime returned count reads " .. tostring(s.totals.returned))
			end
			-- A repayment is not also a buff given unprompted.
			if s.totals.strangers ~= 0 or s.totals.group ~= 0 then
				fail(scenario, "a repayment was counted as a buff given unprompted as well")
			end
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ ledger 3
-- The game refusing, after the fact, a cast the settle already counted. Core
-- puts the debt back; the row goes back to owed and the count comes down. And a
-- buff given unprompted that the game refused was never given, so its row goes.
Mock.reset()
do
	local scenario = "a refused cast puts the ledger back"
	local ns = load(scenario)
	local s = ns and owedByPetra(ns, scenario)
	local entry = s and H.inQueue(ns)[PETRA]
	if s and not entry then
		fail(scenario, "SKIPPED -- Petra is owed and was not offered")
	elseif s then
		local row = newest(s)
		pressWithGuid(ns, entry, 1459, "Cast-7")
		if row.state ~= "returned" then
			fail(scenario, "SKIPPED -- the press was not recorded as a return, so there is nothing to undo")
		else
			ns.addon:UNIT_SPELLCAST_FAILED(nil, "player", "Cast-7", 1459)
			if not ns.owed[PETRA] then
				fail(scenario, "SKIPPED -- Core did not put the debt back on the refusal")
			elseif row.state ~= "owed" then
				fail(scenario, "the game refused the cast and the ledger still says the favour was "
					.. tostring(row.state))
			elseif s.totals.returned ~= 0 then
				fail(scenario, "the refused return is still counted: " .. tostring(s.totals.returned))
			elseif row.gave ~= nil then
				fail(scenario, "the row still names a spell that never arrived")
			end
		end

		-- A gift the game refused.
		Mock.advance(60)
		wipe(ns.owed)
		wipe(ns.tried)
		ns.pendingClick = nil
		local stranger = H.inQueue(ns)[PETRA]
		local rows = #s.entries
		if not stranger then
			fail(scenario, "SKIPPED -- nobody was offered for the gift half")
		elseif not pressWithGuid(ns, stranger, 1459, "Cast-8") or #s.entries ~= rows + 1 then
			fail(scenario, "SKIPPED -- the gift was not recorded, so there is nothing to undo")
		else
			ns.addon:UNIT_SPELLCAST_FAILED(nil, "player", "Cast-8", 1459)
			if #s.entries ~= rows then
				fail(scenario, "a buff the game refused is still listed as given")
			end
			if s.totals.strangers ~= 0 then
				fail(scenario, "a buff the game refused is still counted: " .. tostring(s.totals.strangers))
			end
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ ledger 4
-- A debt that runs out before it is returned is let go, the moment the sweep
-- lets it go -- not left reading "still owed" under a prompt that has stopped
-- offering them.
Mock.reset()
do
	local scenario = "a favour that runs out is let go"
	local ns = load(scenario)
	local s = ns and owedByPetra(ns, scenario)
	if s then
		local row = newest(s)
		Mock.advance(ns.db.profile.timing.reciprocateWindow + 5)
		ns.addon:TickBody()
		if ns.owed[PETRA] then
			fail(scenario, "SKIPPED -- the sweep did not let the debt go")
		elseif row.state ~= "letgo" then
			fail(scenario, "the debt ran out and the ledger still says " .. tostring(row.state))
		else
			if row.why ~= "expired" then fail(scenario, "let go for " .. tostring(row.why)) end
			if s.totals.letGo ~= 1 then fail(scenario, "let go counted " .. tostring(s.totals.letGo)) end
		end
		if ns.Ledger.Headline() ~= ns.Ledger.TEXT.TODAY_ONE:format(0) then
			fail(scenario, "the headline over one favour let go reads: " .. ns.Ledger.Headline())
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ ledger 5
-- A favour still owed at logout. Its row comes back owed when the debt comes
-- back with it, and is let go when the debt ran out while you were away:
-- listing it as owed would be a row promising the prompt offers somebody the
-- prompt has forgotten.
Mock.reset()
do
	local scenario = "a favour owed at logout is let go when its debt did not come back"
	local ns = load(scenario)
	local s = ns and owedByPetra(ns, scenario)
	if s then
		ns.addon:SaveDebts()
		Mock.advance(30)
		local second = load(scenario)
		if second and pcall(function() second.addon:OnInitialize() end) then
			local row = newest(second.db.char.ledger)
			if not second.owed[PETRA] then
				fail(scenario, "SKIPPED -- the debt did not survive a thirty-second logout")
			elseif not row or row.state ~= "owed" then
				fail(scenario, "a favour whose debt came back is listed as " .. tostring(row and row.state))
			end
			second.addon:SaveDebts()
		end
		Mock.advance(ns.db.profile.timing.reciprocateWindow + 60)
		local third = load(scenario)
		if third and pcall(function() third.addon:OnInitialize() end) then
			local row = newest(third.db.char.ledger)
			if third.owed[PETRA] then
				fail(scenario, "SKIPPED -- a debt older than the window came back")
			elseif not row or row.state ~= "letgo" then
				fail(scenario, "a favour whose debt ran out while you were away is listed as "
					.. tostring(row and row.state))
			elseif row.why ~= "expired" then
				fail(scenario, "let go at login for " .. tostring(row.why))
			end
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ ledger 6
-- Buffs given to somebody who had not buffed you are filed under the group or
-- under strangers, by whether they were in the group -- which the prompt has to
-- carry from the queue to the settle, since the settle has no unit to ask.
Mock.reset()
do
	local scenario = "buffs given unprompted are filed under group or strangers"
	local ns = load(scenario)
	if ns then
		H.freshPrompt(ns, scenario)
		local s = fresh(ns)
		local stranger = H.inQueue(ns)[PETRA]
		if not stranger then
			fail(scenario, "SKIPPED -- nobody was offered")
		else
			H.pressAndSend(ns, stranger, 1459)
			local row = newest(s)
			if not row or row.kind ~= "given" then
				fail(scenario, "a buff given to a passer-by was not recorded")
			elseif row.to ~= "stranger" or s.totals.strangers ~= 1 then
				fail(scenario, ("a passer-by was filed under %s (strangers %d)"):format(
					tostring(row.to), s.totals.strangers))
			elseif row.spell ~= 1459 or row.class ~= "PRIEST" then
				fail(scenario, "what was given, or to which class, was not kept")
			end
		end

		Mock.groupSize = 4
		Mock.advance(60)
		wipe(ns.tried)
		ns.pendingClick = nil
		local member = H.inQueue(ns)[PETRA]
		if not member or not member.inGroup then
			fail(scenario, "SKIPPED -- the group member was not offered as one")
		else
			H.pressAndSend(ns, member, 1459)
			local row = newest(s)
			if not row or row.kind ~= "given" or row.to ~= "group" then
				fail(scenario, "a buff given to a group member was filed under "
					.. tostring(row and row.to))
			elseif s.totals.group ~= 1 then
				fail(scenario, "the group count reads " .. tostring(s.totals.group))
			end
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ ledger 7
-- The list on disk is bounded, and buffs given unprompted cannot crowd the
-- favours out of it: a mage in a city buffs a stranger every few seconds. The
-- lifetime counts are not trimmed with it, and a favour still owed is never
-- trimmed at all -- its settle is on its way, and one that finds no row makes a
-- new one and counts the favour twice.
Mock.reset()
do
	local scenario = "the ledger keeps to its bound"
	local ns = load(scenario)
	if ns then
		H.freshPrompt(ns, scenario)
		local s = fresh(ns)
		local L = ns.Ledger
		L.Received({ name = "Owed Early", key = 1459 })
		-- The favours first and the flood of gifts after them, which is the
		-- order a city produces and the one that would push every favour out.
		for i = 1, 150 do
			L.Received({ name = ("Useless %d"):format(i), key = 1459 }, true)
		end
		for i = 1, 150 do
			L.Settled(("Stranger %d"):format(i), nil, { inGroup = false }, 1459)
		end
		local given, favours, owedEarly = 0, 0, false
		for _, e in ipairs(s.entries) do
			if e.kind == "given" then given = given + 1 else favours = favours + 1 end
			if e.name == "Owed Early" then owedEarly = true end
		end
		if #s.entries > 200 then
			fail(scenario, ("%d rows kept, over the bound of 200"):format(#s.entries))
		end
		if given > 100 then
			fail(scenario, ("%d buffs given unprompted kept, over their share of 100"):format(given))
		end
		if favours < 100 then
			fail(scenario, ("only %d favours kept: the gifts after them crowded them out"):format(favours))
		end
		if not owedEarly then
			fail(scenario, "a favour still owed was trimmed off the end of the list")
		end
		local last = s.entries[#s.entries]
		if not last or last.name ~= "Stranger 150" then
			fail(scenario, "the newest row is not the last one recorded: " .. tostring(last and last.name))
		end
		for _, e in ipairs(s.entries) do
			if e.name == "Useless 1" or e.name == "Stranger 1" then
				fail(scenario, "the oldest rows survived the trim: " .. e.name)
				break
			end
		end
		if s.totals.received ~= 151 or s.totals.strangers ~= 150 then
			fail(scenario, ("the lifetime counts were trimmed with the list: received %d, strangers %d"):format(
				s.totals.received, s.totals.strangers))
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ ledger 8
-- A character with no ledger at all, one whose ledger is not even a table, and
-- one whose file is damaged in every way a file can be. All three log in
-- cleanly, and what survives is only what can be trusted.
for _, case in ipairs({
	{ label = "none" },
	{ label = "not a table", ledger = "a string where the ledger should be" },
	{ label = "damaged", ledger = {
		entries = {
			"junk",
			{ kind = "received", name = 123, at = 1699990000 },
			{ kind = "given", name = "Bad|cffff0000Name", at = 1699990100 },
			{ kind = "received", name = "Late Row", at = "yesterday" },
			{ kind = "received", name = "Iris Quill", at = 1699990300, state = "bogus",
				spells = { "x", 1459 }, times = -4, class = "not a class" },
			{ kind = "given", name = "Tomas Reed", at = 1699990200, to = "party", spell = 1.5 },
			{ kind = "stolen", name = "Nobody", at = 1699990000 },
		},
		totals = { received = "lots", returned = -3, group = 1 / 0, extra = 99 },
		window = { point = "NOWHERE", relPoint = "CENTER", x = "a", y = 0 },
		filter = 42,
	} },
}) do
	Mock.reset()
	Mock.sv = { char = { ledger = case.ledger } }
	local scenario = "a character with a ledger that is " .. case.label .. " loads"
	local ns = load(scenario)
	if ns then
		H.drive(scenario, ns)
		ns.Prompt:ExitTest()
		local s = ns.db.char.ledger
		if type(s) ~= "table" or type(s.entries) ~= "table" or type(s.totals) ~= "table" then
			fail(scenario, "the ledger was not made usable at login")
		else
			for _, key in ipairs({ "received", "returned", "letGo", "group", "strangers" }) do
				local v = s.totals[key]
				if type(v) ~= "number" or v ~= v or v < 0 or v == math.huge or v ~= math.floor(v) then
					fail(scenario, ("the %s count is %s"):format(key, tostring(v)))
				end
			end
			if s.totals.extra ~= nil then fail(scenario, "an unknown count survived the repair") end
			if s.filter ~= "all" then fail(scenario, "the tab is " .. tostring(s.filter)) end
			if s.window ~= nil then fail(scenario, "a position no anchor names survived") end
		end
		if case.label == "damaged" and type(s) == "table" and type(s.entries) == "table" then
			local names = {}
			for _, e in ipairs(s.entries) do names[#names + 1] = tostring(e.name) end
			local joined = table.concat(names, ", ")
			if #s.entries ~= 2 then
				fail(scenario, "kept " .. #s.entries .. " rows, wanted Tomas Reed and Iris Quill: " .. joined)
			elseif s.entries[1].name ~= "Tomas Reed" or s.entries[2].name ~= "Iris Quill" then
				fail(scenario, "the surviving rows are not oldest first: " .. joined)
			else
				local iris, tomas = s.entries[2], s.entries[1]
				if iris.state ~= "letgo" then
					fail(scenario, "a favour in a state nobody wrote reads " .. tostring(iris.state))
				end
				if iris.spells[1] ~= 1459 or iris.spells[2] ~= nil then
					fail(scenario, "the spell list was not cleaned")
				end
				if iris.times ~= 1 or iris.class ~= nil then
					fail(scenario, "a nonsense count or class survived")
				end
				if tomas.to ~= "stranger" or tomas.spell ~= nil then
					fail(scenario, "a gift's destination or spell was not cleaned")
				end
			end
			if joined:find("|", 1, true) then
				fail(scenario, "a name carrying a chat escape was kept: " .. joined)
			end
			-- The counts never read lower than the list in front of them.
			if s.totals.received < 1 or s.totals.strangers < 1 or s.totals.returned ~= 0 then
				fail(scenario, ("the counts do not cover the list: received %s, strangers %s,"
					.. " returned %s"):format(tostring(s.totals.received),
					tostring(s.totals.strangers), tostring(s.totals.returned)))
			end
		end
		-- And the window opens on whatever is left.
		local ok, err = pcall(function() ns.addon:HandleSlash("log") end)
		local window = ns.Ledger.Window()
		if not ok then
			fail(scenario, "/manners log threw -> " .. tostring(err))
		elseif not (window and window:IsShown()) then
			fail(scenario, "/manners log did not open the window")
		end
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ ledger 9
-- The window lists what happened, newest first, class-coloured, with each
-- row's state in words; its tabs filter; its Clear takes two presses and keeps
-- the favours still owed; and it scrolls.
Mock.reset()
do
	local scenario = "the ledger window lists entries"
	local ns = load(scenario)
	if ns then
		H.freshPrompt(ns, scenario)
		local s = fresh(ns)
		local L = ns.Ledger
		L.Received({ name = "Iris Quill", key = 1459, class = "PRIEST" })
		Mock.advance(90)
		L.Received({ name = "Tomas Reed", key = 10938, class = "MAGE" })
		L.Settled("Iris Quill", { at = GetTime() - 90 }, { buffKey = "intellect" }, 1459)

		ns.addon:HandleSlash("log")
		local window = L.Window()
		if not (window and window:IsShown()) then
			fail(scenario, "/manners log did not open the window")
		else
			local rows = window.rows
			local first, second = rows[1].name:GetText() or "", rows[2].name:GetText() or ""
			if not first:find("Tomas Reed", 1, true) or not second:find("Iris Quill", 1, true) then
				fail(scenario, ("the rows are not newest first: %q then %q"):format(first, second))
			end
			if not first:find("|cff40c7eb", 1, true) then
				fail(scenario, "a mage's name is not in the mage's colour: " .. first)
			end
			if not (rows[1].detail:GetText() or ""):find(L.TEXT.STATE_OWED, 1, true) then
				fail(scenario, "the owed row does not say so: " .. tostring(rows[1].detail:GetText()))
			end
			if not (rows[2].detail:GetText() or ""):find(L.TEXT.STATE_RETURNED, 1, true) then
				fail(scenario, "the returned row does not say so: " .. tostring(rows[2].detail:GetText()))
			end
			if rows[3]:IsShown() then fail(scenario, "a third row is showing for two entries") end
			if rows[2].when:GetText() ~= "2 min ago" then
				fail(scenario, "a favour ninety seconds old reads " .. tostring(rows[2].when:GetText()))
			end
			if window.headline:GetText() ~= L.TEXT.TODAY_MANY:format(1, 2) then
				fail(scenario, "the headline reads " .. tostring(window.headline:GetText()))
			end
			local tiles = {}
			for _, stat in ipairs(window.stats) do tiles[stat.key] = stat.value:GetText() end
			if tiles.received ~= "2" or tiles.returned ~= "1" or tiles.group ~= "0"
				or tiles.strangers ~= "0" then
				fail(scenario, ("the all-time tiles read %s received, %s returned, %s group,"
					.. " %s strangers"):format(tostring(tiles.received), tostring(tiles.returned),
					tostring(tiles.group), tostring(tiles.strangers)))
			end
			if window.showing:GetText() ~= L.TEXT.SHOWING:format(1, 2, 2) then
				fail(scenario, "the footer reads " .. tostring(window.showing:GetText()))
			end

			-- The row tooltip tells the whole story.
			rows[2].scripts.OnEnter(rows[2])
			local tip = table.concat(Mock.tooltip, "\n")
			if not tip:find("You returned it", 1, true) then
				fail(scenario, "the returned row's tooltip does not say it was returned: " .. tip)
			end

			-- The tabs.
			local given
			for _, tab in ipairs(window.tabs) do if tab.key == "given" then given = tab end end
			given.scripts.OnClick(given)
			if rows[1]:IsShown() or not window.empty:IsShown() then
				fail(scenario, "the buffs-you-gave tab shows favours, or no empty line")
			end
			for _, tab in ipairs(window.tabs) do
				if tab.key == "all" then tab.scripts.OnClick(tab) end
			end

			-- Clear, which is two presses.
			window.clear.scripts.OnClick(window.clear)
			if #s.entries ~= 2 then fail(scenario, "one press of Clear emptied the list") end
			window.clear.scripts.OnClick(window.clear)
			if #s.entries ~= 1 or s.entries[1].name ~= "Tomas Reed" then
				fail(scenario, "Clear did not keep the favour still owed and only that: "
					.. #s.entries .. " rows")
			end
			if s.totals.received ~= 2 or s.totals.returned ~= 1 then
				fail(scenario, "Clear took the all-time counts with the list")
			end

			-- Scrolling.
			for i = 1, 20 do L.Settled(("Walker %d"):format(i), nil, { inGroup = false }, 1459) end
			L.Scroll(5)
			local list = L.Entries("all")
			if rows[1].entry ~= list[6] then
				fail(scenario, "scrolling five rows down does not show the sixth entry on top")
			end
			if not window.thumb:IsShown() then fail(scenario, "a list longer than the window has no scroll bar") end
			L.Scroll(100)
			if rows[#rows].entry ~= list[#list] then
				fail(scenario, "scrolling past the end does not stop at the last entry")
			end

			ns.addon:HandleSlash("log")
			if window:IsShown() then fail(scenario, "/manners log a second time did not close it") end
		end
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ ledger 10
-- The counts: today's from the list, by the calendar day, and the lifetime ones
-- from the totals -- in the window, on the minimap tooltip and on the General
-- tab, which must all say the same thing.
Mock.reset()
do
	local scenario = "the ledger summary counts are right"
	local realDate = date
	local ns = load(scenario)
	if ns then
		H.freshPrompt(ns, scenario)
		fresh(ns)
		local L = ns.Ledger
		-- Yesterday: a favour returned and a stranger buffed.
		L.Received({ name = "Ada Early", key = 1459 })
		L.Settled("Ada Early", { at = GetTime() }, {}, 1459)
		L.Settled("Stranger Early", nil, { inGroup = false }, 1459)
		Mock.advance(6600)
		-- Today: one returned, one still owed, one nothing could be done for,
		-- and a group member buffed.
		L.Received({ name = "Bea Returned", key = 1459 })
		L.Settled("Bea Returned", { at = GetTime() }, {}, 1459)
		Mock.advance(300)
		L.Received({ name = "Cal Owed", key = 1459 })
		Mock.advance(300)
		L.Received({ name = "Dee Useless", key = 1459 }, true)
		L.Settled("Gus Member", nil, { inGroup = true }, 1459)
		-- One in the morning, so today began an hour ago and Ada's row, two
		-- hours old, was yesterday.
		date = function(fmt, t)
			if fmt == "*t" then return { hour = 1, min = 0, sec = 0, year = 2026, month = 9, day = 24 } end
			return realDate(fmt, t)
		end

		local sum = L.Summary()
		if sum.received ~= 3 or sum.returned ~= 1 or sum.given ~= 1 or sum.owed ~= 1 then
			fail(scenario, ("today reads received %d, returned %d, given %d, owed %d;"
				.. " wanted 3, 1, 1, 1"):format(sum.received, sum.returned, sum.given, sum.owed))
		end
		local headline = L.TEXT.TODAY_MANY:format(1, 3)
		if L.Headline() ~= headline then fail(scenario, "the headline reads " .. L.Headline()) end
		local lifetime = L.TEXT.LIFETIME:format(4, 2, 1, 1)
		if L.Lifetime() ~= lifetime then fail(scenario, "the lifetime line reads " .. L.Lifetime()) end

		ns.addon:HandleSlash("log")
		local window = L.Window()
		local sub = window and window.subline:GetText() or ""
		if not sub:find(L.TEXT.OWED_ONE, 1, true) or not sub:find(L.TEXT.GAVE_ONE, 1, true) then
			fail(scenario, "the line under the headline reads: " .. sub)
		end

		local lines = {}
		local tt = { AddLine = function(_, text) lines[#lines + 1] = tostring(text) end }
		if Mock.broker and Mock.broker.OnTooltipShow then
			pcall(Mock.broker.OnTooltipShow, tt)
			local said = table.concat(lines, "\n")
			if not said:find(headline, 1, true) or not said:find(lifetime, 1, true) then
				fail(scenario, "the minimap tooltip does not carry the summary: " .. said)
			end
		else
			fail(scenario, "SKIPPED -- no launcher to read")
		end

		local summary = H.findOption(ns.optionsTable, "ledgerSummary")
		local text = summary and H.optionText(summary.name) or ""
		if not text:find(headline, 1, true) or not text:find(lifetime, 1, true) then
			fail(scenario, "the General tab does not carry the summary: " .. text)
		end
		local open = H.findOption(ns.optionsTable, "ledgerOpen")
		if window then window:Hide() end
		if open and open.func then open.func() end
		if not (window and window:IsShown()) then
			fail(scenario, "Open the ledger on the General tab did not open it")
		end
	end
	date = realDate
end
Mock.reset()

-- ------------------------------------------------------------------ ledger 11
-- A name the client withholds is never kept. The ledger reads issecretvalue
-- once at load, as Core does, so the stand-in secret -- a plain string the
-- client is pretending it may not show -- is in place before the file loads.
Mock.reset()
do
	local scenario = "the ledger never keeps a secret name"
	local realSecret = issecretvalue
	issecretvalue = function(v) return v == "Hidden Name" or realSecret(v) end
	local ns = load(scenario)
	issecretvalue = realSecret
	if ns then
		H.freshPrompt(ns, scenario)
		local s = fresh(ns)
		local L = ns.Ledger
		L.Received({ name = "Hidden Name", key = 1459 })
		L.Received({ name = Mock.SECRET, key = 1459 })
		L.Settled("Hidden Name", nil, { inGroup = false }, 1459)
		L.Settled(Mock.SECRET, nil, { inGroup = false }, 1459)
		if #s.entries ~= 0 then
			fail(scenario, ("%d rows were written for names the client withheld"):format(#s.entries))
		end
		if s.totals.received ~= 0 or s.totals.strangers ~= 0 then
			fail(scenario, "a withheld name was counted")
		end
		-- The control: an ordinary name is kept, so the silence above is about
		-- the secret and not a ledger that writes nothing.
		L.Received({ name = "Iris Quill", key = 1459 })
		if #s.entries ~= 1 then fail(scenario, "SKIPPED -- the control name was not kept either") end
	end
end
Mock.reset()

-- ------------------------------------------------------------------ ledger 12
-- Shift-clicking the minimap button opens the ledger; a plain click is still
-- the options window, as it always was.
Mock.reset()
do
	local scenario = "shift-clicking the minimap button opens the ledger"
	local ns = load(scenario)
	if ns then
		H.freshPrompt(ns, scenario)
		local realShift = IsShiftKeyDown
		IsShiftKeyDown = function() return true end
		if not (Mock.broker and Mock.broker.OnClick) then
			fail(scenario, "SKIPPED -- no launcher to click")
		else
			Mock.broker.OnClick(nil, "LeftButton")
			local window = ns.Ledger.Window()
			if not (window and window:IsShown()) then
				fail(scenario, "shift-click did not open the ledger")
			end
			IsShiftKeyDown = function() return false end
			Mock.broker.OnClick(nil, "LeftButton")
			if not window or not window:IsShown() then
				fail(scenario, "a plain click toggled the ledger instead of opening the options")
			end
		end
		IsShiftKeyDown = realShift
	end
end
Mock.reset()
