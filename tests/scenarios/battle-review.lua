-- Battlegrounds and arenas (Battle.lua and its hooks), the faults a review of
-- them confirmed:
--   1. with Only in range off, a team-mate measured out of a single cast's
--      reach was dropped before the fold of a group cast saw them, where the
--      same people with that switch on are kept for it: ten of the team at
--      forty yards were counted by no Arcane Brilliance;
--   2. a settings string made before a battleground had a section of its own,
--      with Offer nothing in dungeons, raids and battlegrounds ticked, put
--      Buff my team there back on over a profile carried long ago;
--   3. with Buff my team there off, Hold back my target and focus too holds
--      your target back there as well, and neither the switch's text nor
--      /manners debug said so.
--
-- Every scenario name starts with "battle-review:" so the mutations in
-- tests/mutations/battle-review.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load

local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "UnitClass", "UnitLevel", "UnitInParty", "GetItemCount",
	"GetItemInfo", "C_UnitAuras", "IsInInstance", "UnitIsVisible" }

-- The Preparation aura on Forever (Battle.lua, PREPARATION), a mage's Arcane
-- Intellect at its top rank, and the reagent of Arcane Brilliance.
local PREPARATION, INTELLECT, ARCANE_POWDER = 422621, 10157, 17020
local ANNA, BERT, CORA, DAIN, TESS = "Anna Aim", "Bert Beside", "Cora Vell", "Dain Moor", "Tess Target"

-- One session as a mage on WoW Forever with Arcane Intellect, Arcane
-- Brilliance and its powder, in a party of five inside a battleground (`env.kind`:
-- "pvp" unless said, false for out in the world). env.units is everybody else
-- by token: { name = { "Anna", "Aim" }, class = "PRIEST", wears = { [id] = true } }.
-- env.wears is what you wear yourself: Intellect unless said.
local function session(scenario, env, body)
	Mock.reset()
	Mock.setFlavour("camelot")
	Mock.class = "MAGE"
	env.units = env.units or {
		party1 = { name = { "Anna", "Aim" }, class = "PRIEST" },
		party2 = { name = { "Bert", "Beside" }, class = "PRIEST" },
		party3 = { name = { "Cora", "Vell" }, class = "DRUID" },
		party4 = { name = { "Dain", "Moor" }, class = "WARLOCK" },
	}
	env.wears = env.wears or { [INTELLECT] = true }
	env.place = { kind = env.kind == nil and "pvp" or env.kind }
	local names, party = {}, 0
	for token, unit in pairs(env.units) do
		names[token] = unit.name
		if token:find("^party") then party = party + 1 end
	end
	Mock.groupSize = party + 1
	local restoreUnits = H.strangers(names)
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local known = {}
	local function isKnown(id) return known[id] == true end
	rawset(_G, "IsSpellKnown", isKnown)
	rawset(_G, "IsPlayerSpell", isKnown)
	rawset(_G, "IsInInstance", function()
		if env.place.kind then return true, env.place.kind end
		return false, "none"
	end)
	rawset(_G, "GetItemCount", function(id) return id == ARCANE_POWDER and 20 or 0 end)
	rawset(_G, "GetItemInfo", function() return "Reagent" end)
	-- Everybody is within sight: a group spell's hundred yards.
	rawset(_G, "UnitIsVisible", function() return true end)
	rawset(_G, "UnitClass", function(unit)
		local u = env.units[unit]
		if u then return u.class, u.class end
		return saved.UnitClass(unit)
	end)
	rawset(_G, "UnitLevel", function() return 60 end)
	rawset(_G, "UnitInParty", function(unit)
		return type(unit) == "string" and unit:find("^party%d") ~= nil
	end)
	local base = C_UnitAuras
	rawset(_G, "C_UnitAuras", setmetatable({
		GetUnitAuraBySpellID = function(unit, spellId)
			local worn
			if unit == "player" then
				worn = env.wears[spellId]
			else
				local u = env.units[unit]
				worn = u and u.wears and u.wears[spellId]
			end
			if not worn then return nil end
			return { spellId = spellId, expirationTime = Mock.now + 3000,
				sourceUnit = unit == "player" and "player" or nil }
		end,
	}, { __index = base }))

	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		local buff = ns.FindBuff("MAGE", "intellect")
		if not buff then
			fail(scenario, "SKIPPED -- no Arcane Intellect for a mage on this client")
			return
		end
		for _, id in ipairs(buff.ranks or {}) do known[id] = true end
		for _, rank in ipairs(buff.groupCast or {}) do known[rank.id] = true end
		H.freshPrompt(ns, scenario)
		local db = ns.db.profile
		db.sources.strangers = false
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.Prompt:ApplyTarget(nil)
		ns.Prompt:InvalidateMacro()
		ns.addon:Tick()
		body(ns, db)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	restoreUnits()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- The queue as the next scan builds it (the aura cache is three seconds deep,
-- the place two), and its entries for other people by name.
local function queued(ns)
	Mock.advance(4)
	local queue, byName = ns.BuildQueue(), {}
	for _, entry in ipairs(queue) do byName[entry.name] = entry end
	return queue, byName
