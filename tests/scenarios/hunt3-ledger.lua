-- The favour ledger, third bug hunt: a favour let go on purpose, today's count
-- of gifts on a busy day, a Clear or a second buff landing inside a refusal's
-- window, and an owed row's tooltip while the prompt cannot offer them.
--
-- Every scenario name starts with "hunt3 ledger:" so the mutations in
-- tests/mutations/hunt3-ledger.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load

local PETRA = "Petra Stonewell"

-- A clean ledger, after the lifecycle has run, as tests/scenarios/ledger.lua
-- starts each of its own.
local function fresh(ns)
	ns.db.char.ledger = nil
	ns.Ledger.Load()
	return ns.db.char.ledger
end

local function rowsFor(s, name, state)
	local out = {}
	for _, e in ipairs(s and s.entries or {}) do
		if e.kind == "received" and e.name == name and (state == nil or e.state == state) then
			out[#out + 1] = e
		end
	end
	return out
end

local function owedRows(s)
	local n = 0
	for _, e in ipairs(s and s.entries or {}) do
		if e.kind == "received" and e.state == "owed" then n = n + 1 end
	end
	return n
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
-- going out with a cast guid on it, which is what a late refusal names.
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

local function hover(row)
	Mock.tooltip = {}
	row.scripts.OnEnter(row)
	return table.concat(Mock.tooltip, "\n")
end

local function guarded(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- ------------------------------------------------------------------ never
-- A favour let go because the player put its giver on the never-offer list was
-- let go on purpose. Its row said "the time to return it ran out", which was
-- false, and the reason has to survive a reload like the others do. A reason
-- the ledger does not know, or none, is still the sweep's "expired".
Mock.reset()
do
	local scenario = "hunt3 ledger: a favour let go through the never-offer list says so"
	local ns = load(scenario)
	if ns then
		H.freshPrompt(ns, scenario)
		local s = fresh(ns)
		local L, T = ns.Ledger, ns.Ledger.TEXT

		L.Received({ name = "Ada None", key = 1459 })
		L.LetGo("Ada None")
		L.Received({ name = "Bea Bogus", key = 1459 })
		L.LetGo("Bea Bogus", "bogus")
		local ada, bea = rowsFor(s, "Ada None")[1], rowsFor(s, "Bea Bogus")[1]
		if not ada or ada.why ~= "expired" then
			fail(scenario, "a favour let go with no reason reads why=" .. tostring(ada and ada.why))
		end
		if not bea or bea.why ~= "expired" then
			fail(scenario, "a favour let go for a reason nobody knows reads why=" .. tostring(bea and bea.why))
		end

		L.Received({ name = PETRA, key = 1459, class = "PRIEST" })
		L.LetGo(PETRA, "never")
		local row = rowsFor(s, PETRA)[1]
		if not row or row.state ~= "letgo" then
			fail(scenario, "SKIPPED -- the favour was not let go at all: " .. tostring(row and row.state))
		else
			if row.why ~= "never" then
				fail(scenario, "a favour let go through the never-offer list reads why=" .. tostring(row.why))
			end
			if s.totals.letGo ~= 3 then
				fail(scenario, "three favours let go are counted as " .. tostring(s.totals.letGo))
			end
			ns.addon:HandleSlash("ledger")
			local window = L.Window()
			local r = window and window.rows[1]
			if not (r and r:IsShown() and r.entry == row) then
				fail(scenario, "SKIPPED -- Petra's row is not the top one on screen")
			else
				local detail = r.detail:GetText() or ""
				local want = T.LETGO_NEVER or "you put them on your never-offer list"
				if not detail:find(want, 1, true) or detail:find(T.LETGO_EXPIRED, 1, true) then
					fail(scenario, "the row of a favour let go on purpose reads: " .. detail)
				end
				local tip = hover(r)
				local wantTip = T.TIP_LETGO_NEVER or "Let go: you put them on your never-offer list."
				if not tip:find(wantTip, 1, true) or tip:find(T.TIP_LETGO_EXPIRED, 1, true) then
					fail(scenario, "the tooltip of a favour let go on purpose reads: " .. tip)
				end
			end

			local second = load(scenario)
			if second and pcall(function() second.addon:OnInitialize() end) then
				local again = rowsFor(second.db.char.ledger, PETRA)[1]
				if not again or again.why ~= "never" then
					fail(scenario, "after a reload the favour let go on purpose reads why="
						.. tostring(again and again.why))
				end
			else
				fail(scenario, "SKIPPED -- the second copy would not load")
			end
		end
		guarded(scenario, ns)
	end
end
Mock.reset()

-- ------------------------------------------------------------------ today
-- The list keeps at most a hundred gifts, and today's "You gave N buffs
-- unprompted" was counted off the list -- so a mage in a city read "100" for the
-- rest of the day while the strangers tile kept climbing. The day's count is
-- kept apart from the list, survives a reload, comes down for a gift the game
-- refused, and goes back to nothing on Clear and at midnight.
Mock.reset()
do
	local scenario = "hunt3 ledger: today's gifts are counted past a hundred"
	local realDate = date
	local ns = load(scenario)
	if ns then
		H.freshPrompt(ns, scenario)
		-- A clock on which it is three in the afternoon now, and whose days
		-- turn over at a real midnight as time goes on.
		local midnight = time() - 15 * 3600
		date = function(fmt, t)
			if fmt == "*t" then
				local into = ((t or time()) - midnight) % 86400
				return { hour = math.floor(into / 3600), min = math.floor(into % 3600 / 60),
					sec = math.floor(into % 60), year = 2026, month = 9, day = 24 }
			end
			return realDate(fmt, t)
		end
		local s = fresh(ns)
		local L, T = ns.Ledger, ns.Ledger.TEXT
		for i = 1, 150 do
			L.Settled(("Walker %d"):format(i), nil, { inGroup = false }, 1459)
			Mock.advance(3)
		end
		local given = L.Summary().given
		if given ~= 150 then
			fail(scenario, ("150 buffs given unprompted today are counted as %d"):format(given))
		end
		ns.addon:HandleSlash("ledger")
		local window = L.Window()
		local sub = window and window.subline:GetText() or ""
		if not sub:find(T.GAVE_MANY:format(150), 1, true) then
			fail(scenario, "after 150 gifts the line under the headline reads: " .. sub)
		end

		-- A gift the game refused was never given.
		local clock = GetTime()
		L.Settled("Refused Walker", nil, { inGroup = false }, 1459)
		L.Refused("Refused Walker", clock)
		given = L.Summary().given
		if given ~= 150 then
			fail(scenario, ("a refused gift on top of 150 leaves today's count at %d"):format(given))
		end

		-- A reload keeps the day's count; a damaged one is dropped, not trusted.
		local second = load(scenario)
		if second and pcall(function() second.addon:OnInitialize() end) then
			given = second.Ledger.Summary().given
			if given ~= 150 then
				fail(scenario, ("after a reload today's 150 gifts read %d"):format(given))
			end
		end
		ns.db.char.ledger.today = { day = "noon", given = -2 }
		local third = load(scenario)
		if third and pcall(function() third.addon:OnInitialize() end) then
			local ok, sum = pcall(third.Ledger.Summary)
			if not ok then
				fail(scenario, "a damaged day count broke the summary -> " .. tostring(sum))
			elseif third.db.char.ledger.today ~= nil then
				fail(scenario, "a damaged day count survived the repair")
			end
			guarded(scenario, third)
		end

		-- Clear takes today's count with it, as its tooltip says.
		fresh(ns)
		for i = 1, 5 do L.Settled(("Walker %d"):format(i), nil, { inGroup = false }, 1459) end
		L.Clear()
		given = L.Summary().given
		if given ~= 0 then fail(scenario, ("after Clear today's count reads %d"):format(given)) end

		-- And midnight does.
		for i = 1, 5 do L.Settled(("Walker %d"):format(i), nil, { inGroup = false }, 1459) end
		Mock.advance(10 * 3600)
		given = L.Summary().given
		if given ~= 0 then
			fail(scenario, ("the day after five gifts, today's count reads %d"):format(given))
		end
		L.Settled("Morning Walker", nil, { inGroup = false }, 1459)
		given = L.Summary().given
		if given ~= 1 then
			fail(scenario, ("the first gift of a new day is counted as %d"):format(given))
		end
		guarded(scenario, ns)
	end
	date = realDate
end
Mock.reset()

-- ------------------------------------------------------------------ clear
-- Clear pressed in the second between a return and the game refusing it. Clear
-- forgot the settle, so the refusal found nothing to undo: the prompt offered
-- Petra as owed again with no row behind her and the return still counted, and
-- the next return counted the favour a second time.
Mock.reset()
do
	local scenario = "hunt3 ledger: Clear inside a refusal's window keeps the undo"
	local ns = load(scenario)
	local s = ns and owedByPetra(ns, scenario)
	local entry = s and H.inQueue(ns)[PETRA]
	if s and not entry then
		fail(scenario, "SKIPPED -- Petra is owed and was not offered")
	elseif s then
		ns.addon:HandleSlash("ledger")
		local window = ns.Ledger.Window()
		pressWithGuid(ns, entry, 1459, "Cast-7")
		local row = rowsFor(s, PETRA)[1]
		if not row or row.state ~= "returned" or not window then
			fail(scenario, "SKIPPED -- the press was not recorded as a return")
		else
			window.clear.scripts.OnClick(window.clear)
			Mock.advance(0.3)
			window.clear.scripts.OnClick(window.clear)
			if #rowsFor(s, PETRA) ~= 0 then
				fail(scenario, "SKIPPED -- Clear kept the returned row")
			end
			ns.addon:UNIT_SPELLCAST_FAILED(nil, "player", "Cast-7", 1459)
			local rows = rowsFor(s, PETRA)
			if not ns.owed[PETRA] then
				fail(scenario, "SKIPPED -- Core did not put the debt back on the refusal")
			elseif #rows ~= 1 or rows[1].state ~= "owed" then
				fail(scenario, ("the prompt owes Petra again and the ledger has %d rows for her (%s)"):format(
					#rows, tostring(rows[1] and rows[1].state)))
			end
			if s.totals.returned ~= 0 then
				fail(scenario, "the refused return is still counted: " .. tostring(s.totals.returned))
			end

			Mock.advance(3)
			ns.addon:TickBody()
			local again = H.inQueue(ns)[PETRA]
			if not again then
				fail(scenario, "SKIPPED -- Petra was not offered again after the refusal")
			elseif not pressWithGuid(ns, again, 1459, "Cast-9") then
				fail(scenario, "SKIPPED -- the second press did not go out")
			elseif s.totals.received ~= 1 or s.totals.returned ~= 1 then
				fail(scenario, ("one favour returned once is counted as received %d, returned %d"):format(
					s.totals.received, s.totals.returned))
			end
		end
		guarded(scenario, ns)
	end
end
Mock.reset()

-- ------------------------------------------------------------------ rebuff
-- Petra repaid, then buffing you again before the game refuses the return: the
-- second buff opened a row of its own, the refusal reopened the first, and the
-- window read "2 favours still owed" over one debt -- one of which nothing
-- would ever close again.
Mock.reset()
do
	local scenario = "hunt3 ledger: a refusal after a second buff leaves one owed row"
	local ns = load(scenario)
	local s = ns and owedByPetra(ns, scenario)
	local entry = s and H.inQueue(ns)[PETRA]
	if s and not entry then
		fail(scenario, "SKIPPED -- Petra is owed and was not offered")
	elseif s then
		pressWithGuid(ns, entry, 1459, "Cast-9")
		local first = rowsFor(s, PETRA)[1]
		if not first or first.state ~= "returned" then
			fail(scenario, "SKIPPED -- the press was not recorded as a return")
		else
			Mock.advance(0.5)
			H.favourFrom(ns, "nameplate1", 10938, 4102)
			if not ns.owed[PETRA] or #rowsFor(s, PETRA, "owed") ~= 1 then
				fail(scenario, "SKIPPED -- the second buff was not filed as a new favour")
			else
				Mock.advance(0.5)
				ns.addon:UNIT_SPELLCAST_FAILED(nil, "player", "Cast-9", 1459)
				local open = rowsFor(s, PETRA, "owed")
				if #open ~= 1 then
					fail(scenario, ("%d rows read still owed for Petra's one debt"):format(#open))
				else
					local has = {}
					for _, id in ipairs(open[1].spells) do has[id] = true end
					if open[1].times ~= 2 or not has[1459] or not has[10938] then
						fail(scenario, ("the two buffs were not kept as one favour (times=%s, spells %s/%s)"):format(
							tostring(open[1].times), tostring(has[1459]), tostring(has[10938])))
					end
				end
				local sum = ns.Ledger.Summary()
				if sum.owed ~= 1 then
					fail(scenario, ("the window reads %d favours still owed over one debt"):format(sum.owed))
				end
				if s.totals.received ~= 1 or s.totals.returned ~= 0 then
					fail(scenario, ("one favour, not returned, is counted as received %d, returned %d"):format(
						s.totals.received, s.totals.returned))
				end
				Mock.advance(ns.db.profile.timing.reciprocateWindow + 5)
				ns.addon:TickBody()
				if ns.owed[PETRA] then
					fail(scenario, "SKIPPED -- the debt did not run out")
				elseif owedRows(s) ~= 0 then
					fail(scenario, ("the debt ran out and %d rows still read owed"):format(owedRows(s)))
				end
			end
		end
		guarded(scenario, ns)
	end
end
Mock.reset()

-- ------------------------------------------------------------------ offer
-- An owed row's tooltip said "The prompt offers them until you return it or
-- the time runs out" whatever the prompt was doing. With the addon off, the
-- owed source off, nothing to cast, a snooze running or "Not while mounted"
-- keeping the prompt away, that is a promise nothing is keeping. The control is
-- the ordinary case, where it is true.
Mock.reset()
do
	local scenario = "hunt3 ledger: an owed row does not promise an offer the prompt cannot make"
	local ns = load(scenario)
	local s = ns and owedByPetra(ns, scenario)
	if s then
		local T, p = ns.Ledger.TEXT, ns.db.profile
		ns.addon:HandleSlash("ledger")
		local window = ns.Ledger.Window()
		local r = window and window.rows[1]
		if not (r and r:IsShown() and r.entry and r.entry.name == PETRA and r.entry.state == "owed") then
			fail(scenario, "SKIPPED -- Petra's owed row is not on screen")
		else
			local tip = hover(r)
			if not tip:find(T.TIP_OWED, 1, true) then
				fail(scenario, "SKIPPED -- the control does not say the prompt offers them: " .. tip)
			end

			local function expect(case, want)
				local said = hover(r)
				if r.entry.state ~= "owed" then
					fail(scenario, ("SKIPPED -- %s, the row is no longer owed"):format(case))
				elseif said:find(T.TIP_OWED, 1, true) then
					fail(scenario, ("%s, the row still promises the prompt offers them: %s"):format(case, said))
				elseif not said:find(want, 1, true) then
					fail(scenario, ("%s, the row does not say why (%s): %s"):format(case, want, said))
				end
			end

			p.enabled = false
			expect("switched off", "switched off")
			p.enabled = true

			local realCastable = ns.CastableBuffs
			ns.CastableBuffs = function() return {} end
			expect("with nothing to cast", "nothing on this character")
			ns.CastableBuffs = realCastable

			local owedToggle = H.findOption(ns.optionsTable, "owed")
			local strangersToggle = H.findOption(ns.optionsTable, "strangers")
			if not (owedToggle and owedToggle.set and strangersToggle and strangersToggle.set) then
				fail(scenario, "SKIPPED -- no owed or strangers toggle to throw")
			else
				owedToggle.set({ "owed" }, false)
				strangersToggle.set({ "strangers" }, false)
				Mock.advance(5)
				ns.addon:Tick()
				expect("with \"People who buffed me\" off", "\"" .. H.optionText(owedToggle.name) .. "\"")
				owedToggle.set({ "owed" }, true)
				strangersToggle.set({ "strangers" }, true)
			end

			ns.addon:HandleSlash("snooze 15")
			if not ns.SnoozeLeft() then
				fail(scenario, "SKIPPED -- /manners snooze 15 did not start a snooze")
			else
				expect("snoozed", "snoozed")
			end
			ns.addon:HandleSlash("snooze off")

			local realMounted = IsMounted
			p.filters.hideMounted = true
			IsMounted = function() return true end
			expect("mounted with Not while mounted on", "mounted")
			IsMounted = realMounted
			p.filters.hideMounted = false

			tip = hover(r)
			if not tip:find(T.TIP_OWED, 1, true) then
				fail(scenario, "with everything back on, the row no longer says the prompt offers them: " .. tip)
			end
		end
		guarded(scenario, ns)
	end
end
Mock.reset()

-- ------------------------------------------------------------------ never, for real
-- The reason above was only ever given by the scenario: nothing in the addon
-- called LetGo with it. Putting somebody on the never-offer list drops their
-- debt in Core, so the sweep never saw it run out, and the row stayed "owed",
-- counted in the headline and promising an offer, until the next reload marked
-- it "the time to return it ran out". Here it goes the ways the player does it:
-- /manners never typed in lower case, and the call the prompt's shift-right-
-- click and the options box make, for somebody already on the list who buffed
-- you again. Somebody else owed is the control.
Mock.reset()
do
	local scenario = "hunt3 ledger: putting a giver on the never-offer list lets their favour go"
	local ns = load(scenario)
	local s = ns and owedByPetra(ns, scenario)
	if s then
		local L, T = ns.Ledger, ns.Ledger.TEXT
		local ADA = "Ada None"
		ns.owed[ADA] = { expires = GetTime() + 100, at = GetTime() }
		L.Received({ name = ADA, key = 1459 })

		ns.addon:HandleSlash("never petra stonewell")
		if ns.owed[PETRA] then
			fail(scenario, "SKIPPED -- /manners never did not let Petra's debt go")
		else
			local row = rowsFor(s, PETRA)[1]
			if not row or row.state ~= "letgo" or row.why ~= "never" then
				fail(scenario, ("/manners never left Petra's row %s, why=%s"):format(
					tostring(row and row.state), tostring(row and row.why)))
			end
			local sum = L.Summary()
			if sum.owed ~= 1 then
				fail(scenario, ("with one favour still owed the headline counts %d"):format(sum.owed))
			end
			if #rowsFor(s, ADA, "owed") ~= 1 then
				fail(scenario, "somebody nobody put on the list lost their owed row")
			end
			if s.totals.letGo ~= 1 then
				fail(scenario, "one favour let go is counted as " .. tostring(s.totals.letGo))
			end

			ns.addon:HandleSlash("ledger")
			local window = L.Window()
			local shown
			for _, r in ipairs(window and window.rows or {}) do
				if r:IsShown() and r.entry == row then shown = r end
			end
			if not shown then
				fail(scenario, "SKIPPED -- Petra's row is not on screen")
			else
				local tip = hover(shown)
				if not tip:find(T.TIP_LETGO_NEVER or "never-offer list", 1, true)
					or tip:find(T.TIP_OWED, 1, true) then
					fail(scenario, "the tooltip of a favour let go through the list reads: " .. tip)
				end
			end

			-- Already on the list, buffed you again, and shift-right-clicked.
			ns.owed[PETRA] = { expires = GetTime() + 100, at = GetTime() }
			L.Received({ name = PETRA, key = 1459 })
			ns.PutOnNeverList(PETRA)
			local again = rowsFor(s, PETRA, "owed")
			if ns.owed[PETRA] then
				fail(scenario, "SKIPPED -- a second shift-right-click did not let the debt go")
			elseif #again ~= 0 then
				fail(scenario, "somebody already on the list kept an owed row after the favour went")
			elseif #rowsFor(s, PETRA, "letgo") ~= 2 then
				fail(scenario, "the second favour let go through the list is not recorded as let go")
			end

			Mock.advance(ns.db.profile.timing.reciprocateWindow + 5)
			ns.addon:TickBody()
			local second = load(scenario)
			if second and pcall(function() second.addon:OnInitialize() end) then
				for _, e in ipairs(rowsFor(second.db.char.ledger, PETRA)) do
					if e.why ~= "never" then
						fail(scenario, "after the sweep and a reload Petra's favour reads why=" .. tostring(e.why))
					end
				end
			end
		end
		guarded(scenario, ns)
	end
end
Mock.reset()

-- ------------------------------------------------------------------ party-only, held back
-- A favour only a party buff can return is offered only while its giver is in
-- your party. Snoozed or mounted, the row said the prompt offers them once the
-- snooze ends or you get off -- which is not true of somebody who is not in
-- it -- where it used to say it waits on them joining. Both have to be said.
Mock.reset()
Mock.class = "WARRIOR"
Mock.raid = { size = 40, player = 1 }
Mock.unitNames = {}
for i = 1, 40 do Mock.unitNames["raid" .. i] = { "Raider" .. i, "Stone" } end
do
	local scenario = "hunt3 ledger: a party-only favour held back still says it waits on the party"
	local realKnown, realPlayer, realMounted = IsSpellKnown, IsPlayerSpell, IsMounted
	local ns = load(scenario)
	if ns then
		H.knowShout(ns)
		H.drive(scenario, ns)
		Mock.advance(60)
		wipe(ns.owed)
		wipe(ns.tried)
		local s = fresh(ns)
		H.primeAuras(ns)
		H.favourFrom(ns, "raid30", 25289)
		local row = s.entries[#s.entries]
		if not row or row.kind ~= "received" or row.state ~= "owed" or not row.partyOnly then
			fail(scenario, "SKIPPED -- the raider's favour was not filed as owed and party-only")
		else
			local T, p = ns.Ledger.TEXT, ns.db.profile
			ns.addon:HandleSlash("ledger")
			local r = ns.Ledger.Window().rows[1]
			local waits = "only while they are in it"
			local function expect(case, word, plain, want)
				local said = hover(r)
				if r.entry ~= row or row.state ~= "owed" then
					fail(scenario, ("SKIPPED -- %s, the row is no longer the owed one"):format(case))
				elseif not said:find(waits, 1, true) then
					fail(scenario, ("%s, the row no longer says it waits on the party: %s"):format(case, said))
				elseif not said:find(word, 1, true) or said:find(plain, 1, true) then
					fail(scenario, ("%s, the row does not say why in the party-only way: %s"):format(case, said))
				elseif not (want and said:find(want, 1, true)) then
					fail(scenario, ("%s, the row does not use the party-only line: %s"):format(case, said))
				end
			end

			ns.addon:HandleSlash("snooze 15")
			if not ns.SnoozeLeft() then
				fail(scenario, "SKIPPED -- /manners snooze 15 did not start a snooze")
			else
				local ends = ns.SnoozeEndsAt()
				local want = ns.PARTY_IS_SUBGROUP and T.TIP_OWED_SNOOZED_SUBGROUP or T.TIP_OWED_SNOOZED_PARTY
				expect("snoozed", "snoozed", T.TIP_OWED_SNOOZED:format(ends), want and want:format(ends))
			end
			ns.addon:HandleSlash("snooze off")

			p.filters.hideMounted = true
			IsMounted = function() return true end
			expect("mounted with Not while mounted on", "mounted", T.TIP_OWED_MOUNTED,
				ns.PARTY_IS_SUBGROUP and T.TIP_OWED_MOUNTED_SUBGROUP or T.TIP_OWED_MOUNTED_PARTY)
			IsMounted = realMounted
			p.filters.hideMounted = false

			local tip = hover(r)
			local want = ns.PARTY_IS_SUBGROUP and T.TIP_OWED_SUBGROUP or T.TIP_OWED_PARTY
			if not tip:find(want, 1, true) then
				fail(scenario, "with nothing holding the prompt back, the row reads: " .. tip)
			end
		end
		guarded(scenario, ns)
	end
	IsSpellKnown, IsPlayerSpell, IsMounted = realKnown, realPlayer, realMounted
end
Mock.reset()
