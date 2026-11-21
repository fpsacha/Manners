-- Hunt 3 of the day's work, the options window and the milestones
-- (Options/Window/WindowSearch.lua, WindowPage.lua, Layout.lua, Widgets.lua,
-- WindowChrome.lua, Milestones.lua, Ledger.lua, Clicks.lua).
--
-- Search does not say "turn on" a switch that is on already, or one that
-- would show nothing to this class; the line over the fine print is not drawn
-- over the hall of fame; what Show spell icon governs goes with it; a greyed
-- button still runs its tooltip; a raid is everybody by the buff, whichever of
-- its spells reached them, the one a group cast was aimed at included; the
-- week without a debt outlasts the rows the ledger drops; and a toast steps
-- aside when the prompt comes up under it.
--
-- Every name below starts "hunt3-menu-milestones:".

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local P = "hunt3-menu-milestones: "

local function guarded(ns, scenario)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- One session with the options window open on `page`, as `class`.
local function session(scenario, class, page, body)
	Mock.reset()
	if class then Mock.class = class end
	FT.install()
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		drive(scenario, ns)
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.Prompt:ExitTest()
		ns.OpenOptions(page, true)
		ns.Prompt:ExitTest()
		body(ns, ns.WindowUI)
		guarded(ns, scenario)
	end)
	FT.uninstall()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- The search result that leads to `path` through its switch, or nil.
local function found(UI, words, path)
	UI.search.box:SetText(words)
	UI.RunSearch()
	for _, f in ipairs(UI.search.found) do
		if f.ref.via == path then return f end
	end
	return nil
end

-- ------------------------------------------------------------------ 1
-- A control found behind its switch is one that switch would show. A mage's
-- portals are not a priest's, whatever People who ask me in chat says.
do
	local scenario = P .. "search offers a courtesy only to the class that has it"
	session(scenario, "MAGE", "general", function(ns, UI)
		if not (UI.search and UI.search.box) then
			fail(scenario, "SKIPPED -- no search box")
			return
		end
		ns.db.profile.sources.asked = false
		ns.RefreshOptionsDisplay()
		local hit = found(UI, ns.L["Portals, when my group asks"], "who.courtesyPortals")
		if not (hit and hit.first and hit.ref.path == "who.asked") then
			fail(scenario, "SKIPPED -- a mage with the switch off is not led to it for the portals")
		end
		if found(UI, ns.L["Healthstones, when they ask"] or "Healthstone", "who.courtesyHealthstones") then
			fail(scenario, "a mage is told to turn a switch on for a warlock's healthstones")
		end
	end)
	session(scenario, "PRIEST", "general", function(ns, UI)
		if not (UI.search and UI.search.box) then return end
		ns.db.profile.sources.asked = false
		ns.RefreshOptionsDisplay()
		if not UI.Item("who.asked") or UI.Hidden(UI.Item("who.asked")) then
			fail(scenario, "SKIPPED -- a priest has no People who ask me in chat")
			return
		end
		local hit = found(UI, ns.L["Portals, when my group asks"], "who.courtesyPortals")
		if hit then
			fail(scenario, "a priest is told to turn on " .. tostring(hit.first) .. " for a mage's portals")
		end
	end)
end

-- ...and the switch is off. The lines mixed in are hidden by the line set
-- too: with Say a line on and another set chosen, there is nothing to turn on.
do
	local scenario = P .. "search does not say to turn on a switch that is on"
	session(scenario, "MAGE", "general", function(ns, UI)
		if not (UI.search and UI.search.box) then
			fail(scenario, "SKIPPED -- no search box")
			return
		end
		local speech = ns.db.profile.speech
		local words = ns.L["My own lines, mixed in with In character"]
		speech.enabled = true
		if ns.InCharacter.Active(speech) then speech.presetChoice = "plain" end
		if ns.InCharacter.Active(speech) then
			fail(scenario, "SKIPPED -- In character is still the set")
			return
		end
		ns.RefreshOptionsDisplay()
		if not UI.Hidden(UI.Item("click.mixedLines")) then
			fail(scenario, "SKIPPED -- the lines mixed in are shown without In character")
			return
		end
		local hit = found(UI, words, "click.mixedLines")
		if hit then
			fail(scenario, "with Say a line on, the result says: turn on " .. tostring(hit.first) .. " first")
		end
		-- By the switch alone, whatever else the layout knows of the control:
		-- one hidden with its switch on is hidden for a reason the switch is not.
		local also = ns.WindowLayout.parentsIf
		local rule = also["click.mixedLines"]
		also["click.mixedLines"] = nil
		hit = found(UI, words, "click.mixedLines")
		also["click.mixedLines"] = rule
		if hit then
			fail(scenario, "a control hidden with its switch on is found behind it: turn on " .. tostring(hit.first) .. " first")
		end
		-- Line set, hidden by the switch alone, is still found while it is off.
		speech.enabled = false
		ns.RefreshOptionsDisplay()
		if not found(UI, ns.L["Line set"], "click.preset") then
			fail(scenario, "SKIPPED -- Line set is not found while Say a line is off")
		end
		-- And with it off, the lines mixed in wait for the set as well.
		if found(UI, words, "click.mixedLines") then
			fail(scenario, "Say a line off and another set: turning it on would show no lines mixed in")
		end
	end)
