-- "Unverified" offers, and the fight that makes them.
--
-- In a fight the client refuses every reading of other people's auras, and
-- may go on refusing for a moment after it. The prompt then offered, marked
-- "unverified", people already wearing the buff: the refusal from the
-- fight's last scan lived on in the aura cache for three seconds, the
-- reading taken before the pull was not remembered, and a probe made in the
-- fight could take a readable buff for a secret one until the next probe.
-- And a player asked for a switch that never offers anybody unverified.
--
-- Every scenario name starts with "unverified:" so tests/mutations/unverified.py
-- can name the one that has to catch each fault.
--
-- The file follows the client the suite runs as: Forever by default, and
-- retail under `--flavour mainline`, which tools/check.py --flavours does, since
-- retail hides other players' auras in a fight as Forever does (secret values).
-- The classic clients never do, so there the refusals are made up by the mock;
-- the code is the same, and the scenarios still hold. Three things differ by
-- client, and each is handled where it comes up: how Anna is filed (ANNA below),
-- which buff has more than one aura id to declare one of secret (`manyIds`), and
-- ranks, which only Forever, Classic Era and TBC have (the stronger-rank scenario
-- returns quietly where there are none: a "SKIPPED" is a failure).

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, inQueue, owe = H.strangers, H.freshPrompt, H.inQueue, H.owe

-- What UnitName gives Anna, and how the client files her. On Forever her second
-- return is a surname, filed with a space ("Anna Aim"); off it a realm, which the
-- client hands over only for somebody from another one (the mock's
-- Mock.crossRealm) and the addon joins with a dash ("Anna-Aim"). The scenarios
-- here were written on Forever and named her "Anna Aim" throughout, so on any
-- other client every `inQueue(ns)[ANNA]` found nobody and the file reported 32
-- offers missing. ANNA is now set afresh by each session from the client the mock
-- is standing in for, and checked against what the addon files her as (Core.lua,
-- JoinName), so a wrong spelling is one failure that says so.
local ANNA
local ANNA_NAME = { "Anna", "Aim" }

local function filedAs(name)
	if Mock.surnames then return name[1] .. " " .. name[2] end
	if Mock.crossRealm then return name[1] .. "-" .. name[2] end
	return name[1]
end

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- Runs `body(ns, ids, buff)` on a fresh session with Anna on a nameplate four
-- yards off, the buff to offer resolved and its aura ids handed over, and puts
-- the units and the fight back whatever happened. `manyIds` is for a scenario
-- that declares one id of the buff secret while the rest still read: it needs a
-- buff of more than one aura id. A mage has one on every client but retail's,
-- where Arcane Intellect is the single id 1459 (no ranks, no group version),
-- and the evoker's Blessing of the Bronze, with a group's worth of ids, is the
-- buff that has them. The mock's spellbook holds Arcane Intellect alone, so the
-- evoker is given one that knows every spell, and the two globals put back.
local function session(scenario, body, manyIds)
	Mock.reset()
	local knows, knowsPlayer = IsSpellKnown, IsPlayerSpell
	if manyIds and Mock.flavour == "mainline" then
		Mock.class = "EVOKER"
		local all = function() return true end
		rawset(_G, "IsSpellKnown", all)
		rawset(_G, "IsPlayerSpell", all)
	end
	-- Somebody from another realm: Anna-Aim, which is how a stranger reaches
	-- the retail and Classic clients' queues as often as not, and the spelling
	-- where the filed name and the /target name differ (ns.TargetName).
	Mock.crossRealm = not Mock.surnames
	local names = { nameplate1 = ANNA_NAME }
	ANNA = filedAs(ANNA_NAME)
	Mock.yards = { nameplate1 = 4 }
	local restoreUnits = strangers(names)
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		if ns.UnitFullName("nameplate1") ~= ANNA then
			fail(scenario, ("SKIPPED -- the addon files the stranger on the nameplate as %s, not %s")
				:format(tostring(ns.UnitFullName("nameplate1")), ANNA))
			return
		end
		freshPrompt(ns, scenario)
		ns.Prompt:ExitTest()
		Mock.runTimers(0)
		local buff = ns.ResolveBuff(true)
		if not buff then
			fail(scenario, "SKIPPED -- no buff to offer")
			return
		end
		body(ns, buff.auraIds, buff)
		noErrors(scenario, ns)
	end)
	restoreUnits()
	rawset(_G, "IsSpellKnown", knows)
	rawset(_G, "IsPlayerSpell", knowsPlayer)
	Mock.crossRealm = false
	Mock.inCombat = false
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- Every reading of the buff refused from now on, the cache's last answer
-- outlived (it is trusted three seconds).
local function refuse(ids, how)
	Mock.auraReadRefuse = {}
	for _, id in ipairs(ids) do Mock.auraReadRefuse[id] = how end
	Mock.advance(4)
end

local function fightStarts(ns)
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
end

local function fightEnds(ns)
	Mock.inCombat = false
	ns.addon:PLAYER_REGEN_ENABLED()
end

