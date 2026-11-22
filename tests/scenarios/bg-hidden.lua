-- A battleground match hides auras (GitHub issue 29). On Forever and retail the
-- reads by id and by name hand back nothing for an aura the client keeps secret
-- just now, so inside a match:
--
--   * after a death your own buffs were never offered again: a refusal gives
--     "unknown", and the walk offers nothing on unknown. A death takes every
--     buff, so until you cast one of a family again a refusal is read as
--     missing, unless the buff outlasts death (throughDeath);
--   * a team-mate you had just buffed came back "unverified" every twelve
--     seconds for the whole match. A cast that landed on them now covers a
--     reading the game hides for the buff's single length, unless they were
--     seen dead since, or the game takes the cast back.
--
-- Whenever the client gives a reading, that reading decides, as ever.
--
-- Every scenario name starts with "bg-hidden:" so the mutations in
-- tests/mutations/bg-hidden.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

local TOUCHED = { "IsInInstance", "UnitIsDeadOrGhost", "UnitIsFeignDeath", "IsSpellKnown", "IsPlayerSpell",
	"GetItemCount", "GetItemInfo" }
local original = {}
for _, name in ipairs(TOUCHED) do original[name] = rawget(_G, name) end

local ANNA = "Anna Aim"
local INTELLECT, BRILLIANCE, ARCANE_POWDER = 1459, 23028, 17020
local MAGE_SINGLE = { 10157, 10156, 1461, 1460, 1459 }

local function partyNames()
	return { party1 = { "Anna", "Aim" }, party2 = { "Bert", "Beside" },
		party3 = { "Cara", "Close" }, party4 = { "Dora", "Deep" } }
end

