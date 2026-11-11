-- A buff put back on you while it still ran is a favour (1.11.15). A player on
-- CurseForge found the /thank did not always come, and guessed why: a buff
-- somebody topped up on them was read as a refresh and let go. The aura keeps
-- its number and its spell, and only its end moves on; Favours.lua (IsNew) now
-- takes an end moved at least RECAST_GAIN later than the reading before saw
-- for a cast on top of it: a debt, a "buffed you" line and a /thank, as for a
-- buff that was not there. An end restated a moment later is not a cast, and
-- the top-up is noticed once.
--
-- Every scenario name starts with "refreshfavour:" so the mutations in
-- tests/mutations/refreshfavour.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, primeAuras = H.strangers, H.freshPrompt, H.primeAuras

-- Power Word: Fortitude.
local FORTITUDE = 10938

local TOUCHED = { "IsInInstance", "DoEmote", "C_ChatInfo" }
local original = {}
for _, name in ipairs(TOUCHED) do original[name] = rawget(_G, name) end

local emotes = {}

local function said()
	local out = {}
	for _, line in ipairs(Mock.printed or {}) do out[#out + 1] = tostring(line) end
	return table.concat(out, " | ")
end

-- Anna's Fortitude on you, filed as carried, ten minutes left; the /thank on,
-- outdoors.
local function with(scenario, body)
	Mock.reset()
	emotes = {}
	rawset(_G, "IsInInstance", function() return false, "none" end)
	rawset(_G, "DoEmote", function(emote, target) emotes[#emotes + 1] = { emote, target } end)
	rawset(_G, "C_ChatInfo", nil)
	local undo = strangers({ nameplate1 = { "Anna", "Aim" } })
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		ns.db.profile.prompt.thankEmote = true
		Mock.auraCount = 2
		Mock.extraAura, Mock.extraAuraSpell, Mock.extraAuraSource = 4001, FORTITUDE, "nameplate1"
		Mock.extraAuraUntil = Mock.now + 600
		ns.ResetAuraBaseline()
		primeAuras(ns)
		wipe(ns.owed)
		if not ns.auraScan.primed then
			fail(scenario, "SKIPPED -- the baseline of your own buffs never settled")
			return
		end
		Mock.printed = {}
		emotes = {}
		body(ns, ns.UnitFullName("nameplate1"))
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	undo()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, original[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- Read twice, as the client's UNIT_AURA and the next one would.
local function read(ns)
	ns.addon:UNIT_AURA(nil, "player")
	Mock.advance(0.5)
	ns.addon:UNIT_AURA(nil, "player")
end

do
	local scenario = "refreshfavour: a buff put back on you while it still ran is a favour"
	with(scenario, function(ns, anna)
		-- A minute on, Anna casts it on you again: thirty minutes from now.
		Mock.advance(60)
		Mock.extraAuraUntil = Mock.now + 1800
		read(ns)
		if not ns.owed[anna] then
			fail(scenario, "the top-up was let go as a refresh: nothing is owed Anna")
		end
		if not said():find("buffed you", 1, true) then
			fail(scenario, "nothing was said about the top-up: " .. said())
		end
		if #emotes ~= 1 then
			fail(scenario, "the top-up was thanked " .. #emotes .. " times, not once")
		end
	end)
end

do
	local scenario = "refreshfavour: the top-up is noticed once"
	with(scenario, function(ns, anna)
		Mock.advance(60)
		Mock.extraAuraUntil = Mock.now + 1800
		read(ns)
		if not ns.owed[anna] then
			fail(scenario, "SKIPPED -- the top-up was not noticed in the first place")
			return
		end
		-- The same aura, the same end, read again and again.
		wipe(ns.owed)
		Mock.printed = {}
		for _ = 1, 4 do
			Mock.advance(5)
			ns.addon:UNIT_AURA(nil, "player")
		end
		if ns.owed[anna] then
			fail(scenario, "the same top-up was taken for another favour: " .. said())
		end
	end)
end

do
	local scenario = "refreshfavour: an end restated a moment later is no favour"
	with(scenario, function(ns, anna)
		-- The client restating the end: a second later, then two more, each
		-- under RECAST_GAIN from the reading before, never cast again.
		Mock.advance(30)
		local ends = Mock.extraAuraUntil
		for step = 1, 2 do
			Mock.extraAuraUntil = ends + 2 * step
			Mock.advance(1)
			read(ns)
		end
		if ns.owed[anna] then
			fail(scenario, "an end moved a moment later was taken for a cast: " .. said())
		end
		if #emotes > 0 then
			fail(scenario, "Anna was thanked for an end the client restated")
		end
	end)
end