-- ------------------------------------------------------------- unverified 1
-- Read wearing the buff with half an hour left, then refused in a fight and
-- the seconds after it: she still wears it, and is not offered it. Out of a
-- fight's wake the refusal stands, as before. A buff whose time has run out
-- since, or that she was read without since, is no longer taken for worn.
for _, how in ipairs({ "secret", "throw" }) do
	local scenario = "unverified: a buff read with time left still counts once refused (" .. how .. ")"
	session(scenario, function(ns, ids, buff)
		-- The best rank: a lower one counts as not having it (Core.lua).
		Mock.held, Mock.heldFor = { [buff.ranks[1]] = true }, 1800
		Mock.advance(4)
		if inQueue(ns)[ANNA] then
			fail(scenario, "SKIPPED -- Anna was offered while read wearing the buff")
			return
		end
		Mock.held = nil
		fightStarts(ns)
		refuse(ids, how)
		local entry = inQueue(ns)[ANNA]
		if entry then
			fail(scenario, ("Anna was offered (%s) in the fight though she was read wearing it with half an hour left")
				:format(ns.Prompt:ReasonText(entry)))
		end
		fightEnds(ns)
		entry = inQueue(ns)[ANNA]
		if entry then
			fail(scenario, ("Anna was offered (%s) as the fight ended though she was read wearing it with half an hour left")
				:format(ns.Prompt:ReasonText(entry)))
		end
		Mock.advance(10)
		entry = inQueue(ns)[ANNA]
		if not entry then
			fail(scenario, "Anna, still unreadable well after the fight, is taken for wearing the buff out of one")
		elseif entry.known ~= nil then
			fail(scenario, "a refused reading came back as " .. tostring(entry.known))
		end
		Mock.advance(1800)
		fightStarts(ns)
		Mock.advance(4)
		entry = inQueue(ns)[ANNA]
		fightEnds(ns)
		if not entry then
			fail(scenario, "Anna is still taken for wearing a buff whose time ran out half an hour ago")
		elseif entry.known ~= nil then
			fail(scenario, "a refused reading came back as " .. tostring(entry.known))
		end
		-- Wearing it again, then read without it (dispelled, cancelled): the
		-- reading without it is the last one, and a refusal does not bring
		-- the older one back.
		Mock.advance(10)
		Mock.auraReadRefuse = nil
		Mock.held = { [buff.ranks[1]] = true }
		Mock.advance(4)
		inQueue(ns)
		Mock.held = nil
		Mock.advance(4)
		inQueue(ns)
		fightStarts(ns)
		refuse(ids, how)
		entry = inQueue(ns)[ANNA]
		fightEnds(ns)
		if not entry then
			fail(scenario, "Anna is taken for wearing the buff she was last read without")
		end
	end)
end

-- ------------------------------------------------------------- unverified 2
-- A refusal made in the fight is asked again on the first scan after it,
-- not three seconds on: readable and missing the buff, she is offered at once
-- as needing it.
do
	local scenario = "unverified: the fight's refusals are asked again as it ends"
	session(scenario, function(ns, ids)
		fightStarts(ns)
		refuse(ids, "secret")
		ns.BuildQueue()
		Mock.auraReadRefuse = nil
		fightEnds(ns)
		local entry = inQueue(ns)[ANNA]
		if not entry then
			fail(scenario, "Anna, readable and missing the buff, was not offered on the first scan after the fight")
		elseif entry.known ~= false then
			fail(scenario, "Anna was offered on the fight's refusal rather than a fresh reading: known="
				.. tostring(entry.known))
		end
	end)
end

-- ------------------------------------------------------------- unverified 3
-- Still refused after the fight: nobody is offered unverified for the first
-- seconds, while the client may still answer; past them, as before.
do
	local scenario = "unverified: nobody unverified in the first seconds after a fight"
	session(scenario, function(ns, ids)
		refuse(ids, "secret")
		local before = inQueue(ns)[ANNA]
		if not (before and before.known == nil) then
			fail(scenario, "SKIPPED -- Anna, unreadable out of any fight, was not offered unverified")
			return
		end
		fightStarts(ns)
		ns.BuildQueue()
		fightEnds(ns)
		if inQueue(ns)[ANNA] then fail(scenario, "Anna was offered unverified as the fight ended") end
		Mock.advance(2)
		if inQueue(ns)[ANNA] then fail(scenario, "Anna was offered unverified two seconds after the fight") end
		Mock.advance(4)
		local after = inQueue(ns)[ANNA]
		if not after then
			fail(scenario, "Anna, still unreadable, is never offered again after a fight")
		elseif after.known ~= nil then
			fail(scenario, "a refused reading came back as " .. tostring(after.known))
		end
	end)
end

-- ------------------------------------------------------------- unverified 4
-- "Only offer people whose buffs can be read": somebody refused is never
-- offered, in a fight's wake or not; read as missing it, she is.
do
	local scenario = "unverified: the switch never offers anybody unverified"
	session(scenario, function(ns, ids)
		ns.db.profile.filters.verifiedOnly = true
		refuse(ids, "secret")
		if inQueue(ns)[ANNA] then fail(scenario, "Anna was offered unverified with the switch on") end
		Mock.advance(30)
		if inQueue(ns)[ANNA] then fail(scenario, "Anna was offered unverified with the switch on, later") end
		Mock.auraReadRefuse = nil
		Mock.advance(4)
		local entry = inQueue(ns)[ANNA]
		if not entry then
			fail(scenario, "Anna, read as missing the buff, is not offered with the switch on")
		elseif entry.known ~= false then
			fail(scenario, "Anna was offered with known=" .. tostring(entry.known))
		end
		ns.db.profile.filters.verifiedOnly = false
		refuse(ids, "secret")
		if not inQueue(ns)[ANNA] then
			fail(scenario, "with the switch off, Anna unreadable is no longer offered")
		end
	end)
end

-- ------------------------------------------------------------- unverified 5
-- Somebody who buffed you is offered whatever the reading, switch or fight.
do
	local scenario = "unverified: a favour is offered back unread, switch on and after a fight"
	session(scenario, function(ns, ids)
		ns.db.profile.filters.verifiedOnly = true
		refuse(ids, "secret")
		owe(ns, ANNA)
		fightStarts(ns)
		ns.BuildQueue()
		fightEnds(ns)
		local entry = inQueue(ns)[ANNA]
		if not entry then
			fail(scenario, "Anna, who buffed you, was not offered back with her buffs unreadable")
		elseif entry.reason ~= "owed" then
			fail(scenario, "Anna was offered as " .. tostring(entry.reason) .. " rather than for her favour")
		end
	end)