-- One session as a mage in a party of five, inside a battleground, knowing
-- only what `opts.known` lists (Arcane Intellect when it says nothing) and
-- carrying nothing of his own unless `opts.held` says so. `opts.hide` is the
-- set of spell ids the game keeps secret: their reads come back empty with
-- ShouldSpellAuraBeSecret true, the way a match does it.
local function with(scenario, opts, body)
	Mock.reset()
	Mock.class = "MAGE"
	Mock.groupSize = 5
	Mock.playerHeld = opts.held or {}
	local place = { inside = true, kind = "pvp" }
	rawset(_G, "IsInInstance", function() return place.inside, place.kind end)
	local known = {}
	for _, id in ipairs(opts.known or { INTELLECT }) do known[id] = true end
	rawset(_G, "IsSpellKnown", function(id) return known[id] == true end)
	rawset(_G, "IsPlayerSpell", function(id) return known[id] == true end)
	if opts.powder then
		rawset(_G, "GetItemCount", function(id) return id == ARCANE_POWDER and 20 or 0 end)
		rawset(_G, "GetItemInfo", function(id) return id == ARCANE_POWDER and "Arcane Powder" or nil end)
	end
	local dead = {}
	rawset(_G, "UnitIsDeadOrGhost", function(unit)
		if unit == "player" then return Mock.dead end
		return dead[unit] == true
	end)
	rawset(_G, "UnitIsFeignDeath", function() return false end)
	local undo = strangers(partyNames())
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		ns.db.profile.sources.strangers = false
		body(ns, dead)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	undo()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, original[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- The game keeps these spells' auras secret from now on: the aura read comes
-- back empty and says so when asked.
local function hide(ids)
	Mock.secretAuraIds = {}
	for _, id in ipairs(ids) do Mock.secretAuraIds[id] = true end
	Mock.advance(1)
end

local function entryFor(ns, name)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.name == name then return entry end
	end
	return nil
end

local function mine(ns)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.reason == "self" then return entry end
	end
	return nil
end

local function names(ns)
	local out = {}
	for _, entry in ipairs(ns.BuildQueue()) do out[#out + 1] = entry.name end
	return table.concat(out, ", ")
end

-- The death, and getting up again: the event, then a scan with you alive.
local function die(ns)
	Mock.dead = true
	ns.addon:PLAYER_DEAD()
	Mock.advance(1)
	Mock.dead = false
	ns.addon:PLAYER_ALIVE()
	Mock.advance(1)
end

-- A press on `entry`, the game sending the cast at `name` with `castGUID`,
-- and the cast going through when `succeeded` is not false. The record the
-- settle files is what a hidden reading is covered by.
local function press(ns, entry, name, castGUID, spellId, succeeded)
	local button = ns.Prompt:GetButton()
	Mock.advance(1)
	ns.pendingClick = nil
	ns.Prompt:InvalidateMacro()
	ns.Prompt:ApplyTarget(entry)
	local post = button.scripts.PostClick
	if post then pcall(post, button, "LeftButton", true) end
	if not ns.pendingClick then return false end
	ns.addon:UNIT_SPELLCAST_SENT(nil, "player", name, castGUID, spellId)
	if succeeded ~= false then ns.addon:UNIT_SPELLCAST_SUCCEEDED(nil, "player", castGUID, spellId) end
	return true
end

-- The buff Anna is offered, for how long it lasts.
local function single(ns, entry)
	return ns.BuffSeconds(entry.buff)
end

-- ------------------------------------------------------------- bg-hidden 1
-- Before a death the walk offers nothing on a reading the game hides (core20's
-- rule); a death took the buff, and the game will not say so.
do
	local scenario = "bg-hidden: after a death your own buff is offered though the game hides your auras"
	with(scenario, {}, function(ns)
		hide({ INTELLECT })
		if mine(ns) then
			fail(scenario, "your own buff was offered on a reading the game hides, before any death")
			return
		end
		die(ns)
		local me = mine(ns)
		if not me then
			fail(scenario, "after a death nothing of your own is offered: " .. names(ns))
		else
			if me.buff.key ~= "intellect" then
				fail(scenario, "the buff offered is " .. tostring(me.buff.key) .. ", not Arcane Intellect")
			end
			if me.known ~= false then
				fail(scenario, "it is offered as known == " .. tostring(me.known) .. ", not as missing")
			end
			if me.priority ~= ns.Battle.SELF_FIRST then
				fail(scenario, "it stands at " .. tostring(me.priority) .. ", not first")
			end
		end
	end)
end

-- ------------------------------------------------------------- bg-hidden 2
-- Casting it again ends the guess: what the game hides is taken to be up.
do
	local scenario = "bg-hidden: a cast of your own since the death lets the hidden reading stand"
	with(scenario, {}, function(ns)
		hide({ INTELLECT })
		die(ns)
		if not mine(ns) then
			fail(scenario, "SKIPPED -- nothing of your own offered after the death")
			return
		end
		ns.addon:UNIT_SPELLCAST_SUCCEEDED(nil, "player", "Cast-bg-own", INTELLECT)
		Mock.advance(1)
		local me = mine(ns)
		if me then
			fail(scenario, "Arcane Intellect is still offered after you cast it: " .. tostring(me.buff.key))
		end
	end)
end

-- A cast on a team-mate is not you having the buff again.
do
	local scenario = "bg-hidden: a cast on a team-mate leaves your own reading as it was"
	with(scenario, {}, function(ns)
		hide({ INTELLECT })
		die(ns)
		if not mine(ns) then
			fail(scenario, "SKIPPED -- nothing of your own offered after the death")
			return
		end
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", "Teammate", "Cast-bg-mate", INTELLECT)
		ns.addon:UNIT_SPELLCAST_SUCCEEDED(nil, "player", "Cast-bg-mate", INTELLECT)
		Mock.advance(1)
		if not mine(ns) then
			fail(scenario, "Arcane Intellect is no longer offered after a cast on a team-mate")
		end
	end)
end

-- ------------------------------------------------------------- bg-hidden 3
-- A family of a class's own (a mage's armor) reads the same way.
do
	local scenario = "bg-hidden: a class's own family a death took is offered again"
	local family, ids, ranks
	with(scenario, { known = { INTELLECT } }, function(ns)
		for _, f in ipairs(ns.OWN_BUFFS.MAGE or {}) do
			if f.key == "armor" then family = f end
		end
	end)
	if not family then
		fail(scenario, "SKIPPED -- no armor family for a mage")
	else
		ids, ranks = {}, {}
		for _, spell in ipairs(family.spells) do
			for _, id in ipairs(spell.ranks) do ranks[#ranks + 1] = id end
			for _, id in ipairs(spell.auraIds) do ids[#ids + 1] = id end
		end
		local known = { INTELLECT }
		for _, id in ipairs(ranks) do known[#known + 1] = id end
		with(scenario, { known = known, held = { [INTELLECT] = true } }, function(ns)
			hide(ids)
			local function armorOffered()
				for _, entry in ipairs(ns.BuildQueue()) do
					if entry.reason == "self" and entry.buff and entry.buff.family and entry.buff.family.key == "armor" then return entry end
				end
				return nil
			end
			if armorOffered() then
				fail(scenario, "SKIPPED -- the armor is offered on a hidden reading before any death")
				return
			end
			die(ns)
			if not armorOffered() then
				fail(scenario, "after a death the armor the game hides is not offered: " .. names(ns))
				return
			end
			ns.addon:UNIT_SPELLCAST_SUCCEEDED(nil, "player", "Cast-bg-armor", ranks[1])
			Mock.advance(1)
			if armorOffered() then
				fail(scenario, "the armor is offered again after you cast it")
			end
		end)
	end
end

-- ------------------------------------------------------------- bg-hidden 4
-- A buff that outlasts death is still there after one: the guess is never made.
do
	local scenario = "bg-hidden: a buff that outlasts death is not offered on a hidden reading"
	with(scenario, {}, function(ns)
		local buff = ns.FindBuff("MAGE", "intellect")
		if not buff then
			fail(scenario, "SKIPPED -- no Arcane Intellect for a mage")
			return
		end
		buff.throughDeath = true
		hide({ INTELLECT })
		die(ns)
		local me = mine(ns)
		if me then
			fail(scenario, "a buff that outlasts death is offered after one: " .. tostring(me.buff.key))
		end
		buff.throughDeath = nil
	end)
end

-- ------------------------------------------------------------- bg-hidden 5
-- Anna is offered "unverified", buffed, and not offered again at the next
-- retry while the game hides her buffs; after the buff's own length she is.
do
	local scenario = "bg-hidden: a team-mate you just buffed is not offered again while the game hides their buffs"
	with(scenario, {}, function(ns)
		hide({ INTELLECT })
		local anna = entryFor(ns, ANNA)
		if not anna then
			fail(scenario, "SKIPPED -- Anna is not offered at all: " .. names(ns))
			return
		end
		if anna.known ~= nil then
			fail(scenario, "SKIPPED -- Anna is read as known == " .. tostring(anna.known))
			return
		end
		if not press(ns, anna, ANNA, "Cast-bg-5", INTELLECT) then
			fail(scenario, "SKIPPED -- the press on Anna did not go out")
			return
		end
		Mock.advance(13)
		if entryFor(ns, ANNA) then
			fail(scenario, "Anna is offered again 13 seconds after a cast that landed, though her buffs are hidden")
		end
		Mock.advance(single(ns, anna) + 1)
		if not entryFor(ns, ANNA) then
			fail(scenario, "Anna is never offered again, past the buff's own length")
		end
	end)
end

-- ------------------------------------------------------------- bg-hidden 6
-- Seen dead since the cast, what it covered went with her.
do
	local scenario = "bg-hidden: a team-mate seen dead since your cast is offered again"
	with(scenario, {}, function(ns, dead)
		hide({ INTELLECT })
		local anna = entryFor(ns, ANNA)
		if not (anna and press(ns, anna, ANNA, "Cast-bg-6", INTELLECT)) then
			fail(scenario, "SKIPPED -- Anna was not offered and buffed")
			return
		end
		Mock.advance(13)
		if entryFor(ns, ANNA) then
			fail(scenario, "SKIPPED -- Anna is offered again before she died")
			return
		end
		dead.party1 = true
		ns.addon:Tick()
		dead.party1 = nil
		Mock.advance(1)
		ns.addon:Tick()
		Mock.advance(13)
		if not entryFor(ns, ANNA) then
			fail(scenario, "Anna, seen dead since the cast, is not offered again: " .. names(ns))
		end
	end)
end

-- ------------------------------------------------------------- bg-hidden 7
-- The game takes the cast back a moment later: nothing covers her.
do
	local scenario = "bg-hidden: a late refusal takes the cover back"
	with(scenario, {}, function(ns)
		hide({ INTELLECT })
		local anna = entryFor(ns, ANNA)
		if not (anna and press(ns, anna, ANNA, "Cast-bg-7", INTELLECT, false)) then
			fail(scenario, "SKIPPED -- Anna was not offered and buffed")
			return
		end
		ns.addon:UNIT_SPELLCAST_FAILED(nil, "player", "Cast-bg-7", INTELLECT)
		Mock.advance(3)
		if not entryFor(ns, ANNA) then
			fail(scenario, "Anna is not offered again after the game refused the cast: " .. names(ns))
		end
	end)
end

-- ------------------------------------------------------------- bg-hidden 8
-- A group cast covers everybody it reached. The cast is read while the game
-- still answers, and the match starts hiding after it.
do
	local scenario = "bg-hidden: a group cast covers everybody it reached"
	local known = {}
	for _, id in ipairs(MAGE_SINGLE) do known[#known + 1] = id end
	known[#known + 1] = BRILLIANCE
	with(scenario, { known = known, powder = true }, function(ns)
		local group
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.groupCast then group = group or entry end
		end
		if not group then
			fail(scenario, "SKIPPED -- no group cast is offered for four people missing the buff")
			return
		end
		local reached = { group.name }
		for _, name in ipairs(group.groupCast.members) do reached[#reached + 1] = name end
		if not press(ns, group, group.name, "Cast-bg-8", BRILLIANCE) then
			fail(scenario, "SKIPPED -- the press on the group cast did not go out")
			return
		end
		local ids = {}
		for _, id in ipairs(MAGE_SINGLE) do ids[#ids + 1] = id end
		ids[#ids + 1] = BRILLIANCE
		hide(ids)
		Mock.advance(13)
		local again = {}
		for _, name in ipairs(reached) do
			if entryFor(ns, name) then again[#again + 1] = name end
		end
		if #again > 0 then
			fail(scenario, "people the group cast reached are offered again on a hidden reading: "
				.. table.concat(again, ", "))
		end
	end)
end

-- ------------------------------------------------------------- bg-hidden 9
-- Where the game answers, the answer decides: nothing here is a guess.
do
	local scenario = "bg-hidden: a reading the client gives still decides"
	with(scenario, {}, function(ns)
		-- Nothing hidden: Anna reads as lacking it after the cast, and is offered.
		local anna = entryFor(ns, ANNA)
		if not (anna and press(ns, anna, ANNA, "Cast-bg-9", INTELLECT)) then
			fail(scenario, "SKIPPED -- Anna was not offered and buffed")
			return
		end
		Mock.advance(13)
		local again = entryFor(ns, ANNA)
		if not again then
			fail(scenario, "Anna, read without the buff after your cast, is not offered: " .. names(ns))
		elseif again.known ~= false then
			fail(scenario, "Anna is offered as known == " .. tostring(again.known) .. ", not as missing")
		end
	end)
	with(scenario, { held = { [INTELLECT] = true } }, function(ns)
		-- The game answers for you: Intellect is on, a death or not.
		die(ns)
		Mock.playerHeld = { [INTELLECT] = true }
		Mock.advance(1)
		local me = mine(ns)
		if me then
			fail(scenario, "you are offered " .. tostring(me.buff.key) .. " though the game says you wear it")
		end
	end)
end
