-- Water and food for your target (Courtesy.lua, Aimed) and the filled trade
-- window (Fill). A friendly player you target out of a fight is offered what
-- suits their level, a class without mana gets food alone, the trade window
-- takes as many stacks as it has free slots, and somebody who asked is filled
-- for the same way.
--
-- Called by scenarios.lua with the addon directory and its helpers. The bags
-- (a list of stacks, one slot each), the spell book, the cursor and the trade
-- window are stood in here (`world`), as tests/scenarios/courtesy.lua does.
-- Every global a scenario replaces is put back after it. Every name starts
-- "water-target:", so the mutations in tests/mutations/water-target.py can
-- name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, pressButton = H.strangers, H.freshPrompt, H.pressButton

local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "C_Spell", "GetItemCount", "C_Container",
	"ClickTradeButton", "GetTradePlayerItemLink", "GetCursorInfo", "CursorHasItem", "ClearCursor",
	"AcceptTrade", "UnitGUID", "UnitLevel", "UnitClass", "UnitPowerMax", "UnitCanAssist", "UnitIsPlayer",
	"UnitInParty", "IsUsableSpell", "MAX_TRADABLE_ITEMS", "IsResting", "TradeFrame" }
local original = {}
for _, name in ipairs(TOUCHED) do original[name] = rawget(_G, name) end

local function with(scenario, globals, body)
	for name, value in pairs(globals or {}) do rawset(_G, name, value) end
	local ok, err = pcall(body)
	for _, name in ipairs(TOUCHED) do rawset(_G, name, original[name]) end
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

local function entryFor(ns, name)
	local short = type(name) == "string" and name:match("^(%S+)") or name
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.name == name or entry.name == short then return entry end
	end
	return nil
end

local function hear(ns, event, text, sender, guid)
	ns.addon[event](ns.addon, event, text, sender, "Common", "", "", "", 0, 0, "", 0, 1, guid)
end

local function flat(text)
	return (tostring(text):gsub("\n", " / "))
end

-- The names the client gives the spells these scenarios use.
local SPELLS = {
	[1459] = "Arcane Intellect",
	[5504] = "Conjure Water", [5505] = "Conjure Water", [5506] = "Conjure Water", [6127] = "Conjure Water",
	[10138] = "Conjure Water", [10139] = "Conjure Water", [10140] = "Conjure Water",
	[587] = "Conjure Food", [597] = "Conjure Food", [990] = "Conjure Food", [6129] = "Conjure Food",
	[10144] = "Conjure Food", [10145] = "Conjure Food", [28612] = "Conjure Food",
	[42955] = "Conjure Refreshment", [190336] = "Conjure Refreshment",
}
local RANKS = { [5504] = "Rank 1", [5505] = "Rank 2", [5506] = "Rank 3", [6127] = "Rank 4",
	[10138] = "Rank 5", [10139] = "Rank 6", [10140] = "Rank 7",
	[587] = "Rank 1", [597] = "Rank 2", [990] = "Rank 3", [6129] = "Rank 4", [10144] = "Rank 5",
	[10145] = "Rank 6", [28612] = "Rank 7" }
local MAGE = { 1459, 5504, 5505, 5506, 6127, 10138, 10139, 10140, 587, 597, 990, 6129, 10144, 10145, 28612 }

-- Era water and food, best of each (Courtesy.lua).
local WATER_TOP, WATER_25, WATER_5 = 8079, 3772, 2288
local FOOD_TOP, FOOD_5 = 22895, 1113