end

-- ------------------------------------------------------------- unverified 6
-- A probe made in a fight, told the buff is secret, is made again as the
-- fight ends: the buff reads again. One made out of a fight is left alone.
do
	local scenario = "unverified: a probe made in a fight is made again as it ends"
	session(scenario, function(ns, ids)
		local buff = ns.ResolveBuff(true)
		Mock.secretAuraIds = {}
		for _, id in ipairs(ids) do Mock.secretAuraIds[id] = true end
		fightStarts(ns)
		ns.Guard("probe", ns.ProbeCapabilities)
		if ns.BuffInfo(buff).readable then
			fail(scenario, "SKIPPED -- the probe in the fight still took the buff for readable")
			return
		end
		Mock.secretAuraIds = nil
		fightEnds(ns)
		buff = ns.ResolveBuff(true)
		if not (buff and ns.BuffInfo(buff).readable) then
			fail(scenario, "the buff the fight's probe took for secret is still unreadable after it")
		end
		local probes = 0
		local real = ns.ProbeCapabilities
		ns.ProbeCapabilities = function(...) probes = probes + 1 return real(...) end
		fightStarts(ns)
		fightEnds(ns)
		Mock.runTimers(5)
		ns.ProbeCapabilities = real
		if probes > 0 then
			fail(scenario, "a fight with no probe in it probed again " .. probes .. " time(s)")
		end
	end)
end

-- ------------------------------------------------------------- unverified 7
-- A passer-by remembered on a reading the client withheld is let go as the
-- fight ends; one remembered as needing the buff stays, and is still offered
-- by name, and so does one refused for good (an id declared secret), whom the
-- fight changed nothing about.
do
	local scenario = "unverified: the end of a fight lets go of passers-by remembered unread"
	session(scenario, function(ns, _, buff)
		local function remember(name, known, withheld)
			ns.passersBy[name] = { seen = GetTime(), reason = "nearby", buff = buff, checked = true,
				known = known, withheld = withheld, within = ns.db.profile.filters.proximity,
				class = "MAGE", targetName = name, hasMana = true }
		end
		remember("Bert Beside", nil, true)
		remember("Cora Close", false)
		remember("Dora Declared", nil)
		fightStarts(ns)
		fightEnds(ns)
		if ns.passersBy["Bert Beside"] then
			fail(scenario, "a passer-by remembered unread is still remembered after the fight")
		end
		if not ns.passersBy["Dora Declared"] then
			fail(scenario, "a passer-by refused for good was let go with the fight")
		end
		if not ns.passersBy["Cora Close"] then
			fail(scenario, "a passer-by remembered as needing the buff was let go with the fight")
		elseif not inQueue(ns)["Cora Close"] then
			fail(scenario, "a passer-by remembered as needing the buff is no longer offered after the fight")
		end
	end)
end

-- ------------------------------------------------------------- unverified 8
-- With the switch on, a passer-by remembered on a refused reading is not
-- offered by name once no token reaches her either.
do
	local scenario = "unverified: the switch lets go of a passer-by remembered unread"
	session(scenario, function(ns, ids)
		refuse(ids, "secret")
		local before = inQueue(ns)[ANNA]
		if not (before and before.known == nil) then
			fail(scenario, "SKIPPED -- Anna, unreadable, was not offered unverified with the switch off")
			return
		end
		if not ns.passersBy[ANNA] then
			fail(scenario, "SKIPPED -- Anna was not remembered as a passer-by")
			return
		end
		Mock.unitNames.nameplate1 = nil
		ns.nameplateUnits.nameplate1 = nil
		ns.db.profile.filters.verifiedOnly = true
		if inQueue(ns)[ANNA] then
			fail(scenario, "Anna, remembered unread, was offered by name with the switch on")
		end
	end)
end

-- ------------------------------------------------------------- unverified 9
-- Remembered as needing the buff, out of sight through the fight, then back
-- and refused as it ends: neither the token's refusal nor the older memory
-- offers her in the first seconds.
do
	local scenario = "unverified: a refusal after a fight is not offered from an older memory"
	session(scenario, function(ns, ids)
		local before = inQueue(ns)[ANNA]
		if not (before and before.known == false and ns.passersBy[ANNA]) then
			fail(scenario, "SKIPPED -- Anna was not offered and remembered as needing the buff")
			return
		end
		Mock.unitNames.nameplate1 = nil
		ns.nameplateUnits.nameplate1 = nil
		refuse(ids, "secret")
		fightStarts(ns)
		Mock.unitNames.nameplate1 = ANNA_NAME
		ns.nameplateUnits.nameplate1 = true
		fightEnds(ns)
		local entry = inQueue(ns)[ANNA]
		if entry then
			fail(scenario, ("Anna, unreadable as the fight ended, was offered (known=%s) from what was remembered of her")
				:format(tostring(entry.known)))
		end
	end)
end

-- ------------------------------------------------------------------ helpers
-- For the scenarios below.

-- One of the buff's ids other than the best rank, its group version where it
-- has one (Arcane Brilliance): declared secret by a probe made out of a fight,
-- every reading of the buff is refused for good while the rest of its ids
-- still read.
local function declareSecret(ns, buff)
	local other
	for _, id in ipairs(buff.auraIds) do
		if id ~= buff.ranks[1] then other = id end
	end
	if not other then return false end
	Mock.secretAuraIds = { [other] = true }
	ns.Guard("probe", ns.ProbeCapabilities)
	local info = ns.BuffInfo(buff)
	return info and info.readable and info.secrecy[other] == true
		and info.secrecy[buff.ranks[1]] == false and not ns.caps.probedInFight
