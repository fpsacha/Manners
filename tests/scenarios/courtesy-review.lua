-- The review of a class's courtesies on request (Courtesy.lua and its hook in
-- Queue.lua's BuildQueue): one portal for a city with two, one refreshment
-- for water and food where they are one, a conjure that failed asked for
-- again, a trade the asker opened themselves, and the walk for a cure and the
-- ask kept while a courtesy stands.
--
-- Called by scenarios.lua with the addon directory and its helpers. The
-- bags, the spell book, the cursor and the trade window are stood in here
-- (`world`), as tests/scenarios/courtesy.lua does. Every global a scenario
-- replaces is put back after it. Every name starts "courtesy-review:", so
-- the mutations in tests/mutations/courtesy-review.py can name the one that
-- has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, pressButton = H.strangers, H.freshPrompt, H.pressButton

local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "C_Spell", "GetItemCount", "C_Container",
	"ClickTradeButton", "GetTradePlayerItemLink", "GetCursorInfo", "CursorHasItem", "ClearCursor",
	"AcceptTrade", "UnitGUID", "UnitLevel", "UnitInParty", "IsUsableSpell", "MAX_TRADABLE_ITEMS", "IsResting",
	"TradeFrame", "C_UnitAuras", "UnitAffectingCombat" }
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
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.name == name then return entry end
	end
	return nil
end

local function hear(ns, event, text, sender, guid)
	ns.addon[event](ns.addon, event, text, sender, "Common", "", "", "", 0, 0, "", 0, 1, guid)
end

local function flat(text)
	return (tostring(text):gsub("\n", " / "))
end