-- A spell book, bags of stacks (`bags`: a list of { item, count }, one slot
-- each, in bag 0), a cursor and a trade window. `levels` token -> level,
-- `classes` token -> class, `power` token -> its mana. `targetId` names who
-- the target and the trade's other side are (the GUID is "Player-1-" and it).
local function world(opts)
	local w = { bags = opts.bags or {}, trade = {}, picked = {}, levels = opts.levels or {},
		classes = opts.classes or {}, power = opts.power or {}, targetId = "target", cleared = false, clicks = 0 }
	local known = {}
	for _, id in ipairs(opts.known or MAGE) do known[id] = true end
	local knows = function(id) return known[id] == true end
	local base = _G.C_Spell
	local spell = setmetatable({
		GetSpellName = function(id) return SPELLS[id] end,
		GetSpellSubtext = function(id) return RANKS[id] end,
		IsSpellUsable = function() return true end,
	}, { __index = base })
	w.globals = {
		IsSpellKnown = knows, IsPlayerSpell = knows, C_Spell = spell,
		GetItemCount = function(item)
			local total = 0
			for _, stack in ipairs(w.bags) do
				if stack[1] == item then total = total + stack[2] end
			end
			return total
		end,
		C_Container = {
			GetContainerNumSlots = function(bag) return bag == 0 and 16 or 0 end,
			GetContainerItemID = function(bag, slot) return bag == 0 and w.bags[slot] and w.bags[slot][1] or nil end,
			GetContainerItemInfo = function() return { isLocked = false } end,
			PickupContainerItem = function(bag, slot)
				if bag == 0 and w.bags[slot] then
					w.cursor = w.bags[slot][1]
					w.picked[#w.picked + 1] = w.cursor
				end
			end,
		},
		GetCursorInfo = function() if w.cursor then return "item", w.cursor end end,
		CursorHasItem = function() return w.cursor ~= nil end,
		ClearCursor = function() w.cleared = true; w.cursor = nil end,
		ClickTradeButton = function(index)
			w.clicks = w.clicks + 1
			w.trade[index] = w.cursor
			w.cursor = nil
		end,
		GetTradePlayerItemLink = function(index) return w.trade[index] and "link" or nil end,
		AcceptTrade = function() w.accepted = true end,
		UnitGUID = function(unit)
			if unit == "NPC" then return "Player-1-" .. (w.partner or w.targetId) end
			if unit == "target" then return "Player-1-" .. w.targetId end
			return "Player-1-" .. tostring(unit)
		end,
		UnitLevel = function(unit)
			if unit == "player" then return 60 end
			if w.secretLevel then return Mock.SECRET end
			if unit == "NPC" then unit = "target" end
			return w.levels[unit] or 60
		end,
		UnitClass = function(unit)
			if unit == "player" then return "Mage", Mock.class end
			if w.secretClass then return "Priest", Mock.SECRET end
			local class = w.classes[unit] or "PRIEST"
			return class:sub(1, 1) .. class:sub(2):lower(), class
		end,
		UnitPowerMax = function(unit)
			if w.secretPower then return Mock.SECRET end
			local power = w.power[unit]
			if power ~= nil then return power end
			return 1000
		end,
		UnitCanAssist = function() return w.assist ~= false end,
		UnitIsPlayer = function() return w.npc ~= true end,
		MAX_TRADABLE_ITEMS = 6,
	}
	return w
end

-- A loaded addon with the prompt settled, the target switch on and nobody
-- offered anything unasked.
local function ready(ns, scenario, switches)
	freshPrompt(ns, scenario)
	local db = ns.db.profile
	db.sources.strangers = false
	db.sources.group = false
	db.sources.self = false
	db.sources.asked = false
	for _, key in ipairs(switches or { "courtesyTarget" }) do
		db.sources[key] = true
		if key == "courtesyRefresh" then db.sources.asked = true end
	end
end

-- One scenario: the world, the target Tess Target on its token, the body.
local function scene(scenario, opts, body)
	Mock.reset()
	if opts.flavour then Mock.setFlavour(opts.flavour) end
	if opts.class then Mock.class = opts.class end
	local names = { target = opts.target or { "Tess", "Target" } }
	for token, name in pairs(opts.names or {}) do names[token] = name end
	local restoreUnits = strangers(names)
	local w = world(opts)
	with(scenario, w.globals, function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario, opts.switches)
		body(ns, w, names)
		noErrors(scenario, ns)
	end)
	restoreUnits()
	Mock.reset()
end

-- The trade window opens with the target on the other side.
local function openTrade(ns, w, names, name)
	names.NPC = name or names.target
	w.open = true
	ns.Courtesy.OnEvent(nil, "TRADE_SHOW")
end