end

-- Anna leaves every token, and comes back on her nameplate.
local function outOfSight(ns)
	Mock.unitNames.nameplate1 = nil
	ns.nameplateUnits.nameplate1 = nil
end

local function inSight(ns)
	Mock.unitNames.nameplate1 = ANNA_NAME
	ns.nameplateUnits.nameplate1 = true
end

-- Anna asks for the buff in /say, as the client delivers the line (see
-- tests/scenarios/asked.lua).
local function annaAsks(ns)
	ns.db.profile.sources.asked = true
	ns.addon:CHAT_MSG_SAY("CHAT_MSG_SAY", "int pls", ANNA, "Common", "", "", "", 0, 0, "", 0, 1,
		"Player-1-nameplate1")
end

-- ------------------------------------------------------------ unverified 10
-- One of the buff's ids declared secret and the rest readable: every reading
-- of the buff is a refusal, whatever she wears. Read wearing the best rank,
-- then without it: the id she was read wearing reads back absent, and the
-- refusal of another id is no reason to take her for wearing it still. She
-- is offered, unverified, in the fight and as it ends.
do
	local scenario = "unverified: a refusal of another id does not keep the last reading"
	session(scenario, function(ns, _, buff)
		if not declareSecret(ns, buff) then
			fail(scenario, "SKIPPED -- the probe did not take one id alone for secret")
			return
		end
		Mock.held, Mock.heldFor = { [buff.ranks[1]] = true }, 1800
		Mock.advance(4)
		if inQueue(ns)[ANNA] then
			fail(scenario, "SKIPPED -- Anna was offered while read wearing the buff")
			return
		end
		Mock.held = nil
		fightStarts(ns)
		Mock.advance(4)
		local entry = inQueue(ns)[ANNA]
		if not entry then
			fail(scenario, "Anna, read without the buff she wore, was not offered in the fight")
		elseif entry.known ~= nil then
			fail(scenario, "a refused reading came back as " .. tostring(entry.known))
		end
		fightEnds(ns)
		entry = inQueue(ns)[ANNA]
		if not entry then
			fail(scenario, "Anna, read without the buff she wore, was not offered as the fight ended")
		end
	end, true)
end

-- ------------------------------------------------------------ unverified 11
-- Read wearing the buff with half an hour left, then dead in a fight: her
-- buffs went with her. Revived, and refused, she is offered unverified as
-- anybody unreadable is in a fight, not taken for wearing what she died with.
do
	local scenario = "unverified: what was read on somebody goes when they die"
	session(scenario, function(ns, ids, buff)
		Mock.held, Mock.heldFor = { [buff.ranks[1]] = true }, 1800
		Mock.advance(4)
		if inQueue(ns)[ANNA] then
			fail(scenario, "SKIPPED -- Anna was offered while read wearing the buff")
			return
		end
		Mock.held = nil
		fightStarts(ns)
		local alive = rawget(_G, "UnitIsDeadOrGhost")
		rawset(_G, "UnitIsDeadOrGhost", function(unit)
			if unit == "nameplate1" then return true end
			return alive(unit)
		end)
		local ok, err = pcall(function()
			Mock.advance(4)
			if inQueue(ns)[ANNA] then fail(scenario, "Anna was offered dead") end
		end)
		rawset(_G, "UnitIsDeadOrGhost", alive)
		if not ok then error(err, 0) end
		refuse(ids, "secret")
		local entry = inQueue(ns)[ANNA]
		if not entry then
			fail(scenario, "Anna, revived in the fight and unreadable, was taken for wearing the buff she died with")
		elseif entry.known ~= nil then
			fail(scenario, "a refused reading came back as " .. tostring(entry.known))
		end
		fightEnds(ns)
		Mock.advance(6)
		if not inQueue(ns)[ANNA] then
			fail(scenario, "Anna, revived and unreadable, was not offered unverified well after the fight")
		end
	end)
end

-- ------------------------------------------------------------ unverified 12
-- "Top up buffs running low", and Anna read with twenty seconds left: offered
-- the top-up. Refused in the fight and the seconds after it, what was last
-- read of her holds an offer back and never makes one: her timer may have
-- been renewed, or the buff lost, since. Read again after the fight, she is
-- offered the top-up as before. Last read with half an hour left, she is not
-- offered at all in the fight.
do
	local scenario = "unverified: no top-up is offered off the last reading"
	session(scenario, function(ns, ids, buff)
		local f = ns.db.profile.filters
		f.whenBuffed, f.refreshUnder = "refresh", 5
		Mock.held, Mock.heldFor = { [buff.ranks[1]] = true }, 20
		Mock.advance(4)
		local before = inQueue(ns)[ANNA]
		if not (before and before.known == true and before.remaining) then
			fail(scenario, "SKIPPED -- Anna, read with twenty seconds left, was not offered a top-up")
			return
		end
		fightStarts(ns)
		refuse(ids, "secret")
		local entry = inQueue(ns)[ANNA]
		if entry then
			fail(scenario, ("Anna was offered a top-up (known=%s) in the fight off what was last read of her")
				:format(tostring(entry.known)))
		end
		fightEnds(ns)
		entry = inQueue(ns)[ANNA]
		if entry then
			fail(scenario, ("Anna was offered a top-up (known=%s) as the fight ended off what was last read of her")
				:format(tostring(entry.known)))
		end
		Mock.auraReadRefuse = nil
		Mock.advance(6)
		entry = inQueue(ns)[ANNA]
		if not (entry and entry.known == true and entry.remaining) then
			fail(scenario, "Anna, read again with twenty seconds left after the fight, was not offered the top-up")
		end
		Mock.heldFor = 1800
		Mock.advance(4)
		inQueue(ns)
		fightStarts(ns)
		refuse(ids, "secret")
		entry = inQueue(ns)[ANNA]
		fightEnds(ns)
		if entry then
			fail(scenario, ("Anna, last read with half an hour left, was offered (known=%s) in the fight")
				:format(tostring(entry.known)))
		end
	end)
