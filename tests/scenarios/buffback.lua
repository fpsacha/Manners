-- A buff back is not a favour owed (asked for on CurseForge): "If I buff
-- someone, because they are nearby, then they buff me back a minute later, it
-- will start chiming at me to buff them. If I look into the Favours, it will
-- show up as Still Owed, even though I was the one to initiate." A buff from
-- somebody who wears a buff of yours with more than its top-up lead left is a
-- return (Favours.lua, BuffedBack): no debt, nothing on the prompt, no chime,
-- and the ledger's row reads "Buffed back". Yours by the client naming you as
-- its caster (retail), or, where it names nobody on another player (WoW
-- Forever), by Manners' own note of the gift it saw land on them
-- (ns.GaveLately), which answers when the aura cannot be read too. Somebody
-- wearing nothing of yours, or yours about to run out, is owed as ever; and a
-- buff from somebody whose favour you just returned is a new favour (the
-- ledger tests in hunt3-ledger.lua lean on that).
--
-- Every scenario name starts with "buffback:" so the mutations in
-- tests/mutations/buffback.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, primeAuras, favourFrom = H.strangers, H.freshPrompt, H.primeAuras, H.favourFrom

local TOUCHED = { "IsInInstance" }
local original = {}
for _, name in ipairs(TOUCHED) do original[name] = rawget(_G, name) end

local function said() return table.concat(Mock.printed, "\n") end
local function flat(text) return (tostring(text):gsub("\n", " / ")) end