end

-- ------------------------------------------------------------------ 2
-- The line over a page's folds introduces fine print. The hall of fame is a
-- fold with no setting in it: nothing is drawn over it on Start here.
do
	local scenario = P .. "no fine-print caption over the hall of fame on Start here"
	session(scenario, "MAGE", "general", function(ns, UI)
		local w = UI.Where("general.hallNote")
		if not (w and w.sec.fold and w.sec.visible) then
			fail(scenario, "SKIPPED -- the hall of fame is no fold drawn on Start here")
			return
		end
		local cap = UI.Model("general").caption
		if not cap then
			fail(scenario, "SKIPPED -- the page has no caption to show or hide")
		elseif cap.text:IsShown() then
			fail(scenario, "Start here draws over the hall of fame: " .. tostring(cap.text:GetText()))
		end
	end)
	session(scenario, "MAGE", "appearance", function(ns, UI)
		local cap = UI.Model("appearance").caption
		if not (cap and cap.text:IsShown()) then
			fail(scenario, "SKIPPED -- Look draws no caption over its folds")
		end
	end)
end

-- ------------------------------------------------------------------ 3
-- Everything Show spell icon governs is indented straight under it, so it is
-- not drawn while the icon is off; the gryphons, which go by the look, stay.
do
	local scenario = P .. "with Show spell icon off, its sub-options are not drawn"
	session(scenario, "MAGE", "appearance", function(ns, UI)
		local prompt = ns.db.profile.prompt
		-- Round the icon off is with the look's own settings (the look decides
		-- it), greyed there with the icon off, saying why.
		local governed = { "appearance.iconSize", "appearance.iconFrame", "appearance.showCooldown" }
		local function shown(path)
			local w = UI.Where(path)
			return w ~= nil and UI.EntryShown(w.e)
		end
		prompt.showIcon = true
		ns.RefreshOptionsDisplay()
		for _, path in ipairs(governed) do
			if not shown(path) then fail(scenario, "SKIPPED -- " .. path .. " is not drawn with the icon on") end
		end
		local gryphons = shown("appearance.gryphons")
		prompt.showIcon = false
		ns.RefreshOptionsDisplay()
		for _, path in ipairs(governed) do
			if shown(path) then fail(scenario, path .. " is still drawn, greyed, with Show spell icon off") end
		end
		if shown("appearance.gryphons") ~= gryphons then
			fail(scenario, "Gryphons at the ends went with the icon, which does not govern it")
		end
		local w = UI.Where("appearance.gryphons")
		if w and w.e.parent then fail(scenario, "Gryphons at the ends is indented under " .. tostring(w.e.parent.path)) end
	end)
end

-- ------------------------------------------------------------------ 8
-- A greyed button is a disabled one, and the client runs no OnEnter on it
-- unless told to: every button with a tooltip is told.
do
	local scenario = P .. "a greyed button still runs its tooltip"
	session(scenario, "MAGE", "general", function(ns, UI)
		local row = UI.RowFor("general.verbose")
		if not (row and row.hit and row.hit:GetScript("OnEnter")) then
			fail(scenario, "SKIPPED -- no switch with a tooltip on Start here")
		elseif not (row.hit._ft and row.hit._ft.motionWhileDisabled) then
			fail(scenario, "a switch's button runs no OnEnter while it is disabled")
		end
		local move = UI.header and UI.header.move
		if not (move and move:GetScript("OnEnter")) then
			fail(scenario, "SKIPPED -- no Move the prompt in the header")
		elseif not (move._ft and move._ft.motionWhileDisabled) then
			fail(scenario, "Move the prompt runs no OnEnter while it is disabled, which is in a fight")
		end
	end)
end

---------------------------------------------------------------------------
-- milestones
---------------------------------------------------------------------------

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

local function settle(ns)
	Mock.runTimers(ns.Ledger.PROMOTE_SECONDS + 1)
end

-- One favour from `name` and one returned `wait` seconds later.
local function returnOne(ns, name, wait)
	ns.Ledger.Received({ name = name, class = "PRIEST", key = 1459 })
	Mock.advance(wait)
	ns.Ledger.Settled(name, { at = GetTime() - wait }, { buffKey = "intellect" }, 1459)
