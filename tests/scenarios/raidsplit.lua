-- Sharing the group with other Manners users (Share.lua, sources.share). Two
-- Manners users of one class in a party or raid were both sent to buff the
-- same member. Each Manners now says a small hello to its group over the addon
-- channel, and from the hellos every one works out the same split of the
-- group: an offer nobody asked for goes only to a member of your own share. A
-- favour owed, a request, your target and your focus are never held; a member
-- held for 45 seconds is offered anyway; a user who dies, goes offline or
-- leaves is out of the split at once; one user casts a group cast; and a
-- hello, being another player's word, changes nothing but the split.
--
-- The scenarios play two and three users against one roster: the same people,
-- each with one GUID, seen through each user's own tokens in turn.
--
-- Every scenario name starts with "raidsplit:" so the mutations in
-- tests/mutations/raidsplit.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load

-- A mage's Arcane Intellect in every rank, Arcane Brilliance and its reagent.
local MAGE_SINGLE = { 10157, 10156, 1461, 1460, 1459 }
local BRILLIANCE, ARCANE_POWDER = 23028, 17020

-- One party of five: two mages with Manners, three others. The GUIDs are what
-- every side sorts by, so Anna is first of the users everywhere.
local function party()
	return {
		{ name = { "Anna", "Aim" }, guid = "Player-1-0000000A", class = "MAGE" },
		{ name = { "Bert", "Beside" }, guid = "Player-1-0000000B", class = "MAGE" },
		{ name = { "Cora", "Vell" }, guid = "Player-1-0000000C", class = "PRIEST" },
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
	"IsSpellKnown", "IsPlayerSpell", "GetItemCount", "GetItemInfo", "C_ChatInfo", "C_UnitAuras" }