end

-- ------------------------------------------------------------ unverified 13
-- A group member who buffed you, wearing your own cast with forty minutes
-- left, has nothing to repay (PickBuffFor, paidUp). Refused in a fight, what
-- was last read of her says the same: whose cast it is and how long it has
-- left, not merely that she wears it.
do
	local scenario = "unverified: a group member's favour stays paid up on the last reading"
	session(scenario, function(ns, ids, buff)
		-- In a group: the mock's UnitInParty answers yes for every token then.
		Mock.groupSize = 5
		owe(ns, ANNA)
		Mock.held, Mock.heldFor = { [buff.ranks[1]] = true }, 2400
		Mock.advance(4)
		local before = inQueue(ns)[ANNA]
		if not (before and before.reason == "owed") then
			fail(scenario, "SKIPPED -- Anna, owed and wearing somebody else's cast, was not offered for her favour")
			return
		end
		Mock.heldSource = { [buff.ranks[1]] = "player" }
		Mock.advance(4)
		if inQueue(ns)[ANNA] then
			fail(scenario, "SKIPPED -- Anna, in your group and wearing your own cast with forty minutes left,"
				.. " was offered for her favour out of any fight")
			return
		end
		fightStarts(ns)
		refuse(ids, "secret")
		local entry = inQueue(ns)[ANNA]
		if entry then
			fail(scenario, ("Anna, in your group and last read wearing your own cast with forty minutes left,"
				.. " was offered (%s) for her favour in the fight"):format(tostring(entry.reason)))
		end
	end)
end

-- ------------------------------------------------------------ unverified 14
-- A rank above the one your cast would land, worn: covered, and yours on top
-- is refused by the game, so a favour is not repaid with it (see
-- tests/scenarios/flows-fixes.lua). Refused in a fight, what was last read of
-- her says so too.
do
	local scenario = "unverified: a stronger rank last read still bars a favour's refresh"
	session(scenario, function(ns, ids, buff)
		-- Ranks are Forever's, Classic Era's and Burning Crusade's: Mists and
		-- retail each have one spell per buff (Buffs.lua), so nobody can wear a
		-- stronger one there and there is nothing for this to be about. Not a
		-- "SKIPPED": that is a failure, kept for a precondition that should have held.
		if #buff.ranks < 2 then return end
		local info = ns.BuffInfo(buff)
		local ours = info and ns.RankLevel(info.topRank)
		local reach = ns.plain(UnitLevel("nameplate1"))
		local stronger
		for _, id in ipairs(buff.ranks) do
			local at = ns.RankLevel(id)
			if ours and type(reach) == "number" and at and at > ours and at <= reach + 10 then stronger = id end
		end
		if not stronger then
			fail(scenario, "SKIPPED -- no rank above yours within Anna's reach")
			return
		end
		owe(ns, ANNA)
		Mock.held, Mock.heldFor = { [info.topRank] = true }, 1800
		Mock.advance(4)
		local before = inQueue(ns)[ANNA]
		if not (before and before.reason == "owed") then
			fail(scenario, "SKIPPED -- Anna, owed and wearing your rank, was not offered for her favour")
			return
		end
		Mock.held = { [stronger] = true }
		Mock.advance(4)
		if inQueue(ns)[ANNA] then
			fail(scenario, "SKIPPED -- Anna, wearing a rank stronger than yours, was offered for her favour")
			return
		end
		fightStarts(ns)
		refuse(ids, "secret")
		local entry = inQueue(ns)[ANNA]
		if entry then
			fail(scenario, ("Anna, last read wearing a rank stronger than yours, was offered (%s) for her favour"
				.. " in the fight"):format(tostring(entry.reason)))
		end
	end)
end

-- ------------------------------------------------------------ unverified 15
-- Somebody who asked is offered whatever the reading, as somebody who buffed
-- you is: with the switch on, and in the first seconds after a fight.
do
	local scenario = "unverified: a request is offered unread, switch on and after a fight"
	session(scenario, function(ns, ids)
		ns.db.profile.filters.verifiedOnly = true
		annaAsks(ns)
		refuse(ids, "secret")
		local entry = inQueue(ns)[ANNA]
		if not entry then
			fail(scenario, "Anna, who asked, was not offered with her buffs unreadable and the switch on")
		elseif entry.reason ~= "asked" then
			fail(scenario, "Anna was offered as " .. tostring(entry.reason) .. " rather than for asking")
		end
		ns.db.profile.filters.verifiedOnly = false
		fightStarts(ns)
		ns.BuildQueue()
		fightEnds(ns)
		entry = inQueue(ns)[ANNA]
		if not entry then
			fail(scenario, "Anna, who asked, was not offered with her buffs unreadable as the fight ended")
		elseif entry.reason ~= "asked" then
			fail(scenario, "Anna was offered as " .. tostring(entry.reason) .. " rather than for asking")
		end
	end)
end

