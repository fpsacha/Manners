-- Battlegrounds and arenas, a situation of their own (1.11.25, Battle.lua). A
-- player wrote that after each death in a battleground the prompt was on the
-- wrong thing. What a battleground or an arena changes, each behind the
-- section In battlegrounds and arenas on Quiet times:
--
--   * what you are missing of your own comes ahead of the team, the people a
--     graveyard raised beside you included; what you fight with before the
--     long extras; what is missing before what only runs low;
--   * before the gates open (the Preparation aura, by each client's own id)
--     the whole team is offered freely: no mana floor, every raid group, the
--     group casts first;
--   * once they are open, nobody else is offered while you fight, and only
--     somebody within reach;
--   * nothing is said there, and thanks go to your own team alone;
--   * consumables held to dungeons and raids stay held, until ticked.
--
-- Buff my team there decides inside a battleground or an arena whatever Offer
-- nothing in dungeons, raids and battlegrounds says; ticking that one unticks
-- it, and a profile that had it ticked is carried over once. Nothing changes
-- anywhere else.
--
-- Every scenario name starts with "battleground:" so the mutations in
-- tests/mutations/battleground.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe, findOption = H.strangers, H.freshPrompt, H.owe, H.findOption
local primeAuras, favourFrom = H.primeAuras, H.favourFrom

-- Globals the scenarios replace, put back after each: Mock.reset owns none.
local TOUCHED = { "IsInInstance", "UnitAffectingCombat", "UnitIsDeadOrGhost", "UnitIsFeignDeath", "DoEmote",
	"UnitInRaid", "UnitInParty" }
local original = {}
for _, name in ipairs(TOUCHED) do original[name] = rawget(_G, name) end

local ANNA, BERT, CARA, DORA, ZED = "Anna Aim", "Bert Beside", "Cara Close", "Dora Deep", "Zed Far"
local function partyNames()
	return { party1 = { "Anna", "Aim" }, party2 = { "Bert", "Beside" },
		party3 = { "Cara", "Close" }, party4 = { "Dora", "Deep" } }
end

-- The Preparation aura's id on Forever (Battle.lua, PREPARATION), and the
-- mock's Arcane Intellect.
local PREPARATION, INTELLECT = 422621, 1459

-- One session as a mage in a party of five, out in the world until the body
-- says otherwise. `opts.held` is what the player wears (nothing: every buff
-- of your own is missing, and the gates are open); `opts.people` the tokens.
-- `place` is where the game says you are.
local function with(scenario, opts, body)
	Mock.reset()
	Mock.class = opts.class or "MAGE"
	if opts.flavour then Mock.setFlavour(opts.flavour) end
	if opts.raid then Mock.raid = opts.raid else Mock.groupSize = opts.groupSize or 5 end
	Mock.playerHeld = opts.held or {}
	local place = { inside = false, kind = "none" }
	rawset(_G, "IsInInstance", function() return place.inside, place.kind end)
	for name, value in pairs(opts.globals or {}) do rawset(_G, name, value) end
	local undo = strangers(opts.people or partyNames())
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		ns.db.profile.sources.strangers = false
		body(ns, place)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	undo()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, original[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- Into an instance of that kind, or out of one: past the two seconds the
-- answer is kept for (Battle.lua, Where), as a loading screen is.
local function go(place, kind)
	place.inside, place.kind = kind ~= nil, kind or "none"
	Mock.advance(3)
end

-- What the player wears from now on, read at a new moment.
local function wear(held)
	Mock.playerHeld = held
	Mock.advance(1)
end

local function names(ns)
	local out = {}
	for _, entry in ipairs(ns.BuildQueue()) do out[#out + 1] = entry.name end
	return table.concat(out, ", ")
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

local function key(entry) return tostring(entry and entry.buff and entry.buff.key) end

-- ------------------------------------------------------------ battleground 1
-- The three states, read from the game's word on where you are, the
-- Preparation aura and the fight: nothing anywhere but a battleground or an
-- arena.
do
	local scenario = "battleground: prep, fight and open are read from the place, the aura and the fight"
	with(scenario, {}, function(ns, place)
		local Battle = ns.Battle
		if Battle.State() ~= nil then fail(scenario, "out in the world reads as " .. tostring(Battle.State())) end
		for _, kind in ipairs({ "party", "raid", "scenario" }) do
			go(place, kind)
			if Battle.State() ~= nil then fail(scenario, "a " .. kind .. " instance reads as a battleground") end
		end
		for _, kind in ipairs({ "pvp", "arena" }) do
			go(place, kind)
			if Battle.State() ~= "open" then
				fail(scenario, ("in a %s instance with nothing on you the state is %s"):format(kind, tostring(Battle.State())))
			end
			wear({ [PREPARATION] = true })
			if Battle.State() ~= "prep" then
				fail(scenario, ("in a %s instance under Preparation the state is %s"):format(kind, tostring(Battle.State())))
			end
			Mock.inCombat = true
			wear({})
			if Battle.State() ~= "fight" then
				fail(scenario, ("in a %s instance in combat the state is %s"):format(kind, tostring(Battle.State())))
			end
			Mock.inCombat = false
			-- The pull's own repaint comes just before the lockdown, with the
			-- combat flag already up.
			rawset(_G, "UnitAffectingCombat", function(unit) return unit == "player" end)
			if Battle.State() ~= "fight" then
				fail(scenario, "the combat flag up before the lockdown is not read as a fight in a " .. kind .. " instance")
			end
			rawset(_G, "UnitAffectingCombat", original.UnitAffectingCombat)
		end
		-- The game's 1 for true counts; a client that will not say is in none.
		place.inside = 1
		Mock.advance(3)
		if Battle.State() ~= "open" then fail(scenario, "the game's 1 for inside is not read as inside") end
		for label, fn in pairs({
			secret = function() return Mock.SECRET, Mock.SECRET end,
			throws = function() error("refused", 0) end,
			nokind = function() return true, nil end,
		}) do
			rawset(_G, "IsInInstance", fn)
			Mock.advance(3)
			local ok, state = pcall(Battle.State)
			if not ok then
				fail(scenario, "a client that will not say where you are (" .. label .. ") threw: " .. tostring(state))
			elseif state ~= nil then
				fail(scenario, ("a client that will not say where you are (%s) reads as %s"):format(label, tostring(state)))
			end
		end
	end)
end

-- ------------------------------------------------------------ battleground 2
-- The aura is each client's own: Preparation 422621 on Forever and Classic
-- Era, the battleground's 44521 and the arena's 32727 on Burning Crusade,
-- Mists and retail. Another client's id is no aura here.
for _, case in ipairs({
	{ "camelot", { 422621 }, 44521 },
	{ "vanilla", { 422621 }, 44521 },
	{ "tbc", { 44521, 32727, 32728 }, 422621 },
	{ "mists", { 44521, 32727, 32728 }, 422621 },
	{ "mainline", { 44521, 32727, 32728 }, 422621 },
}) do
	local flavour, ids, foreign = case[1], case[2], case[3]
	local scenario = "battleground: the Preparation aura is read by this client's own id (" .. flavour .. ")"
	with(scenario, { flavour = flavour }, function(ns, place)
		go(place, "pvp")
		for _, id in ipairs(ids) do
			wear({ [id] = true })
			if ns.Battle.State() ~= "prep" then
				fail(scenario, ("on %s, aura %d is not read as the gates being shut"):format(flavour, id))
			end
		end
		wear({ [foreign] = true })
		if ns.Battle.State() ~= "open" then
			fail(scenario, ("on %s, aura %d of another client is read as the gates being shut"):format(flavour, foreign))
		end
	end)
end

-- ------------------------------------------------------------ battleground 3
-- A graveyard raises you and the people beside you at once. Everybody raised
-- is "back from the dead" and stood ahead of your own buff; in a battleground
-- what you are missing yourself comes first, and they come straight after.
do
	local scenario = "battleground: after a death your own buff comes ahead of the team raised beside you"
	local dead = {}
	local function deadOrGhost(unit)
		if unit == "player" then return Mock.dead end
		return dead[unit] == true
	end
	with(scenario, { globals = { UnitIsDeadOrGhost = deadOrGhost, UnitIsFeignDeath = function() return false end } },
		function(ns, place)
			local function raise()
				dead.party2 = true
				ns.addon:Tick()
				dead.party2 = nil
				ns.addon:Tick()
			end
			-- Out in the world, as ever: the one raised first, you behind.
			raise()
			local queue = ns.BuildQueue()
			if not (queue[1] and queue[1].name == BERT and queue[1].sweep == "revived") then
				fail(scenario, "SKIPPED -- out in the world somebody raised is not first: " .. names(ns))
				return
			end
			local me = mine(ns)
			if not (me and me.priority == 1.75) then
				fail(scenario, "SKIPPED -- out in the world your own missing buff is not at its usual place: "
					.. tostring(me and me.priority))
				return
			end
			go(place, "pvp")
			raise()
			queue = ns.BuildQueue()
			if not (queue[1] and queue[1].reason == "self") then
				fail(scenario, "in a battleground your own missing buff is not first after a death: " .. names(ns))
			elseif queue[1].priority ~= ns.Battle.SELF_FIRST then
				fail(scenario, "your own missing buff stands at " .. tostring(queue[1].priority))
			end
			if not (queue[2] and queue[2].name == BERT and queue[2].sweep == "revived") then
				fail(scenario, "the team-mate raised beside you does not come straight after you: " .. names(ns))
			end
			-- Your target is still the one you picked on purpose.
			if ns.Battle.SELF_FIRST <= 0 then fail(scenario, "your own buff would come ahead of your target") end
			-- Wearing it, with a top-up due, you are back with the group.
			go(place, nil)
		end)
end

-- ------------------------------------------------------------ battleground 4
-- The order of your own: the mock's verdicts stand in for three families of a
-- mage -- food from the bags and two he fights with -- so the order is the
-- only thing read. Out in the world it is the table's; in a battleground what
-- you fight with comes before food, and what is missing before what runs low.
do
	local scenario = "battleground: of your own, what you fight with before the long extras, the missing before the low"
	with(scenario, { held = { [INTELLECT] = true } }, function(ns, place)
		local food, first, second
		for _, family in ipairs(ns.GetOwnFamilies("MAGE") or {}) do
			if family.food then
				food = food or family
			elseif not ns.Battle.Extra(family) and not family.tracking then
				if not first then first = family elseif not second then second = family end
			end
		end
		if not (food and first and second) then
			fail(scenario, "SKIPPED -- a mage has no food family and two families he fights with")
			return
		end
		if not ns.Battle.Extra(food) then fail(scenario, "food is not one of the long extras") end
		local answers = {}
		ns.KnownOwnFamilies = function() return { food, first, second } end
		ns.OwnVerdict = function(family)
			local a = answers[family]
			if not a then return nil, true, nil, "up" end
			return family.spells[1], a.has, a.remaining, nil, nil, nil, 1800, 180, 1
		end
		local MISSING, LOW = { has = false }, { has = true, remaining = 30 }

		-- Everything missing.
		answers[food], answers[first], answers[second] = MISSING, MISSING, MISSING
		Mock.advance(1)
		local me = mine(ns)
		if not (me and me.buff == food.spells[1]) then
			fail(scenario, "SKIPPED -- out in the world the order is not the table's: " .. key(me))
			return
		end
		go(place, "pvp")
		me = mine(ns)
		if not (me and me.buff == first.spells[1]) then
			fail(scenario, "in a battleground food came ahead of what you fight with: " .. key(me))
		elseif me.priority ~= ns.Battle.SELF_FIRST then
			fail(scenario, "what you fight with and are missing stands at " .. tostring(me.priority))
		end

		-- The first of them only running low, the second gone altogether.
		answers[first] = LOW
		Mock.advance(1)
		me = mine(ns)
		if not (me and me.buff == second.spells[1]) then
			fail(scenario, "one running low came ahead of one missing altogether: " .. key(me))
		end
		-- Nothing missing: the one running low, still ahead of food.
		answers[second] = nil
		Mock.advance(1)
		me = mine(ns)
		if not (me and me.buff == first.spells[1]) then
			fail(scenario, "food came ahead of a top-up of what you fight with: " .. key(me))
		end
		-- And only then food, behind the team.
		answers[first] = nil
		Mock.advance(1)
		me = mine(ns)
		if not (me and me.buff == food.spells[1]) then
			fail(scenario, "food is not offered in a battleground once the rest is up: " .. key(me))
		elseif me.priority ~= ns.Battle.EXTRAS then
			fail(scenario, "food stands at " .. tostring(me.priority) .. ", not behind the team")
		end
		local anna = entryFor(ns, ANNA)
		if not (anna and anna.priority < ns.Battle.EXTRAS) then
			fail(scenario, "SKIPPED -- no team-mate is offered ahead of your food")
		end
	end)
end

-- ------------------------------------------------------------ battleground 5
-- Your group buff only running low steps behind something you fight with and
-- are missing altogether, in a battleground; out in the world it leads, as it
-- always did, and one of your own only running low does not pass it.
do
	local scenario = "battleground: your group buff running low waits behind an armor that is gone"
	with(scenario, { held = { [INTELLECT] = true } }, function(ns, place)
		local first
		for _, family in ipairs(ns.GetOwnFamilies("MAGE") or {}) do
			if not ns.Battle.Extra(family) and not family.tracking then first = first or family end
		end
		if not first then
			fail(scenario, "SKIPPED -- a mage has no family he fights with")
			return
		end
		local answer = { has = false }
		ns.KnownOwnFamilies = function() return { first } end
		ns.OwnVerdict = function()
			if not answer then return nil, true, nil, "up" end
			return first.spells[1], answer.has, answer.remaining, nil, nil, nil, 1800, 180, 1
		end
		-- Your Intellect with twenty seconds left.
		Mock.playerHeldFor = 20
		Mock.advance(1)
		local me = mine(ns)
		if not (me and me.buff ~= first.spells[1] and me.known == true and me.remaining) then
			fail(scenario, "SKIPPED -- out in the world your group buff running low does not lead: " .. key(me))
			return
		end
		local group = me.buff
		go(place, "pvp")
		me = mine(ns)
		if not (me and me.buff == first.spells[1]) then
			fail(scenario, "in a battleground the top-up of your group buff came ahead of an armor that is gone: " .. key(me))
		end
		answer = { has = true, remaining = 30 }
		Mock.advance(1)
		me = mine(ns)
		if not (me and me.buff == group) then
			fail(scenario, "one of your own only running low passed your group buff: " .. key(me))
		end
		Mock.playerHeldFor = nil
	end)
end

-- ------------------------------------------------------------ battleground 6
-- Before the gates open a cast costs nothing: the mana floor holds nobody
-- back. Once they are open it holds, as it does anywhere.
do
	local scenario = "battleground: before the gates open the mana floor holds nobody back"
	with(scenario, {}, function(ns, place)
		-- The mock's mana stands at half.
		ns.db.profile.filters.manaFloor = 60
		Mock.advance(1)
		if entryFor(ns, ANNA) then
			fail(scenario, "SKIPPED -- under the mana floor a party member is offered out in the world")
			return
		end
		go(place, "pvp")
		if entryFor(ns, ANNA) then fail(scenario, "with the gates open, the mana floor let a team-mate through") end
		wear({ [PREPARATION] = true })
		if not entryFor(ns, ANNA) then
			fail(scenario, "under Preparation the mana floor still held the team back: " .. names(ns))
		end
		if ns.SavingMana() ~= nil then fail(scenario, "saving mana is still said under Preparation") end
		go(place, nil)
		if entryFor(ns, ANNA) then fail(scenario, "out in the world the aura alone lifted the mana floor") end
	end)
end

-- ------------------------------------------------------------ battleground 7
-- Before the gates open the whole team is offered, the raid groups switched
-- off for a raid night included; once they are open those groups wait again.
do
	local scenario = "battleground: before the gates open every raid group is offered"
	local people = {}
	for i = 1, 10 do people["raid" .. i] = { "Raider" .. i, "Stone" } end
	with(scenario, { raid = { size = 10, player = 1 }, people = people }, function(ns, place)
		ns.db.profile.filters.skipRaidGroups[2] = true
		Mock.advance(1)
		if entryFor(ns, "Raider7 Stone") or not entryFor(ns, "Raider3 Stone") then
			fail(scenario, "SKIPPED -- out in the world the raid group switched off is not held back: " .. names(ns))
			return
		end
		go(place, "pvp")
		if entryFor(ns, "Raider7 Stone") then
			fail(scenario, "with the gates open, a raid group switched off was offered")
		end
		wear({ [PREPARATION] = true })
		if not entryFor(ns, "Raider7 Stone") then
			fail(scenario, "under Preparation a raid group switched off was still left out: " .. names(ns))
		end
	end)
end

-- ------------------------------------------------------------ battleground 8
-- And the group casts first: one press for the party ahead of every single
-- one, and of your own, while it costs nothing. The fold is the mock's here:
-- one group cast put in the queue as GroupBuffs.lua would.
do
	local scenario = "battleground: before the gates open the group casts come first"
	with(scenario, {}, function(ns, place)
		local fold = ns.GroupCasts
		ns.GroupCasts = function(queue, ...)
			queue = fold(queue, ...)
			local anchor
			for _, entry in ipairs(queue) do
				if entry.name == DORA then anchor = entry end
			end
			if not anchor then return queue end
			anchor.groupCast = { missing = 3, low = 0, members = {}, spellName = "Arcane Brilliance", where = "party" }
			return queue
		end
		go(place, "pvp")
		local queue = ns.BuildQueue()
		local dora = entryFor(ns, DORA)
		if not (dora and dora.groupCast) then
			fail(scenario, "SKIPPED -- the group cast is not in the queue: " .. names(ns))
			return
		end
		if queue[1] == nil or queue[1].name == DORA then
			fail(scenario, "SKIPPED -- with the gates open the group cast already leads: " .. names(ns))
			return
		end
		if dora.priority ~= 2 then fail(scenario, "with the gates open the group cast stands at " .. tostring(dora.priority)) end
		wear({ [PREPARATION] = true })
		queue = ns.BuildQueue()
		if not (queue[1] and queue[1].name == DORA and queue[1].groupCast) then
			fail(scenario, "under Preparation the group cast does not come first: " .. names(ns))
		elseif queue[1].priority ~= ns.Battle.GROUP_FIRST then
			fail(scenario, "under Preparation the group cast stands at " .. tostring(queue[1].priority))
		end
		ns.GroupCasts = fold
	end)
end

-- ------------------------------------------------------------ battleground 9
-- Once the gates are open nobody else is offered while you fight: the pull's
-- own repaint finds nobody, so no press of the fight targets a team-mate. Out
-- in the world a fight keeps whoever the prompt was on, as it always did.
do
	local scenario = "battleground: once the gates are open nobody else is offered in a fight"
	with(scenario, { held = { [INTELLECT] = true } }, function(ns, place)
		Mock.inCombat = true
		Mock.advance(1)
		if not entryFor(ns, ANNA) then
			fail(scenario, "SKIPPED -- out in the world a fight leaves no party member in the queue")
			Mock.inCombat = false
			return
		end
		Mock.inCombat = false
		go(place, "pvp")
		if not entryFor(ns, ANNA) then
			fail(scenario, "out of combat in a battleground the team is not offered: " .. names(ns))
		end
		Mock.inCombat = true
		Mock.advance(1)
		local queue, verdict = ns.BuildQueue()
		if #queue > 0 then
			fail(scenario, "in a fight in a battleground somebody is still offered: " .. names(ns))
		elseif verdict ~= true then
			fail(scenario, "the empty queue of a fight is not a verdict on the whole of it")
		end
		Mock.inCombat = false
		Mock.advance(1)
		if not entryFor(ns, ANNA) then fail(scenario, "the team did not come back once the fight was over") end

		-- The pull itself: the flag is up, the lockdown is not, and the repaint
		-- it makes leaves the button aimed at nobody.
		ns.Prompt:Refresh()
		local button = ns.Prompt:GetButton()
		local armed = button:GetAttribute("macrotext1")
		if type(armed) ~= "string" or not armed:find("/target", 1, true) then
			fail(scenario, "SKIPPED -- the prompt is not armed for a team-mate before the pull: " .. tostring(armed))
			return
		end
		rawset(_G, "UnitAffectingCombat", function(unit) return unit == "player" end)
		ns.addon:PLAYER_REGEN_DISABLED()
		armed = button:GetAttribute("macrotext1")
		if type(armed) == "string" and armed:find("/target", 1, true) then
			fail(scenario, "the pull left the button aimed at a team-mate: " .. armed:gsub("\n", " / "))
		end
		rawset(_G, "UnitAffectingCombat", original.UnitAffectingCombat)
		ns.addon:PLAYER_REGEN_ENABLED()
	end)
end

-- Before the gates open nobody fights, and a flag left up by a duel at the
-- gate holds nobody back there.
do
	local scenario = "battleground: before the gates open a fight holds nobody back"
	with(scenario, { held = { [INTELLECT] = true, [PREPARATION] = true } }, function(ns, place)
		go(place, "pvp")
		rawset(_G, "UnitAffectingCombat", function(unit) return unit == "player" end)
		Mock.advance(1)
		if ns.Battle.State() ~= "prep" then
			fail(scenario, "under Preparation with the combat flag up the state is " .. tostring(ns.Battle.State()))
		end
		rawset(_G, "UnitAffectingCombat", original.UnitAffectingCombat)
	end)
end

-- ----------------------------------------------------------- battleground 10
-- Only somebody within reach: nobody measured out of range, whatever Only in
-- range says, and nobody no token names. Out in the world both are offered
-- with that switch off, as ever.
do
	local scenario = "battleground: only somebody within reach is offered"
	with(scenario, { held = { [INTELLECT] = true } }, function(ns, place)
		ns.db.profile.filters.requireInRange = false
		ns.db.profile.filters.reachableOnly = false
		Mock.rangeByUnit = { party3 = false }
		owe(ns, ZED)
		Mock.advance(1)
		if not (entryFor(ns, CARA) and entryFor(ns, ZED)) then
			fail(scenario, "SKIPPED -- out in the world, with Only in range off, somebody out of range or with no token is not offered: "
				.. names(ns))
			return
		end
		go(place, "pvp")
		owe(ns, ZED)
		local queue, verdicts = ns.BuildQueue()
		local offered = {}
		for _, entry in ipairs(queue) do offered[entry.name] = true end
		if offered[CARA] then fail(scenario, "a team-mate measured out of range was offered in a battleground") end
		if offered[ZED] then fail(scenario, "somebody no token names was offered in a battleground") end
		if not offered[ANNA] then fail(scenario, "a team-mate in reach was dropped with them: " .. names(ns)) end
		if type(verdicts) ~= "table" or verdicts[CARA] ~= true then
			fail(scenario, "the one out of range is not turned down as a verdict")
		end
		if not ns.owed[ZED] then fail(scenario, "the favour was dropped with the offer") end
		Mock.rangeByUnit = nil
	end)
end

-- ----------------------------------------------------------- battleground 11
-- Buff my team there decides inside a battleground or an arena, whatever
-- Offer nothing in dungeons, raids and battlegrounds says: on, the team is
-- offered with that switch ticked; off, nobody but your target with it clear.
-- A dungeon goes by that switch alone.
do
	local scenario = "battleground: Buff my team there decides in a battleground, the instance switch in a dungeon"
	local people = partyNames()
	people.target = { "Tess", "Target" }
	with(scenario, { held = { [INTELLECT] = true }, people = people }, function(ns, place)
		local TESS = "Tess Target"
		local db = ns.db.profile
		if db.battle.team ~= true then fail(scenario, "Buff my team there is not on in a new profile") end
		for _, kind in ipairs({ "pvp", "arena" }) do
			-- The instance switch ticked (in the file, as a profile shared from
			-- another character could have it), the team's still on.
			db.filters.quietInInstances, db.battle.team = true, true
			go(place, kind)
			if not entryFor(ns, ANNA) then
				fail(scenario, ("in a %s instance the instance switch held the team back with Buff my team there on"):format(kind))
			end
			db.filters.quietInInstances, db.battle.team = false, false
			Mock.advance(1)
			if entryFor(ns, ANNA) then
				fail(scenario, ("in a %s instance the team was offered with Buff my team there off"):format(kind))
			end
			if not entryFor(ns, TESS) then
				fail(scenario, ("in a %s instance your target was dropped with Buff my team there off"):format(kind))
			end
			db.filters.quietTargets = true
			Mock.advance(1)
			if entryFor(ns, TESS) then
				fail(scenario, ("in a %s instance Hold back my target and focus too left your target offered"):format(kind))
			end
			db.filters.quietTargets = false
		end
		-- A dungeon: the team's switch says nothing there.
		go(place, "party")
		db.filters.quietInInstances, db.battle.team = false, false
		if not entryFor(ns, ANNA) then fail(scenario, "Buff my team there, off, held a dungeon's party back") end
		db.filters.quietInInstances, db.battle.team = true, true
		Mock.advance(1)
		if entryFor(ns, ANNA) then fail(scenario, "SKIPPED -- the instance switch does not hold a dungeon's party back") end
		-- And out in the world neither does.
		go(place, nil)
		db.filters.quietInInstances, db.battle.team = false, false
		if not entryFor(ns, ANNA) then fail(scenario, "Buff my team there, off, held a party back out in the world") end
	end)
end

-- ----------------------------------------------------------- battleground 12
-- So that the instance switch's name still holds, ticking it unticks Buff my
-- team there; and a profile that had it ticked before the section existed is
-- carried over, once.
do
	local scenario = "battleground: ticking the instance switch unticks Buff my team there, and an old profile is carried over once"
	with(scenario, {}, function(ns)
		local db = ns.db.profile
		local control = findOption(ns.optionsTable, "quietInInstances")
		if not control then
			fail(scenario, "SKIPPED -- no switch for nothing inside an instance")
			return
		end
		local info = { "who", "quietInInstances" }
		control.set(info, true)
		if db.filters.quietInInstances ~= true then fail(scenario, "the instance switch was not kept") end
		if db.battle.team ~= false then fail(scenario, "ticking the instance switch left Buff my team there on") end
		-- Unticking it says nothing about a battleground.
		control.set(info, false)
		if db.battle.team ~= false then fail(scenario, "unticking the instance switch ticked Buff my team there") end
		local desc = type(control.desc) == "function" and control.desc() or tostring(control.desc)
		if not desc:find(ns.L["Buff my team there"], 1, true) then
			fail(scenario, "the instance switch's description does not name the battleground's own switch: " .. desc)
		end

		-- A profile from before the section: the switch ticked, nothing carried.
		db.battle.team, db.battle.carried, db.filters.quietInInstances = true, nil, true
		ns.ClampSettings()
		if db.battle.team ~= false then
			fail(scenario, "a profile with the instance switch ticked was not carried over: the team is offered in a battleground")
		end
		if db.battle.carried ~= true then fail(scenario, "the carrying over was not written down") end
		-- Once: the player ticks the team back on, and it stays.
		db.battle.team = true
		ns.ClampSettings()
		if db.battle.team ~= true then fail(scenario, "the carrying over was made twice, over the player's own tick") end
		-- A profile without the switch keeps the team on.
		db.battle.team, db.battle.carried, db.filters.quietInInstances = true, nil, false
		ns.ClampSettings()
		if db.battle.team ~= true then fail(scenario, "a profile without the instance switch lost Buff my team there") end
	end)
end

-- ----------------------------------------------------------- battleground 13
-- Nothing is said in a battleground or an arena until Say my line there is
-- ticked: the channel is closed there, so no line is armed, in any channel.
do
	local scenario = "battleground: nothing is said there until Say my line there is ticked"
	with(scenario, { held = { [INTELLECT] = true } }, function(ns, place)
		local db = ns.db.profile
		db.speech.enabled = true
		db.speech.channel = "SAY"
		local anna = { name = ANNA, inGroup = true, unit = "party1", reason = "group" }
		if db.battle.speak ~= false then fail(scenario, "Say my line there is not off in a new profile") end
		if not ns.ChannelOpen(anna) then
			fail(scenario, "SKIPPED -- out in the world /say is not open")
			return
		end
		for _, kind in ipairs({ "pvp", "arena" }) do
			go(place, kind)
			if ns.ChannelOpen(anna) then fail(scenario, "a line would be said in a " .. kind .. " instance") end
			for _, channel in ipairs({ "WHISPER", "EMOTE", "YELL" }) do
				db.speech.channel = channel
				if ns.ChannelOpen(anna) then
					fail(scenario, ("a line would go out by %s in a %s instance"):format(channel, kind))
				end
			end
			db.speech.channel = "SAY"
			db.battle.speak = true
			if not ns.ChannelOpen(anna) then
				fail(scenario, "with Say my line there ticked, no line is said in a " .. kind .. " instance")
			end
			db.battle.speak = false
		end
		-- The macro the prompt arms there carries the cast and no line.
		ns.Prompt:InvalidateMacro()
		ns.Prompt:Refresh()
		local armed = ns.Prompt:GetButton():GetAttribute("macrotext1")
		if type(armed) ~= "string" or not armed:find("/cast", 1, true) then
			fail(scenario, "SKIPPED -- the prompt is not armed for a team-mate in the arena: " .. tostring(armed))
		elseif armed:find("/s ", 1, true) or armed:find("/say", 1, true) then
			fail(scenario, "the macro armed in a battleground carries a line: " .. armed:gsub("\n", " / "))
		end
		go(place, "party")
		if not ns.ChannelOpen(anna) then fail(scenario, "a dungeon was silenced with the battleground") end
		go(place, nil)
		if not ns.ChannelOpen(anna) then fail(scenario, "the world was silenced with the battleground") end
	end)
end

-- ----------------------------------------------------------- battleground 14
-- Thanks go to your own team and nobody else: the /thank that every instance
-- holds back is made in a battleground for a team-mate, never for anybody
-- outside your group, and not at all with Thank people there off.
local emotes = {}
local function record(emote, target) emotes[#emotes + 1] = { emote, target } end
local nextId = 8100
for _, case in ipairs({
	{ label = "a team-mate is thanked", kind = "pvp", unit = "party1", thanks = true },
	{ label = "a team-mate is thanked in an arena", kind = "arena", unit = "party1", thanks = true },
	{ label = "nobody outside your team", kind = "pvp", unit = "nameplate1", why = "not on your team, in a battleground" },
	{ label = "nobody with Thank people there off", kind = "pvp", unit = "party1", off = true,
		why = "thanks are off in battlegrounds" },
	{ label = "a dungeon holds a party member's back as ever", kind = "party", unit = "party1", why = "in an instance" },
}) do
	local scenario = "battleground: thanks go to your own team (" .. case.label .. ")"
	local people = partyNames()
	people.nameplate1 = { "Nell", "Near" }
	-- The mock calls everybody a party member in a party: only the party's own
	-- tokens are, here.
	local function inParty(unit) return type(unit) == "string" and unit:find("^party%d") ~= nil end
	with(scenario, { people = people, globals = { DoEmote = record, UnitInParty = inParty } }, function(ns, place)
		emotes = {}
		Mock.nameplates = { "nameplate1" }
		ns.nameplateUnits.nameplate1 = true
		ns.db.profile.prompt.thankEmote = true
		if ns.db.profile.battle.thank ~= true then fail(scenario, "Thank people there is not on in a new profile") end
		if case.off then ns.db.profile.battle.thank = false end
		primeAuras(ns)
		if not ns.auraScan.primed then
			fail(scenario, "SKIPPED -- the baseline never settled")
			return
		end
		go(place, case.kind)
		nextId = nextId + 1
		favourFrom(ns, case.unit, 10938, nextId)
		local name = ns.UnitFullName(case.unit)
		if not (name and ns.owed[name]) then
			fail(scenario, "SKIPPED -- the favour from " .. case.unit .. " was not noticed")
			return
		end
		if case.thanks and #emotes ~= 1 then
			fail(scenario, "a team-mate who buffed you in a battleground was not thanked ("
				.. tostring(ns.thankLog.skipped and ns.thankLog.skipped.why) .. ")")
		elseif not case.thanks and #emotes > 0 then
			fail(scenario, "an emote was made: " .. case.label)
		elseif not case.thanks then
			local why = ns.thankLog.skipped and ns.thankLog.skipped.why
			if why ~= case.why then
				fail(scenario, ("the skip is written down as %q, not %q"):format(tostring(why), case.why))
			end
		end
	end)
end

-- ----------------------------------------------------------- battleground 15
-- Consumables held to dungeons and raids stay held in a battleground until
-- Consumables there too is ticked, which makes it count as a dungeon; out in
-- the world that tick changes nothing.
do
	local scenario = "battleground: consumables held to dungeons wait there until Consumables there too is ticked"
	with(scenario, {}, function(ns, place)
		local food
		for _, family in ipairs(ns.GetOwnFamilies("MAGE") or {}) do
			if family.food then food = food or family end
		end
		if not food then
			fail(scenario, "SKIPPED -- a mage has no food family")
			return
		end
		local db = ns.db.profile
		db.ownBuffs.pick.food = "auto"
		db.ownBuffs.itemsInDungeons = true
		if db.battle.items ~= false then fail(scenario, "Consumables there too is not off in a new profile") end
		local function why()
			Mock.advance(3)
			local ctx = { name = ns.UnitFullName("player"), now = GetTime(), whenBuffed = "skip" }
			return (select(4, ns.OwnVerdict(food, ctx)))
		end
		if why() ~= "dungeon" then
			fail(scenario, "SKIPPED -- out in the world food is not held to dungeons: " .. tostring(why()))
			return
		end
		go(place, "pvp")
		if why() ~= "dungeon" then fail(scenario, "food is no longer held in a battleground: " .. tostring(why())) end
		db.battle.items = true
		if why() == "dungeon" then fail(scenario, "with Consumables there too ticked, food still waits for a dungeon") end
		go(place, "arena")
		if why() == "dungeon" then fail(scenario, "with Consumables there too ticked, food still waits in an arena") end
		go(place, nil)
		if why() ~= "dungeon" then fail(scenario, "the tick let food through out in the world") end
		go(place, "party")
		db.battle.items = false
		if why() == "dungeon" then fail(scenario, "SKIPPED -- food is held in a dungeon") end
	end)
end

-- ----------------------------------------------------------- battleground 16
-- The section: four switches on Quiet times, with their defaults, each kept,
-- placed on the page and put back by its reset.
do
	local scenario = "battleground: Quiet times has the section, its switches are kept and its reset puts them back"
	with(scenario, {}, function(ns)
		local db = ns.db.profile
		local defaults = ns.defaults.profile.battle
		for field, want in pairs({ team = true, speak = false, thank = true, items = false }) do
			if defaults[field] ~= want then
				fail(scenario, ("the default of battle.%s is %s"):format(field, tostring(defaults[field])))
			end
		end
		db.ownBuffs.itemsInDungeons = true
		for control, field in pairs({ battleTeam = "team", battleSpeak = "speak", battleThank = "thank", battleItems = "items" }) do
			local option = findOption(ns.optionsTable, control)
			if not option then
				fail(scenario, "Quiet times has no " .. control)
			else
				local info = { "when", control }
				if option.type ~= "toggle" then fail(scenario, control .. " is a " .. tostring(option.type)) end
				if option.get(info) ~= defaults[field] then fail(scenario, control .. " does not show its default") end
				option.set(info, not defaults[field])
				if db.battle[field] ~= (not defaults[field]) or option.get(info) ~= (not defaults[field]) then
					fail(scenario, control .. " was not kept")
				end
				if H.layoutInToc() then
					local page, section = H.placedOn(ns, "when." .. control)
					if page ~= "quiet" then
						fail(scenario, ("%s is drawn on %s, not on Quiet times"):format(control, tostring(page)))
					elseif type(section) ~= "table" or section.key ~= "quiet.battle" then
						fail(scenario, control .. " is not in the section In battlegrounds and arenas")
					end
				end
			end
		end
		if not findOption(ns.optionsTable, "battleHeader") then fail(scenario, "the section has no heading") end
		-- Consumables there too widens a switch that is off: greyed until it is on.
		local items = findOption(ns.optionsTable, "battleItems")
		if items then
			db.ownBuffs.itemsInDungeons = false
			if not (type(items.disabled) == "function" and items.disabled()) then
				fail(scenario, "Consumables there too is not greyed while consumables are held nowhere")
			end
		end
		-- The page's reset.
		local list = ns.OptionsPage.RESET.quiet or {}
		local listed = {}
		for _, path in ipairs(list) do listed[path] = true end
		for field in pairs(defaults) do
			if not listed["battle." .. field] then
				fail(scenario, "Quiet times' reset leaves battle." .. field .. " as it is")
			end
		end
	end)
end

-- ----------------------------------------------------------- battleground 17
-- /manners debug says which of the rules stands, and each switch that holds
-- something back; nothing about a battleground anywhere else.
do
	local scenario = "battleground: /manners debug says what a battleground is holding back"
	with(scenario, { held = { [INTELLECT] = true } }, function(ns, place)
		local db = ns.db.profile
		local function debug()
			Mock.printed = {}
			ns.addon:HandleSlash("debug")
			return table.concat(Mock.printed, "\n")
		end
		if debug():find("battleground|r --", 1, true) then
			fail(scenario, "/manners debug speaks of a battleground out in the world")
		end
		go(place, "pvp")
		local text = debug()
		if not text:find("out of combat, and only within reach", 1, true) then
			fail(scenario, "/manners debug does not say the gates are open: " .. text)
		end
		wear({ [INTELLECT] = true, [PREPARATION] = true })
		if not debug():find("the gates are shut", 1, true) then
			fail(scenario, "/manners debug does not say the gates are shut")
		end
		wear({ [INTELLECT] = true })
		Mock.inCombat = true
		Mock.advance(1)
		if not debug():find("nobody else is offered until it ends", 1, true) then
			fail(scenario, "/manners debug does not say a fight holds the team back")
		end
		Mock.inCombat = false
		Mock.advance(1)
		db.battle.team = false
		if not debug():find("nobody but your target or focus is offered here", 1, true) then
			fail(scenario, "/manners debug does not say Buff my team there is off")
		end
		db.battle.team = true
		-- Each switch only while it is holding something back.
		text = debug()
		for _, held in ipairs({ "nothing is said here", "nobody is thanked here", "consumables wait here" }) do
			if text:find(held, 1, true) then fail(scenario, "/manners debug says \"" .. held .. "\" with nothing to hold back") end
		end
		db.speech.enabled, db.prompt.thankEmote, db.battle.thank, db.ownBuffs.itemsInDungeons = true, true, false, true
		text = debug()
		for _, held in ipairs({ "nothing is said here", "nobody is thanked here", "consumables wait here" }) do
			if not text:find(held, 1, true) then fail(scenario, "/manners debug does not say \"" .. held .. "\"") end
		end
		-- And the check-up's line of settings.
		local lines = ns.FullReport and ns.FullReport() or ""
		if not lines:find("battle: team=true speak=false thank=false items=false state=open", 1, true) then
			fail(scenario, "the check-up does not hold the section's switches and its state")
		end
	end)
end

-- ----------------------------------------------------------- battleground 18
-- A string pasted from somebody else must not start a line in a battleground
-- for a player who speaks: Say my line there is kept as the player has it,
-- with the rest of what is said and where.
do
	local scenario = "battleground: a pasted string does not switch on speaking in a battleground"
	with(scenario, {}, function(ns)
		local db = ns.db.profile
		db.speech.enabled = true
		db.battle.speak, db.battle.thank = true, false
		local text = ns.ExportSettings()
		db.battle.speak, db.battle.thank = false, true
		local ok, said = ns.ImportSettings(text)
		if not ok then
			fail(scenario, "SKIPPED -- the string did not import: " .. tostring(said))
			return
		end
		if db.battle.thank ~= false then fail(scenario, "SKIPPED -- the section's switches do not travel in a string") end
		if db.battle.speak ~= false then
			fail(scenario, "a pasted string switched on Say my line there for a player who speaks")
		end
	end)
end
