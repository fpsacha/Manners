-- The third hunt of the day, the day's new favours:
--
--   * a Manners user the roster stopped naming while you were in another
--     group (a battleground entered without them) is asked to say hello again
--     once they are back on it (Share.lua, Compute and Tick);
--   * a hello that came before the roster named its sender is asked for again
--     once it does (Share.lua, Read);
--   * a shout left to another Manners user is not offered on yourself through
--     "Remind me of my shout when I'm alone" (Share.lua, ns.ShareShoutHeld;
--     Queue.lua);
--   * before a battleground's gates open the hello says every raid group, as
--     the walk offers every one (Share.lua, Mask);
--   * a Korean or Chinese please beside a one-word name is a small word, and
--     so is a Chinese thanks (Requests.lua, Asks);
--   * "drink" names no water: "need to drink" is somebody sitting down
--     (Courtesy.lua, NAMES);
--   * one member's resurrection says "dead" in its tooltip, not "In your
--     group." (Prompt/Button.lua).
--
-- Every scenario name starts with "hunt3-favours-new:" so the mutations in
-- tests/mutations/hunt3-favours-new.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

-- One party of five: two users of one class first, by GUID, then three others.
local function party(class)
	return {
		{ name = { "Anna", "Aim" }, guid = "Player-1-0000000A", class = class or "MAGE" },
		{ name = { "Bert", "Beside" }, guid = "Player-1-0000000B", class = class or "MAGE" },
		{ name = { "Cora", "Vell" }, guid = "Player-1-0000000C", class = "PRIEST" },
		{ name = { "Dain", "Moor" }, guid = "Player-1-0000000D", class = "WARLOCK" },
		{ name = { "Edda", "Pike" }, guid = "Player-1-0000000E", class = "DRUID" },
	}
end

local function filed(char)
	local pair = char.name
	return Mock.surnames and pair[2] and (pair[1] .. " " .. pair[2]) or pair[1]
end

local TOUCHED = { "UnitGUID", "UnitClass", "UnitIsDeadOrGhost", "UnitIsConnected", "UnitInParty",
	"IsSpellKnown", "IsPlayerSpell", "C_ChatInfo", "C_UnitAuras", "UnitExists", "IsInInstance" }