end

-- The calendar by the mock's clock: a day is 86400 seconds of it.
local function calendar()
	local real = date
	date = function(fmt, t)
		if fmt == "%Y%m%d" then return tostring(math.floor((t or time()) / 86400)) end
		if fmt == "%Y-%m-%d" then return "day " .. tostring(math.floor((t or time()) / 86400)) end
		return real(fmt, t)
	end
	return function() date = real end
end

local function raider(i) return "Raider " .. string.char(64 + i) .. "a" end

local function forget(ns)
	ns.db.char.milestones.earned.raid = nil
	ns.db.char.milestones.n.raid = 0
	Mock.advance(1200)
end

-- ------------------------------------------------------------------ 3
-- A group cast aimed at somebody owed a favour: their row is a favour
-- returned, and the cast's own row is filed under another it reached
-- (Clicks.lua, SettleGroup). Both are the one cast, and it reached them all.
Mock.reset()
do
	local scenario = P .. "the one a group cast was aimed at is one of the raid it reached"
	local ns = load(scenario)
	if ns then
		begin(ns, scenario)
		Mock.raid = { size = 10 }
		local members = {}
		for i = 2, 9 do members[#members + 1] = raider(i) end
		local group = { spell = 23028, members = members }
		-- As Clicks.lua files it: the anchor's favour with the press's own
		-- record, the cast under the first member owed nothing.
		local function cast(everybodyOwed)
			ns.Ledger.Received({ name = raider(1), class = "PRIEST", key = 1459 })
			if everybodyOwed then
				for _, name in ipairs(members) do ns.Ledger.Received({ name = name, class = "PRIEST", key = 1459 }) end
			end
			Mock.advance(30)
			ns.Ledger.Settled(raider(1), { at = GetTime() - 30 },
				{ name = raider(1), buffKey = "intellect", inGroup = true, group = group }, 23028)
			local covered = { buffKey = "intellect", group = group, inGroup = true, member = true }
			if everybodyOwed then
				for _, name in ipairs(members) do ns.Ledger.Settled(name, { at = GetTime() - 30 }, covered, 23028) end
			else
				ns.Ledger.Settled(raider(2), nil, covered, 23028)
			end
			settle(ns)
		end
		cast(false)
		if not earned(ns, "raid") then
			fail(scenario, "one cast reached all nine others, and the one it was aimed at was left out for being owed")
		end
		-- And with every one of them owed, there is no row for the cast itself.
		forget(ns)
		cast(true)
		if not earned(ns, "raid") then
			fail(scenario, "one cast returned nine favours across the raid and reached nobody")
		end
		-- Eight of the nine are still not everybody.
		forget(ns)
		Mock.raid = { size = 11 }
		cast(false)
		if earned(ns, "raid") then fail(scenario, "nine of the ten others were everybody") end
		Mock.raid = nil
		guarded(ns, scenario)
	end
end

-- ------------------------------------------------------------------ 4
-- One of your buffs, whichever of its spells: the group version on one
-- subgroup and the single one on the rest are the same buff on everybody.
Mock.reset()
do
	local scenario = P .. "a raid covered by the group version and the single one of one buff is everybody"
	local ns = load(scenario)
	if ns then
		begin(ns, scenario)
		Mock.raid = { size = 10 }
		local function give(name, key, spell, group)
			ns.Ledger.Settled(name, nil, { inGroup = true, class = "WARRIOR", buffKey = key, group = group }, spell)
		end
		local function round(otherKey)
			give(raider(1), "intellect", 23028, { spell = 23028, members = { raider(2), raider(3), raider(4), raider(5) } })
			-- The rest one by one, one of them low enough for a lower rank.
			for i = 6, 8 do give(raider(i), otherKey or "intellect", 10157) end
			give(raider(9), otherKey or "intellect", 1461)
			settle(ns)
		end
		round()
		if not earned(ns, "raid") then
			fail(scenario, "Arcane Brilliance on five and Arcane Intellect on the other four were three sittings")
		end
		-- Two buffs are not one: half the raid with each is nobody with both.
		forget(ns)
		round("dampen")
		if earned(ns, "raid") then fail(scenario, "two different buffs made up one raid between them") end
		Mock.raid = nil
		guarded(ns, scenario)
	end
end

-- ------------------------------------------------------------------ 5
-- The week without a debt is read from the ledger's rows, and Clear takes
-- them: what was returned this week still counts after it.
Mock.reset()
do
	local scenario = P .. "Clear does not take the week's returned favours with it"
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
		day(2) day(2) day(2) day(2)
		if earned(ns, "week") then fail(scenario, "SKIPPED -- eight favours on four days made a week") end
		ns.Ledger.Clear()
		if #ns.Ledger.Entries("favours") ~= 0 then fail(scenario, "SKIPPED -- Clear left returned favours listed") end
		day(2)
		if not earned(ns, "week") then
			fail(scenario, "ten favours returned on five days, and Clear on the fourth started the week again")
		end
		restore()
		guarded(ns, scenario)
	end
end

-- ...and a favour left unreturned still bars the week after it.
Mock.reset()
do
	local scenario = P .. "Clear does not hide a favour left unreturned this week"
	local ns = load(scenario)
	if ns then
		begin(ns, scenario)
		local restore = calendar()
		ns.Ledger.Received({ name = "Forgotten Fay", class = "PRIEST", key = 1459 })
		Mock.advance(200)
		ns.Ledger.LetGo("Forgotten Fay")
		ns.Ledger.Clear()
		local n = 0
		local function day(count)
			for _ = 1, count do
				n = n + 1
				returnOne(ns, "Weekly " .. string.char(64 + n) .. "z", 30)
				settle(ns)
			end
			Mock.advance(86400)
		end
		day(2) day(2) day(2) day(2) day(2)
		if earned(ns, "week") then
			fail(scenario, "a favour let go on Monday and cleared away, and Friday made a week with none left unreturned")
		end
		-- A week on, the lapse is behind.
		Mock.advance(8 * 86400)
		n = 10
		day(2) day(2) day(2) day(2) day(2)
		if not earned(ns, "week") then fail(scenario, "SKIPPED -- a clean week after the lapse earned nothing") end
		restore()
		guarded(ns, scenario)
	end
end

-- ...and so does a ledger busy enough to trim the week's first days away.
Mock.reset()
do
	local scenario = P .. "a busy ledger's trim does not take the week's first days with it"
	local ns = load(scenario)
	if ns then
		begin(ns, scenario)
		local restore = calendar()
		local n = 0
		local function day(count)
			for i = 1, count do
				n = n + 1
				local name = "Bulk " .. string.char(65 + math.floor(n / 26)) .. string.char(97 + n % 26) .. "z"
				returnOne(ns, name, 2)
				if i % 10 == 0 then settle(ns) end
			end
			settle(ns)
			Mock.advance(86400)
		end
		day(4) day(4) day(100) day(110)
		local first = ns.Ledger.Entries("favours")
		local oldest = first[#first]
		if #first > 200 or (oldest and oldest.name == "Bulk Abz") then
			fail(scenario, "SKIPPED -- the ledger trimmed nothing of the first day")
		end
		if earned(ns, "week") then fail(scenario, "SKIPPED -- four days made a week") end
		day(1)
		if not earned(ns, "week") then
			fail(scenario, "favours returned on five days, and the trim left the week three of them")
		end
		restore()
		guarded(ns, scenario)
	end
end

-- ------------------------------------------------------------------ 9
-- Never over the prompt, for as long as the toast shows: a prompt that comes
-- up where the toast already is sends it to the next spot.
Mock.reset()
do
	local scenario = P .. "a toast steps aside when the prompt comes up under it"
	local ns = load(scenario)
	if ns then
		local M = begin(ns, scenario)
		Mock.geometry = { width = 1600, height = 900 }
		local button = ns.Prompt:GetButton()
		button:ClearAllPoints()
		button:SetPoint("TOP", UIParent, "TOP", 0, -160)
		button:SetSize(200, 40)
		button:Hide()
		M.Ranked(ns.Ledger.TITLES[1])
		local f = M.ToastFrame()
		if not (f and f:IsShown()) then
			fail(scenario, "SKIPPED -- no toast")
		elseif f.spot ~= 1 then
			fail(scenario, "SKIPPED -- with the prompt hidden the toast is not at its first spot")
		else
			local function over(a, b)
				return a:GetLeft() < b:GetRight() and b:GetLeft() < a:GetRight()
					and a:GetBottom() < b:GetTop() and b:GetBottom() < a:GetTop()
			end
			-- Nothing under it: it stays.
			f.scripts.OnUpdate(f, 0.5)
			if f.spot ~= 1 then fail(scenario, "the toast moved with nothing under it") end
			-- A passer-by a second later, and the prompt is up where it is.
			button:Show()
			if not over(f, button) then fail(scenario, "SKIPPED -- the prompt is not under the toast's first spot") end
			f.scripts.OnUpdate(f, 0.5)
			if not f:IsShown() then
				fail(scenario, "SKIPPED -- the toast went")
			elseif over(f, button) or f.spot == 1 then
				fail(scenario, "the prompt came up under the toast, which stayed over it")
			end
		end
		Mock.geometry = nil
		guarded(ns, scenario)
	end
end