-- ------------------------------------------------------------ unverified 16
-- Somebody who asked, remembered on a reading the fight withheld and out of
-- sight as it ends: the request is the reason, so the fight's end does not
-- let her go, and with the switch on she is still offered by name.
do
	local scenario = "unverified: a request remembered unread outlives the fight and the switch"
	session(scenario, function(ns, ids)
		annaAsks(ns)
		fightStarts(ns)
		refuse(ids, "secret")
		local entry = inQueue(ns)[ANNA]
		local memo = ns.passersBy[ANNA]
		if not (entry and entry.reason == "asked" and entry.known == nil and memo and memo.withheld) then
			fail(scenario, "SKIPPED -- Anna, who asked, was not offered and remembered on a withheld reading")
			return
		end
		outOfSight(ns)
		fightEnds(ns)
		if not ns.passersBy[ANNA] then
			fail(scenario, "Anna, who asked and is remembered unread, was let go of as the fight ended")
		end
		ns.db.profile.filters.verifiedOnly = true
		entry = inQueue(ns)[ANNA]
		if not entry then
			fail(scenario, "Anna, who asked and is remembered unread, was not offered by name with the switch on")
		end
	end)
end

-- ------------------------------------------------------------ unverified 17
-- "Offer whatever they wear" reads nobody's buffs: nothing was refused, so
-- the switch and the fight hold nobody back.
do
	local scenario = "unverified: offering whatever they wear ignores the switch and the fight"
	session(scenario, function(ns, ids)
		local f = ns.db.profile.filters
		f.whenBuffed, f.verifiedOnly = "always", true
		refuse(ids, "secret")
		if not inQueue(ns)[ANNA] then
			fail(scenario, "offering whatever they wear, Anna was not offered with the switch on")
		end
		fightStarts(ns)
		Mock.advance(4)
		if not inQueue(ns)[ANNA] then
			fail(scenario, "offering whatever they wear, Anna was not offered in the fight")
		end
		fightEnds(ns)
		if not inQueue(ns)[ANNA] then
			fail(scenario, "offering whatever they wear, Anna was not offered as the fight ended")
		end
	end)
end

-- ------------------------------------------------------------ unverified 18
-- The repaint as a fight ends (PLAYER_REGEN_ENABLED) is a scan of its own: it
-- runs after the fight's refusals are dropped and its end is noted, or it
-- offers, from the fight's last scan, somebody unverified in the very second
-- the wait is for. Anna came into sight in the fight and was refused there.
do
	local scenario = "unverified: the repaint as a fight ends waits like any scan"
	session(scenario, function(ns, ids)
		-- Out of sight, and past what is remembered of her.
		outOfSight(ns)
		Mock.advance(11)
		ns.Prompt:Refresh()
		Mock.advance(1)
		ns.Prompt:Refresh()
		if ns.Prompt.state.current then
			fail(scenario, "SKIPPED -- the prompt still names somebody with nobody about")
			return
		end
		refuse(ids, "secret")
		fightStarts(ns)
		inSight(ns)
		local fought = inQueue(ns)[ANNA]
		if not (fought and fought.known == nil) then
			fail(scenario, "SKIPPED -- Anna, unreadable in the fight, was not offered unverified there")
			return
		end
		fightEnds(ns)
		local shown = ns.Prompt.state.current
		if shown and shown.name == ANNA then
			fail(scenario, ("the repaint as the fight ended put Anna on the prompt (known=%s)")
				:format(tostring(shown.known)))
		end
		Mock.auraReadRefuse = nil
		Mock.advance(6)
		ns.Prompt:Refresh()
		shown = ns.Prompt.state.current
		if not (shown and shown.name == ANNA) then
			fail(scenario, "SKIPPED -- Anna, readable and missing the buff, never reached the prompt")
		end
	end)
end

-- ------------------------------------------------------------ unverified 19
-- The client still withholding as the fight ends: the probe made then takes
-- the buff for secret again, and is made once more three seconds on, by when
-- the client answers.
do
	local scenario = "unverified: a probe still refused as a fight ends is made again three seconds on"
	session(scenario, function(ns, _, buff)
		fightStarts(ns)
		Mock.allSecret = true
		ns.Guard("probe", ns.ProbeCapabilities)
		if ns.BuffInfo(buff).readable then
			fail(scenario, "SKIPPED -- the probe in the fight still took the buff for readable")
			Mock.allSecret = false
			return
		end
		fightEnds(ns)
		local still = ns.BuffInfo(buff).readable
		Mock.allSecret = false
		if still then
			fail(scenario, "SKIPPED -- the buff read as readable while the client still withheld")
			return
		end
		Mock.runTimers(3)
		if not ns.BuffInfo(buff).readable then
			fail(scenario, "the buff is still unreadable three seconds after the fight, the client answering again")
		end
	end)
end

-- A probe made out of a fight while the client said it withheld every aura
-- (C_Secrets.ShouldAurasBeSecret) is no better than one made in a fight: the
-- next fight's end makes it again.
do
	local scenario = "unverified: a probe made while the client withheld is made again as a fight ends"
	session(scenario, function(ns, _, buff)
		Mock.allSecret = true
		ns.Guard("probe", ns.ProbeCapabilities)
		Mock.allSecret = false
		if ns.BuffInfo(buff).readable then
			fail(scenario, "SKIPPED -- the probe took the buff for readable while the client withheld")
			return
		end
		fightStarts(ns)
		fightEnds(ns)
		if not ns.BuffInfo(buff).readable then
			fail(scenario, "the buff a probe took for secret while the client withheld is still unreadable after the next fight")
		end
	end)
end

