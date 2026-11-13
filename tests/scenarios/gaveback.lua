-- A favour repaid is not asked for again (1.11.4). A paladin on WoW Forever,
-- with Blessing of Might only, reported being prompted to buff somebody they
-- had already buffed once that person buffed them back, the Manners button
-- included. Forever names nobody as the caster of a buff on another player, so
-- Might on them read as "not known to be ours", and a favour owed with Might
-- on the person was repaid with another Might, as a refresh. Manners now
-- notes the cast it saw land (ns.NoteGave, Queue.lua) and reads a buff that
-- names nobody as that cast when it runs for no longer than the cast would
-- have (ns.GaveSince): the favour is paid up, and nothing is offered.
--
-- Every scenario name starts with "gaveback:" so the mutations in
-- tests/mutations/gaveback.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load

local TOUCHED = { "IsSpellKnown", "IsPlayerSpell" }

local function with(scenario, body)
	Mock.reset()
	Mock.class = "PALADIN"
	Mock.groupSize = 0
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local restore = H.strangers({ nameplate1 = { "Anna", "Aim" } })
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		local might = ns.FindBuff("PALADIN", "might")
		-- Retail's paladin has no blessings to give.
		if not might then return end
		local known = {}
		for _, id in ipairs(might.ranks) do known[id] = true end
		rawset(_G, "IsSpellKnown", function(id) return known[id] == true end)
		rawset(_G, "IsPlayerSpell", function(id) return known[id] == true end)
		H.freshPrompt(ns, scenario)
		ns.db.profile.sources.strangers = true
		-- Re-aimed by the right-buff audit: these scenarios were written with
		-- Might offered to mages, warlocks and priests, which is a switch that
		-- is on by default now ("Don't offer Might to..."): off here, where the
		-- walk's order, the pin and whose blessing it is are what is held.
		ns.db.profile.buff.skipCasters = false
		-- Whose cast a worn Might is only matters while a favour is repaid by
		-- refreshing one from somebody else: "Refresh a buff they already have,
		-- to return a favour", off by default (tests/scenarios/covered.lua).
		ns.db.profile.filters.repayCovered = true
		ns.Guard("probe", ns.ProbeCapabilities)
		body(ns, might)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	restore()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- A name as the queue files it: Forever's two-part names, the others' first.
local function filed(first, last)
	return Mock.surnames and (first .. " " .. last) or first
end

-- What the queue offers Anna, as a buff key, or false for nothing.
local function offered(ns)
	ns.ForgetUnitAuras(ns.plain(UnitGUID("nameplate1")))
	local entry = H.inQueue(ns)[filed("Anna", "Aim")]
	return entry and entry.buff and entry.buff.key or false
end

-- Anna wearing Might, the client naming nobody as its caster, with `left`
-- seconds on it.
local function wears(ns, might, left)
	-- `left` is a share of the buff's own length, which is Classic Era's five
	-- minutes and Forever's hour.
	if left then left = math.floor(left * (ns.BuffSeconds(might) or 3600)) end
	Mock.held = { [might.ranks[1]] = true }
	Mock.heldSource = nil
	Mock.heldFor = left
end

do
	local scenario = "gaveback: a favour is not repaid with the Might they wear from you, the caster unnamed"
	with(scenario, function(ns, might)
		-- Pressed and landed: the settle notes it.
		wears(ns, might, nil)
		Mock.held = {}
		local first = H.inQueue(ns)[filed("Anna", "Aim")]
		if not (first and first.buff and first.buff.key == "might") then
			fail(scenario, "SKIPPED -- Anna, wearing nothing, is not offered Might")
			return
		end
		if not H.pressAndSend(ns, first, might.ranks[1]) then
			fail(scenario, "SKIPPED -- the press went nowhere")
			return
		end
		Mock.advance(60)
		wipe(ns.tried)
		-- She wears it now, from nobody the client names, and buffs us back.
		wears(ns, might, 0.7)
		H.owe(ns, filed("Anna", "Aim"))
		local got = offered(ns)
		if got then
			fail(scenario, "Anna wears the Might Manners saw land on her and was offered " .. tostring(got)
				.. " for the favour she did: it is repaid already")
		end
	end)
end

do
	local scenario = "gaveback: Might from nobody Manners cast is still offered back for a favour"
	with(scenario, function(ns, might)
		wears(ns, might, 0.9)
		H.owe(ns, filed("Anna", "Aim"))
		local got = offered(ns)
		if got ~= "might" then
			fail(scenario, "Anna, who wears a Might nothing says is ours and did you a favour, was offered "
				.. tostring(got) .. ", not Might to repay her")
		end
	end)
end

do
	local scenario = "gaveback: a Might that outlasts the cast Manners saw is not taken for it"
	with(scenario, function(ns, might)
		ns.NoteGave(filed("Anna", "Aim"), "might")
		-- Half an hour later she wears a Might with nearly all its hour left: it
		-- was cast again since, by somebody else.
		Mock.advance(math.floor((ns.BuffSeconds(might) or 3600) / 2))
		wears(ns, might, 0.97)
		H.owe(ns, filed("Anna", "Aim"))
		local got = offered(ns)
		if got ~= "might" then
			fail(scenario, "Anna wears a Might newer than the one Manners cast and was offered "
				.. tostring(got) .. ": it was taken for ours")
		end
	end)
end

do
	local scenario = "gaveback: a cast noted for another blessing says nothing of this one"
	with(scenario, function(ns, might)
		ns.NoteGave(filed("Anna", "Aim"), "wisdom")
		wears(ns, might, 0.9)
		H.owe(ns, filed("Anna", "Aim"))
		local got = offered(ns)
		if got ~= "might" then
			fail(scenario, "a Wisdom noted for Anna was taken for her Might: she was offered " .. tostring(got))
		end
	end)
end

do
	local scenario = "gaveback: the record is bounded and names nobody it was not given"
	with(scenario, function(ns, might)
		for i = 1, 700 do ns.NoteGave("Walker" .. i, "might") end
		if ns.GaveSince("Nobody Noted", "might", 100, 3600) then
			fail(scenario, "somebody nothing was noted for was read as given to")
		end
		if ns.GaveSince(nil, "might", 100, 3600) or ns.GaveSince("Walker700", nil, 100, 3600) then
			fail(scenario, "a missing name or buff was read as given")
		end
		if not ns.GaveSince("Walker700", "might", 100, 3600) then
			fail(scenario, "the newest cast noted was lost to the bound")
		end
		if ns.GaveSince("Walker700", "might", nil, 3600) or ns.GaveSince("Walker700", "might", 100, nil) then
			fail(scenario, "a buff with no known time or length was read as the cast")
		end
	end)
end