-- One session: `env.chars` as `env.chars[env.viewer]` sees them.
--   env.raid      the subgroup of each, by index: a raid in place of the party
--   env.flavour   the client (Forever when nil)
--   env.known     spell ids known (the mock's own when nil)
--   env.bags      item counts by id
--   env.chat      false for a client with no C_ChatInfo at all
-- body(ns, ctx): ctx.sent is every addon message the client was handed,
-- ctx.send what it answers (0, Success), ctx.lockdown the chat lockdown,
-- ctx.held[unit] = { [spell id] = true } what a unit wears, ctx.names the
-- units that exist, by token.
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
	local restore = H.strangers(names)
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local ctx = { sent = {}, registered = {}, send = 0, lockdown = false, held = {}, names = names, viewer = viewer }

	-- Whoever a token names, by the name the mock gives it.
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
		-- ctx.withheld: the client keeps everybody else's GUID to itself.
		if char and ctx.withheld and unit ~= "player" then return Mock.SECRET end
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
	rawset(_G, "UnitIsConnected", function(unit)
		local char = unit ~= "player" and who(unit)
		if char and char.offline then return false end
		return true
	end)
	if not env.raid then
		-- Only the party's tokens, and whoever you point at who is one of it.
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
	if env.chat ~= false then
		rawset(_G, "C_ChatInfo", {
			SendAddonMessage = function(...)
				ctx.sent[#ctx.sent + 1] = { n = select("#", ...), ... }
				return ctx.send
			end,
			RegisterAddonMessagePrefix = function(prefix)
				ctx.registered[#ctx.registered + 1] = prefix
				return 0
			end,
			InChatMessagingLockdown = function() return ctx.lockdown end,
		})
	end

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

-- A hello from `char`, as their Manners would word it (Share.Text), heard on
-- the group's channel. `said` changes what it says: keys, on, groups, guid,
-- ask, and `channel`, `sender` and `text` for one that is not what it seems.
local function hello(ns, char, said)
	said = said or {}
	local text = said.text or ns.Share.Text({
		class = said.class or char.class, on = said.on ~= false, groups = said.groups or 255,
		guid = said.guid or char.guid, keys = said.keys or { intellect = "single" },
	}, said.ask)
	ns.addon:CHAT_MSG_ADDON("CHAT_MSG_ADDON", "Manners", text, said.channel or (Mock.raid and "RAID" or "PARTY"),
		said.sender or filed(char), "", 0, 0, "", 0)
end

-- The queue two seconds on, by the name each entry is filed under, and as a
-- sorted list of those names.
local function queue(ns, seconds)
	Mock.advance(seconds or 2)
	local byName, list = {}, {}
	for _, entry in ipairs(ns.BuildQueue()) do
		byName[entry.name] = entry
		list[#list + 1] = entry.name
	end
	table.sort(list)
	return byName, list
end

-- Whose share each of `chars` is in for `key`, by the owner's filed name:
-- "-" for nobody's, nil with no split at all.
local function owners(ns, chars, key)
	ns.Share.Compute()
	local plan = ns.Share.plans[key or "intellect"]
	if not plan then return nil end
	local out = {}
	for _, char in ipairs(chars) do
		local whose = plan.owner[filed(char)]
		out[filed(char)] = whose and whose.name or "-"
	end
	return out
end

local function line(map)
	local keys = {}
	for key in pairs(map) do keys[#keys + 1] = key end
	table.sort(keys)
	local out = {}
	for _, key in ipairs(keys) do out[#out + 1] = key .. "=" .. tostring(map[key]) end
	return table.concat(out, ", ")
end

-- A copy of everything in `t`, to hold a table to what it was.
local function snapshot(t, seen)
	if type(t) ~= "table" then return t end
	seen = seen or {}
	if seen[t] then return seen[t] end
	local out = {}
	seen[t] = out
	for k, v in pairs(t) do out[k] = snapshot(v, seen) end
	return out
end

local function same(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then return a == b end
	for k, v in pairs(a) do
		if not same(v, b[k]) then return false end
	end
	for k in pairs(b) do
		if a[k] == nil then return false end
	end
	return true
end

-- -------------------------------------------------------------- raidsplit 1
-- A new profile has the switch on, and with no other Manners user in the group
-- nothing is different: everybody is offered, and nothing is said about it.
do
	local scenario = "raidsplit: on in a new profile, and with no other user everybody is offered"
	local chars = party()
	with(scenario, { chars = chars }, function(ns)
		if ns.defaults.profile.sources.share ~= true then
			fail(scenario, "the default is " .. tostring(ns.defaults.profile.sources.share) .. ", not on")
		end
		if ns.db.profile.sources.share ~= true then
			fail(scenario, "a new profile has it " .. tostring(ns.db.profile.sources.share))
		end
		local _, list = queue(ns)
		if #list ~= 4 then
			fail(scenario, "alone, the queue is " .. table.concat(list, ", ") .. ", not the four others")
		end
		if #ns.ShareLines() ~= 0 then
			fail(scenario, "with nobody to share with, /manners debug says " .. table.concat(ns.ShareLines(), " | "))
		end
		if next(ns.Share.plans) ~= nil then fail(scenario, "a split was made with no other user") end
	end)
end

-- -------------------------------------------------------------- raidsplit 2
-- Two mages in a party of five, each with Manners. Played from each side:
-- every member is in exactly one share, both sides make the same split, each
-- is offered only their own share, and between them nobody is left out.
do
	local scenario = "raidsplit: two users in a party: every member is in one share, the same on both sides"
	local chars = party()
	local splits, offered = {}, {}
	for viewer = 1, 2 do
		with(scenario, { chars = chars, viewer = viewer }, function(ns)
			hello(ns, chars[3 - viewer])
			splits[viewer] = owners(ns, chars)
			local _, list = queue(ns)
			offered[viewer] = list
		end)
	end
	if not (splits[1] and splits[2]) then
		fail(scenario, "no split was made: " .. tostring(splits[1]) .. " / " .. tostring(splits[2]))
	else
		if line(splits[1]) ~= line(splits[2]) then
			fail(scenario, "Anna works out " .. line(splits[1]) .. " and Bert " .. line(splits[2]))
		end
		local users = { [filed(chars[1])] = true, [filed(chars[2])] = true }
		local shares = {}
		for name, whose in pairs(splits[1]) do
			if not users[whose] then fail(scenario, name .. " is in the share of " .. tostring(whose)) end
			shares[whose] = (shares[whose] or 0) + 1
		end
		-- Each user in their own, and the other three dealt in turn: two and one.
		if splits[1][filed(chars[1])] ~= filed(chars[1]) or splits[1][filed(chars[2])] ~= filed(chars[2]) then
			fail(scenario, "a user is not in their own share: " .. line(splits[1]))
		end
		if shares[filed(chars[1])] ~= 3 or shares[filed(chars[2])] ~= 2 then
			fail(scenario, "the members were not dealt in turn: " .. line(splits[1]))
		end
		-- What each is offered is their own share, and nobody is offered twice.
		local times = {}
		for viewer = 1, 2 do
			for _, name in ipairs(offered[viewer] or {}) do
				times[name] = (times[name] or 0) + 1
				if splits[1][name] ~= filed(chars[viewer]) then
					fail(scenario, filed(chars[viewer]) .. " is offered " .. name .. ", who is in the share of "
						.. tostring(splits[1][name]))
				end
			end
		end
		for i = 3, 5 do
			local name = filed(chars[i])
			if times[name] ~= 1 then
				fail(scenario, name .. " is offered by " .. tostring(times[name] or 0) .. " of the two, not by one")
			end
		end
	end
end

-- -------------------------------------------------------------- raidsplit 3
-- Three mages in a raid of fifteen, one in each of its three subgroups. From
-- each of the three sides: the same split, a whole subgroup to each user,
-- everybody in exactly one share, and nobody offered by two of them.
do
	local scenario = "raidsplit: three users in a raid: the subgroups are dealt in turn, the same on every side"
	local chars, subgroups = raid(15, 5, 3)
	local users = { 1, 6, 11 }
	local splits, offered = {}, {}
	for turn, viewer in ipairs(users) do
		with(scenario, { chars = chars, viewer = viewer, raid = subgroups }, function(ns)
			for _, other in ipairs(users) do
				if other ~= viewer then hello(ns, chars[other]) end
			end
			splits[turn] = owners(ns, chars)
			local _, list = queue(ns)
			offered[turn] = list
		end)
	end
	if not (splits[1] and splits[2] and splits[3]) then
		fail(scenario, "no split was made on every side")
	else
		for turn = 2, 3 do
			if line(splits[turn]) ~= line(splits[1]) then
				fail(scenario, ("%s works out %s and %s works out %s"):format(filed(chars[1]), line(splits[1]),
					filed(chars[users[turn]]), line(splits[turn])))
			end
		end
		-- One subgroup each, whole.
		local bySub, shares = {}, {}
		for _, char in ipairs(chars) do
			local whose = splits[1][filed(char)]
			if whose == "-" then fail(scenario, filed(char) .. " is in nobody's share") end
			if not (char.class == "MAGE") then
				if bySub[char.sub] and bySub[char.sub] ~= whose then
					fail(scenario, "subgroup " .. char.sub .. " is split between " .. bySub[char.sub] .. " and " .. whose)
				end
				bySub[char.sub] = whose
			end
		end
		for sub = 1, 3 do shares[bySub[sub] or "?"] = (shares[bySub[sub] or "?"] or 0) + 1 end
		for _, viewer in ipairs(users) do
			if shares[filed(chars[viewer])] ~= 1 then
				fail(scenario, filed(chars[viewer]) .. " has " .. tostring(shares[filed(chars[viewer])] or 0)
					.. " subgroups, not one: " .. line(bySub))
			end
		end
		local times = {}
		for turn, viewer in ipairs(users) do
			for _, name in ipairs(offered[turn] or {}) do
				times[name] = (times[name] or 0) + 1
				if splits[1][name] ~= filed(chars[viewer]) then
					fail(scenario, filed(chars[viewer]) .. " is offered " .. name .. ", who is in the share of "
						.. tostring(splits[1][name]))
				end
			end
		end
		for _, char in ipairs(chars) do
			if char.class ~= "MAGE" and times[filed(char)] ~= 1 then
				fail(scenario, filed(char) .. " is offered by " .. tostring(times[filed(char)] or 0) .. " users, not one")
			end
		end
	end
end

-- -------------------------------------------------------------- raidsplit 4
-- Whoever is owed a favour, asked for the buff, or is your target or focus is
-- offered whatever share they are in.
do
	local scenario = "raidsplit: a favour owed, a request, your target and your focus ignore the split"
	local chars = party()
	-- Dain is in Bert's share: the second of the three dealt, by GUID.
	local dain = chars[4]
	with(scenario, { chars = chars }, function(ns, ctx)
		hello(ns, chars[2])
		local name = filed(dain)
		local byName = queue(ns)
		if byName[name] then
			fail(scenario, "SKIPPED -- Dain, in Bert's share, is offered before anything singles him out")
			return
		end
		H.owe(ns, name)
		byName = queue(ns)
		if not (byName[name] and byName[name].reason == "owed") then
			fail(scenario, "a favour owed to somebody in the other share was held back")
		end
		wipe(ns.owed)

		ns.db.profile.sources.asked = true
		ns.NoteRequest("PARTY", "int pls", name, dain.guid)
		byName = queue(ns)
		if not (byName[name] and byName[name].reason == "asked") then
			fail(scenario, "a request from somebody in the other share was held back")
		end
		ns.db.profile.sources.asked = false

		for _, token in ipairs({ "target", "focus" }) do
			ctx.names[token] = dain.name
			byName = queue(ns)
			if not byName[name] then
				fail(scenario, "your " .. token .. ", in the other share, was held back")
			end
			ctx.names[token] = nil
		end
		byName = queue(ns)
		if byName[name] then fail(scenario, "with nothing singling him out any more, Dain is still offered") end
	end)
end

-- -------------------------------------------------------------- raidsplit 5
-- Nobody goes without: somebody in the other share who stays held for 45
-- seconds is offered anyway. A hold that lapses (they were buffed, then lost
-- it) starts the 45 seconds again.
do
	local scenario = "raidsplit: nobody goes without: held for 45 seconds, they are offered anyway"
	local chars = party()
	local dain = chars[4]
	with(scenario, { chars = chars }, function(ns, ctx)
		hello(ns, chars[2])
		local name = filed(dain)
		if ns.Share.GRACE ~= 45 then fail(scenario, "the grace is " .. tostring(ns.Share.GRACE) .. " seconds") end
		local byName = queue(ns)
		if byName[name] then
			fail(scenario, "SKIPPED -- Dain, in Bert's share, is offered at once")
			return
		end
		-- Scanned every two seconds: forty seconds on he is still Bert's.
		for _ = 1, 20 do byName = queue(ns) end
		if byName[name] then fail(scenario, "held 40 seconds, Dain is offered already") end
		for _ = 1, 3 do byName = queue(ns) end
		if not byName[name] then fail(scenario, "held 46 seconds and still missing it, Dain is not offered") end
		if byName[name] and byName[name].reason ~= "group" then
			fail(scenario, "offered after the grace as " .. tostring(byName[name].reason))
		end
		-- Bert buffs him at last; a while later it is gone again, and the 45
		-- seconds start afresh.
		ctx.held.party3 = { [10157] = true }
		for _ = 1, 5 do byName = queue(ns) end
		if byName[name] then fail(scenario, "wearing the buff, Dain is offered") end
		ctx.held.party3 = nil
		-- A few scans, the first of which may still read what he wore.
		for _ = 1, 4 do
			byName = queue(ns)
			if byName[name] then
				fail(scenario, "missing it again, Dain is offered with no grace given to Bert")
				break
			end
		end
	end)
end

-- A fight's seconds are not counted: on Classic Era, where a member's buffs
-- are read in a fight as out of one.
do
	local scenario = "raidsplit: the 45 seconds are counted out of a fight"
	local chars = party()
	local dain = chars[4]
	with(scenario, { chars = chars, flavour = "vanilla" }, function(ns)
		hello(ns, chars[2])
		local name = filed(dain)
		local byName = queue(ns)
		if byName[name] then
			fail(scenario, "SKIPPED -- Dain, in Bert's share, is offered at once")
			return
		end
		for _ = 1, 10 do byName = queue(ns) end
		Mock.inCombat = true
		for _ = 1, 20 do byName = queue(ns) end
		Mock.inCombat = false
		if byName[name] then
			fail(scenario, "20 seconds out of a fight and 40 in one, and Dain is offered")
		end
		for _ = 1, 10 do byName = queue(ns) end
		if byName[name] then fail(scenario, "42 seconds out of a fight, and Dain is offered") end
		for _ = 1, 3 do byName = queue(ns) end
		if not byName[name] then fail(scenario, "48 seconds out of a fight, and Dain is not offered") end
	end)
end

-- -------------------------------------------------------------- raidsplit 6
-- A user who dies, goes offline or leaves the group is out of the split at
-- the next scan, and back in it when they are back.
do
	local scenario = "raidsplit: a user who dies, goes offline or leaves is out of the split at once"
	local chars = party()
	local bert, dain = chars[2], chars[4]
	with(scenario, { chars = chars }, function(ns, ctx)
		hello(ns, bert)
		local name = filed(dain)
		local byName = queue(ns)
		if byName[name] then
			fail(scenario, "SKIPPED -- Dain, in Bert's share, is offered at once")
			return
		end
		bert.dead = true
		byName = queue(ns)
		if not byName[name] then fail(scenario, "with Bert dead, his share is still left to him") end
		bert.dead = nil
		byName = queue(ns)
		if byName[name] then fail(scenario, "with Bert back on his feet, his share is not his again") end
		bert.offline = true
		byName = queue(ns)
		if not byName[name] then fail(scenario, "with Bert offline, his share is still left to him") end
		bert.offline = nil
		byName = queue(ns)
		if byName[name] then fail(scenario, "with Bert back online, his share is not his again") end

		-- Bert leaves: the party is four, and the roster says so.
		ctx.names.party1 = chars[3].name
		ctx.names.party2 = chars[4].name
		ctx.names.party3 = chars[5].name
		ctx.names.party4 = nil
		Mock.groupSize = 4
		if Mock.frameEvent("GROUP_ROSTER_UPDATE") < 1 then
			fail(scenario, "nothing listens for the roster changing")
		end
		byName = queue(ns)
		if not byName[name] then fail(scenario, "with Bert gone from the group, his share is still left to him") end
		if next(ns.Share.users) ~= nil then fail(scenario, "Bert is still kept as a user after leaving") end
	end)
end

-- -------------------------------------------------------------- raidsplit 7
-- A hello is another player's word. Malformed, oversized, from outside the
-- group, on another channel, speaking for somebody else or for another class:
-- none of it throws, none of it is taken, and nothing changes -- not the
-- queue, not a setting, not a debt.
do
	local scenario = "raidsplit: a hostile or malformed hello changes nothing and never throws"
	local chars = party()
	local bert, cora = chars[2], chars[3]
	with(scenario, { chars = chars }, function(ns, ctx)
		-- A debt too old to be offered with no token: there to be left alone.
		ns.owed["Zed Zoom"] = { expires = GetTime() + 5000, at = GetTime() - 500, class = "PRIEST" }
		local before = snapshot(ns.db.profile)
		local owed = snapshot(ns.owed)
		local _, baseline = queue(ns)
		local good = ns.Share.Text({ class = "MAGE", on = true, groups = 255, guid = bert.guid,
			keys = { intellect = "single" } }, false)
		local long, wide = {}, {}
		for i = 1, 30 do long[i] = "k" .. i end
		-- Twenty keys of thirteen letters: every field well formed, 300 bytes.
		for i = 1, 20 do wide[i] = "k" .. ("a"):rep(11) .. string.char(96 + i) end
		local cases = {
			{ "a whisper", { channel = "WHISPER" } },
			{ "the guild channel", { channel = "GUILD" } },
			{ "no channel", { text = good, channel = Mock.SECRET } },
			{ "a sender outside the group", { sender = "Zed Zoom" } },
			{ "an empty sender", { sender = "" } },
			{ "a withheld sender", { sender = Mock.SECRET } },
			{ "a sender 200 letters long", { sender = ("x"):rep(200) } },
			{ "another member's GUID", { guid = cora.guid } },
			{ "your own GUID from somebody else", { guid = chars[1].guid } },
			{ "another class", { class = "PRIEST" } },
			{ "a class in small letters", { text = good:gsub(";MAGE;", ";mage;") } },
			{ "a priest speaking as a mage", { sender = filed(cora), guid = cora.guid, class = "MAGE" } },
			{ "300 bytes", { text = good:gsub("intellect", table.concat(wide, ",")) } },
			{ "an eighth field", { text = good .. ";x" } },
			{ "six fields", { text = "H1;1.0;MAGE;g;255;" .. bert.guid } },
			{ "nothing after the tag", { text = "H1;" } },
			{ "empty fields", { text = "H1;;;;;;" } },
			{ "flags that are not flags", { text = good:gsub(";g;", ";gz!;") } },
			{ "raid groups past eight", { text = good:gsub(";255;", ";999;") } },
			{ "raid groups that are not a number", { text = good:gsub(";255;", ";-1;") } },
			{ "a GUID with a pipe in it", { text = good:gsub(bert.guid:gsub("%-", "%%-"), "Player|1") } },
			{ "a GUID with a pipe in it, the client keeping his own back",
				{ text = good:gsub(bert.guid:gsub("%-", "%%-"), "Player|1"), withheld = true } },
			{ "a key in capitals", { text = good:gsub("intellect", "INTELLECT") } },
			{ "a key with a format in it", { text = good:gsub("intellect", "%%s%%d") } },
			{ "thirty keys", { text = good:gsub("intellect", table.concat(long, ",")) } },
			{ "a key 40 letters long", { text = good:gsub("intellect", ("k"):rep(40)) } },
			{ "a build with a colour code", { text = good:gsub("^H1;[^;]*;", "H1;|cffff0000x|r;") } },
		}
		for _, case in ipairs(cases) do
			local label, said = case[1], case[2]
			if #tostring(said.text or "") > 255 and label ~= "300 bytes" then
				fail(scenario, label .. ": the case is over 255 bytes, which is not what it is about")
			end
			ctx.withheld = said.withheld
			hello(ns, bert, said)
			ctx.withheld = nil
			if next(ns.Share.users) ~= nil then
				fail(scenario, label .. ": it was taken for a hello")
				wipe(ns.Share.users)
			end
			local _, now = queue(ns)
			if table.concat(now, ", ") ~= table.concat(baseline, ", ") then
				fail(scenario, label .. ": the queue went from " .. table.concat(baseline, ", ") .. " to "
					.. table.concat(now, ", "))
			end
		end
		-- Every one refused, but the one in another class's name, which is set
		-- aside as any other class's hello is, and the one with your own GUID,
		-- which reads as your own hello come back.
		local stats = ns.Share.stats
		if stats.refused ~= #cases - 2 or stats.other ~= 1 or stats.own ~= 1 then
			fail(scenario, ("of %d bad hellos %d were refused, %d set aside as another class's and %d as your own")
				:format(#cases, stats.refused, stats.other, stats.own))
		end
		-- What the client could hand over in place of text.
		for _, junk in ipairs({ Mock.SECRET, 17, {}, true }) do
			ns.addon:CHAT_MSG_ADDON("CHAT_MSG_ADDON", "Manners", junk, "PARTY", filed(bert))
			ns.addon:CHAT_MSG_ADDON("CHAT_MSG_ADDON", "Manners", good, junk, junk)
		end
		ns.addon:CHAT_MSG_ADDON("CHAT_MSG_ADDON", "Manners")
		if next(ns.Share.users) ~= nil then fail(scenario, "junk in place of text was taken for a hello") end
		if not same(before, ns.db.profile) then fail(scenario, "a hello changed a setting") end
		if not same(owed, ns.owed) then fail(scenario, "a hello changed what is owed") end

		-- And a true one from Bert is taken, and changes the split and no more.
		hello(ns, bert)
		if not ns.Share.users[filed(bert)] then fail(scenario, "a true hello from Bert was not taken") end
		local _, now = queue(ns)
		if #now >= #baseline then fail(scenario, "a true hello from Bert left the queue as it was") end
		if not same(before, ns.db.profile) then fail(scenario, "a true hello changed a setting") end
		-- A flood of them, each saying something else: no more users than senders.
		for i = 1, 200 do
			hello(ns, bert, { groups = i % 256, keys = { intellect = "single", ["k" .. i] = "single" } })
		end
		local count = 0
		for _ in pairs(ns.Share.users) do count = count + 1 end
		if count ~= 1 then fail(scenario, count .. " users kept after one member's 200 hellos") end
	end)
end

-- -------------------------------------------------------------- raidsplit 8
-- The hello itself: said once the group is seen, on PARTY (RAID in a raid),
-- never to one person, under 240 bytes; answered when somebody asks, never
-- two within ten seconds, never in a fight or while the client holds chat
-- back; said again when what it says changes, and tried again when the client
-- refuses it.
do
	local scenario = "raidsplit: the hello is said to the group, throttled, and never in a fight"
	local chars = party()
	with(scenario, { chars = chars }, function(ns, ctx)
		local found
		for _, prefix in ipairs(ctx.registered) do
			if prefix == "Manners" then found = true end
		end
		if not found then fail(scenario, "the prefix is never registered, so no hello is handed on") end
		local function tick(seconds)
			Mock.advance(seconds or 1)
			ns.addon:Tick()
		end
		tick()
		if #ctx.sent ~= 0 then fail(scenario, "a hello was said before the client said the world was there") end
		if Mock.frameEvent("PLAYER_ENTERING_WORLD") < 1 then fail(scenario, "nothing listens for the login") end
		-- In a fight, and under the chat lockdown, nothing is said.
		Mock.inCombat = true
		tick()
		tick(6)
		if #ctx.sent ~= 0 then fail(scenario, "a hello was said in a fight") end
		Mock.inCombat = false
		ctx.lockdown = true
		tick(6)
		if #ctx.sent ~= 0 then fail(scenario, "a hello was said while the client holds chat back") end
		ctx.lockdown = false
		tick(6)
		if #ctx.sent ~= 1 then
			fail(scenario, #ctx.sent .. " hellos were said on logging in to a group, not one")
			return
		end
		local one = ctx.sent[1]
		if one[1] ~= "Manners" or one[3] ~= "PARTY" or one.n ~= 3 then
			fail(scenario, ("the hello went out as %s on %s with %d arguments"):format(tostring(one[1]),
				tostring(one[3]), one.n))
		end
		local text = tostring(one[2])
		if not text:find("^H1;[%w%.%-]+;MAGE;gq;255;" .. chars[1].guid:gsub("%-", "%%-") .. ";intellect$") then
			fail(scenario, "the first hello reads " .. text)
		end
		if #text > 240 then fail(scenario, "the hello is " .. #text .. " bytes") end
		-- Nothing more with nothing new to say.
		for _ = 1, 20 do tick(3) end
		if #ctx.sent ~= 1 then fail(scenario, (#ctx.sent - 1) .. " more hellos with nothing new to say") end

		-- Bert asks: answered, without asking back.
		hello(ns, chars[2], { ask = true })
		tick(1)
		if #ctx.sent ~= 2 then
			fail(scenario, "asked for a hello, " .. (#ctx.sent - 1) .. " were said in answer")
		elseif not tostring(ctx.sent[2][2]):find(";g;255;", 1, true) then
			fail(scenario, "the answer reads " .. tostring(ctx.sent[2][2]))
		end
		-- Asked again at once, and again: one answer, ten seconds on.
		hello(ns, chars[2], { ask = true })
		tick(1)
		hello(ns, chars[2], { ask = true })
		tick(1)
		tick(5)
		if #ctx.sent ~= 2 then fail(scenario, "two hellos went out within ten seconds") end
		tick(5)
		if #ctx.sent ~= 3 then fail(scenario, "the second answer never went out: " .. #ctx.sent .. " said") end

		-- The switch turned off: the others are told within a few seconds, so
		-- they stop leaving a share to you.
		ns.db.profile.sources.share = false
		tick(11)
		tick(6)
		if #ctx.sent ~= 4 then
			fail(scenario, "with the switch turned off, " .. (#ctx.sent - 3) .. " hellos said so")
		elseif not tostring(ctx.sent[4][2]):find(";MAGE;;255;", 1, true) then
			fail(scenario, "with the switch off the hello reads " .. tostring(ctx.sent[4][2]))
		end
		-- Back on, and the client refuses the message (3, throttled): tried
		-- again ten seconds on, not at every tick.
		ns.db.profile.sources.share = true
		ctx.send = 3
		tick(11)
		tick(6)
		local tries = #ctx.sent
		if tries ~= 5 then fail(scenario, "back on, " .. (tries - 4) .. " hellos were tried") end
		tick(1)
		tick(1)
		if #ctx.sent ~= tries then fail(scenario, "a refused hello was tried again at once") end
		ctx.send = 0
		tick(4)
		if #ctx.sent ~= tries + 1 then fail(scenario, "a refused hello was never tried again") end
	end)

	-- In a raid it goes to the raid. On Classic Era, where nothing else asks
	-- the client for the prefix.
	local raiders, subgroups = raid(10, 5, 2)
	with(scenario, { chars = raiders, raid = subgroups, flavour = "vanilla" }, function(ns, ctx)
		if ctx.registered[1] ~= "Manners" then
			fail(scenario, "on Classic Era the prefix is never registered, so no hello is handed on")
		end
		Mock.frameEvent("PLAYER_ENTERING_WORLD")
		Mock.advance(1)
		ns.addon:Tick()
		if #ctx.sent ~= 1 or ctx.sent[1][3] ~= "RAID" or ctx.sent[1].n ~= 3 then
			fail(scenario, "in a raid the hello went to " .. tostring(ctx.sent[1] and ctx.sent[1][3]))
		end
	end)

	-- Alone, nothing is said; and a client with no addon channel breaks nothing.
	with(scenario, { chars = { chars[1] } }, function(ns, ctx)
		Mock.groupSize = 0
		Mock.frameEvent("PLAYER_ENTERING_WORLD")
		Mock.advance(1)
		ns.addon:Tick()
		if #ctx.sent ~= 0 then fail(scenario, "a hello was said with no group to say it to") end
	end)
	with(scenario, { chars = chars, chat = false }, function(ns)
		Mock.frameEvent("PLAYER_ENTERING_WORLD")
		Mock.advance(1)
		ns.addon:Tick()
		hello(ns, chars[2])
		queue(ns)
	end)
end

-- Somebody new on the roster is told, whether or not they ask.
do
	local scenario = "raidsplit: somebody new in the group is said hello to"
	local chars = party()
	with(scenario, { chars = chars }, function(ns, ctx)
		Mock.frameEvent("PLAYER_ENTERING_WORLD")
		Mock.advance(1)
		ns.addon:Tick()
		local said = #ctx.sent
		-- The roster event with nobody new: nothing.
		Mock.advance(20)
		Mock.frameEvent("GROUP_ROSTER_UPDATE")
		ns.addon:Tick()
		if #ctx.sent ~= said then fail(scenario, "a roster event with nobody new brought a hello") end
		-- Edda was not there, and now is.
		ctx.names.party4 = nil
		Mock.groupSize = 4
		Mock.advance(20)
		Mock.frameEvent("GROUP_ROSTER_UPDATE")
		ns.addon:Tick()
		ctx.names.party4 = chars[5].name
		Mock.groupSize = 5
		Mock.advance(20)
		Mock.frameEvent("GROUP_ROSTER_UPDATE")
		ns.addon:Tick()
		if #ctx.sent ~= said + 1 then
			fail(scenario, "somebody new joined, and " .. (#ctx.sent - said) .. " hellos were said")
		end
	end)
end

-- -------------------------------------------------------------- raidsplit 9
-- One user casts the group cast. On Forever Arcane Brilliance reaches the
-- whole raid: Anna, first of the two who can cast it, is offered it for
-- everybody, Bert's subgroup counted and covered too; Bert is never offered
-- one, only his own subgroup one at a time, and /manners debug says why.
do
	local scenario = "raidsplit: one user casts the group cast, and counts the other's share"
	local chars, subgroups = raid(10, 5, 2)
	local known = {}
	for _, id in ipairs(MAGE_SINGLE) do known[#known + 1] = id end
	known[#known + 1] = BRILLIANCE
	local env = { chars = chars, raid = subgroups, known = known, bags = { [ARCANE_POWDER] = 20 } }

	env.viewer = 1
	with(scenario, env, function(ns)
		hello(ns, chars[6], { keys = { intellect = "group" } })
		local byName, list = queue(ns)
		local cast
		for _, name in ipairs(list) do
			if byName[name].groupCast then cast = byName[name] end
		end
		if not cast then
			fail(scenario, "Anna, whose it is to cast, is offered no group cast: " .. table.concat(list, ", "))
			return
		end
		if #list ~= 1 then fail(scenario, "beside the group cast Anna is offered " .. table.concat(list, ", ")) end
		local covers = { [cast.name] = true }
		for _, name in ipairs(cast.groupCast.members) do covers[name] = true end
		for i = 2, 10 do
			if not covers[filed(chars[i])] then
				fail(scenario, "the group cast does not count " .. filed(chars[i]) .. ", of subgroup " .. chars[i].sub)
			end
		end
	end)

	-- Only Bert's subgroup needs it: Anna's cast all the same, aimed at one of them.
	with(scenario, env, function(ns, ctx)
		hello(ns, chars[6], { keys = { intellect = "group" } })
		for i = 2, 5 do ctx.held["raid" .. i] = { [10157] = true } end
		local byName, list = queue(ns)
		local entry = byName[list[1] or ""]
		if #list ~= 1 or not (entry and entry.groupCast) then
			fail(scenario, "with only Bert's subgroup missing it, Anna is offered " .. table.concat(list, ", ")
				.. " and no group cast")
		elseif ctx.who(entry.unit) == nil or ctx.who(entry.unit).sub ~= 2 then
			fail(scenario, "the group cast is aimed at " .. tostring(entry.name) .. ", who is not of Bert's subgroup")
		elseif entry.foldOnly then
			fail(scenario, "the group cast is marked as kept for the fold alone")
		end
	end)

	env.viewer = 6
	with(scenario, env, function(ns)
		hello(ns, chars[1], { keys = { intellect = "group" } })
		local byName, list = queue(ns)
		for _, name in ipairs(list) do
			if byName[name].groupCast then fail(scenario, "Bert is offered a group cast too") end
		end
		if #list ~= 4 then
			fail(scenario, "Bert is offered " .. table.concat(list, ", ") .. ", not the four of his subgroup")
		end
		for _, name in ipairs(list) do
			local char
			for _, c in ipairs(chars) do
				if filed(c) == name then char = c end
			end
			if not char or char.sub ~= 2 then fail(scenario, "Bert is offered " .. name .. ", of Anna's subgroup") end
		end
		local said = table.concat(ns.ShareLines(), " | ")
		if not (said:find("casts it for the group", 1, true) and said:find(filed(chars[1]), 1, true)) then
			fail(scenario, "/manners debug does not say the group cast is Anna's: " .. said)
		end
	end)
end

-- ------------------------------------------------------------- raidsplit 10
-- A raid group you do not buff (Who to buff, Raid groups I buff) is not dealt
-- to you: the split goes by what each user says they take.
do
	local scenario = "raidsplit: a raid group a user does not buff is dealt to the others"
	local chars, subgroups = raid(15, 5, 2)
	with(scenario, { chars = chars, raid = subgroups }, function(ns)
		-- Bert, of group 2, says he buffs group 1 alone (its bit): group 2,
		-- his by the turn, is yours.
		hello(ns, chars[6], { groups = 1 })
		local split = owners(ns, chars)
		if not split then fail(scenario, "no split was made") return end
		for _, char in ipairs(chars) do
			if char.class ~= "MAGE" and char.sub == 2 and split[filed(char)] ~= filed(chars[1]) then
				fail(scenario, filed(char) .. ", of group 2 that Bert does not buff, is in the share of "
					.. tostring(split[filed(char)]))
			end
		end
		hello(ns, chars[6], { groups = 255 })
		-- And yours: with group 3 unticked, it is Bert's whatever the turn says.
		ns.db.profile.filters.skipRaidGroups[3] = true
		split = owners(ns, chars)
		for _, char in ipairs(chars) do
			if char.sub == 3 and split[filed(char)] ~= filed(chars[6]) then
				fail(scenario, filed(char) .. ", of group 3 that you do not buff, is in the share of "
					.. tostring(split[filed(char)]))
			end
		end
	end)
end

-- ------------------------------------------------------------- raidsplit 11
-- A buff that lands on the whole party however it is aimed has one caster,
-- and a class whose buffs replace one another starts each key one further on:
-- the deal itself, from lists every side holds.
do
	local scenario = "raidsplit: a shout has one caster, and a paladin's keys start one further on"
	local chars = party()
	with(scenario, { chars = chars }, function(ns)
		local function users()
			return {
				{ name = "A", guid = "G1", groups = 255, keys = { k = "single" }, me = true },
				{ name = "B", guid = "G2", groups = 255, keys = { k = "single" } },
			}
		end
		local members = {
			{ name = "A", guid = "G1" }, { name = "B", guid = "G2" }, { name = "C", guid = "G3" },
			{ name = "D", guid = "G4" }, { name = "E", guid = "G5" },
		}
		local shout = ns.Share.Deal("k", { key = "k", selfCast = true }, users(), members, false, 0)
		for _, member in ipairs(members) do
			local whose = shout.owner[member.name]
			if not (whose and whose.name == "A") then
				fail(scenario, "a shout for " .. member.name .. " is " .. tostring(whose and whose.name) .. "'s, not the first user's")
			end
		end
		local plain = ns.Share.Deal("k", { key = "k" }, users(), members, false, 0)
		local turned = ns.Share.Deal("k", { key = "k" }, users(), members, false, 1)
		for _, name in ipairs({ "C", "D", "E" }) do
			if plain.owner[name].name == turned.owner[name].name then
				fail(scenario, name .. " is in the same share for a key that starts one further on")
			end
		end
		if plain.owner.A.name ~= "A" or turned.owner.B.name ~= "B" then
			fail(scenario, "a user is not in their own share")
		end
		-- The same lists in another order deal the same.
		local back = { users()[2], users()[1] }
		local shuffled = { members[5], members[3], members[1], members[4], members[2] }
		local again = ns.Share.Deal("k", { key = "k" }, back, shuffled, false, 0)
		for _, member in ipairs(members) do
			if again.owner[member.name].name ~= plain.owner[member.name].name then
				fail(scenario, "the lists in another order put " .. member.name .. " in another share")
			end
		end
	end)
end

-- ------------------------------------------------------------- raidsplit 12
-- The switch off: everybody is offered as before, whoever says hello.
do
	local scenario = "raidsplit: with the switch off everybody is offered, and it is said why"
	local chars = party()
	with(scenario, { chars = chars }, function(ns)
		ns.db.profile.sources.share = false
		hello(ns, chars[2])
		local _, list = queue(ns)
		if #list ~= 4 then
			fail(scenario, "with the switch off the queue is " .. table.concat(list, ", ") .. ", not the four others")
		end
		local said = table.concat(ns.ShareLines(), " | ")
		if not said:find("is switched off", 1, true) then
			fail(scenario, "/manners debug does not say the switch is off: " .. said)
		end
		-- A user whose own hello says they do not share is not counted either.
		ns.db.profile.sources.share = true
		hello(ns, chars[2], { on = false })
		_, list = queue(ns)
		if #list ~= 4 then
			fail(scenario, "with Bert not sharing the queue is " .. table.concat(list, ", "))
		end
		-- Nor one who casts another buff.
		hello(ns, chars[2], { keys = { amplifymagic = "single" } })
		_, list = queue(ns)
		if #list ~= 4 then
			fail(scenario, "with Bert casting another buff the queue is " .. table.concat(list, ", "))
		end
		-- Sharing with Bert, and the switch turned off: from the very next scan.
		hello(ns, chars[2])
		_, list = queue(ns)
		if #list >= 4 then
			fail(scenario, "SKIPPED -- sharing with Bert, the queue is still " .. table.concat(list, ", "))
		end
		ns.db.profile.sources.share = false
		_, list = queue(ns)
		if #list ~= 4 then
			fail(scenario, "the switch turned off, the next scan still leaves Bert his share: " .. table.concat(list, ", "))
		end
	end)
end

-- ------------------------------------------------------------- raidsplit 13
-- The setting: under My party and raid on Who to buff, a step in, hidden with
-- the group off, found by search, put back by the page's reset, and repaired.
do
	local scenario = "raidsplit: the switch sits under My party and raid, and is reset and repaired"
	local chars = party()
	with(scenario, { chars = chars }, function(ns)
		local option = H.findOption(ns.optionsTable, "share")
		if not option then fail(scenario, "no control for the switch") return end
		if type(option.name) ~= "string" or not option.name:find("Manners", 1, true) then
			fail(scenario, "the switch is called " .. tostring(option.name))
		end
		ns.db.profile.sources.group = false
		if not (type(option.hidden) == "function" and option.hidden()) then
			fail(scenario, "shown with My party and raid off")
		end
		ns.db.profile.sources.group = true
		if type(option.hidden) == "function" and option.hidden() then fail(scenario, "hidden with My party and raid on") end
		if H.layoutInToc() then
			local page, section, index = H.placedOn(ns, "who.share")
			local groupPage, groupSection, groupIndex = H.placedOn(ns, "who.group")
			if not page then
				fail(scenario, "the switch is on no page of the window")
			elseif page ~= groupPage or section ~= groupSection or index <= groupIndex then
				fail(scenario, "the switch is not under My party and raid")
			else
				local item = section.items[index]
				if not (type(item) == "table" and item.indent) then fail(scenario, "the switch is not a step in") end
			end
			if ns.WindowLayout.parents["who.share"] ~= "who.group" then
				fail(scenario, "search is not told the switch's parent")
			end
		end
		local listed
		for _, field in ipairs(ns.OptionsPage.RESET.who) do
			if field == "sources.share" then listed = true end
		end
		if not listed then fail(scenario, "the page's reset leaves the switch") end
		ns.db.profile.sources.share = "yes"
		ns.ClampSettings()
		if ns.db.profile.sources.share ~= true then
			fail(scenario, "a damaged value is repaired to " .. tostring(ns.db.profile.sources.share))
		end
	end)
end

-- ------------------------------------------------------------- raidsplit 14
-- /manners debug and the full check-up say who you share with, which share
-- is yours, and what the scan left to somebody else; the check-up names
-- nobody.
do
	local scenario = "raidsplit: /manners debug and the check-up say who you share with and which share is yours"
	local chars = party()
	with(scenario, { chars = chars }, function(ns)
		hello(ns, chars[2])
		queue(ns)
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		local said = table.concat(Mock.printed, "\n")
		if not said:find("sharing your group", 1, true) then
			fail(scenario, "/manners debug says nothing of the share")
		end
		if not said:find(filed(chars[2]), 1, true) then fail(scenario, "/manners debug does not name who you share with") end
		if not (said:find(filed(chars[3]), 1, true) and said:find(filed(chars[5]), 1, true)) then
			fail(scenario, "/manners debug does not say which share is yours")
		end
		if said:find("your share is[^\n]*" .. filed(chars[4])) then
			fail(scenario, "/manners debug counts Dain, of Bert's share, in yours")
		end
		if not said:find("left to another Manners user", 1, true) then
			fail(scenario, "/manners debug does not say the scan left anybody to another user")
		end
		-- The trail's own line about Bert's hello put aside, as when it has
		-- long since rolled off the end: the check-up's part still names nobody.
		ns.db.char.trail = {}
		local report = ns.FullReport()
		if not report:find("== Sharing the group ==", 1, true) then
			fail(scenario, "the check-up has no part about sharing the group")
		end
		if not report:find("intellect: 2 users, yours 3 of 5", 1, true) then
			fail(scenario, "the check-up does not count the share")
		end
		-- In the bug report's own part, at the top, and not only further down.
		local counted, selftest = report:find("share=true users=1", 1, true), report:find("== Self-test ==", 1, true)
		if not (counted and selftest and counted < selftest) then
			fail(scenario, "the bug report does not count the users heard")
		end
		for i = 2, 5 do
			if report:find(filed(chars[i]), 1, true) then
				fail(scenario, "the check-up names " .. filed(chars[i]))
			end
		end
	end)
end

-- ------------------------------------------------------------- raidsplit 15
-- What the addon channel carried before is still read: the one word another
-- Manners sends the author's, on Forever.
do
	local scenario = "raidsplit: the author's line is still heard, and a hello is not taken for it"
	local chars = party()
	chars[1].name = { "Mort", "Defrette" }
	with(scenario, { chars = chars }, function(ns)
		local said = {}
		ns.addon.Print = function(_, text) said[#said + 1] = tostring(text) end
		ns.addon:CHAT_MSG_ADDON("CHAT_MSG_ADDON", "Manners", "author", "WHISPER", "Anna Aim")
		if not table.concat(said, " | "):find("Anna Aim buffed you with Manners", 1, true) then
			fail(scenario, "the author was told: " .. table.concat(said, " | "))
		end
		said = {}
		hello(ns, chars[2])
		if #said ~= 0 then fail(scenario, "a hello printed " .. table.concat(said, " | ")) end
		if not ns.Share.users[filed(chars[2])] then fail(scenario, "the hello after it was not taken") end
	end)
end

-- The ranks of a class's buff, straight out of Buffs.lua, from a copy of the
-- addon loaded for nothing else.
local function ranks(scenario, class, keys)
	Mock.reset()
	local probe = load(scenario)
	local out = {}
	for _, key in ipairs(keys) do
		local buff = probe and probe.FindBuff(class, key)
		for _, id in ipairs(buff and buff.ranks or {}) do out[#out + 1] = id end
	end
	Mock.reset()
	return out
end

-- ------------------------------------------------------------- raidsplit 16
-- What is held back is one buff, not the person: a priest who casts Fortitude
-- and Divine Spirit, sharing with one who casts Fortitude alone, offers Spirit
-- to the other's share at once, and Fortitude to their own.
do
	local scenario = "raidsplit: a buff only you cast is offered to the other's share at once"
	local chars = party()
	chars[1].class, chars[2].class = "PRIEST", "PRIEST"
	chars[3].class = "MAGE"
	local known = ranks(scenario, "PRIEST", { "fortitude", "spirit" })
	local dain = chars[4]
	with(scenario, { chars = chars, known = known }, function(ns)
		if #known == 0 then fail(scenario, "SKIPPED -- no ranks were read for a priest's buffs") return end
		hello(ns, chars[2], { keys = { fortitude = "single" } })
		local name = filed(dain)
		local byName = queue(ns)
		local entry = byName[name]
		if not entry then
			fail(scenario, "Dain, Bert's for Fortitude, is offered nothing, though only you cast Divine Spirit")
		elseif entry.buff.key ~= "spirit" then
			fail(scenario, "Dain, Bert's for Fortitude, is offered " .. tostring(entry.buff.key))
		end
		local cora = byName[filed(chars[3])]
		if not (cora and cora.buff.key == "fortitude") then
			fail(scenario, "Cora, of your own share, is offered " .. tostring(cora and cora.buff.key))
		end
		-- A pin is the one buff: nothing else is offered in its place.
		ns.db.profile.buff.choice = "fortitude"
		byName = queue(ns)
		if byName[name] then
			fail(scenario, "with Fortitude pinned, Dain is offered " .. tostring(byName[name].buff.key))
		end
	end)
end

-- ------------------------------------------------------------- raidsplit 17
-- A paladin's blessings replace one another, so the split starts each one a
-- user further on: of two paladins who both cast Might, Wisdom and Kings,
-- each has a blessing that is theirs to give any one member, and between them
-- a member is offered two blessings, never the same one twice.
do
	local scenario = "raidsplit: two paladins give one member two blessings, and not the same one twice"
	local chars = party()
	chars[1].class, chars[2].class = "PALADIN", "PALADIN"
	chars[3].class, chars[4].class, chars[5].class = "DRUID", "SHAMAN", "HUNTER"
	local keys = { "might", "wisdom", "kings" }
	local known = ranks(scenario, "PALADIN", keys)
	local offered = {}
	for viewer = 1, 2 do
		with(scenario, { chars = chars, viewer = viewer, known = known }, function(ns)
			hello(ns, chars[3 - viewer], { keys = { might = "single", wisdom = "single", kings = "single" } })
			local byName = queue(ns)
			offered[viewer] = {}
			for i = 3, 5 do
				local entry = byName[filed(chars[i])]
				offered[viewer][filed(chars[i])] = entry and entry.buff.key or nil
			end
		end)
	end
	if #known == 0 then
		fail(scenario, "SKIPPED -- no ranks were read for a paladin's blessings")
	else
		for i = 3, 5 do
			local name = filed(chars[i])
			local one, two = offered[1] and offered[1][name], offered[2] and offered[2][name]
			if not (one and two) then
				fail(scenario, ("%s is offered %s by Anna and %s by Bert, not a blessing by each"):format(name,
					tostring(one), tostring(two)))
			elseif one == two then
				fail(scenario, name .. " is offered " .. one .. " by both paladins")
			end
		end
	end
end