end

local function listed(queue)
	local out = {}
	for i, entry in ipairs(queue) do
		out[i] = ("%s: %s%s"):format(tostring(entry.name), tostring(entry.buff and entry.buff.key),
			entry.groupCast and (" as a group cast over %d more"):format(#entry.groupCast.members) or "")
	end
	return #out > 0 and table.concat(out, "; ") or "nobody"
end

-- The one group cast of a queue, and how many single casts on other people.
local function casts(queue)
	local group, singles = nil, 0
	for _, entry in ipairs(queue) do
		if entry.groupCast then
			group = group or entry
		elseif entry.reason ~= "self" then
			singles = singles + 1
		end
	end
	return group, singles
end

-- `id` on the person behind `token`, read afresh at the next scan.
local function lands(ns, env, token, id)
	local unit = env.units[token]
	unit.wears = unit.wears or {}
	unit.wears[id] = true
	ns.ForgetUnitAuras(ns.plain(UnitGUID(token)))
end

-- ----------------------------------------------------------- battle-review 1
-- A mage in a battleground, one team-mate beside him and three forty yards
-- off, all four missing Intellect: Arcane Brilliance reaches the whole group
-- within a hundred yards on Forever. With Only in range on the walk keeps the
-- three for the fold alone; with it off they went on as ordinary entries,
-- which Battle.Reach took out before the fold, so the prompt had one single
-- cast and nothing for three. Off must not offer fewer people than on.
for _, state in ipairs({ "open", "prep" }) do
	local scenario = "battle-review: with Only in range off the team out of a single cast's reach is still counted by a group cast ("
		.. state .. ")"
	local env = { wears = { [INTELLECT] = true, [PREPARATION] = state == "prep" or nil } }
	session(scenario, env, function(ns, db)
		if ns.Battle.State() ~= state then
			fail(scenario, "SKIPPED -- the state reads as " .. tostring(ns.Battle.State()))
			return
		end
		Mock.rangeByUnit = { party1 = true, party2 = false, party3 = false, party4 = false }
		db.filters.requireInRange = true
		local queue = queued(ns)
		local group = casts(queue)
		if not (group and group.name == ANNA and #group.groupCast.members == 3) then
			fail(scenario, "SKIPPED -- with Only in range on there is no group cast aimed at Anna over the three: " .. listed(queue))
			return
		end
		db.filters.requireInRange = false
		queue = queued(ns)
		local singles
		group, singles = casts(queue)
		if not group then
			fail(scenario, ("with Only in range off, one of the team beside you and three forty yards off, the queue is %s;"
				.. " it should be the one Arcane Brilliance it is with that switch on"):format(listed(queue)))
		elseif group.name ~= ANNA or #group.groupCast.members ~= 3 then
			fail(scenario, ("with Only in range off the group cast is aimed at %s over %d more; it should be aimed at Anna,"
				.. " beside you, over the three across the yard"):format(tostring(group.name), #group.groupCast.members))
		elseif singles ~= 0 then
			fail(scenario, "with Only in range off somebody has a single cast beside the group cast: " .. listed(queue))
		end
		-- Two of the three buffed since: under the threshold of three, so Anna
		-- keeps her single cast, and Bert, out of its reach, is offered nothing
		-- and is turned down as a verdict, as before.
		lands(ns, env, "party3", INTELLECT)
		lands(ns, env, "party4", INTELLECT)
		Mock.advance(4)
		local verdicts
		queue, verdicts = ns.BuildQueue()
		group, singles = casts(queue)
		local byName = {}
		for _, entry in ipairs(queue) do byName[entry.name] = entry end
		if group or singles ~= 1 or not byName[ANNA] or byName[BERT] then
			fail(scenario, "with two missing it, one of them out of a single cast's reach, the queue is " .. listed(queue)
				.. "; it should be Anna's single Intellect and nothing for Bert")
		end
		if type(verdicts) ~= "table" or verdicts[BERT] ~= true then
			fail(scenario, "Bert, out of reach and in no group cast, is not turned down as a verdict: "
				.. tostring(type(verdicts) == "table" and verdicts[BERT]))
		end
		Mock.rangeByUnit = nil
	end)
end

-- ----------------------------------------------------------- battle-review 2
-- A settings string from before the section, with the instance switch ticked,
-- pasted into a profile carried over long ago: read as that release's saved
-- profile is at login, Buff my team there unticked. A string made since names
-- the team's switch beside that one, so the player's own export comes back as
-- it left.

-- Commands.lua's checksum, to sign a string put together here.
local function checksum(text)
	local h = 0
	for i = 1, #text do h = (h * 31 + text:byte(i)) % 16777213 end
	return ("%06x"):format(h)
end

-- A string as a release from before the section wrote it: every battle.* pair
-- taken out of this one, `extra` (a pair) put in when given, and signed again.
local function before(text, extra)
	local body = text:match("^MNR1:(.*):%x+$")
	if not body then return nil end
	local parts = { extra }
	for pair in (body .. ";"):gmatch("([^;]*);") do
		if pair ~= "" and not pair:find("^battle%.") then parts[#parts + 1] = pair end
	end
	local signed = "MNR1:" .. table.concat(parts, ";")
	return signed .. ":" .. checksum(signed)
end

do
	local scenario = "battle-review: a string from before the section, with the instance switch ticked, is carried when pasted"
	session(scenario, {}, function(ns, db)
		if db.battle.carried ~= true then
			fail(scenario, "SKIPPED -- the profile was not carried over at load")
			return
		end
		-- The friend's settings, as that release held them.
		db.filters.quietInInstances, db.battle.team = true, false
		local old = before(ns.ExportSettings())
		if not old or old:find("battle.", 1, true) or not old:find("filters.quietInInstances=1", 1, true) then
			fail(scenario, "SKIPPED -- no string as an earlier release wrote it: " .. tostring(old))
			return
		end
		-- The player's own: on this version, the team offered.
		db.filters.quietInInstances, db.battle.team = false, true
		local ok, said = ns.ImportSettings(old)
		if not ok then
			fail(scenario, "SKIPPED -- the string did not import: " .. tostring(said))
			return
		end
		if db.filters.quietInInstances ~= true then
			fail(scenario, "SKIPPED -- the instance switch did not travel in the string")
			return
		end
		if db.battle.team ~= false then
			fail(scenario, "the string asked for nothing in dungeons, raids and battlegrounds, and Buff my team there is on after the paste")
		end
		-- And in the battleground the team is not offered.
		local queue = queued(ns)
		local group, singles = casts(queue)
		if group or singles ~= 0 then
			fail(scenario, "after the paste the team is offered in a battleground: " .. listed(queue))
		end

		-- A string made since, both switches on (the player ticked the team
		-- back): it names the team's switch, and comes back as it left.
		db.filters.quietInInstances, db.battle.team = true, true
		local mine = ns.ExportSettings()
		db.battle.team = false
		ok, said = ns.ImportSettings(mine)
		if not ok then
			fail(scenario, "the player's own string did not import: " .. tostring(said))
		elseif db.battle.team ~= true then
			fail(scenario, "the player's own string, both switches on, came back with Buff my team there off")
		end
		-- One that names the team's switch on, whoever wrote it, is taken at its word.
		db.battle.team = false
		ok = ns.ImportSettings(before(mine, "battle.team=1"))
		if not ok then
			fail(scenario, "SKIPPED -- a string naming the team's switch did not import")
		elseif db.battle.team ~= true then
			fail(scenario, "a string that names Buff my team there on lost it to the carry")
		end
		-- And an old string without the instance switch leaves the team on.
		db.filters.quietInInstances, db.battle.team = false, true
		local plain = before(ns.ExportSettings())
		db.battle.team = false
		ok = ns.ImportSettings(plain)
		if not ok then
			fail(scenario, "SKIPPED -- an old string without the instance switch did not import")
		elseif db.battle.team ~= true then
			fail(scenario, "an old string without the instance switch unticked Buff my team there")
		end
		-- The undo puts the player's own back exactly, the team's switch too.
		db.filters.quietInInstances, db.battle.team = true, true
		ok = ns.ImportSettings(old)
		if ok and db.battle.team ~= false then fail(scenario, "SKIPPED -- the second paste was not carried") end
		if ns.UndoImport then
			ns.UndoImport()
			if db.battle.team ~= true or db.filters.quietInInstances ~= true then
				fail(scenario, "the undo did not put Buff my team there back as the player had it")
			end
		end
	end)
end

-- ----------------------------------------------------------- battle-review 3
-- Buff my team there off is the place rule of a battleground, and Hold back my
-- target and focus too takes your target in there as it does under the other
-- two. /manners debug said "nobody but your target or focus is offered here"
-- over an empty prompt, and the switch's text promised the target. Both say it
-- now, and each agrees with what the queue does.
do
	local scenario = "battle-review: /manners debug and the switches say that Hold back my target and focus too reaches a battleground"
	local env = { units = {
		party1 = { name = { "Anna", "Aim" }, class = "PRIEST" },
		target = { name = { "Tess", "Target" }, class = "PRIEST" },
	} }
	session(scenario, env, function(ns, db)
		local function debug()
			Mock.printed = {}
			ns.addon:HandleSlash("debug")
			return table.concat(Mock.printed, "\n")
		end
		local BUT, EVEN = "nobody but your target or focus is offered here", "not even your target or focus"
		-- Tess is of no party token here: a passer-by you picked out.
		db.sources.strangers = true
		db.battle.team, db.filters.quietTargets = false, false
		local queue, byName = queued(ns)
		if byName[ANNA] or not byName[TESS] then
			fail(scenario, "SKIPPED -- with Buff my team there off the queue is not your target alone: " .. listed(queue))
			return
		end
		local text = debug()
		if not text:find(BUT, 1, true) or text:find(EVEN, 1, true) then
			fail(scenario, "with your target offered, /manners debug does not say so: " .. text)
		end
		db.filters.quietTargets = true
		queue, byName = queued(ns)
		if byName[TESS] then
			fail(scenario, "SKIPPED -- Hold back my target and focus too leaves your target offered in a battleground: " .. listed(queue))
			return
		end
		text = debug()
		if text:find(BUT, 1, true) then
			fail(scenario, "your target is held back in a battleground and /manners debug says \"" .. BUT .. "\"")
		end
		if not text:find(EVEN, 1, true) then
			fail(scenario, "/manners debug does not say your target and focus are held back in a battleground too: " .. text)
		elseif not text:find(ns.L["Hold back my target and focus too"], 1, true) then
			fail(scenario, "/manners debug does not name the switch that holds your target back: " .. text)
		end
		-- With the team offered, that switch says nothing here.
		db.battle.team = true
		text = debug()
		if text:find(EVEN, 1, true) or text:find(BUT, 1, true) then
			fail(scenario, "/manners debug speaks of your target with Buff my team there on: " .. text)
		end

		-- The two switches, each naming the other.
		for _, key in ipairs({ "battleTeam", "quietTargets" }) do
			local control = H.findOption(ns.optionsTable, key)
			if not control then
				fail(scenario, "SKIPPED -- no control " .. key)
			else
				local desc = type(control.desc) == "function" and control.desc() or tostring(control.desc)
				if not (desc:find(ns.L["Hold back my target and focus too"], 1, true)
					and desc:find(ns.L["Buff my team there"], 1, true)
					and desc:find("In a battleground or an arena with", 1, true)) then
					fail(scenario, key .. "'s text does not say that Hold back my target and focus too holds your target back"
						.. " in a battleground with Buff my team there off: " .. desc)
				end
			end
		end
	end)
end