-- One session as a mage on `flavour`, one passer-by on a nameplate, outdoors,
-- the chime on for favours only. body(ns, anna, intellect, names) runs, and
-- everything is put back after it.
local function with(scenario, flavour, body)
	Mock.reset()
	Mock.setFlavour(flavour)
	Mock.class = "MAGE"
	Mock.groupSize = 0
	Mock.nameplates = { "nameplate1" }
	Mock.held = {}
	rawset(_G, "IsInInstance", function() return false, "none" end)
	local names = { nameplate1 = { "Anna", "Aim" } }
	local undo = strangers(names)
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		local db = ns.db.profile
		db.sources.strangers = true
		db.verbose = true
		db.sound.enabled, db.sound.owedOnly = true, true
		primeAuras(ns)
		if not ns.auraScan.primed then
			fail(scenario, "SKIPPED -- the baseline never settled")
			return
		end
		local intellect = ns.FindBuff("MAGE", "intellect")
		if not intellect then fail(scenario, "SKIPPED -- no Arcane Intellect on " .. flavour) return end
		body(ns, ns.UnitFullName("nameplate1"), intellect, names)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	undo()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, original[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- How long the buff lasts, from the client's table.
local function length(ns, buff)
	return ns.BuffSeconds(buff) or 3600
end

-- Anna wearing Arcane Intellect with `left` seconds on it, the client naming
-- `source` as its caster (nil: nobody, as WoW Forever names nobody on another
-- player), read afresh rather than from the three-second cache.
local function wears(ns, buff, left, source)
	Mock.held = {}
	for _, id in ipairs(buff.auraIds) do Mock.held[id] = true end
	Mock.heldFor = left
	Mock.heldSource = nil
	if source then
		Mock.heldSource = {}
		for _, id in ipairs(buff.auraIds) do Mock.heldSource[id] = source end
	end
	ns.ForgetUnitAuras(ns.plain(UnitGUID("nameplate1")))
end

-- Anna offered your Arcane Intellect, the press made, and the game saying it
-- went out: the cast Manners notes as landed. False when it never got there.
local function buffAnna(ns, anna, buff)
	local entry = H.inQueue(ns)[anna]
	if not (entry and entry.buff and entry.buff.key == "intellect") then return false end
	local info = ns.BuffInfo(buff)
	return H.pressAndSend(ns, entry, (info and info.topRank) or buff.ranks[1])
end

-- Anna buffs you with Arcane Intellect; what was said about it.
local nextId = 7100
local function annaBuffsYou(ns, buff)
	nextId = nextId + 1
	return favourFrom(ns, "nameplate1", buff.ranks[1], nextId)
end

-- Anna's newest row in the ledger.
local function row(ns, anna)
	local s = ns.db.char.ledger
	for i = #(s and s.entries or {}), 1, -1 do
		local e = s.entries[i]
		if e.kind == "received" and e.name == anna then return e end
	end
	return nil
end

-- Every chime the prompt makes from here on, counted.
local function chimes(ns)
	local count = { n = 0 }
	ns.PlayPromptSound = function() count.n = count.n + 1 end
	return count
end

-- Not owed, not on the prompt, no chime, and the ledger says Buffed back:
-- with her nameplate gone too, so the favour's own way onto the prompt (the
-- tokenless fallback) is asked as well.
local function notOwed(scenario, ns, anna, names)
	local heard = said()
	if ns.owed[anna] then fail(scenario, "a buff back was filed as a favour owed") end
	local r = row(ns, anna)
	if not r then
		fail(scenario, "the buff back has no row in the ledger")
	elseif r.state ~= "back" then
		fail(scenario, "the ledger row reads " .. tostring(r.state) .. ", not Buffed back")
	end
	if not heard:find("buffed you back", 1, true) then
		fail(scenario, "nothing said the buff was a buff back: " .. flat(heard))
	end
	local count = chimes(ns)
	names.nameplate1 = nil
	Mock.nameplates = {}
	for _ = 1, 3 do
		Mock.advance(1)
		ns.Prompt:Refresh()
	end
	local entry = H.inQueue(ns)[anna]
	if entry and entry.reason == "owed" then fail(scenario, "the buff back put her on the prompt as owed") end
	if count.n > 0 then fail(scenario, "the prompt chimed for a buff back") end
	-- The window: the badge, and the row's tooltip.
	ns.addon:HandleSlash("ledger")
	local window = ns.Ledger.Window()
	local first = window and window.rows and window.rows[1]
	if not first then
		fail(scenario, "the ledger window drew no row")
	else
		local badge = first.badge and first.badge:GetText() or ""
		if badge ~= ns.Ledger.TEXT.STATE_BACK then
			fail(scenario, "the ledger's badge reads " .. tostring(badge))
		end
		Mock.tooltip = {}
		first.scripts.OnEnter(first)
		local tip = table.concat(Mock.tooltip, " / ")
		if tip:find("Still owed", 1, true) or not tip:find("buff back, so nothing is owed", 1, true) then
			fail(scenario, "the row's tooltip says " .. tip)
		end
	end
	local sum = ns.Ledger.Summary()
	if sum.owed ~= 0 or sum.received ~= 0 then
		fail(scenario, ("the ledger counts the buff back as a favour: %d owed, %d received"):format(sum.owed, sum.received))
	end
	-- Saved and loaded again, as at a login: the row is repaired from the file.
	local s = ns.db.char.ledger
	ns.db.char.ledger = { entries = s.entries, totals = s.totals, title = s.title }
	ns.Ledger.Summary()
	local again = row(ns, anna)
	if not (again and again.state == "back") then
		fail(scenario, "the ledger reads a buff back saved and loaded again as " .. tostring(again and again.state))
	end
end

-- ------------------------------------------------------------------ Forever
do
	local scenario = "buffback: Forever: a passer-by you buffed first buffs you back a minute later and is not owed"
	with(scenario, "camelot", function(ns, anna, buff, names)
		if not buffAnna(ns, anna, buff) then fail(scenario, "SKIPPED -- the press on Anna went nowhere") return end
		Mock.advance(60)
		wipe(ns.tried)
		-- Forever names nobody as the caster of a buff on another player.
		wears(ns, buff, length(ns, buff) - 60, nil)
		annaBuffsYou(ns, buff)
		notOwed(scenario, ns, anna, names)
	end)
end

do
	local scenario = "buffback: Forever: Manners' own note of the cast answers when her auras cannot be read"
	with(scenario, "camelot", function(ns, anna, buff, names)
		if not buffAnna(ns, anna, buff) then fail(scenario, "SKIPPED -- the press on Anna went nowhere") return end
		Mock.advance(60)
		wipe(ns.tried)
		wears(ns, buff, length(ns, buff) - 60, nil)
		Mock.auraReadRefuse = {}
		for _, id in ipairs(buff.auraIds) do Mock.auraReadRefuse[id] = "throw" end
		annaBuffsYou(ns, buff)
		Mock.auraReadRefuse = nil
		notOwed(scenario, ns, anna, names)
	end)
