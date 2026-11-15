-- Sharing the group with other Manners users (Share.lua), the faults a review
-- of it confirmed:
--   1. a group the game formed (a dungeon queue, a battleground) talks on
--      INSTANCE_CHAT, and the hello went to PARTY or RAID and was heard there
--      alone;
--   2. the 45 seconds a held member waits started again after every fight;
--   3. a group cast left to another user was left for good, and a hello said
--      `+` for a group version with no reagent in the bags;
--   4. where a buff on anybody lands on the whole party, the user who is not
--      its caster was still offered it on themselves;
--   5. a member kept for the fold alone, whom the group cast was aimed at, read
--      as turned down to the prompt;
--   6. the roster was read at every change with sharing switched off.
--
-- Every scenario name starts with "raidsplit-review:" so the mutations in
-- tests/mutations/raidsplit-review.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load

-- A mage's Arcane Intellect in every rank, Arcane Brilliance and its reagent.
local MAGE_SINGLE = { 10157, 10156, 1461, 1460, 1459 }
local BRILLIANCE, ARCANE_POWDER = 23028, 17020

-- One party of five: two users of one class first, by GUID, then three others.
local function party(class)
	return {
		{ name = { "Anna", "Aim" }, guid = "Player-1-0000000A", class = class or "MAGE" },
		{ name = { "Bert", "Beside" }, guid = "Player-1-0000000B", class = class or "MAGE" },
		{ name = { "Cora", "Vell" }, guid = "Player-1-0000000C", class = "WARRIOR" },
		{ name = { "Dain", "Moor" }, guid = "Player-1-0000000D", class = "WARLOCK" },
		{ name = { "Edda", "Pike" }, guid = "Player-1-0000000E", class = "DRUID" },
	}
end

-- A raid of `size` in subgroups of `per`: the first of each subgroup of the
-- first `users` subgroups a mage, the rest priests.
local function raid(size, per, users)
	local chars, subgroups = {}, {}
	for i = 1, size do
		local sub = math.ceil(i / per)
		local first = (i - 1) % per == 0
		chars[i] = {
			name = { ("R%s"):format(string.char(64 + i)), "Stone" },
			guid = ("Player-1-%08X"):format(i),
			class = (first and sub <= users) and "MAGE" or "PRIEST",
			sub = sub,
		}
		subgroups[i] = sub
	end
	return chars, subgroups
end

-- The name somebody is filed under: with a surname on Forever.
local function filed(char)
	local pair = char.name
	return Mock.surnames and pair[2] and (pair[1] .. " " .. pair[2]) or pair[1]
end

local TOUCHED = { "UnitGUID", "UnitClass", "UnitIsDeadOrGhost", "UnitIsConnected", "UnitInParty",
	"IsSpellKnown", "IsPlayerSpell", "GetItemCount", "GetItemInfo", "C_ChatInfo", "C_UnitAuras",
	"UnitExists", "IsInGroup", "LE_PARTY_CATEGORY_HOME", "LE_PARTY_CATEGORY_INSTANCE" }