-- One session: `env.chars` as `env.chars[env.viewer]` sees them, a party, or a
-- raid with `env.raid` the subgroup of each. `env.known` is the spell ids
-- known. body(ns, ctx): ctx.sent is every addon message handed to the client,
-- ctx.names the tokens' names (changed by a scenario to change the roster).
local function with(scenario, env, body)
	Mock.reset()
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
	local restore = strangers(names)
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local ctx = { sent = {}, names = names, viewer = viewer }
	local function who(unit)
		if unit == "player" then return viewer end
		local pair = Mock.unitNames and Mock.unitNames[unit]
		if not pair then return nil end
		for _, char in ipairs(chars) do
			if char.name[1] == pair[1] then return char end
		end
		return nil
	end
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
	local base = C_UnitAuras
	rawset(_G, "C_UnitAuras", setmetatable({
		GetUnitAuraBySpellID = function(unit, spellId)
			if unit == "player" then return base.GetUnitAuraBySpellID(unit, spellId) end
			return nil
		end,
	}, { __index = base }))
	rawset(_G, "C_ChatInfo", {
		SendAddonMessage = function(...)
			ctx.sent[#ctx.sent + 1] = { n = select("#", ...), ... }
			return 0
		end,
		RegisterAddonMessagePrefix = function() return 0 end,
		InChatMessagingLockdown = function() return false end,
	})
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		local sources = ns.db.profile.sources
		sources.group, sources.strangers, sources.self = true, false, false
		ns.Guard("probe", ns.ProbeCapabilities)
		body(ns, ctx)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	-- Back in the order they went on, last first: `saved` was taken after
	-- `strangers` put its own stand-ins up, so its restore goes last or
	-- every later file in this process is left the world of this one.
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	restore()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- A hello from `char`, as their Manners would word it, on the group's channel.
local function hello(ns, char, keys, groups)
	local text = ns.Share.Text({
		class = char.class, on = true, groups = groups or 255, guid = char.guid,
		keys = keys or { intellect = "single" },
	}, false)
	ns.addon:CHAT_MSG_ADDON("CHAT_MSG_ADDON", "Manners", text, Mock.raid and "RAID" or "PARTY",
		filed(char), "", 0, 0, "", 0)
end

-- The roster changed: the event, the ten seconds between two hellos, a tick.
local function rosterChanged(ns)
	Mock.frameEvent("GROUP_ROSTER_UPDATE")
	Mock.advance(11)
	ns.addon:Tick()
end

-- The flags and the raid groups of the hello said last.
local function lastHello(ctx)
	local last = ctx.sent[#ctx.sent]
	if not last then return nil end
	local fields = {}
	for field in (tostring(last[2]) .. ";"):gmatch("([^;]*);") do fields[#fields + 1] = field end
	return fields[4], fields[5]
end

local function ranks(scenario, class, key)
	Mock.reset()
	local probe = load(scenario)
	local out = {}
	local buff = probe and probe.FindBuff(class, key)
	for _, id in ipairs(buff and buff.ranks or {}) do out[#out + 1] = id end
	Mock.reset()
	return out
end

local MAGE_SINGLE = { 10157, 10156, 1461, 1460, 1459 }

-- --------------------------------------------------------------- the hello 1
-- Anna goes into a battleground without Bert: the roster is the team, and
-- Bert is no user of hers there. Back in her party he is new on her roster,
-- but she never left his: only her asking makes him say hello again.
do
	local scenario = "hunt3-favours-new: a user the roster dropped is asked for a hello once back on it"
	local chars = party()
	with(scenario, { chars = chars, known = MAGE_SINGLE }, function(ns, ctx)
		Mock.frameEvent("PLAYER_ENTERING_WORLD")
		Mock.advance(1)
		ns.addon:Tick()
		local flags = lastHello(ctx)
		if not (flags and flags:find("q", 1, true)) then
			fail(scenario, "SKIPPED -- the first hello asks for no answer: " .. tostring(flags))
			return
		end
		hello(ns, chars[2])
		ns.Share.Compute()
		if not ns.Share.users[filed(chars[2])] then
			fail(scenario, "SKIPPED -- Bert's hello was not taken: " .. tostring(ns.Share.stats.why))
			return
		end
		-- The team: somebody else where Bert was.
		ctx.names.party1 = { "Fred", "Far" }
		rosterChanged(ns)
		if ns.Share.users[filed(chars[2])] then
			fail(scenario, "SKIPPED -- Bert is still a user with the roster naming somebody else")
			return
		end
		flags = lastHello(ctx)
		if flags and flags:find("q", 1, true) and #ctx.sent > 1 then
			fail(scenario, "SKIPPED -- the hello to the team already asks for an answer")
			return
		end
		-- And home again.
		local before = #ctx.sent
		ctx.names.party1 = chars[2].name
		rosterChanged(ns)
		if #ctx.sent == before then
			fail(scenario, "back in the party, no hello was said to Bert at all")
			return
		end
		flags = lastHello(ctx)
		if not (flags and flags:find("q", 1, true)) then
			fail(scenario, ("back in the party the hello to Bert, who never saw Anna leave, asks for no answer (flags %q)")
				:format(tostring(flags)))
		end
		-- Asked once: the next hello is a plain one again.
		ctx.names.party4 = { "Gwen", "Gale" }
		rosterChanged(ns)
		flags = lastHello(ctx)
		if flags and flags:find("q", 1, true) then
			fail(scenario, "the hello to somebody new after that still asks for an answer")
		end
	end)
end

-- --------------------------------------------------------------- the hello 2
-- Bert's first hello reaches Anna before her roster names him: refused, and
-- he will not repeat it. Once he is on her roster her hello asks for it.
do
	local scenario = "hunt3-favours-new: a hello heard before the roster names its sender is asked for again"
	local chars = party()
	with(scenario, { chars = chars, known = MAGE_SINGLE }, function(ns, ctx)
		ctx.names.party1 = { "Fred", "Far" }
		Mock.frameEvent("PLAYER_ENTERING_WORLD")
		Mock.advance(1)
		ns.addon:Tick()
		if #ctx.sent ~= 1 then
			fail(scenario, "SKIPPED -- " .. #ctx.sent .. " hellos were said on joining")
			return
		end
		local refused = ns.Share.stats.refused
		hello(ns, chars[2])
		if ns.Share.stats.refused ~= refused + 1 then
			fail(scenario, "SKIPPED -- a hello from somebody the roster does not name was not refused")
			return
		end
		ctx.names.party1 = chars[2].name
		rosterChanged(ns)
		if #ctx.sent < 2 then
			fail(scenario, "no hello was said to Bert once the roster named him")
			return
		end
		local flags = lastHello(ctx)
		if not (flags and flags:find("q", 1, true)) then
			fail(scenario, ("Bert's hello was lost, and the hello said to him asks for no other (flags %q)")
				:format(tostring(flags)))
		end
	end)
end

-- ----------------------------------------------------------------- the shout
-- Two warriors share the party and Anna casts its shout. Bert, with "Remind
-- me of my shout when I'm alone" on, is not offered it on himself because the
-- walk queued it for nobody: it was left to Anna, and he waits as the members
-- do.
do
	local scenario = "hunt3-favours-new: a shout left to another user is not offered on yourself"
	local chars = party("WARRIOR")
	local known = ranks(scenario, "WARRIOR", "battleshout")
	local function shout(ns)
		Mock.advance(2)
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.buff and entry.buff.key == "battleshout" then return entry end
		end
		return nil
	end
	if #known == 0 then
		fail(scenario, "SKIPPED -- no rank of Battle Shout was read for a warrior")
	else
		with(scenario, { chars = chars, known = known, viewer = 2 }, function(ns)
			ns.db.profile.sources.self = true
			ns.db.profile.ownBuffs.shoutAlone = true
			Mock.playerHeld = {}
			H.primeAuras(ns)
			local entry = shout(ns)
			if not entry or entry.reason ~= "group" then
				fail(scenario, "SKIPPED -- with no other user the party is not offered the shout: "
					.. tostring(entry and entry.reason))
				return
			end
			hello(ns, chars[1], { battleshout = "single" })
			ns.Share.Compute()
			local plan = ns.Share.plans.battleshout
			if not (plan and plan.wide and plan.owner[filed(chars[3])] and not plan.owner[filed(chars[3])].me) then
				fail(scenario, "SKIPPED -- the shout is not Anna's to cast")
				return
			end
			entry = shout(ns)
			if entry then
				fail(scenario, ("Anna casts the party's shout, and Bert is offered it on %s (%s)"):format(
					tostring(entry.name), tostring(entry.reason)))
			end
			for _ = 1, 19 do entry = shout(ns) end
			if entry then fail(scenario, "40 seconds on, Bert is offered the shout already (" .. tostring(entry.reason) .. ")") end
			for _ = 1, 4 do entry = shout(ns) end
			if not entry then fail(scenario, "48 seconds on and still missing it, Bert is offered the shout on nobody") end
		end)
	end
end

-- ---------------------------------------------------------- the raid groups
-- Two mages who both leave raid group 2 to somebody else on a raid night. In
-- a battleground before the gates open the walk offers every group, so the
-- hello says every group and group 2 has an owner; with the gates open it
-- says the player's own again.
do
	local scenario = "hunt3-favours-new: before the gates open the hello says every raid group"
	local chars, subgroups = {}, {}
	for i = 1, 10 do
		local sub = math.ceil(i / 5)
		chars[i] = { name = { "R" .. string.char(64 + i), "Stone" }, guid = ("Player-1-%08X"):format(i),
			class = (i == 1 or i == 2) and "MAGE" or "PRIEST", sub = sub }
		subgroups[i] = sub
	end
	with(scenario, { chars = chars, raid = subgroups, known = MAGE_SINGLE }, function(ns, ctx)
		local place = { inside = false, kind = "none" }
		rawset(_G, "IsInInstance", function() return place.inside, place.kind end)
		ns.db.profile.filters.skipRaidGroups[2] = true
		Mock.frameEvent("PLAYER_ENTERING_WORLD")
		Mock.advance(1)
		ns.addon:Tick()
		local _, groups = lastHello(ctx)
		if groups ~= "253" then
			fail(scenario, "SKIPPED -- with raid group 2 unticked the hello says groups " .. tostring(groups))
			return
		end
		-- The other mage's own, as said on the raid night: not group 2 either.
		hello(ns, chars[2], nil, 253)
		ns.Share.Compute()
		local plan = ns.Share.plans.intellect
		if not plan or plan.bySub[2] ~= false then
			fail(scenario, "SKIPPED -- out in the world raid group 2 is somebody's")
			return
		end
		place.inside, place.kind = true, "pvp"
		Mock.playerHeld = { [422621] = true }
		Mock.advance(3)
		if ns.Battle.State() ~= "prep" then
			fail(scenario, "SKIPPED -- not read as before the gates open: " .. tostring(ns.Battle.State()))
			return
		end
		rosterChanged(ns)
		_, groups = lastHello(ctx)
		if groups ~= "255" then
			fail(scenario, "before the gates open the hello says raid groups " .. tostring(groups) .. ", not all of them")
		end
		plan = ns.Share.plans.intellect
		if not (plan and plan.bySub[2] and plan.bySub[2].me) then
			fail(scenario, "before the gates open raid group 2, which the walk offers, is nobody's share")
		end
		-- The gates open.
		Mock.playerHeld = {}
		Mock.advance(3)
		rosterChanged(ns)
		_, groups = lastHello(ctx)
		if groups ~= "253" then
			fail(scenario, "with the gates open the hello says raid groups " .. tostring(groups))
		end
	end)
end

-- ------------------------------------------------------------- the reader
local SPELLS = {
	[1459] = "Arcane Intellect", [5504] = "Conjure Water", [10140] = "Conjure Water", [587] = "Conjure Food",
}

local function mageWorld(scenario, body)
	Mock.reset()
	local restoreUnits = strangers({ party1 = { "Anna", "Aim" } })
	Mock.groupSize = 2
	local touched = { "IsSpellKnown", "IsPlayerSpell", "C_Spell", "GetItemCount", "UnitGUID", "UnitLevel" }
	local saved = {}
	for _, name in ipairs(touched) do saved[name] = rawget(_G, name) end
	local knows = function(id) return SPELLS[id] ~= nil end
	rawset(_G, "IsSpellKnown", knows)
	rawset(_G, "IsPlayerSpell", knows)
	rawset(_G, "C_Spell", setmetatable({
		GetSpellName = function(id) return SPELLS[id] end,
		GetSpellSubtext = function() return nil end,
	}, { __index = saved.C_Spell }))
	rawset(_G, "GetItemCount", function() return 0 end)
	rawset(_G, "UnitGUID", function(unit) return "Player-1-" .. tostring(unit) end)
	rawset(_G, "UnitLevel", function() return 60 end)
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		local sources = ns.db.profile.sources
		sources.asked, sources.strangers, sources.group, sources.self = true, false, false, false
		sources.courtesyRefresh = true
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	for _, name in ipairs(touched) do rawset(_G, name, saved[name]) end
	restoreUnits()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- What Anna is offered after saying `text` in the party: a courtesy's key, the
-- buff's key, or nil.
local function heard(ns, text)
	ns.addon.CHAT_MSG_PARTY(ns.addon, "CHAT_MSG_PARTY", text, "Anna Aim", "Common", "", "", "", 0, 0, "", 0, 1,
		"Player-1-party1")
	local out
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.name == "Anna Aim" then
			out = entry.courtesy and entry.courtesy.key or tostring(entry.buff and entry.buff.key)
		end
	end
	Mock.advance(61)
	return out
end

-- The Korean and Chinese pleases are written inside a word, and a nickname of
-- one word takes only small words beside it: the polite form was the one
-- form never read.
do
	local scenario = "hunt3-favours-new: a Korean or Chinese please beside a one-word name is read"
	mageWorld(scenario, function(ns)
		if heard(ns, "water pls") ~= "courtesy:water" then
			fail(scenario, "SKIPPED -- \"water pls\" is not heard as a request for water")
			return
		end
		for _, ask in ipairs({
			{ "물 주세요", "courtesy:water" }, { "물 부탁", "courtesy:water" }, { "물 부탁해요", "courtesy:water" },
			{ "음식 주세요", "courtesy:food" }, { "求水 请", "courtesy:water" },
		}) do
			local got = heard(ns, ask[1])
			if got ~= ask[2] then
				fail(scenario, ("%q was not heard as %s (%s)"):format(ask[1], ask[2], tostring(got)))
			end
		end
		-- A sentence that only holds the please is no small word.
		for _, text in ipairs({ "물 请问这个怎么样", "물 좋아요" }) do
			local got = heard(ns, text)
			if got then fail(scenario, ("%q put Anna on the prompt for %s"):format(text, got)) end
		end
	end)
end

do
	local scenario = "hunt3-favours-new: a Chinese thanks beside a one-word name is read"
	mageWorld(scenario, function(ns)
		for _, text in ipairs({ "求水 谢谢", "求水 謝謝" }) do
			local got = heard(ns, text)
			if got ~= "courtesy:water" then
				fail(scenario, ("%q was not heard as a request for water (%s)"):format(text, tostring(got)))
			end
		end
	end)
end

-- "need to drink" is a healer sitting down with their own water.
do
	local scenario = "hunt3-favours-new: somebody who says they drink asks for no water"
	mageWorld(scenario, function(ns)
		if heard(ns, "need water") ~= "courtesy:water" then
			fail(scenario, "SKIPPED -- \"need water\" is not heard as a request for water")
			return
		end
		for _, text in ipairs({ "need to drink", "i need to drink", "need drink", "drink", "drinks", "drink?" }) do
			local got = heard(ns, text)
			if got then fail(scenario, ("%q put Anna on the prompt for %s"):format(text, got)) end
		end
	end)
end

-- ----------------------------------------------------------- the tooltip
-- One dead member's resurrection: why they are offered is that they are dead.
do
	local scenario = "hunt3-favours-new: one member's resurrection says dead in its tooltip"
	Mock.reset()
	Mock.class = "PRIEST"
	Mock.groupSize = 4
	local restoreUnits = strangers({ party1 = { "Anna", "Aim" }, party2 = { "Bert", "Beside" } })
	local globals = { "UnitIsDeadOrGhost", "UnitIsGhost", "UnitHasIncomingResurrection", "UnitIsFeignDeath",
		"UnitAffectingCombat", "UnitIsVisible", "UnitInParty", "C_Spell", "IsSpellKnown", "IsPlayerSpell" }
	local saved = {}
	for _, name in ipairs(globals) do saved[name] = rawget(_G, name) end
	local known = { [2006] = true, [2010] = true }
	rawset(_G, "UnitIsDeadOrGhost", function(unit)
		if unit == "player" then return saved.UnitIsDeadOrGhost(unit) end
		return unit == "party1"
	end)
	rawset(_G, "UnitIsGhost", function() return false end)
	rawset(_G, "UnitHasIncomingResurrection", function() return false end)
	rawset(_G, "UnitIsFeignDeath", function() return false end)
	rawset(_G, "UnitAffectingCombat", function() return false end)
	rawset(_G, "UnitIsVisible", function() return true end)
	rawset(_G, "UnitInParty", function(unit) return type(unit) == "string" and unit:find("^party%d") ~= nil end)
	rawset(_G, "C_Spell", setmetatable({
		GetSpellName = function(id) return known[id] and "Resurrection" or saved.C_Spell.GetSpellName(id) end,
		IsSpellUsable = function() return true, false end,
	}, { __index = saved.C_Spell }))
	rawset(_G, "IsSpellKnown", function(id) return known[id] == true end)
	rawset(_G, "IsPlayerSpell", function(id) return known[id] == true end)
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		for _, id in ipairs(ns.FindBuff("PRIEST", "fortitude").ranks) do known[id] = true end
		freshPrompt(ns, scenario)
		local sources = ns.db.profile.sources
		sources.strangers, sources.self = false, false
		ns.Guard("probe", ns.ProbeCapabilities)
		Mock.advance(4)
		local entry
		for _, e in ipairs(ns.BuildQueue()) do
			if e.res and not e.resNames then entry = e end
		end
		if not entry then
			fail(scenario, "SKIPPED -- the dead member is offered no resurrection")
			return
		end
		ns.Prompt:InvalidateMacro()
		ns.Prompt:ApplyTarget(entry)
		local button = ns.Prompt:GetButton()
		for _, kind in ipairs({ "full", "short" }) do
			ns.db.profile.prompt.tooltip = kind
			Mock.tooltip = {}
			if button.scripts.OnEnter then button.scripts.OnEnter(button) end
			local tip = table.concat(Mock.tooltip or {}, " / ")
			if tip == "" then
				fail(scenario, "SKIPPED -- the " .. kind .. " tooltip is not up for the resurrection")
			elseif tip:find("In your group.", 1, true) then
				fail(scenario, "the " .. kind .. " tooltip of a resurrection says no more than \"In your group.\": " .. tip)
			elseif not tip:find(ns.L["dead"], 1, true) then
				fail(scenario, "the " .. kind .. " tooltip of a resurrection does not say they are dead: " .. tip)
			end
			if button.scripts.OnLeave then button.scripts.OnLeave(button) end
		end
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	for _, name in ipairs(globals) do rawset(_G, name, saved[name]) end
	restoreUnits()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end