end

do
	local scenario = "buffback: Forever: somebody wearing nothing of yours who buffs you is owed"
	with(scenario, "camelot", function(ns, anna, buff)
		wears(ns, buff, nil, nil)
		Mock.held = {}
		annaBuffsYou(ns, buff)
		if not ns.owed[anna] then fail(scenario, "a favour from somebody you never buffed was not filed") end
		local r = row(ns, anna)
		if not (r and r.state == "owed") then
			fail(scenario, "the ledger row reads " .. tostring(r and r.state) .. ", not Still owed")
		end
	end)
end

do
	local scenario = "buffback: Forever: somebody whose copy of yours is about to run out is owed"
	with(scenario, "camelot", function(ns, anna, buff)
		if not buffAnna(ns, anna, buff) then fail(scenario, "SKIPPED -- the press on Anna went nowhere") return end
		-- Ten seconds left of the cast Manners saw land.
		Mock.advance(length(ns, buff) - 10)
		wipe(ns.tried)
		wears(ns, buff, 10, nil)
		annaBuffsYou(ns, buff)
		if not ns.owed[anna] then
			fail(scenario, "a favour from somebody whose copy of yours runs out in ten seconds was not filed")
		end
	end)
end

do
	local scenario = "buffback: Forever: a buff after you returned their favour is a new favour"
	with(scenario, "camelot", function(ns, anna, buff)
		-- She wears your buff when the new favour comes, so by default it is let
		-- go as covered (tests/scenarios/covered.lua); with the refresh on, what
		-- is asked here shows: owed, not a buff back.
		ns.db.profile.filters.repayCovered = true
		-- A gift first, then a favour of hers you return: the return, not the
		-- gift, is the last thing you did for her.
		if not buffAnna(ns, anna, buff) then fail(scenario, "SKIPPED -- the press on Anna went nowhere") return end
		Mock.advance(60)
		wipe(ns.tried)
		H.owe(ns, anna)
		if not buffAnna(ns, anna, buff) then fail(scenario, "SKIPPED -- the return to Anna went nowhere") return end
		if ns.owed[anna] then fail(scenario, "SKIPPED -- the return did not repay her") return end
		Mock.advance(5)
		wipe(ns.tried)
		wears(ns, buff, length(ns, buff) - 5, nil)
		annaBuffsYou(ns, buff)
		if not ns.owed[anna] then
			fail(scenario, "a buff from somebody whose favour you had just returned was taken for a buff back")
		end
	end)
end

-- ------------------------------------------------------------------ retail
-- A client that names you as the caster: no press needed, the aura says so.
do
	local scenario = "buffback: retail: somebody wearing yours, the client naming you, buffs you back and is not owed"
	with(scenario, "mainline", function(ns, anna, buff, names)
		wears(ns, buff, length(ns, buff) - 60, "player")
		annaBuffsYou(ns, buff)
		notOwed(scenario, ns, anna, names)
	end)
end

do
	local scenario = "buffback: retail: somebody whose copy of yours is about to run out is owed"
	with(scenario, "mainline", function(ns, anna, buff)
		wears(ns, buff, 10, "player")
		annaBuffsYou(ns, buff)
		if not ns.owed[anna] then
			fail(scenario, "a favour from somebody whose copy of yours runs out in ten seconds was not filed")
		end
	end)
end

do
	local scenario = "buffback: retail: somebody wearing another mage's Intellect is owed"
	with(scenario, "mainline", function(ns, anna, buff)
		-- Another mage's is no buff back; by default it is let go as covered
		-- all the same (tests/scenarios/covered.lua), so the refresh is on.
		ns.db.profile.filters.repayCovered = true
		wears(ns, buff, length(ns, buff) - 60, "nameplate1")
		annaBuffsYou(ns, buff)
		if not ns.owed[anna] then fail(scenario, "a favour from somebody wearing another's Intellect was not filed") end
	end)
end