-- One session: `env.chars` as `env.chars[env.viewer]` sees them (raidsplit.lua's
-- own, with the globals this file stands in put back as well).
--   env.raid      the subgroup of each, by index: a raid in place of the party
--   env.flavour   the client (Forever when nil)
--   env.known     spell ids known (the mock's own when nil)
--   env.bags      item counts by id
-- body(ns, ctx): ctx.sent is every addon message the client was handed,
-- ctx.held[unit] = { [spell id] = true } what a unit wears.
local function with(scenario, env, body)
	Mock.reset()
	if env.flavour then Mock.setFlavour(env.flavour) end
	local chars = env.chars
	local viewer = chars[env.viewer or 1]
	Mock.class = viewer.class
	Mock.playerName = viewer.name
	local names = {}
	if env.raid then
		Mock.raid = { size = #chars, player = env.viewer or 1, subgroups = env.raid }
		for i, char in ipairs(chars) do names["raid" .. i] = char.name end
	else
		Mock.groupSize = #chars
		local n = 0
		for i, char in ipairs(chars) do
			if i ~= (env.viewer or 1) then
				n = n + 1
				names["party" .. n] = char.name
			end
		end
	end
	-- Saved before H.strangers stands in for UnitExists: saved after it, the
	-- stand-in was what this put back, and every file run after this one in
	-- the same process met a world of these five people only.
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local restore = H.strangers(names)
	local ctx = { sent = {}, send = 0, held = {}, names = names, viewer = viewer }

	local function who(unit)
		if unit == "player" then return viewer end
		local pair = Mock.unitNames and Mock.unitNames[unit]
		if not pair then return nil end
		for _, char in ipairs(chars) do
			if char.name[1] == pair[1] then return char end
		end
		return nil
	end
	ctx.who = who
	rawset(_G, "UnitGUID", function(unit)
		local char = who(unit)
		if char then return char.guid end
		return saved.UnitGUID(unit)
	end)
	rawset(_G, "UnitClass", function(unit)
		local char = unit ~= "player" and who(unit)
		if char then return char.class, char.class end
		return saved.UnitClass(unit)
	end)
	rawset(_G, "UnitIsDeadOrGhost", function(unit)
		local char = unit ~= "player" and who(unit)
		if char and char.dead then return true end
		return saved.UnitIsDeadOrGhost(unit)
	end)
	rawset(_G, "UnitIsConnected", function() return true end)
	if not env.raid then
		rawset(_G, "UnitInParty", function(unit)
			return type(unit) == "string" and (unit:find("^party%d") ~= nil or (unit ~= "player" and who(unit) ~= nil))
		end)
	end
	if env.known then
		local known = {}
		for _, id in ipairs(env.known) do known[id] = true end
		rawset(_G, "IsSpellKnown", function(id) return known[id] == true end)
		rawset(_G, "IsPlayerSpell", function(id) return known[id] == true end)
	end
	if env.bags then
		rawset(_G, "GetItemCount", function(id) return env.bags[id] or 0 end)
		rawset(_G, "GetItemInfo", function(id) return env.bags[id] and "Arcane Powder" or nil end)
	end
	local base = C_UnitAuras
	rawset(_G, "C_UnitAuras", setmetatable({
		GetUnitAuraBySpellID = function(unit, spellId)
			if unit == "player" then return base.GetUnitAuraBySpellID(unit, spellId) end
			local wears = ctx.held[unit]
			if not (wears and wears[spellId]) then return nil end
			return { spellId = spellId, expirationTime = Mock.now + 3600, duration = 3600, sourceUnit = "player" }
		end,
	}, { __index = base }))
	rawset(_G, "C_ChatInfo", {
		SendAddonMessage = function(...)
			ctx.sent[#ctx.sent + 1] = { n = select("#", ...), ... }
			return ctx.send
		end,
		RegisterAddonMessagePrefix = function() return 0 end,
		InChatMessagingLockdown = function() return false end,
	})

	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		H.freshPrompt(ns, scenario)
		local sources = ns.db.profile.sources
		sources.group, sources.strangers, sources.self = true, false, false
		ns.Guard("probe", ns.ProbeCapabilities)
		body(ns, ctx)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	restore()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- A hello from `char`, as their Manners would word it, heard on the group's
-- channel (`said.channel` for another).
local function hello(ns, char, said)
	said = said or {}
	local text = ns.Share.Text({
		class = char.class, on = true, groups = 255, guid = char.guid,
		keys = said.keys or { intellect = "single" },
	}, false)
	ns.addon:CHAT_MSG_ADDON("CHAT_MSG_ADDON", "Manners", text, said.channel or (Mock.raid and "RAID" or "PARTY"),
		filed(char), "", 0, 0, "", 0)
end

-- The queue `seconds` on (two when nil), by the name each entry is filed
-- under, as a sorted list of those names, and the scan's verdicts.
local function queue(ns, seconds)
	Mock.advance(seconds or 2)
	local byName, list = {}, {}
	local entries, verdicts = ns.BuildQueue()
	for _, entry in ipairs(entries) do
		byName[entry.name] = entry
		list[#list + 1] = entry.name
	end
	table.sort(list)
	return byName, list, verdicts
end

-- The ranks of a class's buff on a client, straight out of Buffs.lua, from a
-- copy of the addon loaded for nothing else.
local function ranks(scenario, flavour, class, key)
	Mock.reset()
	if flavour then Mock.setFlavour(flavour) end
	local probe = load(scenario)
	local out = {}
	local buff = probe and probe.FindBuff(class, key)
	for _, id in ipairs(buff and buff.ranks or {}) do out[#out + 1] = id end
	Mock.reset()
	return out
end

local function mageKnows()
	local known = {}
	for _, id in ipairs(MAGE_SINGLE) do known[#known + 1] = id end
	known[#known + 1] = BRILLIANCE
	return known
end

-- ------------------------------------------------------- raidsplit-review 1
-- A dungeon queue's party is the group the roster calls answer for, and it
-- talks on INSTANCE_CHAT: the hello is said there, and one heard there is
-- taken. Your own party still gets PARTY.
do
	local scenario = "raidsplit-review: a group the game formed says its hello on INSTANCE_CHAT and hears it there"
	local chars = party()
	for _, formed in ipairs({ true, false }) do
		with(scenario, { chars = chars }, function(ns, ctx)
			rawset(_G, "LE_PARTY_CATEGORY_HOME", 1)
			rawset(_G, "LE_PARTY_CATEGORY_INSTANCE", 2)
			-- With no category the client answers for whichever group is in hand.
			rawset(_G, "IsInGroup", function(category)
				if category == 2 then return formed end
				if category == 1 then return not formed end
				return true
			end)
			Mock.frameEvent("PLAYER_ENTERING_WORLD")
			Mock.advance(1)
			ns.addon:Tick()
			local first = ctx.sent[1]
			local want = formed and "INSTANCE_CHAT" or "PARTY"
			if not first then
				fail(scenario, "no hello was said at all (" .. want .. " wanted)")
			elseif first[3] ~= want then
				fail(scenario, ("in %s the hello went to %s, not %s"):format(
					formed and "a group the game formed" or "your own party", tostring(first[3]), want))
			end
			if formed then
				hello(ns, chars[2], { channel = "INSTANCE_CHAT" })
				ns.Share.Compute()
				if next(ns.Share.users) == nil then
					fail(scenario, "a hello heard on INSTANCE_CHAT was refused: " .. tostring(ns.Share.stats.why))
				elseif not ns.Share.plans.intellect then
					fail(scenario, "a hello heard on INSTANCE_CHAT made no split")
				end
			end
		end)
	end
end

-- ------------------------------------------------------- raidsplit-review 2
-- The 45 seconds are added up across fights. No scan runs in a fight (the
-- prompt's refresh returns before the queue is built), so a pull is a stretch
-- of silence: twenty seconds waited before it and twenty-six after are the
-- forty-five. Buffed in between, the count does start again.
do
	local scenario = "raidsplit-review: the 45 seconds pause over a fight and go on after it"
	local chars = party()
	local dain = chars[4]
	with(scenario, { chars = chars }, function(ns, ctx)
		hello(ns, chars[2])
		local name = filed(dain)
		local byName = queue(ns)
		if byName[name] then
			fail(scenario, "SKIPPED -- Dain, in Bert's share, is offered at once")
			return
		end
		-- Twenty seconds held, then a fight of half a minute with no scan in it.
		for _ = 1, 10 do byName = queue(ns) end
		Mock.inCombat = true
		Mock.advance(30)
		Mock.inCombat = false
		byName = queue(ns)
		if byName[name] then fail(scenario, "20 seconds out of a fight and 30 in one, and Dain is offered") end
		for _ = 1, 11 do byName = queue(ns) end
		if byName[name] then fail(scenario, "42 seconds out of a fight, and Dain is offered") end
		for _ = 1, 2 do byName = queue(ns) end
		if not byName[name] then
			fail(scenario, "20 seconds before a fight and 26 after it, and Dain is still not offered")
		end
		-- Bert buffs him; when it is gone again the 45 seconds are Bert's afresh,
		-- however long that was.
		ctx.held.party3 = { [10157] = true }
		for _ = 1, 3 do byName = queue(ns) end
		if byName[name] then fail(scenario, "wearing the buff, Dain is offered") end
		ctx.held.party3 = nil
		for _ = 1, 4 do
			byName = queue(ns)
			if byName[name] then
				fail(scenario, "missing it again after being buffed, Dain is offered with no grace given to Bert")
				break
			end
		end
	end)
end

-- ------------------------------------------------------- raidsplit-review 3
-- `+` in a hello names you the group's caster on every side: only with the
-- reagent in the bags.
do
	local scenario = "raidsplit-review: a hello marks a group version only with its reagent in the bags"
	local chars, subgroups = raid(10, 5, 2)
	for _, stocked in ipairs({ false, true }) do
		local env = { chars = chars, raid = subgroups, known = mageKnows(),
			bags = stocked and { [ARCANE_POWDER] = 20 } or {} }
		with(scenario, env, function(ns, ctx)
			Mock.frameEvent("PLAYER_ENTERING_WORLD")
			Mock.advance(1)
			ns.addon:Tick()
			local text = ctx.sent[1] and ctx.sent[1][2]
			if type(text) ~= "string" or not text:find("intellect", 1, true) then
				fail(scenario, "SKIPPED -- the hello does not name Arcane Intellect: " .. tostring(text))
			elseif (text:find("intellect+", 1, true) ~= nil) ~= stocked then
				fail(scenario, ("with %s Arcane Powder in the bags the hello reads %s"):format(
					stocked and "twenty" or "no", text))
			end
		end)
	end
end

-- A group cast left to another user who does not cast it comes back: Bert,
-- second of two mages, is offered no Arcane Brilliance while it is Anna's, and
-- is offered it once it has been hers for 45 seconds.
do
	local scenario = "raidsplit-review: a group cast left to another user for 45 seconds is yours to cast"
	local chars, subgroups = raid(10, 5, 2)
	local env = { chars = chars, raid = subgroups, known = mageKnows(), bags = { [ARCANE_POWDER] = 20 }, viewer = 6 }
	with(scenario, env, function(ns)
		hello(ns, chars[1], { keys = { intellect = "group" } })
		local function cast()
			local byName, list = queue(ns)
			for _, name in ipairs(list) do
				if byName[name].groupCast then return byName[name], list end
			end
			return nil, list
		end
		local group, list = cast()
		if group then
			fail(scenario, "SKIPPED -- Bert is offered the group cast at once, though it is Anna's")
			return
		end
		if #list == 0 then fail(scenario, "SKIPPED -- Bert is offered nobody at all") return end
		for _ = 1, 20 do group = cast() end
		if group then fail(scenario, "left to Anna for 40 seconds, the group cast is offered to Bert already") end
		for _ = 1, 3 do group, list = cast() end
		if not group then
			fail(scenario, "left to Anna for 46 seconds and never cast, the group cast is still not offered to Bert: "
				.. table.concat(list, ", "))
		end
	end)
end

-- ------------------------------------------------------- raidsplit-review 4
-- On Mists a Fortitude on anybody lands on the whole party, so it has one
-- caster: Anna. Bert is offered it on nobody, himself included, until it has
-- gone uncast for 45 seconds.
do
	local scenario = "raidsplit-review: mists: a party-wide buff another user casts is not offered on yourself"
	local chars = party("PRIEST")
	local known = ranks(scenario, "mists", "PRIEST", "fortitude")
	local env = { chars = chars, flavour = "mists", known = known, viewer = 2 }
	local function fortitude(byName)
		for name, entry in pairs(byName) do
			if entry.buff and entry.buff.key == "fortitude" then return name, entry end
		end
		return nil
	end
	if #known == 0 then
		fail(scenario, "SKIPPED -- no rank of Fortitude was read for a priest on Mists")
	else
		with(scenario, env, function(ns)
			ns.db.profile.sources.self = true
			-- Bert wears nothing: the mock's player wears every buff otherwise.
			Mock.playerHeld = {}
			hello(ns, chars[1], { keys = { fortitude = "single" } })
			local plan = ns.Share.Compute() or ns.Share.plans.fortitude
			if not (plan and plan.wide) then
				fail(scenario, "SKIPPED -- Fortitude has no one caster on Mists")
				return
			end
			local byName = queue(ns)
			local name, entry = fortitude(byName)
			if name then
				fail(scenario, ("Anna casts the party's Fortitude, and Bert is offered it on %s (%s)"):format(
					name, tostring(entry.reason)))
			end
			for _ = 1, 20 do byName = queue(ns) end
			name = fortitude(byName)
			if name then fail(scenario, "40 seconds on, Bert is offered Fortitude on " .. name .. " already") end
			for _ = 1, 3 do byName = queue(ns) end
			if not fortitude(byName) then
				fail(scenario, "46 seconds on and still missing it, Bert is offered Fortitude on nobody")
			end
		end)
	end
end

-- ------------------------------------------------------- raidsplit-review 5
-- Anna casts the raid's Arcane Brilliance and only Bert's subgroup needs it:
-- the cast is aimed at one of them, kept for the fold alone. That is somebody
-- being offered a cast, not somebody turned down: the prompt holds no line
-- for it and ends no hold on it.
do
	local scenario = "raidsplit-review: a group cast aimed at the other's share is not a verdict on who it is aimed at"
	local chars, subgroups = raid(10, 5, 2)
	local env = { chars = chars, raid = subgroups, known = mageKnows(), bags = { [ARCANE_POWDER] = 20 } }
	with(scenario, env, function(ns, ctx)
		hello(ns, chars[6], { keys = { intellect = "group" } })
		for i = 2, 5 do ctx.held["raid" .. i] = { [10157] = true } end
		local byName, list, verdicts = queue(ns)
		local entry = byName[list[1] or ""]
		if #list ~= 1 or not (entry and entry.groupCast) then
			fail(scenario, "SKIPPED -- with only Bert's subgroup missing it, Anna is offered " .. table.concat(list, ", "))
			return
		end
		if type(verdicts) ~= "table" then
			fail(scenario, "SKIPPED -- the scan hands back no verdicts")
		elseif verdicts[entry.name] == true then
			fail(scenario, "the group cast is aimed at " .. entry.name .. ", whom the same scan calls turned down")
		end
	end)
	-- With the group cast not reaching the threshold nothing comes of the fold,
	-- and whoever was kept for it is turned down as before.
	with(scenario, env, function(ns, ctx)
		hello(ns, chars[6], { keys = { intellect = "group" } })
		for i = 2, 8 do ctx.held["raid" .. i] = { [10157] = true } end
		local _, list, verdicts = queue(ns)
		if #list ~= 0 then
			fail(scenario, "SKIPPED -- with two of Bert's subgroup missing it, Anna is offered " .. table.concat(list, ", "))
			return
		end
		for i = 9, 10 do
			if type(verdicts) ~= "table" or verdicts[filed(chars[i])] ~= true then
				fail(scenario, filed(chars[i]) .. ", kept for a fold that made no group cast, is not turned down: "
					.. tostring(type(verdicts) == "table" and verdicts[filed(chars[i])]))
			end
		end
	end)
end

-- ------------------------------------------------------- raidsplit-review 6
-- Sharing switched off and nobody to share with: a change of the roster reads
-- nothing. Switched on, the roster is read and the hello said; switched off
-- again, that is said once, and then nothing is read.
do
	local scenario = "raidsplit-review: with sharing off and no other user a roster change reads nobody"
	local chars, subgroups = raid(40, 5, 1)
	with(scenario, { chars = chars, raid = subgroups }, function(ns, ctx)
		local exists, asked = UnitExists, 0
		rawset(_G, "UnitExists", function(unit)
			if type(unit) == "string" and unit:find("^raid%d") then asked = asked + 1 end
			return exists(unit)
		end)
		local function change(seconds)
			Mock.advance(seconds or 1)
			asked = 0
			ns.Share.OnEvent()
			ns.Share:Tick(Mock.now)
			return asked
		end
		ns.db.profile.sources.share = false
		local n = change()
		if n ~= 0 then fail(scenario, "with sharing off, a roster change asked after " .. n .. " raid tokens") end
		if #ctx.sent ~= 0 then fail(scenario, "with sharing off a hello was said") end
		ns.db.profile.sources.share = true
		n = change(11)
		if n == 0 then fail(scenario, "with sharing on, a roster change read nobody") end
		if #ctx.sent ~= 1 then fail(scenario, "with sharing on, " .. #ctx.sent .. " hellos were said, not one") end
		ns.db.profile.sources.share = false
		change(11)
		if #ctx.sent ~= 2 then
			fail(scenario, "switched off after a hello, " .. (#ctx.sent - 1) .. " hellos said so, not one")
		end
		n = change(11)
		if n ~= 0 then
			fail(scenario, "switched off and said so, a roster change still asked after " .. n .. " raid tokens")
		end
		if #ctx.sent ~= 2 then fail(scenario, "switched off, it is said again at every roster change") end
		rawset(_G, "UnitExists", exists)
	end)
end