-- ------------------------------------------------------------ unverified 20
-- Refused in the first seconds after a fight, a passer-by remembered as
-- needing the buff is not offered on it ("unread"), and not forgotten either:
-- it is no verdict on her, and the next scan asks again.
do
	local scenario = "unverified: a refusal after a fight is no verdict on a passer-by"
	session(scenario, function(ns, ids)
		local before = inQueue(ns)[ANNA]
		if not (before and before.known == false and ns.passersBy[ANNA]) then
			fail(scenario, "SKIPPED -- Anna was not offered and remembered as needing the buff")
			return
		end
		fightStarts(ns)
		refuse(ids, "secret")
		fightEnds(ns)
		inQueue(ns)
		if not ns.passersBy[ANNA] then
			fail(scenario, "Anna, refused in the first seconds after the fight, was forgotten as a passer-by")
		end
	end)
end

-- ------------------------------------------------------------ unverified 21
-- How long a refusal is trusted: a second in the first seconds after a fight,
-- when the client may answer a moment on; three, as a reading, otherwise.
do
	local scenario = "unverified: a refusal is asked again sooner only just after a fight"
	session(scenario, function(ns, ids)
		refuse(ids, "secret")
		local entry = inQueue(ns)[ANNA]
		if not (entry and entry.known == nil) then
			fail(scenario, "SKIPPED -- Anna, unreadable out of any fight, was not offered unverified")
			return
		end
		Mock.auraReadRefuse = nil
		Mock.advance(1.5)
		entry = inQueue(ns)[ANNA]
		if entry and entry.known ~= nil then
			fail(scenario, "a refusal out of any fight's wake was asked again a second and a half on")
		end
		Mock.advance(2)
		entry = inQueue(ns)[ANNA]
		if not (entry and entry.known == false) then
			fail(scenario, "Anna, readable again and missing the buff, was not read again past three seconds")
		end
		fightStarts(ns)
		refuse(ids, "secret")
		fightEnds(ns)
		inQueue(ns)
		Mock.auraReadRefuse = nil
		Mock.advance(1.5)
		entry = inQueue(ns)[ANNA]
		if not (entry and entry.known == false) then
			fail(scenario, ("a refusal just after a fight was trusted past a second: Anna, readable again and"
				.. " missing the buff, was offered %s"):format(entry and "known=" .. tostring(entry.known) or "nothing"))
		end
	end)
end

-- ------------------------------------------------------------ unverified 22
-- A refusal no fight made (an id declared secret by a probe out of one) will
-- not lift a moment on: she is offered unverified as the fight ends, as
-- before, and remembered on it she is not let go with the fight.
do
	local scenario = "unverified: a refusal for good is offered at once after a fight, and remembered"
	session(scenario, function(ns, _, buff)
		if not declareSecret(ns, buff) then
			fail(scenario, "SKIPPED -- the probe did not take one id alone for secret")
			return
		end
		Mock.advance(4)
		local before = inQueue(ns)[ANNA]
		if not (before and before.known == nil and ns.passersBy[ANNA]) then
			fail(scenario, "SKIPPED -- Anna, refused for good, was not offered unverified and remembered")
			return
		end
		fightStarts(ns)
		Mock.advance(4)
		ns.BuildQueue()
		fightEnds(ns)
		local entry = inQueue(ns)[ANNA]
		if not entry then
			fail(scenario, "Anna, refused for good, was not offered unverified as the fight ended")
		elseif entry.known ~= nil then
			fail(scenario, "a refused reading came back as " .. tostring(entry.known))
		end
		Mock.advance(6)
		fightStarts(ns)
		Mock.advance(4)
		ns.BuildQueue()
		outOfSight(ns)
		fightEnds(ns)
		if not ns.passersBy[ANNA] then
			fail(scenario, "Anna, refused for good, was let go of as a passer-by as the fight ended")
		elseif not inQueue(ns)[ANNA] then
			fail(scenario, "Anna, refused for good, is no longer offered by name after the fight")
		end
	end, true)
end

-- ------------------------------------------------------------ unverified 23
-- What is written in the first seconds after a fight is not trusted past
-- them. A refusal written late in them (4.5 seconds after) is asked again as
-- they end, not a second or three on, and the client, answering for itself by
-- then, says she wears the buff. With the time it is trusted chosen as it is
-- read rather than as it is written, it offered her, unverified, on a refusal
-- written in a wait that had ended since.
do
	local scenario = "unverified: a refusal written late in a fight's wake is not trusted past it"
	session(scenario, function(ns, ids, buff)
		fightStarts(ns)
		refuse(ids, "secret")
		fightEnds(ns)
		Mock.advance(4.5)
		if inQueue(ns)[ANNA] then
			fail(scenario, "SKIPPED -- Anna, refused 4.5 seconds after the fight, was offered unverified")
			return
		end
		Mock.auraReadRefuse = nil
		Mock.held = { [buff.ranks[1]] = true }
		Mock.advance(0.7)
		local entry = inQueue(ns)[ANNA]
		if entry then
			fail(scenario, ("Anna, wearing the buff and readable 5.2 seconds after the fight, was offered"
				.. " (known=%s) on a refusal written before the wait ended"):format(tostring(entry.known)))
		end
	end)
end