-- The courtesy keys a request holds, sorted and joined.
local function keysOf(request)
	local list = {}
	for key in pairs(request and request.keys or {}) do list[#list + 1] = tostring(key) end
	table.sort(list)
	return table.concat(list, ", ")
end

-- The names the client gives the spells these scenarios use.
local SPELLS = {
	[1459] = "Arcane Intellect", [475] = "Remove Lesser Curse",
	[5504] = "Conjure Water", [5505] = "Conjure Water", [5506] = "Conjure Water", [6127] = "Conjure Water",
	[10138] = "Conjure Water", [10139] = "Conjure Water", [10140] = "Conjure Water",
	[587] = "Conjure Food", [28612] = "Conjure Food",
	[42955] = "Conjure Refreshment",
	[53142] = "Portal: Dalaran - Northrend", [224871] = "Portal: Dalaran - Broken Isles",
	[32267] = "Portal: Silvermoon", [1259194] = "Portal: Silvermoon City",
}
local RANKS = { [5504] = "Rank 1", [5505] = "Rank 2", [5506] = "Rank 3", [6127] = "Rank 4",
	[10138] = "Rank 5", [10139] = "Rank 6", [10140] = "Rank 7" }

-- A spell book, bags, a cursor and a trade window: `known` is a list of spell
-- ids, `bags` item -> count (changed by the scenario as it goes), `levels`
-- token -> level, `party` whether every party token is in your party,
-- `partner` the token whose GUID the trade's other side answers with, and
-- `open` (set by the scenario) whether the trade window is up.
local function world(opts)
	local w = { bags = opts.bags or {}, trade = {}, picked = {}, levels = opts.levels or {}, open = false }
	local known = {}
	for _, id in ipairs(opts.known or {}) do known[id] = true end
	local knows = function(id) return known[id] == true end
	local base = _G.C_Spell
	local spell = setmetatable({
		GetSpellName = function(id) return SPELLS[id] end,
		GetSpellSubtext = function(id) return RANKS[id] end,
	}, { __index = base })
	local function slotItems()
		local list = {}
		for item, count in pairs(w.bags) do
			if count > 0 then list[#list + 1] = item end
		end
		table.sort(list)
		return list
	end
	w.partner = opts.partner or "nameplate1"
	w.globals = {
		IsSpellKnown = knows, IsPlayerSpell = knows, C_Spell = spell,
		GetItemCount = function(item) return w.bags[item] or 0 end,
		C_Container = {
			GetContainerNumSlots = function(bag) return bag == 0 and 16 or 0 end,
			GetContainerItemID = function(bag, slot) return bag == 0 and slotItems()[slot] or nil end,
			GetContainerItemInfo = function() return { isLocked = false } end,
			PickupContainerItem = function(bag, slot)
				w.cursor = slotItems()[slot]
				w.picked[#w.picked + 1] = w.cursor
			end,
		},
		GetCursorInfo = function() if w.cursor then return "item", w.cursor end end,
		CursorHasItem = function() return w.cursor ~= nil end,
		ClearCursor = function() w.cursor = nil end,
		ClickTradeButton = function(index)
			w.trade[index] = w.cursor
			w.cursor = nil
		end,
		GetTradePlayerItemLink = function(index) return w.trade[index] and "link" or nil end,
		AcceptTrade = function() w.accepted = true end,
		UnitGUID = function(unit)
			if unit == "NPC" then return "Player-1-" .. w.partner end
			return "Player-1-" .. tostring(unit)
		end,
		UnitLevel = function(unit)
			if unit == "player" then return 60 end
			if unit == "NPC" then return w.levels[w.partner] or 60 end
			return w.levels[unit] or 60
		end,
		MAX_TRADABLE_ITEMS = 6,
		TradeFrame = { IsShown = function() return w.open end },
	}
	if opts.party then
		w.globals.UnitInParty = function(unit) return type(unit) == "string" and unit:find("^party%d+$") ~= nil end
	end
	return w
end

-- A loaded addon with the prompt settled, people who ask switched on and
-- nobody offered anything unasked, so whoever is in the queue asked.
local function ready(ns, scenario, switches)
	freshPrompt(ns, scenario)
	local db = ns.db.profile
	db.sources.asked = true
	db.sources.strangers = false
	db.sources.group = false
	db.sources.self = false
	for _, key in ipairs(switches or {}) do db.sources[key] = true end
end

local MAGE = { 1459, 5504, 5505, 5506, 6127, 10138, 10139, 10140, 587, 28612 }

-- ---------------------------------------------------------- courtesy-review 1
-- Retail: Dalaran and Silvermoon City have two portals each. One request for
-- the city is one portal, the first of the two in the client's list, and it
-- is answered once that portal has gone out.
Mock.reset()
do
	local scenario = "courtesy-review: a city with two portals learned is answered with one portal"
	Mock.setFlavour("mainline")
	local restoreUnits = strangers({ party1 = { "Anna" } })
	local w = world({ known = { 1459, 53142, 224871, 32267, 1259194 }, party = true })
	Mock.groupSize = 2
	with(scenario, w.globals, function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario, { "courtesyPortals" })
		hear(ns, "CHAT_MSG_PARTY", "portal to dal pls", "Anna", "Player-1-party1")
		local request = ns.standingRequests[1]
		if not request then
			fail(scenario, "SKIPPED -- the request for a portal to Dalaran was not kept")
			return
		end
		if keysOf(request) ~= "courtesy:portal:53142" then
			fail(scenario, "one request for Dalaran is kept as " .. keysOf(request))
		end
		local anna = entryFor(ns, "Anna")
		if not (anna and anna.courtesy and anna.courtesy.spell == 53142) then
			fail(scenario, "the portal offered is " .. tostring(anna and anna.courtesy and anna.courtesy.spell)
				.. ", not Northrend's Dalaran, the first of the two in the list")
			return
		end
		ns.Prompt:Refresh()
		local ran = pressButton(ns)
		if ran ~= "/cast Portal: Dalaran - Northrend" then fail(scenario, "the press ran " .. flat(ran)) end
		ns.Courtesy.OnEvent(nil, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 53142)
		if #ns.standingRequests ~= 0 then
			fail(scenario, "the request still stands after its portal went out: " .. keysOf(ns.standingRequests[1]))
		end
		Mock.advance(13)
		anna = entryFor(ns, "Anna")
		if anna then
			fail(scenario, "a second portal is offered for the one request: " .. tostring(anna.courtesy and anna.courtesy.spell))
		end
		Mock.advance(61)

		-- Silvermoon City: Midnight's is the first of the two in the list.
		hear(ns, "CHAT_MSG_PARTY", "port silvermoon?", "Anna", "Player-1-party1")
		request = ns.standingRequests[1]
		if keysOf(request) ~= "courtesy:portal:1259194" then
			fail(scenario, "one request for Silvermoon is kept as " .. keysOf(request))
		end
		Mock.advance(61)

		-- More of the message naming the other one: that is the one meant.
		hear(ns, "CHAT_MSG_PARTY", "port to dalaran broken isles pls", "Anna", "Player-1-party1")
		request = ns.standingRequests[1]
		if keysOf(request) ~= "courtesy:portal:224871" then
			fail(scenario, "Dalaran of the Broken Isles asked for by name is kept as " .. keysOf(request))
		end
		Mock.advance(61)
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ---------------------------------------------------------- courtesy-review 2
-- Two portals standing on one request are answered in the order of the
-- client's list, not by spell id: Midnight's Silvermoon City (the newest id)
-- stands ahead of Dalaran in it.
Mock.reset()
do
	local scenario = "courtesy-review: two portals asked for are answered in the client's order"
	Mock.setFlavour("mainline")
	local restoreUnits = strangers({ party1 = { "Anna" } })
	local w = world({ known = { 1459, 53142, 1259194 }, party = true })
	Mock.groupSize = 2
	with(scenario, w.globals, function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario, { "courtesyPortals" })
		hear(ns, "CHAT_MSG_PARTY", "port to dalaran pls", "Anna", "Player-1-party1")
		local request = ns.standingRequests[1]
		if not request then
			fail(scenario, "SKIPPED -- the request for a portal was not kept")
			return
		end
		request.keys["courtesy:portal:1259194"] = true
		local anna = entryFor(ns, "Anna")
		if not (anna and anna.courtesy) then
			fail(scenario, "SKIPPED -- no portal is offered")
			return
		end
		if anna.courtesy.spell ~= 1259194 then
			fail(scenario, "the first portal offered is " .. tostring(anna.courtesy.spell)
				.. ", not Silvermoon City, which stands first in the list")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ---------------------------------------------------------- courtesy-review 3
-- Mists: water and food are one spell and one item. Asked for together they
-- are one conjure and one trade, and nothing is offered over a press that is
-- still being waited on.
Mock.reset()
do
	local scenario = "courtesy-review: mists: water and food asked for together are one refreshment"
	Mock.setFlavour("mists")
	local names = { nameplate1 = { "Anna" } }
	local restoreUnits = strangers(names)
	-- Level 90, as the Conjured Mana Pudding (80610) asks of whoever eats it.
	local w = world({ known = { 1459, 42955 }, levels = { nameplate1 = 90 } })
	with(scenario, w.globals, function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario, { "courtesyRefresh" })
		hear(ns, "CHAT_MSG_SAY", "water and food pls", "Anna", "Player-1-nameplate1")
		local request = ns.standingRequests[1]
		if not (request and request.keys["courtesy:water"] and request.keys["courtesy:food"]) then
			fail(scenario, "SKIPPED -- the request does not hold both water and food: " .. keysOf(request))
			return
		end
		local anna = entryFor(ns, "Anna")
		if not (anna and anna.courtesy and anna.courtesy.stage == "conjure") then
			fail(scenario, "SKIPPED -- the conjure is not offered")
			return
		end
		ns.Prompt:Refresh()
		pressButton(ns)
		anna = entryFor(ns, "Anna")
		if anna then
			fail(scenario, "while the conjure is on its way the prompt offers another: "
				.. tostring(ns.Prompt:ReasonText(anna)))
		end
		w.bags[80610] = 20
		Mock.advance(5)
		anna = entryFor(ns, "Anna")
		if not (anna and anna.courtesy and anna.courtesy.stage == "trade") then
			fail(scenario, "SKIPPED -- the refreshment in the bags is not offered as the trade")
			return
		end
		ns.Prompt:Refresh()
		pressButton(ns)
		names.NPC = { "Anna" }
		w.open = true
		ns.Courtesy.OnEvent(nil, "TRADE_SHOW")
		if w.trade[1] ~= 80610 then fail(scenario, "the refreshment was not put in the trade") end
		if #ns.standingRequests ~= 0 then
			fail(scenario, "the request still stands after the one trade that answers both: "
				.. keysOf(ns.standingRequests[1]))
		end
		w.open = false
		w.bags[80610] = 0
		Mock.advance(10)
		anna = entryFor(ns, "Anna")
		if anna then
			fail(scenario, "a second answer is offered for the same request: " .. tostring(ns.Prompt:ReasonText(anna)))
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ---------------------------------------------------------- courtesy-review 4
-- A conjure pressed is not a conjure made. One that failed (pressed on the
-- move, or without the mana) leaves the conjure on the prompt, not a trade of
-- water they are too low to drink; once the cast is seen to go out and the
-- bags still hold nothing that suits them, what there is is offered.
Mock.reset()
do
	local scenario = "courtesy-review: a conjure that failed is offered again, not a trade of water they cannot drink"
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
	local w = world({ known = MAGE, bags = { [8079] = 20 }, levels = { nameplate1 = 30 } })
	with(scenario, w.globals, function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario, { "courtesyRefresh" })
		hear(ns, "CHAT_MSG_SAY", "water pls", "Anna Aim", "Player-1-nameplate1")
		local anna = entryFor(ns, "Anna Aim")
		if not (anna and anna.courtesy and anna.courtesy.stage == "conjure") then
			fail(scenario, "SKIPPED -- somebody of level 30 is not offered a conjure over the level 55 water held")
			return
		end
		ns.Prompt:Refresh()
		local ran = pressButton(ns)
		if ran ~= "/cast Conjure Water(Rank 4)" then fail(scenario, "the conjure for level 30 ran " .. flat(ran)) end
		-- No cast went out, and nothing landed in the bags.
		Mock.advance(5)
		anna = entryFor(ns, "Anna Aim")
		if not (anna and anna.courtesy) then
			fail(scenario, "nothing is offered once the failed conjure's moment has passed")
			return
		end
		if anna.courtesy.stage ~= "conjure" then
			fail(scenario, ("after a conjure that failed the offer is a %s of item %s, which they cannot drink")
				:format(tostring(anna.courtesy.stage), tostring(anna.courtesy.item)))
			return
		end
		-- Pressed again, and this time the cast goes out; another spell's does
		-- not count for it.
		ns.Prompt:Refresh()
		pressButton(ns)
		ns.Courtesy.OnEvent(nil, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 1459)
		Mock.advance(5)
		anna = entryFor(ns, "Anna Aim")
		if not (anna and anna.courtesy and anna.courtesy.stage == "conjure") then
			fail(scenario, "another spell going out was read as the conjure")
			return
		end
		ns.Prompt:Refresh()
		pressButton(ns)
		ns.Courtesy.OnEvent(nil, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-2", 6127)
		Mock.advance(5)
		anna = entryFor(ns, "Anna Aim")
		if not (anna and anna.courtesy and anna.courtesy.stage == "trade" and anna.courtesy.item == 8079) then
			fail(scenario, "conjured for them and still nothing that suits them: what the bags hold is not offered ("
				.. tostring(anna and anna.courtesy and anna.courtesy.stage) .. ")")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ---------------------------------------------------------- courtesy-review 5
-- Whoever asks a mage for water mostly opens the trade themselves. The water
-- goes into that window and the request is answered, with no press; a trade
-- somebody else opens gets nothing.
Mock.reset()
do
	local scenario = "courtesy-review: a trade the asker opens themselves gets the water and answers the request"
	local names = { nameplate1 = { "Anna", "Aim" } }
	local restoreUnits = strangers(names)
	local w = world({ known = MAGE, bags = { [8079] = 20 } })
	with(scenario, w.globals, function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario, { "courtesyRefresh" })
		hear(ns, "CHAT_MSG_SAY", "water pls", "Anna Aim", "Player-1-nameplate1")
		local anna = entryFor(ns, "Anna Aim")
		if not (anna and anna.courtesy and anna.courtesy.stage == "trade") then
			fail(scenario, "SKIPPED -- the water in the bags is not offered as a trade")
			return
		end
		-- Somebody else opens a trade first: nothing of hers goes into it.
		names.NPC = { "Bert", "Beside" }
		w.partner = "nameplate2"
		w.open = true
		ns.Courtesy.OnEvent(nil, "TRADE_SHOW")
		if w.trade[1] or #w.picked > 0 then fail(scenario, "the water went into a trade somebody else opened") end
		if #ns.standingRequests ~= 1 then fail(scenario, "a trade somebody else opened answered her request") end
		-- She opens one herself, and no press came before it.
		names.NPC = { "Anna", "Aim" }
		w.partner = "nameplate1"
		ns.Courtesy.OnEvent(nil, "TRADE_SHOW")
		if w.trade[1] ~= 8079 then
			fail(scenario, "the water was not put in the trade she opened herself (" .. tostring(w.trade[1]) .. ")")
		end
		if w.cursor then fail(scenario, "the cursor was left holding the water") end
		if w.accepted then fail(scenario, "Manners accepted the trade") end
		if #ns.standingRequests ~= 0 then fail(scenario, "the request still stands after the water went into her trade") end
		Mock.advance(10)
		if entryFor(ns, "Anna Aim") then fail(scenario, "she is offered water again after the trade") end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ---------------------------------------------------------- courtesy-review 6
-- She opens the trade while the bags hold no water. Nothing goes in then; once
-- it is conjured, the press finds the window open with her already (its
-- /trade opens nothing, and no TRADE_SHOW follows) and puts the water in.
Mock.reset()
do
	local scenario = "courtesy-review: a press with her trade already open puts the water in it"
	local names = { nameplate1 = { "Anna", "Aim" } }
	local restoreUnits = strangers(names)
	local w = world({ known = MAGE, bags = {} })
	with(scenario, w.globals, function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario, { "courtesyRefresh" })
		hear(ns, "CHAT_MSG_SAY", "water pls", "Anna Aim", "Player-1-nameplate1")
		local anna = entryFor(ns, "Anna Aim")
		if not (anna and anna.courtesy and anna.courtesy.stage == "conjure") then
			fail(scenario, "SKIPPED -- with empty bags the conjure is not offered")
			return
		end
		names.NPC = { "Anna", "Aim" }
		w.open = true
		ns.Courtesy.OnEvent(nil, "TRADE_SHOW")
		if w.trade[1] or #ns.standingRequests ~= 1 then
			fail(scenario, "with no water in the bags her trade was answered all the same")
		end
		ns.Prompt:Refresh()
		pressButton(ns)
		ns.Courtesy.OnEvent(nil, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 10140)
		w.bags[8079] = 20
		Mock.advance(5)
		anna = entryFor(ns, "Anna Aim")
		if not (anna and anna.courtesy and anna.courtesy.stage == "trade") then
			fail(scenario, "SKIPPED -- the conjured water is not offered as the trade")
			return
		end
		ns.Prompt:Refresh()
		pressButton(ns)
		if w.trade[1] ~= 8079 then
			fail(scenario, "the press did not put the water in the trade already open with her (" .. tostring(w.trade[1]) .. ")")
		end
		if w.accepted then fail(scenario, "Manners accepted the trade") end
		if #ns.standingRequests ~= 0 then fail(scenario, "the request still stands after the press put the water in") end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ---------------------------------------------------------- courtesy-review 7
-- A single-item trade is complete only after its item is in the window. A
-- full window must not consume either a healthstone or a Soulstone request.
Mock.reset()
do
	local scenario = "courtesy-review: a failed item trade keeps the healthstone and Soulstone request"
	Mock.class = "WARLOCK"
	local names = { nameplate1 = { "Anna", "Aim" }, NPC = { "Anna", "Aim" } }
	local restoreUnits = strangers(names)
	local w = world({ bags = { [19013] = 1, [16896] = 1 } })
	with(scenario, w.globals, function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario, { "courtesyHealthstones", "courtesySoulstone" })
		for _, case in ipairs({
			{ key = "courtesy:healthstone", item = 19013 },
			{ key = "courtesy:soulstone", item = 16896 },
		}) do
			local request = {
				name = "Anna Aim", short = "Anna Aim", guid = "Player-1-nameplate1",
				expires = GetTime() + 60, keys = { [case.key] = true },
			}
			local entry = {
				name = "Anna Aim",
				courtesy = { stage = "trade", request = request, key = case.key,
					item = case.item, buffKey = case.key },
			}
			for slot = 1, 6 do w.trade[slot] = 4306 end
			ns.Courtesy.Pressed(entry, { isBar = false }, GetTime())
			ns.Courtesy.OnEvent(nil, "TRADE_SHOW")
			if not request.keys[case.key] then
				fail(scenario, case.key .. " was consumed although the full trade took no item")
			end
			if #w.picked ~= 0 then fail(scenario, case.key .. " picked up an item for a full trade") end
			w.trade = {}
			ns.Courtesy.Pressed(entry, { isBar = false }, GetTime())
			ns.Courtesy.OnEvent(nil, "TRADE_SHOW")
			if w.trade[1] ~= case.item then
				fail(scenario, case.key .. " was not placed after the trade had room")
			end
			if request.keys[case.key] then
				fail(scenario, case.key .. " still stands after its item was placed")
			end
			w.picked, w.trade = {}, {}
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ---------------------------------------------------------- courtesy-review 8
-- A mage with no buff to give and a cure switched on still walks for the
-- cure while a courtesy stands, answerable or not: here somebody out of sight
-- asked for water.
Mock.reset()
do
	local scenario = "courtesy-review: a courtesy standing does not stop the walk for a cure"
	local restoreUnits = strangers({ party1 = { "Gwen", "Hale" } })
	local known = { 1459, 475, 5504, 10140 }
	local w = world({ known = known, bags = { [8079] = 20 }, party = true })
	Mock.groupSize = 2
	Mock.held = { [1459] = true }
	local cursed = false
	local base = _G.C_UnitAuras
	w.globals.C_UnitAuras = setmetatable({
		GetAuraDataByIndex = function(unit, index, filter)
			if filter ~= "HARMFUL" then return base.GetAuraDataByIndex(unit, index, filter) end
			if not (cursed and unit == "party1" and index == 1) then return nil end
			return {
				name = "Curse thing", spellId = 90000, dispelName = "Curse",
				expirationTime = Mock.now + 60, duration = 60, isHarmful = true, auraInstanceID = 9001,
			}
		end,
	}, { __index = base })
	with(scenario, w.globals, function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario, { "courtesyRefresh" })
		local db = ns.db.profile
		db.sources.group = true
		db.sources.cures = true
		db.buff.skip = { intellect = true }
		ns.Guard("probe", ns.ProbeCapabilities)
		if #ns.CastableBuffs() ~= 0 then
			fail(scenario, "SKIPPED -- the mage still has a buff to give")
			return
		end
		cursed = true
		Mock.advance(4)
		local gwen = entryFor(ns, "Gwen Hale")
		if not (gwen and gwen.cure == "Curse") then
			fail(scenario, "SKIPPED -- the cursed party member is not offered the cure with nobody asking")
			return
		end
		-- Somebody no token names asks for water: nothing to offer them.
		hear(ns, "CHAT_MSG_SAY", "water pls", "Zed Zane", "Player-1-nobody")
		if #ns.standingRequests ~= 1 then
			fail(scenario, "SKIPPED -- the request for water was not kept")
			return
		end
		Mock.advance(4)
		gwen = entryFor(ns, "Gwen Hale")
		if not (gwen and gwen.cure == "Curse") then
			fail(scenario, "with a courtesy standing the cursed party member is no longer offered the cure")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()

-- ---------------------------------------------------------- courtesy-review 9
-- And somebody to ask for a buff (Ask.lua) still comes up behind it.
Mock.reset()
do
	local scenario = "courtesy-review: a courtesy standing does not stop the ask"
	Mock.unitClass = "PRIEST"
	Mock.playerHeld = {}
	local restoreUnits = strangers({ nameplate1 = { "Anna", "Aim" } })
	local w = world({ known = MAGE, bags = { [8079] = 20 } })
	w.globals.IsResting = function() return false end
	w.globals.UnitAffectingCombat = function() return false end
	with(scenario, w.globals, function()
		local ns = load(scenario)
		if not ns then return end
		ready(ns, scenario, { "courtesyRefresh" })
		local db = ns.db.profile
		db.sources.ask = true
		ns.Ask.ARRIVE_SECONDS = 0
		db.buff.skip = { intellect = true }
		if #ns.CastableBuffs() ~= 0 then
			fail(scenario, "SKIPPED -- the mage still has a buff to give")
			return
		end
		local function asking()
			for _, entry in ipairs(ns.BuildQueue()) do
				if entry.ask then return entry end
			end
			return nil
		end
		if not asking() then
			fail(scenario, "SKIPPED -- nobody is asked for a buff with no courtesy standing")
			return
		end
		hear(ns, "CHAT_MSG_SAY", "water pls", "Zed Zane", "Player-1-nobody")
		if #ns.standingRequests ~= 1 then
			fail(scenario, "SKIPPED -- the request for water was not kept")
			return
		end
		if not asking() then fail(scenario, "with a courtesy standing nobody is asked for a buff any more") end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()