local function tradeText(w)
	local out = {}
	for i = 1, 7 do out[#out + 1] = tostring(w.trade[i]) end
	return table.concat(out, ",")
end

local TESS = "Tess Target"

-- ---------------------------------------------------------- water-target 1
scene("water-target: a mana user you target is offered water then food at their level, conjured, then traded together",
	{ levels = { target = 30 } }, function(ns, w, names)
	local scenario = "water-target: a mana user you target is offered water then food at their level, conjured, then traded together"
	local tess = entryFor(ns, TESS)
	if not (tess and tess.courtesy) then
		fail(scenario, "SKIPPED -- the target is not offered water")
		return
	end
	if tess.reason ~= "target" or tess.priority ~= 1.5 then
		fail(scenario, ("filed as %s (%s), not as the target at the tier of a request"):format(tostring(tess.reason), tostring(tess.priority)))
	end
	if tess.courtesy.stage ~= "conjure" or ns.EntrySpellName(tess) ~= "Conjure Water" or tess.courtesy.spell ~= 6127 then
		fail(scenario, "the first offer is not Conjure Water, rank 4: " .. tostring(tess.courtesy.stage) .. " " .. tostring(tess.courtesy.spell))
	end
	if ns.Prompt:ReasonText(tess) ~= "conjure water for your target (level 30)" then
		fail(scenario, "the reason line reads " .. tostring(ns.Prompt:ReasonText(tess)))
	end
	ns.Prompt:Refresh()
	local ran = pressButton(ns)
	if ran ~= "/cast Conjure Water(Rank 4)" then fail(scenario, "the water press ran " .. flat(ran)) end
	ns.Courtesy.OnEvent(nil, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 6127)
	w.bags = { { WATER_25, 20 } }
	Mock.advance(5)
	tess = entryFor(ns, TESS)
	if not (tess and tess.courtesy and tess.courtesy.stage == "conjure" and tess.courtesy.key == "courtesy:food") then
		fail(scenario, "with the water in the bags, the food is not conjured before any trade")
		return
	end
	if ns.Prompt:ReasonText(tess) ~= "conjure food for your target (level 30)" then
		fail(scenario, "the food's reason line reads " .. tostring(ns.Prompt:ReasonText(tess)))
	end
	ns.Prompt:Refresh()
	ran = pressButton(ns)
	if ran ~= "/cast Conjure Food(Rank 4)" then fail(scenario, "the food press ran " .. flat(ran)) end
	ns.Courtesy.OnEvent(nil, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-2", 6129)
	w.bags = { { WATER_25, 20 }, { 1487, 20 } }
	Mock.advance(5)
	tess = entryFor(ns, TESS)
	if not (tess and tess.courtesy and tess.courtesy.stage == "trade") then
		fail(scenario, "with both in the bags the offer is not the trade")
		return
	end
	if ns.Prompt:ReasonText(tess) ~= "trade water and food to your target" then
		fail(scenario, "the trade's reason line reads " .. tostring(ns.Prompt:ReasonText(tess)))
	end
	ns.Prompt:Refresh()
	ran = pressButton(ns)
	if not (ran and ran:find("^/target " .. tess.name .. "\n/trade")) then
		fail(scenario, "the trade press ran " .. flat(ran))
	end
	openTrade(ns, w, names)
	if w.trade[1] ~= WATER_25 or w.trade[2] ~= 1487 then
		fail(scenario, "water and food are not in the window: " .. tradeText(w))
	end
	if w.accepted then fail(scenario, "Manners accepted the trade") end
	if w.cursor then fail(scenario, "the cursor was left holding something") end
end)

-- ---------------------------------------------------------- water-target 2
scene("water-target: a warrior is offered food alone", { classes = { target = "WARRIOR" }, power = { target = 0 } },
	function(ns, w)
	local scenario = "water-target: a warrior is offered food alone"
	local tess = entryFor(ns, TESS)
	if not (tess and tess.courtesy) then
		fail(scenario, "SKIPPED -- a warrior is offered nothing")
		return
	end
	if tess.courtesy.key ~= "courtesy:food" then fail(scenario, "offered " .. tostring(tess.courtesy.key)) end
	local request = tess.courtesy.request
	if request.keys["courtesy:water"] then fail(scenario, "water stands for somebody with no mana") end
	if ns.Prompt:ReasonText(tess) ~= "conjure food for your target (level 60)" then
		fail(scenario, "the reason line reads " .. tostring(ns.Prompt:ReasonText(tess)))
	end
end)

-- ---------------------------------------------------------- water-target 3
scene("water-target: a low-level target gets the low rank and never a stack above their level",
	{ levels = { target = 8 } }, function(ns, w, names)
	local scenario = "water-target: a low-level target gets the low rank and never a stack above their level"
	local tess = entryFor(ns, TESS)
	if not (tess and tess.courtesy and tess.courtesy.stage == "conjure" and tess.courtesy.spell == 5505) then
		fail(scenario, "a level 8 target is not offered rank 2 water: " .. tostring(tess and tess.courtesy and tess.courtesy.spell))
	end
	w.bags = { { WATER_TOP, 20 }, { WATER_25, 20 }, { WATER_5, 20 }, { FOOD_TOP, 20 }, { FOOD_5, 20 } }
	Mock.advance(5)
	tess = entryFor(ns, TESS)
	if not (tess and tess.courtesy and tess.courtesy.stage == "trade") then
		fail(scenario, "SKIPPED -- no trade is offered for what suits them")
		return
	end
	ns.Prompt:Refresh()
	pressButton(ns)
	openTrade(ns, w, names)
	for i = 1, 7 do
		local item = w.trade[i]
		if item == WATER_TOP or item == WATER_25 or item == FOOD_TOP then
			fail(scenario, "a stack above their level went in the window: " .. tradeText(w))
		end
	end
	if w.trade[1] ~= WATER_5 or w.trade[2] ~= FOOD_5 then fail(scenario, "the window holds " .. tradeText(w)) end
end)

scene("water-target: a low-level target gets the low rank and never a stack above their level",
	{ levels = { target = 10 }, known = { 1459, 6127, 6129 } }, function(ns)
	local scenario = "water-target: a low-level target gets the low rank and never a stack above their level"
	if entryFor(ns, TESS) then
		fail(scenario, "a level 10 target is offered a rank for level 25 and up when no lower one is learned")
	end
end)

-- ---------------------------------------------------------- water-target 4
scene("water-target: Fill the trade window puts in as many stacks as fit, water and food in turn, and leaves the player's own slots alone",
	{ bags = { { WATER_TOP, 20 }, { WATER_TOP, 20 }, { WATER_TOP, 20 }, { FOOD_TOP, 20 }, { FOOD_TOP, 20 } } },
	function(ns, w, names)
	local scenario = "water-target: Fill the trade window puts in as many stacks as fit, water and food in turn, and leaves the player's own slots alone"
	local tess = entryFor(ns, TESS)
	if not (tess and tess.courtesy and tess.courtesy.stage == "trade") then
		fail(scenario, "SKIPPED -- no trade is offered")
		return
	end
	w.trade[2] = 999
	ns.Prompt:Refresh()
	pressButton(ns)
	openTrade(ns, w, names)
	local want = { [1] = WATER_TOP, [2] = 999, [3] = FOOD_TOP, [4] = WATER_TOP, [5] = FOOD_TOP, [6] = WATER_TOP }
	for i = 1, 6 do
		if w.trade[i] ~= want[i] then
			fail(scenario, "the window holds " .. tradeText(w) .. ", not water, theirs, food, water, food, water")
			break
		end
	end
	if w.trade[7] ~= nil then fail(scenario, "the seventh slot was touched") end
	if w.accepted then fail(scenario, "Manners accepted the trade") end
end)

-- ---------------------------------------------------------- water-target 5
scene("water-target: One stack puts one of each",
	{ bags = { { WATER_TOP, 20 }, { WATER_TOP, 20 }, { FOOD_TOP, 20 }, { FOOD_TOP, 20 } } },
	function(ns, w, names)
	local scenario = "water-target: One stack puts one of each"
	ns.db.profile.sources.courtesyAmount = "one"
	local tess = entryFor(ns, TESS)
	if not (tess and tess.courtesy and tess.courtesy.stage == "trade") then
		fail(scenario, "SKIPPED -- no trade is offered")
		return
	end
	local lines = table.concat(ns.Prompt:ClickSummary(tess, ns.Prompt.state), "\n")
	if lines:find("fills the trade window", 1, true) then fail(scenario, "the tooltip says the window is filled: " .. lines) end
	if ns.Prompt:ReasonText(tess) ~= "trade water and food to your target" then
		fail(scenario, "one stack of each is not worded as water and food: " .. tostring(ns.Prompt:ReasonText(tess)))
	end
	ns.Prompt:Refresh()
	pressButton(ns)
	openTrade(ns, w, names)
	if w.trade[1] ~= WATER_TOP or w.trade[2] ~= FOOD_TOP or w.trade[3] ~= nil then
		fail(scenario, "the window holds " .. tradeText(w) .. ", not one of each")
	end
end)

-- ---------------------------------------------------------- water-target 6
scene("water-target: nothing but conjured water and food goes in the trade",
	{ bags = { { 2589, 20 }, { WATER_TOP, 20 }, { 1179, 20 }, { FOOD_TOP, 20 }, { 4540, 20 }, { 8932, 5 } } },
	function(ns, w, names)
	local scenario = "water-target: nothing but conjured water and food goes in the trade"
	local tess = entryFor(ns, TESS)
	if not (tess and tess.courtesy and tess.courtesy.stage == "trade") then
		fail(scenario, "SKIPPED -- no trade is offered")
		return
	end
	ns.Prompt:Refresh()
	pressButton(ns)
	openTrade(ns, w, names)
	for i = 1, 7 do
		local item = w.trade[i]
		if item ~= nil and item ~= WATER_TOP and item ~= FOOD_TOP then
			fail(scenario, "something else went in the window: " .. tradeText(w))
		end
	end
	if w.trade[1] ~= WATER_TOP or w.trade[2] ~= FOOD_TOP then fail(scenario, "the window holds " .. tradeText(w)) end
end)

-- ---------------------------------------------------------- water-target 7
scene("water-target: the cursor holding something, nothing goes in and nothing is dropped",
	{ bags = { { WATER_TOP, 20 }, { FOOD_TOP, 20 } } }, function(ns, w, names)
	local scenario = "water-target: the cursor holding something, nothing goes in and nothing is dropped"
	local tess = entryFor(ns, TESS)
	if not (tess and tess.courtesy and tess.courtesy.stage == "trade") then
		fail(scenario, "SKIPPED -- no trade is offered")
		return
	end
	ns.Prompt:Refresh()
	pressButton(ns)
	w.cursor = 55555
	w.cleared = false
	openTrade(ns, w, names)
	if next(w.trade) ~= nil or #w.picked > 0 then fail(scenario, "something was picked up or put in: " .. tradeText(w)) end
	if w.cursor ~= 55555 or w.cleared then fail(scenario, "what the cursor held was put down") end
end)

-- ---------------------------------------------------------- water-target 8
scene("water-target: nothing is offered in a fight", {}, function(ns)
	local scenario = "water-target: nothing is offered in a fight"
	if not entryFor(ns, TESS) then
		fail(scenario, "SKIPPED -- nothing is offered out of a fight")
		return
	end
	Mock.inCombat = true
	Mock.advance(1)
	if entryFor(ns, TESS) then fail(scenario, "the target is offered water in a fight") end
	if ns.Courtesy.Standing(GetTime()) then fail(scenario, "a courtesy stands in a fight") end
	Mock.inCombat = false
end)

-- ---------------------------------------------------------- water-target 9
scene("water-target: nobody but a friendly player is offered: not yourself, an enemy, an NPC or another mage",
	{}, function(ns, w, names)
	local scenario = "water-target: nobody but a friendly player is offered: not yourself, an enemy, an NPC or another mage"
	if not entryFor(ns, TESS) then
		fail(scenario, "SKIPPED -- a friendly priest is not offered water")
		return
	end
	local mine = names.target
	names.target = { "Mort", "Defrette" }
	Mock.advance(1)
	if entryFor(ns, "Mort Defrette") then fail(scenario, "you are offered water for yourself") end
	names.target = mine
	w.assist = false
	Mock.advance(1)
	if entryFor(ns, TESS) then fail(scenario, "an enemy is offered water") end
	w.assist = true
	w.npc = true
	Mock.advance(1)
	if entryFor(ns, TESS) then fail(scenario, "an NPC is offered water") end
	w.npc = false
	w.classes.target = "MAGE"
	Mock.advance(1)
	if entryFor(ns, TESS) then fail(scenario, "another mage is offered water") end
	w.classes.target = "PRIEST"
	Mock.advance(1)
	if not entryFor(ns, TESS) then fail(scenario, "the priest is not offered again once the rest are out of the way") end
end)

-- --------------------------------------------------------- water-target 10
scene("water-target: once traded or skipped they are left alone for ten minutes",
	{ bags = { { WATER_TOP, 20 }, { FOOD_TOP, 20 } }, names = { nameplate9 = { "Unused" } } }, function(ns, w, names)
	local scenario = "water-target: once traded or skipped they are left alone for ten minutes"
	if not entryFor(ns, TESS) then
		fail(scenario, "SKIPPED -- no trade is offered")
		return
	end
	ns.Prompt:Refresh()
	pressButton(ns)
	openTrade(ns, w, names)
	if w.trade[1] == nil then
		fail(scenario, "SKIPPED -- nothing went in the window")
		return
	end
	w.open = false
	names.NPC = nil
	Mock.advance(60)
	if entryFor(ns, TESS) then fail(scenario, "they are offered again a minute after a trade") end
	Mock.advance(601)
	if not entryFor(ns, TESS) then fail(scenario, "they are not offered again after ten minutes") end

	-- Somebody else, skipped with a right-click.
	names.target = { "Bert", "Beside" }
	w.targetId = "bert"
	w.partner = "bert"
	Mock.advance(1)
	local bert = entryFor(ns, "Bert Beside")
	if not bert then
		fail(scenario, "somebody else is not offered straight away")
		return
	end
	ns.Prompt:Refresh()
	pressButton(ns, "RightButton")
	Mock.advance(60)
	if entryFor(ns, "Bert Beside") then fail(scenario, "a skipped target is offered again a minute later") end
	Mock.advance(601)
	if not entryFor(ns, "Bert Beside") then fail(scenario, "a skipped target is not offered again after ten minutes") end
end)

-- --------------------------------------------------------- water-target 11
scene("water-target: switch off, nothing is offered", {}, function(ns)
	local scenario = "water-target: switch off, nothing is offered"
	if ns.defaults.profile.sources.courtesyTarget ~= false then fail(scenario, "the switch is not off in a new profile") end
	if ns.defaults.profile.sources.courtesyAmount ~= "fill" then fail(scenario, "the amount is not Fill in a new profile") end
	ns.db.profile.sources.courtesyTarget = false
	Mock.advance(1)
	if entryFor(ns, TESS) then fail(scenario, "the target is offered water with the switch off") end
	if ns.Courtesy.Standing(GetTime()) then fail(scenario, "a courtesy stands with the switch off") end
end)

-- --------------------------------------------------------- water-target 12
scene("water-target: a withheld level offers nothing on Classic, and a withheld power offers food", {},
	function(ns, w)
	local scenario = "water-target: a withheld level offers nothing on Classic, and a withheld power offers food"
	w.secretLevel = true
	Mock.advance(1)
	if entryFor(ns, TESS) then fail(scenario, "a target whose level cannot be read is offered water") end
	local said = table.concat(ns.RequestLines(), "\n")
	if not said:find("their level cannot be read", 1, true) then fail(scenario, "the check-up does not say why: " .. said) end
	w.secretLevel = false
	w.secretPower = true
	w.secretClass = true
	Mock.advance(1)
	local tess = entryFor(ns, TESS)
	if not (tess and tess.courtesy) then
		fail(scenario, "a target whose power is withheld is offered nothing")
		return
	end
	if tess.courtesy.key ~= "courtesy:food" or tess.courtesy.request.keys["courtesy:water"] then
		fail(scenario, "water is offered where it is not known to be wanted: " .. tostring(tess.courtesy.key))
	end
end)

-- --------------------------------------------------------- water-target 13
scene("water-target: mists: one refreshment that suits their level, nothing for a target below it",
	{ flavour = "mists", target = { "Tess" }, known = { 1459, 42955 }, bags = { { 80610, 20 }, { 65516, 20 } } }, function(ns, w, names)
	local scenario = "water-target: mists: one refreshment that suits their level, nothing for a target below it"
	local tess = entryFor(ns, "Tess")
	if not (tess and tess.courtesy and tess.courtesy.stage == "trade" and tess.courtesy.item == 65516) then
		fail(scenario, "the offer is not the trade of what suits a level 60: " .. tostring(tess and tess.courtesy and tess.courtesy.item) )
		return
	end
	if ns.Prompt:ReasonText(tess) ~= "trade water and food to your target" then
		fail(scenario, "the reason line reads " .. tostring(ns.Prompt:ReasonText(tess)))
	end
	ns.Prompt:Refresh()
	pressButton(ns)
	openTrade(ns, w, names)
	if w.trade[1] ~= 65516 or w.trade[2] ~= nil then fail(scenario, "the window holds " .. tradeText(w)) end
	-- Below what the spell makes at your level, with nothing in the bags.
	w.trade = {}
	w.bags = {}
	w.levels.target = 40
	w.targetId = "low"
	w.partner = "low"
	w.open = false
	names.NPC = nil
	Mock.advance(1)
	if entryFor(ns, "Tess") then fail(scenario, "a level 40 target is offered what they cannot use") end
end)

-- --------------------------------------------------------- water-target 14
scene("water-target: retail: Conjure Refreshment at any level",
	{ flavour = "mainline", target = { "Tess" }, known = { 1459, 190336 } }, function(ns, w)
	local scenario = "water-target: retail: Conjure Refreshment at any level"
	w.secretLevel = true
	local tess = entryFor(ns, "Tess")
	if not (tess and tess.courtesy and tess.courtesy.stage == "conjure" and tess.courtesy.spell == 190336) then
		fail(scenario, "a target with a withheld level is not offered Conjure Refreshment")
		return
	end
	if ns.Prompt:ReasonText(tess) ~= "conjure water and food for your target" then
		fail(scenario, "the reason line reads " .. tostring(ns.Prompt:ReasonText(tess)))
	end
	w.secretLevel = false
	w.levels.target = 20
	Mock.advance(1)
	tess = entryFor(ns, "Tess")
	if not (tess and tess.courtesy and ns.Prompt:ReasonText(tess) == "conjure water and food for your target (level 20)") then
		fail(scenario, "a level 20 target's reason line reads " .. tostring(tess and ns.Prompt:ReasonText(tess)))
	end
end)

-- --------------------------------------------------------- water-target 15
scene("water-target: a target past trade range is not offered the trade",
	{ bags = { { WATER_TOP, 20 }, { FOOD_TOP, 20 } } }, function(ns)
	local scenario = "water-target: a target past trade range is not offered the trade"
	Mock.yards = { target = 30 }
	Mock.advance(1)
	if entryFor(ns, TESS) then fail(scenario, "a target 30 yards away is offered a trade") end
	local said = table.concat(ns.RequestLines(), "\n")
	if not said:find("too far away to trade", 1, true) then fail(scenario, "the check-up does not say why: " .. said) end
	Mock.yards = nil
	Mock.setInteract("restricted")
	Mock.advance(1)
	if not entryFor(ns, TESS) then fail(scenario, "a client that tells nothing of the distance holds the offer back") end
	Mock.setInteract("on")
	Mock.advance(1)
	if not entryFor(ns, TESS) then fail(scenario, "the target is not offered once in reach") end
end)

-- --------------------------------------------------------- water-target 16
scene("water-target: a target who opens the trade themselves gets nothing put in",
	{ bags = { { WATER_TOP, 20 }, { FOOD_TOP, 20 } } }, function(ns, w, names)
	local scenario = "water-target: a target who opens the trade themselves gets nothing put in"
	if not entryFor(ns, TESS) then
		fail(scenario, "SKIPPED -- the target is not offered a trade")
		return
	end
	openTrade(ns, w, names)
	if w.trade[1] ~= nil or w.clicks ~= 0 then fail(scenario, "the window holds " .. tradeText(w)) end
	if w.accepted then fail(scenario, "Manners accepted the trade") end
end)

-- The full tooltip of a target offer holds no "unreadable" line, and the mana
-- floor holds the offer back whatever it keeps.
scene("water-target: no unreadable-buff line on the target's tooltip, and the mana floor holds the offer",
	{ levels = { target = 30 } }, function(ns, w)
	local scenario = "water-target: no unreadable-buff line on the target's tooltip, and the mana floor holds the offer"
	local tess = entryFor(ns, TESS)
	if not (tess and tess.courtesy) then
		fail(scenario, "SKIPPED -- the target is not offered water")
		return
	end
	local lines = {}
	local realAdd = GameTooltip.AddLine
	GameTooltip.AddLine = function(_, text) lines[#lines + 1] = tostring(text) end
	ns.Prompt:ApplyTarget(tess)
	ns.db.profile.prompt.tooltip = "full"
	local onEnter = ns.Prompt:GetButton().scripts.OnEnter
	if onEnter then pcall(onEnter, ns.Prompt:GetButton()) end
	GameTooltip.AddLine = realAdd
	if table.concat(lines, "\n"):find("unreadable", 1, true) then
		fail(scenario, "the target's tooltip warns of an unreadable buff")
	end
	local db = ns.db.profile
	db.filters.manaFloor = 30
	db.filters.manaFloorKeeps = "asked"
	local realPower = _G.UnitPower
	_G.UnitPower = function() return 200 end
	Mock.advance(1)
	local saving = ns.SavingMana() ~= nil
	local offered = entryFor(ns, TESS)
	_G.UnitPower = realPower
	if not saving then
		fail(scenario, "SKIPPED -- the floor is not saving mana at 20%")
	elseif offered then
		fail(scenario, "the target is offered below the mana floor")
	end
end)

-- --------------------------------------------------------- water-target 17
scene("water-target: an asked courtesy fills the window with what was asked for",
	{ switches = { "courtesyRefresh" }, names = { nameplate1 = { "Anna", "Aim" } },
		bags = { { WATER_TOP, 20 }, { WATER_TOP, 20 }, { FOOD_TOP, 20 }, { FOOD_TOP, 20 } } },
	function(ns, w, names)
	local scenario = "water-target: an asked courtesy fills the window with what was asked for"
	names.target = nil
	w.partner = "nameplate1"
	hear(ns, "CHAT_MSG_SAY", "water and food pls", "Anna Aim", "Player-1-nameplate1")
	local anna = entryFor(ns, "Anna Aim")
	if not (anna and anna.courtesy and anna.courtesy.stage == "trade") then
		fail(scenario, "SKIPPED -- the trade is not offered to the one who asked")
		return
	end
	ns.Prompt:Refresh()
	pressButton(ns)
	openTrade(ns, w, names, { "Anna", "Aim" })
	if w.trade[1] ~= WATER_TOP or w.trade[2] ~= FOOD_TOP or w.trade[3] ~= WATER_TOP or w.trade[4] ~= FOOD_TOP then
		fail(scenario, "the window holds " .. tradeText(w))
	end
	if #ns.standingRequests ~= 0 then fail(scenario, "the request still stands after both were answered") end
end)

-- --------------------------------------------------------- water-target 18
scene("water-target: the switch shows for a mage alone, How much to trade beside it, and both reset", {},
	function(ns)
	local scenario = "water-target: the switch shows for a mage alone, How much to trade beside it, and both reset"
	local target = H.findOption(ns.optionsTable, "courtesyTarget")
	local amount = H.findOption(ns.optionsTable, "courtesyAmount")
	if not (target and amount) then
		fail(scenario, "SKIPPED -- the two controls are not on the Who to buff page")
		return
	end
	local db = ns.db.profile
	if target.hidden() then fail(scenario, "a mage is not shown Offer water and food to my target") end
	db.sources.courtesyTarget = false
	db.sources.asked = false
	if not amount.hidden() then fail(scenario, "How much to trade shows with nothing to trade") end
	target.set({ "courtesyTarget" }, true)
	if db.sources.courtesyTarget ~= true then fail(scenario, "ticking the switch did not turn it on") end
	if amount.hidden() then fail(scenario, "How much to trade is hidden beside the switch") end
	amount.set({ "courtesyAmount" }, "one")
	if db.sources.courtesyAmount ~= "one" then fail(scenario, "choosing One stack did not take") end
	for _, key in ipairs({ "courtesyTarget", "courtesyAmount" }) do
		local listed = false
		for _, field in ipairs(ns.OptionsPage.RESET.services) do
			if field == "sources." .. key then listed = true end
		end
		if not listed then fail(scenario, key .. " is not put back by the page's reset") end
	end
	db.sources.courtesyAmount = "everything"
	ns.ClampSettings()
	if db.sources.courtesyAmount ~= "fill" then fail(scenario, "a setting that is neither is not mended to Fill") end
end)

scene("water-target: the switch shows for a mage alone, How much to trade beside it, and both reset",
	{ class = "WARLOCK", known = { 687, 5697 } }, function(ns)
	local scenario = "water-target: the switch shows for a mage alone, How much to trade beside it, and both reset"
	local target = H.findOption(ns.optionsTable, "courtesyTarget")
	local amount = H.findOption(ns.optionsTable, "courtesyAmount")
	if not (target and amount) then
		fail(scenario, "SKIPPED -- the two controls are not on the Who to buff page")
		return
	end
	ns.db.profile.sources.courtesyTarget = true
	if not target.hidden() or not amount.hidden() then fail(scenario, "a warlock is shown the mage's water and food") end
	if entryFor(ns, TESS) then fail(scenario, "a warlock offers water to a target") end
end)

-- --------------------------------------------------------- water-target 19
scene("water-target: /manners debug says what holds the offer back",
	{ bags = { { WATER_TOP, 20 }, { FOOD_TOP, 20 } } }, function(ns)
	local scenario = "water-target: /manners debug says what holds the offer back"
	local said = table.concat(ns.RequestLines(), "\n")
	if not said:find("water and food for your target", 1, true) then fail(scenario, "the switches line does not name it: " .. said) end
	Mock.yards = { target = 30 }
	Mock.advance(1)
	entryFor(ns, TESS)
	said = table.concat(ns.RequestLines(), "\n")
	if not (said:find("your target", 1, true) and said:find("too far away to trade", 1, true)) then
		fail(scenario, "the check-up does not say the target is too far: " .. said)
	end
	Mock.yards = nil
	Mock.advance(1)
	entryFor(ns, TESS)
	said = table.concat(ns.RequestLines(), "\n")
	if not said:find("on the prompt", 1, true) then fail(scenario, "the check-up does not say it is on the prompt: " .. said) end
end)