-- ------------------------------------------------------------ unverified 24
-- The same for the last reading standing in for a refusal: read wearing the
-- buff, refused in the fight and for 4.9 seconds after it, she is held back
-- on what was last read of her, and not a moment past the wait. Past it the
-- client says she lost the buff: offered, as missing it.
do
	local scenario = "unverified: a kept reading is not held past a fight's wake"
	session(scenario, function(ns, ids, buff)
		Mock.held = { [buff.ranks[1]] = true }
		Mock.advance(4)
		if inQueue(ns)[ANNA] then
			fail(scenario, "SKIPPED -- Anna was offered while read wearing the buff")
			return
		end
		Mock.held = nil
		fightStarts(ns)
		refuse(ids, "secret")
		inQueue(ns)
		fightEnds(ns)
		Mock.advance(4.9)
		if inQueue(ns)[ANNA] then
			fail(scenario, "SKIPPED -- Anna, last read wearing the buff, was offered 4.9 seconds after the fight")
			return
		end
		Mock.auraReadRefuse = nil
		Mock.advance(0.6)
		local entry = inQueue(ns)[ANNA]
		if not entry then
			fail(scenario, "Anna, readable and missing the buff 5.5 seconds after the fight, was still held back"
				.. " on what was last read of her")
		elseif entry.known ~= false then
			fail(scenario, "Anna was offered with known=" .. tostring(entry.known))
		end
	end)
end

-- ------------------------------------------------------------ unverified 25
-- A probe made in a fight takes the buff for secret, and every reading of it
-- is refused before it is asked. Read wearing it before the pull, she is not
-- offered it in the fight: what was last read of her answers the refusal, as
-- for any other.
do
	local scenario = "unverified: a probe made in a fight keeps the last reading for what it refuses"
	session(scenario, function(ns, ids, buff)
		Mock.held, Mock.heldFor = { [buff.ranks[1]] = true }, 1800
		Mock.advance(4)
		if inQueue(ns)[ANNA] then
			fail(scenario, "SKIPPED -- Anna was offered while read wearing the buff")
			return
		end
		Mock.held = nil
		fightStarts(ns)
		Mock.secretAuraIds = {}
		for _, id in ipairs(ids) do Mock.secretAuraIds[id] = true end
		ns.Guard("probe", ns.ProbeCapabilities)
		if ns.BuffInfo(buff).readable then
			fail(scenario, "SKIPPED -- the probe in the fight still took the buff for readable")
			return
		end
		Mock.advance(4)
		local entry = inQueue(ns)[ANNA]
		if entry then
			fail(scenario, ("Anna, read wearing the buff before the fight, was offered (known=%s) in it once a"
				.. " probe made there took the buff for secret"):format(tostring(entry.known)))
		end
	end)
end

-- ------------------------------------------------------------ unverified 26
-- The client still withholding as the fight ends, the probe made then takes
-- the buff for secret again: what it refuses is withheld, and nobody is
-- offered on it in the first seconds, as for any refusal the client may lift
-- a moment on. Past them, as before.
do
	local scenario = "unverified: a probe made as a fight ends marks its refusals withheld"
	session(scenario, function(ns, ids, buff)
		-- The mock builds C_Secrets afresh on every read, so the namespace is
		-- replaced by a copy with one answer changed, and the lazy one put back.
		local copy = {}
		for key, value in pairs(C_Secrets) do copy[key] = value end
		copy.ShouldAurasBeSecret = function() return true end
		local ok, err = pcall(function()
			fightStarts(ns)
			Mock.secretAuraIds = {}
			for _, id in ipairs(ids) do Mock.secretAuraIds[id] = true end
			rawset(_G, "C_Secrets", copy)
			ns.Guard("probe", ns.ProbeCapabilities)
			if ns.BuffInfo(buff).readable then
				fail(scenario, "SKIPPED -- the probe in the fight still took the buff for readable")
				return
			end
			Mock.advance(4)
			inQueue(ns)
			fightEnds(ns)
			if ns.BuffInfo(buff).readable then
				fail(scenario, "SKIPPED -- the probe as the fight ended took the buff for readable")
				return
			end
			local entry = inQueue(ns)[ANNA]
			if entry then
				fail(scenario, ("Anna, refused as the fight ended by a client that still withheld, was offered"
					.. " (known=%s) at once"):format(tostring(entry.known)))
			end
			Mock.advance(6)
			entry = inQueue(ns)[ANNA]
			if not entry then
				fail(scenario, "Anna, still refused well after the fight, is never offered unverified")
			elseif entry.known ~= nil then
				fail(scenario, "a refused reading came back as " .. tostring(entry.known))
			end
		end)
		rawset(_G, "C_Secrets", nil)
		if not ok then error(err, 0) end
	end)
end

-- ------------------------------------------------------------ unverified 27
-- The last reading standing in for a refusal is a refusal all the same, and
-- goes with the fight's: read wearing the buff, refused in the fight, she
-- loses it (dispelled, cancelled) with its timer still running. Readable again
-- as the fight ends, she is offered on the first scan after it, as needing
-- it, not held back for up to three seconds on what was last read of her in
-- the fight.
do
	local scenario = "unverified: a kept reading goes with the fight's refusals"
	session(scenario, function(ns, ids, buff)
		Mock.held, Mock.heldFor = { [buff.ranks[1]] = true }, 1800
		Mock.advance(4)
		if inQueue(ns)[ANNA] then
			fail(scenario, "SKIPPED -- Anna was offered while read wearing the buff")
			return
		end
		Mock.held = nil
		fightStarts(ns)
		refuse(ids, "secret")
		if inQueue(ns)[ANNA] then
			fail(scenario, "SKIPPED -- Anna, last read wearing the buff, was offered in the fight")
			return
		end
		Mock.auraReadRefuse = nil
		fightEnds(ns)
		local entry = inQueue(ns)[ANNA]
		if not entry then
			fail(scenario, "Anna, readable and missing the buff, was not offered on the first scan after the fight:"
				.. " the reading kept in it outlived its end")
		elseif entry.known ~= false then
			fail(scenario, "Anna was offered with known=" .. tostring(entry.known))
		end
	end)
end
